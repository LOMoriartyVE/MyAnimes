# Changelog

All notable changes to the MyAnimes project are documented in this file.

---

## [1.4.0] - 2026-10-02

### 🌟 New Features & Enhancements

#### 🎲 Random Anime & Manga Selector & Home Horizontal Card
- **Home Page Horizontal Card Button**: Added an eye-catching horizontal card button on the Home Page beneath the Hero Carousel featuring a brand gradient dice squircle, glowing elevation shadows, dynamic "ROLL" / "تدوير" pill badge, and haptic feedback.
- **Random Selector Modal & Dialog**: Seamlessly pick your next watch or read from Anime, Manga, or Both with randomized rolling animations and interactive candidate winner cards.
- **Source Pool & Score Filtering**: Spin from your *Plan to Watch* backlog, *My List (All)*, or the broader *Discover* pool (locally cached App Data & Top Rated), with minimum score filters (Any, ★ 7.0+, ★ 8.0+ Top).
- **Expandable "Show More" Genre Filter**: Includes all 48+ genres across MAL/Jikan, cached lists, and library data with a compact horizontal view for top genres, inline quick search, and an expandable wrap with "Show more" / "Show less" controls.
- **Expandable "Show More" Studio & Producer Filter**: Filter random picks by animation studio (MAPPA, ufotable, Bones, Madhouse, Wit Studio, Kyoto Animation, CloverWorks, Toei, etc.) with real-time search, dynamic producer harvesting, and expandable wrap.
- **Result Details & Actions**: Displays winning format, episode/chapter count, year, studio badge, and expandable synopsis with 1-tap "Add to List" and "More Info" navigation.

#### 🚫 Content & Category Exclusions System (Settings)
- **App-Wide Exclusion Engine**: Specify categories, genres, or explicit content that are blocked across the entire app. Excluded titles are hidden from Home, See All, Search, Schedule, App Data, Random Selector, and Desktop Sidebar.
- **1-Tap Quick Presets**: Instant exclusion bundles for *Adult / Explicit* (Hentai, Erotica, Ecchi), *Romance & BL/GL*, *Horror & Gore*, and *Action & Combat*.
- **Comprehensive Category Browser**: Browse and toggle 50+ genres, themes, and demographics, or add custom category keywords with instant tag removal.
- **Dynamic Revision Listener**: Updating exclusions triggers instant UI updates across all active views without requiring an app restart.

#### 📅 Multi-Season Schedule & Header View Mode Switcher
- **Header View Mode Switcher**: Replaced the previous fetch button in the schedule header with a compact segmented mode switcher (`[Calendar | Grid | List]`), dynamically styled with the active theme's accent color.
- **Maximized Schedule Display Space**: Removed the redundant secondary season statistics bar to grant full vertical and horizontal screen estate to the schedule view.
- **Select Seasons Dialog Overhaul**: Redesigned the multi-season dialog with card-style selection tiles, consistent left checkboxes, quick "Select All" / "Clear" action pills, and proper title casing (e.g., *Winter 2026*).
- **Integrated Season Fetch Action**: Relocated "Fetch Season" directly into the Select Seasons dialog action bar with real-time rate-limit cooldown tracking.
- **Schedule Category Hide Filters**: Added customizable filters to quickly hide finished, currently watching, ignored, or planned anime from the schedule.

#### 🎯 Sort & Filter Bottom Sheet Stability (My List)
- **Zero Layout Shifting**: Locked the bottom sheet height and fixed section header heights, eliminating vertical jumps when filters are toggled.
- **Constant Metric Buttons**: Standardized button border widths and font weights across selected and unselected states to prevent wrapping reflows.
- **Advanced Multi-Choice Filtering**: Added custom episode numeric ranges, unknown episode support, and distinct high-contrast color badges for genres and studios.
- **AppBar Overflow Fix**: Resolved the 14px RenderFlex overflow on smaller screens by wrapping list titles with flexible ellipsis and streamlining actions.

#### 📺 Airing Delta Badges & 2-Hour Auto-Check
- **Complete Delta Display (`+`, `-`, `0`)**: Resolved issue where `0` or positive deltas were suppressed. Now clearly displays `-N` (behind in red `#FF4D4D`), `0` (caught up with broadcast in emerald `#10B981`), and `+N` (ahead in gold `#FFD54F`).
- **Automatic 2-Hour Release Check**: Added background episode release checker in `AiringScheduleService` querying the main API (MAL/Jikan, NOT WitAnime) every ~2 hours from last broadcast time to keep episode release status fresh without requiring manual refetches.

#### ⏱️ Franchise Relations Chronological Timeline & Dedicated Page
- **Chronological Sorting (Old to New)**: Relations are now organized from earliest release to newest across all prequels, sequels, side stories, and movies.
- **Original Season Highlight**: The current anime is seamlessly integrated into the timeline chart as a prominent `★ Current Entry` with an accent glow and dedicated badge.
- **Adaptive Timeline Layout**: When a franchise has $\le 6$ relations, the full extended timeline renders directly on the detail page; when $> 6$ relations, a "See All" button navigates to the dedicated full-screen `FranchiseTimelinePage` equipped with category filters (`All`, `Main Story`, `Movies`, `Side Stories`).

#### ⭐ "Your Rating" Redesign
- **Big Left Overall Cell**: Overall rating is now featured in a large prominent left cell with score, `/ 10` indicator, and overall badge.
- **7 Vertical Progress Bars**: The right cell displays 7 vertical bars scaled out of 10 for Story, Characters, Dialogues, Main Idea, Drawing, Animation, and Music with existing distinct theme colors. Values sit directly above each bar and category labels below, engineered with responsive flex spacing to prevent layout overflow.

