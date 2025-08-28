import 'package:flutter/material.dart';
import 'colors.dart';

/// Proje genelinde kullanılan stil tanımları
/// CSS benzeri modüler yapı için tasarlandı
class AppStyles {
  // Private constructor - bu sınıf sadece static üyeler içerir
  AppStyles._();

  // ===== TEXT STYLES =====

  /// Ana başlık stili
  static const TextStyle heading1 = TextStyle(
    color: SiriusColors.heading,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    fontFamily: 'Cormorant',
  );

  /// Alt başlık stili
  static const TextStyle heading2 = TextStyle(
    color: SiriusColors.heading,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    fontFamily: 'Playfair Display',
  );

  /// Üçüncü seviye başlık
  static const TextStyle heading3 = TextStyle(
    color: SiriusColors.heading,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  /// Dördüncü seviye başlık
  static const TextStyle heading4 = TextStyle(
    color: SiriusColors.heading,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  /// Normal metin stili
  static const TextStyle bodyText = TextStyle(
    color: SiriusColors.defaultText,
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  /// Küçük metin stili
  static const TextStyle bodyTextSmall = TextStyle(
    color: SiriusColors.defaultText,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  /// Çok küçük metin stili
  static const TextStyle bodyTextTiny = TextStyle(
    color: SiriusColors.defaultText,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  /// Vurgulu metin stili (dinamik accent rengi ile)
  static TextStyle get accentText => const TextStyle(
    // Not: TextStyle const; ancak renk dinamik olduğundan aşağıda copyWith ile ayarlanır
    fontSize: 16,
    fontWeight: FontWeight.w500,
  ).copyWith(color: SiriusColors.accent);

  /// Başarı metni stili
  static const TextStyle successText = TextStyle(
    color: SiriusColors.success,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// Hata metni stili
  static const TextStyle errorText = TextStyle(
    color: SiriusColors.error,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// Uyarı metni stili
  static const TextStyle warningText = TextStyle(
    color: SiriusColors.warning,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// Bilgi metni stili
  static const TextStyle infoText = TextStyle(
    color: SiriusColors.info,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  // ===== BUTTON STYLES =====

  /// Ana buton stili
  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: SiriusColors.accent,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 2,
  );

  /// İkincil buton stili
  static ButtonStyle secondaryButton = ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: SiriusColors.accent,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: SiriusColors.accent),
    ),
    elevation: 0,
  );

  /// Tehlikeli buton stili (çıkış, silme vb.)
  static ButtonStyle dangerButton = ElevatedButton.styleFrom(
    backgroundColor: Colors.red,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    elevation: 2,
  );

  /// Küçük buton stili
  static ButtonStyle smallButton = ElevatedButton.styleFrom(
    backgroundColor: SiriusColors.accent,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    elevation: 1,
  );

  // ===== INPUT FIELD STYLES =====

  /// Input field dekorasyonu
  static InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    IconData? prefixIcon,
    bool isRequired = false,
  }) {
    return InputDecoration(
      labelText: labelText != null
          ? (isRequired ? '$labelText *' : labelText)
          : null,
      hintText: hintText,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: SiriusColors.accent)
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: SiriusColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: SiriusColors.accent, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: SiriusColors.border),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: SiriusColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: SiriusColors.error, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  /// Input field label stili (dinamik accent rengi ile)
  static TextStyle get inputLabelStyle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  ).copyWith(color: SiriusColors.accent);

  // ===== CARD STYLES =====

  /// Ana kart dekorasyonu
  static BoxDecoration primaryCardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  /// Vurgulu kart dekorasyonu
  static BoxDecoration accentCardDecoration = BoxDecoration(
    color: SiriusColors.accent.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: SiriusColors.accent.withValues(alpha: 0.3)),
  );

  /// Koyu tema kart dekorasyonu
  static BoxDecoration darkCardDecoration = BoxDecoration(
    color: SiriusColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: SiriusColors.accent.withValues(alpha: 0.2)),
  );

  // ===== CONTAINER STYLES =====

  /// Ana container dekorasyonu
  static BoxDecoration get primaryContainerDecoration => BoxDecoration(
    gradient: LinearGradient(
      colors: [
        SiriusColors.accent,
        const Color(0xCCBDA2C8),
      ], // 0.8 alpha equivalent
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: const Color(0x66BDA2C8), // 0.4 alpha equivalent
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );

  /// Vurgulu container dekorasyonu
  static BoxDecoration accentContainerDecoration = BoxDecoration(
    color: SiriusColors.accent.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: SiriusColors.accent.withValues(alpha: 0.3)),
  );

  // ===== DIALOG STYLES =====

  /// Dialog dekorasyonu
  static BoxDecoration dialogDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );

  /// Koyu tema dialog dekorasyonu
  static BoxDecoration darkDialogDecoration = BoxDecoration(
    color: SiriusColors.surface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );

  // ===== ANIMATION STYLES =====

  /// Standart animasyon süresi
  static const Duration standardAnimation = Duration(milliseconds: 300);

  /// Hızlı animasyon süresi
  static const Duration fastAnimation = Duration(milliseconds: 150);

  /// Yavaş animasyon süresi
  static const Duration slowAnimation = Duration(milliseconds: 600);

  /// Çok yavaş animasyon süresi
  static const Duration verySlowAnimation = Duration(milliseconds: 1200);

  /// Standart animasyon eğrisi
  static const Curve standardCurve = Curves.easeInOut;

  /// Yumuşak animasyon eğrisi
  static const Curve smoothCurve = Curves.easeOutCubic;

  /// Elastik animasyon eğrisi
  static const Curve elasticCurve = Curves.elasticOut;

  // ===== RESPONSIVE STYLES =====

  /// Mobil için padding
  static const EdgeInsets mobilePadding = EdgeInsets.all(16);

  /// Tablet için padding
  static const EdgeInsets tabletPadding = EdgeInsets.all(24);

  /// Desktop için padding
  static const EdgeInsets desktopPadding = EdgeInsets.all(32);

  /// Mobil için margin
  static const EdgeInsets mobileMargin = EdgeInsets.all(8);

  /// Tablet için margin
  static const EdgeInsets tabletMargin = EdgeInsets.all(16);

  /// Desktop için margin
  static const EdgeInsets desktopMargin = EdgeInsets.all(24);

  // ===== UTILITY STYLES =====

  /// Divider stili
  static const Divider standardDivider = Divider(
    color: SiriusColors.defaultText,
    height: 1,
    thickness: 1,
  );

  /// Spacer boyutları
  static const SizedBox smallSpacer = SizedBox(height: 8);
  static const SizedBox mediumSpacer = SizedBox(height: 16);
  static const SizedBox largeSpacer = SizedBox(height: 24);
  static const SizedBox extraLargeSpacer = SizedBox(height: 32);

  /// Yatay spacer boyutları
  static const SizedBox smallHorizontalSpacer = SizedBox(width: 8);
  static const SizedBox mediumHorizontalSpacer = SizedBox(width: 16);
  static const SizedBox largeHorizontalSpacer = SizedBox(width: 24);
}
