import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';

import 'screens/register_screen.dart';
import 'screens/services_screen.dart';
import 'screens/appointment_screen.dart';
import 'screens/admin_screen.dart';
import 'constants/app_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/db_service.dart';
import 'widgets/common_bottom_navigation.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';

import 'models/customer.dart';
import 'models/employee.dart';

// Tema rengini Supabase'den uygular (isletme.tema_rengi > icerik_blok fallback)
Future<void> _applyThemeFromSupabase() async {
  try {
    final client = Supabase.instance.client;

    // 1) İşletme ID çözümle (kullanıcı-işletme eşleşmesi veya ilk mevcut kayıt)
    final isletmeId = await DbService.resolveIsletmeId();
    String? hex;
    String? hex2;

    if (isletmeId != null && isletmeId.isNotEmpty) {
      final data = await client
          .from('isletme')
          .select('tema_rengi, tema_rengi2')
          .eq('isletme_id', isletmeId)
          .maybeSingle();
      if (data != null) {
        final map = data as Map;
        final val1 = map['tema_rengi'];
        final val2 = map['tema_rengi2'];
        if (val1 is String) hex = val1;
        if (val2 is String) hex2 = val2;
      }
    }

    // 2) Fallback: icerik_blok(anahtar='tema_rengi')
    if (hex == null || hex.trim().isEmpty) {
      final rows = await client
          .from('icerik_blok')
          .select('deger')
          .eq('anahtar', 'tema_rengi')
          .order('created_at', ascending: true)
          .limit(1);
      if (rows.isNotEmpty) {
        hex = rows.first['deger'] as String?;
      }
    }

    // 3) Uygula
    if (hex != null && hex.trim().isNotEmpty) {
      final normalized = hex.trim().replaceAll('#', '');
      if (normalized.length == 6 || normalized.length == 8) {
        final withAlpha = normalized.length == 6 ? 'FF$normalized' : normalized;
        final color = Color(int.parse('0x$withAlpha'));
        SiriusColors.setAccentDynamic(color);
      }
    }

    if (hex2 != null && hex2.trim().isNotEmpty) {
      final normalized2 = hex2.trim().replaceAll('#', '');
      if (normalized2.length == 6 || normalized2.length == 8) {
        final withAlpha2 = normalized2.length == 6
            ? 'FF$normalized2'
            : normalized2;
        final color2 = Color(int.parse('0x$withAlpha2'));
        SiriusColors.setAccent2Dynamic(color2);
      }
    }
  } catch (_) {
    // Tema rengi okunamazsa varsayılan renk kullanılır
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase configuration - replace with your actual values
  const supabaseUrl = 'https://your-project.supabase.co';
  const supabaseAnonKey = 'your-anon-key-here';

  // Check if environment variables are set, otherwise use defaults
  final envUrl = const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: supabaseUrl,
  );
  final envKey = const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: supabaseAnonKey,
  );

  await Supabase.initialize(url: envUrl, anonKey: envKey);

  await _applyThemeFromSupabase();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (context) =>
              LanguageProvider(initialLanguage: AppLanguage.tr),
        ),
      ],
      child: const SiriusBeautyApp(),
    ),
  );
}

class AuthProvider extends ChangeNotifier {
  Customer? _currentCustomer;
  Employee? _currentEmployee;
  bool _isAuthenticated = false;
  bool _isAdmin = false;

  Customer? get currentCustomer => _currentCustomer;
  Employee? get currentEmployee => _currentEmployee;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;

  void setCustomer(Customer customer) {
    _currentCustomer = customer;
    _currentEmployee = null;
    _isAuthenticated = true;
    _isAdmin = false;
    _applyThemeFromSupabase();
    notifyListeners();
  }

  void setEmployee(Employee employee, bool isAdmin) {
    _currentEmployee = employee;
    _currentCustomer = null;
    _isAuthenticated = true;
    _isAdmin = isAdmin;
    _applyThemeFromSupabase();
    notifyListeners();
  }

  // Customer login sonrası state güncelleme
  void loginCustomer(Customer customer) {
    setCustomer(customer);
  }

  // Admin login sonrası state güncelleme
  void loginAdmin(Employee employee) {
    setEmployee(employee, true);
  }

  void logout() {
    _currentCustomer = null;
    _currentEmployee = null;
    _isAuthenticated = false;
    _isAdmin = false;
    _applyThemeFromSupabase();
    notifyListeners();
  }

  void updateCustomer(Customer updatedCustomer) {
    _currentCustomer = updatedCustomer;
    _applyThemeFromSupabase();
    notifyListeners();
  }
}

