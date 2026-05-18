import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { onboardingApi } from '../api/onboarding';
import type { OnboardingMessage } from '../types';
import ReactMarkdown from 'react-markdown';

const OnboardingPage: React.FC = () => {
  const { logout } = useAuth();
  const [messages, setMessages] = useState<OnboardingMessage[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [exchangeCount, setExchangeCount] = useState(0);
  const [redirectUrl, setRedirectUrl] = useState('/dashboard');
  const MAX_EXCHANGES = 8;
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const startedRef = useRef(false);
  const navigate = useNavigate();

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;
    startOnboarding();
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const startOnboarding = async () => {
    try {
      const response = await onboardingApi.start();
      setMessages(response.messages);
      setExchangeCount(response.exchangeCount);
      if (response.isComplete) {
        setIsComplete(true);
        if (response.redirectUrl) setRedirectUrl(response.redirectUrl);
      }
    } catch (err) {
      console.error('Failed to start onboarding:', err);
    }
  };

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || isLoading) return;

    const userContent = input.trim();
    const tempId = -Date.now();
    const tempMessage: OnboardingMessage = {
      id: tempId,
      senderType: 'USER',
      content: userContent,
      createdAt: new Date().toISOString(),
    };

    // 乐观更新：立即显示用户消息
    setMessages((prev) => [...prev, tempMessage]);
    setInput('');
    setIsLoading(true);

    try {
      const response = await onboardingApi.sendMessage(userContent);
      // 用服务端返回的完整消息列表替换（包含用户消息和 AI 回复）
      setMessages(response.messages);
      setExchangeCount(response.exchangeCount);
      if (response.isComplete) {
        setIsComplete(true);
        if (response.redirectUrl) setRedirectUrl(response.redirectUrl);
      }
    } catch (err) {
      console.error('Failed to send message:', err);
      // 失败时移除临时消息
      setMessages((prev) => prev.filter((m) => m.id !== tempId));
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="h-screen bg-gray-50 flex flex-col">
      <div className="gradient-bg p-4 flex items-center justify-between">
        <div>
          <h1 className="text-xl font-heading font-bold">AI性格访谈</h1>
          <div className="text-xs opacity-70 flex items-center gap-1">
            <span>{exchangeCount > 0 ? `第${Math.min(exchangeCount, MAX_EXCHANGES)}轮` : '准备开始'}</span>
            <span>/</span>
            <span>共{MAX_EXCHANGES}轮</span>
          </div>
        </div>
        <button
          onClick={logout}
          className="text-white text-sm hover:underline"
        >
          退出
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-4 max-w-2xl mx-auto w-full">
        {messages.map((msg) => (
          <div
            key={msg.id}
            className={`flex ${msg.senderType === 'USER' ? 'justify-end' : 'justify-start'}`}
          >
            <div
              className={`max-w-xs lg:max-w-md px-4 py-2 rounded-2xl ${
                msg.senderType === 'USER'
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
              {msg.extractedTraits && msg.extractedTraits.length > 0 && (
                <div className="mt-2 flex flex-wrap gap-1">
                  {msg.extractedTraits.map((trait) => (
                    <span
                      key={trait}
                      className="text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full"
                    >
                      {trait}
                    </span>
                  ))}
                </div>
              )}
              <span className="text-xs opacity-60 mt-1 block">
                {new Date(msg.createdAt).toLocaleTimeString()}
              </span>
            </div>
          </div>
        ))}
        {isLoading && (
          <div className="flex justify-start">
            <div className="bg-white px-4 py-2 rounded-2xl shadow">
              <p className="text-gray-500">AI正在思考...</p>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {isComplete ? (
        <div className="p-4 bg-white border-t">
          <div className="max-w-2xl mx-auto">
            <button
              onClick={() => navigate(redirectUrl)}
              className="btn-primary w-full py-3 rounded-xl text-base"
            >
              完成访谈，进入下一步
            </button>
          </div>
        </div>
      ) : (
        <form onSubmit={handleSend} className="p-4 bg-white border-t">
          <div className="flex space-x-2 max-w-2xl mx-auto">
            <input
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              placeholder="输入你的回答..."
              className="flex-1 px-4 py-2 border rounded-full focus:ring-2 focus:ring-primary focus:border-primary"
              disabled={isLoading}
            />
            <button
              type="submit"
              disabled={isLoading || !input.trim()}
              className="btn-primary px-6 rounded-full"
            >
              发送
            </button>
          </div>
        </form>
      )}
    </div>
  );
};

export default OnboardingPage;