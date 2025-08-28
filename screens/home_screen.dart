import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../main.dart';
import '../constants/colors.dart';

import 'package:dots_indicator/dots_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/db_service.dart';
import '../models/appointment.dart';
import '../models/service.dart';

import 'dart:ui'; // Added for ImageFilter
import 'dart:math'; // Added for sin function
import 'package:flutter/foundation.dart' show kIsWeb;

class AutoImageSlider extends StatefulWidget {
  const AutoImageSlider({super.key});

  @override
  State<AutoImageSlider> createState() => _AutoImageSliderState();
}

class _AutoImageSliderState extends State<AutoImageSlider> {
  final PageController _pageController = PageController();
  // ignore: prefer_final_fields
  int _currentPage = 0;
  Timer? _autoTimer;

  final List<String> _images = [
    'assets/images/img1.jpg',
    'assets/images/img2.jpg',
    'assets/images/img3.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % _images.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: _images.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            return Stack(
              children: [
                Image.asset(
                  _images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
                Container(color: Colors.black.withValues(alpha: 0.2)),
              ],
            );
          },
        ),
        Positioned(
          bottom: 20,
          child: DotsIndicator(
            dotsCount: _images.length,
            position: _currentPage.toDouble(),
            decorator: DotsDecorator(
              activeColor: Colors.white,
              color: Colors.white.withValues(alpha: 0.4),
              size: const Size.square(8.0),
              activeSize: const Size(18.0, 8.0),
              activeShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.0),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum ServiceCategory {
  all,
  hair,
  makeup,
  eyelash,
  nail,
  laser,
  microblading,
  skincare,
  massage,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Dark mode ve dil seçenekleri
  bool _isDarkMode = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (_isDarkMode != themeProvider.isDarkMode) {
      setState(() {
        _isDarkMode = themeProvider.isDarkMode;
      });
    }
  }

  final String _selectedLanguage = 'tr'; // ignore: unused_field
  bool _fabPressed = false;

  // UI için controller'lar ve state

  // Drawer kontrolü için Scaffold key

  // Contact form için key
  final GlobalKey<FormState> _contactFormKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _subjectCtl = TextEditingController();
  final _messageCtl = TextEditingController();

  // Menu bölümüne kaydırma için key
  final GlobalKey _menuSectionKey = GlobalKey();

  // Veri tabanı verileri
  List<Service> _services = [
    // Fallback services (Supabase'den veri gelmezse gösterilecek)
    Service(
      serviceId: 1,
      serviceName: 'Saç Kesimi',
      serviceDuration: 30,
      servicePrice: 150.0,
      description: 'Profesyonel saç kesimi ve şekillendirme',
      imageUrl: 'assets/services/hair.jpg',
      category: 'Saç',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Service(
      serviceId: 2,
      serviceName: 'Makyaj',
      serviceDuration: 45,
      servicePrice: 200.0,
      description: 'Günlük ve özel gün makyajı',
      imageUrl: 'assets/services/makeup.jpg',
      category: 'Makyaj',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  Map<String, dynamic>? _isletme = {
    // Fallback işletme bilgileri (Supabase'den veri gelmezse gösterilecek)
    'isim': 'Sirius Beauty & Spa',
    'aciklama': 'Beauty Salon & Spa',
    'logo_url': null, // Local asset path, not a network URL
    'banner_url': null, // Local asset path, not a network URL
    'arka_plan_url': null, // Local asset path, not a network URL
  };
  List<String> _galleryDynamic = [];

  // Service filtering - Default to hair category
  ServiceCategory selectedCategory = ServiceCategory.hair;
  // Dinamik kategoriler (Supabase iceriklerine göre)
  List<String> _dynamicCategories = ['All']; // Fallback kategori
  String _selectedDynamicCategory = 'All';

  // Page controllers ve timers
  final PageController _pageController = PageController();
  final PageController _eventsController = PageController(
    viewportFraction: 0.9,
  );
  // ignore: prefer_final_fields
  int _currentPage = 0;
  int _currentEventsPage = 0;
  Timer? _timer;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _bounceController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  // Team members data
  List<Map<String, String>> teamMembers = [
    // Fallback team members (Supabase'den veri gelmezse gösterilecek)
    {
      'name': 'Fatma Demir',
      'role': 'Saç Ustası',
      'image': 'assets/Team/hair1.jpg',
    },
    {
      'name': 'Ali Özkan',
      'role': 'Makyaj Ustası',
      'image': 'assets/Team/makeup.jpg',
    },
    {
      'name': 'Zeynep Kaya',
      'role': 'Cilt Bakım Uzmanı',
      'image': 'assets/Team/skincare.jpg',
    },
  ];
  Map<String, String> _icerikBlok = {};

  // Gallery images (fallback)
  final List<String> galleryImages = [
    'assets/salon/salon_reception.jpg',
    'assets/salon/salon_hair.jpg',
    'assets/salon/salon_makyaj.jpg',
    'assets/salon/salon_pedikür.jpg',
    'assets/salon/salon_spa.jpg',
    'assets/salon/salon_nail.jpg',
    'assets/salon/salon_skincare.jpg',
    'assets/salon/salon_massage.jpg',
  ];

  // Event images
  List<String> eventImages = [
    // Fallback event images (Supabase'den veri gelmezse gösterilecek)
    'assets/salon/salon_hair.jpg',
    'assets/salon/salon_makyaj.jpg',
    'assets/salon/salon_spa.jpg',
  ];

  // Drawer kontrolü için Scaffold key
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Widget> _buildWhyChooseUsCards() {
    // _icerikBlok anahtarları: why_1_title, why_1_desc, why_2_title, why_2_desc, why_3_title, why_3_desc
    // Bu anahtarlar 'neden_bizi_secmelisiniz_bolumu' tablosundan gelir
    final items = [
      {
        'num': '01',
        'title':
            _icerikBlok['why_1_title'] ??
            Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('beauty_meets_serenity'),
        'desc':
            _icerikBlok['why_1_desc'] ??
            Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('beauty_meets_serenity_desc'),
        'icon': Icons.spa,
      },
      {
        'num': '02',
        'title':
            _icerikBlok['why_2_title'] ??
            Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('your_beauty_our_galaxy'),
        'desc':
            _icerikBlok['why_2_desc'] ??
            Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('your_beauty_our_galaxy_desc'),
        'icon': Icons.star,
      },
      {
        'num': '03',
        'title':
            _icerikBlok['why_3_title'] ??
            Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('glow_beyond_stars'),
        'desc':
            _icerikBlok['why_3_desc'] ??
            Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('glow_beyond_stars_desc'),
        'icon': Icons.auto_awesome,
      },
    ];

    return items
        .map(
          (it) => FeatureCard(
            number: it['num'] as String,
            title: it['title'] as String,
            description: it['desc'] as String,
            icon: it['icon'] as IconData,
            isDarkMode: _isDarkMode,
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();

    // Animation controllers initialization
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Animation definitions
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticInOut),
    );

    _loadData();
    _startAutoSlide();
    _startAnimations();
  }

  void _startAnimations() {
    // Staggered animations
    Future.delayed(const Duration(milliseconds: 300), () {
      _fadeController.forward();
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      _slideController.forward();
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      _scaleController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      _bounceController.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _eventsController.dispose();
    _nameCtl.dispose();
    _emailCtl.dispose();
    _subjectCtl.dispose();
    _messageCtl.dispose();

    // Dispose animation controllers
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _bounceController.dispose();

    super.dispose();
  }

  // Veri yükleme
  Future<void> _loadData() async {
    try {
      // Önce işletme_id'yi çözümle: auth.uid() -> isletme_kullanici, yoksa tip='kuafor' ilk yayındaki
      final resolvedIsletmeId = await DbService.resolveIsletmeId();

      if (resolvedIsletmeId == null) {
        throw Exception(
          'İşletme bulunamadı. Lütfen admin ile iletişime geçiniz.',
        );
      }

      // Supabase: işletme bilgileri, galeri ve içerikler (menü/hizmet)
      final isletme = await DbService.getIsletmeById(resolvedIsletmeId);
      final galeri = await DbService.getIsletmeResimleri(resolvedIsletmeId);
      final galleryUrls = galeri
          .map((e) => (e['resim_url'] as String?))
          .whereType<String>()
          .toList();

      // İçerik: tek tablo üzerinden oku (menu_hizmet_icerigi)
      final icerikler = await DbService.getMenuHizmetIcerigi(resolvedIsletmeId);

      // Team ve etkinlikler (opsiyonel tablolar varsa doldurulur)
      final teamRows = await DbService.getTeamUyesi(resolvedIsletmeId);
      final etkinlikRows = await DbService.getEtkinlikler(resolvedIsletmeId);

      final icerikBlok = await DbService.getIcerikBlokMap(resolvedIsletmeId);

      // Debug logları kaldırıldı

      // Çalışanlar tablosundan veri mapping'i
      // Tablo: calisanlar, alanlar: ad, rol, resim_url
      final dynamicTeam = teamRows
          .map(
            (e) => {
              'name': (e['ad'] as String?) ?? '',
              'role': (e['hizmet'] as String?) ?? '',
              'image': (e['resim_url'] as String?) ?? 'assets/Team/makeup.jpg',
            },
          )
          .toList();
      // Etkinlikler tablosundan veri mapping'i
      // Tablo: etkinlik, alanlar: afis_url
      final dynamicEvents = etkinlikRows
          .map(
            (e) => (e['afis_url'] as String?) ?? 'assets/salon/salon_hair.jpg',
          )
          .toList();

      // Dinamik kategori isimleri (iceriklerde 'kategori' alanı varsa; yoksa tek 'All')
      final kategoriSet = <String>{};
      for (final row in icerikler) {
        final k = (row['kategori'] as String?)?.trim();
        if (k != null && k.isNotEmpty) kategoriSet.add(k);
      }
      final dynamicCategories = ['All', ...kategoriSet.toList()..sort()];

      // Grid için Service modeline dönüştür (UI bozulmasın diye)
      List<Service> supaServices = [];
      for (int i = 0; i < icerikler.length; i++) {
        final row = icerikler[i];
        final hizmet = (row['hizmet'] as String?) ?? '';
        final aciklama = (row['aciklama'] as String?) ?? '';
        final fiyatRaw = row['fiyat'];
        double fiyat = 0.0;
        if (fiyatRaw is num) {
          fiyat = fiyatRaw.toDouble();
        } else if (fiyatRaw is String) {
          final parsed = double.tryParse(fiyatRaw);
          fiyat = parsed ?? 0.0;
        }
        final kategori = (row['kategori'] as String?) ?? 'Hizmet';
        final rawImage = row['resim_url'] as String?;
        final normalizedImageUrl =
            (rawImage != null && rawImage.trim().isNotEmpty)
            ? (rawImage.startsWith('http') || rawImage.startsWith('https')
                  ? rawImage
                  : DbService.getPublicImageUrl(rawImage))
            : 'assets/services/hair.jpg';

        supaServices.add(
          Service(
            serviceId: i + 1,
            serviceName: hizmet,
            serviceDuration: 30,
            servicePrice: fiyat,
            description: aciklama,
            imageUrl: normalizedImageUrl,
            category: kategori,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      // Dinamik içerik Supabase üzerinden yüklendi

      setState(() {
        // Not: Aşağıdaki legacy veriler statik Postgres bağlantısını kullanıyordu.
        // Dinamik yapıda Supabase içeriklerini öne alıyoruz; legacy listeleri burada güncellemiyoruz.
        // İşletme bilgileri: Supabase'den veri gelirse kullan, yoksa fallback
        if (isletme != null) {
          _isletme = isletme;
        } else {}
        // Galeri: Supabase'den veri gelirse kullan, yoksa fallback
        if (galleryUrls.isNotEmpty) {
          _galleryDynamic = galleryUrls;
        } else {
          _galleryDynamic = galleryImages;
        }
        // Services: Supabase'den veri gelirse kullan, yoksa fallback
        if (supaServices.isNotEmpty) {
          _services = supaServices;
        } else {}
        // Kategoriler: Supabase'den veri gelirse kullan
        if (dynamicCategories.isNotEmpty) {
          _dynamicCategories = dynamicCategories;
          if (!_dynamicCategories.contains(_selectedDynamicCategory)) {
            _selectedDynamicCategory = 'All';
          }
        } else {}
        // Team members: Supabase'den veri gelirse kullan, yoksa fallback
        if (dynamicTeam.isNotEmpty) {
          teamMembers = dynamicTeam;
        } else {}

        // Events: Supabase'den veri gelirse kullan, yoksa fallback
        if (dynamicEvents.isNotEmpty) {
          eventImages = dynamicEvents;
        } else {}
        // İçerik blok: Supabase'den veri gelirse kullan
        if (icerikBlok.isNotEmpty) {
          _icerikBlok = icerikBlok;
        } else {}
      });
    } catch (e) {
      setState(() {
        // Hata mesajını UI'da göstermiyoruz, yalnızca durumu güncelliyoruz
      });
    }
  }

  // Auto slide başlat
  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % 3; // 3 resim var
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });

    // Events slider için ayrı timer
    Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_eventsController.hasClients) {
        int nextEventsPage = (_currentEventsPage + 1) % eventImages.length;
        _eventsController.animateToPage(
          nextEventsPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
        setState(() {
          _currentEventsPage = nextEventsPage;
        });
      }
    });
  }

  // Filtered services
  List<Service> get filteredServices {
    // Dinamik kategori filtresi (Supabase'ten gelen)
    if (_dynamicCategories.isNotEmpty) {
      if (_selectedDynamicCategory == 'All') {
        return _services;
      }
      final filtered = _services
          .where(
            (s) =>
                (s.category.toLowerCase()) ==
                _selectedDynamicCategory.toLowerCase(),
          )
          .toList();
      return filtered;
    }
    // Dinamik kategori yoksa eski statik kategori filtresi çalışsın
    if (selectedCategory == ServiceCategory.all) return _services;

    String categoryName = '';
    switch (selectedCategory) {
      case ServiceCategory.hair:
        categoryName = 'Saç';
        break;
      case ServiceCategory.makeup:
        categoryName = 'Makyaj';
        break;
      case ServiceCategory.eyelash:
        categoryName = 'Kirpik';
        break;
      case ServiceCategory.nail:
        categoryName = 'Tırnak';
        break;
      case ServiceCategory.laser:
        categoryName = 'Lazer';
        break;
      case ServiceCategory.microblading:
        categoryName = 'Kaş';
        break;
      case ServiceCategory.skincare:
        categoryName = 'Cilt Bakımı';
        break;
      case ServiceCategory.massage:
        categoryName = 'Masaj';
        break;
      case ServiceCategory.all:
        return _services;
    }
    return _services.where((s) => s.category == categoryName).toList();
  }

  // Helper methods
  Widget _hoverButton({
    required String text,
    required VoidCallback onPressed,
    Color? borderColor,
    Color? hoverBackgroundColor,
    Color? textColor,
  }) {
    borderColor ??= SiriusColors.accent;
    hoverBackgroundColor ??= SiriusColors.accent;
    textColor ??= Colors.black;

    return _HoverButton(
      text: text,
      onPressed: onPressed,
      borderColor: borderColor,
      hoverBackgroundColor: hoverBackgroundColor,
      textColor: textColor,
    );
  }

  Widget _transparentButton({
    required String text,
    required VoidCallback onPressed,
    bool isSelected = false,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? SiriusColors.accent.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? SiriusColors.accent : Colors.transparent,
        ),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: const Size(60, 36),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: SiriusColors.accent,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // Contact key
  final GlobalKey _contactKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Debug loglar kaldırıldı

    final lang = Provider.of<LanguageProvider>(context);

    final width = MediaQuery.of(context).size.width;
    int serviceCols = width > 1200 ? 4 : (width > 800 ? 3 : 2);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _isDarkMode
          ? Colors
                .black // Dark mode'da siyah
          : const Color(0xFFE5E2DB), // Açık modda #E5E2DB rengi
      extendBodyBehindAppBar: false,
      drawerEnableOpenDragGesture: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 56,
        flexibleSpace: Container(
          decoration: BoxDecoration(color: Colors.transparent),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.menu,
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Row(
          children: [
            (_isletme != null &&
                    (_isletme!['logo_url'] as String?)?.isNotEmpty == true &&
                    (_isletme!['logo_url'] as String).startsWith('http'))
                ? Image.network(
                    _isletme!['logo_url'],
                    height: 40,
                    width: 40,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/salon/logo1.png',
                      height: 40,
                      width: 40,
                    ),
                  )
                : Image.asset('assets/salon/logo1.png', height: 40, width: 40),
            const SizedBox(width: 12),
            Text(
              _isletme != null && (_isletme!['isim'] as String?) != null
                  ? _isletme!['isim'] as String
                  : 'Sirius Hair Salon',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Dil seçim ikonu
          IconButton(
            icon: Icon(
              Icons.language,
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              _showLanguageSelectionDialog(context, lang);
            },
            tooltip: lang.t('change_language'),
          ),
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              final themeProvider = Provider.of<ThemeProvider>(
                context,
                listen: false,
              );
              themeProvider.toggleTheme();
              setState(() {
                _isDarkMode = themeProvider.isDarkMode;
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: SiriusColors.accent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
      drawer: _buildSidebarDrawer(lang),
      body: CustomScrollView(
        slivers: [
          // Hero Section
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (_isletme != null &&
                          (_isletme!['banner_url'] as String?)?.isNotEmpty ==
                              true &&
                          (_isletme!['banner_url'] as String).startsWith(
                            'http',
                          ))
                      ? Image.network(
                          _isletme!['banner_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/salon/model.jpg',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/salon/model.jpg',
                          fit: BoxFit.cover,
                        ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Sirius title with scale animation
                          AnimatedBuilder(
                            animation: _scaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Text(
                                  _isletme != null &&
                                          (_isletme!['isim'] as String?)
                                                  ?.isNotEmpty ==
                                              true
                                      ? _isletme!['isim'] as String
                                      : 'Sirius',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: SiriusColors.accent,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Playfair Display',
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          // Subtitle with slide animation
                          SlideTransition(
                            position: _slideAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Text(
                                (_isletme != null &&
                                        (_isletme!['aciklama'] as String?)
                                                ?.isNotEmpty ==
                                            true)
                                    ? _isletme!['aciklama'] as String
                                    : (_icerikBlok['hero_subtitle'] ??
                                          'Beauty Salon & Spa'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontFamily: 'Playfair Display',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Tagline with fade animation
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Text(
                              _icerikBlok['hero_tagline'] ??
                                  '"Feel Beautiful, Be Sirius"',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          // Buttons with bounce animation
                          AnimatedBuilder(
                            animation: _bounceAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _bounceAnimation.value,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _hoverButton(
                                      hoverBackgroundColor: SiriusColors.accent,
                                      text:
                                          _icerikBlok['btn_services'] ??
                                          Provider.of<LanguageProvider>(
                                            context,
                                            listen: false,
                                          ).t('home_our_services'),
                                      textColor: Colors.white,
                                      borderColor: Colors.white,
                                      onPressed: () {
                                        // Menu bölümüne kaydır
                                        if (_menuSectionKey.currentContext !=
                                            null) {
                                          Scrollable.ensureVisible(
                                            _menuSectionKey.currentContext!,
                                            duration: const Duration(
                                              milliseconds: 800,
                                            ),
                                            curve: Curves.easeInOut,
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 20),
                                    // Giriş butonu: sadece AUTH değilse
                                    Builder(
                                      builder: (context) {
                                        final auth = Provider.of<AuthProvider>(
                                          context,
                                          listen: true,
                                        );
                                        if (auth.isAuthenticated) {
                                          return const SizedBox.shrink();
                                        }
                                        return _hoverButton(
                                          hoverBackgroundColor:
                                              SiriusColors.accent,
                                          text:
                                              _icerikBlok['btn_login'] ??
                                              Provider.of<LanguageProvider>(
                                                context,
                                                listen: false,
                                              ).t('sign_in'),
                                          textColor: Colors.white,
                                          borderColor: Colors.white,
                                          onPressed: () => Navigator.pushNamed(
                                            context,
                                            '/login',
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // About Us (solda yazı, sağda resim)
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 30,
                    horizontal: 24,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? SiriusColors.surface
                          : SiriusColors.accent2.withValues(
                              alpha: 0.1,
                            ), // Açık modda daha yoğun siyah transparan
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 700) {
                          return Column(
                            children: [
                              _aboutText(_isDarkMode),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child:
                                    (_isletme != null &&
                                        (_isletme!['arka_plan_url'] as String?)
                                                ?.isNotEmpty ==
                                            true)
                                    ? Image.network(
                                        _isletme!['arka_plan_url'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: SiriusColors.surface,
                                          height: 200,
                                        ),
                                      )
                                    : Image.asset(
                                        'assets/salon/logo2.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: SiriusColors.surface,
                                          height: 200,
                                        ),
                                      ),
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(child: _aboutText(_isDarkMode)),
                              const SizedBox(width: 20),
                              SizedBox(
                                width: 260,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child:
                                      (_isletme != null &&
                                          (_isletme!['arka_plan_url']
                                                      as String?)
                                                  ?.isNotEmpty ==
                                              true)
                                      ? Image.network(
                                          _isletme!['arka_plan_url'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                color: SiriusColors.surface,
                                                height: 200,
                                              ),
                                        )
                                      : Image.asset(
                                          'assets/salon/logo2.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                color: SiriusColors.surface,
                                                height: 200,
                                              ),
                                        ),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Why Us Section (hoverable cards)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    lang.t('why_choose_us'),
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cormorant',
                    ),
                  ),
                  const SizedBox(height: 40),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: MediaQuery.of(context).size.width > 900
                        ? 3
                        : MediaQuery.of(context).size.width > 600
                        ? 2
                        : 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    // Mobilde kartların yüksekliğini içeriğe göre daha kompakt yapmak için
                    childAspectRatio: MediaQuery.of(context).size.width < 600
                        ? 3.2
                        : 1.2,
                    children: _buildWhyChooseUsCards(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Events Section (with auto-scrolling slider)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Text(
                        lang.t('events'),
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cormorant',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Sol kısım: Kaydırılabilir resimler
                      Expanded(
                        child: SizedBox(
                          height: 250,
                          child: PageView.builder(
                            controller: _eventsController,
                            itemCount: eventImages.length,
                            scrollDirection: Axis.horizontal,
                            onPageChanged: (index) {
                              setState(() {
                                _currentEventsPage = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: eventImages[index].startsWith('http')
                                      ? Image.network(
                                          eventImages[index],
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                color: SiriusColors.surface,
                                              ),
                                        )
                                      : Image.asset(
                                          eventImages[index],
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                color: SiriusColors.surface,
                                              ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      // Sağ kısım: Sabit logo
                      const SizedBox(width: 20), // Resim ve logo arasına boşluk
                      SizedBox(
                        width: 250,
                        height: 250,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child:
                              (_isletme != null &&
                                  (_isletme!['logo_url'] as String?)
                                          ?.isNotEmpty ==
                                      true)
                              ? Image.network(
                                  _isletme!['logo_url'],
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/salon/logo1.png',
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : Image.asset(
                                  'assets/salon/logo1.png',
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                    ],
                  ),
                  // Events fotoğrafları için dots indicator
                  const SizedBox(height: 16),
                  if (eventImages.isNotEmpty)
                    Center(
                      child: DotsIndicator(
                        dotsCount: eventImages.length,
                        position: _currentEventsPage.toDouble(),
                        decorator: DotsDecorator(
                          activeColor: SiriusColors.accent,
                          color: SiriusColors.accent.withValues(alpha: 0.3),
                          size: const Size.square(8.0),
                          activeSize: const Size(18.0, 8.0),
                          activeShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                        ),
                        onTap: (position) {
                          setState(() {
                            _currentEventsPage = position.toInt();
                          });
                          _eventsController.animateToPage(
                            position.toInt(),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Menu / Filters
          SliverToBoxAdapter(
            key: _menuSectionKey,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Text(
                        'Menu',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cormorant',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Responsive category buttons (show static only if no dynamic categories)
                  if (_dynamicCategories.isEmpty)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 600) {
                          // Mobile: Vertical scrollable buttons
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ServiceCategory.values.map((cat) {
                                final label = _categoryLabel(cat);
                                final active = cat == selectedCategory;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _transparentButton(
                                    text: label,
                                    isSelected: active,
                                    onPressed: () =>
                                        setState(() => selectedCategory = cat),
                                    isDarkMode: _isDarkMode,
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        } else {
                          // Desktop: Wrap layout
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ServiceCategory.values.map((cat) {
                              final label = _categoryLabel(cat);
                              final active = cat == selectedCategory;
                              return _transparentButton(
                                text: label,
                                isSelected: active,
                                onPressed: () =>
                                    setState(() => selectedCategory = cat),
                                isDarkMode: _isDarkMode,
                              );
                            }).toList(),
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 16),

                  // Dinamik kategori butonları (iceriklerden çıkarılır)
                  if (_dynamicCategories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _dynamicCategories.map((cat) {
                          final active = _selectedDynamicCategory == cat;
                          return _transparentButton(
                            text: cat,
                            isSelected: active,
                            onPressed: () => setState(() {
                              _selectedDynamicCategory = cat;
                            }),
                            isDarkMode: _isDarkMode,
                          );
                        }).toList(),
                      ),
                    ),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredServices.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width < 600
                          ? 1
                          : serviceCols,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: MediaQuery.of(context).size.width < 600
                          ? 2.5
                          : 3.0,
                    ),
                    itemBuilder: (context, i) {
                      final svc = filteredServices[i];
                      return ServiceCard(
                        title: svc.serviceName,
                        price: svc.servicePrice.toDouble(),
                        imagePath: svc.imageUrl,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: SiriusColors.surface,
                              title: Text(
                                svc.serviceName,
                                style: TextStyle(color: SiriusColors.heading),
                              ),
                              content: Text(
                                '${svc.servicePrice} ${_icerikBlok['currency'] ?? 'TL'}',
                                style: TextStyle(
                                  color: SiriusColors.defaultText,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    _icerikBlok['dialog_close'] ?? 'Close',
                                    style: TextStyle(
                                      color: SiriusColors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        isDarkMode: _isDarkMode,
                        currency: _icerikBlok['currency'] ?? 'TL',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Gallery
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Text(
                        lang.t('gallery'),
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cormorant',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 3D Floating Gallery with Parallax Effect
                  SizedBox(
                    height: MediaQuery.of(context).size.width < 600 ? 360 : 600,
                    child: Gallery3DFloating(
                      images: _galleryDynamic,
                      onImageTap: (img) => _openImageDialog(context, img),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Team Section (moved to before Contact)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Text(
                        lang.t('our_team'),
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cormorant',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Team Members 3D Carousel
                  SizedBox(
                    height: 400,
                    child: TeamCarousel3D(teamMembers: teamMembers),
                  ),
                ],
              ),
            ),
          ),

          // Contact Section - Footer Style
          SliverToBoxAdapter(
            child: Container(
              color: SiriusColors.contrast,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Footer Header
                  Row(
                    children: [
                      Image.asset('assets/salon/3.png', height: 50, width: 50),
                      const SizedBox(width: 16),
                      Text(
                        (_isletme != null &&
                                (_isletme!['isim'] as String?) != null)
                            ? _isletme!['isim'] as String
                            : (_icerikBlok['brand_name'] ?? 'Sirius'),
                        style: GoogleFonts.dancingScript(
                          color: SiriusColors.accent,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Footer Content
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 900) {
                        return Column(
                          children: [
                            _contactInfo(),
                            const SizedBox(height: 30),
                            _contactForm(),
                          ],
                        );
                      } else {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 4, child: _contactInfo()),
                            const SizedBox(width: 40),
                            Expanded(flex: 6, child: _contactForm()),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 30),
                  // Footer Bottom
                  const SizedBox.shrink(),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox.shrink()),
        ],
      ),
      floatingActionButton: kIsWeb
          ? Builder(
              builder: (context) {
                final auth = Provider.of<AuthProvider>(context, listen: true);
                if (!auth.isAuthenticated) {
                  // Giriş yapılmamış halde sağda randevu al butonu
                  return FloatingActionButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    backgroundColor: SiriusColors.accent,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.calendar_today),
                  );
                }

                // Giriş yapılmış halde ortada + butonu
                return Transform.translate(
                  offset: const Offset(0, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _fabPressed
                            ? Colors.transparent
                            : SiriusColors.accent.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        if (_fabPressed)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 18,
                            spreadRadius: 1,
                            offset: const Offset(0, 8),
                          ),
                      ],
                    ),
                    child: FloatingActionButton(
                      onPressed: () {
                        setState(() {
                          _fabPressed = true;
                        });
                        _showAppointmentBookingDialog(context);
                      },
                      backgroundColor: _fabPressed
                          ? SiriusColors.accent
                          : Colors.transparent,
                      foregroundColor: _fabPressed
                          ? Colors.white
                          : SiriusColors.accent,
                      child: const Icon(Icons.add),
                    ),
                  ),
                );
              },
            )
          : null,
      floatingActionButtonLocation:
          (Provider.of<AuthProvider>(context, listen: true).isAuthenticated)
          ? FloatingActionButtonLocation.centerDocked
          : FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: null,
    );
  }

  // ---- helper widgets & methods ----

  Widget _buildSidebarDrawer(LanguageProvider lang) {
    return Drawer(
      backgroundColor: _isDarkMode
          ? SiriusColors.surface
          : const Color(0xFFEDECE8),
      width: 250,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          SiriusColors.accent,
                          SiriusColors.accent.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: SiriusColors.accent.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child:
                          (_isletme != null &&
                              (_isletme!['logo_url'] as String?)?.isNotEmpty ==
                                  true)
                          ? Image.network(
                              _isletme!['logo_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/salon/3.png',
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              'assets/salon/3.png',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isletme != null && (_isletme!['isim'] as String?) != null
                        ? _isletme!['isim'] as String
                        : 'Sirius',
                    style: TextStyle(
                      color: _isDarkMode
                          ? SiriusColors.heading
                          : Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                  Text(
                    'Beauty & Spa',
                    style: TextStyle(
                      color: _isDarkMode
                          ? SiriusColors.defaultText
                          : Colors.grey[600],
                      fontSize: 16,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: SiriusColors.defaultText, height: 1),
            _buildSidebarItem(
              icon: Icons.home,
              title: lang.t('home_title'),
              isSelected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _buildSidebarItem(
              icon: Icons.person,
              title: lang.t('profile_title'),
              isSelected: false,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),
            const Spacer(),
            const Divider(color: SiriusColors.defaultText, height: 1),
            const SizedBox(height: 12),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  if (mounted) {
                    try {
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      authProvider.logout();
                      Navigator.of(context).pushReplacementNamed('/');
                    } catch (e) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: Text(lang.t('logout')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: _isDarkMode ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? (_isDarkMode ? Colors.white : Colors.black87)
              : (_isDarkMode ? Colors.grey[400] : Colors.grey[600]),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected
            ? (_isDarkMode ? Colors.white : Colors.black87).withValues(
                alpha: 0.1,
              )
            : Colors.transparent,
      ),
    );
  }

  void _showAppointmentBookingDialog(BuildContext context) {
    String? selectedService;
    String? selectedEmployee;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    final notesController = TextEditingController();
    bool isLoading = false;

    List<String> serviceTitles = [];
    List<Map<String, dynamic>> calisanOptions = [];
    bool servicesLoaded = false;

    Future<void> loadServices(StateSetter setDialogState) async {
      try {
        final isletmeId = await DbService.resolveIsletmeId();
        if (isletmeId == null) return;
        final client = Supabase.instance.client;
        final rows = await client
            .from('menu_hizmet_icerigi')
            .select('hizmet, aktif')
            .eq('isletme_id', isletmeId)
            .eq('aktif', true)
            .order('sira', ascending: true);
        final titles = <String>{};
        for (final r in rows as List) {
          final m = r as Map<String, dynamic>;
          final t = (m['hizmet'] as String?)?.trim();
          if (t != null && t.isNotEmpty) titles.add(t);
        }
        setDialogState(() {
          serviceTitles = titles.toList();
        });
      } catch (_) {}
    }

    Future<void> loadEmployeesByRole(
      StateSetter setDialogState,
      String? role,
    ) async {
      try {
        calisanOptions = [];
        if (role == null || role.isEmpty) {
          setDialogState(() {});
          return;
        }
        final isletmeId = await DbService.resolveIsletmeId();
        if (isletmeId == null) return;
        final client = Supabase.instance.client;
        final rows = await client
            .from('calisanlar')
            .select('ad, hizmet, aktif')
            .eq('isletme_id', isletmeId)
            .eq('aktif', true)
            .eq('hizmet', role)
            .order('sira', ascending: true)
            .order('created_at', ascending: true);
        calisanOptions = List<Map<String, dynamic>>.from(rows as List);
        setDialogState(() {});
      } catch (_) {
        setDialogState(() {
          calisanOptions = [];
        });
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!servicesLoaded) {
              servicesLoaded = true;
              loadServices(setDialogState);
            }
            return AlertDialog(
              backgroundColor: _isDarkMode
                  ? SiriusColors.surface
                  : Colors.white,
              title: Row(
                children: [
                  Icon(Icons.calendar_today, color: SiriusColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('make_appointment'),
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedService,
                      isExpanded: true,
                      hint: Text(
                        Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).t('select_service'),
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      decoration: InputDecoration(
                        labelText: Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).t('service'),
                        labelStyle: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: SiriusColors.accent,
                            width: 2,
                          ),
                        ),
                      ),
                      items: serviceTitles
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (val) {
                        selectedService = val;
                        selectedEmployee = null;
                        loadEmployeesByRole(setDialogState, val);
                      },
                    ),
                    const SizedBox(height: 16),
                    if (selectedService != null && calisanOptions.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedEmployee,
                        isExpanded: true,
                        hint: Text(
                          Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('select_employee'),
                          style: TextStyle(
                            color: _isDarkMode
                                ? Colors.white70
                                : Colors.black54,
                          ),
                        ),
                        decoration: InputDecoration(
                          labelText: Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('employee'),
                          labelStyle: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: SiriusColors.accent,
                              width: 2,
                            ),
                          ),
                        ),
                        items: calisanOptions
                            .map(
                              (m) => DropdownMenuItem(
                                value: (m['ad'] as String?) ?? '-',
                                child: Text((m['ad'] as String?) ?? '-'),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          selectedEmployee = val;
                          setDialogState(() {});
                        },
                      ),
                    const SizedBox(height: 16),
                    // Tarih ve saat
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (d != null) {
                          selectedDate = d;
                          setDialogState(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: _isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (t != null) {
                          selectedTime = t;
                          setDialogState(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: _isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notlar (Opsiyonel)',
                        labelStyle: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!mounted) return;
                          if (selectedService == null ||
                              selectedEmployee == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lütfen hizmet ve çalışan seçin'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isLoading = true);
                          try {
                            final auth = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );
                            final customer = auth.currentCustomer!;
                            // Legacy oluşturma (mevcut fonksiyonu kullan)
                            final appt = Appointment(
                              customerName:
                                  '${customer.firstName} ${customer.lastName}',
                              employeeName: selectedEmployee!,
                              serviceName: selectedService!,
                              process: 'Randevu işlemi',
                              totalPrice: 0.0,
                              appointmentDateTime: DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              ),
                              approvalStatus: 'Pending',
                              customerPhone: '',
                              customerEmail: customer.email,
                              notes: notesController.text.isNotEmpty
                                  ? notesController.text
                                  : null,
                            );
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final ok = await DbService.createAppointment(
                                appt,
                              );
                              if (!mounted) return;
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Randevunuz başarıyla oluşturuldu!'
                                        : 'Randevu oluşturulamadı. Tekrar deneyin.',
                                  ),
                                  backgroundColor: ok
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Hata: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              setDialogState(() => isLoading = false);
                            }
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() => isLoading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SiriusColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Randevu Oluştur'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _aboutText(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('home_about_us'),
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cormorant',
          ),
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 8),
        Text(
          _icerikBlok['about_us_subtitle'] ??
              'Our mission is to empower you to look and feel your best.',
          style: TextStyle(
            color: SiriusColors.accent,
            fontStyle: FontStyle.italic,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _icerikBlok['about_us_p1'] ??
              'At Sirius, we combine our passion for beauty with advanced techniques to deliver exceptional services. Our team of skilled professionals is dedicated to providing a personalized experience tailored to your unique needs.',
          style: TextStyle(
            color: isDarkMode ? Colors.white : const Color(0xFF190a1d),
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _icerikBlok['about_us_p2'] ??
              'From hair styling and makeup to relaxing spa treatments, we use only the highest quality products to ensure lasting results. Step into our salon and let us guide you on a journey to radiance and rejuvenation.',
          style: TextStyle(
            color: isDarkMode ? Colors.white : const Color(0xFF190a1d),
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 20),
        _hoverButton(
          text:
              _icerikBlok['btn_learn_more'] ??
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).t('learn_more'),
          onPressed: () {
            final context = _contactKey.currentContext;
            if (context != null) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
              );
            }
          },
          textColor: Colors.white,
          hoverBackgroundColor: SiriusColors.accent,
        ),
      ],
    );
  }

  String _categoryLabel(ServiceCategory category) {
    switch (category) {
      case ServiceCategory.all:
        return 'Tümü';
      case ServiceCategory.hair:
        return 'Saç';
      case ServiceCategory.makeup:
        return 'Makyaj';
      case ServiceCategory.eyelash:
        return 'Kirpik';
      case ServiceCategory.nail:
        return 'Tırnak';
      case ServiceCategory.laser:
        return 'Lazer';
      case ServiceCategory.microblading:
        return 'Kaş';
      case ServiceCategory.skincare:
        return 'Cilt Bakımı';
      case ServiceCategory.massage:
        return 'Masaj';
    }
  }

  Widget _contactInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _contactInfoItem(
          Icons.location_on,
          'Adres:',
          '${_isletme?['adres'] ?? 'İstanbul'}, ${_isletme?['ilce'] ?? 'Kadıköy'}, ${_isletme?['sehir'] ?? 'İstanbul'} ${_isletme?['posta_kodu'] ?? '34744'}',
        ),
        _contactInfoItem(
          Icons.access_time,
          'Çalışma Saatleri:',
          _isletme?['calisma_saatleri'] ??
              'Pazartesi - Cumartesi: 07:00 - 23:00',
        ),
        _contactInfoItem(
          Icons.email,
          'Email:',
          _isletme?['email'] ?? 'gymOrion@gmail.com',
        ),
        _contactInfoItem(
          Icons.phone,
          'Telefon:',
          _isletme?['telefon'] ?? '+905348956232',
        ),
        _contactInfoItem(
          Icons.language,
          Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).t('footer_website') +
              ':',
          _isletme?['web_site'] ?? 'www.oriongym.com',
        ),
      ],
    );
  }

  Widget _contactInfoItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: SiriusColors.accent, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactForm() {
    return Form(
      key: _contactFormKey,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameCtl,
                  decoration: _inputDecoration(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('name'),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty
                      ? Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('name') +
                            ' boş olamaz'
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _emailCtl,
                  decoration: _inputDecoration(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('email_address'),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty || !value.contains('@')
                      ? 'Geçerli email giriniz'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _subjectCtl,
            decoration: _inputDecoration(
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).t('subject'),
            ),
            style: const TextStyle(color: Colors.white),
            validator: (value) => value!.isEmpty
                ? Provider.of<LanguageProvider>(
                        context,
                        listen: false,
                      ).t('subject') +
                      ' boş olamaz'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _messageCtl,
            decoration: _inputDecoration(
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).t('message'),
            ),
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            validator: (value) => value!.isEmpty
                ? Provider.of<LanguageProvider>(
                        context,
                        listen: false,
                      ).t('message') +
                      ' boş olamaz'
                : null,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: _hoverButton(
              text: Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).t('send_message'),
              onPressed: () {
                if (_contactFormKey.currentState!.validate()) {
                  // Handle form submission
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).t('message_sent'),
                      ),
                    ),
                  );
                }
              },
              textColor: Colors.white,
              hoverBackgroundColor: SiriusColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      hintText: label,
      hintStyle: TextStyle(
        color: _isDarkMode
            ? Colors.white.withValues(alpha: 0.6)
            : const Color(0xFF190a1d).withValues(alpha: 0.6),
      ),
      filled: true,
      fillColor: _isDarkMode ? SiriusColors.background : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: _isDarkMode ? SiriusColors.surface : const Color(0xFF190a1d),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: SiriusColors.accent, width: 2),
      ),
    );
  }

  void _openImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Stack(
          alignment: Alignment.topRight,
          children: [
            imagePath.startsWith('http')
                ? Image.network(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Container(color: SiriusColors.surface, height: 300),
                  )
                : Image.asset(imagePath, fit: BoxFit.contain),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelectionDialog(
    BuildContext context,
    LanguageProvider lang,
  ) {
    final isDarkMode = _isDarkMode;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode
              ? const Color(0xFF181818).withValues(alpha: 0.95)
              : const Color(0xFFEDECE8).withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.language, color: SiriusColors.accent, size: 24),
              const SizedBox(width: 12),
              Text(
                lang.t('change_language'),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.red),
                  title: const Text('Türkçe'),
                  subtitle: const Text('Turkish'),
                  onTap: () {
                    lang.setLanguage(AppLanguage.tr);
                    Navigator.of(context).pop();
                  },
                  tileColor: lang.isTurkish
                      ? SiriusColors.accent.withValues(alpha: 0.1)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.blue),
                  title: const Text('English'),
                  subtitle: const Text('İngilizce'),
                  onTap: () {
                    lang.setLanguage(AppLanguage.en);
                    Navigator.of(context).pop();
                  },
                  tileColor: lang.isEnglish
                      ? SiriusColors.accent.withValues(alpha: 0.1)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: SiriusColors.accent),
                foregroundColor: SiriusColors.accent,
              ),
              child: Text(lang.t('cancel')),
            ),
          ],
        );
      },
    );
  }
}

// Yeni Servis Sınıfı (resim yolu eklendi)

class FeatureCard extends StatefulWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;
  final bool isDarkMode;

  const FeatureCard({
    super.key,
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.isDarkMode,
  });

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _elevationAnimation = Tween<double>(
      begin: 4.0,
      end: 12.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return SizedBox(
      width: double.infinity,
      height: isMobile ? null : 220,
      child: InkWell(
        onTap: () {
          // Add tap functionality if needed
        },
        onHover: (isHovered) {
          if (!mounted) return;
          final double width = MediaQuery.sizeOf(context).width;
          if (width < 600) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (isHovered != _isHovered) {
              setState(() => _isHovered = isHovered);
            }
            if (isHovered) {
              if (_controller.status != AnimationStatus.forward &&
                  _controller.status != AnimationStatus.completed) {
                _controller.forward();
              }
            } else {
              if (_controller.status != AnimationStatus.reverse &&
                  _controller.status != AnimationStatus.dismissed) {
                _controller.reverse();
              }
            }
          });
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: double.infinity,
                height: isMobile ? null : double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? SiriusColors.surface
                      : Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isHovered
                        ? SiriusColors.accent
                        : SiriusColors.surface,
                    width: _isHovered ? 2.0 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: _elevationAnimation.value,
                      offset: Offset(0, _elevationAnimation.value / 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: _isHovered
                            ? SiriusColors.accent
                            : SiriusColors.accent.withValues(alpha: 0.8),
                        child: Icon(
                          widget.icon,
                          color: Colors.white,
                          size: _isHovered ? 24 : 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: Text(
                        widget.description,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.visible,
                        maxLines: isMobile ? null : 6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class TeamMemberCard extends StatefulWidget {
  final String name;
  final String role;
  final String imagePath;

  const TeamMemberCard({
    super.key,
    required this.name,
    required this.role,
    required this.imagePath,
  });

  @override
  State<TeamMemberCard> createState() => _TeamMemberCardState();
}

class _TeamMemberCardState extends State<TeamMemberCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _elevationAnimation = Tween<double>(
      begin: 4.0,
      end: 16.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Add tap functionality if needed
      },
      onHover: (isHovering) {
        if (!mounted) return;
        final double width = MediaQuery.sizeOf(context).width;
        if (width < 600) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (isHovering != _isHovering) {
            setState(() => _isHovering = isHovering);
          }
          if (isHovering) {
            _controller.forward();
          } else {
            _controller.reverse();
          }
        });
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Card(
              color: SiriusColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: _elevationAnimation.value,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      widget.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: SiriusColors.background),
                    ),
                  ),
                  // Hover efekti
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    color: _isHovering
                        ? Colors.black.withValues(alpha: 0.7)
                        : Colors.transparent,
                    child: _isHovering
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _isHovering ? 22 : 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  child: Text(widget.name),
                                ),
                                const SizedBox(height: 4),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: _isHovering ? 18 : 16,
                                  ),
                                  child: Text(widget.role),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HoverButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? borderColor;
  final Color? hoverBackgroundColor;
  final Color? textColor;

  const _HoverButton({
    required this.text,
    required this.onPressed,
    this.borderColor,
    this.hoverBackgroundColor,
    this.textColor,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Add tap functionality if needed
      },
      onHover: (isHovered) {
        if (!mounted) return;
        final double width = MediaQuery.sizeOf(context).width;
        if (width < 600) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (isHovered != this.isHovered) {
            setState(() => this.isHovered = isHovered);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isHovered ? widget.hoverBackgroundColor : Colors.transparent,
          border: Border.all(
            color: widget.borderColor ?? SiriusColors.accent,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: TextButton(
          onPressed: widget.onPressed,
          child: Text(
            widget.text,
            style: TextStyle(
              color: isHovered ? Colors.white : widget.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class ServiceCard extends StatefulWidget {
  final String title;
  final double price;
  final String imagePath;
  final VoidCallback onTap;
  final bool isDarkMode;
  final String currency;

  const ServiceCard({
    super.key,
    required this.title,
    required this.price,
    required this.imagePath,
    required this.onTap,
    required this.isDarkMode,
    required this.currency,
  });

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _borderAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _borderAnimation = Tween<double>(
      begin: 1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Add tap functionality if needed
      },
      onHover: (isHovered) {
        if (!mounted) return;
        final double width = MediaQuery.sizeOf(context).width;
        if (width < 600) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (isHovered != _isHovered) {
            setState(() => _isHovered = isHovered);
          }
          if (isHovered) {
            _controller.forward();
          } else {
            _controller.reverse();
          }
        });
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Card(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: _isHovered ? 8 : 0,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: SiriusColors.accent,
                      width: _borderAnimation.value,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Sol: Yuvarlak resim
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isHovered
                                ? SiriusColors.accent
                                : Colors.white,
                            width: _isHovered ? 3.0 : 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: _isHovered ? 0.2 : 0.1,
                              ),
                              blurRadius: _isHovered ? 12 : 8,
                              offset: Offset(0, _isHovered ? 6 : 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: widget.imagePath.startsWith('http')
                              ? Image.network(
                                  widget.imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.image,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      size: 30,
                                    ),
                                  ),
                                )
                              : Image.asset(
                                  widget.imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.image,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      size: 30,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Orta: Hizmet ismi
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: widget.isDarkMode
                                ? Colors.white
                                : (_isHovered
                                      ? SiriusColors.accent
                                      : SiriusColors.accent2),
                            fontSize: _isHovered ? 18 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                          child: Text(
                            widget.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Sağ: Fiyat
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isHovered
                              ? SiriusColors.accent.withValues(alpha: 0.2)
                              : SiriusColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isHovered
                                ? SiriusColors.accent
                                : SiriusColors.accent.withValues(alpha: 0.3),
                            width: _isHovered ? 2.0 : 1.0,
                          ),
                        ),
                        child: Text(
                          '${widget.price.toStringAsFixed(0)} ${widget.currency}',
                          style: TextStyle(
                            color: SiriusColors.accent,
                            fontSize: _isHovered ? 16 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class VoyagerTeamSlider extends StatefulWidget {
  final List<Map<String, String>> teamMembers;

  const VoyagerTeamSlider({super.key, required this.teamMembers});

  @override
  State<VoyagerTeamSlider> createState() => _VoyagerTeamSliderState();
}

class _VoyagerTeamSliderState extends State<VoyagerTeamSlider>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _parallaxController;

  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _parallaxAnimation;

  int _currentIndex = 0;
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.8);
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _parallaxController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _parallaxAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _parallaxController, curve: Curves.easeInOut),
    );

    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page!;
      });
    });

    _rotationController.repeat();
    _parallaxController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    _parallaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Arka plan gezegen efekti
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.5,
                      colors: [
                        SiriusColors.accent.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Ana slider
        PageView.builder(
          controller: _pageController,
          itemCount: widget.teamMembers.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
            _scaleController.forward().then((_) {
              _scaleController.reverse();
            });
          },
          itemBuilder: (context, index) {
            final member = widget.teamMembers[index];
            final isActive = index == _currentIndex;
            final pageOffset = (index - _currentPage).abs();
            final scale = (1 - pageOffset * 0.3).clamp(0.8, 1.0);
            final opacity = (1 - pageOffset * 0.5).clamp(0.3, 1.0);

            return AnimatedBuilder(
              animation: _parallaxAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: scale * (isActive ? _scaleAnimation.value : 1.0),
                  child: Opacity(
                    opacity: opacity,
                    child: _VoyagerTeamCard(
                      name: member['name']!,
                      role: member['role']!,
                      imagePath: member['image']!,
                      isActive: isActive,
                      parallaxValue: _parallaxAnimation.value,
                    ),
                  ),
                );
              },
            );
          },
        ),

        // Navigasyon noktaları
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.teamMembers.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _currentIndex ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == _currentIndex
                      ? SiriusColors.accent
                      : SiriusColors.accent.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),

        // Sol/Sağ navigasyon butonları
        Positioned(
          left: 20,
          top: 0,
          bottom: 0,
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, -25),
              child: _VoyagerNavButton(
                icon: Icons.chevron_left,
                onPressed: () {
                  if (_currentIndex > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
          ),
        ),

        Positioned(
          right: 20,
          top: 0,
          bottom: 0,
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, -25),
              child: _VoyagerNavButton(
                icon: Icons.chevron_right,
                onPressed: () {
                  if (_currentIndex < widget.teamMembers.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VoyagerTeamCard extends StatefulWidget {
  final String name;
  final String role;
  final String imagePath;
  final bool isActive;
  final double parallaxValue;

  const _VoyagerTeamCard({
    required this.name,
    required this.role,
    required this.imagePath,
    required this.isActive,
    required this.parallaxValue,
  });

  @override
  State<_VoyagerTeamCard> createState() => _VoyagerTeamCardState();
}

class _VoyagerTeamCardState extends State<_VoyagerTeamCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _hoverAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Add tap functionality if needed
      },
      onHover: (isHovered) {
        if (!mounted) return;
        final double width = MediaQuery.sizeOf(context).width;
        if (width < 600) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (isHovered != _isHovered) {
            setState(() => _isHovered = isHovered);
          }
          if (isHovered) {
            _hoverController.forward();
          } else {
            _hoverController.reverse();
          }
        });
      },
      child: AnimatedBuilder(
        animation: _hoverAnimation,
        builder: (context, child) {
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(widget.parallaxValue * 0.1)
              ..rotateX(widget.parallaxValue * 0.05),
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: SiriusColors.accent.withValues(
                      alpha: _isHovered ? 0.4 : 0.2,
                    ),
                    blurRadius: _isHovered ? 30 : 20,
                    spreadRadius: _isHovered ? 10 : 5,
                    offset: Offset(0, _isHovered ? 15 : 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Ana resim
                    (widget.imagePath.startsWith('http') ||
                            widget.imagePath.startsWith('https'))
                        ? Image.network(
                            widget.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: SiriusColors.surface,
                              child: Icon(
                                Icons.person,
                                size: 80,
                                color: SiriusColors.accent,
                              ),
                            ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: SiriusColors.surface,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                        : null,
                                    color: SiriusColors.accent,
                                  ),
                                ),
                              );
                            },
                          )
                        : Image.asset(
                            widget.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: SiriusColors.surface,
                              child: Icon(
                                Icons.person,
                                size: 80,
                                color: SiriusColors.accent,
                              ),
                            ),
                          ),

                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),

                    // İsim ve rol
                    Positioned(
                      bottom: 30,
                      left: 30,
                      right: 30,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _isHovered ? 28 : 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cormorant',
                            ),
                            child: Text(widget.name),
                          ),
                          const SizedBox(height: 8),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: _isHovered ? 18 : 16,
                              fontStyle: FontStyle.italic,
                            ),
                            child: Text(widget.role),
                          ),
                        ],
                      ),
                    ),

                    // Hover efekti - parıltı
                    if (_isHovered)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                SiriusColors.accent.withValues(alpha: 0.3),
                                Colors.transparent,
                                SiriusColors.accent.withValues(alpha: 0.1),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VoyagerNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _VoyagerNavButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: SiriusColors.accent.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: SiriusColors.accent.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onPressed,
      ),
    );
  }
}

class AnimatedGalleryItem extends StatefulWidget {
  final String imagePath;
  final int index;
  final VoidCallback onTap;

  const AnimatedGalleryItem({
    super.key,
    required this.imagePath,
    required this.index,
    required this.onTap,
  });

  @override
  State<AnimatedGalleryItem> createState() => _AnimatedGalleryItemState();
}

class _AnimatedGalleryItemState extends State<AnimatedGalleryItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Staggered animation based on index
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Add tap functionality if needed
      },
      onHover: (isHovered) {
        final double width = MediaQuery.sizeOf(context).width;
        if (width < 600) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (isHovered != _isHovered) {
            setState(() => _isHovered = isHovered);
          }
        });
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _isHovered ? 1.05 : _scaleAnimation.value,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: GestureDetector(
                onTap: widget.onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: _isHovered ? 0.3 : 0.1,
                            ),
                            blurRadius: _isHovered ? 12 : 4,
                            offset: Offset(0, _isHovered ? 6 : 2),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        widget.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: SiriusColors.surface),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// 3D Carousel Widget for Team Members
class TeamCarousel3D extends StatefulWidget {
  final List<Map<String, String>> teamMembers;

  const TeamCarousel3D({super.key, required this.teamMembers});

  @override
  State<TeamCarousel3D> createState() => _TeamCarousel3DState();
}

class _TeamCarousel3DState extends State<TeamCarousel3D>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  int _currentIndex = 0;
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.5, initialPage: 0);
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page!;
      });
    });

    // Auto-play carousel
    _startAutoPlay();
  }

  void _startAutoPlay() {
    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _currentIndex < widget.teamMembers.length - 1) {
        _nextPage();
      } else if (mounted) {
        _goToFirstPage();
      }
    });
  }

  void _nextPage() {
    if (_currentIndex < widget.teamMembers.length - 1) {
      _currentIndex++;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _goToFirstPage() {
    _currentIndex = 0;
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.teamMembers.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final member = widget.teamMembers[index];
              final offset = index - _currentPage;
              final isActive = (offset).abs() < 0.5;

              // Calculate 3D transformations
              final scale = isActive ? 1.15 : 0.65;
              final rotation =
                  offset *
                  0.4; // Rotation angle - increased for more dramatic effect
              final opacity = isActive ? 1.0 : 0.3;
              final blur = isActive ? 0.0 : 3.0;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(
                      3,
                      2,
                      0.002,
                    ) // Perspective - increased for more depth
                    ..rotateY(rotation)
                    ..multiply(Matrix4.diagonal3Values(scale, scale, scale)),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      child: _buildTeamCard(member, isActive, blur),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        // Navigation dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.teamMembers.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentIndex == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentIndex == index
                    ? SiriusColors.accent
                    : SiriusColors.accent.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Navigation buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _currentIndex > 0
                  ? () {
                      _currentIndex--;
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeInOutCubic,
                      );
                    }
                  : null,
              icon: Icon(
                Icons.arrow_back_ios,
                color: _currentIndex > 0
                    ? SiriusColors.accent
                    : SiriusColors.accent.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 20),
            IconButton(
              onPressed: _currentIndex < widget.teamMembers.length - 1
                  ? () {
                      _nextPage();
                    }
                  : null,
              icon: Icon(
                Icons.arrow_forward_ios,
                color: _currentIndex < widget.teamMembers.length - 1
                    ? SiriusColors.accent
                    : SiriusColors.accent.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamCard(
    Map<String, String> member,
    bool isActive,
    double blur,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isActive ? 0.3 : 0.1),
            blurRadius: isActive ? 20 : 10,
            offset: Offset(0, isActive ? 10 : 5),
            spreadRadius: isActive ? 2 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image with blur effect
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child:
                  (member['image']!.startsWith('http') ||
                      member['image']!.startsWith('https'))
                  ? Image.network(
                      member['image']!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: SiriusColors.surface),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: SiriusColors.surface,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              color: SiriusColors.accent,
                            ),
                          ),
                        );
                      },
                    )
                  : Image.asset(
                      member['image']!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: SiriusColors.surface),
                    ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            // Member info
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member['name']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cormorant',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member['role']!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontFamily: 'Cormorant',
                    ),
                  ),
                ],
              ),
            ),
            // Active indicator
            if (isActive)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: SiriusColors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.teamMembers.isNotEmpty
                        ? (_resolveActiveBadgeText() ?? 'Active')
                        : 'Active',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _resolveActiveBadgeText() {
    // TeamCarousel3D bu sınıf içinde _icerikBlok yok; HomeScreen başlıkları sabit
    // ve bu rozeti dinamikleştirmek için buraya ekstra parametre geçilmedi.
    // İleride ihtiyaç olursa parametre olarak geçirilebilir.
    return null;
  }
}

