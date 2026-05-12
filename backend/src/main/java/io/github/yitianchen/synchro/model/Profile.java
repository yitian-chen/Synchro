package io.github.yitianchen.synchro.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "profiles")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Profile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false, unique = true)
    private Long userId;

    @Column(columnDefinition = "TEXT")
    private String bio;

    private Integer age;

    @Enumerated(EnumType.STRING)
    private Gender gender;

    private String location;

    @Column(name = "city_id")
    private Long cityId;

    @Column(columnDefinition = "JSON")
    private String preferences;

    @Column(name = "compatibility_score", precision = 5, scale = 2)
    private BigDecimal compatibilityScore;

    @Column(name = "traits_summary", columnDefinition = "JSON")
    private String traitsSummary;

    @Column(name = "ideal_partner_description", columnDefinition = "TEXT")
    private String idealPartnerDescription;

    @Column(name = "matching_preference")
    @Enumerated(EnumType.STRING)
    private MatchingPreference matchingPreference = MatchingPreference.BALANCED;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at")
    private LocalDateTime updatedAt = LocalDateTime.now();

    public enum Gender {
        MALE, FEMALE, OTHER
    }

    public enum MatchingPreference {
        SIMILAR, COMPLEMENTARY, BALANCED
    }
}
