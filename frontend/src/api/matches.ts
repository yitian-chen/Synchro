import api from './client';
import type { Match, MatchAskResponse } from '../types';

export const matchesApi = {
  getCurrent: async (): Promise<Match | null> => {
    const response = await api.get('/matches/current');
    return response.data;
  },

  getHistory: async (): Promise<Match[]> => {
    const response = await api.get('/matches/history');
    return response.data;
  },

  askAboutMatch: async (matchId: number, question: string): Promise<MatchAskResponse> => {
    const response = await api.post(`/matches/${matchId}/ask`, { question });
    return response.data;
  },
};
