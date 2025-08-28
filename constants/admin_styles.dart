import 'package:flutter/material.dart';
import 'colors.dart';

/// Admin ekranına özel stil tanımları
/// Mevcut tasarımı BOZMADAN, aynı görünümleri isimlendirir
class AdminStyles {
  AdminStyles._();

  // Ana başlıklar
  static const TextStyle pageTitle = TextStyle(
    color: SiriusColors.heading,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle sectionTitle = TextStyle(
    color: SiriusColors.heading,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle smallNote = TextStyle(
    color: SiriusColors.defaultText,
    fontSize: 12,
  );

  // Kutucuk arkaplanları
  static BoxDecoration get panel => BoxDecoration(
    color: SiriusColors.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: SiriusColors.accent.withValues(alpha: 0.2)),
  );

  // İstatistik kartı
  static BoxDecoration get statCard => BoxDecoration(
    color: Colors.black.withValues(alpha: 0.2),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: SiriusColors.accent.withValues(alpha: 0.1)),
  );

  // Başarı/uyarı/hata kutuları
  static BoxDecoration get successBox => BoxDecoration(
    color: Colors.green.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.green),
  );

  static BoxDecoration get warningBox => BoxDecoration(
    color: Colors.orange.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.orange),
  );

  static BoxDecoration get errorBox => BoxDecoration(
    color: Colors.red.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.red),
  );
}
