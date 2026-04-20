import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../data/services/api.dart';
import '../../../data/services/auth.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

// ─── Profile ──────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});
  @override State<ProfileScreen> createState() => _ProfileState();
}
class _ProfileState extends State<ProfileScreen> {
  final _api    = Api();
  final _picker = ImagePicker();
  bool _saving  = false;
  File? _newImg;

  Future<void> _pickImage() async {
    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (f != null) {
      setState(() => _newImg = File(f.path));
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    setState(() => _saving = true);
    try {
      final r = await _api.updateProfile(profileImage: _newImg);
      if (!mounted) return;
      context.read<AuthProvider>().patchUser(asMap(r));
      setState(() { _saving = false; _newImg = null; });
      showMsg(context, 'Profile photo updated!', ok: true);
    } on ApiError catch (e) {
      if (mounted) { setState(() { _saving = false; _newImg = null; }); showMsg(context, e.message, err: true); }
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Sign Out?', style: p(17, w: FontWeight.w700, color: C.t1)),
      content: Text('You\'ll need to log in again.', style: p(14, color: C.t3)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: p(14, color: C.t3))),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: Text('Sign Out', style: p(14, w: FontWeight.w700, color: C.red))),
      ]));
    if (ok == true) { await context.read<AuthProvider>().logout(); widget.onLogout(); }
  }

  @override
  Widget build(BuildContext ctx) {
    final auth  = ctx.watch<AuthProvider>();
    final name  = auth.name;
    final phone = auth.phone;
    final imgUrl = auth.profileImage;

    return Scaffold(
      primary: false,
      backgroundColor: C.bg,
      body: CustomScrollView(slivers: [
        // ── Dark green header ─────────────────────────────────────────────
        SliverToBoxAdapter(child: Container(
          decoration: const BoxDecoration(color: Color(0xFF052B11)),
          child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(children: [
              Row(children: [
                // Avatar
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(children: [
                    Container(width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.12),
                        border: Border.all(color: Colors.white24, width: 2)),
                      child: ClipOval(child: _saving
                        ? Center(child: SizedBox(width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: C.gold)))
                        : _newImg != null ? Image.file(_newImg!, fit: BoxFit.cover)
                        : imgUrl != null ? Image.network(imgUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _initials(name))
                        : _initials(name))),
                    Positioned(right: 0, bottom: 0,
                      child: Container(width: 22, height: 22,
                        decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, size: 12, color: Color(0xFF1A0F00)))),
                  ]),
                ),
                const SizedBox(width: 16),
                // Name + phone
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: p(18, w: FontWeight.w800, color: Colors.white)).animate().fadeIn(),
                  const SizedBox(height: 3),
                  Text('+91 $phone', style: p(13, color: Colors.white54)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(ctx, '/edit-profile'),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Edit profile', style: p(12, w: FontWeight.w600, color: C.gold)),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: C.gold),
                    ]),
                  ),
                ])),
              ]),
            ]),
          )),
        )),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // ── Quick actions grid ───────────────────────────────────────
            Row(children: [
              Expanded(child: _QuickTile(
                icon: Icons.calendar_month_rounded,
                label: 'My\nbookings',
                onTap: () => Navigator.pushNamed(ctx, '/bookings'),
              )),
              const SizedBox(width: 12),
              Expanded(child: _QuickTile(
                icon: Icons.headset_mic_rounded,
                label: 'Help &\nSupport',
                onTap: () => Navigator.pushNamed(ctx, '/complaints'),
              )),
            ]).animate().fadeIn(delay: 60.ms),
            const SizedBox(height: 16),

            // ── Menu list ────────────────────────────────────────────────
            GCard(padding: EdgeInsets.zero, child: Column(children: [
              _MenuItem(Icons.repeat_rounded,                  'Subscriptions',        () => Navigator.pushNamed(ctx, '/subscriptions')),
              _MenuItem(Icons.account_balance_wallet_rounded,  'Wallet',               () => Navigator.pushNamed(ctx, '/wallet'),
                badge: '₹${auth.walletBalance.toStringAsFixed(0)}'),
              _MenuItem(Icons.storefront_rounded,              'Shop',                 () => Navigator.pushNamed(ctx, '/shop')),
              _MenuItem(Icons.shopping_bag_outlined,           'My Orders',            () => Navigator.pushNamed(ctx, '/shop/orders')),
              _MenuItem(Icons.psychology_rounded,              'Plantopedia',          () => Navigator.pushNamed(ctx, '/plantopedia')),
              _MenuItem(Icons.notifications_rounded,           'Notifications',        () => Navigator.pushNamed(ctx, '/notifications')),
              _MenuItem(Icons.map_outlined,                    'Saved addresses',      () {}),
              _MenuItem(Icons.info_outline_rounded,            'About us',             () {}),
              _MenuItem(Icons.description_outlined,            'Terms of services',    () {}),
              _MenuItem(Icons.shield_outlined,                 'Privacy policy',       () {}),
              _MenuItem(Icons.delete_outline_rounded,          'Request account deletion', () {}, danger: true, last: true),
            ])).animate().fadeIn(delay: 140.ms),
            const SizedBox(height: 16),

            // ── Logout ───────────────────────────────────────────────────
            GCard(
              onTap: _logout, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: C.red.withOpacity(0.08), borderRadius: BorderRadius.circular(11)),
                  child: Icon(Icons.logout_rounded, size: 20, color: C.red)),
                const SizedBox(width: 14),
                Text('Log out', style: p(14, w: FontWeight.w600, color: C.red)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, size: 18, color: C.t4),
              ]),
            ).animate().fadeIn(delay: 180.ms),
            const SizedBox(height: 10),
            Center(child: Text('GharKaMali v1.0 · Developed by Gobt',
              style: p(11, color: C.t4))).animate().fadeIn(delay: 200.ms),
          ])),
        ),
      ]),
    );
  }

  Widget _initials(String name) => Center(
    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
      style: p(26, w: FontWeight.w800, color: Colors.white)));
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext ctx) => GCard(
    onTap: onTap,
    padding: const EdgeInsets.all(18),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 28, color: C.forest),
      const SizedBox(height: 10),
      Text(label, style: p(13, w: FontWeight.w700, color: C.t1, h: 1.3),
        textAlign: TextAlign.center),
    ]),
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final bool danger, last;
  const _MenuItem(this.icon, this.label, this.onTap, {this.badge, this.danger = false, this.last = false});

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: last ? BorderSide.none : BorderSide(color: C.divider))),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
            color: (danger ? C.red : C.forest).withOpacity(0.07),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: danger ? C.red : C.forest)),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
          style: p(14, w: FontWeight.w600, color: danger ? C.red : C.t1))),
        if (badge != null) ...[
          Text(badge!, style: p(13, w: FontWeight.w700, color: C.forest)),
          const SizedBox(width: 4),
        ],
        Icon(Icons.chevron_right_rounded, size: 18, color: danger ? C.red.withOpacity(0.5) : C.t4),
      ]),
    ),
  );
}


