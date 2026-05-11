import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { userApi } from '../api/user';
import { matchApi } from '../api/match';
import type { Profile, Match, User } from '../types';

const DashboardPage: React.FC = () => {
  const { user, logout, setUser } = useAuth();
  const navigate = useNavigate();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [currentMatch, setCurrentMatch] = useState<Match | null>(null);
  const [isResetting, setIsResetting] = useState(false);

  useEffect(() => {
    loadProfile();
    loadMatch();
  }, []);

  const loadProfile = async () => {
    try {
      const data = await userApi.getProfile();
      setProfile(data);
      // 同步用户状态到 AuthContext，避免 localStorage 数据与服务端不一致
      const userFromServer: User = {
        id: data.userId,
        email: data.email,
        nickname: data.nickname,
        avatarUrl: data.avatarUrl,
        status: data.status as any,
        onboardingCompleted: data.onboardingCompleted,
      };
      setUser(userFromServer);
      localStorage.setItem('user', JSON.stringify(userFromServer));
    } catch (err) {
      console.error('Failed to load profile:', err);
    }
  };

  const loadMatch = async () => {
    try {
      const match = await matchApi.getCurrentMatch();
      setCurrentMatch(match);
    } catch (err) {
      console.error('Failed to load match:', err);
    }
  };

  const startChat = async () => {
    if (!currentMatch) return;
    try {
      const { conversationId } = await matchApi.createConversation(currentMatch.matchId);
      navigate(`/chat/${conversationId}`);
    } catch (err) {
      console.error('Failed to create conversation:', err);
    }
  };

  const handleResetOnboarding = async () => {
    if (!window.confirm('确定要重新开始AI访谈吗？这将清除你的性格特质摘要。')) {
      return;
    }
    try {
      setIsResetting(true);
      await userApi.resetOnboarding();
      navigate('/onboarding');
    } catch (err) {
      console.error('Failed to reset onboarding:', err);
      alert('重置失败，请稍后重试');
    } finally {
      setIsResetting(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="gradient-bg p-4">
        <div className="max-w-2xl mx-auto flex justify-between items-center">
          <h1 className="text-xl font-heading font-bold text-white">Synchro</h1>
          <div className="flex items-center space-x-4">
            <span className="text-white text-sm">{user?.nickname}</span>
            <button
              onClick={logout}
              className="text-white text-sm hover:underline"
            >
              退出
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-2xl mx-auto p-4 space-y-6">
        {/* Profile Card */}
        <div className="card">
          <div className="flex items-center space-x-4">
            <div className="w-16 h-16 rounded-full bg-primary flex items-center justify-center text-white text-2xl font-bold">
              {user?.nickname?.[0]?.toUpperCase()}
            </div>
            <div>
              <h2 className="text-lg font-semibold">{profile?.nickname || user?.nickname}</h2>
              <p className="text-sm text-gray-500">{profile?.bio || '还没有自我介绍'}</p>
            </div>
          </div>
        </div>

        {/* Current Match Card */}
        {currentMatch ? (
          <div className="card border-2 border-secondary">
            <div className="text-center">
              <h3 className="text-sm text-secondary font-semibold mb-2">本周匹配</h3>
              <div className="w-20 h-20 mx-auto rounded-full bg-secondary flex items-center justify-center text-white text-2xl font-bold mb-2">
                {currentMatch.user1Id === user?.id
                  ? currentMatch.user2Nickname?.[0]?.toUpperCase()
                  : currentMatch.user1Nickname?.[0]?.toUpperCase()}
              </div>
              <p className="font-semibold">
                {currentMatch.user1Id === user?.id
                  ? currentMatch.user2Nickname
                  : currentMatch.user1Nickname}
              </p>
              <p className="text-sm text-gray-500 mb-4">
                匹配度: {Math.round(currentMatch.compatibilityScore * 100)}%
              </p>
              <button onClick={startChat} className="btn-secondary w-full">
                开始聊天
              </button>
            </div>
          </div>
        ) : (
          <div className="card text-center">
            <div className="w-16 h-16 mx-auto rounded-full bg-gray-200 flex items-center justify-center text-gray-400 text-2xl mb-4">
              ?
            </div>
            <p className="text-gray-500">本周还没有匹配</p>
            <p className="text-sm text-gray-400">每周五18:00 UTC自动匹配</p>
          </div>
        )}

        {/* Traits Summary */}
        {profile?.traitsSummary && (
          <div className="card">
            <h3 className="font-semibold mb-2">你的特质</h3>
            <div className="flex flex-wrap gap-2">
              {(() => {
                try {
                  const parsed = JSON.parse(profile.traitsSummary || '{}');
                  const traits = parsed.traits || parsed;
                  if (Array.isArray(traits)) {
                    return traits.map((trait: any) => (
                      <span
                        key={typeof trait === 'string' ? trait : trait.name}
                        className="px-3 py-1 bg-accent rounded-full text-sm"
                      >
                        {typeof trait === 'string' ? trait : `${trait.name}: ${Math.round((trait.value || 0) * 100)}%`}
                      </span>
                    ));
                  }
                  return null;
                } catch {
                  return null;
                }
              })()}
            </div>
          </div>
        )}

        {/* Reset Onboarding - 显示给所有未完成onboarding的用户 */}
        {(user?.status === 'PENDING_ONBOARDING' || !user?.onboardingCompleted) && (
          <div className="card border-2 border-red-300">
            <h3 className="font-semibold mb-2 text-red-600">重新开始访谈</h3>
            <p className="text-sm text-gray-500 mb-4">
              重置将清除你的性格特质摘要，你可以重新开始AI访谈流程。
            </p>
            <button
              onClick={handleResetOnboarding}
              disabled={isResetting}
              className="btn-secondary w-full bg-red-50 hover:bg-red-100 text-red-600 disabled:opacity-50"
            >
              {isResetting ? '重置中...' : '重新开始AI访谈'}
            </button>
          </div>
        )}
      </main>
    </div>
  );
};

export default DashboardPage;
