package io.github.yitianchen.synchro.controller;

import io.github.yitianchen.synchro.dto.response.MatchResponse;
import io.github.yitianchen.synchro.model.Match;
import io.github.yitianchen.synchro.model.User;
import io.github.yitianchen.synchro.repository.UserRepository;
import io.github.yitianchen.synchro.service.MatchingService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/matches")
@RequiredArgsConstructor
public class MatchController {

    private final MatchingService matchingService;
    private final UserRepository userRepository;

    @GetMapping("/current")
    public ResponseEntity<MatchResponse> getCurrentMatch(@AuthenticationPrincipal Long userId) {
        Optional<Match> matchOpt = matchingService.getCurrentMatch(userId);

        if (matchOpt.isEmpty()) {
            return ResponseEntity.noContent().build();
        }

        Match match = matchOpt.get();
        User currentUser = userRepository.findById(userId).orElseThrow();
        User otherUser = userRepository.findById(
                match.getUser1Id().equals(userId) ? match.getUser2Id() : match.getUser1Id()
        ).orElseThrow();

        return ResponseEntity.ok(MatchResponse.fromMatch(match, currentUser, otherUser));
    }

    @GetMapping("/history")
    public ResponseEntity<List<MatchResponse>> getMatchHistory(@AuthenticationPrincipal Long userId) {
        List<Match> matches = matchingService.getMatchHistory(userId);

        List<MatchResponse> responses = matches.stream().map(match -> {
            User user1 = userRepository.findById(match.getUser1Id()).orElseThrow();
            User user2 = userRepository.findById(match.getUser2Id()).orElseThrow();
            return MatchResponse.fromMatch(match, user1, user2);
        }).toList();

        return ResponseEntity.ok(responses);
    }

    @PostMapping("/trigger")
    public ResponseEntity<Map<String, String>> triggerMatching(@AuthenticationPrincipal Long userId) {
        // For testing purposes - trigger matching manually
        matchingService.executeWeeklyMatching();
        return ResponseEntity.ok(Map.of("message", "Matching triggered successfully"));
    }
}
