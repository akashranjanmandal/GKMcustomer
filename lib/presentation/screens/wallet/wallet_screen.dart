import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../data/services/api.dart';
import '../../../data/services/auth.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override State<WalletScreen> createState() => _WalletState();
}
class _WalletState extends State<WalletScreen> {
  final _api = Api();
  List<dynamic> _txns = [];
  bool _loading = true, _topping = false;
  int _preset = 0;
  final _customCtrl = TextEditingController();
  static const _presets = [100, 200, 500, 1000, 2000, 5000];

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _customCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        _api.getProfile().catchError((_) => null),
        _api.getMyPayments().catchError((_) => null),
      ]);
      if (!mounted) return;
      if (r[0] != null) context.read<AuthProvider>().patchUser(asMap(r[0]));
      setState(() { _txns = asList(r[1]); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _topUp() async {
    final amt = _customCtrl.text.isNotEmpty ? double.tryParse(_customCtrl.text) ?? 0 : _preset.toDouble();
    if (amt < 100) { showMsg(context, 'Minimum top-up is ₹100', err: true); return; }
    setState(() => _topping = true);
    try {
      final res = await _api.walletTopup(amt);
      final url = asStr(asMap(res)['payu_url']);
      if (url.isNotEmpty) {
        showMsg(context, 'Redirecting to payment gateway…', ok: true);
        // In production: launch url via url_launcher
      } else {
        showMsg(context, '₹${amt.toStringAsFixed(0)} top-up initiated!', ok: true);
        setState(() { _preset = 0; _customCtrl.clear(); });
        await _load();
      }
    } on ApiError catch (e) { if (mounted) showMsg(context, e.message, err: true); }
    finally { if (mounted) setState(() => _topping = false); }
  }

  @override
  Widget build(BuildContext ctx) {
    final balance = ctx.watch<AuthProvider>().walletBalance;
    return Scaffold(
      primary: false,
      backgroundColor: C.bg,
      body: RefreshIndicator(
        color: C.forest, onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: GHeader(pb: 54,
            child: Column(children: [
              Text('MY WALLET', style: p(10, w: FontWeight.w700, color: Colors.white54, ls: 1.5)),
              const SizedBox(height: 10),
              Text('₹${balance.toStringAsFixed(2)}',
                style: p(44, w: FontWeight.w900, color: Colors.white, ls: -1.5, h: 1),
              ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
              const SizedBox(height: 6),
              Text('Available balance', style: p(13, color: Colors.white54)),
            ]))),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(delegate: SliverChildListDelegate([
              // ── Top-up card ───────────────────────────────────────────
              GCard(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GSec('Add Money'),
                const SizedBox(height: 14),
                GridView.count(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2,
                  children: _presets.map((amt) {
                    final sel = amt == _preset;
                    return GestureDetector(
                      onTap: () { HapticFeedback.selectionClick(); setState(() { _preset = amt; _customCtrl.clear(); }); },
                      child: AnimatedContainer(duration: 160.ms,
                        decoration: BoxDecoration(
                          color: sel ? C.forest : C.subtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: sel ? C.forest2 : C.border)),
                        alignment: Alignment.center,
                        child: Text('₹$amt',
                          style: p(14, w: FontWeight.w700, color: sel ? Colors.white : C.t2))));
                  }).toList()),
                const SizedBox(height: 14),
                TextField(
                  controller: _customCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: p(16, w: FontWeight.w600, color: C.t1),
                  onChanged: (_) => setState(() => _preset = 0),
                  decoration: InputDecoration(
                    hintText: 'Custom amount (min ₹100)',
                    prefixText: '₹ ',
                    prefixStyle: p(16, w: FontWeight.w600, color: C.t3))),
                const SizedBox(height: 16),
                GBtn(label: 'Add Money to Wallet', icon: Icons.add_rounded, loading: _topping, onTap: _topUp),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.lock_rounded, size: 13, color: C.t4),
                  const SizedBox(width: 5),
                  Text('Secured by PayU payment gateway', style: p(11, color: C.t4)),
                ]),
              ])).animate().fadeIn(),

              const SizedBox(height: 20),
              GSec('Transactions'),
              const SizedBox(height: 12),

              if (_loading) ...List.generate(4, (_) => const GSkelCard())
              else if (_txns.isEmpty)
                const GEmpty(title: 'No transactions', sub: 'Your payment history will appear here', icon: Icons.receipt_long_outlined)
              else GCard(padding: EdgeInsets.zero, child: Column(
                children: _txns.take(25).toList().asMap().entries.map((e) {
                  final tx = e.value; final isLast = e.key == _txns.take(25).length - 1;
                  final type = asStr(tx['transaction_type'] ?? tx['type']);
                  final credit = ['credit','wallet_topup','refund','cashback'].contains(type);
                  final amt = asDouble(tx['amount']);
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: isLast ? BorderSide.none : const BorderSide(color: C.divider))),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      leading: Container(width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: (credit ? C.green : C.red).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12)),
                        child: Icon(credit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          size: 18, color: credit ? C.green : C.red)),
                      title: Text(type.replaceAll('_', ' ').toUpperCase(),
                        style: p(11, w: FontWeight.w700, color: C.t2, ls: 0.3)),
                      subtitle: Text(asStr(tx['created_at']).length >= 10 ? asStr(tx['created_at']).substring(0,10) : '—', style: p(10, color: C.t4)),
                      trailing: Text('${credit ? '+' : '−'}₹${amt.toStringAsFixed(0)}',
                        style: p(15, w: FontWeight.w800, color: credit ? C.green : C.red)),
                    ));
                }).toList(),
              )).animate().fadeIn(delay: 100.ms),
            ])),
          ),
        ]),
      ),
    );
  }
}
