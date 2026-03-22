import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../models/receipt.dart';
import '../theme/app_colors.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final DatabaseService _databaseService = DatabaseService();
  List<Receipt> _receipts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllReceipts();
  }

  Future<void> _loadAllReceipts() async {
    setState(() => _isLoading = true);
    try {
      final receipts = await _databaseService.getAllReceipts();
      // Sort by date descending (newest first)
      receipts.sort((a, b) => b.imageTaken.compareTo(a.imageTaken));
      setState(() {
        _receipts = receipts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading receipts: $e');
      setState(() {
        _receipts = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceContainerHighest),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: AppColors.onSurfaceVariant, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Transaction History',
                      style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),
                  ),
                  // Total count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_receipts.length} items',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

            // Summary Card
            if (!_isLoading && _receipts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryContainer],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Spent', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                          const SizedBox(height: 4),
                          Text(
                            '${_receipts.fold<double>(0.0, (sum, r) => sum + r.amount).toStringAsFixed(0)} VND',
                            style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Receipt List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _receipts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 64, color: AppColors.onSurfaceVariant.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text('No transactions yet', style: GoogleFonts.inter(fontSize: 16, color: AppColors.onSurfaceVariant)),
                              const SizedBox(height: 8),
                              Text('Scan receipts to see your history', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant.withOpacity(0.6))),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAllReceipts,
                          color: AppColors.primary,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: _receipts.length,
                            itemBuilder: (context, index) {
                              final receipt = _receipts[index];

                              // Show date separator if different day from previous
                              bool showDateSeparator = true;
                              if (index > 0) {
                                final prev = _receipts[index - 1].imageTaken;
                                final curr = receipt.imageTaken;
                                if (prev.year == curr.year && prev.month == curr.month && prev.day == curr.day) {
                                  showDateSeparator = false;
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showDateSeparator)
                                    Padding(
                                      padding: EdgeInsets.only(top: index == 0 ? 0 : 16, bottom: 8),
                                      child: Text(
                                        _formatDateHeader(receipt.imageTaken),
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                                      ),
                                    ),
                                  _buildReceiptTile(receipt),
                                ],
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptTile(Receipt receipt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHighest),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long, color: AppColors.onSurfaceVariant, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.merchantName ?? 'Unknown Merchant',
                  style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(receipt.imageTaken),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${receipt.amount.toStringAsFixed(0)} VND',
                style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.onSurface),
              ),
              if (receipt.category != null && receipt.category!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    receipt.category!,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.tertiary),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:$minute $period';
  }
}
