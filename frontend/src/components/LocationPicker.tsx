import React, { useState, useEffect } from 'react';
import { locationApi } from '../api/location';
import type { Province, City } from '../types';

interface LocationPickerProps {
  defaultCityId?: number;
  onChange: (cityId: number | undefined, locationLabel: string) => void;
  error?: string;
}

const LocationPicker: React.FC<LocationPickerProps> = ({ defaultCityId, onChange, error }) => {
  const [provinces, setProvinces] = useState<Province[]>([]);
  const [cities, setCities] = useState<City[]>([]);
  const [selectedProvinceId, setSelectedProvinceId] = useState<number | ''>('');
  const [selectedCityId, setSelectedCityId] = useState<number | ''>('');
  const [isLoadingProvinces, setIsLoadingProvinces] = useState(true);
  const [isLoadingCities, setIsLoadingCities] = useState(false);
  const [hasInitialized, setHasInitialized] = useState(false);

  // Load provinces on mount
  useEffect(() => {
    const loadProvinces = async () => {
      try {
        const data = await locationApi.getProvinces();
        setProvinces(data);
      } catch (err) {
        console.error('Failed to load provinces:', err);
      } finally {
        setIsLoadingProvinces(false);
      }
    };
    loadProvinces();
  }, []);

  // Load cities when province changes
  useEffect(() => {
    if (!selectedProvinceId) {
      setCities([]);
      return;
    }
    const loadCities = async () => {
      setIsLoadingCities(true);
      try {
        const data = await locationApi.getCities(selectedProvinceId as number);
        setCities(data);
      } catch (err) {
        console.error('Failed to load cities:', err);
      } finally {
        setIsLoadingCities(false);
      }
    };
    loadCities();
  }, [selectedProvinceId]);

  // Initialize from defaultCityId once provinces are loaded
  useEffect(() => {
    if (hasInitialized || !defaultCityId || provinces.length === 0) return;

    // We need to find which province this city belongs to
    // Load all city data for all provinces to find the matching city
    const initFromCityId = async () => {
      // Try to find the city by searching through all provinces
      for (const province of provinces) {
        try {
          const cityList = await locationApi.getCities(province.id);
          const match = cityList.find(c => c.id === defaultCityId);
          if (match) {
            setSelectedProvinceId(province.id);
            setCities(cityList);
            setSelectedCityId(match.id);
            setHasInitialized(true);
            return;
          }
        } catch {
          continue;
        }
      }
      setHasInitialized(true);
    };

    initFromCityId();
  }, [provinces, defaultCityId, hasInitialized]);

  const handleProvinceChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const value = e.target.value;
    const provinceId = value ? parseInt(value, 10) : '';
    setSelectedProvinceId(provinceId);
    setSelectedCityId('');
    onChange(undefined, '');
  };

  const handleCityChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const value = e.target.value;
    if (!value) {
      setSelectedCityId('');
      onChange(undefined, '');
      return;
    }
    const cityIdVal = parseInt(value, 10);
    setSelectedCityId(cityIdVal);

    const province = provinces.find((p) => p.id === selectedProvinceId);
    const city = cities.find((c) => c.id === cityIdVal);
    const label = province && city ? `${province.name} ${city.name}` : '';
    onChange(cityIdVal, label);
  };

  return (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-1">
        所在地 <span className="text-red-500">*</span>
      </label>
      <div className="flex gap-3">
        <select
          value={selectedProvinceId}
          onChange={handleProvinceChange}
          disabled={isLoadingProvinces}
          className={`flex-1 px-4 py-2 border rounded-lg focus:ring-2 focus:ring-primary focus:border-primary bg-white ${
            error ? 'border-red-500' : ''
          }`}
        >
          <option value="">
            {isLoadingProvinces ? '加载中...' : '选择省份'}
          </option>
          {provinces.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>

        <select
          value={selectedCityId}
          onChange={handleCityChange}
          disabled={!selectedProvinceId || isLoadingCities}
          className={`flex-1 px-4 py-2 border rounded-lg focus:ring-2 focus:ring-primary focus:border-primary bg-white ${
            error ? 'border-red-500' : ''
          }`}
        >
          <option value="">
            {!selectedProvinceId
              ? '请先选择省份'
              : isLoadingCities
                ? '加载中...'
                : '选择城市'}
          </option>
          {cities.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
      </div>
      {error && <p className="text-red-500 text-xs mt-1">{error}</p>}
    </div>
  );
};

export default LocationPicker;
