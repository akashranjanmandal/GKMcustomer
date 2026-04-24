import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/services/api.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoggedIn;
  const LoginScreen({super.key, required this.onLoggedIn});
  @override State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final _api = Api();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final List<TextEditingController> _otpCtrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode>             _otpFocus = List.generate(6, (_) => FocusNode());
  String _step = 'phone';
  bool _busy = false;
  int _cd = 0;
  Timer? _timer;

  @override void dispose() {
    _timer?.cancel(); _phoneCtrl.dispose(); _nameCtrl.dispose();
    for (var c in _otpCtrls) c.dispose();
    for (var f in _otpFocus) f.dispose();
    super.dispose();
  }

  void _startCd() {
    _cd = 30; _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cd == 0) t.cancel(); else setState(() => _cd--);
    });
  }

  Future<void> _sendOtp() async {
    final p = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (p.length != 10) return showMsg(context, 'Enter a valid 10-digit number', err: true);
    setState(() => _busy = true);
    try {
      await _api.sendOtp(p);
      _startCd();
      if (mounted) setState(() { _step = 'otp'; _busy = false; });
    } on ApiError catch (e) {
      if (mounted) { setState(() => _busy = false); showMsg(context, e.message, err: true); }
    }
  }

  Future<void> _verifyOtp() async {
    final p    = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final code = _otpCtrls.map((c) => c.text).join();
    if (code.length != 6) return showMsg(context, 'Enter 6-digit OTP', err: true);
    setState(() => _busy = true);
    try {
      final res = await _api.verifyOtp(p, code);
      if (!mounted) return;
      if (res is Map && res['requires_name'] == true) {
        setState(() { _step = 'name'; _busy = false; });
      } else { widget.onLoggedIn(); }
    } on ApiError catch (e) {
      if (mounted) { setState(() => _busy = false); showMsg(context, e.message, err: true); }
    }
  }

  Future<void> _submitName() async {
    final n = _nameCtrl.text.trim();
    if (n.isEmpty) return showMsg(context, 'Enter your name', err: true);
    setState(() => _busy = true);
    try {
      final p    = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
      final code = _otpCtrls.map((c) => c.text).join();
      await _api.verifyOtp(p, code, name: n);
      if (mounted) widget.onLoggedIn();
    } on ApiError catch (e) {
      if (mounted) { setState(() => _busy = false); showMsg(context, e.message, err: true); }
    }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: C.forest,
    resizeToAvoidBottomInset: true,
    body: AnimatedSwitcher(
      duration: 500.ms,
      child: switch (_step) {
        'otp'  => _OtpScreen(key: const ValueKey('otp'), phone: _phoneCtrl.text, controllers: _otpCtrls, focusNodes: _otpFocus, busy: _busy, cd: _cd, onBack: () => setState(() { _step = 'phone'; for (final c in _otpCtrls) c.clear(); }), onVerify: _verifyOtp, onResend: _sendOtp, onChange: (_) => setState(() {})),
        'name' => _NameScreen(key: const ValueKey('name'), nameCtrl: _nameCtrl, busy: _busy, onSubmit: _submitName),
        _ => _PhoneScreen(key: const ValueKey('phone'), phoneCtrl: _phoneCtrl, busy: _busy, onSend: _sendOtp, onPhoneChanged: (_) => setState(() {})),
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile model
// ─────────────────────────────────────────────────────────────────────────────
class _Tile {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  const _Tile(this.icon, this.label, this.bg, {this.fg = Colors.white});
}

// ─────────────────────────────────────────────────────────────────────────────
// Phone screen — Pronto-style layout
// ─────────────────────────────────────────────────────────────────────────────
class _PhoneScreen extends StatelessWidget {
  final TextEditingController phoneCtrl;
  final bool busy;
  final VoidCallback onSend;
  final ValueChanged<String> onPhoneChanged;
  const _PhoneScreen({super.key, required this.phoneCtrl, required this.busy, required this.onSend, required this.onPhoneChanged});

  static const _r1 = [
    _Tile(Icons.eco_rounded,              'Organic',       Color(0xFF1A4731)),
    _Tile(Icons.local_florist_rounded,    'Blooming',      Color(0xFF2D6A4F)),
    _Tile(Icons.yard_rounded,             'Lawn Care',     Color(0xFF40916C)),
    _Tile(Icons.water_drop_rounded,       'Watering',      Color(0xFF074F2A)),
    _Tile(Icons.agriculture_rounded,      'Farming',       Color(0xFF1B5E38)),
  ];
  static const _r2 = [
    _Tile(Icons.content_cut_rounded,            'Pruning',    Color(0xFF2D6A4F)),
    _Tile(Icons.spa_rounded,                    'Wellness',   Color(0xFF1B5E38)),
    _Tile(Icons.park_rounded,                   'Garden',     Color(0xFF1A4731)),
    _Tile(Icons.grass_rounded,                  'Lawn',       Color(0xFF40916C)),
    _Tile(Icons.energy_savings_leaf_rounded,    'Eco Care',   Color(0xFF074F2A)),
  ];
  static const _r3 = [
    _Tile(Icons.pest_control_rounded,     'Pest Free',     Color(0xFF52796F)),
    _Tile(Icons.compost_rounded,          'Soil Health',   Color(0xFF7A5C3E)),
    _Tile(Icons.forest_rounded,           'Trees',         Color(0xFF1B4332)),
    _Tile(Icons.energy_savings_leaf_rounded, 'Eco Care',   Color(0xFF2D6A4F)),
    _Tile(Icons.local_florist_rounded,    'Flowers',       Color(0xFF095D36)),
  ];

  @override
  Widget build(BuildContext ctx) {
    final canContinue = phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length == 10;
    final top = MediaQuery.of(ctx).padding.top;
    final bot = MediaQuery.of(ctx).padding.bottom;

    return Column(
      children: [
        // ── Top Section (Header + Marquee) ─────────────────────────
        // ── Green header: logo + headline ─────────────────────────
        Container(
          width: double.infinity,
          color: C.forest,
          padding: EdgeInsets.fromLTRB(24, top + 20, 24, 10),
          child: Column(children: [
            Image.asset('assets/images/logo.png', height: 64, fit: BoxFit.contain)
              .animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.88, 0.88)),
          ]),
        ),
        
        // ── Marquee area (Expanded to fill gap) ──────────────────
        Expanded(
          child: Stack(children: [
            Container(
              width: double.infinity,
              color: C.forest,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MarqueeRow(tiles: _r1, duration: const Duration(seconds: 36), reverse: false),
                  _MarqueeRow(tiles: _r2, duration: const Duration(seconds: 30), reverse: true),
                  _MarqueeRow(tiles: _r3, duration: const Duration(seconds: 40), reverse: false),
                ],
              ),
            ),
            // Top fade: forest → transparent
            Positioned(top: 0, left: 0, right: 0, height: 36,
              child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [C.forest, C.forest.withOpacity(0)],
              ))))),
            // Bottom fade: transparent → white
            Positioned(bottom: 0, left: 0, right: 0, height: 40,
              child: IgnorePointer(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.white, Colors.transparent],
              ))))),
          ]),
        ),

        // ── Bottom Section (White Card) ────────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 24, 24, bot + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mobile Number', style: p(13, w: FontWeight.w600, color: C.t3)),
            const SizedBox(height: 10),
            _LoginInput(
              child: Row(children: [
                const SizedBox(width: 16),
                const Icon(Icons.phone_android_rounded, size: 20, color: C.forest),
                const SizedBox(width: 12),
                Expanded(child: _rawField(
                  ctrl: phoneCtrl,
                  hint: 'e.g. 7319XXXXXX',
                  onChanged: onPhoneChanged,
                  keyboard: TextInputType.phone,
                  formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                )),
              ]),
            ),
            const SizedBox(height: 16),
            GBtn(label: 'Continue', loading: busy, onTap: canContinue ? onSend : null, bg: canContinue ? C.forest : Colors.grey[300]!),
            const SizedBox(height: 18),
            Center(child: Text.rich(TextSpan(style: p(12, color: Colors.black38, h: 1.5), children: [
              const TextSpan(text: 'By continuing, you agree to our '),
              TextSpan(text: 'Terms of Service', style: p(12, w: FontWeight.w700, color: Colors.black54)),
              const TextSpan(text: ' & '),
              TextSpan(text: 'Privacy Policy', style: p(12, w: FontWeight.w700, color: Colors.black54)),
            ]))),
          ]),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seamless marquee row