// 3D Floating Gallery with Parallax Effect
class Gallery3DFloating extends StatefulWidget {
  final List<String> images;
  final Function(String) onImageTap;

  const Gallery3DFloating({
    super.key,
    required this.images,
    required this.onImageTap,
  });

  @override
  State<Gallery3DFloating> createState() => _Gallery3DFloatingState();
}

class _Gallery3DFloatingState extends State<Gallery3DFloating>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  List<AnimationController>? _floatControllers;
  List<AnimationController>? _scaleControllers;
  List<Animation<double>>? _floatAnimations;
  List<Animation<double>>? _scaleAnimations;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Güvenlik kontrolü - boş liste kontrolü
    if (widget.images.isEmpty) {
      return;
    }

    // Dispose existing controllers if any
    _disposeControllers();

    // Initialize animation controllers for each image
    _floatControllers = List.generate(
      widget.images.length,
      (index) => AnimationController(
        duration: Duration(milliseconds: 2000 + (index * 200)),
        vsync: this,
      ),
    );

    _scaleControllers = List.generate(
      widget.images.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );

    // Create floating animations with different phases
    _floatAnimations = List.generate(
      widget.images.length,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _floatControllers![index],
          curve: Curves.easeInOut,
        ),
      ),
    );

    // Create scale animations
    _scaleAnimations = List.generate(
      widget.images.length,
      (index) => Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(
          parent: _scaleControllers![index],
          curve: Curves.easeOutBack,
        ),
      ),
    );

    // Start floating animations
    _startFloatingAnimations();
  }

  void _disposeControllers() {
    if (_floatControllers?.isNotEmpty ?? false) {
      for (var controller in _floatControllers!) {
        controller.dispose();
      }
    }
    if (_scaleControllers?.isNotEmpty ?? false) {
      for (var controller in _scaleControllers!) {
        controller.dispose();
      }
    }
  }

  @override
  void didUpdateWidget(Gallery3DFloating oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Images listesi değiştiyse animation controller'ları yeniden başlat
    if (oldWidget.images.length != widget.images.length ||
        (widget.images.isNotEmpty && oldWidget.images.isEmpty)) {
      _initializeAnimations();
    }
  }

  void _startFloatingAnimations() {
    // Güvenlik kontrolü - boş liste kontrolü
    if (_floatControllers?.isEmpty ?? true) {
      return;
    }

    for (int i = 0; i < _floatControllers!.length; i++) {
      _floatControllers![i].repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Güvenlik kontrolü - boş liste kontrolü
    if (widget.images.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.width < 600 ? 360 : 600,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Galeri fotoğrafı bulunamadı',
                style: TextStyle(color: Colors.grey[600], fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Parallax effect based on scroll
        setState(() {});
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        child: SizedBox(
          height: MediaQuery.of(context).size.width < 600 ? 360 : 600,
          child: Stack(
            children: List.generate(
              widget.images.length,
              (index) => _buildFloatingImage(index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingImage(int index) {
    // Güvenlik kontrolü - index sınırları ve nullable alanlar
    if (index < 0 ||
        index >= widget.images.length ||
        _floatControllers == null ||
        _scaleControllers == null ||
        _floatAnimations == null ||
        _scaleAnimations == null) {
      return const SizedBox.shrink();
    }

    final image = widget.images[index];
    final isEven = index.isEven;

    // Calculate position based on index and scroll
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final double left = isMobile
        ? (isEven ? 12.0 + (index * 8.0) : screenWidth * 0.5 + (index * 6.0))
        : (isEven
              ? 20.0 + (index * 15.0)
              : screenWidth * 0.55 + (index * 10.0));

    final double top = isMobile ? 24.0 + (index * 56.0) : 50.0 + (index * 80.0);

    // Calculate parallax offset based on scroll
    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final parallaxOffset = (scrollOffset * 0.1) + (index * 0.5);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _floatControllers![index],
        _scaleControllers![index],
      ]),
      builder: (context, child) {
        final floatValue = _floatAnimations![index].value;
        final scaleValue = _scaleAnimations![index].value;

        // Calculate floating movement
        final floatOffset = sin(floatValue * 2 * pi) * 15.0;

        return Positioned(
          left: left,
          top: top + floatOffset + parallaxOffset,
          child: GestureDetector(
            onTap: () => widget.onImageTap(image),
            onTapDown: (_) => _scaleControllers![index].forward(),
            onTapUp: (_) => _scaleControllers![index].reverse(),
            onTapCancel: () => _scaleControllers![index].reverse(),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // Perspective
                ..rotateY(isEven ? 0.1 : -0.1) // Slight rotation
                ..rotateX(0.05) // Slight tilt
                ..multiply(
                  Matrix4.diagonal3Values(scaleValue, scaleValue, scaleValue),
                ),
              child: Container(
                width: isMobile ? screenWidth * 0.72 : 200,
                height: isMobile ? screenWidth * 0.48 : 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: Offset(isEven ? 10 : -10, 10 + floatOffset),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: SiriusColors.accent.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: Offset(isEven ? 15 : -15, 15 + floatOffset),
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background image - Network image for Supabase URLs, Asset for local images
                      image.startsWith('http') || image.startsWith('https')
                          ? Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: SiriusColors.surface),
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: SiriusColors.surface,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                          color: SiriusColors.accent,
                                        ),
                                      ),
                                    );
                                  },
                            )
                          : Image.asset(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: SiriusColors.surface),
                            ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                      // Glowing border effect
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: SiriusColors.accent.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                      ),
                      // Hover effect overlay - removed icon, keeping transparent overlay for tap effect
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
