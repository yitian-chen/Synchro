package io.github.yitianchen.synchro.service;

import io.github.yitianchen.synchro.model.Message;
import io.github.yitianchen.synchro.model.UserTrait;
import io.github.yitianchen.synchro.repository.ProfileRepository;
import io.github.yitianchen.synchro.repository.UserTraitRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Slf4j
@Service
@RequiredArgsConstructor
public class TraitExtractionService {

    private final UserTraitRepository userTraitRepository;
    private final ProfileRepository profileRepository;
    private final AiService aiService;
    private final ObjectMapper objectMapper;

    @Transactional
    public List<UserTrait> extractAndSaveTraits(Long userId, List<Message> conversationHistory) {
        log.info("[TraitExtractionService] extractAndSaveTraits for userId: {}", userId);

        StringBuilder userContent = new StringBuilder();
        for (Message msg : conversationHistory) {
            if (msg.getSenderType() == Message.SenderType.USER) {
                userContent.append(msg.getContent()).append("\n");
            }
        }

        String prompt = """
                Extract personality traits, interests, and preferences from the following user description.
                Return a JSON array of traits with name, value (0.0-1.0), and confidence (0.0-1.0).

                Traits to extract:
                - extroversion (1.0=very extroverted, 0.0=very introverted)
                - openness (1.0=very open to new experiences)
                - agreeableness (1.0=very agreeable)
                - adventurousness (1.0=very adventurous)
                - socialness (1.0=very social)
                - activity_level (1.0=very active)
                - romantic (1.0=very romantic)
                - family_oriented (1.0=family oriented)
                - career_oriented (1.0=career oriented)
                - creative (1.0=very creative)
                - intellectual (1.0=very intellectual)

                User description:
                %s

                Return ONLY a JSON array, no other text. Example: [{"name":"extroversion","value":0.7,"confidence":0.9}]
                """.formatted(userContent);

        String aiResponse = aiService.chat(prompt, List.of());

        List<UserTrait> extractedTraits = parseTraits(aiResponse, conversationHistory);

        Long profileId = profileRepository.findByUserId(userId)
                .map(p -> p.getId())
                .orElse(null);

        if (profileId != null) {
            userTraitRepository.deleteByProfileId(profileId);

            for (UserTrait trait : extractedTraits) {
                trait.setProfileId(profileId);
                trait.setSourceMessageId(conversationHistory.get(conversationHistory.size() - 1).getId());
                userTraitRepository.save(trait);
            }
        }

        log.info("[TraitExtractionService] extracted {} traits", extractedTraits.size());
        return extractedTraits;
    }

    private List<UserTrait> parseTraits(String aiResponse, List<Message> history) {
        List<UserTrait> traits = new ArrayList<>();

        try {
            String jsonContent = extractJsonArray(aiResponse);
            List<Map> traitList = objectMapper.readValue(jsonContent,
                    objectMapper.getTypeFactory().constructCollectionType(List.class, Map.class));

            for (Map traitMap : traitList) {
                UserTrait trait = new UserTrait();
                trait.setTraitName((String) traitMap.get("name"));
                Object value = traitMap.get("value");
                trait.setTraitValue(value instanceof Number ? BigDecimal.valueOf(((Number) value).doubleValue()) : BigDecimal.ZERO);
                Object confidence = traitMap.get("confidence");
                trait.setConfidence(confidence instanceof Number ? BigDecimal.valueOf(((Number) confidence).doubleValue()) : BigDecimal.ONE);
                traits.add(trait);
            }
        } catch (Exception e) {
            log.warn("[TraitExtractionService] failed to parse traits from AI response: {}", e.getMessage());
            extractTraitsFromKeywords(userContentFromHistory(history), traits);
        }

        return traits;
    }

    private void extractTraitsFromKeywords(String content, List<UserTrait> traits) {
        content = content.toLowerCase();

        addTraitIfPresent(traits, "extroversion", content, List.of("outgoing", "social", "party", "talkative", "energetic"), 0.7);
        addTraitIfPresent(traits, "introversion", content, List.of("introvert", "quiet", "reserved", "solitary", "private"), 0.7);
        addTraitIfPresent(traits, "adventurousness", content, List.of("adventure", "travel", "explore", "hiking", "adventurous"), 0.7);
        addTraitIfPresent(traits, "activity_level", content, List.of("active", "sport", "gym", "exercise", "athletic"), 0.7);
        addTraitIfPresent(traits, "creative", content, List.of("creative", "art", "music", "writing", "artistic"), 0.7);
        addTraitIfPresent(traits, "intellectual", content, List.of("book", "reading", "intellectual", "learning", "philosophy"), 0.7);
    }

    private void addTraitIfPresent(List<UserTrait> traits, String traitName, String content, List<String> keywords, double baseValue) {
        for (String keyword : keywords) {
            if (content.contains(keyword)) {
                UserTrait trait = new UserTrait();
                trait.setTraitName(traitName);
                trait.setTraitValue(BigDecimal.valueOf(baseValue));
                trait.setConfidence(BigDecimal.valueOf(0.5));
                traits.add(trait);
                return;
            }
        }
    }

    private String extractJsonArray(String text) {
        Pattern pattern = Pattern.compile("\\[.*\\]", Pattern.DOTALL);
        Matcher matcher = pattern.matcher(text);
        if (matcher.find()) {
            return matcher.group();
        }
        return "[]";
    }

    private String userContentFromHistory(List<Message> history) {
        StringBuilder sb = new StringBuilder();
        for (Message msg : history) {
            if (msg.getSenderType() == Message.SenderType.USER) {
                sb.append(msg.getContent()).append(" ");
            }
        }
        return sb.toString();
    }
}