#### 🎬 Episodes Header & Quick Controls (-12 / +12 Jumps & List View)
- **Streamlined Jump Controls**: Removed the cluttered `-64` to `+64` chip row and "Jump:" label. Replaced with clean `[-12]` and `[+12]` jump buttons and `[Go to Ep...]` dialog.
- **Card & List View Toggle**: Added a toggle button between horizontal card view and a compact vertical list item view.
- **Quick `+` Mark Watched Action**: Added a direct `+` / check button on both card and list item layouts to quickly increment or toggle watch progress.

#### 🧹 Maintenance & Cleanups
- **Removed Tiers Feature**: Cleaned up legacy tier list references for a leaner and faster user experience.
- **One Piece Episode Count Fix (1407 -> 1180)**: Long-running franchises (>180 days) now bypass naive weekly estimation and prioritize verified published episode counts from streaming ground truth.

## [1.3.0] - 2026-09-28

### 🌟 New Features & Enhancements

#### 🔒 Storage Permission Rationale & Access Gates
- **In-App Permission Rationale**: Eliminated abrupt redirects to Android's "All files access" system settings on app launch; users now receive a clear explanatory dialog first.
- **Feature Protection**: Local Library, WitAnime navigation, and episode downloads remain safely locked and disabled until storage access is explicitly confirmed by the user.

#### 📂 Local Library Auto-Link & Multi-Format Player
- **Smart WitAnime & Acronym Auto-Linking**: Intelligently identifies and groups episodes using short acronyms (e.g., `[Witanime.com] GBS3 EP 01` linked to *Grand Blue Season 3*).
- **Automated Directory Organization**: Moves and syncs watching list animes into clean structured directories (`MyAnimes/{Anime Title}/`) with category badges.
- **Archive Video Scanning**: Directly accesses and indexes single-video `.zip` and `.rar` archives without requiring manual extraction.
- **Safe Video Deletion**: Added video deletion with confirmation dialog directly from the library.

#### 📅 Seasonal Fetch, Schedule Grid & Permanent Caching
- **Schedule View Switcher (Weekly vs Grid)**: Added a one-tap toggle to switch between the traditional Day-by-Day Weekly Schedule and a full Seasonal Grid view displaying all anime side-by-side.
- **Permanent Multi-Season Caching**: Fetched seasons (e.g. 2020, 2026) are permanently registered in Hive storage and never lost on app restart.
- **Partial Downgrade Protection**: Prevents full 200+ anime seasonal caches from being overwritten or downgraded by 25-item preview fetches on app startup.
- **Seasonal Breakdown Header**: Real-time summary banner displaying total anime count, scheduled broadcasts, and TBA/unscheduled counts.
- **Dismissable Season Chips**: Added `(X)` delete buttons to saved season chips for quick management.
- **Custom Season Fetch Dialog**: Easily fetch any season from 1960 onwards with year dropdown, manual year input, season selector chips, and live rate-limit safe progress tracking.

#### 📊 Dedicated App Data Page (`lib/pages/data_page.dart`)
- **Centralized Local Data Hub**: Comprehensive viewer for all anime data saved locally in Hive across the app.
- **Multi-Filter & Sorting**: Real-time search, multi-filter bottom sheet (Year, Season, Genre, Studio, Status), and sorting (Score, Title, Year, Episodes).
- **Data Maintenance**: Individual item re-fetch from Jikan, direct edit, and deletion with a floating undo SnackBar.

#### 🎨 Layered Tier List Overhaul (`Create Layered List Image`)
- **Decimal Range Inputs (`From` & `To`)**: Independent numerical inputs with automated real-time range overlap warnings.
- **Tier Options Menu**: Moved "Remove Tier" into an options popup menu per tier.
- **Full-Width "Add Tier" Button**: Accessible action button anchored at the bottom of the tiers list.
- **Rich Anime Filters**: Added Year, Season, and Episode count filters for pinpoint list generation.

#### 🛡️ Rating Score Persistence & Sync Stability
- **Non-Destructive Sync**: Fixed rating reset bug on app exit and MAL sync; preserved nuanced decimal sub-ratings (Story, Character, Draw, Animation, Music, Dialogues, Main Idea) without overwrite.

#### 🔍 Search Experience & 504 Gateway Fallback
- **Persistent Bottom Navigation**: Bottom navigation bar remains visible and responsive while searching.
- **504 Gateway Timeout Fallback**: Gracefully falls back to searching locally saved Hive anime if external APIs time out.
- **Search Bar Filter Menu & Active Badges**: Direct popup menu filter access within the search bar with active badge indicators.

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

#### 🔄 Universal Delete Undo & Schedule Polish
- **Delete Undo Action Toast**: Any deletion or item removal across My List (swipe-to-dismiss, context menu, desktop view), Detail pages, Home, and Search now presents a floating SnackBar with an **"UNDO"** action, seamlessly restoring the item, watch progress, and rating dimensions.
- **Finished Airing Schedule Cleaner**: Animes that have concluded their broadcast or reached their final episode are automatically excluded from the airing schedule and "Airing Next Today" countdowns.
- **Season Turnover Detection & Pull-to-Refresh**: Entering a new anime season automatically flushes stale season cache and queries the fresh seasonal catalog. Added pull-to-refresh and a dedicated season refetch control to the schedule page.
- **Rating Precision & Score Normalization**: Retains full floating-point decimal precision (`double`) locally for nuanced criteria ratings while normalizing scores `0..10` as rounded integers (`int`) for MyAnimeList sync (with `0` properly clearing ratings).

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
