package io.github.yitianchen.synchro.service;

import io.github.yitianchen.synchro.model.Message;
import io.github.yitianchen.synchro.model.Profile;
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
                从以下用户对话描述中提取全面的性格特质、兴趣爱好和择偶偏好。
                返回 JSON 数组，每项包含 name、value (0.0-1.0)、confidence (0.0-1.0)。

                用户性格特质：
                - extroversion (1.0=非常外向, 0.0=非常内向)
                - openness (1.0=非常开放, 0.0=传统保守)
                - agreeableness (1.0=非常友善, 0.0=较难相处)
                - adventurousness (1.0=热爱冒险, 0.0=偏好安稳)
                - socialness (1.0=社交达人, 0.0=偏好独处)
                - activity_level (1.0=精力充沛, 0.0=安静慵懒)
                - romantic (1.0=浪漫主义者, 0.0=务实理性)
                - family_oriented (1.0=家庭为重, 0.0=事业为先)
                - career_oriented (1.0=事业心强, 0.0=随遇而安)
                - creative (1.0=富有创意, 0.0=脚踏实地)
                - intellectual (1.0=爱好思考, 0.0=行动派)
                - emotional_expressiveness (1.0=情感外露, 0.0=内敛沉稳)
                - conflict_avoidant (1.0=回避冲突, 0.0=直面矛盾)
                - independence (1.0=高度独立, 0.0=依赖陪伴)

                择偶偏好（影响匹配，value 表示偏好强度）：
                - partner_extroversion_pref (1.0=希望对方很外向, 0.5=无所谓, 0.0=希望对方内向)
                - partner_adventurous_pref (1.0=希望对方爱冒险, 0.5=无所谓, 0.0=希望对方安稳)
                - partner_social_pref (1.0=希望对方社交多, 0.5=无所谓, 0.0=希望对方宅)
                - importance_appearance (1.0=外表非常重要, 0.0=外表无所谓)
                - importance_values (1.0=价值观契合非常重要, 0.0=不那么重要)
                - importance_intelligence (1.0=智商/才华很重要, 0.0=不那么重要)
                - openness_to_distance (1.0=能接受异地, 0.0=完全不接受)
                - long_term_goal (1.0=以结婚为目标, 0.5=认真谈恋爱, 0.0=先慢慢了解)

                用户对话内容：
                %s

                只返回 JSON 数组，不要其他文字。示例：[{"name":"extroversion","value":0.7,"confidence":0.9}]
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

            // 更新 profile.traitsSummary，供前端 Dashboard 展示
            try {
                List<Map<String, Object>> summaryList = extractedTraits.stream()
                        .map(t -> Map.<String, Object>of(
                                "name", t.getTraitName(),
                                "value", t.getTraitValue().doubleValue(),
                                "confidence", t.getConfidence().doubleValue()))
                        .toList();
                String summaryJson = objectMapper.writeValueAsString(summaryList);
                profileRepository.findByUserId(userId).ifPresent(profile -> {
                    profile.setTraitsSummary(summaryJson);
                    profileRepository.save(profile);
                });
                log.info("[TraitExtractionService] traitsSummary updated for userId: {}", userId);
            } catch (Exception e) {
                log.warn("[TraitExtractionService] failed to serialize traitsSummary: {}", e.getMessage());
            }
        }

        log.info("[TraitExtractionService] extracted {} traits", extractedTraits.size());
        return extractedTraits;
    }

    @Transactional
    public void updateTraitsSummary(Long userId) {
        profileRepository.findByUserId(userId).ifPresent(profile -> {
            List<UserTrait> traits = userTraitRepository.findByProfileId(profile.getId());
            try {
                List<Map<String, Object>> summaryList = traits.stream()
                        .map(t -> Map.<String, Object>of(
                                "name", t.getTraitName(),
                                "value", t.getTraitValue().doubleValue(),
                                "confidence", t.getConfidence().doubleValue()))
                        .toList();
                String summaryJson = objectMapper.writeValueAsString(summaryList);
                profile.setTraitsSummary(summaryJson);
                profileRepository.save(profile);
                log.info("[TraitExtractionService] updateTraitsSummary userId={} traitCount={}", userId, traits.size());
            } catch (Exception e) {
                log.warn("[TraitExtractionService] failed to serialize traitsSummary: {}", e.getMessage());
            }
        });
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
