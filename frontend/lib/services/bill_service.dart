import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../config/api_config.dart';
import 'auth_service.dart';

class BillService {
  static const _base = ApiConfig.baseUrl;

  /// URI for an expense's receipt image/PDF. Not a public static file — the endpoint is
  /// group-membership gated, so requests must include the Authorization header (see
  /// [receiptImageHeaders]).
  static Uri receiptImageUri(String expenseId) => Uri.parse('$_base/bills/$expenseId/image');

  /// Auth header to attach to a receipt-image request (e.g. `Image.network(uri, headers: ...)`).
  static Future<Map<String, String>> receiptImageHeaders() async {
    final token = await AuthService.getToken();
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }

  /// Upload a bill image
  static Future<Map<String, dynamic>> uploadBill({
    required File imageFile,
    required String groupId,
    required String billName,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      final uri = Uri.parse('$_base/bills/upload');
      var request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['groupId'] = groupId;
      request.fields['billName'] = billName;

      // Add the image file - field name must match backend expectation
      request.files.add(
        await http.MultipartFile.fromPath(
          'bill', // Backend expects 'bill' field name
          imageFile.path,
        ),
      );


      final streamedResponse = await request.send()
          .timeout(const Duration(seconds: 45)); // Increased timeout for parsing
      final response = await http.Response.fromStream(streamedResponse);


      final parsed = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': parsed['message'] ?? 'Bill uploaded successfully',
          'expense': parsed['expense'],
        };
      } else {
        return {
          'success': false,
          'message': parsed['message'] ?? 'Failed to upload bill',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// Get bill details by expense ID
  static Future<Map<String, dynamic>?> getBillDetails(String expenseId) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return null;
    }

    final uri = Uri.parse('$_base/bills/getBillDetails/$expenseId');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final res = await http.get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));


      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);

        // Handle different response structures
        if (parsed is Map<String, dynamic>) {
          if (parsed['expense'] is Map<String, dynamic>) {
            return parsed['expense'] as Map<String, dynamic>;
          } else if (parsed['data'] is Map<String, dynamic>) {
            return parsed['data'] as Map<String, dynamic>;
          }
          return parsed;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Assign money to members
  /// Backend expects: assignments = [{ from: userId, to: userId, amount: number }]
  static Future<Map<String, dynamic>> assignMoney({
    required String expenseId,
    required List<Map<String, dynamic>> assignments,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$_base/bills/assign-money');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'expenseId': expenseId,
      'assignments': assignments,
    });

    try {

      final res = await http.patch(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));


      final parsed = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          'success': true,
          'message': parsed['message'] ?? 'Money assigned successfully',
          'expense': parsed['expense'],
        };
      } else {
        return {
          'success': false,
          'message': parsed['message'] ?? 'Failed to assign money',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// Settle assignments (update user balances)
  static Future<Map<String, dynamic>> settleAssignments({
    required String expenseId,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$_base/bills/settleAssignment');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'expenseId': expenseId,
    });

    try {

      final res = await http.post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));


      final parsed = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          'success': true,
          'message': parsed['message'] ?? 'Assignments settled successfully',
          'expense': parsed['expense'],
        };
      } else {
        return {
          'success': false,
          'message': parsed['message'] ?? 'Failed to settle assignments',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// Create a manual expense (no image)
  /// Backend route: POST /bills/manual
  /// Required fields: groupId, totalAmount, items, billName
  static Future<Map<String, dynamic>> createManualExpense({
    required String groupId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    required String billName,
    String? splitMethod, // 'equal' | 'per-item' | 'money'
    List<Map<String, dynamic>>? payments, // [{ user, amount, method? }]
    List<Map<String, dynamic>>? assignments, // [{ from, to, amount }]
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$_base/bills/manual');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    // Normalize items and pass assignedTo if provided
    final normalizedItems = items.map((it) {
      final map = {
        'name': it['name'],
        'quantity': it['quantity'],
        'price': it['price'],
      };
      if (it['assignedTo'] != null) {
        map['assignedTo'] = it['assignedTo'];
      }
      return map;
    }).toList();

    final payload = <String, dynamic>{
      'groupId': groupId,
      'totalAmount': totalAmount,
      'items': normalizedItems,
      'billName': billName,
    };
    if (splitMethod != null) payload['splitMethod'] = splitMethod;
    if (payments != null) payload['payments'] = payments;
    if (assignments != null) payload['assignments'] = assignments;

    final body = jsonEncode(payload);

    try {
      final res = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));


      final parsed = jsonDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        return {
          'success': true,
          'message': parsed['message'] ?? 'Expense created successfully',
          'expense': parsed['expense'] ?? parsed['data'],
        };
      }

      return {
        'success': false,
        'message': parsed['message'] ?? 'Failed to create expense',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

}