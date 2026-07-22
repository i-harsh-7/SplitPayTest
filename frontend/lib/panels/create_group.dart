import 'package:flutter/material.dart';
import '../components/header.dart';
import '../models/group_model.dart';
import 'package:provider/provider.dart';
import '../services/group_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../themes/app_theme.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController = TextEditingController();

  bool _isCreating = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateGroup() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in the group name'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final newGroup = GroupModel(
        name: _groupNameController.text.trim(),
        members: 1,
        status: GroupStatus.settled,
        amount: 0,
        avatars: ['https://i.pravatar.cc/150?img=12'],
        icon: Icons.group,
        description: _groupDescriptionController.text.trim(),
      );

      final serverGroup = await _createGroupInBackend(newGroup);

      try {
        final svc = Provider.of<GroupService>(context, listen: false);
        
        // Refresh groups from backend to get the latest data
        await svc.fetchGroups();
        
        // Switch to Groups tab (index 1)
        svc.selectedIndex = 1;
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group "${newGroup.name}" created successfully!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );

      _groupNameController.clear();
      _groupDescriptionController.clear();

      setState(() => _isCreating = false);

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating group: ${e.toString()}'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() => _isCreating = false);
    }
  }

  Future<GroupModel?> _createGroupInBackend(GroupModel group) async {
    const base = ApiConfig.baseUrl;
    final uri = Uri.parse('$base/group/create');

    final token = await AuthService.getToken();
    
    // ✅ FIX: Get the current user's ID to add them as a member
    final currentUser = await AuthService.getProfile();
    if (currentUser == null) {
      throw Exception('Could not get current user profile');
    }

    // Get user ID from backend
    String? currentUserId;
    try {
      final userDetailsUri = Uri.parse('$base/getUserDetails');
      final userRes = await http.get(
        userDetailsUri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (userRes.statusCode == 200) {
        final userParsed = jsonDecode(userRes.body);
        // Backend returns: { success: true, user: { _id: "...", ... } }
        if (userParsed['success'] == true && userParsed['user'] != null) {
          currentUserId = userParsed['user']['_id']?.toString();
        }
      }
    } catch (e) {
      print('Error fetching user details: $e');
    }

    if (currentUserId == null || currentUserId.isEmpty) {
      throw Exception('Could not get current user ID');
    }

    print('✅ Creating group with creator ID: $currentUserId');

    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    // ✅ FIX: Include the creator as a member
    final body = jsonEncode({
      'name': group.name,
      'description': _groupDescriptionController.text.trim(),
      'members': [currentUserId], // Add creator as first member
    });

    print('📤 Creating group with body: $body');

    try {
      final res = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));

      print('📡 Create group status: ${res.statusCode}');
      print('📡 Create group response: ${res.body}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        final Map<String, dynamic> parsed = jsonDecode(res.body);
        final Map<String, dynamic>? g = parsed['group'] is Map<String, dynamic>
            ? parsed['group'] as Map<String, dynamic>
            : (parsed['data'] is Map && parsed['data']['group'] is Map)
                ? parsed['data']['group'] as Map<String, dynamic>
                : null;

        if (g != null) {
          final membersField = g['members'];
          int membersCount = 1;
          List<String> avatars = [];
          if (membersField is List) {
            membersCount = membersField.length;
            try {
              for (final m in membersField) {
                if (m is Map && (m['email'] is String)) {
                  final email = m['email'] as String;
                  final id = (email.hashCode.abs() % 70) + 1;
                  avatars.add('https://i.pravatar.cc/150?img=$id');
                }
              }
            } catch (_) {}
          }

          final created = GroupModel(
            id: g['_id']?.toString() ?? g['id']?.toString(),
            name: g['name']?.toString() ?? group.name,
            members: membersCount,
            status: GroupStatus.settled,
            amount: 0,
            avatars: avatars,
            icon: Icons.group,
            description: g['description']?.toString() ?? group.description,
          );
          
          print('✅ Group created successfully with ID: ${created.id}');
          return created;
        }
        return null;
      } else {
        print('Create group failed: ${res.statusCode} ${res.body}');
        return null;
      }
    } catch (e) {
      print('Error creating group: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final backgroundColor = theme.scaffoldBackgroundColor;

    final media = MediaQuery.of(context);
    final safeBottom = media.viewPadding.bottom;
    final keyboardBottom = media.viewInsets.bottom;
    final extraBottomPadding = (safeBottom + 16.0);

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          const Header(
            title: "Create Group",
            heightFactor: 0.12,
          ),
          Expanded(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardBottom > 0 ? keyboardBottom : 0),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 16, 20, extraBottomPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      Text(
                        "Group Name",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _groupNameController,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: "Enter group name",
                          hintStyle: TextStyle(
                            color: textColor.withOpacity(0.5),
                          ),
                          filled: true,
                          fillColor: cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.danger,
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.danger,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a group name';
                          }
                          if (value.trim().length < 3) {
                            return 'Group name must be at least 3 characters';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),

                      const SizedBox(height: 24),

                      Text(
                        "Description",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _groupDescriptionController,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                        ),
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: "Enter group description (optional)",
                          hintStyle: TextStyle(
                            color: textColor.withOpacity(0.5),
                          ),
                          filled: true,
                          fillColor: cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                      ),

                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isCreating ? null : _handleCreateGroup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            disabledBackgroundColor: primaryColor.withOpacity(0.6),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white70,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isCreating
                              ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                              : const Text(
                            "Create",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
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
}