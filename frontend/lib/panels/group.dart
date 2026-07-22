import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/header.dart';
import '../models/group_model.dart';
import '../screens/group_details.dart';
import '../services/group_service.dart';
import '../services/auth_service.dart';

class GroupsPanel extends StatelessWidget {
  const GroupsPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final cardColor = theme.cardColor;
    final background = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: background,
      body: Column(
        children: [
          const Header(title: "Groups"),
          Expanded(
            child: Consumer<GroupService>(
              builder: (context, svc, _) {
                final groups = svc.groups;
                return groups.isEmpty
                    ? const _NoGroupsView()
                    : Padding(
                        padding: const EdgeInsets.all(18),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Your Groups",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...groups.map((g) => _GroupCard(
                                    group: g,
                                    cardColor: cardColor,
                                    textColor: textColor,
                                  )),
                            ],
                          ),
                        ),
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- Group Card ---
class _GroupCard extends StatefulWidget {
  final GroupModel group;
  final Color cardColor;
  final Color textColor;

  const _GroupCard({
    required this.group,
    required this.cardColor,
    required this.textColor,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _isHovered = false;
  bool _isAdmin = false;
  bool _isCheckingAdmin = true;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  // Check if the current user is the admin of this group
  Future<void> _checkAdminStatus() async {
    // Prevent errors if widget is disposed
    if (!mounted) return;

    try {
      final currentUser = await AuthService.getProfile();
      if (currentUser != null && widget.group.id != null) {
        final groupService = Provider.of<GroupService>(context, listen: false);
        final groupData = await groupService.fetchGroupDetails(widget.group.id!);

        if (groupData != null && mounted) {
          final createdByField = groupData['createdBy'];
          String? adminEmail;

          if (createdByField is Map) {
            adminEmail = createdByField['email']?.toString();
          } else if (createdByField is String) {
            // Fallback if the field is just an email string
            adminEmail = createdByField;
          }

          setState(() {
            _isAdmin = (adminEmail != null && adminEmail == currentUser.email);
            _isCheckingAdmin = false;
          });
        } else if (mounted) {
          setState(() => _isCheckingAdmin = false);
        }
      } else if (mounted) {
        setState(() => _isCheckingAdmin = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingAdmin = false);
      }
    }
  }

  // Show confirmation dialog *before* deleting
  void _showDeleteDialog() {
    // This check is correct. It shows a snackbar for non-admins.
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.lock, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Only admin can delete the group')),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // If admin, show the confirmation dialog
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Delete Group'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${widget.group.name}"? This action cannot be undone and will remove all group data.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: theme.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteGroup();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Handle the actual deletion process
  Future<void> _deleteGroup() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
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
              Text('Deleting group...'),
            ],
          ),
        ),
      ),
    );

    try {
      final groupService = Provider.of<GroupService>(context, listen: false);
      // This service call uses the correct API endpoint
      final success = await groupService.deleteGroup(widget.group.id!);

      Navigator.of(context).pop(); // Close loading indicator

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Group deleted successfully')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to delete group')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        if (group.id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailsPage(groupId: group.id!),
            ),
          );
        }
      },
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapCancel: () => setState(() => _isHovered = false),
      onTapUp: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Hero(
                tag: 'group_avatar_${group.id}',
                child: _GroupAvatar(
                  groupName: group.name,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.textColor,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // --- MODIFICATION START ---
              // Show button after check, but change color based on admin status
              if (!_isCheckingAdmin)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    // Set color based on admin status
                    color: _isAdmin ? Colors.red.withOpacity(0.8) : Colors.grey,
                    size: 24,
                  ),
                  // _showDeleteDialog handles the non-admin click
                  onPressed: _showDeleteDialog,
                  tooltip: 'Delete Group',
                  splashRadius: 24,
                ),
              // --- MODIFICATION END ---
            ],
          ),
        ),
      ),
    );
  }
}

