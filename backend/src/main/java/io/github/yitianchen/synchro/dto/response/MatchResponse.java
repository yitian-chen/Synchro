package io.github.yitianchen.synchro.dto.response;

import io.github.yitianchen.synchro.model.Match;
import io.github.yitianchen.synchro.model.User;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MatchResponse {

    private Long matchId;
    private Long user1Id;
    private Long user2Id;
    private String user1Nickname;
    private String user2Nickname;
    private String user1AvatarUrl;
    private String user2AvatarUrl;
    private LocalDate matchWeek;
    private BigDecimal compatibilityScore;
    private Match.MatchStatus status;
    private String matchReason;
    private LocalDateTime createdAt;

    public static MatchResponse fromMatch(Match match, User user1, User user2) {
        return MatchResponse.builder()
                .matchId(match.getId())
                .user1Id(match.getUser1Id())
                .user2Id(match.getUser2Id())
                .user1Nickname(user1.getNickname())
                .user2Nickname(user2.getNickname())
                .user1AvatarUrl(user1.getAvatarUrl())
                .user2AvatarUrl(user2.getAvatarUrl())
                .matchWeek(match.getMatchWeek())
                .compatibilityScore(match.getCompatibilityScore())
                .status(match.getStatus())
                .matchReason(match.getMatchReason())
                .createdAt(match.getCreatedAt())
                .build();
    }
}
