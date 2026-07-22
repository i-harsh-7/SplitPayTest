import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import 'auth_service.dart';

class GetBillsService {
  static const _base = ApiConfig.baseUrl;

  /// Get all bill assignments for the current user (optionally for a specific group if backend adds filtering)
  static Future<List<Map<String, dynamic>>> getAssignmentsForGroup() async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$_base/bills/getAssignments');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        if (parsed is Map<String, dynamic> && parsed['success'] == true && parsed['allAssigments'] is List) {
          // allAssignments/Assigments spelling is as per backend response
          return List<Map<String, dynamic>>.from(parsed['allAssigments']);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Get all bills for a group
  static Future<List<Map<String, dynamic>>> getAllBills({required String groupId}) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$_base/bills/getAllBills').replace(queryParameters: {
      'group': groupId,
    });
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    // No body for GET; pass groupId as query parameter

    try {
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        // Uncomment to view full body if needed
        final parsed = jsonDecode(res.body);
        if (parsed is Map<String, dynamic> && parsed['success'] == true && parsed['bills'] is List) {
          final list = List<Map<String, dynamic>>.from(parsed['bills']);
          return list;
        } else {
        }
      } else {
      }
    } catch (_) {}
    return [];
  }
}
