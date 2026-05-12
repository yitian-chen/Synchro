import api from './client';
import type { Province, City } from '../types';

export const locationApi = {
  getProvinces: async (): Promise<Province[]> => {
    const response = await api.get('/locations/provinces');
    return response.data;
  },

  getCities: async (provinceId: number): Promise<City[]> => {
    const response = await api.get('/locations/cities', { params: { provinceId } });
    return response.data;
  },
};
