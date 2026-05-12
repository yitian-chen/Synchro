package io.github.yitianchen.synchro.service;

import io.github.yitianchen.synchro.dto.request.LoginRequest;
import io.github.yitianchen.synchro.dto.request.RegisterRequest;
import io.github.yitianchen.synchro.dto.response.AuthResponse;
import io.github.yitianchen.synchro.model.Profile;
import io.github.yitianchen.synchro.model.User;
import io.github.yitianchen.synchro.repository.ProfileRepository;
import io.github.yitianchen.synchro.repository.UserRepository;
import io.github.yitianchen.synchro.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final ProfileRepository profileRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final RedisTemplate<String, Object> redisTemplate;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new IllegalArgumentException("Email already registered");
        }

        User user = new User();
        user.setEmail(request.getEmail());
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        user.setNickname(request.getNickname());
        user.setStatus(User.UserStatus.PENDING_ONBOARDING);
        user = userRepository.save(user);

        Profile profile = new Profile();
        profile.setUserId(user.getId());
        profileRepository.save(profile);

        return generateAuthResponse(user);
    }

    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new IllegalArgumentException("Invalid email or password"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new IllegalArgumentException("Invalid email or password");
        }

        return generateAuthResponse(user);
    }

    public AuthResponse refreshToken(String refreshToken) {
        if (!jwtTokenProvider.validateToken(refreshToken)) {
            throw new IllegalArgumentException("Invalid refresh token");
        }

        if (!"REFRESH".equals(jwtTokenProvider.getTokenType(refreshToken))) {
            throw new IllegalArgumentException("Invalid token type");
        }

        // Check if token is blacklisted
        Boolean isBlacklisted = redisTemplate.hasKey("jwt:blacklist:" + refreshToken);
        if (Boolean.TRUE.equals(isBlacklisted)) {
            throw new IllegalArgumentException("Token has been revoked");
        }

        Long userId = jwtTokenProvider.getUserIdFromToken(refreshToken);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        return generateAuthResponse(user);
    }

    public void logout(String accessToken, String refreshToken) {
        if (accessToken != null && jwtTokenProvider.validateToken(accessToken)) {
            long expiration = jwtTokenProvider.getTokenExpiration(accessToken);
            redisTemplate.opsForValue().set("jwt:blacklist:" + accessToken, "true", expiration, TimeUnit.MILLISECONDS);
        }

        if (refreshToken != null && jwtTokenProvider.validateToken(refreshToken)) {
            long expiration = jwtTokenProvider.getTokenExpiration(refreshToken);
            redisTemplate.opsForValue().set("jwt:blacklist:" + refreshToken, "true", expiration, TimeUnit.MILLISECONDS);
        }
    }

    private String getRedirectUrl(User.UserStatus status) {
        return status == User.UserStatus.ACTIVE ? "/dashboard" : "/profile-setup";
    }

    private AuthResponse generateAuthResponse(User user) {
        String accessToken = jwtTokenProvider.generateAccessToken(user.getId(), user.getEmail());
        String refreshToken = jwtTokenProvider.generateRefreshToken(user.getId(), user.getEmail());

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .redirectUrl(getRedirectUrl(user.getStatus()))
                .user(AuthResponse.UserResponse.builder()
                        .id(user.getId())
                        .email(user.getEmail())
                        .nickname(user.getNickname())
                        .avatarUrl(user.getAvatarUrl())
                        .status(user.getStatus())
                        .build())
                .build();
    }
}