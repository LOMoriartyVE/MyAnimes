import React, { useState, useEffect, useRef } from 'react';
import {
    Bell,
    BellOff,
    Share2,
    ArrowLeft,
    ExternalLink,
    Copy,
    FileText,
    Activity,
    User,
    Calendar,
    MapPin,
    Star,
    Sparkles,
    AlertTriangle,
    CheckCircle,
    Tv,
    BookOpen,
    ChevronDown,
    ChevronUp,
    Download,
    Eye,
    Heart,
    ListPlus,
    Flame,
    RotateCcw,
    Sliders,
    X
} from 'lucide-react';

// Highly detailed local database fallback representing MuhammadGoi
const curatedMockProfile = {
    "username": "MuhammadGoi",
    "url": "https://myanimelist.net/profile/MuhammadGoi",
    "images": {
        "jpg": { "image_url": "https://images.unsplash.com/photo-1578632767115-351597cf2477?q=80&w=300" }
    },
    "last_online": "Online Now",
    "gender": "Male",
    "birthday": "May 14",
    "location": "Global Anime Community",
    "joined": "2024-02-11T00:00:00+00:00",
    "about": "Anime collector, manga researcher, and visual novels enthusiast. Special interest in dark psychological thrillers, cyberpunk aesthetics, and futuristic sci-fi series. Ready to connect, exchange detailed reviews, and configure dynamic recommendation lists!",
    "statistics": {
        "anime": {
            "days_watched": 45.8,
            "mean_score": 8.14,
            "watching": 12,
            "completed": 165,
            "on_hold": 4,
            "dropped": 3,
            "plan_to_watch": 88,
            "total_entries": 272,
            "episodes_watched": 2710
        },
        "manga": {
            "days_read": 18.2,
            "mean_score": 7.9,
            "reading": 9,
            "completed": 54,
            "on_hold": 2,
            "dropped": 1,
            "plan_to_read": 35,
            "total_entries": 101,
            "chapters_read": 1240,
            "volumes_read": 140
        }
    },
    "favorites": {
        "anime": [
            { "title": "Frieren: Beyond Journey's End", "images": { "jpg": { "image_url": "https://cdn.myanimelist.net/images/anime/1015/138075.jpg" } }, "type": "TV", "score": "10.0" },
            { "title": "Steins;Gate", "images": { "jpg": { "image_url": "https://cdn.myanimelist.net/images/anime/1935/127974.jpg" } }, "type": "TV", "score": "9.8" },
            { "title": "Hunter x Hunter (2011)", "images": { "jpg": { "image_url": "https://cdn.myanimelist.net/images/anime/1337/99013.jpg" } }, "type": "TV", "score": "9.5" },
            { "title": "Monster", "images": { "jpg": { "image_url": "https://cdn.myanimelist.net/images/anime/10/18793.jpg" } }, "type": "TV", "score": "9.4" }
        ],
        "characters": [
            { "name": "Lelouch Lamperouge", "images": { "jpg": { "image_url": "https://cdn.myanimelist.net/images/characters/8/406163.jpg" } }, "role": "Main" },
            { "name": "Rintarou Okabe", "images": { "jpg": { "image_url": "https://cdn.myanimelist.net/images/characters/6/122645.jpg" } }, "role": "Main" },
            { "name": "Killua Zoldyck", "images": { "jpg": { "image_url": "https://cdn.myanimelist.net/images/characters/2/208321.jpg" } }, "role": "Main" },
            { "name": "Frieren", "images": { "jpg": { "image_url": "https://cdn.myanimelist.net/images/characters/16/483669.jpg" } }, "role": "Main" }
        ]
    },
    "updates": [
        { "item": "Frieren: Beyond Journey's End", "type": "Anime", "status": "Completed", "score": 10, "progress": "28/28", "date": "10 hours ago" },
        { "item": "Steins;Gate", "type": "Anime", "status": "Watching", "score": null, "progress": "12/24", "date": "2 days ago" },
        { "item": "Monster", "type": "Anime", "status": "Watching", "score": null, "progress": "44/74", "date": "1 week ago" },
        { "item": "Chainsaw Man", "type": "Manga", "status": "Reading", "score": 8, "progress": "Chapter 120", "date": "3 weeks ago" }
    ]
};

