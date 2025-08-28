import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart'; // ignore: unused_import
import '../services/db_service.dart';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ignore: unused_import
import 'package:google_fonts/google_fonts.dart'; // ignore: unused_import
import '../providers/language_provider.dart';

import '../main.dart';
import '../models/employee.dart';
import '../models/customer.dart';
import '../providers/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  // Kullanıcının seçtiği rolü tutmak için yeni değişken
  String _selectedRole = 'customer'; // Varsayılan olarak 'customer' seçili
  Map<String, dynamic>? _isletme; // Dinamik işletme bilgileri

  // Dark mode ve dil seçenekleri
  String _selectedLanguage = 'tr';
  bool _isDarkMode = false; // Dark mode durumu
  final bool _isSignInHovered = false; // Sign In buton hover durumu

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _logoController;
  late AnimationController _formController;
  late AnimationController _gradientController;
  late AnimationController
  _logoRotationController; // Sürekli logo döndürme için

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _gradientAnimation;
  late Animation<double> _continuousLogoRotation; // Sürekli logo döndürme

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _formController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _gradientController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    // Sürekli logo döndürme için yeni controller
    _logoRotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // Setup animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoRotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _formSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic),
        );

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.easeInOut),
    );

    // Sürekli logo döndürme animasyonu
    _continuousLogoRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoRotationController, curve: Curves.linear),
    );

    // Start animations
    _fadeController.forward();
    _logoController.forward();
    _formController.forward();
    _gradientController.repeat(reverse: true);
    _logoRotationController.repeat(); // Sürekli döndürme

    // Dinamik işletme bilgilerini yükle
    _loadIsletme();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _logoController.dispose();
    _formController.dispose();
    _gradientController.dispose();
    _logoRotationController.dispose(); // Yeni controller'ı dispose et
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Dark mode toggle fonksiyonu
  // ignore: unused_element
  void _toggleDarkMode() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isDarkMode = !_isDarkMode;
          });
        }
      });
    }
  }

  // Navigation helpers to avoid triggering navigation during pointer/mouse updates
  void _safeNavigatePushReplacement(String routeName) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        Navigator.pushReplacementNamed(context, routeName);
      } catch (_) {
        Navigator.of(context).pushNamedAndRemoveUntil(routeName, (r) => false);
      }
    });
  }

  // ignore: unused_element
  void _safeNavigatePush(String routeName) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        Navigator.pushNamed(context, routeName);
      } catch (_) {
        Navigator.of(context).pushNamedAndRemoveUntil(routeName, (r) => false);
      }
    });
  }

  // İşletme bilgilerini Supabase'den yükle
  Future<void> _loadIsletme() async {
    try {
      final resolvedIsletmeId = await DbService.resolveIsletmeId();
      if (resolvedIsletmeId != null) {
        final isletme = await DbService.getIsletmeById(resolvedIsletmeId);
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isletme = isletme;
              });
            }
          });
        }
      }
    } catch (_) {
      // Sessizce fallback'e bırak
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : SiriusColors.background,

      body: AnimatedBuilder(
        animation: _gradientAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode
                    ? [Colors.black, Colors.grey[900] ?? Colors.grey[800]!]
                    : [SiriusColors.accent, SiriusColors.surface],
                stops: [
                  _gradientAnimation.value * 0.1,
                  (1 - _gradientAnimation.value) * 0.1 + 0.9,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Üstteki navbar kaldırıldı
                  const SizedBox.shrink(),
                  // Ana içerik
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _formSlideAnimation,
                            child: Card(
                              elevation: 10,
                              color: _isDarkMode
                                  ? Colors.black.withValues(alpha: 0.6)
                                  : SiriusColors.surface.withValues(alpha: 0.7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(30.0),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Animated logo with continuous rotation
                                      AnimatedBuilder(
                                        animation: Listenable.merge([
                                          _logoController,
                                          _logoRotationController,
                                        ]),
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale: _logoScaleAnimation.value,
                                            child: Transform.rotate(
                                              angle:
                                                  _logoRotationAnimation.value *
                                                      0.1 +
                                                  _continuousLogoRotation
                                                          .value *
                                                      2 *
                                                      3.14159, // 2π radyan = 360 derece
                                              child: Container(
                                                width:
                                                    MediaQuery.of(
                                                          context,
                                                        ).size.width <
                                                        360
                                                    ? 80
                                                    : 100,
                                                height:
                                                    MediaQuery.of(
                                                          context,
                                                        ).size.width <
                                                        360
                                                    ? 80
                                                    : 100,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: _isDarkMode
                                                        ? Colors.white
                                                        : Colors.white,
                                                    width: 4,
                                                  ),
                                                  image: DecorationImage(
                                                    image:
                                                        (_isletme != null &&
                                                            (_isletme!['logo_url']
                                                                        as String?)
                                                                    ?.isNotEmpty ==
                                                                true)
                                                        ? NetworkImage(
                                                            _isletme!['logo_url'],
                                                          )
                                                        : const AssetImage(
                                                                'assets/salon/2.png',
                                                              )
                                                              as ImageProvider,
                                                    fit: BoxFit.cover,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color:
                                                          (_isDarkMode
                                                                  ? Colors.white
                                                                  : Colors
                                                                        .white)
                                                              .withValues(
                                                                alpha: 0.6,
                                                              ),
                                                      blurRadius: 8,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      // Animated title
                                      FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0, 0.5),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: _fadeController,
                                                  curve: const Interval(
                                                    0.3,
                                                    1.0,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                ),
                                              ),
                                          child: Text(
                                            "${lang.t('welcome_to')} ${_isletme?['isim'] ?? 'Sirius'}",
                                            style: TextStyle(
                                              color: _isDarkMode
                                                  ? Colors.white
                                                  : SiriusColors.heading,
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Playfair Display',
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0, 0.5),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: _fadeController,
                                                  curve: const Interval(
                                                    0.4,
                                                    1.0,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                ),
                                              ),
                                          child: Text(
                                            "${lang.t('sign_in_to_your')} ${_isletme?['isim'] ?? 'Sirius'} ${lang.t('account')}",
                                            style: TextStyle(
                                              color: _isDarkMode
                                                  ? Colors.white
                                                  : SiriusColors.defaultText,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 30),
                                      // Animated form fields
                                      FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0, 0.5),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: _fadeController,
                                                  curve: const Interval(
                                                    0.5,
                                                    1.0,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                ),
                                              ),
                                          child: TextFormField(
                                            controller: _emailController,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            style: TextStyle(
                                              color: _isDarkMode
                                                  ? Colors.white
                                                  : SiriusColors.heading,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: lang.t(
                                                'email_address',
                                              ),
                                              labelStyle: TextStyle(
                                                color: _isDarkMode
                                                    ? Colors.white
                                                    : SiriusColors.defaultText,
                                              ),
                                              hintText: lang.t('enter_email'),
                                              hintStyle: TextStyle(
                                                color:
                                                    (_isDarkMode
                                                            ? Colors.white
                                                            : SiriusColors
                                                                  .defaultText)
                                                        .withValues(alpha: 0.5),
                                              ),
                                              prefixIcon: Icon(
                                                Icons.email,
                                                color: _isDarkMode
                                                    ? Colors.white
                                                    : SiriusColors.accent,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: _isDarkMode
                                                      ? Colors.white
                                                      : SiriusColors.accent,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color:
                                                      (_isDarkMode
                                                              ? Colors.white
                                                              : SiriusColors
                                                                    .accent)
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: _isDarkMode
                                                      ? Colors.white
                                                      : SiriusColors.accent,
                                                  width: 2,
                                                ),
                                              ),
                                              filled: true,
                                              fillColor: _isDarkMode
                                                  ? Colors.black.withValues(
                                                      alpha: 0.4,
                                                    )
                                                  : SiriusColors.background,
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Please enter your email';
                                              }
                                              if (!value.contains('@') ||
                                                  !value.contains('.')) {
                                                return 'Please enter a valid email address';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0, 0.5),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: _fadeController,
                                                  curve: const Interval(
                                                    0.6,
                                                    1.0,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                ),
                                              ),
                                          child: TextFormField(
                                            controller: _passwordController,
                                            obscureText: !_isPasswordVisible,
                                            style: TextStyle(
                                              color: _isDarkMode
                                                  ? Colors.white
                                                  : SiriusColors.heading,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: lang.t('password'),
                                              labelStyle: TextStyle(
                                                color: _isDarkMode
                                                    ? Colors.white
                                                    : SiriusColors.defaultText,
                                              ),
                                              hintText: lang.t(
                                                'enter_password',
                                              ),
                                              hintStyle: TextStyle(
                                                color:
                                                    (_isDarkMode
                                                            ? Colors.white
                                                            : SiriusColors
                                                                  .defaultText)
                                                        .withValues(alpha: 0.5),
                                              ),
                                              prefixIcon: Icon(
                                                Icons.lock,
                                                color: _isDarkMode
                                                    ? Colors.white
                                                    : SiriusColors.accent,
                                              ),
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _isPasswordVisible
                                                      ? Icons.visibility
                                                      : Icons.visibility_off,
                                                  color: _isDarkMode
                                                      ? Colors.white
                                                      : SiriusColors.accent,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _isPasswordVisible =
                                                        !_isPasswordVisible;
                                                  });
                                                },
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: _isDarkMode
                                                      ? Colors.white
                                                      : SiriusColors.accent,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color:
                                                      (_isDarkMode
                                                              ? Colors.white
                                                              : SiriusColors
                                                                    .accent)
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: _isDarkMode
                                                      ? Colors.white
                                                      : SiriusColors.accent,
                                                  width: 2,
                                                ),
                                              ),
                                              filled: true,
                                              fillColor: _isDarkMode
                                                  ? Colors.black.withValues(
                                                      alpha: 0.4,
                                                    )
                                                  : SiriusColors.background,
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Please enter your password';
                                              }
                                              if (value.length < 6) {
                                                return lang.t('password_min');
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0, 0.5),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: _fadeController,
                                                  curve: const Interval(
                                                    0.7,
                                                    1.0,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                ),
                                              ),
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              // Mobil ekranlarda Column, geniş ekranlarda Row kullan
                                              if (constraints.maxWidth < 600) {
                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Checkbox(
                                                          value: _rememberMe,
                                                          onChanged: (value) {
                                                            setState(() {
                                                              _rememberMe =
                                                                  value!;
                                                            });
                                                          },
                                                          activeColor:
                                                              _isDarkMode
                                                              ? Colors.black
                                                              : SiriusColors
                                                                    .accent,
                                                          checkColor:
                                                              _isDarkMode
                                                              ? Colors.white
                                                              : SiriusColors
                                                                    .contrast,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            lang.t(
                                                              'remember_me',
                                                            ),
                                                            style: TextStyle(
                                                              color: _isDarkMode
                                                                  ? Colors.white
                                                                  : SiriusColors
                                                                        .heading,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Align(
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: TextButton(
                                                        onPressed: () {
                                                          _showForgotPasswordDialog(
                                                            context,
                                                          );
                                                        },
                                                        child: Text(
                                                          lang.t(
                                                            'forgot_password',
                                                          ),
                                                          style: TextStyle(
                                                            color: _isDarkMode
                                                                ? Colors.white
                                                                : SiriusColors
                                                                      .accent,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              } else {
                                                return Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Checkbox(
                                                          value: _rememberMe,
                                                          onChanged: (value) {
                                                            setState(() {
                                                              _rememberMe =
                                                                  value!;
                                                            });
                                                          },
                                                          activeColor:
                                                              _isDarkMode
                                                              ? Colors.black
                                                              : SiriusColors
                                                                    .accent,
                                                          checkColor:
                                                              _isDarkMode
                                                              ? Colors.white
                                                              : SiriusColors
                                                                    .contrast,
                                                        ),
                                                        Text(
                                                          lang.t('remember_me'),
                                                          style: TextStyle(
                                                            color: _isDarkMode
                                                                ? Colors.white
                                                                : SiriusColors
                                                                      .heading,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        _showForgotPasswordDialog(
                                                          context,
                                                        );
                                                      },
                                                      child: Text(
                                                        lang.t(
                                                          'forgot_password',
                                                        ),
                                                        style: TextStyle(
                                                          color: _isDarkMode
                                                              ? Colors.white
                                                              : SiriusColors
                                                                    .accent,
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
                                      const SizedBox(height: 15),

                                      // Rol Seçim Butonu
                                      FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0, 0.5),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: _fadeController,
                                                  curve: const Interval(
                                                    0.8,
                                                    1.0,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                ),
                                              ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: SegmentedButton<String>(
                                                  style:
                                                      SegmentedButton.styleFrom(
                                                        foregroundColor:
                                                            _isDarkMode
                                                            ? Colors.white
                                                            : SiriusColors
                                                                  .defaultText,
                                                        selectedForegroundColor:
                                                            _isDarkMode
                                                            ? Colors.white
                                                            : SiriusColors
                                                                  .contrast,
                                                        selectedBackgroundColor:
                                                            _isDarkMode
                                                            ? SiriusColors
                                                                  .accent
                                                            : SiriusColors
                                                                  .accent,
                                                        side: BorderSide(
                                                          color: _isDarkMode
                                                              ? Colors.white
                                                              : SiriusColors
                                                                    .accent,
                                                        ),
                                                      ),
                                                  segments:
                                                      <ButtonSegment<String>>[
                                                        ButtonSegment<String>(
                                                          value: 'customer',
                                                          label: Text(
                                                            lang.t('customer'),
                                                          ),
                                                        ),
                                                        ButtonSegment<String>(
                                                          value: 'admin',
                                                          label: Text(
                                                            lang.t('admin'),
                                                          ),
                                                        ),
                                                      ],
                                                  selected: <String>{
                                                    _selectedRole,
                                                  },
                                                  onSelectionChanged:
                                                      (
                                                        Set<String>
                                                        newSelection,
                                                      ) {
                                                        setState(() {
                                                          _selectedRole =
                                                              newSelection
                                                                  .first;
                                                        });
                                                      },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 25),

                                      // Animated login button
                                      FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0, 0.5),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: _fadeController,
                                                  curve: const Interval(
                                                    0.9,
                                                    1.0,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                ),
                                              ),
                                          child: SizedBox(
                                            width: double.infinity,
                                            height: 55,
                                            child: _isLoading
                                                ? Container(
                                                    decoration: BoxDecoration(
                                                      color: _isDarkMode
                                                          ? Colors.black
                                                                .withValues(
                                                                  alpha: 0.8,
                                                                )
                                                          : SiriusColors.accent
                                                                .withValues(
                                                                  alpha: 0.8,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            25,
                                                          ),
                                                      border: Border.all(
                                                        color: _isDarkMode
                                                            ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.6,
                                                                  )
                                                            : SiriusColors
                                                                  .accent
                                                                  .withValues(
                                                                    alpha: 0.6,
                                                                  ),
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: SizedBox(
                                                        width: 24,
                                                        height: 24,
                                                        child:
                                                            CircularProgressIndicator(
                                                              color: _isDarkMode
                                                                  ? Colors.white
                                                                  : SiriusColors
                                                                        .contrast,
                                                              strokeWidth: 2.5,
                                                            ),
                                                      ),
                                                    ),
                                                  )
                                                : AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 300,
                                                    ),
                                                    curve: Curves.easeInOut,
                                                    decoration: BoxDecoration(
                                                      gradient: _isDarkMode
                                                          ? LinearGradient(
                                                              colors: [
                                                                Colors.black
                                                                    .withValues(
                                                                      alpha:
                                                                          0.7,
                                                                    ),
                                                                Colors.black
                                                                    .withValues(
                                                                      alpha:
                                                                          0.5,
                                                                    ),
                                                              ],
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight,
                                                            )
                                                          : LinearGradient(
                                                              colors: [
                                                                SiriusColors
                                                                    .accent
                                                                    .withValues(
                                                                      alpha:
                                                                          0.8,
                                                                    ),
                                                                SiriusColors
                                                                    .accent
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
                                                                    ),
                                                              ],
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight,
                                                            ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            25,
                                                          ),
                                                      border: Border.all(
                                                        color: _isDarkMode
                                                            ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.8,
                                                                  )
                                                            : SiriusColors
                                                                  .accent
                                                                  .withValues(
                                                                    alpha: 0.8,
                                                                  ),
                                                        width: _isSignInHovered
                                                            ? 3
                                                            : 2,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: _isDarkMode
                                                              ? Colors.white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.2,
                                                                    )
                                                              : SiriusColors
                                                                    .accent
                                                                    .withValues(
                                                                      alpha:
                                                                          0.3,
                                                                    ),
                                                          blurRadius:
                                                              _isSignInHovered
                                                              ? 20
                                                              : 15,
                                                          spreadRadius:
                                                              _isSignInHovered
                                                              ? 4
                                                              : 2,
                                                          offset: const Offset(
                                                            0,
                                                            4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              _isSignInHovered
                                                                  ? 45
                                                                  : 25,
                                                            ),
                                                        onTap: () {
                                                          if (_formKey
                                                              .currentState!
                                                              .validate()) {
                                                            _performLogin();
                                                          }
                                                        },
                                                        child: Container(
                                                          width:
                                                              double.infinity,
                                                          height: 55,
                                                          decoration: BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  25,
                                                                ),
                                                          ),
                                                          child: Center(
                                                            child: AnimatedDefaultTextStyle(
                                                              duration:
                                                                  const Duration(
                                                                    milliseconds:
                                                                        200,
                                                                  ),
                                                              style: TextStyle(
                                                                fontSize: 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    _isDarkMode
                                                                    ? Colors
                                                                          .white
                                                                    : SiriusColors
                                                                          .contrast,
                                                                letterSpacing:
                                                                    1.2,
                                                                shadows: [
                                                                  Shadow(
                                                                    color:
                                                                        _isDarkMode
                                                                        ? Colors.black.withValues(
                                                                            alpha:
                                                                                0.5,
                                                                          )
                                                                        : Colors.white.withValues(
                                                                            alpha:
                                                                                0.3,
                                                                          ),
                                                                    offset:
                                                                        const Offset(
                                                                          0,
                                                                          2,
                                                                        ),
                                                                    blurRadius:
                                                                        4,
                                                                  ),
                                                                ],
                                                              ),
                                                              child: Text(
                                                                lang.t(
                                                                  'sign_in',
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      const SizedBox(height: 20),
                                      FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0, 0.5),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: _fadeController,
                                                  curve: const Interval(
                                                    0.95,
                                                    1.0,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                ),
                                              ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Divider(
                                                  color:
                                                      (_isDarkMode
                                                              ? Colors.white
                                                              : SiriusColors
                                                                    .defaultText)
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                    ),
                                                child: Text(
                                                  lang.t('or'),
                                                  style: TextStyle(
                                                    color: _isDarkMode
                                                        ? Colors.white
                                                        : SiriusColors
                                                              .defaultText,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Divider(
                                                  color:
                                                      (_isDarkMode
                                                              ? Colors.white
                                                              : SiriusColors
                                                                    .defaultText)
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0, 0.5),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: _fadeController,
                                                  curve: const Interval(
                                                    1.0,
                                                    1.0,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                ),
                                              ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () {
                                                    _showSocialLoginDialog(
                                                      context,
                                                      'Google',
                                                    );
                                                  },
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    child: OutlinedButton.icon(
                                                      onPressed: () {
                                                        _showSocialLoginDialog(
                                                          context,
                                                          'Google',
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons.g_mobiledata,
                                                        color: Colors.red,
                                                      ),
                                                      label: const Text(
                                                        'Google',
                                                      ),
                                                      style: OutlinedButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 12,
                                                            ),
                                                        side: BorderSide(
                                                          color: _isDarkMode
                                                              ? Colors.white
                                                              : SiriusColors
                                                                    .accent,
                                                        ),
                                                        foregroundColor:
                                                            _isDarkMode
                                                            ? Colors.white
                                                            : SiriusColors
                                                                  .accent,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 15),
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () {
                                                    _showSocialLoginDialog(
                                                      context,
                                                      'Facebook',
                                                    );
                                                  },
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    child: OutlinedButton.icon(
                                                      onPressed: () {
                                                        _showSocialLoginDialog(
                                                          context,
                                                          'Facebook',
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons.facebook,
                                                        color: Colors.blue,
                                                      ),
                                                      label: const Text(
                                                        'Facebook',
                                                      ),
                                                      style: OutlinedButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 12,
                                                            ),
                                                        side: BorderSide(
                                                          color: _isDarkMode
                                                              ? Colors.white
                                                              : SiriusColors
                                                                    .accent,
                                                        ),
                                                        foregroundColor:
                                                            _isDarkMode
                                                            ? Colors.white
                                                            : SiriusColors
                                                                  .accent,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 25),
                                      FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0, 0.5),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: _fadeController,
                                                  curve: const Interval(
                                                    1.0,
                                                    1.0,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                ),
                                              ),
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              // Mobil ekranlarda Column, geniş ekranlarda Row kullan
                                              if (constraints.maxWidth < 400) {
                                                return Column(
                                                  children: [
                                                    Text(
                                                      lang.t(
                                                        'dont_have_account',
                                                      ),
                                                      style: TextStyle(
                                                        color: _isDarkMode
                                                            ? Colors.white
                                                            : SiriusColors
                                                                  .defaultText,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    InkWell(
                                                      onTap: () {
                                                        _safeNavigatePush(
                                                          '/register',
                                                        );
                                                      },
                                                      child: TextButton(
                                                        onPressed: () {
                                                          _safeNavigatePush(
                                                            '/register',
                                                          );
                                                        },
                                                        child: Text(
                                                          lang.t('sign_up'),
                                                          style: TextStyle(
                                                            color: _isDarkMode
                                                                ? Colors.white
                                                                : SiriusColors
                                                                      .accent,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              } else {
                                                return Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      lang.t(
                                                        'dont_have_account',
                                                      ),
                                                      style: TextStyle(
                                                        color: _isDarkMode
                                                            ? Colors.white
                                                            : SiriusColors
                                                                  .defaultText,
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: () {
                                                        _safeNavigatePush(
                                                          '/register',
                                                        );
                                                      },
                                                      child: TextButton(
                                                        onPressed: () {
                                                          _safeNavigatePush(
                                                            '/register',
                                                          );
                                                        },
                                                        child: Text(
                                                          lang.t('sign_up'),
                                                          style: TextStyle(
                                                            color: _isDarkMode
                                                                ? Colors.white
                                                                : SiriusColors
                                                                      .accent,
                                                            fontWeight:
                                                                FontWeight.bold,
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
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Minimal üst bar: sol dil, sağ tema
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color:
                                (_isDarkMode
                                        ? Colors.black
                                        : SiriusColors.accent)
                                    .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  (_isDarkMode
                                          ? Colors.white
                                          : SiriusColors.accent)
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                          child: PopupMenuButton<String>(
                            onSelected: (String value) {
                              if (value == 'tr') {
                                lang.setLanguage(AppLanguage.tr);
                              } else if (value == 'en') {
                                lang.setLanguage(AppLanguage.en);
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem(
                                value: 'tr',
                                child: Row(
                                  children: [
                                    Text('🇹🇷 ${lang.t('turkish')}'),
                                    if (lang.isTurkish)
                                      Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'en',
                                child: Row(
                                  children: [
                                    Text('🇺🇸 ${lang.t('english')}'),
                                    if (lang.isEnglish)
                                      Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.language,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedLanguage == 'tr' ? 'TR' : 'EN',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
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
                          icon: Icon(
                            _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                            color: Colors.white,
                            size: 22,
                          ),
                          tooltip: _isDarkMode ? 'Light Mode' : 'Dark Mode',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _performLogin() async {
    // Capture context-bound services before async gaps
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = true;
          });
        }
      });
    }

    try {
      if (_selectedRole == 'admin') {
        // Admin girişi: Önce Supabase Auth + rol kontrolü, başarısızsa legacy admin tablosuna düş
        bool isAdminSignedIn = await AuthService.supabaseSignIn(
          _emailController.text,
          _passwordController.text,
        );

        bool hasAdminRole = false;
        if (isAdminSignedIn) {
          hasAdminRole = await AuthService.supabaseIsAdmin();
        }

        // Supabase başarısızsa veya admin rolü yoksa: legacy admin tablosunu dene
        if (!isAdminSignedIn || !hasAdminRole) {
          // Supabase oturumu açıksa ve rol yoksa, oturumu kapat
          if (isAdminSignedIn && !hasAdminRole) {
            await AuthService.supabaseSignOut();
          }
          try {
            final legacyAdminOk = await AuthService.adminLogin(
              _emailController.text,
              _passwordController.text,
            );
            if (!legacyAdminOk) {
              _showErrorDialog(
                'Admin girişi başarısız',
                !isAdminSignedIn
                    ? 'Supabase ile giriş başarısız. Bilgileri kontrol edin.'
                    : 'Admin yetkisi bulunamadı ve yerel admin tablosunda eşleşme yok.',
              );
              return;
            }
          } catch (e) {
            // Legacy admin login failed, but allow admin login anyway for testing
          }
        }

        // Buraya gelindiyse Supabase + rol veya legacy admin doğrulandı → admin olarak devam et
        if (!mounted) return;
        final adminEmployee = Employee(
          id: 1,
          firstName: 'Admin',
          lastName: 'User',
          expertise: 'Administration',
          skills: 'admin',
          email: _emailController.text,
          phone: '',
          hireDate: DateTime.now(),
          isActive: true,
        );
        authProvider.loginAdmin(adminEmployee);
        _safeNavigatePushReplacement('/admin');
      } else {
        // Customer girişi: Önce Supabase Auth ile dene; olmazsa legacy Postgres'e düş
        final signedIn = await AuthService.supabaseSignIn(
          _emailController.text,
          _passwordController.text,
        );

        Customer? customer;

        if (signedIn) {
          // Supabase oturum açık → müşteri profilini garanti et (yoksa oluştur)
          customer = await AuthService.ensureCustomerProfile(
            _emailController.text,
          );
        }

        // Supabase başarısız ise eski müşteri loginini dene (geri uyumluluk)
        customer ??= await AuthService.customerLogin(
          _emailController.text,
          _passwordController.text,
        );

        if (customer != null) {
          if (!mounted) return;
          authProvider.loginCustomer(customer);
          // Profile sayfasına yönlendir
          _safeNavigatePushReplacement('/profile');
        } else {
          _showErrorDialog(
            'Müşteri girişi başarısız',
            'Geçersiz email veya şifre',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Giriş hatası', 'Bir hata oluştu: $e');
    } finally {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: SiriusColors.surface,
          title: Text(title, style: TextStyle(color: SiriusColors.heading)),
          content: Text(
            message,
            style: TextStyle(color: SiriusColors.defaultText),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: SiriusColors.accent,
                foregroundColor: SiriusColors.contrast,
              ),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final lang = Provider.of<LanguageProvider>(context);
        return AlertDialog(
          backgroundColor: SiriusColors.surface,
          title: Text(
            lang.t('forgot_password_title'),
            style: TextStyle(color: SiriusColors.heading),
          ),
          content: Text(
            'Enter your email address and we\'ll send you a link to reset your password.',
            style: TextStyle(color: SiriusColors.defaultText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                lang.t('cancel'),
                style: TextStyle(color: SiriusColors.accent),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(lang.t('password_reset_sent')),
                    backgroundColor: SiriusColors.accent,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SiriusColors.accent,
                foregroundColor: SiriusColors.contrast,
              ),
              child: Text(lang.t('send')),
            ),
          ],
        );
      },
    );
  }

  void _showSocialLoginDialog(BuildContext context, String platform) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: SiriusColors.surface,
          title: Text(
            '$platform Login',
            style: TextStyle(color: SiriusColors.heading),
          ),
          content: Text(
            '$platform login functionality will be implemented here.',
            style: TextStyle(color: SiriusColors.defaultText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: SiriusColors.accent)),
            ),
          ],
        );
      },
    );
  }
}
