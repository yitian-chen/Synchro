package io.github.yitianchen.synchro.repository;

import io.github.yitianchen.synchro.model.Message;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface MessageRepository extends JpaRepository<Message, Long> {
    List<Message> findByConversationIdOrderByCreatedAtAsc(Long conversationId);
    List<Message> findByConversationIdAndAiProcessedFalse(Long conversationId);
}
