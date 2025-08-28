import 'package:flutter/material.dart';
import 'colors.dart';

/// Home ekranına özel stil tanımları
/// Mevcut tasarımı BOZMADAN, aynı görünümleri isimlendirir
class HomeStyles {
  HomeStyles._();

  // AppBar başlığı ("Sirius")
  static const TextStyle appBarTitle = TextStyle(
    color: Color.fromARGB(255, 228, 224, 216),
    fontFamily: 'Playfair Display',
    fontWeight: FontWeight.bold,
    fontSize: 20,
  );

  // Slider üzeri karartma
  static Color get sliderOverlayColor => Colors.black.withValues(alpha: 0.2);

  // DotsIndicator renkleri
  static const Color dotsActive = Colors.white;
  static Color get dotsInactive => Colors.white.withValues(alpha: 0.4);

  // Bölüm başlıkları
  static const TextStyle sectionTitle = TextStyle(
    color: SiriusColors.heading,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle sectionSubtitle = TextStyle(
    color: SiriusColors.defaultText,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  // Kart gölgesi
  static List<BoxShadow> get lightShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  // Genel kart dekorasyonu (açık)
  static BoxDecoration get lightCard => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: lightShadow,
  );

  // Genel kart dekorasyonu (koyu benzeri)
  static BoxDecoration get darkCard => BoxDecoration(
    color: SiriusColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: SiriusColors.accent.withValues(alpha: 0.2)),
  );

  // Vurgulu kapsayıcı (accent arkaplanlı)
  static BoxDecoration get accentContainer => BoxDecoration(
    color: SiriusColors.accent.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: SiriusColors.accent.withValues(alpha: 0.3)),
  );
}
