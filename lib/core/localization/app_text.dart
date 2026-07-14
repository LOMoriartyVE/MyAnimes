/// Simple localization system supporting English and Arabic.
class AppText {
  static String _currentLang = 'en';

  static String get currentLang => _currentLang;
  static bool get isArabic => _currentLang == 'ar';

  static void setLanguage(String lang) {
    _currentLang = lang;
  }

  static String get(String key) {
    final map = _translations[_currentLang];
    return map?[key] ?? _translations['en']?[key] ?? key;
  }

  static String getPlural(String baseKey, int count) {
    if (count == 1) {
      return get('${baseKey}_singular');
    } else {
      return get('${baseKey}_plural');
    }
  }

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      // Nav
      'nav_home': 'Home',
      'nav_search': 'Search',
      'nav_schedule': 'Schedule',
      'nav_my_list': 'My List',
      'nav_library': 'Library',
      'nav_settings': 'Settings',

      // Home
      'trending_now': 'Trending Now',
      'current_season': 'Current Season',
      'top_rated': 'Top Rated Anime',
      'see_all': 'See All',
      'more_info': 'More Info',
      'featured_trending_anime_singular': 'Featured & Trending Anime',
      'featured_trending_anime_plural': 'Featured & Trending Animes',
      'upcoming_anime_singular': 'Upcoming Anime',
      'upcoming_anime_plural': 'Upcoming Animes',
      'top_manga_singular': 'Top Manga',
      'top_manga_plural': 'Top Mangas',
      'top_reviews_singular': 'Top Review',
      'top_reviews_plural': 'Top Reviews',
      'for_you_singular': 'For You',
      'for_you_plural': 'For You',
      'recommended_for_you_singular': 'Recommended For You',
      'recommended_for_you_plural': 'Recommended For You',
      'airing_next_today': 'Airing Next Today',

      // Search
      'search_anime': 'Search anime...',
      'all_statuses': 'All Statuses',
      'airing': 'Airing',
      'finished': 'Finished',
      'upcoming': 'Upcoming',
      'all_ratings': 'All Ratings',
      'sort_by': 'Sort by',
      'score': 'Score',
      'title': 'Title',
      'popularity': 'Popularity',
      'no_results': 'No results found.',
      'start_searching': 'Start typing or use filters to find anime.',

      // Schedule
      'weekly_schedule': 'Weekly Schedule',
      'today': 'Today',
      'monday': 'Monday',
      'tuesday': 'Tuesday',
      'wednesday': 'Wednesday',
      'thursday': 'Thursday',
      'friday': 'Friday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',
      'no_schedule': 'No anime scheduled for this day.',

      // My List
      'plan_to_watch': 'Plan to Watch',
      'watching': 'Watching',
      'completed': 'Completed',
      'ignored': 'Ignored',
      'planned': 'Planned',
      'empty_list': 'Your list is empty.',
      'empty_list_hint': 'Tap the + button on anime cards to add them here.',
      'remove_from_list': 'Remove from list',
      'delete_from_list': 'Delete from List',
      'add_to_list': 'Add to List',
      'select_category': 'Select Category',
      'sort_filter': 'Sort & Filter',
      'sort_by_title': 'By Title',
      'sort_by_score': 'By Score',
      'sort_by_date_added': 'By Date Added',
      'filter_by_genre': 'Filter by Genre',
      'all_genres': 'All Genres',

      // Detail
      'synopsis': 'Synopsis',
      'trailer': 'Trailer',
      'characters': 'Characters',
      'information': 'Information',
      'genres': 'Genres',
      'studio': 'Studio',
      'episodes': 'Episodes',
      'rating': 'Rating',
      'status': 'Status',
      'year': 'Year',
      'type': 'Type',
      'source': 'Source',
      'duration': 'Duration',
      'added_to_list': 'Added to List',

      // User Rating
      'your_rating': 'Your Rating',
      'overall_rating': 'Overall',
      'story_rating': 'Story',
      'character_rating': 'Characters',
      'animation_rating': 'Animation',
      'draw_rating': 'Drawing',
      'music_rating': 'Music (OSTs)',
      'notes': 'Notes',
      'notes_hint': 'Write your thoughts about this anime...',
      'save': 'Save',
      'cancel': 'Cancel',
      'edit': 'Edit',

