// Export all style files for easy access
export 'colors.dart';
export 'styles.dart';
export 'dimensions.dart';
export 'themes.dart';
export 'animations.dart';
export 'home_styles.dart';
export 'admin_styles.dart';
export 'profile_styles.dart';

/// Proje genelinde kullanılan tüm stil tanımları
/// Bu dosya tüm stil dosyalarını export eder
/// 
/// Kullanım örnekleri:
/// 
/// ```dart
/// import '../constants/app_styles.dart';
/// 
/// // Renkler
/// color: SiriusColors.accent
/// 
/// // Text stilleri
/// style: AppStyles.heading1
/// 
/// // Boyutlar
/// padding: AppDimensions.paddingM
/// 
/// // Temalar
/// theme: AppThemes.lightTheme
/// 
/// // Animasyonlar
/// duration: AppAnimations.durationM
/// ```
/// 
/// Bu yapı sayesinde:
/// - Tüm stiller tek yerden yönetilir
/// - CSS benzeri modüler yapı sağlanır
/// - Tutarlı tasarım elde edilir
/// - Bakım kolaylaşır
/// - Responsive tasarım desteklenir
/// - Tema desteği sağlanır
/// - Animasyon standartları belirlenir


