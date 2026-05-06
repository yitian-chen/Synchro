package io.github.yitianchen.synchro.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "user_traits")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserTrait {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "profile_id", nullable = false)
    private Long profileId;

    @Column(name = "trait_name", nullable = false)
    private String traitName;

    @Column(name = "trait_value", nullable = false, precision = 5, scale = 4)
    private BigDecimal traitValue;

    @Column(precision = 5, scale = 4)
    private BigDecimal confidence = BigDecimal.ONE;

    @Column(name = "source_message_id")
    private Long sourceMessageId;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();
}
