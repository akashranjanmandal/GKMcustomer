import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

// Plantopedia (AI plant identification) is temporarily disabled while we polish it.
// The full camera/identify implementation lives in git history — restore that file
// to re-enable. Constructor kept identical so existing call sites don't change.
class PlantopediaScreen extends StatelessWidget {
  final VoidCallback? onClose;
  final bool isVisible;
  const PlantopediaScreen({super.key, this.onClose, this.isVisible = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0x1403411A), // forest @ ~8%
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.eco_rounded, color: C.forest, size: 46),
                ),
                const SizedBox(height: 24),
                Text('PLANTOPEDIA',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: C.forest, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text('Under Development',
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w800, color: C.t1)),
                const SizedBox(height: 12),
                Text(
                  'Our AI plant identification & care assistant is coming soon — snap a photo for instant species ID, watering, light and health tips. 🌱',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14, height: 1.6, color: C.t3),
                ),
                if (onClose != null) ...[
                  const SizedBox(height: 28),
                  GBtn(label: 'Go Back', icon: Icons.arrow_back_rounded, bg: C.forest, onTap: onClose),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
