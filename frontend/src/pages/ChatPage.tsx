import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { chatApi } from '../api/chat';
import SockJS from 'sockjs-client';
import Stomp from 'stompjs';
import type { ChatMessage } from '../types';

const ChatPage: React.FC = () => {
  const { conversationId } = useParams<{ conversationId: string }>();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [isConnected, setIsConnected] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const stompClientRef = useRef<Stomp.Client | null>(null);
  const navigate = useNavigate();

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    if (!conversationId) return;

    loadMessages();
    connectWebSocket();

    return () => {
      if (stompClientRef.current && stompClientRef.current.connected) {
        stompClientRef.current.disconnect();
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

  const connectWebSocket = () => {
    const token = localStorage.getItem('accessToken');
    if (!token) {
      navigate('/login');
      return;
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
            setMessages((prev) => [...prev, newMessage]);
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

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      <header className="gradient-bg p-4 flex items-center">
        <button onClick={() => navigate('/dashboard')} className="text-white mr-4">
          ←
        </button>
        <div className="flex-1">
          <h1 className="text-lg font-heading font-bold text-white">聊天</h1>
          <span className={`text-xs ${isConnected ? 'text-green-300' : 'text-red-300'}`}>
            {isConnected ? '已连接' : '连接中...'}
          </span>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto p-4 space-y-3 max-w-2xl mx-auto w-full">
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
              <p>{msg.content}</p>
              <span className="text-xs opacity-60 mt-1 block">
                {new Date(msg.createdAt).toLocaleTimeString()}
              </span>
            </div>
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>

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
