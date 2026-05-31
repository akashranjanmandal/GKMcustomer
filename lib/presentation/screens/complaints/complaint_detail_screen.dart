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

  Color _statusColor(String s) => switch (s) {
    'open' => C.red,
    'in_progress' => Colors.blue,
    'awaiting_customer' => Colors.purple,
    'in_review' => C.amber,
    'resolved' => C.green,
    'closed' => C.t4,
    'reopened' => Colors.deepOrange,
    _ => C.t4,
  };

  @override
  Widget build(BuildContext ctx) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_ticket == null) return Scaffold(body: Center(child: Text('Ticket not found', style: p(14))));

    final t = _ticket!;
    final status = asStr(t['status'], 'open');
    final comments = (t['comments'] as List?)?.where((c) => c['is_internal'] != true).toList() ?? [];
    final history = (t['history'] as List?) ?? [];
    final events = [
      ...comments.map((c) => {'kind': 'comment', 'at': c['created_at'], 'data': c}),
      ...history.map((h) => {'kind': 'status', 'at': h['created_at'], 'data': h}),
    ]..sort((a, b) => (a['at'] as String).compareTo(b['at'] as String));
    final attachments = (t['attachments'] as List?) ?? [];

    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        GHeader(pb: 16, child: Row(children: [
          GestureDetector(onTap: () => Navigator.pop(ctx, true),
            child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_rounded, size: 15, color: Colors.white))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(asStr(t['ticket_number'], '#${t['id']}'), style: p(13, w: FontWeight.w700, color: Colors.white70)),
            Text(asStr(t['subject'], asStr(t['type']).replaceAll('_', ' ')),
              style: p(16, w: FontWeight.w800, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ])),
        Expanded(child: RefreshIndicator(
          onRefresh: _load, color: C.forest,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), children: [
            // Status / meta
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Chip(label: status.replaceAll('_', ' '), color: _statusColor(status)),
              _Chip(label: asStr(t['priority'], 'medium'), color: C.amber),
              if (t['department'] != null) _Chip(label: asStr(t['department']?['name']), color: C.forest),
              if (t['assignedTo'] != null) _Chip(label: 'Assigned: ${asStr(t['assignedTo']?['name'])}', color: C.t3),
            ]),
            const SizedBox(height: 16),
            GCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Issue', style: p(11, w: FontWeight.w700, color: C.t4, ls: 0.5)),
              const SizedBox(height: 6),
              Text(asStr(t['description']), style: p(14, color: C.t1, h: 1.5)),
              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final a in attachments) _Attach(att: Map<String, dynamic>.from(a as Map)),
                ]),
              ],
            ])),
            const SizedBox(height: 20),
            Text('Activity', style: p(13, w: FontWeight.w800, color: C.t1)),
            const SizedBox(height: 10),
            if (events.isEmpty)
              Text('No replies yet. Our team will respond shortly.',
                style: p(12, color: C.t4, w: FontWeight.w500)),
            for (final ev in events) Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ev['kind'] == 'comment'
                ? _CommentBubble(c: Map<String, dynamic>.from(ev['data'] as Map))
                : _StatusEntry(h: Map<String, dynamic>.from(ev['data'] as Map)),
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
  final String label; final Color color;
  const _Chip({required this.label, required this.color});
  @override Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
    child: Text(label.toUpperCase(), style: p(10, w: FontWeight.w700, color: color, ls: 0.5)),
  );
}

class _CommentBubble extends StatelessWidget {
  final Map<String, dynamic> c;
  const _CommentBubble({required this.c});
  @override Widget build(BuildContext ctx) {
    final role = asStr(c['user_role']);
    final isStaff = role == 'admin' || role == 'supervisor';
    final atts = (c['attachments'] as List?) ?? [];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isStaff ? C.subtle : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isStaff ? C.forest.withOpacity(0.20) : C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(asStr(c['user']?['name'], isStaff ? 'Support' : 'You'),
            style: p(12, w: FontWeight.w800, color: C.t1)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: (isStaff ? C.green : C.gold).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(isStaff ? 'SUPPORT' : role.toUpperCase(),
              style: p(9, w: FontWeight.w800, color: isStaff ? C.green : C.gold, ls: 0.4))),
          const Spacer(),
          Text(asStr(c['created_at']).length >= 16 ? asStr(c['created_at']).substring(0, 16).replaceFirst('T', ' ') : '',
            style: p(10, color: C.t4)),
        ]),
        const SizedBox(height: 6),
        Text(asStr(c['comment']), style: p(13, color: C.t1, h: 1.5)),
        if (atts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final a in atts) _Attach(att: Map<String, dynamic>.from(a as Map)),
          ]),
        ],
      ]),
    );
  }
}

class _StatusEntry extends StatelessWidget {
  final Map<String, dynamic> h;
  const _StatusEntry({required this.h});
  @override Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      const Icon(Icons.history_rounded, size: 13, color: C.t4),
      const SizedBox(width: 6),
      Expanded(child: Text(
        'Status: ${asStr(h['from_status'], '—')} → ${asStr(h['to_status'])}',
        style: p(11, color: C.t4))),
    ]),
  );
}

class _Attach extends StatelessWidget {
  final Map<String, dynamic> att;
  const _Attach({required this.att});
  @override Widget build(BuildContext ctx) {
    final type = asStr(att['file_type']);
    final url = asStr(att['file_url']);
    final isImage = type.startsWith('image/');
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: C.subtle, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isImage)
            ClipRRect(borderRadius: BorderRadius.circular(6),
              child: Image.network(url, width: 32, height: 32, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 24)))
          else const Icon(Icons.attach_file_rounded, size: 16, color: C.t3),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(asStr(att['file_name']), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: p(11, color: C.t2, w: FontWeight.w600))),
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
  Widget build(BuildContext ctx) => Container(
    padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(ctx).viewInsets.bottom + 10),
    decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.border))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (files.isNotEmpty)
        SizedBox(height: 32, child: ListView.separated(
          scrollDirection: Axis.horizontal, itemCount: files.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: C.subtle, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.image, size: 14, color: C.t3),
              const SizedBox(width: 4),
              Text(files[i].path.split('/').last, style: p(11, color: C.t3)),
              GestureDetector(onTap: () => onRemove(i),
                child: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.close, size: 13))),
            ]),
          ),
        )),
      if (files.isNotEmpty) const SizedBox(height: 8),
      Row(children: [
        IconButton(onPressed: onPick, icon: const Icon(Icons.attach_file_rounded, color: C.t3)),
        Expanded(child: TextField(
          controller: ctrl, minLines: 1, maxLines: 4,
          style: p(13, color: C.t1),
          decoration: const InputDecoration(hintText: 'Type your reply…', border: InputBorder.none),
        )),
        IconButton(
          onPressed: sending ? null : onSend,
          icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.send_rounded, color: C.forest)),
      ]),
    ]),
  );
}
