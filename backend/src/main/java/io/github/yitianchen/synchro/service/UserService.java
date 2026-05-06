package io.github.yitianchen.synchro.service;

import io.github.yitianchen.synchro.dto.request.UpdateProfileRequest;
import io.github.yitianchen.synchro.dto.response.UserProfileResponse;
import io.github.yitianchen.synchro.model.Profile;
import io.github.yitianchen.synchro.model.User;
import io.github.yitianchen.synchro.repository.ProfileRepository;
import io.github.yitianchen.synchro.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final ProfileRepository profileRepository;

    public UserProfileResponse getCurrentUserProfile(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        Profile profile = profileRepository.findByUserId(userId)
                .orElse(new Profile());

        return buildUserProfileResponse(user, profile);
    }

    @Transactional
    public UserProfileResponse updateProfile(Long userId, UpdateProfileRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        Profile profile = profileRepository.findByUserId(userId)
                .orElseGet(() -> {
                    Profile newProfile = new Profile();
                    newProfile.setUserId(userId);
                    return newProfile;
                });

        if (request.getBio() != null) {
            profile.setBio(request.getBio());
        }
        if (request.getAge() != null) {
            profile.setAge(request.getAge());
        }
        if (request.getGender() != null) {
            profile.setGender(request.getGender());
        }
        if (request.getLocation() != null) {
            profile.setLocation(request.getLocation());
        }
        if (request.getPreferences() != null) {
            profile.setPreferences(request.getPreferences());
        }

        profileRepository.save(profile);

        return buildUserProfileResponse(user, profile);
    }

    @Transactional
    public String updateAvatar(Long userId, String avatarUrl) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        user.setAvatarUrl(avatarUrl);
        userRepository.save(user);

        return avatarUrl;
    }

    private UserProfileResponse buildUserProfileResponse(User user, Profile profile) {
        return UserProfileResponse.builder()
                .userId(user.getId())
                .email(user.getEmail())
                .nickname(user.getNickname())
                .avatarUrl(user.getAvatarUrl())
                .status(user.getStatus())
                .onboardingCompleted(user.isOnboardingCompleted())
                .bio(profile.getBio())
                .age(profile.getAge())
                .gender(profile.getGender())
                .location(profile.getLocation())
                .preferences(profile.getPreferences())
                .compatibilityScore(profile.getCompatibilityScore())
                .traitsSummary(profile.getTraitsSummary())
                .build();
    }
}
