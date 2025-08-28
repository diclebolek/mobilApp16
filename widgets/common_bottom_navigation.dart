import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:hairsalon_flutter/constants/colors.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

// Ortak Bottom Navigation Bar Widget'ı - Güçlü camsı efekt ve floating tasarım
class CommonBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onRandevuTap;

  const CommonBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onRandevuTap,
  });

  @override
  Widget build(BuildContext context) {
    // Web'de navbar'ı gizle
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Tablet ve büyük ekranlarda navbar'ı gizle
    if (screenWidth > 768) {
      return const SizedBox.shrink();
    }

    final lang = Provider.of<LanguageProvider>(context);
    return Container(
      height: 76, // Biraz küçült - overflow'u azalt
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ana bottom navigation bar - camsız, tamamen şeffaf overlay
          Positioned(
            bottom: 8,
            left: 16,
            right: 16,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.black.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(
                          0,
                          Icons.home_rounded,
                          lang.t('home_title'),
                          isDarkMode,
                        ),
                        const SizedBox(width: 56), // Orta boşluk (FAB için)
                        _buildNavItem(
                          1,
                          Icons.person_rounded,
                          lang.t('profile_title'),
                          isDarkMode,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // FAB - Randevu butonu (Profesyonel gradient)
          Positioned(
            top: -6,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onRandevuTap,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [SiriusColors.accent, SiriusColors.accent2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SiriusColors.accent.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    bool isDarkMode,
  ) {
    final isActive = currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // İkon container - Profesyonel aktif durum
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isActive
                        ? SiriusColors.accent.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: isActive
                          ? SiriusColors.accent.withValues(alpha: 0.4)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: SiriusColors.accent.withValues(
                                alpha: 0.15,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    scale: isActive ? 1.08 : 1.0,
                    child: Icon(
                      icon,
                      color: isActive
                          ? SiriusColors.accent
                          : isDarkMode
                          ? Colors.grey[400]
                          : Colors.grey[600],
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                // Label - Profesyonel tipografi
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: isActive
                        ? SiriusColors.accent
                        : isDarkMode
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    fontSize: 8.5,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: 0.3,
                    height: 1.1,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
