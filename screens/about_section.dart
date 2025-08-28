import 'package:flutter/material.dart';
import 'package:hairsalon_flutter/constants/colors.dart';
import 'package:hairsalon_flutter/constants/dimensions.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class AboutSection extends StatefulWidget {
  const AboutSection({super.key});

  @override
  State<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<AboutSection> {
  final bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Responsive tasarım için ekran boyutlarını al
    final lang = Provider.of<LanguageProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTinyMobile = screenWidth <= AppDimensions.tinyMobileBreakpoint;
    final isSmallMobile = screenWidth <= AppDimensions.smallMobileBreakpoint;

    return InkWell(
      onTap: () {
        // Add tap functionality if needed
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: AppDimensions.getResponsivePadding(context),
        decoration: BoxDecoration(
          color: _isHovered
              ? Colors.black.withValues(alpha: 0.1) // hover efekti
              : SiriusColors.surface,
          borderRadius: BorderRadius.circular(
            AppDimensions.getResponsiveRadius(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Text(
              lang.t('about_us'),
              style: TextStyle(
                color: SiriusColors.heading,
                fontSize: AppDimensions.getResponsiveFontSize(
                  context,
                  tiny: 20,
                  small: 22,
                  medium: 24,
                  large: 26,
                  xlarge: 28,
                ),
                fontWeight: FontWeight.bold,
                fontFamily: 'Playfair Display',
              ),
            ),
            SizedBox(height: AppDimensions.getResponsiveSpacing(context)),

            // Yazı ve resim - Responsive layout
            if (screenWidth > AppDimensions.mobileBreakpoint)
              // Desktop/Tablet layout
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tüm yazılar solda
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.t('about_description'),
                          style: TextStyle(
                            color: SiriusColors.defaultText,
                            fontSize: AppDimensions.getResponsiveFontSize(
                              context,
                              tiny: 12,
                              small: 13,
                              medium: 14,
                              large: 15,
                              xlarge: 16,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: AppDimensions.getResponsiveSpacing(context),
                        ),

                        // Feature kartlar (Why Us section) - Responsive grid
                        _buildResponsiveFeatureGrid(
                          context,
                          isTinyMobile,
                          isSmallMobile,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: AppDimensions.getResponsiveSpacing(context)),

                  // Resim sağda
                  Expanded(
                    flex: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.getResponsiveRadius(context),
                      ),
                      child: Image.asset(
                        'assets/salon/model.jpg',
                        fit: BoxFit.cover,
                        height: screenWidth <= AppDimensions.tabletBreakpoint
                            ? 200
                            : 300,
                      ),
                    ),
                  ),
                ],
              )
            else
              // Mobile layout
              Column(
                children: [
                  Text(
                    lang.t('about_description'),
                    style: TextStyle(
                      color: SiriusColors.defaultText,
                      fontSize: AppDimensions.getResponsiveFontSize(
                        context,
                        tiny: 12,
                        small: 13,
                        medium: 14,
                        large: 15,
                        xlarge: 16,
                      ),
                    ),
                  ),
                  SizedBox(height: AppDimensions.getResponsiveSpacing(context)),

                  // Resim üstte
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.getResponsiveRadius(context),
                    ),
                    child: Image.asset(
                      'assets/salon/model.jpg',
                      fit: BoxFit.cover,
                      height: 200,
                      width: double.infinity,
                    ),
                  ),
                  SizedBox(height: AppDimensions.getResponsiveSpacing(context)),

                  // Feature kartlar (Why Us section) - Mobile grid
                  _buildResponsiveFeatureGrid(
                    context,
                    isTinyMobile,
                    isSmallMobile,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveFeatureGrid(
    BuildContext context,
    bool isTinyMobile,
    bool isSmallMobile,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = AppDimensions.getResponsiveGridColumns(context);

    // Feature kartlar
    final items = [
      {
        'num': '01',
        'title': 'Where Beauty Meets Serenity',
        'desc':
            'At Sirius, we create a peaceful escape from the hustle of daily life. Our tranquil atmosphere and expert care are designed to help you relax, rejuvenate, and rediscover your inner calm.',
        'icon': Icons.spa,
      },
      {
        'num': '02',
        'title': 'Your Beauty, Our Galaxy',
        'desc':
            'You are at the center of everything we do. Our personalized treatments celebrate your unique beauty, enhancing your natural radiance with the finest products and techniques.',
        'icon': Icons.star,
      },
      {
        'num': '03',
        'title': 'Glow Beyond the Stars with Sirius',
        'desc':
            'We go beyond ordinary beauty care to make you feel extraordinary. At Sirius, every treatment is crafted to leave you glowing with confidence, inside and out.',
        'icon': Icons.auto_awesome,
      },
    ];

    if (screenWidth <= AppDimensions.mobileBreakpoint) {
      // Mobile: Column layout
      return Column(
        children: items
            .map(
              (it) => _buildFeatureCard(
                number: it['num'] as String,
                title: it['title'] as String,
                description: it['desc'] as String,
                icon: it['icon'] as IconData,
                isDarkMode: false,
                context: context,
              ),
            )
            .toList(),
      );
    } else {
      // Desktop/Tablet: Grid layout
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.2,
          crossAxisSpacing: AppDimensions.getResponsiveSpacing(context),
          mainAxisSpacing: AppDimensions.getResponsiveSpacing(context),
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final it = items[index];
          return _buildFeatureCard(
            number: it['num'] as String,
            title: it['title'] as String,
            description: it['desc'] as String,
            icon: it['icon'] as IconData,
            isDarkMode: false,
            context: context,
          );
        },
      );
    }
  }

  Widget _buildFeatureCard({
    required String number,
    required String title,
    required String description,
    required IconData icon,
    required bool isDarkMode,
    required BuildContext context,
  }) {
    return Container(
      padding: AppDimensions.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.black.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(
          AppDimensions.getResponsiveRadius(context),
        ),
        border: Border.all(
          color: SiriusColors.accent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  AppDimensions.getResponsiveSpacing(context) / 2,
                ),
                decoration: BoxDecoration(
                  color: SiriusColors.accent,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.getResponsiveRadius(context),
                  ),
                ),
                child: Text(
                  number,
                  style: TextStyle(
                    color: SiriusColors.contrast,
                    fontWeight: FontWeight.bold,
                    fontSize: AppDimensions.getResponsiveFontSize(
                      context,
                      tiny: 10,
                      small: 11,
                      medium: 12,
                      large: 13,
                      xlarge: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppDimensions.getResponsiveSpacing(context)),
              Icon(
                icon,
                color: SiriusColors.accent,
                size: AppDimensions.getResponsiveIconSize(context),
              ),
            ],
          ),
          SizedBox(height: AppDimensions.getResponsiveSpacing(context)),
          Text(
            title,
            style: TextStyle(
              color: SiriusColors.heading,
              fontSize: AppDimensions.getResponsiveFontSize(
                context,
                tiny: 14,
                small: 15,
                medium: 16,
                large: 17,
                xlarge: 18,
              ),
              fontWeight: FontWeight.bold,
              fontFamily: 'Playfair Display',
            ),
          ),
          SizedBox(height: AppDimensions.getResponsiveSpacing(context) / 2),
          Text(
            description,
            style: TextStyle(
              color: SiriusColors.defaultText,
              fontSize: AppDimensions.getResponsiveFontSize(
                context,
                tiny: 10,
                small: 11,
                medium: 12,
                large: 13,
                xlarge: 14,
              ),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
