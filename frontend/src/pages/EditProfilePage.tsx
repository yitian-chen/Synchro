import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { userApi } from '../api/user';
import LocationPicker from '../components/LocationPicker';

type Gender = 'MALE' | 'FEMALE' | 'OTHER';

const EditProfilePage: React.FC = () => {
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

  useEffect(() => {
    const loadProfile = async () => {
      try {
        const profile = await userApi.getProfile();
        setBio(profile.bio || '');
        setAge(profile.age?.toString() || '');
        setGender((profile.gender as Gender) || '');
        setLocation(profile.location || '');
        setCityId(profile.cityId);
        setIdealPartnerDescription(profile.idealPartnerDescription || '');
        if (profile.matchingPreference) {
          setMatchingPreference(profile.matchingPreference);
        }
      } catch (err) {
        console.error('Failed to load profile:', err);
      } finally {
        setIsLoading(false);
      }
    };
    loadProfile();
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
      navigate('/dashboard');
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
        <div className="flex items-center gap-3">
          <button onClick={() => navigate('/dashboard')} className="text-white text-lg leading-none">
            ←
          </button>
          <div>
            <h1 className="text-xl font-heading font-bold text-white">编辑个人资料</h1>
            <p className="text-sm text-white opacity-80">修改你的个人信息</p>
          </div>
        </div>
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
              defaultCityId={cityId}
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

            <div className="flex gap-3">
              <button
                type="button"
                onClick={() => navigate('/dashboard')}
                className="flex-1 py-2 px-4 border border-gray-300 rounded-lg text-gray-600 hover:bg-gray-50 transition-colors"
              >
                取消
              </button>
              <button type="submit" disabled={isSubmitting} className="btn-primary flex-1">
                {isSubmitting ? '保存中...' : '保存'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};

export default EditProfilePage;
