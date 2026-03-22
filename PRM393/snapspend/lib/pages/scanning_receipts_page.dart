import 'dart:developer';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import '../services/ocr_service.dart';
import '../services/database_service.dart';
import '../models/receipt.dart';
import '../theme/app_colors.dart';
import 'expenses_summary_page.dart';

class ScanningReceiptsPage extends StatefulWidget {
  const ScanningReceiptsPage({super.key});

  @override
  State<ScanningReceiptsPage> createState() => _ScanningReceiptsPageState();
}

class _ScanningReceiptsPageState extends State<ScanningReceiptsPage> with TickerProviderStateMixin {
  int _currentScanning = 0;
  int _totalReceipts = 0;
  final List<ScannedReceipt> _scannedReceipts = [];
  bool _isComplete = false;
  String _statusMessage = 'Preparing to scan...';

  late AnimationController _pulseController;
  late Animation<double> _pulseRing1;
  late Animation<double> _pulseRing2;

  final OcrService _ocrService = OcrService();
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseRing1 = Tween<double>(begin: 0.6, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseRing2 = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );

    _startScanning();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<List<File>> _getReceiptImages() async {
    List<File> receiptFiles = [];
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> pickedFiles = await picker.pickMultiImage(limit: 5);
      
      for (var xFile in pickedFiles) {
        receiptFiles.add(File(xFile.path));
      }
    } catch (e) {
      print('Error getting receipt images: $e');
    }
    return receiptFiles;
  }


  Future<void> _startScanning() async {
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _statusMessage = 'Checking AI model...';
    });

    final modelExists = await _ocrService.llamaService.checkModelExists();
    if (!modelExists) {
      if (!mounted) return;
      final shouldDownload = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHighest,
          title: Text('AI Model Required', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
          content: Text(
            'The Qwen3 AI model is needed to extract receipt data. '
            'Would you like to download it now? (~400MB)',
            style: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.outline)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text('Download', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (shouldDownload != true) {
        if (mounted) _navigateToMainApp();
        return;
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'Downloading AI model...';
        });
      }

      try {
        await _ocrService.llamaService.downloadModel(
          onProgress: (progress, message) {
            if (mounted) {
              setState(() {
                _statusMessage = message;
              });
            }
          },
        );

        if (mounted) {
          setState(() {
            _statusMessage = 'Model downloaded! Starting scan...';
          });
        }
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download model: $e'), backgroundColor: AppColors.error));
          _navigateToMainApp();
        }
        return;
      }
    }

    final receiptFiles = await _getReceiptImages();
    if (receiptFiles.isEmpty) {
      if (mounted) {
        setState(() {
          _statusMessage = 'No images selected';
          _isComplete = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No images selected. Returning to dashboard...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        _navigateToMainApp();
      }
      return;
    }

    setState(() {
      _totalReceipts = receiptFiles.length;
      _statusMessage = 'Processing with AI-powered OCR';
    });

    for (int i = 0; i < receiptFiles.length; i++) {
      if (!mounted) return;
      final file = receiptFiles[i];
      final filename = path.basename(file.path);

      setState(() {
        _currentScanning = i + 1;
        _statusMessage = 'Scanning $filename...';
      });

      try {
        final text = await _ocrService.scanReceipt(file.path);
        if (!mounted) return;

        setState(() {
          _statusMessage = 'Extracting data with Qwen3 AI...';
        });

        Map<String, dynamic> extractedData = await _ocrService.extractReceiptDataWithLlama(
          receiptText: text,
          onStatusUpdate: (status) {
            if (mounted) setState(() { _statusMessage = status; });
          },
          onTextUpdate: (generatedText) {},
        );

        if (!mounted) return;

        final scannedReceipt = ScannedReceipt(
          filename: filename,
          amount: extractedData['amount'] as double,
          rawText: text,
          sender: extractedData['sender'] as String,
          recipient: extractedData['recipient'] as String,
          time: extractedData['time'] as String,
        );

        setState(() {
          _scannedReceipts.add(scannedReceipt);
          _statusMessage = 'Processing with AI-powered OCR';
        });

        try {
          final receipt = Receipt(
            imagePath: file.path,
            imageTaken: DateTime.now(),
            amount: extractedData['amount'] as double,
            recipient: extractedData['recipient'] as String,
            merchantName: extractedData['sender'] as String,
            category: null,
            rawOcrText: text,
            rawJsonData: json.encode(extractedData),
          );
          await _databaseService.insertReceipt(receipt);
        } catch (dbError) {
          print('Failed to save to database: $dbError');
        }

      } catch (e) {
        if (mounted) {
          setState(() {
            _scannedReceipts.add(
              ScannedReceipt(filename: filename, amount: 0.0, rawText: 'Error: $e'),
            );
          });
        }
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (mounted) {
      setState(() {
        _isComplete = true;
        _statusMessage = 'Scanning complete!';
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) _navigateToMainApp();
    }
  }

  void _navigateToMainApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ExpensesSummaryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalReceipts > 0 ? _currentScanning / _totalReceipts : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
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
                ],
              ),
            ),

            // Pulsing Animation Area
            Expanded(
              flex: 4,
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Ring
                        Opacity(
                          opacity: 1.0 - (_pulseRing2.value - 0.8) / 0.7,
                          child: Transform.scale(
                            scale: _pulseRing2.value,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primaryContainer, width: 2),
                              ),
                            ),
                          ),
                        ),
                        // Inner Ring
                        Opacity(
                          opacity: 1.0 - (_pulseRing1.value - 0.6) / 0.6,
                          child: Transform.scale(
                            scale: _pulseRing1.value,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary, width: 4),
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                            ),
                          ),
                        ),
                        // Center Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceContainerLowest,
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 12))
                            ],
                          ),
                          child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 40),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Status Section
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  boxShadow: const [BoxShadow(color: Color.fromRGBO(11, 15, 16, 0.05), blurRadius: 40, offset: Offset(0, -10))],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isComplete ? 'Scan Complete' : 'Processing...',
                        style: GoogleFonts.manrope(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$_currentScanning / $_totalReceipts Receipts Processed', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
                          Text('${(progress * 100).toInt()}%', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 8,
                          color: AppColors.surfaceContainerHigh,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    width: constraints.maxWidth * progress,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(colors: [AppColors.primary, AppColors.tertiary]),
                                      borderRadius: BorderRadius.all(Radius.circular(4)),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Scanned Items Grid
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _scannedReceipts.length,
                          itemBuilder: (context, index) {
                            return _ReceiptListItem(receipt: _scannedReceipts[index], index: index + 1);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptListItem extends StatelessWidget {
  final ScannedReceipt receipt;
  final int index;

  const _ReceiptListItem({required this.receipt, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceContainerHigh, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.receipt_long, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan $index',
                    style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: recipeSuccessColor(receipt), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        receipt.amount > 0 ? 'Completed' : 'Failed',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (receipt.amount > 0)
              Text(
                '${receipt.amount.toStringAsFixed(0)} VND',
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }

  Color recipeSuccessColor(ScannedReceipt receipt) {
    return receipt.amount > 0 ? const Color(0xFF10B981) : AppColors.error;
  }
}

class ScannedReceipt {
  final String filename;
  final double amount;
  final String rawText;
  final String sender;
  final String recipient;
  final String time;

  ScannedReceipt({
    required this.filename,
    required this.amount,
    this.rawText = '',
    this.sender = 'N/A',
    this.recipient = 'N/A',
    this.time = 'N/A',
  });
}
