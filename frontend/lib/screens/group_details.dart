import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/header.dart';
import '../services/group_service.dart';
import '../services/auth_service.dart';
import '../services/invite_service.dart';
import 'add_bill.dart';
import 'members.dart';
import 'dart:convert';
import '../components/loading_dialog.dart';
import '../services/get_bills.dart';
import '../services/bill_service.dart';
import '../services/delete_bill.dart';
import '../themes/app_theme.dart';

class GroupDetailsPage extends StatefulWidget {
  final String groupId;
  const GroupDetailsPage({super.key, required this.groupId});
  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  bool _isLoading = true;
  String _groupName = 'Group';
  String _groupDescription = '';
  List<Map<String, String>> _members = [];
  String? _currentUserEmail;
  String? _adminEmail;
  String? _adminName;
  bool _isCurrentUserAdmin = false;
  late GroupService _groupService;
  List<Map<String, dynamic>> _billAssignments = [];
  List<Map<String, dynamic>> _bills = [];

  @override
  void initState() {
    super.initState();
    _groupService = Provider.of<GroupService>(context, listen: false);
    _loadGroupDetails();
    _loadBillAssignments();
    _loadBills();
  }

  Future<void> _loadGroupDetails() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = await AuthService.getProfile();
      _currentUserEmail = currentUser?.email ?? '';
      final groupData = await _groupService.fetchGroupDetails(widget.groupId);
      if (groupData != null && mounted) {
        final membersList = groupData['members'];
        if (membersList is List) {
          for (int i = 0; i < membersList.length; i++) {
            final member = membersList[i];
            if (member is Map) {
            }
          }
        }
        final createdByField = groupData['createdBy'];
        String? adminId;
        if (createdByField is Map) {
          _adminEmail = createdByField['email']?.toString();
          _adminName = createdByField['name']?.toString();
          adminId = createdByField['_id']?.toString() ?? createdByField['id']?.toString();
        } else if (createdByField is String) {
          adminId = createdByField;
        }
        _isCurrentUserAdmin = (_adminEmail != null && _adminEmail == _currentUserEmail);

        // Build the new member list before calling setState so the mutation
        // is committed atomically with the rebuild.
        final newMembers = <Map<String, String>>[];
        if (membersList is List && membersList.isNotEmpty) {
          for (final member in membersList) {
            if (member is Map) {
              final memberId = member['_id']?.toString() ?? member['id']?.toString() ?? '';
              final memberName = member['name']?.toString() ?? 'Member';
              final memberEmail = member['email']?.toString() ?? '';
              if (memberId.isNotEmpty && memberId != 'null') {
                final avatarId = memberEmail.isNotEmpty
                    ? (memberEmail.hashCode.abs() % 70) + 1
                    : (memberId.hashCode.abs() % 70) + 1;
                final isAdmin = (memberId == adminId) || (memberEmail == _adminEmail && memberEmail.isNotEmpty);
                final isCurrentUser = (memberEmail == _currentUserEmail && memberEmail.isNotEmpty);
                newMembers.add({
                  'id': memberId,
                  'name': memberName,
                  'email': memberEmail,
                  'avatar': 'https://i.pravatar.cc/150?img=$avatarId',
                  'isCurrentUser': isCurrentUser ? 'true' : 'false',
                  'isAdmin': isAdmin ? 'true' : 'false',
                });
              }
            } else if (member is String) {
            }
          }
        }
        if (newMembers.isEmpty) {
          throw Exception('No valid members found. The backend must populate member details in /group/get/:id endpoint.');
        }
        setState(() {
          _members = newMembers;
          _groupName = groupData['name']?.toString() ?? 'Group';
          _groupDescription = groupData['description']?.toString() ?? '';
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load group data');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadBillAssignments() async {
    try {
      final data = await GetBillsService.getAssignmentsForGroup();
      if (mounted) setState(() => _billAssignments = data);
    } catch (_) {}
  }

  Future<void> _loadBills() async {
    try {
      final data = await GetBillsService.getAllBills(groupId: widget.groupId);
      if (mounted) {
        setState(() => _bills = data);
        // Keep GroupService cache in sync so BalancesPanel analytics are accurate
        _groupService.setGroupBills(widget.groupId, data);
      }
    } catch (_) {}
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildExpenseCard({
    required Map<String, dynamic> expense,
    required Color cardColor,
    required Color textColor,
    required Color primaryColor,
    required bool isDark,
  }) {
    final totalAmount = (expense['totalAmount'] ?? 0).toDouble();
    final description = expense['description']?.toString() ?? 'Expense';
    final createdAt = expense['createdAt']?.toString() ?? '';
    final assignments = expense['assignments'] as List? ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 0.8),
        boxShadow: AppShadows.card(isDark),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '₹${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            ...assignments.map((assignment) {
              final fromName = assignment['from']?['name'] ?? 'Someone';
              final toName = assignment['to']?['name'] ?? 'Someone';
              final amount = (assignment['amount'] ?? 0).toDouble();
              final fromEmail = assignment['from']?['email'] ?? '';
              final toEmail = assignment['to']?['email'] ?? '';
              String displayText;
              Color displayColor;
              IconData displayIcon;
              if (fromEmail == _currentUserEmail) {
                displayText = 'You owe $toName ₹${amount.toStringAsFixed(2)}';
                displayColor = isDark ? AppColors.dangerDark : AppColors.danger;
                displayIcon = Icons.arrow_upward;
              } else if (toEmail == _currentUserEmail) {
                displayText = '$fromName owes you ₹${amount.toStringAsFixed(2)}';
                displayColor = isDark ? AppColors.successDark : AppColors.success;
                displayIcon = Icons.arrow_downward;
              } else {
                displayText = '$fromName owes $toName ₹${amount.toStringAsFixed(2)}';
                displayColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
                displayIcon = Icons.people_outline;
              }
              return Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(displayIcon, size: 14, color: displayColor),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(displayText, style: TextStyle(fontSize: 13, color: displayColor, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              );
            }).toList(),
            if (createdAt.isNotEmpty) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                _formatDate(createdAt),
                style: TextStyle(fontSize: 11, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Premium delete-confirmation dialog ──────────────────────────────────────
  Future<bool?> _showDeleteConfirmationDialog(String billName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyMedium?.color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final dangerColor = isDark ? AppColors.dangerDark : AppColors.danger;

    return showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        backgroundColor: theme.cardColor,
        contentPadding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: dangerColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, size: 34, color: dangerColor),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Delete Bill?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              '"$billName"',
              style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.65), fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'This action cannot be undone.',
              style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.45)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
          ],
        ),
        actionsPadding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dCtx).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: theme.dividerColor, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                    minimumSize: Size(0, 46),
                  ),
                  child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dCtx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dangerColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                    minimumSize: Size(0, 46),
                    elevation: 0,
                  ),
                  child: Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Receipt image viewer ─────────────────────────────────────────────────────
  Future<void> _viewReceiptImage(String expenseId) async {
    final headers = await BillService.receiptImageHeaders();
    if (!mounted) return;
    if (headers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not authenticated'), backgroundColor: AppColors.danger),
      );
      return;
    }
    final uri = BillService.receiptImageUri(expenseId);

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  uri.toString(),
                  headers: headers,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'Could not load receipt image',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Premium invite dialog ────────────────────────────────────────────────────
  void _showInviteDialog() {
    if (!_isCurrentUserAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.lock, color: Colors.white),
              SizedBox(width: AppSpacing.md),
              Expanded(child: Text('Only the group admin can invite members')),
            ],
          ),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
        ),
      );
      return;
    }

    final TextEditingController emailController = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final textColor = theme.textTheme.bodyMedium?.color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    // secondaryText must be computed here — it's only in scope inside build()
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
              backgroundColor: theme.cardColor,
              contentPadding: EdgeInsets.all(AppSpacing.lg),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Icon(Icons.person_add, color: primaryColor, size: 20),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invite Member', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textColor)),
                          Text('Add someone to this group', style: TextStyle(fontSize: 13, color: secondaryText)),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg),
                  // Email field with clear button
                  TextField(
                    controller: emailController,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
                      suffixIcon: emailController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 18),
                              onPressed: () {
                                emailController.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Please enter an email'), backgroundColor: AppColors.warning),
                          );
                          return;
                        }
                        Navigator.of(ctx).pop();
                        LoadingDialog.show(
                          context: context,
                          title: 'Sending Invite',
                          subtitle: 'Inviting $email to join the group...',
                          icon: Icons.send,
                          primaryColor: primaryColor,
                        );
                        try {
                          final result = await InviteService.sendInvite(
                            groupId: widget.groupId,
                            friendEmail: email,
                          );
                          LoadingDialog.hide(context);
                          if (result['success']) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invite sent successfully!'), backgroundColor: AppColors.success),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result['message'] ?? 'Failed to send invite'), backgroundColor: AppColors.danger),
                            );
                          }
                        } catch (e) {
                          LoadingDialog.hide(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.danger),
                          );
                        }
                      },
                      icon: Icon(Icons.send, size: 18),
                      label: Text('Send Invite', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Cancel', style: TextStyle(color: secondaryText, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Premium bill details bottom sheet ────────────────────────────────────────
  void _showBillDetailsModal(Map<String, dynamic> bill, ThemeData theme, Color textColor, Color cardColor, bool isDark) {
    final primaryColor = theme.primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
      builder: (ctx) {
        final createdBy = bill['createdBy'] ?? {};
        final createdByEmail = createdBy is Map ? (createdBy['email']?.toString() ?? '') : '';
        final billName = bill['billName']?.toString() ?? 'Bill';
        final totalAmount = (bill['totalAmount'] ?? 0).toDouble();
        final splitMethod = bill['splitMethod']?.toString() ?? '';
        final createdAt = bill['createdAt']?.toString() ?? '';
        final items = (bill['items'] as List?) ?? [];
        final assignments = (bill['assignments'] as List?) ?? [];
        final expenseId = bill['_id']?.toString() ?? bill['id']?.toString() ?? '';
        final canDelete = createdByEmail.isNotEmpty && createdByEmail == _currentUserEmail && expenseId.isNotEmpty;
        final billImageUrl = bill['billImageUrl']?.toString();
        final hasReceiptImage = billImageUrl != null && billImageUrl.isNotEmpty && expenseId.isNotEmpty;

        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          onTap: hasReceiptImage ? () => _viewReceiptImage(expenseId) : null,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Icon(Icons.receipt_long, color: primaryColor, size: 22),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                billName,
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 3),
                              Text(
                                'By ${createdBy is Map ? (createdBy['name'] ?? 'Unknown') : 'Unknown'}'
                                ' · ${_formatDate(createdAt)}'
                                '${splitMethod.isNotEmpty ? ' · $splitMethod' : ''}',
                                style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.55)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          '₹${totalAmount.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: primaryColor),
                        ),
                      ],
                    ),
                  ),
                  if (hasReceiptImage) ...[
                    SizedBox(height: AppSpacing.xs),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _viewReceiptImage(expenseId),
                          icon: Icon(Icons.image_outlined, size: 16),
                          label: Text('View Receipt', style: TextStyle(fontSize: 13)),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: AppSpacing.sm),
                  Divider(height: 1, thickness: 0.8),
                  // Scrollable content
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl),
                      children: [
                        if (items.isNotEmpty) ...[
                          Text(
                            'Items',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          ...items.map((it) {
                            final name = it['name']?.toString() ?? 'Item';
                            final qty = (it['quantity'] ?? 0).toString();
                            final price = (it['price'] ?? 0).toDouble();
                            return Container(
                              margin: EdgeInsets.only(bottom: AppSpacing.sm),
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                border: Border.all(color: theme.dividerColor, width: 0.8),
                                boxShadow: AppShadows.card(isDark),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(AppRadii.pill),
                                    ),
                                    child: Text(
                                      'x$qty',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
                                    ),
                                  ),
                                  Text(
                                    '₹${price.toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          SizedBox(height: AppSpacing.md),
                        ],
                        if (assignments.isNotEmpty) ...[
                          Text(
                            'Assignments',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          ...assignments.map((a) {
                            final fromName = a['from'] is Map ? (a['from']['name'] ?? 'Someone') : 'Someone';
                            final toName = a['to'] is Map ? (a['to']['name'] ?? 'Someone') : 'Someone';
                            final amount = (a['amount'] ?? 0).toDouble();
                            final amountColor = isDark ? AppColors.dangerDark : AppColors.danger;
                            return Container(
                              margin: EdgeInsets.only(bottom: AppSpacing.sm),
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                border: Border.all(color: theme.dividerColor, width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  _InitialAvatar(
                                    name: fromName,
                                    radius: 18,
                                    backgroundColor: primaryColor.withOpacity(0.18),
                                    textColor: primaryColor,
                                  ),
                                  SizedBox(width: AppSpacing.xs + 2),
                                  Icon(Icons.arrow_forward, size: 15, color: textColor.withOpacity(0.40)),
                                  SizedBox(width: AppSpacing.xs + 2),
                                  _InitialAvatar(
                                    name: toName,
                                    radius: 18,
                                    backgroundColor: (isDark ? AppColors.successDark : AppColors.success).withOpacity(0.18),
                                    textColor: isDark ? AppColors.successDark : AppColors.success,
                                  ),
                                  SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      '$fromName → $toName',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                    decoration: BoxDecoration(
                                      color: amountColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(AppRadii.pill),
                                    ),
                                    child: Text(
                                      '₹${amount.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: amountColor),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                        if (canDelete) ...[
                          SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final confirm = await _showDeleteConfirmationDialog(billName);
                                if (confirm != true) return;
                                final res = await DeleteBillService.deleteBill(
                                  expenseId: expenseId,
                                  context: context,
                                  groupId: widget.groupId,
                                );
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                if (res['success'] == true) {
                                  setState(() {
                                    _bills.removeWhere((b) => (b['_id']?.toString() ?? b['id']?.toString() ?? '') == expenseId);
                                  });
                                  // Keep GroupService cache in sync so analytics reflect the deletion
                                  _groupService.removeExpenseFromGroup(widget.groupId, expenseId);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Bill deleted'), backgroundColor: AppColors.success),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res['message'] ?? 'Failed to delete'), backgroundColor: AppColors.danger),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppColors.dangerDark : AppColors.danger,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                              ),
                              icon: Icon(Icons.delete_outline, size: 20),
                              label: Text('Delete Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Premium action card ──────────────────────────────────────────────────────
  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required Color cardColor,
    required Color textColor,
    bool isDisabled = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: theme.dividerColor, width: 0.8),
          boxShadow: AppShadows.card(isDark),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: InkWell(
            onTap: isDisabled ? null : onTap,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Icon(icon, size: 22, color: color),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDisabled ? textColor.withOpacity(0.35) : textColor,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyMedium?.color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final successColor = isDark ? AppColors.successDark : AppColors.success;
    final dangerColor = isDark ? AppColors.dangerDark : AppColors.danger;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Header(title: _groupName, heightFactor: 0.12),
          if (_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'Loading group details...',
                      style: TextStyle(color: secondaryText, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: primaryColor,
                onRefresh: () async {
                  await _loadGroupDetails();
                  await _loadBillAssignments();
                  await _loadBills();
                },
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Group info card ──────────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            border: Border.all(color: theme.dividerColor, width: 0.8),
                            boxShadow: AppShadows.card(isDark),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(AppRadii.sm),
                                    ),
                                    child: Icon(Icons.groups, size: 24, color: primaryColor),
                                  ),
                                  SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _groupName,
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          '${_members.length} member${_members.length != 1 ? 's' : ''}${_adminName != null && _adminName!.isNotEmpty ? ' · Admin: $_adminName' : ''}',
                                          style: TextStyle(fontSize: 13, color: secondaryText),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_groupDescription.isNotEmpty) ...[
                                SizedBox(height: AppSpacing.sm),
                                Divider(height: 1, thickness: 0.8),
                                SizedBox(height: AppSpacing.sm),
                                Text(
                                  _groupDescription,
                                  style: TextStyle(fontSize: 13, color: secondaryText),
                                ),
                              ],
                            ],
                          ),
                        ),

                        SizedBox(height: AppSpacing.lg),

                        // ── Premium action cards ─────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.person_add,
                                label: 'Invite',
                                color: _isCurrentUserAdmin ? primaryColor : secondaryText,
                                onTap: _showInviteDialog,
                                cardColor: cardColor,
                                textColor: textColor,
                                isDisabled: !_isCurrentUserAdmin,
                              ),
                            ),
                            SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.people,
                                label: 'Members',
                                color: successColor,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MembersPage(
                                        groupName: _groupName,
                                        members: _members,
                                        primaryColor: primaryColor,
                                      ),
                                    ),
                                  );
                                },
                                cardColor: cardColor,
                                textColor: textColor,
                              ),
                            ),
                          ],
                        ),

                        // ── Bills section ────────────────────────────────────
                        if (_bills.isNotEmpty) ...[
                          SizedBox(height: AppSpacing.lg),
                          Text(
                            'Bills',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          SizedBox(height: AppSpacing.md),
                          Column(
                            children: _bills.map((bill) {
                              final theme = Theme.of(context);
                              final billName = bill['billName']?.toString() ?? 'Bill';
                              final totalAmount = (bill['totalAmount'] ?? 0).toDouble();
                              final splitMethod = bill['splitMethod']?.toString() ?? '';
                              final createdAt = bill['createdAt']?.toString() ?? '';
                              final assignments = (bill['assignments'] as List?) ?? [];

                              double totalOwedToYou = 0.0;
                              double totalYouOwe = 0.0;
                              for (final a in assignments) {
                                final fromEmail = a is Map ? (a['from'] is Map ? (a['from']['email']?.toString() ?? '') : '') : '';
                                final toEmail = a is Map ? (a['to'] is Map ? (a['to']['email']?.toString() ?? '') : '') : '';
                                final amount = a is Map ? ((a['amount'] ?? 0).toDouble()) : 0.0;
                                if (fromEmail == _currentUserEmail) totalYouOwe += amount;
                                if (toEmail == _currentUserEmail) totalOwedToYou += amount;
                              }
                              final net = totalOwedToYou - totalYouOwe;

                              // Accent border color
                              final Color accentColor;
                              if (net > 0.0) {
                                accentColor = successColor;
                              } else if (net < 0.0) {
                                accentColor = dangerColor;
                              } else {
                                accentColor = theme.dividerColor;
                              }

                              return Container(
                                margin: EdgeInsets.only(bottom: AppSpacing.md),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: AppShadows.card(isDark),
                                ),
                                child: Material(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    onTap: () => _showBillDetailsModal(bill, theme, textColor, cardColor, isDark),
                                    borderRadius: BorderRadius.circular(16),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Left accent border
                                            Container(width: 3, color: accentColor),
                                            // Content
                                            Expanded(
                                              child: Padding(
                                                padding: EdgeInsets.all(AppSpacing.md),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        // Icon container
                                                        Container(
                                                          width: 44,
                                                          height: 44,
                                                          decoration: BoxDecoration(
                                                            color: primaryColor.withOpacity(0.12),
                                                            borderRadius: BorderRadius.circular(AppRadii.sm),
                                                          ),
                                                          child: Icon(Icons.receipt_long, color: primaryColor, size: 22),
                                                        ),
                                                        SizedBox(width: AppSpacing.md),
                                                        // Name + amount
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Row(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Expanded(
                                                                    child: Text(
                                                                      billName,
                                                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                  SizedBox(width: AppSpacing.xs),
                                                                  Container(
                                                                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                                                    decoration: BoxDecoration(
                                                                      color: primaryColor,
                                                                      borderRadius: BorderRadius.circular(AppRadii.pill),
                                                                    ),
                                                                    child: Text(
                                                                      '₹${totalAmount.toStringAsFixed(0)}',
                                                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              SizedBox(height: AppSpacing.xs),
                                                              // Date + split method chips
                                                              Row(
                                                                children: [
                                                                  if (createdAt.isNotEmpty)
                                                                    Text(
                                                                      _formatDate(createdAt),
                                                                      style: TextStyle(fontSize: 11, color: secondaryText),
                                                                    ),
                                                                  if (splitMethod.isNotEmpty) ...[
                                                                    SizedBox(width: AppSpacing.sm),
                                                                    Container(
                                                                      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                                      decoration: BoxDecoration(
                                                                        color: primaryColor.withOpacity(0.10),
                                                                        borderRadius: BorderRadius.circular(AppRadii.pill),
                                                                      ),
                                                                      child: Text(
                                                                        splitMethod,
                                                                        style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.w600),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: AppSpacing.sm),
                                                    // Status badge row
                                                    if (net > 0.0)
                                                      Container(
                                                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
                                                        decoration: BoxDecoration(
                                                          color: successColor,
                                                          borderRadius: BorderRadius.circular(AppRadii.pill),
                                                        ),
                                                        child: Text(
                                                          "You're owed ₹${net.toStringAsFixed(2)}",
                                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                                        ),
                                                      )
                                                    else if (net < 0.0)
                                                      Container(
                                                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
                                                        decoration: BoxDecoration(
                                                          color: dangerColor,
                                                          borderRadius: BorderRadius.circular(AppRadii.pill),
                                                        ),
                                                        child: Text(
                                                          'You owe ₹${(-net).toStringAsFixed(2)}',
                                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                                        ),
                                                      )
                                                    else
                                                      Container(
                                                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(AppRadii.pill),
                                                          border: Border.all(color: theme.dividerColor, width: 1),
                                                        ),
                                                        child: Text(
                                                          'Settled',
                                                          style: TextStyle(color: secondaryText, fontSize: 11, fontWeight: FontWeight.w500),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        // ── Uploaded bill assignments ────────────────────────
                        if (_billAssignments.isNotEmpty) ...[
                          SizedBox(height: AppSpacing.lg),
                          Text(
                            'Uploaded Bills',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Column(
                            children: _billAssignments.map((a) {
                              String getMemberName(String id) {
                                final found = _members.firstWhere(
                                  (m) => m['id'] == id,
                                  orElse: () => {},
                                );
                                return found['name'] ?? id;
                              }

                              final fromId = a['from']?.toString() ?? '';
                              final toId = a['to']?.toString() ?? '';
                              final amount = a['amount']?.toString() ?? '';
                              final fromName = getMemberName(fromId);
                              final toName = getMemberName(toId);

                              return Container(
                                margin: EdgeInsets.only(bottom: AppSpacing.sm),
                                padding: EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(AppRadii.md),
                                  border: Border.all(color: theme.dividerColor, width: 0.8),
                                  boxShadow: AppShadows.card(isDark),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(AppRadii.sm),
                                      ),
                                      child: Icon(Icons.receipt_long, color: primaryColor, size: 18),
                                    ),
                                    SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$fromName → $toName',
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Amount: ₹$amount',
                                            style: TextStyle(fontSize: 12, color: secondaryText),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                final invalidMembers = _members.where((m) => m['id'] == null || m['id']!.isEmpty || m['id'] == 'null').toList();
                if (invalidMembers.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Some members have invalid IDs. Cannot create bill.'),
                      backgroundColor: AppColors.danger,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                if (_members.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No members in group. Cannot create bill.'),
                      backgroundColor: AppColors.warning,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                for (var m in _members) {
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddBillPage(
                      groupId: widget.groupId,
                      members: _members,
                    ),
                  ),
                );
              },
              backgroundColor: primaryColor,
              icon: Icon(Icons.add, color: Colors.white),
              label: Text(
                'Add Bill',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ── Private helper: InitialAvatar ─────────────────────────────────────────────
class _InitialAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color backgroundColor;
  final Color textColor;

  const _InitialAvatar({
    required this.name,
    this.radius = 18,
    required this.backgroundColor,
    this.textColor = Colors.white,
  });

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        _initials,
        style: TextStyle(
          color: textColor,
          fontSize: radius * 0.65,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
