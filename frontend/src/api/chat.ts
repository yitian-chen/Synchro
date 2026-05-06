import api from './client';
import type { Conversation, ChatMessage } from '../types';

export const chatApi = {
  getConversations: async (): Promise<Conversation[]> => {
    const response = await api.get('/conversations');
    return response.data;
  },

  getMessages: async (conversationId: number, limit = 50, offset = 0): Promise<ChatMessage[]> => {
    const response = await api.get(`/conversations/${conversationId}/messages`, {
      params: { limit, offset },
    });
    return response.data;
  },

  sendMessage: async (conversationId: number, content: string): Promise<ChatMessage> => {
    const response = await api.post(`/conversations/${conversationId}/messages`, {
      conversationId,
      content,
    });
    return response.data;
  },
};
