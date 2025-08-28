// Gerekli paketleri import ediyoruz.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hairsalon_flutter/models/appointment.dart';
import 'package:hairsalon_flutter/models/employee.dart';
import 'package:hairsalon_flutter/models/employee_performance.dart';
import 'package:hairsalon_flutter/services/db_service.dart';
import 'package:hairsalon_flutter/constants/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

// Ana AdminScreen widget'ı
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

// Responsive tasarım için eşik değeri (kaldırıldı)

class _AdminScreenState extends State<AdminScreen> {
  // State değişkenleri
  late Future<List<Appointment>> _appointmentsFuture;

  List<EmployeePerformance> _employeePerformance = [];
  bool _isLoadingPerformance = true;

  List<Employee> _allEmployees = [];
  bool _isLoadingEmployees = true;

  // Supabase ve çoklu-tenant için yardımcı durum
  String? _isletmeId;
  Map<String, dynamic>? _isletme;
  // Supabase randevu UUID -> UI'de kullanılan lokal int ID eşlemesi
  final Map<int, String> _localApptIdToUuid = {};
  int _localApptCounter = 0;

  // UI için controller'lar ve state
  int _selectedIndex =
      2; // 0: Employee Operations, 1: Employee Performance, 2: Personal Info (default)
  int _employeeOpsIndex = 0; // 0: Appointments, 1: Employee Management

  // Seçili randevular için state
  Set<String> _selectedAppointments = {};

  // Dark mode ve dil seçenekleri
  bool _isDarkMode = false;
  String _selectedLanguage = 'tr';
  bool _isDebugMode = true; // Debug modu varsayılan olarak açık
  final bool _isAutoRefresh =
      false; // Otomatik yenileme varsayılan olarak kapalı
  Timer? _autoRefreshTimer; // Otomatik yenileme timer'ı

  // Günlük özet sayıları
  int _todayTotalAppointments = 0;
  int _todayPendingAppointments = 0;
  int _todayCompletedAppointments = 0;

  // Çalışan listesi filtreleme
  String _employeeSearchQuery = '';
  bool _employeeOnlyActive = false;

  // Drawer kontrolü için Scaffold key
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedService;
  String? _selectedCategory;

  // Randevu arama/sıralama/filtreleme durumu
  String _appointmentSearchQuery = '';
  bool _appointmentSortAscending =
      false; // false: en yeni -> en eski (varsayılan)
  DateTime? _appointmentFilterStart;
  DateTime? _appointmentFilterEnd;
  String _appointmentFilterStatus =
      'Tümü'; // Tümü, Pending, Approved, Cancelled

  @override
  void initState() {
    super.initState();

    // Sıralı olarak veri yükle
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _loadIsletme();
      await _fetchEmployees();
      await _fetchAppointments();
      await _fetchEmployeePerformance();
      await _fetchTodaySummary();
    } catch (e) {
      // Hata durumunda kullanıcıya bilgi ver
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veri yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _skillsController.dispose();
    _selectedAppointments.clear();
    super.dispose();
  }

  // --- Veri Çekme Fonksiyonları (PostgreSQL ile entegre edildi) ---

  Future<void> _fetchAppointments() async {
    if (mounted) {
      setState(() {
        _appointmentsFuture = _getAppointmentsFromSupabase();
      });
    }
  }

  Future<void> _ensureIsletmeId() async {
    if (!mounted) return;

    if (_isletmeId == null || _isletmeId!.isEmpty) {
      try {
        _isletmeId = await DbService.resolveIsletmeId();
      } catch (e) {
        // Sessizce devam et
      }
    }
  }

