package io.github.yitianchen.synchro.controller;

import io.github.yitianchen.synchro.dto.request.SendMessageRequest;
import io.github.yitianchen.synchro.dto.response.ConversationResponse;
import io.github.yitianchen.synchro.model.Conversation;
import io.github.yitianchen.synchro.model.Message;
import io.github.yitianchen.synchro.model.User;
import io.github.yitianchen.synchro.repository.UserRepository;
import io.github.yitianchen.synchro.service.ChatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;
    private final UserRepository userRepository;

    @GetMapping("/api/conversations")
    public ResponseEntity<List<ConversationResponse>> getConversations(@AuthenticationPrincipal Long userId) {
        List<Conversation> conversations = chatService.getUserConversations(userId);

        List<ConversationResponse> responses = conversations.stream()
                .map(conv -> {
                    Long participantId = conv.getUserId().equals(userId)
                            ? conv.getParticipantId()
                            : conv.getUserId();
                    User participant = userRepository.findById(participantId).orElse(null);

                    List<Message> messages = chatService.getConversationMessages(conv.getId(), 1, 0);
                    ConversationResponse.MessageResponse lastMsg = null;
                    if (!messages.isEmpty()) {
                        Message msg = messages.get(0);
                        lastMsg = ConversationResponse.MessageResponse.builder()
                                .id(msg.getId())
                                .senderType(msg.getSenderType())
                                .content(msg.getContent())
                                .createdAt(msg.getCreatedAt())
                                .build();
                    }

                    int unreadCount = chatService.getUnreadCount(conv.getId(), userId);

                    return ConversationResponse.builder()
                            .id(conv.getId())
                            .type(conv.getConversationType())
                            .participantId(participantId)
                            .participantNickname(participant != null ? participant.getNickname() : null)
                            .participantAvatarUrl(participant != null ? participant.getAvatarUrl() : null)
                            .matchId(conv.getMatchId())
                            .title(conv.getTitle())
                            .status(conv.getStatus())
                            .lastMessage(lastMsg)
                            .unreadCount(unreadCount)
                            .createdAt(conv.getCreatedAt())
                            .build();
                })
                .toList();

        return ResponseEntity.ok(responses);
    }

    @GetMapping("/api/conversations/{id}/messages")
    public ResponseEntity<List<ConversationResponse.MessageResponse>> getMessages(
            @AuthenticationPrincipal Long userId,
            @PathVariable Long id,
            @RequestParam(defaultValue = "50") int limit,
            @RequestParam(defaultValue = "0") int offset) {

        List<Message> messages = chatService.getConversationMessages(id, limit, offset);

        List<ConversationResponse.MessageResponse> responses = messages.stream()
                .map(msg -> ConversationResponse.MessageResponse.builder()
                        .id(msg.getId())
                        .senderType(msg.getSenderType())
                        .content(msg.getContent())
                        .createdAt(msg.getCreatedAt())
                        .build())
                .toList();

        return ResponseEntity.ok(responses);
    }

    @Transactional
    @PutMapping("/api/conversations/{id}/read")
    public ResponseEntity<Void> markAsRead(
            @AuthenticationPrincipal Long userId,
            @PathVariable Long id) {
        chatService.markConversationAsRead(id, userId);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/api/conversations/{id}/messages")
    public ResponseEntity<ConversationResponse.MessageResponse> sendMessage(
            @AuthenticationPrincipal Long userId,
            @PathVariable Long id,
            @Valid @RequestBody SendMessageRequest request) {

        Message message = chatService.sendMessage(userId, id, request.getContent());

        return ResponseEntity.ok(ConversationResponse.MessageResponse.builder()
                .id(message.getId())
                .senderType(message.getSenderType())
                .content(message.getContent())
                .createdAt(message.getCreatedAt())
                .build());
    }

    @PostMapping("/api/matches/{matchId}/conversations")
    public ResponseEntity<Map<String, Long>> createMatchConversation(
            @AuthenticationPrincipal Long userId,
            @PathVariable Long matchId) {

        Conversation conversation = chatService.getOrCreateMatchConversation(userId, matchId);
        return ResponseEntity.ok(Map.of("conversationId", conversation.getId()));
    }

    @MessageMapping("/chat/message")
    public void handleWebSocketMessage(@Payload SendMessageRequest request, @AuthenticationPrincipal Long userId) {
        chatService.sendMessage(userId, request.getConversationId(), request.getContent());
    }
}
