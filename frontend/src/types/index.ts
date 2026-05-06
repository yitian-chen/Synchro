export interface User {
  id: number;
  email: string;
  nickname: string;
  avatarUrl?: string;
  status: 'PENDING_ONBOARDING' | 'ACTIVE' | 'SUSPENDED';
  onboardingCompleted: boolean;
}

export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: User;
}

export interface Profile {
  userId: number;
  email: string;
  nickname: string;
  avatarUrl?: string;
  status: string;
  onboardingCompleted: boolean;
  bio?: string;
  age?: number;
  gender?: 'MALE' | 'FEMALE' | 'OTHER';
  location?: string;
  preferences?: string;
  compatibilityScore?: number;
  traitsSummary?: string;
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
  status: 'PENDING' | 'ACTIVE' | 'EXPIRED' | 'REMATCHED';
  createdAt: string;
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
  createdAt: string;
}

export interface ChatMessage {
  id: number;
  senderType: 'USER' | 'AI';
  content: string;
  createdAt: string;
}
