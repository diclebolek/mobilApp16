import 'package:flutter/material.dart';
import 'package:hairsalon_flutter/constants/colors.dart';
import 'package:hairsalon_flutter/constants/dimensions.dart';
import 'package:hairsalon_flutter/services/auth_service.dart';
import 'package:hairsalon_flutter/services/db_service.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _agreeToTerms = false;
  bool _agreeToMarketing = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  Map<String, dynamic>? _isletme;

  // Basit animasyonlar (login tasarımına uyum için)
  late AnimationController _fadeController;
  late AnimationController _gradientController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _gradientController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _formSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
        );
    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _gradientController.repeat(reverse: true);
    _selectedDate = DateTime.now();
    _selectedTime = const TimeOfDay(hour: 10, minute: 0);
    _loadIsletme();
  }

  Future<void> _loadIsletme() async {
    try {
      final resolvedIsletmeId = await DbService.resolveIsletmeId();
      if (resolvedIsletmeId != null) {
        final isletme = await DbService.getIsletmeById(resolvedIsletmeId);
        if (mounted) {
          setState(() {
            _isletme = isletme;
          });
        }
      }
    } catch (_) {
      // Sessizce fallback'e bırak
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive tasarım için ekran boyutlarını al
    final lang = Provider.of<LanguageProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTinyMobile = screenWidth <= AppDimensions.tinyMobileBreakpoint;
    final isSmallMobile = screenWidth <= AppDimensions.smallMobileBreakpoint;

    return Scaffold(
      backgroundColor: SiriusColors.background,
      extendBodyBehindAppBar: true,
      body: AnimatedBuilder(
        animation: _gradientAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [SiriusColors.accent, SiriusColors.surface],
                stops: [
                  _gradientAnimation.value * 0.1,
                  (1 - _gradientAnimation.value) * 0.1 + 0.9,
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: AppDimensions.getResponsivePadding(context),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _formSlideAnimation,
                      child: Card(
                        elevation: 10,
                        color: SiriusColors.surface.withValues(alpha: 0.7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.getResponsiveRadius(context),
                          ),
                        ),
                        child: Container(
                          width: screenWidth > AppDimensions.mobileBreakpoint
                              ? screenWidth * 0.4
                              : double.infinity,
                          padding: EdgeInsets.all(
                            AppDimensions.getResponsiveSpacing(context) * 2,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Back button in top left
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: Icon(
                                      Icons.arrow_back,
                                      color: SiriusColors.heading,
                                      size: 24,
                                    ),
                                    tooltip: 'Geri Dön',
                                  ),
                                ),
                                SizedBox(
                                  height: AppDimensions.getResponsiveSpacing(
                                    context,
                                  ),
                                ),
                                // Logo/Icon
                                Container(
                                  width: AppDimensions.getResponsiveIconSize(
                                    context,
                                    tiny: 60,
                                    small: 70,
                                    medium: 80,
                                    large: 90,
                                  ),
                                  height: AppDimensions.getResponsiveIconSize(
                                    context,
                                    tiny: 60,
                                    small: 70,
                                    medium: 80,
                                    large: 90,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SiriusColors.accent,
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.getResponsiveRadius(
                                        context,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.person_add,
                                    size: AppDimensions.getResponsiveIconSize(
                                      context,
                                      tiny: 30,
                                      small: 35,
                                      medium: 40,
                                      large: 45,
                                    ),
                                    color: SiriusColors.contrast,
                                  ),
                                ),
                                SizedBox(
                                  height: AppDimensions.getResponsiveSpacing(
                                    context,
                                  ),
                                ),

                                // Title
                                Text(
                                  lang.t('join') + ' ${_isletme?['isim'] ?? 'Sirius'}',
                                  style: TextStyle(
                                    color: SiriusColors.heading,
                                    fontSize:
                                        AppDimensions.getResponsiveFontSize(
                                          context,
                                          tiny: 18,
                                          small: 20,
                                          medium: 22,
                                          large: 24,
                                          xlarge: 26,
                                        ),
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Playfair Display',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(
                                  height:
                                      AppDimensions.getResponsiveSpacing(
                                        context,
                                      ) /
                                      2,
                                ),
                                Text(
                                  lang.t('create_account_description').replaceAll('{business}', _isletme?['isim'] ?? 'Sirius'),
                                  style: TextStyle(
                                    color: SiriusColors.defaultText,
                                    fontSize:
                                        AppDimensions.getResponsiveFontSize(
                                          context,
                                          tiny: 12,
                                          small: 13,
                                          medium: 14,
                                          large: 15,
                                          xlarge: 16,
                                        ),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(
                                  height:
                                      AppDimensions.getResponsiveSpacing(
                                        context,
                                      ) *
                                      2,
                                ),

                                // Form Fields
                                _buildFormFields(
                                  context,
                                  isTinyMobile,
                                  isSmallMobile,
                                ),

                                SizedBox(
                                  height:
                                      AppDimensions.getResponsiveSpacing(
                                        context,
                                      ) *
                                      2,
                                ),

                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  height:
                                      AppDimensions.getResponsiveButtonHeight(
                                        context,
                                      ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          SiriusColors.accent.withValues(
                                            alpha: 0.8,
                                          ),
                                          SiriusColors.accent.withValues(
                                            alpha: 0.6,
                                          ),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.getResponsiveRadius(
                                          context,
                                        ),
                                      ),
                                      border: Border.all(
                                        color: SiriusColors.accent.withValues(
                                          alpha: 0.8,
                                        ),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: SiriusColors.accent.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 15,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(
                                          AppDimensions.getResponsiveRadius(
                                            context,
                                          ),
                                        ),
                                        onTap: _isLoading ? null : _submitForm,
                                        child: Center(
                                          child: _isLoading
                                              ? SizedBox(
                                                  height:
                                                      AppDimensions.getResponsiveIconSize(
                                                        context,
                                                      ),
                                                  width:
                                                      AppDimensions.getResponsiveIconSize(
                                                        context,
                                                      ),
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: SiriusColors
                                                            .contrast,
                                                        strokeWidth: 2.5,
                                                      ),
                                                )
                                              : Text(
                                                  lang.t('create_account'),
                                                  style: TextStyle(
                                                    fontSize:
                                                        AppDimensions.getResponsiveFontSize(
                                                          context,
                                                          tiny: 14,
                                                          small: 15,
                                                          medium: 16,
                                                          large: 17,
                                                          xlarge: 18,
                                                        ),
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        SiriusColors.contrast,
                                                    letterSpacing: 1.1,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(
                                  height: AppDimensions.getResponsiveSpacing(
                                    context,
                                  ),
                                ),

                                // Login Link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      lang.t('already_have_account') + ' ',
                                      style: TextStyle(
                                        color: SiriusColors.defaultText,
                                        fontSize:
                                            AppDimensions.getResponsiveFontSize(
                                              context,
                                              tiny: 12,
                                              small: 13,
                                              medium: 14,
                                              large: 15,
                                              xlarge: 16,
                                            ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pushReplacementNamed(
                                            context,
                                            '/login',
                                          ),
                                      child: Text(
                                        lang.t('sign_in'),
                                        style: TextStyle(
                                          color: SiriusColors.accent,
                                          fontSize:
                                              AppDimensions.getResponsiveFontSize(
                                                context,
                                                tiny: 12,
                                                small: 13,
                                                medium: 14,
                                                large: 15,
                                                xlarge: 16,
                                              ),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
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
          );
        },
      ),
    );
  }

  Widget _buildFormFields(
    BuildContext context,
    bool isTinyMobile,
    bool isSmallMobile,
  ) {
    return Column(
      children: [
        // First Name and Last Name
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  labelStyle: TextStyle(
                    color: SiriusColors.heading.withValues(alpha: 0.9),
                  ),
                  hintText: 'Your first name',
                  hintStyle: TextStyle(
                    color: SiriusColors.defaultText.withValues(alpha: 0.7),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.getResponsiveRadius(context),
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.getResponsiveSpacing(context),
                    vertical: AppDimensions.getResponsiveSpacing(context),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'First name is required';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: AppDimensions.getResponsiveSpacing(context)),
            Expanded(
              child: TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  labelStyle: TextStyle(
                    color: SiriusColors.heading.withValues(alpha: 0.9),
                  ),
                  hintText: 'Your last name',
                  hintStyle: TextStyle(
                    color: SiriusColors.defaultText.withValues(alpha: 0.7),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.getResponsiveRadius(context),
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.getResponsiveSpacing(context),
                    vertical: AppDimensions.getResponsiveSpacing(context),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Last name is required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        SizedBox(height: AppDimensions.getResponsiveSpacing(context)),

        // Email
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email',
            labelStyle: TextStyle(
              color: SiriusColors.heading.withValues(alpha: 0.9),
            ),
            hintText: 'name@example.com',
            hintStyle: TextStyle(
              color: SiriusColors.defaultText.withValues(alpha: 0.7),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppDimensions.getResponsiveRadius(context),
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppDimensions.getResponsiveSpacing(context),
              vertical: AppDimensions.getResponsiveSpacing(context),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          onChanged: (value) {
            // Email validation happens in real-time
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email is required';
            }
            final email = value.trim();
            if (email.isEmpty) {
              return 'Email cannot be empty';
            }
            if (!email.contains('@')) {
              return 'Please enter a valid email';
            }
            // More strict email validation
            final emailRegex = RegExp(
              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
            );
            if (!emailRegex.hasMatch(email)) {
              return 'Please enter a valid email format (e.g., name@domain.com)';
            }
            // Check for common invalid patterns
            if (email.startsWith('@') || email.endsWith('@')) {
              return 'Email cannot start or end with @';
            }
            if (email.contains('..') || email.contains('@@')) {
              return 'Email contains invalid characters';
            }
            return null;
          },
        ),
        SizedBox(height: AppDimensions.getResponsiveSpacing(context)),

        // Phone
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: 'Phone',
            labelStyle: TextStyle(
              color: SiriusColors.heading.withValues(alpha: 0.9),
            ),
            hintText: '+90 5xx xxx xx xx',
            hintStyle: TextStyle(
              color: SiriusColors.defaultText.withValues(alpha: 0.7),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppDimensions.getResponsiveRadius(context),
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppDimensions.getResponsiveSpacing(context),
              vertical: AppDimensions.getResponsiveSpacing(context),
            ),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Phone is required';
            }
            return null;
          },
        ),
        SizedBox(height: AppDimensions.getResponsiveSpacing(context)),

        // Date and Time Selection
        Text(
          'Preferred Date & Time',
          style: TextStyle(
            color: SiriusColors.heading.withValues(alpha: 0.9),
            fontSize: AppDimensions.getResponsiveFontSize(
              context,
              tiny: 14,
              small: 15,
              medium: 16,
              large: 17,
              xlarge: 18,
            ),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppDimensions.getResponsiveSpacing(context) / 2),

        // Date Selection
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.calendar_today,
            color: const Color(0xFFD2A6F5),
            size: AppDimensions.getResponsiveIconSize(context),
          ),
          title: Text(
            'Date: ${_selectedDate?.day ?? DateTime.now().day}/${_selectedDate?.month ?? DateTime.now().month}/${_selectedDate?.year ?? DateTime.now().year}',
            style: TextStyle(
              color: SiriusColors.heading.withValues(alpha: 0.9),
              fontSize: AppDimensions.getResponsiveFontSize(
                context,
                tiny: 12,
                small: 13,
                medium: 14,
                large: 15,
                xlarge: 16,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: ElevatedButton(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  final theme = Theme.of(context);
                  return Theme(
                    data: theme.copyWith(
                      colorScheme: theme.colorScheme.copyWith(
                        primary: SiriusColors.accent,
                        onPrimary: SiriusColors.contrast,
                        surface: const Color(0xFFE0E0E0),
                        onSurface: Colors.black,
                        onSurfaceVariant: Colors.black,
                        onSecondary: Colors.black,
                        secondary: SiriusColors.accent.withValues(alpha: 0.8),
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: SiriusColors.accent,
                        ),
                      ),
                      textTheme: theme.textTheme.copyWith(
                        bodyLarge: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.black,
                        ),
                        bodyMedium: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black,
                        ),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                setState(() {
                  _selectedDate = date;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SiriusColors.accent,
              foregroundColor: SiriusColors.contrast,
              padding: EdgeInsets.symmetric(
                horizontal: AppDimensions.getResponsiveSpacing(context),
                vertical: AppDimensions.getResponsiveSpacing(context) / 2,
              ),
              minimumSize: Size(
                AppDimensions.getResponsiveButtonHeight(context),
                AppDimensions.getResponsiveButtonHeight(context) * 0.8,
              ),
            ),
            child: Text(
              'Select Date',
              style: TextStyle(
                color: SiriusColors.contrast,
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
        ),

        // Time Selection
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.access_time,
            color: const Color(0xFFF5928E),
            size: AppDimensions.getResponsiveIconSize(context),
          ),
          title: Text(
            'Time: ${_selectedTime?.format(context) ?? '10:00 AM'}',
            style: TextStyle(
              color: SiriusColors.heading.withValues(alpha: 0.9),
              fontSize: AppDimensions.getResponsiveFontSize(
                context,
                tiny: 12,
                small: 13,
                medium: 14,
                large: 15,
                xlarge: 16,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: ElevatedButton(
            onPressed: () async {
              final time = await showTimePicker(
                context: context,
                initialTime:
                    _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
                builder: (context, child) {
                  final theme = Theme.of(context);
                  return Theme(
                    data: theme.copyWith(
                      colorScheme: theme.colorScheme.copyWith(
                        primary: SiriusColors.accent,
                        onPrimary: SiriusColors.contrast,
                        surface: const Color(0xFFE0E0E0),
                        onSurface: Colors.black,
                        onSurfaceVariant: Colors.black,
                        onSecondary: Colors.black,
                        secondary: SiriusColors.accent.withValues(alpha: 0.8),
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: SiriusColors.accent,
                        ),
                      ),
                      textTheme: theme.textTheme.copyWith(
                        bodyLarge: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.black,
                        ),
                        bodyMedium: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black,
                        ),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (time != null) {
                setState(() {
                  _selectedTime = time;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SiriusColors.accent,
              foregroundColor: SiriusColors.contrast,
              padding: EdgeInsets.symmetric(
                horizontal: AppDimensions.getResponsiveSpacing(context),
                vertical: AppDimensions.getResponsiveSpacing(context) / 2,
              ),
              minimumSize: Size(
                AppDimensions.getResponsiveButtonHeight(context),
                AppDimensions.getResponsiveButtonHeight(context) * 0.8,
              ),
            ),
            child: Text(
              'Select Time',
              style: TextStyle(
                color: SiriusColors.contrast,
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
        ),

        SizedBox(height: AppDimensions.getResponsiveSpacing(context)),

        // Password
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: TextStyle(
              color: SiriusColors.heading.withValues(alpha: 0.9),
            ),
            hintText: 'At least 6 characters',
            hintStyle: TextStyle(
              color: SiriusColors.defaultText.withValues(alpha: 0.7),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppDimensions.getResponsiveRadius(context),
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppDimensions.getResponsiveSpacing(context),
              vertical: AppDimensions.getResponsiveSpacing(context),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: SiriusColors.heading.withValues(alpha: 0.7),
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
          obscureText: !_isPasswordVisible,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        SizedBox(height: AppDimensions.getResponsiveSpacing(context)),

        // Confirm Password
        TextFormField(
          controller: _confirmPasswordController,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            labelStyle: TextStyle(
              color: SiriusColors.heading.withValues(alpha: 0.9),
            ),
            hintText: 'Re-enter your password',
            hintStyle: TextStyle(
              color: SiriusColors.defaultText.withValues(alpha: 0.7),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppDimensions.getResponsiveRadius(context),
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppDimensions.getResponsiveSpacing(context),
              vertical: AppDimensions.getResponsiveSpacing(context),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isConfirmPasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: SiriusColors.heading.withValues(alpha: 0.7),
              ),
              onPressed: () {
                setState(() {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
            ),
          ),
          obscureText: !_isConfirmPasswordVisible,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        SizedBox(height: AppDimensions.getResponsiveSpacing(context)),

        // Terms and Marketing
        Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: _agreeToTerms,
                  onChanged: (value) {
                    setState(() {
                      _agreeToTerms = value ?? false;
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    'I agree to the Terms and Conditions',
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
            Row(
              children: [
                Checkbox(
                  value: _agreeToMarketing,
                  onChanged: (value) {
                    setState(() {
                      _agreeToMarketing = value ?? false;
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    'I agree to receive marketing communications',
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
          ],
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms and Conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if Supabase is properly configured
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Additional validation before submission
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Please fill in all required fields');
      }

      // Form validation passed, submit registration to Supabase (Auth + musteriler)
      final ok = await AuthService.supabaseRegisterCustomer(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: email,
        phone: _phoneController.text.trim(),
        password: password,
      );

      if (!ok) {
        final message = 'Registration failed';

        // Check for specific error types
        if (message.contains('Database connection failed')) {
          throw Exception(
            'Unable to connect to the server. Please check your internet connection and try again.',
          );
        } else if (message.contains('Email address format')) {
          throw Exception(
            'Please enter a valid email address (e.g., name@domain.com)',
          );
        } else if (message.contains('already exists')) {
          throw Exception(
            'An account with this email already exists. Please sign in instead.',
          );
        } else if (message.contains('weak password')) {
          throw Exception(
            'Password is too weak. Please use a stronger password (at least 6 characters).',
          );
        } else {
          throw Exception(message);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created successfully! Please verify your email if required.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error creating account: $e';

        // Remove the "Exception: " prefix for cleaner display
        if (errorMessage.startsWith('Error creating account: Exception: ')) {
          errorMessage = errorMessage.replaceFirst(
            'Error creating account: Exception: ',
            '',
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _gradientController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
