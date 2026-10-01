import 'dart:async';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../data/services/api.dart';
import '../../../data/services/push_service.dart';
import '../../../utils/validators.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

// Placeholder background — swap for the client-supplied photo when it arrives.
const _kLoginBg = 'assets/images/img-10.jpeg';
const _kGreenBtn = Color(0xFF4CB648);
const _kLink = Color(0xFFF2B65A);
const _legalUrl = 'https://gharkamali.com/terms';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoggedIn;
  // Shown over a page because the session ended: opens straight on the number
  // step, and backing out closes the screen instead of going to "Hello!".
  final bool reauth;
  const LoginScreen({super.key, required this.onLoggedIn, this.reauth = false});
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
  // welcome → phone → otp → (name, for new users)
  late String _step = widget.reauth ? 'phone' : 'welcome';
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
    if (_busy) return;
    final code = _otpCtrls.map((c) => c.text).join();
    final otpErr = Validators.otp(code, min: 6, max: 6);
    if (otpErr != null) return showMsg(context, otpErr, err: true);
    final p = Validators.normalizePhone(_phoneCtrl.text);
    setState(() => _busy = true);
    try {
      final res = await _api.verifyOtp(p, code,
          fcmToken: await PushService.instance.getToken());
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
      await _api.verifyOtp(p, code, name: n,
          fcmToken: await PushService.instance.getToken());
      if (mounted) widget.onLoggedIn();
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMsg(context, e.message, err: true);
      }
    }
  }

  void _clearOtp() {
    for (final c in _otpCtrls) c.clear();
  }

  // One step back through the flow (top-left arrow and Android back).
  void _back() {
    FocusScope.of(context).unfocus();
    setState(() {
      switch (_step) {
        case 'phone':
          if (widget.reauth) {
            Navigator.of(context).pop(false);
            return;
          }
          _step = 'welcome';
        case 'otp':
        case 'name':
          _clearOtp();
          _step = 'phone';
      }
    });
  }

  void _toPhone() => setState(() => _step = 'phone');

  @override
  Widget build(BuildContext ctx) {
    final card = switch (_step) {
      'phone' => _PhoneCard(
          key: const ValueKey('phone'),
          phoneCtrl: _phoneCtrl,
          reauth: widget.reauth,
          busy: _busy,
          onSend: _sendOtp,
          onChanged: (_) => setState(() {})),
      'otp' => _OtpCard(
          key: const ValueKey('otp'),
          phone: _phoneCtrl.text,
          controllers: _otpCtrls,
          focusNodes: _otpFocus,
          busy: _busy,
          cd: _cd,
          onVerify: _verifyOtp,
          onResend: _sendOtp,
          onChangeNumber: _back,
          onChange: (_) => setState(() {})),
      'name' => _NameCard(
          key: const ValueKey('name'),
          nameCtrl: _nameCtrl,
          busy: _busy,
          onSubmit: _submitName),
      _ => _WelcomeCard(
          key: const ValueKey('welcome'),
          onSignIn: _toPhone),
    };

    return PopScope(
      canPop: _step == 'welcome' || (widget.reauth && _step == 'phone'),
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _back(); },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: const Color(0xFF07160C),
          resizeToAvoidBottomInset: true,
          body: Stack(children: [
            // Full-bleed photo, darkened + tinted green so the glass card reads.
            Positioned.fill(child: Image.asset(_kLoginBg, fit: BoxFit.cover)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF041A0B).withValues(alpha: 0.55),
                      const Color(0xFF062611).withValues(alpha: 0.72),
                      const Color(0xFF041A0B).withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(children: [
                SizedBox(
                  height: 52,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: _step == 'welcome' ? 0 : 1,
                      child: IgnorePointer(
                        ignoring: _step == 'welcome',
                        child: IconButton(
                          onPressed: _back,
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 52),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(
                            scale: Tween(begin: 0.96, end: 1.0).animate(a),
                            child: child,
                          ),
                        ),
                        child: card,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Frosted glass card + shared controls
// ─────────────────────────────────────────────────────────────────────────────
class _Glass extends StatelessWidget {
  final Widget child;
  final double minHeight;
  const _Glass({required this.child, this.minHeight = 0});
  @override
  Widget build(BuildContext ctx) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.32), width: 1),
            ),
            child: child,
          ),
        ),
      );
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const _PillButton({required this.label, this.onTap, this.busy = false});
  @override
  Widget build(BuildContext ctx) {
    final enabled = onTap != null && !busy;
    return GestureDetector(
      onTap: enabled ? () { HapticFeedback.lightImpact(); onTap!(); } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? _kGreenBtn.withValues(alpha: 0.45) : _kGreenBtn,
          borderRadius: BorderRadius.circular(99),
        ),
        child: busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
            : Text(label.toUpperCase(), style: p(14.5, w: FontWeight.w500, color: Colors.white, ls: 0.4)),
      ),
    );
  }
}

