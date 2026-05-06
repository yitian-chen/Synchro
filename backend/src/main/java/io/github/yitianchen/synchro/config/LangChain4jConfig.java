package io.github.yitianchen.synchro.config;

import dev.langchain4j.model.chat.ChatModel;
import dev.langchain4j.model.chat.StreamingChatModel;
import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.model.openai.OpenAiStreamingChatModel;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.openai.OpenAiEmbeddingModel;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Slf4j
@Configuration
public class LangChain4jConfig {

    @Value("${ai.openai.model}")
    private String chatModel;

    @Value("${ai.openai.embedding-model}")
    private String embeddingModel;

    @Value("${ai.openai.api-key}")
    private String apiKey;

    @Value("${ai.openai.base-url}")
    private String baseUrl;

    @PostConstruct
    public void init() {
        log.info("===== AI Config =====");
        log.info("baseUrl: {}", baseUrl);
        log.info("chatModel: {}", chatModel);
        log.info("embeddingModel: {}", embeddingModel);
        log.info("apiKey: {}", apiKey != null ? apiKey.substring(0, 10) + "..." : "null");
    }

    @Bean
    public ChatModel chatModel() {
        return OpenAiChatModel.builder()
                .apiKey(apiKey)
                .modelName(chatModel)
                .baseUrl(baseUrl)
                .temperature(0.8)
                .timeout(java.time.Duration.ofSeconds(60))
                .build();
    }

    @Bean
    public StreamingChatModel streamingChatModel() {
        return OpenAiStreamingChatModel.builder()
                .apiKey(apiKey)
                .modelName(chatModel)
                .baseUrl(baseUrl)
                .temperature(0.8)
                .timeout(java.time.Duration.ofSeconds(60))
                .build();
    }

    @Bean
    public EmbeddingModel embeddingModel() {
        return OpenAiEmbeddingModel.builder()
                .apiKey(apiKey)
                .modelName(embeddingModel)
                .baseUrl(baseUrl)
                .build();
    }
}
