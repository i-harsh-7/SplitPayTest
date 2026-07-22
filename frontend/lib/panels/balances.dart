import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/header.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../themes/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';

class BalancesPanel extends StatefulWidget {
  const BalancesPanel({super.key});

  @override
  State<BalancesPanel> createState() => _BalancesPanelState();
}

class _BalancesPanelState extends State<BalancesPanel> {
  double _youOwe = 0.0;
  double _youAreOwed = 0.0;
  String? _currentUserId;
  bool _isLoading = true;
  bool _isAnalyticsLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // Run balance fetch and analytics fetch in parallel
    await Future.wait([
      _loadBalances(),
      _loadAnalytics(),
    ]);
  }

  Future<void> _loadBalances() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userDetails = await AuthService.getUserDetails();

      if (userDetails != null && mounted) {
        double youOwe = 0.0;
        double youAreOwed = 0.0;
        String? userId;

        if (userDetails['user'] != null) {
          final userData = userDetails['user'];
          youOwe = _parseDouble(userData['youOwe']);
          youAreOwed = _parseDouble(userData['youAreOwed']);
          userId = userData['_id']?.toString() ?? userData['id']?.toString();
        } else if (userDetails['youOwe'] != null || userDetails['youAreOwed'] != null) {
          youOwe = _parseDouble(userDetails['youOwe']);
          youAreOwed = _parseDouble(userDetails['youAreOwed']);
          userId = userDetails['_id']?.toString() ?? userDetails['id']?.toString();
        }

        if (mounted) {
          setState(() {
            _youOwe = youOwe;
            _youAreOwed = youAreOwed;
            _currentUserId = userId;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Unable to load balance information';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading balances: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading balances: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadAnalytics() async {
    if (!mounted) return;
    setState(() => _isAnalyticsLoading = true);
    final groupService = Provider.of<GroupService>(context, listen: false);
    // Only fetch groups if not already loaded; then always refresh bills
    if (groupService.groups.isEmpty) {
      await groupService.fetchGroups();
    }
    await groupService.fetchAllBills();
    if (mounted) setState(() => _isAnalyticsLoading = false);
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Returns the user ID string from a populated or raw assignment field.
  String? _extractUserId(dynamic field) {
    if (field == null) return null;
    if (field is Map) return field['_id']?.toString() ?? field['id']?.toString();
    return field.toString();
  }

  Map<String, dynamic> _calculateAnalytics() {
    final groupService = Provider.of<GroupService>(context, listen: false);
    final allGroups = groupService.groups;

    double totalSpending = 0.0;
    Map<String, double> categorySpending = {
      'Food': 0.0,
      'Fare': 0.0,
      'Snacks': 0.0,
      'Clothing': 0.0,
      'Recharges': 0.0,
      'Entertainment': 0.0,
      'Utilities': 0.0,
      'Other': 0.0,
    };
    Map<String, double> monthlySpending = {};
    Map<String, double> userBalances = {};
    int totalExpenses = 0;

    for (var group in allGroups) {
      if (group.id == null) continue;
      final expenses = groupService.getGroupExpenses(group.id!);

      for (var expense in expenses) {
        // Determine the current user's personal share for this expense.
        // Strategy:
        //   1. Sum all assignment amounts where `from` is the current user — this is what
        //      they owe others (their debt share of the bill).
        //   2. Sum all payment amounts where `payment.user` is the current user — this is
        //      what they actually paid out of pocket.
        // Personal spend = payments made by user + owed amounts (assignments.from == user)
        // We count assignments.from as the user's consumed share because the app always
        // creates an assignment per debtor. If the user is the payer (no assignment FROM them),
        // their net contribution is captured via payments.
        // To avoid double-counting when the payer also has an assignment, we use the
        // assignment sum as primary and fall back to totalAmount only when there are no
        // assignments at all (e.g. a freshly uploaded, unassigned bill).

        final assignments = expense['assignments'] as List? ?? [];
        final payments = expense['payments'] as List? ?? [];

        double userAssignedShare = 0.0;
        double userPaymentShare = 0.0;
        bool hasAnyAssignment = assignments.isNotEmpty;

        for (var assignment in assignments) {
          if (assignment is! Map) continue;
          final fromId = _extractUserId(assignment['from']);
          if (_currentUserId != null && fromId == _currentUserId) {
            userAssignedShare += _parseDouble(assignment['amount']);
          }
          // Accumulate other-person balances for the "Top Debtors" chart
          final from = assignment['from'];
          String fromName;
          if (from is Map) {
            fromName = from['name']?.toString() ?? 'Unknown';
          } else {
            fromName = from?.toString() ?? 'Unknown';
          }
          userBalances[fromName] = (userBalances[fromName] ?? 0.0) + _parseDouble(assignment['amount']);
        }

        for (var payment in payments) {
          if (payment is! Map) continue;
          final payerId = _extractUserId(payment['user']);
          if (_currentUserId != null && payerId == _currentUserId) {
            userPaymentShare += _parseDouble(payment['amount']);
          }
        }

        // Personal share: if assignments exist, use the sum of what this user owes (their
        // debtor share). If the user is the payer with no FROM-assignment, use their payment.
        // If there are no assignments yet (bill just uploaded), fall back to totalAmount
        // divided equally so the analytics still shows something reasonable.
        double personalShare;
        if (hasAnyAssignment) {
          // User is a debtor: use assigned share. User is only the payer: use payment amount.
          personalShare = userAssignedShare > 0 ? userAssignedShare : userPaymentShare;
        } else {
          // Unassigned bill — show total so at least something appears
          personalShare = _parseDouble(expense['totalAmount']);
        }

        // Only count expenses where the current user is actually involved (or when userId is
        // unknown, fall back to total to avoid blank analytics).
        if (_currentUserId == null) {
          personalShare = _parseDouble(expense['totalAmount']);
        }

        if (personalShare <= 0) continue;

        totalExpenses++;
        totalSpending += personalShare;

        // Categorize by billName
        final description = (expense['billName'] ?? expense['description'] ?? '')
            .toString()
            .toLowerCase();
        String category = 'Other';

        if (description.contains('snack') || description.contains('chips') ||
            description.contains('cookie') || description.contains('biscuit') ||
            description.contains('chocolate') || description.contains('tea') ||
            description.contains('coffee') || description.contains('canteen')) {
          category = 'Snacks';
        } else if (description.contains('food') || description.contains('restaurant') ||
            description.contains('dinner') || description.contains('lunch') ||
            description.contains('breakfast') || description.contains('paneer') ||
            description.contains('chicken') || description.contains('pizza') ||
            description.contains('burger')) {
          category = 'Food';
        } else if (description.contains('fare') || description.contains('travel') ||
            description.contains('uber') || description.contains('ola') ||
            description.contains('taxi') || description.contains('cab') ||
            description.contains('bus') || description.contains('train') ||
            description.contains('metro') || description.contains('flight') ||
            description.contains('hotel')) {
          category = 'Fare';
        } else if (description.contains('cloth') || description.contains('shirt') ||
            description.contains('jeans') || description.contains('shoe') ||
            description.contains('dress') || description.contains('fashion') ||
            description.contains('myntra') || description.contains('amazon') ||
            description.contains('flipkart')) {
          category = 'Clothing';
        } else if (description.contains('recharge') || description.contains('mobile') ||
            description.contains('data pack') || description.contains('dth') ||
            description.contains('wifi') || description.contains('broadband')) {
          category = 'Recharges';
        } else if (description.contains('movie') || description.contains('game') ||
            description.contains('concert') || description.contains('party') ||
            description.contains('netflix') || description.contains('subscription')) {
          category = 'Entertainment';
        } else if (description.contains('electric') || description.contains('water') ||
            description.contains('rent') || description.contains('utility') ||
            description.contains('gas')) {
          category = 'Utilities';
        }

        categorySpending[category] = (categorySpending[category] ?? 0) + personalShare;

        // Monthly spending
        try {
          final dateStr = expense['createdAt']?.toString() ?? '';
          if (dateStr.isNotEmpty) {
            final date = DateTime.parse(dateStr);
            final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
            monthlySpending[monthKey] = (monthlySpending[monthKey] ?? 0) + personalShare;
          }
        } catch (_) {}
      }
    }

    return {
      'totalSpending': totalSpending,
      'categorySpending': categorySpending,
      'monthlySpending': monthlySpending,
      'userBalances': userBalances,
      'totalExpenses': totalExpenses,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color textPrimary = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final Color cardColor = theme.cardColor;
    final Color owedColor = theme.brightness == Brightness.dark
        ? AppColors.dangerDark
        : AppColors.danger;
    final Color owingColor = theme.brightness == Brightness.dark
        ? AppColors.successDark
        : AppColors.success;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Header(title: "Your Balances", heightFactor: 0.12),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading balances...',
                          style: TextStyle(color: textPrimary.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Consumer<GroupService>(
                          builder: (context, groupService, _) {
                            final analytics = _calculateAnalytics();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_errorMessage != null) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: Colors.red),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(color: Colors.red, fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Balance Cards Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildBalanceCard(
                                        icon: Icons.arrow_upward,
                                        label: "You Owe",
                                        amount: _youOwe,
                                        color: owedColor,
                                        cardColor: cardColor,
                                        textColor: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildBalanceCard(
                                        icon: Icons.arrow_downward,
                                        label: "You are Owed",
                                        amount: _youAreOwed,
                                        color: owingColor,
                                        cardColor: cardColor,
                                        textColor: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                _buildNetBalanceCard(
                                  youOwe: _youOwe,
                                  youAreOwed: _youAreOwed,
                                  owedColor: owedColor,
                                  owingColor: owingColor,
                                  textColor: textPrimary,
                                ),

                                const SizedBox(height: 30),

                                // Analytics Section Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Analytics',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    _isAnalyticsLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: theme.primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '${analytics['totalExpenses']} Bills',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: theme.primaryColor,
                                              ),
                                            ),
                                          ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                _buildTotalSpendingCard(
                                  analytics['totalSpending'] as double,
                                  cardColor,
                                  textPrimary,
                                  theme.primaryColor,
                                ),

                                const SizedBox(height: 16),

                                if ((analytics['categorySpending'] as Map<String, double>)
                                    .values.any((v) => v > 0)) ...[
                                  _buildSectionTitle('Spending by Category', textPrimary),
                                  const SizedBox(height: 12),
                                  _buildCategorySpendingChart(
                                    analytics['categorySpending'] as Map<String, double>,
                                    cardColor,
                                    textPrimary,
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                if ((analytics['monthlySpending'] as Map<String, double>).isNotEmpty) ...[
                                  _buildSectionTitle('Spending Over Time', textPrimary),
                                  const SizedBox(height: 12),
                                  _buildSpendingOverTimeChart(
                                    analytics['monthlySpending'] as Map<String, double>,
                                    cardColor,
                                    textPrimary,
                                    theme.primaryColor,
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                if ((analytics['userBalances'] as Map<String, double>).isNotEmpty) ...[
                                  _buildSectionTitle('Top Debtors', textPrimary),
                                  const SizedBox(height: 12),
                                  _buildUserBalancesChart(
                                    analytics['userBalances'] as Map<String, double>,
                                    cardColor,
                                    textPrimary,
                                    owedColor,
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                if (!_isAnalyticsLoading &&
                                    (analytics['totalExpenses'] as int) == 0)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: theme.primaryColor, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'No bills found where you have a share. Add bills and assign yourself to see analytics.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: textPrimary.withOpacity(0.7),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 20),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
    );
  }

  Widget _buildBalanceCard({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
    required Color cardColor,
    required Color textColor,
  }) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              "₹ ${amount.toStringAsFixed(2)}",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetBalanceCard({
    required double youOwe,
    required double youAreOwed,
    required Color owedColor,
    required Color owingColor,
    required Color textColor,
  }) {
    final netBalance = youAreOwed - youOwe;
    final isPositive = netBalance >= 0;
    final displayColor = isPositive ? owingColor : owedColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPositive
              ? [owingColor.withOpacity(0.2), owingColor.withOpacity(0.05)]
              : [owedColor.withOpacity(0.2), owedColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPositive ? owingColor.withOpacity(0.3) : owedColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Net Balance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹ ${netBalance.abs().toStringAsFixed(2)}',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: displayColor),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                size: 18,
                color: displayColor,
              ),
              const SizedBox(width: 6),
              Text(
                isPositive ? 'You are owed overall' : 'You owe overall',
                style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.6)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSpendingCard(
    double totalSpending,
    Color cardColor,
    Color textColor,
    Color accentColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.account_balance_wallet, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Spending',
                      style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${totalSpending.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your personal share across all groups',
            style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySpendingChart(
    Map<String, double> categorySpending,
    Color cardColor,
    Color textColor,
  ) {
    final nonZeroCategories = Map.fromEntries(
      categorySpending.entries.where((e) => e.value > 0),
    );

    if (nonZeroCategories.isEmpty) return const SizedBox.shrink();

    final total = nonZeroCategories.values.fold(0.0, (sum, val) => sum + val);

    final colors = [
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.brown,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: nonZeroCategories.entries.toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final value = entry.value.value;
                    final percentage = (value / total * 100);
                    return PieChartSectionData(
                      color: colors[index % colors.length],
                      value: value,
                      title: '${percentage.toStringAsFixed(0)}%',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      titlePositionPercentageOffset: 0.6,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: nonZeroCategories.entries.toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value.key;
                  final value = entry.value.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors[index % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            category,
                            style: TextStyle(fontSize: 13, color: textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${value.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingOverTimeChart(
    Map<String, double> monthlySpending,
    Color cardColor,
    Color textColor,
    Color accentColor,
  ) {
    if (monthlySpending.isEmpty) return const SizedBox.shrink();

    final sortedEntries = monthlySpending.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final maxValue = sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxValue * 1.2,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i >= 0 && i < sortedEntries.length) {
                      final parts = sortedEntries[i].key.split('-');
                      final monthNum = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
                      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          monthNum > 0 && monthNum <= 12 ? months[monthNum] : sortedEntries[i].key,
                          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value >= 1000
                          ? '₹${(value / 1000).toStringAsFixed(0)}k'
                          : '₹${value.toStringAsFixed(0)}',
                      style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: sortedEntries.asMap().entries.map((entry) {
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: entry.value.value,
                    color: accentColor,
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildUserBalancesChart(
    Map<String, double> userBalances,
    Color cardColor,
    Color textColor,
    Color accentColor,
  ) {
    final sortedBalances = userBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedBalances.take(5).toList();
    if (top5.isEmpty) return const SizedBox.shrink();

    final maxAmount = top5.first.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: top5.map((entry) {
          final percentage = maxAmount > 0 ? entry.value / maxAmount : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${entry.value.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 8,
                    backgroundColor: accentColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
