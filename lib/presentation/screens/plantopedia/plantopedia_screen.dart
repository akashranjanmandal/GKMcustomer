import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../data/services/api.dart';
import '../../../data/services/auth.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class PlantopediaScreen extends StatefulWidget {
  final VoidCallback? onClose;
  final bool isVisible;
  const PlantopediaScreen({super.key, this.onClose, this.isVisible = true});
  @override State<PlantopediaScreen> createState() => _PlantState();
}

class _PlantState extends State<PlantopediaScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _api = Api();
  final _picker = ImagePicker();
  
  CameraController? _camera;
  bool _camInit = false;
  
  File? _image;
  Map<String, dynamic>? _result;
  bool _identifying = false;
  List<dynamic> _history = [];
  bool _histLoading = false;
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHistory();
    if (widget.isVisible) {
      _initCamera();
    }
    _anim = AnimationController(vsync: this, duration: 2.seconds)..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PlantopediaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        if (_camera == null || !_camera!.value.isInitialized) {
          _initCamera();
        } else {
          _camera!.resumePreview().catchError((e) {
            print('>>> [Plantopedia] Resume error, re-initializing: $e');
            _initCamera();
          });
        }
      } else {
        _camera?.pausePreview();
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      print('>>> [Plantopedia] Initializing camera...');
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('>>> [Plantopedia] No cameras available on device');
        return;
      }
      print('>>> [Plantopedia] Found ${cameras.length} camera(s). Using: ${cameras.first.name}');
      _camera = CameraController(
        cameras.first, 
        ResolutionPreset.medium, // medium is more compatible across Android devices
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _camera!.initialize();
      if (mounted) {
        print('>>> [Plantopedia] Camera initialized successfully');
        setState(() => _camInit = true);
      }
    } catch (e) {
      print('>>> [Plantopedia] Camera initialization ERROR: $e');
      if (mounted) {
        setState(() => _camInit = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera unavailable: ${e.toString().split(':').first}'),
            action: SnackBarAction(label: 'Retry', onPressed: _initCamera),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _camera;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      ctrl.pausePreview();
    } else if (state == AppLifecycleState.resumed) {
      ctrl.resumePreview();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _anim.dispose();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (!context.read<AuthProvider>().isAuthed) return;
    setState(() => _histLoading = true);
    try {
      final r = await _api.getPlantHistory();
      if (mounted) setState(() { _history = asList(r); _histLoading = false; });
    } catch (_) { if (mounted) setState(() => _histLoading = false); }
  }

  Future<void> _capture() async {
    if (_camera == null || !_camera!.value.isInitialized) return;
    try {
      final xf = await _camera!.takePicture();
      setState(() { _image = File(xf.path); _result = null; });
      _identify();
    } catch (e) {
      if (mounted) showMsg(context, 'Failed to capture image', err: true);
    }
  }

  Future<void> _pickGallery() async {
    try {
      final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1200);
      if (f != null) {
        setState(() { _image = File(f.path); _result = null; });
        _identify();
      }
    } catch (_) { if (mounted) showMsg(context, 'Could not access gallery', err: true); }
  }

  Future<void> _identify() async {
    if (_image == null) return;
    setState(() => _identifying = true);
    try {
      final r = await _api.identifyPlant(_image!);
      if (mounted) {
        setState(() { _result = asMap(r); _identifying = false; });
        _showResult();
        _loadHistory();
      }
    } on ApiError catch (e) {
      if (mounted) { setState(() => _identifying = false); showMsg(context, e.message, err: true); }
    }
  }

  void _showResult() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ResultSheet(result: _result!),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Camera Preview
        Positioned.fill(child: (_camInit && widget.isVisible)
          ? CameraPreview(_camera!) 
          : Container(color: Colors.black, child: const Center(child: CircularProgressIndicator(color: Colors.white24)))),
        
        // Scan Overlay
        Positioned.fill(child: CustomPaint(painter: _ScannerPainter())),

        // Header
        Positioned(top: MediaQuery.of(ctx).padding.top + 16, left: 16, right: 16,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(onPressed: widget.onClose ?? () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white)),
            Text('Scan Plant', style: p(18, w: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 48), // Spacer
          ])),

        // Scan Line
        Center(child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, -100 + (200 * _anim.value)),
            child: Container(
              width: 250, height: 2,
              decoration: BoxDecoration(
                boxShadow: [BoxShadow(color: C.green.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
                gradient: LinearGradient(colors: [C.green.withOpacity(0), C.green, C.green.withOpacity(0)])),
            )))),

        // Bottom Controls
        Positioned(bottom: 60, left: 0, right: 0,
          child: Column(children: [
            Text('Point your camera at a plant', style: p(14, color: Colors.white70)),
            const SizedBox(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _ScanTool(icon: Icons.photo_library, label: 'Gallery', onTap: _pickGallery),
              const SizedBox(width: 40),
              GestureDetector(
                onTap: _capture,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                  padding: const EdgeInsets.all(4),
                  child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                )),
              const SizedBox(width: 40),
              _ScanTool(icon: Icons.history, label: 'History', onTap: () => _showHistory()),
            ]),
          ])),

        if (_identifying) Positioned.fill(child: Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white)))),
      ]),
    );
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _HistorySheet(history: _history, loading: _histLoading),
    );
  }
}

class _ScanTool extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ScanTool({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(
        width: 50, height: 50,
        decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
      const SizedBox(height: 8),
      Text(label, style: p(12, color: Colors.white60)),
    ]));
}

class _ScannerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final r = 250.0;
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: r, height: r);
    
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    final borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)), borderPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResultSheet extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ResultSheet({required this.result});
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(asStr(result['plant_name'] ?? result['name'], 'Plant'), style: p(22, w: FontWeight.w800, color: Colors.black))),
        const Icon(Icons.share, color: Colors.black54),
      ]),
      const SizedBox(height: 16),
      Text(asStr(result['care_instructions'] ?? result['care_tips'], 'Care instructions...'), style: p(14, color: Colors.black87, h: 1.5)),
      const SizedBox(height: 24),
      GBtn(label: 'Add to My Garden', onTap: () => Navigator.pop(ctx), bg: C.green),
      const SizedBox(height: 12),
    ]),
  );
}

class _HistorySheet extends StatelessWidget {
  final List<dynamic> history; final bool loading;
  const _HistorySheet({required this.history, required this.loading});
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(24),
    height: MediaQuery.of(ctx).size.height * 0.7,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Identification History', style: p(20, w: FontWeight.w800, color: Colors.black)),
      const SizedBox(height: 20),
      if (loading) const Center(child: CircularProgressIndicator())
      else Expanded(child: ListView.builder(
        itemCount: history.length,
        itemBuilder: (_, i) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.park)),
          title: Text(asStr(history[i]['plant_name'] ?? history[i]['name'], 'Plant')),
          subtitle: Text(asStr(history[i]['created_at'])),
        ),
      )),
    ]),
  );
}

