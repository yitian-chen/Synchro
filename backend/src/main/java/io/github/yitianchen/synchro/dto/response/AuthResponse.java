package io.github.yitianchen.synchro.dto.response;

import io.github.yitianchen.synchro.model.User;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AuthResponse {
    private String accessToken;
    private String refreshToken;
    private UserResponse user;
    private String redirectUrl;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UserResponse {
        private Long id;
        private String email;
        private String nickname;
        private String avatarUrl;
        private User.UserStatus status;
        private boolean onboardingCompleted;
        private boolean matchingOptIn;
    }
}
