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

export interface CommunityProfile {
  id: string;
  user_id: string;
  category: string;
  business_name_ta: string | null;
  business_name_en: string | null;
  description_ta: string | null;
  description_en: string | null;
  contact_phone: string | null;
  contact_whatsapp: string | null;
  service_area: string | null;
  years_experience: number | null;
  is_available: boolean;
  is_verified: boolean;
  full_name_en: string | null;
  full_name_ta: string | null;
}

export interface Tournament {
  id: string;
  name_ta: string;
  name_en: string;
  sport: string;
  year: number;
  format: string;
  status: string;
  description_ta: string | null;
  description_en: string | null;
}

export interface Team {
  id: string;
  tournament_id: string;
  name: string;
  captain_name: string | null;
  contact_phone: string | null;
  wins: number;
  losses: number;
  draws: number;
  points: number;
  is_fyc_team: boolean;
  status: string;
}

export interface Fixture {
  id: string;
  tournament_id: string;
  team_a_id: string;
  team_b_id: string;
  team_a_name: string | null;
  team_b_name: string | null;
  match_number: number | null;
  scheduled_at: string | null;
  venue: string | null;
  status: string;
  team_a_score: string | null;
  team_b_score: string | null;
  winner_id: string | null;
  result_notes: string | null;
}

export interface ChallengeMatch {
  id: string;
  challenger_team_name: string;
  challenger_captain: string;
  challenger_phone: string;
  sport: string;
  proposed_date: string | null;
  venue: string | null;
  message: string | null;
  status: string;
  admin_response: string | null;
}

export interface MembershipCard {
  id: string;
  user_id: string;
  membership_number: string;
  qr_code_payload: string;
  status: string;
  designation_ta: string;
  designation_en: string;
  issued_at: string | null;
  expires_at: string;
}
