import 'package:flutter/material.dart';
import '../../../data/services/api.dart';
import '../../../data/services/razorpay_service.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

// ─── Wallet ───────────────────────────────────────────────────────────────────
// Balance + cashback offer + ledger history, all from the backend wallet
// ledger (amounts arrive in paise). Cashback credits expire (validity shown per
// entry); top-ups never do. Money is spent via "Use wallet" at any checkout.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override State<WalletScreen> createState() => _WalletState();
}

class _WalletState extends State<WalletScreen> {
  final _api = Api();
  Map<String, dynamic> _wallet = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final w = await _api.getWallet();
      if (mounted) setState(() { _wallet = asMap(w); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  double get _balance => asDouble(_wallet['balance']);
  List<dynamic> get _txns => asList(_wallet['transactions']);
  List<dynamic> get _expiring => asList(_wallet['expiring']);
  Map<String, dynamic> get _offer => asMap(_wallet['offer']);

  String _inrP(dynamic paise) => '₹${(asDouble(paise) / 100).toStringAsFixed(0)}';
  String _fmtDate(dynamic v, {bool time = false}) {
    final d = DateTime.tryParse(asStr(v).replaceFirst(' ', 'T'));
    if (d == null) return '—';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final base = '${d.day} ${m[d.month - 1]} ${d.year}';
    if (!time) return base;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$base, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _addMoney() async {
    final amounts = [100, 250, 500, 1000];
    int? chosen = amounts[1];
    final customCtrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add money to wallet', style: vx(18, w: FontWeight.w600, color: V.ink)),
          const SizedBox(height: 4),
          Text('Wallet money never expires and works on any booking or shop order.', style: p(12, color: V.fog)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: amounts.map((a) {
            final sel = chosen == a && customCtrl.text.isEmpty;
            return GestureDetector(
              onTap: () => setSheet(() { chosen = a; customCtrl.clear(); }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? V.leaf : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? V.leaf : const Color(0xFFE3E8E1)),
                ),
                child: Text('₹$a', style: p(14, w: FontWeight.w600, color: sel ? Colors.white : V.ink)),
              ),
            );
          }).toList()),
          const SizedBox(height: 12),
          TextField(
            controller: customCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setSheet(() {}),
            decoration: InputDecoration(
              hintText: 'Custom amount (₹)',
              hintStyle: p(13, color: V.fog),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE3E8E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE3E8E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: V.leaf)),
            ),
          ),
          const SizedBox(height: 16),
          GBtn(label: 'Add money', icon: Icons.add_rounded, glass: true, onTap: () => Navigator.pop(ctx, true)),
        ]),
      )),
    );
    final amount = customCtrl.text.isNotEmpty ? (int.tryParse(customCtrl.text.trim()) ?? 0) : (chosen ?? 0);
    customCtrl.dispose();
    if (confirmed != true || !mounted) return;
    if (amount < 1) { showMsg(context, 'Enter a valid amount', err: true); return; }
    final pay = await RazorpayService().pay(type: 'wallet_topup', amount: amount.toDouble());
    if (!mounted) return;
    showMsg(context, pay.ok ? '₹$amount added to your wallet!' : (pay.cancelled ? 'Top-up cancelled' : (pay.message ?? 'Payment failed')), ok: pay.ok, err: !pay.ok && !pay.cancelled);
    if (pay.ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final tiers = asList(_offer['tiers']);
    final validityDays = asInt(_offer['validity_days']);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F9F4),
        elevation: 0,
        foregroundColor: V.ink,
        title: Text('My Wallet', style: vx(18, w: FontWeight.w600, color: V.ink)),
      ),
      body: RefreshIndicator(
        color: V.leaf,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            // Balance card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: V.ink,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text('Available balance', style: p(12, color: Colors.white70)),
                ]),
                const SizedBox(height: 8),
                Text('₹${_balance.toStringAsFixed(0)}', style: vx(34, w: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Use it on any booking or shop order at checkout', style: p(11.5, color: Colors.white60)),
                const SizedBox(height: 14),
                GBtn(label: 'Add money', icon: Icons.add_rounded, h: 44, bg: Colors.white, labelColor: V.ink, onTap: _addMoney),
              ]),
            ),
            const SizedBox(height: 12),

            // Expiring soon
            if (_expiring.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF92400E)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    '${_inrP(asMap(_expiring.first)['amount_paise'])} expires on ${_fmtDate(asMap(_expiring.first)['expires_at'])} — use it on your next order!',
                    style: p(12, w: FontWeight.w600, color: const Color(0xFF92400E)),
                  )),
                ]),
              ),

            // Cashback offer
            if (_offer['enabled'] == true && tiers.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3E8E1)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('🎁  Cashback on every order', style: p(13, w: FontWeight.w700, color: V.ink)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: tiers.map((t) {
                    final m = asMap(t);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: V.leaf.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: V.leaf.withValues(alpha: 0.25)),
                      ),
                      child: Column(children: [
                        Text('₹${asInt(m['cashback'])}', style: p(14, w: FontWeight.w700, color: V.leaf)),
                        Text('on ₹${asInt(m['min_order'])}+', style: p(10.5, color: V.fog)),
                      ]),
                    );
                  }).toList()),
                  const SizedBox(height: 10),
                  Text('Cashback lands in your wallet when the order is paid and stays valid for $validityDays days.',
                      style: p(11.5, color: V.fog)),
                ]),
              ),

            Text('History', style: vx(16, w: FontWeight.w600, color: V.ink)),
            const SizedBox(height: 10),
            if (_loading)
              ...List.generate(4, (_) => Container(
                height: 66, margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              ))
            else if (_txns.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(children: [
                  const Icon(Icons.receipt_long_outlined, size: 40, color: V.fog),
                  const SizedBox(height: 10),
                  Text('No wallet activity yet', style: p(14, w: FontWeight.w600, color: V.ink)),
                  const SizedBox(height: 4),
                  Text('Place an order of ₹1000+ to earn your first cashback.', style: p(12, color: V.fog)),
                ]),
              )
            else ..._txns.map(_txTile),
          ],
        ),
      ),
    );
  }

  Widget _txTile(dynamic raw) {
    final t = asMap(raw);
    final credit = asStr(t['direction']) == 'credit';
    final expired = t['expired'] == true;
    final type = asStr(t['type']);
    final label = asStr(t['note']).isNotEmpty ? asStr(t['note'])
        : type == 'topup' ? 'Wallet top-up'
        : type == 'cashback' ? 'Cashback earned'
        : type == 'migration' ? 'Balance carried over'
        : type == 'admin' ? 'GharKaMali credit'
        : credit ? 'Wallet credit' : 'Paid from wallet';
    final amountColor = expired ? V.fog : credit ? V.leaf : V.ink;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E8E1)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (credit ? V.leaf : V.ink).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            type == 'cashback' ? Icons.card_giftcard_rounded
                : type == 'topup' ? Icons.add_card_rounded
                : credit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: 20, color: credit ? V.leaf : V.ink,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: p(13, w: FontWeight.w600, color: V.ink)),
          const SizedBox(height: 2),
          Text(
            _fmtDate(t['created_at'], time: true)
            + (credit && asStr(t['expires_at']).isNotEmpty && !expired ? ' · valid till ${_fmtDate(t['expires_at'])}' : '')
            + (expired ? ' · expired' : ''),
            style: p(11, color: expired ? const Color(0xFFDC2626) : V.fog),
          ),
        ])),
        Text(
          '${credit ? '+' : '-'}${_inrP(t['amount_paise'])}',
          style: p(14.5, w: FontWeight.w700, color: amountColor).copyWith(
            decoration: expired ? TextDecoration.lineThrough : TextDecoration.none,
          ),
        ),
      ]),
    );
  }
}
