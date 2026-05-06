package io.github.yitianchen.synchro.repository;

import io.github.yitianchen.synchro.model.UserTrait;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface UserTraitRepository extends JpaRepository<UserTrait, Long> {
    List<UserTrait> findByProfileId(Long profileId);
    Optional<UserTrait> findByProfileIdAndTraitName(Long profileId, String traitName);
    void deleteByProfileId(Long profileId);
}
