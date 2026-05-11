package io.github.yitianchen.synchro.controller;

import io.github.yitianchen.synchro.dto.request.OnboardingMessageRequest;
import io.github.yitianchen.synchro.dto.response.OnboardingResponse;
import io.github.yitianchen.synchro.service.OnboardingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;

@RestController
@RequestMapping("/api/onboarding")
@RequiredArgsConstructor
public class OnboardingController {

    private final OnboardingService onboardingService;

    @PostMapping("/start")
    public ResponseEntity<OnboardingResponse> startOnboarding(@AuthenticationPrincipal Long userId) {
        return ResponseEntity.ok(onboardingService.startOnboarding(userId));
    }

    @PostMapping("/message")
    public ResponseEntity<OnboardingResponse> sendMessage(
            @AuthenticationPrincipal Long userId,
            @Valid @RequestBody OnboardingMessageRequest request) {
        return ResponseEntity.ok(onboardingService.sendMessage(userId, request));
    }

    @GetMapping("/messages")
    public ResponseEntity<OnboardingResponse> getMessages(@AuthenticationPrincipal Long userId) {
        return ResponseEntity.ok(onboardingService.getOnboardingStatus(userId));
    }

    @PostMapping("/complete")
    public ResponseEntity<OnboardingResponse> completeManually(@AuthenticationPrincipal Long userId) {
        return ResponseEntity.ok(onboardingService.completeOnboardingManually(userId));
    }

    @PostMapping("/reset")
    public ResponseEntity<Void> resetOnboarding(@AuthenticationPrincipal Long userId) {
        onboardingService.resetOnboarding(userId);
        return ResponseEntity.ok().build();
    }
}
