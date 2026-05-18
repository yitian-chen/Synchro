package io.github.yitianchen.synchro.service;

import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Seeds the RAG icebreaker knowledge base into Redis on startup.
 * Each tip is embedded and stored for later cosine-similarity retrieval.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class IcebreakerKnowledgeBase {

    private final EmbeddingService embeddingService;

    private static final String ICEBREAKER_PREFIX = "icebreaker:";

    private static final List<String> TIPS = List.of(
            "从对方的个人简介中找到具体的兴趣爱好作为切入点，比如\"我看到你也喜欢户外徒步，你最近去过哪里？\"这样既自然又能快速找到共同话题。",
            "观察你们的共享特质，从共同点出发建立连接感。例如你们都偏向开放性高，可以聊聊彼此对新事物的看法和有趣的经历。",
            "用开放式问题了解对方的兴趣和生活，避免封闭式的是非题。比如\"你周末一般喜欢做什么？\"比\"你喜欢看电影吗？\"更能展开对话。",
            "利用你们的互补特质制造趣味互动。如果你外向而对方偏内向，可以说\"我比较话多，你要做好心理准备哈哈\"，让对方放松。",
            "从匹配原因自然过渡到聊天。比如\"系统说我们很匹配，好奇你填资料时最看重什么特质？\"既引出话题又了解对方。",
            "分享一个关于你自己的小趣事或最近的经历，然后自然地问对方相关的问题，让对话有来有回而不是单方面提问。",
            "避免一上来就查户口式提问（年龄、工作、收入等），先从轻松的话题切入，建立舒适感后再深入了解。",
            "如果对方个人简介中有明确的爱好标签，围绕这个爱好展开是最高效的破冰方式，人们对谈论自己热爱的事物总是很乐意。",
            "使用轻松幽默的语气开场，比如\"所以我们是AI认证的绝配，你觉得AI的眼光怎么样？\"可以让初次对话不那么尴尬。",
            "注意观察对方回复的长度和热情度来调整自己的节奏。如果对方回复简短，可以换个话题试试；如果对方回复详细，说明这个话题对方感兴趣。",
            "基于双方的地理位置展开话题，如果你们在同一个城市，可以聊聊本地的餐厅、景点、活动等共同熟悉的事物。",
            "聊旅行经历是一个很好的切入点，几乎每个人都有旅行故事可以分享，而且能从中了解对方的价值观和生活方式。",
            "可以从双方的择偶偏好切入，聊聊对理想关系的看法，这能帮助双方判断是否在重要的事情上价值观一致。",
            "如果对话出现短暂冷场，可以准备一些通用的话题备选：最近在看的剧/电影、最喜欢的食物、如果中了彩票会做什么等轻松话题。",
            "真诚地表达对对方某个特点的欣赏，比如\"看到你的个人简介感觉你是个很有意思的人\"，积极的反馈会让对方更愿意分享。",
            "在对话进行2-3轮后，可以尝试聊更深一点的话题，比如对生活的期待、最近在思考的问题等，让关系从表面走向深入。",
            "如果对方提到了你不熟悉的话题，可以大方表示好奇并请对方多讲一点，这本身就是一种很好的交流方式。",
            "聊饮食习惯和美食偏好往往能快速拉近距离，毕竟\"吃\"是每个人都关心的话题，也可以自然过渡到约见面。"
    );

    @PostConstruct
    public void init() {
        log.info("[IcebreakerKnowledgeBase] Seeding {} tips into Redis...", TIPS.size());
        for (int i = 0; i < TIPS.size(); i++) {
            String docId = ICEBREAKER_PREFIX + i;
            embeddingService.saveDocEmbedding(docId, TIPS.get(i));
        }
        log.info("[IcebreakerKnowledgeBase] Done seeding icebreaker tips.");
    }

    public List<EmbeddingService.DocEntry> retrieve(String question, int topK) {
        float[] queryEmbedding = embeddingService.embedText(question);
        List<EmbeddingService.DocEntry> allDocs = embeddingService.getAllDocs("rag:doc:" + ICEBREAKER_PREFIX + "*");

        return allDocs.stream()
                .map(doc -> new java.util.AbstractMap.SimpleEntry<>(
                        doc, embeddingService.cosineSimilarity(queryEmbedding, doc.embedding())))
                .sorted((a, b) -> Double.compare(b.getValue(), a.getValue()))
                .limit(topK)
                .map(java.util.AbstractMap.SimpleEntry::getKey)
                .toList();
    }
}
