import api from './client';
import type { AuthResponse } from '../types';

export const authApi = {
  register: async (email: string, password: string, nickname: string): Promise<AuthResponse> => {
    const response = await api.post('/auth/register', { email, password, nickname });
    return response.data;
  },

  login: async (email: string, password: string): Promise<AuthResponse> => {
    const response = await api.post('/auth/login', { email, password });
    return response.data;
  },

  refresh: async (refreshToken: string): Promise<{ accessToken: string }> => {
    const response = await api.post('/auth/refresh', { refreshToken });
    return response.data;
  },

  logout: async (): Promise<void> => {
    const refreshToken = localStorage.getItem('refreshToken');
    await api.post('/auth/logout', { refreshToken });
  },
};
