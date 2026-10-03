import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/services/api.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final int complaintId;
  const ComplaintDetailScreen({super.key, required this.complaintId});
  @override State<ComplaintDetailScreen> createState() => _State();
}

class _State extends State<ComplaintDetailScreen> {
  final _api = Api();
  final _replyCtrl = TextEditingController();
  Map<String, dynamic>? _ticket;
  bool _loading = true;
  bool _sending = false;
  final List<File> _files = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getComplaintDetail(widget.complaintId);
      if (mounted) setState(() { _ticket = Map<String, dynamic>.from(r as Map); _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); showMsg(context, 'Failed to load ticket', err: true); }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final res = await picker.pickMultiImage(maxWidth: 1600, imageQuality: 80);
    if (res.isEmpty) return;
    setState(() => _files.addAll(res.map((x) => File(x.path))));
  }

  Future<void> _send() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty && _files.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _api.addComplaintComment(
        complaintId: widget.complaintId,
        comment: text.isEmpty ? null : text,
        attachments: _files,
      );
      _replyCtrl.clear();
      _files.clear();
      await _load();
      if (mounted) showMsg(context, 'Reply sent', ok: true);
    } on ApiError catch (e) { if (mounted) showMsg(context, e.message, err: true); }
    finally { if (mounted) setState(() => _sending = false); }
  }


  static String _when(String s) {
    final d = DateTime.tryParse(s)?.toLocal();
    if (d == null) return '';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final hh = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${d.day} ${m[d.month - 1]}, $hh:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext ctx) {
    if (_loading) return Scaffold(backgroundColor: Colors.transparent, body: Column(children: [
      VPageHeader(title: 'Ticket', onBack: () => Navigator.pop(ctx, true)),
      const Expanded(child: Center(child: CircularProgressIndicator(color: V.leaf))),
    ]));
    if (_ticket == null) return Scaffold(backgroundColor: Colors.transparent, body: Column(children: [
      VPageHeader(title: 'Ticket', onBack: () => Navigator.pop(ctx, true)),
      Expanded(child: GEmpty(title: 'Ticket not found', sub: 'It may have been closed or removed.', icon: Icons.headset_mic_outlined,
        action: GBtn(label: 'Back to support', onTap: () => Navigator.pop(ctx, true), w: 220, h: 48))),
    ]));

    final t = _ticket!;
    final status = asStr(t['status'], 'open');
    final comments = (t['comments'] as List?)?.where((c) => c['is_internal'] != true).toList() ?? [];
    final history = (t['history'] as List?) ?? [];
    final events = [
      ...comments.map((c) => {'kind': 'comment', 'at': c['created_at'], 'data': c}),
      ...history.map((h) => {'kind': 'status', 'at': h['created_at'], 'data': h}),
    ]..sort((a, b) => asStr(a['at']).compareTo(asStr(b['at'])));
    final attachments = (t['attachments'] as List?) ?? [];
    final type = asStr(t['type']).replaceAll('_', ' ');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
          child: Row(children: [
            VRoundBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(ctx, true)),
            const SizedBox(width: 12),
            Expanded(child: Text(asStr(t['ticket_number'], '#${t['id']}'), style: p(13, color: V.fog))),
            GBadge(status),
          ]),
        )),
        Expanded(child: RefreshIndicator(
          onRefresh: _load, color: V.leaf,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 20), children: [
            VPod(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (type.isNotEmpty) Text(type[0].toUpperCase() + type.substring(1), style: p(12, color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 2),
                Text(asStr(t['subject'], 'Your issue'), style: vx(21, w: FontWeight.w600, color: Colors.white, h: 1.2)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (t['department'] != null) _Chip(label: asStr(t['department']?['name'])),
                  if (t['assignedTo'] != null) _Chip(label: 'With ${asStr(t['assignedTo']?['name'])}'),
                  if (t['booking_id'] != null) _Chip(label: 'Booking #${t['booking_id']}'),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            // Your original message
            _Bubble(
              mine: true,
              name: 'You',
              when: _when(asStr(t['created_at'] ?? t['createdAt'])),
              text: asStr(t['description']),
              attachments: [for (final a in attachments) Map<String, dynamic>.from(a as Map)],
            ),
            for (final ev in events) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ev['kind'] == 'comment'
                ? Builder(builder: (_) {
                    final c = Map<String, dynamic>.from(ev['data'] as Map);
                    final role = asStr(c['user_role']);
                    final staff = role == 'admin' || role == 'supervisor';
                    return _Bubble(
                      mine: !staff,
                      name: staff ? asStr(c['user']?['name'], 'Support') : 'You',
                      when: _when(asStr(c['created_at'])),
                      text: asStr(c['comment']),
                      attachments: [for (final a in (c['attachments'] as List?) ?? []) Map<String, dynamic>.from(a as Map)],
                    );
                  })
                : _StatusEntry(h: Map<String, dynamic>.from(ev['data'] as Map)),
            ),
            if (comments.isEmpty) Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Center(child: Text('Our team will reply here shortly.', style: p(12.5, color: V.fog))),
            ),
          ]),
        )),
        if (status != 'closed') _Composer(
          ctrl: _replyCtrl, files: _files, sending: _sending,
          onPick: _pickImage, onRemove: (i) => setState(() => _files.removeAt(i)),
          onSend: _send,
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});
  @override Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
    child: Text(label, style: p(11.5, color: Colors.white.withValues(alpha: 0.85))),
  );
}

