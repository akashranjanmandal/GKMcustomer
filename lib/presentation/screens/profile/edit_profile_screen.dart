import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../data/services/api.dart';
import '../../../data/services/auth.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _api    = Api();
  final _picker = ImagePicker();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _saving = false;
  File? _newImg;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameCtrl.text  = auth.name == 'User' ? '' : auth.name;
    _emailCtrl.text = auth.email ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (f != null) setState(() => _newImg = File(f.path));
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _save() async {
    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (name.isEmpty) {
      showMsg(context, 'Name cannot be empty', err: true);
      return;
    }
    if (email.isEmpty) {
      showMsg(context, 'Email is required', err: true);
      return;
    }
    if (!_isValidEmail(email)) {
      showMsg(context, 'Please enter a valid email address', err: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await _api.updateProfile(
        name:         name,
        email:        email,
        profileImage: _newImg,
      );
      if (!mounted) return;
      context.read<AuthProvider>().patchUser(asMap(r));
      showMsg(context, 'Profile updated!', ok: true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      if (mounted) showMsg(context, e.message, err: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final auth   = ctx.watch<AuthProvider>();
    final imgUrl = auth.profileImage;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 110),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const VPageHeader(title: 'Your profile', subtitle: 'How we address you and send receipts.'),
            const SizedBox(height: 26),
            Center(child: GestureDetector(
              onTap: _pickImage,
              child: Stack(children: [
                Container(
                  width: 120, height: 120,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white,
                    boxShadow: [BoxShadow(color: V.ink.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10))]),
                  child: ClipOval(child: Container(
                    color: V.deep,
                    child: _newImg != null
                      ? Image.file(_newImg!, fit: BoxFit.cover)
                      : imgUrl != null
                        ? Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials(auth.name))
                        : _initials(auth.name),
                  )),
                ),
                Positioned(right: 2, bottom: 2,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: V.lime, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                    child: const Icon(Icons.photo_camera_outlined, size: 17, color: V.ink),
                  )),
              ]),
            )),
            const SizedBox(height: 10),
            Center(child: Text('Tap to change photo', style: p(12, color: V.fog))),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                _ReadOnlyField(
                  label: 'Mobile number',
                  value: auth.phone.isNotEmpty ? '+91 ${auth.phone}' : 'Not available',
                  icon: Icons.phone_iphone_rounded,
                ),
                const SizedBox(height: 18),
                GField(ctrl: _nameCtrl, label: 'Full name', hint: 'e.g. Rahul Sharma', icon: Icons.person_outline_rounded),
                const SizedBox(height: 18),
                GField(ctrl: _emailCtrl, label: 'Email', hint: 'e.g. rahul@email.com', icon: Icons.mail_outline_rounded, keyboard: TextInputType.emailAddress),
              ]),
            ),
          ]),
        ),
        Positioned(left: 16, right: 16, bottom: MediaQuery.of(ctx).padding.bottom + 14,
          child: GBtn(label: 'Save changes', loading: _saving, onTap: _save)),
      ]),
    );
  }

  Widget _initials(String name) => Center(
    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
      style: vx(42, w: FontWeight.w600, color: Colors.white)));
}

class _ReadOnlyField extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _ReadOnlyField({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(label.toUpperCase(), style: vx(10.5, w: FontWeight.w700, color: V.fog, ls: 1.4))),
    Container(
      height: 56,
      decoration: BoxDecoration(color: V.ink.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        const SizedBox(width: 16),
        Icon(icon, size: 20, color: V.fog),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: p(15, w: FontWeight.w600, color: V.ink.withValues(alpha: 0.6)))),
        const Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.lock_outline_rounded, size: 17, color: V.fog)),
      ]),
    ),
  ]);
}