      // Settings
      'settings': 'Settings',
      'preferences': 'Preferences',
      'dark_mode': 'Dark Mode',
      'language': 'Language',
      'english': 'English',
      'arabic': 'Arabic',
      'data': 'Data Management',
      'export_data': 'Export Data',
      'import_data': 'Import Data',

      // General
      'try_again': 'Try Again',
      'error_title': 'Oops, something went wrong',
      'error_message': 'Something went wrong while fetching data.',
      'loading': 'Loading...',
      'no_synopsis': 'No synopsis available.',
      'unknown': 'Unknown',
      'watch_trailer': 'Watch Trailer',
      'press_back_again': 'Press back again to exit',
      'api_unavailable': 'API temporarily unavailable',
      'showing_cached_data': 'Showing cached data — pull to refresh when online.',
      'google_drive_sync': 'Google Drive Sync',
      'connect_drive': 'Connect Google Drive',
      'disconnect_drive': 'Disconnect Account',
      'backup_now': 'Back Up Now',
      'restore_backup': 'Restore Backup',
      'sync_success': 'Backup updated successfully!',
      'restore_success': 'Data restored successfully!',
      'sync_failed': 'Sync failed. Please try again.',
      'cache_settings': 'Cache Settings',
      'cache_mode': 'Cache Duration',
      'cache_mode_never': 'Keep Forever (Never Delete)',
      'cache_mode_default': 'Default (Delete after 2 hours)',
      'cache_mode_custom': 'Custom Duration',
      'custom_duration': 'Select Custom Time',
      'hours_label': 'Hours',
      'days_label': 'Days',
      'drive_not_supported_windows': 'Google Drive Sync is not supported on Windows. Please use Export/Import Data to transfer your list.',
    },
    'ar': {
      // Nav
      'nav_home': 'الرئيسية',
      'nav_search': 'بحث',
      'nav_schedule': 'الجدول',
      'nav_my_list': 'قائمتي',
      'nav_library': 'المكتبة',
      'nav_settings': 'الإعدادات',

      // Home
      'trending_now': 'الأكثر رواجاً',
      'current_season': 'الموسم الحالي',
      'top_rated': 'الأعلى تقييماً',
      'see_all': 'عرض الكل',
      'more_info': 'المزيد',
      'featured_trending_anime_singular': 'أنمي مميز ورائج',
      'featured_trending_anime_plural': 'أنميات مميزة ورائجة',
      'upcoming_anime_singular': 'أنمي قادم',
      'upcoming_anime_plural': 'أنميات قادمة',
      'top_manga_singular': 'أفضل مانجا',
      'top_manga_plural': 'أفضل المانجا',
      'top_reviews_singular': 'أفضل مراجعة',
      'top_reviews_plural': 'أفضل المراجعات',
      'for_you_singular': 'من أجلك',
      'for_you_plural': 'من أجلك',
      'recommended_for_you_singular': 'موصى به لك',
      'recommended_for_you_plural': 'موصى به لك',
      'airing_next_today': 'يعرض لاحقاً اليوم',

      // Search
      'search_anime': 'ابحث عن أنمي...',
      'all_statuses': 'جميع الحالات',
      'airing': 'يُعرض الآن',
      'finished': 'منتهي',
      'upcoming': 'قادم',
      'all_ratings': 'جميع التصنيفات',
      'sort_by': 'ترتيب حسب',
      'score': 'التقييم',
      'title': 'العنوان',
      'popularity': 'الشعبية',
      'no_results': 'لا توجد نتائج.',
      'start_searching': 'ابدأ بالكتابة أو استخدم الفلاتر.',

      // Schedule
      'weekly_schedule': 'الجدول الأسبوعي',
      'today': 'اليوم',
      'monday': 'الإثنين',
      'tuesday': 'الثلاثاء',
      'wednesday': 'الأربعاء',
      'thursday': 'الخميس',
      'friday': 'الجمعة',
      'saturday': 'السبت',
      'sunday': 'الأحد',
      'no_schedule': 'لا يوجد أنمي مجدول لهذا اليوم.',

      // My List
      'plan_to_watch': 'خطة المشاهدة',
      'watching': 'أشاهد',
      'completed': 'مكتمل',
      'ignored': 'متجاهل',
      'planned': 'مخطط',
      'empty_list': 'قائمتك فارغة.',
      'empty_list_hint': 'اضغط على زر + لإضافة أنمي هنا.',
      'remove_from_list': 'إزالة من القائمة',
      'delete_from_list': 'حذف من القائمة',
      'add_to_list': 'إضافة للقائمة',
      'select_category': 'اختر التصنيف',
      'sort_filter': 'الترتيب والتصفية',
      'sort_by_title': 'حسب العنوان',
      'sort_by_score': 'حسب التقييم',
      'sort_by_date_added': 'حسب تاريخ الإضافة',
      'filter_by_genre': 'تصفية حسب النوع',
      'all_genres': 'جميع الأنواع',

      // Detail
      'synopsis': 'الملخص',
      'trailer': 'العرض الدعائي',
      'characters': 'الشخصيات',
      'information': 'المعلومات',
      'genres': 'الأنواع',
      'studio': 'الاستوديو',
      'episodes': 'الحلقات',
      'rating': 'التصنيف العمري',
      'status': 'الحالة',
      'year': 'السنة',
      'type': 'النوع',
      'source': 'المصدر',
      'duration': 'المدة',
      'added_to_list': 'تمت الإضافة',

      // User Rating
      'your_rating': 'تقييمك',
      'overall_rating': 'التقييم العام',
      'story_rating': 'القصة',
      'character_rating': 'الشخصيات',
      'animation_rating': 'الحركة',
      'draw_rating': 'الرسم',
      'music_rating': 'الموسيقى',
      'notes': 'ملاحظات',
      'notes_hint': 'اكتب رأيك عن هذا الأنمي...',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'edit': 'تعديل',

      // Settings
      'settings': 'الإعدادات',
      'preferences': 'التفضيلات',
      'dark_mode': 'الوضع الداكن',
      'language': 'اللغة',
      'english': 'الإنجليزية',
      'arabic': 'العربية',
      'data': 'إدارة البيانات',
      'export_data': 'تصدير البيانات',
      'import_data': 'استيراد البيانات',

      // General
      'try_again': 'حاول مجدداً',
      'error_title': 'حدث خطأ ما',
      'error_message': 'حدث خطأ أثناء جلب البيانات.',
      'loading': 'جاري التحميل...',
      'no_synopsis': 'لا يوجد ملخص متاح.',
      'unknown': 'غير معروف',
      'watch_trailer': 'مشاهدة العرض',
      'press_back_again': 'اضغط مرتين للخروج',
      'api_unavailable': 'الخدمة غير متوفرة مؤقتاً',
      'showing_cached_data': 'يتم عرض البيانات المخزنة — اسحب للتحديث عند الاتصال.',
      'google_drive_sync': 'مزامنة جوجل درايف',
      'connect_drive': 'الاتصال بجوجل درايف',
      'disconnect_drive': 'قطع الاتصال بالحساب',
      'backup_now': 'نسخ احتياطي الآن',
      'restore_backup': 'استعادة النسخة',
      'sync_success': 'تم تحديث النسخ الاحتياطي بنجاح!',
      'restore_success': 'تم استعادة البيانات بنجاح!',
      'sync_failed': 'فشلت المزامنة، يرجى المحاولة لاحقاً.',
      'cache_settings': 'إعدادات التخزين المؤقت',
      'cache_mode': 'مدة التخزين المؤقت',
      'cache_mode_never': 'حفظ للأبد (لا يحذف أبداً)',
      'cache_mode_default': 'تلقائي (الحذف بعد ساعتين)',
      'cache_mode_custom': 'مدة مخصصة',
      'custom_duration': 'اختر مدة مخصصة',
      'hours_label': 'ساعات',
      'days_label': 'أيام',
      'drive_not_supported_windows': 'مزامنة جوجل درايف غير مدعومة على ويندوز. يرجى استخدام تصدير/استيراد البيانات لنقل قائمتك.',
    },
  };
}
