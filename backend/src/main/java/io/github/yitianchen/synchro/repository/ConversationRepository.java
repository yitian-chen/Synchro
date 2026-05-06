package io.github.yitianchen.synchro.repository;

import io.github.yitianchen.synchro.model.Conversation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface ConversationRepository extends JpaRepository<Conversation, Long> {
    List<Conversation> findByUserId(Long userId);
    List<Conversation> findByUserIdAndConversationType(Long userId, Conversation.ConversationType type);
    Optional<Conversation> findByUserIdAndConversationTypeAndStatus(Long userId, Conversation.ConversationType type, Conversation.ConversationStatus status);
    Optional<Conversation> findByMatchId(Long matchId);
}
