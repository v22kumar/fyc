import type { IssueStatus } from '@/types';

const STYLES: Record<IssueStatus, string> = {
  NEW:          'bg-blue-100   text-blue-800',
  ASSIGNED:     'bg-yellow-100 text-yellow-800',
  UNDER_REVIEW: 'bg-orange-100 text-orange-800',
  ESCALATED:    'bg-red-100    text-red-800',
  RESOLVED:     'bg-green-100  text-green-800',
  CLOSED:       'bg-gray-100   text-gray-600',
  REJECTED:     'bg-slate-100  text-slate-600',
};

const LABELS: Record<IssueStatus, string> = {
  NEW:          'New',
  ASSIGNED:     'Assigned',
  UNDER_REVIEW: 'Under Review',
  ESCALATED:    'Escalated',
  RESOLVED:     'Resolved',
  CLOSED:       'Closed',
  REJECTED:     'Rejected',
};

export default function StatusBadge({ status }: { status: IssueStatus }) {
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold ${STYLES[status]}`}>
      {LABELS[status]}
    </span>
  );
}
