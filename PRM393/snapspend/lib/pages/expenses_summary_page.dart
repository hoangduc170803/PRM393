import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../models/receipt.dart';
import '../theme/app_colors.dart';
import 'scan_receipts_page.dart';
import 'transaction_history_page.dart';

class ExpensesSummaryPage extends StatefulWidget {
  const ExpensesSummaryPage({super.key});

  @override
  State<ExpensesSummaryPage> createState() => _ExpensesSummaryPageState();
}

class _ExpensesSummaryPageState extends State<ExpensesSummaryPage> {
  final DatabaseService _databaseService = DatabaseService();
  String _selectedPeriod = 'Monthly'; // Weekly, Monthly, Yearly
  double _totalExpenses = 0.0;
  List<Receipt> _receipts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;

      switch (_selectedPeriod) {
        case 'Weekly':
          final weekday = now.weekday;
          startDate = now.subtract(Duration(days: weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'Monthly':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'Yearly':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, 1);
      }

      final receipts = await _databaseService.getReceiptsByDateRange(startDate, endDate);

      double total = 0.0;
      for (var receipt in receipts) {
        total += receipt.amount;
      }

      setState(() {
        _receipts = receipts;
        _totalExpenses = total;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading expenses: $e');
      setState(() {
        _receipts = [];
        _totalExpenses = 0.0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -100,
            right: -50,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.wallet, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SnapSpend', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface, letterSpacing: -0.5)),
                              Text('Dashboard', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(), // Removed notification and user icons
                    ],
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadExpenses,
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          
                          // Segmented Control Filter
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                _buildFilterTab('Weekly'),
                                _buildFilterTab('Monthly'),
                                _buildFilterTab('Yearly'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Main Hero Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryContainer],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 12))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total Expenses', style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500)),
                                    if (!_isLoading && _receipts.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                        child: Text(
                                          '${_receipts.length} receipt${_receipts.length > 1 ? 's' : ''}',
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _isLoading
                                    ? const SizedBox(height: 48, width: 48, child: CircularProgressIndicator(color: Colors.white))
                                    : Text(
                                        '${_totalExpenses.toStringAsFixed(0)} VND',
                                        style: GoogleFonts.manrope(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Weekly Pattern (Chart placeholder)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.surfaceContainerHighest),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Spending Pattern', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                                const SizedBox(height: 24),
                                Builder(
                                  builder: (context) {
                                    // Compute daily spending from receipts
                                    final dayTotals = <int, double>{};
                                    for (int i = 1; i <= 7; i++) {
                                      dayTotals[i] = 0.0;
                                    }
                                    for (var receipt in _receipts) {
                                      final weekday = receipt.imageTaken.weekday; // 1=Mon, 7=Sun
                                      dayTotals[weekday] = (dayTotals[weekday] ?? 0.0) + receipt.amount;
                                    }
                                    final maxVal = dayTotals.values.fold<double>(0.0, (a, b) => a > b ? a : b);
                                    final today = DateTime.now().weekday;
                                    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: List.generate(7, (i) {
                                        final weekday = i + 1;
                                        final amount = dayTotals[weekday] ?? 0.0;
                                        final factor = maxVal > 0 ? amount / maxVal : 0.0;
                                        // Ensure a minimum visible height for non-zero values
                                        final displayFactor = amount > 0 && factor < 0.05 ? 0.05 : factor;
                                        return _buildChartBar(
                                          displayFactor,
                                          dayLabels[i],
                                          active: weekday == today,
                                          amount: amount,
                                        );
                                      }),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Recent Transactions Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Recent Transactions', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const TransactionHistoryPage()));
                                },
                                child: Text('View All', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Transactions List
                          _isLoading
                              ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                              : _receipts.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32.0),
                                        child: Column(
                                          children: [
                                            Icon(Icons.receipt_long, size: 48, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
                                            const SizedBox(height: 16),
                                            Text('No receipts found', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      physics: const NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      itemCount: _receipts.length > 5 ? 5 : _receipts.length, // Limit to recent 5
                                      itemBuilder: (context, index) {
                                        return _ReceiptCard(receipt: _receipts[index]);
                                      },
                                    ),
                          const SizedBox(height: 100), // Space for bottom nav
                        ],
                      ),
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
                      _buildBottomNavItem(Icons.dashboard_rounded, 'Home', true),
                      
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
                      
                      _buildBottomNavItem(Icons.history_rounded, 'History', false, onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const TransactionHistoryPage()));
                      }),
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

  Widget _buildFilterTab(String period) {
    bool isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = period;
          });
          _loadExpenses();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))] : [],
          ),
          alignment: Alignment.center,
          child: Text(
            period,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? AppColors.onSurface : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartBar(double heightFactor, String label, {bool active = false, double amount = 0.0}) {
    // Format amount for display
    String amountLabel;
    if (amount >= 1000000) {
      amountLabel = '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      amountLabel = '${(amount / 1000).toStringAsFixed(0)}K';
    } else if (amount > 0) {
      amountLabel = amount.toStringAsFixed(0);
    } else {
      amountLabel = '';
    }

    return Column(
      children: [
        if (amountLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              amountLabel,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: active ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        Container(
          width: 32,
          height: 100 * (heightFactor > 0 ? heightFactor : 0.02), // tiny baseline for zero
          decoration: BoxDecoration(
            color: active ? AppColors.primary : (amount > 0 ? AppColors.primary.withOpacity(0.3) : AppColors.primary.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? AppColors.primary : AppColors.onSurfaceVariant,
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
}

class _ReceiptCard extends StatelessWidget {
  final Receipt receipt;

  const _ReceiptCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(receipt.imageTaken),
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
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.onSurface),
              ),
              if (receipt.category != null && receipt.category!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final receiptDate = DateTime(date.year, date.month, date.day);

    if (receiptDate == today) {
      return 'Today, ${_formatTime(date)}';
    } else if (receiptDate == yesterday) {
      return 'Yesterday, ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:$minute $period';
  }
}
