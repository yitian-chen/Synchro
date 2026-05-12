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

    @Retry(name = "ai")
    public String chat(String userMessage, List<ChatMessageRecord> history) {
        log.info("[AiService] chat - START, userMessage: {}", sanitizeForDebug(userMessage));
        log.info("[AiService] chat - history size: {}", history.size());
        for (int i = 0; i < history.size(); i++) {
            log.info("[AiService] chat - history[{}]: role={}, content={}", i, history.get(i).role(), sanitizeForDebug(history.get(i).content()));
        }

        StringBuilder fullPrompt = new StringBuilder(ONBOARDING_SYSTEM_PROMPT).append("\n\n");
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

    private String sanitizeForDebug(String text) {
        if (text == null) return "null";
        if (text.length() <= 100) return text;
        return text.substring(0, 100) + "...";
    }

    public record ChatMessageRecord(String role, String content) {}
}
