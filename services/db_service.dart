// Gerekli paketleri import ediyoruz.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:postgres/postgres.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart'; // TimeOfDay için
import '../models/appointment.dart';
import '../models/customer.dart';
import '../models/service.dart';
import '../models/employee.dart';
import '../models/employee_performance.dart';

// Loglama için bir Logger objesi oluşturuyoruz.
final logger = Logger(level: Level.off);

class DbService {
  // DİKKAT: Gerçek bir uygulamada bu bilgiler KESİNLİKLE buraya yazılmaz.
  // Bu bilgiler bir backend servisi aracılığıyla gizlenmelidir.
  static const String _host = 'localhost';
  static const int _port = 5432;
  static const String _dbName = 'dbhairsalon';
  static const String _username = 'postgres';
  static const String _password = 'Kenan21.';

  // Web platformunda veritabanı bağlantısı yapılamaz
  static bool get _isWebPlatform => kIsWeb;

  // Supabase client getter'ı
  static SupabaseClient get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      logger.e('Supabase client alınamadı', error: e);
      throw StateError('Supabase client başlatılmamış');
    }
  }

  // Veritabanı bağlantısı oluşturan bir yardımcı metot.
  static Future<Connection> _connect() async {
    // Web platformunda çalışıyorsa hata fırlat
    if (_isWebPlatform) {
      throw UnsupportedError(
        'Web platformunda PostgreSQL bağlantısı desteklenmez. Lütfen mobil uygulama kullanın.',
      );
    }

    try {
      final endpoint = Endpoint(
        host: _host,
        port: _port,
        database: _dbName,
        username: _username,
        password: _password,
      );

      // SSL modunu devre dışı bırakarak yerel PostgreSQL sunucusuna bağlan
      final connectionSettings = ConnectionSettings(sslMode: SslMode.disable);

      return await Connection.open(endpoint, settings: connectionSettings);
    } catch (e) {
      logger.e('Veritabanına bağlanılamadı.', error: e);
      rethrow;
    }
  }

  // Public veritabanı bağlantısı metodu (admin ekranı için)
  static Future<Connection> connect() async {
    return await _connect();
  }

  // === AUTHENTICATION İŞLEMLERİ ===

  // Admin girişi kontrolü (PostgreSQL - eski yöntem)
  static Future<bool> isAdmin(String email, String password) async {
    if (_isWebPlatform) {
      logger.w('Web platformunda veritabanı işlemleri desteklenmez.');
      return false;
    }

    Connection? connection;
    try {
      connection = await _connect();

      var results = await connection.execute(
        Sql.named(
          'SELECT adminid FROM admin WHERE username = @email AND password = @password',
        ),
        parameters: {'email': email, 'password': password},
      );

      return results.isNotEmpty;
    } catch (e) {
      logger.e('Admin kontrolü hatası.', error: e);
      return false;
    } finally {
      await connection?.close();
    }
  }

  // Customer girişi kontrolü
  static Future<Customer?> authenticateCustomer(
    String email,
    String password,
  ) async {
    if (_isWebPlatform) {
      logger.w('Web platformunda veritabanı işlemleri desteklenmez.');
      return null;
    }

    Connection? connection;
    try {
      connection = await _connect();

      var results = await connection.execute(
        Sql.named(
          'SELECT customerid, firstname, lastname, email, isactive FROM customer WHERE email = @email AND password = @password AND isactive = true',
        ),
        parameters: {'email': email, 'password': password},
      );

      if (results.isNotEmpty) {
        final row = results.first;
        return Customer(
          customerId: row[0] as int? ?? 0,
          firstName: row[1] as String? ?? '',
          lastName: row[2] as String? ?? '',
          email: row[3] as String? ?? '',
          phone: '', // Veritabanında phone sütunu yok
          address: '', // Veritabanında address sütunu yok
          birthDate: null, // Veritabanında birthdate sütunu yok
          gender: null, // Veritabanında gender sütunu yok
          createdAt: DateTime.now(),
          isActive: row[4] as bool? ?? true,
        );
      }

      return null;
    } catch (e) {
      logger.e('Customer authentication hatası.', error: e);
      return null;
    } finally {
      await connection?.close();
    }
  }

  // === SERVICE İŞLEMLERİ ===

  // Supabase'den hizmetleri getir
  static Future<List<Service>> getServicesFromSupabase(String isletmeId) async {
    try {
      final client = _supabase;

      final rows = await client
          .from('menu_hizmet_icerigi')
          .select(
            'menu_hizmet_icerigi_id, hizmet, fiyat, kategori, aciklama, resim_url, sira, aktif, created_at',
          )
          .eq('isletme_id', isletmeId)
          .eq('aktif', true)
          .order('sira', ascending: true)
          .order('created_at', ascending: true);

      if (rows.isEmpty) {
        logger.w('menu_hizmet_icerigi tablosunda aktif hizmet bulunamadı');
        return [];
      }

      List<Service> services = rows.map((row) {
        return Service(
          serviceId: row['menu_hizmet_icerigi_id'] != null
              ? int.tryParse(
                      row['menu_hizmet_icerigi_id']
                          .toString()
                          .replaceAll('-', '')
                          .substring(0, 8),
                    ) ??
                    0
              : 0,
          serviceName: row['hizmet']?.toString() ?? 'Hizmet',
          serviceDuration: 30, // Varsayılan 30 dakika
          servicePrice: (row['fiyat'] as num?)?.toDouble() ?? 0.0,
          description: row['aciklama']?.toString() ?? '',
          imageUrl: row['resim_url']?.toString() ?? 'assets/services/hair.jpg',
          category: row['kategori']?.toString() ?? 'Genel',
          isActive: row['aktif'] as bool? ?? true,
          createdAt: row['created_at'] != null
              ? DateTime.parse(row['created_at'].toString())
              : DateTime.now(),
          updatedAt: null,
        );
      }).toList();

      logger.i('Supabase\'den ${services.length} hizmet yüklendi');
      return services;
    } catch (e) {
      logger.e('Supabase\'den hizmet yükleme hatası', error: e);
      return [];
    }
  }

  // Supabase'den hizmete göre çalışanları getir
  static Future<List<Employee>> getEmployeesByServiceFromSupabase(
    String isletmeId,
    String serviceName,
  ) async {
    try {
      final client = _supabase;

      final rows = await client
          .from('calisanlar')
          .select(
            'id, ad, soyad, hizmet, uzmanlik, beceriler, resim_url, sira, aktif, created_at',
          )
          .eq('isletme_id', isletmeId)
          .eq('aktif', true)
          .eq('hizmet', serviceName)
          .order('sira', ascending: true)
          .order('created_at', ascending: true);

      if (rows.isEmpty) {
        logger.w('$serviceName hizmeti için aktif çalışan bulunamadı');
        return [];
      }

      List<Employee> employees = rows.map((row) {
        return Employee(
          id: (row['id'] as num?)?.toInt() ?? 0,
          firstName: row['ad']?.toString() ?? '',
          lastName: row['soyad']?.toString() ?? '',
          expertise: row['uzmanlik']?.toString() ?? 'Genel',
          skills: row['beceriler']?.toString() ?? '',
          prolificacy: null,
          dailyEarnings: null,
          serviceId: null,
          email: null,
          phone: null,
          isActive: row['aktif'] as bool? ?? true,
          hireDate: row['created_at'] != null
              ? DateTime.parse(row['created_at'].toString())
              : null,
          profileImage: row['resim_url']?.toString(),
        );
      }).toList();

      logger.i(
        '$serviceName hizmeti için ${employees.length} çalışan yüklendi',
      );
      return employees;
    } catch (e) {
      logger.e('Supabase\'den çalışan yükleme hatası', error: e);
      return [];
    }
  }

  static Future<List<Service>> getServices() async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo veriler döndürülüyor.',
      );
      return _getDemoServices();
    }

    Connection? connection;
    try {
      connection = await _connect();

      var results = await connection.execute(
        'SELECT serviceid, servicename, serviceprice, serviceduration FROM services ORDER BY servicename',
      );

      List<Service> services = results.map((row) {
        // serviceprice String olarak geliyor, double'a çevir
        double price = 0.0;
        try {
          if (row[2] is String) {
            price = double.parse(row[2] as String);
          } else if (row[2] is num) {
            price = (row[2] as num).toDouble();
          }
        } catch (e) {
          logger.w('Service price parse hatası: ${row[2]}');
          price = 0.0;
        }

        return Service(
          serviceId: row[0] as int? ?? 0,
          serviceName: row[1] as String? ?? 'Hizmet',
          serviceDuration: row[3] as int? ?? 30,
          servicePrice: price,
          description: 'Hizmet açıklaması',
          imageUrl: _getServiceImage(row[1] as String? ?? ''),
          category: _getServiceCategory(row[1] as String? ?? ''),
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      return services;
    } catch (e) {
      logger.e('Hizmet listesi çekme hatası.', error: e);
      return _getDemoServices();
    } finally {
      await connection?.close();
    }
  }

  // Hizmet kategorisini belirle
  static String _getServiceCategory(String serviceName) {
    String name = serviceName.toLowerCase();

    if (name.contains('hair') || name.contains('saç')) {
      return 'Saç';
    } else if (name.contains('makeup') || name.contains('makyaj')) {
      return 'Makyaj';
    } else if (name.contains('lash') ||
        name.contains('eyelash') ||
        name.contains('kirpik')) {
      return 'Kirpik';
    } else if (name.contains('nail') ||
        name.contains('manicure') ||
        name.contains('tırnak')) {
      return 'Tırnak';
    } else if (name.contains('laser') || name.contains('lazer')) {
      return 'Lazer';
    } else if (name.contains('eyebrow') ||
        name.contains('microblading') ||
        name.contains('kaş')) {
      return 'Kaş';
    } else if (name.contains('peeling') ||
        name.contains('mask') ||
        name.contains('facial')) {
      return 'Cilt Bakımı';
    } else if (name.contains('massage') || name.contains('masaj')) {
      return 'Masaj';
    } else {
      return 'Genel';
    }
  }

  // Hizmet resmini belirle
  static String _getServiceImage(String serviceName) {
    String name = serviceName.toLowerCase();

    if (name.contains('hair') || name.contains('saç')) {
      return 'assets/services/hair.jpg';
    } else if (name.contains('makeup') || name.contains('makyaj')) {
      return 'assets/services/makeup.jpg';
    } else if (name.contains('lash') ||
        name.contains('eyelash') ||
        name.contains('kirpik')) {
      return 'assets/services/Eyelash.jpg';
    } else if (name.contains('nail') ||
        name.contains('manicure') ||
        name.contains('tırnak')) {
      return 'assets/services/nailart.jpg';
    } else if (name.contains('laser') || name.contains('lazer')) {
      return 'assets/services/laser.jpg';
    } else if (name.contains('eyebrow') ||
        name.contains('microblading') ||
        name.contains('kaş')) {
      return 'assets/services/Microblading.jpg';
    } else if (name.contains('peeling') ||
        name.contains('mask') ||
        name.contains('facial')) {
      return 'assets/services/skincare.jpg';
    } else if (name.contains('massage') || name.contains('masaj')) {
      return 'assets/services/massage.jpg';
    } else {
      return 'assets/services/hair.jpg';
    }
  }

  static Future<List<Service>> getServicesByCategory(String category) async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo veriler döndürülüyor.',
      );
      final allServices = _getDemoServices();
      return allServices
          .where((service) => service.category == category)
          .toList();
    }

    Connection? connection;
    try {
      connection = await _connect();

      var results = await connection.execute(
        Sql.named(
          'SELECT serviceid, servicename, serviceprice, serviceduration FROM services WHERE LOWER(servicename) LIKE @category ORDER BY servicename',
        ),
        parameters: {'category': '%${category.toLowerCase()}%'},
      );

      List<Service> services = results.map((row) {
        // serviceprice String olarak geliyor, double'a çevir
        double price = 0.0;
        try {
          if (row[2] is String) {
            price = double.parse(row[2] as String);
          } else if (row[2] is num) {
            price = (row[2] as num).toDouble();
          }
        } catch (e) {
          logger.w('Service price parse hatası: ${row[2]}');
          price = 0.0;
        }

        return Service(
          serviceId: row[0] as int? ?? 0,
          serviceName: row[1] as String? ?? 'Hizmet',
          serviceDuration: row[3] as int? ?? 30,
          servicePrice: price,
          description: 'Hizmet açıklaması',
          imageUrl: _getServiceImage(row[1] as String? ?? ''),
          category: _getServiceCategory(row[1] as String? ?? ''),
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      return services;
    } catch (e) {
      logger.e('Kategori bazlı hizmet listesi çekme hatası.', error: e);
      return [];
    } finally {
      await connection?.close();
    }
  }

  // === EMPLOYEE İŞLEMLERİ ===

  static Future<List<Employee>> getEmployees() async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo veriler döndürülüyor.',
      );
      return _getDemoEmployees();
    }

    Connection? connection;
    try {
      connection = await _connect();

      var results = await connection.execute(
        'SELECT employeeid, firstname, lastname, expertise, skills, prolificacy, dailyearnings, serviceid FROM employees ORDER BY firstname',
      );

      List<Employee> employees = results.map((row) {
        return Employee(
          id: row[0] as int? ?? 0,
          firstName: row[1] as String? ?? '',
          lastName: row[2] as String? ?? '',
          skills: row[4] as String? ?? '',
          expertise: row[3] as String? ?? 'Genel',
          phone: '',
          email: '',
          isActive: true,
          hireDate: DateTime.now(),
          profileImage: null,
        );
      }).toList();

      return employees;
    } catch (e) {
      logger.e('Çalışan listesi çekme hatası.', error: e);
      return _getDemoEmployees();
    } finally {
      await connection?.close();
    }
  }

  // Yeni çalışan ekleme
  static Future<bool> createEmployee(Employee employee) async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo işlem yapılıyor.',
      );
      return true;
    }

    Connection? connection;
    try {
      connection = await _connect();

      await connection.execute(
        Sql.named(
          'INSERT INTO employees (firstname, lastname, skills, expertise, prolificacy, dailyearnings, serviceid) '
          'VALUES (@firstName, @lastName, @skills, @expertise, @prolificacy, @dailyearnings, @serviceid)',
        ),
        parameters: {
          'firstName': employee.firstName,
          'lastName': employee.lastName,
          'skills': employee.skills,
          'expertise': employee.expertise,
          'prolificacy': 0.0,
          'dailyearnings': 0,
          'serviceid': null,
        },
      );

      return true;
    } catch (e) {
      logger.e('Çalışan eklenirken hata oluştu.', error: e);
      return false;
    } finally {
      await connection?.close();
    }
  }

  // Çalışan güncelleme
  static Future<bool> updateEmployee(Employee employee) async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo işlem yapılıyor.',
      );
      return true;
    }

    Connection? connection;
    try {
      connection = await _connect();

      await connection.execute(
        Sql.named(
          'UPDATE employees SET firstname = @firstName, lastname = @lastName, '
          'skills = @skills, expertise = @expertise WHERE employeeid = @id',
        ),
        parameters: {
          'id': employee.id,
          'firstName': employee.firstName,
          'lastName': employee.lastName,
          'skills': employee.skills,
          'expertise': employee.expertise,
        },
      );

      return true;
    } catch (e) {
      logger.e('Çalışan güncellenirken hata oluştu.', error: e);
      return false;
    } finally {
      await connection?.close();
    }
  }

  // Çalışan silme (soft delete - isactive = false)
  static Future<bool> deleteEmployee(int employeeId) async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo işlem yapılıyor.',
      );
      return true;
    }

    Connection? connection;
    try {
      connection = await _connect();

      // Soft delete - çalışanı pasif yap
      await connection.execute(
        Sql.named(
          'UPDATE employees SET prolificacy = -1 WHERE employeeid = @id',
        ),
        parameters: {'id': employeeId},
      );

      return true;
    } catch (e) {
      logger.e('Çalışan silinirken hata oluştu.', error: e);
      return false;
    } finally {
      await connection?.close();
    }
  }

  // === APPOINTMENT İŞLEMLERİ ===

  // Belirli bir customer'ın randevularını getir
  static Future<List<Appointment>> getAppointmentsByCustomerId(
    int customerId,
  ) async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo veriler döndürülüyor.',
      );
      // Demo verilerde customer ID'ye göre filtreleme yap
      final demoAppointments = _getDemoAppointments();
      // Demo verilerde customer ID yok, bu yüzden tüm randevuları döndür
      // Gerçek uygulamada customer ID ile filtrelenecek
      logger.i(
        'Demo modda customer ID $customerId için ${demoAppointments.length} randevu döndürülüyor',
      );
      return demoAppointments;
    }

    Connection? connection;
    try {
      connection = await _connect();

      // Debug: Önce appointments tablosunda bu customer ID ile kaç randevu var kontrol et
      var countResults = await connection.execute(
        Sql.named(
          'SELECT COUNT(*) FROM appointments WHERE customerid = @customerId',
        ),
        parameters: {'customerId': customerId},
      );

      int totalAppointments = countResults.first[0] as int;
      logger.i(
        'Customer ID $customerId için appointments tablosunda toplam $totalAppointments randevu bulundu',
      );

      // Eğer hiç randevu yoksa boş liste döndür
      if (totalAppointments == 0) {
        logger.w(
          'Customer ID $customerId için appointments tablosunda randevu bulunamadı',
        );

        // Debug: Appointments tablosunda hiç veri var mı kontrol et
        var totalCountResults = await connection.execute(
          'SELECT COUNT(*) FROM appointments',
        );
        int totalAppointmentsInTable = totalCountResults.first[0] as int;
        logger.w(
          'Appointments tablosunda toplam $totalAppointmentsInTable randevu var',
        );

        // Debug: Appointments tablosundaki customerid değerlerini kontrol et
        var customerIdCheckResults = await connection.execute(
          'SELECT customerid, COUNT(*) FROM appointments GROUP BY customerid ORDER BY customerid',
        );
        logger.w('Appointments tablosundaki customerid dağılımı:');
        for (var row in customerIdCheckResults) {
          int? customerIdValue = row[0] as int?;
          int count = row[1] as int;
          if (customerIdValue == null) {
            logger.w('  NULL customerid: $count randevu');
          } else {
            logger.w('  Customer ID $customerIdValue: $count randevu');
          }
        }

        // Debug: Tüm randevuları detaylı kontrol et
        var allAppointmentsResults = await connection.execute(
          'SELECT appointmentid, customerid, employeeid, serviceid, appointmentdatetime FROM appointments ORDER BY appointmentid LIMIT 5',
        );
        logger.w('İlk 5 randevunun detayları:');
        for (var row in allAppointmentsResults) {
          int appointmentId = row[0] as int;
          int? customerId = row[1] as int?;
          int? employeeId = row[2] as int?;
          int? serviceId = row[3] as int?;
          DateTime appointmentDateTime = row[4] as DateTime;

          logger.w(
            '  Appointment ID: $appointmentId, Customer ID: $customerId, Employee ID: $employeeId, Service ID: $serviceId, Date: $appointmentDateTime',
          );
        }

        // Debug: Customer tablosunda bu ID var mı kontrol et
        var customerCheckResults = await connection.execute(
          Sql.named(
            'SELECT customerid, firstname, lastname, email FROM customer WHERE customerid = @customerId',
          ),
          parameters: {'customerId': customerId},
        );

        if (customerCheckResults.isNotEmpty) {
          var customerRow = customerCheckResults.first;
          logger.w(
            'Customer bulundu: ID: ${customerRow[0]}, Ad: ${customerRow[1]}, Soyad: ${customerRow[2]}, Email: ${customerRow[3]}',
          );
        } else {
          logger.w('Customer ID $customerId customer tablosunda bulunamadı!');
        }

        return [];
      }

      // Önce sadece appointments tablosundan temel bilgileri al
      logger.i(
        'SQL sorgusu çalıştırılıyor: SELECT * FROM appointments WHERE customerid = $customerId',
      );

      var results = await connection.execute(
        Sql.named('''SELECT a.appointmentid, 
                    a.customerid,
                    a.employeeid,
                    a.serviceid,
                    a.appointmentdatetime,
                    a.process,
                    a.totalprice,
                    COALESCE(a.approvalstatus, 'Pending') as approvalstatus
             FROM appointments a
             WHERE a.customerId = @customerId
             ORDER BY a.appointmentdatetime DESC'''),
        parameters: {'customerId': customerId},
      );

      logger.i('SQL sorgusu sonucu: ${results.length} satır bulundu');

      // Debug: Ham veriyi yazdır
      if (results.isNotEmpty) {
        var firstRow = results.first;
        logger.i(
          'İlk satır verisi: appointmentid=${firstRow[0]}, customerid=${firstRow[1]}, employeeid=${firstRow[2]}, serviceid=${firstRow[3]}',
        );
      }

      List<Appointment> appointments = [];

      for (var row in results) {
        // totalprice String olarak geliyor, double'a çevir
        double totalPrice = 0.0;
        try {
          if (row[6] is String) {
            totalPrice = double.parse(row[6] as String);
          } else if (row[6] is num) {
            totalPrice = (row[6] as num).toDouble();
          }
        } catch (e) {
          logger.w('Total price parse hatası: ${row[6]}');
          totalPrice = 0.0;
        }

        // Customer, employee ve service bilgilerini ayrı sorgularla al
        int rowCustomerId = row[1] as int? ?? 0;
        int employeeId = row[2] as int? ?? 0;
        int serviceId = row[3] as int? ?? 0;

        // Customer bilgilerini al
        var customerResults = await connection.execute(
          Sql.named(
            'SELECT firstname, lastname, email FROM customer WHERE customerid = @customerId',
          ),
          parameters: {'customerId': rowCustomerId},
        );

        String customerName = 'Bilinmeyen';
        String customerEmail = '';
        if (customerResults.isNotEmpty) {
          var customerRow = customerResults.first;
          customerName = '${customerRow[0] ?? ''} ${customerRow[1] ?? ''}';
          customerEmail = customerRow[2] as String? ?? '';
        }

        // Employee bilgilerini al
        var employeeResults = await connection.execute(
          Sql.named(
            'SELECT firstname, lastname FROM employees WHERE employeeid = @employeeId',
          ),
          parameters: {'employeeId': employeeId},
        );

        String employeeName = 'Bilinmeyen';
        if (employeeResults.isNotEmpty) {
          var employeeRow = employeeResults.first;
          employeeName = '${employeeRow[0] ?? ''} ${employeeRow[1] ?? ''}';
        }

        // Service bilgilerini al
        var serviceResults = await connection.execute(
          Sql.named(
            'SELECT servicename FROM services WHERE serviceid = @serviceId',
          ),
          parameters: {'serviceId': serviceId},
        );

        String serviceName = 'Bilinmeyen';
        if (serviceResults.isNotEmpty) {
          serviceName = serviceResults.first[0] as String? ?? 'Bilinmeyen';
        }

        logger.i(
          'Customer ID $customerId için randevu bulundu: $customerName - $serviceName',
        );

        // Process değerini string'e çevir
        String processText = 'Bekliyor';
        if (row[5] != null) {
          int processValue = row[5] as int? ?? 0;
          switch (processValue) {
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

        appointments.add(
          Appointment(
            appointmentId: row[0] as int? ?? 0,
            customerName: customerName,
            employeeName: employeeName,
            serviceName: serviceName,
            process: processText,
            totalPrice: totalPrice,
            appointmentDateTime: row[4] as DateTime? ?? DateTime.now(),
            approvalStatus: row[7] as String? ?? 'Pending',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            notes: '',
            customerPhone: '',
            customerEmail: customerEmail,
          ),
        );
      }

      logger.i(
        'Customer ID $customerId için ${appointments.length} randevu bulundu',
      );
      return appointments;
    } catch (e) {
      logger.e(
        'Customer ID $customerId için randevu listesi çekme hatası.',
        error: e,
      );
      return [];
    } finally {
      await connection?.close();
    }
  }

  // Belirli bir customer'ın email'ine göre randevularını getir
  static Future<List<Appointment>> getAppointmentsByCustomerEmail(
    String customerEmail,
  ) async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo veriler döndürülüyor.',
      );
      // Demo verilerde email'e göre filtreleme yap
      final demoAppointments = _getDemoAppointments();
      return demoAppointments.where((appointment) {
        return appointment.customerEmail == customerEmail;
      }).toList();
    }

    Connection? connection;
    try {
      connection = await _connect();

      // Debug: Önce appointments tablosunda bu email ile kaç randevu var kontrol et
      var countResults = await connection.execute(
        Sql.named(
          'SELECT COUNT(*) FROM appointments a JOIN customer c ON a.customerid = c.customerid WHERE c.email = @customerEmail',
        ),
        parameters: {'customerEmail': customerEmail},
      );

      int totalAppointments = countResults.first[0] as int;
      logger.i(
        'Customer email $customerEmail için appointments tablosunda toplam $totalAppointments randevu bulundu',
      );

      // Eğer hiç randevu yoksa boş liste döndür
      if (totalAppointments == 0) {
        logger.w(
          'Customer email $customerEmail için appointments tablosunda randevu bulunamadı',
        );

        // Debug: Appointments tablosunda hiç veri var mı kontrol et
        var totalCountResults = await connection.execute(
          'SELECT COUNT(*) FROM appointments',
        );
        int totalAppointmentsInTable = totalCountResults.first[0] as int;
        logger.w(
          'Appointments tablosunda toplam $totalAppointmentsInTable randevu var',
        );

        // Debug: Appointments tablosundaki customerid değerlerini kontrol et
        var customerIdCheckResults = await connection.execute(
          'SELECT customerid, COUNT(*) FROM appointments GROUP BY customerid ORDER BY customerid',
        );
        logger.w('Appointments tablosundaki customerid dağılımı:');
        for (var row in customerIdCheckResults) {
          int? customerIdValue = row[0] as int?;
          int count = row[1] as int;
          if (customerIdValue == null) {
            logger.w('  NULL customerid: $count randevu');
          } else {
            logger.w('  Customer ID $customerIdValue: $count randevu');
          }
        }

        // Debug: Tüm randevuları detaylı kontrol et
        var allAppointmentsResults = await connection.execute(
          'SELECT appointmentid, customerid, employeeid, serviceid, appointmentdatetime FROM appointments ORDER BY appointmentid LIMIT 5',
        );
        logger.w('İlk 5 randevunun detayları:');
        for (var row in allAppointmentsResults) {
          int appointmentId = row[0] as int;
          int? customerId = row[1] as int?;
          int? employeeId = row[2] as int?;
          int? serviceId = row[3] as int?;
          DateTime appointmentDateTime = row[4] as DateTime;

          logger.w(
            '  Appointment ID: $appointmentId, Customer ID: $customerId, Employee ID: $employeeId, Service ID: $serviceId, Date: $appointmentDateTime',
          );
        }

        // Debug: Customer tablosunda bu email var mı kontrol et
        var customerCheckResults = await connection.execute(
          Sql.named(
            'SELECT customerid, firstname, lastname, email FROM customer WHERE email = @customerId',
          ),
          parameters: {'customerId': customerEmail},
        );

        if (customerCheckResults.isNotEmpty) {
          var customerRow = customerCheckResults.first;
          logger.w(
            'Customer bulundu: ID: ${customerRow[0]}, Ad: ${customerRow[1]}, Soyad: ${customerRow[2]}, Email: ${customerRow[3]}',
          );
        } else {
          logger.w(
            'Customer email $customerEmail customer tablosunda bulunamadı!',
          );
        }

        return [];
      }

      // Önce customer ID'yi bul
      var customerIdResults = await connection.execute(
        Sql.named(
          'SELECT customerid FROM customer WHERE email = @customerEmail',
        ),
        parameters: {'customerEmail': customerEmail},
      );

      if (customerIdResults.isEmpty) {
        logger.w('Customer email $customerEmail için customer ID bulunamadı');
        return [];
      }

      int customerId = customerIdResults.first[0] as int;
      logger.i('Customer email $customerEmail için customer ID: $customerId');

      // Şimdi customer ID ile randevuları getir
      logger.i(
        'SQL sorgusu çalıştırılıyor: SELECT * FROM appointments WHERE customerid = $customerId (email: $customerEmail)',
      );

      var results = await connection.execute(
        Sql.named('''SELECT a.appointmentid, 
                    a.customerid,
                    a.employeeid,
                    a.serviceid,
                    a.appointmentdatetime,
                    a.process,
                    a.totalprice,
                    COALESCE(a.approvalstatus, 'Pending') as approvalstatus
             FROM appointments a
             WHERE a.customerid = @customerId
             ORDER BY a.appointmentdatetime DESC'''),
        parameters: {'customerId': customerId},
      );

      logger.i('SQL sorgusu sonucu: ${results.length} satır bulundu');

      // Debug: Ham veriyi yazdır
      if (results.isNotEmpty) {
        var firstRow = results.first;
        logger.i(
          'İlk satır verisi: appointmentid=${firstRow[0]}, customerid=${firstRow[1]}, employeeid=${firstRow[2]}, serviceid=${firstRow[3]}',
        );
      }

      List<Appointment> appointments = [];

      for (var row in results) {
        // totalprice String olarak geliyor, double'a çevir
        double totalPrice = 0.0;
        try {
          if (row[6] is String) {
            totalPrice = double.parse(row[6] as String);
          } else if (row[6] is num) {
            totalPrice = (row[6] as num).toDouble();
          }
        } catch (e) {
          logger.w('Total price parse hatası: ${row[6]}');
          totalPrice = 0.0;
        }

        // Customer, employee ve service bilgilerini ayrı sorgularla al
        int rowCustomerId = row[1] as int? ?? 0;
        int employeeId = row[2] as int? ?? 0;
        int serviceId = row[3] as int? ?? 0;

        // Customer bilgilerini al
        var customerResults = await connection.execute(
          Sql.named(
            'SELECT firstname, lastname, email FROM customer WHERE customerid = @customerId',
          ),
          parameters: {'customerId': rowCustomerId},
        );

        String customerName = 'Bilinmeyen';
        String customerEmail = '';
        if (customerResults.isNotEmpty) {
          var customerRow = customerResults.first;
          customerName = '${customerRow[0] ?? ''} ${customerRow[1] ?? ''}';
          customerEmail = customerRow[2] as String? ?? '';
        }

        // Employee bilgilerini al
        var employeeResults = await connection.execute(
          Sql.named(
            'SELECT firstname, lastname FROM employees WHERE employeeid = @employeeId',
          ),
          parameters: {'employeeId': employeeId},
        );

        String employeeName = 'Bilinmeyen';
        if (employeeResults.isNotEmpty) {
          var employeeRow = employeeResults.first;
          employeeName = '${employeeRow[0] ?? ''} ${employeeRow[1] ?? ''}';
        }

        // Service bilgilerini al
        var serviceResults = await connection.execute(
          Sql.named(
            'SELECT servicename FROM services WHERE serviceid = @serviceId',
          ),
          parameters: {'serviceId': serviceId},
        );

        String serviceName = 'Bilinmeyen';
        if (serviceResults.isNotEmpty) {
          serviceName = serviceResults.first[0] as String? ?? 'Bilinmeyen';
        }

        logger.i(
          'Customer email $customerEmail için randevu bulundu: $customerName - $serviceName',
        );

        // Process değerini string'e çevir
        String processText = 'Bekliyor';
        if (row[5] != null) {
          int processValue = row[5] as int? ?? 0;
          switch (processValue) {
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

        appointments.add(
          Appointment(
            appointmentId: row[0] as int? ?? 0,
            customerName: customerName,
            employeeName: employeeName,
            serviceName: serviceName,
            process: processText,
            totalPrice: totalPrice,
            appointmentDateTime: row[4] as DateTime? ?? DateTime.now(),
            approvalStatus: row[7] as String? ?? 'Pending',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            notes: '',
            customerPhone: '',
            customerEmail: customerEmail,
          ),
        );
      }

      logger.i(
        'Customer email $customerEmail için ${appointments.length} randevu bulundu',
      );
      return appointments;
    } catch (e) {
      logger.e(
        'Customer email $customerEmail için randevu listesi çekme hatası.',
        error: e,
      );
      return [];
    } finally {
      await connection?.close();
    }
  }

  static Future<List<Appointment>> getAppointments() async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo veriler döndürülüyor.',
      );
      return _getDemoAppointments();
    }

    Connection? connection;
    try {
      connection = await _connect();

      var results = await connection.execute(
        '''SELECT a.appointmentid, c.firstname || ' ' || c.lastname as customername, 
                  e.firstname || ' ' || e.lastname as employeename, s.servicename, 
                  a.process, a.totalprice, a.appointmentdatetime, COALESCE(a.approvalstatus, 'Pending') as approvalstatus,
                  c.email as customeremail, '' as customerphone
           FROM appointments a
           JOIN customer c ON a.customerid = c.customerid
           JOIN employees e ON a.employeeid = e.employeeid
           JOIN services s ON a.serviceid = s.serviceid
           ORDER BY a.appointmentdatetime DESC''',
      );

      List<Appointment> appointments = results.map((row) {
        // Debug: Ham veriyi yazdır
        logger.i(
          'Ham veri - Row[8] (customerEmail): ${row[8]} (Type: ${row[8].runtimeType})',
        );
        logger.i(
          'Ham veri - Row[9] (customerPhone): ${row[9]} (Type: ${row[9].runtimeType})',
        );

        // totalprice numeric olarak geliyor, double'a çevir
        double totalPrice = 0.0;
        try {
          if (row[5] is num) {
            totalPrice = (row[5] as num).toDouble();
          } else if (row[5] is String) {
            totalPrice = double.parse(row[5] as String);
          }
        } catch (e) {
          logger.w('Total price parse hatası: ${row[5]}');
          totalPrice = 0.0;
        }

        final customerEmail = row[8] as String? ?? '';
        final customerPhone = row[9] as String? ?? '';

        logger.i('İşlenmiş customerEmail: "$customerEmail"');
        logger.i('İşlenmiş customerPhone: "$customerPhone"');

        // Process değerini string'e çevir
        String processText = 'Bekliyor';
        if (row[4] != null) {
          int processValue = row[4] as int;
          switch (processValue) {
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

        return Appointment(
          appointmentId: row[0] as int? ?? 0,
          customerName: row[1] as String? ?? 'Bilinmeyen',
          employeeName: row[2] as String? ?? 'Bilinmeyen',
          serviceName: row[3] as String? ?? 'Bilinmeyen',
          process: processText,
          totalPrice: totalPrice,
          appointmentDateTime: row[6] as DateTime? ?? DateTime.now(),
          approvalStatus: row[7] as String? ?? 'Pending',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          notes: '',
          customerPhone: customerPhone,
          customerEmail: customerEmail,
        );
      }).toList();

      return appointments;
    } catch (e) {
      logger.e('Randevu listesi çekme hatası.', error: e);
      return _getDemoAppointments();
    } finally {
      await connection?.close();
    }
  }

  // Randevu çakışma kontrolü - Sadece Dart kodu ile!
  static Future<bool> hasAppointmentConflict(
    DateTime appointmentDateTime,
    int employeeId,
    int serviceId, {
    int? excludeAppointmentId,
  }) async {
    if (_isWebPlatform) {
      logger.w('Web platformunda veritabanı işlemleri desteklenmez.');
      return false;
    }

    try {
      // 1. Hizmet süresini al
      int serviceDuration = await _getServiceDuration(serviceId);
      logger.i('Hizmet süresi: $serviceDuration dakika');

      // 2. Yeni randevunun bitiş zamanını hesapla
      DateTime newAppointmentEnd = appointmentDateTime.add(
        Duration(minutes: serviceDuration),
      );

      // 3. O çalışanın o gündeki tüm randevularını al
      List<Map<String, dynamic>> existingAppointments =
          await _getEmployeeAppointmentsForDate(
            appointmentDateTime,
            employeeId,
            excludeAppointmentId,
          );

      // 4. Her mevcut randevu ile karşılaştır
      for (var existing in existingAppointments) {
        DateTime existingStart = existing['appointmentDateTime'] as DateTime;
        int existingServiceDuration = existing['serviceDuration'] as int;
        DateTime existingEnd = existingStart.add(
          Duration(minutes: existingServiceDuration),
        );

        // Çakışma kontrolü - çok basit mantık!
        if (_isTimeConflict(
          appointmentDateTime, // Yeni randevu başlangıç
          newAppointmentEnd, // Yeni randevu bitiş
          existingStart, // Mevcut randevu başlangıç
          existingEnd, // Mevcut randevu bitiş
        )) {
          logger.w('Çakışma bulundu!');
          logger.w('Yeni randevu: $appointmentDateTime - $newAppointmentEnd');
          logger.w('Mevcut randevu: $existingStart - $existingEnd');
          return true; // Çakışma var!
        }
      }

      return false; // Çakışma yok
    } catch (e) {
      logger.e('Randevu çakışma kontrolü hatası.', error: e);
      return false;
    }
  }

  // Zaman çakışması kontrolü - çok basit!
  static bool _isTimeConflict(
    DateTime start1,
    DateTime end1, // Yeni randevu
    DateTime start2,
    DateTime end2, // Mevcut randevu
  ) {
    // İki zaman aralığı çakışıyor mu?
    return start1.isBefore(end2) && end1.isAfter(start2);
  }

  // Hizmet süresini al
  static Future<int> _getServiceDuration(int serviceId) async {
    Connection? connection;
    try {
      connection = await _connect();

      var results = await connection.execute(
        'SELECT sure_dk FROM menu_hizmet_icerigi WHERE hizmet = (SELECT servicename FROM services WHERE serviceid = @serviceId)',
        parameters: {'serviceId': serviceId},
      );

      if (results.isNotEmpty) {
        return results.first[0] as int;
      }
      return 30; // Varsayılan süre
    } finally {
      await connection?.close();
    }
  }

  // Çalışanın belirli gündeki randevularını al
  static Future<List<Map<String, dynamic>>> _getEmployeeAppointmentsForDate(
    DateTime date,
    int employeeId,
    int? excludeAppointmentId,
  ) async {
    Connection? connection;
    try {
      connection = await _connect();

      var results = await connection.execute(
        '''
        SELECT 
          a.appointmentid,
          a.appointmentdatetime,
          s.servicename,
          mhi.sure_dk as service_duration
        FROM appointments a
        JOIN services s ON a.serviceid = s.serviceid
        JOIN menu_hizmet_icerigi mhi ON s.servicename = mhi.hizmet
        WHERE a.employeeid = @employeeId 
        AND DATE(a.appointmentdatetime) = DATE(@date)
        AND a.appointmentid != COALESCE(@excludeAppointmentId, -1)
        ORDER BY a.appointmentdatetime
      ''',
        parameters: {
          'employeeId': employeeId,
          'date': date,
          'excludeAppointmentId': excludeAppointmentId,
        },
      );

      List<Map<String, dynamic>> appointments = [];
      for (var row in results) {
        appointments.add({
          'appointmentid': row[0],
          'appointmentDateTime': row[1],
          'servicename': row[2],
          'serviceDuration': row[3],
        });
      }
      return appointments;
    } finally {
      await connection?.close();
    }
  }

  static Future<bool> createAppointment(Appointment appointment) async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo işlem yapılıyor.',
      );
      return true;
    }

    Connection? connection;
    try {
      connection = await _connect();

      logger.i('Randevu oluşturma başladı: ${appointment.customerEmail}');

      // Önce customer ID'yi bul
      var customerResults = await connection.execute(
        'SELECT customerid FROM customer WHERE email = @email LIMIT 1',
        parameters: {'email': appointment.customerEmail ?? ''},
      );

      if (customerResults.isEmpty) {
        logger.e('Customer bulunamadı: ${appointment.customerEmail}');
        return false;
      }

      int customerId = customerResults.first[0] as int;
      logger.i('Customer ID bulundu: $customerId');

      // Önce employee ID'yi bul
      var employeeResults = await connection.execute(
        'SELECT employeeid FROM employees WHERE firstname || \' \' || lastname = @name LIMIT 1',
        parameters: {'name': appointment.employeeName},
      );

      if (employeeResults.isEmpty) {
        logger.e('Employee bulunamadı: ${appointment.employeeName}');
        return false;
      }

      int employeeId = employeeResults.first[0] as int;
      logger.i('Employee ID bulundu: $employeeId');

      // Önce service ID'yi bul
      var serviceResults = await connection.execute(
        'SELECT serviceid FROM services WHERE servicename = @name LIMIT 1',
        parameters: {'name': appointment.serviceName},
      );

      if (serviceResults.isEmpty) {
        logger.e('Service bulunamadı: ${appointment.serviceName}');
        return false;
      }

      int serviceId = serviceResults.first[0] as int;
      logger.i('Service ID bulundu: $serviceId');

      // Randevu çakışma kontrolü
      bool hasConflict = await hasAppointmentConflict(
        appointment.appointmentDateTime,
        employeeId,
        serviceId,
      );

      // Müşteri bazlı çakışma: aynı müşteri aynı anda iki randevu alamaz (customerId ile)
      bool hasCustomerOverlap = await hasCustomerConflictById(
        appointment.appointmentDateTime,
        customerId,
        appointment.serviceName,
      );

      if (hasConflict || hasCustomerOverlap) {
        logger.w('Supabase randevu çakışması tespit edildi!');
        throw Exception(
          'Seçilen tarih ve saatte başka bir randevu bulunmaktadır. Lütfen farklı bir zaman seçiniz.',
        );
      }

      // Hizmet süresini logla
      var serviceDurationResults = await connection.execute(
        'SELECT sure_dk FROM menu_hizmet_icerigi WHERE hizmet = (SELECT servicename FROM services WHERE serviceid = @serviceId)',
        parameters: {'serviceId': serviceId},
      );

      if (serviceDurationResults.isNotEmpty) {
        int serviceDuration = serviceDurationResults.first[0] as int;
        logger.i('Randevu süresi: $serviceDuration dakika');
        logger.i(
          'Randevu bitiş zamanı: ${appointment.appointmentDateTime.add(Duration(minutes: serviceDuration))}',
        );
      }

      // Randevu oluştur
      logger.i('Randevu INSERT sorgusu çalıştırılıyor...');
      logger.i(
        'INSERT INTO appointments (customerid, employeeid, serviceid, appointmentdatetime, process, totalprice) VALUES ($customerId, $employeeId, $serviceId, ${appointment.appointmentDateTime}, 0, ${appointment.totalPrice})',
      );

      await connection.execute(
        'INSERT INTO appointments (customerid, employeeid, serviceid, appointmentdatetime, process, totalprice) '
        'VALUES (@customerId, @employeeId, @serviceId, @appointmentDateTime, @process, @totalPrice)',
        parameters: {
          'customerId': customerId,
          'employeeId': employeeId,
          'serviceId': serviceId,
          'appointmentDateTime': appointment.appointmentDateTime,
          'process': 0, // 0 = Bekliyor
          'totalPrice': appointment.totalPrice,
        },
      );

      // Randevunun gerçekten oluşturulduğunu kontrol et
      var verifyResults = await connection.execute(
        'SELECT appointmentid, customerid, employeeid, serviceid FROM appointments WHERE customerid = @customerId AND employeeid = @employeeId AND serviceid = @serviceId AND appointmentdatetime = @appointmentDateTime ORDER BY appointmentid DESC LIMIT 1',
        parameters: {
          'customerId': customerId,
          'employeeId': employeeId,
          'serviceId': serviceId,
          'appointmentDateTime': appointment.appointmentDateTime,
        },
      );

      if (verifyResults.isNotEmpty) {
        var verifyRow = verifyResults.first;
        int createdAppointmentId = verifyRow[0] as int;
        int verifyCustomerId = verifyRow[1] as int;
        int verifyEmployeeId = verifyRow[2] as int;
        int verifyServiceId = verifyRow[3] as int;

        logger.i('Randevu başarıyla oluşturuldu ve doğrulandı.');
        logger.i('Appointment ID: $createdAppointmentId');
        logger.i('Customer ID: $verifyCustomerId (beklenen: $customerId)');
        logger.i('Employee ID: $verifyEmployeeId (beklenen: $employeeId)');
        logger.i('Service ID: $verifyServiceId (beklenen: $serviceId)');

        if (verifyCustomerId != customerId) {
          logger.w(
            'UYARI: Customer ID eşleşmiyor! Beklenen: $customerId, Bulunan: $verifyCustomerId',
          );
        }
      } else {
        logger.w('Randevu oluşturuldu ama doğrulanamadı!');
      }

      logger.i(
        'Randevu başarıyla oluşturuldu: Customer ID: $customerId, Employee ID: $employeeId, Service ID: $serviceId',
      );
      return true;
    } catch (e) {
      logger.e('Randevu oluşturma hatası.', error: e);
      rethrow; // Hatayı yukarı fırlat
    } finally {
      await connection?.close();
    }
  }

  static Future<void> updateAppointmentStatus(
    int appointmentId,
    String status,
  ) async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo işlem yapılıyor.',
      );
      return;
    }

    Connection? connection;
    try {
      connection = await _connect();

      await connection.execute(
        'UPDATE appointments SET approvalstatus = @status WHERE appointmentid = @id',
        parameters: {'status': status, 'id': appointmentId},
      );
    } catch (e) {
      logger.e('Randevu durumu güncellenirken hata oluştu.', error: e);
      rethrow;
    } finally {
      await connection?.close();
    }
  }

  /// Appointments tablosundaki NULL customerid değerlerini düzelt
  Future<void> fixNullCustomerIds() async {
    Connection? connection;
    try {
      connection = await _connect();

      // Önce NULL customerid'li randevuları bul
      var nullCustomerIdResults = await connection.execute(
        'SELECT appointmentid, customerid FROM appointments WHERE customerid IS NULL ORDER BY appointmentid',
      );

      if (nullCustomerIdResults.isEmpty) {
        logger.i('NULL customerid değeri bulunamadı, tablo zaten düzgün');
        return;
      }

      logger.w(
        'NULL customerid değerli ${nullCustomerIdResults.length} randevu bulundu:',
      );
      for (var row in nullCustomerIdResults) {
        int appointmentId = row[0] as int;
        logger.w('  Appointment ID: $appointmentId - customerid: NULL');
      }

      // İlk customer'ı bul (genellikle ID 1)
      var firstCustomerResults = await connection.execute(
        'SELECT customerid, firstname, lastname, email FROM customer ORDER BY customerid LIMIT 1',
      );

      if (firstCustomerResults.isEmpty) {
        logger.e('Customer tablosunda hiç veri yok!');
        return;
      }

      var firstCustomer = firstCustomerResults.first;
      int firstCustomerId = firstCustomer[0] as int;
      String firstName = firstCustomer[1] as String;
      String lastName = firstCustomer[2] as String;
      String email = firstCustomer[3] as String;

      logger.i(
        'İlk customer bulundu: ID: $firstCustomerId, Ad: $firstName $lastName, Email: $email',
      );

      // NULL customerid'li randevuları bu customer'a ata
      await connection.execute(
        'UPDATE appointments SET customerid = @customerId WHERE customerid IS NULL',
        parameters: {'customerId': firstCustomerId},
      );

      logger.i(
        '${nullCustomerIdResults.length} randevu customer ID $firstCustomerId\'e atandı',
      );

      // Güncellenmiş durumu kontrol et
      var updatedResults = await connection.execute(
        'SELECT appointmentid, customerid FROM appointments ORDER BY appointmentid LIMIT 10',
      );

      logger.i('Güncellenmiş randevular (ilk 10):');
      for (var row in updatedResults) {
        int appointmentId = row[0] as int;
        int? customerId = row[1] as int?;
        logger.i('  Appointment ID: $appointmentId - customerid: $customerId');
      }
    } catch (e) {
      logger.e('fixNullCustomerIds hatası: $e');
    } finally {
      if (connection != null) {
        await connection.close();
      }
    }
  }

  /// Belirli bir customer için randevuları düzelt
  Future<void> fixCustomerAppointments(
    int targetCustomerId,
    String targetEmail,
  ) async {
    Connection? connection;
    try {
      connection = await _connect();

      logger.i('Customer ID $targetCustomerId için randevular düzeltiliyor...');

      // Önce bu customer'ın mevcut randevularını kontrol et
      var existingAppointments = await connection.execute(
        'SELECT appointmentid, customerid FROM appointments WHERE customerid = @customerId',
        parameters: {'customerId': targetCustomerId},
      );

      logger.i(
        'Customer ID $targetCustomerId için mevcut ${existingAppointments.length} randevu bulundu',
      );

      // Tüm randevuları kontrol et
      var allAppointments = await connection.execute(
        'SELECT appointmentid, customerid, appointmentdatetime FROM appointments ORDER BY appointmentid',
      );

      logger.i('Toplam ${allAppointments.length} randevu bulundu');

      // Customer ID dağılımını göster
      var customerIdDistribution = await connection.execute(
        'SELECT customerid, COUNT(*) FROM appointments GROUP BY customerid ORDER BY customerid',
      );

      logger.i('Customer ID dağılımı:');
      for (var row in customerIdDistribution) {
        int? customerId = row[0] as int?;
        int count = row[1] as int;
        if (customerId == null) {
          logger.w('  NULL customerid: $count randevu');
        } else {
          logger.w('  Customer ID $customerId: $count randevu');
        }
      }

      // Eğer bu customer için hiç randevu yoksa, en yakın tarihli randevuları bu customer'a ata
      if (existingAppointments.isEmpty) {
        logger.w(
          'Customer ID $targetCustomerId için hiç randevu bulunamadı, en yakın tarihli randevular atanıyor...',
        );

        // En yakın tarihli 3 randevuyu bu customer'a ata
        var recentAppointments = await connection.execute(
          'SELECT appointmentid, customerid FROM appointments WHERE customerid != @customerId ORDER BY appointmentdatetime DESC LIMIT 3',
          parameters: {'customerId': targetCustomerId},
        );

        if (recentAppointments.isNotEmpty) {
          for (var row in recentAppointments) {
            int appointmentId = row[0] as int;
            int currentCustomerId = row[1] as int;

            logger.i(
              'Appointment ID $appointmentId (şu anda Customer ID $currentCustomerId\'de) Customer ID $targetCustomerId\'ye atanıyor...',
            );

            await connection.execute(
              'UPDATE appointments SET customerid = @newCustomerId WHERE appointmentid = @appointmentId',
              parameters: {
                'newCustomerId': targetCustomerId,
                'appointmentId': appointmentId,
              },
            );
          }

          logger.i(
            '${recentAppointments.length} randevu Customer ID $targetCustomerId\'ye atandı',
          );
        }
      }

      // Güncellenmiş durumu kontrol et
      var updatedAppointments = await connection.execute(
        'SELECT appointmentid, customerid FROM appointments WHERE customerid = @customerId ORDER BY appointmentid',
        parameters: {'customerId': targetCustomerId},
      );

      logger.i(
        'Güncelleme sonrası Customer ID $targetCustomerId için ${updatedAppointments.length} randevu bulundu',
      );

      if (updatedAppointments.isNotEmpty) {
        logger.i('Randevular:');
        for (var row in updatedAppointments) {
          int appointmentId = row[0] as int;
          int customerId = row[1] as int;
          logger.i(
            '  Appointment ID: $appointmentId - Customer ID: $customerId',
          );
        }
      }
    } catch (e) {
      logger.e('fixCustomerAppointments hatası: $e');
    } finally {
      if (connection != null) {
        await connection.close();
      }
    }
  }

  /// Belirli bir customer için örnek randevular oluştur
  Future<void> createSampleAppointmentsForCustomer(int customerId) async {
    Connection? connection;
    try {
      connection = await _connect();

      logger.i(
        'Customer ID $customerId için örnek randevular oluşturuluyor...',
      );

      // Önce bu customer'ın mevcut randevularını kontrol et
      var existingAppointments = await connection.execute(
        'SELECT appointmentid FROM appointments WHERE customerid = @customerId',
        parameters: {'customerId': customerId},
      );

      if (existingAppointments.isNotEmpty) {
        logger.i(
          'Customer ID $customerId için zaten ${existingAppointments.length} randevu var',
        );
        return;
      }

      // Örnek randevular oluştur
      final sampleAppointments = [
        {
          'employeeid': 1,
          'serviceid': 1,
          'appointmentdatetime': DateTime.now().add(const Duration(days: 1)),
          'process': 0,
          'totalprice': 100.0,
          'approvalstatus': 'Pending',
        },
        {
          'employeeid': 2,
          'serviceid': 2,
          'appointmentdatetime': DateTime.now().add(const Duration(days: 3)),
          'process': 0,
          'totalprice': 200.0,
          'approvalstatus': 'Pending',
        },
        {
          'employeeid': 1,
          'serviceid': 1,
          'appointmentdatetime': DateTime.now().add(const Duration(days: 7)),
          'process': 0,
          'totalprice': 150.0,
          'approvalstatus': 'Pending',
        },
      ];

      for (var appointment in sampleAppointments) {
        await connection.execute(
          '''INSERT INTO appointments (customerid, employeeid, serviceid, appointmentdatetime, process, totalprice, approvalstatus)
             VALUES (@customerId, @employeeId, @serviceId, @appointmentDateTime, @process, @totalPrice, @approvalStatus)''',
          parameters: {
            'customerId': customerId,
            'employeeId': appointment['employeeid'],
            'serviceId': appointment['serviceid'],
            'appointmentDateTime': appointment['appointmentdatetime'],
            'process': appointment['process'],
            'totalPrice': appointment['totalprice'],
            'approvalStatus': appointment['approvalstatus'],
          },
        );
      }

      logger.i(
        'Customer ID $customerId için ${sampleAppointments.length} örnek randevu oluşturuldu',
      );

      // Oluşturulan randevuları kontrol et
      var newAppointments = await connection.execute(
        'SELECT appointmentid, customerid, employeeid, serviceid, appointmentdatetime FROM appointments WHERE customerid = @customerId ORDER BY appointmentid',
        parameters: {'customerId': customerId},
      );

      logger.i('Oluşturulan randevular:');
      for (var row in newAppointments) {
        int appointmentId = row[0] as int;
        int rowCustomerId = row[1] as int;
        int employeeId = row[2] as int;
        int serviceId = row[3] as int;
        DateTime appointmentDateTime = row[4] as DateTime;

        logger.i(
          '  Appointment ID: $appointmentId, Customer ID: $rowCustomerId, Employee ID: $employeeId, Service ID: $serviceId, Date: $appointmentDateTime',
        );
      }
    } catch (e) {
      logger.e('createSampleAppointmentsForCustomer hatası: $e');
    } finally {
      if (connection != null) {
        await connection.close();
      }
    }
  }

  /// Customer ID 2 için örnek randevular oluştur
  Future<void> createAppointmentsForCustomer2() async {
    Connection? connection;
    try {
      connection = await _connect();

      logger.i('Customer ID 2 için örnek randevular oluşturuluyor...');

      // Önce Customer ID 2'nin mevcut randevularını kontrol et
      var existingAppointments = await connection.execute(
        'SELECT appointmentid FROM appointments WHERE customerid = 2',
      );

      if (existingAppointments.isNotEmpty) {
        logger.i(
          'Customer ID 2 için zaten ${existingAppointments.length} randevu var',
        );
        return;
      }

      // Customer ID 2 için 3 örnek randevu oluştur
      await connection.execute(
        '''INSERT INTO appointments (customerid, employeeid, serviceid, appointmentdatetime, process, totalprice, approvalstatus)
           VALUES (2, 1, 1, @date1, 0, 100.0, 'Pending')''',
        parameters: {'date1': DateTime.now().add(const Duration(days: 1))},
      );

      await connection.execute(
        '''INSERT INTO appointments (customerid, employeeid, serviceid, appointmentdatetime, process, totalprice, approvalstatus)
           VALUES (2, 2, 2, @date2, 0, 200.0, 'Pending')''',
        parameters: {'date2': DateTime.now().add(const Duration(days: 3))},
      );

      await connection.execute(
        '''INSERT INTO appointments (customerid, employeeid, serviceid, appointmentdatetime, process, totalprice, approvalstatus)
           VALUES (2, 1, 1, @date3, 0, 150.0, 'Pending')''',
        parameters: {'date3': DateTime.now().add(const Duration(days: 7))},
      );

      logger.i('Customer ID 2 için 3 örnek randevu oluşturuldu');

      // Oluşturulan randevuları kontrol et
      var newAppointments = await connection.execute(
        'SELECT appointmentid, customerid, employeeid, serviceid, appointmentdatetime FROM appointments WHERE customerid = 2 ORDER BY appointmentid',
      );

      logger.i('Customer ID 2 için oluşturulan randevular:');
      for (var row in newAppointments) {
        int appointmentId = row[0] as int;
        int customerId = row[1] as int;
        int employeeId = row[2] as int;
        int serviceId = row[3] as int;
        DateTime appointmentDateTime = row[4] as DateTime;

        logger.i(
          '  Appointment ID: $appointmentId, Customer ID: $customerId, Employee ID: $employeeId, Service ID: $serviceId, Date: $appointmentDateTime',
        );
      }
    } catch (e) {
      logger.e('createAppointmentsForCustomer2 hatası: $e');
    } finally {
      if (connection != null) {
        await connection.close();
      }
    }
  }

  /// Appointments tablosundaki mevcut durumu kontrol et
  Future<void> checkAppointmentsTable() async {
    Connection? connection;
    try {
      connection = await _connect();

      logger.i('=== APPOINTMENTS TABLOSU DURUMU ===');

      // Toplam randevu sayısı
      var totalCount = await connection.execute(
        'SELECT COUNT(*) FROM appointments',
      );
      int totalAppointments = totalCount.first[0] as int;
      logger.i('Toplam randevu sayısı: $totalAppointments');

      // Customer ID dağılımı
      var customerIdDistribution = await connection.execute(
        'SELECT customerid, COUNT(*) FROM appointments GROUP BY customerid ORDER BY customerid',
      );

      logger.i('Customer ID dağılımı:');
      for (var row in customerIdDistribution) {
        int? customerId = row[0] as int?;
        int count = row[1] as int;
        if (customerId == null) {
          logger.w('  NULL customerid: $count randevu');
        } else {
          logger.i('  Customer ID $customerId: $count randevu');
        }
      }

      // İlk 10 randevunun detayları
      var first10Appointments = await connection.execute(
        'SELECT appointmentid, customerid, employeeid, serviceid, appointmentdatetime FROM appointments ORDER BY appointmentid LIMIT 10',
      );

      logger.i('İlk 10 randevunun detayları:');
      for (var row in first10Appointments) {
        int appointmentId = row[0] as int;
        int? customerId = row[1] as int?;
        int? employeeId = row[2] as int?;
        int? serviceId = row[3] as int?;
        DateTime appointmentDateTime = row[4] as DateTime;

        logger.i(
          '  Appointment ID: $appointmentId, Customer ID: $customerId, Employee ID: $employeeId, Service ID: $serviceId, Date: $appointmentDateTime',
        );
      }

      // Customer tablosundaki mevcut customer'ları kontrol et
      var customers = await connection.execute(
        'SELECT customerid, firstname, lastname, email FROM customer ORDER BY customerid',
      );

      logger.i('Customer tablosundaki mevcut customer\'lar:');
      for (var row in customers) {
        int customerId = row[0] as int;
        String firstName = row[1] as String;
        String lastName = row[2] as String;
        String email = row[3] as String;

        logger.i(
          '  Customer ID: $customerId, Ad: $firstName $lastName, Email: $email',
        );
      }
    } catch (e) {
      logger.e('checkAppointmentsTable hatası: $e');
    } finally {
      if (connection != null) {
        await connection.close();
      }
    }
  }

  // === CUSTOMER İŞLEMLERİ ===

  // Customer bilgilerini güncelle
  static Future<bool> updateCustomerProfile(
    int customerId,
    String email,
    String? phone,
    String? address,
  ) async {
    if (_isWebPlatform) {
      logger.w('Web platformunda veritabanı işlemleri desteklenmez.');
      return false;
    }

    Connection? connection;
    try {
      connection = await _connect();

      // Email güncelleme
      if (email.isNotEmpty) {
        await connection.execute(
          Sql.named(
            'UPDATE customer SET email = @email WHERE customerid = @customerId',
          ),
          parameters: {'email': email, 'customerId': customerId},
        );
      }

      // Phone güncelleme (eğer phone sütunu varsa)
      if (phone != null && phone.isNotEmpty) {
        try {
          await connection.execute(
            Sql.named(
              'UPDATE customer SET phone = @phone WHERE customerid = @customerId',
            ),
            parameters: {'phone': phone, 'customerId': customerId},
          );
        } catch (e) {
          logger.w('Phone sütunu bulunamadı, güncellenmedi: $e');
        }
      }

      // Address güncelleme (eğer address sütunu varsa)
      if (address != null && address.isNotEmpty) {
        try {
          await connection.execute(
            Sql.named(
              'UPDATE customer SET address = @address WHERE customerid = @customerId',
            ),
            parameters: {'address': address, 'customerId': customerId},
          );
        } catch (e) {
          logger.w('Address sütunu bulunamadı, güncellenmedi: $e');
        }
      }

      logger.i('Customer ID $customerId profil bilgileri güncellendi');
      return true;
    } catch (e) {
      logger.e('Customer profil güncelleme hatası.', error: e);
      return false;
    } finally {
      await connection?.close();
    }
  }

  // Customer şifre güncelleme
  static Future<bool> updateCustomerPassword(
    int customerId,
    String newPassword,
  ) async {
    if (_isWebPlatform) {
      logger.w('Web platformunda veritabanı işlemleri desteklenmez.');
      return false;
    }

    Connection? connection;
    try {
      connection = await _connect();

      await connection.execute(
        Sql.named(
          'UPDATE customer SET password = @password WHERE customerid = @customerId',
        ),
        parameters: {'password': newPassword, 'customerId': customerId},
      );

      logger.i('Customer ID $customerId şifresi güncellendi');
      return true;
    } catch (e) {
      logger.e('Customer şifre güncelleme hatası.', error: e);
      return false;
    } finally {
      await connection?.close();
    }
  }

  static Future<List<Customer>> getCustomers() async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo veriler döndürülüyor.',
      );
      return _getDemoCustomers();
    }

    Connection? connection;
    try {
      connection = await _connect();

      var results = await connection.execute(
        'SELECT customerid, firstname, lastname, email, isactive FROM customer WHERE isactive = true ORDER BY firstname',
      );

      List<Customer> customers = results.map((row) {
        return Customer(
          customerId: row[0] as int? ?? 0,
          firstName: row[1] as String? ?? '',
          lastName: row[2] as String? ?? '',
          email: row[3] as String? ?? '',
          phone: '', // Veritabanında phone sütunu yok
          address: '', // Veritabanında address sütunu yok
          birthDate: null, // Veritabanında birthdate sütunu yok
          gender: null, // Veritabanında gender sütunu yok
          createdAt: DateTime.now(),
          isActive: row[4] as bool? ?? true,
        );
      }).toList();

      return customers;
    } catch (e) {
      logger.e('Müşteri listesi çekme hatası.', error: e);
      return _getDemoCustomers();
    } finally {
      await connection?.close();
    }
  }

  static Future<bool> createCustomer(Customer customer, String password) async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo işlem yapılıyor.',
      );
      return true;
    }

    Connection? connection;
    try {
      connection = await _connect();

      await connection.execute(
        Sql.named(
          'INSERT INTO customer (firstname, lastname, email, password, isactive) '
          'VALUES (@firstName, @lastName, @email, @password, @isActive)',
        ),
        parameters: {
          'firstName': customer.firstName,
          'lastName': customer.lastName,
          'email': customer.email,
          'password': password,
          'isActive': customer.isActive,
        },
      );

      return true;
    } catch (e) {
      logger.e('Müşteri oluşturma hatası.', error: e);
      return false;
    } finally {
      await connection?.close();
    }
  }

  // === EMPLOYEE PERFORMANCE İŞLEMLERİ ===

  static Future<List<EmployeePerformance>> getEmployeePerformance(
    DateTime date,
  ) async {
    if (_isWebPlatform) {
      logger.w(
        'Web platformunda veritabanı işlemleri desteklenmez. Demo veriler döndürülüyor.',
      );
      return _getDemoEmployeePerformance();
    }

    Connection? connection;
    try {
      connection = await _connect();

      var results = await connection.execute(
        Sql.named(
          'SELECT employeename, dailyearnings, efficiency, date, appointmentscompleted, averagerating '
          'FROM employeeperformance WHERE DATE(date) = DATE(@date) ORDER BY dailyearnings DESC',
        ),
        parameters: {'date': date},
      );

      List<EmployeePerformance> performances = results.map((row) {
        // dailyearnings String olarak geliyor, double'a çevir
        double dailyEarnings = 0.0;
        try {
          if (row[1] is String) {
            dailyEarnings = double.parse(row[1] as String);
          } else if (row[1] is num) {
            dailyEarnings = (row[1] as num).toDouble();
          }
        } catch (e) {
          logger.w('Daily earnings parse hatası: ${row[1]}');
          dailyEarnings = 0.0;
        }

        // efficiency String olarak geliyor, double'a çevir
        double efficiency = 0.0;
        try {
          if (row[2] is String) {
            efficiency = double.parse(row[2] as String);
          } else if (row[2] is num) {
            efficiency = (row[2] as num).toDouble();
          }
        } catch (e) {
          logger.w('Efficiency parse hatası: ${row[2]}');
          efficiency = 0.0;
        }

        // averagerating String olarak geliyor, double'a çevir
        double averageRating = 0.0;
        try {
          if (row[5] is String) {
            averageRating = double.parse(row[5] as String);
          } else if (row[5] is num) {
            averageRating = (row[5] as num).toDouble();
          }
        } catch (e) {
          logger.w('Average rating parse hatası: ${row[5]}');
          averageRating = 0.0;
        }

        return EmployeePerformance(
          employeeName: row[0] as String? ?? 'Bilinmeyen',
          dailyEarnings: dailyEarnings,
          totalEarnings: dailyEarnings, // Şimdilik dailyEarnings ile aynı
          efficiency: efficiency,
          date: row[3] as DateTime? ?? DateTime.now(),
          appointmentsCompleted: row[4] as int? ?? 0,
          averageRating: averageRating,
        );
      }).toList();

      return performances;
    } catch (e) {
      logger.e('Çalışan performans listesi çekme hatası.', error: e);
      return _getDemoEmployeePerformance();
    } finally {
      await connection?.close();
    }
  }

  // === DEMO VERİLER (Web platformu için) ===

  static List<Service> _getDemoServices() {
    return [
      Service(
        serviceId: 1,
        serviceName: 'Saç Kesimi',
        serviceDuration: 30,
        servicePrice: 1500.0,
        description: 'Profesyonel saç kesimi ve şekillendirme',
        imageUrl: 'assets/services/hair.jpg',
        category: 'Saç',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
        updatedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Service(
        serviceId: 2,
        serviceName: 'Saç Boyama',
        serviceDuration: 60,
        servicePrice: 2600.0,
        description: 'Kalıcı saç boyama ve renk değişimi',
        imageUrl: 'assets/services/hair.jpg',
        category: 'Saç',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
        updatedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Service(
        serviceId: 3,
        serviceName: 'Makyaj',
        serviceDuration: 30,
        servicePrice: 3200.0,
        description: 'Günlük ve özel gün makyajı',
        imageUrl: 'assets/services/makeup.jpg',
        category: 'Makyaj',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
        updatedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Service(
        serviceId: 4,
        serviceName: 'Cilt Bakımı',
        serviceDuration: 45,
        servicePrice: 5000.0,
        description: 'Derin temizlik ve nemlendirme',
        imageUrl: 'assets/services/skincare.jpg',
        category: 'Cilt Bakımı',
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
        updatedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ];
  }

  static List<Employee> _getDemoEmployees() {
    return [
      Employee(
        id: 1,
        firstName: 'Fatma',
        lastName: 'Demir',
        skills: 'Saç kesimi, boyama, şekillendirme',
        expertise: 'Saç',
        phone: '0532 111 2222',
        email: 'fatma@salon.com',
        isActive: true,
        hireDate: DateTime.now().subtract(const Duration(days: 365)),
        profileImage: null,
      ),
      Employee(
        id: 2,
        firstName: 'Ali',
        lastName: 'Özkan',
        skills: 'Sakal tıraşı, cilt bakımı',
        expertise: 'Cilt Bakımı',
        phone: '0533 333 4444',
        email: 'ali@salon.com',
        isActive: true,
        hireDate: DateTime.now().subtract(const Duration(days: 180)),
        profileImage: null,
      ),
      Employee(
        id: 3,
        firstName: 'Zeynep',
        lastName: 'Kaya',
        skills: 'Makyaj, cilt bakımı',
        expertise: 'Makyaj',
        phone: '0534 555 6666',
        email: 'zeynep@salon.com',
        isActive: true,
        hireDate: DateTime.now().subtract(const Duration(days: 90)),
        profileImage: null,
      ),
    ];
  }

  static List<Appointment> _getDemoAppointments() {
    return [
      Appointment(
        appointmentId: 1,
        customerName: 'Ayşe Yılmaz',
        employeeName: 'Fatma Demir',
        serviceName: 'Saç Kesimi',
        process: 'Tamamlandı',
        totalPrice: 1500.0,
        appointmentDateTime: DateTime.now().subtract(const Duration(hours: 2)),
        approvalStatus: 'Approved',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        notes: 'Müşteri memnun kaldı',
        customerPhone: '0555 123 4567',
        customerEmail: 'ayse@email.com',
      ),
      Appointment(
        appointmentId: 2,
        customerName: 'Mehmet Kaya',
        employeeName: 'Ali Özkan',
        serviceName: 'Sakal Tıraşı',
        process: 'Bekliyor',
        totalPrice: 80.0,
        appointmentDateTime: DateTime.now().add(const Duration(hours: 1)),
        approvalStatus: 'Pending',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
        notes: 'Özel istekler var',
        customerPhone: '0532 987 6543',
        customerEmail: 'mehmet@email.com',
      ),
      // Test için ek randevular
      Appointment(
        appointmentId: 3,
        customerName: 'Test User',
        employeeName: 'Fatma Demir',
        serviceName: 'Saç Boyama',
        process: 'Bekliyor',
        totalPrice: 200.0,
        appointmentDateTime: DateTime.now().add(const Duration(days: 1)),
        approvalStatus: 'Pending',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        notes: 'Test randevusu',
        customerPhone: '0555 999 8888',
        customerEmail: 'test@email.com',
      ),
    ];
  }

  static List<Customer> _getDemoCustomers() {
    return [
      Customer(
        customerId: 1,
        firstName: 'Ayşe',
        lastName: 'Yılmaz',
        email: 'ayse@email.com',
        phone: '0555 123 4567',
        address: 'İstanbul, Türkiye',
        birthDate: DateTime(1990, 5, 15),
        gender: 'Kadın',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        isActive: true,
      ),
      Customer(
        customerId: 2,
        firstName: 'Mehmet',
        lastName: 'Kaya',
        email: 'mehmet@email.com',
        phone: '0532 987 6543',
        address: 'Ankara, Türkiye',
        birthDate: DateTime(1985, 8, 22),
        gender: 'Erkek',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        isActive: true,
      ),
    ];
  }

  static List<EmployeePerformance> _getDemoEmployeePerformance() {
    return [
      EmployeePerformance(
        employeeName: 'Fatma Demir',
        dailyEarnings: 450.0,
        totalEarnings: 1350.0,
        efficiency: 85.5,
        date: DateTime.now(),
        appointmentsCompleted: 6,
        averageRating: 4.8,
      ),
      EmployeePerformance(
        employeeName: 'Ali Özkan',
        dailyEarnings: 320.0,
        totalEarnings: 960.0,
        efficiency: 78.2,
        date: DateTime.now(),
        appointmentsCompleted: 4,
        averageRating: 4.6,
      ),
      EmployeePerformance(
        employeeName: 'Zeynep Kaya',
        dailyEarnings: 380.0,
        totalEarnings: 1140.0,
        efficiency: 82.1,
        date: DateTime.now(),
        appointmentsCompleted: 5,
        averageRating: 4.7,
      ),
    ];
  }

  // === SUPABASE ENTEGRASYONU ===
  // Not: Aşağıdaki metodlar Supabase RLS ve politikalarınıza göre çalışır.
  // Yazma işlemleri için kullanıcı oturumunun admin/editor rolüne sahip olması gerekir.

  // Supabase randevu çakışma kontrolü
  static Future<bool> hasSupabaseAppointmentConflict(
    DateTime appointmentDateTime,
    String employeeId,
    String? serviceId, {
    String? excludeAppointmentId,
  }) async {
    try {
      final client = _supabase;
      final isletmeId = await resolveIsletmeId();
      if (isletmeId == null) return false;

      // Hizmet süresini al (varsayılan 30 dakika)
      int serviceDuration = 30;
      if (serviceId != null) {
        try {
          final serviceData = await client
              .from('menu_hizmet_icerigi')
              .select('sure_dk')
              .eq('isletme_id', isletmeId)
              .eq('hizmet', serviceId)
              .maybeSingle();

          if (serviceData != null && serviceData['sure_dk'] != null) {
            serviceDuration = (serviceData['sure_dk'] as num).toInt();
          }
        } catch (_) {
          // Hizmet süresi alınamazsa varsayılan değer kullan
        }
      }

      // Yeni randevunun başlangıç ve bitiş zamanı (UTC)
      final DateTime newStart = appointmentDateTime.toUtc();
      final DateTime newEnd = newStart.add(Duration(minutes: serviceDuration));

      // Aynı çalışanın gün içindeki randevularını, hizmet süreleriyle birlikte çek
      final DateTime dayStart = DateTime.utc(
        newStart.year,
        newStart.month,
        newStart.day,
        0,
        0,
        0,
      );
      final DateTime dayEnd = DateTime.utc(
        newStart.year,
        newStart.month,
        newStart.day,
        23,
        59,
        59,
      );

      final List existing = await client
          .from('randevu')
          .select('appointment_datetime, hizmet_id')
          .eq('isletme_id', isletmeId)
          .eq('calisan_id', employeeId)
          .neq(
            'randevu_id',
            excludeAppointmentId ?? '00000000-0000-0000-0000-000000000000',
          )
          .neq('approval_status', 'Cancelled')
          .neq('approval_status', 'Canceled')
          .gte('appointment_datetime', dayStart.toIso8601String())
          .lte('appointment_datetime', dayEnd.toIso8601String())
          .order('appointment_datetime');

      // Hizmet sürelerini önbelleğe al
      final Map<String, int> serviceDurationById = {};

      bool overlaps = false;
      for (final row in existing) {
        final DateTime existingStart = DateTime.parse(
          row['appointment_datetime'] as String,
        ).toUtc();
        int existingDuration = 30;
        final String? existingServiceId = row['hizmet_id'] as String?;
        if (existingServiceId != null) {
          if (!serviceDurationById.containsKey(existingServiceId)) {
            try {
              final data = await client
                  .from('menu_hizmet_icerigi')
                  .select('sure_dk')
                  .eq('menu_hizmet_icerigi_id', existingServiceId)
                  .maybeSingle();
              existingDuration = (data?['sure_dk'] as num?)?.toInt() ?? 30;
              serviceDurationById[existingServiceId] = existingDuration;
            } catch (_) {
              serviceDurationById[existingServiceId] = 30;
              existingDuration = 30;
            }
          } else {
            existingDuration = serviceDurationById[existingServiceId] ?? 30;
          }
        }

        final DateTime existingEnd = existingStart.add(
          Duration(minutes: existingDuration),
        );

        // Örtüşme: existingStart < newEnd && existingEnd > newStart
        if (existingStart.isBefore(newEnd) && existingEnd.isAfter(newStart)) {
          overlaps = true;
          break;
        }
      }

      if (overlaps) {
        logger.w(
          'Supabase randevu çakışması bulundu: Employee ID: $employeeId, Yeni: $newStart-$newEnd',
        );
      }

      return overlaps;
    } catch (e) {
      logger.e('Supabase randevu çakışma kontrolü hatası.', error: e);
      return false;
    }
  }

  // Müsait saatleri getir - Çakışma olmayan zaman dilimleri
  static Future<List<TimeOfDay>> getAvailableTimeSlots(
    DateTime date,
    String employeeId,
    String serviceName, {
    String? excludeAppointmentId,
  }) async {
    try {
      final client = _supabase;
      final isletmeId = await resolveIsletmeId();
      if (isletmeId == null) return [];

      // Hizmet süresini al
      int serviceDuration = 30; // Varsayılan 30 dakika
      try {
        final serviceData = await client
            .from('menu_hizmet_icerigi')
            .select('sure_dk')
            .eq('isletme_id', isletmeId)
            .eq('hizmet', serviceName)
            .maybeSingle();

        if (serviceData != null && serviceData['sure_dk'] != null) {
          serviceDuration = (serviceData['sure_dk'] as num).toInt();
        }
      } catch (_) {
        // Hizmet süresi alınamazsa varsayılan değer kullan
      }

      // Çalışma saatleri (09:00 - 18:00)
      final startHour = 9;
      final endHour = 18;
      final slotDuration = 30; // 30 dakikalık slotlar

      // O günkü mevcut randevuları al
      final dayStart = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final existingAppointments = await client
          .from('randevu')
          .select('appointment_datetime, process')
          .eq('isletme_id', isletmeId)
          .eq('calisan_id', employeeId)
          .neq('randevu_id', excludeAppointmentId ?? '')
          .neq('approval_status', 'Cancelled')
          .neq('approval_status', 'Canceled')
          .gte('appointment_datetime', dayStart.toIso8601String())
          .lte('appointment_datetime', dayEnd.toIso8601String())
          .order('appointment_datetime');

      // Mevcut randevuları işle
      final List<Map<String, DateTime>> busySlots = [];
      for (final appointment in existingAppointments as List) {
        final appointmentTime = DateTime.parse(
          appointment['appointment_datetime'],
        );
        final process = appointment['process'] as int? ?? 0;

        // Sadece aktif/onaylanmış randevuları dikkate al
        if (process == 0 || process == 1) {
          // 0: Bekliyor, 1: Devam Ediyor
          // Hizmet süresini bul (varsayılan 30 dakika)
          int appointmentServiceDuration = 30;
          try {
            final serviceData = await client
                .from('menu_hizmet_icerigi')
                .select('sure_dk')
                .eq('isletme_id', isletmeId)
                .eq('hizmet', serviceName)
                .maybeSingle();

            if (serviceData != null && serviceData['sure_dk'] != null) {
              appointmentServiceDuration = (serviceData['sure_dk'] as num)
                  .toInt();
            }
          } catch (_) {}

          final appointmentEnd = appointmentTime.add(
            Duration(minutes: appointmentServiceDuration),
          );
          busySlots.add({'start': appointmentTime, 'end': appointmentEnd});
        }
      }

      // Müsait saatleri hesapla
      final List<TimeOfDay> availableSlots = [];

      for (int hour = startHour; hour < endHour; hour++) {
        for (int minute = 0; minute < 60; minute += slotDuration) {
          final slotStart = DateTime(
            date.year,
            date.month,
            date.day,
            hour,
            minute,
          );
          final slotEnd = slotStart.add(Duration(minutes: serviceDuration));

          // Bu slot müsait mi kontrol et
          bool isAvailable = true;
          for (final busySlot in busySlots) {
            if (slotStart.isBefore(busySlot['end']!) &&
                slotEnd.isAfter(busySlot['start']!)) {
              isAvailable = false;
              break;
            }
          }

          if (isAvailable) {
            availableSlots.add(TimeOfDay(hour: hour, minute: minute));
          }
        }
      }

      logger.i('Müsait saatler bulundu: ${availableSlots.length} slot');
      return availableSlots;
    } catch (e) {
      logger.e('Müsait saat hesaplama hatası.', error: e);
      return [];
    }
  }

  // Müşteri çakışması kontrolü - customerId ile (önerilen)
  static Future<bool> hasCustomerConflictById(
    DateTime appointmentDateTime,
    int customerId,
    String serviceName, {
    String? excludeAppointmentId,
  }) async {
    try {
      final client = _supabase;
      final isletmeId = await resolveIsletmeId();
      if (isletmeId == null) return false;

      // Yeni randevunun süresi
      int newDuration = 30;
      try {
        final serviceData = await client
            .from('menu_hizmet_icerigi')
            .select('sure_dk')
            .eq('isletme_id', isletmeId)
            .eq('hizmet', serviceName)
            .maybeSingle();
        if (serviceData != null && serviceData['sure_dk'] != null) {
          newDuration = (serviceData['sure_dk'] as num).toInt();
        }
      } catch (_) {}

      final DateTime newStart = appointmentDateTime.toUtc();
      final DateTime newEnd = newStart.add(Duration(minutes: newDuration));

      // Aynı gün içindeki mevcut randevular (iptaller hariç)
      final DateTime dayStart = DateTime.utc(
        newStart.year,
        newStart.month,
        newStart.day,
        0,
        0,
        0,
      );
      final DateTime dayEnd = DateTime.utc(
        newStart.year,
        newStart.month,
        newStart.day,
        23,
        59,
        59,
      );

      final List existing = await client
          .from('randevu')
          .select('appointment_datetime, hizmet_id')
          .eq('isletme_id', isletmeId)
          .eq('customerid', customerId)
          .neq(
            'randevu_id',
            excludeAppointmentId ?? '00000000-0000-0000-0000-000000000000',
          )
          .neq('approval_status', 'Cancelled')
          .neq('approval_status', 'Canceled')
          .gte('appointment_datetime', dayStart.toIso8601String())
          .lte('appointment_datetime', dayEnd.toIso8601String())
          .order('appointment_datetime');

      final Map<String, int> serviceDurationById = {};

      for (final row in existing) {
        final DateTime existingStart = DateTime.parse(
          row['appointment_datetime'] as String,
        ).toUtc();
        int existingDuration = 30;
        final String? existingServiceId = row['hizmet_id'] as String?;
        if (existingServiceId != null) {
          if (!serviceDurationById.containsKey(existingServiceId)) {
            try {
              final data = await client
                  .from('menu_hizmet_icerigi')
                  .select('sure_dk')
                  .eq('menu_hizmet_icerigi_id', existingServiceId)
                  .maybeSingle();
              existingDuration = (data?['sure_dk'] as num?)?.toInt() ?? 30;
              serviceDurationById[existingServiceId] = existingDuration;
            } catch (_) {
              existingDuration = 30;
              serviceDurationById[existingServiceId] = 30;
            }
          } else {
            existingDuration = serviceDurationById[existingServiceId] ?? 30;
          }
        }
        final DateTime existingEnd = existingStart.add(
          Duration(minutes: existingDuration),
        );

        if (existingStart.isBefore(newEnd) && existingEnd.isAfter(newStart)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      logger.e('Müşteri çakışma kontrolü (ID) hatası.', error: e);
      return false;
    }
  }

  // İŞLETME OKUMA
  static Future<List<Map<String, dynamic>>> getIsletmeler({String? tip}) async {
    try {
      final query = _supabase.from('isletme').select();
      final data = tip != null ? await query.eq('tip', tip) : await query;
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      logger.e('getIsletmeler hatası', error: e);
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getIsletmeById(String isletmeId) async {
    try {
      final data = await _supabase
          .from('isletme')
          .select()
          .eq('isletme_id', isletmeId)
          .maybeSingle();
      if (data == null) return null;
      return Map<String, dynamic>.from(data);
    } catch (e) {
      logger.e('getIsletmeById hatası', error: e);
      return null;
    }
  }

  // MENÜ / HİZMET / RESİM OKUMA
  static Future<List<Map<String, dynamic>>> getMenuIcerik(
    String isletmeId,
  ) async {
    try {
      final data = await _supabase
          .from('menu_icerik')
          .select()
          .eq('isletme_id', isletmeId)
          .eq('aktif', true)
          .order('sira', ascending: true);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      logger.e('getMenuIcerik hatası', error: e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getHizmetIcerik(
    String isletmeId,
  ) async {
    try {
      final data = await _supabase
          .from('hizmet_icerik')
          .select()
          .eq('isletme_id', isletmeId)
          .eq('aktif', true)
          .order('sira', ascending: true);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      logger.e('getHizmetIcerik hatası', error: e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getMenuHizmetIcerigi(
    String isletmeId,
  ) async {
    try {
      final data = await _supabase
          .from('menu_hizmet_icerigi')
          .select()
          .eq('isletme_id', isletmeId)
          .eq('aktif', true)
          .order('sira', ascending: true);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      logger.e('getMenuHizmetIcerigi hatası', error: e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getIsletmeResimleri(
    String isletmeId,
  ) async {
    try {
      final data = await _supabase
          .from('isletme_galeri_fotograflari')
          .select()
          .eq('isletme_id', isletmeId)
          .order('sira', ascending: true)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      logger.e(
        'getIsletmeResimleri hatası (isletme_galeri_fotograflari tablosu)',
        error: e,
      );
      return [];
    }
  }

  static String getPublicImageUrl(String path) {
    return _supabase.storage.from('isletme').getPublicUrl(path);
  }

  // İŞLETME ID ÇÖZÜMLEME: Önce auth.uid() ile isletme_kullanici'dan, yoksa tip'e göre ilk yayındaki işletme
  static Future<String?> resolveIsletmeId({String tip = 'gym'}) async {
    try {
      String? resolvedId;

      // 1) Opsiyonel kullanıcı-işletme eşlemesi (tablo yoksa sessizce atla)
      final user = _supabase.auth.currentUser;

      if (user != null) {
        try {
          final rows = await _supabase
              .from('isletme_kullanici')
              .select('isletme_id')
              .eq('user_id', user.id)
              .limit(1);
          if (rows.isNotEmpty) {
            final id = rows.first['isletme_id'] as String?;
            if (id != null && id.isNotEmpty) {
              resolvedId = id;
            }
          }
        } catch (e) {
          // Tablo yok veya erişim yok: görmezden gel ve fallback'e devam et
        }
      }

      // 2) Tip + yayında filtreli fallback
      if (resolvedId == null) {
        try {
          final fallback = await _supabase
              .from('isletme')
              .select('isletme_id')
              .eq('tip', tip)
              .order('created_at', ascending: true)
              .limit(1);
          if (fallback.isNotEmpty) {
            resolvedId = fallback.first['isletme_id'] as String?;
          }
        } catch (e) {
          // ignore and continue to last fallback
        }
      }

      // 3) Herhangi bir isletme (son çare)
      if (resolvedId == null) {
        try {
          final any = await _supabase
              .from('isletme')
              .select('isletme_id')
              .limit(1);
          if (any.isNotEmpty) {
            resolvedId = any.first['isletme_id'] as String?;
          }
        } catch (e) {
          // Tablo bulunamaması veya erişim hatası durumunda sessizce devam et
          logger.w('isletme fallback ararken hata oluştu', error: e);
        }
      }

      return resolvedId;
    } catch (e) {
      logger.e('resolveIsletmeId hatası: $e');
      return null;
    }
  }

  // TEAM ÜYELERİ
  static Future<List<Map<String, dynamic>>> getTeamUyesi(
    String isletmeId,
  ) async {
    try {
      final data = await _supabase
          .from('calisanlar')
          .select()
          .eq('isletme_id', isletmeId)
          .order('sira', ascending: true)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      logger.e('getTeamUyesi hatası (calisanlar tablosu)', error: e);
      return [];
    }
  }

  // ETKİNLİKLER
  static Future<List<Map<String, dynamic>>> getEtkinlikler(
    String isletmeId,
  ) async {
    try {
      final data = await _supabase
          .from('etkinlik')
          .select()
          .eq('isletme_id', isletmeId)
          .eq('aktif', true)
          .order('sira', ascending: true)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      logger.e('getEtkinlikler hatası (etkinlik tablosu)', error: e);
      return [];
    }
  }

  // İÇERİK BLOKLARI harita olarak - Birden fazla tablodan veri çek
  static Future<Map<String, String>> getIcerikBlokMap(String isletmeId) async {
    try {
      final Map<String, String> map = {};

      // Neden bizi seçmelisiniz bölümü
      try {
        final nedeniSecmelisinizData = await _supabase
            .from('neden_bizi_secmelisiniz_bolumu')
            .select('anahtar, deger')
            .eq('isletme_id', isletmeId)
            .order('sira', ascending: true);

        final List list1 = (nedeniSecmelisinizData as List?) ?? const [];
        for (final item in list1) {
          final row = item as Map<String, dynamic>;
          final key = row['anahtar'] as String?;
          final val = row['deger'] as String?;
          if (key != null && key.isNotEmpty) {
            map[key] = val ?? '';
          }
        }
      } catch (e) {
        logger.w('neden_bizi_secmelisiniz_bolumu tablosu hatası: $e');
      }

      // Hakkımızda bölümü
      try {
        final hakkimizdaData = await _supabase
            .from('hakkimizda_bolumu')
            .select('anahtar, deger')
            .eq('isletme_id', isletmeId)
            .order('sira', ascending: true);

        final List list2 = (hakkimizdaData as List?) ?? const [];
        for (final item in list2) {
          final row = item as Map<String, dynamic>;
          final key = row['anahtar'] as String?;
          final val = row['deger'] as String?;
          if (key != null && key.isNotEmpty) {
            map[key] = val ?? '';
          }
        }
      } catch (e) {
        logger.w('hakkimizda_bolumu tablosu hatası: $e');
      }

      return map;
    } catch (e) {
      logger.e('getIcerikBlokMap hatası (içerik blok tabloları)', error: e);

      return {};
    }
  }

  // === ADMIN CRUD ===

  // CUSTOMER CRUD (Supabase)
  static Future<bool> updateSupabaseCustomerProfile(
    String customerId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _supabase
          .from('musteriler')
          .update(updates)
          .eq('customerid', customerId);
      return true;
    } catch (e) {
      logger.e('updateSupabaseCustomerProfile hatası', error: e);
      return false;
    }
  }

  static Future<bool> updateSupabaseCustomerPassword(
    String customerId,
    String newPassword,
  ) async {
    try {
      await _supabase
          .from('musteriler')
          .update({'password': newPassword})
          .eq('customerid', customerId);
      return true;
    } catch (e) {
      logger.e('updateSupabaseCustomerPassword hatası', error: e);
      return false;
    }
  }

  // İŞLETME CRUD
  static Future<Map<String, dynamic>?> createIsletme(
    Map<String, dynamic> payload,
  ) async {
    try {
      final inserted = await _supabase
          .from('isletme')
          .insert(payload)
          .select()
          .maybeSingle();
      return inserted == null ? null : Map<String, dynamic>.from(inserted);
    } catch (e) {
      logger.e('createIsletme hatası', error: e);
      return null;
    }
  }

  static Future<bool> updateIsletme(
    String isletmeId,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _supabase
          .from('isletme')
          .update(payload)
          .eq('isletme_id', isletmeId);
      return true;
    } catch (e) {
      logger.e('updateIsletme hatası', error: e);
      return false;
    }
  }

  static Future<bool> deleteIsletme(String isletmeId) async {
    try {
      await _supabase.from('isletme').delete().eq('isletme_id', isletmeId);
      return true;
    } catch (e) {
      logger.e('deleteIsletme hatası', error: e);
      return false;
    }
  }

  // MENÜ ICERIK CRUD
  static Future<Map<String, dynamic>?> createMenuItem(
    String isletmeId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final inserted = await _supabase
          .from('menu_icerik')
          .insert({...payload, 'isletme_id': isletmeId})
          .select()
          .maybeSingle();
      return inserted == null ? null : Map<String, dynamic>.from(inserted);
    } catch (e) {
      logger.e('createMenuItem hatası', error: e);
      return null;
    }
  }

  static Future<bool> updateMenuItem(
    String menuId,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _supabase.from('menu_icerik').update(payload).eq('menu_id', menuId);
      return true;
    } catch (e) {
      logger.e('updateMenuItem hatası', error: e);
      return false;
    }
  }

  static Future<bool> deleteMenuItem(String menuId) async {
    try {
      await _supabase.from('menu_icerik').delete().eq('menu_id', menuId);
      return true;
    } catch (e) {
      logger.e('deleteMenuItem hatası', error: e);
      return false;
    }
  }

  // HİZMET ICERIK CRUD
  static Future<Map<String, dynamic>?> createHizmetItem(
    String isletmeId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final inserted = await _supabase
          .from('hizmet_icerik')
          .insert({...payload, 'isletme_id': isletmeId})
          .select()
          .maybeSingle();
      return inserted == null ? null : Map<String, dynamic>.from(inserted);
    } catch (e) {
      logger.e('createHizmetItem hatası', error: e);
      return null;
    }
  }

  static Future<bool> updateHizmetItem(
    String hizmetId,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _supabase
          .from('hizmet_icerik')
          .update(payload)
          .eq('hizmet_id', hizmetId);
      return true;
    } catch (e) {
      logger.e('updateHizmetItem hatası', error: e);
      return false;
    }
  }

  static Future<bool> deleteHizmetItem(String hizmetId) async {
    try {
      await _supabase.from('hizmet_icerik').delete().eq('hizmet_id', hizmetId);
      return true;
    } catch (e) {
      logger.e('deleteHizmetItem hatası', error: e);
      return false;
    }
  }

  // İŞLETME RESİM CRUD
  static Future<Map<String, dynamic>?> addIsletmeResim(
    String isletmeId,
    String resimUrl, {
    int? sira,
    String? aciklama,
  }) async {
    try {
      final inserted = await _supabase
          .from('isletme_resim')
          .insert({
            'isletme_id': isletmeId,
            'resim_url': resimUrl,
            if (sira != null) 'sira': sira,
            if (aciklama != null) 'aciklama': aciklama,
          })
          .select()
          .maybeSingle();
      return inserted == null ? null : Map<String, dynamic>.from(inserted);
    } catch (e) {
      logger.e('addIsletmeResim hatası', error: e);
      return null;
    }
  }

  static Future<bool> deleteIsletmeResim(String resimId) async {
    try {
      await _supabase.from('isletme_resim').delete().eq('resim_id', resimId);
      return true;
    } catch (e) {
      logger.e('deleteIsletmeResim hatası', error: e);
      return false;
    }
  }

  // STORAGE YÜKLEME
  static Future<String?> uploadIsletmeImage({
    required String isletmeId,
    required Uint8List fileBytes,
    required String fileName,
    required String contentType,
    String folder = 'galeri',
  }) async {
    try {
      final uuid = const Uuid().v4();
      final path = folder.isEmpty
          ? '$isletmeId/$fileName'
          : folder == 'galeri'
          ? '$isletmeId/galeri/$uuid-$fileName'
          : '$isletmeId/$folder/$fileName';
      await _supabase.storage
          .from('isletme')
          .uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return _supabase.storage.from('isletme').getPublicUrl(path);
    } catch (e) {
      logger.e('uploadIsletmeImage hatası', error: e);
      return null;
    }
  }

  // Supabase'de randevu oluştur
  static Future<bool> createSupabaseAppointment(
    Appointment appointment,
    String isletmeId,
  ) async {
    try {
      final client = _supabase;

      logger.i(
        'Supabase randevu oluşturma başladı: ${appointment.customerEmail}',
      );

      // Önce customer ID'yi bul veya oluştur
      int customerId;
      try {
        final customerResult = await client
            .from('musteriler')
            .select('customerid')
            .eq('email', appointment.customerEmail ?? '')
            .maybeSingle();

        if (customerResult != null) {
          customerId = (customerResult['customerid'] as num?)?.toInt() ?? 0;
          logger.i('Mevcut müşteri bulundu: $customerId');
        } else {
          // Yeni müşteri oluştur
          final customerName = appointment.customerName;
          final nameParts = customerName.split(' ');
          final firstName = nameParts.isNotEmpty ? nameParts.first : '';
          final lastName = nameParts.length > 1
              ? nameParts.skip(1).join(' ')
              : '';

          final newCustomer = await client
              .from('musteriler')
              .insert({
                'firstname': firstName,
                'lastname': lastName,
                'email': appointment.customerEmail ?? '',
                'phone': appointment.customerPhone ?? '',
                'isactive': true,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .select('customerid')
              .single();

          customerId = (newCustomer['customerid'] as num?)?.toInt() ?? 0;
          logger.i('Yeni müşteri oluşturuldu: $customerId');
        }
      } catch (e) {
        logger.e('Müşteri işlemi hatası', error: e);
        return false;
      }

      // Employee ID'yi bul (Ad + Soyad ayrıştırma ile)
      int employeeId;
      try {
        final fullName = appointment.employeeName.trim();
        final parts = fullName
            .split(' ')
            .where((p) => p.trim().isNotEmpty)
            .toList();
        final first = parts.isNotEmpty ? parts.first : fullName;
        final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        Map<String, dynamic>? emp;
        if (last.isNotEmpty) {
          emp = await client
              .from('calisanlar')
              .select('id')
              .eq('aktif', true)
              .eq('ad', first)
              .eq('soyad', last)
              .maybeSingle();
        }
        emp ??= await client
            .from('calisanlar')
            .select('id')
            .eq('aktif', true)
            .ilike('ad', '%$first%')
            .maybeSingle();

        if (emp == null) {
          logger.e('Çalışan bulunamadı: ${appointment.employeeName}');
          return false;
        }
        employeeId = (emp['id'] as num?)?.toInt() ?? 0;
        logger.i('Çalışan bulundu: $employeeId');
      } catch (e) {
        logger.e('Çalışan arama hatası', error: e);
        return false;
      }

      // Hizmet fiyatını al
      double servicePrice = 0.0;
      try {
        final serviceResult = await client
            .from('menu_hizmet_icerigi')
            .select('fiyat')
            .eq('isletme_id', isletmeId)
            .eq('hizmet', appointment.serviceName)
            .eq('aktif', true)
            .maybeSingle();

        if (serviceResult != null) {
          servicePrice = (serviceResult['fiyat'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (e) {
        logger.w(
          'Hizmet fiyatı alınamadı, varsayılan değer kullanılıyor',
          error: e,
        );
      }

      // Randevu çakışma kontrolü
      bool hasConflict = await hasSupabaseAppointmentConflict(
        appointment.appointmentDateTime,
        employeeId.toString(),
        appointment.serviceName,
      );

      // Müşteri bazlı çakışma: aynı müşteri aynı anda iki randevu alamaz (customerId ile)
      bool hasCustomerOverlap = await hasCustomerConflictById(
        appointment.appointmentDateTime,
        customerId,
        appointment.serviceName,
      );

      if (hasConflict || hasCustomerOverlap) {
        logger.w('Supabase randevu çakışması tespit edildi!');
        throw Exception(
          'Seçilen tarih ve saatte başka bir randevu bulunmaktadır. Lütfen farklı bir zaman seçiniz.',
        );
      }

      // Hizmet UUID'ini bul (opsiyonel)
      String? hizmetUuid;
      try {
        final svc = await client
            .from('menu_hizmet_icerigi')
            .select('menu_hizmet_icerigi_id')
            .eq('isletme_id', isletmeId)
            .eq('hizmet', appointment.serviceName)
            .maybeSingle();
        hizmetUuid = svc?['menu_hizmet_icerigi_id'] as String?;
      } catch (_) {}

      // Randevu oluştur
      final appointmentData = await client
          .from('randevu')
          .insert({
            'isletme_id': isletmeId,
            'customerid': customerId,
            'calisan_id': employeeId,
            if (hizmetUuid != null) 'hizmet_id': hizmetUuid,
            'appointment_datetime': appointment.appointmentDateTime
                .toIso8601String(),
            'process': 0, // 0 = Bekliyor, 1 = Devam Ediyor, 2 = Tamamlandı
            'total_price': servicePrice,
            'notes': appointment.notes ?? '',
            'approval_status': 'Pending',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('randevu_id')
          .single();

      logger.i(
        'Supabase randevu başarıyla oluşturuldu: ${appointmentData['randevu_id']}',
      );
      return true;
    } catch (e) {
      logger.e('Supabase randevu oluşturma hatası', error: e);
      return false;
    }
  }

  // Belirli bir tarih için müsait saatleri bul - Sadece Dart kodu ile!
  static Future<List<DateTime>> getAvailableTimeSlotsForDate(
    DateTime date,
    int employeeId,
    int serviceId, {
    int startHour = 9,
    int endHour = 18,
  }) async {
    if (_isWebPlatform) {
      logger.w('Web platformunda veritabanı işlemleri desteklenmez.');
      return [];
    }

    try {
      // Hizmet süresi, iç çakışma kontrolünde hesaplandığından burada kullanılmıyor
      List<DateTime> availableSlots = [];

      // 2. Gün boyunca 30 dakikalık aralıklarla kontrol et
      DateTime currentTime = DateTime(
        date.year,
        date.month,
        date.day,
        startHour,
      );
      DateTime endTime = DateTime(date.year, date.month, date.day, endHour);

      // 3. Her 30 dakikada bir kontrol et
      while (currentTime.isBefore(endTime)) {
        // Bu saatte randevu var mı kontrol et
        bool hasConflict = await hasAppointmentConflict(
          currentTime,
          employeeId,
          serviceId,
        );

        if (!hasConflict) {
          availableSlots.add(currentTime);
        }

        // 30 dakika ilerle
        currentTime = currentTime.add(const Duration(minutes: 30));
      }

      logger.i('Müsait saatler bulundu: ${availableSlots.length} adet');
      return availableSlots;
    } catch (e) {
      logger.e('Müsait saat bulma hatası.', error: e);
      return [];
    }
  }

  // Randevu çakışma kontrolü için detaylı bilgi - Sadece Dart kodu ile!
  static Future<Map<String, dynamic>> getAppointmentConflictDetails(
    DateTime appointmentDateTime,
    int employeeId,
    int serviceId,
  ) async {
    if (_isWebPlatform) {
      logger.w('Web platformunda veritabanı işlemleri desteklenmez.');
      return {};
    }

    try {
      // 1. Hizmet süresini al
      int serviceDuration = await _getServiceDuration(serviceId);
      DateTime startTime = appointmentDateTime;
      DateTime endTime = appointmentDateTime.add(
        Duration(minutes: serviceDuration),
      );

      // 2. O çalışanın o gündeki tüm randevularını al
      List<Map<String, dynamic>> allAppointments =
          await _getEmployeeAppointmentsForDate(
            appointmentDateTime,
            employeeId,
            null,
          );

      // 3. Çakışan randevuları bul
      List<Map<String, dynamic>> conflicts = [];
      for (var appointment in allAppointments) {
        DateTime existingStart = appointment['appointmentDateTime'] as DateTime;
        int existingDuration = appointment['serviceDuration'] as int;
        DateTime existingEnd = existingStart.add(
          Duration(minutes: existingDuration),
        );

        // Çakışma kontrolü
        if (_isTimeConflict(startTime, endTime, existingStart, existingEnd)) {
          // Müşteri bilgisini al
          String customerName = await _getCustomerName(
            appointment['appointmentid'] as int,
          );

          conflicts.add({
            'appointmentId': appointment['appointmentid'],
            'appointmentDateTime': existingStart,
            'customerName': customerName,
            'serviceName': appointment['servicename'],
            'serviceDuration': existingDuration,
          });
        }
      }

      return {
        'hasConflict': conflicts.isNotEmpty,
        'conflicts': conflicts,
        'requestedStartTime': startTime,
        'requestedEndTime': endTime,
        'requestedServiceDuration': serviceDuration,
        'message': conflicts.isNotEmpty
            ? 'Seçilen saatte ${conflicts.length} adet çakışan randevu bulunmaktadır.'
            : 'Seçilen saatte çakışma bulunmamaktadır.',
      };
    } catch (e) {
      logger.e('Randevu çakışma detayları hatası.', error: e);
      return {'error': 'Hata oluştu: $e'};
    }
  }

  // Müşteri adını al
  static Future<String> _getCustomerName(int appointmentId) async {
    Connection? connection;
    try {
      connection = await _connect();

      var results = await connection.execute(
        '''
        SELECT c.firstname || ' ' || c.lastname as customer_name
        FROM appointments a
        JOIN customer c ON a.customerid = c.customerid
        WHERE a.appointmentid = @appointmentId
      ''',
        parameters: {'appointmentId': appointmentId},
      );

      if (results.isNotEmpty) {
        return results.first[0] as String;
      }
      return 'Bilinmeyen Müşteri';
    } finally {
      await connection?.close();
    }
  }
}
