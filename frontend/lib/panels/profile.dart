import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../screens/about_us.dart';
import '../screens/edit_profile.dart';
import '../screens/change_password.dart';
import '../components/initial_avatar.dart';

class ProfilePanel extends StatefulWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onBackToHome;

  const ProfilePanel({
    Key? key,
    this.onLogout,
    this.onBackToHome,
  }) : super(key: key);

  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfilePanel> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  String? _name;
  String? _email;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await AuthService.getProfile();
      if (user != null) {
        setState(() {
          _name = user.name;
          _email = user.email.isNotEmpty ? user.email : null;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    final media = MediaQuery.of(context);
    final size = media.size;
    final textScale = media.textScaler.scale(1.0);

    final double maxScroll = (size.height * 0.24).clamp(140.0, 240.0);
    final double progress = (_scrollOffset / maxScroll).clamp(0.0, 1.0);

    final double expandedHeaderHeight = (size.height * 0.38).clamp(240.0, 320.0);
    final double collapsedHeaderHeight = (size.height * 0.14).clamp(90.0, 130.0);

    final double largePhotoSize = (size.width * 0.42).clamp(140.0, 220.0);
    final double smallPhotoSize = (size.width * 0.18).clamp(60.0, 85.0);
    final double photoSize = largePhotoSize - (progress * (largePhotoSize - smallPhotoSize));

    final double photoCutPercentage = 0.25;
    final double expandedPhotoLeft = -(photoSize * photoCutPercentage);
    final double collapsedPhotoLeft = (size.width * 0.25).clamp(80.0, 120.0);
    final double photoLeftPosition = expandedPhotoLeft + (progress * (collapsedPhotoLeft - expandedPhotoLeft));

    final double expandedPhotoTop = (size.height * 0.08).clamp(50.0, 80.0);
    final double collapsedPhotoTop = (size.height * 0.015).clamp(10.0, 20.0);
    final double photoTopPosition = expandedPhotoTop - (progress * (expandedPhotoTop - collapsedPhotoTop));

    final double expandedTextLeft = photoLeftPosition + photoSize + 20;
    final double collapsedTextLeft = collapsedPhotoLeft + smallPhotoSize + 15;
    final double textLeftPosition = expandedTextLeft + (progress * (collapsedTextLeft - expandedTextLeft));

    final double expandedTextTop = expandedPhotoTop + (photoSize / 2) - 25;
    final double collapsedTextTop = collapsedPhotoTop + (smallPhotoSize / 2) - 10;
    final double textTopPosition = expandedTextTop - (progress * (expandedTextTop - collapsedTextTop));

    final double nameSize = ((size.width * 0.06) - (progress * 6.0)).clamp(16.0, 26.0) * textScale;
    final double emailSize = ((size.width * 0.037) - (progress * 2.0)).clamp(12.0, 16.0) * textScale;

    final double borderRadius = ((size.width * 0.14) - (progress * 10.0)).clamp(40.0, 60.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: WillPopScope(
        onWillPop: () async {
          if (widget.onBackToHome != null) {
            widget.onBackToHome!();
            return false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _ProfileHeaderDelegate(
                  minHeight: collapsedHeaderHeight,
                  maxHeight: expandedHeaderHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(borderRadius),
                              bottomRight: Radius.circular(borderRadius),
                            ),
                          ),
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + photoTopPosition,
                        left: photoLeftPosition,
                        child: Container(
                          width: photoSize,
                          height: photoSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: InitialAvatar(name: _name ?? 'User', radius: photoSize / 2 - 6),
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + textTopPosition,
                        left: textLeftPosition,
                        right: 24,
                        child: Column(
                          crossAxisAlignment: progress > 0.5
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _name ?? 'User',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: nameSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: progress > 0.5 ? 1 : 2),
                            Text(
                              _email ?? '',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: emailSize,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.only(top: 12, left: 18, right: 18, bottom: 100),
                    child: Column(
                      children: [
                        _buildSettingCard(
                          icon: Icons.edit_outlined,
                          title: 'Edit Profile',
                          subtitle: 'Update your personal information',
                          cardColor: cardColor,
                          textColor: textColor,
                          iconColor: primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EditProfilePage()),
                          ),
                        ),
                        _buildSettingCard(
                          icon: Icons.lock_outline,
                          title: 'Change Password',
                          subtitle: 'Update your account security',
                          cardColor: cardColor,
                          textColor: textColor,
                          iconColor: primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChangePasswordPage(onPasswordChanged: widget.onLogout),
                            ),
                          ),
                        ),
                        _buildSettingCard(
                          icon: Icons.info_outline,
                          title: 'About Us',
                          subtitle: 'Learn more about our app',
                          cardColor: cardColor,
                          textColor: textColor,
                          iconColor: primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AboutUsPage()),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: widget.onLogout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Logout',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardColor,
    required Color textColor,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 26),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: textColor.withOpacity(0.65),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (iconColor != Colors.red)
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.withOpacity(0.4),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _ProfileHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_ProfileHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
