import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';

import 'package:hairsalon_flutter/constants/colors.dart';
import 'package:hairsalon_flutter/constants/dimensions.dart';
import 'package:hairsalon_flutter/constants/animations.dart';
import 'package:hairsalon_flutter/models/appointment.dart';
import 'package:hairsalon_flutter/models/employee.dart';
import 'package:hairsalon_flutter/models/service.dart';

import 'package:hairsalon_flutter/services/db_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  // Logger instance
  final Logger logger = Logger();

  // Form key
  final _formKey = GlobalKey<FormState>();

  // State variables
  String? _selectedService;
  String? _selectedEmployee;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _notes = '';
  bool _isLoading = false;
  bool _isLoadingTimeSlots = false;
  List<Service> _services = [];
  List<Employee> _employees = [];
  List<TimeOfDay> _availableTimeSlots = [];

  List<TimeOfDay> _buildStaticTimeList() {
    final List<TimeOfDay> times = [];
    for (int hour = 9; hour <= 19; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        times.add(TimeOfDay(hour: hour, minute: minute));
      }
    }
    return times;
  }

  String? _isletmeId;
  Map<String, dynamic>? _isletme;

  // Dark mode durumu
  bool _isDarkMode = false;

  // Tema rengini çözümle
  Color _resolveThemeColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return const Color(0xFF228AE6); // Varsayılan mavi
    }
    try {
      hexColor = hexColor.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      } else if (hexColor.length == 8) {
        return Color(int.parse(hexColor, radix: 16));
      }
    } catch (e) {
      // Hata durumunda varsayılan renk
    }
    return const Color(0xFF228AE6);
  }

  // Tarih seçimi
  Future<void> _selectDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate!,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: _resolveThemeColor(_isletme?['tema_rengi']),
              onPrimary: Colors.white,
              surface: _isDarkMode ? Colors.black : Colors.white,
              onSurface: _isDarkMode ? Colors.white : Colors.black,
              onSurfaceVariant: _isDarkMode ? Colors.white : Colors.black,
              onSecondary: _isDarkMode ? Colors.white : Colors.black,
              secondary: _resolveThemeColor(
                _isletme?['tema_rengi'],
              ).withValues(alpha: 0.8),
            ),
            dialogBackgroundColor: _isDarkMode ? Colors.black : Colors.white,
            datePickerTheme: DatePickerThemeData(
              backgroundColor: _isDarkMode ? Colors.black : Colors.white,
              headerForegroundColor: _isDarkMode ? Colors.white : Colors.black,
              dayForegroundColor: WidgetStateProperty.all(
                _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _resolveThemeColor(_isletme?['tema_rengi']),
              ),
            ),
            textTheme: theme.textTheme.copyWith(
              bodyLarge: theme.textTheme.bodyLarge?.copyWith(
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
              bodyMedium: theme.textTheme.bodyMedium?.copyWith(
                color: _isDarkMode ? Colors.white : Colors.black,
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
      _onDateChanged(date);
    }
  }

  // Saat seçimi
  Future<void> _selectTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: _resolveThemeColor(_isletme?['tema_rengi']),
              onPrimary: Colors.white,
              surface: _isDarkMode ? Colors.black : Colors.white,
              onSurface: _isDarkMode ? Colors.white : Colors.black,
              onSurfaceVariant: _isDarkMode ? Colors.white : Colors.black,
              onSecondary: _isDarkMode ? Colors.white : Colors.black,
              secondary: _resolveThemeColor(
                _isletme?['tema_rengi'],
              ).withValues(alpha: 0.8),
            ),
            dialogBackgroundColor: _isDarkMode ? Colors.black : Colors.white,
            timePickerTheme: TimePickerThemeData(
              backgroundColor: _isDarkMode ? Colors.black : Colors.white,
              dialBackgroundColor: _isDarkMode ? Colors.black : Colors.white,
              hourMinuteTextColor: _isDarkMode ? Colors.white : Colors.black,
              helpTextStyle: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _resolveThemeColor(_isletme?['tema_rengi']),
              ),
            ),
            textTheme: theme.textTheme.copyWith(
              bodyLarge: theme.textTheme.bodyLarge?.copyWith(
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
              bodyMedium: theme.textTheme.bodyMedium?.copyWith(
                color: _isDarkMode ? Colors.white : Colors.black,
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
  }

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

  // Drawer kontrolü için Scaffold key
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Test method to check Supabase connection
  Future<void> _testSupabaseConnection() async {
    try {
      logger.d('Supabase bağlantı testi başladı');
      final client = Supabase.instance.client;

      // Test isletme table access
      final isletmeResult = await client
          .from('isletme')
          .select('isletme_id, ad')
          .limit(1);
      logger.d('İşletme tablosu erişimi: ${isletmeResult.length} kayıt');

      // Test menu_hizmet_icerigi table access
      final hizmetResult = await client
          .from('menu_hizmet_icerigi')
          .select('hizmet, fiyat, kategori')
          .limit(1);
      logger.d('Hizmet tablosu erişimi: ${hizmetResult.length} kayıt');

      // Test calisanlar table access
      final calisanResult = await client
          .from('calisanlar')
          .select('id, ad, hizmet')
          .limit(1);
      logger.d('Çalışan tablosu erişimi: ${calisanResult.length} kayıt');

      logger.d('Supabase bağlantı testi başarılı');
    } catch (e) {
      logger.e('Supabase bağlantı testi hatası: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // Varsayılan değerleri ayarla
    _selectedDate = DateTime.now();
    _selectedTime = const TimeOfDay(hour: 10, minute: 0);
    _notes = '';

    // Supabase bağlantısını test et
    _testSupabaseConnection();

    _loadData();
    _loadIsletme();
  }

  Future<void> _reloadEmployeesByHizmet(String? hizmet) async {
    if (!mounted) return;

    if (hizmet == null || hizmet.isEmpty) {
      // Hizmet seçilmemişse tüm çalışanları getir
      await _loadServices();
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      await _ensureIsletmeId();

      List<Employee> employees = [];

      if (_isletmeId != null && _isletmeId!.isNotEmpty) {
        // Seçilen hizmete göre sadece eşleşen çalışanları getir
        employees = await DbService.getEmployeesByServiceFromSupabase(
          _isletmeId!,
          hizmet,
        );
      } else {
        // isletme_id yoksa eski metodu kullan
        employees.addAll(await DbService.getEmployees());
      }

      if (mounted) {
        setState(() {
          _employees = employees;
          _isLoading = false;
        });

        // Çalışan seçilmemişse ilk çalışanı seç
        if (_employees.isNotEmpty && _selectedEmployee == null) {
          _selectedEmployee = _employees.first.fullName;
        }
      }
    } catch (e) {
      logger.e('Hizmete göre çalışan yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _ensureIsletmeId() async {
    if (_isletmeId == null || _isletmeId!.isEmpty) {
      // Sabit işletme ID kullan (CSV'den alınan)
      _isletmeId = '951e6a49-a509-49a5-9406-d735b3950b67';
    }
  }

  Future<void> _loadData() async {
    await _loadServices();
  }

  Future<void> _loadServices() async {
    if (!mounted) return;

    logger.d('Hizmet yükleme başladı');
    setState(() {
      _isLoading = true;
    });

    await _ensureIsletmeId();
    logger.d('İşletme ID: $_isletmeId');

    // Hizmetler: menu_hizmet_icerigi tablosundan Supabase üzerinden yükle
    List<Service> services = [];
    try {
      if (_isletmeId != null && _isletmeId!.isNotEmpty) {
        logger.d('Supabase\'den hizmetler yükleniyor...');
        // Yeni DbService metodunu kullan
        services = await DbService.getServicesFromSupabase(_isletmeId!);
        logger.d('Supabase\'den ${services.length} hizmet yüklendi');

        if (services.isEmpty) {
          logger.w('Supabase\'den hizmet bulunamadı, fallback deneniyor...');
          // Hizmet bulunamadıysa fallback olarak eski metodu dene
          services = await DbService.getServices();
          logger.d('Fallback ile ${services.length} hizmet yüklendi');
        }
      } else {
        logger.w('İşletme ID yok, eski metot kullanılıyor...');
        // isletme_id yoksa eski metodu kullan
        services = await DbService.getServices();
        logger.d('Eski metot ile ${services.length} hizmet yüklendi');
      }
    } catch (e) {
      logger.e('Hizmet yükleme hatası: $e');
      // Hata durumunda eski metodu dene
      try {
        services = await DbService.getServices();
        logger.d(
          'Hata sonrası fallback ile ${services.length} hizmet yüklendi',
        );
      } catch (fallbackError) {
        logger.e('Fallback hizmet yükleme hatası: $fallbackError');
        services = [];
      }
    }

    // Çalışanlar: Supabase 'calisanlar' üzerinden
    final employees = <Employee>[];
    try {
      if (_isletmeId != null && _isletmeId!.isNotEmpty) {
        logger.d('Supabase\'den çalışanlar yükleniyor...');
        // Eğer hizmet seçilmişse, o hizmete göre çalışanları getir
        if (_selectedService != null && _selectedService!.isNotEmpty) {
          employees.addAll(
            await DbService.getEmployeesByServiceFromSupabase(
              _isletmeId!,
              _selectedService!,
            ),
          );
          logger.d('Hizmete göre ${employees.length} çalışan yüklendi');
        } else {
          logger.d('Tüm aktif çalışanlar yükleniyor...');
          // Hizmet seçilmemişse tüm aktif çalışanları getir
          final supa = Supabase.instance.client;
          final rows = await supa
              .from('calisanlar')
              .select(
                'id, ad, soyad, hizmet, uzmanlik, beceriler, resim_url, sira, aktif, created_at',
              )
              .eq('isletme_id', _isletmeId!)
              .eq('aktif', true)
              .order('sira', ascending: true)
              .order('created_at', ascending: true);

          for (final row in rows) {
            employees.add(
              Employee(
                id: (row['id'] as num?)?.toInt(),
                firstName: row['ad'] ?? '',
                lastName: row['soyad'] ?? '',
                expertise: row['uzmanlik'] ?? 'Genel',
                skills: row['beceriler'] ?? '',
                prolificacy: null,
                dailyEarnings: null,
                serviceId: null,
                email: null,
                phone: null,
                isActive: row['aktif'] ?? true,
                hireDate: row['created_at'] != null
                    ? DateTime.parse(row['created_at'].toString())
                    : null,
                profileImage: (row['resim_url'] as String?),
              ),
            );
          }
          logger.d('Tüm çalışanlardan ${employees.length} yüklendi');
        }
      } else {
        logger.w('İşletme ID yok, eski çalışan yükleme metodu kullanılıyor...');
        // isletme_id yoksa eski metodu kullan
        employees.addAll(await DbService.getEmployees());
        logger.d('Eski metot ile ${employees.length} çalışan yüklendi');
      }
    } catch (e) {
      logger.e('Çalışan yükleme hatası: $e');
      // Hata durumunda eski metodu dene
      try {
        employees.addAll(await DbService.getEmployees());
        logger.d(
          'Hata sonrası fallback ile ${employees.length} çalışan yüklendi',
        );
      } catch (fallbackError) {
        logger.e('Fallback çalışan yükleme hatası: $fallbackError');
      }
    }

    if (mounted) {
      setState(() {
        _employees = employees;
        _services = services;
        _isLoading = false;
      });

      logger.d(
        'State güncellendi: ${services.length} hizmet, ${employees.length} çalışan',
      );

      // Hizmetler yüklendiyse ve hizmet seçilmemişse ilk hizmeti seç
      if (_services.isNotEmpty && _selectedService == null) {
        _selectedService = _services.first.serviceName;
        logger.d('İlk hizmet seçildi: $_selectedService');
        // Hizmete göre çalışanları yükle ve ilk çalışanı seç
        await _reloadEmployeesByHizmet(_selectedService);
      }
    }
  }

  Future<void> _submitAppointment() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedService == null ||
        _selectedEmployee == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.t('please_fill_required')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _ensureIsletmeId();

      if (_isletmeId == null || _isletmeId!.isEmpty) {
        throw Exception(lang.t('business_id_not_found'));
      }

      // Mevcut kullanıcı bilgilerini al
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null || user.email == null) {
        throw Exception(lang.t('user_not_logged_in'));
      }

      // Müşteri bilgilerini Supabase'den al
      final customerData = await client
          .from('musteriler')
          .select('*')
          .eq('email', user.email!)
          .maybeSingle();

      if (customerData == null) {
        throw Exception(lang.t('customer_not_found'));
      }

      // Müşteri ID
      final int customerId = (customerData['customerid'] as num?)?.toInt() ?? 0;

      // Appointment nesnesi oluştur
      final customerFullName =
          '${customerData['firstname'] ?? ''} ${customerData['lastname'] ?? ''}'
              .trim();
      final appointment = Appointment(
        appointmentId: null,
        customerName: customerFullName,
        customerEmail: customerData['email'] ?? '',
        customerPhone: customerData['phone'] ?? '',
        employeeName: _selectedEmployee!,
        serviceName: _selectedService!,
        appointmentDateTime: DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        ),
        totalPrice: 0.0, // Fiyat Supabase'den alınacak
        process: 'bekliyor', // bekliyor, onaylandı, iptal, tamamlandı
        approvalStatus: 'bekliyor', // bekliyor, onaylandı, iptal, tamamlandı
        notes: _notes,
      );

      // Müşteri çakışması kontrolü (customerId ile)
      bool hasCustomerConflict = await DbService.hasCustomerConflictById(
        appointment.appointmentDateTime,
        customerId,
        appointment.serviceName,
      );

      if (hasCustomerConflict) {
        throw Exception(
          'Seçilen tarih ve saatte başka bir randevunuz bulunmaktadır. Lütfen farklı bir zaman seçiniz.',
        );
      }

      // Çalışan ve hizmet çakışması kontrolü - sure_dk alanını kullanarak
      if (!kIsWeb) {
        try {
          final employeeId = _employees
              .firstWhere((emp) => emp.fullName == _selectedEmployee)
              .id;
          final serviceId = _services
              .firstWhere((service) => service.serviceName == _selectedService)
              .serviceId;

          if (employeeId != null && serviceId != null) {
            // Gelişmiş randevu çakışma kontrolü
            final hasConflict = await DbService.hasAppointmentConflict(
              appointment.appointmentDateTime,
              employeeId,
              serviceId,
            );

            if (hasConflict) {
              // Çakışma detaylarını al
              final conflictDetails =
                  await DbService.getAppointmentConflictDetails(
                    appointment.appointmentDateTime,
                    employeeId,
                    serviceId,
                  );

              if (conflictDetails['hasConflict'] == true) {
                final conflicts = conflictDetails['conflicts'] as List;
                final message = conflictDetails['message'] as String;

                logger.w('Randevu çakışması tespit edildi: $message');
                logger.w('Çakışan randevular: $conflicts');

                // Kullanıcıya detaylı çakışma bilgisi göster
                if (mounted) {
                  _showConflictDialog(conflicts, message);
                }
                return; // Randevu oluşturmayı durdur
              }
            }
          }
        } catch (e) {
          if (e.toString().contains('çakışma')) {
            rethrow; // Çakışma hatasını yukarı fırlat
          }
          logger.w('Çakışma kontrolü yapılamadı: $e');
        }
      }

      // Supabase'de randevu oluştur
      bool success = false;
      if (_isletmeId != null && _isletmeId!.isNotEmpty) {
        success = await DbService.createSupabaseAppointment(
          appointment,
          _isletmeId!,
        );
      } else {
        // Fallback olarak eski metodu dene
        success = await DbService.createAppointment(appointment);
      }

      if (success) {
        // Başarılı mesajı göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lang.t('appointment_created_success')),
              backgroundColor: Colors.green,
            ),
          );

          // Formu temizle
          if (_formKey.currentState != null) {
            _formKey.currentState!.reset();
          }
          setState(() {
            _selectedService = null;
            _selectedEmployee = null;
            _selectedDate = DateTime.now();
            _selectedTime = const TimeOfDay(hour: 10, minute: 0);
            _notes = '';
          });

          // Hizmetleri yeniden yükle
          await _loadServices();
        }
      } else {
        throw Exception('Randevu oluşturulamadı');
      }
    } catch (e) {
      logger.e('Randevu oluşturma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.t('error_occurred')} $e'),
            backgroundColor: Colors.red,
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

  // İşletme bilgilerini Supabase'den yükle
  Future<void> _loadIsletme() async {
    if (!mounted) return;

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

  void _onServiceChanged(String? service) {
    setState(() {
      _selectedService = service;
      _selectedEmployee = null;
      _selectedTime = null;
      _availableTimeSlots = [];
    });
    if (service != null) {
      _reloadEmployeesByHizmet(service);
    }
  }

  // removed unused _onEmployeeChanged

  void _onDateChanged(DateTime? date) {
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
      _availableTimeSlots = [];
    });
    if (date != null && _selectedEmployee != null && _selectedService != null) {
      _loadAvailableTimeSlots();
    }
  }

  // Müsait saatleri yükle - sure_dk alanını kullanarak
  Future<void> _loadAvailableTimeSlots() async {
    if (_selectedDate == null ||
        _selectedEmployee == null ||
        _selectedService == null) {
      return;
    }

    setState(() {
      _isLoadingTimeSlots = true;
    });

    try {
      // Web platformunda basit saat listesi kullan
      if (kIsWeb) {
        final timeSlots = _buildStaticTimeList();
        setState(() {
          _availableTimeSlots = timeSlots;
          _isLoadingTimeSlots = false;
        });
        return;
      }

      // Mobil platformda veritabanından müsait saatleri al
      final employeeId = _employees
          .firstWhere((emp) => emp.fullName == _selectedEmployee)
          .id;
      final serviceId = _services
          .firstWhere((service) => service.serviceName == _selectedService)
          .serviceId;

      if (employeeId == null || serviceId == null) {
        logger.w('Employee ID veya Service ID bulunamadı');
        final timeSlots = _buildStaticTimeList();
        setState(() {
          _availableTimeSlots = timeSlots;
          _isLoadingTimeSlots = false;
        });
        return;
      }

      final timeSlots = await DbService.getAvailableTimeSlotsForDate(
        _selectedDate!,
        employeeId,
        serviceId,
        startHour: 9,
        endHour: 19,
      );

      // DateTime'ları TimeOfDay'e çevir
      final availableTimes = timeSlots
          .map((dt) => TimeOfDay(hour: dt.hour, minute: dt.minute))
          .toList();

      setState(() {
        _availableTimeSlots = availableTimes;
        _isLoadingTimeSlots = false;
      });

      logger.i('Müsait saatler yüklendi: ${availableTimes.length} adet');
    } catch (e) {
      setState(() {
        _availableTimeSlots = [];
        _isLoadingTimeSlots = false;
      });
      logger.e('Müsait saatler yüklenirken hata: $e');

      // Hata durumunda basit saat listesi kullan
      if (!kIsWeb) {
        final timeSlots = _buildStaticTimeList();
        setState(() {
          _availableTimeSlots = timeSlots;
          _isLoadingTimeSlots = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    // Responsive tasarım için ekran boyutlarını al
    final screenWidth = MediaQuery.of(context).size.width;
    final isTinyMobile = screenWidth <= AppDimensions.tinyMobileBreakpoint;
    final isSmallMobile = screenWidth <= AppDimensions.smallMobileBreakpoint;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _isDarkMode
          ? const Color(0xFF101010)
          : const Color(0xFFEFEADF),
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
            Icons.arrow_back,
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: lang.t('back'),
        ),
        title: Row(
          children: [
            (_isletme != null &&
                    (_isletme!['logo_url'] as String?)?.isNotEmpty == true)
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
      drawer: _buildSidebarDrawer(),

      // bottomNavigationBar: kIsWeb ? null : _buildBottomNavigationBar(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: SiriusColors.accent))
          : SingleChildScrollView(
              padding: AppDimensions.getResponsivePadding(context),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Form Card
                    Card(
                      color: _isDarkMode
                          ? const Color(0xFF404344)
                          : const Color(0xFFEFEADF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.getResponsiveRadius(context),
                        ),
                        side: BorderSide(
                          color: SiriusColors.heading.withValues(alpha: 0.06),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: AppDimensions.getResponsivePadding(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.t('create_appointment'),
                              style: TextStyle(
                                color: _isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: AppDimensions.getResponsiveFontSize(
                                  context,
                                  tiny: 19,
                                  small: 21,
                                  medium: 23,
                                  large: 25,
                                  xlarge: 27,
                                ),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cormorant',
                              ),
                            ),
                            SizedBox(
                              height:
                                  AppDimensions.getResponsiveSpacing(context) *
                                  2,
                            ),

                            // Mobile-first responsive layout
                            Column(
                              children: [
                                _buildFormFields(
                                  context,
                                  isTinyMobile,
                                  isSmallMobile,
                                ),
                                SizedBox(
                                  height: AppDimensions.getResponsiveSpacing(
                                    context,
                                  ),
                                ),
                                _buildDateTimeSection(
                                  context,
                                  isTinyMobile,
                                  isSmallMobile,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFormFields(
    BuildContext context,
    bool isTinyMobile,
    bool isSmallMobile,
  ) {
    final lang = Provider.of<LanguageProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hizmet Seçimi
        Text(
          lang.t('select_service_label'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
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
        // Always-visible quick info
        // Padding(
        //   padding: const EdgeInsets.only(top: 6, bottom: 6),
        //   child: Text(
        //     'İşletme ID: ${_isletmeId ?? '-'}  |  Hizmet Sayısı: ${_services.length}  |  Çalışan Sayısı: ${_employees.length}',
        //     style: TextStyle(
        //       color: _isDarkMode ? SiriusColors.defaultText : Colors.black87,
        //       fontSize: AppDimensions.getResponsiveFontSize(
        //         context,
        //         tiny: 11,
        //         small: 12,
        //         medium: 12,
        //         large: 13,
        //         xlarge: 13,
        //       ),
        //     ),
        //   ),
        // ),
        SizedBox(height: AppDimensions.getResponsiveSpacing(context) / 2),
        if (_services.isEmpty) ...[
          // Empty-state helper when list is empty (dropdown can't open)
          Container(
            padding: EdgeInsets.all(
              AppDimensions.getResponsiveSpacing(context),
            ),
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? SiriusColors.surface
                  : const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(
                AppDimensions.getResponsiveRadius(context),
              ),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.red.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hizmet listesi boş görünüyor. Liste boşken seçim menüsü açılamaz.',
                  style: TextStyle(
                    color: _isDarkMode
                        ? SiriusColors.defaultText
                        : Colors.black87,
                    fontSize: AppDimensions.getResponsiveFontSize(
                      context,
                      tiny: 12,
                      small: 12,
                      medium: 13,
                      large: 13,
                      xlarge: 14,
                    ),
                  ),
                ),
                SizedBox(
                  height: AppDimensions.getResponsiveSpacing(context) / 2,
                ),
                SizedBox(
                  height:
                      AppDimensions.getResponsiveButtonHeight(context) * 0.9,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loadData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SiriusColors.accent,
                      foregroundColor: SiriusColors.contrast,
                    ),
                    child: Text(
                      _isLoading
                          ? lang.t('loading')
                          : lang.t('refresh_services'),
                      style: TextStyle(
                        color: _isDarkMode
                            ? SiriusColors.contrast
                            : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            initialValue: _selectedService,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDimensions.getResponsiveRadius(context),
                ),
              ),
              filled: true,
              fillColor: _isDarkMode ? Colors.black : Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDimensions.getResponsiveRadius(context),
                ),
                borderSide: BorderSide(
                  color: SiriusColors.accent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDimensions.getResponsiveRadius(context),
                ),
                borderSide: BorderSide(
                  color: SiriusColors.accent.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppDimensions.getResponsiveSpacing(context),
                vertical: AppDimensions.getResponsiveSpacing(context),
              ),
              hintText: lang.t('select_service_hint'),
              hintStyle: TextStyle(
                color: _isDarkMode ? Colors.white70 : Colors.black54,
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
            items: _services.map((service) {
              return DropdownMenuItem(
                value: service.serviceName,
                child: Text(
                  service.serviceName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontSize: AppDimensions.getResponsiveFontSize(
                      context,
                      tiny: 12,
                      small: 13,
                      medium: 14,
                      large: 15,
                      xlarge: 16,
                    ),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontSize: AppDimensions.getResponsiveFontSize(
                context,
                tiny: 12,
                small: 13,
                medium: 14,
                large: 15,
                xlarge: 16,
              ),
            ),
            onChanged: _onServiceChanged,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return lang.t('select_service_validate');
              }
              return null;
            },
          ),
        ],
        SizedBox(height: AppDimensions.getResponsiveSpacing(context)),

        // Çalışan Seçimi
        Text(
          lang.t('select_employee_label'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black,
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
        if (_selectedService != null && _employees.isNotEmpty) ...[
          // Seçilen hizmete göre çalışanları göster
          ...(_employees.map((employee) {
            final name = '${employee.firstName} ${employee.lastName}'.trim();
            final expertise = employee.expertise.isNotEmpty
                ? employee.expertise
                : lang.t('general');
            final isSelected = _selectedEmployee == name;
            return Card(
              margin: EdgeInsets.only(bottom: 8),
              color: isSelected
                  ? SiriusColors.accent.withValues(alpha: 0.12)
                  : (_isDarkMode
                        ? SiriusColors.surface.withValues(alpha: 0.9)
                        : const Color(0xFFE0E0E0).withValues(alpha: 0.9)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppDimensions.getResponsiveRadius(context),
                ),
                side: BorderSide(
                  color: isSelected
                      ? SiriusColors.accent.withValues(alpha: 0.6)
                      : SiriusColors.heading.withValues(alpha: 0.06),
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: employee.profileImage != null
                      ? NetworkImage(employee.profileImage!)
                      : null,
                  child: employee.profileImage == null ? Text(name[0]) : null,
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _isDarkMode ? SiriusColors.heading : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'Uzmanlık: $expertise',
                  style: TextStyle(
                    color: _isDarkMode
                        ? SiriusColors.defaultText
                        : Colors.black87,
                  ),
                ),
                trailing: Checkbox(
                  value: _selectedEmployee == name,
                  onChanged: (value) {
                    setState(() {
                      _selectedEmployee = value == true ? name : null;
                    });
                  },
                ),
                onTap: () {
                  setState(() {
                    _selectedEmployee = name;
                  });
                },
              ),
            );
          }).toList()),
          // Çalışan seçimi validator mesajı
          if (_selectedEmployee == null)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                lang.t('select_employee_validate'),
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ] else if (_selectedService == null) ...[
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              lang.t('select_service_first'),
              style: TextStyle(
                color: _isDarkMode ? Colors.grey[600] : Colors.black87,
              ),
            ),
          ),
        ] else ...[
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              lang.t('no_employee_for_service'),
              style: TextStyle(
                color: _isDarkMode ? Colors.orange[800] : Colors.black87,
              ),
            ),
          ),
        ],
        SizedBox(height: AppDimensions.getResponsiveSpacing(context)),

        // Notlar
        Text(
          lang.t('notes_optional'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black,
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
        Container(
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(
              AppDimensions.getResponsiveRadius(context),
            ),
            border: Border.all(
              color: SiriusColors.accent.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            decoration: InputDecoration(
              labelText: lang.t('enter_notes'),
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.all(
                AppDimensions.getResponsiveSpacing(context),
              ),
              labelStyle: TextStyle(
                color: _isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
            maxLines: 3,
            onChanged: (value) => _notes = value,
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSection(
    BuildContext context,
    bool isTinyMobile,
    bool isSmallMobile,
  ) {
    final lang = Provider.of<LanguageProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.t('date_time'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black,
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

        // Tarih ve Saat Seçimi - Birleştirilmiş tasarım
        AppAnimations.fadeIn(
          duration: const Duration(milliseconds: 400),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SiriusColors.accent.withValues(alpha: 0.3),
                width: 1,
              ),
              color: _isDarkMode ? Colors.black : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: _isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: SiriusColors.accent,
                      size: AppDimensions.getResponsiveIconSize(context),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      lang.t('date_time'),
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black87,
                        fontSize: AppDimensions.getResponsiveFontSize(
                          context,
                          tiny: 16,
                          small: 17,
                          medium: 18,
                          large: 19,
                          xlarge: 20,
                        ),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cormorant',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Tarih ve Saat Bilgileri
                Row(
                  children: [
                    // Tarih
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.t('date'),
                            style: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _isDarkMode
                                  ? Colors.grey[900]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _resolveThemeColor(
                                  _isletme?['tema_rengi'],
                                ).withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: _resolveThemeColor(
                                    _isletme?['tema_rengi'],
                                  ),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Saat
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.t('time'),
                            style: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _isDarkMode
                                  ? Colors.grey[900]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _resolveThemeColor(
                                  _isletme?['tema_rengi'],
                                ).withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: _resolveThemeColor(
                                    _isletme?['tema_rengi'],
                                  ),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedTime != null
                                      ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                                      : '--:--',
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Seçim Butonları
                Row(
                  children: [
                    // Tarih Seç Butonu
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _selectDate(context);
                        },
                        icon: Icon(Icons.calendar_today, size: 18),
                        label: Text(lang.t('pick_date')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SiriusColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Saat Seç Butonu
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _selectTime(context);
                        },
                        icon: Icon(Icons.access_time, size: 18),
                        label: Text(lang.t('pick_time')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SiriusColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: AppDimensions.getResponsiveSpacing(context) * 2),

        // Tarih-saat seçimi ile buton arasında boşluk
        SizedBox(height: AppDimensions.getResponsiveSpacing(context) * 2),

        // Ortalanmış Randevu Oluştur butonu
        Center(
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: AppDimensions.getResponsiveSpacing(context),
            ),
            child: AppAnimations.slideInFromBottom(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: double.infinity,
                height: AppDimensions.getResponsiveButtonHeight(context),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2), // Şeffaf mavi
                  borderRadius: BorderRadius.circular(25), // Daha yuvarlak
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.8),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            _submitAppointment();
                          },
                    borderRadius: BorderRadius.circular(
                      AppDimensions.getResponsiveRadius(context),
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            AppDimensions.getResponsiveSpacing(context) * 1.5,
                        vertical: AppDimensions.getResponsiveSpacing(context),
                      ),
                      child: Center(
                        child: _isLoading
                            ? SizedBox(
                                height: AppDimensions.getResponsiveIconSize(
                                  context,
                                ),
                                width: AppDimensions.getResponsiveIconSize(
                                  context,
                                ),
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : Text(
                                lang.t('create_appointment'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: AppDimensions.getResponsiveFontSize(
                                    context,
                                    tiny: 16,
                                    small: 17,
                                    medium: 18,
                                    large: 19,
                                    xlarge: 20,
                                  ),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
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

        // Alt boşluk: butonun bottom bar altında kalmaması için
        SizedBox(height: AppDimensions.getResponsiveSpacing(context) * 4),
      ],
    );
  }

  Widget _buildSidebarDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      width: 250,
      child: Container(
        decoration: BoxDecoration(
          color: _isDarkMode
              ? Colors.black.withValues(alpha: 0.85)
              : const Color(0xFFE5E2DB).withValues(alpha: 0.85),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: _isDarkMode
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color(0xFFE5E2DB).withValues(alpha: 0.3),
                border: Border(
                  right: BorderSide(
                    color: _isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
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
                                  color: SiriusColors.accent.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child:
                                  (_isletme != null &&
                                      (_isletme!['logo_url'] as String?)
                                              ?.isNotEmpty ==
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
                            _isletme != null &&
                                    (_isletme!['isim'] as String?) != null
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
                                  : Colors.black87,
                              fontSize: 16,
                              fontFamily: 'Playfair Display',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      color: _isDarkMode
                          ? SiriusColors.defaultText
                          : Colors.black87.withValues(alpha: 0.3),
                      height: 1,
                    ),
                    _buildSidebarItem(
                      icon: Icons.home,
                      title: 'Ana Sayfa',
                      isSelected: false,
                      onTap: () => Navigator.pushReplacementNamed(context, '/'),
                    ),
                    _buildSidebarItem(
                      icon: Icons.person,
                      title: 'Profil',
                      isSelected: false,
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/profile'),
                    ),

                    const Spacer(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? SiriusColors.accent.withValues(alpha: 0.15)
                  : Colors.transparent,
              border: isSelected
                  ? Border.all(
                      color: SiriusColors.accent.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? SiriusColors.accent
                      : (_isDarkMode
                            ? SiriusColors.defaultText
                            : Colors.black87),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? SiriusColors.accent
                        : (_isDarkMode
                              ? SiriusColors.defaultText
                              : Colors.black87),
                    fontSize: 16,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Randevu çakışma dialog'u
  void _showConflictDialog(List conflicts, String message) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Text(
                lang.t('appointment_conflict_title'),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cormorant',
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.t('employee_not_available'),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              if (conflicts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  lang.t('conflicting_appointments'),
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    itemCount: conflicts.length,
                    itemBuilder: (context, index) {
                      final conflict = conflicts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? Colors.grey[800]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${conflict['customerName'] ?? 'Müşteri'} - ${conflict['serviceName'] ?? 'Hizmet'} - ${conflict['time'] ?? 'Saat'}',
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                lang.t('ok'),
                style: TextStyle(
                  color: SiriusColors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // removed unused _buildBottomNavigationBar

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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.red),
                title: Text(lang.t('turkish')),
                subtitle: const Text('Turkish'),
                onTap: () {
                  lang.setLanguage(AppLanguage.tr);
                  Navigator.of(context).pop();
                },
                tileColor: lang.isTurkish
                    ? SiriusColors.accent.withValues(alpha: 0.1)
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.blue),
                title: Text(lang.t('english')),
                subtitle: const Text('İngilizce'),
                onTap: () {
                  lang.setLanguage(AppLanguage.en);
                  Navigator.of(context).pop();
                },
                tileColor: lang.isEnglish
                    ? SiriusColors.accent.withValues(alpha: 0.1)
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: SiriusColors.accent),
              child: Text(lang.t('cancel')),
            ),
          ],
        );
      },
    );
  }
}
