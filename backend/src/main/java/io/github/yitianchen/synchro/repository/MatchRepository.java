package io.github.yitianchen.synchro.repository;

import io.github.yitianchen.synchro.model.Match;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface MatchRepository extends JpaRepository<Match, Long> {
    Optional<Match> findByUser1IdOrUser2IdAndMatchWeek(Long user1Id, Long user2Id, LocalDate matchWeek);
    List<Match> findByUser1IdOrUser2IdOrderByMatchWeekDesc(Long user1Id, Long user2Id);
    boolean existsByUser1IdOrUser2IdAndMatchWeek(Long user1Id, Long user2Id, LocalDate matchWeek);
}
