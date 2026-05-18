package io.github.yitianchen.synchro.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import dev.langchain4j.agent.tool.ToolSpecification;
import dev.langchain4j.data.message.AiMessage;
import dev.langchain4j.data.message.ChatMessage;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.model.chat.ChatModel;
import dev.langchain4j.model.chat.request.ChatRequest;
import dev.langchain4j.model.chat.response.ChatResponse;
import io.github.resilience4j.retry.annotation.Retry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

@Slf4j
@Service
public class AiService {

    private final ChatModel chatModel;
    private final ObjectMapper objectMapper;

    public AiService(ChatModel chatModel, ObjectMapper objectMapper) {
        this.chatModel = chatModel;
        this.objectMapper = objectMapper;
    }

    private static final String ONBOARDING_SYSTEM_PROMPT = """
            你是 Synchro 的 AI 交友助手，正在进行一场深入的性格与喜好访谈。
            你的目标是全面了解用户，帮助他们建立精准的交友档案。
            由于只能对话8次，请合理安排对话，如果用户回答不够清晰，可以追问，但是请确保八次提问能覆盖用户的各种特征。

            访谈话题维度（按顺序逐步覆盖）：

            1. 兴趣爱好与生活方式
               - 业余时间喜欢做什么？工作日 vs 周末有区别吗？
               - 运动健身、阅读、游戏、户外活动、文艺创作等
               - 饮食习惯、消费观念

            2. 性格与情感
               - 如何描述自己的性格？朋友会怎么形容你？
               - 在关系中你是哪种依恋风格？（焦虑型、安全型、回避型等）
               - 发生矛盾时你喜欢怎么处理？

            3. 社交与交友
               - 你是社交达人还是偏向小圈子？社交对你意味着什么？
               - 在新环境中融入得快吗？
               - 朋友在你生活中扮演什么角色？

            4. 择偶偏好（核心！）
               - 你理想中的另一半是什么样的？哪些特质是必须的？
               - 有什么底线或雷区（dealbreaker）？比如异地、抽烟、某种价值观
               - 你更看重外表、性格、才华还是其他？
               - 对年龄、身高、学历有要求吗？

            5. 价值观与人生目标
               - 人生中最重要的是什么？（家庭、事业、自由、自我实现等）
               - 对婚姻和长期关系的看法？希望多久内找到稳定关系？
               - 未来想生活在什么样的城市/生活方式？

            6. 情感需求与沟通
               - 谈恋爱时你需要的情感支持是什么样的？
               - 喜欢每天聊天还是保持一定独立空间？
               - 爱的语言是什么？（肯定、礼物、时间、服务、身体接触）

            访谈风格：
            - 像和一个有趣的朋友微信聊天，轻松但真诚
            - 一次只问一个问题，等用户回答后自然追问
            - 用户说的话题深入聊透了再自然过渡到下一个话题
            - 8 轮对话后，整理用户透露的信息并确认理解是否正确
            - 保持友好、好奇、略微俏皮的风格
            - 全程用中文交流，称呼自己为"交友助手"
            """;

    // ── Legacy chat (used by TraitExtractionService & startOnboarding) ──

    @Retry(name = "ai")
    public String chat(String userMessage, List<ChatMessageRecord> history) {
        return chat(userMessage, history, false);
    }

