import React, { useState, useEffect, useRef } from 'react';
import {
    Play,
    Check,
    Eye,
    Star,
    Calendar,
    List,
    Search,
    Bell,
    Clock,
    Sliders,
    ChevronDown,
    Download,
    Heart,
    Shield,
    Sparkles,
    Plus,
    Minus,
    RotateCw,
    ChevronRight,
    BarChart3,
    Activity,
    Github,
    Twitter,
    MessageSquare,
    Flame,
    Tv,
    HelpCircle,
    Folder,
    FolderHeart,
    Settings,
    User,
    AlertCircle,
    Share2,
    LogOut,
    CheckSquare,
    Square,
    Smartphone,
    Languages,
    Home,
    PlusCircle,
    Filter,
    Trash2,
    Monitor,
    AlertTriangle,
    X
} from 'lucide-react';
import anime from 'animejs';
import { animeData } from './animeData.js';

// Theme Definitions matching Flutter App themes
const themes = {
    default_dark: {
        bg: '#0a0c14',
        surface: '#131622',
        nav: '#0c0d16',
        border: 'rgba(255, 255, 255, 0.05)',
        text: '#ffffff',
        textSecondary: '#9ca3af',
        accent: '#8b5cf6',
        accentSecondary: '#f43f5e',
        glow: 'rgba(139, 92, 246, 0.15)',
        isDark: true
    },
    default_light: {
        bg: '#f8fafc',
        surface: '#ffffff',
        nav: '#f1f5f9',
        border: 'rgba(0, 0, 0, 0.08)',
        text: '#0f172a',
        textSecondary: '#64748b',
        accent: '#6366f1',
        accentSecondary: '#ec4899',
        glow: 'rgba(99, 102, 241, 0.1)',
        isDark: false
    },
    glassmorphic_dark: {
        bg: '#090a10',
        surface: 'rgba(25, 28, 45, 0.45)',
        nav: 'rgba(12, 13, 22, 0.8)',
        border: 'rgba(255, 255, 255, 0.08)',
        text: '#ffffff',
        textSecondary: '#cbd5e1',
        accent: '#a78bfa',
        accentSecondary: '#fb7185',
        glow: 'rgba(167, 139, 250, 0.2)',
        isDark: true
    },
    cyberpunk_neon: {
        bg: '#030712',
        surface: '#0f172a',
        nav: '#020617',
        border: 'rgba(244, 63, 94, 0.3)',
        text: '#38bdf8',
        textSecondary: '#94a3b8',
        accent: '#06b6d4',
        accentSecondary: '#ec4899',
        glow: 'rgba(6, 182, 212, 0.25)',
        isDark: true
    },
    sakura_blossom: {
        bg: '#fff5f5',
        surface: '#ffe3e3',
        nav: '#ffd0d0',
        border: 'rgba(255, 179, 179, 0.4)',
        text: '#4a154b',
        textSecondary: '#862e9c',
        accent: '#d6336c',
        accentSecondary: '#f783ac',
        glow: 'rgba(214, 51, 108, 0.15)',
        isDark: false
    },
    midnight_abyss: {
        bg: '#020205',
        surface: '#070714',
        nav: '#010103',
        border: 'rgba(139, 92, 246, 0.15)',
        text: '#e2e8f0',
        textSecondary: '#94a3b8',
        accent: '#7c3aed',
        accentSecondary: '#c084fc',
        glow: 'rgba(124, 58, 237, 0.2)',
        isDark: true
    },
    retro_forest: {
        bg: '#141c15',
        surface: '#1d2a1f',
        nav: '#0f1510',
        border: 'rgba(16, 185, 129, 0.1)',
        text: '#ecfdf5',
        textSecondary: '#a7f3d0',
        accent: '#10b981',
        accentSecondary: '#f59e0b',
        glow: 'rgba(16, 185, 129, 0.15)',
        isDark: true
    }
};

// UI translation mapping
const translations = {
    en: {
        title: "MY ANIMES",
        tracker: "TRACKER",
        home: "Home",
        animeHub: "Anime Hub",
        myWatchlist: "My Watchlist",
        telemetryStats: "Schedule",
        searchPlaceholder: "Search popular anime...",
        continueWatching: "Continue Watching",
        airingNext: "Airing Next Today",
        weeklySchedule: "Weekly Schedule",
        myTrackerList: "My Tracker List",
        localLibrary: "Local Library",
        watching: "Watching",
        completed: "Completed",
        planned: "Planned",
        ignored: "Ignored",
        episodes: "Episodes",
        avgScore: "Average Score",
        topStudio: "Top Studio",
        completionRate: "Completion Rate",
        totalHours: "Total Hours",
        statusDistribution: "Status Distribution",
        themePack: "Theme Pack",
        language: "Language",
        syncMal: "Sync with MyAnimeList",
        daysSpent: "Days Spent",
        anime: "Anime",
        close: "Close",
        heroTag: "Unlimited Anime Finder",
        heroTitle: "Track Your Anime & Manga Journey.",
        heroDesc: "The ultimate companion application for anime and manga lovers. Keep tabs on your current episodes, organize your planned shows, and analyze your lifetime watch history on the go. Download our native app for Android and Windows, or explore its features using the sandbox tracker below!",
        heroStat1Value: "0.1s",
        heroStat1Label: "Response Time",
        heroStat2Value: "100%",
        heroStat2Label: "Offline Support",
        heroStat3Value: "Zero",
        heroStat3Label: "Advertisements",
        downloadApk: "Download APK for Android Mobile",
        downloadMsix: "Download MSIX for Windows Client",
        noAds: "No Ads",
        freeForever: "100% Free Forever",
        madeByFans: "Made by Fans",
        scrollyTitle: "Immersive Anime Details Page",
        scrollySubtitle: "Every Detail, Beautifully Structured",
        scrollyDesc: "Experience the most detailed overview of your favorite anime series. Instantly check MAL community metrics, airing schedules, studio logs, and genre classifications. Everything you need is structured inside custom native cards, designed for fast and beautiful readability.",
        scrollyPoint1Title: "Real-time MyAnimeList Sync",
        scrollyPoint1Desc: "Instantly check global rankings, popularity scores, and member count synchronized with MyAnimeList.",
        scrollyPoint2Title: "Rich Specifications",
        scrollyPoint2Desc: "Browse technical details including broadcast schedules, episode counts, source type, and rating certificates.",
        scrollyPoint3Title: "Genre Classifications",
        scrollyPoint3Desc: "Filter, classify, and discover related shows using custom tags designed for intuitive database navigation.",
        sandboxTitle: "Watchlist Sandbox",
        sandboxDesc: "Increment episode metrics local-only. Tracked data simulates offline caching database.",
        syncToMal: "Sync watchlist to MyAnimeList",
        syncingToMal: "Syncing with MAL...",
        watchlistShowcaseTitle: "Your Watchlist, Beautifully Organized",
        watchlistShowcaseSubtitle: "NATIVE WATCHLIST TRACKER",
        watchlistShowcaseDesc: "Keep track of your current progress, completed series, and plans in a beautiful mobile-native list layout. Effortlessly update episode counters, rate shows, and sync in real-time with MAL.",
        watchlistPoint1Title: "Flexible Status Categories",
        watchlistPoint1Desc: "Filter your watchlists instantly by Watching, Completed, Planned, or Ignored.",
        watchlistPoint2Title: "One-Tap Counter Updates",
        watchlistPoint2Desc: "Update episode counters with simple plus/minus controls that automatically recalculate telemetry statistics.",
        watchlistPoint3Title: "Seamless MAL Backup",
        watchlistPoint3Desc: "Push updates directly to MyAnimeList from a unified syncing command dashboard.",
        yourRating: "Your Rating:",
        telemetryTitle: "Watch Telemetry",
        telemetryDesc: "Dynamic analytics calculated instantly from tracked sandbox items.",
        loggedLabel: "You have logged",
        daysLabel: "Days",
        spentLabel: "Spent watching anime! (approx. {count} episodes)",
        showsLabel: "Shows",
        faqTitle: "Frequently Asked Questions",
        faqDesc: "Got questions? We've got answers.",
        faq1Q: "How does the tracking synchronize?",
        faq1A: "Our app synchronizes natively with major databases such as MyAnimeList (MAL) instantly using secure API OAuth. Every modification to episode count inside the app updates your official profile database.",
        faq2Q: "Is there an offline mode?",
        faq2A: "Yes! My Animes stores your local state and updates securely in-memory. Once you establish a network connection, the application automatically syncs and resolves version updates seamlessly.",
        faq3Q: "Are the push notification broadcast schedules accurate?",
        faq3A: "Absolutely. Broadcast schedule updates are queried globally from local television guide and streaming sources. Alerts can be customized relative to your localized time zone!",
        startWatching: "Start Watching",
        planToWatch: "Plan to Watch",
        synopsisLabel: "Synopsis",
        episodesLabel2: "Episodes:",
        typeLabel: "Type:",
        airedLabel: "Aired:",
        statusLabel: "Status:",
        footerText: "© 2026 MA App. All rights reserved.",
        scheduleShowcaseTitle: "Weekly Airing Schedule, Synchronized",
        scheduleShowcaseSubtitle: "WEEKLY BROADCAST CALENDAR",
        scheduleShowcaseDesc: "Track new episodes in real-time. View scheduled countdowns, receive alerts, and browse the weekly calendar directly in the app.",
        schedulePoint1Title: "Airing Next Countdown",
        schedulePoint1Desc: "See exactly how many hours and minutes remain before the next episode airs with accurate real-time countdown widgets.",
        schedulePoint2Title: "Day-by-Day Broadcast Schedule",
        schedulePoint2Desc: "Filter airing shows day by day (Monday to Sunday) to organize your active viewing schedule.",
        schedulePoint3Title: "One-Tap Watchlist Integration",
        schedulePoint3Desc: "Quickly add newly airing shows to your watchlist or set notifications to alert you the minute an episode is subbed."
    },
    ar: {
        title: "أنمياتي",
        tracker: "تعقب المشاهدة",
        home: "الرئيسية",
        animeHub: "مركز الأنمي",
        myWatchlist: "قائمتي الخاصة",
        telemetryStats: "الجدول",
        searchPlaceholder: "ابحث عن الأنميات الشهيرة...",
        continueWatching: "مواصلة المشاهدة",
        airingNext: "يعرض تالياً اليوم",
        weeklySchedule: "جدول العرض الأسبوعي",
        myTrackerList: "قائمة التتبع الخاصة بي",
        localLibrary: "المكتبة المحلية",
        watching: "قيد المشاهدة",
        completed: "مكتمل",
        planned: "مخطط للمشاهدة",
        ignored: "متجاهل",
        episodes: "الحلقات",
        avgScore: "متوسط التقييم",
        topStudio: "أفضل استوديو",
        completionRate: "معدل الإكمال",
        totalHours: "إجمالي الساعات",
        statusDistribution: "توزيع الحالات",
        themePack: "حزمة المظهر",
        language: "اللغة",
        syncMal: "مزامنة مع MyAnimeList",
        daysSpent: "الأيام المستغرقة",
        anime: "الأنمي",
        close: "إغلاق",
        heroTag: "مكتشف أنميات غير محدود",
        heroTitle: "تتبع رحلة الأنمي والمانجا الخاصة بك.",
        heroDesc: "التطبيق الرفيق الأمثل لعشاق الأنمي والمانجا. تابع حلقاتك الحالية، ونظم عروضك المخطط لها، وحلل سجل مشاهدتك مدى الحياة أثناء تنقلك. قم بتنزيل تطبيقنا الأصلي لنظامي التشغيل أندرويد وويندوز، أو استكشف ميزاته باستخدام صندوق تتبع الأنمي أدناه!",
        heroStat1Value: "0.1 ثانية",
        heroStat1Label: "سرعة الاستجابة",
        heroStat2Value: "100%",
        heroStat2Label: "دعم دون اتصال",
        heroStat3Value: "خالي من",
        heroStat3Label: "الإعلانات",
        downloadApk: "تحميل APK لأجهزة أندرويد",
        downloadMsix: "تحميل MSIX لنظام ويندوز",
        noAds: "بدون إعلانات",
        freeForever: "مجاني 100% للأبد",
        madeByFans: "صنع بواسطة معجبين",
        scrollyTitle: "صفحة تفاصيل أنمي غامرة",
        scrollySubtitle: "كل التفاصيل، منسقة بشكل جميل",
        scrollyDesc: "اختبر نظرة شاملة وتفصيلية لسلسلة الأنمي المفضلة لديك. تحقق فوراً من مقاييس مجتمع MAL، وجداول البث، وسجلات الاستوديو، وتصنيفات الأنواع. كل ما تحتاجه منظم داخل بطاقات مخصصة مصممة للقراءة السريعة والجميلة.",
        scrollyPoint1Title: "مزامنة MAL الفورية",
        scrollyPoint1Desc: "تحقق فوراً من التصنيفات العالمية، ونقاط الشعبية، وعدد الأعضاء المتزامن مع MyAnimeList.",
        scrollyPoint2Title: "المواصفات الغنية",
        scrollyPoint2Desc: "تصفح التفاصيل الفنية بما في ذلك مواعيد البث، وعدد الحلقات، ونوع المصدر، وشهادات التصنيف العمري.",
        scrollyPoint3Title: "تصنيفات الأنواع",
        scrollyPoint3Desc: "قم بتصفية وتصنيف واكتشاف العروض ذات الصلة باستخدام بطاقات مخصصة مصممة للتنقل السهل.",
        sandboxTitle: "لوحة تحكم قائمة التتبع",
        sandboxDesc: "قم بزيادة عدد الحلقات محلياً. البيانات المتتبعة تحاكي التخزين المؤقت غير المتصل بالإنترنت.",
        syncToMal: "مزامنة القائمة مع MyAnimeList",
        syncingToMal: "جاري المزامنة مع MAL...",
        watchlistShowcaseTitle: "قائمتك المفضلة، منظمة بشكل رائع",
        watchlistShowcaseSubtitle: "متتبع القائمة الأصلي",
        watchlistShowcaseDesc: "تتبع تقدمك الحالي، الحلقات المكتملة، وخطط المشاهدة في واجهة جوال أصلية وأنيقة. قم بتحديث عداد الحلقات بسهولة، وقيم المسلسلات، وتزامن مع MAL بالوقت الفعلي.",
        watchlistPoint1Title: "تصنيفات حالات مرنة",
        watchlistPoint1Desc: "قم بتصفية قائمة المشاهدة فوراً حسب أشاهد، مكتمل، مخطط للمشاهدة، أو متجاهل.",
        watchlistPoint2Title: "تحديثات العداد بضغطة واحدة",
        watchlistPoint2Desc: "حدث عدد الحلقات التي شاهدتها بأزرار تحكم بسيطة تجمع فوراً الإحصائيات الفنية.",
        watchlistPoint3Title: "نسخ احتياطي فوري لـ MAL",
        watchlistPoint3Desc: "أرسل التحديثات والتعديلات مباشرة إلى MyAnimeList من لوحة تحكم موحدة وسريعة.",
        yourRating: "تقييمك الخاص:",
        telemetryTitle: "تحليلات المشاهدة",
        telemetryDesc: "إحصائيات ديناميكية يتم حسابها فورياً من قائمة التتبع الخاصة بك.",
        loggedLabel: "لقد سجلت",
        daysLabel: "أيام",
        spentLabel: "مقضية في مشاهدة الأنمي! (حوالي {count} حلقة)",
        showsLabel: "عرض",
        faqTitle: "الأسئلة الشائعة",
        faqDesc: "لديك أسئلة؟ لدينا إجابات.",
        faq1Q: "كيف تتم مزامنة التتبع؟",
        faq1A: "يتزامن تطبيقنا تلقائياً مع قواعد البيانات الكبرى مثل MyAnimeList (MAL) فورياً باستخدام بروتوكول OAuth الآمن. أي تعديل في عدد الحلقات المشاهدة يحدث حسابك الرسمي تلقائياً.",
        faq2Q: "هل يدعم التطبيق العمل بدون إنترنت؟",
        faq2A: "نعم! يقوم تطبيق أنمياتي بحفظ حالتك محلياً وتحديثها بشكل آمن. فور توفر اتصال بالإنترنت، يقوم التطبيق بمزامنة البيانات وحل التعارضات تلقائياً.",
        faq3Q: "هل مواعيد بث الإشعارات دقيقة؟",
        faq3A: "بكل تأكيد. يتم جلب مواعيد البث العالمية من مصادر التلفزيون المباشر وقنوات البث الرقمي. يمكن تخصيص التنبيهات حسب منطقتك الزمنية المحلية!",
        startWatching: "بدء المشاهدة",
        planToWatch: "التخطيط للمشاهدة",
        synopsisLabel: "القصة",
        episodesLabel2: "الحلقات:",
        typeLabel: "النوع:",
        airedLabel: "تاريخ البث:",
        statusLabel: "الحالة:",
        footerText: "© 2026 تطبيق MA. جميع الحقوق محفوظة.",
        scheduleShowcaseTitle: "جدول البث الأسبوعي، متزامن بالكامل",
        scheduleShowcaseSubtitle: "تقويم البث الأسبوعي",
        scheduleShowcaseDesc: "تابع الحلقات الجديدة في الوقت الفعلي. عرض العد التنازلي المجدول، وتلقي التنبيهات، وتصفح التقويم الأسبوعي مباشرة في التطبيق.",
        schedulePoint1Title: "العد التنازلي للبث القادم",
        schedulePoint1Desc: "تعرف بالضبط على عدد الساعات والدقائق المتبقية قبل عرض الحلقة التالية مع أدوات عد تنازلي دقيقة في الوقت الفعلي.",
        schedulePoint2Title: "جدول البث اليومي",
        schedulePoint2Desc: "قم بتصفية العروض التي تبث يوماً بعد يوم (من الاثنين إلى الأحد) لتنظيم جدول مشاهدتك النشط.",
        schedulePoint3Title: "إضافة سريعة لقائمة المتابعة",
        schedulePoint3Desc: "أضف العروض الجديدة التي تبث حالياً بسرعة إلى قائمة المتابعة الخاصة بك أو اضبط التنبيهات لتنبيهك فور صدور الترجمة."
    }
};

