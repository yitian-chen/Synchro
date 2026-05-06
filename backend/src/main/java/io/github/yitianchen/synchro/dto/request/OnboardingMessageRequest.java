package io.github.yitianchen.synchro.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class OnboardingMessageRequest {

    @NotBlank(message = "Message content is required")
    private String content;
}
