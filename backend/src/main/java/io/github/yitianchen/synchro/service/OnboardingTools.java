package io.github.yitianchen.synchro.service;

import dev.langchain4j.agent.tool.P;
import dev.langchain4j.agent.tool.Tool;
import io.github.yitianchen.synchro.model.City;
import io.github.yitianchen.synchro.model.Profile;
import io.github.yitianchen.synchro.model.UserTrait;
import io.github.yitianchen.synchro.repository.CityRepository;
import io.github.yitianchen.synchro.repository.ProfileRepository;
import io.github.yitianchen.synchro.repository.UserTraitRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;

import java.math.BigDecimal;
import java.time.Duration;
import java.util.List;

@Slf4j
public class OnboardingTools {

    private final Long userId;
    private final Long profileId;
    private final Long messageId;
    private final ProfileRepository profileRepository;
    private final UserTraitRepository userTraitRepository;
    private final CityRepository cityRepository;
    private final RedisTemplate<String, Object> redisTemplate;

    public OnboardingTools(Long userId, Long profileId, Long messageId,
                           ProfileRepository profileRepository,
                           UserTraitRepository userTraitRepository,
                           CityRepository cityRepository,
                           RedisTemplate<String, Object> redisTemplate) {
        this.userId = userId;
        this.profileId = profileId;
        this.messageId = messageId;
        this.profileRepository = profileRepository;
        this.userTraitRepository = userTraitRepository;
        this.cityRepository = cityRepository;
        this.redisTemplate = redisTemplate;
    }

    // ── Trait save helpers ──

    private void upsertTrait(String traitName, BigDecimal value, BigDecimal confidence, String reason) {
        userTraitRepository.findByProfileIdAndTraitName(profileId, traitName)
                .ifPresent(userTraitRepository::delete);

        UserTrait trait = new UserTrait();
        trait.setProfileId(profileId);
        trait.setTraitName(traitName);
        trait.setTraitValue(value);
        trait.setConfidence(confidence);
        trait.setSourceMessageId(messageId);
        userTraitRepository.save(trait);

        log.info("[OnboardingTools] upsertTrait userId={} trait={} value={} confidence={} reason={}",
                userId, traitName, value, confidence, reason);
    }

    // ── Tool methods ──

    @Tool("Save or update a personality trait. Name must be one of: extroversion, openness, agreeableness, adventurousness, socialness, activity_level, romantic, family_oriented, career_oriented, creative, intellectual, emotional_expressiveness, conflict_avoidant, independence")
    public void savePersonalityTrait(
            @P("Trait name") String traitName,
            @P("Trait value from 0.0 to 1.0") double value,
            @P("Confidence in this assessment from 0.0 to 1.0") double confidence,
            @P("Evidence from the user's response") String reason) {
        upsertTrait(traitName, BigDecimal.valueOf(value), BigDecimal.valueOf(confidence), reason);
    }

    @Tool("Save or update a partner preference. Name must be one of: partner_extroversion_pref, partner_adventurous_pref, partner_social_pref, importance_appearance, importance_values, importance_intelligence, openness_to_distance, long_term_goal")
    public void savePartnerPreference(
            @P("Preference name") String traitName,
            @P("Preference value from 0.0 to 1.0") double value,
            @P("Confidence from 0.0 to 1.0") double confidence,
            @P("Evidence from the user's response") String reason) {
        upsertTrait(traitName, BigDecimal.valueOf(value), BigDecimal.valueOf(confidence), reason);
    }

    @Tool("Auto-fill the user's age in their profile")
    public void setProfileAge(@P("User age in years") int age) {
        profileRepository.findById(profileId).ifPresent(profile -> {
            profile.setAge(age);
            profileRepository.save(profile);
            log.info("[OnboardingTools] setProfileAge userId={} age={}", userId, age);
        });
    }

    @Tool("Auto-fill the user's gender. Value must be MALE, FEMALE, or OTHER")
    public void setProfileGender(@P("Gender value") String gender) {
        try {
            Profile.Gender g = Profile.Gender.valueOf(gender.toUpperCase());
            profileRepository.findById(profileId).ifPresent(profile -> {
                profile.setGender(g);
                profileRepository.save(profile);
                log.info("[OnboardingTools] setProfileGender userId={} gender={}", userId, g);
            });
        } catch (IllegalArgumentException e) {
            log.warn("[OnboardingTools] setProfileGender invalid gender: {}", gender);
        }
    }

    @Tool("Auto-fill the user's city/location. Provide the city name in Chinese")
    public void setProfileLocation(@P("City name in Chinese") String location) {
        profileRepository.findById(profileId).ifPresent(profile -> {
            profile.setLocation(location);

            List<City> cities = cityRepository.findAll();
            for (City city : cities) {
                if (city.getName().contains(location) || location.contains(city.getName())) {
                    profile.setCityId(city.getId());
                    log.info("[OnboardingTools] setProfileLocation matched city: {} -> {}", location, city.getName());
                    break;
                }
            }

            profileRepository.save(profile);
            log.info("[OnboardingTools] setProfileLocation userId={} location={}", userId, location);
        });
    }

    @Tool("Auto-generate a bio summary (2-4 Chinese sentences) based on what you have learned about the user")
    public void setProfileBio(@P("Bio summary in Chinese") String bio) {
        profileRepository.findById(profileId).ifPresent(profile -> {
            profile.setBio(bio);
            profileRepository.save(profile);
            log.info("[OnboardingTools] setProfileBio userId={}", userId);
        });
    }

    @Tool("Auto-generate an ideal partner description (2-4 Chinese sentences) based on what the user wants in a partner")
    public void setIdealPartnerDescription(@P("Ideal partner description in Chinese") String description) {
        profileRepository.findById(profileId).ifPresent(profile -> {
            profile.setIdealPartnerDescription(description);
            profileRepository.save(profile);
            log.info("[OnboardingTools] setIdealPartnerDescription userId={}", userId);
        });
    }

    @Tool("Mark a conversation topic as covered so you do NOT ask about it again. Topic must be one of: hobbies_lifestyle, personality_emotion, social_preferences, partner_preferences, values_life_goals, emotional_needs_communication")
    public void markTopicCovered(
            @P("Topic identifier") String topic) {
        String key = "onboarding:topics:" + userId;
        redisTemplate.opsForSet().add(key, topic);
        redisTemplate.expire(key, Duration.ofDays(7));
        log.info("[OnboardingTools] markTopicCovered userId={} topic={}", userId, topic);
    }
}
