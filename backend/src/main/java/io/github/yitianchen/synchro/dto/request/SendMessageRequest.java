package io.github.yitianchen.synchro.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class SendMessageRequest {

    @NotNull(message = "Conversation ID is required")
    private Long conversationId;

    @NotBlank(message = "Message content is required")
    private String content;
}
