import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { userApi } from '../api/user';

const PostOnboardingPage: React.FC = () => {
  const { logout } = useAuth();
  const navigate = useNavigate();

  const [bio, setBio] = useState('');
  const [idealPartnerDescription, setIdealPartnerDescription] = useState('');
  const [matchingPreference, setMatchingPreference] = useState<'SIMILAR' | 'COMPLEMENTARY' | 'BALANCED'>('BALANCED');
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});

  useEffect(() => {
    const loadProfile = async () => {
      try {
        const profile = await userApi.getProfile();
        if (profile.bio) setBio(profile.bio);
        if (profile.idealPartnerDescription) setIdealPartnerDescription(profile.idealPartnerDescription);
        if (profile.matchingPreference) setMatchingPreference(profile.matchingPreference);
      } catch (err) {
        console.error('Failed to load profile:', err);
      } finally {
        setIsLoading(false);
      }
    };
    loadProfile();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      await userApi.updateProfile({
        bio: bio.trim() || undefined,
        idealPartnerDescription: idealPartnerDescription.trim() || undefined,
        matchingPreference,
      });
      navigate('/dashboard');
    } catch (err) {
      console.error('Failed to save:', err);
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
          <h1 className="text-xl font-heading font-bold text-white">完善个人资料</h1>
          <p className="text-sm text-white opacity-80">AI 访谈完成！检查和补充你的资料</p>
        </div>
        <button onClick={logout} className="text-white text-sm hover:underline">
          退出
        </button>
      </div>

      <div className="flex-1 flex items-start justify-center p-4 pt-8">
        <div className="card w-full max-w-md">
          <div className="text-center mb-6">
            <div className="text-3xl mb-2">✨</div>
            <p className="text-sm text-gray-500">
              AI 在访谈中根据你的回答生成了以下内容，你可以修改或补充。
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5" noValidate>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                自我介绍
                {bio && <span className="text-xs text-green-600 ml-1">（AI 已生成）</span>}
              </label>
              <textarea
                value={bio}
                onChange={(e) => setBio(e.target.value)}
                rows={4}
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
                理想伴侣描述
                {idealPartnerDescription && <span className="text-xs text-green-600 ml-1">（AI 已生成）</span>}
              </label>
              <textarea
                value={idealPartnerDescription}
                onChange={(e) => setIdealPartnerDescription(e.target.value)}
                rows={4}
                maxLength={1000}
                placeholder="你理想中的伴侣是什么样的？"
                className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-primary focus:border-primary resize-none"
              />
              <div className="flex justify-between mt-1">
                <span />
                <span className="text-xs text-gray-400">{idealPartnerDescription.length}/1000</span>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                你希望对方和你？
              </label>
              <div className="flex gap-3">
                {[
                  { value: 'SIMILAR' as const, label: '更相似', desc: '志趣相投' },
                  { value: 'COMPLEMENTARY' as const, label: '更互补', desc: '性格互补' },
                  { value: 'BALANCED' as const, label: '平衡', desc: '两者兼顾' },
                ].map((opt) => (
                  <button
                    key={opt.value}
                    type="button"
                    onClick={() => setMatchingPreference(opt.value)}
                    className={`flex-1 py-3 rounded-lg border text-center transition-colors ${
                      matchingPreference === opt.value
                        ? 'bg-primary text-white border-primary'
                        : 'bg-white text-gray-600 border-gray-300 hover:border-primary'
                    }`}
                  >
                    <div className="text-sm font-medium">{opt.label}</div>
                    <div
                      className={`text-xs ${
                        matchingPreference === opt.value ? 'text-white opacity-80' : 'text-gray-400'
                      }`}
                    >
                      {opt.desc}
                    </div>
                  </button>
                ))}
              </div>
            </div>

            {errors.submit && (
              <p className="text-red-500 text-sm text-center">{errors.submit}</p>
            )}

            <button type="submit" disabled={isSubmitting} className="btn-primary w-full">
              {isSubmitting ? '保存中...' : '完成，进入主页'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default PostOnboardingPage;
