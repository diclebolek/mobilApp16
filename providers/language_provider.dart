import 'package:flutter/material.dart';

/// Simple language provider to toggle and read translations.
///
/// Usage pattern inside widgets:
///   final lang = context.watch<LanguageProvider>();
///   Text(lang.t('appointment_title'))
///
/// Keep keys consistent across the app. Add new keys to both `en` and `tr` maps.
class LanguageProvider extends ChangeNotifier {
  LanguageProvider({AppLanguage initialLanguage = AppLanguage.en})
    : _currentLanguage = initialLanguage;

  AppLanguage _currentLanguage;

  /// Current selected language
  AppLanguage get currentLanguage => _currentLanguage;

  /// Convenience flags
  bool get isTurkish => _currentLanguage == AppLanguage.tr;
  bool get isEnglish => _currentLanguage == AppLanguage.en;

  /// Flutter `Locale` to be used by `MaterialApp.locale`
  Locale get locale => isTurkish ? const Locale('tr') : const Locale('en');

  /// Switch language at runtime
  void setLanguage(AppLanguage language) {
    if (language == _currentLanguage) return;
    _currentLanguage = language;
    notifyListeners();
  }

  /// Translate by key. Falls back to the key itself if missing.
  String t(String key) {
    final table = _translations[_currentLanguage] ?? const {};
    return table[key] ?? key;
  }

