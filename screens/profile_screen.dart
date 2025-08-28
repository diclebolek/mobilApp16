import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter/rendering.dart';
import 'dart:ui';

import 'package:supabase_flutter/supabase_flutter.dart';
// duplicate import removed
import '../constants/app_styles.dart';
import '../main.dart';
import '../providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../models/appointment.dart';
// import '../models/service.dart';
// import '../models/employee.dart';
import '../services/db_service.dart';
import 'package:image_picker/image_picker.dart';

// Lightweight local holder for story button config
class _StoryBtn {
  final String title;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  _StoryBtn(this.title, this.color, this.icon, this.onTap);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Dark mode ve dil seçenekleri
  bool _isDarkMode = false;

  // Dinamik işletme bilgileri
  Map<String, dynamic>? _isletme;
  Map<String, dynamic>? _supaCustomer;

  // Randevu listesi için
  List<Appointment> _userAppointments = [];
  bool _isLoadingAppointments = true;
  // Randevu filtre/sıralama durumları
  String _appointmentsFilter = 'ALL'; // ALL, PAST, PENDING, APPROVED, CANCELED
  bool _sortDesc = true; // true: Yeniden eskiye

  // Servis ve çalışan listeleri için (gerektiğinde kullanılır)
  // List<Service> _services = [];
  // List<Employee> _employees = [];

