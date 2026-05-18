package io.github.yitianchen.synchro.config;

import dev.langchain4j.model.chat.ChatModel;
import dev.langchain4j.model.chat.StreamingChatModel;
import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.model.openai.OpenAiStreamingChatModel;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.openai.OpenAiEmbeddingModel;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class LangChain4jConfig {

    @Value("${ai.openai.model}")
    private String chatModel;

    @Value("${ai.openai.api-key}")
    private String apiKey;

    @Value("${ai.openai.base-url}")
    private String baseUrl;

    // Embedding 独立配置（可对接不同供应商）
    @Value("${ai.embedding.model}")
    private String embeddingModel;

    @Value("${ai.embedding.api-key}")
    private String embeddingApiKey;

    @Value("${ai.embedding.base-url}")
    private String embeddingBaseUrl;

    @Bean
    public ChatModel chatModel() {
        return OpenAiChatModel.builder()
                .apiKey(apiKey)
                .modelName(chatModel)
                .baseUrl(baseUrl)
                .temperature(0.1)
                .timeout(java.time.Duration.ofSeconds(60))
                .logRequests(true)
                .logResponses(true)
                .build();
    }

    @Bean
    public StreamingChatModel streamingChatModel() {
        return OpenAiStreamingChatModel.builder()
                .apiKey(apiKey)
                .modelName(chatModel)
                .baseUrl(baseUrl)
                .temperature(0.1)
                .timeout(java.time.Duration.ofSeconds(60))
                .build();
    }

    @Bean
    public EmbeddingModel embeddingModel() {
        return OpenAiEmbeddingModel.builder()
                .apiKey(embeddingApiKey)
                .modelName(embeddingModel)
                .baseUrl(embeddingBaseUrl)
                .build();
    }
}
