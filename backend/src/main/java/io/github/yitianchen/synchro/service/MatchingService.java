package io.github.yitianchen.synchro.service;

import io.github.yitianchen.synchro.model.Match;
import io.github.yitianchen.synchro.model.Profile;
import io.github.yitianchen.synchro.model.User;
import io.github.yitianchen.synchro.model.UserTrait;
import io.github.yitianchen.synchro.repository.MatchRepository;
import io.github.yitianchen.synchro.repository.ProfileRepository;
import io.github.yitianchen.synchro.repository.UserRepository;
import io.github.yitianchen.synchro.repository.UserTraitRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class MatchingService {

    private final UserRepository userRepository;
    private final ProfileRepository profileRepository;
    private final UserTraitRepository userTraitRepository;
    private final MatchRepository matchRepository;
    private final EmbeddingService embeddingService;

    @Value("${matching.trait-similarity-weight:0.3}")
    private double traitSimilarityWeight;

    @Value("${matching.semantic-similarity-weight:0.25}")
    private double semanticSimilarityWeight;

    @Value("${matching.preference-match-weight:0.25}")
    private double preferenceMatchWeight;

    @Value("${matching.complementarity-weight:0.2}")
    private double complementarityWeight;

    @Transactional
    public void executeWeeklyMatching() {
        log.info("[MatchingService] Starting weekly matching");

        LocalDate thisFriday = getThisFriday();
        LocalDate lastFriday = thisFriday.minusWeeks(1);

        List<User> eligibleUsers = userRepository.findAll().stream()
                .filter(u -> u.getStatus() == User.UserStatus.ACTIVE)
                .filter(u -> u.isOnboardingCompleted())
                .filter(User::isMatchingOptIn)
                .filter(u -> !matchRepository.existsByUser1IdOrUser2IdAndMatchWeek(u.getId(), u.getId(), thisFriday))
                .collect(Collectors.toList());

        log.info("[MatchingService] Found {} eligible users", eligibleUsers.size());

        if (eligibleUsers.size() < 2) {
            log.warn("[MatchingService] Not enough eligible users for matching");
            return;
        }

        // Greedy matching: sort by average compatibility and pair highest with highest
        List<User> sortedUsers = new ArrayList<>(eligibleUsers);
        Collections.shuffle(sortedUsers); // Randomize to avoid bias

        // Calculate average scores for sorting
        Map<Long, Double> userAverageScores = new HashMap<>();
        for (User user : sortedUsers) {
            double avgScore = sortedUsers.stream()
                    .filter(other -> !other.getId().equals(user.getId()))
                    .mapToDouble(other -> calculateCompatibilityScore(user.getId(), other.getId()))
                    .average()
                    .orElse(0.5);
            userAverageScores.put(user.getId(), avgScore);
        }

        sortedUsers.sort((u1, u2) -> Double.compare(
                userAverageScores.getOrDefault(u2.getId(), 0.0),
                userAverageScores.getOrDefault(u1.getId(), 0.0)));

        Set<Long> matchedUsers = new HashSet<>();
        List<Match> createdMatches = new ArrayList<>();

        for (User user : sortedUsers) {
            if (matchedUsers.contains(user.getId())) continue;

            User bestMatch = null;
            double bestScore = -1;

            for (User candidate : sortedUsers) {
                if (matchedUsers.contains(candidate.getId())) continue;
                if (candidate.getId().equals(user.getId())) continue;

                double score = calculateCompatibilityScore(user.getId(), candidate.getId());
                if (score > bestScore) {
                    bestScore = score;
                    bestMatch = candidate;
                }
            }

            if (bestMatch != null) {
                Match match = createMatch(user, bestMatch, thisFriday, bestScore);
                createdMatches.add(match);
                matchedUsers.add(user.getId());
                matchedUsers.add(bestMatch.getId());
                log.info("[MatchingService] Matched user {} with user {} (score: {})",
                        user.getId(), bestMatch.getId(), String.format("%.4f", bestScore));
            }
        }

        log.info("[MatchingService] Created {} matches", createdMatches.size());
    }

    public double calculateCompatibilityScore(Long userId1, Long userId2) {
        double traitSim = calculateTraitSimilarity(userId1, userId2);
        double semanticSim = embeddingService.calculateSemanticSimilarity(userId1, userId2);
        double prefMatch = calculatePreferenceMatch(userId1, userId2);
        double complementarity = calculateComplementarity(userId1, userId2);

        // 意向对象匹配度（双向平均）
        double idealPartnerScore = embeddingService.calculateIdealPartnerMatch(userId1, userId2);

        // 从双方偏好出发分别计算个性化分数，然后取平均
        Profile.MatchingPreference pref1 = getMatchingPreference(userId1);
        Profile.MatchingPreference pref2 = getMatchingPreference(userId2);

        double score1 = calculatePersonalizedScore(pref1, traitSim, semanticSim, prefMatch, complementarity);
        double score2 = calculatePersonalizedScore(pref2, traitSim, semanticSim, prefMatch, complementarity);

        double personalizedScore = (score1 + score2) / 2.0;

        // 最终分 = 个性化基础 * 0.8 + 意向匹配度 * 0.2
        double totalScore = personalizedScore * 0.8 + idealPartnerScore * 0.2;

        log.debug("[MatchingService] Score for {} vs {}: trait={}, semantic={}, pref={}, comp={}, ideal={}, total={}",
                userId1, userId2,
                String.format("%.4f", traitSim),
                String.format("%.4f", semanticSim),
                String.format("%.4f", prefMatch),
                String.format("%.4f", complementarity),
                String.format("%.4f", idealPartnerScore),
                String.format("%.4f", totalScore));

        return totalScore;
    }

    /**
     * 根据用户偏好调整特质相似度和互补性的权重。
     * SIMILAR = 提高特质相似度权重，降低互补权重
     * COMPLEMENTARY = 反之
     * BALANCED = 维持配置权重
     */
    private double calculatePersonalizedScore(Profile.MatchingPreference preference,
                                               double traitSim, double semanticSim,
                                               double prefMatch, double complementarity) {
        double traitW = traitSimilarityWeight;
        double complW = complementarityWeight;

        switch (preference) {
            case SIMILAR:
                traitW += 0.15;
                complW -= 0.15;
                break;
            case COMPLEMENTARY:
                traitW -= 0.15;
                complW += 0.15;
                break;
            case BALANCED:
            default:
                break;
        }

        // 归一化，确保四项之和为 1.0
        double total = traitW + semanticSimilarityWeight + preferenceMatchWeight + complW;
        traitW /= total;
        complW /= total;
        double semW = semanticSimilarityWeight / total;
        double prefW = preferenceMatchWeight / total;

        return traitSim * traitW + semanticSim * semW + prefMatch * prefW + complementarity * complW;
    }

    private Profile.MatchingPreference getMatchingPreference(Long userId) {
        return profileRepository.findByUserId(userId)
                .map(Profile::getMatchingPreference)
                .orElse(Profile.MatchingPreference.BALANCED);
    }

    private double calculateTraitSimilarity(Long userId1, Long userId2) {
        List<UserTrait> traits1 = userTraitRepository.findByProfileId(
                profileRepository.findByUserId(userId1).map(p -> p.getId()).orElse(-1L));
        List<UserTrait> traits2 = userTraitRepository.findByProfileId(
                profileRepository.findByUserId(userId2).map(p -> p.getId()).orElse(-1L));

        if (traits1.isEmpty() || traits2.isEmpty()) {
            return 0.5; // Neutral if no traits
        }

        Map<String, Double> traitMap1 = traits1.stream()
                .collect(Collectors.toMap(UserTrait::getTraitName, t -> t.getTraitValue().doubleValue()));
        Map<String, Double> traitMap2 = traits2.stream()
                .collect(Collectors.toMap(UserTrait::getTraitName, t -> t.getTraitValue().doubleValue()));

        Set<String> allTraits = new HashSet<>();
        allTraits.addAll(traitMap1.keySet());
        allTraits.addAll(traitMap2.keySet());

        double dotProduct = 0;
        double norm1 = 0;
        double norm2 = 0;

        for (String trait : allTraits) {
            double v1 = traitMap1.getOrDefault(trait, 0.5);
            double v2 = traitMap2.getOrDefault(trait, 0.5);

            dotProduct += v1 * v2;
            norm1 += v1 * v1;
            norm2 += v2 * v2;
        }

        if (norm1 == 0 || norm2 == 0) return 0.5;
        return dotProduct / (Math.sqrt(norm1) * Math.sqrt(norm2));
    }

    private double calculatePreferenceMatch(Long userId1, Long userId2) {
        Optional<Profile> profile1 = profileRepository.findByUserId(userId1);
        Optional<Profile> profile2 = profileRepository.findByUserId(userId2);

        if (profile1.isEmpty() || profile2.isEmpty()) {
            return 0.5;
        }

        double score = 0;
        int factors = 0;

        // Location match
        String loc1 = profile1.get().getLocation();
        String loc2 = profile2.get().getLocation();
        if (loc1 != null && loc2 != null && !loc1.isEmpty() && !loc2.isEmpty()) {
            factors++;
            score += loc1.equalsIgnoreCase(loc2) ? 1.0 : 0.3;
        }

        // Age match (check if both are in each other's acceptable ranges)
        Integer age1 = profile1.get().getAge();
        Integer age2 = profile2.get().getAge();
        if (age1 != null && age2 != null) {
            factors++;
            int ageDiff = Math.abs(age1 - age2);
            score += ageDiff <= 5 ? 1.0 : ageDiff <= 10 ? 0.7 : 0.3;
        }

        return factors > 0 ? score / factors : 0.5;
    }

    private double calculateComplementarity(Long userId1, Long userId2) {
        List<UserTrait> traits1 = userTraitRepository.findByProfileId(
                profileRepository.findByUserId(userId1).map(p -> p.getId()).orElse(-1L));
        List<UserTrait> traits2 = userTraitRepository.findByProfileId(
                profileRepository.findByUserId(userId2).map(p -> p.getId()).orElse(-1L));

        if (traits1.isEmpty() || traits2.isEmpty()) {
            return 0.5;
        }

        Map<String, Double> traitMap1 = traits1.stream()
                .collect(Collectors.toMap(UserTrait::getTraitName, t -> t.getTraitValue().doubleValue()));
        Map<String, Double> traitMap2 = traits2.stream()
                .collect(Collectors.toMap(UserTrait::getTraitName, t -> t.getTraitValue().doubleValue()));

        double complementarityScore = 0;
        int complementCount = 0;

        // Complementary trait pairs
        String[][] complementaryPairs = {
                {"extroversion", "introversion"},
                {"socialness", "introversion"},
                {"adventurousness", "stability_seeking"},
                {"activity_level", "relaxed"},
                {"spontaneous", "structured"}
        };

        for (String[] pair : complementaryPairs) {
            Double v1 = traitMap1.get(pair[0]);
            Double v2 = traitMap2.get(pair[0]);
            Double v2Alt = traitMap2.get(pair[1]);

            if (v1 != null && v2 != null) {
                complementCount++;
                // If one is high and other is also high, it's not complementary
                // Complementary = one high, one lower
                double product = v1 * v2;
                complementarityScore += product < 0.3 ? 1.0 : product < 0.6 ? 0.5 : 0.2;
            }

            if (v1 != null && v2Alt != null) {
                complementCount++;
                double product = v1 * v2Alt;
                complementarityScore += product > 0.3 && product < 0.7 ? 1.0 : 0.3;
            }
        }

        return complementCount > 0 ? complementarityScore / complementCount : 0.5;
    }

    @Transactional
    public Match createMatch(User user1, User user2, LocalDate matchWeek, double score) {
        Match match = new Match();
        match.setUser1Id(user1.getId());
        match.setUser2Id(user2.getId());
        match.setMatchWeek(matchWeek);
        match.setCompatibilityScore(BigDecimal.valueOf(score));
        match.setStatus(Match.MatchStatus.PENDING);

        return matchRepository.save(match);
    }

    public Optional<Match> getCurrentMatch(Long userId) {
        LocalDate thisFriday = getThisFriday();
        return matchRepository.findByUser1IdOrUser2IdAndMatchWeek(userId, userId, thisFriday);
    }

    public List<Match> getMatchHistory(Long userId) {
        return matchRepository.findByUser1IdOrUser2IdOrderByMatchWeekDesc(userId, userId);
    }

    private LocalDate getThisFriday() {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        int daysUntilFriday = DayOfWeek.FRIDAY.getValue() - today.getDayOfWeek().getValue();
        if (daysUntilFriday < 0) daysUntilFriday += 7;
        return today.plusDays(daysUntilFriday);
    }
}
