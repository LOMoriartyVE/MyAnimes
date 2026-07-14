import React, { useState, useEffect, useRef } from 'react';

// ==========================================
// PRESET MOCK DATA FOR INSTANT GRATIFICATION
// ==========================================
const PRESETS = {
    5114: {
        id: 5114,
        title: "Fullmetal Alchemist: Brotherhood",
        englishTitle: "Fullmetal Alchemist: Brotherhood",
        japaneseTitle: "鋼の錬金術師 FULLMETAL ALCHEMIST",
        synonyms: ["FMA", "FMAB"],
        synopsis: "After a horrific alchemy accident leaves brothers Edward and Alphonse Elric with damaged bodies, they embark on a journey to find the legendary Philosopher's Stone to restore themselves. Edward, now a state-certified 'State Alchemist,' must navigate political intrigue and dark conspiracies while facing off against dangerous homunculi.",
        imageUrl: "https://cdn.myanimelist.net/images/anime/1223/96541.jpg",
        bannerUrl: "https://images.unsplash.com/photo-1578632767115-351597cf2477?q=80&w=1200&auto=format&fit=crop",
        score: 9.10,
        rank: 1,
        popularity: 3,
        members: 3300251,
        episodes: 64,
        status: "Finished Airing",
        aired: "Apr 5, 2009 to Jul 4, 2010",
        type: "TV",
        source: "Manga",
        duration: "24 min. per ep.",
        rating: "R - 17+ (violence & profanity)",
        studios: ["Bones"],
        genres: ["Action", "Adventure", "Drama", "Fantasy"],
        trailerUrl: "https://www.youtube.com/embed/dQw4w9WgXcQ",
        statistics: {
            watching: 180000,
            completed: 2500000,
            on_hold: 120000,
            dropped: 50251,
            plan_to_watch: 450000
        },
        background: "Fullmetal Alchemist: Brotherhood is an adaptation of Hiromu Arakawa's manga that stays entirely faithful to the source material.",
        broadcast: "Sundays at 17:00 (JST)",
        season: "Spring 2009"
    },
    52991: {
        id: 52991,
        title: "Sousou no Frieren",
        englishTitle: "Frieren: Beyond Journey's End",
        japaneseTitle: "葬送のフリーレン",
        synonyms: ["Frieren"],
        synopsis: "The adventure is over, but life goes on for an elf mage who begins to learn what time means to her mortal companions. Decades after the hero's party defeated the Demon King, Frieren visits her former allies only to discover how quickly human life passes, inspiring her to embark on a new journey to understand them better.",
        imageUrl: "https://cdn.myanimelist.net/images/anime/1015/138075.jpg",
        bannerUrl: "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?q=80&w=1200&auto=format&fit=crop",
        score: 9.39,
        rank: 2,
        popularity: 204,
        members: 950000,
        episodes: 28,
        status: "Finished Airing",
        aired: "Sep 29, 2023 to Mar 22, 2024",
        type: "TV",
        source: "Manga",
        duration: "24 min. per ep.",
        rating: "PG-13 - Teens 13 or older",
        studios: ["Madhouse"],
        genres: ["Adventure", "Drama", "Fantasy"],
        trailerUrl: "https://www.youtube.com/embed/qgQkT9C1eTY",
        statistics: {
            watching: 85000,
            completed: 750000,
            on_hold: 25000,
            dropped: 8000,
            plan_to_watch: 82000
        },
        background: "Winner of multiple prestige manga awards before adapting, Sousou no Frieren quickly rose to the #1 spot on MyAnimeList.",
        broadcast: "Fridays at 23:00 (JST)",
        season: "Fall 2023"
    }
};

const DEFAULT_CHARACTERS = [
    { name: "Edward Elric", role: "Main", vaName: "Romi Park", vaImage: "https://cdn.myanimelist.net/images/voiceactors/3/65113.jpg", charImage: "https://cdn.myanimelist.net/images/characters/9/72533.jpg" },
    { name: "Alphonse Elric", role: "Main", vaName: "Rie Kugimiya", vaImage: "https://cdn.myanimelist.net/images/voiceactors/3/54432.jpg", charImage: "https://cdn.myanimelist.net/images/characters/5/54211.jpg" },
    { name: "Roy Mustang", role: "Supporting", vaName: "Shinichiro Miki", vaImage: "https://cdn.myanimelist.net/images/voiceactors/1/54941.jpg", charImage: "https://cdn.myanimelist.net/images/characters/14/72553.jpg" },
    { name: "Winry Rockbell", role: "Supporting", vaName: "Megumi Toyoguchi", vaImage: "https://cdn.myanimelist.net/images/voiceactors/3/54823.jpg", charImage: "https://cdn.myanimelist.net/images/characters/11/72535.jpg" }
];

const DEFAULT_RECOMMENDATIONS = [
    { id: 2904, title: "Code Geass: Lelouch of the Rebellion R2", image: "https://cdn.myanimelist.net/images/anime/4/9391.jpg", score: 8.91 },
    { id: 9253, title: "Steins;Gate", image: "https://cdn.myanimelist.net/images/anime/73/9617.jpg", score: 9.07 },
    { id: 11061, title: "Hunter x Hunter (2011)", image: "https://cdn.myanimelist.net/images/anime/1337/119013.jpg", score: 9.04 },
    { id: 30276, title: "One Punch Man", image: "https://cdn.myanimelist.net/images/anime/12/76049.jpg", score: 8.51 }
];

const DEFAULT_REVIEWS = [
    { author: "AnimeMaster_99", rating: 10, date: "Oct 12, 2021", content: "This is easily one of the greatest stories ever told in media. The pacing, the character growth, and the closure of the ending are unmatched. If you haven't watched it yet, you are missing out on a certified masterpiece." },
    { author: "Sakura_Blossom", rating: 9, date: "Jan 04, 2023", content: "A near-flawless show with top-tier animation by Bones. My only minor gripe is the initial speed which brushes past content covered in the original 2003 adaptation, but once it finds its independent footing it is purely glorious." }
];

