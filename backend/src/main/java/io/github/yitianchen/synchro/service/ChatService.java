package io.github.yitianchen.synchro.service;

import io.github.yitianchen.synchro.model.Conversation;
import io.github.yitianchen.synchro.model.Match;
import io.github.yitianchen.synchro.model.Message;
import io.github.yitianchen.synchro.repository.ConversationRepository;
import io.github.yitianchen.synchro.repository.MatchRepository;
import io.github.yitianchen.synchro.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Slf4j
@Service
@RequiredArgsConstructor
public class ChatService {

    private final MessageRepository messageRepository;
    private final ConversationRepository conversationRepository;
    private final MatchRepository matchRepository;
    private final SimpMessagingTemplate messagingTemplate;
    private final RedisTemplate<String, Object> redisTemplate;

    @Transactional
    public Message sendMessage(Long senderId, Long conversationId, String content) {
        log.info("[ChatService] sendMessage - senderId: {}, conversationId: {}, content: {}",
                senderId, conversationId, sanitizeForDebug(content));

        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new IllegalArgumentException("Conversation not found"));

        // Verify sender is participant
        if (!conversation.getUserId().equals(senderId) &&
                !conversation.getParticipantId().equals(senderId)) {
            throw new IllegalArgumentException("User not participant in this conversation");
        }

        Message message = new Message();
        message.setConversationId(conversationId);
        message.setSenderId(senderId);
        message.setSenderType(Message.SenderType.USER);
        message.setContent(content);
        message = messageRepository.save(message);

        // Get the other participant's userId
        Long recipientId = conversation.getUserId().equals(senderId)
                ? conversation.getParticipantId()
                : conversation.getUserId();

        // Broadcast via WebSocket
        messagingTemplate.convertAndSend(
                "/queue/chat/" + recipientId,
                new ChatMessagePayload(message.getId(), conversationId, senderId,
                        Message.SenderType.USER, content, message.getCreatedAt())
        );

        // Cache recent message in Redis
        cacheRecentMessage(conversationId, message);

        log.info("[ChatService] Message sent and broadcast: messageId={}", message.getId());
        return message;
    }

    public List<Message> getConversationMessages(Long conversationId, int limit, int offset) {
        return messageRepository.findByConversationIdOrderByCreatedAtAsc(conversationId)
                .stream()
                .skip(offset)
                .limit(limit)
                .toList();
    }

    /**
     * 获取用户参与的所有对话（作为所有者或参与者）
     */
    public List<Conversation> getUserConversations(Long userId) {
        // 合并用户作为 owner 和 participant 的所有对话，去重
        Set<Long> seenIds = new HashSet<>();
        List<Conversation> allConversations = new ArrayList<>();

        Stream.concat(
                conversationRepository.findByUserId(userId).stream(),
                conversationRepository.findByParticipantId(userId).stream()
        ).forEach(conv -> {
            if (seenIds.add(conv.getId())) {
                allConversations.add(conv);
            }
        });

        // 按 updatedAt/createdAt 降序排列
        allConversations.sort((a, b) -> {
            if (a.getUpdatedAt() != null && b.getUpdatedAt() != null) {
                return b.getUpdatedAt().compareTo(a.getUpdatedAt());
            }
            return b.getCreatedAt().compareTo(a.getCreatedAt());
        });

        return allConversations;
    }

    /**
     * 获取用户在指定对话中的未读消息数
     */
    public int getUnreadCount(Long conversationId, Long userId) {
        return messageRepository.countByConversationIdAndSenderIdNotAndReadFalse(conversationId, userId);
    }

    /**
     * 标记对话中所有非用户发送的消息为已读
     */
    @Transactional
    public void markConversationAsRead(Long conversationId, Long userId) {
        int updated = messageRepository.markAsReadByConversation(conversationId, userId);
        if (updated > 0) {
            log.info("[ChatService] Marked {} messages as read in conversation {} for user {}",
                    updated, conversationId, userId);
        }
    }

    @Transactional
    public Conversation getOrCreateMatchConversation(Long userId, Long matchId) {
        return conversationRepository.findByMatchId(matchId)
                .orElseGet(() -> {
                    Match match = matchRepository.findById(matchId)
                            .orElseThrow(() -> new IllegalArgumentException("Match not found"));

                    Conversation conversation = new Conversation();
                    conversation.setUserId(match.getUser1Id());
                    conversation.setParticipantId(match.getUser2Id());
                    conversation.setMatchId(matchId);
                    conversation.setConversationType(Conversation.ConversationType.MATCH);
                    conversation.setTitle("Match Conversation");
                    conversation = conversationRepository.save(conversation);

                    // Update match status to ACTIVE
                    match.setStatus(Match.MatchStatus.ACTIVE);
                    matchRepository.save(match);

                    return conversation;
                });
    }

    private void cacheRecentMessage(Long conversationId, Message message) {
        String key = "conversation:" + conversationId + ":recent";
        redisTemplate.opsForList().rightPush(key, message.getId());
        redisTemplate.opsForList().trim(key, -50, -1); // Keep only 50 most recent
        redisTemplate.expire(key, java.time.Duration.ofDays(1));
    }

    private String sanitizeForDebug(String text) {
        if (text == null) return "null";
        if (text.length() <= 50) return text;
        return text.substring(0, 50) + "...";
    }

    public record ChatMessagePayload(Long id, Long conversationId, Long senderId,
                                     Message.SenderType senderType, String content,
                                     java.time.LocalDateTime createdAt) {}
}
