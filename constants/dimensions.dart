import 'package:flutter/material.dart';

/// Proje genelinde kullanılan boyut sabitleri
/// CSS benzeri modüler yapı için tasarlandı
class AppDimensions {
  // Private constructor - bu sınıf sadece static üyeler içerir
  AppDimensions._();

  // ===== SPACING =====

  /// Çok küçük boşluk
  static const double spacingXS = 4.0;

  /// Küçük boşluk
  static const double spacingS = 8.0;

  /// Orta boşluk
  static const double spacingM = 16.0;

  /// Büyük boşluk
  static const double spacingL = 24.0;

  /// Çok büyük boşluk
  static const double spacingXL = 32.0;

  /// Ekstra büyük boşluk
  static const double spacingXXL = 48.0;

  // ===== PADDING =====

  /// Çok küçük padding
  static const EdgeInsets paddingXS = EdgeInsets.all(spacingXS);

  /// Küçük padding
  static const EdgeInsets paddingS = EdgeInsets.all(spacingS);

  /// Orta padding
  static const EdgeInsets paddingM = EdgeInsets.all(spacingM);

  /// Büyük padding
  static const EdgeInsets paddingL = EdgeInsets.all(spacingL);

  /// Çok büyük padding
  static const EdgeInsets paddingXL = EdgeInsets.all(spacingXL);

  /// Ekstra büyük padding
  static const EdgeInsets paddingXXL = EdgeInsets.all(spacingXXL);

  // ===== MARGIN =====

  /// Çok küçük margin
  static const EdgeInsets marginXS = EdgeInsets.all(spacingXS);

  /// Küçük margin
  static const EdgeInsets marginS = EdgeInsets.all(spacingS);

  /// Orta margin
  static const EdgeInsets marginM = EdgeInsets.all(spacingM);

  /// Büyük margin
  static const EdgeInsets marginL = EdgeInsets.all(spacingL);

  /// Çok büyük margin
  static const EdgeInsets marginXL = EdgeInsets.all(spacingXL);

  /// Ekstra büyük margin
  static const EdgeInsets marginXXL = EdgeInsets.all(spacingXXL);

  // ===== HORIZONTAL SPACING =====

  /// Yatay çok küçük boşluk
  static const EdgeInsets horizontalPaddingXS = EdgeInsets.symmetric(
    horizontal: spacingXS,
  );

  /// Yatay küçük boşluk
  static const EdgeInsets horizontalPaddingS = EdgeInsets.symmetric(
    horizontal: spacingS,
  );

  /// Yatay orta boşluk
  static const EdgeInsets horizontalPaddingM = EdgeInsets.symmetric(
    horizontal: spacingM,
  );

  /// Yatay büyük boşluk
  static const EdgeInsets horizontalPaddingL = EdgeInsets.symmetric(
    horizontal: spacingL,
  );

  /// Yatay çok büyük boşluk
  static const EdgeInsets horizontalPaddingXL = EdgeInsets.symmetric(
    horizontal: spacingXL,
  );

  // ===== VERTICAL SPACING =====

  /// Dikey çok küçük boşluk
  static const EdgeInsets verticalPaddingXS = EdgeInsets.symmetric(
    vertical: spacingXS,
  );

  /// Dikey küçük boşluk
  static const EdgeInsets verticalPaddingS = EdgeInsets.symmetric(
    vertical: spacingS,
  );

  /// Dikey orta boşluk
  static const EdgeInsets verticalPaddingM = EdgeInsets.symmetric(
    vertical: spacingM,
  );

  /// Dikey büyük boşluk
  static const EdgeInsets verticalPaddingL = EdgeInsets.symmetric(
    vertical: spacingL,
  );

  /// Dikey çok büyük boşluk
  static const EdgeInsets verticalPaddingXL = EdgeInsets.symmetric(
    vertical: spacingXL,
  );

  // ===== BORDER RADIUS =====

  /// Çok küçük border radius
  static const double radiusXS = 4.0;

  /// Küçük border radius
  static const double radiusS = 8.0;

  /// Orta border radius
  static const double radiusM = 12.0;

  /// Büyük border radius
  static const double radiusL = 16.0;

  /// Çok büyük border radius
  static const double radiusXL = 20.0;

  /// Ekstra büyük border radius
  static const double radiusXXL = 24.0;

  /// Yuvarlak border radius
  static const double radiusRound = 50.0;

  /// Yuvarlak border radius objesi
  static const BorderRadius borderRadiusRound = BorderRadius.all(
    Radius.circular(radiusRound),
  );

  // ===== BORDER RADIUS OBJECTS =====

  /// Çok küçük border radius
  static const BorderRadius borderRadiusXS = BorderRadius.all(
    Radius.circular(radiusXS),
  );

  /// Küçük border radius
  static const BorderRadius borderRadiusS = BorderRadius.all(
    Radius.circular(radiusS),
  );

  /// Orta border radius
  static const BorderRadius borderRadiusM = BorderRadius.all(
    Radius.circular(radiusM),
  );