// ─────────────────────────────────────────────────────────────────────────────
class _MarqueeRow extends StatefulWidget {
  final List<_Tile> tiles;
  final Duration duration;
  final bool reverse;
  const _MarqueeRow({required this.tiles, required this.duration, required this.reverse});
  @override State<_MarqueeRow> createState() => _MarqueeRowState();
}

class _MarqueeRowState extends State<_MarqueeRow> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const double _w = 106;
  static const double _gap = 8;
  static const double _stride = _w + _gap;

  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final n      = widget.tiles.length;
    final loopW  = n * _stride;
    // Generate 4× the tiles so we never run out as it scrolls
    final reps   = 4;

    return Expanded(child: ClipRect(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final raw    = (_ctrl.value * loopW) % loopW;
          final offset = widget.reverse ? (loopW - raw) % loopW : raw;
          return OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            child: Transform.translate(
              offset: Offset(-offset, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(n * reps, (i) {
                  final t = widget.tiles[i % n];
                  return Container(
                    width: _w,
                    margin: const EdgeInsets.fromLTRB(0, 5, _gap, 5),
                    decoration: BoxDecoration(
                      color: t.bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(t.icon, color: t.fg.withOpacity(0.88), size: 28),
                      const SizedBox(height: 8),
                      Text(t.label,
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: t.fg.withOpacity(0.72)),
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  );
                }),
              ),
            ),
          );
        },
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared input widgets — ONE container, ONE border, TextField fully stripped
// ─────────────────────────────────────────────────────────────────────────────
class _LoginInput extends StatelessWidget {
  final Widget child;
  const _LoginInput({required this.child});
  @override
  Widget build(BuildContext ctx) => Container(
    height: 54,
    decoration: BoxDecoration(
      color: const Color(0xFFF3F7F0),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: C.border, width: 1.2),
    ),
    alignment: Alignment.center,
    child: child,
  );
}