// --- Enhanced Group Avatar with EXTENSIVE ICON LIBRARY ---
class _GroupAvatar extends StatelessWidget {
  final String groupName;

  const _GroupAvatar({required this.groupName});

  // Comprehensive icon selection with 100+ patterns
  IconData _getIconForGroup(String name) {
    final lowerName = name.toLowerCase();

    // 🍽️ Food & Dining (Extended)
    if (lowerName.contains('dinner') || lowerName.contains('lunch') ||
        lowerName.contains('breakfast') || lowerName.contains('meal') ||
        lowerName.contains('restaurant') || lowerName.contains('dine'))
      return Icons.restaurant_rounded;

    if (lowerName.contains('coffee') || lowerName.contains('cafe') ||
        lowerName.contains('tea') || lowerName.contains('starbucks'))
      return Icons.coffee_rounded;

    if (lowerName.contains('pizza') || lowerName.contains('burger') ||
        lowerName.contains('fast food') || lowerName.contains('snack'))
      return Icons.fastfood_rounded;

    if (lowerName.contains('bar') || lowerName.contains('drink') ||
        lowerName.contains('beer') || lowerName.contains('wine') ||
        lowerName.contains('pub') || lowerName.contains('cocktail'))
      return Icons.local_bar_rounded;

    if (lowerName.contains('cake') || lowerName.contains('dessert') ||
        lowerName.contains('sweet') || lowerName.contains('bakery') ||
        lowerName.contains('ice cream'))
      return Icons.cake_rounded;

    if (lowerName.contains('brunch') || lowerName.contains('breakfast'))
      return Icons.brunch_dining_rounded;

    if (lowerName.contains('ramen') || lowerName.contains('noodle') ||
        lowerName.contains('soup'))
      return Icons.ramen_dining_rounded;

    // ✈️ Travel & Places (Extended)
    if (lowerName.contains('trip') || lowerName.contains('travel') ||
        lowerName.contains('vacation') || lowerName.contains('holiday') ||
        lowerName.contains('tour'))
      return Icons.flight_takeoff_rounded;

    if (lowerName.contains('beach') || lowerName.contains('sea') ||
        lowerName.contains('ocean') || lowerName.contains('coast'))
      return Icons.beach_access_rounded;

    if (lowerName.contains('hotel') || lowerName.contains('stay') ||
        lowerName.contains('resort') || lowerName.contains('accommodation'))
      return Icons.hotel_rounded;

    if (lowerName.contains('camping') || lowerName.contains('camp') ||
        lowerName.contains('tent') || lowerName.contains('outdoor'))
      return Icons.hiking_rounded;

    if (lowerName.contains('mountain') || lowerName.contains('hiking') ||
        lowerName.contains('trek'))
      return Icons.terrain_rounded;

    if (lowerName.contains('road trip') || lowerName.contains('drive') ||
        lowerName.contains('car rental'))
      return Icons.directions_car_rounded;

    if (lowerName.contains('cruise') || lowerName.contains('boat') ||
        lowerName.contains('sailing'))
      return Icons.directions_boat_rounded;

    // 🏠 Home & Living (Extended)
    if (lowerName.contains('home') || lowerName.contains('house') ||
        lowerName.contains('apartment'))
      return Icons.home_rounded;

    if (lowerName.contains('rent') || lowerName.contains('lease') ||
        lowerName.contains('utilities'))
      return Icons.house_rounded;

    if (lowerName.contains('roommate') || lowerName.contains('flatmate') ||
        lowerName.contains('shared'))
      return Icons.apartment_rounded;

    if (lowerName.contains('furniture') || lowerName.contains('ikea') ||
        lowerName.contains('decor'))
      return Icons.chair_rounded;

    if (lowerName.contains('garden') || lowerName.contains('plant') ||
        lowerName.contains('yard'))
      return Icons.yard_rounded;

    // 🎬 Entertainment (Extended)
    if (lowerName.contains('movie') || lowerName.contains('film') ||
        lowerName.contains('cinema') || lowerName.contains('netflix'))
      return Icons.movie_creation_rounded;

    if (lowerName.contains('music') || lowerName.contains('concert') ||
        lowerName.contains('festival') || lowerName.contains('spotify'))
      return Icons.music_note_rounded;

    if (lowerName.contains('game') || lowerName.contains('gaming') ||
        lowerName.contains('esport') || lowerName.contains('xbox') ||
        lowerName.contains('playstation'))
      return Icons.sports_esports_rounded;

    if (lowerName.contains('party') || lowerName.contains('celebrate') ||
        lowerName.contains('birthday') || lowerName.contains('anniversary'))
      return Icons.celebration_rounded;

    if (lowerName.contains('theater') || lowerName.contains('drama') ||
        lowerName.contains('show') || lowerName.contains('broadway'))
      return Icons.theater_comedy_rounded;

    if (lowerName.contains('night') || lowerName.contains('club') ||
        lowerName.contains('disco'))
      return Icons.nightlife_rounded;

    if (lowerName.contains('karaoke') || lowerName.contains('sing'))
      return Icons.mic_rounded;

    if (lowerName.contains('book') || lowerName.contains('reading') ||
        lowerName.contains('library'))
      return Icons.menu_book_rounded;

    // 🛍️ Shopping (Extended)
    if (lowerName.contains('shop') || lowerName.contains('shopping') ||
        lowerName.contains('buy') || lowerName.contains('mall'))
      return Icons.shopping_bag_rounded;

    if (lowerName.contains('grocery') || lowerName.contains('supermarket') ||
        lowerName.contains('market') || lowerName.contains('costco') ||
        lowerName.contains('walmart'))
      return Icons.shopping_cart_rounded;

    if (lowerName.contains('gift') || lowerName.contains('present') ||
        lowerName.contains('surprise'))
      return Icons.card_giftcard_rounded;

    if (lowerName.contains('fashion') || lowerName.contains('clothes') ||
        lowerName.contains('outfit'))
      return Icons.checkroom_rounded;

    // ⚽ Sports & Fitness (Extended)
    if (lowerName.contains('soccer') || lowerName.contains('football'))
      return Icons.sports_soccer_rounded;

    if (lowerName.contains('basketball') || lowerName.contains('nba'))
      return Icons.sports_basketball_rounded;

    if (lowerName.contains('gym') || lowerName.contains('fitness') ||
        lowerName.contains('workout') || lowerName.contains('exercise'))
      return Icons.fitness_center_rounded;

    if (lowerName.contains('tennis') || lowerName.contains('badminton'))
      return Icons.sports_tennis_rounded;

    if (lowerName.contains('golf'))
      return Icons.golf_course_rounded;

    if (lowerName.contains('swim') || lowerName.contains('pool'))
      return Icons.pool_rounded;

    if (lowerName.contains('yoga') || lowerName.contains('meditation') ||
        lowerName.contains('pilates'))
      return Icons.self_improvement_rounded;

    if (lowerName.contains('run') || lowerName.contains('marathon') ||
        lowerName.contains('jog'))
      return Icons.directions_run_rounded;

    if (lowerName.contains('bike') || lowerName.contains('cycling'))
      return Icons.directions_bike_rounded;

    // 💼 Work & Education (Extended)
    if (lowerName.contains('school') || lowerName.contains('class') ||
        lowerName.contains('study') || lowerName.contains('student'))
      return Icons.school_rounded;

    if (lowerName.contains('work') || lowerName.contains('office') ||
        lowerName.contains('business') || lowerName.contains('company') ||
        lowerName.contains('project'))
      return Icons.business_center_rounded;

    if (lowerName.contains('meeting') || lowerName.contains('conference') ||
        lowerName.contains('zoom'))
      return Icons.groups_rounded;

    if (lowerName.contains('presentation') || lowerName.contains('pitch'))
      return Icons.present_to_all_rounded;

    // 🏥 Health & Wellness (Extended)
    if (lowerName.contains('medical') || lowerName.contains('doctor') ||
        lowerName.contains('hospital') || lowerName.contains('health'))
      return Icons.local_hospital_rounded;

    if (lowerName.contains('pharmacy') || lowerName.contains('medicine') ||
        lowerName.contains('drug'))
      return Icons.local_pharmacy_rounded;

    if (lowerName.contains('spa') || lowerName.contains('wellness') ||
        lowerName.contains('massage') || lowerName.contains('salon'))
      return Icons.spa_rounded;

    if (lowerName.contains('pet') || lowerName.contains('dog') ||
        lowerName.contains('cat') || lowerName.contains('vet'))
      return Icons.pets_rounded;

    // 👨‍👩‍👧‍👦 Family & Friends (Extended)
    if (lowerName.contains('family') || lowerName.contains('parent') ||
        lowerName.contains('kid') || lowerName.contains('children'))
      return Icons.family_restroom_rounded;

    if (lowerName.contains('friend') || lowerName.contains('buddy') ||
        lowerName.contains('squad') || lowerName.contains('crew'))
      return Icons.groups_rounded;

    if (lowerName.contains('love') || lowerName.contains('couple') ||
        lowerName.contains('date') || lowerName.contains('romance'))
      return Icons.favorite_rounded;

    if (lowerName.contains('wedding') || lowerName.contains('marriage') ||
        lowerName.contains('bride') || lowerName.contains('groom'))
      return Icons.cake_rounded;

    if (lowerName.contains('baby') || lowerName.contains('infant') ||
        lowerName.contains('newborn'))
      return Icons.child_care_rounded;

    // 🚗 Transportation (Extended)
    if (lowerName.contains('uber') || lowerName.contains('lyft') ||
        lowerName.contains('taxi') || lowerName.contains('ride'))
      return Icons.local_taxi_rounded;

    if (lowerName.contains('gas') || lowerName.contains('fuel') ||
        lowerName.contains('petrol'))
      return Icons.local_gas_station_rounded;

    if (lowerName.contains('parking') || lowerName.contains('garage'))
      return Icons.local_parking_rounded;

    if (lowerName.contains('train') || lowerName.contains('subway') ||
        lowerName.contains('metro'))
      return Icons.train_rounded;

    if (lowerName.contains('bus'))
      return Icons.directions_bus_rounded;

    // 💰 Finance (Extended)
    if (lowerName.contains('bank') || lowerName.contains('atm') ||
        lowerName.contains('finance'))
      return Icons.account_balance_rounded;

    if (lowerName.contains('invest') || lowerName.contains('stock') ||
        lowerName.contains('trading'))
      return Icons.trending_up_rounded;

    if (lowerName.contains('bill') || lowerName.contains('payment') ||
        lowerName.contains('expense'))
      return Icons.receipt_long_rounded;

    if (lowerName.contains('saving') || lowerName.contains('piggy'))
      return Icons.savings_rounded;

    // 🎨 Creative & Hobbies (Extended)
    if (lowerName.contains('art') || lowerName.contains('paint') ||
        lowerName.contains('draw') || lowerName.contains('craft'))
      return Icons.palette_rounded;

    if (lowerName.contains('photo') || lowerName.contains('camera') ||
        lowerName.contains('instagram'))
      return Icons.camera_alt_rounded;

    if (lowerName.contains('cooking') || lowerName.contains('recipe') ||
        lowerName.contains('chef'))
      return Icons.restaurant_menu_rounded;

    if (lowerName.contains('volunteer') || lowerName.contains('charity') ||
        lowerName.contains('donation'))
      return Icons.volunteer_activism_rounded;

    // 📱 Technology (Extended)
    if (lowerName.contains('tech') || lowerName.contains('gadget') ||
        lowerName.contains('electronics'))
      return Icons.devices_rounded;

    if (lowerName.contains('internet') || lowerName.contains('wifi') ||
        lowerName.contains('network'))
      return Icons.wifi_rounded;

    if (lowerName.contains('subscription') || lowerName.contains('netflix') ||
        lowerName.contains('spotify') || lowerName.contains('streaming'))
      return Icons.subscriptions_rounded;

    // 🎓 Special Events
    if (lowerName.contains('graduation') || lowerName.contains('ceremony'))
      return Icons.school_rounded;

    if (lowerName.contains('christmas') || lowerName.contains('holiday'))
      return Icons.celebration_rounded;

    if (lowerName.contains('halloween'))
      return Icons.nightlight_rounded;

    if (lowerName.contains('new year') || lowerName.contains('nye'))
      return Icons.celebration_rounded;

    // Default: Premium, visually appealing icons
    final genericIcons = [
      Icons.rocket_launch_rounded,
      Icons.auto_awesome_rounded,
      Icons.bubble_chart_rounded,
      Icons.palette_rounded,
      Icons.psychology_rounded,
      Icons.emoji_emotions_rounded,
      Icons.lightbulb_rounded,
      Icons.hub_rounded,
      Icons.diamond_rounded,
      Icons.stars_rounded,
      Icons.favorite_border_rounded,
      Icons.celebration_rounded,
      Icons.local_fire_department_rounded,
      Icons.bolt_rounded,
      Icons.emoji_objects_rounded,
      Icons.eco_rounded,
    ];
    final index = name.hashCode.abs() % genericIcons.length;
    return genericIcons[index];
  }