  /// Büyük border radius
  static const BorderRadius borderRadiusL = BorderRadius.all(
    Radius.circular(radiusL),
  );

  /// Çok büyük border radius
  static const BorderRadius borderRadiusXL = BorderRadius.all(
    Radius.circular(radiusXL),
  );

  /// Ekstra büyük border radius
  static const BorderRadius borderRadiusXXL = BorderRadius.all(
    Radius.circular(radiusXXL),
  );

  // ===== ICON SIZES =====

  /// Çok küçük ikon boyutu
  static const double iconSizeXS = 16.0;

  /// Küçük ikon boyutu
  static const double iconSizeS = 20.0;

  /// Orta ikon boyutu
  static const double iconSizeM = 24.0;

  /// Büyük ikon boyutu
  static const double iconSizeL = 32.0;

  /// Çok büyük ikon boyutu
  static const double iconSizeXL = 48.0;

  /// Ekstra büyük ikon boyutu
  static const double iconSizeXXL = 64.0;

  // ===== BUTTON SIZES =====

  /// Küçük buton yüksekliği
  static const double buttonHeightS = 36.0;

  /// Orta buton yüksekliği
  static const double buttonHeightM = 48.0;

  /// Büyük buton yüksekliği
  static const double buttonHeightL = 56.0;

  /// Çok büyük buton yüksekliği
  static const double buttonHeightXL = 64.0;

  // ===== INPUT FIELD SIZES =====

  /// Input field yüksekliği
  static const double inputHeight = 48.0;

  /// Input field yüksekliği (büyük)
  static const double inputHeightL = 56.0;

  // ===== CARD SIZES =====

  /// Kart yüksekliği (küçük)
  static const double cardHeightS = 80.0;

  /// Kart yüksekliği (orta)
  static const double cardHeightM = 120.0;

  /// Kart yüksekliği (büyük)
  static const double cardHeightL = 160.0;

  // ===== SHADOW VALUES =====

  /// Çok küçük gölge blur
  static const double shadowBlurXS = 2.0;

  /// Küçük gölge blur
  static const double shadowBlurS = 4.0;

  /// Orta gölge blur
  static const double shadowBlurM = 8.0;

  /// Büyük gölge blur
  static const double shadowBlurL = 16.0;

  /// Çok büyük gölge blur
  static const double shadowBlurXL = 24.0;

  /// Çok küçük gölge offset
  static const double shadowOffsetXS = 1.0;

  /// Küçük gölge offset
  static const double shadowOffsetS = 2.0;

  /// Orta gölge offset
  static const double shadowOffsetM = 4.0;

  /// Büyük gölge offset
  static const double shadowOffsetL = 8.0;

  /// Çok büyük gölge offset
  static const double shadowOffsetXL = 12.0;

  // ===== ANIMATION DURATIONS =====

  /// Çok hızlı animasyon
  static const Duration animationDurationXS = Duration(milliseconds: 100);

  /// Hızlı animasyon
  static const Duration animationDurationS = Duration(milliseconds: 200);

  /// Orta hızda animasyon
  static const Duration animationDurationM = Duration(milliseconds: 300);

  /// Yavaş animasyon
  static const Duration animationDurationL = Duration(milliseconds: 500);

  /// Çok yavaş animasyon
  static const Duration animationDurationXL = Duration(milliseconds: 800);

  // ===== RESPONSIVE BREAKPOINTS =====

  /// Çok küçük mobil breakpoint (iPhone SE, küçük Android)
  static const double tinyMobileBreakpoint = 320.0;
  
  /// Küçük mobil breakpoint (iPhone 12 mini, Samsung Galaxy S21)
  static const double smallMobileBreakpoint = 375.0;
  
  /// Orta mobil breakpoint (iPhone 12, Samsung Galaxy S21+)
  static const double mediumMobileBreakpoint = 414.0;
  
  /// Büyük mobil breakpoint (iPhone 12 Pro Max, Samsung Galaxy S21 Ultra)
  static const double largeMobileBreakpoint = 428.0;
  
  /// Mobil breakpoint (eski)
  static const double mobileBreakpoint = 600.0;

  /// Tablet breakpoint
  static const double tabletBreakpoint = 900.0;

  /// Desktop breakpoint
  static const double desktopBreakpoint = 1200.0;

  // ===== UTILITY METHODS =====