  Future<void> _loadIsletme() async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return;
      final isletme = await DbService.getIsletmeById(_isletmeId!);
      if (mounted) {
        setState(() {
          _isletme = isletme;
        });
      }
      await _fetchTodaySummary();
    } catch (_) {
      // Hata durumunda sessizce devam et
    }
  }

  Future<List<Appointment>> _getAppointmentsFromSupabase() async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return [];

      final client = Supabase.instance.client;
      // Not: Bazı ortamlarda 'randevu_view' bulunmayabilir. Bu nedenle doğrudan
      // 'randevu' tablosundan ilişkisel select ile gerekli alanları çekiyoruz.
      // İlişkiler: customerid -> musteriler, calisan_id -> calisanlar
      final data = await client
          .from('randevu')
          .select(
            'randevu_id, appointment_datetime, process, total_price, approval_status, notes, customerid, calisan_id,'
            'musteriler:customerid (firstname, lastname, email, phone),'
            'calisanlar:calisan_id (ad, soyad)',
          )
          .eq('isletme_id', _isletmeId!)
          .order('appointment_datetime', ascending: false);

      // Widget dispose edildiyse işlemi durdur
      if (!mounted) return [];

      // Yeni liste ve lokal ID eşlemelerini oluştur
      _localApptIdToUuid.clear();
      _localApptCounter = 0;

      final List<Appointment> list = [];
      for (final row in (data as List)) {
        final map = row as Map<String, dynamic>;
        _localApptCounter += 1;
        final localId = _localApptCounter;
        final uuid = (map['randevu_id'] ?? '').toString();
        _localApptIdToUuid[localId] = uuid;

        final dynamic priceVal = map['total_price'];
        double price = 0.0;
        if (priceVal is num) {
          price = priceVal.toDouble();
        } else if (priceVal is String) {
          price = double.tryParse(priceVal) ?? 0.0;
        }

        final dynamic dtVal = map['appointment_datetime'];
        final DateTime apptDt = dtVal is String
            ? DateTime.parse(dtVal)
            : (dtVal is DateTime ? dtVal : DateTime.now());

        // process alanını metne çevir (0/1/2)
        String processText = 'Bekliyor';
        final dynamic proc = map['process'];
        if (proc is int) {
          switch (proc) {
            case 0:
              processText = 'Bekliyor';
              break;
            case 1:
              processText = 'Devam Ediyor';
              break;
            case 2:
              processText = 'Tamamlandı';
              break;
            default:
              processText = 'Bilinmeyen';
          }
        }

        // İlişkisel alanlardan isim ve iletişim bilgileri
        final musteriler = map['musteriler'] as Map<String, dynamic>?;
        final calisan = map['calisanlar'] as Map<String, dynamic>?;

        final String customerFirst = (musteriler?['firstname'] ?? '')
            .toString();
        final String customerLast = (musteriler?['lastname'] ?? '').toString();
        final String customerName = [
          customerFirst,
          customerLast,
        ].where((p) => p.trim().isNotEmpty).join(' ');

        final String employeeFirst = (calisan?['ad'] ?? '').toString();
        final String employeeLast = (calisan?['soyad'] ?? '').toString();
        final String employeeName = [
          employeeFirst,
          employeeLast,
        ].where((p) => p.trim().isNotEmpty).join(' ');

        list.add(
          Appointment(
            appointmentId:
                localId, // UI aynı kalsın diye lokal sayı kullanıyoruz
            customerName: customerName.isNotEmpty ? customerName : 'Bilinmeyen',
            employeeName: employeeName.isNotEmpty ? employeeName : 'Bilinmeyen',
            serviceName: '-', // Hizmet adı şimdilik gösterilmiyor
            process: processText,
            totalPrice: price,
            appointmentDateTime: apptDt,
            approvalStatus: (map['approval_status'] ?? 'Pending').toString(),
            createdAt: null,
            updatedAt: null,
            notes: (map['notes'] as String?),
            customerPhone: (musteriler?['phone'] as String?) ?? '',
            customerEmail: (musteriler?['email'] as String?) ?? '',
          ),
        );
      }

      return list;
    } catch (e) {
      // Supabase yoksa veya hata varsa boş liste döndür
      return [];
    }
  }

  // Randevu durumunu manuel olarak güncelleme
  Future<void> _updateAppointmentStatus(
    int appointmentId,
    String status,
  ) async {
    try {
      if (!mounted) return;

      // Lokal numeric ID'den Supabase UUID'ye çevir
      final uuid = _localApptIdToUuid[appointmentId];
      if (uuid == null || uuid.isEmpty) {
        throw Exception('Randevu ID eşlemesi bulunamadı');
      }

      final client = Supabase.instance.client;
      await client
          .from('randevu')
          .update({'approval_status': status})
          .eq('randevu_id', uuid);

      if (mounted) {
        // Randevuları yeniden yükle
        await _fetchAppointments();

        // Günlük özeti yeniden yükle
        await _fetchTodaySummary();

        // Performans verilerini yeniden yükle

        await _fetchEmployeePerformance();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Randevu durumu $status olarak güncellendi ve performans verileri yenilendi!',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Eğer randevu onaylandıysa performans analizi sekmesine geç
          if (status == 'Approved' || status == 'Tamamlandı') {
            _selectedIndex = 2; // Performans analizi sekmesi
            setState(() {});
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Çalışan ekleme
  Future<void> _addEmployee() async {
    if (!mounted) return;

    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _skillsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tüm alanları doldurun!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) {
        throw Exception('İşletme ID bulunamadı');
      }

      final client = Supabase.instance.client;

      // Çalışan eklemeden önce aynı isimde çalışan var mı kontrol et
      final existingEmployee = await client
          .from('calisanlar')
          .select('id')
          .eq('isletme_id', _isletmeId!)
          .eq('ad', _firstNameController.text.trim())
          .eq('soyad', _lastNameController.text.trim())
          .maybeSingle();

      if (existingEmployee != null) {
        throw Exception('Bu isimde bir çalışan zaten mevcut!');
      }

      await client.from('calisanlar').insert({
        'isletme_id': _isletmeId,
        'ad': _firstNameController.text.trim(),
        'soyad': _lastNameController.text.trim(),
        'beceriler': _skillsController.text.trim(),
        'uzmanlik': _selectedCategory ?? 'genel',
        'hizmet': _selectedService ?? 'Genel',
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'aktif': true,
        'sira': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      _firstNameController.clear();
      _lastNameController.clear();
      _skillsController.clear();
      _emailController.clear();
      _phoneController.clear();
      _selectedService = null;
      _selectedCategory = null;

      if (mounted) {
        await _fetchEmployees();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Çalışan başarıyla eklendi!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Çalışan güncelleme
  Future<void> _updateEmployee(Employee employee) async {
    try {
      if (!mounted) return;

      await _ensureIsletmeId();
      if (_isletmeId == null) {
        throw Exception('İşletme ID bulunamadı');
      }

      final client = Supabase.instance.client;
      if (employee.id == null) {
        throw Exception('Çalışan ID bulunamadı');
      }

      // Güncelleme öncesi aynı isimde başka çalışan var mı kontrol et
      final existingEmployee = await client
          .from('calisanlar')
          .select('id')
          .eq('isletme_id', _isletmeId!)
          .eq('ad', employee.firstName.trim())
          .eq('soyad', employee.lastName.trim())
          .neq('id', employee.id!)
          .maybeSingle();

      if (existingEmployee != null) {
        throw Exception('Bu isimde başka bir çalışan zaten mevcut!');
      }

      await client
          .from('calisanlar')
          .update({
            'ad': employee.firstName.trim(),
            'soyad': employee.lastName.trim(),
            'beceriler': employee.skills.trim(),
            'uzmanlik': employee.expertise.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', employee.id!);

      if (mounted) {
        await _fetchEmployees();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Çalışan başarıyla güncellendi!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Çalışan silme
  Future<void> _deleteEmployee(int employeeId) async {
    try {
      if (!mounted) return;

      await _ensureIsletmeId();
      if (_isletmeId == null) {
        throw Exception('İşletme ID bulunamadı');
      }

      final client = Supabase.instance.client;
      // Soft delete
      await client
          .from('calisanlar')
          .update({'aktif': false})
          .eq('id', employeeId);

      if (mounted) {
        await _fetchEmployees();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Çalışan başarıyla silindi!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchEmployeePerformance() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingPerformance = true;
        });
      }

      await _ensureIsletmeId();
      if (_isletmeId == null) {
        if (mounted) {
          setState(() {
            _employeePerformance = [];
            _isLoadingPerformance = false;
          });
        }
        return;
      }

      // Önce çalışanların yüklenmesini bekle
      if (_allEmployees.isEmpty) {
        await _fetchEmployees();
        // Çalışanlar yüklendikten sonra tekrar kontrol et
        if (_allEmployees.isEmpty) {
          if (mounted) {
            setState(() {
              _employeePerformance = [];
              _isLoadingPerformance = false;
            });
          }
          return;
        }
      }

      final client = Supabase.instance.client;
      final today = DateTime.now();
      final dateStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      List<EmployeePerformance> performances = [];

      // Önce performans tablosundan veri çekmeyi dene
      try {
        final rows = await client
            .from('calisan_performans')
            .select()
            .eq('isletme_id', _isletmeId!)
            .eq('tarih', dateStr)
            .order('created_at', ascending: true);

        if (rows.isNotEmpty) {
          final Map<int, String> idToName = {
            for (final e in _allEmployees)
              if (e.id != null) e.id!: e.fullName,
          };

          for (final row in (rows as List)) {
            final m = row as Map<String, dynamic>;
            final calisanId = (m['calisan_id'] as num?)?.toInt();
            final name = calisanId != null
                ? (idToName[calisanId] ?? 'Bilinmeyen')
                : 'Bilinmeyen';
            performances.add(
              EmployeePerformance(
                employeeName: name,
                dailyEarnings: (m['gunluk_kazanc'] as num?)?.toDouble() ?? 0.0,
                totalEarnings: (m['toplam_kazanc'] as num?)?.toDouble() ?? 0.0,
                efficiency: (m['verimlilik'] as num?)?.toDouble() ?? 0.0,
                date:
                    DateTime.tryParse((m['tarih'] ?? dateStr).toString()) ??
                    today,
                appointmentsCompleted:
                    (m['tamamlanan_randevu'] as num?)?.toInt() ?? 0,
                averageRating: (m['ortalama_puan'] as num?)?.toDouble() ?? 0.0,
              ),
            );
          }
        }
      } catch (e) {
        performances = [];
      }

      // Eğer performans tablosunda veri yoksa, randevulardan hesapla
      if (performances.isEmpty) {
        try {
          final now = DateTime.now();
          // Son 30 günlük veriyi al
          final start = DateTime(now.year, now.month, now.day - 30, 0, 0, 0);
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

          // Tüm çalışanlar için performans hesapla (randevu olsun ya da olmasın)
          // ignore: unused_local_variable
          final Map<int, String> idToName = {
            for (final e in _allEmployees)
              if (e.id != null) e.id!: e.fullName,
          };

          // Her çalışan için performans hesapla
          final List<EmployeePerformance> computed = [];

          for (final employee in _allEmployees) {
            if (employee.id == null) continue;

            final empId = employee.id!;
            final name = employee.fullName;

            try {
              // Bu çalışanın randevularını getir (bugünkü onaylanan randevulara öncelik ver)
              final today = DateTime.now();
              final todayStart = DateTime(
                today.year,
                today.month,
                today.day,
                0,
                0,
                0,
              );
              final todayEnd = DateTime(
                today.year,
                today.month,
                today.day,
                23,
                59,
                59,
                999,
              );

              // Önce bugünkü onaylanan randevuları getir (çeşitli durum değerlerini kabul et)
              final todayAppts = await client
                  .from('randevu')
                  .select(
                    'calisan_id, approval_status, total_price, appointment_datetime',
                  )
                  .eq('isletme_id', _isletmeId!)
                  .eq('calisan_id', empId)
                  .or(
                    "approval_status.eq.Approved,approval_status.eq.approved,"
                    "approval_status.eq.Tamamlandı,approval_status.eq.tamamlandı,"
                    "approval_status.eq.Onaylandı,approval_status.eq.onaylandı,"
                    "approval_status.eq.Completed,approval_status.eq.completed",
                  )
                  .gte(
                    'appointment_datetime',
                    todayStart.toUtc().toIso8601String(),
                  )
                  .lte(
                    'appointment_datetime',
                    todayEnd.toUtc().toIso8601String(),
                  );

              // Bugünkü bekleyen randevuları getir
              final todayPendingAppts = await client
                  .from('randevu')
                  .select(
                    'calisan_id, approval_status, total_price, appointment_datetime',
                  )
                  .eq('isletme_id', _isletmeId!)
                  .eq('calisan_id', empId)
                  .eq('approval_status', 'Pending')
                  .gte(
                    'appointment_datetime',
                    todayStart.toUtc().toIso8601String(),
                  )
                  .lte(
                    'appointment_datetime',
                    todayEnd.toUtc().toIso8601String(),
                  );

              // Sonra genel randevuları getir
              final appts = await client
                  .from('randevu')
                  .select(
                    'calisan_id, approval_status, total_price, appointment_datetime',
                  )
                  .eq('isletme_id', _isletmeId!)
                  .eq('calisan_id', empId)
                  .gte('appointment_datetime', start.toIso8601String())
                  .lte('appointment_datetime', end.toIso8601String());

              int approvedCount = 0;
              int pendingCount = 0;
              double totalEarnings = 0.0;
              double todayEarnings = 0.0;

              // Bugünkü onaylanan randevuları işle
              for (final row in (todayAppts as List)) {
                final m = row as Map<String, dynamic>;
                final dynamic rawPrice = m['total_price'];
                final double price = rawPrice is num
                    ? rawPrice.toDouble()
                    : double.tryParse(rawPrice?.toString() ?? '') ?? 0.0;
                todayEarnings += price;
                approvedCount++;
              }

              // Genel randevuları işle
              for (final row in (appts as List)) {
                final m = row as Map<String, dynamic>;
                final status = (m['approval_status'] ?? '')
                    .toString()
                    .toLowerCase();
                final dynamic rawPrice = m['total_price'];
                final double price = rawPrice is num
                    ? rawPrice.toDouble()
                    : double.tryParse(rawPrice?.toString() ?? '') ?? 0.0;

                if (status == 'approved' ||
                    status == 'tamamlandı' ||
                    status == 'onaylandı' ||
                    status == 'completed') {
                  totalEarnings += price;
                }
              }

              // Bugünkü bekleyenleri say
              pendingCount = (todayPendingAppts as List).length;

              final total = approvedCount + pendingCount;
              // Verimlilik: Onaylanan randevular / Toplam randevular * 100
              final efficiency = total > 0
                  ? (approvedCount * 100.0 / total)
                  : 0.0;

              computed.add(
                EmployeePerformance(
                  employeeName: name,
                  dailyEarnings: todayEarnings, // Bugünkü kazancı kullan
                  totalEarnings: totalEarnings, // Tüm zamanlardan toplam kazanç
                  efficiency: efficiency,
                  date: DateTime(now.year, now.month, now.day),
                  appointmentsCompleted: approvedCount,
                  averageRating: approvedCount > 0
                      ? 4.5
                      : 0.0, // Onaylanan randevu varsa rating ver
                  pendingAppointments: pendingCount,
                ),
              );
            } catch (e) {
              // Hata durumunda da çalışanı ekle (sıfır performans ile)
              computed.add(
                EmployeePerformance(
                  employeeName: name,
                  dailyEarnings: 0.0,
                  totalEarnings: 0.0,
                  efficiency: 0.0,
                  date: DateTime(now.year, now.month, now.day),
                  appointmentsCompleted: 0,
                  averageRating: 0.0,
                  pendingAppointments: 0,
                ),
              );
            }
          }

          performances = computed;
        } catch (e) {
          // Hata durumunda tüm çalışanları sıfır performans ile ekle
          performances = _allEmployees
              .map(
                (employee) => EmployeePerformance(
                  employeeName: employee.fullName,
                  dailyEarnings: 0.0,
                  totalEarnings: 0.0,
                  efficiency: 0.0,
                  date: DateTime.now(),
                  appointmentsCompleted: 0,
                  averageRating: 0.0,
                  pendingAppointments: 0,
                ),
              )
              .toList();
        }
      }

      if (mounted) {
        setState(() {
          _employeePerformance = performances;
          _isLoadingPerformance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPerformance = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Performans verileri yüklenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingEmployees = true;
        });
      }

      await _ensureIsletmeId();
      if (_isletmeId == null) {
        if (mounted) {
          setState(() {
            _allEmployees = [];
            _isLoadingEmployees = false;
          });
        }
        return;
      }

      final client = Supabase.instance.client;

      // Önce tüm çalışanları getir (aktif olmayanlar dahil)
      final allRows = await client
          .from('calisanlar')
          .select()
          .eq('isletme_id', _isletmeId!)
          .order('sira', ascending: true)
          .order('created_at', ascending: true);

      // Sadece aktif çalışanları filtrele
      final rows = await client
          .from('calisanlar')
          .select()
          .eq('isletme_id', _isletmeId!)
          .eq('aktif', true) // Sadece aktif çalışanları getir
          .order('sira', ascending: true)
          .order('created_at', ascending: true);

      // Eğer aktif çalışan yoksa, tüm çalışanları göster
      final finalRows = (rows as List).isNotEmpty ? rows : allRows;

      final employees = <Employee>[];
      for (final row in (finalRows as List)) {
        final m = row as Map<String, dynamic>;
        final empId = (m['id'] as num?)?.toInt();
        final firstName = (m['ad'] ?? '').toString();
        final lastName = (m['soyad'] ?? '').toString();
        final isActive = (m['aktif'] as bool?) ?? true;

        employees.add(
          Employee(
            id: empId,
            firstName: firstName,
            lastName: lastName,
            expertise: (m['uzmanlik'] ?? 'Genel').toString(),
            skills: (m['beceriler'] ?? '').toString(),
            prolificacy: null,
            dailyEarnings: null,
            serviceId: null,
            email: (m['email'] as String?),
            phone: (m['phone'] as String?),
            isActive: isActive,
            hireDate: m['ise_baslama_tarihi'] != null
                ? DateTime.tryParse(m['ise_baslama_tarihi'].toString())
                : null,
            profileImage: (m['profil_resmi'] as String?),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _allEmployees = employees;
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEmployees = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çalışan verileri yüklenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _isDarkMode
          ? Colors
                .black // Dark mode'da siyah (eskisi gibi)
          : const Color(0xFFE5E2DB), // Açık modda #E5E2DB rengi
      appBar: AppBar(
        backgroundColor: SiriusColors.contrast,
        toolbarHeight: 56,
        iconTheme: const IconThemeData(
          color: Colors.white, // Sidebar ikonunu beyaz yap
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final bool isNarrow = constraints.maxWidth < 400;
            return Row(
              children: [
                const Spacer(),
                // Logo + İşletme adı (dinamik)
                ((_isletme != null) &&
                        ((_isletme!['logo_url'] as String?)?.isNotEmpty ==
                            true))
                    ? Image.network(
                        ((_isletme!['logo_url'] as String).startsWith('http') ||
                                (_isletme!['logo_url'] as String).startsWith(
                                  'https',
                                ))
                            ? (_isletme!['logo_url'] as String)
                            : DbService.getPublicImageUrl(
                                _isletme!['logo_url'] as String,
                              ),
                        height: isNarrow ? 32 : 40,
                        width: isNarrow ? 32 : 40,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/salon/3.png',
                            height: isNarrow ? 32 : 40,
                            width: isNarrow ? 32 : 40,
                          );
                        },
                      )
                    : Image.asset(
                        'assets/salon/3.png',
                        height: isNarrow ? 32 : 40,
                        width: isNarrow ? 32 : 40,
                      ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    (_isletme != null && (_isletme!['isim'] as String?) != null)
                        ? ((_isletme!['isim'] as String?) ?? 'Sirius')
                        : 'Sirius',
                    style: TextStyle(
                      color: const Color.fromARGB(255, 228, 224, 216),
                      fontFamily: 'Playfair Display',
                      fontWeight: FontWeight.bold,
                      fontSize: isNarrow ? 16 : 20,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          // Dark Mode Toggle
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: const Color.fromARGB(255, 228, 224, 216),
              ),
              onPressed: () {
                setState(() {
                  _isDarkMode = !_isDarkMode;
                });
              },
              tooltip: _isDarkMode ? 'Light Mode' : 'Dark Mode',
            ),
          ),
        ],
      ),
      drawer: _buildSidebarDrawer(),
      body: _selectedIndex == 0
          ? _buildEmployeeOperations()
          : _selectedIndex == 1
          ? _buildPerformanceAnalysis()
          : _buildWelcomeScreen(),
    );
  }

  // Drawer içeriği (eski sol sidebar ile aynı)
  Widget _buildSidebarDrawer() {
    final lang = Provider.of<LanguageProvider>(context);
    return Drawer(
      backgroundColor: SiriusColors.surface,
      width: MediaQuery.of(context).size.width < 400 ? 200 : 250,
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
                          ((_isletme != null) &&
                              ((_isletme!['logo_url'] as String?)?.isNotEmpty ==
                                  true))
                          ? Image.network(
                              (((_isletme!['logo_url'] as String?)!).startsWith(
                                        'http',
                                      ) ||
                                      ((_isletme!['logo_url'] as String?)!)
                                          .startsWith('https'))
                                  ? (_isletme!['logo_url'] as String)
                                  : DbService.getPublicImageUrl(
                                      _isletme!['logo_url'] as String,
                                    ),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/salon/3.png',
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.asset(
                              'assets/salon/3.png',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (_isletme != null && (_isletme!['isim'] as String?) != null)
                        ? ((_isletme!['isim'] as String?) ?? 'Sirius')
                        : 'Sirius',
                    style: TextStyle(
                      color: SiriusColors.heading,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                  Text(
                    (_isletme != null &&
                            (_isletme!['aciklama'] as String?) != null)
                        ? ((_isletme!['aciklama'] as String?) ?? 'Beauty & Spa')
                        : 'Beauty & Spa',
                    style: TextStyle(
                      color: SiriusColors.defaultText,
                      fontSize: 16,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: SiriusColors.defaultText, height: 1),
            // Ana Sayfa en üstte
            _buildSidebarItem(
              icon: Icons.home,
              title: 'Ana Sayfa',
              isSelected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.of(context).pop();
              },
            ),
            _buildSidebarItem(
              icon: Icons.work,
              title: lang.t('employee_and_appointment'),
              isSelected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.of(context).pop();
              },
            ),
            _buildSidebarItem(
              icon: Icons.analytics,
              title: lang.t('performance_analysis'),
              isSelected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.of(context).pop();
              },
            ),
            // Yeni: Profil Bilgileri
            _buildSidebarItem(
              icon: Icons.person,
              title: lang.t('profile_info'),
              isSelected: false,
              onTap: () {
                Navigator.of(context).pop();
                _showAdminProfileDialog();
              },
            ),
            const SizedBox(height: 20),
            const Spacer(),
            const Divider(color: SiriusColors.defaultText, height: 1),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.language, color: SiriusColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      isExpanded: true,
                      underline: Container(),
                      items: const [
                        DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedLanguage = value ?? 'tr';
                        });
                      },
                      style: TextStyle(
                        color: SiriusColors.heading,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Dil seçme butonu
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Icon(Icons.language, color: SiriusColors.accent),
                title: Text(
                  lang.t('change_language'),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  lang.isTurkish ? 'Türkçe' : 'English',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  _showLanguageSelectionDialog(context, lang);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: SiriusColors.accent.withValues(alpha: 0.1),
              ),
            ),
            
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('Çıkış Yap'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.white),
                  ),
                  elevation: 0,
                ),
              ),
            ),
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
          color: isSelected ? SiriusColors.accent : SiriusColors.defaultText,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? SiriusColors.accent : SiriusColors.defaultText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected
            ? SiriusColors.accent.withValues(alpha: 0.1)
            : null,
      ),
    );
  }

  Widget _buildEmployeeOperations() {
    return Column(
      children: [
        // Sekme Butonları
        Container(
          margin: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 12 : 20,
          ),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: SiriusColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: SiriusColors.accent.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTabButton(
                  title: 'Randevular',
                  isSelected: _employeeOpsIndex == 0,
                  onTap: () => setState(() {
                    _employeeOpsIndex = 0;
                    _selectedAppointments.clear();
                  }),
                ),
              ),
              Expanded(
                child: _buildTabButton(
                  title: 'Çalışan Yönetimi',
                  isSelected: _employeeOpsIndex == 1,
                  onTap: () => setState(() {
                    _employeeOpsIndex = 1;
                    _selectedAppointments.clear();
                  }),
                ),
              ),
            ],
          ),
        ),

        // İçerik - Expanded kullanarak overflow'u önlüyoruz
        Expanded(
          child: _employeeOpsIndex == 0
              ? _buildAppointmentsTab()
              : _buildEmployeeManagementTab(),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          vertical: MediaQuery.of(context).size.width < 600 ? 12 : 16,
          horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 20,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? SiriusColors.accent
              : (_isDarkMode
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? SiriusColors.accent : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? SiriusColors.contrast : SiriusColors.heading,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    return FutureBuilder<List<Appointment>>(
      future: _appointmentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: SiriusColors.accent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Randevular yüklenirken hata oluştu: ${snapshot.error}',
                  style: const TextStyle(
                    color: SiriusColors.defaultText,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchAppointments,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SiriusColors.accent,
                    foregroundColor: SiriusColors.contrast,
                  ),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          );
        }

        final appointments = snapshot.data ?? [];

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Arama ve Filtreleme
              Container(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 600 ? 12 : 16,
                ),
                color: _isDarkMode
                    ? SiriusColors.surface
                    : Colors.black.withValues(
                        alpha: 0.3,
                      ), // Açık modda transparan siyah
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Arama ve Filtreleme
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isNarrow = constraints.maxWidth < 500;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                decoration: InputDecoration(
                                  hintText: 'Randevu ara...',
                                  prefixIcon: Icon(Icons.search),
                                  border: const OutlineInputBorder(),
                                  hintStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                                cursorColor: Colors.black,
                                style: TextStyle(color: Colors.black),
                                onChanged: (query) {
                                  setState(() {
                                    _appointmentSearchQuery = query.trim();
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _showFilterDialog();
                                  },
                                  icon: const Icon(Icons.filter_list),
                                  label: const Text('Filtrele'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SiriusColors.accent,
                                    foregroundColor: SiriusColors.contrast,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Randevu ara...',
                                  prefixIcon: Icon(Icons.search),
                                  border: const OutlineInputBorder(),
                                  hintStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                                cursorColor: Colors.black,
                                style: TextStyle(color: Colors.black),
                                onChanged: (query) {
                                  setState(() {
                                    _appointmentSearchQuery = query.trim();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Row(
                              children: [
                                // Sıralama butonu (en yeni <-> en eski)
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _appointmentSortAscending =
                                          !_appointmentSortAscending;
                                    });
                                  },
                                  icon: Icon(
                                    _appointmentSortAscending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                  ),
                                  label: Text(
                                    _appointmentSortAscending
                                        ? 'Eskiden Yeniye'
                                        : 'En Yeniden Eskiye',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SiriusColors.surface,
                                    foregroundColor: SiriusColors.accent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _showFilterDialog();
                                  },
                                  icon: const Icon(Icons.filter_list),
                                  label: const Text('Filtrele'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SiriusColors.accent,
                                    foregroundColor: SiriusColors.contrast,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Günlük özet
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? Colors.blueGrey[800]
                                : Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.today,
                                size: 16,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Bugün: $_todayTotalAppointments',
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? SiriusColors.defaultText
                                      : Colors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? Colors.orange[900]
                                : Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.timelapse,
                                size: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Bekleyen: $_todayPendingAppointments',
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? SiriusColors.defaultText
                                      : Colors.orange,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? Colors.green[900]
                                : Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Tamamlanan: $_todayCompletedAppointments',
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? SiriusColors.defaultText
                                      : Colors.green,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Üst işlem butonları - Sağ üstte ikonlar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Tümünü seç checkbox'ı
                        Row(
                          children: [
                            Checkbox(
                              value:
                                  _selectedAppointments.length ==
                                      appointments.length &&
                                  appointments.isNotEmpty,
                              tristate: true,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    // Tümünü seç
                                    _selectedAppointments = appointments
                                        .map(
                                          (appointment) => appointment
                                              .appointmentId
                                              .toString(),
                                        )
                                        .toSet();
                                  } else {
                                    // Tümünü kaldır
                                    _selectedAppointments.clear();
                                  }
                                });
                              },
                            ),
                            Text(
                              'Tümünü Seç',
                              style: TextStyle(
                                color: _isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        // Sağ taraftaki işlem butonları
                        Row(
                          children: [
                            // Seçili randevuları silme ikonu
                            IconButton(
                              onPressed: _selectedAppointments.isEmpty
                                  ? null
                                  : () => _showBulkDeleteDialog(
                                      appointments
                                          .where(
                                            (appointment) =>
                                                _selectedAppointments.contains(
                                                  appointment.appointmentId
                                                      .toString(),
                                                ),
                                          )
                                          .toList(),
                                    ),
                              icon: Icon(
                                Icons.delete,
                                color: _selectedAppointments.isEmpty
                                    ? Colors.grey
                                    : Colors.red[600],
                                size: 24,
                              ),
                              tooltip: 'Seçili Randevuları Sil',
                            ),
                            const SizedBox(width: 8),
                            // Yenileme ikonu
                            IconButton(
                              onPressed: () => _refreshAppointments(),
                              icon: Icon(
                                Icons.refresh,
                                color: SiriusColors.accent,
                                size: 24,
                              ),
                              tooltip: 'Yenile',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Randevu Listesi - Container ile height sınırlaması
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Builder(
                  builder: (context) {
                    // Arama + filtre + sıralama uygulanan listeyi hazırla
                    List<Appointment> filtered = List.of(appointments);

                    // Metin araması (müşteri, çalışan, hizmet)
                    final q = _appointmentSearchQuery.toLowerCase();
                    if (q.isNotEmpty) {
                      filtered = filtered.where((a) {
                        return (a.customerName.toLowerCase().contains(q) ||
                            a.employeeName.toLowerCase().contains(q) ||
                            a.serviceName.toLowerCase().contains(q));
                      }).toList();
                    }

                    // Durum filtresi
                    if (_appointmentFilterStatus != 'Tümü') {
                      filtered = filtered.where((a) {
                        final status = a.approvalStatus;
                        if (_appointmentFilterStatus == 'Tamamlandı') {
                          // UI'de Tamamlandı, veride Approved + geçmiş tarih
                          return status.toLowerCase() == 'approved' &&
                              a.appointmentDateTime.isBefore(DateTime.now());
                        }
                        return status.toLowerCase() ==
                            _appointmentFilterStatus.toLowerCase();
                      }).toList();
                    }

                    // Tarih aralığı filtresi
                    if (_appointmentFilterStart != null) {
                      filtered = filtered
                          .where(
                            (a) => !a.appointmentDateTime.isBefore(
                              _appointmentFilterStart!,
                            ),
                          )
                          .toList();
                    }
                    if (_appointmentFilterEnd != null) {
                      filtered = filtered
                          .where(
                            (a) => !a.appointmentDateTime.isAfter(
                              _appointmentFilterEnd!,
                            ),
                          )
                          .toList();
                    }

                    // Sıralama
                    filtered.sort(
                      (a, b) => a.appointmentDateTime.compareTo(
                        b.appointmentDateTime,
                      ),
                    );
                    if (!_appointmentSortAscending) {
                      filtered = filtered.reversed.toList();
                    }

                    return filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Randevu bulunamadı.',
                              style: TextStyle(
                                color: SiriusColors.defaultText,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final appointment = filtered[index];
                              return Card(
                                margin: EdgeInsets.symmetric(
                                  horizontal:
                                      MediaQuery.of(context).size.width < 600
                                      ? 12
                                      : 16,
                                  vertical: 8,
                                ),
                                color: _isDarkMode
                                    ? SiriusColors.surface
                                    : Colors.black.withValues(
                                        alpha: 0.3,
                                      ), // Açık modda transparan siyah
                                child: ListTile(
                                  leading: Radio<String>(
                                    value: appointment.appointmentId.toString(),
                                    groupValue: _selectedAppointments.isEmpty
                                        ? null
                                        : _selectedAppointments.first,
                                    onChanged: (String? value) {
                                      setState(() {
                                        if (value != null) {
                                          if (_selectedAppointments.contains(
                                            value,
                                          )) {
                                            _selectedAppointments.remove(value);
                                          } else {
                                            _selectedAppointments.add(value);
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  title: Text(
                                    appointment.customerName,
                                    style: const TextStyle(
                                      color: SiriusColors.heading,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hizmet: ${appointment.serviceName}',
                                        style: const TextStyle(
                                          color: SiriusColors.heading,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Çalışan: ${appointment.employeeName}',
                                        style: const TextStyle(
                                          color: SiriusColors.heading,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Tarih: ${_formatDateTime(appointment.appointmentDateTime)}',
                                        style: const TextStyle(
                                          color: SiriusColors.heading,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Fiyat: ₺${appointment.totalPrice}',
                                        style: TextStyle(
                                          color: SiriusColors.accent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Builder(
                                    builder: (context) {
                                      final double width = MediaQuery.of(
                                        context,
                                      ).size.width;
                                      final bool veryNarrow = width < 380;
                                      final bool narrow = width < 600;
                                      final double minW = veryNarrow
                                          ? 100
                                          : (narrow ? 140 : 180);
                                      final double maxW = veryNarrow
                                          ? 140
                                          : (narrow ? 180 : 220);
                                      final bool isPast = appointment
                                          .appointmentDateTime
                                          .isBefore(DateTime.now());
                                      return Container(
                                        constraints: BoxConstraints(
                                          minWidth: minW,
                                          maxWidth: maxW,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: isPast
                                                  ? null
                                                  : () =>
                                                        _toggleAppointmentStatus(
                                                          appointment,
                                                        ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      _getStatusColor(
                                                        appointment
                                                            .approvalStatus,
                                                      ).withValues(
                                                        alpha: isPast
                                                            ? 0.4
                                                            : 1.0,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  _getDisplayStatusForAppointment(
                                                    appointment,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // Silme butonu
                                            GestureDetector(
                                              onTap: isPast
                                                  ? null
                                                  : () =>
                                                        _showDeleteAppointmentDialog(
                                                          appointment,
                                                        ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      (Colors.red[600] ??
                                                              Colors.red)
                                                          .withValues(
                                                            alpha: isPast
                                                                ? 0.4
                                                                : 1.0,
                                                          ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.delete,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                  },
                ),
              ),
              // Alt padding overflow önlemek için
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmployeeManagementTab() {
    return Column(
      children: [
        // Çalışan Yönetimi Kartı
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _isDarkMode
                ? SiriusColors.surface
                : Colors.black.withValues(
                    alpha: 0.3,
                  ), // Açık modda transparan siyah
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 600;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SiriusColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.people,
                            color: SiriusColors.accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Çalışan Yönetimi',
                                style: TextStyle(
                                  color: SiriusColors.heading,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Ad, Soyad ve İşlemler',
                                style: TextStyle(
                                  color: SiriusColors.defaultText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddEmployeeDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Yeni Çalışan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SiriusColors.accent,
                              foregroundColor: SiriusColors.contrast,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showEmployeeFilterDialog(),
                          icon: const Icon(Icons.filter_list),
                          label: const Text('Filtrele'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SiriusColors.accent,
                            foregroundColor: SiriusColors.contrast,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _fetchEmployees(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Yenile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SiriusColors.surface,
                            foregroundColor: SiriusColors.accent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Çalışan ara (ad, soyad)...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (q) {
                        setState(() {
                          _employeeSearchQuery = q.trim().toLowerCase();
                        });
                      },
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SiriusColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.people,
                      color: SiriusColors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Çalışan Yönetimi',
                          style: TextStyle(
                            color: SiriusColors.heading,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Ad, Soyad ve İşlemler',
                          style: TextStyle(
                            color: SiriusColors.defaultText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEmployeeDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni Çalışan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SiriusColors.accent,
                      foregroundColor: SiriusColors.contrast,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showEmployeeFilterDialog(),
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Filtrele'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SiriusColors.accent,
                      foregroundColor: SiriusColors.contrast,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _fetchEmployees(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Yenile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SiriusColors.surface,
                      foregroundColor: SiriusColors.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoadingEmployees
              ? Center(
                  child: CircularProgressIndicator(color: SiriusColors.accent),
                )
              : _allEmployees.isEmpty
              ? const Center(
                  child: Text(
                    'Henüz çalışan bulunmamaktadır.',
                    style: TextStyle(
                      color: SiriusColors.defaultText,
                      fontSize: 16,
                    ),
                  ),
                )
              : Builder(
                  builder: (context) {
                    List<Employee> filtered = List.of(_allEmployees);
                    if (_employeeSearchQuery.isNotEmpty) {
                      filtered = filtered.where((e) {
                        final name = e.fullName.toLowerCase();
                        final exp = (e.expertise).toLowerCase();
                        return name.contains(_employeeSearchQuery) ||
                            exp.contains(_employeeSearchQuery);
                      }).toList();
                    }
                    if (_employeeOnlyActive) {
                      filtered = filtered
                          .where((e) => e.isActive == true)
                          .toList();
                    }
                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          'Filtrenize uygun çalışan bulunamadı.',
                          style: TextStyle(
                            color: SiriusColors.defaultText,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final employee = filtered[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: _isDarkMode
                              ? SiriusColors.surface
                              : Colors.black.withValues(
                                  alpha: 0.3,
                                ), // Açık modda transparan siyah
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: SiriusColors.accent,
                              child: Text(
                                employee.firstName[0],
                                style: const TextStyle(
                                  color: SiriusColors.contrast,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              employee.fullName,
                              style: const TextStyle(
                                color: SiriusColors.heading,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Uzmanlık: ${employee.expertise}',
                                  style: const TextStyle(
                                    color: SiriusColors.defaultText,
                                  ),
                                ),
                                Text(
                                  'Beceriler: ${employee.skills}',
                                  style: const TextStyle(
                                    color: SiriusColors.defaultText,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Düzenleme butonu
                                IconButton(
                                  onPressed: () =>
                                      _showEditEmployeeDialog(employee),
                                  icon: Icon(
                                    Icons.edit,
                                    color: SiriusColors.accent,
                                    size: 20,
                                  ),
                                  tooltip: 'Düzenle',
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                                // Silme butonu
                                IconButton(
                                  onPressed: () =>
                                      _showDeleteEmployeeDialog(employee.id!),
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  tooltip: 'Sil',
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: false,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPerformanceAnalysis() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 12 : 16,
          ),
          color: _isDarkMode
              ? Colors.black
              : Colors.black.withValues(alpha: 0.3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 500;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Çalışan Performans Analizi',
                      style: TextStyle(
                        color: SiriusColors.heading,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tarih: ${_formatDate(DateTime.now())}',
                      style: const TextStyle(
                        color: SiriusColors.defaultText,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            _fetchEmployeePerformance();
                          },
                          icon: Icon(
                            Icons.refresh,
                            color: SiriusColors.accent,
                            size: 20,
                          ),
                          tooltip: 'Performans Verilerini Yenile',
                        ),
                        Text(
                          'Yenile',
                          style: TextStyle(
                            color: SiriusColors.accent,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            _fetchEmployees();
                          },
                          icon: Icon(
                            Icons.people,
                            color: Colors.blue,
                            size: 20,
                          ),
                          tooltip: 'Çalışanları Yenile',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            _initializeData();
                          },
                          icon: Icon(Icons.sync, color: Colors.green, size: 20),
                          tooltip: 'Tüm Verileri Yenile',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isDebugMode = !_isDebugMode;
                            });
                          },
                          icon: Icon(
                            _isDebugMode
                                ? Icons.bug_report
                                : Icons.bug_report_outlined,
                            color: _isDebugMode ? Colors.red : Colors.grey,
                            size: 20,
                          ),
                          tooltip:
                              'Debug Modu: ${_isDebugMode ? 'Açık' : 'Kapalı'}',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Detaylı log konsola yazıldı'),
                                backgroundColor: Colors.blue,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.list_alt,
                            color: Colors.purple,
                            size: 20,
                          ),
                          tooltip: 'Detaylı Log',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Hata ayıklama tamamlandı'),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.build,
                            color: Colors.orange,
                            size: 20,
                          ),
                          tooltip: 'Hata Ayıklama',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            if (_allEmployees.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Önce çalışanları yükleyin'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            _showManualDataEntryDialog();
                          },
                          icon: Icon(
                            Icons.add_circle,
                            color: Colors.teal,
                            size: 20,
                          ),
                          tooltip: 'Manuel Veri Ekle',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text(
                                  'Performans Verilerini Temizle',
                                ),
                                content: const Text(
                                  'Tüm performans verilerini silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('İptal'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _employeePerformance.clear();
                                      });
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Performans verileri temizlendi',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Temizle'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.clear_all,
                            color: Colors.red,
                            size: 20,
                          ),
                          tooltip: 'Verileri Temizle',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text(
                                  'Çalışan Performans Analizi Yardım',
                                ),
                                content: const SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Bu ekran çalışanların performans verilerini gösterir:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '• Çalışan sayısı: Sistemdeki aktif çalışan sayısı',
                                      ),
                                      Text(
                                        '• Performans verisi: Çalışanların günlük performans bilgileri',
                                      ),
                                      Text(
                                        '• Toplam kazanç: Tüm çalışanların günlük kazanç toplamı',
                                      ),
                                      Text(
                                        '• Ortalama verimlilik: Çalışanların ortalama verimlilik yüzdesi',
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Eğer sadece bir çalışan görünüyorsa:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '• Çalışanları yenile butonuna tıklayın',
                                      ),
                                      Text(
                                        '• Tüm verileri yenile butonuna tıklayın',
                                      ),
                                      Text(
                                        '• Debug modunu açın ve hata ayıklama yapın',
                                      ),
                                      Text(
                                        '• Test verisi oluştur butonunu kullanın',
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Tamam'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.help,
                            color: Colors.indigo,
                            size: 20,
                          ),
                          tooltip: 'Yardım',
                        ),
                        Text(
                          'Çalışanlar',
                          style: TextStyle(color: Colors.blue, fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            _initializeData();
                          },
                          icon: Icon(Icons.sync, color: Colors.green, size: 20),
                          tooltip: 'Tüm Verileri Yenile',
                        ),
                        Text(
                          'Tümü',
                          style: TextStyle(color: Colors.green, fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Detaylı log konsola yazıldı'),
                                backgroundColor: Colors.blue,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.list_alt,
                            color: Colors.purple,
                            size: 20,
                          ),
                          tooltip: 'Detaylı Log',
                        ),
                        Text(
                          'Log',
                          style: TextStyle(color: Colors.purple, fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Hata ayıklama tamamlandı'),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.build,
                            color: Colors.orange,
                            size: 20,
                          ),
                          tooltip: 'Hata Ayıklama',
                        ),
                        Text(
                          'Hata',
                          style: TextStyle(color: Colors.orange, fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            if (_allEmployees.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Önce çalışanları yükleyin'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            _showManualDataEntryDialog();
                          },
                          icon: Icon(
                            Icons.add_circle,
                            color: Colors.teal,
                            size: 20,
                          ),
                          tooltip: 'Manuel Veri Ekle',
                        ),
                        Text(
                          'Veri',
                          style: TextStyle(color: Colors.teal, fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text(
                                  'Performans Verilerini Temizle',
                                ),
                                content: const Text(
                                  'Tüm performans verilerini silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('İptal'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _employeePerformance.clear();
                                      });
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Performans verileri temizlendi',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Temizle'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.clear_all,
                            color: Colors.red,
                            size: 20,
                          ),
                          tooltip: 'Verileri Temizle',
                        ),
                        Text(
                          'Temizle',
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text(
                                  'Çalışan Performans Analizi Yardım',
                                ),
                                content: const SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Bu ekran çalışanların performans verilerini gösterir:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '• Çalışan sayısı: Sistemdeki aktif çalışan sayısı',
                                      ),
                                      Text(
                                        '• Performans verisi: Çalışanların günlük performans bilgileri',
                                      ),
                                      Text(
                                        '• Toplam kazanç: Tüm çalışanların günlük kazanç toplamı',
                                      ),
                                      Text(
                                        '• Ortalama verimlilik: Çalışanların ortalama verimlilik yüzdesi',
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Eğer sadece bir çalışan görünüyorsa:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '• Çalışanları yenile butonuna tıklayın',
                                      ),
                                      Text(
                                        '• Tüm verileri yenile butonuna tıklayın',
                                      ),
                                      Text(
                                        '• Debug modunu açın ve hata ayıklama yapın',
                                      ),
                                      Text(
                                        '• Test verisi oluştur butonunu kullanın',
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Tamam'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.help,
                            color: Colors.indigo,
                            size: 20,
                          ),
                          tooltip: 'Yardım',
                        ),
                        Text(
                          'Yardım',
                          style: TextStyle(color: Colors.indigo, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Debug bilgileri
                    if (_isDebugMode)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Debug Bilgileri:',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Çalışan: ${_allEmployees.length}, Performans: ${_employeePerformance.length}, İşletme ID: ${_isletmeId ?? 'Bulunamadı'}',
                              style: TextStyle(
                                color: Colors.blue.withValues(alpha: 0.8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'Çalışan Performans Analizi',
                      style: TextStyle(
                        color: SiriusColors.heading,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Debug sayacı kaldırıldı
                  const SizedBox(width: 16),
                  Text(
                    'Tarih: ${_formatDate(DateTime.now())}',
                    style: const TextStyle(
                      color: SiriusColors.defaultText,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      _fetchEmployeePerformance();
                    },
                    icon: Icon(
                      Icons.refresh,
                      color: SiriusColors.accent,
                      size: 20,
                    ),
                    tooltip: 'Performans Verilerini Yenile',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      _fetchEmployees();
                    },
                    icon: Icon(Icons.people, color: Colors.blue, size: 20),
                    tooltip: 'Çalışanları Yenile',
                  ),
                ],
              );
            },
          ),
        ),
        // Performans özeti kartları (responsive)
        Container(
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 12 : 16,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 700;
              if (isNarrow) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: _buildSummaryCard(
                          'Toplam Çalışan',
                          '${_allEmployees.length}',
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: _buildSummaryCard(
                          'Toplam Kazanç',
                          '₺${_calculateTotalEarnings().toStringAsFixed(2)}',
                          Icons.attach_money,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: _buildSummaryCard(
                          'Ortalama Verimlilik',
                          '${_calculateAverageEfficiency().toStringAsFixed(1)}%',
                          Icons.trending_up,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Toplam Çalışan',
                      '${_allEmployees.length}',
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Toplam Kazanç',
                      '₺${_calculateTotalEarnings().toStringAsFixed(2)}',
                      Icons.attach_money,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Ortalama Verimlilik',
                      '${_calculateAverageEfficiency().toStringAsFixed(1)}%',
                      Icons.trending_up,
                      Colors.orange,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: _isLoadingPerformance
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: SiriusColors.accent),
                      const SizedBox(height: 16),
                      Text(
                        'Performans verileri yükleniyor...',
                        style: TextStyle(
                          color: SiriusColors.defaultText,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : _employeePerformance.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 64,
                        color: SiriusColors.defaultText.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Performans verisi bulunamadı',
                        style: TextStyle(
                          color: SiriusColors.defaultText,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Çalışan sayısı: ${_allEmployees.length}',
                        style: TextStyle(
                          color: SiriusColors.defaultText.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'İşletme ID: ${_isletmeId ?? 'Bulunamadı'}',
                        style: TextStyle(
                          color: SiriusColors.defaultText.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              _fetchEmployeePerformance();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SiriusColors.accent,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Yenile'),
                          ),
                          const SizedBox(width: 16),
                          if (_isDebugMode)
                            OutlinedButton(
                              onPressed: () {
                                _createTestPerformanceData();
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.orange),
                                foregroundColor: Colors.orange,
                              ),
                              child: const Text('Test Verisi'),
                            ),
                        ],
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _employeePerformance.length,
                  itemBuilder: (context, index) {
                    final performance = _employeePerformance[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: _isDarkMode
                          ? SiriusColors.surface
                          : Colors.black.withValues(alpha: 0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    performance.employeeName,
                                    style: const TextStyle(
                                      color: SiriusColors.heading,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SiriusColors.accent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '₺${performance.dailyEarnings.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: SiriusColors.contrast,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPerformanceMetric(
                                    'Verimlilik',
                                    '${performance.efficiency.toStringAsFixed(1)}%',
                                    Icons.trending_up,
                                    _getEfficiencyColor(performance.efficiency),
                                  ),
                                ),
                                Expanded(
                                  child: _buildPerformanceMetric(
                                    'Tamamlanan',
                                    '${performance.appointmentsCompleted}',
                                    Icons.check_circle,
                                    Colors.green,
                                  ),
                                ),
                                Expanded(
                                  child: _buildPerformanceMetric(
                                    'Bekleyen',
                                    '${performance.pendingAppointments}',
                                    Icons.timelapse,
                                    Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Detaylı performans bilgileri
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isDarkMode
                                    ? SiriusColors.background
                                    : Colors.black.withValues(
                                        alpha: 0.2,
                                      ), // Açık modda daha açık transparan siyah
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDetailMetric(
                                          'Saatlik Kazanç',
                                          '₺${(performance.dailyEarnings / 8).toStringAsFixed(2)}',
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDetailMetric(
                                          'Randevu Başına',
                                          '₺${performance.appointmentsCompleted > 0 ? (performance.dailyEarnings / performance.appointmentsCompleted).toStringAsFixed(2) : '0.00'}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: performance.efficiency / 100,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getEfficiencyColor(
                                        performance.efficiency,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Verimlilik: ${performance.efficiency.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: SiriusColors.defaultText,
                                      fontSize: 12,
                                    ),
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
        ),
      ],
    );
  }

  Widget _buildPerformanceMetric(
    String label,
    String value,
    IconData icon,
    Color? color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color ?? SiriusColors.accent, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: SiriusColors.heading,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: SiriusColors.defaultText, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDetailMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: SiriusColors.heading,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: SiriusColors.defaultText, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      color: SiriusColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: SiriusColors.heading,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: SiriusColors.defaultText,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _isDarkMode
            ? Colors.grey[900]!.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width < 600
              ? double.infinity
              : 500,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık ve kapatma butonu
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.grey[800] : Colors.blue[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Yeni Çalışan Ekle',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.red[600], size: 24),
                      tooltip: 'Kapat',
                    ),
                  ],
                ),
              ),
              // İçerik
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: (() async {
                      try {
                        await _ensureIsletmeId();
                        if (_isletmeId == null) return <Map<String, dynamic>>[];
                        final client = Supabase.instance.client;
                        final rows = await client
                            .from('menu_hizmet_icerigi')
                            .select('kategori, hizmet, aktif')
                            .eq('isletme_id', _isletmeId!)
                            .eq('aktif', true)
                            .order('kategori', ascending: true)
                            .order('hizmet', ascending: true);
                        return (rows as List).cast<Map<String, dynamic>>();
                      } catch (_) {
                        return <Map<String, dynamic>>[];
                      }
                    })(),
                    builder: (context, snapshot) {
                      final data = snapshot.data ?? [];
                      final Map<String, List<String>> categoryToServices = {};
                      for (final m in data) {
                        final cat = (m['kategori'] ?? 'Genel').toString();
                        final svc = (m['hizmet'] ?? '').toString();
                        if (svc.isEmpty) continue;
                        categoryToServices.putIfAbsent(cat, () => []);
                        if (!categoryToServices[cat]!.contains(svc)) {
                          categoryToServices[cat]!.add(svc);
                        }
                      }

                      final categories = categoryToServices.keys.toList()
                        ..sort();
                      String? localSelectedCategory = categories.isNotEmpty
                          ? categories.first
                          : null;
                      String? localSelectedService =
                          (localSelectedCategory != null &&
                              categoryToServices[localSelectedCategory]!
                                  .isNotEmpty)
                          ? categoryToServices[localSelectedCategory]!.first
                          : null;

                      return StatefulBuilder(
                        builder: (context, setLocalState) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Üst başlık şeridi
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: _isDarkMode
                                      ? Colors.blueGrey[800]!
                                      : Colors.blue[50]!,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _isDarkMode
                                        ? Colors.blueGrey[600]!
                                        : Colors.blue[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Yeni Çalışan Bilgilerini Lütfen Girin',
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white
                                        : Colors.blue[800]!,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              TextField(
                                controller: _firstNameController,
                                decoration: InputDecoration(
                                  labelText: 'Ad *',
                                  hintText: 'Çalışanın adı',
                                  border: const OutlineInputBorder(),
                                  labelStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  hintStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'E-posta *',
                                  hintText: 'ornek@firma.com',
                                  border: const OutlineInputBorder(),
                                  labelStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  hintStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Telefon *',
                                  hintText: '+90 5XX XXX XX XX',
                                  border: const OutlineInputBorder(),
                                  labelStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  hintStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _lastNameController,
                                decoration: InputDecoration(
                                  labelText: 'Soyad *',
                                  hintText: 'Çalışanın soyadı',
                                  border: const OutlineInputBorder(),
                                  labelStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  hintStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Beceriler alanı hizmet seçiminden sonra gösterilecek
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting)
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: LinearProgressIndicator(),
                                )
                              else if (categoryToServices.isNotEmpty) ...[
                                DropdownButtonFormField<String>(
                                  initialValue: localSelectedCategory,
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  dropdownColor: _isDarkMode
                                      ? Colors.grey[850]
                                      : Colors.white,
                                  decoration: InputDecoration(
                                    labelText: 'Kategori *',
                                    hintText: 'Kategori seçin',
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: categories
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              c,
                                              style: TextStyle(
                                                color: _isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setLocalState(() {
                                      localSelectedCategory = value;
                                      final services = value != null
                                          ? categoryToServices[value] ?? []
                                          : <String>[];
                                      localSelectedService = services.isNotEmpty
                                          ? services.first
                                          : null;
                                      _selectedService =
                                          localSelectedService; // store chosen service
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: localSelectedService,
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  dropdownColor: _isDarkMode
                                      ? Colors.grey[850]
                                      : Colors.white,
                                  decoration: InputDecoration(
                                    labelText: 'Hizmet *',
                                    hintText: 'Hizmet seçin',
                                    border: const OutlineInputBorder(),
                                  ),
                                  items:
                                      (localSelectedCategory != null
                                              ? (categoryToServices[localSelectedCategory!] ??
                                                    [])
                                              : <String>[])
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                    ),
                                                child: Text(
                                                  s,
                                                  style: TextStyle(
                                                    color: _isDarkMode
                                                        ? Colors.white
                                                        : Colors.black87,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) {
                                    setLocalState(() {
                                      localSelectedService = value;
                                      _selectedService = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _skillsController,
                                  decoration: InputDecoration(
                                    labelText: 'Beceriler *',
                                    hintText: 'Örn: Boya, Kesim, Fön',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: _isDarkMode
                                        ? Colors.black26
                                        : Colors.white,
                                    prefixIcon: const Icon(Icons.handyman),
                                    labelStyle: TextStyle(
                                      color: _isDarkMode
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                    hintStyle: TextStyle(
                                      color: _isDarkMode
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ] else ...[
                                // Fallback: eski uzmanlık alanı seçimi
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedService,
                                  decoration: const InputDecoration(
                                    labelText: 'Uzmanlık Alanı *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Genel',
                                      child: Text('Genel'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setLocalState(() {
                                      _selectedService = value;
                                    });
                                  },
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              // Alt butonlar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.grey[800] : Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'İptal',
                          style: TextStyle(
                            color: _isDarkMode
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _addEmployee,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Ekle'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Çalışan düzenleme dialog'u
  void _showEditEmployeeDialog(Employee employee) async {
    try {
      // Önce güncel çalışan verilerini Supabase'den yükle
      await _ensureIsletmeId();
      if (_isletmeId == null) {
        throw Exception('İşletme ID bulunamadı');
      }

      if (employee.id == null) {
        throw Exception('Çalışan ID bulunamadı');
      }

      final client = Supabase.instance.client;
      final updatedEmployeeData = await client
          .from('calisanlar')
          .select()
          .eq('id', employee.id!)
          .eq('isletme_id', _isletmeId!)
          .single();

      // Güncel verileri controller'lara yükle
      _firstNameController.text = (updatedEmployeeData['ad'] ?? '').toString();
      _lastNameController.text = (updatedEmployeeData['soyad'] ?? '')
          .toString();
      _skillsController.text = (updatedEmployeeData['beceriler'] ?? '')
          .toString();
      _selectedService = (updatedEmployeeData['uzmanlik'] ?? 'Genel')
          .toString();
    } catch (e) {
      // Hata durumunda mevcut veriyi kullan
      _firstNameController.text = employee.firstName;
      _lastNameController.text = employee.lastName;
      _skillsController.text = employee.skills;
      _selectedService = employee.expertise;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çalışan verileri güncellenirken hata: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Çalışan Düzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'Ad',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(
                    color: _isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Soyad',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(
                    color: _isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _skillsController,
                decoration: InputDecoration(
                  labelText: 'Beceriler',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(
                    color: _isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedService,
                decoration: const InputDecoration(
                  labelText: 'Uzmanlık Alanı',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Saç', child: Text('Saç')),
                  DropdownMenuItem(value: 'Makyaj', child: Text('Makyaj')),
                  DropdownMenuItem(
                    value: 'Cilt Bakımı',
                    child: Text('Cilt Bakımı'),
                  ),
                  DropdownMenuItem(
                    value: 'Manikür/Pedikür',
                    child: Text('Manikür/Pedikür'),
                  ),
                  DropdownMenuItem(value: 'Masaj', child: Text('Masaj')),
                  DropdownMenuItem(value: 'Lazer', child: Text('Lazer')),
                  DropdownMenuItem(value: 'Genel', child: Text('Genel')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedService = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (mounted) Navigator.pop(context);
              },
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedEmployee = Employee(
                  id: employee.id,
                  firstName: _firstNameController.text,
                  lastName: _lastNameController.text,
                  skills: _skillsController.text,
                  expertise: _selectedService ?? 'Genel',
                  phone: employee.phone,
                  email: employee.email,
                  isActive: employee.isActive,
                  hireDate: employee.hireDate,
                  profileImage: employee.profileImage,
                );
                _updateEmployee(updatedEmployee);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SiriusColors.accent,
                foregroundColor: SiriusColors.contrast,
              ),
              child: const Text('Güncelle'),
            ),
          ],
        ),
      );
    }
  }

  // Çalışan silme onay dialog'u
  void _showDeleteEmployeeDialog(int employeeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çalışan Sil'),
        content: const Text('Bu çalışanı silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEmployee(employeeId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
          title: Text(
            'Randevu Filtrele',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filtreleme özelliği yakında eklenecek!',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Tamam',
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Çalışan filtreleme dialog'u
  void _showEmployeeFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
          title: Text(
            'Çalışan Filtrele',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Çalışan filtreleme özelliği yakında eklenecek!',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Tamam',
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Son 30 günün başlangıç ve bitiş zamanlarını al (sistem saati yanlış olabilir)
  (DateTime, DateTime) _todayRange() {
    final now = DateTime.now();

    // Son 30 günün başlangıcı ve sonu (sistem saati yanlış olsa bile veri bulabiliriz)
    final start = DateTime.utc(now.year, now.month, now.day - 30, 0, 0, 0);
    final end = DateTime.utc(now.year, now.month, now.day, 23, 59, 59, 999);

    return (start, end);
  }

  // Supabase'den günlük özet sayılarını çek
  Future<void> _fetchTodaySummary() async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) {
        return;
      }

      final (start, end) = _todayRange();
      final client = Supabase.instance.client;

      // Toplam randevu sayısı
      final totalResp = await client
          .from('randevu')
          .select('randevu_id')
          .eq('isletme_id', _isletmeId!)
          .gte('appointment_datetime', start.toIso8601String())
          .lte('appointment_datetime', end.toIso8601String());

      final int total = (totalResp as List).length;

      // Bekleyen randevu sayısı (Pending)
      final pendingResp = await client
          .from('randevu')
          .select('randevu_id')
          .eq('isletme_id', _isletmeId!)
          .eq('approval_status', 'Pending')
          .gte('appointment_datetime', start.toIso8601String())
          .lte('appointment_datetime', end.toIso8601String());
      final int pending = (pendingResp as List).length;

      // Tamamlanan randevu sayısı (Approved)
      final completedResp = await client
          .from('randevu')
          .select('randevu_id')
          .eq('isletme_id', _isletmeId!)
          .eq('approval_status', 'Approved')
          .gte('appointment_datetime', start.toIso8601String())
          .lte('appointment_datetime', end.toIso8601String());
      final int completed = (completedResp as List).length;

      // Test için son 7 günün toplam randevu sayısını da göster
      final lastWeekStart = DateTime.utc(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day - 7,
        0,
        0,
        0,
      );
      final lastWeekResp = await client
          .from('randevu')
          .select('randevu_id')
          .eq('isletme_id', _isletmeId!)
          .gte('appointment_datetime', lastWeekStart.toIso8601String())
          .lte('appointment_datetime', end.toIso8601String());

      // ignore: unused_local_variable
      final int lastWeekTotal = (lastWeekResp as List).length;

      if (!mounted) return;
      setState(() {
        _todayTotalAppointments = total;
        _todayPendingAppointments = pending;
        _todayCompletedAppointments = completed;
      });
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Geçmiş tarihli ve onaylı randevular için görüntü metni
  String _getDisplayStatusForAppointment(Appointment appt) {
    if (appt.approvalStatus.toLowerCase() == 'approved' &&
        appt.appointmentDateTime.isBefore(DateTime.now())) {
      return 'Tamamlandı';
    }
    return _getStatusDisplayText(appt.approvalStatus);
  }

  Color _getEfficiencyColor(double efficiency) {
    if (efficiency >= 80) return Colors.green;
    if (efficiency >= 60) return Colors.orange;
    return Colors.red;
  }

  double _calculateTotalEarnings() {
    // Performans verilerinden toplam kazancı hesapla (tüm zamanlar için)
    double totalFromPerformance = _employeePerformance.fold(
      0.0,
      (sum, p) => sum + p.totalEarnings,
    );

    return totalFromPerformance;
  }

  double _calculateAverageEfficiency() {
    if (_employeePerformance.isEmpty) return 0.0;
    final average =
        _employeePerformance.fold(0.0, (sum, p) => sum + p.efficiency) /
        _employeePerformance.length;
    return average;
  }

  // Manuel veri girişi dialog'u
  void _showManualDataEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manuel Performans Verisi Ekle'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Çalışan Seçin',
                  border: OutlineInputBorder(),
                ),
                initialValue: _allEmployees.isNotEmpty
                    ? _allEmployees.first.fullName
                    : null,
                items: _allEmployees.map((emp) {
                  return DropdownMenuItem(
                    value: emp.fullName,
                    child: Text(emp.fullName),
                  );
                }).toList(),
                onChanged: (value) {
                  // Çalışan seçimi
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Günlük Kazanç (₺)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Verimlilik (%)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Tamamlanan Randevu',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              // Manuel veri ekleme işlemi
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Manuel veri ekleme özelliği geliştiriliyor'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  // Otomatik yenileme timer'ını başlat
  // ignore: unused_element
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _isAutoRefresh) {
        _fetchEmployeePerformance();
        _fetchTodaySummary();
      }
    });
  }

  // Otomatik yenileme timer'ını durdur
  // ignore: unused_element
  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
  }

  // Test performans verisi oluştur
  void _createTestPerformanceData() {
    if (_allEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce çalışanları yükleyin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final testPerformances = _allEmployees.map((employee) {
      final random = employee.id ?? 1;
      return EmployeePerformance(
        employeeName: employee.fullName,
        dailyEarnings: (random * 100.0) + (random * 50.0),
        totalEarnings: (random * 500.0) + (random * 250.0),
        efficiency: (random * 10.0) % 100.0,
        date: DateTime.now(),
        appointmentsCompleted: (random % 10) + 1,
        averageRating: (random % 5) + 1.0,
      );
    }).toList();

    setState(() {
      _employeePerformance = testPerformances;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${testPerformances.length} test performans verisi oluşturuldu',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Admin hoşgeldiniz ekranı
  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        MediaQuery.of(context).size.width < 600 ? 16 : 24,
      ),
      child: Column(
        children: [
          // Ana hoşgeldiniz kartı - Animasyonlu giriş
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 50 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width < 600 ? 24 : 40,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          SiriusColors.accent,
                          SiriusColors.accent.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: SiriusColors.accent.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Profil resmi - Dönen animasyon
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 1200),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, rotationValue, child) {
                            return Transform.rotate(
                              angle: rotationValue * 2 * 3.14159,
                              child: Container(
                                width: MediaQuery.of(context).size.width < 600
                                    ? 80
                                    : 120,
                                height: MediaQuery.of(context).size.width < 600
                                    ? 80
                                    : 120,
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
                                child: Icon(
                                  Icons.admin_panel_settings,
                                  size: MediaQuery.of(context).size.width < 600
                                      ? 40
                                      : 60,
                                  color: SiriusColors.accent,
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.width < 600
                              ? 16
                              : 24,
                        ),

                        // Hoşgeldiniz yazısı - Cormorant font ile
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 1000),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, textValue, child) {
                            return Transform.scale(
                              scale: 0.5 + (textValue * 0.5),
                              child: Opacity(
                                opacity: textValue,
                                child: Text(
                                  'Hoş Geldiniz!',
                                  style: TextStyle(
                                    color: SiriusColors.contrast,
                                    fontSize:
                                        MediaQuery.of(context).size.width < 600
                                        ? 24
                                        : 36,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cormorant',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Alt yazılar - Sırayla görünme
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 1200),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, subtitleValue, child) {
                            return Opacity(
                              opacity: subtitleValue,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - subtitleValue)),
                                child: Column(
                                  children: [
                                    Text(
                                      (_isletme != null &&
                                              (_isletme!['isim'] as String?) !=
                                                  null)
                                          ? ((_isletme!['isim'] as String?) ??
                                                '')
                                          : '',
                                      style: TextStyle(
                                        color: SiriusColors.contrast.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Yönetim Paneli',
                                      style: TextStyle(
                                        color: SiriusColors.contrast.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // Hızlı erişim kartları - Sırayla görünme
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 600;
              if (isNarrow) {
                final double itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1000),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(-30 * (1 - value), 0),
                            child: Opacity(
                              opacity: value,
                              child: _buildQuickAccessCard(
                                'Çalışan ve Randevu İşlemleri',
                                'Randevuları yönetin ve çalışan bilgilerini düzenleyin',
                                Icons.work,
                                () => setState(() => _selectedIndex = 0),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1200),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(30 * (1 - value), 0),
                            child: Opacity(
                              opacity: value,
                              child: _buildQuickAccessCard(
                                'Performans Analizi',
                                'Çalışan performansını takip edin ve analiz edin',
                                Icons.analytics,
                                () => setState(() => _selectedIndex = 1),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1000),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(-50 * (1 - value), 0),
                          child: Opacity(
                            opacity: value,
                            child: _buildQuickAccessCard(
                              'Çalışan ve Randevu İşlemleri',
                              'Randevuları yönetin ve çalışan bilgilerini düzenleyin',
                              Icons.work,
                              () => setState(() => _selectedIndex = 0),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1200),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(50 * (1 - value), 0),
                          child: Opacity(
                            opacity: value,
                            child: _buildQuickAccessCard(
                              'Performans Analizi',
                              'Çalışan performansını takip edin ve analiz edin',
                              Icons.analytics,
                              () => setState(() => _selectedIndex = 1),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // İstatistik kartları - Yukarıdan aşağıya görünme
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1400),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? SiriusColors.surface
                          : Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: SiriusColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Son 30 Gün Özeti',
                          style: TextStyle(
                            color: SiriusColors.heading,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Toplam Randevu',
                                _todayTotalAppointments.toString(),
                                Icons.calendar_today,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                'Bekleyen',
                                _todayPendingAppointments.toString(),
                                Icons.pending,
                                Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                'Tamamlanan',
                                _todayCompletedAppointments.toString(),
                                Icons.check_circle,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Son aktiviteler - En son görünme
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1600),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 40 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? SiriusColors.surface
                          : Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: SiriusColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Son Aktiviteler',
                              style: TextStyle(
                                color: SiriusColors.heading,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    setState(() {});
                                  },
                                  icon: Icon(
                                    Icons.refresh,
                                    color: Colors.green[600],
                                    size: 22,
                                  ),
                                  tooltip: 'Yenile',
                                ),
                                IconButton(
                                  onPressed: () => _showClearActivitiesDialog(),
                                  icon: Icon(
                                    Icons.delete_sweep,
                                    color: Colors.red[600],
                                    size: 24,
                                  ),
                                  tooltip: 'Geçmiş Aktiviteleri Sil',
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _loadRecentActivities(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Text(
                                'Aktiviteler yüklenemedi',
                                style: TextStyle(color: Colors.red[300]),
                              );
                            }
                            final items = snapshot.data ?? [];
                            if (items.isEmpty) {
                              return Text(
                                'Son aktivite bulunamadı',
                                style: TextStyle(
                                  color: SiriusColors.defaultText,
                                ),
                              );
                            }
                            return Column(
                              children: [
                                for (int i = 0; i < items.length; i++) ...[
                                  _buildActivityItem(
                                    items[i]['title'] as String,
                                    items[i]['time'] as String,
                                    items[i]['icon'] as IconData,
                                    items[i]['color'] as Color,
                                  ),
                                  if (i < items.length - 1)
                                    const SizedBox(height: 12),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: SiriusColors.heading,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(color: SiriusColors.defaultText, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: SiriusColors.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                time,
                style: TextStyle(color: SiriusColors.defaultText, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _loadRecentActivities() async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return [];
      final client = Supabase.instance.client;
      // Son 15 randevuyu (en güncel) çek
      final resp = await client
          .from('randevu')
          .select(
            'appointment_datetime, approval_status, customerid, calisan_id, musteriler:customerid(firstname, lastname)',
          )
          .eq('isletme_id', _isletmeId!)
          .order('appointment_datetime', ascending: false)
          .limit(15);

      final List<Map<String, dynamic>> activities = [];
      for (final row in (resp as List)) {
        final m = row as Map<String, dynamic>;
        final DateTime dt =
            DateTime.tryParse(
              m['appointment_datetime']?.toString() ?? '',
            )?.toLocal() ??
            DateTime.now();
        final String status = (m['approval_status'] ?? '').toString();
        String? fullName;
        final cust = m['musteriler'] as Map<String, dynamic>?;
        if (cust != null) {
          final first = (cust['firstname'] ?? '').toString();
          final last = (cust['lastname'] ?? '').toString();
          fullName = [first, last].where((p) => p.trim().isNotEmpty).join(' ');
        }
        final String title = _activityTitleFromStatus(status, fullName);
        final IconData icon = _activityIconFromStatus(status);
        final Color color = _activityColorFromStatus(status);
        activities.add({
          'title': title,
          'time': _relativeTime(dt),
          'icon': icon,
          'color': color,
          'ts': dt,
        });
      }

      // Çalışan aktiviteleri: eklenenler (created_at) ve güncellemeler (updated_at)
      final recentCreated = await client
          .from('calisanlar')
          .select('ad, soyad, created_at, aktif')
          .eq('isletme_id', _isletmeId!)
          .order('created_at', ascending: false)
          .limit(10);

      final recentUpdated = await client
          .from('calisanlar')
          .select('ad, soyad, updated_at, aktif')
          .eq('isletme_id', _isletmeId!)
          .order('updated_at', ascending: false)
          .limit(20);

      for (final row in (recentCreated as List)) {
        final m = row as Map<String, dynamic>;
        final String name =
            '${(m['ad'] ?? '').toString()} ${(m['soyad'] ?? '').toString()}'
                .trim();
        final DateTime dt =
            DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now();
        activities.add({
          'title': name.isNotEmpty
              ? 'Çalışan eklendi: $name'
              : 'Çalışan eklendi',
          'time': _relativeTime(dt),
          'icon': Icons.person_add,
          'color': Colors.blue,
          'ts': dt,
        });
      }

      for (final row in (recentUpdated as List)) {
        final m = row as Map<String, dynamic>;
        if (m['updated_at'] == null) continue;
        final String name =
            '${(m['ad'] ?? '').toString()} ${(m['soyad'] ?? '').toString()}'
                .trim();
        final DateTime dt =
            DateTime.tryParse(m['updated_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now();
        final bool aktif = (m['aktif'] as bool?) ?? true;
        final bool isDeactivated = !aktif;
        activities.add({
          'title': name.isNotEmpty
              ? (isDeactivated
                    ? 'Çalışan silindi: $name'
                    : 'Profil bilgileri güncellendi: $name')
              : (isDeactivated
                    ? 'Çalışan silindi'
                    : 'Profil bilgileri güncellendi'),
          'time': _relativeTime(dt),
          'icon': isDeactivated ? Icons.person_remove : Icons.edit,
          'color': isDeactivated ? Colors.red : Colors.orange,
          'ts': dt,
        });
      }

      // En yeni ilk 15 kaydı tarihe göre sırala ve dön
      activities.sort(
        (a, b) => (b['ts'] as DateTime).compareTo(a['ts'] as DateTime),
      );
      final top = activities
          .take(15)
          .map(
            (e) => {
              'title': e['title'],
              'time': e['time'],
              'icon': e['icon'],
              'color': e['color'],
            },
          )
          .toList();
      return top;
    } catch (_) {
      return [];
    }
  }

  String _activityTitleFromStatus(String status, dynamic customerName) {
    final name = (customerName?.toString() ?? '').trim();
    switch (status.toLowerCase()) {
      case 'approved':
      case 'tamamlandı':
      case 'onaylandı':
      case 'completed':
        return name.isNotEmpty
            ? 'Randevu tamamlandı: $name'
            : 'Randevu tamamlandı';
      case 'pending':
        return name.isNotEmpty
            ? 'Yeni randevu beklemede: $name'
            : 'Yeni randevu beklemede';
      case 'canceled':
      case 'iptal':
      case 'iptal edildi':
        return name.isNotEmpty
            ? 'Randevu iptal edildi: $name'
            : 'Randevu iptal edildi';
      default:
        return name.isNotEmpty
            ? 'Randevu güncellendi: $name'
            : 'Randevu güncellendi';
    }
  }

  IconData _activityIconFromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'tamamlandı':
      case 'onaylandı':
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'canceled':
      case 'iptal':
      case 'iptal edildi':
        return Icons.cancel;
      default:
        return Icons.update;
    }
  }

  Color _activityColorFromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'tamamlandı':
      case 'onaylandı':
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'canceled':
      case 'iptal':
      case 'iptal edildi':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _relativeTime(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds} saniye önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 30) return '${diff.inDays} gün önce';
    final int months = (diff.inDays / 30).floor();
    if (months < 12) return '$months ay önce';
    final int years = (months / 12).floor();
    return '$years yıl önce';
  }

  // Admin profil bilgileri dialog'u
  void _showAdminProfileDialog() {
    final currentUser = Supabase.instance.client.auth.currentUser;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _isDarkMode
            ? Colors.grey[900]!.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width < 600
              ? double.infinity
              : 600,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık - Gradient arka plan ile
              Container(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 600 ? 20 : 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isDarkMode
                        ? [Colors.blueGrey[800]!, Colors.blueGrey[700]!]
                        : [Colors.blue[400]!, Colors.blue[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width < 600 ? 12 : 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: MediaQuery.of(context).size.width < 600 ? 20 : 28,
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 600 ? 16 : 20,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profil Bilgileri',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: MediaQuery.of(context).size.width < 600
                                  ? 20
                                  : 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hesap ve İşletme Bilgileri',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: MediaQuery.of(context).size.width < 600
                                  ? 12
                                  : 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white, size: 24),
                      tooltip: 'Kapat',
                    ),
                  ],
                ),
              ),

              // İçerik
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width < 600 ? 16 : 20,
                  ),
                  child: currentUser != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hesap Bilgileri Kategorisi
                            _buildProfileCategoryHeader(
                              'Hesap Bilgileri',
                              Icons.account_circle,
                            ),
                            _buildEditableProfileInfoRow(
                              'E-posta',
                              currentUser.email ?? 'N/A',
                              'email',
                              currentUser.email ?? '',
                            ),
                            _buildPasswordChangeRow(),
                            _buildProfileInfoRow(
                              'Kullanıcı ID',
                              currentUser.id,
                            ),
                            _buildProfileInfoRow(
                              'Oluşturulma Tarihi',
                              DateTime.parse(
                                currentUser.createdAt,
                              ).toLocal().toString().split('.')[0],
                            ),
                            _buildProfileInfoRow(
                              'Son Giriş',
                              DateTime.parse(
                                currentUser.lastSignInAt ??
                                    currentUser.createdAt,
                              ).toLocal().toString().split('.')[0],
                            ),
                            _buildProfileInfoRow(
                              'İşletme ID',
                              _isletmeId ?? 'N/A',
                            ),

                            if (_isletme != null) ...[
                              const SizedBox(height: 20),
                              // İşletme Bilgileri Kategorisi
                              _buildProfileCategoryHeader(
                                'İşletme Bilgileri',
                                Icons.business,
                              ),
                              _buildEditableProfileInfoRow(
                                'İşletme Adı',
                                _isletme!['isim'] ?? 'N/A',
                                'isletme_isim',
                                _isletme!['isim'] ?? '',
                              ),
                              _buildEditableProfileInfoRow(
                                'İşletme Türü',
                                _isletme!['tip'] ?? 'N/A',
                                'isletme_tip',
                                _isletme!['tip'] ?? '',
                              ),
                              _buildEditableProfileInfoRow(
                                'Açıklama',
                                _isletme!['aciklama'] ?? 'N/A',
                                'isletme_aciklama',
                                _isletme!['aciklama'] ?? '',
                              ),

                              const SizedBox(height: 20),
                              // İletişim Bilgileri Kategorisi
                              _buildProfileCategoryHeader(
                                'İletişim Bilgileri',
                                Icons.contact_phone,
                              ),
                              _buildEditableProfileInfoRow(
                                'Telefon',
                                _isletme!['telefon'] ?? 'N/A',
                                'isletme_telefon',
                                _isletme!['telefon'] ?? '',
                              ),
                              _buildEditableProfileInfoRow(
                                'E-posta',
                                _isletme!['email'] ?? 'N/A',
                                'isletme_email',
                                _isletme!['email'] ?? '',
                              ),
                              _buildEditableProfileInfoRow(
                                'Web Sitesi',
                                _isletme!['web_site'] ?? 'N/A',
                                'isletme_web_site',
                                _isletme!['web_site'] ?? '',
                              ),

                              const SizedBox(height: 20),
                              // Adres Bilgileri Kategorisi
                              _buildProfileCategoryHeader(
                                'Adres Bilgileri',
                                Icons.location_on,
                              ),
                              _buildEditableProfileInfoRow(
                                'Adres',
                                _isletme!['adres'] ?? 'N/A',
                                'isletme_adres',
                                _isletme!['adres'] ?? '',
                              ),
                              _buildEditableProfileInfoRow(
                                'Şehir',
                                _isletme!['sehir'] ?? 'N/A',
                                'isletme_sehir',
                                _isletme!['sehir'] ?? '',
                              ),
                              _buildEditableProfileInfoRow(
                                'İlçe',
                                _isletme!['ilce'] ?? 'N/A',
                                'isletme_ilce',
                                _isletme!['ilce'] ?? '',
                              ),
                              _buildEditableProfileInfoRow(
                                'Posta Kodu',
                                _isletme!['posta_kodu'] ?? 'N/A',
                                'isletme_posta_kodu',
                                _isletme!['posta_kodu'] ?? '',
                              ),

                              const SizedBox(height: 20),
                              // Görsel ve Tema Kategorisi
                              _buildProfileCategoryHeader(
                                'Görsel ve Tema',
                                Icons.palette,
                              ),
                              _buildEditableProfileInfoRow(
                                'Logo URL',
                                _isletme!['logo_url'] ?? 'N/A',
                                'isletme_logo_url',
                                _isletme!['logo_url'] ?? '',
                              ),
                              _buildEditableProfileInfoRow(
                                'Banner URL',
                                _isletme!['banner_url'] ?? 'N/A',
                                'isletme_banner_url',
                                _isletme!['banner_url'] ?? '',
                              ),
                              _buildEditableProfileInfoRow(
                                'Arka Plan URL',
                                _isletme!['arka_plan_url'] ?? 'N/A',
                                'isletme_arka_plan_url',
                                _isletme!['arka_plan_url'] ?? '',
                              ),
                              _buildEditableProfileInfoRow(
                                'Tema Rengi',
                                _isletme!['tema_rengi'] ?? 'N/A',
                                'isletme_tema_rengi',
                                _isletme!['tema_rengi'] ?? '',
                              ),
                              _buildEditableProfileInfoRow(
                                'Para Birimi',
                                _isletme!['currency'] ?? '₺',
                                'isletme_currency',
                                _isletme!['currency'] ?? '₺',
                              ),
                            ],
                          ],
                        )
                      : Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: _isDarkMode
                                  ? Colors.red[300]
                                  : Colors.red[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Kullanıcı bilgileri yüklenemedi.',
                              style: TextStyle(
                                color: _isDarkMode
                                    ? Colors.white70
                                    : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lütfen tekrar deneyin veya sayfayı yenileyin.',
                              style: TextStyle(
                                color: _isDarkMode
                                    ? Colors.white54
                                    : Colors.black54,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                ),
              ),

              // Butonlar
              Container(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 600 ? 16 : 20,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showEditProfileDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SiriusColors.accent,
                          foregroundColor: SiriusColors.contrast,
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width < 600
                                ? 12
                                : 16,
                            vertical: MediaQuery.of(context).size.width < 600
                                ? 12
                                : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit,
                              size: MediaQuery.of(context).size.width < 600
                                  ? 16
                                  : 20,
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width < 600
                                  ? 8
                                  : 12,
                            ),
                            Text(
                              'Düzenle',
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width < 600
                                    ? 14
                                    : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 600 ? 12 : 16,
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width < 600
                                ? 12
                                : 16,
                            vertical: MediaQuery.of(context).size.width < 600
                                ? 12
                                : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Kapat',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 600
                                ? 14
                                : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Profil kategori başlığı widget'ı
  Widget _buildProfileCategoryHeader(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDarkMode
              ? [
                  Colors.blueGrey[700]!.withValues(alpha: 0.3),
                  Colors.blueGrey[600]!.withValues(alpha: 0.2),
                ]
              : [Colors.blue[100]!, Colors.blue[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode
              ? Colors.blueGrey[600]!.withValues(alpha: 0.5)
              : Colors.blue[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.blue[600] : Colors.blue[500],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.blue[800],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Profil bilgisi satırı widget'ı
  Widget _buildProfileInfoRow(String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 400;

        return Container(
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.width < 600 ? 12 : 16,
          ),
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.grey[800]! : Colors.grey[50]!,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
            ),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: _isDarkMode
                            ? Colors.grey[300]!
                            : Colors.grey[600]!,
                        fontSize: MediaQuery.of(context).size.width < 600
                            ? 12
                            : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.width < 600 ? 4 : 8,
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black87,
                        fontSize: MediaQuery.of(context).size.width < 600
                            ? 14
                            : 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 600 ? 80 : 100,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: _isDarkMode
                              ? Colors.grey[300]!
                              : Colors.grey[600]!,
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 12
                              : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 14
                              : 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // Profil düzenleme dialog'u
  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width < 600
              ? double.infinity
              : 500,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Container(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 600 ? 16 : 20,
                ),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.grey[800] : Colors.blue[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width < 600 ? 8 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? Colors.blue[700]
                            : Colors.blue[600],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: MediaQuery.of(context).size.width < 600 ? 18 : 24,
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 600 ? 12 : 16,
                    ),
                    Expanded(
                      child: Text(
                        'Profil Düzenle',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 18
                              : 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // İçerik
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width < 600 ? 16 : 20,
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'Ad',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(
                            Icons.person,
                            size: MediaQuery.of(context).size.width < 600
                                ? 18
                                : 24,
                          ),
                          labelStyle: TextStyle(
                            color: _isDarkMode
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 14
                              : 16,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.width < 600
                            ? 12
                            : 16,
                      ),
                      TextField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Soyad',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(
                            Icons.person,
                            size: MediaQuery.of(context).size.width < 600
                                ? 18
                                : 18,
                          ),
                          labelStyle: TextStyle(
                            color: _isDarkMode
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 14
                              : 16,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Butonlar
              Container(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 600 ? 16 : 20,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Profil güncelleme işlemi burada yapılacak
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SiriusColors.accent,
                          foregroundColor: SiriusColors.contrast,
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width < 600
                                ? 12
                                : 16,
                            vertical: MediaQuery.of(context).size.width < 600
                                ? 12
                                : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Kaydet',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 600
                                ? 14
                                : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 600 ? 12 : 16,
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width < 600
                                ? 12
                                : 16,
                            vertical: MediaQuery.of(context).size.width < 600
                                ? 12
                                : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'İptal',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 600
                                ? 14
                                : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Düzenlenebilir profil bilgisi satırı widget'ı
  Widget _buildEditableProfileInfoRow(
    String label,
    String value,
    String fieldType,
    String currentValue,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 400;

        return Container(
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.width < 600 ? 12 : 16,
          ),
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.grey[800]! : Colors.grey[50]!,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
            ),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: _isDarkMode
                                  ? Colors.grey[300]!
                                  : Colors.grey[600]!,
                              fontSize: MediaQuery.of(context).size.width < 600
                                  ? 12
                                  : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showEditFieldDialog(
                            fieldType,
                            currentValue,
                            label,
                          ),
                          icon: Icon(
                            Icons.edit,
                            color: SiriusColors.accent,
                            size: MediaQuery.of(context).size.width < 600
                                ? 16
                                : 20,
                          ),
                          padding: EdgeInsets.all(4),
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width < 600
                                ? 32
                                : 40,
                            minHeight: MediaQuery.of(context).size.width < 600
                                ? 32
                                : 40,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.width < 600 ? 4 : 8,
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black87,
                        fontSize: MediaQuery.of(context).size.width < 600
                            ? 14
                            : 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 600 ? 80 : 100,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: _isDarkMode
                              ? Colors.grey[300]!
                              : Colors.grey[600]!,
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 12
                              : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 14
                              : 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          _showEditFieldDialog(fieldType, currentValue, label),
                      icon: Icon(
                        Icons.edit,
                        color: SiriusColors.accent,
                        size: MediaQuery.of(context).size.width < 600 ? 16 : 20,
                      ),
                      padding: EdgeInsets.all(4),
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width < 600
                            ? 32
                            : 40,
                        minHeight: MediaQuery.of(context).size.width < 600
                            ? 32
                            : 40,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // Alan düzenleme dialog'u
  void _showEditFieldDialog(
    String fieldType,
    String currentValue,
    String fieldLabel,
  ) {
    final TextEditingController fieldController = TextEditingController(
      text: currentValue,
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width < 600
              ? double.infinity
              : 400,
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 16 : 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width < 600 ? 8 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: SiriusColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: MediaQuery.of(context).size.width < 600 ? 18 : 24,
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width < 600 ? 12 : 16,
                  ),
                  Expanded(
                    child: Text(
                      '$fieldLabel Düzenle',
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: MediaQuery.of(context).size.width < 600
                            ? 18
                            : 20,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(
                height: MediaQuery.of(context).size.width < 600 ? 16 : 20,
              ),

              // Input alanı
              TextField(
                controller: fieldController,
                cursorColor: _isDarkMode ? Colors.white : Colors.black87,
                decoration: InputDecoration(
                  labelText: fieldLabel,
                  filled: true,
                  fillColor: _isDarkMode ? Colors.grey[850] : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _isDarkMode
                          ? Colors.grey[700]!
                          : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _isDarkMode ? Colors.blue[400]! : Colors.blue,
                      width: 1.5,
                    ),
                  ),
                  prefixIcon: Icon(
                    _getFieldIcon(fieldType),
                    color: _isDarkMode ? Colors.white70 : Colors.black54,
                    size: MediaQuery.of(context).size.width < 600 ? 18 : 24,
                  ),
                  labelStyle: TextStyle(
                    color: _isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ),

              SizedBox(
                height: MediaQuery.of(context).size.width < 600 ? 20 : 24,
              ),

              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _updateProfileField(
                          fieldType,
                          fieldController.text,
                        );
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SiriusColors.accent,
                        foregroundColor: SiriusColors.contrast,
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width < 600
                              ? 12
                              : 16,
                          vertical: MediaQuery.of(context).size.width < 600
                              ? 12
                              : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Güncelle',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 14
                              : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width < 600 ? 12 : 16,
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width < 600
                              ? 12
                              : 16,
                          vertical: MediaQuery.of(context).size.width < 600
                              ? 12
                              : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'İptal',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 14
                              : 16,
                          fontWeight: FontWeight.w500,
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
    );
  }

  // Profil alanını güncelleme
  Future<void> _updateProfileField(String fieldType, String newValue) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      if (fieldType == 'email') {
        // Email güncelleme
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(email: newValue),
        );

        // Email değişikliği için onay gerekebilir
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Email güncellendi. Yeni email adresinizi onaylamanız gerekebilir.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (fieldType == 'firstName') {
        // İsim güncelleme (Supabase metadata'da)
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'first_name': newValue}),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İsim başarıyla güncellendi.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (fieldType == 'lastName') {
        // Soyisim güncelleme (Supabase metadata'da)
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'last_name': newValue}),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Soyisim başarıyla güncellendi.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (fieldType.startsWith('isletme_')) {
        // İşletme bilgilerini güncelleme
        if (_isletmeId != null) {
          final fieldName = fieldType.replaceFirst('isletme_', '');

          final updateData = <String, dynamic>{};
          updateData[fieldName] = newValue;

          await Supabase.instance.client
              .from('isletme')
              .update(updateData)
              .eq('isletme_id', _isletmeId!);

          // Local state'i güncelle
          if (_isletme != null) {
            _isletme![fieldName] = newValue;
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$fieldName başarıyla güncellendi.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // UI'yi yenile
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Güncelleme sırasında hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Randevu silme işlemi
  Future<void> _deleteAppointment(String appointmentId) async {
    try {
      // Lokal numeric ID'den Supabase UUID'ye çevir
      final uuid = _localApptIdToUuid[int.parse(appointmentId)];
      if (uuid == null || uuid.isEmpty) {
        throw Exception('Randevu ID eşlemesi bulunamadı');
      }

      // Supabase'den randevuyu sil
      await Supabase.instance.client
          .from('randevu')
          .delete()
          .eq('randevu_id', uuid);

      // UI'yi yenile
      _fetchAppointments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Randevu başarıyla silindi.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Randevu silinirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Alan tipine göre ikon seçimi
  IconData _getFieldIcon(String fieldType) {
    switch (fieldType) {
      case 'email':
      case 'isletme_email':
        return Icons.email;
      case 'isletme_telefon':
        return Icons.phone;
      case 'isletme_web_site':
        return Icons.web;
      case 'isletme_adres':
      case 'isletme_sehir':
      case 'isletme_ilce':
      case 'isletme_posta_kodu':
        return Icons.location_on;
      case 'isletme_logo_url':
      case 'isletme_banner_url':
      case 'isletme_arka_plan_url':
        return Icons.image;
      case 'isletme_tema_rengi':
      case 'isletme_currency':
        return Icons.palette;
      case 'isletme_tip':
        return Icons.business;
      case 'isletme_aciklama':
        return Icons.description;
      case 'isletme_isim':
        return Icons.store;
      default:
        return Icons.edit;
    }
  }

  // Randevu durumunu değiştir (toggle)
  Future<void> _toggleAppointmentStatus(Appointment appointment) async {
    try {
      String newStatus;
      if (appointment.approvalStatus.toLowerCase() == 'pending') {
        newStatus = 'Approved';
      } else if (appointment.approvalStatus.toLowerCase() == 'approved') {
        newStatus = 'Denied';
      } else {
        newStatus = 'Pending';
      }

      await _updateAppointmentStatus(appointment.appointmentId!, newStatus);

      // UI'yi yenile
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Durum güncellenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Tek randevu silme dialog'u
  void _showDeleteAppointmentDialog(Appointment appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: Colors.orange,
              size: MediaQuery.of(context).size.width < 600 ? 20 : 24,
            ),
            SizedBox(width: MediaQuery.of(context).size.width < 600 ? 8 : 12),
            Expanded(
              child: Text(
                'Randevu Sil',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Bu randevuyu kalıcı olarak silmek istediğinizden emin misiniz?\n\n'
          'Müşteri: ${appointment.customerName}\n'
          'Tarih: ${_formatDateTime(appointment.appointmentDateTime)}\n\n'
          'Bu işlem geri alınamaz!',
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : Colors.black87,
            fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'İptal',
              style: TextStyle(
                color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _deleteAppointment(appointment.appointmentId!.toString());
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Sil',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Toplu silme dialog'u
  void _showBulkDeleteDialog(List<Appointment> appointments) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: Colors.orange,
              size: MediaQuery.of(context).size.width < 600 ? 20 : 24,
            ),
            SizedBox(width: MediaQuery.of(context).size.width < 600 ? 8 : 12),
            Expanded(
              child: Text(
                'Toplu Silme',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Seçili ${appointments.length} randevuyu kalıcı olarak silmek istediğinizden emin misiniz?\n\n'
          'Bu işlem geri alınamaz!',
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : Colors.black87,
            fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'İptal',
              style: TextStyle(
                color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _bulkDeleteAppointments(appointments);
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Toplu Sil',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Toplu randevu silme işlemi
  Future<void> _bulkDeleteAppointments(List<Appointment> appointments) async {
    try {
      // Supabase'den tüm randevuları sil
      for (final appointment in appointments) {
        final uuid = _localApptIdToUuid[appointment.appointmentId!];
        if (uuid != null && uuid.isNotEmpty) {
          await Supabase.instance.client
              .from('randevu')
              .delete()
              .eq('randevu_id', uuid);
        }
      }

      // Seçili randevuları temizle ve UI'yi yenile
      setState(() {
        _selectedAppointments.clear();
      });
      _fetchAppointments();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${appointments.length} randevu başarıyla silindi.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Toplu silme sırasında hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Randevuları yenile
  Future<void> _refreshAppointments() async {
    try {
      // Seçili randevuları temizle
      setState(() {
        _selectedAppointments.clear();
      });

      _fetchAppointments();
      await _fetchTodaySummary();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Randevular yenilendi.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yenileme sırasında hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Şifre değiştirme satırı
  Widget _buildPasswordChangeRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 500;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lock,
                    color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Şifre',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPasswordChangeDialog(),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Şifre Değiştir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Icon(
              Icons.lock,
              color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Şifre',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showPasswordChangeDialog(),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Şifre Değiştir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Şifre değiştirme dialog'u
  void _showPasswordChangeDialog() {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.lock_reset,
              color: Colors.blue,
              size: MediaQuery.of(context).size.width < 600 ? 20 : 24,
            ),
            SizedBox(width: MediaQuery.of(context).size.width < 600 ? 8 : 12),
            Expanded(
              child: Text(
                'Şifre Değiştir',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Mevcut Şifre',
                prefixIcon: Icon(
                  Icons.lock,
                  color: _isDarkMode ? Colors.white70 : Colors.black54,
                ),
                border: const OutlineInputBorder(),
                labelStyle: TextStyle(
                  color: _isDarkMode ? Colors.white70 : Colors.black87,
                ),
                hintStyle: TextStyle(
                  color: _isDarkMode ? Colors.white60 : Colors.black45,
                ),
              ),
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Yeni Şifre',
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: _isDarkMode ? Colors.white70 : Colors.black54,
                ),
                border: const OutlineInputBorder(),
                labelStyle: TextStyle(
                  color: _isDarkMode ? Colors.white70 : Colors.black87,
                ),
                hintStyle: TextStyle(
                  color: _isDarkMode ? Colors.white60 : Colors.black45,
                ),
              ),
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Yeni Şifre (Tekrar)',
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: _isDarkMode ? Colors.white70 : Colors.black54,
                ),
                border: const OutlineInputBorder(),
                labelStyle: TextStyle(
                  color: _isDarkMode ? Colors.white70 : Colors.black87,
                ),
                hintStyle: TextStyle(
                  color: _isDarkMode ? Colors.white60 : Colors.black45,
                ),
              ),
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'İptal',
              style: TextStyle(
                color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Yeni şifreler eşleşmiyor!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Yeni şifre en az 6 karakter olmalıdır!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              await _changePassword(
                currentPasswordController.text,
                newPasswordController.text,
              );
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Şifreyi Değiştir',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Geçmiş aktiviteleri silme dialog'u
  void _showClearActivitiesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.red[600], size: 24),
            const SizedBox(width: 12),
            Text(
              'Geçmiş Aktiviteleri Sil',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Tüm geçmiş aktivite verilerini silmek istediğinizden emin misiniz?\n\nBu işlem geri alınamaz!',
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: TextStyle(
                color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Burada aktivite verilerini temizleme işlemi yapılabilir
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Geçmiş aktiviteler temizlendi'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }

  // Şifre değiştirme işlemi
  Future<void> _changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı bulunamadı');
      }

      // Şifreyi güncelle
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifre başarıyla değiştirildi!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Şifre değiştirilirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Durum için Türkçe çeviri
  String _getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Beklemede';
      case 'approved':
        return 'Onaylandı'; // Geçmiş tarihliyse üstte Tamamlandı gösteriyoruz
      case 'denied':
        return 'Reddedildi';
      default:
        return status; // Bilinmeyen durumlar için orijinal değeri döndür
    }
  }

  // Randevu çakışma kontrolü için yardımcı fonksiyon
  Future<Map<String, dynamic>> _checkAppointmentConflict(
    DateTime appointmentDateTime,
    String employeeName,
    String serviceName,
  ) async {
    try {
      // Çalışan ID'sini bul
      final employee = _allEmployees.firstWhere(
        (emp) => emp.fullName == employeeName,
        orElse: () => throw Exception('Çalışan bulunamadı: $employeeName'),
      );

      if (employee.id == null) {
        return {'error': 'Çalışan ID bulunamadı'};
      }

      // Hizmet ID'sini bul (services tablosundan)
      final serviceId = await _getServiceIdByName(serviceName);
      if (serviceId == null) {
        return {'error': 'Hizmet ID bulunamadı'};
      }

      // Çakışma kontrolü yap
      final conflictDetails = await DbService.getAppointmentConflictDetails(
        appointmentDateTime,
        employee.id!,
        serviceId,
      );

      return conflictDetails;
    } catch (e) {
      return {'error': 'Çakışma kontrolü hatası: $e'};
    }
  }

  // Hizmet adından ID bulma
  Future<int?> _getServiceIdByName(String serviceName) async {
    try {
      // Web platformunda null döndür
      if (kIsWeb) return null;

      final connection = await DbService.connect();
      try {
        final results = await connection.execute(
          'SELECT serviceid FROM services WHERE servicename = @serviceName LIMIT 1',
          parameters: {'serviceName': serviceName},
        );

        if (results.isNotEmpty) {
          return results.first[0] as int;
        }
        return null;
      } finally {
        await connection.close();
      }
    } catch (e) {
      return null;
    }
  }

  // Randevu çakışma uyarısı göster
  void _showConflictWarning(Map<String, dynamic> conflictDetails) {
    if (conflictDetails['hasConflict'] == true) {
      final conflicts = conflictDetails['conflicts'] as List;
      final message = conflictDetails['message'] as String;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Randevu Çakışması'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              SizedBox(height: 16),
              Text(
                'Çakışan Randevular:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ...conflicts.map(
                (conflict) => Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• ${conflict['customerName']} - ${conflict['serviceName']} '
                    '(${conflict['appointmentDateTime']})',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Tamam'),
            ),
          ],
        ),
      );
    }
  }

  void _showLanguageSelectionDialog(BuildContext context, LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: SiriusColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.language,
                color: SiriusColors.accent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                lang.t('change_language'),
                style: TextStyle(
                  color: Colors.white,
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
