import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'data/services/api.dart';
import 'data/services/auth.dart';
import 'data/services/location_provider.dart';
import 'data/services/cart_provider.dart';
import 'data/services/ops_status_provider.dart';
import 'data/services/push_service.dart';
import 'presentation/theme/theme.dart';
import 'presentation/widgets/widgets.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/bookings/bookings_screen.dart';
import 'presentation/screens/bookings/book_screen.dart';
import 'presentation/screens/shop/shop_screen.dart';
import 'presentation/screens/plantopedia/plantopedia_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/subscriptions/subscriptions_screen.dart';
import 'presentation/screens/subscriptions/plans_screen.dart';
import 'presentation/screens/notifications/notifications_screen.dart';
import 'presentation/screens/complaints/complaints_screen.dart';
import 'presentation/screens/profile/saved_addresses_screen.dart';
import 'presentation/screens/profile/edit_profile_screen.dart';
import 'presentation/screens/green_makeover/green_makeover_screen.dart';
import 'presentation/screens/services/services_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  Animate.restartOnHotReload = true;
  // Compile glass shaders up front so the first glass surface doesn't hitch.
  VLiquid.precache();
  // Push notifications — no-op when Firebase isn't configured yet. After init,
  // re-sync the FCM token to the backend if a session already exists.
  PushService.instance.init().then((_) => PushService.instance.syncTokenIfLoggedIn());
  // Session ended mid-use → sign in over the current page, then come back to
  // it with everything (e.g. booking details) still filled in. The failed
  // request is retried automatically by Api once this resolves true.
  Api.onAuthRequired = () async {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return false;
    final ok = await nav.push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LoginScreen(reauth: true, onLoggedIn: () => nav.pop(true)),
    ));
    if (ok == true) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) await ctx.read<AuthProvider>().reload();
    }
    return ok == true;
  };
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => LocationProvider()),
    ChangeNotifierProvider(create: (_) => CartProvider()),
    ChangeNotifierProvider(create: (_) => OpsStatusProvider()),
  ], child: const GkmApp()));
}

class GkmApp extends StatelessWidget {
  const GkmApp({super.key});

  @override
  Widget build(BuildContext ctx) => MaterialApp(
        title: 'Ghar Ka Mali',
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AT.light,
        home: const GGlassBg(child: _Root()),
        onGenerateRoute: _onRoute,
        // iOS-style elastic scrolling on every platform.
        scrollBehavior: const _BouncyScroll(),
      );

  static Route<dynamic>? _onRoute(RouteSettings s) {
    Widget? page;
    switch (s.name) {
      case '/book':
        final planId = s.arguments is int ? s.arguments as int : null;
        page = BookScreen(planId: planId);
        return _slide(page, s);
      case '/bookings':
        page = const BookingsScreen();
        break;
      case '/subscriptions':
        return _slide(const SubscriptionsScreen(), s);
      case '/plans':
        return _slide(const PlansScreen(), s);
      case '/green-makeover':
        return _slide(const GreenMakeoverScreen(), s);
      case '/services':
        return _slide(const ServicesScreen(), s);
      case '/shop':
        page = const ShopScreen();
        break;
      case '/shop/orders':
        return _slide(const MyOrdersScreen(), s);
      case '/plantopedia':
        page = const PlantopediaScreen();
        break;
      case '/notifications':
        return _slide(const NotificationsScreen(), s);
      case '/complaints':
        return _slide(const ComplaintsScreen(), s);
      case '/saved-addresses':
        return _slide(const SavedAddressesScreen(), s);
      case '/edit-profile':
        return _slide(const EditProfileScreen(), s);
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

  // Every page uses the standard route: the theme's GlassPageTransitionsBuilder
  // gives it the glass backdrop and the iOS slide with edge swipe-back.
  static PageRoute _fade(Widget pg, RouteSettings s) => MaterialPageRoute(settings: s, builder: (_) => pg);
  static PageRoute _slide(Widget pg, RouteSettings s) => MaterialPageRoute(settings: s, builder: (_) => pg);
}

class _BouncyScroll extends MaterialScrollBehavior {
  const _BouncyScroll();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _showingSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(800.ms, () {
      if (mounted) setState(() => _showingSplash = false);
    });
  }

  @override
  Widget build(BuildContext ctx) {
    if (_showingSplash) return const _Splash();

    final auth = ctx.watch<AuthProvider>();
    if (auth.loading) return const _Splash();
    if (!auth.isAuthed) return LoginScreen(onLoggedIn: () => _goShell(ctx));
    return const _Shell();
  }

  void _goShell(BuildContext ctx) {
    // Pick up the token Api.verifyOtp just stored — but only after the
    // drop-in animation, so the old root doesn't rebuild into a second Home
    // underneath it (double work + a flash mid-transition).
    final auth = ctx.read<AuthProvider>();
    Future.delayed(const Duration(milliseconds: 900), auth.reload);
    Navigator.pushAndRemoveUntil(
      ctx,
      // Plain fade for the shell (the glass dock stays put, so it isn't
      // re-rendered every frame); Home's own content drops in from the top.
      PageRouteBuilder(
          transitionDuration: 380.ms,
          pageBuilder: (_, __, ___) => const GGlassBg(child: _Shell()),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child)),
      (_) => false);
  }
}