// Fully-stripped TextField — no fill, no border, no decoration from theme
TextField _rawField({
  required TextEditingController ctrl,
  required String hint,
  ValueChanged<String>? onChanged,
  TextInputType keyboard = TextInputType.text,
  List<TextInputFormatter>? formatters,
}) => TextField(
  controller: ctrl,
  onChanged: onChanged,
  keyboardType: keyboard,
  inputFormatters: formatters,
  style: p(15, w: FontWeight.w600, color: C.t1),
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: C.t4, fontSize: 14, fontWeight: FontWeight.w400),
    border:             InputBorder.none,
    enabledBorder:      InputBorder.none,
    focusedBorder:      InputBorder.none,
    errorBorder:        InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    disabledBorder:     InputBorder.none,
    filled:             false,
    isDense:            true,
    contentPadding:     EdgeInsets.zero,
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// OTP screen
// ─────────────────────────────────────────────────────────────────────────────
class _OtpScreen extends StatelessWidget {
  final String phone; final List<TextEditingController> controllers; final List<FocusNode> focusNodes;
  final bool busy; final int cd; final VoidCallback onBack, onVerify, onResend; final ValueChanged<String> onChange;
  const _OtpScreen({super.key, required this.phone, required this.controllers, required this.focusNodes, required this.busy, required this.cd, required this.onBack, required this.onVerify, required this.onResend, required this.onChange});

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back, color: Colors.black))),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('OTP verification', style: p(26, w: FontWeight.w900, color: Colors.black)),
        const SizedBox(height: 8),
        Text('Enter the 6-digit code sent to +91 $phone', style: p(14, color: Colors.black54)),
        const SizedBox(height: 48),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(6, (i) => _OtpBox(
          controller: controllers[i], focusNode: focusNodes[i],
          onChanged: (v) {
            if (v.isNotEmpty && i < 5) focusNodes[i + 1].requestFocus();
            if (v.isEmpty  && i > 0) focusNodes[i - 1].requestFocus();
            onChange(v);
            
            // Auto submit when all fields are filled
            final code = controllers.map((c) => c.text).join();
            if (code.length == 6) onVerify();
          },
        ))),
        const SizedBox(height: 48),
        GBtn(label: 'Verify OTP', loading: busy, onTap: onVerify, bg: C.forest),
        const SizedBox(height: 28),
        Center(child: TextButton(onPressed: cd == 0 ? onResend : null,
          child: Text(cd == 0 ? 'Resend OTP' : 'Resend in ${cd}s', style: p(14, w: FontWeight.w800, color: cd == 0 ? C.forest : Colors.black26)))),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Name screen
// ─────────────────────────────────────────────────────────────────────────────
class _NameScreen extends StatelessWidget {
  final TextEditingController nameCtrl; final bool busy; final VoidCallback onSubmit;
  const _NameScreen({super.key, required this.nameCtrl, required this.busy, required this.onSubmit});
  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 30),
          Text('Last Step', style: p(36, w: FontWeight.w900, color: Colors.black)),
          Text('Enter your name to complete your profile', style: p(15, color: Colors.black54)),
          const SizedBox(height: 54),
          GField(ctrl: nameCtrl, label: 'Full Name', hint: 'e.g. John Doe', icon: Icons.person_rounded),
          const SizedBox(height: 48),
          GBtn(label: 'Complete Profile', loading: busy, onTap: onSubmit, bg: C.forest),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP box
// ─────────────────────────────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller; final FocusNode focusNode; final ValueChanged<String> onChanged;
  const _OtpBox({required this.controller, required this.focusNode, required this.onChanged});
  @override
  Widget build(BuildContext ctx) => SizedBox(width: 48, height: 64, child: TextField(
    controller: controller, focusNode: focusNode,
    keyboardType: TextInputType.number, textAlign: TextAlign.center,
    maxLength: 1, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
    decoration: InputDecoration(
      counterText: '', contentPadding: EdgeInsets.zero,
      filled: true, fillColor: const Color(0xFFF2F5F8),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.forest, width: 2.5)),
    ),
    onChanged: onChanged,
  ));
}