    @Retry(name = "ai")
    public String chat(String userMessage, List<ChatMessageRecord> history, boolean isLastRound) {
        log.info("[AiService] chat - START, userMessage: {}, isLastRound: {}", sanitizeForDebug(userMessage), isLastRound);
        log.info("[AiService] chat - history size: {}", history.size());
        for (int i = 0; i < history.size(); i++) {
            log.info("[AiService] chat - history[{}]: role={}, content={}", i, history.get(i).role(), sanitizeForDebug(history.get(i).content()));
        }

        StringBuilder fullPrompt = new StringBuilder(ONBOARDING_SYSTEM_PROMPT).append("\n\n");

        if (isLastRound) {
            fullPrompt.append("[重要] 这是最后一轮对话。请给用户一段温暖真诚的总结和感谢，告诉用户你已经充分了解了他/她。").append("\n");
            fullPrompt.append("绝对不要再提出任何新的问题。用一段友好、温暖的结束语来结束这次访谈。").append("\n\n");
        }

        for (ChatMessageRecord msg : history) {
            fullPrompt.append(msg.role()).append(": ").append(msg.content()).append("\n");
        }
        fullPrompt.append("user: ").append(userMessage).append("\nassistant:");

        log.info("[AiService] chat - calling chatModel.chat...");
        var response = chatModel.chat(List.of(UserMessage.from(fullPrompt.toString())));
        String responseText = response.aiMessage().text();
        log.info("[AiService] chat - response received, length: {}", responseText != null ? responseText.length() : "null");
        log.debug("[AiService] chat - response: {}", sanitizeForDebug(responseText));

        return responseText;
    }

    // ── Prompt-based tool calling (model-agnostic, works without native function calling) ──

    private static final Pattern TOOL_CALL_PATTERN =
            Pattern.compile("<\\|tool_call\\|>\\s*\\n(\\{.*?})\\s*\\n<\\|/tool_call\\|>", Pattern.DOTALL);

    /**
     * Chat with prompt-based tool calling. Tools are NOT sent via API function calling;
     * the model is instructed to output {@code ```tool_call} code blocks in its response.
     * Works with any LLM regardless of native function calling support.
     */
    public AiMessage chatWithTools(
            List<ChatMessage> messages,
            List<ToolSpecification> toolSpecifications,
            OnboardingTools tools) {

        var mutableMessages = new ArrayList<>(messages);
        AiMessage aiMessage = null;

        for (int loop = 0; loop < 5; loop++) {
            ChatRequest request = ChatRequest.builder()
                    .messages(mutableMessages)
                    .build();

            log.info("[AiService] chatWithTools - loop {} calling chatModel, {} messages, {} tools",
                    loop, mutableMessages.size(), toolSpecifications.size());
            for (ToolSpecification spec : toolSpecifications) {
                log.info("[AiService] chatWithTools - tool spec: name={} desc={}",
                        spec.name(), spec.description());
            }

            ChatResponse response = chatModel.chat(request);
            aiMessage = response.aiMessage();
            String rawText = aiMessage.text();
            if (rawText == null) rawText = "";

            log.info("[AiService] chatWithTools - response textLen={} finishReason={}",
                    rawText.length(), response.finishReason());

            var result = parseAndExecuteToolCalls(rawText, tools);

            if (result.toolCalls().isEmpty()) {
                log.info("[AiService] chatWithTools - no tool calls found, returning text.");
                return AiMessage.from(result.cleanText());
            }

            log.info("[AiService] chatWithTools - {} tool calls executed: {}",
                    result.toolCalls().size(),
                    result.toolCalls().stream().map(tc -> tc.name).toList());

            StringBuilder toolResultText = new StringBuilder();
            for (var tc : result.toolCalls()) {
                toolResultText.append("- ").append(tc.name).append(": ").append(tc.result).append("\n");
            }

            mutableMessages.add(AiMessage.from(result.cleanText()));
            mutableMessages.add(SystemMessage.from(
                    "[系统提示] 以下工具已在后台执行完成：\n" + toolResultText +
                    "请继续对话，不要再重复调用已成功的工具。"));
        }

        log.warn("[AiService] chatWithTools - max tool loop iterations reached");
        return aiMessage;
    }

    private record ToolCallParseResult(String cleanText, List<ToolCall> toolCalls) {}

    private record ToolCall(String name, String result) {}

