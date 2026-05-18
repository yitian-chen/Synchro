package io.github.yitianchen.synchro.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.model.chat.ChatModel;
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
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class RagService {

    private final ChatModel chatModel;
    private final ObjectMapper objectMapper;
    private final EmbeddingService embeddingService;
    private final IcebreakerKnowledgeBase icebreakerKnowledgeBase;
    private final MatchRepository matchRepository;
    private final ProfileRepository profileRepository;
    private final UserRepository userRepository;
    private final UserTraitRepository userTraitRepository;

    private static final Set<String> ICEBREAKER_KEYWORDS = Set.of(
            "破冰", "开场", "话题", "怎么开始", "如何开始", "说什么", "聊什么",
            "怎么聊", "如何聊", "聊天", "第一句", "打招呼", "搭讪", "冷场",
            "开启对话", "怎么开口", "聊些", "什么话题"
    );

    /**
     * Answer a user's question about a specific match using RAG.
     */
    public String answerMatchQuestion(Long userId, Long matchId, String question) {
        log.info("[RagService] Question about match {}: {}", matchId, question);

        Match match = matchRepository.findById(matchId)
                .orElseThrow(() -> new IllegalArgumentException("Match not found: " + matchId));

        Long otherUserId = match.getUser1Id().equals(userId) ? match.getUser2Id() : match.getUser1Id();

        // 1. Build match context
        String matchContext = buildMatchContext(match, userId, otherUserId);

        // 2. Retrieve icebreaker tips if question is about conversation
        List<String> icebreakerTips = List.of();
        if (isIcebreakerQuestion(question)) {
            icebreakerTips = icebreakerKnowledgeBase.retrieve(question, 3).stream()
                    .map(EmbeddingService.DocEntry::text)
                    .toList();
            log.info("[RagService] Retrieved {} icebreaker tips", icebreakerTips.size());
        }

        // 3. Build system prompt
        String systemPrompt = buildRagSystemPrompt(matchContext, icebreakerTips);

        // 4. Call LLM
        log.info("[RagService] Calling LLM with system prompt length: {}", systemPrompt.length());
        var response = chatModel.chat(List.of(
                SystemMessage.from(systemPrompt),
                UserMessage.from(question)
        ));
        String answer = response.aiMessage().text();
        log.info("[RagService] Answer length: {}", answer != null ? answer.length() : 0);

        return answer != null ? answer : "抱歉，暂时无法生成回答，请稍后再试。";
    }

    private String buildMatchContext(Match match, Long askerUserId, Long otherUserId) {
        User asker = userRepository.findById(askerUserId).orElse(null);
        User other = userRepository.findById(otherUserId).orElse(null);
        Profile askerProfile = profileRepository.findByUserId(askerUserId).orElse(null);
        Profile otherProfile = profileRepository.findByUserId(otherUserId).orElse(null);
        List<UserTrait> askerTraits = askerProfile != null
                ? userTraitRepository.findByProfileId(askerProfile.getId()) : List.of();
        List<UserTrait> otherTraits = otherProfile != null
                ? userTraitRepository.findByProfileId(otherProfile.getId()) : List.of();

        StringBuilder ctx = new StringBuilder();

        // Match scores
        ctx.append("## 匹配评分\n");
        ctx.append("综合匹配分: ").append(String.format("%.2f%%", match.getCompatibilityScore().doubleValue() * 100)).append("\n");
        if (match.getMatchReason() != null) {
            try {
                var reason = objectMapper.readTree(match.getMatchReason());
                ctx.append("- 特质相似度: ").append(formatPercent(reason, "traitSimilarity")).append("\n");
                ctx.append("- 语义相似度: ").append(formatPercent(reason, "semanticSimilarity")).append("\n");
                ctx.append("- 偏好匹配度: ").append(formatPercent(reason, "preferenceMatch")).append("\n");
                ctx.append("- 互补性得分: ").append(formatPercent(reason, "complementarity")).append("\n");
                ctx.append("- 意向匹配度: ").append(formatPercent(reason, "idealPartnerMatch")).append("\n");
            } catch (Exception e) {
                log.warn("[RagService] Failed to parse matchReason", e);
            }
        }

        // User profiles
        ctx.append("\n## 用户信息\n");
        appendUserInfo(ctx, "你", asker, askerProfile);
        ctx.append("\n");
        appendUserInfo(ctx, "对方", other, otherProfile);

        // Traits
        ctx.append("\n## 特质对比\n");
        if (!askerTraits.isEmpty() || !otherTraits.isEmpty()) {
            Map<String, Double> askerMap = toTraitMap(askerTraits);
            Map<String, Double> otherMap = toTraitMap(otherTraits);
            Set<String> allNames = new TreeSet<>();
            allNames.addAll(askerMap.keySet());
            allNames.addAll(otherMap.keySet());

            // Shared and complementary traits
            List<String> sharedTraits = new ArrayList<>();
            List<String> complementaryPairs = new ArrayList<>();

            for (String name : allNames) {
                Double av = askerMap.getOrDefault(name, 0.5);
                Double ov = otherMap.getOrDefault(name, 0.5);
                ctx.append(String.format("- %s: 你=%.2f  对方=%.2f\n", traitLabel(name), av, ov));

                if (Math.abs(av - ov) < 0.25) {
                    sharedTraits.add(traitLabel(name));
                }
                if (Math.abs(av - ov) > 0.4) {
                    complementaryPairs.add(traitLabel(name) + "(你" + (av > ov ? "高" : "低") + "/对方" + (ov > av ? "高" : "低") + ")");
                }
            }

            if (!sharedTraits.isEmpty()) {
                ctx.append("\n**共享特质**: ").append(String.join("、", sharedTraits)).append("\n");
            }
            if (!complementaryPairs.isEmpty()) {
                ctx.append("**互补特质**: ").append(String.join("、", complementaryPairs)).append("\n");
            }
        }

        return ctx.toString();
    }

    private void appendUserInfo(StringBuilder ctx, String label, User user, Profile profile) {
        ctx.append(label).append(": ");
        if (user != null) ctx.append(user.getNickname());
        if (profile != null) {
            if (profile.getAge() != null) ctx.append("，").append(profile.getAge()).append("岁");
            if (profile.getGender() != null) {
                String gender = switch (profile.getGender()) {
                    case MALE -> "男";
                    case FEMALE -> "女";
                    case OTHER -> "其他";
                };
                ctx.append("，").append(gender);
            }
            if (profile.getLocation() != null) ctx.append("，").append(profile.getLocation());
        }
        ctx.append("\n");
        if (profile != null && profile.getBio() != null && !profile.getBio().isBlank()) {
            ctx.append("  自我介绍: ").append(profile.getBio()).append("\n");
        }
        if (profile != null && profile.getIdealPartnerDescription() != null && !profile.getIdealPartnerDescription().isBlank()) {
            ctx.append("  理想伴侣: ").append(profile.getIdealPartnerDescription()).append("\n");
        }
    }

    private Map<String, Double> toTraitMap(List<UserTrait> traits) {
        return traits.stream()
                .collect(Collectors.toMap(UserTrait::getTraitName, t -> t.getTraitValue().doubleValue(), (a, b) -> a));
    }

    private String traitLabel(String name) {
        return switch (name) {
            case "extroversion" -> "外向性";
            case "openness" -> "开放性";
            case "agreeableness" -> "宜人性";
            case "adventurousness" -> "冒险性";
            case "socialness" -> "社交性";
            case "activity_level" -> "活跃度";
            case "romantic" -> "浪漫度";
            case "family_oriented" -> "家庭导向";
            case "career_oriented" -> "事业导向";
            case "creative" -> "创造力";
            case "intellectual" -> "智力追求";
            case "emotional_expressiveness" -> "情感表达";
            case "conflict_avoidant" -> "回避冲突";
            case "independence" -> "独立性";
            case "partner_extroversion_pref" -> "偏好外向";
            case "partner_adventurous_pref" -> "偏好冒险";
            case "partner_social_pref" -> "偏好社交";
            case "importance_appearance" -> "看重外表";
            case "importance_values" -> "看重价值观";
            case "importance_intelligence" -> "看重才智";
            case "openness_to_distance" -> "接受异地";
            case "long_term_goal" -> "长期目标";
            default -> name;
        };
    }

    private boolean isIcebreakerQuestion(String question) {
        return ICEBREAKER_KEYWORDS.stream().anyMatch(question::contains);
    }

    private String formatPercent(com.fasterxml.jackson.databind.JsonNode node, String field) {
        if (node.has(field)) {
            return String.format("%.1f%%", node.get(field).asDouble() * 100);
        }
        return "N/A";
    }

    private String buildRagSystemPrompt(String matchContext, List<String> icebreakerTips) {
        StringBuilder prompt = new StringBuilder();
        prompt.append("你是 Synchro 的 AI 匹配顾问。你拥有匹配算法产生的详细数据，你的任务是根据这些数据回答用户关于匹配结果的问题。\n\n");
        prompt.append("回答要求：\n");
        prompt.append("- 用自然、热情、像朋友聊天的语气回答\n");
        prompt.append("- 引用匹配数据中的具体数字和特质来说明原因\n");
        prompt.append("- 回答要具体、个性化，不要泛泛而谈\n");
        prompt.append("- 保护用户隐私，不要透露对方的年龄、所在地等具体个人信息\n");
        prompt.append("- 用中文回答，控制在200字以内\n\n");

        if (!icebreakerTips.isEmpty()) {
            prompt.append("## 破冰话题参考\n");
            for (int i = 0; i < icebreakerTips.size(); i++) {
                prompt.append(i + 1).append(". ").append(icebreakerTips.get(i)).append("\n");
            }
            prompt.append("\n");
        }

        prompt.append(matchContext);

        return prompt.toString();
    }
}
