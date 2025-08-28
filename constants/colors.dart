import 'package:flutter/material.dart';

class SiriusColors {
  // WEB3'teki ana renkler
  static const Color background = Color(0xFF0C0B09); // --background-color
  // Surface artık dinamik: isletme.tema_rengi2 ile güncellenir
  static Color get surface => accent2Dynamic; // --surface-color
  // Accent artık dinamik: Supabase'den okunan renk ile güncellenir
  static Color get accent => accentDynamic; // --accent-color (mor)
  static const Color heading = Color(0xFFFFFFFF); // --heading-color (beyaz)
  static const Color defaultText = Color(
    0xB3FFFFFF,
  ); // --default-color (beyaz 70%)
  static const Color contrast = Color(0xFF0C0B09); // --contrast-color

  // Dinamik olarak güncellenebilen ana renk (varsayılan: accent)
  static Color accentDynamic = const Color(0xFFBDA2C8);

  // İkinci tema rengi (isletme.tema_rengi2)
  static Color accent2Dynamic = const Color(0xFFFFFFFF);
  static Color get accent2 => accent2Dynamic;

  // Dışarıdan dinamik ana rengi ayarlamak için yardımcı
  static void setAccentDynamic(Color color) {
    accentDynamic = color;
  }

  // Dışarıdan dinamik ikinci rengi ayarlamak için yardımcı
  static void setAccent2Dynamic(Color color) {
    accent2Dynamic = color;
  }

  // Ek renkler
  static const Color lightBackground = Color(0xFF241F29); // .light-background
  static const Color darkBackground = Color(0xFF000000); // .dark-background
  static const Color surfaceLight = Color(
    0xFF413546,
  ); // .light-background surface

  // Durum renkleri
  static const Color success = Color(0xFF4CAF50); // Başarı rengi
  static const Color error = Color(0xFFF44336); // Hata rengi
  static const Color warning = Color(0xFFFF9800); // Uyarı rengi
  static const Color info = Color(0xFF2196F3); // Bilgi rengi

  // Border ve çizgi renkleri
  static const Color border = Color(0xFF413546); // Kenarlık rengi
}