// Chat bubble: yours on the right (ink), support on the left (glass).
class _Bubble extends StatelessWidget {
  final bool mine;
  final String name, when, text;
  final List<Map<String, dynamic>> attachments;
  const _Bubble({required this.mine, required this.name, required this.when, required this.text, this.attachments = const []});
  @override Widget build(BuildContext ctx) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.8),
      child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text('$name  ·  $when', style: p(11, color: V.fog)),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: mine ? V.ink : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(mine ? 20 : 6), bottomRight: Radius.circular(mine ? 6 : 20)),
            border: mine ? null : Border.all(color: Colors.white),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (text.isNotEmpty) Text(text, style: p(13.5, color: mine ? Colors.white : V.ink, h: 1.5)),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final a in attachments) _Attach(att: a, onDark: mine)]),
            ],
          ]),
        ),
      ]),
    ),
  );
}

class _StatusEntry extends StatelessWidget {
  final Map<String, dynamic> h;
  const _StatusEntry({required this.h});
  @override Widget build(BuildContext ctx) => Center(child: Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: V.ink.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(99)),
    child: Text('Status changed to ${asStr(h['to_status']).replaceAll('_', ' ')}', style: p(11.5, color: V.fog)),
  ));
}

class _Attach extends StatelessWidget {
  final Map<String, dynamic> att;
  final bool onDark;
  const _Attach({required this.att, this.onDark = false});
  @override Widget build(BuildContext ctx) {
    final type = asStr(att['file_type']);
    final url = asStr(att['file_url']);
    final isImage = type.startsWith('image/');
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: isImage
        ? ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.network(url, cacheWidth: 300, width: 84, height: 84, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 84, height: 84, color: V.mint, child: const Icon(Icons.image_outlined, color: V.deep))))
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: onDark ? Colors.white.withValues(alpha: 0.12) : V.mint, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.attach_file_rounded, size: 15, color: onDark ? Colors.white : V.deep),
              const SizedBox(width: 6),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 140),
                child: Text(asStr(att['file_name']), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: p(11.5, w: FontWeight.w500, color: onDark ? Colors.white : V.deep))),
            ]),
          ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController ctrl;
  final List<File> files;
  final bool sending;
  final VoidCallback onPick, onSend;
  final void Function(int) onRemove;
  const _Composer({required this.ctrl, required this.files, required this.sending,
    required this.onPick, required this.onRemove, required this.onSend});

  @override
  Widget build(BuildContext ctx) => Padding(
    padding: EdgeInsets.fromLTRB(12, 8, 12,
      MediaQuery.of(ctx).viewInsets.bottom > 0 ? MediaQuery.of(ctx).viewInsets.bottom + 8 : MediaQuery.of(ctx).padding.bottom + 10),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (files.isNotEmpty) ...[
        SizedBox(height: 34, child: ListView.separated(
          scrollDirection: Axis.horizontal, itemCount: files.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: V.mint, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.image_outlined, size: 14, color: V.deep),
              const SizedBox(width: 4),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 120),
                child: Text(files[i].path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis, style: p(11, color: V.deep))),
              GestureDetector(onTap: () => onRemove(i),
                child: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.close_rounded, size: 14, color: V.deep))),
            ]),
          ),
        )),
        const SizedBox(height: 8),
      ],
      Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 5, 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white),
          boxShadow: [BoxShadow(color: V.ink.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          IconButton(onPressed: onPick, icon: const Icon(Icons.add_photo_alternate_outlined, color: V.fog)),
          Expanded(child: TextField(
            controller: ctrl, minLines: 1, maxLines: 4,
            style: p(13.5, color: V.ink),
            decoration: InputDecoration(hintText: 'Write a reply…', hintStyle: p(13.5, color: V.fog),
              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, isDense: true),
          )),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(color: V.ink, shape: BoxShape.circle),
              child: sending
                ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.arrow_upward_rounded, color: V.lime, size: 20),
            ),
          ),
        ]),
      ),
    ]),
  );
}