class _Shell extends StatefulWidget {
  const _Shell();
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> with SingleTickerProviderStateMixin {
  int _idx = 0;
  int _dir = 1; // slide direction of the incoming tab
  // Tab-switch animation: the IndexedStack is animated in place (not
  // re-keyed), so every tab keeps its scroll position and state.
  late final AnimationController _tabAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  late final CurvedAnimation _tabCurve = CurvedAnimation(parent: _tabAnim, curve: Curves.easeOutCubic);
  late final Animation<double> _tabFade = Tween(begin: 0.5, end: 1.0).animate(_tabCurve);
  late final Animation<Offset> _tabSlideFromRight = Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(_tabCurve);
  late final Animation<Offset> _tabSlideFromLeft = Tween(begin: const Offset(-0.06, 0), end: Offset.zero).animate(_tabCurve);

  void _setTab(int i) {
    if (i == _idx) return;
    setState(() { _dir = i > _idx ? 1 : -1; _idx = i; });
    _tabAnim.forward(from: 0);
  }

  @override
  void dispose() { _tabAnim.dispose(); super.dispose(); }

  @override
  void initState() {
    super.initState();
    // Refresh profile and auto-detect location
    // Heavier start-up work (GPS, status polling) waits until the entry
    // animation has finished so it doesn't compete for frames.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      context.read<AuthProvider>().refreshProfile();

      // Operations kill-switch — fetch now, then re-check every 5 minutes.
      context.read<OpsStatusProvider>()
        ..load()
        ..startPolling();

      // Always refresh GPS location on every app open (Swiggy/Zepto style)
      context.read<LocationProvider>().autoDetect();
    });
  }

  void _onLogout() => Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
          transitionDuration: 360.ms,
          pageBuilder: (_, __, ___) => const GGlassBg(child: _Root()),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child)),
      (_) => false);

  // HomeScreen calls this both for the 3 bottom tabs (0-2) and for actions
  // that live outside the tab bar (Plantopedia, Profile) — those are pushed
  // as routes instead of switching the IndexedStack.
  void _navTo(int i) {
    switch (i) {
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => PlantopediaScreen(
          isVisible: true,
          onClose: () => Navigator.pop(context),
        )));
        break;
      case 4:
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(onLogout: _onLogout)));
        break;
      default:
        _setTab(i);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    void toHome() => _setTab(0);
    final pages = [
      HomeScreen(navTo: _navTo),
      BookingsScreen(onBack: toHome),
      ShopScreen(onBack: toHome),
    ];
    // Android back on the Bookings/Shop tabs returns to Home before exiting.
    return PopScope(
      canPop: _idx == 0,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) toHome(); },
      child: Scaffold(
      // Pages scroll underneath the floating dock — no strip behind it. The
      // body's MediaQuery bottom padding grows by the dock height, so lists
      // and the cart bar keep clear of it.
      extendBody: true,
      // Hidden tabs stay alive in the IndexedStack, so mute their tickers —
      // otherwise their animations keep rendering off-screen (battery/heat).
      // Transition widgets animate without rebuilding the tab's subtree.
      body: FadeTransition(
        opacity: _tabFade,
        child: SlideTransition(
          position: _dir > 0 ? _tabSlideFromRight : _tabSlideFromLeft,
          child: IndexedStack(index: _idx, children: [
          for (var i = 0; i < pages.length; i++) TickerMode(enabled: i == _idx, child: pages[i]),
        ]),
        ),
      ),
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (_, cart, __) => GNavBar(
            idx: _idx,
            onTap: _setTab,
            cartCount: cart.count),
      ),
    ));
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext ctx) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Image.asset('assets/images/logo.png', width: 140)
              .animate()
              .fadeIn(duration: 800.ms)
              .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack),
        ),
      );
}
