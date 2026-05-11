import api from './client';
import type { Profile } from '../types';

export const userApi = {
  getProfile: async (): Promise<Profile> => {
    const response = await api.get('/users/me');
    return response.data;
  },

  updateProfile: async (data: Partial<Profile>): Promise<Profile> => {
    const response = await api.put('/users/me', data);
    return response.data;
  },

  updateAvatar: async (file: File): Promise<{ avatarUrl: string }> => {
    const formData = new FormData();
    formData.append('file', file);
    const response = await api.put('/users/me/avatar', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return response.data;
  },

  resetOnboarding: async (): Promise<void> => {
    await api.post('/onboarding/reset');
  },
};
