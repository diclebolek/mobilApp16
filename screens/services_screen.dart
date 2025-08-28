import 'package:flutter/material.dart';
import '../models/service.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../services/db_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<Service> _services = [];
  bool _isLoading = true;
  String? _error;

  // Dil seçeneği
  String _selectedLanguage = 'tr';

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final services = await DbService.getServices();

      setState(() {
        _services = services;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Hizmetler yüklenirken hata oluştu: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: SiriusColors.background,

      appBar: AppBar(
        title: Text(
          lang.t('our_services'),
          style: TextStyle(
            color: SiriusColors.heading,
            fontFamily: 'Playfair Display',
            fontSize: AppDimensions.getResponsiveFontSize(
              context,
              tiny: 16,
              small: 18,
              medium: 20,
              large: 22,
              xlarge: 24,
            ),
          ),
        ),
        backgroundColor: SiriusColors.surface,
        foregroundColor: SiriusColors.heading,
        toolbarHeight: AppDimensions.getResponsiveButtonHeight(context),
        actions: [
          // Dil Seçimi
          PopupMenuButton<String>(
            icon: Icon(
              Icons.language,
              color: SiriusColors.heading,
              size: AppDimensions.getResponsiveIconSize(context),
            ),
            onSelected: (String value) {
              if (value == 'tr') {
                lang.setLanguage(AppLanguage.tr);
              } else if (value == 'en') {
                lang.setLanguage(AppLanguage.en);
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'tr',
                child: Row(
                  children: [
                    Text('🇹🇷 ${lang.t('turkish')}'),
                    if (lang.isTurkish)
                      Icon(Icons.check, color: SiriusColors.accent),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'en',
                child: Row(
                  children: [
                    Text('🇺🇸 ${lang.t('english')}'),
                    if (lang.isEnglish)
                      Icon(Icons.check, color: SiriusColors.accent),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: AppDimensions.getResponsiveIconSize(context),
            ),
            onPressed: _loadServices,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: kIsWeb ? null : null,
    );
  }

  Widget _buildBody() {
    final lang = Provider.of<LanguageProvider>(context);
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: SiriusColors.accent),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: AppDimensions.getResponsiveIconSize(
                context,
                tiny: 48,
                small: 56,
                medium: 64,
                large: 72,
              ),
              color: Colors.red[300],
            ),
            SizedBox(height: AppDimensions.getResponsiveSpacing(context)),
            Padding(
              padding: AppDimensions.getResponsivePadding(context),
              child: Text(
                _error!,
                style: TextStyle(
                  color: SiriusColors.defaultText,
                  fontSize: AppDimensions.getResponsiveFontSize(
                    context,
                    tiny: 14,
                    small: 15,
                    medium: 16,
                    large: 17,
                    xlarge: 18,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: AppDimensions.getResponsiveSpacing(context)),
            ElevatedButton(
              onPressed: _loadServices,
              style: ElevatedButton.styleFrom(
                backgroundColor: SiriusColors.accent,
                foregroundColor: SiriusColors.contrast,
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.getResponsiveSpacing(context) * 2,
                  vertical: AppDimensions.getResponsiveSpacing(context),
                ),
                minimumSize: Size(
                  AppDimensions.getResponsiveButtonHeight(context) * 2,
                  AppDimensions.getResponsiveButtonHeight(context),
                ),
              ),
              child: Text(
                lang.t('try_again'),
                style: TextStyle(
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
            ),
          ],
        ),
      );
    }

    if (_services.isEmpty) {
      return Center(
        child: Text(
          lang.t('no_services'),
          style: TextStyle(
            color: SiriusColors.defaultText,
            fontSize: AppDimensions.getResponsiveFontSize(
              context,
              tiny: 14,
              small: 15,
              medium: 16,
              large: 17,
              xlarge: 18,
            ),
          ),
        ),
      );
    }

    // Responsive grid sistemi
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = AppDimensions.getResponsiveGridColumns(context);
    final childAspectRatio = screenWidth <= AppDimensions.mobileBreakpoint
        ? 0.8
        : 1.2;

    return GridView.builder(
      padding: AppDimensions.getResponsivePadding(context),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: AppDimensions.getResponsiveSpacing(context),
        mainAxisSpacing: AppDimensions.getResponsiveSpacing(context),
      ),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final service = _services[index];
        return Card(
          elevation: 4,
          color: SiriusColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppDimensions.getResponsiveRadius(context),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                      AppDimensions.getResponsiveRadius(context),
                    ),
                  ),
                  child: Image.asset(
                    service.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        color: SiriusColors.surfaceLight,
                        child: Icon(
                          Icons.image_not_supported,
                          size: AppDimensions.getResponsiveIconSize(context),
                          color: SiriusColors.defaultText,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.all(
                    AppDimensions.getResponsiveSpacing(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              service.serviceName,
                              style: TextStyle(
                                fontSize: AppDimensions.getResponsiveFontSize(
                                  context,
                                  tiny: 14,
                                  small: 15,
                                  medium: 16,
                                  large: 17,
                                  xlarge: 18,
                                ),
                                fontWeight: FontWeight.bold,
                                color: SiriusColors.heading,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppDimensions.getResponsiveSpacing(
                                context,
                              ),
                              vertical:
                                  AppDimensions.getResponsiveSpacing(context) /
                                  2,
                            ),
                            decoration: BoxDecoration(
                              color: SiriusColors.accent,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.getResponsiveRadius(context),
                              ),
                            ),
                            child: Text(
                              '₺${service.servicePrice.toStringAsFixed(0)}',
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
                        ],
                      ),
                      SizedBox(
                        height: AppDimensions.getResponsiveSpacing(context) / 2,
                      ),
                      Text(
                        service.description,
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
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${service.serviceDuration} ${lang.t('minute_suffix')}',
                            style: TextStyle(
                              color: SiriusColors.accent,
                              fontSize: AppDimensions.getResponsiveFontSize(
                                context,
                                tiny: 10,
                                small: 11,
                                medium: 12,
                                large: 13,
                                xlarge: 14,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.access_time,
                            color: SiriusColors.accent,
                            size: AppDimensions.getResponsiveIconSize(
                              context,
                              tiny: 12,
                              small: 14,
                              medium: 16,
                              large: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
