const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '../Website/index.jsx');
let content = fs.readFileSync(filePath, 'utf8');

// 1. Declare state for feedback modal and scrollToSection helper
const stateDeclarationTarget = `    // User watchlist state (initialized with 5 popular items from static database)
    const [watchlist, setWatchlist] = useState([`;

const stateDeclarationReplacement = `    const [showFeedbackModal, setShowFeedbackModal] = useState(false);

    const scrollToSection = (id) => {
        const element = document.getElementById(id);
        if (element) {
            element.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    };

    // User watchlist state (initialized with 5 popular items from static database)
    const [watchlist, setWatchlist] = useState([`;

if (content.includes(stateDeclarationTarget)) {
    content = content.replace(stateDeclarationTarget, stateDeclarationReplacement);
} else {
    console.error("Target stateDeclarationTarget not found!");
}

// 2. Translations Updates (English)
const enTelemetryTarget = `        telemetryStats: "Telemetry Stats",`;
const enTelemetryReplacement = `        telemetryStats: "Schedule",`;
content = content.replace(enTelemetryTarget, enTelemetryReplacement);

const enFooterTarget = `        footerText: "© 2026 MA Tracker App. All rights reserved. Powered by the offline static database of 300 MyAnimeList shows.",`;
const enFooterReplacement = `        footerText: "© 2026 MA App. All rights reserved.",`;
content = content.replace(enFooterTarget, enFooterReplacement);

// Translations Updates (Arabic)
const arTelemetryTarget = `        telemetryStats: "إحصائيات القياس",`;
const arTelemetryReplacement = `        telemetryStats: "الجدول",`;
content = content.replace(arTelemetryTarget, arTelemetryReplacement);

const arFooterTarget = `        footerText: "© 2026 تطبيق تعقب أنمياتي. جميع الحقوق محفوظة. مدعوم بقاعدة بيانات غير متصلة لـ 300 أنمي من MyAnimeList.",`;
const arFooterReplacement = `        footerText: "© 2026 تطبيق MA. جميع الحقوق محفوظة.",`;
content = content.replace(arFooterTarget, arFooterReplacement);

// 3. Header Logo Brand update (Remove Tracker word and add onClick)
const headerBrandTarget = `                    <a href="#" className="flex items-center gap-3">
                        <img src="/MA_logo.png" className="w-9 h-9 rounded-xl shadow-lg border border-white/10 object-contain" alt="MA Logo" />
                        <div className="flex flex-col">
                            <span className="font-extrabold text-lg tracking-wider leading-none">{t('title')}</span>
                            <span className="text-[9px] uppercase tracking-widest text-rose-500 font-bold mt-0.5">{t('tracker')}</span>
                        </div>
                    </a>`;

const headerBrandReplacement = `                    <a href="#hero" onClick={(e) => { e.preventDefault(); scrollToSection('hero'); }} className="flex items-center gap-3">
                        <img src="/MA_logo.png" className="w-9 h-9 rounded-xl shadow-lg border border-white/10 object-contain" alt="MA Logo" />
                        <div className="flex flex-col">
                            <span className="font-extrabold text-lg tracking-wider leading-none">{t('title')}</span>
                        </div>
                    </a>`;

if (content.includes(headerBrandTarget)) {
    content = content.replace(headerBrandTarget, headerBrandReplacement);
} else {
    console.error("Target headerBrandTarget not found!");
}

// 4. Header nav links updates (Remove hashes from push history, use scrollToSection)
const headerNavTarget = `                    <nav className="hidden md:flex items-center gap-8 text-sm font-medium">
                        <a href="#hero" className="hover:text-violet-400 transition-colors">{t('home')}</a>
                        <a href="#hub" className="hover:text-violet-400 transition-colors">{t('animeHub')}</a>
                        <a href="#watchlist" className="hover:text-violet-400 transition-colors">{t('myWatchlist')}</a>
                        <a href="#stats" className="hover:text-violet-400 transition-colors">{t('telemetryStats')}</a>
                    </nav>`;

const headerNavReplacement = `                    <nav className="hidden md:flex items-center gap-8 text-sm font-medium">
                        <a href="#hero" onClick={(e) => { e.preventDefault(); scrollToSection('hero'); }} className="hover:text-violet-400 transition-colors">{t('home')}</a>
                        <a href="#hub" onClick={(e) => { e.preventDefault(); scrollToSection('hub'); }} className="hover:text-violet-400 transition-colors">{t('animeHub')}</a>
                        <a href="#watchlist" onClick={(e) => { e.preventDefault(); scrollToSection('watchlist'); }} className="hover:text-violet-400 transition-colors">{t('myWatchlist')}</a>
                        <a href="#schedule-showcase" onClick={(e) => { e.preventDefault(); scrollToSection('schedule-showcase'); }} className="hover:text-violet-400 transition-colors">{t('telemetryStats')}</a>
                    </nav>`;

