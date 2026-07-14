# 🌟 MyAnimes - The Ultimate Anime Companion

[![GitHub release](https://img.shields.io/github/v/release/LOMoriartyVE/myanimes-privacy?color=violet)](https://github.com/LOMoriartyVE/myanimes-privacy/releases)
[![Build & Deploy](https://github.com/LOMoriartyVE/MyAnimes/actions/workflows/deploy.yml/badge.svg)](https://github.com/LOMoriartyVE/MyAnimes/actions/workflows/deploy.yml)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows-rose)](https://github.com/LOMoriartyVE/myanimes-privacy/releases/download/1.1.70/MyAnimes.apk)
[![License: MIT](https://img.shields.io/badge/License-MIT-emerald.svg)](https://opensource.org/licenses/MIT)

**MyAnimes** is a premium, beautifully designed companion tracking application for anime lovers. Utilizing a fast, offline static database of 300 popular MyAnimeList shows, it provides a seamless, advertisement-free experience for organizing your watchlist, tracking current episode progress, and checking release schedules.

This repository hosts both the **Flutter Mobile & Windows client applications** and the **Vite + React interactive landing page**.

---

## 🚀 Key Features

*   **Watchlist Organization**: Intuitively manage your *Watching*, *Completed*, *Planned*, and *Ignored* shows.
*   **Offline First**: Instant response times (<0.1s) powered by an optimized offline database.
*   **Weekly Release Schedule**: Live schedule display pulling real MAL scores, genres, and airing times.
*   **Immersive Detail Pages**: Interactive modal views with comprehensive studio info, rating classifications, and synopsis details.
*   **Premium Aesthetics**: Curated dark and light themes, smooth micro-animations, glassmorphism overlays, and fully responsive grids.
*   **Privacy Centric & Ad-Free**: No third-party advertisements or invasive trackers.

---

## 🌐 Companion Landing Page

The interactive companion web landing page is located in the [`/Website`](./Website) directory.

### Live Demo
🔗 **[myanimes.app](https://LOMoriartyVE.github.io/MyAnimes/)**

### Tech Stack
*   **Core**: React (JSX) + Vite (Supercharged build system)
*   **Styling**: Tailwind CSS + Custom Vanilla CSS for rich glassmorphism textures
*   **Icons**: Lucide React

### Running the Website Locally
1. Navigate to the website directory:
   ```bash
   cd Website
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Start the local development server:
   ```bash
   npm run dev
   ```
4. Build for production:
   ```bash
   npm run build
   ```

---

## 📱 Flutter Client Application

The client app is built using Flutter, targeting Android Mobile and Windows Client.

### Getting Started with Flutter
A few resources to get you started if this is your first Flutter project:
*   [Flutter SDK Installation](https://docs.flutter.dev/get-started/install)
*   [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
*   [Flutter API Reference](https://api.flutter.dev/)

### Building the Client App
1. Get Flutter packages:
   ```bash
   flutter pub get
   ```
2. Run on connected device:
   ```bash
   flutter run
   ```

---

## 🛡️ Privacy & Terms
For detailed legal documentation regarding data safety and application usage:
*   [Privacy Policy](https://lomoriartyve.github.io/myanimes-privacy/privacy.html)
*   [Terms & Conditions](https://lomoriartyve.github.io/myanimes-privacy/terms.html)