// Outlined pill input (transparent, white border) — matches the reference.
class _PillField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final Widget? prefix;
  final ValueChanged<String>? onChanged;
  final TextInputType keyboard;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization caps;
  const _PillField({
    required this.ctrl,
    required this.hint,
    this.prefix,
    this.onChanged,
    this.keyboard = TextInputType.text,
    this.formatters,
    this.caps = TextCapitalization.none,
  });
  @override
  Widget build(BuildContext ctx) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.2),
        ),
        child: Row(children: [
          if (prefix != null) prefix!,
          Expanded(
            child: TextField(
              controller: ctrl,
              onChanged: onChanged,
              keyboardType: keyboard,
              inputFormatters: formatters,
              textCapitalization: caps,
              cursorColor: Colors.white,
              style: p(14, w: FontWeight.w500, color: Colors.white),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: p(14, color: Colors.white.withValues(alpha: 0.6)),
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
            ),
          ),
        ]),
      );
}

// "Question? Action" line at the bottom of the card.
Widget _footerLine(String q, String action, VoidCallback onTap) => Center(
      child: Text.rich(TextSpan(
        style: p(12, color: Colors.white.withValues(alpha: 0.85)),
        children: [
          TextSpan(text: '$q '),
          TextSpan(
            text: action,
            style: p(12, w: FontWeight.w600, color: _kLink),
            recognizer: TapGestureRecognizer()..onTap = onTap,
          ),
        ],
      )),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Hello!
// ─────────────────────────────────────────────────────────────────────────────
class _WelcomeCard extends StatelessWidget {
  final VoidCallback onSignIn;
  const _WelcomeCard({super.key, required this.onSignIn});
  @override
  Widget build(BuildContext ctx) => _Glass(
        minHeight: MediaQuery.of(ctx).size.height * 0.42,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: MediaQuery.of(ctx).size.height * 0.06),
            Text('Hello!', style: p(30, w: FontWeight.w500, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Expert gardeners at your doorstep — plant care, makeovers and a shop for everything green.',
                style: p(13, color: Colors.white.withValues(alpha: 0.85), h: 1.45)),
            const SizedBox(height: 28),
            _PillButton(label: 'Sign in', onTap: onSignIn),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Mobile number
// ─────────────────────────────────────────────────────────────────────────────
class _PhoneCard extends StatelessWidget {
  final TextEditingController phoneCtrl;
  final bool busy, reauth;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;
  const _PhoneCard({
    super.key,
    required this.phoneCtrl,
    required this.busy,
    this.reauth = false,
    required this.onSend,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext ctx) {
    final canContinue = phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length == 10;
    return _Glass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Sign in',
            style: p(20, w: FontWeight.w500, color: Colors.white)),
        const SizedBox(height: 6),
        Text(reauth
            ? 'Please sign in to continue. You\'ll be brought right back to where you were.'
            : 'We\'ll send a one-time code to your mobile number.',
            style: p(12, color: Colors.white.withValues(alpha: 0.75), h: 1.4)),
        const SizedBox(height: 22),
        _PillField(
          ctrl: phoneCtrl,
          hint: 'Mobile number',
          keyboard: TextInputType.phone,
          onChanged: onChanged,
          formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          prefix: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('+91', style: p(14, w: FontWeight.w600, color: Colors.white)),
              Container(width: 1, height: 18, margin: const EdgeInsets.only(left: 10), color: Colors.white54),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        _PillButton(label: 'Get OTP', busy: busy, onTap: canContinue ? onSend : null),
        const SizedBox(height: 14),
        Center(
          child: Text.rich(TextSpan(
            style: p(11, color: Colors.white.withValues(alpha: 0.7), h: 1.5),
            children: [
              const TextSpan(text: 'By continuing you agree to our '),
              TextSpan(
                text: 'Terms',
                style: p(11, w: FontWeight.w600, color: Colors.white),
                recognizer: TapGestureRecognizer()..onTap = () => launchUrlString(_legalUrl),
              ),
              const TextSpan(text: ' & '),
              TextSpan(
                text: 'Privacy Policy',
                style: p(11, w: FontWeight.w600, color: Colors.white),
                recognizer: TapGestureRecognizer()..onTap = () => launchUrlString(_legalUrl),
              ),
            ],
          ), textAlign: TextAlign.center),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — OTP
// ─────────────────────────────────────────────────────────────────────────────
class _OtpCard extends StatelessWidget {
  final String phone;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool busy;
  final int cd;
  final VoidCallback onVerify, onResend, onChangeNumber;
  final ValueChanged<String> onChange;
  const _OtpCard({
    super.key,
    required this.phone,
    required this.controllers,
    required this.focusNodes,
    required this.busy,
    required this.cd,
    required this.onVerify,
    required this.onResend,
    required this.onChangeNumber,
    required this.onChange,
  });

  @override
  Widget build(BuildContext ctx) => _Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Verify OTP', style: p(20, w: FontWeight.w500, color: Colors.white)),
          const SizedBox(height: 6),
          Text('Enter the 6-digit code sent to +91 $phone',
              style: p(12, color: Colors.white.withValues(alpha: 0.75), h: 1.4)),
          const SizedBox(height: 22),
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
                    // The OS SMS-autofill suggestion pastes the full code
                    // into whichever box is focused — spread it across all 6.
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
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _PillButton(label: 'Verify', busy: busy, onTap: onVerify),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: cd == 0 && !busy ? onResend : null,
              child: Text(cd == 0 ? 'Resend OTP' : 'Resend in ${cd}s',
                  style: p(12, color: Colors.white.withValues(alpha: cd == 0 ? 0.9 : 0.4))),
            ),
          ),
          const SizedBox(height: 10),
          _footerLine('Wrong number?', 'Change', onChangeNumber),
        ]),
      );
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  // Only the first box carries the SMS-autofill hint. Its maxLength stays
  // high (6) so the OS can paste the *whole* code into it — onChanged then
  // spreads those digits across all 6 boxes. Other boxes stay capped at 1
  // for normal manual digit-by-digit typing.
  final bool autofillHint;
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.autofillHint = false,
  });
  @override
  Widget build(BuildContext ctx) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return SizedBox(
      width: 38,
      height: 48,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: autofillHint ? 6 : 1,
        autofillHints: autofillHint ? const [AutofillHints.oneTimeCode] : null,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        cursorColor: Colors.white,
        style: p(19, w: FontWeight.w600, color: Colors.white),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: b(Colors.white.withValues(alpha: 0.7), 1.2),
          enabledBorder: b(Colors.white.withValues(alpha: 0.7), 1.2),
          focusedBorder: b(_kGreenBtn, 2),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4 — Name (new users only)
// ─────────────────────────────────────────────────────────────────────────────
class _NameCard extends StatelessWidget {
  final TextEditingController nameCtrl;
  final bool busy;
  final VoidCallback onSubmit;
  const _NameCard({super.key, required this.nameCtrl, required this.busy, required this.onSubmit});
  @override
  Widget build(BuildContext ctx) => _Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Last step', style: p(20, w: FontWeight.w500, color: Colors.white)),
          const SizedBox(height: 6),
          Text('Tell us your name to complete your profile.',
              style: p(12, color: Colors.white.withValues(alpha: 0.75), h: 1.4)),
          const SizedBox(height: 22),
          _PillField(ctrl: nameCtrl, hint: 'Full name', caps: TextCapitalization.words),
          const SizedBox(height: 18),
          _PillButton(label: 'Continue', busy: busy, onTap: onSubmit),
        ]),
      );
}