export default function App() {
    const [searchInput, setSearchInput] = useState("MuhammadGoi");
    const [profileData, setProfileData] = useState(curatedMockProfile);
    const [isLoading, setIsLoading] = useState(false);
    const [isDemoMode, setIsDemoMode] = useState(true);
    const [activeTab, setActiveTab] = useState("overview");
    const [synopsisExpanded, setSynopsisExpanded] = useState(false);
    const [isAlertsEnabled, setIsAlertsEnabled] = useState(false);
    const [showShareModal, setShowShareModal] = useState(false);

    // Flutter-style local ratings sheet configuration
    const [dnaRatings, setDnaRatings] = useState({
        overall: 8.8,
        completeness: 8.5,
        variety: 8.0,
        activity: 9.2,
        uniqueness: 7.5,
        engagement: 9.4
    });
    const [isEditingDNA, setIsEditingDNA] = useState(false);

    // Custom visual toast system
    const [toast, setToast] = useState({ show: false, message: "", icon: "info" });
    const toastTimeoutRef = useRef(null);

    const showToast = (message, icon = "info") => {
        if (toastTimeoutRef.current) {
            clearTimeout(toastTimeoutRef.current);
        }
        setToast({ show: true, message, icon });
        toastTimeoutRef.current = setTimeout(() => {
            setToast(prev => ({ ...prev, show: false }));
        }, 4000);
    };

    const fetchProfileData = async (targetUser = searchInput) => {
        const formattedUser = targetUser.trim();
        if (!formattedUser) return;

        setIsLoading(true);
        showToast(`Syncing ${formattedUser}'s live data via Jikan...`, "spinner");

        try {
            const response = await fetch(`https://api.jikan.moe/v4/users/${formattedUser}/full`);
            if (!response.ok) {
                throw new Error(`Profile not found or API rate limited (Status: ${response.status})`);
            }
            const result = await response.json();
            if (!result.data) {
                throw new Error("No usable data in response.");
            }

            setProfileData(result.data);
            setIsDemoMode(false);
            calculateDnaRatings(result.data);
            showToast("Profile parsed & synchronized successfully!", "success");
        } catch (error) {
            console.warn("API limit/private profile fallback activated:", error.message);

            // Fallback custom mock dynamic sync
            const mockCopy = JSON.parse(JSON.stringify(curatedMockProfile));
            mockCopy.username = formattedUser;
            mockCopy.url = `https://myanimelist.net/profile/${formattedUser}`;
            setProfileData(mockCopy);
            setIsDemoMode(true);
            calculateDnaRatings(mockCopy);
            showToast(`Showing simulated sandbox listing for "${formattedUser}"`, "warning");
        } finally {
            setIsLoading(false);
        }
    };

    // Replicates the dynamic formula of UserRatingSheet
    const calculateDnaRatings = (profile) => {
        const anime = profile.statistics?.anime || {};
        const manga = profile.statistics?.manga || {};
        const totalAnime = anime.total_entries || 0;

        const completeness = totalAnime > 0 ? Math.min(10, (anime.completed / totalAnime) * 10) : 6.0;
        const variety = Math.min(10, 5 + (manga.total_entries || 0) / 15);
        const activity = Math.min(10, ((anime.days_watched || 0) + (manga.days_read || 0)) / 7);
        const uniqueness = Math.max(4.0, Math.min(10.0, 12.0 - (anime.mean_score || 7.5)));
        const engagement = Math.min(10, 5 + ((anime.watching || 0) + (manga.reading || 0)) * 0.6);

        const overall = ((completeness + variety + activity + uniqueness + engagement) / 5);

        setDnaRatings({
            overall: parseFloat(overall.toFixed(1)),
            completeness: parseFloat(completeness.toFixed(1)),
            variety: parseFloat(variety.toFixed(1)),
            activity: parseFloat(activity.toFixed(1)),
            uniqueness: parseFloat(uniqueness.toFixed(1)),
            engagement: parseFloat(engagement.toFixed(1))
        });
    };

    useEffect(() => {
        fetchProfileData("MuhammadGoi");
    }, []);

    const resetToMuhammadGoi = () => {
        setSearchInput("MuhammadGoi");
        fetchProfileData("MuhammadGoi");
    };

    const copyToClipboard = (text, type = "Link") => {
        navigator.clipboard.writeText(text);
        showToast(`${type} successfully copied to clipboard!`, "success");
    };

    const downloadRawJson = () => {
        const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(profileData, null, 2));
        const downloadAnchor = document.createElement('a');
        downloadAnchor.setAttribute("href", dataStr);
        downloadAnchor.setAttribute("download", `mal_profile_${profileData.username}.json`);
        document.body.appendChild(downloadAnchor);
        downloadAnchor.click();
        downloadAnchor.remove();
        showToast("Raw JSON packet downloaded", "success");
    };

    const handleAlertToggle = () => {
        const nextState = !isAlertsEnabled;
        setIsAlertsEnabled(nextState);
        if (nextState) {
            showToast("Airing update push notifications configured!", "bell");
        } else {
            showToast("Airing notifications muted.", "bellOff");
        }
    };

    const formatNumber = (num) => {
        if (!num) return "0";
        if (num >= 1000000) return (num / 1000000).toFixed(1) + "M";
        if (num >= 1000) return (num / 1000).toFixed(1) + "K";
        return num.toString();
    };

    const getDnaBadgeStyle = (score) => {
        if (score >= 9.0) return "text-emerald-400 bg-emerald-500/10 border-emerald-500/20";
        if (score >= 7.5) return "text-indigo-400 bg-indigo-500/10 border-indigo-500/20";
        if (score >= 6.0) return "text-amber-400 bg-amber-500/10 border-amber-500/20";
        return "text-rose-400 bg-rose-500/10 border-rose-500/20";
    };

    // Safe variables extracted from data structures
    const animeStats = profileData.statistics?.anime || {};
    const mangaStats = profileData.statistics?.manga || {};
    const totalAnimeCount = (animeStats.watching || 0) + (animeStats.completed || 0) + (animeStats.on_hold || 0) + (animeStats.dropped || 0) + (animeStats.plan_to_watch || 0);

    return (
        <div className="min-h-screen bg-[#0F1117] text-[#F1F5F9] font-sans selection:bg-indigo-500 selection:text-white flex flex-col antialiased">
            <style>{`
        ::-webkit-scrollbar {
          width: 8px;
          height: 8px;
        }
        ::-webkit-scrollbar-track {
          background: #0F1117;
        }
        ::-webkit-scrollbar-thumb {
          background: #1E2230;
          border-radius: 999px;
          border: 2px solid #0F1117;
        }
        ::-webkit-scrollbar-thumb:hover {
          background: #6366f1;
        }
      `}</style>

            { }
            {/* Toast Overlay */}
            {toast.show && (
                <div className="fixed bottom-6 right-6 z-50 flex items-center space-x-3 bg-[#1e2230] border border-indigo-500/30 text-[#F1F5F9] px-4 py-3 rounded-2xl shadow-[0_10px_30px_rgba(0,0,0,0.5)] transition-all duration-300 animate-bounce">
                    <div className="text-indigo-400">
                        {toast.icon === "spinner" && <Flame className="w-5 h-5 animate-spin text-orange-400" />}
                        {toast.icon === "success" && <CheckCircle className="w-5 h-5 text-emerald-400" />}
                        {toast.icon === "warning" && <AlertTriangle className="w-5 h-5 text-amber-500" />}
                        {toast.icon === "info" && <Sparkles className="w-5 h-5" />}
                        {toast.icon === "bell" && <Bell className="w-5 h-5 text-yellow-400" />}
                        {toast.icon === "bellOff" && <BellOff className="w-5 h-5 text-slate-400" />}
                    </div>
                    <p className="text-xs font-semibold">{toast.message}</p>
                </div>
            )}

            {/* Header Sync Area */}
            <header className="sticky top-0 z-40 bg-[#0F1117]/80 backdrop-blur-xl border-b border-white/5 transition-all">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-20 flex items-center justify-between">
                    <div className="flex items-center space-x-3 cursor-pointer" onClick={resetToMuhammadGoi}>
                        <div className="bg-gradient-to-tr from-indigo-600 to-violet-500 p-2.5 rounded-2xl text-white shadow-lg shadow-indigo-500/20">
                            <Flame className="w-5 h-5" />
                        </div>
                        <div>
                            <h1 className="text-sm sm:text-base font-extrabold tracking-tight bg-gradient-to-r from-white via-[#E0E0EA] to-[#c084fc] bg-clip-text text-transparent">
                                MAL PROFILE <span className="text-indigo-400">EXPLORER</span>
                            </h1>
                            <p className="text-[9px] text-slate-400 uppercase tracking-widest font-bold">Fluid Analytical Premium Immersive</p>
                        </div>
                    </div>

                    <div className="flex items-center space-x-3">
                        <div className="relative hidden sm:block">
                            <input
                                type="text"
                                value={searchInput}
                                onChange={(e) => setSearchInput(e.target.value)}
                                onKeyDown={(e) => e.key === "Enter" && fetchProfileData()}
                                className="bg-[#1E2230] border border-white/5 text-slate-100 placeholder-slate-500 rounded-xl pl-4 pr-10 py-2.5 text-xs w-60 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-all"
                                placeholder="Search MAL Username..."
                            />
                            <button
                                onClick={() => fetchProfileData()}
                                className="absolute right-2 top-1/2 -translate-y-1/2 text-xs font-bold text-indigo-400 hover:text-indigo-300 px-1.5"
                            >
                                Go
                            </button>
                        </div>
                        <button
                            onClick={() => fetchProfileData()}
                            className="bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs px-4 py-2.5 rounded-xl transition-all shadow-lg shadow-indigo-600/30 active:scale-[0.98]"
                        >
                            Sync Profile
                        </button>
                    </div>
                </div>
            </header>

            <main className="flex-grow max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">

                {/* Mobile Input Field */}
                <div className="relative block sm:hidden w-full mb-3">
                    <input
                        type="text"
                        value={searchInput}
                        onChange={(e) => setSearchInput(e.target.value)}
                        onKeyDown={(e) => e.key === "Enter" && fetchProfileData()}
                        className="bg-[#1E2230] border border-[#1E2230] text-slate-100 placeholder-slate-500 rounded-2xl px-4 py-3 text-xs w-full focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-all"
                        placeholder="Search MAL User..."
                    />
                </div>

                { }
                {/* Cover Banner Stack */}
                <div className="relative w-full rounded-3xl overflow-hidden bg-[#1E2230] border border-white/5 shadow-2xl shadow-black/40">
                    <div className="absolute inset-0 z-0">
                        <img
                            src={profileData.images?.jpg?.image_url || curatedMockProfile.images.jpg.image_url}
                            className="w-full h-full object-cover blur-3xl scale-125 opacity-45"
                            alt="Backdrop blur"
                        />
                        <div className="absolute inset-0 bg-[#0F1117]/80"></div>
                        <div className="absolute inset-0 bg-gradient-to-t from-[#0F1117] via-transparent to-transparent"></div>
                    </div>

                    <div className="relative z-10 p-5 sm:p-8 md:p-10 flex flex-col">
                        {/* Cover Action Header Row */}
                        <div className="flex items-center justify-between mb-6">
                            <button
                                onClick={resetToMuhammadGoi}
                                className="bg-black/40 hover:bg-black/60 transition-all rounded-full p-2.5 text-white/80 active:scale-95"
                                title="Reset to MuhammadGoi"
                            >
                                <ArrowLeft className="w-4 h-4" />
                            </button>
                            <div className="flex items-center space-x-2">
                                <button
                                    onClick={handleAlertToggle}
                                    className={`rounded-full p-2.5 transition-all active:scale-95 ${isAlertsEnabled ? 'bg-yellow-500/25 border border-yellow-500/30 text-yellow-400' : 'bg-black/40 hover:bg-black/60 text-white/80'}`}
                                    title="Configure Airing Notifications"
                                >
                                    {isAlertsEnabled ? <Bell className="w-4 h-4 fill-current" /> : <BellOff className="w-4 h-4" />}
                                </button>
                                <button
                                    onClick={() => setShowShareModal(true)}
                                    className="bg-black/40 hover:bg-black/60 text-white/80 rounded-full p-2.5 transition-all active:scale-95"
                                    title="Share Card"
                                >
                                    <Share2 className="w-4 h-4" />
                                </button>
                            </div>
                        </div>

                        {/* Profile Detail Stack */}
                        <div className="flex flex-col md:flex-row items-center md:items-end space-y-5 md:space-y-0 md:space-x-8 text-center md:text-left">
                            <div className="relative group">
                                <div className="absolute -inset-1 bg-gradient-to-tr from-indigo-500 to-violet-500 rounded-3xl blur opacity-30 group-hover:opacity-60 transition duration-500"></div>
                                <div className="relative w-36 h-48 sm:w-40 sm:h-52 bg-[#0F1117] rounded-2xl overflow-hidden border-2 border-white/10 shadow-2xl">
                                    <img
                                        src={profileData.images?.jpg?.image_url || curatedMockProfile.images.jpg.image_url}
                                        className="w-full h-full object-cover transform duration-500 group-hover:scale-110"
                                        alt="User Avatar"
                                    />
                                    <div className="absolute top-3 left-3 bg-black/75 backdrop-blur-md px-2 py-0.5 rounded-lg border border-white/10 text-[8px] uppercase tracking-widest font-black text-indigo-400">
                                        MEMBER
                                    </div>
                                </div>
                            </div>

                            {/* Badges and meta labels */}
                            <div className="flex-grow space-y-3">
                                <div className="flex flex-wrap gap-2 justify-center md:justify-start">
                                    <span className="bg-indigo-500/15 text-indigo-400 border border-indigo-500/20 px-3 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wider">
                                        {profileData.gender || "Not Specified"}
                                    </span>
                                    <span className="bg-emerald-500/15 text-emerald-400 border border-emerald-500/20 px-3 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wider">
                                        {profileData.last_online ? "Active" : "Offline"}
                                    </span>
                                    <span className={`border px-3 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wider ${isDemoMode ? "bg-amber-500/15 text-amber-400 border-amber-500/20" : "bg-purple-500/15 text-purple-400 border-purple-500/20"}`}>
                                        {isDemoMode ? "Demo Mode" : "Synced Live"}
                                    </span>
                                </div>

                                <h2 className="text-2xl sm:text-4xl font-extrabold tracking-tight text-white">
                                    {profileData.username}
                                </h2>

                                <a
                                    href={profileData.url}
                                    target="_blank"
                                    rel="noreferrer"
                                    className="inline-flex items-center text-xs text-indigo-400 hover:text-indigo-300 transition-colors font-semibold"
                                >
                                    <span>{profileData.url?.replace("https://", "")}</span>
                                    <ExternalLink className="w-3.5 h-3.5 ml-1.5" />
                                </a>

                                {/* Grid Indicators inside Cover Card */}
                                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 bg-black/40 backdrop-blur-md p-3.5 rounded-2xl border border-white/5 max-w-xl mx-auto md:mx-0 mt-4">
                                    <div className="text-center">
                                        <span className="block text-[8px] font-extrabold text-slate-400 uppercase tracking-widest">Anime Score</span>
                                        <span className="text-xs sm:text-sm font-bold text-yellow-400 flex items-center justify-center gap-1 mt-1">
                                            <Star className="w-3 h-3 fill-current" /> {animeStats.mean_score ? animeStats.mean_score.toFixed(2) : "0.00"}
                                        </span>
                                    </div>
                                    <div className="h-8 w-px bg-white/5 hidden sm:block self-center"></div>
                                    <div className="text-center">
                                        <span className="block text-[8px] font-extrabold text-slate-400 uppercase tracking-widest">Days Read</span>
                                        <span className="text-xs sm:text-sm font-bold text-slate-200 mt-1 block">
                                            {mangaStats.days_read ? mangaStats.days_read.toFixed(1) : "0.0"}
                                        </span>
                                    </div>
                                    <div className="h-8 w-px bg-white/5 hidden sm:block self-center"></div>
                                    <div className="text-center">
                                        <span className="block text-[8px] font-extrabold text-slate-400 uppercase tracking-widest">Completed Items</span>
                                        <span className="text-xs sm:text-sm font-bold text-indigo-400 mt-1 block">
                                            {(animeStats.completed || 0) + (mangaStats.completed || 0)}
                                        </span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                { }
                {/* User Profile DNA Rating card (Adapted from Flutter UserRatingSheet) */}
                <div className="bg-gradient-to-br from-indigo-500/5 to-purple-500/5 border border-indigo-500/10 rounded-2xl p-5 sm:p-6 shadow-xl relative overflow-hidden">
                    <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-4 gap-3">
                        <div className="flex items-center space-x-2.5">
                            <div className="w-1.5 h-4 bg-indigo-500 rounded-full"></div>
                            <h3 className="text-xs sm:text-sm font-bold tracking-tight text-indigo-400 uppercase">
                                Profile DNA & Engagement Ratings (Flutter Spec)
                            </h3>
                        </div>

                        <div className="flex items-center space-x-3">
                            <button
                                onClick={() => setIsEditingDNA(!isEditingDNA)}
                                className="text-[10px] font-bold text-indigo-400 hover:text-indigo-300 transition-colors uppercase tracking-wider flex items-center"
                            >
                                <Sliders className="w-3 h-3 mr-1" />
                                {isEditingDNA ? "Done Customizing" : "Customize"}
                            </button>
                            <button
                                onClick={() => {
                                    calculateDnaRatings(profileData);
                                    setIsEditingDNA(false);
                                    showToast("Formula re-calculated with actual database scores", "success");
                                }}
                                className="text-[10px] font-bold text-indigo-400 hover:text-indigo-300 transition-colors uppercase tracking-wider flex items-center"
                            >
                                <RotateCcw className="w-3 h-3 mr-1" />
                                Reset Formula
                            </button>
                        </div>
                    </div>

                    {/* DNA Rating grid */}
                    <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
                        <div className={`border rounded-2xl p-4 text-center transition-all ${getDnaBadgeStyle(dnaRatings.overall)}`}>
                            <span className="text-2xl font-black">{dnaRatings.overall}</span>
                            <p className="text-[9px] font-extrabold text-slate-400 uppercase tracking-wider mt-1.5">Overall Tier</p>
                            {isEditingDNA && (
                                <input
                                    type="range" min="1" max="10" step="0.1"
                                    value={dnaRatings.overall}
                                    onChange={(e) => setDnaRatings({ ...dnaRatings, overall: parseFloat(e.target.value) })}
                                    className="w-full mt-2 accent-indigo-500"
                                />
                            )}
                        </div>

                        <div className={`border rounded-2xl p-4 text-center transition-all bg-[#1E2230]/40 border-white/5`}>
                            <span className="text-2xl font-black text-[#60C8A0]">{dnaRatings.completeness}</span>
                            <p className="text-[9px] font-extrabold text-slate-400 uppercase tracking-wider mt-1.5">Completeness</p>
                            {isEditingDNA && (
                                <input
                                    type="range" min="1" max="10" step="0.1"
                                    value={dnaRatings.completeness}
                                    onChange={(e) => setDnaRatings({ ...dnaRatings, completeness: parseFloat(e.target.value) })}
                                    className="w-full mt-2 accent-emerald-500"
                                />
                            )}
                        </div>

                        <div className={`border rounded-2xl p-4 text-center transition-all bg-[#1E2230]/40 border-white/5`}>
                            <span className="text-2xl font-black text-purple-400">{dnaRatings.variety}</span>
                            <p className="text-[9px] font-extrabold text-slate-400 uppercase tracking-wider mt-1.5">Genre Variety</p>
                            {isEditingDNA && (
                                <input
                                    type="range" min="1" max="10" step="0.1"
                                    value={dnaRatings.variety}
                                    onChange={(e) => setDnaRatings({ ...dnaRatings, variety: parseFloat(e.target.value) })}
                                    className="w-full mt-2 accent-purple-500"
                                />
                            )}
                        </div>

                        <div className={`border rounded-2xl p-4 text-center transition-all bg-[#1E2230]/40 border-white/5`}>
                            <span className="text-2xl font-black text-yellow-400">{dnaRatings.activity}</span>
                            <p className="text-[9px] font-extrabold text-slate-400 uppercase tracking-wider mt-1.5">Activity Level</p>
                            {isEditingDNA && (
                                <input
                                    type="range" min="1" max="10" step="0.1"
                                    value={dnaRatings.activity}
                                    onChange={(e) => setDnaRatings({ ...dnaRatings, activity: parseFloat(e.target.value) })}
                                    className="w-full mt-2 accent-yellow-500"
                                />
                            )}
                        </div>

                        <div className={`border rounded-2xl p-4 text-center transition-all bg-[#1E2230]/40 border-white/5`}>
                            <span className="text-2xl font-black text-pink-400">{dnaRatings.uniqueness}</span>
                            <p className="text-[9px] font-extrabold text-slate-400 uppercase tracking-wider mt-1.5">Uniqueness</p>
                            {isEditingDNA && (
                                <input
                                    type="range" min="1" max="10" step="0.1"
                                    value={dnaRatings.uniqueness}
                                    onChange={(e) => setDnaRatings({ ...dnaRatings, uniqueness: parseFloat(e.target.value) })}
                                    className="w-full mt-2 accent-pink-500"
                                />
                            )}
                        </div>

                        <div className={`border rounded-2xl p-4 text-center transition-all bg-[#1E2230]/40 border-white/5`}>
                            <span className="text-2xl font-black text-sky-400">{dnaRatings.engagement}</span>
                            <p className="text-[9px] font-extrabold text-slate-400 uppercase tracking-wider mt-1.5">Engagement</p>
                            {isEditingDNA && (
                                <input
                                    type="range" min="1" max="10" step="0.1"
                                    value={dnaRatings.engagement}
                                    onChange={(e) => setDnaRatings({ ...dnaRatings, engagement: parseFloat(e.target.value) })}
                                    className="w-full mt-2 accent-sky-500"
                                />
                            )}
                        </div>
                    </div>
                </div>

                {/* Split screen content area (Responsive Left Sidebar, Right Main Panel) */}
                <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">

                    { }
                    {/* Left Sidebar Specification */}
                    <div className="lg:col-span-4 space-y-6">
                        <div className="bg-[#1E2230] border border-white/5 rounded-2xl p-5 shadow-lg space-y-4">
                            <h3 className="text-xs font-black tracking-widest text-slate-400 uppercase mb-3 flex items-center gap-2">
                                <User className="w-4 h-4 text-indigo-400" />
                                <span>Specifications</span>
                            </h3>

                            <div className="divide-y divide-white/5 text-xs">
                                <div className="flex justify-between py-3">
                                    <span className="text-slate-400">Gender</span>
                                    <span className="font-bold text-slate-200">{profileData.gender || "Not Specified"}</span>
                                </div>
                                <div className="flex justify-between py-3">
                                    <span className="text-slate-400">Location</span>
                                    <span className="font-bold text-slate-200 truncate max-w-[180px] text-right">
                                        {profileData.location || "Global Anime Community"}
                                    </span>
                                </div>
                                <div className="flex justify-between py-3">
                                    <span className="text-slate-400">Joined Date</span>
                                    <span className="font-bold text-slate-200">
                                        {profileData.joined ? new Date(profileData.joined).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' }) : "Unknown"}
                                    </span>
                                </div>
                                <div className="flex justify-between py-3">
                                    <span className="text-slate-400">Last Active</span>
                                    <span className="font-bold text-slate-200">{profileData.last_online || "Offline"}</span>
                                </div>
                                <div className="flex justify-between py-3">
                                    <span className="text-slate-400">Birthday</span>
                                    <span className="font-bold text-slate-200">
                                        {profileData.birthday ? new Date(profileData.birthday).toLocaleDateString(undefined, { month: 'long', day: 'numeric' }) : "May 14 (Simulated)"}
                                    </span>
                                </div>
                            </div>
                        </div>

                        {/* Interest Tags / Classifications */}
                        <div className="bg-[#1E2230] border border-white/5 rounded-2xl p-5 shadow-lg space-y-4">
                            <h3 className="text-xs font-black tracking-widest text-slate-400 uppercase mb-2 flex items-center gap-2">
                                <Sparkles className="w-4 h-4 text-indigo-400" />
                                <span>Interests & Badges</span>
                            </h3>
                            <div className="flex flex-wrap gap-2 pt-2">
                                {["Psychological", "Sci-Fi", "Seinen", "Mystery", "Cyberpunk", "Tragedy", "Philosophy", "Deep Storytelling"].map((badge, idx) => (
                                    <span key={idx} className="bg-black/30 border border-white/5 text-slate-300 px-2.5 py-1.5 rounded-lg text-[10px] font-semibold hover:border-indigo-500/30 transition-all cursor-pointer">
                                        {badge}
                                    </span>
                                ))}
                            </div>
                        </div>

                        {/* Shortcuts Utility Actions */}
                        <div className="bg-[#1E2230] border border-white/5 rounded-2xl p-4 shadow-lg space-y-2">
                            <a
                                href={profileData.url || "https://myanimelist.net"}
                                target="_blank"
                                rel="noreferrer"
                                className="w-full border border-indigo-500/20 hover:bg-indigo-500/10 text-indigo-400 py-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center space-x-2"
                            >
                                <ExternalLink className="w-3.5 h-3.5" />
                                <span>Open Official MAL Listing</span>
                            </a>
                            <button
                                onClick={() => copyToClipboard(profileData.url || "", "Listing Link")}
                                className="w-full bg-[#0F1117]/60 hover:bg-[#0F1117] text-slate-300 py-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center space-x-2"
                            >
                                <Copy className="w-3.5 h-3.5" />
                                <span>Copy Profile Link</span>
                            </button>
                            <button
                                onClick={downloadRawJson}
                                className="w-full bg-[#0F1117]/30 hover:bg-[#0F1117]/60 text-slate-400 py-2.5 rounded-xl text-[11px] font-bold transition-all flex items-center justify-center space-x-1.5"
                            >
                                <Download className="w-3.5 h-3.5" />
                                <span>Export Profile RAW Backup</span>
                            </button>
                        </div>
                    </div>

                    { }
                    {/* Right Main Analytics panel */}
                    <div className="lg:col-span-8 space-y-6">

                        {/* Dynamic Tabs Indicator bar */}
                        <div className="bg-[#1E2230] border border-white/5 rounded-2xl p-1.5 flex space-x-1 overflow-x-auto">
                            {[
                                { id: "overview", label: "Overview & Story" },
                                { id: "metrics", label: "Metrics & Stats" },
                                { id: "favorites", label: "Cast & Favorites" },
                                { id: "raw", label: "Raw JSON Object" }
                            ].map((tab) => (
                                <button
                                    key={tab.id}
                                    onClick={() => setActiveTab(tab.id)}
                                    className={`flex-shrink-0 text-xs font-bold px-4 py-3 rounded-xl transition-all duration-200 ${activeTab === tab.id ? "bg-indigo-600 text-white shadow-lg shadow-indigo-600/15" : "text-slate-400 hover:text-slate-200"}`}
                                >
                                    {tab.label}
                                </button>
                            ))}
                        </div>

                        { }
                        {/* TAB CONTENT: Overview & bio */}
                        {activeTab === "overview" && (
                            <div className="space-y-6">

                                {/* Story / About synopsis Box */}
                                <div className="bg-[#1E2230] border border-white/5 rounded-2xl p-5 sm:p-6 shadow-lg space-y-4">
                                    <div className="flex items-center space-x-2">
                                        <div className="w-1 h-3.5 bg-indigo-500 rounded-full"></div>
                                        <h4 className="text-xs font-black tracking-wider text-slate-400 uppercase">Profile Narrative / Bio Statement</h4>
                                    </div>
                                    <p className={`text-xs text-slate-300 leading-relaxed transition-all duration-300 ${synopsisExpanded ? "" : "max-h-24 overflow-hidden"}`}>
                                        {profileData.about ? profileData.about : "This user has not structured a personalized biography or custom intro details on MyAnimeList yet. We've compiled sandbox specifications based on their database activity history."}
                                    </p>
                                    <button
                                        onClick={() => setSynopsisExpanded(!synopsisExpanded)}
                                        className="text-[10px] font-black text-indigo-400 hover:text-indigo-300 transition-colors uppercase tracking-widest flex items-center pt-1"
                                    >
                                        {synopsisExpanded ? <ChevronUp className="w-3.5 h-3.5 mr-1" /> : <ChevronDown className="w-3.5 h-3.5 mr-1" />}
                                        {synopsisExpanded ? "Collapse Narrative" : "Read Full Storyline"}
                                    </button>
                                </div>

                                {/* Activity Feed Updates */}
                                <div className="bg-[#1E2230] border border-white/5 rounded-2xl p-5 sm:p-6 shadow-lg space-y-4">
                                    <div className="flex items-center space-x-2">
                                        <div className="w-1 h-3.5 bg-indigo-500 rounded-full"></div>
                                        <h4 className="text-xs font-black tracking-wider text-slate-400 uppercase">Airing updates & feed items</h4>
                                    </div>

                                    <div className="divide-y divide-white/5">
                                        {profileData.updates && profileData.updates.length > 0 ? (
                                            profileData.updates.map((update, idx) => (
                                                <div key={idx} className="py-4 flex justify-between items-center text-xs first:pt-0 last:pb-0">
                                                    <div className="space-y-1.5 pr-4">
                                                        <span className="font-extrabold text-white text-sm hover:text-indigo-400 transition-colors cursor-pointer block">
                                                            {update.item}
                                                        </span>
                                                        <div className="flex flex-wrap items-center gap-2">
                                                            <span className={`border px-1.5 py-0.5 rounded text-[8px] font-black uppercase ${update.type === "Anime" ? "text-indigo-400 bg-indigo-500/10 border-indigo-500/20" : "text-pink-400 bg-pink-500/10 border-pink-500/20"}`}>
                                                                {update.type}
                                                            </span>
                                                            <span className="text-slate-500">•</span>
                                                            <span className="text-slate-300 font-bold">{update.status}</span>
                                                            {update.progress && <span className="text-slate-400">({update.progress})</span>}
                                                            {update.score && (
                                                                <span className="bg-yellow-500/10 border border-yellow-500/20 text-yellow-400 text-[9px] px-1.5 py-0.5 rounded font-black">
                                                                    Scored {update.score}
                                                                </span>
                                                            )}
                                                        </div>
                                                    </div>
                                                    <span className="text-slate-500 text-[10px] font-semibold whitespace-nowrap">{update.date}</span>
                                                </div>
                                            ))
                                        ) : (
                                            <div className="py-8 text-center text-slate-500 text-xs">
                                                No activity updates available for this user on the general profile interface.
                                            </div>
                                        )}
                                    </div>
                                </div>

                            </div>
                        )}

                        { }
                        {/* TAB CONTENT: Metrics & Stats with Dynamic Donut Progress */}
                        {activeTab === "metrics" && (
                            <div className="space-y-6">
                                <div className="grid grid-cols-1 md:grid-cols-12 gap-6 bg-[#1E2230] border border-white/5 rounded-2xl p-6 shadow-lg">

                                    {/* Dynamic SVG Donut Chart */}
                                    <div className="md:col-span-5 flex flex-col items-center justify-center py-4">
                                        <div className="relative w-40 h-40 flex items-center justify-center">
                                            <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
                                                {/* Background Base Ring */}
                                                <circle cx="50" cy="50" r="40" stroke="#0F1117" strokeWidth="8" fill="transparent" />

                                                {/* Completed Ring - Segment 1 */}
                                                <circle
                                                    cx="50" cy="50" r="40"
                                                    stroke="#10b981" strokeWidth="8" fill="transparent"
                                                    strokeDasharray={`${((animeStats.completed || 0) / (totalAnimeCount || 1)) * 251.2} 251.2`}
                                                />
                                                {/* Watching Ring - Segment 2 */}
                                                <circle
                                                    cx="50" cy="50" r="40"
                                                    stroke="#6366f1" strokeWidth="8" fill="transparent"
                                                    strokeDasharray={`${((animeStats.watching || 0) / (totalAnimeCount || 1)) * 251.2} 251.2`}
                                                    strokeDashoffset={`-${((animeStats.completed || 0) / (totalAnimeCount || 1)) * 251.2}`}
                                                />
                                                {/* Plan to watch Ring - Segment 3 */}
                                                <circle
                                                    cx="50" cy="50" r="40"
                                                    stroke="#64748b" strokeWidth="8" fill="transparent"
                                                    strokeDasharray={`${((animeStats.plan_to_watch || 0) / (totalAnimeCount || 1)) * 251.2} 251.2`}
                                                    strokeDashoffset={`-${(((animeStats.completed || 0) + (animeStats.watching || 0)) / (totalAnimeCount || 1)) * 251.2}`}
                                                />
                                            </svg>
                                            <div className="absolute inset-0 flex flex-col items-center justify-center">
                                                <span className="text-[8px] font-extrabold text-slate-400 uppercase tracking-widest">Total Anime</span>
                                                <span className="text-xl font-black text-slate-100">{totalAnimeCount}</span>
                                            </div>
                                        </div>
                                    </div>

                                    {/* Progressive Categories Breakdown */}
                                    <div className="md:col-span-7 space-y-4 flex flex-col justify-center">
                                        <h4 className="text-xs font-black tracking-widest text-slate-400 uppercase">
                                            Anime Statistical Profile
                                        </h4>

                                        <div className="space-y-3">
                                            <div>
                                                <div className="flex justify-between text-[11px] mb-1">
                                                    <span className="font-bold text-emerald-400">Completed</span>
                                                    <span className="font-semibold text-slate-300">
                                                        {animeStats.completed || 0} ({(((animeStats.completed || 0) / (totalAnimeCount || 1)) * 100).toFixed(1)}%)
                                                    </span>
                                                </div>
                                                <div className="w-full bg-[#0F1117] h-2 rounded-full overflow-hidden">
                                                    <div
                                                        className="bg-emerald-500 h-full rounded-full transition-all duration-500"
                                                        style={{ width: `${((animeStats.completed || 0) / (totalAnimeCount || 1)) * 100}%` }}
                                                    ></div>
                                                </div>
                                            </div>

                                            <div>
                                                <div className="flex justify-between text-[11px] mb-1">
                                                    <span className="font-bold text-indigo-400">Watching</span>
                                                    <span className="font-semibold text-slate-300">
                                                        {animeStats.watching || 0} ({(((animeStats.watching || 0) / (totalAnimeCount || 1)) * 100).toFixed(1)}%)
                                                    </span>
                                                </div>
                                                <div className="w-full bg-[#0F1117] h-2 rounded-full overflow-hidden">
                                                    <div
                                                        className="bg-indigo-500 h-full rounded-full transition-all duration-500"
                                                        style={{ width: `${((animeStats.watching || 0) / (totalAnimeCount || 1)) * 100}%` }}
                                                    ></div>
                                                </div>
                                            </div>

                                            <div>
                                                <div className="flex justify-between text-[11px] mb-1">
                                                    <span className="font-bold text-amber-500">On Hold</span>
                                                    <span className="font-semibold text-slate-300">
                                                        {animeStats.on_hold || 0} ({(((animeStats.on_hold || 0) / (totalAnimeCount || 1)) * 100).toFixed(1)}%)
                                                    </span>
                                                </div>
                                                <div className="w-full bg-[#0F1117] h-2 rounded-full overflow-hidden">
                                                    <div
                                                        className="bg-amber-500 h-full rounded-full transition-all duration-500"
                                                        style={{ width: `${((animeStats.on_hold || 0) / (totalAnimeCount || 1)) * 100}%` }}
                                                    ></div>
                                                </div>
                                            </div>

                                            <div>
                                                <div className="flex justify-between text-[11px] mb-1">
                                                    <span className="font-bold text-rose-500">Dropped</span>
                                                    <span className="font-semibold text-slate-300">
                                                        {animeStats.dropped || 0} ({(((animeStats.dropped || 0) / (totalAnimeCount || 1)) * 100).toFixed(1)}%)
                                                    </span>
                                                </div>
                                                <div className="w-full bg-[#0F1117] h-2 rounded-full overflow-hidden">
                                                    <div
                                                        className="bg-rose-500 h-full rounded-full transition-all duration-500"
                                                        style={{ width: `${((animeStats.dropped || 0) / (totalAnimeCount || 1)) * 100}%` }}
                                                    ></div>
                                                </div>
                                            </div>

                                            <div>
                                                <div className="flex justify-between text-[11px] mb-1">
                                                    <span className="font-bold text-slate-400">Plan To Watch</span>
                                                    <span className="font-semibold text-slate-300">
                                                        {animeStats.plan_to_watch || 0} ({(((animeStats.plan_to_watch || 0) / (totalAnimeCount || 1)) * 100).toFixed(1)}%)
                                                    </span>
                                                </div>
                                                <div className="w-full bg-[#0F1117] h-2 rounded-full overflow-hidden">
                                                    <div
                                                        className="bg-slate-500 h-full rounded-full transition-all duration-500"
                                                        style={{ width: `${((animeStats.plan_to_watch || 0) / (totalAnimeCount || 1)) * 100}%` }}
                                                    ></div>
                                                </div>
                                            </div>
                                        </div>

                                    </div>
                                </div>

                                {/* Manga Statistical metrics Box */}
                                <div className="bg-[#1E2230] border border-white/5 rounded-2xl p-5 sm:p-6 shadow-lg space-y-4">
                                    <div className="flex items-center space-x-2">
                                        <div className="w-1 h-3.5 bg-pink-500 rounded-full"></div>
                                        <h4 className="text-xs font-black tracking-widest text-slate-400 uppercase">
                                            Manga Metrics Overview
                                        </h4>
                                    </div>
                                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 pt-2">
                                        <div className="bg-[#0F1117] p-3 rounded-xl border border-white/5">
                                            <span className="block text-[8px] text-slate-500 uppercase tracking-widest">Chapters Read</span>
                                            <span className="text-sm sm:text-base font-black text-pink-400 mt-1 block">
                                                {mangaStats.chapters_read ? formatNumber(mangaStats.chapters_read) : "0"}
                                            </span>
                                        </div>
                                        <div className="bg-[#0F1117] p-3 rounded-xl border border-white/5">
                                            <span className="block text-[8px] text-slate-500 uppercase tracking-widest">Volumes Read</span>
                                            <span className="text-sm sm:text-base font-black text-pink-400 mt-1 block">
                                                {mangaStats.volumes_read ? formatNumber(mangaStats.volumes_read) : "0"}
                                            </span>
                                        </div>
                                        <div className="bg-[#0F1117] p-3 rounded-xl border border-white/5">
                                            <span className="block text-[8px] text-slate-500 uppercase tracking-widest">Total Entries</span>
                                            <span className="text-sm sm:text-base font-black text-pink-400 mt-1 block">
                                                {mangaStats.total_entries || "0"}
                                            </span>
                                        </div>
                                        <div className="bg-[#0F1117] p-3 rounded-xl border border-white/5">
                                            <span className="block text-[8px] text-slate-500 uppercase tracking-widest">Mean Score</span>
                                            <span className="text-sm sm:text-base font-black text-pink-400 mt-1 block">
                                                {mangaStats.mean_score ? mangaStats.mean_score.toFixed(2) : "0.00"}
                                            </span>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        )}

                        { }
                        {/* TAB CONTENT: Favorites & Cast grids */}
                        {activeTab === "favorites" && (
                            <div className="space-y-6">

                                {/* Favorite Anime Grid */}
                                <div className="space-y-4">
                                    <div className="flex items-center space-x-2">
                                        <div className="w-1 h-3.5 bg-indigo-500 rounded-full"></div>
                                        <h4 className="text-xs font-black tracking-wider text-slate-400 uppercase">
                                            Favorite Shows / Media
                                        </h4>
                                    </div>
                                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                                        {profileData.favorites?.anime && profileData.favorites.anime.length > 0 ? (
                                            profileData.favorites.anime.map((anime, idx) => (
                                                <div key={idx} className="bg-[#0F1117]/60 border border-white/5 rounded-2xl overflow-hidden hover:border-indigo-500/30 hover:scale-[1.01] transition-all group flex flex-col h-full">
                                                    <div className="relative aspect-[3/4] bg-black">
                                                        <img
                                                            src={anime.images?.jpg?.image_url || anime.images?.webp?.image_url}
                                                            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                                                            alt={anime.title}
                                                        />
                                                        <span className="absolute bottom-2 left-2 bg-black/80 backdrop-blur px-2 py-0.5 rounded text-[8px] font-black tracking-widest text-indigo-400 uppercase">
                                                            {anime.type || "TV"}
                                                        </span>
                                                        {anime.score && (
                                                            <span className="absolute top-2 right-2 bg-black/80 backdrop-blur px-1.5 py-0.5 rounded text-[8px] font-black text-yellow-400 flex items-center gap-1">
                                                                <Star className="w-2.5 h-2.5 fill-current" /> {anime.score}
                                                            </span>
                                                        )}
                                                    </div>
                                                    <div className="p-3 flex-grow flex items-center justify-center bg-[#1e2230]/40">
                                                        <p className="text-[11px] font-bold text-center text-slate-300 line-clamp-2">{anime.title}</p>
                                                    </div>
                                                </div>
                                            ))
                                        ) : (
                                            <div className="col-span-full py-8 text-center text-slate-500 text-xs bg-[#1E2230]/30 rounded-2xl border border-white/5">
                                                No designated favorite anime media available.
                                            </div>
                                        )}
                                    </div>
                                </div>

                                {/* Favorite Characters Grid */}
                                <div className="space-y-4">
                                    <div className="flex items-center space-x-2">
                                        <div className="w-1 h-3.5 bg-pink-500 rounded-full"></div>
                                        <h4 className="text-xs font-black tracking-wider text-slate-400 uppercase">
                                            Favorite Characters & Cast
                                        </h4>
                                    </div>
                                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                                        {profileData.favorites?.characters && profileData.favorites.characters.length > 0 ? (
                                            profileData.favorites.characters.map((char, idx) => (
                                                <div key={idx} className="bg-[#0F1117]/60 border border-white/5 rounded-2xl overflow-hidden hover:border-pink-500/30 hover:scale-[1.01] transition-all group flex flex-col h-full">
                                                    <div className="relative aspect-[3/4] bg-black">
                                                        <img
                                                            src={char.images?.jpg?.image_url || char.images?.webp?.image_url}
                                                            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                                                            alt={char.name}
                                                        />
                                                        <span className="absolute bottom-2 left-2 bg-pink-500/15 border border-pink-500/20 px-2 py-0.5 rounded text-[8px] font-black tracking-widest text-pink-400 uppercase">
                                                            {char.role || "Main"}
                                                        </span>
                                                    </div>
                                                    <div className="p-3 flex-grow flex items-center justify-center bg-[#1e2230]/40">
                                                        <p className="text-[11px] font-bold text-center text-slate-300 line-clamp-1">{char.name}</p>
                                                    </div>
                                                </div>
                                            ))
                                        ) : (
                                            <div className="col-span-full py-8 text-center text-slate-500 text-xs bg-[#1E2230]/30 rounded-2xl border border-white/5">
                                                No designated favorite characters available.
                                            </div>
                                        )}
                                    </div>
                                </div>

                            </div>
                        )}

                        { }
                        {/* TAB CONTENT: Raw JSON Viewer */}
                        {activeTab === "raw" && (
                            <div className="space-y-4">
                                <div className="flex justify-between items-center bg-[#1E2230] border border-white/5 rounded-2xl p-4 shadow-lg">
                                    <div>
                                        <h4 className="text-xs font-bold text-slate-300">Jikan API v4 Direct payload data</h4>
                                        <p className="text-[10px] text-slate-500">Live JSON response parsed natively from official REST API</p>
                                    </div>
                                    <button
                                        onClick={() => copyToClipboard(JSON.stringify(profileData, null, 2), "Raw JSON Packet")}
                                        className="bg-indigo-600/20 hover:bg-indigo-600/30 text-indigo-400 text-xs font-bold px-3.5 py-2 rounded-xl border border-indigo-500/15 transition-all flex items-center gap-1.5"
                                    >
                                        <Copy className="w-3.5 h-3.5" />
                                        <span>Copy JSON</span>
                                    </button>
                                </div>
                                <pre className="bg-[#0F1117] text-[10px] sm:text-xs text-slate-400 p-5 rounded-2xl border border-white/5 overflow-auto max-h-[500px] leading-relaxed">
                                    {JSON.stringify(profileData, null, 2)}
                                </pre>
                            </div>
                        )}

                    </div>
                </div>
            </main>

            { }
            {/* PREMIUM SHARE DIALOG MODAL */}
            {showShareModal && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm transition-all duration-300">
                    <div className="bg-[#1E2230] border border-white/10 rounded-3xl max-w-md w-full overflow-hidden shadow-2xl relative animate-in zoom-in-95 duration-200">
                        <button
                            onClick={() => setShowShareModal(false)}
                            className="absolute top-4 right-4 text-slate-400 hover:text-white"
                        >
                            <X className="w-5 h-5" />
                        </button>
                        <div className="p-6 text-center space-y-4">
                            <div className="mx-auto w-12 h-12 rounded-full bg-indigo-500/10 text-indigo-400 flex items-center justify-center text-xl mb-2">
                                <Share2 className="w-5 h-5" />
                            </div>
                            <h3 className="text-lg font-bold text-white">Share User Card</h3>
                            <p className="text-xs text-slate-400">
                                Generate a compiled sharing snapshot link for <span className="font-bold text-slate-200">{profileData.username}</span>.
                            </p>

                            <div className="bg-[#0F1117] p-3 rounded-xl flex items-center justify-between border border-white/5">
                                <span className="text-[10px] text-slate-400 select-all truncate max-w-[240px]">
                                    {profileData.url || "https://myanimelist.net"}
                                </span>
                                <button
                                    onClick={() => {
                                        copyToClipboard(profileData.url || "", "Share Link");
                                        setShowShareModal(false);
                                    }}
                                    className="text-xs text-indigo-400 hover:text-indigo-300 font-bold ml-2 shrink-0"
                                >
                                    Copy
                                </button>
                            </div>

                            <div className="flex space-x-2 pt-2">
                                <button
                                    onClick={() => setShowShareModal(false)}
                                    className="w-full bg-white/5 hover:bg-white/10 text-slate-300 py-3 rounded-xl text-xs font-bold transition-all"
                                >
                                    Cancel
                                </button>
                                <button
                                    onClick={() => {
                                        showToast("Snapshot downloaded to local storage!", "success");
                                        setShowShareModal(false);
                                    }}
                                    className="w-full bg-indigo-600 hover:bg-indigo-500 text-white py-3 rounded-xl text-xs font-bold transition-all"
                                >
                                    Download Card
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Premium Footer */}
            <footer className="border-t border-white/5 bg-[#0F1117] py-8 text-xs text-slate-500 mt-12">
                <div className="max-w-7xl mx-auto px-4 flex flex-col sm:flex-row justify-between items-center gap-4">
                    <p>© 2026 Premium Profile Explorer Dashboard. Rebuilt to Flutter Visual Specs.</p>
                    <p>
                        Powered by open-source <a href="https://jikan.moe" target="_blank" rel="noreferrer" className="text-indigo-400 hover:underline">Jikan REST API</a>.
                    </p>
                </div>
            </footer>
        </div>
    );
}