import api from './client';
import type { Match } from '../types';

export const matchApi = {
  getCurrentMatch: async (): Promise<Match | null> => {
    const response = await api.get('/matches/current');
    return response.data;
  },

  getMatchHistory: async (): Promise<Match[]> => {
    const response = await api.get('/matches/history');
    return response.data;
  },

  createConversation: async (matchId: number): Promise<{ conversationId: number }> => {
    const response = await api.post(`/matches/${matchId}/conversations`);
    return response.data;
  },

  triggerMatching: async (): Promise<void> => {
    await api.post('/matches/trigger');
  },
};
