# Changelog

All notable changes to the MyAnimes project are documented in this file.

---

## [1.2.1] - 2026-09-25

### 🌟 New Features & Enhancements

#### ⭐ Expanded Rating System (Dialogues & Main Idea)
- **New Rating Criteria**: Added dedicated rating bars for **"Dialogues"** and **"Main Idea"** alongside Story, Character, Draw, Animation, and Music.
- **Dynamic Real-Time Calculation**: Sub-ratings now recalculate and update the overall anime rating immediately upon adjusting any slider or numerical score.
- **Selective Average (Zero-Exclusion)**: Unrated criteria (score of `0`) are excluded from the calculation, ensuring that unrated dimensions do not penalize or skew the overall score.
- **Full Backward Compatibility**: Enhanced Hive schema with zero-default values and complete import/export serialization.
- **Responsive Wrap UI**: Rating pills in anime and manga details automatically adapt across mobile and desktop displays without overflow.

#### 📱 Mobile Anime Wrapped Fix
- **Resolved Black Screen on Physical Mobile**: Eliminated an unconstrained flex layout bug where desktop container dimensions conflicted with mobile boundaries, restoring the full annual story swiper experience on all Android devices.

---

## [1.2.0] - 2026-09-24

### 🌟 New Features & Major Highlights

#### 🎬 Anime Wrapped (Year in Review)
- **Comprehensive Annual Statistics**: Discover total episodes watched, total hours and days logged, and completion percentages.
- **Top Genres & Studio Powerhouses**: Visual breakdowns and ranked leaderboards for animation studios (Ufotable, MAPPA, Bones, etc.) and favorite genres.
- **Hall of Fame**: Showcase highest-rated masterpieces and personal rated favorites.
- **Anime Persona Profiler**: Calculates an archetype/persona (e.g. *Anime Connoisseur*) tailored to your unique watch history and tastes.
- **Sharable High-Res Story Cards**: Export and share elegant 9:16 story cards to social platforms or download them directly.

#### 🪟 Windows Desktop Experience & UI/UX Revamp
- **Dedicated Desktop Card Story Mode**: Redesigned Anime Wrapped for wide screens with centered card view, dark glassmorphism, glowing ambient aura, and zero overflow errors on all desktop resolutions.
- **Full Keyboard Navigation**:
  - `[Right Arrow]` / `[Space]` : Advance to next story slide.
  - `[Left Arrow]` : Return to previous story slide.
  - `[Escape]` : Close story / return to application.
- **Direct Save File Dialog**: Replaced mobile gallery save with native Windows file picker (`FilePicker.platform.saveFile`) across all image exports (Wrapped card, anime cards, gallery pictures, and layered spectrum lists). Added an immediate **"Open Folder"** action to locate saved files in Windows Explorer.
- **Desktop Navigation & Layout Polish**:
  - Removed duplicate "Settings" titles in the desktop settings view.
  - Restyled desktop search pill with proper icon constraints, centered vertical baseline, and clean placeholder padding for titles like *"Chainsaw Man"*.
  - Added desktop next/previous hover buttons on either side of the story canvas.

#### ⚡ Download Engine & Ad-Bypass Pipeline
- **Workupload Direct API Resolver**: Replaced webview DOM scraping with direct `workupload.com/api/file/getDownloadServer/<id>` API resolution, ensuring instant download link retrieval without hosting-page redirects.
- **Smart Window Proxy & Popup Blocker**: Intercepts intrusive popunder tabs, blank window redirects, and fake ad overlays while preserving genuine download triggers.
- **Anti-Ad Overlay Cleaner**: Automatically dismantles transparent clicktrap covers and high-z-index deceptive overlays.
- **Download Guard & Host Page Rejection**: Protects the download manager against downloading raw HTML landing pages, guaranteeing valid media file streams.

#### ☁️ Cloud Sync & Account Integration
- **MyAnimeList (MAL) Authentication**: OAuth2 integration to sync watchlists, episode progress, and user profile data seamlessly.
- **Google Drive Backup & Restore**: Effortlessly backup local database, custom ratings, and watch lists to your personal Google Drive, with instant one-click restoration.

#### 📂 Local Anime Library & MediaKit Player
- **Local Directory Scanner**: Scan any folder on your PC (e.g., `B:\Animes`) to detect, organize, and match episodes with cover art and synopsis.
- **Hardware-Accelerated Video Player**: Built-in video player powered by `media_kit` with support for high-bitrate video, subtitles, and audio tracks.

#### 🎨 Customization & Localization
- **Theme Packs**: Select from curated themes including *Midnight Abyss*, *Cyber Neon*, and *Solar Light*.
- **Bilingual Interface**: Seamless switching between English and Arabic with full RTL support.

---

## [1.1.70] - 2026-07-15
- Initial desktop layout with Windows navigation rail.
- Added WitAnime integration and video streaming extractor.
- Added layered tier spectrum cards and export feature.
- Implemented basic offline database caching with Hive.
