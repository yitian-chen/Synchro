package io.github.yitianchen.synchro.service;

import dev.langchain4j.model.chat.ChatModel;
import dev.langchain4j.data.message.UserMessage;
import io.github.resilience4j.retry.annotation.Retry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class AiService {

    private final ChatModel chatModel;

    private static final String ONBOARDING_SYSTEM_PROMPT = """
            You are Synchro, an AI dating assistant conducting a fun and engaging personality interview.
            Your goal is to help users build their dating profile by learning about their personality,
            hobbies, and preferences.

            Guidelines:
            - Keep questions casual and conversational (like texting a friend)
            - Ask one question at a time
            - Vary topics to get a holistic view (hobbies, personality, lifestyle, values)
            - When users mention traits, interests, or preferences, acknowledge them naturally
            - After 8-10 exchanges, summarize and confirm their profile traits
            - Be friendly, curious, and slightly playful
            - Extracted traits should include: interests, personality style, lifestyle preferences, dealbreakers
            - Reply in Chinese, 称呼自己为"交友助手"
            """;

    @Retry(name = "ai")
    public String chat(String userMessage, List<ChatMessageRecord> history) {
        log.debug("[AiService] chat - userMessage: {}", sanitizeForDebug(userMessage));

        StringBuilder fullPrompt = new StringBuilder(ONBOARDING_SYSTEM_PROMPT).append("\n\n");
        for (ChatMessageRecord msg : history) {
            fullPrompt.append(msg.role()).append(": ").append(msg.content()).append("\n");
        }
        fullPrompt.append("user: ").append(userMessage).append("\nassistant:");

        var response = chatModel.chat(List.of(UserMessage.from(fullPrompt.toString())));
        String responseText = response.aiMessage().text();
        log.debug("[AiService] chat - response: {}", sanitizeForDebug(responseText));

        return responseText;
    }

    private String sanitizeForDebug(String text) {
        if (text == null) return "null";
        if (text.length() <= 100) return text;
        return text.substring(0, 100) + "...";
    }

    public record ChatMessageRecord(String role, String content) {}
}
