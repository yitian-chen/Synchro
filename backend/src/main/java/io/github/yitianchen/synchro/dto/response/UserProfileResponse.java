package io.github.yitianchen.synchro.dto.response;

import io.github.yitianchen.synchro.model.Profile;
import io.github.yitianchen.synchro.model.User;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserProfileResponse {
    private Long userId;
    private String email;
    private String nickname;
    private String avatarUrl;
    private User.UserStatus status;
    private boolean onboardingCompleted;
    private boolean matchingOptIn;
    private boolean postOnboardingCompleted;

    // Profile fields
    private String bio;
    private Integer age;
    private Profile.Gender gender;
    private String location;
    private Long cityId;
    private String provinceName;
    private String cityName;
    private String traitsSummary;
    private String idealPartnerDescription;
    private Profile.MatchingPreference matchingPreference;
}