  /// Core translation tables.
  ///
  /// IMPORTANT:
  /// - Add every new key to BOTH languages to keep parity.
  /// - Keep keys lowercase_with_underscores.
  static const Map<AppLanguage, Map<String, String>> _translations = {
    AppLanguage.en: {
      // Titles / Headers
      'app_title': 'Hair Salon',
      'home_title': 'Home',
      'appointment_title': 'Appointments',
      'services_title': 'Services',
      'stylists_title': 'Stylists',
      'profile_title': 'Profile',

      // Common actions / Buttons
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'update': 'Update',
      'confirm': 'Confirm',
      'book_now': 'Book Now',
      'refresh': 'Refresh',
      'change_language': 'Change Language',

      // Form labels / helpers
      'name': 'Name',
      'email': 'Email',
      'phone': 'Phone',
      'date': 'Date',
      'time': 'Time',
      'notes': 'Notes',
      'select_service': 'Select Service',
      'select_stylist': 'Select Stylist',

      // Paragraphs / Explanations
      'appointment_description':
          'Choose your preferred service and stylist to book an appointment.',
      'no_appointments': 'You have no upcoming appointments.',

      // Footer / Misc
      'footer_rights': 'All rights reserved.',
      'footer_contact': 'Contact',
      'footer_terms': 'Terms',
      'footer_privacy': 'Privacy',

      // Appointment screen
      'back': 'Back',
      'create_appointment': 'Create Appointment',
      'select_service_label': 'Select Service',
      'loading': 'Loading...',
      'refresh_services': 'Refresh Services',
      'select_service_hint': 'Select a service',
      'select_service_validate': 'Please select a service',
      'select_employee_label': 'Select Employee',
      'general': 'General',
      'select_employee_validate': 'Please select an employee',
      'select_service_first': 'Please select a service first',
      'no_employee_for_service': 'No available employee for this service',
      'notes_optional': 'Notes (Optional)',
      'enter_notes': 'Enter your notes...',
      'date_time': 'Date & Time',
      'make_appointment': 'Make Appointment',
      'service': 'Service',
      'employee': 'Employee',
      'pick_date': 'Pick Date',
      'pick_time': 'Pick Time',
      'appointment_created_success': 'Appointment created successfully!',
      'error_occurred': 'Error occurred:',
      'please_fill_required': 'Please fill all required fields',
      'business_id_not_found': 'Business ID not found',
      'user_not_logged_in': 'User is not logged in',
      'customer_not_found': 'Customer information not found',
      'appointment_conflict_title': 'Appointment Conflict',
      'employee_not_available':
          'The employee is not available at the selected time:',
      'conflicting_appointments': 'Conflicting Appointments:',
      'ok': 'OK',

      // Login screen
      'welcome_to': 'Welcome to',
      'sign_in_to_your': 'Sign in to your',
      'account': 'account',
      'email_address': 'Email Address',
      'enter_email': 'Enter your email',
      'password': 'Password',
      'enter_password': 'Enter your password',
      'password_min': 'Password must be at least 6 characters',
      'remember_me': 'Remember me',
      'forgot_password': 'Forgot Password?',
      'or': 'OR',
      'sign_in': 'Sign In',
      'sign_up': 'Sign Up',
      'join': 'Join',
      'create_account': 'Create Account',
      'create_account_description':
          'Create your {business} account to book appointments',
      'already_have_account': 'Already have an account?',
      'forgot_password_title': 'Forgot Password',
      'password_reset_sent': 'Password reset link sent to your email!',
      'send': 'Send',

      // Services screen
      'our_services': 'Our Services',
      'try_again': 'Try Again',
      'no_services': 'No services available yet.',
      'minute_suffix': 'min',

      // Admin / Navigation labels
      'employee_and_appointment': 'Employees & Appointments',
      'performance_analysis': 'Performance Analysis',
      'profile_info': 'Profile Info',
      'about_us': 'About Us',
      'about_description':
          'At Sirius Beauty & Spa, we believe that true beauty comes from within, and we\'re here to help you shine like the star you are.',
      'turkish': 'Turkish',
      'english': 'English',

      // Login screen additional translations
      'customer': 'Customer',
      'admin': 'Admin',
      'dont_have_account': 'Don\'t have an account?',
      'register': 'Register',

      // Sidebar and navigation
      'logout': 'Logout',
      'exit': 'Exit',

      // Why Choose Us section
      'why_choose_us': 'Why Choose Us',
      'why_choose_us_description':
          'We provide the best service with our experienced team',
      'professional_service': 'Professional Service',
      'professional_service_description':
          'Our team consists of experts in their field',
      'quality_products': 'Quality Products',
      'quality_products_description':
          'We use only the highest quality products',
      'customer_satisfaction': 'Customer Satisfaction',
      'customer_satisfaction_description': 'Your satisfaction is our priority',

      // Menu services
      'hair_cut': 'Hair Cut',
      'hair_styling': 'Hair Styling',
      'hair_coloring': 'Hair Coloring',
      'hair_treatment': 'Hair Treatment',
      'manicure': 'Manicure',
      'pedicure': 'Pedicure',
      'facial': 'Facial',
      'massage': 'Massage',

      // Footer
      'contact_us': 'Contact Us',
      'address': 'Address',
      'footer_phone': 'Phone',
      'footer_email': 'Email',
      'working_hours': 'Working Hours',
      'monday_friday': 'Monday - Friday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',
      'all_rights_reserved': 'All Rights Reserved',

      // Profile screen story buttons
      'edit_profile_info': 'Edit Profile Info',
      'profile_contact_us': 'Contact Us',
      'profile_create_appointment': 'Create Appointment',
      'get_directions': 'Get Directions',

      // Home screen additional translations
      'sirius_hair_salon': 'Sirius Hair Salon',
      'events': 'Events',
      'our_team': 'Our Team',
      'gallery': 'Gallery',
      'contact': 'Contact',
      'ad_soyad': 'Name Surname',
      'no_appointments_found': 'No appointments found',
      'appointments': 'Appointments',
      'profile_settings': 'Profile Settings',
      'contact_info': 'Contact Information',
      'get_directions_info': 'Get directions to our salon',
      'working_hours_info': 'Monday - Saturday: 07:00 - 23:00',
      'phone_info': '+905348956232',
      'email_info': 'gymOrion@gmail.com',
      'website_info': 'www.oriongym.com',
      'address_info': 'Istanbul, Kadıköy, Istanbul 34744',

      // Form fields
      'subject': 'Subject',
      'message': 'Message',
      'send_message': 'Send Message',
      'message_sent': 'Message sent!',

      // Appointment filter buttons
      'all': 'All',
      'past': 'Past',
      'pending': 'Pending',
      'confirmed': 'Confirmed',
      'cancelled': 'Cancelled',

      // Sorting buttons
      'newest_to_oldest': 'Newest to Oldest',
      'oldest_to_newest': 'Oldest to Newest',

      // Menu buttons and card texts
      'book_appointment': 'Book Appointment',
      'view_services': 'View Services',
      'meet_team': 'Meet Our Team',
      'view_gallery': 'View Gallery',
      'menu_contact_us': 'Contact Us',
      'learn_more': 'Learn More',
      'read_more': 'Read More',
      'see_all': 'See All',
      'view_details': 'View Details',

      // Card content texts
      'beauty_meets_serenity': 'Where Beauty Meets Serenity',
      'beauty_meets_serenity_desc':
          'At Sirius, we create a peaceful escape from the hustle of daily life. Our tranquil atmosphere and expert care are designed to help you relax, rejuvenate, and rediscover your inner calm.',
      'your_beauty_our_galaxy': 'Your Beauty, Our Galaxy',
      'your_beauty_our_galaxy_desc':
          'You are at the center of everything we do. Our personalized treatments celebrate your unique beauty, enhancing your natural radiance with the finest products and techniques.',
      'glow_beyond_stars': 'Glow Beyond the Stars with Sirius',
      'glow_beyond_stars_desc':
          'We go beyond ordinary beauty care to make you feel extraordinary. At Sirius, every treatment is crafted to leave you glowing with confidence.',

      // About Us section
      'home_about_us': 'About Us',
      'home_about_us_description':
          'At Sirius Beauty & Spa, we believe that true beauty comes from within, and we\'re here to help you shine like the star you are.',

      // Our Services section
      'home_our_services': 'Our Services',
      'home_our_services_description':
          'We offer a wide range of beauty and wellness services to help you look and feel your best.',

      // Menu buttons
      'menu_book_appointment': 'Book Appointment',
      'menu_view_services': 'View Services',
      'menu_meet_team': 'Meet Our Team',
      'menu_view_gallery': 'View Gallery',

      // Service names
      'service_hair_cut': 'Hair Cut',
      'service_hair_styling': 'Hair Styling',
      'service_hair_coloring': 'Hair Coloring',
      'service_hair_treatment': 'Hair Treatment',
      'service_manicure': 'Manicure',
      'service_pedicure': 'Pedicure',
      'service_facial': 'Facial',
      'service_massage': 'Massage',

      // Footer additional texts
      'footer_website': 'Website',
      'footer_working_hours_info': 'Monday - Saturday: 07:00 - 23:00',
      'footer_phone_info': '+905348956232',
      'footer_email_info': 'gymOrion@gmail.com',
      'footer_address_info': 'Istanbul, Kadıköy, Istanbul 34744',
    },
    AppLanguage.tr: {
      // Titles / Headers
      'app_title': 'Kuaför Salonu',
      'home_title': 'Ana Sayfa',
      'appointment_title': 'Randevular',
      'services_title': 'Hizmetler',
      'stylists_title': 'Uzmanlar',
      'profile_title': 'Profil',

      // Common actions / Buttons
      'save': 'Kaydet',
      'cancel': 'İptal',
      'delete': 'Sil',
      'edit': 'Düzenle',
      'update': 'Güncelle',
      'confirm': 'Onayla',
      'book_now': 'Hemen Randevu Al',
      'refresh': 'Yenile',
      'change_language': 'Dili Değiştir',

      // Form labels / helpers
      'name': 'Ad Soyad',
      'email': 'E-posta',
      'phone': 'Telefon',
      'date': 'Tarih',
      'time': 'Saat',
      'notes': 'Notlar',
      'select_service': 'Hizmet Seçin',
      'select_stylist': 'Uzman Seçin',

      // Paragraphs / Explanations
      'appointment_description':
          'Randevu oluşturmak için tercih ettiğiniz hizmeti ve uzmanı seçin.',
      'no_appointments': 'Yaklaşan bir randevunuz yok.',

      // Footer / Misc
      'footer_rights': 'Tüm hakları saklıdır.',
      'footer_contact': 'İletişim',
      'footer_terms': 'Şartlar',
      'footer_privacy': 'Gizlilik',

      // Appointment screen
      'back': 'Geri',
      'create_appointment': 'Randevu Oluştur',
      'select_service_label': 'Hizmet Seçin',
      'loading': 'Yükleniyor...',
      'refresh_services': 'Hizmetleri Yenile',
      'select_service_hint': 'Hizmet seçin',
      'select_service_validate': 'Lütfen bir hizmet seçin',
      'select_employee_label': 'Çalışan Seçin',
      'general': 'Genel',
      'select_employee_validate': 'Lütfen bir çalışan seçin',
      'select_service_first': 'Önce bir hizmet seçin',
      'no_employee_for_service': 'Bu hizmet için uygun çalışan bulunamadı',
      'notes_optional': 'Notlar (Opsiyonel)',
      'enter_notes': 'Notlarınızı yazın...',
      'date_time': 'Tarih ve Saat',
      'make_appointment': 'Randevu Al',
      'service': 'Hizmet',
      'employee': 'Çalışan',
      'pick_date': 'Tarih Seç',
      'pick_time': 'Saat Seç',
      'appointment_created_success': 'Randevu başarıyla oluşturuldu!',
      'error_occurred': 'Hata oluştu:',
      'please_fill_required': 'Lütfen tüm gerekli alanları doldurun',
      'business_id_not_found': 'İşletme ID bulunamadı',
      'user_not_logged_in': 'Kullanıcı girişi yapılmamış',
      'customer_not_found': 'Müşteri bilgileri bulunamadı',
      'appointment_conflict_title': 'Randevu Çakışması',
      'employee_not_available': 'Seçilen saatte çalışan müsait değil:',
      'conflicting_appointments': 'Çakışan Randevular:',
      'ok': 'Tamam',

      // Login screen
      'welcome_to': 'Hoş geldiniz',
      'sign_in_to_your': 'Hesabınıza giriş yapın',
      'account': 'hesabı',
      'email_address': 'E-posta Adresi',
      'enter_email': 'E-postanızı girin',
      'password': 'Şifre',
      'enter_password': 'Şifrenizi girin',
      'password_min': 'Şifre en az 6 karakter olmalıdır',
      'remember_me': 'Beni hatırla',
      'forgot_password': 'Şifremi Unuttum?',
      'or': 'VEYA',
      'sign_in': 'Giriş Yap',
      'sign_up': 'Kayıt Ol',
      'join': 'Katıl',
      'create_account': 'Hesap Oluştur',
      'create_account_description':
          '{business} hesabınızı oluşturun ve randevu alın',
      'already_have_account': 'Zaten hesabınız var mı?',
      'forgot_password_title': 'Şifremi Unuttum',
      'password_reset_sent':
          'Şifre sıfırlama bağlantısı e-postanıza gönderildi!',
      'send': 'Gönder',

      // Services screen
      'our_services': 'Hizmetlerimiz',
      'try_again': 'Tekrar Dene',
      'no_services': 'Henüz hizmet bulunmamaktadır.',
      'minute_suffix': 'dk',

      // Admin / Navigation labels
      'employee_and_appointment': 'Çalışan & Randevu',
      'performance_analysis': 'Performans Analizi',
      'profile_info': 'Profil Bilgileri',
      'about_us': 'Hakkımızda',
      'about_description':
          'Sirius Beauty & Spa\'da, gerçek güzelliğin içten geldiğine inanıyoruz ve yıldız gibi parlamanıza yardım etmek için buradayız.',
      'turkish': 'Türkçe',
      'english': 'İngilizce',

      // Login screen additional translations
      'customer': 'Müşteri',
      'admin': 'Yönetici',
      'dont_have_account': 'Hesabınız yok mu?',
      'register': 'Kayıt Ol',

      // Sidebar and navigation
      'logout': 'Çıkış Yap',
      'exit': 'Çıkış',

      // Why Choose Us section
      'why_choose_us': 'Neden Bizi Seçmelisiniz',
      'why_choose_us_description':
          'Deneyimli ekibimizle en iyi hizmeti sunuyoruz',
      'professional_service': 'Profesyonel Hizmet',
      'professional_service_description':
          'Ekibimiz alanında uzman kişilerden oluşur',
      'quality_products': 'Kaliteli Ürünler',
      'quality_products_description':
          'Sadece en yüksek kalitede ürünler kullanıyoruz',
      'customer_satisfaction': 'Müşteri Memnuniyeti',
      'customer_satisfaction_description': 'Memnuniyetiniz önceliğimizdir',

      // Menu services
      'hair_cut': 'Saç Kesimi',
      'hair_styling': 'Saç Şekillendirme',
      'hair_coloring': 'Saç Boyama',
      'hair_treatment': 'Saç Bakımı',
      'manicure': 'Manikür',
      'pedicure': 'Pedikür',
      'facial': 'Cilt Bakımı',
      'massage': 'Masaj',

      // Footer
      'contact_us': 'Bize Ulaşın',
      'address': 'Adres',
      'footer_phone': 'Telefon',
      'footer_email': 'E-posta',
      'working_hours': 'Çalışma Saatleri',
      'monday_friday': 'Pazartesi - Cuma',
      'saturday': 'Cumartesi',
      'sunday': 'Pazar',
      'all_rights_reserved': 'Tüm Hakları Saklıdır',

      // Profile screen story buttons
      'edit_profile_info': 'Profil Bilgilerimi Düzenle',
      'profile_contact_us': 'İletişime Geç',
      'profile_create_appointment': 'Randevu Oluştur',
      'get_directions': 'Yol Tarifi',

      // Home screen additional translations
      'sirius_hair_salon': 'Sirius Kuaför Salonu',
      'events': 'Etkinlikler',
      'our_team': 'Ekibimiz',
      'gallery': 'Galeri',
      'contact': 'İletişim',
      'ad_soyad': 'Ad Soyad',
      'no_appointments_found': 'Randevu bulunamadı',
      'appointments': 'Randevular',
      'profile_settings': 'Profil Ayarları',
      'contact_info': 'İletişim Bilgileri',
      'get_directions_info': 'Salonumuza yol tarifi alın',
      'working_hours_info': 'Pazartesi - Cumartesi: 07:00 - 23:00',
      'phone_info': '+905348956232',
      'email_info': 'gymOrion@gmail.com',
      'website_info': 'www.oriongym.com',
      'address_info': 'İstanbul, Kadıköy, İstanbul 34744',

      // Form fields
      'subject': 'Konu',
      'message': 'Mesajınız',
      'send_message': 'Mesaj Gönder',
      'message_sent': 'Mesaj Gönderildi!',

      // Appointment filter buttons
      'all': 'Tümü',
      'past': 'Geçmiş',
      'pending': 'Bekleyen',
      'confirmed': 'Onaylanan',
      'cancelled': 'İptal',

      // Sorting buttons
      'newest_to_oldest': 'Yeniden Eskiye',
      'oldest_to_newest': 'Eskiden Yeniye',

      // Menu buttons and card texts
      'book_appointment': 'Randevu Al',
      'view_services': 'Hizmetleri Görüntüle',
      'meet_team': 'Ekibimizle Tanışın',
      'view_gallery': 'Galeriyi Görüntüle',
      'menu_contact_us': 'Bize Ulaşın',
      'learn_more': 'Daha Fazla Bilgi',
      'read_more': 'Devamını Oku',
      'see_all': 'Tümünü Gör',
      'view_details': 'Detayları Görüntüle',

      // Card content texts
      'beauty_meets_serenity': 'Güzellik Huzurla Buluşuyor',
      'beauty_meets_serenity_desc':
          'Sirius\'ta, günlük hayatın koşuşturmasından huzurlu bir kaçamak yaratıyoruz. Huzurlu atmosferimiz ve uzman bakımımız, rahatlamanıza, yenilenmenize ve iç huzurunuzu yeniden keşfetmenize yardımcı olmak için tasarlanmıştır.',
      'your_beauty_our_galaxy': 'Güzelliğiniz, Galaksimiz',
      'your_beauty_our_galaxy_desc':
          'Yaptığımız her şeyin merkezinde siz varsınız. Kişiselleştirilmiş tedavilerimiz, benzersiz güzelliğinizi kutlar ve en kaliteli ürünler ve tekniklerle doğal parlaklığınızı artırır.',
      'glow_beyond_stars': 'Sirius ile Yıldızlardan Öteye Parlayın',
      'glow_beyond_stars_desc':
          'Sıradan güzellik bakımının ötesine geçerek kendinizi olağanüstü hissetmenizi sağlıyoruz. Sirius\'ta, her tedavi güvenle parlamanız için özenle hazırlanmıştır.',

      // About Us section
      'home_about_us': 'Hakkımızda',
      'home_about_us_description':
          'Sirius Beauty & Spa\'da, gerçek güzelliğin içten geldiğine inanıyoruz ve yıldız gibi parlamanıza yardım etmek için buradayız.',

      // Our Services section
      'home_our_services': 'Hizmetlerimiz',
      'home_our_services_description':
          'En iyi görünmeniz ve hissetmeniz için geniş bir güzellik ve sağlık hizmetleri yelpazesi sunuyoruz.',

      // Menu buttons
      'menu_book_appointment': 'Randevu Al',
      'menu_view_services': 'Hizmetleri Görüntüle',
      'menu_meet_team': 'Ekibimizle Tanışın',
      'menu_view_gallery': 'Galeriyi Görüntüle',

      // Service names
      'service_hair_cut': 'Saç Kesimi',
      'service_hair_styling': 'Saç Şekillendirme',
      'service_hair_coloring': 'Saç Boyama',
      'service_hair_treatment': 'Saç Bakımı',
      'service_manicure': 'Manikür',
      'service_pedicure': 'Pedikür',
      'service_facial': 'Cilt Bakımı',
      'service_massage': 'Masaj',

      // Footer additional texts
      'footer_website': 'Web Sitesi',
      'footer_working_hours_info': 'Pazartesi - Cumartesi: 07:00 - 23:00',
      'footer_phone_info': '+905348956232',
      'footer_email_info': 'gymOrion@gmail.com',
      'footer_address_info': 'İstanbul, Kadıköy, İstanbul 34744',
    },
  };
}

/// Supported application languages
enum AppLanguage { en, tr }
