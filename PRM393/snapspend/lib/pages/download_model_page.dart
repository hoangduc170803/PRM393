import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:snapspend/theme/app_colors.dart';
import '../services/llama_service.dart';
import 'scan_receipts_page.dart';

class DownloadModelPage extends StatefulWidget {
  const DownloadModelPage({super.key});

  @override
  State<DownloadModelPage> createState() => _DownloadModelPageState();
}

class _DownloadModelPageState extends State<DownloadModelPage> with SingleTickerProviderStateMixin {
  final LlamaService _llamaService = LlamaService();

  bool _isDownloading = false;
  bool _isModelReady = false;
  double _downloadProgress = 0.0;
  String _statusMessage = 'Checking model status...';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkModelExists();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkModelExists() async {
    final exists = await _llamaService.checkModelExists();
    if (mounted) {
      setState(() {
        _isModelReady = exists;
        if (exists) {
          _statusMessage = 'Model ready!';
          _downloadProgress = 1.0;
        } else {
          _statusMessage = 'Ready to download...';
        }
      });
    }
  }

  Future<void> _downloadModel() async {
    if (_isModelReady) {
      _navigateToNextPage();
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Starting download...';
    });

    try {
      await _llamaService.downloadModel(
        onProgress: (progress, message) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _statusMessage = message;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isModelReady = true;
          _statusMessage = 'Download complete!';
          _downloadProgress = 1.0;
        });

        // Auto-navigate after successful download
        await Future.delayed(const Duration(milliseconds: 800));
        _navigateToNextPage();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
          _isDownloading = false;
        });
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Download Failed', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text('Failed to download model:\n$error', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.outline)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadModel();
            },
            child: Text('Retry', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigateToNextPage() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ScanReceiptsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressClamp = _downloadProgress.clamp(0.0, 1.0);
    final percentage = (progressClamp * 100).toInt();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 100, spreadRadius: 50)
                ],
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tertiary.withOpacity(0.05),
                boxShadow: [
                  BoxShadow(color: AppColors.tertiary.withOpacity(0.05), blurRadius: 100, spreadRadius: 50)
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Navigation Shell
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SnapSpend',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -1,
                        ),
                      ),
                      if (Navigator.canPop(context))
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                          onPressed: () => Navigator.pop(context),
                        )
                      else
                        const SizedBox(width: 48), // Balancing space
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Elegant Dynamic Progress Ring
                          SizedBox(
                            width: 280,
                            height: 280,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Background circle
                                Container(
                                  width: 280,
                                  height: 280,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.surfaceContainerHigh,
                                      width: 12,
                                    ),
                                  ),
                                ),
                                // Gradient Progress
                                SizedBox(
                                  width: 280,
                                  height: 280,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0, end: progressClamp),
                                    duration: const Duration(milliseconds: 250),
                                    builder: (context, value, _) {
                                      return CircularProgressIndicator(
                                        value: value,
                                        strokeWidth: 12,
                                        backgroundColor: Colors.transparent,
                                        strokeCap: StrokeCap.round,
                                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                      );
                                    },
                                  ),
                                ),
                                // Text inside
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$percentage%',
                                      style: GoogleFonts.manrope(
                                        fontSize: 64,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurface,
                                        letterSpacing: -2,
                                      ),
                                    ),
                                    Text(
                                      _isModelReady ? 'COMPLETED' : 'DOWNLOADING',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurfaceVariant,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                // Floating AI Badge
                                Positioned(
                                  top: 10,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.psychology, color: AppColors.tertiary, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'OFFLINE AI',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.onSurface,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Status Text Area
                          Text(
                            _isModelReady
                                ? 'Offline AI Model Ready'
                                : _isDownloading
                                    ? 'Downloading offline AI model...'
                                    : 'Model download required',
                            style: GoogleFonts.manrope(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isModelReady
                                ? 'SnapSpend is ready to process your receipts.'
                                : 'This allows SnapSpend to categorize your expenses instantly without an internet connection.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.onSurfaceVariant,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),
                          // Sub-message text / Pulsing dots
                          if (_isDownloading)
                            Column(
                              children: [
                                Text(
                                  _statusMessage,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildPulseDot(0.0),
                                    const SizedBox(width: 8),
                                    _buildPulseDot(0.3),
                                    const SizedBox(width: 8),
                                    _buildPulseDot(0.6),
                                  ],
                                ),
                              ],
                            ),

                          // Pro Tip contextual block
                          const SizedBox(height: 32),
                          if (!_isDownloading && !_isModelReady)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: -5)],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.tertiary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.lightbulb, color: AppColors.tertiary),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('PRO TIP',
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                                        const SizedBox(height: 4),
                                        Text('Offline mode encrypts all transaction data locally on your device for maximum privacy.',
                                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.5)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                            
                          const SizedBox(height: 32),
                          // Action Button
                          if (!_isDownloading)
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: _downloadModel,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  elevation: 5,
                                  shadowColor: AppColors.primary.withOpacity(0.5),
                                ),
                                child: Text(
                                  _isModelReady ? 'Continue' : 'Start Download',
                                  style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseDot(double offset) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        // Simple phase shift for offset effect
        double value = _pulseAnimation.value;
        return Opacity(
          opacity: (value + offset) % 1.0 < 0.5 ? 1.0 : 0.4,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
