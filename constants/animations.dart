import 'package:flutter/material.dart';
import 'dart:math';

/// Proje genelinde kullanılan animasyon sabitleri
/// CSS benzeri modüler yapı için tasarlandı
class AppAnimations {
  // Private constructor - bu sınıf sadece static üyeler içerir
  AppAnimations._();

  // ===== DURATION =====

  /// Çok hızlı animasyon
  static const Duration durationXS = Duration(milliseconds: 100);

  /// Hızlı animasyon
  static const Duration durationS = Duration(milliseconds: 200);

  /// Orta hızda animasyon
  static const Duration durationM = Duration(milliseconds: 300);

  /// Yavaş animasyon
  static const Duration durationL = Duration(milliseconds: 500);

  /// Çok yavaş animasyon
  static const Duration durationXL = Duration(milliseconds: 800);

  /// Ekstra yavaş animasyon
  static const Duration durationXXL = Duration(milliseconds: 1200);

  // ===== CURVES =====

  /// Standart animasyon eğrisi
  static const Curve curveStandard = Curves.easeInOut;

  /// Yumuşak animasyon eğrisi
  static const Curve curveSmooth = Curves.easeOutCubic;

  /// Elastik animasyon eğrisi
  static const Curve curveElastic = Curves.elasticOut;

  /// Bounce animasyon eğrisi
  static const Curve curveBounce = Curves.bounceOut;

  /// Hızlı başlangıç animasyon eğrisi
  static const Curve curveFastStart = Curves.easeIn;

  /// Hızlı bitiş animasyon eğrisi
  static const Curve curveFastEnd = Curves.easeOut;

  /// Linear animasyon eğrisi
  static const Curve curveLinear = Curves.linear;

  // ===== ANIMATION BUILDER HELPERS =====

  /// Fade in animasyonu
  static Widget fadeIn({
    required Widget child,
    Duration? duration,
    Curve? curve,
    VoidCallback? onEnd,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: curve ?? curveStandard,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      onEnd: onEnd,
      child: child,
    );
  }

  /// Slide in animasyonu (yukarıdan)
  static Widget slideInFromTop({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double offset = 50.0,
    VoidCallback? onEnd,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: curve ?? curveStandard,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, offset * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      onEnd: onEnd,
      child: child,
    );
  }

  /// Slide in animasyonu (aşağıdan)
  static Widget slideInFromBottom({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double offset = 50.0,
    VoidCallback? onEnd,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: curve ?? curveStandard,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -offset * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      onEnd: onEnd,
      child: child,
    );
  }

