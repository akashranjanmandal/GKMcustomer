import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: C.white,
      body: Center(
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Placeholder for logo
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: C.green,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: C.green.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.yard_rounded, size: 64, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text('Ghar Ka Mali', style: p(28, w: FontWeight.w900, color: C.green, ls: -0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
