package io.github.yitianchen.synchro.repository;

import io.github.yitianchen.synchro.model.Message;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface MessageRepository extends JpaRepository<Message, Long> {
    List<Message> findByConversationIdOrderByCreatedAtAsc(Long conversationId);
    List<Message> findByConversationIdAndAiProcessedFalse(Long conversationId);
    int countByConversationIdAndSenderIdNotAndReadFalse(Long conversationId, Long senderId);

    @Modifying
    @Query("UPDATE Message m SET m.read = true WHERE m.conversationId = :conversationId AND m.senderId <> :userId AND m.read = false")
    int markAsReadByConversation(Long conversationId, Long userId);
}
