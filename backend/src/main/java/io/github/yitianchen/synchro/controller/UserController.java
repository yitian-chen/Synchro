package io.github.yitianchen.synchro.controller;

import io.github.yitianchen.synchro.dto.request.UpdateProfileRequest;
import io.github.yitianchen.synchro.dto.response.UserProfileResponse;
import io.github.yitianchen.synchro.service.AvatarService;
import io.github.yitianchen.synchro.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;
    private final AvatarService avatarService;

    @GetMapping("/me")
    public ResponseEntity<UserProfileResponse> getCurrentUser(@AuthenticationPrincipal Long userId) {
        return ResponseEntity.ok(userService.getCurrentUserProfile(userId));
    }

    @PutMapping("/me")
    public ResponseEntity<UserProfileResponse> updateProfile(
            @AuthenticationPrincipal Long userId,
            @Valid @RequestBody UpdateProfileRequest request) {
        return ResponseEntity.ok(userService.updateProfile(userId, request));
    }

    @PutMapping("/me/avatar")
    public ResponseEntity<Map<String, String>> updateAvatar(
            @AuthenticationPrincipal Long userId,
            @RequestParam("file") MultipartFile file) throws Exception {
        String avatarUrl = avatarService.uploadAvatar(file, userId);
        userService.updateAvatar(userId, avatarUrl);
        return ResponseEntity.ok(Map.of("avatarUrl", avatarUrl));
    }

    @PutMapping("/me/matching-opt-in")
    public ResponseEntity<Void> setMatchingOptIn(
            @AuthenticationPrincipal Long userId,
            @RequestBody Map<String, Boolean> body) {
        userService.setMatchingOptIn(userId, body.getOrDefault("optIn", false));
        return ResponseEntity.ok().build();
    }
}