  // VIBRANT, MODERN GRADIENT COLORS - Enhanced palette
  List<Color> _getColorsForGroup(String name) {
    final colorSets = [
      // Vibrant Purple & Lavender
      [Color(0xFF9575CD), Color(0xFF7E57C2)],

      // Hot Pink & Rose
      [Color(0xFFEF5DA8), Color(0xFFF48FB1)],

      // Ocean Teal & Turquoise
      [Color(0xFF4DB6AC), Color(0xFF26A69A)],

      // Sky Blue & Azure
      [Color(0xFF5DADE2), Color(0xFF42A5F5)],

      // Coral & Salmon
      [Color(0xFFFF7961), Color(0xFFFF8A80)],

      // Royal Indigo & Violet
      [Color(0xFF7986CB), Color(0xFF5C6BC0)],

      // Bright Cyan & Aqua
      [Color(0xFF4DD0E1), Color(0xFF26C6DA)],

      // Golden Amber & Honey
      [Color(0xFFFFB74D), Color(0xFFFFA726)],

      // Magenta & Pink
      [Color(0xFFF06292), Color(0xFFEC407A)],

      // Fresh Green & Mint
      [Color(0xFF66BB6A), Color(0xFF4DB6AC)],

      // Steel Blue-Grey
      [Color(0xFF78909C), Color(0xFF607D8B)],

      // Peach & Orange
      [Color(0xFFFF9E80), Color(0xFFFFAB91)],

      // Deep Purple & Plum
      [Color(0xFFBA68C8), Color(0xFFAB47BC)],

      // Lime & Chartreuse
      [Color(0xFF9CCC65), Color(0xFF8BC34A)],



      // Ruby & Crimson
      [Color(0xFFE57373), Color(0xFFEF5350)],

      // Sapphire & Navy
      [Color(0xFF64B5F6), Color(0xFF42A5F5)],
    ];
    final index = name.hashCode.abs() % colorSets.length;
    return colorSets[index];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getColorsForGroup(groupName);
    final displayIcon = _getIconForGroup(groupName);

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.35),
            blurRadius: 10,
            offset: Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [Colors.white.withOpacity(0.95), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Icon(
          displayIcon,
          size: 26,
          color: Colors.white,
        ),
      ),
    );
  }
}

// --- Empty State View ---
class _NoGroupsView extends StatelessWidget {
  const _NoGroupsView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 80,
              color: isDark ? Colors.white24 : Colors.grey[400],
            ),
            const SizedBox(height: 28),
            Text(
              "You're not in any group yet!",
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Create or join a group to start splitting expenses.",
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}