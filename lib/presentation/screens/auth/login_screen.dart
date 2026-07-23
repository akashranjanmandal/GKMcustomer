import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../data/services/api.dart';
import '../../../utils/validators.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoggedIn;
  const LoginScreen({super.key, required this.onLoggedIn});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final _api = Api();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());
  String _step = 'phone';
  bool _busy = false;
  int _cd = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    for (var c in _otpCtrls) c.dispose();
    for (var f in _otpFocus) f.dispose();
    super.dispose();
  }

  // Send a real OTP (MSG91) to the entered phone, then advance to the OTP screen.
  Future<void> _sendOtp() async {
    final phoneErr = Validators.phone(_phoneCtrl.text);
    if (phoneErr != null) return showMsg(context, phoneErr, err: true);
    final p = Validators.normalizePhone(_phoneCtrl.text);
    setState(() => _busy = true);
    try {
      await _api.sendOtp(p);
      if (mounted) {
        setState(() { _step = 'otp'; _busy = false; });
        showMsg(context, 'OTP sent to your phone');
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMsg(context, e.message, err: true);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrls.map((c) => c.text).join();
    final otpErr = Validators.otp(code, min: 6, max: 6);
    if (otpErr != null) return showMsg(context, otpErr, err: true);
    final p = Validators.normalizePhone(_phoneCtrl.text);
    setState(() => _busy = true);
    try {
      final res = await _api.verifyOtp(p, code);
      if (!mounted) return;
      if (res is Map && res['requires_name'] == true) {
        setState(() {
          _step = 'name';
          _busy = false;
        });
      } else {
        widget.onLoggedIn();
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMsg(context, e.message, err: true);
      }
    }
  }

  Future<void> _submitName() async {
    final nameErr = Validators.name(_nameCtrl.text);
    if (nameErr != null) return showMsg(context, nameErr, err: true);
    final n = _nameCtrl.text.trim();
    setState(() => _busy = true);
    try {
      final p = Validators.normalizePhone(_phoneCtrl.text);
      final code = _otpCtrls.map((c) => c.text).join();
      await _api.verifyOtp(p, code, name: n);
      if (mounted) widget.onLoggedIn();
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMsg(context, e.message, err: true);
      }
    }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
        backgroundColor: C.forest,
        resizeToAvoidBottomInset: true,
        body: AnimatedSwitcher(
          duration: 500.ms,
          child: switch (_step) {
            'otp' => _OtpScreen(
                key: const ValueKey('otp'),
                phone: _phoneCtrl.text,
                controllers: _otpCtrls,
                focusNodes: _otpFocus,
                busy: _busy,
                cd: _cd,
                onBack: () => setState(() {
                      _step = 'phone';
                      for (final c in _otpCtrls) c.clear();
                    }),
                onVerify: _verifyOtp,
                onResend: _sendOtp,
                onChange: (_) => setState(() {})),
            'name' => _NameScreen(
                key: const ValueKey('name'),
                nameCtrl: _nameCtrl,
                busy: _busy,
                onSubmit: _submitName),
            _ => _PhoneScreen(
                key: const ValueKey('phone'),
                phoneCtrl: _phoneCtrl,
                busy: _busy,
                onSend: _sendOtp,
                onPhoneChanged: (_) => setState(() {})),
          },
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile model
// ─────────────────────────────────────────────────────────────────────────────
class _ImgTile {
  final String img;
  final String label;
  const _ImgTile(this.img, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// Phone screen — Pronto-style layout
// ─────────────────────────────────────────────────────────────────────────────
class _PhoneScreen extends StatelessWidget {
  final TextEditingController phoneCtrl;
  final bool busy;
  final VoidCallback onSend;
  final ValueChanged<String> onPhoneChanged;
  const _PhoneScreen(
      {super.key,
      required this.phoneCtrl,
      required this.busy,
      required this.onSend,
      required this.onPhoneChanged});

  static const _r1 = [
    _ImgTile('assets/images/img-1.jpeg', 'Balcony'),
    _ImgTile('assets/images/img-2.jpeg', 'Terrace'),
    _ImgTile('assets/images/img-3.jpeg', 'Indoor'),
    _ImgTile('assets/images/img-4.jpeg', 'Garden'),
    _ImgTile('assets/images/img-5.jpeg', 'Patio'),
  ];
  static const _r2 = [
    _ImgTile('assets/images/img-6.jpeg', 'Lawn'),
    _ImgTile('assets/images/img-7.jpeg', 'Office'),
    _ImgTile('assets/images/img-8.jpeg', 'Vertical'),
    _ImgTile('assets/images/img-9.jpeg', 'Backyard'),
    _ImgTile('assets/images/img-10.jpeg', 'Kitchen'),
  ];
  static const _r3 = [
    _ImgTile('assets/images/img-11.jpeg', 'Rooftop'),
    _ImgTile('assets/images/img-12.jpeg', 'Courtyard'),
    _ImgTile('assets/images/img-13.jpeg', 'Porch'),
    _ImgTile('assets/images/img-14.jpeg', 'Living'),
    _ImgTile('assets/images/img-15.jpeg', 'Desk'),
    _ImgTile('assets/images/img-16.jpeg', 'Window'),
  ];

  @override
  Widget build(BuildContext ctx) {
    final canContinue =
        phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length == 10;
    final top = MediaQuery.of(ctx).padding.top;
    final bot = MediaQuery.of(ctx).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(children: [
          // ── Green hero card — rounded bottom corners, logo + tagline + photo grid ──
          // Stacked so a green→white gradient can bleed over the card's tail,
          // softening the seam into the white section below instead of a hard cut.
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
              child: Container(
                color: C.forest,
                padding: EdgeInsets.fromLTRB(24, top + 28, 24, 0),
                child: Column(children: [
                  Image.asset('assets/images/logo.png',
                          height: 96, fit: BoxFit.contain)
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(0.88, 0.88)),
                  const SizedBox(height: 24),
                  // Photo grid — three auto-scrolling rows, cropped by the card edge.
                  // Faded out (via ShaderMask) starting halfway down so the third
                  // row dissolves into the green background instead of hard-cutting.
                  ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0.0, 0.5, 1.0],
                    ).createShader(rect),
                    child: SizedBox(
                      height: 274,
                      child: ClipRect(
                        child: Column(children: [
                          const SizedBox(height: 4),
                          _MarqueeRow(tiles: _r1, duration: const Duration(seconds: 36), reverse: false),
                          const SizedBox(height: 8),
                          _MarqueeRow(tiles: _r2, duration: const Duration(seconds: 30), reverse: true),
                          const SizedBox(height: 8),
                          _MarqueeRow(tiles: _r3, duration: const Duration(seconds: 40), reverse: false),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            // Green → white bleed, anchored to the bottom of the whole card.
            Positioned(
              left: 0, right: 0, bottom: 0, height: 140,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [C.forest.withOpacity(0), Colors.white],
                      stops: const [0.0, 0.92],
                    ),
                  ),
                ),
              ),
            ),
          ]),

          // ── White section — Log in or Sign up ───────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 24, bot > 0 ? bot + 20 : 28),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log in or Sign up',
                      style: p(24, w: FontWeight.w900, color: Colors.black)),
                  const SizedBox(height: 24),
                  Text('Mobile Number',
                      style: p(13, w: FontWeight.w600, color: C.t3)),
                  const SizedBox(height: 10),
                  _LoginInput(
                    child: Row(children: [
                      const SizedBox(width: 16),
                      const Icon(Icons.phone_android_rounded,
                          size: 20, color: C.forest),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _rawField(
                        ctrl: phoneCtrl,
                        hint: 'e.g. 7319XXXXXX',
                        onChanged: onPhoneChanged,
                        keyboard: TextInputType.phone,
                        formatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10)
                        ],
                      )),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  GBtn(
                      label: 'Continue',
                      loading: busy,
                      onTap: canContinue ? onSend : null,
                      bg: canContinue ? C.forest : Colors.grey[300]!),
                  const SizedBox(height: 18),
                  Center(
                      child: Text.rich(TextSpan(
                          style: p(12, color: Colors.black38, h: 1.5),
                          children: [
                        const TextSpan(
                            text: 'By continuing, you agree to our '),
                        TextSpan(
                            text: 'Terms of Service',
                            style: p(12,
                                w: FontWeight.w700, color: Colors.black54),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => launchUrlString(_legalUrl)),
                        const TextSpan(text: ' & '),
                        TextSpan(
                            text: 'Privacy Policy',
                            style: p(12,
                                w: FontWeight.w700, color: Colors.black54),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => launchUrlString(_legalUrl)),
                      ]))),
                ]),
          ),
        ]),
      ),
    );
  }
}

