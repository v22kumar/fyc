import type { Metadata } from 'next';
import { Toaster } from 'react-hot-toast';
import './globals.css';

export const metadata: Metadata = {
  title: 'FYC Admin',
  description: 'Friends Youth Club — Admin Triage Dashboard',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Toaster position="top-center" toastOptions={{ duration: 3000, style: { background: '#333', color: '#fff', fontSize: '14px', borderRadius: '8px' } }} />
        {children}
      </body>
    </html>
  );
}