// Horizontal scrolling row of anime posters
function PosterRow({ items, direction = 'left', duration = '45s', delay = '0s' }) {
    const animationClass = direction === 'left' ? 'animate-marquee-left' : 'animate-marquee-right';
    const speedStyle = { 
        animationDuration: duration, 
        animationDelay: delay,
        animationPlayState: 'running'
    };
    
    return (
        <div dir="ltr" className="w-full overflow-hidden relative flex py-1 select-none">
            <div className={`flex gap-4 whitespace-nowrap min-w-full ${animationClass}`} style={speedStyle}>
                {items.map((anime, idx) => (
                    <div 
                        key={`row1-${anime.id}-${idx}`}
                        className="inline-block w-24 sm:w-32 aspect-[2/3] rounded-2xl overflow-hidden shadow-xl border border-white/5 flex-shrink-0"
                    >
                        <img
                            src={anime.image ? anime.image.replace('l.webp', '.webp') : ''}
                            alt={anime.title}
                            className="w-full h-full object-cover pointer-events-none"
                            loading="lazy"
                        />
                    </div>
                ))}
                {/* Duplicate items for infinite marquee loop */}
                {items.map((anime, idx) => (
                    <div 
                        key={`row2-${anime.id}-${idx}`}
                        className="inline-block w-24 sm:w-32 aspect-[2/3] rounded-2xl overflow-hidden shadow-xl border border-white/5 flex-shrink-0"
                    >
                        <img
                            src={anime.image ? anime.image.replace('l.webp', '.webp') : ''}
                            alt={anime.title}
                            className="w-full h-full object-cover pointer-events-none"
                            loading="lazy"
                        />
                    </div>
                ))}
            </div>
        </div>
    );
}