// Ana wrapper widget - Navigation bar'ı içerir
class MainWrapper extends StatefulWidget {
  final Widget child;
  final String routeName;

  const MainWrapper({super.key, required this.child, required this.routeName});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _getCurrentIndex() {
    int index = 0;
    switch (widget.routeName) {
      case '/':
        index = 0; // Ana Sayfa
        break;
      case '/profile':
        index = 1; // Profil
        break;
      case '/appointment':
        index = 2; // Randevu (merkez FAB)
        break;
      default:
        index = 0;
        break;
    }

    return index;
  }

  bool _shouldShowBottomNav() {
    // Sadece mobil platformlarda ve mobil ekran boyutunda navbar göster
    if (kIsWeb) {
      return false; // Web'de navbar gösterme
    }

    // Ekran boyutu kontrolü - sadece mobil boyutlarda göster
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) {
      // Tablet ve üstünde navbar gösterme
      return false;
    }

    // Admin sayfasında navbar gösterme
    if (widget.routeName == '/admin') {
      return false;
    }

    // Login ve register sayfalarında da navbar gösterme
    if (widget.routeName == '/login' || widget.routeName == '/register') {
      return false;
    }

    return true; // Diğer sayfalarda navbar göster (sadece mobil)
  }

  void _onTabTapped(int index) {
    String route = '/';
    switch (index) {
      case 0:
        route = '/';
        break;
      case 1:
        route = '/profile';
        break;
      case 2:
        route = '/appointment';
        break;
    }

    if (widget.routeName != route) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  void _onRandevuTap() {
    if (widget.routeName != '/appointment') {
      Navigator.pushNamed(context, '/appointment');
    } else {
      // Zaten randevu sayfasındayız, randevu oluştur dialog'unu aç
      // HomeScreen'deki _showAppointmentBookingDialog fonksiyonunu çağır
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowBottomNav()) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true, // Body'yi navigation bar'ın altına uzat
      body: SafeArea(
        bottom: false, // Alt kısmı SafeArea'dan çıkar (bottom nav için)
        child: widget.child,
      ),
      bottomNavigationBar: CommonBottomNavigationBar(
        currentIndex: _getCurrentIndex(),
        onTap: _onTabTapped,
        onRandevuTap: _onRandevuTap,
      ),
    );
  }
}

class SiriusBeautyApp extends StatelessWidget {
  const SiriusBeautyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => MaterialApp(
        title: 'Sirius Beauty & Spa',
        debugShowCheckedModeBanner: false,
        theme: themeProvider.lightTheme,
        darkTheme: themeProvider.darkTheme,
        themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        locale: Provider.of<LanguageProvider>(context).locale,
        initialRoute: '/login',
        routes: {
          '/': (context) => Consumer<AuthProvider>(
            builder: (context, auth, child) {
              if (auth.isAuthenticated && auth.currentCustomer != null) {
                return const MainWrapper(routeName: '/', child: HomeScreen());
              } else if (auth.isAuthenticated && auth.isAdmin) {
                return const MainWrapper(
                  routeName: '/admin',
                  child: AdminScreen(),
                );
              } else {
                return const MainWrapper(
                  routeName: '/login',
                  child: LoginScreen(),
                );
              }
            },
          ),
          '/login': (context) =>
              const MainWrapper(routeName: '/login', child: LoginScreen()),
          '/register': (context) => const MainWrapper(
            routeName: '/register',
            child: RegisterScreen(),
          ),
          '/services': (context) => const MainWrapper(
            routeName: '/services',
            child: ServicesScreen(),
          ),
          '/appointment': (context) => const MainWrapper(
            routeName: '/appointment',
            child: AppointmentScreen(),
          ),
          '/profile': (context) => Consumer<AuthProvider>(
            builder: (context, auth, child) {
              if (auth.isAuthenticated && auth.currentCustomer != null) {
                return const MainWrapper(
                  routeName: '/profile',
                  child: ProfileScreen(),
                );
              } else {
                return const MainWrapper(
                  routeName: '/login',
                  child: LoginScreen(),
                );
              }
            },
          ),
          '/admin': (context) => Consumer<AuthProvider>(
            builder: (context, auth, child) {
              if (auth.isAuthenticated && auth.isAdmin) {
                return const MainWrapper(
                  routeName: '/admin',
                  child: AdminScreen(),
                );
              } else {
                return const MainWrapper(
                  routeName: '/login',
                  child: LoginScreen(),
                );
              }
            },
          ),
        },
      ),
    );
  }
}
