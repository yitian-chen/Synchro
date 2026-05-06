package io.github.yitianchen.synchro.dto.response;

import io.github.yitianchen.synchro.model.Conversation;
import io.github.yitianchen.synchro.model.Message;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OnboardingResponse {

    private ConversationResponse conversation;
    private List<MessageResponse> messages;
    private int exchangeCount;
    private boolean isComplete;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ConversationResponse {
        private Long id;
        private Conversation.ConversationType type;
        private Conversation.ConversationStatus status;
        private LocalDateTime createdAt;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class MessageResponse {
        private Long id;
        private Message.SenderType senderType;
        private String content;
        private List<String> extractedTraits;
        private LocalDateTime createdAt;
    }
}
