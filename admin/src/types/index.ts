export type IssueStatus =
  | 'NEW'
  | 'ASSIGNED'
  | 'UNDER_REVIEW'
  | 'ESCALATED'
  | 'RESOLVED'
  | 'CLOSED'
  | 'REJECTED';

export type IssueCategory =
  | 'ROAD'
  | 'WATER'
  | 'STREET_LIGHT'
  | 'GARBAGE'
  | 'SAFETY'
  | 'OTHER';

export interface Issue {
  id: string;
  category: IssueCategory;
  description_ta: string;
  description_en: string;
  latitude: number;
  longitude: number;
  photo_url: string | null;
  verification_photo_url: string | null;
  status: IssueStatus;
  assigned_volunteer_id: string | null;
  reported_by_user_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface Event {
  id: string;
  title_ta: string;
  title_en: string;
  description_ta: string;
  description_en: string;
  event_start: string;
  event_end: string;
  banner_url: string | null;
  created_by_user_id: string | null;
  created_at: string;
}

export interface Member {
  id: string;
  phone_number: string;
  role: string;
  is_verified: boolean;
  preferred_language: string;
  full_name_ta: string | null;
  full_name_en: string | null;
}

export interface AuthUser {
  id: string;
  phone_number: string;
  role: string;
  is_verified: boolean;
  preferred_language: string;
}

export const VALID_TRANSITIONS: Record<IssueStatus, IssueStatus[]> = {
  NEW:          ['ASSIGNED', 'REJECTED'],
  ASSIGNED:     ['UNDER_REVIEW', 'ESCALATED'],
  UNDER_REVIEW: ['RESOLVED', 'ESCALATED'],
  ESCALATED:    ['UNDER_REVIEW', 'RESOLVED'],
  RESOLVED:     ['CLOSED'],
  CLOSED:       [],
  REJECTED:     [],
};

export const STATUS_LABELS: Record<IssueStatus, string> = {
  NEW:          'New',
  ASSIGNED:     'Assigned',
  UNDER_REVIEW: 'Under Review',
  ESCALATED:    'Escalated',
  RESOLVED:     'Resolved',
  CLOSED:       'Closed',
  REJECTED:     'Rejected',
};

export const CATEGORY_LABELS: Record<IssueCategory, string> = {
  ROAD:         'Road',
  WATER:        'Water',
  STREET_LIGHT: 'Street Light',
  GARBAGE:      'Garbage',
  SAFETY:       'Safety',
  OTHER:        'Other',
};
