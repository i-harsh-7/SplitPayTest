import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../models/group_model.dart';
import 'auth_service.dart';
import 'get_bills.dart';
import 'dart:math';

IconData _getRandomGroupIcon() {
  final random = Random();
  final icons = [
    Icons.people,
    Icons.group,
    Icons.groups,
    Icons.family_restroom,
    Icons.emoji_people,
    Icons.restaurant,
    Icons.local_cafe,
    Icons.fastfood,
    Icons.nightlife,
    Icons.sports_bar,
    Icons.flight,
    Icons.beach_access,
    Icons.hotel,
    Icons.home,
    Icons.apartment,
    Icons.business,
    Icons.school,
    Icons.sports_soccer,
    Icons.sports_basketball,
    Icons.sports_esports,
    Icons.movie,
    Icons.theater_comedy,
    Icons.music_note,
    Icons.celebration,
    Icons.cake,
    Icons.card_giftcard,
    Icons.favorite,
    Icons.shopping_bag,
    Icons.shopping_cart,
  ];
  return icons[random.nextInt(icons.length)];
}

class GroupService extends ChangeNotifier {
  final List<GroupModel> _groups = [];
  final Map<String, List<Map<String, dynamic>>> _groupExpenses = {};
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  set selectedIndex(int v) {
    if (_selectedIndex == v) return;
    _selectedIndex = v;
    notifyListeners();
  }

  List<GroupModel> get groups => List.unmodifiable(_groups);

  void addGroup(GroupModel group) {
    _groups.insert(0, group);
    notifyListeners();
  }

  void addExpenseToGroup(String groupId, Map<String, dynamic> expense) {
    if (!_groupExpenses.containsKey(groupId)) {
      _groupExpenses[groupId] = [];
    }
    _groupExpenses[groupId]!.insert(0, expense);
    notifyListeners();
  }

  List<Map<String, dynamic>> getGroupExpenses(String groupId) {
    return _groupExpenses[groupId] ?? [];
  }

  // Write the full bill list for a group into the cache (called by GroupDetailsPage after fetch)
  void setGroupBills(String groupId, List<Map<String, dynamic>> bills) {
    _groupExpenses[groupId] = bills;
    notifyListeners();
  }

  void removeExpenseFromGroup(String groupId, String expenseId) {
    final list = _groupExpenses[groupId];
    if (list == null) return;
    _groupExpenses[groupId] = list
        .where((e) => (e['_id']?.toString() ?? e['id']?.toString() ?? '') != expenseId)
        .toList();
    notifyListeners();
  }

  void clearGroups() {
    _groups.clear();
    _groupExpenses.clear();
    _selectedIndex = 0;
    notifyListeners();
  }

  void addSampleData() {
    return;
  }

  Future<void> fetchGroups() async {
    const base = ApiConfig.baseUrl;
    final token = await AuthService.getToken();

    if (token == null) {
      _groups.clear();
      notifyListeners();
      return;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final uri = Uri.parse('$base/group/getAll');
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        List<dynamic>? arr;

        if (parsed is Map && parsed['success'] == true) {
          if (parsed['groups'] is List) arr = parsed['groups'];
        } else if (parsed is List) {
          arr = parsed;
        } else if (parsed is Map) {
          if (parsed['data'] is List) arr = parsed['data'];
          else if (parsed['data'] is Map && parsed['data']['groups'] is List) arr = parsed['data']['groups'];
        }

        if (arr != null) {
          // Clear only on success, before repopulating — stale data stays on error
          _groups.clear();
          for (final item in arr) {
            try {
              final Map<String, dynamic> g = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
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

              _groups.add(GroupModel(
                id: g['_id']?.toString() ?? g['id']?.toString(),
                name: g['name']?.toString() ?? 'Group',
                members: membersCount,
                status: GroupStatus.settled,
                amount: 0,
                avatars: avatars,
                description: g['description']?.toString(),
              ));
            } catch (_) {}
          }
          notifyListeners();
          return;
        }
      } else if (res.statusCode == 400) {
        // User is not in any group — clear and return normally
        _groups.clear();
        notifyListeners();
        return;
      }
      // Any other non-200 status: leave existing list intact, don't clear
    } catch (e) {
      print('Error fetching groups: $e');
      // Network error — leave existing list intact
    }
  }

  // Fetch bills for all groups in parallel and populate the expenses cache
  Future<void> fetchAllBills() async {
    if (_groups.isEmpty) return;
    await Future.wait(
      _groups
          .where((g) => g.id != null)
          .map((g) async {
            try {
              final bills = await GetBillsService.getAllBills(groupId: g.id!);
              _groupExpenses[g.id!] = bills;
            } catch (_) {}
          })
          .toList(),
    );
    notifyListeners();
  }

  Future<bool> deleteGroup(String groupId) async {
    const base = ApiConfig.baseUrl;
    final token = await AuthService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final uri = Uri.parse('$base/group/delete/$groupId');
      final res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 204) {
        _groups.removeWhere((g) => g.id == groupId);
        _groupExpenses.remove(groupId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Error deleting group: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>?> fetchGroupDetails(String groupId) async {
    const base = ApiConfig.baseUrl;
    final token = await AuthService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final uri = Uri.parse('$base/group/get/$groupId');
      print('📥 Fetching group from: $uri');

      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      print('📡 Status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');

      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);

        print('📦 Parsed structure:');
        print('   Keys: ${parsed.keys}');
        if (parsed['group'] != null) {
          print('   group.members type: ${parsed['group']['members'].runtimeType}');
          print('   group.members: ${parsed['group']['members']}');
        }

        if (parsed is Map<String, dynamic>) {
          if (parsed['group'] is Map<String, dynamic>) {
            return parsed['group'] as Map<String, dynamic>;
          } else if (parsed['data'] is Map<String, dynamic>) {
            return parsed['data'] as Map<String, dynamic>;
          }
          return parsed;
        }
      }
    } catch (e) {
      print('❌ Error: $e');
    }
    return null;
  }
}