if (content.includes(headerNavTarget)) {
    content = content.replace(headerNavTarget, headerNavReplacement);
} else {
    console.error("Target headerNavTarget not found!");
}

// 5. Browse Hub button redirection update
const browseHubBtnTarget = `                        <a
                            href="#hub"
                            className="relative group overflow-hidden px-5 py-2.5 rounded-full bg-gradient-to-r from-violet-600 to-rose-600 text-sm font-semibold hover:opacity-95 transition-all shadow-lg"
                        >
                            <span className="relative z-10 flex items-center gap-2 text-white">
                                {language === 'ar' ? 'تصفح المركز' : 'Browse Hub'} <Search className="w-3.5 h-3.5" />
                            </span>
                        </a>`;

const browseHubBtnReplacement = `                        <a
                            href="https://github.com/LOMoriartyVE/myanimes-privacy"
                            target="_blank"
                            rel="noopener noreferrer"
                            className="relative group overflow-hidden px-5 py-2.5 rounded-full bg-gradient-to-r from-violet-600 to-rose-600 text-sm font-semibold hover:opacity-95 transition-all shadow-lg"
                        >
                            <span className="relative z-10 flex items-center gap-2 text-white">
                                {language === 'ar' ? 'تصفح المركز' : 'Browse Hub'} <Search className="w-3.5 h-3.5" />
                            </span>
                        </a>`;

if (content.includes(browseHubBtnTarget)) {
    content = content.replace(browseHubBtnTarget, browseHubBtnReplacement);
} else {
    console.error("Target browseHubBtnTarget not found!");
}

// 6. Insert CONTACTS section right after FAQ section
const faqEndTarget = `                        ))}
                    </div>
                </section>
            </main>`;

const faqEndReplacement = `                        ))}
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
            </main>`;

if (content.includes(faqEndTarget)) {
    content = content.replace(faqEndTarget, faqEndReplacement);
} else {
    console.error("Target faqEndTarget not found!");
}

// 7. Insert Feedback Modal near the bottom of index.jsx (alongside Anime Details Modal)
const detailsModalEndTarget = `            {/* FOOTER */}`;
const detailsModalEndReplacement = `            {/* FEEDBACK MODAL */}
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

            {/* FOOTER */}`;

if (content.includes(detailsModalEndTarget)) {
    content = content.replace(detailsModalEndTarget, detailsModalEndReplacement);
} else {
    console.error("Target detailsModalEndTarget not found!");
}

// 8. Footer component updates (Remove Tracker from logo sublabel, remove Twitter, update Github link, update feedback click, update footerText)
const footerTarget = `            {/* FOOTER */}
            <footer className="border-t border-white/5 py-12 bg-black/35 relative z-10 px-6 mt-20">
                <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-6">
                    <div className="flex items-center gap-2.5">
                        <img src="/MA_logo.png" className="w-7 h-7 rounded-lg shadow-md border border-white/10 object-contain" alt="MA Logo" />
                        <div className="flex flex-col text-left">
                            <span className="font-extrabold text-sm tracking-wider leading-none">{t('title')}</span>
                            <span className="text-[8px] uppercase tracking-widest text-rose-500 font-bold mt-0.5">{t('tracker')}</span>
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
                        <a href="#" className="w-8 h-8 rounded-full bg-[#131622] border border-white/5 flex items-center justify-center text-slate-400 hover:text-white transition-colors">
                            <MessageSquare className="w-4 h-4" />
                        </a>
                        <a href="#" className="w-8 h-8 rounded-full bg-[#131622] border border-white/5 flex items-center justify-center text-slate-400 hover:text-white transition-colors">
                            <Twitter className="w-4 h-4" />
                        </a>
                        <a href="#" className="w-8 h-8 rounded-full bg-[#131622] border border-white/5 flex items-center justify-center text-slate-400 hover:text-white transition-colors">
                            <Github className="w-4 h-4" />
                        </a>
                    </div>
                </div>
            </footer>`;

const footerReplacement = `            {/* FOOTER */}
            <footer className="border-t border-white/5 py-12 bg-black/35 relative z-10 px-6 mt-20">
                <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-6">
                    <div className="flex items-center gap-2.5">
                        <img src="/MA_logo.png" className="w-7 h-7 rounded-lg shadow-md border border-white/10 object-contain" alt="MA Logo" />
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
            </footer>`;

if (content.includes(footerTarget)) {
    content = content.replace(footerTarget, footerReplacement);
} else {
    console.error("Target footerTarget not found!");
}

fs.writeFileSync(filePath, content, 'utf8');
console.log("Successfully patched Website/index.jsx with all new footer, contacts section, feedback page, link redirections, hashless scrolling, and title updates!");