  /// Slide in animasyonu (soldan)
  static Widget slideInFromLeft({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double offset = 50.0,
    VoidCallback? onEnd,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: curve ?? curveStandard,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(-offset * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      onEnd: onEnd,
      child: child,
    );
  }

  /// Slide in animasyonu (sağdan)
  static Widget slideInFromRight({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double offset = 50.0,
    VoidCallback? onEnd,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: curve ?? curveStandard,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(offset * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      onEnd: onEnd,
      child: child,
    );
  }

  /// Scale animasyonu
  static Widget scaleIn({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double startScale = 0.5,
    VoidCallback? onEnd,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: startScale, end: 1.0),
      curve: curve ?? curveStandard,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(opacity: value, child: child),
        );
      },
      onEnd: onEnd,
      child: child,
    );
  }

  /// Rotate animasyonu
  static Widget rotateIn({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double startRotation = 0.0,
    double endRotation = 1.0,
    VoidCallback? onEnd,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationL,
      tween: Tween(begin: startRotation, end: endRotation),
      curve: curve ?? curveStandard,
      builder: (context, value, child) {
        return Transform.rotate(angle: value * 2 * 3.14159, child: child);
      },
      onEnd: onEnd,
      child: child,
    );
  }

  /// Staggered animasyon (sırayla görünme)
  static Widget staggered({
    required List<Widget> children,
    Duration? duration,
    Curve? curve,
    Duration? delay,
    VoidCallback? onEnd,
  }) {
    return Column(
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        final animationDelay = delay ?? durationS;

        return TweenAnimationBuilder<double>(
          duration: duration ?? durationM,
          tween: Tween(begin: 0.0, end: 1.0),
          curve: curve ?? curveStandard,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          onEnd: index == children.length - 1 ? onEnd : null,
          child: FutureBuilder(
            future: Future.delayed(animationDelay * index),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return child;
              }
              return const SizedBox.shrink();
            },
          ),
        );
      }).toList(),
    );
  }

  // ===== PAGE TRANSITIONS =====

  /// Sayfa geçiş animasyonu (slide)
  static PageRouteBuilder<T> slidePageRoute<T>({
    required Widget page,
    RouteSettings? settings,
    Duration? duration,
    Curve? curve,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: duration ?? durationM,
    );
  }

  /// Sayfa geçiş animasyonu (fade)
  static PageRouteBuilder<T> fadePageRoute<T>({
    required Widget page,
    RouteSettings? settings,
    Duration? duration,
    Curve? curve,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: duration ?? durationM,
    );
  }

  /// Sayfa geçiş animasyonu (scale)
  static PageRouteBuilder<T> scalePageRoute<T>({
    required Widget page,
    RouteSettings? settings,
    Duration? duration,
    Curve? curve,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(scale: animation, child: child);
      },
      transitionDuration: duration ?? durationM,
    );
  }

  // ===== ANIMATION CONTROLLERS =====

  /// Animasyon controller oluşturur
  static AnimationController createController({
    required TickerProvider vsync,
    Duration? duration,
    VoidCallback? onEnd,
  }) {
    final controller = AnimationController(
      duration: duration ?? durationM,
      vsync: vsync,
    );

    if (onEnd != null) {
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          onEnd();
        }
      });
    }

    return controller;
  }

  /// Animasyon controller'ı dispose eder
  static void disposeController(AnimationController? controller) {
    controller?.dispose();
  }

  // ===== UTILITY METHODS =====

  /// Animasyon süresini responsive hale getirir
  static Duration getResponsiveDuration(
    BuildContext context,
    Duration baseDuration,
  ) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      // Mobil - daha hızlı animasyon
      return Duration(
        milliseconds: (baseDuration.inMilliseconds * 0.7).round(),
      );
    } else if (width < 900) {
      // Tablet - normal animasyon
      return baseDuration;
    } else {
      // Desktop - daha yavaş animasyon
      return Duration(
        milliseconds: (baseDuration.inMilliseconds * 1.3).round(),
      );
    }
  }

  /// Animasyon eğrisini responsive hale getirir
  static Curve getResponsiveCurve(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      // Mobil - daha basit eğri
      return curveStandard;
    } else {
      // Tablet/Desktop - daha karmaşık eğri
      return curveSmooth;
    }
  }

  // ===== BUTTON INTERACTION ANIMATIONS =====

  /// Buton tıklama animasyonu (scale down)
  static Widget buttonPress({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double pressScale = 0.95,
    VoidCallback? onTap,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationXS,
      tween: Tween(begin: 1.0, end: pressScale),
      curve: curve ?? curveFastStart,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(onTapDown: (_) => onTap?.call(), child: child),
        );
      },
      child: child,
    );
  }

  /// Hover animasyonu (scale up)
  static Widget buttonHover({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double hoverScale = 1.05,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationS,
      tween: Tween(begin: 1.0, end: hoverScale),
      curve: curve ?? curveSmooth,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: child,
    );
  }

  /// Smooth color transition
  static Widget colorTransition({
    required Widget child,
    required Color fromColor,
    required Color toColor,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<Color?>(
      duration: duration ?? durationM,
      tween: ColorTween(begin: fromColor, end: toColor),
      curve: curve ?? curveStandard,
      builder: (context, color, child) {
        return Container(color: color ?? fromColor, child: child);
      },
      child: child,
    );
  }

  /// Smooth height transition
  static Widget heightTransition({
    required Widget child,
    required double fromHeight,
    required double toHeight,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: fromHeight, end: toHeight),
      curve: curve ?? curveSmooth,
      builder: (context, height, child) {
        return AnimatedContainer(
          duration: Duration.zero,
          height: height,
          child: child,
        );
      },
      child: child,
    );
  }

  /// Smooth width transition
  static Widget widthTransition({
    required Widget child,
    required double fromWidth,
    required double toWidth,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: fromWidth, end: toWidth),
      curve: curve ?? curveSmooth,
      builder: (context, width, child) {
        return AnimatedContainer(
          duration: Duration.zero,
          width: width,
          child: child,
        );
      },
      child: child,
    );
  }

  /// Smooth border radius transition
  static Widget borderRadiusTransition({
    required Widget child,
    required BorderRadius fromRadius,
    required BorderRadius toRadius,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<BorderRadius>(
      duration: duration ?? durationM,
      tween: Tween(begin: fromRadius, end: toRadius),
      curve: curve ?? curveSmooth,
      builder: (context, radius, child) {
        return ClipRRect(borderRadius: radius, child: child);
      },
      child: child,
    );
  }

  /// Smooth shadow transition
  static Widget shadowTransition({
    required Widget child,
    required List<BoxShadow> fromShadows,
    required List<BoxShadow> toShadows,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<List<BoxShadow>>(
      duration: duration ?? durationM,
      tween: Tween(begin: fromShadows, end: toShadows),
      curve: curve ?? curveSmooth,
      builder: (context, shadows, child) {
        return Container(
          decoration: BoxDecoration(boxShadow: shadows),
          child: child,
        );
      },
      child: child,
    );
  }

  /// Smooth elevation transition (Material)
  static Widget elevationTransition({
    required Widget child,
    required double fromElevation,
    required double toElevation,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: fromElevation, end: toElevation),
      curve: curve ?? curveSmooth,
      builder: (context, elevation, child) {
        return Material(elevation: elevation, child: child);
      },
      child: child,
    );
  }

  /// Smooth opacity transition
  static Widget opacityTransition({
    required Widget child,
    required double fromOpacity,
    required double toOpacity,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: fromOpacity, end: toOpacity),
      curve: curve ?? curveSmooth,
      builder: (context, opacity, child) {
        return Opacity(opacity: opacity, child: child);
      },
      child: child,
    );
  }

  /// Smooth rotation transition
  static Widget rotationTransition({
    required Widget child,
    required double fromAngle,
    required double toAngle,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: fromAngle, end: toAngle),
      curve: curve ?? curveSmooth,
      builder: (context, angle, child) {
        return Transform.rotate(angle: angle, child: child);
      },
      child: child,
    );
  }

  /// Smooth position transition
  static Widget positionTransition({
    required Widget child,
    required Offset fromOffset,
    required Offset toOffset,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<Offset>(
      duration: duration ?? durationM,
      tween: Tween(begin: fromOffset, end: toOffset),
      curve: curve ?? curveSmooth,
      builder: (context, offset, child) {
        return Transform.translate(offset: offset, child: child);
      },
      child: child,
    );
  }

  /// Smooth text style transition
  static Widget textStyleTransition({
    required Widget child,
    required TextStyle fromStyle,
    required TextStyle toStyle,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<TextStyle>(
      duration: duration ?? durationM,
      tween: TextStyleTween(begin: fromStyle, end: toStyle),
      curve: curve ?? curveSmooth,
      builder: (context, style, child) {
        return DefaultTextStyle(style: style, child: child!);
      },
      child: child,
    );
  }

  // ===== MICRO-INTERACTIONS =====

  /// Ripple effect animasyonu
  static Widget rippleEffect({
    required Widget child,
    required Color rippleColor,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationS,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: curve ?? curveFastEnd,
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: rippleColor.withValues(alpha: (1 - value) * 0.3),
          ),
          child: child,
        );
      },
      child: child,
    );
  }

  /// Pulse animasyonu
  static Widget pulse({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double maxScale = 1.1,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationL,
      tween: Tween(begin: 1.0, end: maxScale),
      curve: curve ?? curveElastic,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: child,
    );
  }

  /// Bounce animasyonu
  static Widget bounce({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double bounceHeight = 20.0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: curve ?? curveBounce,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -bounceHeight * value),
          child: child,
        );
      },
      child: child,
    );
  }

  /// Shake animasyonu
  static Widget shake({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double shakeIntensity = 10.0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: curve ?? curveElastic,
      builder: (context, value, child) {
        final shake = sin(value * 10) * shakeIntensity * (1 - value);
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: child,
    );
  }

  /// Wiggle animasyonu
  static Widget wiggle({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double wiggleAngle = 5.0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration ?? durationM,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: curve ?? curveElastic,
      builder: (context, value, child) {
        final wiggle = sin(value * 8) * wiggleAngle * (1 - value);
        return Transform.rotate(
          angle: wiggle * 0.0174533, // Convert to radians
          child: child,
        );
      },
      child: child,
    );
  }
}