const _legalUrl = 'https://gharkamali.com/terms';

// ─────────────────────────────────────────────────────────────────────────────
// Seamless marquee row
// ─────────────────────────────────────────────────────────────────────────────
class _MarqueeRow extends StatefulWidget {
  final List<_ImgTile> tiles;
  final Duration duration;
  final bool reverse;
  const _MarqueeRow(
      {required this.tiles, required this.duration, required this.reverse});
  @override
  State<_MarqueeRow> createState() => _MarqueeRowState();
}

class _MarqueeRowState extends State<_MarqueeRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const double _w = 120;
  static const double _h = 76;
  static const double _gap = 12;
  static const double _stride = _w + _gap;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final n = widget.tiles.length;
    final loopW = n * _stride;
    final reps = 4;

    return Container(
      height: _h + 10,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final raw = (_ctrl.value * loopW) % loopW;
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
                      height: _h,
                      margin: const EdgeInsets.only(right: _gap),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: ResizeImage(AssetImage(t.img), width: 300),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ),
    );
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
}) =>
    TextField(
      controller: ctrl,
      onChanged: onChanged,
      keyboardType: keyboard,
      inputFormatters: formatters,
      style: p(15, w: FontWeight.w600, color: C.t1),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: C.t4, fontSize: 14, fontWeight: FontWeight.w400),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// OTP screen
