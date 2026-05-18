export interface User {
  id: number;
  email: string;
  nickname: string;
  avatarUrl?: string;
  status: 'PENDING_ONBOARDING' | 'ACTIVE' | 'SUSPENDED';
  onboardingCompleted: boolean;
  matchingOptIn: boolean;
}

export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: User;
  redirectUrl?: string;
}

export interface Profile {
  userId: number;
  email: string;
  nickname: string;
  avatarUrl?: string;
  status: string;
  onboardingCompleted: boolean;
  matchingOptIn: boolean;
  bio?: string;
  age?: number;
  gender?: 'MALE' | 'FEMALE' | 'OTHER';
  location?: string;
  cityId?: number;
  provinceName?: string;
  cityName?: string;
  traitsSummary?: string;
  idealPartnerDescription?: string;
  matchingPreference?: 'SIMILAR' | 'COMPLEMENTARY' | 'BALANCED';
  postOnboardingCompleted?: boolean;
}

export interface Province {
  id: number;
  name: string;
}

export interface City {
  id: number;
  provinceId: number;
  name: string;
}

export interface OnboardingMessage {
  id: number;
  senderType: 'USER' | 'AI';
  content: string;
  extractedTraits?: string[];
  createdAt: string;
}

export interface OnboardingResponse {
  conversation: {
    id: number;
    type: 'ONBOARDING' | 'MATCH';
    status: 'ACTIVE' | 'COMPLETED' | 'ARCHIVED';
    createdAt: string;
  };
  messages: OnboardingMessage[];
  exchangeCount: number;
  isComplete: boolean;
  redirectUrl?: string;
}

export interface Match {
  matchId: number;
  user1Id: number;
  user2Id: number;
  user1Nickname: string;
  user2Nickname: string;
  user1AvatarUrl?: string;
  user2AvatarUrl?: string;
  matchWeek: string;
  compatibilityScore: number;
  matchReason?: string;
  status: 'PENDING' | 'ACTIVE' | 'EXPIRED' | 'REMATCHED';
  createdAt: string;
}

export interface MatchAskResponse {
  answer: string;
}

export interface Conversation {
  id: number;
  type: 'ONBOARDING' | 'MATCH';
  participantId: number;
  participantNickname?: string;
  participantAvatarUrl?: string;
  matchId?: number;
  title?: string;
  status: 'ACTIVE' | 'COMPLETED' | 'ARCHIVED';
  lastMessage?: {
    id: number;
    senderType: 'USER' | 'AI';
    content: string;
    createdAt: string;
  };
  unreadCount: number;
  createdAt: string;
}

export interface ChatMessage {
  id: number;
  senderId?: number;
  senderType: 'USER' | 'AI';
  content: string;
  createdAt: string;
}
