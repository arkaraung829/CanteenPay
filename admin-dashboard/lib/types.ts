export type UserRole = 'student' | 'parent' | 'seller' | 'admin' | 'super_admin' | 'counter_staff';
export type TransactionType = 'deposit' | 'purchase' | 'refund' | 'adjustment';

export interface School {
  id: string;
  name: string;
  name_my?: string;
  code: string;
  address?: string;
  phone?: string;
  logo_url?: string;
  is_active: boolean;
  settings: Record<string, unknown>;
  created_at: string;
}

export interface Profile {
  id: string;
  role: UserRole;
  school_id?: string;
  full_name: string;
  full_name_my?: string;
  phone?: string;
  avatar_url?: string;
  is_active: boolean;
  fcm_token?: string;
  locale: string;
  created_at: string;
}

export interface Student {
  id: string;
  profile_id?: string;
  school_id: string;
  student_code: string;
  qr_data: string;
  full_name: string;
  full_name_my?: string;
  class_name?: string;
  grade?: string;
  enrollment_year?: number;
  photo_url?: string;
  is_active: boolean;
  daily_spending_limit?: number;
  created_at: string;
  // Joined fields
  wallet?: Wallet;
}

export interface Wallet {
  id: string;
  student_id: string;
  balance: number;
  currency: string;
  is_frozen: boolean;
  updated_at: string;
}

export interface Transaction {
  id: string;
  wallet_id: string;
  type: TransactionType;
  amount: number;
  balance_before: number;
  balance_after: number;
  description?: string;
  reference_id?: string;
  performed_by?: string;
  seller_id?: string;
  metadata: Record<string, unknown>;
  created_at: string;
  // Joined fields
  performer?: Profile;
  seller?: CanteenSeller;
  wallet?: Wallet & { student?: Student };
}

export interface CanteenSeller {
  id: string;
  profile_id: string;
  school_id: string;
  stall_name: string;
  stall_name_my?: string;
  stall_number?: string;
  is_active: boolean;
  created_at: string;
  profile?: Profile;
}

export interface Announcement {
  id: string;
  school_id: string;
  author_id: string;
  title: string;
  title_my?: string;
  body: string;
  body_my?: string;
  target_audience: string[];
  is_published: boolean;
  published_at?: string;
  expires_at?: string;
  created_at: string;
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  pagination?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
    hasMore: boolean;
  };
}

export function formatMMK(amount: number): string {
  return `${amount.toLocaleString()} MMK`;
}