// ─────────────────────────────────────────────────────────────────────────────
class _OtpScreen extends StatelessWidget {
  final String phone;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool busy;
  final int cd;
  final VoidCallback onBack, onVerify, onResend;
  final ValueChanged<String> onChange;
  const _OtpScreen(
      {super.key,
      required this.phone,
      required this.controllers,
      required this.focusNodes,
      required this.busy,
      required this.cd,
      required this.onBack,
      required this.onVerify,
      required this.onResend,
      required this.onChange});

  @override
  Widget build(BuildContext ctx) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.black))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('OTP verification',
                style: p(26, w: FontWeight.w900, color: Colors.black)),
            const SizedBox(height: 8),
            Text('Enter the 6-digit code sent to +91 $phone',
                style: p(14, color: Colors.black54)),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: C.forest.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: C.forest.withValues(alpha: 0.18), width: 1.2),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chevron_left, size: 16, color: C.forest),
                  const SizedBox(width: 4),
                  Text('Change number', style: p(13, w: FontWeight.w700, color: C.forest)),
                ]),
              ),
            ),
            const SizedBox(height: 48),
            AutofillGroup(
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                      6,
                      (i) => _OtpBox(
                            controller: controllers[i],
                            focusNode: focusNodes[i],
                            autofillHint: i == 0,
                            onChanged: (v) {
                              // The OS SMS-autofill suggestion pastes the full
                              // code into whichever box is focused — spread it
                              // across all 6 boxes instead of just the one.
                              if (v.length > 1) {
                                final digits = v.replaceAll(RegExp(r'\D'), '');
                                for (var j = 0; j < 6; j++) {
                                  controllers[j].text = j < digits.length ? digits[j] : '';
                                }
                                if (digits.length >= 6) {
                                  focusNodes[5].requestFocus();
                                } else {
                                  focusNodes[digits.length.clamp(0, 5)].requestFocus();
                                }
                              } else {
                                if (v.isNotEmpty && i < 5) focusNodes[i + 1].requestFocus();
                                if (v.isEmpty && i > 0) focusNodes[i - 1].requestFocus();
                              }
                              onChange(v);

                              // Auto submit when all fields are filled
                              final code = controllers.map((c) => c.text).join();
                              if (code.length == 6) onVerify();
                            },
                          ))),
            ),
            const SizedBox(height: 48),
            GBtn(
                label: 'Verify OTP',
                loading: busy,
                onTap: onVerify,
                bg: C.forest),
            const SizedBox(height: 28),
            Center(
                child: TextButton(
                    onPressed: cd == 0 ? onResend : null,
                    child: Text(cd == 0 ? 'Resend OTP' : 'Resend in ${cd}s',
                        style: p(14,
                            w: FontWeight.w800,
                            color: cd == 0 ? C.forest : Colors.black26)))),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Name screen
// ─────────────────────────────────────────────────────────────────────────────
class _NameScreen extends StatelessWidget {
  final TextEditingController nameCtrl;
  final bool busy;
  final VoidCallback onSubmit;
  const _NameScreen(
      {super.key,
      required this.nameCtrl,
      required this.busy,
      required this.onSubmit});
  @override
  Widget build(BuildContext ctx) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 30),
              Text('Last Step',
                  style: p(36, w: FontWeight.w900, color: Colors.black)),
              Text('Enter your name to complete your profile',
                  style: p(15, color: Colors.black54)),
              const SizedBox(height: 54),
              GField(
                  ctrl: nameCtrl,
                  label: 'Full Name',
                  hint: 'e.g. John Doe',
                  icon: Icons.person_rounded),
              const SizedBox(height: 48),
              GBtn(
                  label: 'Complete Profile',
                  loading: busy,
                  onTap: onSubmit,
                  bg: C.forest),
            ]),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP box
// ─────────────────────────────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  // Only the first box carries the SMS-autofill hint. Its maxLength stays
  // high (6) so the OS can paste the *whole* code into it — onChanged then
  // spreads those digits across all 6 boxes. Other boxes stay capped at 1
  // for normal manual digit-by-digit typing.
  final bool autofillHint;
  const _OtpBox(
      {required this.controller,
      required this.focusNode,
      required this.onChanged,
      this.autofillHint = false});
  @override
  Widget build(BuildContext ctx) => SizedBox(
      width: 48,
      height: 64,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: autofillHint ? 6 : 1,
        autofillHints: autofillHint ? const [AutofillHints.oneTimeCode] : null,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: const Color(0xFFF2F5F8),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: C.forest, width: 2.5)),
        ),
        onChanged: onChanged,
      ));
}
