package io.github.yitianchen.synchro.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import dev.langchain4j.agent.tool.ToolSpecification;
import dev.langchain4j.agent.tool.ToolSpecifications;
import dev.langchain4j.data.message.AiMessage;
import dev.langchain4j.data.message.ChatMessage;
import io.github.yitianchen.synchro.dto.request.OnboardingMessageRequest;
import io.github.yitianchen.synchro.dto.response.OnboardingResponse;
import io.github.yitianchen.synchro.model.Conversation;
import io.github.yitianchen.synchro.model.Message;
import io.github.yitianchen.synchro.model.Profile;
import io.github.yitianchen.synchro.model.User;
import io.github.yitianchen.synchro.model.UserTrait;
import io.github.yitianchen.synchro.repository.CityRepository;
import io.github.yitianchen.synchro.repository.ConversationRepository;
import io.github.yitianchen.synchro.repository.MessageRepository;
import io.github.yitianchen.synchro.repository.ProfileRepository;
import io.github.yitianchen.synchro.repository.UserRepository;
import io.github.yitianchen.synchro.repository.UserTraitRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class OnboardingService {

    private final UserRepository userRepository;
    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final ProfileRepository profileRepository;
    private final UserTraitRepository userTraitRepository;
    private final CityRepository cityRepository;
    private final AiService aiService;
    private final TraitExtractionService traitExtractionService;
    private final ObjectMapper objectMapper;
    private final RedisTemplate<String, Object> redisTemplate;

    private static final int MAX_EXCHANGES_BEFORE_SUMMARY = 8;

    private static final List<String> ALL_TOPICS = List.of(
            "hobbies_lifestyle", "personality_emotion", "social_preferences",
            "partner_preferences", "values_life_goals", "emotional_needs_communication"
    );

    // ── Start / Status ──

    @Transactional
    public OnboardingResponse startOnboarding(Long userId) {
        log.info("[OnboardingService] startOnboarding - userId: {}", userId);

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        List<Conversation> conversations = conversationRepository.findByUserIdAndConversationType(userId, Conversation.ConversationType.ONBOARDING);
        Conversation conversation = conversations.stream()
                .filter(c -> c.getStatus() == Conversation.ConversationStatus.ACTIVE)
                .findFirst()
                .orElseGet(() -> {
                    Conversation existingActive = conversations.stream()
                            .filter(c -> c.getStatus() == Conversation.ConversationStatus.ACTIVE)
                            .findFirst()
                            .orElse(null);
                    if (existingActive != null) {
                        return existingActive;
                    }
                    if (user.getStatus() != User.UserStatus.PENDING_ONBOARDING) {
                        throw new IllegalStateException("Onboarding not available. Please contact support.");
                    }
                    conversations.stream()
                            .filter(c -> c.getStatus() != Conversation.ConversationStatus.ACTIVE)
                            .forEach(conv -> {
                                conv.setStatus(Conversation.ConversationStatus.ARCHIVED);
                                conversationRepository.save(conv);
                            });
                    Conversation newConv = new Conversation();
                    newConv.setUserId(userId);
                    newConv.setConversationType(Conversation.ConversationType.ONBOARDING);
                    newConv.setTitle("AI Onboarding Interview");
                    return conversationRepository.save(newConv);
                });

        List<Message> existingMessages = messageRepository.findByConversationIdOrderByCreatedAtAsc(conversation.getId());

        if (existingMessages.isEmpty()) {
            Profile profile = getOrCreateProfile(userId);
            String systemPrompt = buildDynamicSystemPrompt(userId, profile.getId(), false);

            OnboardingTools tools = new OnboardingTools(
                    userId, profile.getId(), null,
                    profileRepository, userTraitRepository, cityRepository, redisTemplate);

            List<ToolSpecification> specs = ToolSpecifications.toolSpecificationsFrom(tools);
            List<ChatMessage> messages = aiService.buildStructuredMessages(systemPrompt, List.of(), "Hello");

            String welcomeMessage;
            try {
                AiMessage aiResponse = aiService.chatWithTools(messages, specs, tools);
                welcomeMessage = aiResponse.text() != null ? aiResponse.text() : "";
                if (welcomeMessage.isBlank()) {
                    // LLM only made tool calls but returned no text — fall back
                    throw new IllegalStateException("Empty welcome from AI");
                }
            } catch (Exception e) {
                log.error("[OnboardingService] AI chat failed to generate welcome: {}", e.getMessage());
                welcomeMessage = "Hey there! 我是 Synchro 的交友助手，很高兴认识你！让我们开始聊聊吧——先介绍一下你自己？";
            }

            Message aiMessage = new Message();
            aiMessage.setConversationId(conversation.getId());
            aiMessage.setSenderId(-1L);
            aiMessage.setSenderType(Message.SenderType.AI);
            aiMessage.setContent(welcomeMessage);
            messageRepository.save(aiMessage);
            existingMessages = List.of(aiMessage);
        }

        return buildOnboardingResponse(conversation, existingMessages);
    }

    public OnboardingResponse getOnboardingStatus(Long userId) {
        List<Conversation> conversations = conversationRepository.findByUserIdAndConversationType(userId, Conversation.ConversationType.ONBOARDING);
        Conversation conversation = conversations.stream()
                .filter(c -> c.getStatus() == Conversation.ConversationStatus.ACTIVE)
                .findFirst()
                .orElse(null);

        if (conversation == null) {
            return OnboardingResponse.builder()
                    .isComplete(false)
                    .exchangeCount(0)
                    .messages(List.of())
                    .build();
        }

        List<Message> messages = messageRepository.findByConversationIdOrderByCreatedAtAsc(conversation.getId());
        return buildOnboardingResponse(conversation, messages);
    }

    // ── Send message ──

    @Transactional
    public OnboardingResponse sendMessage(Long userId, OnboardingMessageRequest request) {
        log.info("[OnboardingService] sendMessage - userId: {}, content: {}", userId, sanitizeForDebug(request.getContent()));

        List<Conversation> conversations = conversationRepository.findByUserIdAndConversationType(userId, Conversation.ConversationType.ONBOARDING);
        Conversation conversation = conversations.stream()
                .filter(c -> c.getStatus() == Conversation.ConversationStatus.ACTIVE)
                .findFirst()
                .orElse(null);

        if (conversation == null) {
            log.error("[OnboardingService] sendMessage - no ACTIVE conversation for userId: {}", userId);
            throw new IllegalStateException("No active onboarding conversation. Please start onboarding first.");
        }

        conversations.stream()
                .filter(c -> c.getId() != conversation.getId() && c.getStatus() != Conversation.ConversationStatus.ARCHIVED)
                .forEach(c -> {
                    c.setStatus(Conversation.ConversationStatus.ARCHIVED);
                    conversationRepository.save(c);
                });

        // 1. Save user message
        Message userMessage = new Message();
        userMessage.setConversationId(conversation.getId());
        userMessage.setSenderId(userId);
        userMessage.setSenderType(Message.SenderType.USER);
        userMessage.setContent(request.getContent());
        messageRepository.save(userMessage);

        // 2. Load history (including the just-saved user message)
        List<Message> history = new ArrayList<>(messageRepository.findByConversationIdOrderByCreatedAtAsc(conversation.getId()));

        // 3. Get or create profile
        Profile profile = getOrCreateProfile(userId);

        // 4. Check if last round
        boolean isLastRound = history.size() / 2 >= MAX_EXCHANGES_BEFORE_SUMMARY;

        // 5. Snapshot traits before this turn (for extractedTraits diff)
        List<String> traitsBefore = userTraitRepository.findByProfileId(profile.getId())
                .stream().map(UserTrait::getTraitName).collect(Collectors.toList());

        // 6. Build dynamic system prompt
        String systemPrompt = buildDynamicSystemPrompt(userId, profile.getId(), isLastRound);

        // 7. Build structured messages (exclude current user msg from db history, pass separately)
        //    dbMessages should exclude the just-saved user message — it goes as currentUserMessage
        List<Message> dbMessagesExcludingCurrent = history.subList(0, history.size() - 1);
        List<ChatMessage> messages = aiService.buildStructuredMessages(
                systemPrompt, dbMessagesExcludingCurrent, request.getContent());

        // 8. Create tools + specs
        OnboardingTools tools = new OnboardingTools(
                userId, profile.getId(), userMessage.getId(),
                profileRepository, userTraitRepository, cityRepository, redisTemplate);

        List<ToolSpecification> specs = ToolSpecifications.toolSpecificationsFrom(tools);

        // 9. Call AI with tool calling
        String aiResponseText;
        try {
            AiMessage aiMessage = aiService.chatWithTools(messages, specs, tools);
            aiResponseText = aiMessage.text();
            if (aiResponseText == null) aiResponseText = "";
        } catch (Throwable t) {
            log.error("[OnboardingService] AI chat failed: {}", t.getMessage(), t);
            throw new IllegalStateException("AI service unavailable, please try again later: " + t.getMessage());
        }

        // 10. Compute extractedTraits diff
        List<String> traitsAfter = userTraitRepository.findByProfileId(profile.getId())
                .stream().map(UserTrait::getTraitName).collect(Collectors.toList());
        List<String> newTraits = new ArrayList<>(traitsAfter);
        newTraits.removeAll(traitsBefore);

        // 11. Save AI message with extractedTraits in metadata
        Message aiMessage = new Message();
        aiMessage.setConversationId(conversation.getId());
        aiMessage.setSenderId(-1L);
        aiMessage.setSenderType(Message.SenderType.AI);
        aiMessage.setContent(aiResponseText);
        if (!newTraits.isEmpty()) {
            try {
                aiMessage.setMetadata(objectMapper.writeValueAsString(
                        Map.of("extractedTraits", newTraits)));
            } catch (Exception e) {
                log.warn("[OnboardingService] failed to serialize extractedTraits: {}", e.getMessage());
            }
        }
        messageRepository.save(aiMessage);

        // 12. Check completion
        history.add(aiMessage);
        boolean shouldComplete = history.size() / 2 >= MAX_EXCHANGES_BEFORE_SUMMARY;
        if (shouldComplete) {
            return completeOnboarding(userId, conversation, history);
        }

        return buildOnboardingResponse(conversation, history);
    }

    // ── Complete / Reset ──

    @Transactional
    public OnboardingResponse completeOnboardingManually(Long userId) {
        Conversation conversation = conversationRepository
                .findByUserIdAndConversationTypeAndStatus(userId, Conversation.ConversationType.ONBOARDING, Conversation.ConversationStatus.ACTIVE)
                .orElseThrow(() -> new IllegalStateException("No active onboarding conversation"));

        List<Message> history = new ArrayList<>(messageRepository.findByConversationIdOrderByCreatedAtAsc(conversation.getId()));
        return completeOnboarding(userId, conversation, history);
    }

    private OnboardingResponse completeOnboarding(Long userId, Conversation conversation, List<Message> history) {
        log.info("[OnboardingService] completing onboarding for userId: {}", userId);

        // Fallback: batch trait extraction if incremental missed many traits
        Profile profile = getOrCreateProfile(userId);
        long existingTraitCount = userTraitRepository.findByProfileId(profile.getId()).size();
        if (existingTraitCount < 15) {
            log.info("[OnboardingService] incremental traits: {} < 15, running batch fallback", existingTraitCount);
            traitExtractionService.extractAndSaveTraits(userId, history);
        } else {
            log.info("[OnboardingService] incremental traits: {} >= 15, skipping batch extraction, updating summary", existingTraitCount);
            traitExtractionService.updateTraitsSummary(userId);
        }

        // Clean up Redis topic tracking
        redisTemplate.delete("onboarding:topics:" + userId);

        conversation.setStatus(Conversation.ConversationStatus.COMPLETED);
        conversationRepository.save(conversation);

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
        user.setStatus(User.UserStatus.ACTIVE);
        user.setOnboardingCompleted(true);
        userRepository.save(user);

        OnboardingResponse response = buildOnboardingResponse(conversation, history);
        response.setRedirectUrl("/dashboard");
        return response;
    }

    @Transactional
    public void resetOnboarding(Long userId) {
        log.info("[OnboardingService] resetOnboarding - userId: {}", userId);

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        if (user.getStatus() != User.UserStatus.ACTIVE) {
            throw new IllegalStateException("Onboarding is not completed, cannot reset");
        }

        user.setStatus(User.UserStatus.PENDING_ONBOARDING);
        user.setOnboardingCompleted(false);
        userRepository.save(user);

        Profile profile = profileRepository.findByUserId(userId).orElse(null);
        if (profile != null) {
            userTraitRepository.deleteByProfileId(profile.getId());
            profile.setTraitsSummary(null);
            profileRepository.save(profile);
        }

        conversationRepository
                .findByUserIdAndConversationTypeAndStatus(userId, Conversation.ConversationType.ONBOARDING, Conversation.ConversationStatus.COMPLETED)
                .ifPresent(conv -> {
                    conv.setStatus(Conversation.ConversationStatus.ARCHIVED);
                    conversationRepository.save(conv);
                });

        conversationRepository
                .findByUserIdAndConversationTypeAndStatus(userId, Conversation.ConversationType.ONBOARDING, Conversation.ConversationStatus.ACTIVE)
                .ifPresent(conv -> {
                    conv.setStatus(Conversation.ConversationStatus.ARCHIVED);
                    conversationRepository.save(conv);
                });

        // Clean up Redis topic tracking
        redisTemplate.delete("onboarding:topics:" + userId);

        log.info("[OnboardingService] resetOnboarding completed for userId: {}", userId);
    }

    // ── Dynamic System Prompt ──

    private String buildDynamicSystemPrompt(Long userId, Long profileId, boolean isLastRound) {
        // Read covered topics from Redis
        Set<Object> rawTopics = redisTemplate.opsForSet().members("onboarding:topics:" + userId);
        Set<String> coveredTopics = rawTopics != null
                ? rawTopics.stream().map(Object::toString).collect(Collectors.toSet())
                : Set.of();

        // Read existing traits
        List<UserTrait> existingTraits = userTraitRepository.findByProfileId(profileId);
        List<String> personalityTraits = new ArrayList<>();
        List<String> partnerPrefs = new ArrayList<>();
        for (UserTrait t : existingTraits) {
            if (t.getTraitName().startsWith("partner_")) {
                partnerPrefs.add(t.getTraitName() + "=" + t.getTraitValue());
            } else {
                personalityTraits.add(t.getTraitName() + "=" + t.getTraitValue());
            }
        }

        // Read existing profile fields
        Profile profile = profileRepository.findById(profileId).orElse(null);
        List<String> filledFields = new ArrayList<>();
        List<String> unfilledFields = new ArrayList<>();

        for (String field : List.of("age", "gender", "location", "bio", "idealPartnerDescription")) {
            boolean filled = switch (field) {
                case "age" -> profile != null && profile.getAge() != null;
                case "gender" -> profile != null && profile.getGender() != null;
                case "location" -> profile != null && profile.getLocation() != null && !profile.getLocation().isBlank();
                case "bio" -> profile != null && profile.getBio() != null && !profile.getBio().isBlank();
                case "idealPartnerDescription" -> profile != null && profile.getIdealPartnerDescription() != null && !profile.getIdealPartnerDescription().isBlank();
                default -> false;
            };
            if (filled) filledFields.add(field);
            else unfilledFields.add(field);
        }

        // Build topic status lines
        StringBuilder topicLines = new StringBuilder();
        for (String topic : ALL_TOPICS) {
            String label = switch (topic) {
                case "hobbies_lifestyle" -> "兴趣爱好与生活方式";
                case "personality_emotion" -> "性格与情感";
                case "social_preferences" -> "社交与交友";
                case "partner_preferences" -> "择偶偏好";
                case "values_life_goals" -> "价值观与人生目标";
                case "emotional_needs_communication" -> "情感需求与沟通";
                default -> topic;
            };
            if (coveredTopics.contains(topic)) {
                topicLines.append("  - ").append(label).append(" (id: ").append(topic).append(") [已覆盖 - 请勿再问]\n");
            } else {
                topicLines.append("  - ").append(label).append(" (id: ").append(topic).append(") [待了解]\n");
            }
        }

        StringBuilder prompt = new StringBuilder();
        prompt.append("你是 Synchro 的 AI 交友助手，正在进行一场深入的性格与喜好访谈。\n");
        prompt.append("你的目标是通过对话全面了解用户，帮助他们建立精准的交友档案。\n\n");

        prompt.append("## 工具\n");
        prompt.append("你可以随时调用以下工具，这些操作在后台执行，用户看不到：\n");
        prompt.append("- savePersonalityTrait / savePartnerPreference：实时保存你从用户回答中推断出的特质\n");
        prompt.append("- setProfileAge / setProfileGender / setProfileLocation / setProfileBio / setIdealPartnerDescription：自动填充档案\n");
        prompt.append("- markTopicCovered：标记某个话题已充分了解，之后不要再问\n\n");

        prompt.append("## 工具使用规则\n");
        prompt.append("1. 当 confidence >= 0.6 时立即保存特质，不要等待对话结束\n");
        prompt.append("2. 当用户透露个人信息（年龄、性别、城市），立即调用档案填充工具\n");
        prompt.append("3. 当某个维度已聊得足够深入，调用 markTopicCovered 标记\n");
        prompt.append("4. 不要在对话中提到你调用了什么工具\n");
        prompt.append("5. 特质值范围 0.0-1.0\n\n");

        prompt.append("## 访谈维度\n");
        prompt.append(topicLines).append("\n");

        if (!personalityTraits.isEmpty()) {
            prompt.append("## 已保存的性格特质\n");
            prompt.append(String.join(", ", personalityTraits)).append("\n\n");
        }
        if (!partnerPrefs.isEmpty()) {
            prompt.append("## 已保存的择偶偏好\n");
            prompt.append(String.join(", ", partnerPrefs)).append("\n\n");
        }

        prompt.append("## 档案填充状态\n");
        prompt.append("已填充: ").append(filledFields.isEmpty() ? "无" : String.join(", ", filledFields)).append("\n");
        prompt.append("未填充: ").append(unfilledFields.isEmpty() ? "无" : String.join(", ", unfilledFields)).append("\n\n");

        prompt.append("## 访谈风格\n");
        prompt.append("- 像和朋友微信聊天一样轻松自然\n");
        prompt.append("- 一次只问一个问题\n");
        prompt.append("- 优先覆盖标记为「待了解」的维度\n");
        prompt.append("- 全程中文交流，称呼自己为「交友助手」\n");

        if (isLastRound) {
            prompt.append("\n[重要] 这是最后一轮对话。请给用户一段温暖真诚的总结和感谢。\n");
            prompt.append("绝对不要再提出新的问题。用友好温暖的结束语来结束访谈。\n");
        }

        log.info("[OnboardingService] buildDynamicSystemPrompt - userId={} coveredTopics={} traits={} isLastRound={}",
                userId, coveredTopics, existingTraits.size(), isLastRound);
        log.debug("[OnboardingService] systemPrompt:\n{}", prompt);

        return prompt.toString();
    }

    // ── Build response ──

    private OnboardingResponse buildOnboardingResponse(Conversation conversation, List<Message> messages) {
        return OnboardingResponse.builder()
                .conversation(OnboardingResponse.ConversationResponse.builder()
                        .id(conversation.getId())
                        .type(conversation.getConversationType())
                        .status(conversation.getStatus())
                        .createdAt(conversation.getCreatedAt())
                        .build())
                .messages(messages.stream()
                        .map(m -> {
                            List<String> extractedTraits = List.of();
                            if (m.getMetadata() != null) {
                                try {
                                    var node = objectMapper.readTree(m.getMetadata());
                                    if (node.has("extractedTraits")) {
                                        extractedTraits = objectMapper.convertValue(
                                                node.get("extractedTraits"),
                                                new TypeReference<List<String>>() {});
                                    }
                                } catch (Exception e) {
                                    // ignore parse errors
                                }
                            }
                            return OnboardingResponse.MessageResponse.builder()
                                    .id(m.getId())
                                    .senderType(m.getSenderType())
                                    .content(m.getContent())
                                    .extractedTraits(extractedTraits.isEmpty() ? null : extractedTraits)
                                    .createdAt(m.getCreatedAt())
                                    .build();
                        })
                        .collect(Collectors.toList()))
                .exchangeCount(messages.size() / 2)
                .isComplete(conversation.getStatus() == Conversation.ConversationStatus.COMPLETED)
                .build();
    }

    // ── Helpers ──

    private Profile getOrCreateProfile(Long userId) {
        return profileRepository.findByUserId(userId)
                .orElseGet(() -> {
                    Profile profile = new Profile();
                    profile.setUserId(userId);
                    return profileRepository.save(profile);
                });
    }

    private String sanitizeForDebug(String text) {
        if (text == null) return "null";
        if (text.length() <= 50) return text;
        return text.substring(0, 50) + "...";
    }

    private String getStackTrace(Throwable t) {
        java.io.StringWriter sw = new java.io.StringWriter();
        t.printStackTrace(new java.io.PrintWriter(sw));
        String stack = sw.toString();
        return stack.length() > 500 ? stack.substring(0, 500) : stack;
    }
}
