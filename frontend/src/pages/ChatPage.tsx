import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { chatApi } from '../api/chat';
import { matchesApi } from '../api/matches';
import SockJS from 'sockjs-client';
import Stomp from 'stompjs';
import type { ChatMessage } from '../types';
import ReactMarkdown from 'react-markdown';

const ChatPage: React.FC = () => {
  const { user } = useAuth();
  const { conversationId } = useParams<{ conversationId: string }>();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [isConnected, setIsConnected] = useState(false);
  const [participantName, setParticipantName] = useState<string>('');
  const [matchId, setMatchId] = useState<number | null>(null);
  const [showAdvisor, setShowAdvisor] = useState(false);
  const [ragQuestion, setRagQuestion] = useState('');
  const [ragAnswer, setRagAnswer] = useState('');
  const [ragLoading, setRagLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const stompClientRef = useRef<Stomp.Client | null>(null);
  const navigate = useNavigate();

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    if (!conversationId) return;

    loadMessages();
    loadConversationInfo();
    connectWebSocket();
    chatApi.markAsRead(Number(conversationId));

    return () => {
      if (stompClientRef.current) {
        try {
          stompClientRef.current.disconnect(() => {});
        } catch (_) {}
        stompClientRef.current = null;
      }
    };
  }, [conversationId]);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const loadMessages = async () => {
    try {
      const data = await chatApi.getMessages(Number(conversationId));
      setMessages(data);
    } catch (err) {
      console.error('Failed to load messages:', err);
    }
  };

  const loadConversationInfo = async () => {
    try {
      const convs = await chatApi.getConversations();
      const conv = convs.find((c) => c.id === Number(conversationId));
      if (conv) {
        if (conv.participantNickname) setParticipantName(conv.participantNickname);
        if (conv.matchId) setMatchId(conv.matchId);
      }
    } catch (err) {
      console.error('Failed to load conversation info:', err);
    }
  };

  const connectWebSocket = () => {
    const token = localStorage.getItem('accessToken');
    if (!token) {
      navigate('/login');
      return;
    }

    // 断开旧连接（即使未完成也要断开，防止 StrictMode 双订阅）
    if (stompClientRef.current) {
      try {
        stompClientRef.current.disconnect(() => {});
      } catch (_) {}
    }

    const socket = new SockJS('/ws/chat');
    const stompClient = Stomp.over(socket);
    stompClientRef.current = stompClient;

    stompClient.connect(
      { Authorization: `Bearer ${token}` },
      () => {
        setIsConnected(true);
        const userId = JSON.parse(localStorage.getItem('user') || '{}').id;
        stompClient.subscribe(
          `/queue/chat/${userId}`,
          (msg: Stomp.Message) => {
            const newMessage = JSON.parse(msg.body);
            setMessages((prev) => {
              // 去重：如果该消息已存在则不添加
              if (prev.some((m) => m.id === newMessage.id)) return prev;
              return [...prev, newMessage];
            });
          }
        );
      },
      (err: Stomp.Frame | string) => {
        console.error('WebSocket connection error:', err);
        setIsConnected(false);
      }
    );
  };

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || !conversationId) return;

    try {
      const message = await chatApi.sendMessage(Number(conversationId), input);
      setMessages((prev) => [...prev, message]);
      setInput('');
    } catch (err) {
      console.error('Failed to send message:', err);
    }
  };

  const handleAskAdvisor = async (question: string) => {
    if (!matchId || ragLoading) return;
    setRagLoading(true);
    setRagAnswer('');
    try {
      const response = await matchesApi.askAboutMatch(matchId, question);
      setRagAnswer(response.answer);
    } catch (err) {
      console.error('Failed to ask advisor:', err);
      setRagAnswer('抱歉，暂时无法获取回答，请稍后再试。');
    } finally {
      setRagLoading(false);
    }
  };

  return (
    <div className="h-screen bg-gray-50 flex flex-col">
      <header className="gradient-bg p-4 flex items-center">
        <button onClick={() => navigate('/chat')} className="text-white mr-4">
          ←
        </button>
        <div className="flex-1">
          <h1 className="text-lg font-heading font-bold text-white">{participantName || '聊天'}</h1>
          <span className={`text-xs ${isConnected ? 'text-green-300' : 'text-red-300'}`}>
            {isConnected ? '在线' : '连接中...'}
          </span>
        </div>
        {matchId && (
          <button
            onClick={() => setShowAdvisor(!showAdvisor)}
            className={`text-white text-sm px-3 py-1.5 rounded-full transition-colors ${
              showAdvisor ? 'bg-white/20' : 'bg-white/10 hover:bg-white/20'
            }`}
            title="AI匹配顾问"
          >
            💡 AI顾问
          </button>
        )}
      </header>

      <div className="flex-1 overflow-y-auto p-4 space-y-3 max-w-2xl mx-auto w-full">
        {messages.map((msg) => {
          const isMyMessage = msg.senderType === 'USER' && msg.senderId === user?.id;
          return (
            <div
              key={msg.id}
              className={`flex ${isMyMessage ? 'justify-end' : 'justify-start'}`}
            >
              <div
                className={`max-w-xs lg:max-w-md px-4 py-2 rounded-2xl ${
                  isMyMessage
                    ? 'bg-primary text-white rounded-br-sm'
                    : 'bg-white text-gray-800 rounded-bl-sm shadow'
                }`}
              >
                <ReactMarkdown
                  components={{
                    p: ({ children }) => <span className="message-content">{children}</span>,
                  }}
                >
                  {msg.content}
                </ReactMarkdown>
                <span className="text-xs opacity-60 mt-1 block">
                  {new Date(msg.createdAt).toLocaleTimeString()}
                </span>
              </div>
            </div>
          );
        })}
        <div ref={messagesEndRef} />
      </div>

      {showAdvisor && matchId && (
        <div className="bg-white border-t shadow-inner">
          <div className="max-w-2xl mx-auto p-4">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-semibold text-gray-700">AI 匹配顾问</h3>
              <button
                onClick={() => setShowAdvisor(false)}
                className="text-gray-400 hover:text-gray-600 text-sm"
              >
                ✕
              </button>
            </div>

            {/* Quick questions */}
            <div className="flex flex-wrap gap-2 mb-3">
              <button
                onClick={() => {
                  setRagQuestion('为什么我们被匹配到一起了？');
                  handleAskAdvisor('为什么我们被匹配到一起了？');
                }}
                disabled={ragLoading}
                className="text-xs px-3 py-1.5 bg-primary/10 text-primary rounded-full hover:bg-primary/20 disabled:opacity-50"
              >
                为什么匹配到TA？
              </button>
              <button
                onClick={() => {
                  setRagQuestion('如何开启话题破冰？');
                  handleAskAdvisor('如何开启话题破冰？');
                }}
                disabled={ragLoading}
                className="text-xs px-3 py-1.5 bg-primary/10 text-primary rounded-full hover:bg-primary/20 disabled:opacity-50"
              >
                如何开启话题？
              </button>
            </div>

            {/* Custom question input */}
            <form
              onSubmit={(e) => {
                e.preventDefault();
                if (ragQuestion.trim()) handleAskAdvisor(ragQuestion.trim());
              }}
              className="flex gap-2 mb-3"
            >
              <input
                type="text"
                value={ragQuestion}
                onChange={(e) => setRagQuestion(e.target.value)}
                placeholder="输入你的问题..."
                className="flex-1 px-3 py-1.5 border rounded-full text-sm focus:ring-2 focus:ring-primary focus:border-primary"
                disabled={ragLoading}
              />
              <button
                type="submit"
                disabled={ragLoading || !ragQuestion.trim()}
                className="px-4 py-1.5 bg-primary text-white rounded-full text-sm hover:opacity-90 disabled:opacity-50"
              >
                发送
              </button>
            </form>

            {/* Answer display */}
            {ragLoading && (
              <div className="flex items-center gap-2 text-sm text-gray-500 py-2">
                <div className="animate-spin w-4 h-4 border-2 border-primary border-t-transparent rounded-full" />
                AI正在分析匹配数据...
              </div>
            )}
            {ragAnswer && !ragLoading && (
              <div className="bg-gray-50 rounded-xl p-4 text-sm">
                <ReactMarkdown
                  components={{
                    p: ({ children }) => <p className="mb-2 last:mb-0">{children}</p>,
                  }}
                >
                  {ragAnswer}
                </ReactMarkdown>
              </div>
            )}
          </div>
        </div>
      )}

      <form onSubmit={handleSend} className="p-4 bg-white border-t">
        <div className="flex space-x-2 max-w-2xl mx-auto">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="输入消息..."
            className="flex-1 px-4 py-2 border rounded-full focus:ring-2 focus:ring-primary focus:border-primary"
          />
          <button type="submit" className="btn-primary px-6 rounded-full">
            发送
          </button>
        </div>
      </form>
    </div>
  );
};

export default ChatPage;