  // Drawer kontrolü için Scaffold key
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Müşteri bilgileri için controller'lar
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isEditingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadUserAppointments();
    _loadServicesAndEmployees();
    _loadIsletme();
    _loadSupabaseCustomer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (_isDarkMode != themeProvider.isDarkMode) {
      setState(() {
        _isDarkMode = themeProvider.isDarkMode;
      });
    }
  }

  @override
  void dispose() {
    // Controller'ları dispose et
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Güvenli setState çağrısı için helper method
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(fn);
        }
      });
    }
  }

  // Navigation helpers to avoid triggering navigation during pointer/mouse updates

  // İşletme bilgilerini Supabase'den yükle
  Future<void> _loadIsletme() async {
    if (!mounted) return;

    try {
      final resolvedIsletmeId = await DbService.resolveIsletmeId(tip: 'gym');
      if (resolvedIsletmeId != null) {
        final isletme = await DbService.getIsletmeById(resolvedIsletmeId);
        if (mounted) {
          _safeSetState(() {
            _isletme = isletme;
          });
        }
      }
    } catch (_) {
      // Sessizce fallback'e bırak
    }
  }

  // Müşteri bilgilerini Supabase'den yükle
  Future<void> _loadSupabaseCustomer() async {
    if (!mounted) return;

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user != null && user.email != null) {
        // Müşteri bilgilerini musteriler tablosundan getir
        final customerData = await client
            .from('musteriler')
            .select('*')
            .eq('email', user.email!)
            .maybeSingle();

        if (customerData != null) {
          _safeSetState(() {
            _supaCustomer = customerData;
            // Controller'ları doldur
            _firstNameController.text = (customerData['firstname'] ?? '')
                .toString();
            _lastNameController.text = (customerData['lastname'] ?? '')
                .toString();
            _emailController.text = (customerData['email'] ?? '').toString();
            _phoneController.text = (customerData['phone'] ?? '').toString();
          });
        }
      }
    } catch (e) {
      // Müşteri bilgileri yüklenirken hata oluştu
    }
  }

  // Profil fotoğrafını değiştir
  Future<void> _changeProfilePhoto() async {
    if (!mounted) return;

    try {
      // Galeri'den fotoğraf seç
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        // Yükleme göstergesi
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf yükleniyor...'),
            backgroundColor: Colors.blue,
          ),
        );

        // Supabase Storage'a yükle
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;

        if (user != null && user.email != null) {
          final fileName =
              'profile_${user.email}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = 'profile_images/$fileName';

          // Dosyayı oku
          final bytes = await image.readAsBytes();

          // Storage'a yükle
          await client.storage.from('profiles').uploadBinary(filePath, bytes);

          // Public URL al
          final imageUrl = client.storage
              .from('profiles')
              .getPublicUrl(filePath);

          // Veritabanında profil fotoğrafı URL'ini güncelle
          await client
              .from('musteriler')
              .update({
                'profil_fotografi': imageUrl,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('email', user.email!);

          // Local state'i güncelle
          _safeSetState(() {
            if (_supaCustomer != null) {
              _supaCustomer!['profil_fotografi'] = imageUrl;
            }
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil fotoğrafı başarıyla güncellendi!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf yüklenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ignore: unused_element
  Future<void> _updateCustomerProfile() async {
    if (!mounted) return;

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user != null && _supaCustomer != null && user.email != null) {
        await client
            .from('musteriler')
            .update({
              'firstname': _firstNameController.text.trim(),
              'lastname': _lastNameController.text.trim(),
              'email': _emailController.text.trim(),
              'phone': _phoneController.text.trim(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('email', user.email!);

        _safeSetState(() {
          _isEditingProfile = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil bilgileri başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil güncellenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadServicesAndEmployees() async {
    if (!mounted) return;

    // Servisler ve çalışanlar şu anda kullanılmıyor
    // try {
    //   final services = await DbService.getServices();
    //   final employees = await DbService.getEmployees();
    //   // _services = services;
    //   // _employees = employees;
    // } catch (e) {
    //   // Hata durumunda örnek veriler kullan
    // }
  }

  Future<void> _loadUserAppointments() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final customer = authProvider.currentCustomer;

    if (customer == null) {
      if (mounted) {
        _safeSetState(() {
          _userAppointments = [];
          _isLoadingAppointments = false;
        });
      }
      return;
    }

    if (mounted) {
      _safeSetState(() {
        _isLoadingAppointments = true;
      });
    }

    try {
      List<Appointment> userAppointments = [];

      // Önce Supabase'den randevuları getirmeye çalış
      try {
        final client = Supabase.instance.client;
        final isletmeId = await DbService.resolveIsletmeId();

        int? effectiveCustomerId;
        // Supabase müşteri ID'si öncelikli
        final dynamic supaIdRaw = _supaCustomer?['customerid'];
        if (supaIdRaw != null) {
          effectiveCustomerId = int.tryParse(supaIdRaw.toString());
        }
        // AuthProvider'dan gelirse ikinci öncelik
        effectiveCustomerId ??= customer.customerId;
        // Hâlâ yoksa email ile musteriler tablosundan bul
        if (effectiveCustomerId == null &&
            client.auth.currentUser?.email != null) {
          try {
            final musteri = await client
                .from('musteriler')
                .select('customerid')
                .eq('email', client.auth.currentUser!.email!)
                .maybeSingle();
            if (musteri != null && musteri['customerid'] != null) {
              effectiveCustomerId = int.tryParse(
                musteri['customerid'].toString(),
              );
            }
          } catch (_) {}
        }

        if (effectiveCustomerId != null) {
          Future<List<dynamic>> fetchWith({bool withIsletme = true}) async {
            final int customerId = effectiveCustomerId!;
            var query = client
                .from('randevu')
                .select(
                  'randevu_id, customerid, calisan_id, hizmet_id, appointment_datetime, process, total_price, approval_status, notes',
                )
                .eq('customerid', customerId);
            if (withIsletme && isletmeId != null) {
              query = query.eq('isletme_id', isletmeId);
            }
            return await query.order('appointment_datetime', ascending: false);
          }

          List<dynamic> rows = [];
          try {
            rows = await fetchWith(withIsletme: true);
          } catch (_) {}
          if (rows.isEmpty) {
            try {
              rows = await fetchWith(withIsletme: false);
            } catch (_) {}
          }

          if (rows.isNotEmpty) {
            final list = rows.cast<Map<String, dynamic>>();

            // İsim çözümleme için ID setleri
            final Set<String> hizmetIds = {
              for (final m in list)
                if (m['hizmet_id'] != null) m['hizmet_id'].toString(),
            };
            final Set<String> calisanIds = {
              for (final m in list)
                if (m['calisan_id'] != null) m['calisan_id'].toString(),
            };

            // Hizmet adlarını getir
            final Map<String, String> hizmetMap = {};
            if (hizmetIds.isNotEmpty) {
              try {
                final hRows = await client
                    .from('menu_hizmet_icerigi')
                    .select('menu_hizmet_icerigi_id, hizmet')
                    .inFilter('menu_hizmet_icerigi_id', hizmetIds.toList());
                for (final r in (hRows as List)) {
                  final rm = r as Map<String, dynamic>;
                  final key = rm['menu_hizmet_icerigi_id']?.toString();
                  final val = rm['hizmet']?.toString();
                  if (key != null && val != null) hizmetMap[key] = val;
                }
              } catch (_) {}
            }

            // Çalışan adlarını getir
            final Map<String, String> calisanMap = {};
            if (calisanIds.isNotEmpty) {
              try {
                final cRows = await client
                    .from('calisanlar')
                    .select('id, ad, soyad')
                    .inFilter('id', calisanIds.toList());
                for (final r in (cRows as List)) {
                  final rm = r as Map<String, dynamic>;
                  final key = rm['id']?.toString();
                  final ad = (rm['ad'] as String?) ?? '';
                  final soyad = (rm['soyad'] as String?) ?? '';
                  if (key != null) calisanMap[key] = '$ad $soyad'.trim();
                }
              } catch (_) {}
            }

            userAppointments = list.map((m) {
              final hizmetId = m['hizmet_id']?.toString();
              final calisanIdStr = m['calisan_id']?.toString();
              return Appointment(
                appointmentId:
                    int.tryParse((m['randevu_id'] ?? '').toString()) ?? 0,
                customerName: '${customer.firstName} ${customer.lastName}',
                employeeName: calisanIdStr != null
                    ? (calisanMap[calisanIdStr] ?? '')
                    : '',
                serviceName: hizmetId != null
                    ? (hizmetMap[hizmetId] ?? '')
                    : '',
                process: _mapProcess(m['process'] as int?),
                totalPrice: (m['total_price'] as num?)?.toDouble() ?? 0.0,
                appointmentDateTime: DateTime.parse(
                  m['appointment_datetime'] as String,
                ),
                approvalStatus: (m['approval_status'] as String?) ?? 'Pending',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                notes: (m['notes'] as String?) ?? '',
                customerPhone: '',
                customerEmail: customer.email,
              );
            }).toList();
          }
        }
      } catch (e) {
        // Supabase randevu yükleme hatası
        userAppointments = [];
      }

      // Supabase'den veri gelmezse legacy veritabanından dene
      if (userAppointments.isEmpty) {
        if (customer.customerId != null) {
          userAppointments = await DbService.getAppointmentsByCustomerId(
            customer.customerId!,
          );
        }
        if (userAppointments.isEmpty) {
          userAppointments = await DbService.getAppointmentsByCustomerEmail(
            customer.email,
          );
        }
      }

      if (mounted) {
        _safeSetState(() {
          _userAppointments = userAppointments;
          _isLoadingAppointments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _safeSetState(() {
          _isLoadingAppointments = false;
          _userAppointments = [];
        });
      }
    }
  }

  String _mapProcess(int? value) {
    switch (value) {
      case 0:
        return 'Bekliyor';
      case 1:
        return 'Devam Ediyor';
      case 2:
        return 'Tamamlandı';
      default:
        return 'Bilinmeyen';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final isDesktop = MediaQuery.of(context).size.width > 600;

    assert(() {
      _buildQuickAccessCard('', '', Icons.info, () {});
      return true;
    }());

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _isDarkMode ? Colors.black : const Color(0xFFE5E2DB),
      extendBodyBehindAppBar: false,
      drawerEnableOpenDragGesture: false,
      appBar: AppBar(
        backgroundColor: _isDarkMode
            ? Colors.black.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.9),
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
                      color: _isDarkMode
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.15),
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
              _showLanguageSelectionDialog(context);
            },
            tooltip: Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('change_language'),
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
                  color: _isDarkMode
                      ? SiriusColors.accent.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
      drawer: _buildSidebarDrawer(),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ana profil kartı
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0D2CA),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 15,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child:
                                        _supaCustomer != null &&
                                            (_supaCustomer!['profil_fotografi']
                                                        as String?)
                                                    ?.isNotEmpty ==
                                                true
                                        ? ClipOval(
                                            child: Image.network(
                                              _supaCustomer!['profil_fotografi'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(
                                                    Icons.person,
                                                    size: 50,
                                                    color: SiriusColors.accent,
                                                  ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.person,
                                            size: 50,
                                            color: SiriusColors.accent,
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: SiriusColors.accent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: IconButton(
                                        onPressed: _changeProfilePhoto,
                                        icon: Icon(
                                          Icons.camera_alt,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('welcome_to'),
                                style: const TextStyle(
                                  color: SiriusColors.contrast,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cormorant',
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                (_supaCustomer != null &&
                                        ((_supaCustomer!['firstname']
                                                        as String?)
                                                    ?.isNotEmpty ==
                                                true ||
                                            (_supaCustomer!['lastname']
                                                        as String?)
                                                    ?.isNotEmpty ==
                                                true))
                                    ? '${_supaCustomer!['firstname'] ?? ''} ${_supaCustomer!['lastname'] ?? ''}'
                                          .trim()
                                    : 'Ad Soyad',
                                style: TextStyle(
                                  color: SiriusColors.contrast.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_supaCustomer != null &&
                                  ((_supaCustomer!['email'] as String?)
                                              ?.isNotEmpty ==
                                          true ||
                                      (_supaCustomer!['phone'] as String?)
                                              ?.isNotEmpty ==
                                          true)) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '${_supaCustomer!['email'] ?? ''}  ${_supaCustomer!['phone'] ?? ''}'
                                      .trim(),
                                  style: TextStyle(
                                    color: SiriusColors.contrast.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Story buttons
                        _buildStoryButtons(),
                        const SizedBox(height: 24),

                        // Appointments section
                        _buildAppointmentsSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: null,
    );
  }

  Widget _buildAppointmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).t('appointment_title'),
              style: TextStyle(
                color: _isDarkMode ? SiriusColors.heading : Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cormorant',
              ),
            ),
            IconButton(
              tooltip: Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).t('refresh'),
              icon: const Icon(Icons.refresh),
              color: Colors.green,
              onPressed: () async {
                setState(() {
                  _isLoadingAppointments = true;
                });
                await _loadUserAppointments();
                if (mounted) {
                  setState(() {
                    _isLoadingAppointments = false;
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Filtre ve sıralama butonları (responsive)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip(
              Provider.of<LanguageProvider>(context, listen: false).t('all'),
              'ALL',
            ),
            _buildFilterChip(
              Provider.of<LanguageProvider>(context, listen: false).t('past'),
              'PAST',
            ),
            _buildFilterChip(
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).t('pending'),
              'PENDING',
            ),
            _buildFilterChip(
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).t('confirmed'),
              'APPROVED',
            ),
            _buildFilterChip(
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).t('cancelled'),
              'CANCELED',
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _sortDesc = !_sortDesc;
                });
              },
              icon: Icon(
                _sortDesc ? Icons.south : Icons.north,
                color: SiriusColors.accent,
                size: 18,
              ),
              label: Text(
                _sortDesc
                    ? Provider.of<LanguageProvider>(
                        context,
                        listen: false,
                      ).t('newest_to_oldest')
                    : Provider.of<LanguageProvider>(
                        context,
                        listen: false,
                      ).t('oldest_to_newest'),
                style: TextStyle(color: SiriusColors.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _isLoadingAppointments
            ? const Center(child: CircularProgressIndicator())
            : _userAppointments.isEmpty
            ? Center(
                child: Text(
                  Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).t('no_appointments'),
                  style: TextStyle(
                    color: _isDarkMode
                        ? SiriusColors.defaultText
                        : Colors.black,
                    fontSize: 16,
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: (() {
                  final now = DateTime.now();
                  List<Appointment> items = _userAppointments.where((a) {
                    switch (_appointmentsFilter) {
                      case 'PAST':
                        return a.appointmentDateTime.isBefore(now);
                      case 'PENDING':
                        return a.approvalStatus.toLowerCase() == 'pending' &&
                            a.appointmentDateTime.isAfter(now);
                      case 'APPROVED':
                        return a.approvalStatus.toLowerCase() == 'approved';
                      case 'CANCELED':
                        return a.approvalStatus.toLowerCase().startsWith(
                          'cancel',
                        );
                      default:
                        return true;
                    }
                  }).toList();
                  items.sort(
                    (a, b) => _sortDesc
                        ? b.appointmentDateTime.compareTo(a.appointmentDateTime)
                        : a.appointmentDateTime.compareTo(
                            b.appointmentDateTime,
                          ),
                  );
                  return items.length;
                })(),
                itemBuilder: (context, index) {
                  final now = DateTime.now();
                  List<Appointment> items = _userAppointments.where((a) {
                    switch (_appointmentsFilter) {
                      case 'PAST':
                        return a.appointmentDateTime.isBefore(now);
                      case 'PENDING':
                        return a.approvalStatus.toLowerCase() == 'pending' &&
                            a.appointmentDateTime.isAfter(now);
                      case 'APPROVED':
                        return a.approvalStatus.toLowerCase() == 'approved';
                      case 'CANCELED':
                        return a.approvalStatus.toLowerCase().startsWith(
                          'cancel',
                        );
                      default:
                        return true;
                    }
                  }).toList();
                  items.sort(
                    (a, b) => _sortDesc
                        ? b.appointmentDateTime.compareTo(a.appointmentDateTime)
                        : a.appointmentDateTime.compareTo(
                            b.appointmentDateTime,
                          ),
                  );
                  final appointment = items[index];
                  return _buildNotebookAppointmentCard(appointment);
                },
              ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool selected = _appointmentsFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _appointmentsFilter = value;
          });
        },
        backgroundColor: _isDarkMode
            ? SiriusColors.surface
            : const Color(0xFFFFFBF0),
        selectedColor: SiriusColors.accent.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: selected
              ? SiriusColors.accent
              : (_isDarkMode ? Colors.white : Colors.black),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
        side: BorderSide(
          color: SiriusColors.accent.withValues(alpha: 0.25),
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildNotebookAppointmentCard(Appointment appointment) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: _isDarkMode ? SiriusColors.surface : const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: SiriusColors.accent.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Çizgili kağıt efekti
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 36),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final lineCount = (constraints.maxHeight / 22)
                      .clamp(3, 30)
                      .floor();
                  return Column(
                    children: List.generate(
                      lineCount,
                      (index) => Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: SiriusColors.accent.withValues(
                                  alpha: 0.10,
                                ),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // İçerik
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Spiral delikleri
              Container(
                width: 36,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    6,
                    (i) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? SiriusColors.defaultText
                            : Colors.black.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment.serviceName.isNotEmpty
                                  ? appointment.serviceName
                                  : 'Hizmet',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _isDarkMode
                                    ? SiriusColors.heading
                                    : Colors.black,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.event,
                                  size: 16,
                                  color: _isDarkMode
                                      ? SiriusColors.defaultText
                                      : Colors.black,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${appointment.appointmentDateTime.day}/${appointment.appointmentDateTime.month}/${appointment.appointmentDateTime.year}',
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? SiriusColors.defaultText
                                        : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: _isDarkMode
                                      ? SiriusColors.defaultText
                                      : Colors.black,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${appointment.appointmentDateTime.hour}:${appointment.appointmentDateTime.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? SiriusColors.defaultText
                                        : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: SiriusColors.accent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Durum: ${appointment.approvalStatus}',
                                  style: TextStyle(
                                    color: SiriusColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₺${appointment.totalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: SiriusColors.accent,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () =>
                                    _showEditAppointmentDialog(appointment),
                                tooltip: 'Düzenle',
                                color: SiriusColors.accent,
                                style: IconButton.styleFrom(
                                  backgroundColor: SiriusColors.accent
                                      .withValues(alpha: 0.1),
                                  padding: const EdgeInsets.all(8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, size: 18),
                                onPressed: () =>
                                    _cancelAppointment(appointment),
                                tooltip: 'İptal Et',
                                color: Colors.red,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red.withValues(
                                    alpha: 0.08,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDesktopSidebar() {
    return SafeArea(
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
                        : Image.asset('assets/salon/3.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isletme != null && (_isletme!['isim'] as String?) != null
                      ? _isletme!['isim'] as String
                      : 'Sirius',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Playfair Display',
                  ),
                ),
                Text(
                  'Beauty & Spa',
                  style: TextStyle(
                    color: _isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.black87.withValues(alpha: 0.7),
                    fontSize: 16,
                    fontFamily: 'Playfair Display',
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: _isDarkMode
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black87.withValues(alpha: 0.3),
            height: 1,
          ),
          _buildSidebarItem(
            icon: Icons.home,
            title: Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('home_title'),
            isSelected: false,
            onTap: () => Navigator.pushNamed(context, '/'),
          ),
          _buildSidebarItem(
            icon: Icons.person,
            title: Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('profile_title'),
            isSelected: true,
            onTap: () {},
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Icon(Icons.settings, color: const Color(0xFFDEC41F)),
              title: Text(
                'Ayarlar',
                style: TextStyle(
                  color: const Color(0xFFDEC41F),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                _showProfileSettingsDialog();
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: const Color(0xFFDEC41F).withValues(alpha: 0.1),
            ),
          ),

          const Spacer(),
          Divider(
            color: _isDarkMode
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black87.withValues(alpha: 0.3),
            height: 1,
          ),
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
              label: Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('logout'),
              ),
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
    );
  }

  Widget _buildSidebarDrawer() {
    final lang = Provider.of<LanguageProvider>(context);
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
              isSelected: false,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/');
              },
            ),
            _buildSidebarItem(
              icon: Icons.person,
              title: lang.t('profile_title'),
              isSelected: true,
              onTap: () {
                Navigator.pop(context);
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
                label: Text(
                  Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).t('logout'),
                ),
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

  // _showAppointmentsDialog() kaldırıldı (kullanılmıyordu)

  // ignore: unused_element
  void _showSimpleAppointmentsDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Randevularım'),
          content: const Text(
            'Randevu bilgileri yüklenirken bir hata oluştu. Lütfen tekrar deneyin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  // Profil ayarları dialog'u
  void _showProfileSettingsDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final fallbackAuth = Provider.of<AuthProvider>(context, listen: false);
        final fallbackCustomer = fallbackAuth.currentCustomer;
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: _isDarkMode
                  ? const Color(0xFF181818).withValues(alpha: 0.95)
                  : const Color(0xFFEDECE8).withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: _isDarkMode ? Colors.white : Colors.black87,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Profil Bilgileri',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      size: 20,
                    ),
                    tooltip: 'Kapat',
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(maxHeight: 520),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isEditingProfile) ...[
                        TextField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            labelText: 'Ad',
                            labelStyle: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.8),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: SiriusColors.accent.withValues(
                                  alpha: 0.4,
                                ),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: SiriusColors.accent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          style: TextStyle(color: Colors.black87, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            labelText: 'Soyad',
                            labelStyle: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.8),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: SiriusColors.accent.withValues(
                                  alpha: 0.4,
                                ),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: SiriusColors.accent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          style: TextStyle(color: Colors.black87, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.8),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: SiriusColors.accent.withValues(
                                  alpha: 0.4,
                                ),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: SiriusColors.accent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          style: TextStyle(color: Colors.black87, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Telefon',
                            labelStyle: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.8),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: SiriusColors.accent.withValues(
                                  alpha: 0.4,
                                ),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: SiriusColors.accent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          style: TextStyle(color: Colors.black87, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        // Butonlar sağda alt alta hizalı
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  dialogSetState(() {
                                    _isEditingProfile = false;
                                  });
                                },
                                child: Text(
                                  'Geri Dön',
                                  style: TextStyle(
                                    color: SiriusColors.defaultText,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () async {
                                  await _saveProfileChanges();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SiriusColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Güncelle'),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        if (_supaCustomer != null) ...[
                          _buildProfileInfoRow(
                            'Ad',
                            _supaCustomer!['firstname'] ?? '',
                          ),
                          _buildProfileInfoRow(
                            'Soyad',
                            _supaCustomer!['lastname'] ?? '',
                          ),
                          _buildProfileInfoRow(
                            'Email',
                            _supaCustomer!['email'] ?? '',
                          ),
                          _buildProfileInfoRow(
                            'Telefon',
                            _supaCustomer!['phone'] ?? '',
                          ),
                        ] else if (fallbackCustomer != null) ...[
                          _buildProfileInfoRow(
                            'Ad',
                            fallbackCustomer.firstName,
                          ),
                          _buildProfileInfoRow(
                            'Soyad',
                            fallbackCustomer.lastName,
                          ),
                          _buildProfileInfoRow('Email', fallbackCustomer.email),
                          _buildProfileInfoRow(
                            'Telefon',
                            fallbackCustomer.phone,
                          ),
                        ] else ...[
                          Text(
                            'Profil bilgileri yüklenemedi.',
                            style: TextStyle(color: SiriusColors.defaultText),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Butonlar sağda alt alta
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => _showChangePasswordDialog(),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: SiriusColors.accent),
                                  foregroundColor: SiriusColors.accent,
                                ),
                                child: const Text('Şifre Değiştir'),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: () {
                                  dialogSetState(() {
                                    _isEditingProfile = true;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: SiriusColors.accent),
                                  foregroundColor: SiriusColors.accent,
                                ),
                                child: const Text('Bilgilerimi Düzenle'),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () async {
                                  await _saveProfileChanges();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SiriusColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Kaydet'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: const [],
            );
          },
        );
      },
    );
  }

  // Şifre değiştirme dialog'u
  void _showChangePasswordDialog() {
    if (!mounted) return;

    final TextEditingController currentController = TextEditingController();
    final TextEditingController newController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: SiriusColors.surface,
          title: Row(
            children: [
              Icon(Icons.lock, color: SiriusColors.accent),
              const SizedBox(width: 8),
              Text(
                'Şifre Değiştir',
                style: TextStyle(color: SiriusColors.heading),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Mevcut Şifre',
                    labelStyle: TextStyle(color: SiriusColors.defaultText),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: SiriusColors.accent.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: SiriusColors.accent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(color: SiriusColors.heading),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Yeni Şifre (min 6 karakter)',
                    labelStyle: TextStyle(color: SiriusColors.defaultText),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: SiriusColors.accent.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: SiriusColors.accent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(color: SiriusColors.heading),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Yeni Şifre (Tekrar)',
                    labelStyle: TextStyle(color: SiriusColors.defaultText),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: SiriusColors.accent.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: SiriusColors.accent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(color: SiriusColors.heading),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () async {
                final newPwd = newController.text.trim();
                final confirmPwd = confirmController.text.trim();
                final currentPwd = currentController.text.trim();

                if (newPwd.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Şifre en az 6 karakter olmalı'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (newPwd != confirmPwd) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Yeni şifreler eşleşmiyor'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final client = Supabase.instance.client;
                  final user = client.auth.currentUser;
                  if (user == null || user.email == null) {
                    throw Exception('Kullanıcı oturumu bulunamadı');
                  }

                  // Mevcut şifreyi doğrula
                  try {
                    await client.auth.signInWithPassword(
                      email: user.email!,
                      password: currentPwd,
                    );
                  } catch (_) {
                    throw Exception('Mevcut şifre hatalı');
                  }

                  // Şifreyi güncelle
                  await client.auth.updateUser(
                    UserAttributes(password: newPwd),
                  );

                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Şifre başarıyla güncellendi'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Şifre güncellenemedi: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: SiriusColors.accent),
                foregroundColor: SiriusColors.accent,
              ),
              child: const Text('Güncelle'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Kapat',
                style: TextStyle(color: SiriusColors.defaultText),
              ),
            ),
          ],
        );
      },
    );
  }

  // İletişim dialog'u
  void _showContactDialog() {
    if (!mounted) return;

    final TextEditingController questionController = TextEditingController();
    final TextEditingController emailController = TextEditingController();

    final Map<String, dynamic>? biz = _isletme is Map<String, dynamic>
        ? _isletme as Map<String, dynamic>
        : null;
    final String tel = (biz?['telefon'] ?? biz?['phone'] ?? '-').toString();
    final String mail = (biz?['email'] ?? '-').toString();
    final String calisma =
        (biz?['contact_open'] ?? biz?['calisma_saatleri'] ?? '-').toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode
              ? const Color(0xFF181818).withValues(alpha: 0.95)
              : const Color(0xFFEDECE8).withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.contact_support,
                color: _isDarkMode ? Colors.white : Colors.black87,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'İletişim',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildContactInfoRow('Telefon', tel),
                _buildContactInfoRow('Email', mail),
                _buildContactInfoRow('Çalışma Saatleri', calisma),
                const SizedBox(height: 16),
                Text(
                  'Soru Sormak İstiyorum',
                  style: TextStyle(
                    color: _isDarkMode ? SiriusColors.heading : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email Adresiniz',
                    labelStyle: TextStyle(color: SiriusColors.defaultText),
                    filled: true,
                    fillColor: _isDarkMode
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: SiriusColors.accent.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: SiriusColors.accent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(
                    color: _isDarkMode ? SiriusColors.heading : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: questionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Sorunuz',
                    labelStyle: TextStyle(
                      color: _isDarkMode
                          ? SiriusColors.defaultText
                          : Colors.black87,
                    ),
                    filled: true,
                    fillColor: _isDarkMode
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: SiriusColors.accent.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: SiriusColors.accent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(color: SiriusColors.heading),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SiriusColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SiriusColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Sorularınızı bekliyoruz. En kısa sürede size dönüş yapacağız.',
                    style: TextStyle(
                      color: _isDarkMode
                          ? SiriusColors.heading
                          : Colors.black87,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Vazgeç',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                if (questionController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lütfen tüm alanları doldurun'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                // Burada soru gönderme işlemi yapılabilir
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sorunuz başarıyla gönderildi'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: SiriusColors.accent),
                foregroundColor: SiriusColors.accent,
              ),
              child: const Text('Soru Gönder'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContactInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? SiriusColors.heading : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _isDarkMode ? SiriusColors.defaultText : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? SiriusColors.heading : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Belirtilmemiş',
              style: TextStyle(
                color: _isDarkMode ? SiriusColors.defaultText : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Randevu iptal etme
  void _cancelAppointment(Appointment appointment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: SiriusColors.surface,
          title: Row(
            children: [
              Icon(Icons.cancel, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                'Randevu İptali',
                style: TextStyle(color: SiriusColors.heading),
              ),
            ],
          ),
          content: Text(
            'Bu randevuyu iptal etmek istediğinizden emin misiniz?',
            style: TextStyle(color: SiriusColors.defaultText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Vazgeç',
                style: TextStyle(color: SiriusColors.defaultText),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performCancelAppointment(appointment);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('İptal Et'),
            ),
          ],
        );
      },
    );
  }

  // Supabase ile randevu iptal etme
  Future<void> _performCancelAppointment(Appointment appointment) async {
    try {
      final client = Supabase.instance.client;

      final dynamic custIdDyn = _supaCustomer != null
          ? (_supaCustomer as Map<String, dynamic>)['customerid']
          : null;
      final int? customerId = (custIdDyn is num) ? custIdDyn.toInt() : null;
      if (customerId == null) {
        throw Exception('Müşteri ID bulunamadı');
      }

      // Müşterinin ilgili tarih/saatteki randevusunu sil
      await client
          .from('randevu')
          .delete()
          .eq('customerid', customerId)
          .eq(
            'appointment_datetime',
            appointment.appointmentDateTime.toIso8601String(),
          );

      // Local listeyi güncelle
      _safeSetState(() {
        _userAppointments.removeWhere(
          (a) => a.appointmentDateTime == appointment.appointmentDateTime,
        );
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Randevu başarıyla iptal edildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Randevu iptal edilemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ignore: unused_element
  Future<void> _logout() async {
    try {
      final client = Supabase.instance.client;
      await client.auth.signOut();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Çıkış yapılamadı: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Randevu düzenleme dialog'u
  void _showEditAppointmentDialog(Appointment appointment) {
    if (!mounted) return;

    final TextEditingController notesController = TextEditingController(
      text: appointment.notes ?? '',
    );
    DateTime selectedDateTime = appointment.appointmentDateTime;
    String selectedService = appointment.serviceName;
    String selectedEmployee = appointment.employeeName;
    List<Map<String, dynamic>> services = [];
    List<Map<String, dynamic>> employees = [];
    bool isLoadingData = true;

    // Hizmet ve çalışan verilerini yükle (tema bağımsız)
    Future<void> loadData() async {
      try {
        final client = Supabase.instance.client;

        // isletme_id belirle (varsa)
        final dynamic bizIdDyn = (_isletme is Map<String, dynamic>)
            ? (_isletme as Map<String, dynamic>)['isletme_id']
            : null;
        final String? bizId = bizIdDyn?.toString();

        var svcQuery = client
            .from('menu_hizmet_icerigi')
            .select('hizmet, menu_hizmet_icerigi_id, isletme_id');
        if (bizId != null && bizId.isNotEmpty) {
          svcQuery = svcQuery.eq('isletme_id', bizId);
        }
        final servicesResult = await svcQuery;

        var empQuery = client
            .from('calisanlar')
            .select('id, ad, soyad, isletme_id');
        if (bizId != null && bizId.isNotEmpty) {
          empQuery = empQuery.eq('isletme_id', bizId);
        }
        final employeesResult = await empQuery;

        services = List<Map<String, dynamic>>.from(servicesResult);
        employees = List<Map<String, dynamic>>.from(employeesResult);

        // Varsayılanları doğrula
        if (!services.any((s) => (s['hizmet'] ?? '') == selectedService)) {
          if (services.isNotEmpty) {
            selectedService = (services.first['hizmet'] ?? '').toString();
          }
        }
        if (!employees.any(
          (e) =>
              ('${e['ad'] ?? ''} ${e['soyad'] ?? ''}'.trim() ==
              selectedEmployee),
        )) {
          if (employees.isNotEmpty) {
            final e = employees.first;
            selectedEmployee = '${e['ad'] ?? ''} ${e['soyad'] ?? ''}'.trim();
          }
        }

        if (mounted) {
          setState(() {
            isLoadingData = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            isLoadingData = false;
          });
        }
      }
    }

    // Dialog açıldığında verileri yükle
    loadData();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _isDarkMode
                  ? Colors.white
                  : const Color(0xFFEDECE8).withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.edit, color: const Color(0xFFFAA940), size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Randevu Düzenle',
                    style: TextStyle(
                      color: const Color(0xFFFAA940), // Story button rengi
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoadingData) ...[
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 16),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedService.isEmpty
                            ? null
                            : selectedService,
                        decoration: InputDecoration(
                          labelText: 'Hizmet',
                          labelStyle: const TextStyle(color: Colors.black87),
                          filled: true,
                          fillColor: Colors.grey[100],
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: SiriusColors.accent.withValues(alpha: 0.4),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: SiriusColors.accent),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: services
                            .map(
                              (service) => DropdownMenuItem<String>(
                                value: (service['hizmet'] ?? '').toString(),
                                child: Text(
                                  (service['hizmet'] ?? '').toString(),
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedService = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: selectedEmployee.isEmpty
                            ? null
                            : selectedEmployee,
                        decoration: InputDecoration(
                          labelText: 'Çalışan',
                          labelStyle: const TextStyle(color: Colors.black87),
                          filled: true,
                          fillColor: Colors.grey[100],
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: SiriusColors.accent.withValues(alpha: 0.4),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: SiriusColors.accent),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: employees.map((employee) {
                          final fullName =
                              '${employee['ad'] ?? ''} ${employee['soyad'] ?? ''}'
                                  .trim();
                          return DropdownMenuItem<String>(
                            value: fullName,
                            child: Text(
                              fullName,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedEmployee = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.calendar_today,
                        color: SiriusColors.accent,
                      ),
                      title: const Text(
                        'Tarih ve Saat',
                        style: TextStyle(color: Colors.black54),
                      ),
                      subtitle: Text(
                        '${selectedDateTime.hour}:${selectedDateTime.minute.toString().padLeft(2, '0')} ${selectedDateTime.day}/${selectedDateTime.month}/${selectedDateTime.year}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.edit_calendar,
                          color: SiriusColors.accent,
                        ),
                        onPressed: () async {
                          // Önce saat seç, ardından tarih seç
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              selectedDateTime,
                            ),
                            builder: (context, child) {
                              final theme = Theme.of(context);
                              return Theme(
                                data: theme.copyWith(
                                  colorScheme: theme.colorScheme.copyWith(
                                    primary: SiriusColors.accent,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: SiriusColors.accent,
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (time != null) {
                            if (!context.mounted) return;
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDateTime,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              builder: (context, child) {
                                final theme = Theme.of(context);
                                return Theme(
                                  data: theme.copyWith(
                                    colorScheme: theme.colorScheme.copyWith(
                                      primary: SiriusColors.accent,
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                      onSurface: Colors.black,
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                        foregroundColor: SiriusColors.accent,
                                      ),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (date != null) {
                              setDialogState(() {
                                selectedDateTime = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notlar',
                        labelStyle: const TextStyle(color: Colors.black87),
                        filled: true,
                        fillColor: Colors.grey[100],
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: SiriusColors.accent.withValues(alpha: 0.4),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: SiriusColors.accent),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Vazgeç',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _performEditAppointment(
                      appointment,
                      selectedDateTime,
                      notesController.text.trim(),
                      selectedService,
                      selectedEmployee,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SiriusColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Güncelle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Supabase ile randevu düzenleme
  Future<void> _performEditAppointment(
    Appointment appointment,
    DateTime newDateTime,
    String newNotes,
    String newService,
    String newEmployee,
  ) async {
    try {
      final client = Supabase.instance.client;

      // customerid al
      final dynamic custIdDyn = _supaCustomer != null
          ? (_supaCustomer as Map<String, dynamic>)['customerid']
          : null;
      final int? customerId = (custIdDyn is num) ? custIdDyn.toInt() : null;
      if (customerId == null) {
        throw Exception('Müşteri ID bulunamadı');
      }

      // Hizmet ve çalışan ID'leri (opsiyonel)
      String? hizmetId;
      int? calisanId;
      try {
        final svcRow = await client
            .from('menu_hizmet_icerigi')
            .select('menu_hizmet_icerigi_id')
            .eq('hizmet', newService)
            .maybeSingle();
        hizmetId = svcRow?['menu_hizmet_icerigi_id'] as String?;

        final names = newEmployee.split(' ');
        final first = names.isNotEmpty ? names.first : newEmployee;
        final empRow = await client
            .from('calisanlar')
            .select('id')
            .eq('ad', first)
            .maybeSingle();
        calisanId = (empRow?['id'] as num?)?.toInt();
      } catch (_) {}

      final updateData = <String, dynamic>{
        'appointment_datetime': newDateTime.toIso8601String(),
        'notes': newNotes.isEmpty ? null : newNotes,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (hizmetId != null) updateData['hizmet_id'] = hizmetId;
      if (calisanId != null) updateData['calisan_id'] = calisanId;

      // Orijinal kaydı müşteri + orijinal tarih ile eşle
      await client
          .from('randevu')
          .update(updateData)
          .eq('customerid', customerId)
          .eq(
            'appointment_datetime',
            appointment.appointmentDateTime.toIso8601String(),
          );

      // Local listeyi güncelle
      _safeSetState(() {
        final index = _userAppointments.indexWhere(
          (a) => a.appointmentDateTime == appointment.appointmentDateTime,
        );
        if (index != -1) {
          _userAppointments[index] = _userAppointments[index].copyWith(
            appointmentDateTime: newDateTime,
            notes: newNotes.isEmpty ? null : newNotes,
            serviceName: newService,
            employeeName: newEmployee,
          );
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Randevu başarıyla güncellendi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Randevu güncellenemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildQuickAccessCard(
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode
            ? SiriusColors.surface
            : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SiriusColors.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SiriusColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: SiriusColors.accent, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: SiriusColors.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: SiriusColors.defaultText,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryButtons() {
    final List<_StoryBtn> items = [
      _StoryBtn(
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('edit_profile_info'),
        Color(0xFFD2A6F5),
        Icons.edit,
        () {
          _showProfileSettingsDialog();
        },
      ),
      _StoryBtn(
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('profile_contact_us'),
        Color(0xFF9EF7BF),
        Icons.chat_bubble,
        () {
          _showContactDialog();
        },
      ),
      _StoryBtn(
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('profile_create_appointment'),
        Color(0xFFFAA940),
        Icons.add_circle,
        () {
          Navigator.pushNamed(context, '/appointment');
        },
      ),
      _StoryBtn(
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('get_directions'),
        Color(0xFFF5928E),
        Icons.map,
        () {
          _showDirectionDialog();
        },
      ),
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 800;
    final bool isTiny = screenWidth < 360;
    final bool isSmall = screenWidth < 480;
    final double circleSize = isTiny ? 52 : (isSmall ? 58 : 64);
    final double labelWidth = isTiny ? 68 : (isSmall ? 76 : 80);

    Widget buildItem(_StoryBtn it) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isDarkMode
                    ? const Color(0xFF181818)
                    : const Color(0xFFF0F0F0),
                gradient: _isDarkMode
                    ? null
                    : LinearGradient(
                        colors: [
                          it.color.withValues(alpha: 0.9),
                          it.color.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: it.color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: it.onTap,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Icon(
                      it.icon,
                      color: _isDarkMode ? it.color : Colors.white,
                      size: isTiny ? 24 : 28,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: labelWidth,
              child: Text(
                it.title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (isDesktop) {
      return Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [for (final it in items) buildItem(it)],
        ),
      );
    }

    return SizedBox(
      height: circleSize + 56,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final it in items) buildItem(it)],
        ),
      ),
    );
  }

  // Profil değişikliklerini kaydetme
  Future<void> _saveProfileChanges() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null || user.email == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Müşteri ID'sini al
      final customerId = _supaCustomer?['customerid'];
      if (customerId == null) {
        throw Exception('Müşteri ID bulunamadı');
      }

      // Profil bilgilerini güncelle
      await client
          .from('musteriler')
          .update({
            'firstname': _firstNameController.text.trim(),
            'lastname': _lastNameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('customerid', customerId);

      // Local state'i güncelle
      _safeSetState(() {
        _isEditingProfile = false;
        _supaCustomer = {
          ..._supaCustomer!,
          'firstname': _firstNameController.text.trim(),
          'lastname': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        };
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil bilgileri başarıyla güncellendi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil güncellenemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Yol tarifi dialog'u
  void _showDirectionDialog() {
    if (!mounted) return;

    final Map<String, dynamic>? biz = _isletme is Map<String, dynamic>
        ? _isletme as Map<String, dynamic>
        : null;
    final String adres = (biz?['adres'] ?? '-').toString();
    final String ilce = (biz?['ilce'] ?? '-').toString();
    final String sehir = (biz?['sehir'] ?? '-').toString();
    final String posta = (biz?['posta_kodu'] ?? biz?['postakodu'] ?? '-')
        .toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode
              ? const Color(0xFF181818).withValues(alpha: 0.95)
              : const Color(0xFFEDECE8).withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.location_on,
                color: _isDarkMode ? Colors.white : Colors.black87,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Yol Tarifi',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildContactInfoRow('Adres', adres),
                _buildContactInfoRow('İlçe', ilce),
                _buildContactInfoRow('Şehir', sehir),
                _buildContactInfoRow('Posta Kodu', posta),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SiriusColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SiriusColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.directions_car,
                        color: SiriusColors.accent,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toplu Taşıma ile Ulaşım',
                        style: TextStyle(
                          color: _isDarkMode
                              ? SiriusColors.heading
                              : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Metro: M4 Kadıköy-Kartal hattı\nOtobüs: 10A, 15F, 16A\nMarmaray: Ayrılık Çeşmesi durağı',
                        style: TextStyle(
                          color: _isDarkMode
                              ? SiriusColors.defaultText
                              : Colors.black87,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode
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
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('change_language'),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
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
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).setLanguage(AppLanguage.tr);
                    Navigator.of(context).pop();
                  },
                  tileColor:
                      Provider.of<LanguageProvider>(
                        context,
                        listen: false,
                      ).isTurkish
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
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).setLanguage(AppLanguage.en);
                    Navigator.of(context).pop();
                  },
                  tileColor:
                      Provider.of<LanguageProvider>(
                        context,
                        listen: false,
                      ).isEnglish
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
              child: Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('cancel'),
              ),
            ),
          ],
        );
      },
    );
  }
}
