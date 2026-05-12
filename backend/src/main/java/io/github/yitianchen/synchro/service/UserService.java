package io.github.yitianchen.synchro.service;

import io.github.yitianchen.synchro.dto.request.UpdateProfileRequest;
import io.github.yitianchen.synchro.dto.response.UserProfileResponse;
import io.github.yitianchen.synchro.model.City;
import io.github.yitianchen.synchro.model.Profile;
import io.github.yitianchen.synchro.model.Province;
import io.github.yitianchen.synchro.model.User;
import io.github.yitianchen.synchro.repository.CityRepository;
import io.github.yitianchen.synchro.repository.ProfileRepository;
import io.github.yitianchen.synchro.repository.ProvinceRepository;
import io.github.yitianchen.synchro.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Slf4j
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final ProfileRepository profileRepository;
    private final EmbeddingService embeddingService;
    private final CityRepository cityRepository;
    private final ProvinceRepository provinceRepository;

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
        if (request.getGender() != null && !request.getGender().isEmpty()) {
            profile.setGender(Profile.Gender.valueOf(request.getGender()));
        }
        if (request.getLocation() != null) {
            profile.setLocation(request.getLocation());
        }
        // 通过 cityId 自动填充 location（省份/城市）
        if (request.getCityId() != null) {
            cityRepository.findById(request.getCityId()).ifPresent(city -> {
                profile.setCityId(city.getId());
                provinceRepository.findById(city.getProvinceId()).ifPresent(province -> {
                    profile.setLocation(province.getName() + " " + city.getName());
                });
            });
        }
        if (request.getIdealPartnerDescription() != null) {
            profile.setIdealPartnerDescription(request.getIdealPartnerDescription());
        }
        if (request.getMatchingPreference() != null && !request.getMatchingPreference().isEmpty()) {
            profile.setMatchingPreference(Profile.MatchingPreference.valueOf(request.getMatchingPreference()));
        }

        profileRepository.save(profile);

        // 生成意向描述的向量嵌入（非关键路径，失败不应阻止资料保存）
        if (request.getIdealPartnerDescription() != null) {
            try {
                embeddingService.saveIdealPartnerEmbedding(userId, request.getIdealPartnerDescription());
            } catch (Exception e) {
                log.warn("[UserService] Failed to save ideal partner embedding: {}", e.getMessage());
            }
        }

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

    @Transactional
    public void setMatchingOptIn(Long userId, boolean optIn) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
        user.setMatchingOptIn(optIn);
        userRepository.save(user);
    }

    private UserProfileResponse buildUserProfileResponse(User user, Profile profile) {
        // 查询城市/省份名称用于响应
        String provinceName = null;
        String cityName = null;
        if (profile.getCityId() != null) {
            var cityOpt = cityRepository.findById(profile.getCityId());
            if (cityOpt.isPresent()) {
                City city = cityOpt.get();
                cityName = city.getName();
                var provinceOpt = provinceRepository.findById(city.getProvinceId());
                if (provinceOpt.isPresent()) {
                    provinceName = provinceOpt.get().getName();
                }
            }
        }

        return UserProfileResponse.builder()
                .userId(user.getId())
                .email(user.getEmail())
                .nickname(user.getNickname())
                .avatarUrl(user.getAvatarUrl())
                .status(user.getStatus())
                .onboardingCompleted(user.isOnboardingCompleted())
                .matchingOptIn(user.isMatchingOptIn())
                .bio(profile.getBio())
                .age(profile.getAge())
                .gender(profile.getGender())
                .location(profile.getLocation())
                .cityId(profile.getCityId())
                .provinceName(provinceName)
                .cityName(cityName)
                .traitsSummary(profile.getTraitsSummary())
                .idealPartnerDescription(profile.getIdealPartnerDescription())
                .matchingPreference(profile.getMatchingPreference())
                .build();
    }
}
