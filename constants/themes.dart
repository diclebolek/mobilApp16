import 'package:flutter/material.dart';
import 'colors.dart';
import 'styles.dart';
import 'dimensions.dart';

/// Proje genelinde kullanılan tema tanımları
/// CSS benzeri modüler yapı için tasarlandı
class AppThemes {
  // Private constructor - bu sınıf sadece static üyeler içerir
  AppThemes._();

  // ===== LIGHT THEME =====

  /// Açık tema
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Renk şeması
      colorScheme: ColorScheme.light(
        primary: SiriusColors.accentDynamic,
        onPrimary: Colors.white,
        secondary: SiriusColors.surface,
        onSecondary: SiriusColors.heading,
        surface: Colors.white,
        onSurface: SiriusColors.heading,
        error: SiriusColors.error,
        onError: Colors.white,
      ),

      // AppBar teması
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: SiriusColors.heading,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppStyles.heading3.copyWith(
          fontFamily: 'Cormorant',
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: SiriusColors.heading,
        ),
        toolbarHeight: AppDimensions.buttonHeightM,
        iconTheme: IconThemeData(
          color: SiriusColors.heading,
          size: AppDimensions.iconSizeM,
        ),
      ),

      // Card teması
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusL,
        ),
        margin: AppDimensions.marginS,
      ),

      // Buton teması
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppStyles.primaryButton,
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppStyles.secondaryButton,
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SiriusColors.accentDynamic,
          padding: AppDimensions.paddingS,
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusS,
          ),
        ),
      ),

      // Input field teması
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusS,
          borderSide: const BorderSide(color: SiriusColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusS,
          borderSide: const BorderSide(color: SiriusColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusS,
          borderSide: BorderSide(color: SiriusColors.accentDynamic, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusS,
          borderSide: const BorderSide(color: SiriusColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusS,
          borderSide: const BorderSide(color: SiriusColors.error, width: 2),
        ),
        contentPadding: AppDimensions.paddingM,
        labelStyle: AppStyles.inputLabelStyle,
        hintStyle: AppStyles.bodyTextSmall.copyWith(color: Colors.grey),
      ),

      // Dialog teması
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusXL,
        ),
        titleTextStyle: AppStyles.heading3,
        contentTextStyle: AppStyles.bodyText,
      ),

      // Bottom sheet teması
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Snackbar teması
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SiriusColors.surface,
        contentTextStyle: AppStyles.bodyText.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusS,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Divider teması
      dividerTheme: const DividerThemeData(
        color: SiriusColors.border,
        thickness: 1,
        space: 1,
      ),

      // Icon teması
      iconTheme: IconThemeData(
        color: SiriusColors.accent,
        size: AppDimensions.iconSizeM,
      ),

      // Text teması
      textTheme: TextTheme(
        displayLarge: AppStyles.heading1,
        displayMedium: AppStyles.heading2,
        displaySmall: AppStyles.heading3,
        headlineLarge: AppStyles.heading1,
        headlineMedium: AppStyles.heading2,
        headlineSmall: AppStyles.heading3,
        titleLarge: AppStyles.heading4,
        titleMedium: AppStyles.bodyText.copyWith(fontWeight: FontWeight.w600),
        titleSmall: AppStyles.bodyTextSmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: AppStyles.bodyText,
        bodyMedium: AppStyles.bodyText,
        bodySmall: AppStyles.bodyTextSmall,
        labelLarge: AppStyles.bodyText.copyWith(fontWeight: FontWeight.w500),
        labelMedium: AppStyles.bodyTextSmall.copyWith(
          fontWeight: FontWeight.w500,
        ),
        labelSmall: AppStyles.bodyTextTiny.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),

      // Chip teması
      chipTheme: ChipThemeData(
        backgroundColor: SiriusColors.accentDynamic.withValues(alpha: 0.1),
        selectedColor: SiriusColors.accentDynamic,
        labelStyle: AppStyles.bodyTextSmall,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusRound,
        ),
        padding: AppDimensions.paddingS,
      ),

      // Switch teması
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SiriusColors.accentDynamic;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SiriusColors.accentDynamic.withValues(alpha: 0.5);
          }
          return Colors.grey.withValues(alpha: 0.5);
        }),
      ),

      // Checkbox teması
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SiriusColors.accentDynamic;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusXS,
        ),
      ),

      // Radio teması
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SiriusColors.accentDynamic;
          }
          return Colors.grey;
        }),
      ),
    );
  }

  // ===== DARK THEME =====

  /// Koyu tema
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Renk şeması
      colorScheme: ColorScheme.dark(
        primary: SiriusColors.accentDynamic,
        onPrimary: Colors.white,
        secondary: SiriusColors.surface,
        onSecondary: SiriusColors.heading,
        surface: SiriusColors.surface,
        onSurface: SiriusColors.heading,
        error: SiriusColors.error,
        onError: Colors.white,
      ),

      // AppBar teması
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: SiriusColors.heading,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppStyles.heading3.copyWith(
          fontFamily: 'Cormorant',
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: SiriusColors.heading,
        ),
        toolbarHeight: AppDimensions.buttonHeightM,
        iconTheme: IconThemeData(
          color: SiriusColors.heading,
          size: AppDimensions.iconSizeM,
        ),
      ),

      // Card teması
      cardTheme: CardThemeData(
        color: SiriusColors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusL,
        ),
        margin: AppDimensions.marginS,
      ),

      // Buton teması
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppStyles.primaryButton,
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppStyles.secondaryButton,
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SiriusColors.accentDynamic,
          padding: AppDimensions.paddingS,
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusS,
          ),
        ),
      ),

      // Input field teması
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SiriusColors.surface,
        border: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusS,
          borderSide: const BorderSide(color: SiriusColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusS,
          borderSide: const BorderSide(color: SiriusColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusS,
          borderSide: BorderSide(color: SiriusColors.accentDynamic, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusS,
          borderSide: const BorderSide(color: SiriusColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusS,
          borderSide: const BorderSide(color: SiriusColors.error, width: 2),
        ),
        contentPadding: AppDimensions.paddingM,
        labelStyle: AppStyles.inputLabelStyle,
        hintStyle: AppStyles.bodyTextSmall.copyWith(
          color: Colors.grey.shade400,
        ),
      ),

      // Dialog teması
      dialogTheme: DialogThemeData(
        backgroundColor: SiriusColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusXL,
        ),
        titleTextStyle: AppStyles.heading3,
        contentTextStyle: AppStyles.bodyText,
      ),

      // Bottom sheet teması
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: SiriusColors.surface,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Snackbar teması
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SiriusColors.surface,
        contentTextStyle: AppStyles.bodyText.copyWith(
          color: SiriusColors.heading,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusS,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Divider teması
      dividerTheme: const DividerThemeData(
        color: SiriusColors.border,
        thickness: 1,
        space: 1,
      ),

      // Icon teması
      iconTheme: IconThemeData(
        color: SiriusColors.accentDynamic,
        size: AppDimensions.iconSizeM,
      ),

      // Text teması
      textTheme: TextTheme(
        displayLarge: AppStyles.heading1,
        displayMedium: AppStyles.heading2,
        displaySmall: AppStyles.heading3,
        headlineLarge: AppStyles.heading1,
        headlineMedium: AppStyles.heading2,
        headlineSmall: AppStyles.heading3,
        titleLarge: AppStyles.heading4,
        titleMedium: AppStyles.bodyText.copyWith(fontWeight: FontWeight.w600),
        titleSmall: AppStyles.bodyTextSmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: AppStyles.bodyText,
        bodyMedium: AppStyles.bodyText,
        bodySmall: AppStyles.bodyTextSmall,
        labelLarge: AppStyles.bodyText.copyWith(fontWeight: FontWeight.w500),
        labelMedium: AppStyles.bodyTextSmall.copyWith(
          fontWeight: FontWeight.w500,
        ),
        labelSmall: AppStyles.bodyTextTiny.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),

      // Chip teması
      chipTheme: ChipThemeData(
        backgroundColor: SiriusColors.accentDynamic.withValues(alpha: 0.2),
        selectedColor: SiriusColors.accentDynamic,
        labelStyle: AppStyles.bodyTextSmall,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusRound,
        ),
        padding: AppDimensions.paddingS,
      ),

      // Switch teması
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SiriusColors.accentDynamic;
          }
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SiriusColors.accentDynamic.withValues(alpha: 0.5);
          }
          return Colors.grey.shade600;
        }),
      ),

      // Checkbox teması
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SiriusColors.accentDynamic;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusXS,
        ),
      ),

      // Radio teması
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SiriusColors.accentDynamic;
          }
          return Colors.grey.shade400;
        }),
      ),
    );
  }

  // ===== THEME EXTENSIONS =====

  /// Tema uzantıları
  static ThemeExtension get lightThemeExtension => ThemeExtension.light();
  static ThemeExtension get darkThemeExtension => ThemeExtension.dark();
}

/// Tema uzantıları - ek stil özellikleri için
class ThemeExtension {
  final bool isDark;

  ThemeExtension._({required this.isDark});

  factory ThemeExtension.light() => ThemeExtension._(isDark: false);
  factory ThemeExtension.dark() => ThemeExtension._(isDark: true);

  /// Tema rengine göre container dekorasyonu
  BoxDecoration get containerDecoration =>
      isDark ? AppStyles.darkCardDecoration : AppStyles.primaryCardDecoration;

  /// Tema rengine göre dialog dekorasyonu
  BoxDecoration get dialogDecoration =>
      isDark ? AppStyles.darkDialogDecoration : AppStyles.dialogDecoration;

  /// Tema rengine göre arka plan rengi
  Color get backgroundColor =>
      isDark ? SiriusColors.background : const Color(0xFFE5E2DB);

  /// Tema rengine göre yüzey rengi
  Color get surfaceColor => isDark ? SiriusColors.surface : Colors.white;
}
