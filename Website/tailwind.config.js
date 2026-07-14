/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./index.jsx",
    "./main.jsx",
  ],
  theme: {
    extend: {
      colors: {
        brandBg: '#090a0f',
        brandSurface: '#151821',
        brandAccent: '#8b5cf6',
        brandPink: '#f43f5e',
        brandGold: '#f59e0b',
        brandText: '#9ca3af',
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
        display: ['Outfit', 'sans-serif'],
      }
    },
  },
  plugins: [],
}
