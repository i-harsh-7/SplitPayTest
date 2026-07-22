import 'package:flutter/material.dart';
import '../services/bill_service.dart';
import '../themes/app_theme.dart';
import '../components/header.dart';
import '../components/initial_avatar.dart';

class ExpenseSummaryPage extends StatefulWidget {
  final String groupId;
  final List<Map<String, String>> members;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final String? paidBy;
  final String? billName;

  const ExpenseSummaryPage({
    super.key,
    required this.groupId,
    required this.members,
    required this.items,
    required this.totalAmount,
    required this.paidBy,
    this.billName,
  });

  @override
  State<ExpenseSummaryPage> createState() => _ExpenseSummaryPageState();
}

class _ExpenseSummaryPageState extends State<ExpenseSummaryPage> {
  Map<String, double> _memberAmounts = {};
  Map<String, List<Map<String, dynamic>>> _memberItems = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _calculateMemberAmounts();
  }

  void _calculateMemberAmounts() {
    _memberAmounts.clear();
    _memberItems.clear();

    // Initialize all members with 0 amount
    for (var member in widget.members) {
      _memberAmounts[member['email']!] = 0.0;
      _memberItems[member['email']!] = [];
    }

    // Calculate amounts for each item
    for (var item in widget.items) {
      final itemPrice = item['price'] as double;
      final itemQuantity = item['quantity'] as int;
      final memberQuantities = item['memberQuantities'] as Map<String, int>;
      final distributionMethod = item['distributionMethod'] as String? ?? 'Equally';

      if (distributionMethod == 'Equally') {
        // For equally distributed items, split price equally among members
        final selectedMembers = item['takenBy'] as List<String>;
        final memberCount = selectedMembers.length;

        if (memberCount > 0) {
          final amountPerMember = itemPrice / memberCount;

          for (var memberEmail in selectedMembers) {
            _memberAmounts[memberEmail] = (_memberAmounts[memberEmail] ?? 0.0) + amountPerMember;
            _memberItems[memberEmail]!.add({
              'name': item['name'],
              'quantity': memberQuantities[memberEmail] ?? 0,
              'amount': amountPerMember,
              'totalQuantity': itemQuantity,
              'totalPrice': itemPrice,
            });
          }
        }
      } else {
        // For by quantity items, calculate based on individual quantities
        for (var entry in memberQuantities.entries) {
          final memberEmail = entry.key;
          final memberQuantity = entry.value;

          if (memberQuantity > 0) {
            final amountPerUnit = itemPrice / itemQuantity;
            final memberAmount = amountPerUnit * memberQuantity;

            _memberAmounts[memberEmail] = (_memberAmounts[memberEmail] ?? 0.0) + memberAmount;
            _memberItems[memberEmail]!.add({
              'name': item['name'],
              'quantity': memberQuantity,
              'amount': memberAmount,
              'totalQuantity': itemQuantity,
              'totalPrice': itemPrice,
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    // Get paid by member info
    final paidByMember = widget.members.firstWhere(
      (member) => member['email'] == widget.paidBy,
      orElse: () => {'name': 'Unknown', 'email': '', 'avatar': ''},
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Header(
            title: 'Expense Summary',
            heightFactor: 0.12,
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero Total Amount Card ─────────────────────────────
                    _HeroCard(
                      totalAmount: widget.totalAmount,
                      billName: widget.billName,
                      paidByMember: paidByMember,
                      isDark: isDark,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Section header ────────────────────────────────────
                    _SectionHeader(
                      label: 'Member Breakdown',
                      primaryColor: theme.primaryColor,
                      textColor: textColor,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── Member Cards ──────────────────────────────────────
                    ...widget.members.map((member) {
                      final email = member['email']!;
                      final memberAmount = _memberAmounts[email] ?? 0.0;
                      final memberItemList = _memberItems[email] ?? [];

                      if (memberAmount == 0.0) return const SizedBox.shrink();

                      final isPayer = member['email'] == widget.paidBy;

                      return _MemberCard(
                        member: member,
                        memberAmount: memberAmount,
                        memberItemList: memberItemList,
                        isPayer: isPayer,
                        isDark: isDark,
                        theme: theme,
                        textColor: textColor,
                      );
                    }).toList(),

                    const SizedBox(height: 100), // Space for floating button
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _ConfirmButton(
        isSubmitting: _isSubmitting,
        isDark: isDark,
        onPressed: () async {
          setState(() => _isSubmitting = true);
          try {
            // Map item assignedTo using member emails -> ids
            final items = widget.items.map((it) {
              final mapped = {
                'name': it['name'],
                'quantity': it['quantity'],
                'price': it['price'],
              };
              final takenByEmails = (it['takenBy'] as List?)?.cast<String>() ?? [];
              final assignedToIds = widget.members
                  .where((m) => takenByEmails.contains(m['email']))
                  .map((m) => m['id']!)
                  .toList();
              if (assignedToIds.isNotEmpty) mapped['assignedTo'] = assignedToIds;
              return mapped;
            }).toList();

            final billName = (widget.billName ?? 'Manual Expense').trim();
            final totalAmount = widget.totalAmount;

            // Resolve payer id
            String? payerId;
            if (widget.paidBy != null && widget.paidBy!.isNotEmpty) {
              payerId = widget.members
                  .firstWhere((m) => m['email'] == widget.paidBy, orElse: () => {'id': ''})['id'];
            }

            // Payments array
            final payments = <Map<String, dynamic>>[];
            if (payerId != null && payerId.isNotEmpty) {
              payments.add({
                'user': payerId,
                'amount': totalAmount,
              });
            }

            // Assignments based on per-item member amounts
            final assignments = <Map<String, dynamic>>[];
            if (payerId != null && payerId.isNotEmpty) {
              widget.members.forEach((member) {
                final email = member['email']!;
                final userId = member['id']!;
                final owed = _memberAmounts[email] ?? 0.0;
                if (owed > 0 && userId != payerId) {
                  assignments.add({
                    'from': userId,
                    'to': payerId,
                    'amount': double.parse(owed.toStringAsFixed(2)),
                  });
                }
              });
            }

            final res = await BillService.createManualExpense(
              groupId: widget.groupId,
              totalAmount: totalAmount,
              items: items,
              billName: billName.isNotEmpty ? billName : 'Manual Expense',
              splitMethod: 'per-item',
              payments: payments,
              assignments: assignments,
            );

            if (mounted) {
              if (res['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Expense added successfully!'),
                    backgroundColor: AppColors.success,
                  ),
                );
                Navigator.popUntil(context, (route) => route.isFirst);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Failed to create expense'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            }
          } finally {
            if (mounted) setState(() => _isSubmitting = false);
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ── Hero Card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.totalAmount,
    required this.billName,
    required this.paidByMember,
    required this.isDark,
  });

  final double totalAmount;
  final String? billName;
  final Map<String, String> paidByMember;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primaryDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.floating(isDark),
      ),
      child: Column(
        children: [
          // "Total Bill" label
          Text(
            'Total Bill',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.70),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Amount
          Text(
            '₹ ${totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          // Bill name pill chip
          if ((billName ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                billName!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          // Paid by row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InitialAvatar(
                name: paidByMember['name'] ?? 'User',
                radius: 16,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Paid by ${paidByMember['name'] ?? 'Unknown'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.primaryColor,
    required this.textColor,
  });

  final String label;
  final Color primaryColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 22,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

// ── Member Card ──────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.memberAmount,
    required this.memberItemList,
    required this.isPayer,
    required this.isDark,
    required this.theme,
    required this.textColor,
  });

  final Map<String, String> member;
  final double memberAmount;
  final List<Map<String, dynamic>> memberItemList;
  final bool isPayer;
  final bool isDark;
  final ThemeData theme;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: theme.dividerColor, width: 1),
        boxShadow: AppShadows.card(isDark),
      ),
      child: Column(
        children: [
          // ── Header row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                InitialAvatar(name: member['name']!, radius: 22),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        member['name']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      if (isPayer) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const _PaidBadge(),
                      ],
                    ],
                  ),
                ),
                Text(
                  '₹ ${memberAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // ── Items list ─────────────────────────────────────────────────
          if (memberItemList.isNotEmpty) ...[
            Divider(
              color: theme.dividerColor,
              height: 1,
              thickness: 1,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                children: memberItemList.map((item) {
                  return _ItemRow(
                    item: item,
                    isDark: isDark,
                    primaryColor: theme.primaryColor,
                    textColor: textColor,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Paid Badge ───────────────────────────────────────────────────────────────

class _PaidBadge extends StatelessWidget {
  const _PaidBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: const Text(
        'Paid',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.success,
        ),
      ),
    );
  }
}

// ── Item Row ─────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.isDark,
    required this.primaryColor,
    required this.textColor,
  });

  final Map<String, dynamic> item;
  final bool isDark;
  final Color primaryColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final rowBg = isDark
        ? AppColors.surfaceVariantDark
        : AppColors.borderLight.withOpacity(0.40);
    final rowBorder = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: rowBorder, width: 1),
      ),
      child: Row(
        children: [
          // Item name
          Expanded(
            child: Text(
              item['name'] as String,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Qty badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              '×${item['quantity']}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Amount
          Text(
            '₹ ${(item['amount'] as double).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Confirm Button ───────────────────────────────────────────────────────────

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.isSubmitting,
    required this.isDark,
    required this.onPressed,
  });

  final bool isSubmitting;
  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryLight, AppColors.primaryDeep],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: AppShadows.floating(isDark),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: isSubmitting ? null : onPressed,
            child: Center(
              child: isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'Confirm & Add Expense',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
