import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'group_service.dart';

class DeleteBillService {
  static const _base = ApiConfig.baseUrl;

  /// Delete a bill by expenseId using DELETE /bills/deleteBill with JSON body
  /// If [context] and [groupId] are provided, updates local GroupService cache on success
  static Future<Map<String, dynamic>> deleteBill({
    required String expenseId,
    BuildContext? context,
    String? groupId,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$_base/bills/deleteBill');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({'expenseId': expenseId});

    try {
      final res = await http
          .delete(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 12));

      final ok = res.statusCode == 200 || res.statusCode == 204;
      Map<String, dynamic> parsed = {};
      if (res.body.isNotEmpty) {
        try {
          parsed = jsonDecode(res.body);
        } catch (_) {}
      }

      final success = ok || (parsed['success'] == true);

      if (success && context != null && groupId != null && groupId.isNotEmpty) {
        try {
          final groupService = Provider.of<GroupService>(context, listen: false);
          groupService.removeExpenseFromGroup(groupId, expenseId);
        } catch (_) {}
      }

      return {
        'success': success,
        'message': parsed['message'] ?? (success ? 'Deleted' : 'Failed to delete'),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}


