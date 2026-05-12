import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { chatApi } from '../api/chat';
import type { Conversation } from '../types';

const ChatListPage: React.FC = () => {
  const navigate = useNavigate();
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadConversations();
  }, []);

  const loadConversations = async () => {
    try {
      const data = await chatApi.getConversations();
      // 只显示 MATCH 类型的对话
      setConversations(data.filter((c) => c.type === 'MATCH'));
    } catch (err) {
      console.error('Failed to load conversations:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const formatTime = (dateStr: string) => {
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    if (diffDays === 0) {
      return date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
    }
    if (diffDays === 1) return '昨天';
    if (diffDays < 7) return `${diffDays}天前`;
    return date.toLocaleDateString('zh-CN', { month: '2-digit', day: '2-digit' });
  };

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      <header className="gradient-bg p-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <button onClick={() => navigate('/dashboard')} className="text-white text-lg leading-none">
            ←
          </button>
          <h1 className="text-xl font-heading font-bold text-white">消息</h1>
        </div>
      </header>

      <main className="flex-1">
        {isLoading ? (
          <div className="flex items-center justify-center py-20">
            <p className="text-gray-400">加载中...</p>
          </div>
        ) : conversations.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20">
            <div className="w-16 h-16 rounded-full bg-gray-200 flex items-center justify-center text-gray-400 text-2xl mb-4">
              💬
            </div>
            <p className="text-gray-500">暂无消息</p>
            <p className="text-sm text-gray-400 mt-1">匹配成功后即可开始聊天</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-100">
            {conversations.map((conv) => (
              <button
                key={conv.id}
                onClick={() => navigate(`/chat/${conv.id}`)}
                className="w-full flex items-center px-4 py-3 hover:bg-gray-100 transition-colors text-left"
              >
                {/* Avatar */}
                <div className="w-12 h-12 rounded-full bg-primary bg-opacity-20 overflow-hidden flex-shrink-0 flex items-center justify-center text-primary font-bold">
                  {conv.participantAvatarUrl ? (
                    <img src={conv.participantAvatarUrl} alt="" className="w-full h-full object-cover" />
                  ) : (
                    conv.participantNickname?.[0]?.toUpperCase() || '?'
                  )}
                </div>

                {/* Content */}
                <div className="ml-3 flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <h3 className="font-semibold text-sm truncate">
                      {conv.participantNickname || '未知用户'}
                    </h3>
                    {conv.lastMessage && (
                      <span className="text-xs text-gray-400 flex-shrink-0 ml-2">
                        {formatTime(conv.lastMessage.createdAt)}
                      </span>
                    )}
                  </div>
                  <div className="flex items-center justify-between mt-0.5">
                    <p className="text-sm text-gray-500 truncate">
                      {conv.lastMessage?.content || '暂无消息'}
                    </p>
                    {conv.unreadCount > 0 && (
                      <span className="flex-shrink-0 ml-2 min-w-[18px] h-[18px] rounded-full bg-red-500 text-white text-xs flex items-center justify-center px-1">
                        {conv.unreadCount > 99 ? '99+' : conv.unreadCount}
                      </span>
                    )}
                  </div>
                </div>
              </button>
            ))}
          </div>
        )}
      </main>
    </div>
  );
};

export default ChatListPage;