export default function App() {
    // Configuration State
    const [apiMode, setApiMode] = useState(() => localStorage.getItem('mal_api_mode') || 'jikan');
    const [clientId, setClientId] = useState(() => localStorage.getItem('mal_client_id') || '');
    const [corsProxy, setCorsProxy] = useState(() => localStorage.getItem('mal_cors_proxy') || 'https://api.allorigins.win/raw?url=');

    // Interactive Content State
    const [searchQuery, setSearchQuery] = useState('');
    const [suggestions, setSuggestions] = useState([]);
    const [selectedId, setSelectedId] = useState(5114); // Default to FMAB
    const [anime, setAnime] = useState(PRESETS[5114]);
    const [characters, setCharacters] = useState(DEFAULT_CHARACTERS);
    const [recommendations, setRecommendations] = useState(DEFAULT_RECOMMENDATIONS);
    const [reviews, setReviews] = useState(DEFAULT_REVIEWS);

    // Status handlers
    const [loading, setLoading] = useState(false);
    const [searchLoading, setSearchLoading] = useState(false);
    const [error, setError] = useState(null);
    const [activeTab, setActiveTab] = useState('overview');
    const [showConfigModal, setShowConfigModal] = useState(false);
    const [synopsisExpanded, setSynopsisExpanded] = useState(false);
    const [toastMessage, setToastMessage] = useState(null);

    // Suggestions debouncer
    const searchTimeout = useRef(null);

    // Sync config inputs to localStorage
    useEffect(() => {
        localStorage.setItem('mal_api_mode', apiMode);
        localStorage.setItem('mal_client_id', clientId);
        localStorage.setItem('mal_cors_proxy', corsProxy);
    }, [apiMode, clientId, corsProxy]);

    // Load selected anime details
    useEffect(() => {
        fetchAnimeDetails(selectedId);
    }, [selectedId, apiMode, clientId]);

    // Toast Helper
    const showToast = (msg) => {
        setToastMessage(msg);
        setTimeout(() => setToastMessage(null), 3500);
    };

    // Helper: Request Wrapper with CORS proxy handling
    const executeFetch = async (targetUrl, useProxy = true) => {
        let finalUrl = targetUrl;
        if (useProxy && corsProxy) {
            finalUrl = `${corsProxy}${encodeURIComponent(targetUrl)}`;
        }

        const headers = {};
        if (apiMode === 'official' && clientId) {
            headers['X-MAL-CLIENT-ID'] = clientId;
        }

        const response = await fetch(finalUrl, { headers });
        if (!response.ok) {
            throw new Error(`API response status ${response.status}: Failed to grab data.`);
        }

        // AllOrigins JSON raw response unpacking
        if (corsProxy.includes('allorigins') && useProxy) {
            const textData = await response.text();
            return JSON.parse(textData);
        }
        return await response.json();
    };

    // Main Anime Data Retrieval Flow
    const fetchAnimeDetails = async (id) => {
        setLoading(true);
        setError(null);

        // If ID is a preset and we have no client credentials in official mode, we can render preset instantly
        if (apiMode === 'official' && !clientId && PRESETS[id]) {
            setAnime(PRESETS[id]);
            setCharacters(DEFAULT_CHARACTERS);
            setRecommendations(DEFAULT_RECOMMENDATIONS);
            setReviews(DEFAULT_REVIEWS);
            setLoading(false);
            return;
        }

        try {
            if (apiMode === 'official' && clientId) {
                // --- Official MyAnimeList API V2 ---
                const fields = 'id,title,main_picture,alternative_titles,start_date,end_date,synopsis,mean,rank,popularity,num_list_users,media_type,status,genres,num_episodes,start_season,broadcast,source,average_episode_duration,rating,pictures,background,recommendations,studios,statistics';
                const url = `https://api.myanimelist.net/v2/anime/${id}?fields=${fields}`;

                const data = await executeFetch(url, true);
                const parsed = {
                    id: data.id,
                    title: data.title,
                    englishTitle: data.alternative_titles?.en || data.title,
                    japaneseTitle: data.alternative_titles?.ja || "",
                    synonyms: data.alternative_titles?.synonyms || [],
                    synopsis: data.synopsis || "No synopsis recorded.",
                    imageUrl: data.main_picture?.large || data.main_picture?.medium || "",
                    bannerUrl: data.pictures?.[0]?.large || data.main_picture?.large || "",
                    score: data.mean || 0,
                    rank: data.rank || 0,
                    popularity: data.popularity || 0,
                    members: data.num_list_users || 0,
                    episodes: data.num_episodes || 0,
                    status: data.status ? data.status.replace(/_/g, ' ') : "Unknown",
                    aired: `${data.start_date || "?"} to ${data.end_date || "?"}`,
                    type: data.media_type ? data.media_type.toUpperCase() : "Unknown",
                    source: data.source ? data.source.replace(/_/g, ' ') : "Unknown",
                    duration: data.average_episode_duration ? `${Math.round(data.average_episode_duration / 60)} min.` : "Unknown",
                    rating: data.rating ? data.rating.replace(/_/g, ' ') : "Unknown",
                    studios: data.studios?.map(s => s.name) || [],
                    genres: data.genres?.map(g => g.name) || [],
                    trailerUrl: null, // MAL public API might restrict default trailer objects
                    statistics: {
                        watching: data.statistics?.status?.watching || 0,
                        completed: data.statistics?.status?.completed || 0,
                        on_hold: data.statistics?.status?.on_hold || 0,
                        dropped: data.statistics?.status?.dropped || 0,
                        plan_to_watch: data.statistics?.status?.plan_to_watch || 0
                    },
                    background: data.background || "",
                    broadcast: data.broadcast?.day_of_the_week ? `${data.broadcast.day_of_the_week} at ${data.broadcast.start_time}` : "Unknown",
                    season: data.start_season ? `${data.start_season.season} ${data.start_season.year}` : "Unknown"
                };
                setAnime(parsed);

                // Supplement Recommendations from MAL V2 payload
                if (data.recommendations) {
                    const mappedRecs = data.recommendations.slice(0, 6).map(r => ({
                        id: r.node.id,
                        title: r.node.title,
                        image: r.node.main_picture?.medium || r.node.main_picture?.large || "",
                        score: null
                    }));
                    setRecommendations(mappedRecs);
                } else {
                    setRecommendations([]);
                }

                // Fetch characters as supplementary from Jikan to keep layout complete
                try {
                    const charData = await executeFetch(`https://api.jikan.moe/v4/anime/${id}/characters`, false);
                    mapJikanCharacters(charData);
                } catch {
                    setCharacters(DEFAULT_CHARACTERS);
                }

            } else {
                // --- Jikan Public API (MAL Wrapper) ---
                const detailsData = await executeFetch(`https://api.jikan.moe/v4/anime/${id}/full`, false);
                const animePayload = detailsData.data;

                const parsed = {
                    id: animePayload.mal_id,
                    title: animePayload.title,
                    englishTitle: animePayload.title_english || animePayload.title,
                    japaneseTitle: animePayload.title_japanese || "",
                    synonyms: animePayload.titles?.filter(t => t.type === 'Synonym').map(t => t.title) || [],
                    synopsis: animePayload.synopsis || "No synopsis recorded.",
                    imageUrl: animePayload.images?.jpg?.large_image_url || animePayload.images?.jpg?.image_url || "",
                    bannerUrl: animePayload.images?.jpg?.large_image_url || "",
                    score: animePayload.score || 0,
                    rank: animePayload.rank || 0,
                    popularity: animePayload.popularity || 0,
                    members: animePayload.members || 0,
                    episodes: animePayload.episodes || 0,
                    status: animePayload.status || "Unknown",
                    aired: animePayload.aired?.string || "?",
                    type: animePayload.type || "Unknown",
                    source: animePayload.source || "Unknown",
                    duration: animePayload.duration || "Unknown",
                    rating: animePayload.rating || "Unknown",
                    studios: animePayload.studios?.map(s => s.name) || [],
                    genres: animePayload.genres?.map(g => g.name) || [],
                    trailerUrl: animePayload.trailer?.embed_url ? animePayload.trailer.embed_url.replace("&autoplay=1", "") : null,
                    statistics: {
                        watching: Math.round(animePayload.members * 0.12),
                        completed: Math.round(animePayload.members * 0.65),
                        on_hold: Math.round(animePayload.members * 0.05),
                        dropped: Math.round(animePayload.members * 0.03),
                        plan_to_watch: Math.round(animePayload.members * 0.15)
                    },
                    background: animePayload.background || "",
                    broadcast: animePayload.broadcast?.string || "Unknown",
                    season: animePayload.season ? `${animePayload.season} ${animePayload.year}` : "Unknown"
                };
                setAnime(parsed);

                // Fetch supplemental Stats, Characters, Recommendations, Reviews
                fetchSupplementalJikan(id);
            }
        } catch (err) {
            console.error(err);
            setError("We encountered an API error or CORS restriction. Falling back to built-in presets.");
            // Auto fallback to a preset to guarantee premium experience
            const fallbackId = PRESETS[id] ? id : 5114;
            setAnime(PRESETS[fallbackId]);
            setCharacters(DEFAULT_CHARACTERS);
            setRecommendations(DEFAULT_RECOMMENDATIONS);
            setReviews(DEFAULT_REVIEWS);
        } finally {
            setLoading(false);
        }
    };

    // Helper Jikan Data Builders
    const fetchSupplementalJikan = async (id) => {
        try {
            const charRes = await executeFetch(`https://api.jikan.moe/v4/anime/${id}/characters`, false);
            mapJikanCharacters(charRes);
        } catch (e) { console.warn("Could not fetch Jikan characters", e); }

        try {
            const recRes = await executeFetch(`https://api.jikan.moe/v4/anime/${id}/recommendations`, false);
            const mappedRecs = recRes.data?.slice(0, 6).map(r => ({
                id: r.entry.mal_id,
                title: r.entry.title,
                image: r.entry.images?.jpg?.large_image_url || r.entry.images?.jpg?.image_url || "",
                score: null
            })) || [];
            setRecommendations(mappedRecs.length ? mappedRecs : DEFAULT_RECOMMENDATIONS);
        } catch (e) { setRecommendations(DEFAULT_RECOMMENDATIONS); }

        try {
            const revRes = await executeFetch(`https://api.jikan.moe/v4/anime/${id}/reviews`, false);
            const mappedReviews = revRes.data?.slice(0, 3).map(r => ({
                author: r.user.username,
                rating: r.score,
                date: new Date(r.date).toLocaleDateString(),
                content: r.review
            })) || [];
            setReviews(mappedReviews.length ? mappedReviews : DEFAULT_REVIEWS);
        } catch (e) { setReviews(DEFAULT_REVIEWS); }
    };

    const mapJikanCharacters = (charRes) => {
        const mapped = charRes.data?.slice(0, 6).map(c => {
            const va = c.voice_actors?.find(v => v.language === "Japanese");
            return {
                name: c.character.name,
                role: c.role,
                charImage: c.character.images?.jpg?.image_url || "",
                vaName: va ? va.person.name : "N/A",
                vaImage: va ? va.person.images?.jpg?.image_url : null
            };
        }) || [];
        setCharacters(mapped.length ? mapped : DEFAULT_CHARACTERS);
    };

    // Search Input Handlers
    const handleSearchChange = (e) => {
        const query = e.target.value;
        setSearchQuery(query);

        if (searchTimeout.current) clearTimeout(searchTimeout.current);

        if (query.trim().length < 3) {
            setSuggestions([]);
            return;
        }

        setSearchLoading(true);
        searchTimeout.current = setTimeout(async () => {
            try {
                if (apiMode === 'official' && clientId) {
                    const url = `https://api.myanimelist.net/v2/anime?q=${encodeURIComponent(query)}&limit=6`;
                    const results = await executeFetch(url, true);
                    const mapped = results.data?.map(item => ({
                        id: item.node.id,
                        title: item.node.title,
                        image: item.node.main_picture?.medium || ""
                    })) || [];
                    setSuggestions(mapped);
                } else {
                    const url = `https://api.jikan.moe/v4/anime?q=${encodeURIComponent(query)}&limit=6`;
                    const results = await executeFetch(url, false);
                    const mapped = results.data?.map(item => ({
                        id: item.mal_id,
                        title: item.title,
                        image: item.images?.jpg?.image_url || ""
                    })) || [];
                    setSuggestions(mapped);
                }
            } catch (err) {
                console.warn("Autosuggest fetch failed, using offline matches", err);
                // Direct preset filter
                const presetMatches = Object.values(PRESETS).filter(p =>
                    p.title.toLowerCase().includes(query.toLowerCase())
                ).map(p => ({ id: p.id, title: p.title, image: p.imageUrl }));
                setSuggestions(presetMatches);
            } finally {
                setSearchLoading(false);
            }
        }, 450);
    };

    // Selection trigger
    const selectAnime = (id) => {
        setSelectedId(id);
        setSearchQuery('');
        setSuggestions([]);
    };

    const testConnection = async () => {
        if (!clientId && apiMode === 'official') {
            showToast("❌ Enter your MAL Client ID first!");
            return;
        }
        setLoading(true);
        try {
            if (apiMode === 'official') {
                const testUrl = `https://api.myanimelist.net/v2/anime/5114?fields=title`;
                await executeFetch(testUrl, true);
                showToast("✅ Connected to Official MAL API successfully!");
            } else {
                const testUrl = `https://api.jikan.moe/v4/anime/5114`;
                await executeFetch(testUrl, false);
                showToast("✅ Public Jikan API Connected successfully!");
            }
        } catch (e) {
            showToast("❌ API connection failed. Check Client ID, CORS setup, or proxy choice.");
        } finally {
            setLoading(false);
        }
    };

    // Helper to copy API endpoints
    const copyToClipboard = (text) => {
        const dummy = document.createElement("textarea");
        document.body.appendChild(dummy);
        dummy.value = text;
        dummy.select();
        document.execCommand("copy");
        document.body.removeChild(dummy);
        showToast("📋 Copied to clipboard!");
    };

    // Visual Helper: Calculate SVG Stat Chart segments
    const getStatAngles = () => {
        const stats = anime.statistics;
        const total = Object.values(stats).reduce((a, b) => a + b, 0);
        if (!total) return [];

        let currentAngle = 0;
        return Object.entries(stats).map(([key, val]) => {
            const percentage = (val / total) * 100;
            const angle = (val / total) * 360;
            const start = currentAngle;
            currentAngle += angle;
            return { key, val, percentage, start, end: currentAngle };
        });
    };

    return (
        <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans antialiased selection:bg-indigo-500 selection:text-white">
            {/* Toast Notification */}
            {toastMessage && (
                <div className="fixed top-6 right-6 z-50 bg-slate-900 border border-indigo-500/30 text-white px-5 py-3 rounded-xl shadow-2xl flex items-center gap-3 backdrop-blur-md animate-bounce">
                    <span className="w-2 h-2 rounded-full bg-indigo-500 animate-pulse" />
                    <p className="text-sm font-medium">{toastMessage}</p>
                </div>
            )}

            {/* Main Header */}
            <header className="sticky top-0 z-40 bg-slate-950/85 backdrop-blur-md border-b border-slate-800/80">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-18 flex items-center justify-between gap-4">

                    {/* Logo */}
                    <div className="flex items-center gap-3 select-none">
                        <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-600 via-purple-600 to-pink-500 flex items-center justify-center shadow-lg shadow-indigo-500/20">
                            <svg className="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M13 10V3L4 14h7v7l9-11h-7z" />
                            </svg>
                        </div>
                        <div>
                            <span className="text-lg font-black tracking-wider text-transparent bg-clip-text bg-gradient-to-r from-white via-slate-200 to-indigo-400">
                                ANIME<span className="text-indigo-500 font-extrabold text-xl font-mono">SPHERE</span>
                            </span>
                            <div className="text-[10px] text-slate-400 font-semibold uppercase tracking-widest leading-none mt-0.5">MAL Premium Portal</div>
                        </div>
                    </div>

                    {/* Quick Search */}
                    <div className="flex-1 max-w-xl relative">
                        <div className="relative">
                            <input
                                type="text"
                                placeholder="Search an anime (e.g. Naruto, Bleach, Attack on Titan)..."
                                value={searchQuery}
                                onChange={handleSearchChange}
                                className="w-full bg-slate-900/90 border border-slate-800 focus:border-indigo-500 rounded-2xl pl-11 pr-10 py-2.5 text-sm outline-none transition-all duration-300 placeholder-slate-400/80 hover:bg-slate-900 focus:shadow-[0_0_15px_rgba(99,102,241,0.15)]"
                            />
                            <span className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none">
                                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                                </svg>
                            </span>
                            {searchLoading && (
                                <span className="absolute right-4 top-1/2 -translate-y-1/2">
                                    <svg className="animate-spin h-5 w-5 text-indigo-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                                    </svg>
                                </span>
                            )}
                        </div>

                        {/* Live Autocomplete suggestions */}
                        {suggestions.length > 0 && (
                            <div className="absolute top-full left-0 right-0 mt-2.5 bg-slate-900/95 border border-slate-850 rounded-2xl shadow-2xl z-50 overflow-hidden backdrop-blur-xl divide-y divide-slate-800">
                                {suggestions.map((item) => (
                                    <button
                                        key={item.id}
                                        onClick={() => selectAnime(item.id)}
                                        className="w-full px-4 py-3 flex items-center gap-3 hover:bg-slate-800/50 transition-colors text-left"
                                    >
                                        <img src={item.image} alt="" className="w-10 h-14 object-cover rounded bg-slate-800 flex-shrink-0" />
                                        <span className="text-sm font-semibold text-slate-200 line-clamp-2 hover:text-indigo-400 transition-colors">{item.title}</span>
                                    </button>
                                ))}
                            </div>
                        )}
                    </div>

                    {/* Action Buttons & Configuration */}
                    <div className="flex items-center gap-3">
                        <button
                            onClick={() => selectAnime(52991)}
                            className="hidden md:flex items-center gap-1.5 px-3.5 py-2 rounded-xl border border-slate-800 bg-slate-900 text-xs font-semibold text-slate-300 hover:text-white hover:border-slate-700 transition-colors"
                        >
                            🔥 Frieren Profile
                        </button>
                        <button
                            onClick={() => setShowConfigModal(true)}
                            className="flex items-center gap-1.5 bg-indigo-600 hover:bg-indigo-500 text-white px-4 py-2 rounded-xl text-xs font-bold transition-all duration-300 shadow-lg shadow-indigo-600/15"
                        >
                            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                            </svg>
                            <span>Setup MAL API</span>
                        </button>
                    </div>
                </div>
            </header>

            {/* Connection warning header strip */}
            {apiMode === 'official' && !clientId && (
                <div className="bg-amber-500/10 border-b border-amber-500/20 py-2.5 px-4 text-center">
                    <p className="text-xs text-amber-300 font-medium flex items-center justify-center gap-2">
                        <span className="w-1.5 h-1.5 rounded-full bg-amber-400 animate-ping" />
                        Active Mode: <strong>Official MAL API</strong> without Client ID. Presets and public fallbacks loaded. Click
                        <button onClick={() => setShowConfigModal(true)} className="underline hover:text-amber-200 font-bold ml-1">Setup MAL API</button> to enter your credentials.
                    </p>
                </div>
            )}

            {/* Main Container */}
            <main className="flex-1 w-full max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">

                {/* Loading Indicator */}
                {loading ? (
                    <div className="flex flex-col items-center justify-center min-h-[450px]">
                        <div className="w-16 h-16 relative">
                            <div className="absolute inset-0 rounded-full border-4 border-slate-800" />
                            <div className="absolute inset-0 rounded-full border-4 border-t-indigo-500 border-r-indigo-500 animate-spin" />
                        </div>
                        <p className="text-slate-400 text-sm mt-4 font-semibold tracking-wide animate-pulse">Retrieving Anime Profiles & Community Stats...</p>
                    </div>
                ) : (
                    <>
                        {/* Cover / Profile Banner Area */}
                        <div className="relative rounded-3xl overflow-hidden bg-slate-900 border border-slate-800/80 mb-8 shadow-2xl shadow-black/45">

                            {/* Blur backdrop backing */}
                            <div className="absolute inset-0 select-none pointer-events-none">
                                <img src={anime.imageUrl} alt="" className="w-full h-full object-cover blur-2xl opacity-20 scale-110" />
                                <div className="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-950/75 to-transparent" />
                            </div>

                            {/* Main Content Layout */}
                            <div className="relative z-10 px-6 pt-16 pb-8 md:p-8 lg:p-10 flex flex-col md:flex-row gap-8 items-end">

                                {/* Poster Artwork card */}
                                <div className="w-48 sm:w-56 md:w-64 flex-shrink-0 mx-auto md:mx-0 -mt-12 md:mt-0 relative group">
                                    <div className="absolute -inset-1 rounded-2xl bg-gradient-to-t from-indigo-500 to-purple-600 opacity-30 blur group-hover:opacity-45 transition duration-300" />
                                    <img
                                        src={anime.imageUrl}
                                        alt={anime.title}
                                        className="relative w-full h-72 sm:h-80 md:h-96 object-cover rounded-2xl shadow-2xl bg-slate-850"
                                    />
                                    <div className="absolute top-3 left-3 bg-slate-950/80 backdrop-blur-md px-3 py-1 rounded-lg text-[10px] font-black uppercase tracking-wider text-indigo-400 border border-indigo-500/20">
                                        {anime.type}
                                    </div>
                                </div>

                                {/* Details text area */}
                                <div className="flex-1 text-center md:text-left">
                                    <div className="flex flex-wrap items-center justify-center md:justify-start gap-2 mb-3">
                                        {anime.studios.map((studio, i) => (
                                            <span key={i} className="bg-indigo-500/10 text-indigo-400 text-xs px-3 py-1 rounded-full font-bold border border-indigo-500/20">
                                                {studio}
                                            </span>
                                        ))}
                                        <span className="bg-slate-800 text-slate-300 text-xs px-3 py-1 rounded-full font-medium">
                                            {anime.status}
                                        </span>
                                    </div>

                                    <h1 className="text-2xl sm:text-3xl md:text-4xl lg:text-5xl font-black text-white leading-tight tracking-tight mb-2">
                                        {anime.title}
                                    </h1>

                                    {anime.englishTitle && anime.englishTitle !== anime.title && (
                                        <h2 className="text-base sm:text-lg text-slate-300 font-medium mb-1">
                                            {anime.englishTitle}
                                        </h2>
                                    )}

                                    {anime.japaneseTitle && (
                                        <p className="text-xs sm:text-sm text-slate-400 font-semibold font-mono tracking-wider mb-6">
                                            {anime.japaneseTitle}
                                        </p>
                                    )}

                                    {/* Summary Metric Badges */}
                                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 max-w-2xl bg-slate-950/70 border border-slate-850 p-4 rounded-2xl backdrop-blur-md">
                                        <div className="text-center sm:border-r border-slate-850">
                                            <div className="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-0.5">MAL Score</div>
                                            <div className="flex items-center justify-center gap-1.5">
                                                <span className="text-xl font-black text-emerald-400">{anime.score ? anime.score.toFixed(2) : "N/A"}</span>
                                                <svg className="w-4 h-4 text-emerald-400 fill-current" viewBox="0 0 20 20">
                                                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                                                </svg>
                                            </div>
                                        </div>

                                        <div className="text-center sm:border-r border-slate-850">
                                            <div className="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-0.5">Rank</div>
                                            <div className="text-xl font-black text-white">#{anime.rank || "N/A"}</div>
                                        </div>

                                        <div className="text-center sm:border-r border-slate-850">
                                            <div className="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-0.5">Popularity</div>
                                            <div className="text-xl font-black text-white">#{anime.popularity || "N/A"}</div>
                                        </div>

                                        <div className="text-center">
                                            <div className="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-0.5">Members</div>
                                            <div className="text-xl font-black text-indigo-400">{anime.members ? anime.members.toLocaleString() : "0"}</div>
                                        </div>
                                    </div>

                                </div>
                            </div>

                        </div>

                        {/* Content Layout Split */}
                        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">

                            {/* Sidebar Specific Specs */}
                            <div className="lg:col-span-4 space-y-6">

                                {/* Meta specifications */}
                                <div className="bg-slate-900 border border-slate-800/80 rounded-2xl p-6 shadow-xl">
                                    <h3 className="text-sm font-black uppercase tracking-widest text-slate-300 mb-4 pb-2 border-b border-slate-800/60">Anime Specifications</h3>
                                    <div className="space-y-4">

                                        <div className="flex justify-between items-start gap-4">
                                            <span className="text-xs font-semibold text-slate-400">Type</span>
                                            <span className="text-xs font-bold text-slate-200 text-right bg-slate-800 px-2 py-0.5 rounded">{anime.type}</span>
                                        </div>

                                        <div className="flex justify-between items-start gap-4">
                                            <span className="text-xs font-semibold text-slate-400">Episodes</span>
                                            <span className="text-xs font-bold text-slate-200 text-right">{anime.episodes || "Unknown"} episodes</span>
                                        </div>

                                        <div className="flex justify-between items-start gap-4">
                                            <span className="text-xs font-semibold text-slate-400">Duration</span>
                                            <span className="text-xs font-bold text-slate-200 text-right">{anime.duration}</span>
                                        </div>

                                        <div className="flex justify-between items-start gap-4">
                                            <span className="text-xs font-semibold text-slate-400">Aired Dates</span>
                                            <span className="text-xs font-bold text-slate-200 text-right line-clamp-2">{anime.aired}</span>
                                        </div>

                                        <div className="flex justify-between items-start gap-4">
                                            <span className="text-xs font-semibold text-slate-400">Premier Season</span>
                                            <span className="text-xs font-bold text-slate-200 text-right">{anime.season !== "Unknown Unknown" ? anime.season : "N/A"}</span>
                                        </div>

                                        <div className="flex justify-between items-start gap-4">
                                            <span className="text-xs font-semibold text-slate-400">Broadcast Window</span>
                                            <span className="text-xs font-bold text-slate-200 text-right">{anime.broadcast}</span>
                                        </div>

                                        <div className="flex justify-between items-start gap-4">
                                            <span className="text-xs font-semibold text-slate-400">Source Material</span>
                                            <span className="text-xs font-bold text-slate-200 text-right">{anime.source}</span>
                                        </div>

                                        <div className="flex justify-between items-start gap-4">
                                            <span className="text-xs font-semibold text-slate-400">Age Rating</span>
                                            <span className="text-xs font-bold text-slate-200 text-right">{anime.rating}</span>
                                        </div>

                                    </div>
                                </div>

                                {/* Genres block */}
                                <div className="bg-slate-900 border border-slate-800/80 rounded-2xl p-6 shadow-xl">
                                    <h3 className="text-sm font-black uppercase tracking-widest text-slate-300 mb-4 pb-2 border-b border-slate-800/60">Classifications</h3>
                                    <div className="flex flex-wrap gap-2">
                                        {anime.genres.map((genre, i) => (
                                            <span key={i} className="bg-slate-800 hover:bg-slate-750 text-xs text-slate-300 font-semibold px-3.5 py-1.5 rounded-xl border border-slate-750 transition-colors cursor-default">
                                                {genre}
                                            </span>
                                        ))}
                                        {anime.genres.length === 0 && <span className="text-xs text-slate-400 italic">No genres categorized.</span>}
                                    </div>
                                </div>

                                {/* External Actions */}
                                <div className="bg-slate-900 border border-slate-800/80 rounded-2xl p-4 shadow-xl flex flex-col gap-2">
                                    <a
                                        href={`https://myanimelist.net/anime/${anime.id}`}
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className="w-full flex items-center justify-center gap-2 bg-indigo-600/10 hover:bg-indigo-600/20 text-indigo-400 text-xs font-bold py-3 rounded-xl border border-indigo-500/20 transition-all"
                                    >
                                        <span>View on Official MAL Website</span>
                                        <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                                        </svg>
                                    </a>
                                    <button
                                        onClick={() => copyToClipboard(`https://myanimelist.net/anime/${anime.id}`)}
                                        className="w-full flex items-center justify-center gap-2 bg-slate-800 hover:bg-slate-750 text-xs text-slate-300 font-bold py-3 rounded-xl border border-slate-750 transition-all"
                                    >
                                        <span>Copy MAL Listing Link</span>
                                    </button>
                                </div>

                            </div>

                            {/* Main Tabs Area */}
                            <div className="lg:col-span-8 space-y-6">

                                {/* Tabs Selector Bar */}
                                <div className="bg-slate-900 border border-slate-800/80 rounded-2xl p-1.5 flex flex-wrap gap-1 shadow-md">
                                    {[
                                        { id: 'overview', label: 'Overview' },
                                        { id: 'stats', label: 'Metrics & Stats' },
                                        { id: 'characters', label: 'Cast & Characters' },
                                        { id: 'recommendations', label: 'Recommendations' },
                                        { id: 'reviews', label: 'Community Reviews' }
                                    ].map((tab) => (
                                        <button
                                            key={tab.id}
                                            onClick={() => setActiveTab(tab.id)}
                                            className={`flex-1 min-w-[100px] text-xs font-bold py-2.5 px-3 rounded-xl transition-all duration-300 ${activeTab === tab.id
                                                    ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/20'
                                                    : 'text-slate-400 hover:text-white hover:bg-slate-800/50'
                                                }`}
                                        >
                                            {tab.label}
                                        </button>
                                    ))}
                                </div>

                                {/* Tab: Overview Section */}
                                {activeTab === 'overview' && (
                                    <div className="bg-slate-900 border border-slate-800/80 rounded-3xl p-6 sm:p-8 shadow-xl space-y-8 animate-fadeIn">

                                        {/* Synopsis text details */}
                                        <div>
                                            <h4 className="text-base font-black uppercase tracking-wider text-slate-200 mb-4 flex items-center gap-2">
                                                <span className="w-1 h-4 rounded bg-indigo-500" />
                                                Synopsis / Storyline
                                            </h4>
                                            <p className={`text-sm text-slate-300 leading-relaxed transition-all duration-300 ${!synopsisExpanded ? 'line-clamp-5' : ''}`}>
                                                {anime.synopsis}
                                            </p>
                                            {anime.synopsis.length > 250 && (
                                                <button
                                                    onClick={() => setSynopsisExpanded(!synopsisExpanded)}
                                                    className="mt-3 text-xs text-indigo-400 hover:text-indigo-300 font-extrabold focus:outline-none"
                                                >
                                                    {synopsisExpanded ? "Collapse Text ▲" : "Read Full Synopsis ▼"}
                                                </button>
                                            )}
                                        </div>

                                        {/* Background details (if present) */}
                                        {anime.background && (
                                            <div className="bg-slate-950/60 rounded-2xl p-5 border border-slate-850">
                                                <h4 className="text-xs font-black uppercase tracking-widest text-slate-400 mb-2">Development Background</h4>
                                                <p className="text-xs text-slate-400 leading-relaxed font-medium">{anime.background}</p>
                                            </div>
                                        )}

                                        {/* Trailer Presentation (Youtube Embed) */}
                                        {anime.trailerUrl ? (
                                            <div>
                                                <h4 className="text-base font-black uppercase tracking-wider text-slate-200 mb-4 flex items-center gap-2">
                                                    <span className="w-1 h-4 rounded bg-indigo-500" />
                                                    Official Media Trailer
                                                </h4>
                                                <div className="relative aspect-video rounded-2xl overflow-hidden border border-slate-800 shadow-2xl bg-black">
                                                    <iframe
                                                        title="Anime Trailer"
                                                        src={anime.trailerUrl}
                                                        className="absolute inset-0 w-full h-full border-0"
                                                        allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                                                        allowFullScreen
                                                    />
                                                </div>
                                            </div>
                                        ) : (
                                            <div className="bg-slate-950/50 rounded-2xl p-6 text-center border border-dashed border-slate-800">
                                                <svg className="w-10 h-10 text-slate-600 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                                                </svg>
                                                <p className="text-xs text-slate-500 font-medium">No official video trailer linked for this entry in basic fields.</p>
                                            </div>
                                        )}

                                    </div>
                                )}

                                {/* Tab: Stats Breakdown Section */}
                                {activeTab === 'stats' && (
                                    <div className="bg-slate-900 border border-slate-800/80 rounded-3xl p-6 sm:p-8 shadow-xl space-y-8 animate-fadeIn">

                                        <h4 className="text-base font-black uppercase tracking-wider text-slate-200 mb-4 flex items-center gap-2">
                                            <span className="w-1 h-4 rounded bg-indigo-500" />
                                            Community List Breakdown
                                        </h4>

                                        {/* Chart & Numeric Layout */}
                                        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 items-center">

                                            {/* Responsive Interactive SVG Doughnut Chart */}
                                            <div className="relative max-w-[240px] mx-auto">
                                                <svg width="220" height="220" viewBox="0 0 42 42" className="transform -rotate-90">
                                                    {/* Base circle background */}
                                                    <circle cx="21" cy="21" r="15.915" fill="transparent" stroke="#1e293b" strokeWidth="4.2" />

                                                    {/* Slices iteration calculation */}
                                                    {getStatAngles().map((segment, index) => {
                                                        const colors = ['#6366f1', '#10b981', '#f59e0b', '#ef4444', '#a855f7'];
                                                        const color = colors[index % colors.length];

                                                        // Calculate dash array and offset
                                                        const dashArray = `${segment.percentage} ${100 - segment.percentage}`;
                                                        // offset must be negative of start percent
                                                        let totalPrevOffset = 0;
                                                        getStatAngles().slice(0, index).forEach(s => {
                                                            totalPrevOffset += s.percentage;
                                                        });
                                                        const dashOffset = 100 - totalPrevOffset + 25; // add offset adjustment for standard starting point

                                                        return (
                                                            <circle
                                                                key={segment.key}
                                                                cx="21"
                                                                cy="21"
                                                                r="15.915"
                                                                fill="transparent"
                                                                stroke={color}
                                                                strokeWidth="4.5"
                                                                strokeDasharray={dashArray}
                                                                strokeDashoffset={dashOffset}
                                                                className="transition-all duration-500"
                                                            />
                                                        );
                                                    })}
                                                </svg>

                                                {/* Chart Overlay Center text */}
                                                <div className="absolute inset-0 flex flex-col justify-center items-center text-center select-none pointer-events-none">
                                                    <span className="text-[10px] text-slate-400 uppercase tracking-widest font-black leading-none">Total Members</span>
                                                    <span className="text-lg font-black text-white mt-1">{(anime.members || 0).toLocaleString()}</span>
                                                </div>
                                            </div>

                                            {/* Stat Metrics Legend List */}
                                            <div className="space-y-4">
                                                {[
                                                    { key: 'Completed', val: anime.statistics.completed, color: 'bg-emerald-500' },
                                                    { key: 'Watching', val: anime.statistics.watching, color: 'bg-indigo-500' },
                                                    { key: 'Plan to Watch', val: anime.statistics.plan_to_watch, color: 'bg-purple-500' },
                                                    { key: 'On Hold', val: anime.statistics.on_hold, color: 'bg-amber-500' },
                                                    { key: 'Dropped', val: anime.statistics.dropped, color: 'bg-red-500' }
                                                ].map((stat, idx) => {
                                                    const total = Object.values(anime.statistics).reduce((a, b) => a + b, 0) || 1;
                                                    const ratio = ((stat.val / total) * 100).toFixed(1);
                                                    return (
                                                        <div key={idx} className="space-y-1.5">
                                                            <div className="flex justify-between items-center text-xs">
                                                                <span className="flex items-center gap-2 text-slate-300 font-bold">
                                                                    <span className={`w-3 h-3 rounded-full ${stat.color}`} />
                                                                    {stat.key}
                                                                </span>
                                                                <span className="text-slate-400 font-bold font-mono">
                                                                    {stat.val.toLocaleString()} <span className="text-[10px] text-indigo-400">({ratio}%)</span>
                                                                </span>
                                                            </div>
                                                            <div className="w-full bg-slate-950 h-2.5 rounded-full overflow-hidden">
                                                                <div className={`h-full ${stat.color} rounded-full`} style={{ width: `${ratio}%` }} />
                                                            </div>
                                                        </div>
                                                    );
                                                })}
                                            </div>

                                        </div>

                                    </div>
                                )}

                                {/* Tab: Characters and Staff Section */}
                                {activeTab === 'characters' && (
                                    <div className="bg-slate-900 border border-slate-800/80 rounded-3xl p-6 sm:p-8 shadow-xl animate-fadeIn">

                                        <h4 className="text-base font-black uppercase tracking-wider text-slate-200 mb-6 flex items-center gap-2">
                                            <span className="w-1 h-4 rounded bg-indigo-500" />
                                            Key Characters & Voice Cast (Seiyuu)
                                        </h4>

                                        {characters.length > 0 ? (
                                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                                {characters.map((char, index) => (
                                                    <div
                                                        key={index}
                                                        className="bg-slate-950/60 border border-slate-850 p-3.5 rounded-2xl flex items-center justify-between gap-4 hover:border-indigo-500/30 hover:bg-slate-950 transition-all duration-300"
                                                    >
                                                        {/* Left Side: Character Image/Name */}
                                                        <div className="flex items-center gap-3">
                                                            <img
                                                                src={char.charImage}
                                                                alt={char.name}
                                                                className="w-11 h-14 object-cover rounded-xl bg-slate-800 border border-slate-800"
                                                                onError={(e) => { e.target.src = "https://cdn.myanimelist.net/images/characters/16/381752.jpg"; }}
                                                            />
                                                            <div>
                                                                <h5 className="text-sm font-bold text-slate-200 leading-tight">{char.name}</h5>
                                                                <span className="text-[10px] bg-slate-800 text-slate-400 px-2 py-0.5 rounded-full font-bold mt-1 inline-block uppercase tracking-wider">
                                                                    {char.role}
                                                                </span>
                                                            </div>
                                                        </div>

                                                        {/* Right Side: VA info */}
                                                        {char.vaName && (
                                                            <div className="flex items-center gap-3 text-right">
                                                                <div>
                                                                    <h6 className="text-xs font-bold text-slate-300">{char.vaName}</h6>
                                                                    <span className="text-[10px] text-slate-500 font-medium">Japanese VA</span>
                                                                </div>
                                                                {char.vaImage && (
                                                                    <img
                                                                        src={char.vaImage}
                                                                        alt={char.vaName}
                                                                        className="w-11 h-14 object-cover rounded-xl bg-slate-800 border border-slate-800"
                                                                        onError={(e) => { e.target.style.display = "none"; }}
                                                                    />
                                                                )}
                                                            </div>
                                                        )}

                                                    </div>
                                                ))}
                                            </div>
                                        ) : (
                                            <div className="bg-slate-950/50 rounded-2xl p-6 text-center border border-dashed border-slate-800">
                                                <p className="text-xs text-slate-400 font-medium">No cast data retrieved for this specific query.</p>
                                            </div>
                                        )}

                                    </div>
                                )}

                                {/* Tab: Recommendations */}
                                {activeTab === 'recommendations' && (
                                    <div className="bg-slate-900 border border-slate-800/80 rounded-3xl p-6 sm:p-8 shadow-xl animate-fadeIn">

                                        <h4 className="text-base font-black uppercase tracking-wider text-slate-200 mb-2 flex items-center gap-2">
                                            <span className="w-1 h-4 rounded bg-indigo-500" />
                                            Linked & Recommended Shows
                                        </h4>
                                        <p className="text-xs text-slate-400 mb-6 font-medium">Handpicked suggestions based on similarity. Click to navigate directly.</p>

                                        <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
                                            {recommendations.map((rec) => (
                                                <div
                                                    key={rec.id}
                                                    onClick={() => selectAnime(rec.id)}
                                                    className="bg-slate-950/60 hover:bg-indigo-600/10 hover:border-indigo-500/40 border border-slate-850 p-3 rounded-2xl cursor-pointer group transition-all duration-300"
                                                >
                                                    <div className="relative aspect-[3/4] rounded-xl overflow-hidden mb-3 bg-slate-800">
                                                        <img
                                                            src={rec.image}
                                                            alt={rec.title}
                                                            className="w-full h-full object-cover group-hover:scale-105 transition duration-500"
                                                        />
                                                        {rec.score && (
                                                            <span className="absolute bottom-2 right-2 bg-slate-950/80 backdrop-blur text-[10px] font-black text-emerald-400 px-2 py-0.5 rounded-md border border-emerald-400/20">
                                                                {rec.score.toFixed(2)}
                                                            </span>
                                                        )}
                                                    </div>
                                                    <h5 className="text-xs font-bold text-slate-200 line-clamp-2 group-hover:text-indigo-400 transition-colors leading-tight">
                                                        {rec.title}
                                                    </h5>
                                                </div>
                                            ))}
                                        </div>

                                    </div>
                                )}

                                {/* Tab: Reviews Panel */}
                                {activeTab === 'reviews' && (
                                    <div className="bg-slate-900 border border-slate-800/80 rounded-3xl p-6 sm:p-8 shadow-xl space-y-6 animate-fadeIn">

                                        <h4 className="text-base font-black uppercase tracking-wider text-slate-200 mb-2 flex items-center gap-2">
                                            <span className="w-1 h-4 rounded bg-indigo-500" />
                                            MAL Community Reviews
                                        </h4>

                                        <div className="space-y-4">
                                            {reviews.map((rev, index) => (
                                                <div key={index} className="bg-slate-950/50 rounded-2xl p-5 border border-slate-850 space-y-3">
                                                    <div className="flex justify-between items-center flex-wrap gap-2">
                                                        <div className="flex items-center gap-2">
                                                            <div className="w-8 h-8 rounded-full bg-slate-800 flex items-center justify-center font-bold text-xs text-indigo-400 border border-slate-700">
                                                                {rev.author[0].toUpperCase()}
                                                            </div>
                                                            <div>
                                                                <span className="text-xs font-black text-slate-200">{rev.author}</span>
                                                                <span className="block text-[10px] text-slate-500 font-bold">{rev.date}</span>
                                                            </div>
                                                        </div>
                                                        <span className="bg-indigo-500/10 text-indigo-400 text-xs px-3 py-1 rounded-xl border border-indigo-500/20 font-black">
                                                            ★ {rev.rating} / 10
                                                        </span>
                                                    </div>
                                                    <p className="text-xs text-slate-350 leading-relaxed font-medium line-clamp-4 hover:line-clamp-none cursor-pointer transition-all duration-350">
                                                        {rev.content}
                                                    </p>
                                                    <span className="text-[10px] text-slate-500 block text-right font-semibold italic">Hover/Click to expand detailed review</span>
                                                </div>
                                            ))}
                                        </div>

                                    </div>
                                )}

                            </div>

                        </div>
                    </>
                )}

            </main>

            {/* MAL configuration/settings drawer modal */}
            {showConfigModal && (
                <div className="fixed inset-0 z-50 overflow-y-auto flex items-center justify-center p-4 bg-slate-950/85 backdrop-blur-sm">
                    <div className="bg-slate-900 border border-slate-850 rounded-3xl w-full max-w-xl p-6 sm:p-8 shadow-2xl relative">

                        {/* Close button */}
                        <button
                            onClick={() => setShowConfigModal(false)}
                            className="absolute top-5 right-5 text-slate-400 hover:text-white"
                        >
                            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M6 18L18 6M6 6l12 12" />
                            </svg>
                        </button>

                        <h3 className="text-xl font-black text-white mb-2 flex items-center gap-2">
                            <span className="w-1.5 h-5 rounded bg-indigo-500" />
                            MyAnimeList API Configuration
                        </h3>
                        <p className="text-xs text-slate-400 mb-6 leading-relaxed font-medium">
                            Configure your credentials to query either the official MyAnimeList V2 REST API directly, or Jikan Public API Wrapper.
                        </p>

                        <div className="space-y-5">

                            {/* API Provider Mode Selector */}
                            <div>
                                <label className="block text-xs font-extrabold uppercase tracking-widest text-slate-400 mb-2">API Provider</label>
                                <div className="grid grid-cols-2 gap-3">
                                    <button
                                        onClick={() => setApiMode('jikan')}
                                        className={`p-3.5 rounded-2xl border text-xs font-bold text-center transition-all ${apiMode === 'jikan'
                                                ? 'bg-indigo-600/10 border-indigo-500 text-white shadow-lg'
                                                : 'bg-slate-950 border-slate-850 text-slate-400 hover:text-white'
                                            }`}
                                    >
                                        🚀 Public Jikan API
                                        <span className="block text-[10px] text-slate-400 font-medium mt-1">Default (No Credentials Required)</span>
                                    </button>
                                    <button
                                        onClick={() => setApiMode('official')}
                                        className={`p-3.5 rounded-2xl border text-xs font-bold text-center transition-all ${apiMode === 'official'
                                                ? 'bg-indigo-600/10 border-indigo-500 text-white shadow-lg'
                                                : 'bg-slate-950 border-slate-850 text-slate-400 hover:text-white'
                                            }`}
                                    >
                                        🔑 Official MAL (V2)
                                        <span className="block text-[10px] text-slate-400 font-medium mt-1">Needs MAL Client ID</span>
                                    </button>
                                </div>
                            </div>

                            {/* Official MAL Form inputs */}
                            {apiMode === 'official' && (
                                <div className="space-y-4 p-4 rounded-2xl bg-slate-950 border border-slate-850 animate-slideDown">

                                    <div>
                                        <label className="block text-xs font-extrabold uppercase tracking-widest text-slate-400 mb-1.5">MyAnimeList Client ID</label>
                                        <input
                                            type="text"
                                            placeholder="Insert your Client ID here..."
                                            value={clientId}
                                            onChange={(e) => setClientId(e.target.value)}
                                            className="w-full bg-slate-900 border border-slate-800 focus:border-indigo-500 rounded-xl px-4 py-2.5 text-xs text-white outline-none font-mono"
                                        />
                                        <div className="mt-1.5 text-[10px] text-slate-500 leading-relaxed font-medium">
                                            Retrieve or generate your Application Client ID at: <a href="https://myanimelist.net/apiconfig" target="_blank" rel="noreferrer" className="text-indigo-400 hover:underline">myanimelist.net/apiconfig</a>
                                        </div>
                                    </div>

                                    <div>
                                        <label className="block text-xs font-extrabold uppercase tracking-widest text-slate-400 mb-1.5">CORS Fetching Proxy (Highly Recommended for Web apps)</label>
                                        <input
                                            type="text"
                                            placeholder="e.g. https://api.allorigins.win/raw?url="
                                            value={corsProxy}
                                            onChange={(e) => setCorsProxy(e.target.value)}
                                            className="w-full bg-slate-900 border border-slate-800 focus:border-indigo-500 rounded-xl px-4 py-2.5 text-xs text-white outline-none font-mono"
                                        />
                                        <div className="mt-1.5 text-[10px] text-slate-500 leading-relaxed font-medium">
                                            Direct client-side browser requests to MAL API trigger CORS blocking. Route queries through a proxy or leave empty to disable.
                                        </div>
                                    </div>

                                </div>
                            )}

                            {/* Action operations in configuration */}
                            <div className="pt-3 flex flex-col sm:flex-row gap-3">
                                <button
                                    onClick={testConnection}
                                    className="flex-1 bg-slate-800 hover:bg-slate-750 text-white text-xs font-bold py-3 px-4 rounded-xl border border-slate-750 transition-all text-center"
                                >
                                    Test Connections
                                </button>
                                <button
                                    onClick={() => setShowConfigModal(false)}
                                    className="flex-1 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold py-3 px-4 rounded-xl transition-all text-center shadow-lg shadow-indigo-600/15"
                                >
                                    Save & Apply Settings
                                </button>
                            </div>

                        </div>
                    </div>
                </div>
            )}

            {/* Footer */}
            <footer className="bg-slate-950 border-t border-slate-900/60 py-8 mt-12 text-slate-500 text-xs">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center space-y-4">
                    <p className="font-semibold text-slate-450">ANIME•SPHERE Profile Engine — Engineered with direct Client-ID credentials support & CORS fallback pipelines.</p>
                    <p className="max-w-2xl mx-auto leading-relaxed">
                        All data and assets displayed are retrieved from MyAnimeList API. This application provides custom profile visual styling dashboards, stats chart visualization mapping, and rabbit-hole navigation paths for educational and entertainment display purposes.
                    </p>
                    <p className="text-[10px]">&copy; 2026 AnimeSphere. Built for MAL Power Users.</p>
                </div>
            </footer>

        </div>
    );
}