export default function App() {
    const [theme, setTheme] = useState('default_dark');
    const [screenSize, setScreenSize] = useState(() => {
        if (typeof window !== 'undefined') {
            const width = window.innerWidth;
            if (width < 768) return 'mobile';
            if (width < 1024) return 'tablet';
        }
        return 'desktop';
    });

    useEffect(() => {
        const handleResize = () => {
            const width = window.innerWidth;
            if (width < 768) {
                setScreenSize('mobile');
            } else if (width < 1024) {
                setScreenSize('tablet');
            } else {
                setScreenSize('desktop');
            }
        };
        // Already handled by initial state initializer, just bind the listener
        window.addEventListener('resize', handleResize);
        return () => window.removeEventListener('resize', handleResize);
    }, []);
    const [language, setLanguage] = useState('en');
    const [toastMessage, setToastMessage] = useState(null);
    const [selectedAnime, setSelectedAnime] = useState(null);
    const [searchQuery, setSearchQuery] = useState('');
    const [selectedGenre, setSelectedGenre] = useState('');
    const [syncing, setSyncing] = useState(false);
    const [activeListTab, setActiveListTab] = useState('watching'); // watching, completed, planned, ignored
    
    const [showFeedbackModal, setShowFeedbackModal] = useState(false);

    const scrollToSection = (id) => {
        const element = document.getElementById(id);
        if (element) {
            element.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    };

    // User watchlist state (initialized with 5 popular items from static database)
    const [watchlist, setWatchlist] = useState([
        {
            id: 21, // One Piece
            title: "One Piece",
            image: "https://cdn.myanimelist.net/images/anime/1244/138851.jpg",
            episodeProgress: 1080,
            episodes: 1100,
            score: 8.75,
            category: "watching",
            genres: ["Action", "Adventure", "Fantasy"],
            studios: ["Toei Animation"],
            userRating: 9,
            synopsis: "Gol D. Roger was known as the 'Pirate King,' the strongest and most infamous being to have sailed the Grand Line."
        },
        {
            id: 51009, // Frieren
            title: "Shingeki no Kyojin Season 3 Part 2",
            image: "https://cdn.myanimelist.net/images/anime/1517/100633.jpg",
            episodeProgress: 10,
            episodes: 10,
            score: 9.05,
            category: "completed",
            genres: ["Action", "Drama", "Suspense"],
            studios: ["Wit Studio"],
            userRating: 10,
            synopsis: "Seeking to restore humanity's diminishing hope, the Survey Corps embark on a mission to retake Wall Maria."
        },
        {
            id: 41467, // Bleach TYBW
            title: "Bleach: Sennen Kessen-hen",
            image: "https://cdn.myanimelist.net/images/anime/1764/126627.jpg",
            episodeProgress: 3,
            episodes: 13,
            score: 9.02,
            category: "watching",
            genres: ["Action", "Adventure", "Fantasy"],
            studios: ["Pierrot"],
            userRating: 8,
            synopsis: "Soul Reaper Substitute Ichigo Kurosaki spends his days fighting off Hollows, dangerous evil spirits."
        },
        {
            id: 38524, // Vinland Saga
            title: "Shingeki no Kyojin: The Final Season",
            image: "https://cdn.myanimelist.net/images/anime/1000/110531.jpg",
            episodeProgress: 0,
            episodes: 16,
            score: 8.81,
            category: "planned",
            genres: ["Action", "Drama", "Suspense"],
            studios: ["MAPPA"],
            userRating: 0,
            synopsis: "Gabi Braun and Falco Grice have been training their entire lives to inherit one of the seven Titans."
        }
    ]);

    const particleContainerRef = useRef(null);
    const scrollySectionRef = useRef(null);
    const watchlistSectionRef = useRef(null);
    const scheduleSectionRef = useRef(null);
    const [scrollyAnimated, setScrollyAnimated] = useState(false);
    const [watchlistAnimated, setWatchlistAnimated] = useState(false);
    const [scheduleAnimated, setScheduleAnimated] = useState(false);

    // Dynamic Mock Show typewriter loop
    const popular10 = animeData.slice(0, 10);
    
    // Retrieve actual database records for the schedule section
    const reZero = animeData.find(a => a.id === 61316) || animeData[1];
    const frierenS2 = animeData.find(a => a.id === 59978) || animeData[0];
    const jojoSbr = animeData.find(a => a.id === 61469) || animeData[3];
    const mushokuS3 = animeData.find(a => a.id === 59193) || animeData[11];
    const apothecaryS2 = animeData.find(a => a.id === 58514) || animeData[15];
    const chainsawReze = animeData.find(a => a.id === 57555) || animeData[5];
    const [activeMockIndex, setActiveMockIndex] = useState(0);
    const [displayedMockIndex, setDisplayedMockIndex] = useState(0);
    const [typedText, setTypedText] = useState("");
    const [isDeleting, setIsDeleting] = useState(false);

    // Dynamic Mockup transition animation helper
    const triggerMockupSwitch = (nextIndex) => {
        if (!scrollyAnimated) {
            setDisplayedMockIndex(nextIndex);
            return;
        }
        
        // Phase 1: Disassemble / Explode Outward
        anime.timeline({
            easing: 'easeInQuad',
            duration: 250
        })
        .add({
            targets: '.anime-comp-poster',
            opacity: 0,
            translateY: 40,
            scale: 0.95
        })
        .add({
            targets: '.anime-comp-spec-card',
            opacity: 0,
            translateX: 40,
            translateY: -20,
            scale: 0.95
        }, 0)
        .add({
            targets: '.anime-comp-classifications',
            opacity: 0,
            translateX: -40,
            translateY: 20,
            scale: 0.95
        }, 0)
        .add({
            duration: 10,
            complete: () => {
                setDisplayedMockIndex(nextIndex);
                
                // Set starting position for Phase 2 entry
                anime.set('.anime-comp-poster', { translateY: -40, scale: 0.95 });
                anime.set('.anime-comp-spec-card', { translateX: -40, translateY: 20, scale: 0.95 });
                anime.set('.anime-comp-classifications', { translateX: 40, translateY: -20, scale: 0.95 });
            }
        })
        // Phase 2: Reassemble / Fly In
        .add({
            targets: '.anime-comp-poster',
            opacity: 1,
            translateY: 0,
            scale: 1,
            easing: 'easeOutElastic(1.1, 0.75)',
            duration: 800
        })
        .add({
            targets: '.anime-comp-spec-card',
            opacity: 1,
            translateX: 0,
            translateY: 0,
            scale: 1,
            easing: 'easeOutElastic(1.1, 0.75)',
            duration: 800
        }, '-=700')
        .add({
            targets: '.anime-comp-classifications',
            opacity: 1,
            translateX: 0,
            translateY: 0,
            scale: 1,
            easing: 'easeOutElastic(1.1, 0.75)',
            duration: 800
        }, '-=700');
    };

    useEffect(() => {
        let timer;
        const activeAnime = popular10[activeMockIndex];
        const fullText = activeAnime.englishTitle || activeAnime.title;
        
        if (!isDeleting) {
            if (typedText.length < fullText.length) {
                // Calculate dynamic delay based on title length so typing phase takes exactly 1500ms
                const charDelay = Math.max(10, 1500 / fullText.length);
                timer = setTimeout(() => {
                    const nextText = fullText.slice(0, typedText.length + 1);
                    setTypedText(nextText);
                    // Switch components exactly when writing stops
                    if (nextText.length === fullText.length) {
                        triggerMockupSwitch(activeMockIndex);
                    }
                }, charDelay);
            } else {
                timer = setTimeout(() => {
                    setIsDeleting(true);
                }, 3500);
            }
        } else {
            if (typedText.length > 0) {
                // Deleting is fast and constant (20ms per char)
                timer = setTimeout(() => {
                    setTypedText(typedText.slice(0, -1));
                }, 20);
            } else {
                setIsDeleting(false);
                setActiveMockIndex((prev) => (prev + 1) % 10);
            }
        }
        return () => clearTimeout(timer);
    }, [typedText, isDeleting, activeMockIndex, popular10, scrollyAnimated]);

    useEffect(() => {
        const observer = new IntersectionObserver(
            ([entry]) => {
                if (entry.isIntersecting && !scrollyAnimated) {
                    setScrollyAnimated(true);

                    // Initialize components with opacity 0 before animating
                    anime.set('.anime-comp-poster', { opacity: 0, translateY: 120, scale: 0.8, rotateX: 0, rotateY: 0 });
                    anime.set('.anime-comp-header-badges', { 
                        opacity: 0, 
                        translateX: language === 'ar' ? 0 : -50,
                        translateY: language === 'ar' ? -20 : 0
                    });
                    anime.set('.anime-comp-title', { opacity: 0, translateY: 40 });
                    anime.set('.anime-comp-score-box', { opacity: 0, scale: 0.85, translateY: 40 });
                    anime.set('.anime-comp-action-btn', { opacity: 0, scale: 0.8 });
                    anime.set('.anime-comp-overview-tabs', { opacity: 0, translateY: 30 });
                    anime.set('.anime-comp-spec-card', { opacity: 0, translateX: 0, translateY: 0, rotateZ: 0, scale: 1 });
                    anime.set('.anime-comp-classifications', { opacity: 0, translateY: 0, translateX: 0, scale: 1, rotateZ: 0 });
                    anime.set('.anime-desc-text-right', { 
                        opacity: 0, 
                        translateX: language === 'ar' ? 0 : 80,
                        translateY: language === 'ar' ? 40 : 0
                    });

                    // Construction timeline animation
                    anime.timeline({
                        easing: 'easeOutElastic(1.1, .75)',
                        duration: 1400
                    })
                    .add({
                        targets: '.anime-comp-poster',
                        opacity: [0, 1],
                        translateY: [120, 0],
                        scale: [0.8, 1],
                        rotateX: [0, 0],
                        rotateY: [0, 0],
                        delay: 150
                    })
                    .add({
                        targets: '.anime-comp-header-badges',
                        opacity: [0, 1],
                        translateX: [language === 'ar' ? 0 : -50, 0],
                        translateY: [language === 'ar' ? -20 : 0, 0],
                        duration: 1000,
                        easing: 'easeOutQuad'
                    }, '-=1000')
                    .add({
                        targets: '.anime-comp-title',
                        opacity: [0, 1],
                        translateY: [40, 0],
                        duration: 1100,
                        easing: 'easeOutQuad'
                    }, '-=900')
                    .add({
                        targets: '.anime-comp-score-box',
                        opacity: [0, 1],
                        scale: [0.85, 1],
                        translateY: [40, 0],
                        duration: 1200
                    }, '-=950')
                    .add({
                        targets: '.anime-comp-action-btn',
                        opacity: [0, 1],
                        scale: [0.8, 1],
                        delay: anime.stagger(120),
                        duration: 1000
                    }, '-=900')
                    .add({
                        targets: '.anime-comp-overview-tabs',
                        opacity: [0, 1],
                        translateY: [30, 0],
                        duration: 1000,
                        easing: 'easeOutQuad'
                    }, '-=900')
                    // Spec card: fade in only (no movement)
                    .add({
                        targets: '.anime-comp-spec-card',
                        opacity: [0, 1],
                        duration: 1100,
                        easing: 'easeOutQuad'
                    }, 0)
                    // Classifications card: fade in only (no movement)
                    .add({
                        targets: '.anime-comp-classifications',
                        opacity: [0, 1],
                        duration: 1100,
                        easing: 'easeOutQuad'
                    }, 0)
                    .add({
                        targets: '.anime-desc-text-right',
                        opacity: [0, 1],
                        translateX: [language === 'ar' ? 0 : 80, 0],
                        translateY: [language === 'ar' ? 40 : 0, 0],
                        duration: 1200,
                        easing: 'easeOutQuad'
                    }, 200);
                }
            },
            { threshold: 0.15 }
        );

        if (scrollySectionRef.current) {
            observer.observe(scrollySectionRef.current);
        }
        return () => observer.disconnect();
    }, [scrollyAnimated]);

    useEffect(() => {
        const observer = new IntersectionObserver(
            ([entry]) => {
                if (entry.isIntersecting && !watchlistAnimated) {
                    setWatchlistAnimated(true);

                    // Initialize watchlist elements before animating
                    anime.set('.watchlist-mockup-container', { 
                        opacity: 0, 
                        scale: 0.8, 
                        rotateX: 8, 
                        rotateY: language === 'ar' ? -28 : 28, 
                        rotateZ: language === 'ar' ? 4 : -4 
                    });
                    anime.set('.watchlist-mockup-card', { opacity: 0, translateY: 40 });
                    anime.set('.watchlist-desc-text-left', { 
                        opacity: 0, 
                        translateX: language === 'ar' ? 0 : -80,
                        translateY: language === 'ar' ? 40 : 0
                    });

                    // Run timeline
                    anime.timeline({
                        easing: 'easeOutElastic(1.1, .75)',
                        duration: 1400
                    })
                    .add({
                        targets: '.watchlist-mockup-container',
                        opacity: [0, 1],
                        scale: [0.8, 1],
                        rotateX: [8, 8],
                        rotateY: language === 'ar' ? [-28, -28] : [28, -28], 
                        rotateZ: language === 'ar' ? [4, 4] : [-4, 4],
                        duration: 1200,
                        delay: 150
                    })
                    .add({
                        targets: '.watchlist-mockup-card',
                        opacity: [0, 1],
                        translateY: [40, 0],
                        delay: anime.stagger(150),
                        duration: 1000
                    }, '-=900')
                    .add({
                        targets: '.watchlist-desc-text-left',
                        opacity: [0, 1],
                        translateX: [language === 'ar' ? 0 : -80, 0],
                        translateY: [language === 'ar' ? 40 : 0, 0],
                        duration: 1200,
                        easing: 'easeOutQuad'
                    }, 200);
                }
            },
            { threshold: 0.15 }
        );

        if (watchlistSectionRef.current) {
            observer.observe(watchlistSectionRef.current);
        }
        return () => observer.disconnect();
    }, [watchlistAnimated]);

    useEffect(() => {
        const observer = new IntersectionObserver(
            ([entry]) => {
                if (entry.isIntersecting && !scheduleAnimated) {
                    setScheduleAnimated(true);

                    // Initialize schedule elements before animating
                    anime.set('.schedule-mockup-container', { 
                        opacity: 0, 
                        scale: 0.8, 
                        rotateX: 8, 
                        rotateY: 28, 
                        rotateZ: -4 
                    });
                    anime.set('.schedule-mockup-card', { opacity: 0, translateY: 30 });
                    anime.set('.schedule-desc-text-right', { 
                        opacity: 0, 
                        translateX: language === 'ar' ? 0 : 80,
                        translateY: language === 'ar' ? 40 : 0
                    });

                    // Run timeline
                    anime.timeline({
                        easing: 'easeOutElastic(1.1, .75)',
                        duration: 1400
                    })
                    .add({
                        targets: '.schedule-mockup-container',
                        opacity: [0, 1],
                        scale: [0.8, 1],
                        rotateX: [8, 8],
                        rotateY: [28, 28], 
                        rotateZ: [-4, -4],
                        duration: 1200,
                        delay: 150
                    })
                    .add({
                        targets: '.schedule-mockup-card',
                        opacity: [0, 1],
                        translateY: [30, 0],
                        delay: anime.stagger(100),
                        duration: 800
                    }, '-=900')
                    .add({
                        targets: '.schedule-desc-text-right',
                        opacity: [0, 1],
                        translateX: [language === 'ar' ? 0 : 80, 0],
                        translateY: [language === 'ar' ? 40 : 0, 0],
                        duration: 1200,
                        easing: 'easeOutQuad'
                    }, 200);
                }
            },
            { threshold: 0.15 }
        );

        if (scheduleSectionRef.current) {
            observer.observe(scheduleSectionRef.current);
        }
        return () => observer.disconnect();
    }, [scheduleAnimated]);

    const currentColors = themes[theme];

    // Access translated strings
    const t = (key) => {
        return translations[language]?.[key] || translations.en[key] || '';
    };

    // Trigger feedback message
    const showToast = (msg) => {
        setToastMessage(msg);
        setTimeout(() => setToastMessage(null), 3000);
    };

    // Spawn visual feedback sparkles
    const spawnSparkles = (e) => {
        if (!particleContainerRef.current) return;
        const rect = e.currentTarget.getBoundingClientRect();
        const spawnX = rect.left + rect.width / 2 + window.scrollX;
        const spawnY = rect.top + rect.height / 2 + window.scrollY;

        for (let i = 0; i < 12; i++) {
            const p = document.createElement('div');
            p.className = 'absolute w-1.5 h-1.5 rounded-full pointer-events-none z-50 transition-all duration-700 ease-out';
            const colors = ['#8b5cf6', '#f43f5e', '#ec4899', '#f59e0b', '#10b981', '#38bdf8'];
            p.style.backgroundColor = colors[Math.floor(Math.random() * colors.length)];
            p.style.left = `${spawnX}px`;
            p.style.top = `${spawnY}px`;
            particleContainerRef.current.appendChild(p);

            const angle = Math.random() * Math.PI * 2;
            const velocity = 25 + Math.random() * 40;
            
            // Trigger animation in micro-task
            setTimeout(() => {
                p.style.transform = `translate(${Math.cos(angle) * velocity}px, ${Math.sin(angle) * velocity}px) scale(0.1)`;
                p.style.opacity = '0';
            }, 10);

            setTimeout(() => p.remove(), 750);
        }
    };

    // Add to local list helper
    const handleAddToWatchlist = (anime, status) => {
        const alreadyExists = watchlist.some(item => item.id === anime.id);
        if (alreadyExists) {
            showToast(`${anime.title} ${language === 'ar' ? 'موجود بالفعل في قائمتك!' : 'is already in your watchlist!'}`);
            return;
        }

        const newTracked = {
            id: anime.id,
            title: anime.title,
            image: anime.image,
            episodeProgress: status === 'completed' ? anime.episodes : 0,
            episodes: anime.episodes,
            score: anime.score,
            category: status,
            genres: anime.genres,
            studios: anime.studios,
            userRating: 0,
            synopsis: anime.synopsis
        };

        setWatchlist(prev => [newTracked, ...prev]);
        showToast(`${language === 'ar' ? 'تمت إضافة' : 'Added'} ${anime.title} ${language === 'ar' ? 'إلى قائمتك!' : 'to your watchlist!'}`);
    };

    // Increment progress
    const handleIncrement = (id, e) => {
        if (e) spawnSparkles(e);
        setWatchlist(prev => prev.map(item => {
            if (item.id === id) {
                const nextProgress = Math.min(item.episodes, item.episodeProgress + 1);
                const isCompleted = nextProgress >= item.episodes && item.episodes > 0;
                return {
                    ...item,
                    episodeProgress: nextProgress,
                    category: isCompleted ? 'completed' : item.category
                };
            }
            return item;
        }));
    };

    // Decrement progress
    const handleDecrement = (id, e) => {
        if (e) spawnSparkles(e);
        setWatchlist(prev => prev.map(item => {
            if (item.id === id) {
                const nextProgress = Math.max(0, item.episodeProgress - 1);
                return {
                    ...item,
                    episodeProgress: nextProgress,
                    category: nextProgress === 0 ? 'watching' : item.category
                };
            }
            return item;
        }));
    };

    // Delete item
    const handleDelete = (id, e) => {
        if (e) spawnSparkles(e);
        setWatchlist(prev => prev.filter(item => item.id !== id));
        showToast(language === 'ar' ? "تمت الإزالة من قائمة التتبع." : "Removed from tracking list.");
    };

    // Update user personal rating
    const handleUpdateRating = (id, rating) => {
        setWatchlist(prev => prev.map(item => {
            if (item.id === id) {
                return { ...item, userRating: rating };
            }
            return item;
        }));
    };

    // Sync animation
    const triggerSync = () => {
        setSyncing(true);
        setTimeout(() => {
            setSyncing(false);
            showToast(language === 'ar' ? "تمت مزامنة البيانات بنجاح مع MyAnimeList! 🌟" : "Successfully synchronized database with MyAnimeList! 🌟");
        }, 1800);
    };

    // Calculate interactive stats
    const totalEpisodes = watchlist.reduce((sum, item) => sum + item.episodeProgress, 0);
    const totalDays = ((totalEpisodes * 23.5) / 1440).toFixed(1);
    const avgScore = watchlist.filter(item => item.userRating > 0).reduce((sum, item) => sum + item.userRating, 0) / (watchlist.filter(item => item.userRating > 0).length || 1);
    
    // Find top studio from tracked anime
    const studioCounts = {};
    watchlist.forEach(item => {
        item.studios.forEach(s => {
            studioCounts[s] = (studioCounts[s] || 0) + 1;
        });
    });
    const topStudio = Object.keys(studioCounts).reduce((a, b) => studioCounts[a] > studioCounts[b] ? a : b, 'Toei Animation');

    // Extract unique genres for filter chips
    const allGenresSet = new Set();
    animeData.forEach(anime => anime.genres.forEach(g => allGenresSet.add(g)));
    const genreList = Array.from(allGenresSet).slice(0, 14);

    // Filter database
    const filteredAnime = animeData.filter(anime => {
        const matchesSearch = anime.title.toLowerCase().includes(searchQuery.toLowerCase()) || 
                             anime.englishTitle.toLowerCase().includes(searchQuery.toLowerCase());
        const matchesGenre = selectedGenre ? anime.genres.includes(selectedGenre) : true;
        return matchesSearch && matchesGenre;
    }).slice(0, 36);

    // Setup rows of anime posters dynamically based on device size & power to optimize performance
    const getMarqueeRows = () => {
        if (screenSize === 'mobile') {
            return {
                r1: animeData.slice(0, 6),
                r2: animeData.slice(6, 12),
                r3: [],
                r4: []
            };
        } else if (screenSize === 'tablet') {
            return {
                r1: animeData.slice(0, 10),
                r2: animeData.slice(10, 20),
                r3: animeData.slice(20, 30),
                r4: []
            };
        } else {
            return {
                r1: animeData.slice(0, 15),
                r2: animeData.slice(15, 30),
                r3: animeData.slice(30, 45),
                r4: animeData.slice(45, 60)
            };
        }
    };

    const { r1: bgRow1, r2: bgRow2, r3: bgRow3, r4: bgRow4 } = getMarqueeRows();

    return (
        <div 
            className="min-h-screen relative overflow-x-hidden transition-colors duration-300"
            style={{ 
                backgroundColor: currentColors.bg, 
                color: currentColors.text,
                fontFamily: 'Outfit, sans-serif'
            }}
            dir={language === 'ar' ? 'rtl' : 'ltr'}
        >
            {/* Global particle container */}
            <div ref={particleContainerRef} className="fixed inset-0 pointer-events-none z-55 overflow-hidden" />

            {/* Toast Alerts */}
            {toastMessage && (
                <div className="fixed bottom-6 right-6 z-[100] glass border border-violet-500/30 px-5 py-3 rounded-2xl flex items-center gap-2 shadow-2xl animate-bounce">
                    <Sparkles className="w-4 h-4 text-violet-400" />
                    <span className="text-xs font-bold text-white">{toastMessage}</span>
                </div>
            )}

            {/* HEADER */}
            <header className="sticky top-0 z-40 glass border-b border-white/5 px-6 py-4">
                <div className="max-w-7xl mx-auto flex items-center justify-between">
                    <a href="#hero" onClick={(e) => { e.preventDefault(); scrollToSection('hero'); }} className="flex items-center gap-3">
                        <img src="./MA_logo.webp" width="36" height="36" fetchpriority="high" className="w-9 h-9 rounded-xl shadow-lg border border-white/10 object-contain" alt="MA Logo" />
                        <div className="flex flex-col">
                            <span className="font-extrabold text-lg tracking-wider leading-none">{t('title')}</span>
                        </div>
                    </a>

                    <nav className="hidden md:flex items-center gap-8 text-sm font-medium">
                        <a href="#hero" onClick={(e) => { e.preventDefault(); scrollToSection('hero'); }} className="hover:text-violet-400 transition-colors">{t('home')}</a>
                        <a href="#hub" onClick={(e) => { e.preventDefault(); scrollToSection('hub'); }} className="hover:text-violet-400 transition-colors">{t('animeHub')}</a>
                        <a href="#watchlist" onClick={(e) => { e.preventDefault(); scrollToSection('watchlist'); }} className="hover:text-violet-400 transition-colors">{t('myWatchlist')}</a>
                        <a href="#schedule-showcase" onClick={(e) => { e.preventDefault(); scrollToSection('schedule-showcase'); }} className="hover:text-violet-400 transition-colors">{t('telemetryStats')}</a>
                    </nav>

                    <div className="flex items-center gap-4">
                        <button
                            onClick={() => {
                                const nextTheme = theme === 'default_dark' ? 'default_light' : 
                                                 theme === 'default_light' ? 'cyberpunk_neon' : 
                                                 theme === 'cyberpunk_neon' ? 'sakura_blossom' : 
                                                 theme === 'sakura_blossom' ? 'midnight_abyss' : 
                                                 theme === 'midnight_abyss' ? 'retro_forest' : 'default_dark';
                                setTheme(nextTheme);
                                showToast(`Theme updated to: ${nextTheme.replace('_', ' ')}`);
                            }}
                            className="p-2 rounded-full border border-white/10 hover:bg-white/5 transition-all active:scale-95 text-slate-400 hover:text-white"
                            title="Toggle Theme"
                            aria-label="Toggle Theme"
                        >
                            <Sliders className="w-4 h-4" />
                        </button>
                        
                        <button
                            onClick={() => {
                                const nextLang = language === 'en' ? 'ar' : 'en';
                                setLanguage(nextLang);
                                showToast(nextLang === 'ar' ? 'تم تغيير اللغة إلى العربية' : 'Language set to English');
                            }}
                            className="p-2 rounded-full border border-white/10 hover:bg-white/5 transition-all active:scale-95 text-slate-400 hover:text-white"
                            title="Toggle Language"
                            aria-label="Toggle Language"
                        >
                            <Languages className="w-4 h-4" />
                        </button>

                        <a
                            href="https://github.com/LOMoriartyVE/myanimes-privacy"
                            target="_blank"
                            rel="noopener noreferrer"
                            style={{ 
                                background: 'linear-gradient(to right, #7c3aed, #db2777)',
                                color: '#ffffff'
                            }}
                            className="relative group overflow-hidden px-5 py-2.5 rounded-full text-sm font-semibold hover:opacity-95 transition-all shadow-lg"
                        >
                            <span className="relative z-10 flex items-center gap-2 text-white">
                                {language === 'ar' ? 'تصفح المركز' : 'Browse Hub'} <Search className="w-3.5 h-3.5" />
                            </span>
                        </a>
                    </div>
                </div>
            </header>

            {/* HERO SECTION WITH FLOWING POSTERS BACKGROUND */}
            <section id="hero" className="relative w-full min-h-[95vh] flex items-center justify-center overflow-hidden py-16 px-6">
                
                {/* Layer 1: Scrolling Anime Posters Horizontal Rows Background (z-0, bottom) */}
                <div dir="ltr" className="absolute inset-0 z-0 flex flex-col gap-4 justify-between py-12 pointer-events-none select-none overflow-hidden opacity-25">
                    {bgRow1.length > 0 && <PosterRow items={bgRow1} direction="left" duration="52s" delay="-15s" />}
                    {bgRow2.length > 0 && <PosterRow items={bgRow2} direction="right" duration="68s" delay="-30s" />}
                    {bgRow3.length > 0 && <PosterRow items={bgRow3} direction="left" duration="58s" delay="-8s" />}
                    {bgRow4.length > 0 && <PosterRow items={bgRow4} direction="right" duration="74s" delay="-45s" />}
                </div>

                {/* Layer 3: Combined Horizontal & Vertical Fade Gradients (z-20) */}
                <div 
                    className="absolute inset-0 pointer-events-none z-20"
                    style={{
                        background: `linear-gradient(to right, ${currentColors.bg} 0%, transparent 25%, transparent 75%, ${currentColors.bg} 100%), linear-gradient(to bottom, ${currentColors.bg} 0%, transparent 15%, transparent 85%, ${currentColors.bg} 100%)`
                    }}
                />

                {/* Layer 3b: Grid dots pattern overlay (z-25, positioned above gradients and posters for full canvas texture) */}
                <div className={`absolute inset-0 pointer-events-none z-25 ${currentColors.isDark ? 'grid-dots' : 'grid-dots-light'}`} />
                
                {/* Glowing Ambient Orb */}
                <div className="absolute inset-0 pointer-events-none overflow-hidden z-20">
                    <div 
                        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[550px] h-[550px] rounded-full blur-[130px] opacity-15 animate-pulse-glow"
                        style={{ backgroundColor: currentColors.accent }}
                    />
                </div>

                {/* Layer 4: Central Hero / Hook Card (z-30, on top, transparent background) */}
                <div 
                    className="max-w-4xl mx-auto text-center relative z-30 space-y-8 p-8 sm:p-12 rounded-3xl transition-all duration-300"
                    style={{
                        backgroundColor: 'transparent'
                    }}
                >
                    <div className="inline-flex items-center gap-2 bg-violet-500/10 border border-violet-500/30 rounded-full px-4 py-1.5 text-xs text-violet-400 font-semibold uppercase tracking-wider">
                        <Flame className="w-3.5 h-3.5 text-rose-500 fill-rose-500" /> {t('heroTag')}
                    </div>

                    <h1 className="text-4xl sm:text-6xl font-extrabold leading-tight tracking-tight font-display">
                        {language === 'ar' ? (
                            <>
                                تتبع رحلة <span className="bg-gradient-to-r from-violet-400 via-fuchsia-400 to-rose-400 text-transparent bg-clip-text text-glow font-display">الأنمي والمانجا</span> <br />
                                الخاصة بك بسهولة.
                            </>
                        ) : (
                            <>
                                Track Your <span className="bg-gradient-to-r from-violet-400 via-fuchsia-400 to-rose-400 text-transparent bg-clip-text text-glow font-display">Anime & Manga</span> <br />
                                Journey Everywhere.
                            </>
                        )}
                    </h1>

                    <p className="text-base sm:text-lg text-slate-400 max-w-2xl mx-auto leading-relaxed">
                        {t('heroDesc')}
                    </p>

                    {/* Key Watch Telemetry Metrics (App abilities format) */}
                    <div className="grid grid-cols-3 gap-6 max-w-lg mx-auto py-6 border-y border-white/10">
                        <div>
                            <div className="text-2xl sm:text-3xl font-extrabold text-white font-display">{t('heroStat1Value')}</div>
                            <div className="text-[10px] text-slate-500 uppercase tracking-widest mt-1">{t('heroStat1Label')}</div>
                        </div>
                        <div>
                            <div className="text-2xl sm:text-3xl font-extrabold text-white font-display">{t('heroStat2Value')}</div>
                            <div className="text-[10px] text-slate-500 uppercase tracking-widest mt-1">{t('heroStat2Label')}</div>
                        </div>
                        <div>
                            <div className="text-2xl sm:text-3xl font-extrabold text-white font-display">{t('heroStat3Value')}</div>
                            <div className="text-[10px] text-slate-500 uppercase tracking-widest mt-1">{t('heroStat3Label')}</div>
                        </div>
                    </div>

                    {/* App Downloads Actions */}
                    <div className="flex flex-wrap items-center justify-center gap-6 pt-4">
                        <button
                            onClick={() => {
                                showToast(language === 'ar' ? "جاري تحميل ملف APK للأندرويد..." : "Downloading Android APK...");
                                setTimeout(() => {
                                    window.location.href = "https://github.com/LOMoriartyVE/myanimes-privacy/releases/download/1.1.70/MyAnimes.apk";
                                }, 1000);
                            }}
                            style={{ 
                                background: 'linear-gradient(to right, #7c3aed, #db2777)',
                                color: '#ffffff'
                            }}
                            className="group flex items-center gap-3 hover:opacity-90 px-8 py-4 rounded-2xl font-bold transition-all transform hover:-translate-y-1 shadow-2xl"
                        >
                            <Smartphone className="w-6 h-6" />
                            <div className="text-left leading-none">
                                <span className="text-[10px] uppercase text-slate-200 block">{language === 'ar' ? 'تحميل تطبيق' : 'Download APK for'}</span>
                                <span className="text-base font-bold font-sans">{language === 'ar' ? 'أندرويد الهاتف' : 'Android Mobile'}</span>
                            </div>
                        </button>
                        <button
                            onClick={() => {
                                showToast(language === 'ar' ? "جاري تحميل برنامج تثبيت ويندوز..." : "Downloading Windows Installer...");
                                setTimeout(() => {
                                    window.location.href = "https://github.com/LOMoriartyVE/myanimes-privacy/releases/download/1.1.70.Win2/MyAnimes-Setup.exe";
                                }, 1000);
                            }}
                            style={{ 
                                backgroundColor: currentColors.isDark ? '#131622' : '#f1f5f9',
                                color: currentColors.text,
                                borderColor: currentColors.border 
                            }}
                            className="group flex items-center gap-3 hover:opacity-90 px-8 py-4 rounded-2xl font-bold transition-all transform hover:-translate-y-1 shadow-2xl border"
                        >
                            <Tv className="w-6 h-6 text-violet-400" />
                            <div className="text-left leading-none">
                                <span className="text-[10px] uppercase text-slate-455 block">{language === 'ar' ? 'تحميل برنامج التثبيت' : 'Download Installer for'}</span>
                                <span className="text-base font-bold font-sans">{language === 'ar' ? 'لويندوز المكتبي' : 'Windows Client'}</span>
                            </div>
                        </button>
                    </div>

                    {/* Feature icons */}
                    <div className="text-slate-500 text-xs pt-4 flex flex-wrap justify-center items-center gap-6">
                        <span><Shield className="w-4 h-4 text-violet-500 inline mr-1" /> {t('noAds')}</span>
                        <span><Sparkles className="w-4 h-4 text-rose-500 inline mr-1" /> {t('freeForever')}</span>
                        <span><Heart className="w-4 h-4 text-amber-500 inline mr-1" /> {t('madeByFans')}</span>
                    </div>
                </div>
            </section>

            {/* DYNAMIC INTERACTIVE ZONE (COMPANION APP INTERFACE) */}
            <main className="max-w-7xl mx-auto px-6 py-12 relative z-20 space-y-16">
                
                {/* SCROLLYTELLING CONSTRUCTING ANIME PAGE SECTION */}
                <section ref={scrollySectionRef} id="hub" className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center py-16 scroll-mt-24 overflow-visible">
                    
                    {/* Left: Angled Construction Mockup (6 Columns on large screens) */}
                    <div className="lg:col-span-6 relative flex items-center justify-center min-h-[640px] overflow-visible perspective-[1500px] select-none">
                        {(() => {
                            const currentAnime = popular10[displayedMockIndex];
                            return (
                                <div 
                                    className="w-full max-w-sm relative transition-all duration-700 ease-out cursor-pointer active:scale-98"
                                    style={{
                                        transform: 'rotateX(8deg) rotateY(28deg) rotateZ(-4deg)',
                                        transformStyle: 'preserve-3d'
                                    }}
                                    onClick={() => {
                                        setSelectedAnime(currentAnime);
                                        showToast(language === 'ar' ? `تم فتح تفاصيل ${currentAnime.englishTitle || currentAnime.title}!` : `Opened ${currentAnime.englishTitle || currentAnime.title} details!`);
                                    }}
                                >
                                    {/* Component 1: Main Header Card (Overview Details) */}
                                    <div className="anime-comp-poster bg-[#131622]/95 border border-white/10 rounded-3xl p-5 shadow-2xl backdrop-blur-md transition-all duration-300 z-10" style={{ transform: 'translateZ(50px)' }}>
                                        {/* Top Bar inside mockup */}
                                        <div className="flex items-center justify-between mb-4">
                                            <div className="w-8 h-8 rounded-full bg-black/40 border border-white/5 flex items-center justify-center text-slate-400">
                                                <ChevronDown className="w-4 h-4 rotate-90" />
                                            </div>
                                            <div className="flex gap-2">
                                                <div className="w-8 h-8 rounded-full bg-black/40 border border-white/5 flex items-center justify-center text-amber-550">
                                                    <Bell className="w-4 h-4 fill-current" />
                                                </div>
                                                <div className="w-8 h-8 rounded-full bg-black/40 border border-white/5 flex items-center justify-center text-slate-400">
                                                    <Share2 className="w-4 h-4" />
                                                </div>
                                            </div>
                                        </div>

                                        {/* Poster cover */}
                                        <div className="w-36 h-52 mx-auto rounded-2xl overflow-hidden shadow-2xl border border-white/10 relative mb-4 bg-slate-900">
                                            <img 
                                                src={currentAnime.image} 
                                                alt={currentAnime.title} 
                                                className="w-full h-full object-cover" 
                                                loading="lazy"
                                                onError={(e) => {
                                                    e.target.onerror = null;
                                                    e.target.src = "./MA_logo.webp";
                                                }}
                                            />
                                            <span className="absolute top-2 left-2 text-[9px] bg-black/75 text-slate-305 font-extrabold px-2 py-0.5 rounded-lg border border-white/10">{currentAnime.type}</span>
                                        </div>

                                        {/* Badges */}
                                        <div className="anime-comp-header-badges flex flex-wrap justify-center gap-1.5 mb-3.5">
                                            <span className="text-[8px] bg-violet-500/10 text-violet-400 border border-violet-500/20 px-2.5 py-0.5 rounded-full font-bold">
                                                {currentAnime.studios.join(', ')}
                                            </span>
                                            <span className="text-[8px] bg-rose-500/10 text-rose-450 border border-rose-500/20 px-2.5 py-0.5 rounded-full font-bold">
                                                {currentAnime.status}
                                            </span>
                                        </div>

                                        {/* Title / Subtitles */}
                                        <div className="anime-comp-title text-center space-y-1 mb-4">
                                            <h3 className="text-xs font-black text-white leading-snug">
                                                {currentAnime.englishTitle || currentAnime.title}
                                            </h3>
                                            <p className="text-[8px] text-slate-550 font-semibold truncate">
                                                {currentAnime.title}
                                            </p>
                                            {currentAnime.japaneseTitle && (
                                                <p className="text-[7.5px] text-slate-650 font-extrabold">
                                                    {currentAnime.japaneseTitle}
                                                </p>
                                            )}
                                        </div>

                                        {/* MAL Score Box */}
                                        <div className="anime-comp-score-box grid grid-cols-4 gap-2 bg-black/35 border border-white/5 rounded-2xl p-2.5 mb-4 text-center">
                                            <div>
                                                <div className="text-[7px] text-slate-500 uppercase tracking-wider font-extrabold">MAL Score</div>
                                                <div className="text-xs font-black text-amber-400 mt-0.5 flex items-center justify-center gap-0.5">★ {currentAnime.score}</div>
                                            </div>
                                            <div>
                                                <div className="text-[7px] text-slate-500 uppercase tracking-wider font-extrabold">Rank</div>
                                                <div className="text-xs font-black text-white mt-0.5">#{displayedMockIndex + 1}</div>
                                            </div>
                                            <div>
                                                <div className="text-[7px] text-slate-500 uppercase tracking-wider font-extrabold">Popularity</div>
                                                <div className="text-xs font-black text-white mt-0.5">#{100 + displayedMockIndex * 24}</div>
                                            </div>
                                            <div>
                                                <div className="text-[7px] text-slate-500 uppercase tracking-wider font-extrabold">Members</div>
                                                <div className="text-xs font-black text-violet-400 mt-0.5">{((1.8 - displayedMockIndex * 0.12)).toFixed(1)}M</div>
                                            </div>
                                        </div>

                                        {/* Tracking Actions */}
                                        <div className="flex gap-2">
                                            <button className="anime-comp-action-btn flex-1 bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 rounded-xl py-2.5 text-[10px] font-bold flex items-center justify-center gap-1.5">
                                                <Check className="w-3.5 h-3.5" /> Added to List
                                            </button>
                                            <button className="anime-comp-action-btn w-11 bg-black/40 border border-white/5 rounded-xl flex items-center justify-center text-slate-400 hover:text-white">
                                                <Star className="w-3.5 h-3.5 fill-current text-violet-400" />
                                            </button>
                                        </div>

                                        {/* Tabs bar */}
                                        <div className="anime-comp-overview-tabs flex border-t border-white/5 mt-4 pt-3.5 gap-2 overflow-x-auto no-scrollbar">
                                            <span className="text-[9px] font-bold text-violet-400 bg-violet-500/10 border border-violet-500/20 px-2.5 py-1 rounded-lg">Overview</span>
                                            <span className="text-[9px] font-bold text-slate-455 px-2.5 py-1">Metrics & Stats</span>
                                            <span className="text-[9px] font-bold text-slate-455 px-2.5 py-1">Cast</span>
                                        </div>
                                    </div>

                                    {/* Component 2: Specifications Card */}
                                    <div className="anime-comp-spec-card absolute -bottom-10 -right-2 sm:-top-16 sm:-right-28 sm:bottom-auto w-48 sm:w-64 bg-[#131622]/95 border border-white/10 rounded-2xl p-3 sm:p-4 shadow-2xl backdrop-blur-md transition-all duration-300 z-30" style={{ transform: 'translateZ(90px)' }}>
                                        <h4 className="text-[8px] uppercase tracking-wider text-slate-400 font-extrabold border-b border-white/5 pb-1.5 mb-2 sm:mb-3">{language === 'ar' ? 'المواصفات' : 'Specifications'}</h4>
                                        <div className="space-y-1.5 sm:space-y-2 text-[9px] sm:text-[10px]">
                                            <div className="flex justify-between"><span className="text-slate-500">{language === 'ar' ? 'النوع' : 'Type'}</span><span className="text-slate-200 font-bold bg-white/5 px-1 sm:px-1.5 py-0.5 rounded text-[8px] sm:text-[9px]">{currentAnime.type}</span></div>
                                            <div className="flex justify-between"><span className="text-slate-500">{language === 'ar' ? 'الحلقات' : 'Episodes'}</span><span className="text-slate-200 font-semibold">{currentAnime.episodes} episodes</span></div>
                                            <div className="flex justify-between"><span className="text-slate-500">{language === 'ar' ? 'المدة' : 'Duration'}</span><span className="text-slate-200 font-semibold">24 min</span></div>
                                            <div className="flex justify-between"><span className="text-slate-500">{language === 'ar' ? 'تاريخ البث' : 'Aired Dates'}</span><span className="text-slate-200 font-semibold truncate block max-w-[100px] sm:max-w-[140px]">{currentAnime.aired}</span></div>
                                            <div className="flex justify-between"><span className="text-slate-500">{language === 'ar' ? 'الموسم' : 'Season'}</span><span className="text-amber-500 font-bold uppercase text-[7px] sm:text-[8px] tracking-wider">{displayedMockIndex % 2 === 0 ? "Fall" : "Spring"}</span></div>
                                            <div className="flex justify-between"><span className="text-slate-500">{language === 'ar' ? 'البث' : 'Broadcast'}</span><span className="text-slate-200 font-semibold truncate max-w-[100px] sm:max-w-[160px]">{language === 'ar' ? 'السبت 23:00' : 'Saturdays 23:00'}</span></div>
                                            <div className="flex justify-between"><span className="text-slate-500">{language === 'ar' ? 'المصدر' : 'Source'}</span><span className="text-slate-200 font-semibold">Manga</span></div>
                                            <div className="flex justify-between"><span className="text-slate-500">{language === 'ar' ? 'التصنيف' : 'Rating'}</span><span className="text-slate-200 font-semibold truncate max-w-[100px] sm:max-w-[160px]">PG-13</span></div>
                                        </div>
                                    </div>

                                    {/* Component 3: Classifications Card */}
                                    <div className="anime-comp-classifications absolute -bottom-24 -left-6 w-60 bg-[#131622]/95 border border-white/10 rounded-2xl p-4 shadow-2xl backdrop-blur-md transition-all duration-300 z-20" style={{ transform: 'translateZ(70px)' }}>
                                        <h4 className="text-[8px] uppercase tracking-wider text-slate-400 font-extrabold border-b border-white/5 pb-2 mb-3">{language === 'ar' ? 'التصنيفات' : 'Classifications'}</h4>
                                        <div className="flex flex-wrap gap-1.5">
                                            {currentAnime.genres.map(tag => (
                                                <span key={tag} className="bg-black/45 text-slate-300 border border-white/5 text-[9px] font-bold px-2 py-0.5 rounded-lg">
                                                    {tag}
                                                </span>
                                            ))}
                                        </div>
                                    </div>
                                </div>
                            );
                        })()}
                    </div>

                    {/* Right: Description Block (6 Columns on large screens) */}
                    <div className="anime-desc-text-right lg:col-span-6 space-y-6 text-left rtl:text-right opacity-0 transform">
                        <div className="space-y-3">
                            <div className="flex items-center gap-1.5 h-7 mb-1 overflow-hidden select-none">
                                <span className="text-emerald-400 font-black tracking-wide text-lg">{language === 'ar' ? 'احصل على' : 'Get'}</span>
                                <span style={{ color: currentColors.text }} className="font-black text-lg border-r-2 border-emerald-400 animate-pulse pr-1 leading-none">
                                    {typedText}
                                </span>
                            </div>
                            <span className="text-xs uppercase tracking-widest text-violet-400 font-extrabold block">{t('scrollySubtitle')}</span>
                            <h2 style={{ color: currentColors.text }} className="text-3xl sm:text-4xl font-extrabold leading-tight">
                                {t('scrollyTitle')}
                            </h2>
                            <p className="text-slate-400 text-sm leading-relaxed">
                                {t('scrollyDesc')}
                            </p>
                        </div>

                        {/* Scrolly Points list */}
                        <div className="space-y-5">
                            <div className="flex gap-4 items-start">
                                <div className="w-10 h-10 rounded-xl bg-violet-600/10 border border-violet-500/20 flex items-center justify-center text-violet-400 flex-shrink-0">
                                    <Activity className="w-5 h-5" />
                                </div>
                                <div className="space-y-1">
                                    <h4 style={{ color: currentColors.text }} className="text-sm font-bold">{t('scrollyPoint1Title')}</h4>
                                    <p className="text-xs text-slate-450 leading-relaxed">{t('scrollyPoint1Desc')}</p>
                                </div>
                            </div>

                            <div className="flex gap-4 items-start">
                                <div className="w-10 h-10 rounded-xl bg-rose-600/10 border border-rose-500/20 flex items-center justify-center text-rose-450 flex-shrink-0">
                                    <Tv className="w-5 h-5" />
                                </div>
                                <div className="space-y-1">
                                    <h4 style={{ color: currentColors.text }} className="text-sm font-bold">{t('scrollyPoint2Title')}</h4>
                                    <p className="text-xs text-slate-450 leading-relaxed">{t('scrollyPoint2Desc')}</p>
                                </div>
                            </div>

                            <div className="flex gap-4 items-start">
                                <div className="w-10 h-10 rounded-xl bg-amber-600/10 border border-amber-500/20 flex items-center justify-center text-amber-550 flex-shrink-0">
                                    <Sliders className="w-5 h-5" />
                                </div>
                                <div className="space-y-1">
                                    <h4 style={{ color: currentColors.text }} className="text-sm font-bold">{t('scrollyPoint3Title')}</h4>
                                    <p className="text-xs text-slate-450 leading-relaxed">{t('scrollyPoint3Desc')}</p>
                                </div>
                            </div>
                        </div>
                    </div>

                </section>

                {/* WATCHLIST SHOWCASE SECTION */}
                <section ref={watchlistSectionRef} id="watchlist" className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center py-16 scroll-mt-24 overflow-visible">
                    
                    {/* Left: Description Column */}
                    <div className="watchlist-desc-text-left lg:col-span-6 space-y-6 text-left rtl:text-right opacity-0 transform">
                        <div className="space-y-3">
                            <span className="text-xs uppercase tracking-widest text-violet-400 font-extrabold block">{t('watchlistShowcaseSubtitle')}</span>
                            <h2 style={{ color: currentColors.text }} className="text-3xl sm:text-4xl font-extrabold leading-tight">
                                {t('watchlistShowcaseTitle')}
                            </h2>
                            <p className="text-slate-400 text-sm leading-relaxed">
                                {t('watchlistShowcaseDesc')}
                            </p>
                        </div>

                        {/* Feature points */}
                        <div className="space-y-5">
                            <div className="flex gap-4 items-start">
                                <div className="w-10 h-10 rounded-xl bg-violet-600/10 border border-violet-500/20 flex items-center justify-center text-violet-400 flex-shrink-0">
                                    <Filter className="w-5 h-5" />
                                </div>
                                <div className="space-y-1">
                                    <h4 style={{ color: currentColors.text }} className="text-sm font-bold">{t('watchlistPoint1Title')}</h4>
                                    <p className="text-xs text-slate-455 leading-relaxed">{t('watchlistPoint1Desc')}</p>
                                </div>
                            </div>

                            <div className="flex gap-4 items-start">
                                <div className="w-10 h-10 rounded-xl bg-rose-600/10 border border-rose-500/20 flex items-center justify-center text-rose-455 flex-shrink-0">
                                    <Activity className="w-5 h-5" />
                                </div>
                                <div className="space-y-1">
                                    <h4 style={{ color: currentColors.text }} className="text-sm font-bold">{t('watchlistPoint2Title')}</h4>
                                    <p className="text-xs text-slate-455 leading-relaxed">{t('watchlistPoint2Desc')}</p>
                                </div>
                            </div>

                            <div className="flex gap-4 items-start">
                                <div className="w-10 h-10 rounded-xl bg-amber-600/10 border border-amber-500/20 flex items-center justify-center text-amber-550 flex-shrink-0">
                                    <RotateCw className="w-5 h-5" />
                                </div>
                                <div className="space-y-1">
                                    <h4 style={{ color: currentColors.text }} className="text-sm font-bold">{t('watchlistPoint3Title')}</h4>
                                    <p className="text-xs text-slate-455 leading-relaxed">{t('watchlistPoint3Desc')}</p>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Right: Mirrored Angled Mobile Watchlist Mockup */}
                    <div className="lg:col-span-6 relative flex items-center justify-center min-h-[640px] overflow-visible perspective-[1500px] select-none">
                        <div 
                            className="watchlist-mockup-container w-full max-w-sm relative transition-all duration-700 ease-out cursor-pointer active:scale-98 bg-[#131622]/95 border border-white/10 rounded-[32px] p-5 shadow-2xl backdrop-blur-md"
                            style={{
                                transform: 'rotateX(8deg) rotateY(-28deg) rotateZ(4deg)',
                                transformStyle: 'preserve-3d'
                            }}
                        >
                            {/* App top bar */}
                            <div className="flex items-center justify-between mb-5 gap-3 border-b border-white/5 pb-3">
                                <div className="flex items-center gap-1.5">
                                    <div className="w-8 h-8 rounded-xl overflow-hidden border border-white/10 flex items-center justify-center bg-black/40"><img src="./MA_logo.webp" className="w-full h-full object-contain" alt="MA Logo" /></div>
                                </div>
                                <div className="flex-1 bg-black/45 border border-white/5 rounded-full px-3 py-1.5 flex items-center gap-2 text-slate-500">
                                    <Search className="w-3.5 h-3.5" />
                                    <span className="text-[10px] font-semibold">Search anime...</span>
                                </div>
                                <div className="w-8 h-8 rounded-full border border-white/10 overflow-hidden bg-slate-900">
                                    <div className="w-full h-full bg-violet-600/30 flex items-center justify-center text-[10px] font-bold text-violet-400">JD</div>
                                </div>
                            </div>

                            {/* Page header */}
                            <div className="flex items-center justify-between mb-4">
                                <h3 className="text-lg font-black text-white">{language === 'ar' ? 'قائمتي' : 'My List'}</h3>
                                <div className="flex gap-2 text-slate-400">
                                    <div className="w-7 h-7 rounded-lg bg-black/30 border border-white/5 flex items-center justify-center"><BarChart3 className="w-3.5 h-3.5" /></div>
                                    <div className="w-7 h-7 rounded-lg bg-black/30 border border-white/5 flex items-center justify-center"><Share2 className="w-3.5 h-3.5" /></div>
                                    <div className="w-7 h-7 rounded-lg bg-black/30 border border-white/5 flex items-center justify-center"><Sliders className="w-3.5 h-3.5" /></div>
                                </div>
                            </div>

                            {/* Search my list */}
                            <div className="bg-black/30 border border-white/5 rounded-xl px-3 py-2 flex items-center gap-2 text-slate-500 mb-4 text-left rtl:text-right">
                                <Search className="w-3.5 h-3.5" />
                                <span className="text-[10px] font-semibold">Search my list...</span>
                            </div>

                            {/* Filter category tabs */}
                            <div className="grid grid-cols-4 gap-1 bg-black/35 border border-white/5 rounded-xl p-1 mb-5">
                                <div className="bg-violet-600/20 border border-violet-500/30 text-white rounded-lg py-1.5 text-[9px] font-bold text-center capitalize">{language === 'ar' ? 'أشاهد' : 'Watching'} (18)</div>
                                <div className="text-slate-450 rounded-lg py-1.5 text-[9px] font-bold text-center capitalize">{language === 'ar' ? 'مكتمل' : 'Completed'} (136)</div>
                                <div className="text-slate-450 rounded-lg py-1.5 text-[9px] font-bold text-center capitalize">{language === 'ar' ? 'مخطط' : 'Planned'} (4)</div>
                                <div className="text-slate-450 rounded-lg py-1.5 text-[9px] font-bold text-center capitalize">{language === 'ar' ? 'تجاهل' : 'Ignored'} (0)</div>
                            </div>

                            {/* Cards list */}
                            <div className="space-y-3 mb-6">
                                {/* Card 1 */}
                                <div className="watchlist-mockup-card bg-black/30 border border-white/5 rounded-2xl p-3 flex items-center justify-between gap-3 text-left rtl:text-right">
                                    <div className="flex items-center gap-3">
                                        <div className="w-11 h-15 rounded-lg overflow-hidden bg-slate-900 flex-shrink-0">
                                            <img src="https://cdn.myanimelist.net/images/anime/1337/99013l.webp" alt="Hunter x Hunter" className="w-full h-full object-cover" loading="lazy" />
                                        </div>
                                        <div className="space-y-1.5">
                                            <h4 className="text-[11px] font-bold text-white leading-tight">Hunter x Hunter (2011)</h4>
                                            <div className="flex items-center gap-2 bg-white/5 border border-white/10 rounded-lg px-2 py-0.5 w-max">
                                                <span className="text-[10px] text-slate-400 font-extrabold cursor-pointer hover:text-white">-</span>
                                                <span className="text-[10px] text-slate-200 font-black">148 / 148</span>
                                                <span className="text-[10px] text-violet-400 font-extrabold cursor-pointer hover:text-white">+</span>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="flex flex-col items-end gap-1.5">
                                        <div className="flex items-center gap-1">
                                            <span className="text-[7px] bg-sky-500/10 text-sky-400 border border-sky-500/20 px-1 py-0.5 rounded font-extrabold">MAL</span>
                                            <div className="w-4 h-4 rounded-full bg-white/5 flex items-center justify-center text-slate-400"><RotateCw className="w-2.5 h-2.5" /></div>
                                        </div>
                                        <div className="flex items-center gap-1">
                                            <span className="text-[10px] font-black text-white">★ 9.04</span>
                                            <Star className="w-3.5 h-3.5 text-violet-450 fill-violet-450" />
                                        </div>
                                    </div>
                                </div>

                                {/* Card 2 */}
                                <div className="watchlist-mockup-card bg-black/30 border border-white/5 rounded-2xl p-3 flex items-center justify-between gap-3 text-left rtl:text-right">
                                    <div className="flex items-center gap-3">
                                        <div className="w-11 h-15 rounded-lg overflow-hidden bg-slate-900 flex-shrink-0">
                                            <img src="https://cdn.myanimelist.net/images/anime/10/47347l.webp" alt="Attack on Titan" className="w-full h-full object-cover" loading="lazy" />
                                        </div>
                                        <div className="space-y-1.5">
                                            <h4 className="text-[11px] font-bold text-white leading-tight">Attack on Titan</h4>
                                            <div className="flex items-center gap-2 bg-white/5 border border-white/10 rounded-lg px-2 py-0.5 w-max">
                                                <span className="text-[10px] text-slate-400 font-extrabold cursor-pointer hover:text-white">-</span>
                                                <span className="text-[10px] text-slate-200 font-black">25 / 25</span>
                                                <span className="text-[10px] text-violet-400 font-extrabold cursor-pointer hover:text-white">+</span>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="flex flex-col items-end gap-1.5">
                                        <div className="flex items-center gap-1">
                                            <span className="text-[7px] bg-sky-500/10 text-sky-400 border border-sky-500/20 px-1 py-0.5 rounded font-extrabold">MAL</span>
                                            <div className="w-4 h-4 rounded-full bg-white/5 flex items-center justify-center text-slate-400"><RotateCw className="w-2.5 h-2.5" /></div>
                                        </div>
                                        <div className="flex items-center gap-1">
                                            <span className="text-[10px] font-black text-white">★ 8.57</span>
                                            <Star className="w-3.5 h-3.5 text-violet-450 fill-violet-450" />
                                        </div>
                                    </div>
                                </div>

                                {/* Card 3 */}
                                <div className="watchlist-mockup-card bg-black/30 border border-white/5 rounded-2xl p-3 flex items-center justify-between gap-3 text-left rtl:text-right">
                                    <div className="flex items-center gap-3">
                                        <div className="w-11 h-15 rounded-lg overflow-hidden bg-slate-900 flex-shrink-0">
                                            <img src="https://cdn.myanimelist.net/images/anime/1244/138851l.webp" alt="One Piece" className="w-full h-full object-cover" loading="lazy" />
                                        </div>
                                        <div className="space-y-1">
                                            <h4 className="text-[11px] font-bold text-white leading-tight">One Piece</h4>
                                            <div className="flex items-center gap-2 bg-white/5 border border-white/10 rounded-lg px-2 py-0.5 w-max">
                                                <span className="text-[10px] text-slate-400 font-extrabold cursor-pointer hover:text-white">-</span>
                                                <span className="text-[10px] text-slate-200 font-black">1100 / ?</span>
                                                <span className="text-[10px] text-violet-400 font-extrabold cursor-pointer hover:text-white">+</span>
                                            </div>
                                            <div className="text-[8px] text-violet-400 font-bold">Your Rating: 8.0</div>
                                        </div>
                                    </div>
                                    <div className="flex flex-col items-end gap-1.5">
                                        <div className="flex items-center gap-1">
                                            <span className="text-[7px] bg-sky-500/10 text-sky-400 border border-sky-500/20 px-1 py-0.5 rounded font-extrabold">MAL</span>
                                            <div className="w-4 h-4 rounded-full bg-white/5 flex items-center justify-center text-slate-400"><RotateCw className="w-2.5 h-2.5" /></div>
                                        </div>
                                        <div className="flex items-center gap-1">
                                            <span className="text-[10px] font-black text-white">★ 8.73</span>
                                            <Star className="w-3.5 h-3.5 text-violet-450 fill-violet-450" />
                                        </div>
                                    </div>
                                </div>
                            </div>

                            {/* App bottom navigation bar */}
                            <div className="border-t border-white/5 pt-3 flex items-center justify-between text-slate-500">
                                <div className="flex flex-col items-center gap-1 flex-1">
                                    <Home className="w-4 h-4" />
                                    <span className="text-[7px] font-extrabold">Home</span>
                                </div>
                                <div className="flex flex-col items-center gap-1 flex-1">
                                    <Calendar className="w-4 h-4" />
                                    <span className="text-[7px] font-extrabold">Schedule</span>
                                </div>
                                <div className="flex flex-col items-center gap-1 flex-1 text-violet-400 relative">
                                    <div className="absolute -top-1.5 right-4 bg-rose-500 text-white text-[7px] font-black w-3.5 h-3.5 rounded-full flex items-center justify-center border border-[#131622] scale-90">158</div>
                                    <List className="w-4 h-4" />
                                    <span className="text-[7px] font-extrabold">My List</span>
                                </div>
                                <div className="flex flex-col items-center gap-1 flex-1">
                                    <FolderHeart className="w-4 h-4" />
                                    <span className="text-[7px] font-extrabold">Library</span>
                                </div>
                                <div className="flex flex-col items-center gap-1 flex-1">
                                    <Sliders className="w-4 h-4" />
                                    <span className="text-[7px] font-extrabold">Settings</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </section>

                {/* WEEKLY SCHEDULE SHOWCASE SECTION */}
                <section ref={scheduleSectionRef} id="schedule-showcase" className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center py-16 scroll-mt-24 overflow-visible">
                    
                    {/* Left: Angled Mobile Schedule Mockup */}
                    <div className="lg:col-span-6 relative flex items-center justify-center min-h-[640px] overflow-visible perspective-[1500px] select-none">
                        <div 
                            className="schedule-mockup-container w-full max-w-sm relative transition-all duration-700 ease-out cursor-pointer active:scale-98 bg-[#131622]/95 border border-white/10 rounded-[32px] p-5 shadow-2xl backdrop-blur-md"
                            style={{
                                transform: 'rotateX(8deg) rotateY(28deg) rotateZ(-4deg)',
                                transformStyle: 'preserve-3d'
                            }}
                        >
                            {/* App top bar */}
                            <div className="flex items-center justify-between mb-4 border-b border-white/5 pb-3">
                                <div className="flex items-center gap-2">
                                    <div className="w-6 h-6 rounded-lg overflow-hidden border border-white/10 flex items-center justify-center bg-black/40">
                                        <img src="./MA_logo.webp" className="w-full h-full object-contain" alt="MA Logo" />
                                    </div>
                                    <span className="text-[10px] font-black text-white">MA</span>
                                </div>
                                <div className="flex-1 max-w-[120px] bg-black/30 border border-white/5 rounded-lg px-2 py-1 text-[8px] text-slate-500 truncate flex items-center gap-1.5 ltr:ml-auto rtl:mr-auto">
                                    <Search className="w-2.5 h-2.5" />
                                    <span>Search anime...</span>
                                </div>
                                <div className="w-5 h-5 rounded-full overflow-hidden bg-rose-600/35 border border-white/10 ltr:ml-2 rtl:mr-2 flex items-center justify-center text-[8px] font-bold text-rose-300">
                                    <span>JD</span>
                                </div>
                            </div>

                            {/* Page header */}
                            <div className="flex items-center justify-between mb-4">
                                <div className="flex items-center gap-1.5">
                                    <div className="w-1 h-4 rounded bg-gradient-to-b from-violet-500 to-rose-500" />
                                    <span className="text-xs font-black text-white uppercase tracking-wider">{language === 'ar' ? 'جدول العرض الأسبوعي' : 'Weekly Schedule'}</span>
                                </div>
                                <button className="flex items-center gap-1 text-[8px] text-violet-400 font-bold hover:text-white transition-colors bg-violet-500/10 px-2 py-0.5 rounded-lg border border-violet-500/20">
                                    <RotateCw className="w-2 h-2" />
                                    <span>{language === 'ar' ? 'تحديث' : 'Refetch'}</span>
                                </button>
                            </div>

                            {/* Airing Next Today Card */}
                            <div className="schedule-mockup-card bg-black/40 border border-white/5 rounded-2xl p-3 mb-4 flex items-center justify-between gap-3 text-left rtl:text-right">
                                <div className="flex items-center gap-3">
                                    <div className="w-11 h-15 rounded-lg overflow-hidden bg-slate-900 border border-white/5 flex-shrink-0">
                                        <img src={reZero.image ? reZero.image.replace('l.webp', '.webp') : ''} alt={reZero.englishTitle} className="w-full h-full object-cover" loading="lazy" />
                                    </div>
                                    <div className="space-y-1">
                                        <div className="flex items-center gap-1 text-[8px] text-violet-400 font-extrabold uppercase tracking-wide">
                                            <Flame className="w-2.5 h-2.5 text-rose-500 fill-rose-500" />
                                            <span>{language === 'ar' ? 'يعرض تالياً اليوم' : 'Airing Next Today'}</span>
                                        </div>
                                        <h4 className="text-[10px] font-black text-white leading-tight max-w-[120px] truncate">{language === 'ar' && reZero.title ? reZero.title : reZero.englishTitle}</h4>
                                        <div className="flex items-center gap-1.5">
                                            <div className="flex items-center gap-1 text-slate-400 text-[8px]">
                                                <Clock className="w-2.5 h-2.5 text-violet-400" />
                                                <span>22:30</span>
                                            </div>
                                            <div className="inline-block bg-violet-500/15 border border-violet-500/20 text-violet-400 text-[7px] font-bold px-1.5 py-0.5 rounded">
                                                4h 15m left
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <div className="w-7 h-7 rounded-full bg-white/5 flex items-center justify-center border border-white/10 hover:bg-violet-500/15 cursor-pointer transition-colors text-slate-400 hover:text-white">
                                    <Bell className="w-3.5 h-3.5 text-violet-400 fill-violet-400/20" />
                                </div>
                            </div>

                            {/* Today - Tuesday Section */}
                            <div className="schedule-mockup-card space-y-2">
                                <div className="flex items-center gap-1.5">
                                    <div className="w-0.5 h-3 rounded bg-violet-400" />
                                    <span className="text-[9px] font-bold text-slate-400 uppercase tracking-wider">{language === 'ar' ? 'اليوم - الثلاثاء' : 'Today - Tuesday'}</span>
                                </div>
                                
                                <div className="flex gap-3 overflow-x-auto no-scrollbar pb-1">
                                    {/* Card 1 */}
                                    <div className="w-[100px] flex-shrink-0 text-left rtl:text-right">
                                        <div className="relative aspect-[2/3] rounded-xl overflow-hidden bg-slate-900 border border-white/5 mb-1.5">
                                            <img src={frierenS2.image ? frierenS2.image.replace('l.webp', '.webp') : ''} alt={frierenS2.englishTitle} className="w-full h-full object-cover" loading="lazy" />
                                            <div className="absolute top-1.5 right-1.5 bg-black/60 backdrop-blur-md px-1.5 py-0.5 rounded-lg flex items-center gap-0.5 border border-white/5">
                                                <Star className="w-2.5 h-2.5 text-amber-500 fill-amber-500" />
                                                <span className="text-[7px] font-black text-white">{frierenS2.score}</span>
                                            </div>
                                            <div className="absolute top-1.5 left-1.5 flex flex-col gap-1">
                                                <div className="w-5 h-5 rounded-full bg-black/60 backdrop-blur-md flex items-center justify-center border border-white/10 hover:bg-violet-500 text-white cursor-pointer transition-colors">
                                                    <Plus className="w-3 h-3" />
                                                </div>
                                                <div className="w-5 h-5 rounded-full bg-black/60 backdrop-blur-md flex items-center justify-center border border-white/10 hover:bg-violet-500 text-white cursor-pointer transition-colors">
                                                    <Bell className="w-2.5 h-2.5" />
                                                </div>
                                            </div>
                                        </div>
                                        <h5 className="text-[9px] font-black text-white leading-tight truncate">{language === 'ar' && frierenS2.title ? frierenS2.title : frierenS2.englishTitle}</h5>
                                        <span className="text-[7px] text-slate-500">{frierenS2.genres.slice(0, 2).join(', ')}</span>
                                    </div>
                                    
                                    {/* Card 2 */}
                                    <div className="w-[100px] flex-shrink-0 text-left rtl:text-right">
                                        <div className="relative aspect-[2/3] rounded-xl overflow-hidden bg-slate-900 border border-white/5 mb-1.5">
                                            <img src={jojoSbr.image ? jojoSbr.image.replace('l.webp', '.webp') : ''} alt={jojoSbr.englishTitle} className="w-full h-full object-cover" loading="lazy" />
                                            <div className="absolute top-1.5 right-1.5 bg-black/60 backdrop-blur-md px-1.5 py-0.5 rounded-lg flex items-center gap-0.5 border border-white/5">
                                                <Star className="w-2.5 h-2.5 text-amber-500 fill-amber-500" />
                                                <span className="text-[7px] font-black text-white">{jojoSbr.score}</span>
                                            </div>
                                            <div className="absolute top-1.5 left-1.5 flex flex-col gap-1">
                                                <div className="w-5 h-5 rounded-full bg-black/60 backdrop-blur-md flex items-center justify-center border border-white/10 hover:bg-violet-500 text-white cursor-pointer transition-colors">
                                                    <Plus className="w-3 h-3" />
                                                </div>
                                                <div className="w-5 h-5 rounded-full bg-black/60 backdrop-blur-md flex items-center justify-center border border-white/10 hover:bg-violet-500 text-white cursor-pointer transition-colors">
                                                    <Bell className="w-2.5 h-2.5" />
                                                </div>
                                            </div>
                                        </div>
                                        <h5 className="text-[9px] font-black text-white leading-tight truncate">{language === 'ar' && jojoSbr.title ? jojoSbr.title : jojoSbr.englishTitle}</h5>
                                        <span className="text-[7px] text-slate-500">{jojoSbr.genres.slice(0, 2).join(', ')}</span>
                                    </div>
                                    
                                    {/* Card 3 */}
                                    <div className="w-[100px] flex-shrink-0 text-left rtl:text-right">
                                        <div className="relative aspect-[2/3] rounded-xl overflow-hidden bg-slate-900 border border-white/5 mb-1.5">
                                            <img src={mushokuS3.image ? mushokuS3.image.replace('l.webp', '.webp') : ''} alt={mushokuS3.englishTitle} className="w-full h-full object-cover" loading="lazy" />
                                            <div className="absolute top-1.5 right-1.5 bg-black/60 backdrop-blur-md px-1.5 py-0.5 rounded-lg flex items-center gap-0.5 border border-white/5">
                                                <Star className="w-2.5 h-2.5 text-amber-500 fill-amber-500" />
                                                <span className="text-[7px] font-black text-white">{mushokuS3.score}</span>
                                            </div>
                                            <div className="absolute top-1.5 left-1.5 flex flex-col gap-1">
                                                <div className="w-5 h-5 rounded-full bg-black/60 backdrop-blur-md flex items-center justify-center border border-white/10 hover:bg-violet-500 text-white cursor-pointer transition-colors">
                                                    <Plus className="w-3 h-3" />
                                                </div>
                                                <div className="w-5 h-5 rounded-full bg-black/60 backdrop-blur-md flex items-center justify-center border border-white/10 hover:bg-violet-500 text-white cursor-pointer transition-colors">
                                                    <Bell className="w-2.5 h-2.5" />
                                                </div>
                                            </div>
                                        </div>
                                        <h5 className="text-[9px] font-black text-white leading-tight truncate">{language === 'ar' && mushokuS3.title ? mushokuS3.title : mushokuS3.englishTitle}</h5>
                                        <span className="text-[7px] text-slate-500">{mushokuS3.genres.slice(0, 2).join(', ')}</span>
                                    </div>
                                </div>
                            </div>

                            {/* Wednesday Section */}
                            <div className="schedule-mockup-card space-y-2 mt-3">
                                <div className="flex items-center gap-1.5">
                                    <div className="w-0.5 h-3 rounded bg-violet-400" />
                                    <span className="text-[9px] font-bold text-slate-400 uppercase tracking-wider">{language === 'ar' ? 'الأربعاء' : 'Wednesday'}</span>
                                </div>
                                
                                <div className="flex gap-3 overflow-x-auto no-scrollbar pb-1">
                                    {/* Card 1 */}
                                    <div className="w-[100px] flex-shrink-0 text-left rtl:text-right">
                                        <div className="relative aspect-[2/3] rounded-xl overflow-hidden bg-slate-900 border border-white/5 mb-1.5">
                                            <img src={apothecaryS2.image ? apothecaryS2.image.replace('l.webp', '.webp') : ''} alt={apothecaryS2.englishTitle} className="w-full h-full object-cover" loading="lazy" />
                                            <div className="absolute top-1.5 right-1.5 bg-black/60 backdrop-blur-md px-1.5 py-0.5 rounded-lg flex items-center gap-0.5 border border-white/5">
                                                <Star className="w-2.5 h-2.5 text-amber-500 fill-amber-500" />
                                                <span className="text-[7px] font-black text-white">{apothecaryS2.score}</span>
                                            </div>
                                            <div className="absolute top-1.5 left-1.5">
                                                <div className="w-5 h-5 rounded-full bg-emerald-500 flex items-center justify-center border border-white/10 text-white shadow-lg">
                                                    <Check className="w-3 h-3 font-bold" />
                                                </div>
                                            </div>
                                        </div>
                                        <h5 className="text-[9px] font-black text-white leading-tight truncate">{language === 'ar' && apothecaryS2.title ? apothecaryS2.title : apothecaryS2.englishTitle}</h5>
                                        <span className="text-[7px] text-slate-500">{apothecaryS2.genres.slice(0, 2).join(', ')}</span>
                                    </div>
                                    
                                    {/* Card 2 */}
                                    <div className="w-[100px] flex-shrink-0 text-left rtl:text-right">
                                        <div className="relative aspect-[2/3] rounded-xl overflow-hidden bg-slate-900 border border-white/5 mb-1.5">
                                            <img src={chainsawReze.image ? chainsawReze.image.replace('l.webp', '.webp') : ''} alt={chainsawReze.englishTitle} className="w-full h-full object-cover" loading="lazy" />
                                            <div className="absolute top-1.5 right-1.5 bg-black/60 backdrop-blur-md px-1.5 py-0.5 rounded-lg flex items-center gap-0.5 border border-white/5">
                                                <Star className="w-2.5 h-2.5 text-amber-500 fill-amber-500" />
                                                <span className="text-[7px] font-black text-white">{chainsawReze.score}</span>
                                            </div>
                                            <div className="absolute top-1.5 left-1.5">
                                                <div className="w-5 h-5 rounded-full bg-emerald-500 flex items-center justify-center border border-white/10 text-white shadow-lg">
                                                    <Check className="w-3 h-3 font-bold" />
                                                </div>
                                            </div>
                                        </div>
                                        <h5 className="text-[9px] font-black text-white leading-tight truncate">{language === 'ar' && chainsawReze.title ? chainsawReze.title : chainsawReze.englishTitle}</h5>
                                        <span className="text-[7px] text-slate-500">{chainsawReze.genres.slice(0, 2).join(', ')}</span>
                                    </div>
                                </div>
                            </div>

                            {/* App bottom navigation bar */}
                            <div className="border-t border-white/5 pt-3 mt-4 flex items-center justify-between text-slate-500">
                                <div className="flex flex-col items-center gap-1 flex-1">
                                    <Home className="w-4 h-4" />
                                    <span className="text-[7px] font-extrabold">Home</span>
                                </div>
                                <div className="flex flex-col items-center gap-1 flex-1 text-violet-400">
                                    <Calendar className="w-4 h-4" />
                                    <span className="text-[7px] font-extrabold">Schedule</span>
                                </div>
                                <div className="flex flex-col items-center gap-1 flex-1 relative">
                                    <div className="absolute -top-1.5 right-4 bg-rose-500 text-white text-[7px] font-black w-3.5 h-3.5 rounded-full flex items-center justify-center border border-[#131622] scale-90">158</div>
                                    <List className="w-4 h-4" />
                                    <span className="text-[7px] font-extrabold">My List</span>
                                </div>
                                <div className="flex flex-col items-center gap-1 flex-1">
                                    <FolderHeart className="w-4 h-4" />
                                    <span className="text-[7px] font-extrabold">Library</span>
                                </div>
                                <div className="flex flex-col items-center gap-1 flex-1">
                                    <Sliders className="w-4 h-4" />
                                    <span className="text-[7px] font-extrabold">Settings</span>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Right: Description Column */}
                    <div className="schedule-desc-text-right lg:col-span-6 space-y-6 text-left rtl:text-right opacity-0 transform">
                        <div className="space-y-3">
                            <span className="text-xs uppercase tracking-widest text-violet-400 font-extrabold block">{t('scheduleShowcaseSubtitle')}</span>
                            <h2 style={{ color: currentColors.text }} className="text-3xl sm:text-4xl font-extrabold leading-tight">
                                {t('scheduleShowcaseTitle')}
                            </h2>
                            <p className="text-slate-400 text-sm leading-relaxed">
                                {t('scheduleShowcaseDesc')}
                            </p>
                        </div>

                        {/* Feature points */}
                        <div className="space-y-5">
                            <div className="flex gap-4 items-start">
                                <div className="w-10 h-10 rounded-xl bg-violet-600/10 border border-violet-500/20 flex items-center justify-center text-violet-400 flex-shrink-0">
                                    <Clock className="w-5 h-5" />
                                </div>
                                <div className="space-y-1">
                                    <h4 style={{ color: currentColors.text }} className="text-sm font-bold">{t('schedulePoint1Title')}</h4>
                                    <p className="text-xs text-slate-455 leading-relaxed">{t('schedulePoint1Desc')}</p>
                                </div>
                            </div>

                            <div className="flex gap-4 items-start">
                                <div className="w-10 h-10 rounded-xl bg-rose-600/10 border border-rose-500/20 flex items-center justify-center text-rose-455 flex-shrink-0">
                                    <Calendar className="w-5 h-5" />
                                </div>
                                <div className="space-y-1">
                                    <h4 style={{ color: currentColors.text }} className="text-sm font-bold">{t('schedulePoint2Title')}</h4>
                                    <p className="text-xs text-slate-455 leading-relaxed">{t('schedulePoint2Desc')}</p>
                                </div>
                            </div>

                            <div className="flex gap-4 items-start">
                                <div className="w-10 h-10 rounded-xl bg-amber-600/10 border border-amber-500/20 flex items-center justify-center text-amber-550 flex-shrink-0">
                                    <Bell className="w-5 h-5" />
                                </div>
                                <div className="space-y-1">
                                    <h4 style={{ color: currentColors.text }} className="text-sm font-bold">{t('schedulePoint3Title')}</h4>
                                    <p className="text-xs text-slate-455 leading-relaxed">{t('schedulePoint3Desc')}</p>
                                </div>
                            </div>
                        </div>
                    </div>

                </section>

                {/* FAQ SECTION */}
                <section id="faq" className="max-w-4xl mx-auto py-12">
                    <div className="text-center space-y-4 mb-16">
                        <h2 style={{ color: currentColors.text }} className="text-3xl font-extrabold flex items-center justify-center gap-2">
                            <HelpCircle className="w-8 h-8 text-violet-400" /> {t('faqTitle')}
                        </h2>
                        <p className="text-slate-400 text-sm">{t('faqDesc')}</p>
                    </div>

                    <div className="space-y-4 text-left">
                        {[
                            {
                                q: t('faq1Q'),
                                a: t('faq1A')
                            },
                            {
                                q: t('faq2Q'),
                                a: t('faq2A')
                            },
                            {
                                q: t('faq3Q'),
                                a: t('faq3A')
                            }
                        ].map((faq, idx) => (
                            <div 
                                key={idx} 
                                style={{ backgroundColor: currentColors.surface, borderColor: currentColors.border }}
                                className="rounded-2xl border overflow-hidden"
                            >
                                <div 
                                    style={{ color: currentColors.text }}
                                    className="px-6 py-5 flex items-center justify-between font-bold font-semibold"
                                >
                                    <span>{faq.q}</span>
                                    <HelpCircle className="w-4 h-4 text-violet-400" />
                                </div>
                                <div style={{ borderColor: currentColors.border }} className="border-t p-6 bg-black/10">
                                    <p className="text-slate-400 text-sm leading-relaxed">{faq.a}</p>
                                </div>
                            </div>
                        ))}
                    </div>
                </section>

                {/* CONTACTS SECTION */}
                <section id="contacts" className="max-w-6xl mx-auto py-16 border-t border-white/5 mt-16 scroll-mt-24">
                    <div className="text-center space-y-4 mb-16">
                        <span className="text-xs uppercase tracking-widest text-violet-400 font-extrabold block">
                            {language === 'ar' ? 'اتصل بنا' : 'CONTACT US'}
                        </span>
                        <h2 style={{ color: currentColors.text }} className="text-3xl font-extrabold font-display">
                            {language === 'ar' ? 'ابقَ على تواصل' : 'Get in Touch'}
                        </h2>
                        <p className="text-slate-450 text-sm max-w-xl mx-auto">
                            {language === 'ar' 
                                ? 'هل لديك أي أسئلة أو تود تقديم اقتراحات؟ لا تتردد في الاتصال بنا عبر البريد الإلكتروني أو من خلال قنواتنا الرسمية.'
                                : 'Have questions, ideas, or feedback? Feel free to reach out to us directly or drop us a message below.'}
                        </p>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-8 items-start">
                        {/* Left Side: Contact Information Cards */}
                        <div className="space-y-4 text-left rtl:text-right">
                            <div 
                                style={{ backgroundColor: currentColors.surface, borderColor: currentColors.border }}
                                className="p-6 rounded-3xl border flex gap-4 items-start shadow-lg hover:shadow-xl transition-all"
                            >
                                <div className="w-12 h-12 rounded-2xl bg-violet-600/10 border border-violet-500/20 flex items-center justify-center text-violet-400 flex-shrink-0">
                                    <MessageSquare className="w-6 h-6" />
                                </div>
                                <div className="space-y-1">
                                    <h4 style={{ color: currentColors.text }} className="font-bold text-base">
                                        {language === 'ar' ? 'البريد الإلكتروني' : 'Email Address'}
                                    </h4>
                                    <p className="text-slate-400 text-xs leading-relaxed">
                                        {language === 'ar' ? 'أرسل لنا استفسارك في أي وقت:' : 'Send us your questions at any time:'}
                                    </p>
                                    <a 
                                        href="mailto:support@myanimes.app" 
                                        className="text-violet-400 font-black text-sm hover:underline block pt-1"
                                    >
                                        support@myanimes.app
                                    </a>
                                </div>
                            </div>

                            <div 
                                style={{ backgroundColor: currentColors.surface, borderColor: currentColors.border }}
                                className="p-6 rounded-3xl border flex gap-4 items-start shadow-lg hover:shadow-xl transition-all"
                            >
                                <div className="w-12 h-12 rounded-2xl bg-rose-600/10 border border-rose-500/20 flex items-center justify-center text-rose-455 flex-shrink-0">
                                    <Github className="w-6 h-6" />
                                </div>
                                <div className="space-y-1">
                                    <h4 style={{ color: currentColors.text }} className="font-bold text-base">
                                        {language === 'ar' ? 'مستودع المشروع' : 'Project Repository'}
                                    </h4>
                                    <p className="text-slate-400 text-xs leading-relaxed">
                                        {language === 'ar' ? 'ساهم أو تصفح الأكواد والتعليمات البرمجية:' : 'Contribute, browse issues, or read documentation:'}
                                    </p>
                                    <a 
                                        href="https://github.com/LOMoriartyVE/myanimes-privacy" 
                                        target="_blank" 
                                        rel="noopener noreferrer" 
                                        className="text-rose-400 font-black text-sm hover:underline block pt-1"
                                    >
                                        github.com/LOMoriartyVE/myanimes-privacy
                                    </a>
                                </div>
                            </div>

                            <div 
                                style={{ backgroundColor: currentColors.surface, borderColor: currentColors.border }}
                                className="p-6 rounded-3xl border flex gap-4 items-start shadow-lg hover:shadow-xl transition-all"
                            >
                                <div className="w-12 h-12 rounded-2xl bg-amber-600/10 border border-amber-500/20 flex items-center justify-center text-amber-500 flex-shrink-0">
                                    <Clock className="w-6 h-6" />
                                </div>
                                <div className="space-y-1">
                                    <h4 style={{ color: currentColors.text }} className="font-bold text-base">
                                        {language === 'ar' ? 'وقت الاستجابة' : 'Response Timeline'}
                                    </h4>
                                    <p className="text-slate-400 text-xs leading-relaxed">
                                        {language === 'ar' ? 'فريق الدعم لدينا يبذل قصارى جهده للرد في غضون 24 ساعة.' : 'Our team strives to address all inquiries within 24 hours.'}
                                    </p>
                                </div>
                            </div>
                        </div>

                        {/* Right Side: Simple Interactive Contact Form */}
                        <form 
                            onSubmit={(e) => {
                                e.preventDefault();
                                showToast(language === 'ar' ? 'تم إرسال رسالتك بنجاح! شكرًا لك.' : 'Your message has been sent successfully! Thank you.');
                                e.target.reset();
                            }}
                            style={{ backgroundColor: currentColors.surface, borderColor: currentColors.border }}
                            className="p-8 rounded-3xl border text-left rtl:text-right space-y-4 shadow-xl"
                        >
                            <div>
                                <label className="block text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
                                    {language === 'ar' ? 'الاسم الكامل' : 'Full Name'}
                                </label>
                                <input 
                                    type="text" 
                                    required 
                                    placeholder={language === 'ar' ? 'أدخل اسمك الكريم' : 'Enter your name'}
                                    style={{ backgroundColor: currentColors.bg, borderColor: currentColors.border, color: currentColors.text }}
                                    className="w-full rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 border transition-all"
                                />
                            </div>

                            <div>
                                <label className="block text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
                                    {language === 'ar' ? 'البريد الإلكتروني' : 'Email Address'}
                                </label>
                                <input 
                                    type="email" 
                                    required 
                                    placeholder={language === 'ar' ? 'name@example.com' : 'name@example.com'}
                                    style={{ backgroundColor: currentColors.bg, borderColor: currentColors.border, color: currentColors.text }}
                                    className="w-full rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 border transition-all"
                                />
                            </div>

                            <div>
                                <label className="block text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
                                    {language === 'ar' ? 'الرسالة' : 'Message'}
                                </label>
                                <textarea 
                                    required 
                                    rows="4" 
                                    placeholder={language === 'ar' ? 'كيف يمكننا مساعدتك اليوم؟' : 'How can we help you today?'}
                                    style={{ backgroundColor: currentColors.bg, borderColor: currentColors.border, color: currentColors.text }}
                                    className="w-full rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 border transition-all resize-none"
                                />
                            </div>

                            <button 
                                type="submit" 
                                className="w-full bg-gradient-to-r from-violet-600 to-rose-600 hover:opacity-95 text-white font-bold py-3 px-6 rounded-xl text-sm transition-all shadow-lg active:scale-98"
                            >
                                {language === 'ar' ? 'إرسال الرسالة' : 'Send Message'}
                            </button>
                        </form>
                    </div>
                </section>
            </main>

            {/* ANIME DETAILS MODAL */}
            {selectedAnime && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/85 backdrop-blur-sm animate-fade-in">
                    <div style={{ backgroundColor: currentColors.surface, borderColor: currentColors.border }} className="relative w-full max-w-2xl max-h-[90vh] md:max-h-none overflow-y-auto md:overflow-visible rounded-3xl border shadow-2xl flex flex-col md:flex-row">
                        
                        {/* Floating Close Button */}
                        <button 
                            onClick={() => setSelectedAnime(null)}
                            className="absolute top-3 right-3 z-50 w-8 h-8 rounded-full bg-black/60 hover:bg-black/80 text-white flex items-center justify-center border border-white/10 shadow-lg transition-all active:scale-95"
                            aria-label="Close modal"
                        >
                            <X className="w-4.5 h-4.5" />
                        </button>

                        {/* Left image block */}
                        <div className="w-full md:w-2/5 h-48 md:h-auto relative bg-slate-900 flex-shrink-0">
                            <img 
                                src={selectedAnime.image} 
                                alt={selectedAnime.title} 
                                className="w-full h-full object-cover" 
                                loading="lazy" 
                                onError={(e) => {
                                    e.target.onerror = null;
                                    e.target.src = "./MA_logo.webp";
                                }}
                            />
                            <span className="absolute top-4 left-4 bg-black/60 text-amber-400 font-bold px-2 py-1 rounded text-xs flex items-center gap-1">
                                ★ {selectedAnime.score}
                            </span>
                        </div>

                        {/* Right details content */}
                        <div className="w-full md:w-3/5 p-6 flex flex-col justify-between space-y-4 text-left">
                            <div className="space-y-2">
                                <div className="flex justify-between items-start gap-4">
                                    <h3 style={{ color: currentColors.text }} className="text-xl font-bold leading-tight">{selectedAnime.title}</h3>
                                    <button 
                                        onClick={() => setSelectedAnime(null)}
                                        style={{ color: currentColors.textSecondary, borderColor: currentColors.border }} className="hidden md:block text-xs font-semibold uppercase tracking-widest border px-2.5 py-1 rounded-lg hover:opacity-85"
                                    >
                                        {t('close')}
                                    </button>
                                </div>
                                <p className="text-[10px] text-slate-500 uppercase tracking-wider font-extrabold">{selectedAnime.studios.join(', ')}</p>
                                
                                <div className="flex flex-wrap gap-1.5 pt-1.5">
                                    {selectedAnime.genres.map(g => (
                                        <span key={g} className="bg-violet-950/45 text-violet-400 border border-violet-900/40 text-[9px] font-bold px-2.5 py-0.5 rounded-full capitalize">
                                            {g}
                                        </span>
                                    ))}
                                </div>
                            </div>

                            <div className="space-y-1.5">
                                <h5 className="text-[10px] uppercase tracking-widest font-extrabold text-slate-450 border-b border-white/5 pb-1">{t('synopsisLabel')}</h5>
                                <p className="text-xs text-slate-350 leading-relaxed max-h-36 overflow-y-auto pr-1">
                                    {selectedAnime.synopsis}
                                </p>
                            </div>

                            {/* Telemetry info */}
                            <div style={{ borderColor: currentColors.border }} className="grid grid-cols-2 gap-3 text-[10px] bg-black/30 p-3 rounded-xl border">
                                <div><span className="text-slate-500 font-bold">{t('episodesLabel2')}</span> <span style={{ color: currentColors.text }} className="font-semibold">{selectedAnime.episodes}</span></div>
                                <div><span className="text-slate-500 font-bold">{t('typeLabel')}</span> <span className="text-violet-400 font-extrabold uppercase">{selectedAnime.type}</span></div>
                                <div><span className="text-slate-500 font-bold">{t('airedLabel')}</span> <span style={{ color: currentColors.text }} className="font-semibold truncate block max-w-full">{selectedAnime.aired}</span></div>
                                <div><span className="text-slate-500 font-bold">{t('statusLabel')}</span> <span style={{ color: currentColors.text }} className="font-semibold">{selectedAnime.status}</span></div>
                            </div>

                            {/* Watch Action Buttons */}
                            <div className="flex gap-2 pt-2">
                                <button
                                    onClick={() => {
                                        handleAddToWatchlist(selectedAnime, 'watching');
                                        setSelectedAnime(null);
                                    }}
                                    className="flex-1 bg-violet-600 hover:bg-violet-550 text-white font-bold py-2.5 px-4 rounded-xl text-xs flex items-center justify-center gap-1.5 active:scale-98 transition-all"
                                >
                                    <Play className="w-3.5 h-3.5 fill-current" /> {t('startWatching')}
                                </button>
                                <button
                                    onClick={() => {
                                        handleAddToWatchlist(selectedAnime, 'planned');
                                        setSelectedAnime(null);
                                    }}
                                    style={{ backgroundColor: currentColors.isDark ? '#1c1e2b' : '#f1f5f9', color: currentColors.textSecondary, borderColor: currentColors.border }} className="flex-1 hover:opacity-85 font-bold py-2.5 px-4 rounded-xl text-xs flex items-center justify-center gap-1.5 border active:scale-98 transition-all"
                                >
                                    <Clock className="w-3.5 h-3.5" /> {t('planToWatch')}
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* FEEDBACK MODAL */}
            {showFeedbackModal && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/85 backdrop-blur-sm animate-fade-in">
                    <div 
                        style={{ backgroundColor: currentColors.surface, borderColor: currentColors.border }} 
                        className="relative w-full max-w-md rounded-3xl border p-6 shadow-2xl space-y-4 text-left rtl:text-right"
                    >
                        <div className="flex justify-between items-center pb-2 border-b border-white/5">
                            <h3 style={{ color: currentColors.text }} className="text-lg font-black font-display">
                                {language === 'ar' ? 'تقديم الملاحظات' : 'Submit Feedback'}
                            </h3>
                            <button 
                                onClick={() => setShowFeedbackModal(false)}
                                style={{ color: currentColors.textSecondary, borderColor: currentColors.border }} 
                                className="text-xs font-semibold uppercase tracking-widest border px-2.5 py-1 rounded-lg hover:opacity-85"
                            >
                                {t('close')}
                            </button>
                        </div>

                        <form 
                            onSubmit={(e) => {
                                e.preventDefault();
                                showToast(language === 'ar' ? 'شكراً لملاحظاتك القيمة! تم استلامها.' : 'Thank you for your valuable feedback! It has been received.');
                                setShowFeedbackModal(false);
                            }}
                            className="space-y-4"
                        >
                            <div>
                                <label className="block text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1.5">
                                    {language === 'ar' ? 'نوع الملاحظة' : 'Feedback Type'}
                                </label>
                                <select 
                                    style={{ backgroundColor: currentColors.bg, borderColor: currentColors.border, color: currentColors.text }}
                                    className="w-full rounded-xl px-4 py-2.5 text-xs focus:outline-none border transition-all"
                                >
                                    <option value="bug">{language === 'ar' ? 'تقرير عن مشكلة (Bug)' : 'Bug Report'}</option>
                                    <option value="suggestion">{language === 'ar' ? 'اقتراح تحسين' : 'Suggestion'}</option>
                                    <option value="feature">{language === 'ar' ? 'طلب ميزة جديدة' : 'Feature Request'}</option>
                                    <option value="other">{language === 'ar' ? 'آخر' : 'Other'}</option>
                                </select>
                            </div>

                            <div>
                                <label className="block text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1.5">
                                    {language === 'ar' ? 'الاسم' : 'Name'}
                                </label>
                                <input 
                                    type="text" 
                                    required 
                                    placeholder={language === 'ar' ? 'أدخل اسمك' : 'Enter your name'}
                                    style={{ backgroundColor: currentColors.bg, borderColor: currentColors.border, color: currentColors.text }}
                                    className="w-full rounded-xl px-4 py-2.5 text-xs focus:outline-none border transition-all"
                                />
                            </div>

                            <div>
                                <label className="block text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1.5">
                                    {language === 'ar' ? 'الرسالة التفصيلية' : 'Detailed message'}
                                </label>
                                <textarea 
                                    required 
                                    rows="4" 
                                    placeholder={language === 'ar' ? 'اكتب ملاحظاتك هنا بالتفصيل...' : 'Write your feedback details here...'}
                                    style={{ backgroundColor: currentColors.bg, borderColor: currentColors.border, color: currentColors.text }}
                                    className="w-full rounded-xl px-4 py-2.5 text-xs focus:outline-none border transition-all resize-none"
                                />
                            </div>

                            <button 
                                type="submit" 
                                className="w-full bg-gradient-to-r from-violet-600 to-rose-600 hover:opacity-95 text-white font-bold py-2.5 rounded-xl text-xs transition-all shadow-lg active:scale-98"
                            >
                                {language === 'ar' ? 'إرسال التقييم' : 'Submit Feedback'}
                            </button>
                        </form>
                    </div>
                </div>
            )}

            {/* FOOTER */}
            <footer className="border-t border-white/5 py-12 bg-black/35 relative z-10 px-6 mt-20">
                <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-6">
                    <div className="flex items-center gap-2.5">
                        <img src="./MA_logo.webp" width="28" height="28" className="w-7 h-7 rounded-lg shadow-md border border-white/10 object-contain" alt="MA Logo" />
                        <div className="flex flex-col text-left">
                            <span className="font-extrabold text-sm tracking-wider leading-none">{t('title')}</span>
                        </div>
                    </div>

                    <div className="text-xs text-slate-550 text-center md:text-left">
                        {t('footerText')}
                    </div>

                    <div className="flex items-center gap-4">
                        <div className="flex items-center gap-3 text-xs text-slate-500 mr-2">
                            <a href="https://lomoriartyve.github.io/myanimes-privacy/privacy.html" target="_blank" rel="noopener noreferrer" className="hover:text-violet-400 transition-colors">
                                {language === 'ar' ? 'سياسة الخصوصية' : 'Privacy Policy'}
                            </a>
                            <span>•</span>
                            <a href="https://lomoriartyve.github.io/myanimes-privacy/terms.html" target="_blank" rel="noopener noreferrer" className="hover:text-violet-400 transition-colors">
                                {language === 'ar' ? 'الشروط' : 'Terms'}
                            </a>
                        </div>
                        <button 
                            onClick={() => setShowFeedbackModal(true)} 
                            className="w-8 h-8 rounded-full bg-[#131622] border border-white/5 flex items-center justify-center text-slate-400 hover:text-white transition-colors hover:bg-violet-600/20 hover:border-violet-500/30"
                            title="Provide Feedback"
                        >
                            <MessageSquare className="w-4 h-4" />
                        </button>
                        <a 
                            href="https://github.com/LOMoriartyVE/myanimes-privacy" 
                            target="_blank" 
                            rel="noopener noreferrer" 
                            className="w-8 h-8 rounded-full bg-[#131622] border border-white/5 flex items-center justify-center text-slate-400 hover:text-white transition-colors"
                        >
                            <Github className="w-4 h-4" />
                        </a>
                    </div>
                </div>
            </footer>
        </div>
    );
}