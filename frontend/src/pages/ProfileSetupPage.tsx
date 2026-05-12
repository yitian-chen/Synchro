import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { userApi } from '../api/user';
import LocationPicker from '../components/LocationPicker';

type Gender = 'MALE' | 'FEMALE' | 'OTHER';

const OnboardingInviteModal: React.FC<{
  onAccept: () => void;
  onDecline: () => void;
}> = ({ onAccept, onDecline }) => (
  <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <div className="card w-full max-w-sm mx-4">
      <h2 className="text-xl font-heading font-bold text-center mb-2">开始了解你自己</h2>
      <p className="text-gray-500 text-sm text-center mb-6">
        通过一段简短的 AI 访谈，我们能更精准地为你匹配志同道合的人。只需几分钟。
      </p>
      <button onClick={onAccept} className="btn-primary w-full mb-3">
        立即开始访谈
      </button>
      <button
        onClick={onDecline}
        className="w-full py-2 text-sm text-gray-500 hover:text-gray-700"
      >
        稍后再说
      </button>
    </div>
  </div>
);

const ProfileSetupPage: React.FC = () => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const [bio, setBio] = useState('');
  const [age, setAge] = useState('');
  const [gender, setGender] = useState<Gender | ''>('');
  const [location, setLocation] = useState('');
  const [cityId, setCityId] = useState<number | undefined>();
  const [idealPartnerDescription, setIdealPartnerDescription] = useState('');
  const [matchingPreference, setMatchingPreference] = useState<'SIMILAR' | 'COMPLEMENTARY' | 'BALANCED'>('BALANCED');
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [showModal, setShowModal] = useState(false);

  useEffect(() => {
    const checkProfile = async () => {
      try {
        const profile = await userApi.getProfile();
        const needsSetup =
          profile.bio == null &&
          profile.age == null &&
          profile.gender == null &&
          profile.location == null;

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
    if (!bio.trim()) {
      newErrors.bio = '请填写自我介绍';
    } else if (bio.length > 500) {
      newErrors.bio = '自我介绍不超过 500 字';
    }
    if (!age) {
      newErrors.age = '请填写年龄';
    } else {
      const ageNum = parseInt(age, 10);
      if (isNaN(ageNum) || ageNum < 18 || ageNum > 100) {
        newErrors.age = '年龄需在 18 到 100 之间';
      }
    }
    if (!gender) newErrors.gender = '请选择性别';
    if (!cityId) {
      newErrors.location = '请选择所在地';
    }
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;

    setIsSubmitting(true);
    try {
      await userApi.updateProfile({
        bio: bio.trim(),
        age: parseInt(age, 10),
        gender: gender as Gender,
        location: location.trim(),
        cityId,
        idealPartnerDescription: idealPartnerDescription.trim() || undefined,
        matchingPreference,
      });
      setShowModal(true);
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
          <h1 className="text-xl font-heading font-bold text-white">完善个人信息</h1>
          <p className="text-sm text-white opacity-80">让大家更好地了解你</p>
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
                自我介绍 <span className="text-red-500">*</span>
              </label>
              <textarea
                value={bio}
                onChange={(e) => setBio(e.target.value)}
                rows={3}
                maxLength={500}
                placeholder="简单介绍一下自己..."
                className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-primary focus:border-primary resize-none"
              />
              <div className="flex justify-between mt-1">
                {errors.bio ? (
                  <p className="text-red-500 text-xs">{errors.bio}</p>
                ) : (
                  <span />
                )}
                <span className="text-xs text-gray-400">{bio.length}/500</span>
              </div>
            </div>

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

            {/* 意向对象描述 */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                你理想中的伴侣是什么样的人？
              </label>
              <textarea
                value={idealPartnerDescription}
                onChange={(e) => setIdealPartnerDescription(e.target.value)}
                rows={4}
                placeholder="描述你理想中的伴侣的性格、生活方式、价值观等..."
                className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-primary focus:border-primary resize-none"
              />
              <div className="flex justify-between mt-1">
                {errors.idealPartnerDescription ? (
                  <p className="text-red-500 text-xs">{errors.idealPartnerDescription}</p>
                ) : (
                  <span />
                )}
                <span className="text-xs text-gray-400">{idealPartnerDescription.length}/1000</span>
              </div>
            </div>

            {/* 匹配偏好 */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                你希望对方和你？
              </label>
              <div className="flex gap-3">
                {[
                  { value: 'SIMILAR' as const, label: '更相似' },
                  { value: 'COMPLEMENTARY' as const, label: '更互补' },
                  { value: 'BALANCED' as const, label: '都可以' },
                ].map((opt) => (
                  <button
                    key={opt.value}
                    type="button"
                    onClick={() => setMatchingPreference(opt.value)}
                    className={`flex-1 py-2 rounded-lg border text-sm font-medium transition-colors ${
                      matchingPreference === opt.value
                        ? 'bg-primary text-white border-primary'
                        : 'bg-white text-gray-600 border-gray-300 hover:border-primary'
                    }`}
                  >
                    {opt.label}
                  </button>
                ))}
              </div>
            </div>

            {errors.submit && (
              <p className="text-red-500 text-sm text-center">{errors.submit}</p>
            )}

            <button type="submit" disabled={isSubmitting} className="btn-primary w-full">
              {isSubmitting ? '保存中...' : '保存并继续'}
            </button>
          </form>
        </div>
      </div>

      {showModal && (
        <OnboardingInviteModal
          onAccept={() => navigate('/onboarding')}
          onDecline={() => navigate('/dashboard')}
        />
      )}
    </div>
  );
};

export default ProfileSetupPage;
