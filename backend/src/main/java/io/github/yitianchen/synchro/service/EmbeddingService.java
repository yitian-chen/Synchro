package io.github.yitianchen.synchro.service;

import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.data.embedding.Embedding;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmbeddingService {

    private final EmbeddingModel embeddingModel;
    private final RedisTemplate<String, Object> redisTemplate;

    private static final String VECTOR_KEY_PREFIX = "user:vectors:";
    private static final int EMBEDDING_DIMENSION = 1536; // DeepSeek embedding dimension

    public float[] embedText(String text) {
        if (text == null || text.isBlank()) {
            return new float[EMBEDDING_DIMENSION];
        }
        var response = embeddingModel.embed(text);
        Embedding embedding = response.content();
        return embedding.vector();
    }

    public void saveUserEmbedding(Long userId, String bio, float[] embeddingVector) {
        String key = VECTOR_KEY_PREFIX + userId;
        redisTemplate.opsForHash().put(key, "bio_embedding", serializeVector(embeddingVector));
        redisTemplate.opsForHash().put(key, "bio_summary", bio);
        redisTemplate.opsForHash().put(key, "updated_at", java.time.LocalDateTime.now().toString());
        log.info("[EmbeddingService] Saved embedding for userId: {}", userId);
    }

    public float[] getUserEmbedding(Long userId) {
        String key = VECTOR_KEY_PREFIX + userId;
        Object embeddingObj = redisTemplate.opsForHash().get(key, "bio_embedding");
        if (embeddingObj == null) {
            return null;
        }
        return deserializeVector(embeddingObj);
    }

    public String getUserBioSummary(Long userId) {
        String key = VECTOR_KEY_PREFIX + userId;
        return (String) redisTemplate.opsForHash().get(key, "bio_summary");
    }

    public double cosineSimilarity(float[] vec1, float[] vec2) {
        if (vec1 == null || vec2 == null || vec1.length != vec2.length) {
            return 0.0;
        }

        double dotProduct = 0.0;
        double norm1 = 0.0;
        double norm2 = 0.0;

        for (int i = 0; i < vec1.length; i++) {
            dotProduct += vec1[i] * vec2[i];
            norm1 += vec1[i] * vec1[i];
            norm2 += vec2[i] * vec2[i];
        }

        if (norm1 == 0 || norm2 == 0) {
            return 0.0;
        }

        return dotProduct / (Math.sqrt(norm1) * Math.sqrt(norm2));
    }

    public double calculateSemanticSimilarity(Long userId1, Long userId2) {
        float[] embedding1 = getUserEmbedding(userId1);
        float[] embedding2 = getUserEmbedding(userId2);

        if (embedding1 == null || embedding2 == null) {
            log.warn("[EmbeddingService] Missing embedding for users: {} or {}", userId1, userId2);
            return 0.5; // Return neutral score if embedding not available
        }

        return cosineSimilarity(embedding1, embedding2);
    }

    public void saveIdealPartnerEmbedding(Long userId, String description) {
        if (description == null || description.isBlank()) {
            log.warn("[EmbeddingService] Empty ideal partner description for userId: {}", userId);
            return;
        }
        float[] embeddingVector = embedText(description);
        String key = VECTOR_KEY_PREFIX + userId;
        redisTemplate.opsForHash().put(key, "ideal_partner_embedding", serializeVector(embeddingVector));
        redisTemplate.opsForHash().put(key, "ideal_partner_summary", description);
        log.info("[EmbeddingService] Saved ideal partner embedding for userId: {}", userId);
    }

    public float[] getIdealPartnerEmbedding(Long userId) {
        String key = VECTOR_KEY_PREFIX + userId;
        Object embeddingObj = redisTemplate.opsForHash().get(key, "ideal_partner_embedding");
        if (embeddingObj == null) {
            return null;
        }
        return deserializeVector(embeddingObj);
    }

    /**
     * 计算双向意向匹配度:
     * - A的意向描述 vs B的自我介绍 + B的意向描述 vs A的自我介绍
     * - 两个方向取平均
     */
    public double calculateIdealPartnerMatch(Long userId1, Long userId2) {
        float[] user1Ideal = getIdealPartnerEmbedding(userId1);
        float[] user1Bio = getUserEmbedding(userId1);
        float[] user2Ideal = getIdealPartnerEmbedding(userId2);
        float[] user2Bio = getUserEmbedding(userId2);

        if (user1Ideal == null && user2Ideal == null) {
            return 0.5; // 双方都无意向描述，中性值
        }

        double match1 = 0.5; // 默认中性
        double match2 = 0.5;

        if (user1Ideal != null && user2Bio != null) {
            match1 = cosineSimilarity(user1Ideal, user2Bio);
        }
        if (user2Ideal != null && user1Bio != null) {
            match2 = cosineSimilarity(user2Ideal, user1Bio);
        }

        return (match1 + match2) / 2.0;
    }

    // ── Generic document embedding (RAG knowledge base) ──

    private static final String DOC_KEY_PREFIX = "rag:doc:";

    public void saveDocEmbedding(String docId, String text) {
        String key = DOC_KEY_PREFIX + docId;
        float[] embedding = embedText(text);
        redisTemplate.opsForHash().put(key, "text", text);
        redisTemplate.opsForHash().put(key, "embedding", serializeVector(embedding));
        log.info("[EmbeddingService] Saved doc embedding: {}", docId);
    }

    public float[] getDocEmbedding(String docId) {
        String key = DOC_KEY_PREFIX + docId;
        Object embeddingObj = redisTemplate.opsForHash().get(key, "embedding");
        if (embeddingObj == null) return null;
        return deserializeVector(embeddingObj);
    }

    public String getDocText(String docId) {
        String key = DOC_KEY_PREFIX + docId;
        return (String) redisTemplate.opsForHash().get(key, "text");
    }

    public record DocEntry(String docId, String text, float[] embedding) {}

    public List<DocEntry> getAllDocs(String keyPattern) {
        List<DocEntry> docs = new ArrayList<>();
        Set<String> keys = redisTemplate.keys(keyPattern);
        if (keys == null) return docs;
        for (String key : keys) {
            String docId = key.substring(DOC_KEY_PREFIX.length());
            float[] embedding = getDocEmbedding(docId);
            String text = getDocText(docId);
            if (embedding != null && text != null) {
                docs.add(new DocEntry(docId, text, embedding));
            }
        }
        return docs;
    }

    private String serializeVector(float[] vector) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < vector.length; i++) {
            if (i > 0) sb.append(",");
            sb.append(vector[i]);
        }
        return sb.toString();
    }

    private float[] deserializeVector(Object obj) {
        if (obj == null) return null;
        String str = obj.toString();
        String[] parts = str.split(",");
        float[] vector = new float[parts.length];
        for (int i = 0; i < parts.length; i++) {
            vector[i] = Float.parseFloat(parts[i]);
        }
        return vector;
    }
}
