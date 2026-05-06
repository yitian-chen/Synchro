import api from './client';
import type { OnboardingResponse } from '../types';

export const onboardingApi = {
  start: async (): Promise<OnboardingResponse> => {
    const response = await api.post('/onboarding/start');
    return response.data;
  },

  sendMessage: async (content: string): Promise<OnboardingResponse> => {
    const response = await api.post('/onboarding/message', { content });
    return response.data;
  },

  getMessages: async (): Promise<OnboardingResponse> => {
    const response = await api.get('/onboarding/messages');
    return response.data;
  },

  complete: async (): Promise<OnboardingResponse> => {
    const response = await api.post('/onboarding/complete');
    return response.data;
  },
};
