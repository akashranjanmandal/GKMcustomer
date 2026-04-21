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

  Future<void> _save() async {
    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (name.isEmpty) {
      showMsg(context, 'Name cannot be empty', err: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await _api.updateProfile(
        name:         name,
        email:        email.isNotEmpty ? email : null,
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
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(ctx),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: C.t1),
        ),
        title: Text('Edit Profile', style: p(17, w: FontWeight.w800, color: C.t1)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Divider(height: 1, color: C.divider),
          const SizedBox(height: 32),

          // Avatar picker
          Center(child: GestureDetector(
            onTap: _pickImage,
            child: Stack(children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: C.forest.withOpacity(0.1),
                  border: Border.all(color: C.forest.withOpacity(0.2), width: 2),
                ),
                child: ClipOval(child: _newImg != null
                  ? Image.file(_newImg!, fit: BoxFit.cover)
                  : imgUrl != null
                    ? Image.network(imgUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _initials(auth.name))
                    : _initials(auth.name)),
              ),
              Positioned(right: 0, bottom: 0,
                child: Container(
                  width: 30, height: 30,
                  decoration: const BoxDecoration(color: C.forest, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                )),
            ]),
          )),
          const SizedBox(height: 8),
          Text('Tap to change photo', style: p(12, color: C.t4)),

          const SizedBox(height: 36),

          // Phone (read-only)
          _ReadOnlyField(
            label: 'Mobile Number',
            value: auth.phone.isNotEmpty ? '+91 ${auth.phone}' : 'Not available',
            icon: Icons.phone_android_rounded,
          ),
          const SizedBox(height: 16),

          // Name
          GField(ctrl: _nameCtrl, label: 'Full Name', hint: 'e.g. Rahul Sharma', icon: Icons.person_rounded),
          const SizedBox(height: 16),

          // Email
          GField(ctrl: _emailCtrl, label: 'Email (optional)', hint: 'e.g. rahul@email.com', icon: Icons.email_rounded, keyboard: TextInputType.emailAddress),

          const SizedBox(height: 40),

          GBtn(label: 'Save Changes', loading: _saving, onTap: _save, bg: C.forest),
        ]),
      ),
    );
  }

  Widget _initials(String name) => Center(
    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
      style: p(32, w: FontWeight.w800, color: C.forest)));
}

class _ReadOnlyField extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _ReadOnlyField({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: p(13, w: FontWeight.w700, color: Colors.black54))),
    Container(
      height: 58,
      decoration: BoxDecoration(
        color: C.subtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.border),
      ),
      child: Row(children: [
        const SizedBox(width: 16),
        Icon(icon, size: 20, color: C.t4),
        const SizedBox(width: 12),
        Text(value, style: p(15, w: FontWeight.w600, color: C.t3)),
        const Spacer(),
        Padding(padding: const EdgeInsets.only(right: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(6)),
            child: Text('LOCKED', style: p(9, w: FontWeight.w800, color: C.t4, ls: 0.5)),
          )),
      ]),
    ),
  ]);
}
