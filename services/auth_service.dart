//import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:hairsalon_flutter/models/customer.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

final logger = Logger();

class AuthService {
  static const String _host = 'localhost';
  static const int _port = 5432;
  static const String _dbName = 'dbhairsalon';
  static const String _username = 'postgres';
  static const String _password = 'Kenan21.';

  // Veritabanı bağlantısı
  static Future<Connection> _connect() async {
    try {
      final endpoint = Endpoint(
        host: _host,
        port: _port,
        database: _dbName,
        username: _username,
        password: _password,
      );

      return await Connection.open(
        endpoint,
        settings: ConnectionSettings(sslMode: SslMode.disable),
      );
    } catch (e) {
      logger.e('Veritabanına bağlanılamadı.', error: e);
      rethrow;
    }
  }

  // === SUPABASE ADMIN AUTHENTICATION ===

  // Supabase admin girişi kontrolü
  static Future<bool> isSupabaseAdmin(String email, String password) async {
    try {
      // Supabase client'ı al
      final supabase = sb.Supabase.instance.client;

      // Email ve şifre ile giriş yap
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Kullanıcının admin rolünü kontrol et
        final userRole = await _checkUserRole(response.user!.id);
        return userRole == 'admin';
      }

      return false;
    } catch (e) {
      logger.e('Supabase admin girişi hatası.', error: e);
      return false;
    }
  }

  // Kullanıcının rolünü kontrol et
  static Future<String?> _checkUserRole(String userId) async {
    try {
      final supabase = sb.Supabase.instance.client;

      // isletme_kullanici tablosundan kullanıcının rolünü al
      final response = await supabase
          .from('isletme_kullanici')
          .select('rol')
          .eq('user_id', userId)
          .single();

      return response['rol'] as String?;
    } catch (e) {
      logger.e('Kullanıcı rolü kontrolü hatası.', error: e);
      return null;
    }
  }

  // === CUSTOMER AUTHENTICATION ===

  // Customer login
  static Future<Customer?> customerLogin(String email, String password) async {
    Connection? connection;
    try {
      logger.i('Customer girişi deneniyor: $email');
      connection = await _connect();
      logger.i('Veritabanına bağlanıldı');

      // Customer tablosundan email ve password kontrolü
      var results = await connection.execute(
        Sql.named(
          'SELECT customerid, firstname, lastname, email, isactive FROM customer WHERE email = @email AND password = @password AND isactive = true',
        ),
        parameters: {'email': email, 'password': password},
      );

      logger.i('Sorgu sonucu: ${results.length} satır bulundu');

      if (results.isNotEmpty) {
        final row = results.first;
        logger.i('Customer girişi başarılı: ${row[3]}'); // email alanı
        return Customer(
          customerId: row[0] as int,
          firstName: row[1] as String,
          lastName: row[2] as String,
          email: row[3] as String,
          phone: '', // Veritabanında phone sütunu yok
          address: '', // Veritabanında address sütunu yok
          birthDate: null, // Veritabanında birthdate sütunu yok
          gender: null, // Veritabanında gender sütunu yok
          createdAt: DateTime.now(),
          isActive: row[4] as bool,
        );
      }

      logger.w('Customer girişi başarısız: Geçersiz email veya şifre');
      return null; // Email veya password yanlış - giriş yapılamaz
    } catch (e) {
      logger.e('Customer login hatası.', error: e);
      return null;
    } finally {
      await connection?.close();
      logger.i('Veritabanı bağlantısı kapatıldı');
    }
  }

  // Customer'ı sadece email ile getir (şifre kontrolü yapmadan)
  static Future<Customer?> fetchCustomerByEmail(String email) async {
    Connection? connection;
    try {
      connection = await _connect();
      var results = await connection.execute(
        Sql.named(
          'SELECT customerid, firstname, lastname, email, isactive FROM customer WHERE email = @email LIMIT 1',
        ),
        parameters: {'email': email},
      );

      if (results.isEmpty) return null;
      final row = results.first;
      return Customer(
        customerId: row[0] as int,
        firstName: row[1] as String? ?? '',
        lastName: row[2] as String? ?? '',
        email: row[3] as String,
        phone: '',
        address: '',
        birthDate: null,
        gender: null,
        createdAt: DateTime.now(),
        isActive: (row[4] as bool?) ?? true,
      );
    } catch (e) {
      logger.e('fetchCustomerByEmail hatası', error: e);
      return null;
    } finally {
      await connection?.close();
    }
  }

  // === SUPABASE AUTH (EK) ===

  static sb.SupabaseClient get _supabase => sb.Supabase.instance.client;

  // Email/şifre ile Supabase oturumu aç
  static Future<bool> supabaseSignIn(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.session != null;
    } catch (e) {
      logger.e('Supabase signIn hatası', error: e);
      return false;
    }
  }

  // Supabase oturumu kapat
  static Future<void> supabaseSignOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      logger.e('Supabase signOut hatası', error: e);
    }
  }

  // Geçerli Supabase oturumu
  static sb.Session? supabaseSession() {
    return _supabase.auth.currentSession;
  }

  // Kullanıcının herhangi bir işletmede admin/editor rolü var mı?
  static Future<bool> supabaseIsAdmin() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;
      final data = await _supabase
          .from('isletme_kullanici')
          .select('rol')
          .eq('user_id', user.id)
          .inFilter('rol', ['admin', 'editor'])
          .limit(1);
      return (data as List).isNotEmpty;
    } catch (e) {
      logger.e('supabaseIsAdmin hatası', error: e);
      return false;
    }
  }

  // Supabase ile başarıyla oturum açılmışsa, müşteri profilini garanti et (musteriler)
  static Future<Customer?> ensureCustomerProfile(String email) async {
    // Önce Supabase'teki musteriler tablosunda ara; yoksa oluştur.
    try {
      final list = await _supabase
          .from('musteriler')
          .select('customerid, firstname, lastname, email, isactive')
          .eq('email', email)
          .limit(1);

      if (list.isNotEmpty) {
        final Map<String, dynamic> row = list.first;
        return Customer(
          customerId: (row['customerid'] as num).toInt(),
          firstName: (row['firstname'] as String?) ?? '',
          lastName: (row['lastname'] as String?) ?? '',
          email: row['email'] as String,
          phone: '',
          address: '',
          birthDate: null,
          gender: null,
          createdAt: DateTime.now(),
          isActive: (row['isactive'] as bool?) ?? true,
        );
      }

      // Yoksa minimal profil oluştur
      final localPart = email.split('@').first;
      String firstName = '';
      String lastName = '';
      if (localPart.contains('.')) {
        final parts = localPart.split('.');
        if (parts.isNotEmpty) firstName = parts[0];
        if (parts.length > 1) lastName = parts[1];
      } else {
        firstName = localPart;
      }

      final user = _supabase.auth.currentUser;

      final inserted = await _supabase
          .from('musteriler')
          .insert({
            'firstname': firstName,
            'lastname': lastName,
            'email': email,
            'isactive': true,
            if (user != null) 'user_id': user.id,
          })
          .select('customerid, firstname, lastname, email, isactive')
          .single();

      return Customer(
        customerId: (inserted['customerid'] as num).toInt(),
        firstName: (inserted['firstname'] as String?) ?? '',
        lastName: (inserted['lastname'] as String?) ?? '',
        email: inserted['email'] as String,
        phone: '',
        address: '',
        birthDate: null,
        gender: null,
        createdAt: DateTime.now(),
        isActive: (inserted['isactive'] as bool?) ?? true,
      );
    } catch (e) {
      // Supabase customer tablosu yoksa veya hata olursa eski DB'ye düş
      logger.w(
        'Supabase musteriler tablo erişimi başarısız, legacy DB denenecek',
        error: e,
      );
      // Legacy: mevcut Postgres'te ara, yoksa oluştur
      final existing = await fetchCustomerByEmail(email);
      if (existing != null) return existing;

      Connection? connection;
      try {
        connection = await _connect();
        final localPart = email.split('@').first;
        String firstName = '';
        String lastName = '';
        if (localPart.contains('.')) {
          final parts = localPart.split('.');
          if (parts.isNotEmpty) firstName = parts[0];
          if (parts.length > 1) lastName = parts[1];
        } else {
          firstName = localPart;
        }
        final randomPassword = const Uuid().v4();
        final results = await connection.execute(
          Sql.named(
            'INSERT INTO customer (firstname, lastname, email, password, isactive) '
            'VALUES (@firstName, @lastName, @email, @password, true) '
            'RETURNING customerid, firstname, lastname, email, isactive',
          ),
          parameters: {
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
            'password': randomPassword,
          },
        );
        if (results.isEmpty) return null;
        final row = results.first;
        return Customer(
          customerId: row[0] as int,
          firstName: row[1] as String? ?? '',
          lastName: row[2] as String? ?? '',
          email: row[3] as String,
          phone: '',
          address: '',
          birthDate: null,
          gender: null,
          createdAt: DateTime.now(),
          isActive: (row[4] as bool?) ?? true,
        );
      } catch (e2) {
        logger.e('ensureCustomerProfile legacy hatası', error: e2);
        return null;
      } finally {
        await connection?.close();
      }
    }
  }

  // Supabase Auth ile kullanıcı oluştur ve musteriler tablosuna profil ekle
  static Future<bool> supabaseRegisterCustomer({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      // Ek kontrol: email formatı
      final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      );
      final trimmedEmail = email.trim();
      if (!emailRegex.hasMatch(trimmedEmail)) {
        logger.w('Geçersiz e-posta formatı: $trimmedEmail');
        return false;
      }

      // Önce Supabase Auth'ta kullanıcıyı oluştur ve metadata gönder
      final signUpRes = await _supabase.auth.signUp(
        email: trimmedEmail,
        password: password,
        data: {
          'firstname': firstName,
          'lastname': lastName,
          'phone': phone,
          'full_name': '$firstName $lastName',
        },
      );

      final user = signUpRes.user;
      if (user == null) {
        return false;
      }

      // Eğer email onayı açıksa session null olabilir. Bu durumda
      // RLS nedeniyle client'tan insert denemeyip true döneriz.
      // Profil kaydı için DB tarafındaki trigger devreye girecektir.
      if (signUpRes.session == null) {
        return true;
      }

      // musteriler tablosunda varsa tekrar ekleme
      final existing = await _supabase
          .from('musteriler')
          .select('customerid')
          .eq('email', trimmedEmail)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('musteriler').insert({
          'firstname': firstName,
          'lastname': lastName,
          'email': trimmedEmail,
          'phone': phone,
          'isactive': true,
          'user_id': user.id,
        });
      } else {
        // Mevcut satır varsa user_id eşitle
        if ((existing['customerid'] as num?) != null) {
          await _supabase
              .from('musteriler')
              .update({'user_id': user.id})
              .eq('customerid', (existing['customerid'] as num).toInt());
        }
      }

      return true;
    } catch (e) {
      logger.e('supabaseRegisterCustomer hatası', error: e);
      rethrow; // UI'ya gerçek Supabase hatasını yansıt
    }
  }

  // Customer register
  static Future<bool> customerRegister(
    Customer customer,
    String password,
  ) async {
    Connection? connection;
    try {
      connection = await _connect();

      await connection.execute(
        Sql.named(
          'INSERT INTO customer (firstname, lastname, email, password, isactive) VALUES (@firstName, @lastName, @email, @password, @isActive)',
        ),
        parameters: {
          'firstName': customer.firstName,
          'lastName': customer.lastName,
          'email': customer.email,
          'password': password, // Gerçek uygulamada hash'lenmiş olmalı
          'isActive': customer.isActive,
        },
      );

      return true;
    } catch (e) {
      logger.e('Customer register hatası.', error: e);
      return false;
    } finally {
      await connection?.close();
    }
  }

  // === ADMIN AUTHENTICATION ===

  // Admin login - admin tablosundan username ve password kontrolü
  static Future<bool> adminLogin(String email, String password) async {
    Connection? connection;
    try {
      logger.i('Admin girişi deneniyor: $email');
      connection = await _connect();
      logger.i('Veritabanına bağlanıldı');

      // Admin tablosundan username ve password kontrolü
      var results = await connection.execute(
        Sql.named(
          'SELECT adminid FROM admin WHERE username = @email AND password = @password',
        ),
        parameters: {'email': email, 'password': password},
      );

      logger.i('Sorgu sonucu: ${results.length} satır bulundu');

      if (results.isNotEmpty) {
        logger.i('Admin girişi başarılı: $email');
        return true;
      }

      logger.w('Admin girişi başarısız: Geçersiz email veya şifre');
      return false;
    } catch (e) {
      logger.e('Admin login hatası.', error: e);
      return false;
    } finally {
      await connection?.close();
      logger.i('Veritabanı bağlantısı kapatıldı');
    }
  }

  // === VERİTABANI BAĞLANTI TESTİ ===

  // Veritabanı bağlantı testi
  static Future<bool> testDatabaseConnection() async {
    try {
      logger.i('Veritabanı bağlantısı test ediliyor...');
      final connection = await _connect();
      await connection.close();
      logger.i('Veritabanı bağlantısı başarılı!');
      return true;
    } catch (e) {
      logger.e('Veritabanı bağlantısı başarısız: $e');
      return false;
    }
  }
}
