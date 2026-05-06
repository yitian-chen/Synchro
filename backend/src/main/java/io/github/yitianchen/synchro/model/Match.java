package io.github.yitianchen.synchro.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "matches")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Match {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user1_id", nullable = false)
    private Long user1Id;

    @Column(name = "user2_id", nullable = false)
    private Long user2Id;

    @Column(name = "match_week", nullable = false)
    private LocalDate matchWeek;

    @Column(name = "compatibility_score", precision = 5, scale = 4)
    private BigDecimal compatibilityScore;

    @Column(name = "match_reason", columnDefinition = "JSON")
    private String matchReason;

    @Enumerated(EnumType.STRING)
    private MatchStatus status = MatchStatus.PENDING;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    public enum MatchStatus {
        PENDING, ACTIVE, EXPIRED, REMATCHED
    }
}
