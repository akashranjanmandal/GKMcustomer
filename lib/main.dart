import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'data/services/auth.dart';
import 'data/services/location_provider.dart';
import 'data/services/cart_provider.dart';
import 'presentation/theme/theme.dart';
import 'presentation/widgets/widgets.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/bookings/bookings_screen.dart';
import 'presentation/screens/bookings/book_screen.dart';
import 'presentation/screens/shop/shop_screen.dart';
import 'presentation/screens/wallet/wallet_screen.dart';
import 'presentation/screens/plantopedia/plantopedia_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/subscriptions/subscriptions_screen.dart';
import 'presentation/screens/subscriptions/plans_screen.dart';
import 'presentation/screens/notifications/notifications_screen.dart';
import 'presentation/screens/complaints/complaints_screen.dart';
import 'presentation/screens/profile/saved_addresses_screen.dart';
import 'presentation/screens/profile/edit_profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  Animate.restartOnHotReload = true;
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => LocationProvider()),
    ChangeNotifierProvider(create: (_) => CartProvider()),
  ], child: const GkmApp()));
}

class GkmApp extends StatelessWidget {
  const GkmApp({super.key});

  @override
  Widget build(BuildContext ctx) => MaterialApp(
    title: 'Ghar Ka Mali',
    debugShowCheckedModeBanner: false,
    theme: AT.light,
    home: const _Root(),
    onGenerateRoute: _onRoute,
  );

  static Route<dynamic>? _onRoute(RouteSettings s) {
    Widget? page;
    switch (s.name) {
      case '/book':
        final planId = s.arguments is int ? s.arguments as int : null;
        page = BookScreen(planId: planId);
        return _slide(page, s);
      case '/bookings':       page = const BookingsScreen(); break;
      case '/subscriptions':  return _slide(const SubscriptionsScreen(), s);
      case '/plans':          return _slide(const PlansScreen(), s);
      case '/shop':           page = const ShopScreen(); break;
      case '/shop/orders':    return _slide(const MyOrdersScreen(), s);
      case '/wallet':         page = const WalletScreen(); break;
      case '/plantopedia':    page = const PlantopediaScreen(); break;
      case '/notifications':  return _slide(const NotificationsScreen(), s);
      case '/complaints':     return _slide(const ComplaintsScreen(), s);
      case '/saved-addresses':return _slide(const SavedAddressesScreen(), s);
      case '/edit-profile':   return _slide(const EditProfileScreen(), s);
      default:
        if (s.name?.startsWith('/booking/') == true) {
          final id = int.tryParse(s.name!.replaceFirst('/booking/', '')) ?? 0;
          return _slide(BookingDetailScreen(id: id), s);
        }
        return null;
    }
    if (page != null) return _fade(page, s);
    return null;
  }

  static PageRoute _fade(Widget pg, RouteSettings s) => PageRouteBuilder(
    settings: s,
    transitionDuration: 280.ms, reverseTransitionDuration: 240.ms,
    pageBuilder: (_, __, ___) => pg,
    transitionsBuilder: (_, a, __, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: c,
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(c), child: child));
    });

  static PageRoute _slide(Widget pg, RouteSettings s) => PageRouteBuilder(
    settings: s,
    transitionDuration: 340.ms, reverseTransitionDuration: 280.ms,
    pageBuilder: (_, __, ___) => pg,
    transitionsBuilder: (_, a, __, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(c),
        child: FadeTransition(opacity: Tween<double>(begin: 0.3, end: 1.0).animate(c), child: child));
    });
}

class _Root extends StatefulWidget {
  const _Root();
  @override State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _showingSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(2.seconds, () { if (mounted) setState(() => _showingSplash = false); });
  }

  @override
  Widget build(BuildContext ctx) {
    if (_showingSplash) return const _Splash();
    
    final auth = ctx.watch<AuthProvider>();
    if (auth.loading) return const _Splash();
    if (!auth.isAuthed) return LoginScreen(onLoggedIn: () => _goShell(ctx));
    return const _Shell();
  }

  void _goShell(BuildContext ctx) => Navigator.pushAndRemoveUntil(ctx,
    PageRouteBuilder(
      transitionDuration: 380.ms,
      pageBuilder: (_, __, ___) => const _Shell(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child)),
    (_) => false);
}

class _Shell extends StatefulWidget {
  const _Shell();
  @override State<_Shell> createState() => _ShellState();
}
class _ShellState extends State<_Shell> {
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    // Refresh profile from server so phone/name/wallet are always current
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
    });
  }

  void _onLogout() => Navigator.pushAndRemoveUntil(context,
    PageRouteBuilder(
      transitionDuration: 360.ms,
      pageBuilder: (_, __, ___) => const _Root(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child)),
    (_) => false);

  @override
  Widget build(BuildContext ctx) {
    final pages = [
      HomeScreen(navTo: (i) => setState(() => _idx = i)),
      const BookingsScreen(),
      const PlantopediaScreen(),
      const ShopScreen(),
      ProfileScreen(onLogout: _onLogout),
    ];
    return Scaffold(
      body: IndexedStack(index: _idx, children: pages),
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (_, cart, __) => GNavBar(idx: _idx, onTap: (i) => setState(() => _idx = i), cartCount: cart.count),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Image.asset('assets/images/logo.png', width: 220)
        .animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), curve: Curves.easeOutBack),
    ),
  );
}
