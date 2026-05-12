package io.github.yitianchen.synchro.service;

import io.github.yitianchen.synchro.dto.request.OnboardingMessageRequest;
import io.github.yitianchen.synchro.dto.response.OnboardingResponse;
import io.github.yitianchen.synchro.model.Conversation;
import io.github.yitianchen.synchro.model.Message;
import io.github.yitianchen.synchro.model.Profile;
import io.github.yitianchen.synchro.model.User;
import io.github.yitianchen.synchro.repository.ConversationRepository;
import io.github.yitianchen.synchro.repository.MessageRepository;
import io.github.yitianchen.synchro.repository.ProfileRepository;
import io.github.yitianchen.synchro.repository.UserRepository;
import io.github.yitianchen.synchro.repository.UserTraitRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import reactor.core.publisher.Flux;
import java.util.ArrayList;
import java.util.List;
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
    private final AiService aiService;
    private final TraitExtractionService traitExtractionService;

    private static final int MAX_EXCHANGES_BEFORE_SUMMARY = 8;

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
                    if (user.getStatus() != User.UserStatus.PENDING_ONBOARDING) {
                        throw new IllegalStateException("Onboarding not available. Please contact support.");
                    }
                    // 清理该用户所有非ACTIVE状态的onboarding对话
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
            String welcomeMessage;
            try {
                welcomeMessage = aiService.chat("Hello", List.of());
            } catch (Exception e) {
                log.error("[OnboardingService] AI chat failed to generate welcome: {}", e.getMessage());
                welcomeMessage = "Hey there! I'm Synchro — your personal dating profile assistant. Let's get to know each other!";
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

    @Transactional
    public OnboardingResponse sendMessage(Long userId, OnboardingMessageRequest request) {
        log.info("[OnboardingService] sendMessage - userId: {}, content: {}",
                userId, sanitizeForDebug(request.getContent()));

        log.info("[OnboardingService] sendMessage - looking for ACTIVE onboarding conversation...");
        List<Conversation> conversations = conversationRepository.findByUserIdAndConversationType(userId, Conversation.ConversationType.ONBOARDING);
        Conversation conversation = conversations.stream()
                .filter(c -> c.getStatus() == Conversation.ConversationStatus.ACTIVE)
                .findFirst()
                .orElse(null);

        if (conversation == null) {
            log.error("[OnboardingService] sendMessage - no ACTIVE conversation found for userId: {}", userId);
            throw new IllegalStateException("No active onboarding conversation. Please start onboarding first.");
        }

        // 清理同一用户的其他非ACTIVE状态的onboarding对话，避免累积
        conversations.stream()
                .filter(c -> c.getId() != conversation.getId() && c.getStatus() != Conversation.ConversationStatus.ARCHIVED)
                .forEach(c -> {
                    c.setStatus(Conversation.ConversationStatus.ARCHIVED);
                    conversationRepository.save(c);
                });

        log.info("[OnboardingService] sendMessage - found conversation id: {}, status: {}", conversation.getId(), conversation.getStatus());

        Message userMessage = new Message();
        userMessage.setConversationId(conversation.getId());
        userMessage.setSenderId(userId);
        userMessage.setSenderType(Message.SenderType.USER);
        userMessage.setContent(request.getContent());
        messageRepository.save(userMessage);
        log.info("[OnboardingService] sendMessage - user message saved, id: {}", userMessage.getId());

        List<Message> history = messageRepository.findByConversationIdOrderByCreatedAtAsc(conversation.getId());
        log.info("[OnboardingService] sendMessage - history size: {}", history.size());

        List<AiService.ChatMessageRecord> chatHistory = history.stream()
                .limit(history.size() - 1) // 排除刚保存的用户消息，避免重复发送
                .map(m -> new AiService.ChatMessageRecord(
                        m.getSenderType() == Message.SenderType.USER ? "user" : "assistant",
                        m.getContent()))
                .collect(Collectors.toList());
        log.info("[OnboardingService] sendMessage - chatHistory size: {}", chatHistory.size());

        log.info("[OnboardingService] sendMessage - calling aiService.chat...");
        String aiResponse;
        try {
            aiResponse = aiService.chat(request.getContent(), chatHistory);
            log.info("[OnboardingService] sendMessage - aiResponse received, length: {}", aiResponse != null ? aiResponse.length() : "null");
        } catch (Throwable t) {
            log.error("[OnboardingService] AI chat failed: {}, type: {}, stack: {}",
                t.getMessage(), t.getClass().getName(), getStackTrace(t));
            throw new IllegalStateException("AI service unavailable, please try again later: " + t.getMessage());
        }

        Message aiMessage = new Message();
        aiMessage.setConversationId(conversation.getId());
        aiMessage.setSenderId(-1L);
        aiMessage.setSenderType(Message.SenderType.AI);
        aiMessage.setContent(aiResponse);
        messageRepository.save(aiMessage);

        history.add(userMessage);
        history.add(aiMessage);

        boolean shouldComplete = history.size() / 2 >= MAX_EXCHANGES_BEFORE_SUMMARY;
        if (shouldComplete) {
            return completeOnboarding(userId, conversation, history);
        }

        return buildOnboardingResponse(conversation, history);
    }

    @Transactional
    public OnboardingResponse completeOnboardingManually(Long userId) {
        Conversation conversation = conversationRepository
                .findByUserIdAndConversationTypeAndStatus(userId, Conversation.ConversationType.ONBOARDING, Conversation.ConversationStatus.ACTIVE)
                .orElseThrow(() -> new IllegalStateException("No active onboarding conversation"));

        List<Message> history = messageRepository.findByConversationIdOrderByCreatedAtAsc(conversation.getId());
        return completeOnboarding(userId, conversation, history);
    }

    private OnboardingResponse completeOnboarding(Long userId, Conversation conversation, List<Message> history) {
        log.info("[OnboardingService] completing onboarding for userId: {}", userId);

        traitExtractionService.extractAndSaveTraits(userId, history);

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

        log.info("[OnboardingService] resetOnboarding completed for userId: {}", userId);
    }

    private OnboardingResponse buildOnboardingResponse(Conversation conversation, List<Message> messages) {
        return OnboardingResponse.builder()
                .conversation(OnboardingResponse.ConversationResponse.builder()
                        .id(conversation.getId())
                        .type(conversation.getConversationType())
                        .status(conversation.getStatus())
                        .createdAt(conversation.getCreatedAt())
                        .build())
                .messages(messages.stream()
                        .map(m -> OnboardingResponse.MessageResponse.builder()
                                .id(m.getId())
                                .senderType(m.getSenderType())
                                .content(m.getContent())
                                .createdAt(m.getCreatedAt())
                                .build())
                        .collect(Collectors.toList()))
                .exchangeCount(messages.size() / 2)
                .isComplete(conversation.getStatus() == Conversation.ConversationStatus.COMPLETED)
                .build();
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