  /// Responsive padding döndürür
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width <= tinyMobileBreakpoint) {
      return paddingXS; // 4px
    } else if (width <= smallMobileBreakpoint) {
      return paddingS; // 8px
    } else if (width <= mediumMobileBreakpoint) {
      return paddingM; // 16px
    } else if (width <= largeMobileBreakpoint) {
      return paddingL; // 24px
    } else if (width < mobileBreakpoint) {
      return paddingL; // 24px
    } else if (width < tabletBreakpoint) {
      return paddingL; // 24px
    } else {
      return paddingXL; // 32px
    }
  }

  /// Responsive margin döndürür
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width <= tinyMobileBreakpoint) {
      return marginXS; // 4px
    } else if (width <= smallMobileBreakpoint) {
      return marginS; // 8px
    } else if (width <= mediumMobileBreakpoint) {
      return marginM; // 16px
    } else if (width <= largeMobileBreakpoint) {
      return marginL; // 24px
    } else if (width < mobileBreakpoint) {
      return marginL; // 24px
    } else if (width < tabletBreakpoint) {
      return marginL; // 24px
    } else {
      return marginXL; // 32px
    }
  }

  /// Responsive border radius döndürür
  static double getResponsiveRadius(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width <= tinyMobileBreakpoint) {
      return radiusS; // 8px
    } else if (width <= smallMobileBreakpoint) {
      return radiusM; // 12px
    } else if (width <= mediumMobileBreakpoint) {
      return radiusM; // 12px
    } else if (width <= largeMobileBreakpoint) {
      return radiusL; // 16px
    } else if (width < mobileBreakpoint) {
      return radiusL; // 16px
    } else if (width < tabletBreakpoint) {
      return radiusL; // 16px
    } else {
      return radiusXL; // 20px
    }
  }

  /// Responsive font boyutu döndürür
  static double getResponsiveFontSize(BuildContext context, {
    double tiny = 10.0,
    double small = 12.0,
    double medium = 14.0,
    double large = 16.0,
    double xlarge = 18.0,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width <= tinyMobileBreakpoint) return tiny;
    if (width <= smallMobileBreakpoint) return small;
    if (width <= mediumMobileBreakpoint) return medium;
    if (width <= largeMobileBreakpoint) return large;
    if (width < mobileBreakpoint) return large;
    if (width < tabletBreakpoint) return xlarge;
    return xlarge;
  }

  /// Responsive icon boyutu döndürür
  static double getResponsiveIconSize(BuildContext context, {
    double tiny = 16.0,
    double small = 20.0,
    double medium = 24.0,
    double large = 32.0,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width <= tinyMobileBreakpoint) return tiny;
    if (width <= smallMobileBreakpoint) return small;
    if (width <= mediumMobileBreakpoint) return medium;
    if (width <= largeMobileBreakpoint) return medium;
    if (width < mobileBreakpoint) return large;
    return large;
  }

  /// Responsive button yüksekliği döndürür
  static double getResponsiveButtonHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width <= tinyMobileBreakpoint) return buttonHeightS; // 36px
    if (width <= smallMobileBreakpoint) return buttonHeightS; // 36px
    if (width <= mediumMobileBreakpoint) return buttonHeightM; // 48px
    if (width <= largeMobileBreakpoint) return buttonHeightM; // 48px
    if (width < mobileBreakpoint) return buttonHeightL; // 56px
    return buttonHeightL; // 56px
  }

  /// Responsive input yüksekliği döndürür
  static double getResponsiveInputHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width <= tinyMobileBreakpoint) return inputHeight; // 48px
    if (width <= smallMobileBreakpoint) return inputHeight; // 48px
    if (width <= mediumMobileBreakpoint) return inputHeight; // 48px
    if (width <= largeMobileBreakpoint) return inputHeightL; // 56px
    if (width < mobileBreakpoint) return inputHeightL; // 56px
    return inputHeightL; // 56px
  }

  /// Responsive card yüksekliği döndürür
  static double getResponsiveCardHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width <= tinyMobileBreakpoint) return cardHeightS; // 80px
    if (width <= smallMobileBreakpoint) return cardHeightS; // 80px
    if (width <= mediumMobileBreakpoint) return cardHeightM; // 120px
    if (width <= largeMobileBreakpoint) return cardHeightM; // 120px
    if (width < mobileBreakpoint) return cardHeightL; // 160px
    return cardHeightL; // 160px
  }

  /// Responsive drawer genişliği döndürür
  static double getResponsiveDrawerWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width <= tinyMobileBreakpoint) return 200.0;
    if (width <= smallMobileBreakpoint) return 220.0;
    if (width <= mediumMobileBreakpoint) return 240.0;
    if (width <= largeMobileBreakpoint) return 250.0;
    if (width < mobileBreakpoint) return 250.0;
    return 250.0;
  }

  /// Responsive grid sütun sayısı döndürür
  static int getResponsiveGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width <= tinyMobileBreakpoint) return 1;
    if (width <= smallMobileBreakpoint) return 1;
    if (width <= mediumMobileBreakpoint) return 1;
    if (width <= largeMobileBreakpoint) return 1;
    if (width < mobileBreakpoint) return 2;
    if (width < tabletBreakpoint) return 3;
    return 4;
  }

  /// Responsive spacing döndürür
  static double getResponsiveSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width <= tinyMobileBreakpoint) return spacingXS; // 4px
    if (width <= smallMobileBreakpoint) return spacingS; // 8px
    if (width <= mediumMobileBreakpoint) return spacingM; // 16px
    if (width <= largeMobileBreakpoint) return spacingM; // 16px
    if (width < mobileBreakpoint) return spacingL; // 24px
    return spacingL; // 24px
  }
}
