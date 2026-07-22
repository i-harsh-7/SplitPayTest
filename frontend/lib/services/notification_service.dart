import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import 'auth_service.dart';

class NotificationService {
  static const _base = ApiConfig.baseUrl;

  /// Get all notifications for the current user
  /// Returns a list of notification objects with type, title, message, timestamp, and id
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final token = await AuthService.getToken();
    if (token == null) {
      return [];
    }

    final uri = Uri.parse('$_base/notifications');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final res = await http.get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        
        // Handle different response structures from backend
        List<dynamic>? notificationsArray;
        
        if (parsed is Map) {
          if (parsed['success'] == true && parsed['notifications'] is List) {
            notificationsArray = parsed['notifications'];
          } else if (parsed['data'] is List) {
            notificationsArray = parsed['data'];
          } else if (parsed['data'] is Map && parsed['data']['notifications'] is List) {
            notificationsArray = parsed['data']['notifications'];
          }
        } else if (parsed is List) {
          notificationsArray = parsed;
        }

        if (notificationsArray != null) {
          List<Map<String, dynamic>> notifications = [];
          
          for (var notification in notificationsArray) {
            if (notification is Map) {
              notifications.add(_parseNotification(notification));
            }
          }
          
          return notifications;
        }
      } else if (res.statusCode == 404 || res.statusCode == 204) {
        // No notifications found - return empty list
        return [];
      }
    } catch (_) {}
    
    return [];
  }

  /// Parse a notification object from backend response
  static Map<String, dynamic> _parseNotification(Map notification) {
    String type = 'info';
    String title = 'Notification';
    String message = '';
    String timestamp = '';
    String id = notification['_id']?.toString() ?? 
                notification['id']?.toString() ?? 
                DateTime.now().millisecondsSinceEpoch.toString();

    // Determine notification type and content
    final notificationType = notification['type']?.toString().toLowerCase() ?? '';
    final status = notification['status']?.toString().toLowerCase() ?? '';
    
    if (notificationType == 'invite_accepted' || status == 'accepted') {
      type = 'accepted';
      final userName = notification['user']?['name']?.toString() ?? 
                      notification['userName']?.toString() ?? 
                      notification['senderName']?.toString() ?? 
                      'A user';
      final groupName = notification['group']?['name']?.toString() ?? 
                       notification['groupName']?.toString() ?? 
                       'the group';
      title = 'Invite Accepted';
      message = '$userName has accepted your invitation to join $groupName';
    } else if (notificationType == 'invite_rejected' || status == 'rejected') {
      type = 'rejected';
      final userName = notification['user']?['name']?.toString() ?? 
                      notification['userName']?.toString() ?? 
                      notification['senderName']?.toString() ?? 
                      'A user';
      final groupName = notification['group']?['name']?.toString() ?? 
                       notification['groupName']?.toString() ?? 
                       'the group';
      title = 'Invite Declined';
      message = '$userName has declined your invitation to join $groupName';
    } else {
      // Generic notification
      type = notificationType.isNotEmpty ? notificationType : 'info';
      title = notification['title']?.toString() ?? 
              notification['subject']?.toString() ?? 
              'Notification';
      message = notification['message']?.toString() ?? 
               notification['body']?.toString() ?? 
               notification['content']?.toString() ?? 
               '';
    }

    // Parse timestamp
    final createdAt = notification['createdAt']?.toString() ?? 
                     notification['timestamp']?.toString() ?? 
                     notification['date']?.toString();
    
    if (createdAt != null && createdAt.isNotEmpty) {
      timestamp = _formatTimestamp(createdAt);
    }

    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'read': notification['read'] ?? notification['isRead'] ?? false,
    };
  }

  /// Format timestamp to human-readable format
  static String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        // Format as date
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return timestamp;
    }
  }

  /// Dismiss/delete a notification
  static Future<bool> dismissNotification(String notificationId) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return false;
    }

    final uri = Uri.parse('$_base/notifications/$notificationId');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final res = await http.delete(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 204) {
        return true;
      }
    } catch (_) {}
    
    return false;
  }

  /// Mark a notification as read
  static Future<bool> markAsRead(String notificationId) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return false;
    }

    final uri = Uri.parse('$_base/notifications/$notificationId/read');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final res = await http.put(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return true;
      }
    } catch (_) {}
    
    return false;
  }

  /// Mark all notifications as read
  static Future<bool> markAllAsRead() async {
    final token = await AuthService.getToken();
    if (token == null) {
      return false;
    }

    final uri = Uri.parse('$_base/notifications/read-all');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final res = await http.put(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return true;
      }
    } catch (_) {}
    
    return false;
  }

  /// Get unread notification count
  static Future<int> getUnreadCount() async {
    final notifications = await getNotifications();
    return notifications.where((n) => n['read'] == false).length;
  }
}