import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:snapspend/theme/app_colors.dart';
import 'scanning_receipts_page.dart';

class ScanReceiptsPage extends StatefulWidget {
  const ScanReceiptsPage({super.key});

  @override
  State<ScanReceiptsPage> createState() => _ScanReceiptsPageState();
}

class _ScanReceiptsPageState extends State<ScanReceiptsPage> with SingleTickerProviderStateMixin {
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _getStarted() {
    // Navigate to automatic scanning page
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ScanningReceiptsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inverseSurface,
      body: Stack(
        children: [
          // 1. Camera Viewport Background
          Positioned.fill(
            child: Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDSZzn-ukPENl_rXDZRMF57_8eAGf2gtWtb5qXgYw3JK3yWPJSChXYjqqeVa6Xq_qcVNXeBUrUIweJcxyRcWWrmsCSp829S9RCvikpXvv0zUZwGTTZ-jJnvXAkhzt6exGYjUq_TEVcgu435B37tE3QyvD5zAh566UC3U0LkBigBThtUUyi1PIg0pmbHrQQQczi7FVSZSoI2hQtvMw70Zn_Me26H9SgdXACN0_AlTC1MsQTUTNMy5W2Bd5Co3L-mB8hRD8kW2HHT9lk_',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.1),
              colorBlendMode: BlendMode.darken,
            ),
          ),

          // 2. Viewfinder Overlay
          Positioned(
            top: MediaQuery.of(context).size.height * 0.25,
            left: 40,
            right: 40,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: _ViewfinderGridPainter(),
                ),
              ),
            ),
          ),

          // Laser Scan effect
          AnimatedBuilder(
            animation: _scannerController,
            builder: (context, child) {
              return Positioned(
                top: MediaQuery.of(context).size.height * 0.25 + 
                     (MediaQuery.of(context).size.height * 0.45 * _scannerController.value),
                left: 0,
                right: 0,
                height: 4,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.transparent, AppColors.primary, Colors.transparent],
                      stops: [0.1, 0.5, 0.9],
                    ),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)
                    ],
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Stack(
              children: [
                // Top Navigation Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.inverseSurface.withOpacity(0.4),
                    ),
                    child: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildGlassButton(Icons.arrow_back, () {
                              if (Navigator.canPop(context)) Navigator.pop(context);
                            }),
                            Row(
                              children: [
                                const Icon(Icons.psychology, color: AppColors.tertiaryContainer),
                                const SizedBox(width: 8),
                                Text(
                                  'SnapSpend',
                                  style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                _buildGlassButton(Icons.flash_on, () {}),
                                const SizedBox(width: 12),
                                _buildGlassButton(Icons.settings, () {}),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Contextual AI Label
                Positioned(
                  top: 96,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'AUTO-DETECTING RECEIPT',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom UI Stack
                Positioned(
                  bottom: 48,
                  left: 32,
                  right: 32,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // AI Insight Bubble
                      Container(
                        margin: const EdgeInsets.only(bottom: 40),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 40, offset: Offset(0, 20))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.tertiary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.auto_awesome, color: AppColors.tertiaryContainer, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('AI SUGGESTION', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white60, letterSpacing: 2)),
                                        const SizedBox(height: 4),
                                        Text('Position receipt flat within the frame for best OCR precision.', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white, height: 1.2)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Capture Modes
                      Container(
                        margin: const EdgeInsets.only(bottom: 40),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildModeButton('SINGLE', false),
                                _buildModeButton('MULTI', true),
                                _buildModeButton('IMPORT', false),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Main Interaction Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Gallery Button
                          GestureDetector(
                            onTap: _getStarted, // Tying gallery to starting the real flow
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.photo_library, color: Colors.white, size: 24),
                                  const SizedBox(height: 2),
                                  Text('CHỌN ẢNH', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white60)),
                                ],
                              ),
                            ),
                          ),

                          // Shutter Button
                          GestureDetector(
                            onTap: _getStarted, // Main action navigates to Scanning process
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withOpacity(0.2),
                                    boxShadow: [
                                      BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 30)
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [AppColors.primary, AppColors.primaryContainer],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 4),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Thumbnail
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                              image: const DecorationImage(
                                image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuAz1GuM5A7UNV8wdnHOtvnb8R0Zl31MkgASwhJjy7QUfkltxmyv0mzCA1Dwi-xXHZQRI76M9JptL5we--ApXSsovW6F_PImlpjrEAq7FjJkkyHCntRVHVyTaCH12yRMIS8SlUTOniAblD_irZ5CkFTpsw0gXNIGTDPlrUy5qWTheLlmDbYF6IyDlxOaajqqWZzl-5QhxkCOP7VFmjbyhHJ6AKPLKNuYQEetdmHYznxJl3dXOfkZCYTP6R-WgXozYBznkprcITWZnpA4'),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildModeButton(String text, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Colors.white.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: active ? Colors.white : Colors.white.withOpacity(0.4),
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _ViewfinderGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1.0;

    const double spacing = 40.0;
    
    // Vertical lines
    for (double i = spacing; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    
    // Horizontal lines
    for (double i = spacing; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
