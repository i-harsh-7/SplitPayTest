import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import 'auth_service.dart';

class InviteService {
  static const _base = ApiConfig.baseUrl;

  // Send invite to a user by email
  static Future<Map<String, dynamic>> sendInvite({
    required String groupId,
    required String friendEmail,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$_base/group/invite');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'groupId': groupId,
      'friendMail': friendEmail,
    });

    try {
      final res = await http.post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      final parsed = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          'success': true,
          'message': parsed['message'] ?? 'Invite sent successfully',
        };
      } else {
        return {
          'success': false,
          'message': parsed['message'] ?? 'Failed to send invite',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Get pending invites for current user
  static Future<List<Map<String, dynamic>>> getPendingInvites() async {
    final token = await AuthService.getToken();
    if (token == null) {
      return [];
    }

    final uri = Uri.parse('$_base/group/invite/pending');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final res = await http.get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        
        if (parsed['success'] == true && parsed['invites'] is List) {
          List<Map<String, dynamic>> invites = [];
          for (var invite in parsed['invites']) {
            if (invite is Map) {
              invites.add({
                'id': invite['_id']?.toString() ?? '',
                'groupName': invite['group']?['name']?.toString() ?? 
                            invite['group']?['groupName']?.toString() ?? 
                            'Group',
                'groupId': invite['group']?['_id']?.toString() ?? '',
                'senderName': invite['sender']?['name']?.toString() ?? 'Someone',
                'senderEmail': invite['sender']?['email']?.toString() ?? '',
                'status': invite['status']?.toString() ?? 'pending',
              });
            }
          }
          return invites;
        }
      }
    } catch (_) {}
    return [];
  }

  // Accept an invite
  static Future<Map<String, dynamic>> acceptInvite(String inviteId) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$_base/group/invite/accept');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({'inviteId': inviteId});

    try {
      final res = await http.post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      final parsed = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          'success': true,
          'message': parsed['message'] ?? 'Invite accepted successfully',
        };
      } else {
        return {
          'success': false,
          'message': parsed['message'] ?? 'Failed to accept invite',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Reject an invite
  static Future<Map<String, dynamic>> rejectInvite(String inviteId) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('$_base/group/invite/reject');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({'inviteId': inviteId});

    try {
      final res = await http.post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      final parsed = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          'success': true,
          'message': parsed['message'] ?? 'Invite rejected successfully',
        };
      } else {
        return {
          'success': false,
          'message': parsed['message'] ?? 'Failed to reject invite',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}