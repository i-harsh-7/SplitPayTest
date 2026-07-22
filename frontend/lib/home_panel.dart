import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'panels/profile.dart';
import 'panels/group.dart';
import 'panels/create_group.dart';
import 'panels/balances.dart';
import 'screens/add_bill.dart';
import 'services/auth_service.dart';
import 'services/group_service.dart';
import 'services/invite_service.dart';
import 'services/notification_service.dart';
import 'components/loading_dialog.dart';

class HomePanel extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;
  final VoidCallback onLogout;

  const HomePanel({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
    required this.onLogout,
  });

  @override
  State<HomePanel> createState() => _HomePanelState();
}

class _HomePanelState extends State<HomePanel> {
  String? _name;
  List<Map<String, dynamic>> _pendingInvites = [];
  List<Map<String, dynamic>> _notifications = [];
  bool _loadingInvites = false;
  bool _loadingNotifications = false;

  // Cached tab widgets — created once in initState so rebuilds from
  // GroupService.notifyListeners() don't re-instantiate them and retrigger
  // initState / network calls on BalancesPanel and ProfilePanel.
  late final List<Widget> _cachedTabs;

  @override
  void initState() {
    super.initState();
    _cachedTabs = [
      // index 0 is the home panel which reads local state — built inline in build()
      const GroupsPanel(),
      const CreateGroupPage(),
      const BalancesPanel(),
      ProfilePanel(onLogout: widget.onLogout),
    ];
    _loadProfile();
    _loadPendingInvites();
    _loadNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupService>(context, listen: false).fetchGroups();
    });
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.getProfile();
    if (profile != null && mounted) {
      setState(() {
        _name = profile.name;
      });
    }
  }

  Future<void> _loadPendingInvites() async {
    setState(() => _loadingInvites = true);
    try {
      final invites = await InviteService.getPendingInvites();
      if (mounted) {
        setState(() {
          _pendingInvites = invites;
          _loadingInvites = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingInvites = false);
      }
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _loadingNotifications = true);
    try {
      final notifications = await NotificationService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _loadingNotifications = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingNotifications = false);
      }
    }
  }

  Future<void> _handleAcceptInvite(String inviteId, String groupName) async {
    LoadingDialog.show(
      context: context,
      title: 'Accepting Invite',
      subtitle: 'Joining "$groupName"...',
      icon: Icons.group_add,
      primaryColor: Colors.green,
    );

    try {
      final result = await InviteService.acceptInvite(inviteId);
      LoadingDialog.hide(context);

      if (!mounted) return;
      if (result['success']) {
        await Future.wait([
          Provider.of<GroupService>(context, listen: false).fetchGroups(),
          _loadPendingInvites(),
        ]);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Joined "$groupName" successfully!')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      LoadingDialog.hide(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRejectInvite(String inviteId, String groupName) async {
    LoadingDialog.show(
      context: context,
      title: 'Declining Invite',
      subtitle: 'Declining invitation to "$groupName"...',
      icon: Icons.group_remove,
      primaryColor: Colors.orange,
    );

    try {
      final result = await InviteService.rejectInvite(inviteId);
      LoadingDialog.hide(context);

      if (!mounted) return;
      if (result['success']) {
        await _loadPendingInvites();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Declined invitation to "$groupName"')),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      LoadingDialog.hide(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _dismissNotification(String notificationId) async {
    try {
      await NotificationService.dismissNotification(notificationId);
      await _loadNotifications();
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error dismissing notification'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToCreateGroup() {
    final svc = Provider.of<GroupService>(context, listen: false);
    svc.selectedIndex = 2;
  }

  void _showAddBillDialog() async {
    final groupService = Provider.of<GroupService>(context, listen: false);
    final groups = groupService.groups;

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please create a group first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.receipt_long, color: Theme.of(context).primaryColor),
              SizedBox(width: 12),
              Text('Select Group'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: groups.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final group = groups[index];
                return ListTile(
                  leading: Icon(
                    Icons.groups,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text(
                    group.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text('${group.members} member${group.members != 1 ? 's' : ''}'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    
                    navigator.pop();

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (loadingCtx) => WillPopScope(
                        onWillPop: () async => false,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Loading group details...'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    try {
                      final groupData = await groupService.fetchGroupDetails(group.id!)
                          .timeout(
                            Duration(seconds: 15),
                            onTimeout: () {
                              throw Exception('Request timed out. Please check your connection.');
                            },
                          );

                      if (groupData == null) {
                        throw Exception('Failed to load group details');
                      }

                      print('📦 Group data received: ${groupData.keys}');

                      List<Map<String, String>> members = [];
                      final membersList = groupData['members'];
                      
                      print('👥 Members list type: ${membersList.runtimeType}');
                      print('👥 Members list: $membersList');
                      
                      if (membersList is List && membersList.isNotEmpty) {
                        for (final member in membersList) {
                          if (member is Map) {
                            final memberId = member['_id']?.toString() ?? member['id']?.toString() ?? '';
                            final memberName = member['name']?.toString() ?? 'Member';
                            final memberEmail = member['email']?.toString() ?? '';
                            
                            print('   Processing: $memberName (ID: $memberId)');
                            
                            if (memberId.isNotEmpty && memberId != 'null') {
                              final avatarId = memberEmail.isNotEmpty 
                                  ? (memberEmail.hashCode.abs() % 70) + 1
                                  : (memberId.hashCode.abs() % 70) + 1;
                              
                              members.add({
                                'id': memberId,
                                'name': memberName,
                                'email': memberEmail,
                                'avatar': 'https://i.pravatar.cc/150?img=$avatarId',
                              });
                              
                              print('   ✅ Added: $memberName');
                            }
                          }
                        }
                      }

                      print('📋 Total members extracted: ${members.length}');

                      if (members.isEmpty) {
                        throw Exception('No valid members found in group. Please ensure the group has members.');
                      }

                      if (mounted && navigator.canPop()) {
                        navigator.pop();
                      }

                      if (mounted) {
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => AddBillPage(
                              groupId: group.id!,
                              members: members,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      print('❌ Error in _showAddBillDialog: $e');
                      
                      if (mounted && navigator.canPop()) {
                        try {
                          navigator.pop();
                        } catch (_) {}
                      }
                      
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 4),
                            action: SnackBarAction(
                              label: 'OK',
                              textColor: Colors.white,
                              onPressed: () {},
                            ),
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHome(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    final colorPrimary = Theme.of(context).primaryColor;
    final background = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textPrimary = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;

    final media = MediaQuery.of(context);
    final size = media.size;
    final textScale = media.textScaler.scale(1.0);
    final horizontalPadding = (size.width * 0.045).clamp(12.0, 24.0);
    final cardRadius = (size.width * 0.035).clamp(12.0, 18.0);
    final sectionTitleSize = (size.width * 0.045).clamp(16.0, 20.0) * textScale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRoundedHeader(context, colorPrimary, cardColor, textPrimary),

        Expanded(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(horizontalPadding),
            color: background,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_pendingInvites.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Pending Invitations",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: sectionTitleSize,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_pendingInvites.length}',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, size: 20),
                          onPressed: _loadPendingInvites,
                          tooltip: 'Refresh invites',
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ..._pendingInvites.map((invite) => _buildInviteCard(
                      invite: invite,
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      colorPrimary: colorPrimary,
                      cardRadius: cardRadius,
                      isDark: isDark,
                    )),
                    SizedBox(height: 20),
                  ],

                  if (_notifications.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Notifications",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: sectionTitleSize,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorPrimary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_notifications.length}',
                                style: TextStyle(
                                  color: colorPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, size: 20),
                          onPressed: _loadNotifications,
                          tooltip: 'Refresh notifications',
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ..._notifications.map((notification) => _buildNotificationCard(
                      notification: notification,
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      colorPrimary: colorPrimary,
                      cardRadius: cardRadius,
                      isDark: isDark,
                    )),
                    SizedBox(height: 20),
                  ],

                  if (_pendingInvites.isEmpty && _notifications.isEmpty &&
                      !_loadingInvites && !_loadingNotifications)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: isDark ? Colors.white24 : Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No pending invitations",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "You're all caught up!",
                              style: TextStyle(
                                fontSize: 14,
                                color: textPrimary.withOpacity(0.6),
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
      ],
    );
  }

  Widget _buildInviteCard({
    required Map<String, dynamic> invite,
    required Color cardColor,
    required Color textPrimary,
    required Color colorPrimary,
    required double cardRadius,
    required bool isDark,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.mail_outline,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite['groupName'] ?? 'Group',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Invited by ${invite['senderName'] ?? 'Someone'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: textPrimary.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAcceptInvite(
                      invite['id'],
                      invite['groupName'] ?? 'Group',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      'Accept',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleRejectInvite(
                      invite['id'],
                      invite['groupName'] ?? 'Group',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Decline',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required Map<String, dynamic> notification,
    required Color cardColor,
    required Color textPrimary,
    required Color colorPrimary,
    required double cardRadius,
    required bool isDark,
  }) {
    final type = notification['type'] ?? 'info';
    Color accentColor;
    IconData icon;

    switch (type) {
      case 'accepted':
        accentColor = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        accentColor = Colors.red;
        icon = Icons.cancel_outlined;
        break;
      default:
        accentColor = colorPrimary;
        icon = Icons.info_outline;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] ?? 'Notification',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notification['message'] != null) ...[
                    SizedBox(height: 4),
                    Text(
                      notification['message'],
                      style: TextStyle(
                        fontSize: 13,
                        color: textPrimary.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (notification['timestamp'] != null) ...[
                    SizedBox(height: 4),
                    Text(
                      notification['timestamp'],
                      style: TextStyle(
                        fontSize: 11,
                        color: textPrimary.withOpacity(0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 20),
              color: textPrimary.withOpacity(0.5),
              onPressed: () => _dismissNotification(notification['id']),
              tooltip: 'Dismiss',
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundedHeader(BuildContext context, Color colorPrimary, Color cardColor, Color textPrimary) {
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight = screenHeight * 0.30;

    return Container(
      height: headerHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorPrimary, Color.lerp(colorPrimary, Colors.black, 0.18)!],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: colorPrimary.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: (headerHeight * 0.06).clamp(10.0, 24.0)),
              child: Center(
                child: Text(
                  "SplitPay",
                  style: TextStyle(
                    fontSize: (headerHeight * 0.09).clamp(18.0, 26.0),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: (headerHeight * 0.12).clamp(8.0, 28.0), left: 18, right: 18),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Container(
                      padding: EdgeInsets.all((headerHeight * 0.06).clamp(10.0, 20.0)),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular((headerHeight * 0.08).clamp(16.0, 28.0)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name != null
                                ? "Hi $_name, ready to split today's bill?"
                                : "Hi there, ready to split today's bill?",
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: (headerHeight * 0.06).clamp(14.0, 18.0),
                            ),
                          ),
                          SizedBox(height: (headerHeight * 0.04).clamp(8.0, 14.0)),
                          
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorPrimary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular((headerHeight * 0.05).clamp(10.0, 16.0)),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: (headerHeight * 0.06).clamp(8.0, 16.0), 
                                      vertical: (headerHeight * 0.05).clamp(8.0, 12.0)
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: _navigateToCreateGroup,
                                  icon: Icon(Icons.group_add, size: 18),
                                  label: Text(
                                    "Create Group",
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular((headerHeight * 0.05).clamp(10.0, 16.0)),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: (headerHeight * 0.06).clamp(8.0, 16.0), 
                                      vertical: (headerHeight * 0.05).clamp(8.0, 12.0)
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: _showAddBillDialog,
                                  icon: Icon(Icons.receipt_long, size: 18),
                                  label: Text(
                                    "Add Bill",
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Calculate floating button position
  double _getFloatingButtonPosition(int index, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final navBarWidth = screenWidth - 32; // minus horizontal margins (16 each side)
    final contentWidth = navBarWidth - 40; // minus internal padding (20 each side)
    final itemWidth = contentWidth / 5; // divide equally by 5 items
    
    // Calculate exact center position for the bubble
    final bubbleWidth = 70.0;
    final startPosition = 20.0; // left padding
    final itemCenter = startPosition + (itemWidth * index) + (itemWidth / 2);
    
    return itemCenter - (bubbleWidth / 2); // center the bubble on the icon
  }

  // NEW: Floating nav item widget
  Widget _buildFloatingNavItem({
    required IconData icon,
    required int index,
    required int currentIndex,
    required Color colorPrimary,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final isSelected = currentIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 70,
          alignment: Alignment.center,
          child: AnimatedSlide(
            offset: Offset(0, isSelected ? -0.06 : 0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
            child: AnimatedScale(
              scale: isSelected ? 1.12 : 0.95,
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn,
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white38 : Colors.grey.shade400),
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    final colorPrimary = Theme.of(context).primaryColor;

    return WillPopScope(
      onWillPop: () async {
        final svc = Provider.of<GroupService>(context, listen: false);
        if (svc.selectedIndex != 0) {
          svc.selectedIndex = 0;
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: Provider.of<GroupService>(context).selectedIndex == 4
            ? AppBar(
          title: Text('SplitPay'),
          actions: [
            IconButton(
              icon: Icon(isDark ? Icons.wb_sunny : Icons.nightlight_round),
              onPressed: widget.toggleTheme,
            ),
          ],
        )
            : null,
        body: Consumer<GroupService>(
          builder: (context, svc, _) {
            final idx = svc.selectedIndex;
            // index 0 is rebuilt reactively (reads _name, _pendingInvites etc.)
            // indices 1-4 use the cached widgets to avoid re-running their initState
            final Widget currentTab = idx == 0
                ? _buildHome(context)
                : _cachedTabs[idx - 1];
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey<int>(idx),
                child: currentTab,
              ),
            );
          },
        ),
        bottomNavigationBar: Consumer<GroupService>(
          builder: (context, svc, _) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              height: 75,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                  width: isDark ? 1 : 0.8,
                ),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Stack(
                  children: [
                    // Animated floating button background
                    AnimatedPositioned(
                      duration: Duration(milliseconds: 400),
                      curve: Curves.fastOutSlowIn,
                      left: _getFloatingButtonPosition(svc.selectedIndex, context),
                      top: 2.5,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorPrimary,
                              colorPrimary.withOpacity(0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorPrimary.withOpacity(0.4),
                              blurRadius: 20,
                              offset: Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Navigation items
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildFloatingNavItem(
                            icon: Icons.home_rounded,
                            index: 0,
                            currentIndex: svc.selectedIndex,
                            colorPrimary: colorPrimary,
                            isDark: isDark,
                            onTap: () {
                              svc.selectedIndex = 0;
                              _loadPendingInvites();
                              _loadNotifications();
                            },
                          ),
                          _buildFloatingNavItem(
                            icon: Icons.groups_rounded,
                            index: 1,
                            currentIndex: svc.selectedIndex,
                            colorPrimary: colorPrimary,
                            isDark: isDark,
                            onTap: () => svc.selectedIndex = 1,
                          ),
                          _buildFloatingNavItem(
                            icon: Icons.add_circle_rounded,
                            index: 2,
                            currentIndex: svc.selectedIndex,
                            colorPrimary: colorPrimary,
                            isDark: isDark,
                            onTap: () => svc.selectedIndex = 2,
                          ),
                          _buildFloatingNavItem(
                            icon: Icons.account_balance_wallet_rounded,
                            index: 3,
                            currentIndex: svc.selectedIndex,
                            colorPrimary: colorPrimary,
                            isDark: isDark,
                            onTap: () => svc.selectedIndex = 3,
                          ),
                          _buildFloatingNavItem(
                            icon: Icons.person_rounded,
                            index: 4,
                            currentIndex: svc.selectedIndex,
                            colorPrimary: colorPrimary,
                            isDark: isDark,
                            onTap: () => svc.selectedIndex = 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}