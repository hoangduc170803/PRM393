import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snapspend/theme/app_colors.dart';
import 'scan_receipts_page.dart';

class GalleryAccessPage extends StatefulWidget {
  const GalleryAccessPage({super.key});

  @override
  State<GalleryAccessPage> createState() => _GalleryAccessPageState();
}

class _GalleryAccessPageState extends State<GalleryAccessPage> {
  bool _isCheckingPermission = false;

  Future<void> _requestGalleryAccess() async {
    setState(() {
      _isCheckingPermission = true;
    });

    try {
      PermissionStatus status;

      // Request both Camera and Storage/Photos since this is a combined permission screen
      final cameraStatus = await Permission.camera.request();
      
      if (await Permission.photos.isRestricted || await Permission.photos.isPermanentlyDenied) {
        status = await Permission.storage.request();
      } else {
        status = await Permission.photos.request();
      }

      if (status.isGranted && cameraStatus.isGranted) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ScanReceiptsPage()),
          );
        }
      } else if (status.isDenied || cameraStatus.isDenied) {
        if (mounted) _showPermissionDeniedDialog();
      } else if (status.isPermanentlyDenied || cameraStatus.isPermanentlyDenied) {
        if (mounted) _showOpenSettingsDialog();
      }
    } catch (e) {
      if (mounted) _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPermission = false;
        });
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Required', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text(
          'Camera and Gallery access is needed to scan receipt photos automatically. '
          'Please grant permission to continue.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.outline)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _requestGalleryAccess();
            },
            child: Text('Try Again', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Required', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text(
          'Access to camera or gallery was permanently denied. '
          'Please enable it in app settings to continue.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.outline)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Open Settings', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text('Failed to request permission:\n$error', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.inter(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _skipForNow() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ScanReceiptsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient Glows
          Positioned(
            top: -SizeConfig.screenHeight(context) * 0.1,
            left: -SizeConfig.screenWidth(context) * 0.1,
            child: Container(
              width: SizeConfig.screenWidth(context) * 0.5,
              height: SizeConfig.screenHeight(context) * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 120, spreadRadius: 60)
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -SizeConfig.screenHeight(context) * 0.1,
            right: -SizeConfig.screenWidth(context) * 0.1,
            child: Container(
              width: SizeConfig.screenWidth(context) * 0.5,
              height: SizeConfig.screenHeight(context) * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tertiary.withOpacity(0.05),
                boxShadow: [
                  BoxShadow(color: AppColors.tertiary.withOpacity(0.05), blurRadius: 120, spreadRadius: 60)
                ],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Center Visual: Overlapping Rounded Cards
                    SizedBox(
                      height: 320,
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background Layer Card (tilted)
                          Transform.translate(
                            offset: const Offset(-24, 16),
                            child: Transform.rotate(
                              angle: -0.2, // ~ -12 degrees
                              child: _buildDecorativeCard(
                                width: 220,
                                height: 280,
                                shadowOpacity: 0.04,
                              ),
                            ),
                          ),
                          // Gallery Card (slightly translated back)
                          Transform.translate(
                            offset: const Offset(36, -24),
                            child: _buildDecorativeCard(
                              width: 220,
                              height: 280,
                              shadowOpacity: 0.06,
                              borderColor: Colors.white.withOpacity(0.5),
                              content: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppColors.tertiary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: AppColors.tertiary.withOpacity(0.15), blurRadius: 30)
                                      ],
                                    ),
                                    child: const Icon(Icons.photo_library, color: AppColors.tertiary, size: 40),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(width: 100, height: 8, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(4))),
                                  const SizedBox(height: 8),
                                  Container(width: 60, height: 8, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh.withOpacity(0.6), borderRadius: BorderRadius.circular(4))),
                                ],
                              ),
                            ),
                          ),
                          // Camera Card (Foreground)
                          Transform.translate(
                            offset: const Offset(-16, 16),
                            child: _buildDecorativeCard(
                              width: 240,
                              height: 300,
                              shadowOpacity: 0.08,
                              borderColor: Colors.white.withOpacity(0.8),
                              boxShadowColor: const Color.fromRGBO(5, 70, 237, 0.1),
                              content: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 30)
                                      ],
                                    ),
                                    child: const Icon(Icons.photo_camera, color: AppColors.primary, size: 48),
                                  ),
                                  const SizedBox(height: 24),
                                  Container(width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 24), height: 10, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(5))),
                                  const SizedBox(height: 12),
                                  Container(width: double.infinity, margin: const EdgeInsets.only(left: 24, right: 48), height: 10, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(5))),
                                  const SizedBox(height: 12),
                                  Container(width: double.infinity, margin: const EdgeInsets.only(left: 24, right: 72), height: 10, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh.withOpacity(0.5), borderRadius: BorderRadius.circular(5))),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(width: 40, height: 40, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(8))),
                                      Container(width: 40, height: 40, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(8))),
                                      Container(width: 40, height: 40, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(8))),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Typography
                    Text(
                      'Snap to Save',
                      style: GoogleFonts.manrope(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurface,
                        letterSpacing: -1,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'We need access to your camera and gallery to scan your receipts and parse data automatically.',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppColors.onSurfaceVariant,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Action Buttons
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isCheckingPermission ? null : _requestGalleryAccess,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryContainer],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 12))
                            ],
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: _isCheckingPermission
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                : Text('Allow Access', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isCheckingPermission ? null : _skipForNow,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceVariant,
                        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      child: const Text('Skip for now'),
                    ),
                    const SizedBox(height: 32),

                    // Trust Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield, color: AppColors.onSurface.withOpacity(0.6), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'ENCRYPTED & PRIVATE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface.withOpacity(0.6),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeCard({
    required double width,
    required double height,
    required double shadowOpacity,
    Color? borderColor,
    Widget? content,
    Color? boxShadowColor,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? Colors.transparent, width: 1),
        boxShadow: [
          BoxShadow(
            color: boxShadowColor ?? const Color.fromRGBO(11, 15, 16, 1.0).withOpacity(shadowOpacity),
            blurRadius: 48,
            offset: const Offset(0, 24),
          )
        ],
      ),
      child: content,
    );
  }
}

class SizeConfig {
  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  static double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;
}
