import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { userApi } from '../api/user';
import LocationPicker from '../components/LocationPicker';

type Gender = 'MALE' | 'FEMALE' | 'OTHER';

const ProfileSetupPage: React.FC = () => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const [age, setAge] = useState('');
  const [gender, setGender] = useState<Gender | ''>('');
  const [location, setLocation] = useState('');
  const [cityId, setCityId] = useState<number | undefined>();
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});

  useEffect(() => {
    const checkProfile = async () => {
      try {
        const profile = await userApi.getProfile();
        const needsSetup =
          profile.age == null &&
          profile.gender == null &&
          profile.cityId == null;

        if (!needsSetup) {
          if (user?.status === 'PENDING_ONBOARDING' || !user?.onboardingCompleted) {
            navigate('/onboarding', { replace: true });
          } else {
            navigate('/dashboard', { replace: true });
          }
          return;
        }
      } catch (err) {
        console.error('Failed to load profile:', err);
      } finally {
        setIsLoading(false);
      }
    };
    checkProfile();
  }, []);

  const validate = (): boolean => {
    const newErrors: Record<string, string> = {};
    if (!age) {
      newErrors.age = '请填写年龄';
    } else {
      const ageNum = parseInt(age, 10);
      if (isNaN(ageNum) || ageNum < 18 || ageNum > 100) {
        newErrors.age = '年龄需在 18 到 100 之间';
      }
    }
    if (!gender) newErrors.gender = '请选择性别';
    if (!cityId) newErrors.location = '请选择所在地';
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;

    setIsSubmitting(true);
    try {
      await userApi.updateProfile({
        age: parseInt(age, 10),
        gender: gender as Gender,
        location: location.trim(),
        cityId,
      });
      navigate('/onboarding');
    } catch (err) {
      console.error('Failed to update profile:', err);
      setErrors({ submit: '保存失败，请稍后重试' });
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <p className="text-gray-500">加载中...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      <div className="gradient-bg p-4 flex items-center justify-between">
        <div>
          <h1 className="text-xl font-heading font-bold text-white">完善基本信息</h1>
          <p className="text-sm text-white opacity-80">完善基础资料，然后开始 AI 访谈</p>
        </div>
        <button onClick={logout} className="text-white text-sm hover:underline">
          退出
        </button>
      </div>

      <div className="flex-1 flex items-start justify-center p-4 pt-8">
        <div className="card w-full max-w-md">
          <form onSubmit={handleSubmit} className="space-y-5" noValidate>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                年龄 <span className="text-red-500">*</span>
              </label>
              <input
                type="number"
                value={age}
                onChange={(e) => setAge(e.target.value)}
                min={18}
                max={100}
                placeholder="18 - 100"
                className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-primary focus:border-primary"
              />
              {errors.age && <p className="text-red-500 text-xs mt-1">{errors.age}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                性别 <span className="text-red-500">*</span>
              </label>
              <div className="flex gap-3">
                {(['MALE', 'FEMALE', 'OTHER'] as const).map((g) => (
                  <button
                    key={g}
                    type="button"
                    onClick={() => setGender(g)}
                    className={`flex-1 py-2 rounded-lg border text-sm font-medium transition-colors ${
                      gender === g
                        ? 'bg-primary text-white border-primary'
                        : 'bg-white text-gray-600 border-gray-300 hover:border-primary'
                    }`}
                  >
                    {g === 'MALE' ? '男' : g === 'FEMALE' ? '女' : '其他'}
                  </button>
                ))}
              </div>
              {errors.gender && <p className="text-red-500 text-xs mt-1">{errors.gender}</p>}
            </div>

            <LocationPicker
              onChange={(newCityId, locationLabel) => {
                setCityId(newCityId);
                setLocation(locationLabel);
              }}
              error={errors.location}
            />

            <p className="text-xs text-gray-400">
              这些信息将不可被 AI 修改，请如实填写。自我介绍和择偶偏好将在 AI 访谈后填写。
            </p>

            {errors.submit && (
              <p className="text-red-500 text-sm text-center">{errors.submit}</p>
            )}

            <button type="submit" disabled={isSubmitting} className="btn-primary w-full">
              {isSubmitting ? '保存中...' : '保存并开始访谈'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default ProfileSetupPage;