    private ToolCallParseResult parseAndExecuteToolCalls(String rawText, OnboardingTools tools) {
        var matcher = TOOL_CALL_PATTERN.matcher(rawText);
        var toolCalls = new ArrayList<ToolCall>();

        while (matcher.find()) {
            String jsonStr = matcher.group(1);
            log.info("[AiService] parseAndExecuteToolCalls - found tool_call: {}", sanitizeForDebug(jsonStr));
            try {
                JsonNode call = objectMapper.readTree(jsonStr);
                String name = call.get("name").asText();
                JsonNode args = call.get("arguments");
                if (args == null) args = objectMapper.createObjectNode();

                toolCalls.add(new ToolCall(name, executeToolCall(name, args, tools)));
            } catch (Exception e) {
                log.warn("[AiService] parseAndExecuteToolCalls - failed: {}", e.getMessage());
                toolCalls.add(new ToolCall("parse_error", "Failed: " + e.getMessage()));
            }
        }

        String cleanText = TOOL_CALL_PATTERN.matcher(rawText).replaceAll("").trim();
        return new ToolCallParseResult(cleanText, toolCalls);
    }

    public List<ChatMessage> buildStructuredMessages(
            String systemPrompt,
            List<io.github.yitianchen.synchro.model.Message> dbMessages,
            String currentUserMessage) {

        List<ChatMessage> messages = new ArrayList<>();
        messages.add(SystemMessage.from(systemPrompt));

        for (io.github.yitianchen.synchro.model.Message dbMsg : dbMessages) {
            if (dbMsg.getContent() == null) continue;
            if (dbMsg.getSenderType() == io.github.yitianchen.synchro.model.Message.SenderType.USER) {
                messages.add(UserMessage.from(dbMsg.getContent()));
            } else if (dbMsg.getSenderType() == io.github.yitianchen.synchro.model.Message.SenderType.AI) {
                messages.add(AiMessage.from(dbMsg.getContent()));
            }
        }

        if (currentUserMessage != null && !currentUserMessage.isEmpty()) {
            messages.add(UserMessage.from(currentUserMessage));
        }

        return messages;
    }

    // ── Tool dispatch ──

    private String executeToolCall(String toolName, JsonNode args, OnboardingTools tools) {
        log.info("[AiService] executeToolCall - tool={} args={}", toolName, sanitizeForDebug(args.toString()));

        try {
            return switch (toolName) {
                case "savePersonalityTrait" -> {
                    tools.savePersonalityTrait(
                            args.get("traitName").asText(),
                            args.get("value").asDouble(),
                            args.get("confidence").asDouble(),
                            args.has("reason") ? args.get("reason").asText() : "");
                    yield "Saved personality trait: " + args.get("traitName").asText();
                }
                case "savePartnerPreference" -> {
                    tools.savePartnerPreference(
                            args.get("traitName").asText(),
                            args.get("value").asDouble(),
                            args.get("confidence").asDouble(),
                            args.has("reason") ? args.get("reason").asText() : "");
                    yield "Saved partner preference: " + args.get("traitName").asText();
                }
                case "setProfileBio" -> {
                    tools.setProfileBio(args.get("bio").asText());
                    yield "Profile bio updated.";
                }
                case "setIdealPartnerDescription" -> {
                    tools.setIdealPartnerDescription(args.get("description").asText());
                    yield "Ideal partner description updated.";
                }
                case "markTopicCovered" -> {
                    tools.markTopicCovered(args.get("topic").asText());
                    yield "Topic marked as covered: " + args.get("topic").asText();
                }
                default -> {
                    log.warn("[AiService] executeToolCall - unknown tool: {}", toolName);
                    yield "Unknown tool: " + toolName;
                }
            };
        } catch (Exception e) {
            log.error("[AiService] executeToolCall - failed for {}: {}", toolName, e.getMessage());
            return "Tool execution error: " + e.getMessage();
        }
    }

    // ── Utilities ──

    private String sanitizeForDebug(String text) {
        if (text == null) return "null";
        if (text.length() <= 100) return text;
        return text.substring(0, 100) + "...";
    }

    @Deprecated(forRemoval = false)
    public record ChatMessageRecord(String role, String content) {}
}
