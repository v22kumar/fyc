import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#064e3b',
          50:  '#ecfdf5',
          100: '#d1fae5',
          600: '#059669',
          700: '#047857',
          800: '#065f46',
          900: '#064e3b',
        },
        accent: {
          DEFAULT: '#991b1b',
          100: '#fee2e2',
          600: '#dc2626',
          700: '#b91c1c',
          800: '#991b1b',
        },
      },
      borderRadius: { card: '12px' },
    },
  },
  plugins: [],
};

export default config;
