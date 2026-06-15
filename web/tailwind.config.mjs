/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#0F5132',
          50:  '#f0fbf6',
          100: '#dcf7e9',
          200: '#bceecf',
          300: '#8ee0ae',
          400: '#58cc86',
          500: '#198754',
          600: '#136b41',
          700: '#105936',
          800: '#0f5132',
          900: '#0c3f27',
        },
        secondary: {
          DEFAULT: '#198754',
        },
        accent: {
          DEFAULT: '#D4AF37',
          50:  '#fefdf3',
          100: '#fdfae6',
          200: '#faf2bf',
          300: '#f6e689',
          400: '#eed354',
          500: '#d4af37',
          600: '#bc972b',
          700: '#9c7a22',
          800: '#7d5f1d',
          900: '#664e1a',
        },
      },
      borderRadius: {
        card: '16px',
      },
      fontFamily: {
        sans: ['Inter', 'Noto Sans Tamil', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
