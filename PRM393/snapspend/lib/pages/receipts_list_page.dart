import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../models/receipt.dart';
import '../theme/app_colors.dart';
import 'expenses_summary_page.dart';
import 'scan_receipts_page.dart';
import 'dart:io';

class ReceiptsListPage extends StatefulWidget {
  const ReceiptsListPage({super.key});

  @override
  State<ReceiptsListPage> createState() => _ReceiptsListPageState();
}

class _ReceiptsListPageState extends State<ReceiptsListPage> {
  final DatabaseService _databaseService = DatabaseService();
  List<Receipt> _receipts = [];
  List<Receipt> _filteredReceipts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Food', 'Transport', 'Utilities', 'Others'];

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final receipts = await _databaseService.getAllReceipts();
      
      // Sort receipts by date descending
      receipts.sort((a, b) => b.imageTaken.compareTo(a.imageTaken));

      setState(() {
        _receipts = receipts;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error loading receipts: $e');
    }
  }

  void _applyFilters() {
    _filteredReceipts = _receipts.where((receipt) {
      final matchesSearch = receipt.merchantName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      final matchesCategory = _selectedCategory == 'All' || (receipt.category == _selectedCategory);
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _deleteReceipt(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text('Delete Receipt', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this receipt?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.outline)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseService.deleteReceipt(id);
        _showSuccess('Receipt deleted');
        _loadReceipts();
      } catch (e) {
        _showError('Error deleting receipt: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF10B981)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.04),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 100, spreadRadius: 50)],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.history_edu, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SnapSpend', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface, letterSpacing: -0.5)),
                          Text('Receipts History', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Search Bar and Filters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.surfaceContainerHigh),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: AppColors.onSurfaceVariant, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                    _applyFilters();
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search receipts...',
                                  hintStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 14),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Filter Chips
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final isSelected = _selectedCategory == category;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = category;
                                  _applyFilters();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh),
                                  boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  category,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Main List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadReceipts,
                    color: AppColors.primary,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : _filteredReceipts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long, size: 64, color: AppColors.onSurfaceVariant.withOpacity(0.3)),
                                    const SizedBox(height: 16),
                                    Text('No receipts found', style: GoogleFonts.inter(fontSize: 18, color: AppColors.onSurfaceVariant)),
                                    const SizedBox(height: 100), // Push up slightly from bottom nav
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120),
                                physics: const BouncingScrollPhysics(),
                                itemCount: _filteredReceipts.length,
                                itemBuilder: (context, index) {
                                  return _buildReceiptCard(_filteredReceipts[index]);
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Navigation Bar Menu (Glassmorphic)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBottomNavItem(Icons.dashboard_rounded, 'Home', false, onTap: () {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ExpensesSummaryPage()));
                      }),
                      
                      // Scanner FAB
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanReceiptsPage()));
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryContainer]),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: const Icon(Icons.document_scanner, color: Colors.white),
                        ),
                      ),
                      
                      _buildBottomNavItem(Icons.history_rounded, 'History', true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(Receipt receipt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHighest),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReceiptDetails(receipt),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    image: File(receipt.imagePath).existsSync()
                        ? DecorationImage(
                            image: FileImage(File(receipt.imagePath)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: !File(receipt.imagePath).existsSync()
                      ? const Icon(Icons.receipt, color: AppColors.onSurfaceVariant)
                      : null,
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receipt.merchantName ?? 'Unknown Merchant',
                        style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: AppColors.onSurfaceVariant.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(receipt.imageTaken),
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                      if (receipt.category != null && receipt.category!.isNotEmpty && receipt.category != 'All') ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            receipt.category!,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.tertiary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${receipt.amount.toStringAsFixed(0)} VND',
                      style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReceiptDetails(Receipt receipt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle block
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Receipt Details', style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteReceipt(receipt.id!);
                    },
                  )
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Image
                      if (File(receipt.imagePath).existsSync()) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(receipt.imagePath),
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Grid Details
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.surfaceContainerHigh),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow('Merchant', receipt.merchantName ?? 'Unknown'),
                            const Divider(height: 24, color: AppColors.surfaceContainerHighest),
                            _buildDetailRow('Amount', '${receipt.amount.toStringAsFixed(0)} VND', isHighlight: true),
                            const Divider(height: 24, color: AppColors.surfaceContainerHighest),
                            _buildDetailRow('Date', DateFormat('MMMM dd, yyyy - hh:mm a').format(receipt.imageTaken)),
                            if (receipt.recipient != null && receipt.recipient != 'N/A') ...[
                              const Divider(height: 24, color: AppColors.surfaceContainerHighest),
                              _buildDetailRow('Recipient', receipt.recipient!),
                            ],
                            if (receipt.category != null) ...[
                              const Divider(height: 24, color: AppColors.surfaceContainerHighest),
                              _buildDetailRow('Category', receipt.category!),
                            ],
                          ],
                        ),
                      ),
                      
                      // Raw OCR text
                      if (receipt.rawOcrText != null && receipt.rawOcrText!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Scanned Text Data:', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.surfaceContainerHighest),
                          ),
                          child: Text(
                            receipt.rawOcrText!,
                            style: GoogleFonts.robotoMono(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            color: isHighlight ? AppColors.primary : AppColors.onSurface,
            fontSize: isHighlight ? 18 : 14,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, bool active, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? AppColors.primary : AppColors.onSurfaceVariant, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.w600,
              color: active ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final receiptDate = DateTime(date.year, date.month, date.day);

    if (receiptDate == today) {
      return 'Today';
    } else if (receiptDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }
}
