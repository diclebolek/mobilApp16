import 'package:flutter/material.dart';
import 'colors.dart';

/// Profile ekranına özel stil tanımları
/// Mevcut tasarımı BOZMADAN, aynı görünümleri isimlendirir
class ProfileStyles {
  ProfileStyles._();

  // Hoşgeldiniz başlığı (Cormorant)
  static const TextStyle welcomeTitle = TextStyle(
    color: SiriusColors.contrast,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    fontFamily: 'Cormorant',
  );

  // Kullanıcı adı
  static TextStyle get userName => TextStyle(
    color: SiriusColors.contrast.withValues(alpha: 0.9),
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );

  // Hoşgeldiniz kartı arkaplan (gradient)
  static BoxDecoration get welcomeCard => BoxDecoration(
    gradient: LinearGradient(
      colors: [SiriusColors.accent, SiriusColors.accent.withValues(alpha: 0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: SiriusColors.accent.withValues(alpha: 0.4),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );

  // Dialog arkaplanları
  static BoxDecoration dialogBackground(bool isDark) => BoxDecoration(
    color: isDark ? SiriusColors.surface : Colors.white,
    borderRadius: BorderRadius.circular(20),
  );

  // Vurgulu bölüm başlığı (dialog içi)
  static TextStyle get dialogSectionTitle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  ).copyWith(color: SiriusColors.accent);

  // Vurgulu kapsayıcı (calendar/time/note blokları)
  static BoxDecoration get accentBlock => BoxDecoration(
    color: SiriusColors.accent.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: SiriusColors.accent.withValues(alpha: 0.3)),
  );

  // Input borderları (dialog içi)
  static InputBorder get inputBorder => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: SiriusColors.accent),
  );

  static InputBorder get inputBorderFocused => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: SiriusColors.accent, width: 2),
  );

  // Randevu durum etiketleri
  static BoxDecoration statusChip(Color color) => BoxDecoration(
    color: color.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: color.withValues(alpha: 0.4)),
  );
}
