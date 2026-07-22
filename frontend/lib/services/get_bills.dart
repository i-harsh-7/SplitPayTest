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
    } catch (e) {
      print('❌ Error fetching assignments: $e');
    }
    return [];
  }

  /// Get all bills for a group
  static Future<List<Map<String, dynamic>>> getAllBills({required String groupId}) async {
    print('🚀 getAllBills(groupId: $groupId) invoked');
    final token = await AuthService.getToken();
    if (token == null) {
      print('❌ getAllBills: No auth token found');
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
      print('🌐 GET $uri');
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      print('📡 getAllBills status: ${res.statusCode}');
      if (res.statusCode == 200) {
        print('✅ Bills fetched successfully');
        print('📦 Raw body length: ${res.body.length}');
        // Uncomment to view full body if needed
        print('📡 Bills response: ${res.body}');
        final parsed = jsonDecode(res.body);
        if (parsed is Map<String, dynamic> && parsed['success'] == true && parsed['bills'] is List) {
          final list = List<Map<String, dynamic>>.from(parsed['bills']);
          print('🔢 getAllBills: parsed bills count = ${list.length}');
          return list;
        } else {
          print('⚠️ getAllBills: Unexpected response shape: $parsed');
        }
      } else {
        print('⚠️ getAllBills non-200. Body: ${res.body}');
      }
    } catch (e) {
      print('❌ Error fetching bills: $e');
    }
    print('ℹ️ getAllBills returning empty list');
    return [];
  }
}
