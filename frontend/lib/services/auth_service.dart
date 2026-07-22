import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthService {
  static const _base = ApiConfig.baseUrl;
  static User? _cachedUser;

  /// Sign up with name, email, phone and password.
  static Future<String> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final uri = Uri.parse('$_base/signUp');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'phone': phone, 'password': password}));

    final Map<String, dynamic> body = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      final token = body['token'] ?? body['data']?['token'];
      if (token != null && token is String) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
        } on MissingPluginException {
          _inMemory['auth_token'] = token;
        }

        try {
          final Map<String, dynamic>? userMap = body['user'] is Map<String, dynamic>
              ? body['user'] as Map<String, dynamic>
              : null;
          if (userMap != null) {
            _cachedUser = User(
              name: userMap['name']?.toString() ?? 'User',
              email: userMap['email']?.toString() ?? '',
            );
            // Persist user data
            await _saveUserData(_cachedUser!);
          }
        } catch (_) {}

        return token;
      }
      throw Exception(body['message'] ?? 'Sign up succeeded but no token returned');
    }
    throw Exception(body['message'] ?? 'Sign up failed');
  }

  /// Login with email and password.
  static Future<String> login({
    required String email,
    required String password,
  }) async {
    _cachedUser = null;

    final uri = Uri.parse('$_base/login');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}));

    final Map<String, dynamic> body = jsonDecode(res.body);
    if (res.statusCode == 200) {
      final token = body['token'] ?? body['data']?['token'];
      if (token != null && token is String) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
        } on MissingPluginException {
          _inMemory['auth_token'] = token;
        }

        try {
          final Map<String, dynamic>? userMap =
          (body['user'] is Map<String, dynamic>) ? body['user'] as Map<String, dynamic> :
          (body['data'] is Map<String, dynamic> && body['data']['user'] is Map<String, dynamic>)
              ? body['data']['user'] as Map<String, dynamic>
              : null;
          if (userMap != null) {
            _cachedUser = User(
              name: userMap['name']?.toString() ?? 'User',
              email: userMap['email']?.toString() ?? '',
            );
            // Persist user data
            await _saveUserData(_cachedUser!);
          }
        } catch (_) {}
        return token;
      }
      throw Exception(body['message'] ?? 'Login succeeded but no token returned');
    }
    throw Exception(body['message'] ?? 'Login failed');
  }

  /// Change password - FIXED to match backend expectations
  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please login again.',
      };
    }

    // Get user email from profile
    final profile = await getProfile();
    if (profile == null || profile.email.isEmpty) {
      return {
        'success': false,
        'message': 'Could not retrieve user email',
      };
    }

    final uri = Uri.parse('$_base/changePassword');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'email': profile.email, // Backend expects email
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });

    try {
      final res = await http.patch(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      print('Change Password - Status: ${res.statusCode}');
      print('Change Password - Body: ${res.body}');

      if (res.body.isEmpty) {
        if (res.statusCode == 200 || res.statusCode == 204) {
          return {
            'success': true,
            'message': 'Password changed successfully',
          };
        } else {
          return {
            'success': false,
            'message': 'Failed to change password. Status: ${res.statusCode}',
          };
        }
      }

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(res.body);
      } catch (e) {
        return {
          'success': false,
          'message': 'Invalid response from server',
        };
      }

      if (res.statusCode == 200) {
        return {
          'success': parsed['success'] ?? true,
          'message': parsed['message']?.toString() ?? 'Password changed successfully',
        };
      } else {
        return {
          'success': false,
          'message': parsed['message']?.toString() ?? 'Failed to change password',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// Update profile - FIXED to match backend expectations
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please login again.',
      };
    }

    // Get user email from profile
    final profile = await getProfile();
    if (profile == null || profile.email.isEmpty) {
      return {
        'success': false,
        'message': 'Could not retrieve user email',
      };
    }

    final uri = Uri.parse('$_base/updateProfile');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'name': name,
      'email': profile.email, // Backend expects email
    });

    try {
      final res = await http.patch(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      print('Update Profile - Status: ${res.statusCode}');
      print('Update Profile - Body: ${res.body}');

      if (res.body.isEmpty) {
        if (res.statusCode == 200 || res.statusCode == 204) {
          if (_cachedUser != null) {
            _cachedUser = User(
              name: name,
              email: _cachedUser!.email,
            );
            // Save updated user data
            await _saveUserData(_cachedUser!);
          }
          return {
            'success': true,
            'message': 'Profile updated successfully',
          };
        } else {
          return {
            'success': false,
            'message': 'Failed to update profile. Status: ${res.statusCode}',
          };
        }
      }

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(res.body);
      } catch (e) {
        return {
          'success': false,
          'message': 'Invalid response from server',
        };
      }

      if (res.statusCode == 200) {
        if (_cachedUser != null) {
          _cachedUser = User(
            name: name,
            email: _cachedUser!.email,
          );
          // Save updated user data
          await _saveUserData(_cachedUser!);
        }

        return {
          'success': parsed['success'] ?? true,
          'message': parsed['message']?.toString() ?? 'Profile updated successfully',
        };
      } else {
        return {
          'success': false,
          'message': parsed['message']?.toString() ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// Get detailed user information including balances
  static Future<Map<String, dynamic>?> getUserDetails() async {
    final token = await getToken();
    if (token == null) {
      print('❌ No auth token found');
      return null;
    }

    final uri = Uri.parse('$_base/getUserDetails');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      print('🔍 Fetching user details from: $uri');
      final res = await http.get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      print('📡 getUserDetails status: ${res.statusCode}');
      print('📡 getUserDetails body: ${res.body}');

      if (res.statusCode == 200) {
        final Map<String, dynamic> parsed = jsonDecode(res.body);
        
        // Backend returns: { success: true, user: {...}, message: "..." }
        if (parsed['success'] == true && parsed['user'] != null) {
          return parsed;
        }
        
        // Fallback if structure is different
        return parsed;
      } else {
        print('❌ Failed to fetch user details: ${res.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching user details: $e');
      return null;
    }
  }

  /// Logs out on the server (invalidates every JWT issued to this user — there's no per-token
  /// store, so this signs out all devices, not just this one) and clears local session state.
  /// The server call is best-effort: local state is always cleared even if it fails or the
  /// token was already invalid.
  static Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        final uri = Uri.parse('$_base/logout');
        await http.post(uri, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 8));
      }
    } catch (_) {
      // Best-effort — local state is cleared regardless.
    }

    _cachedUser = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
    } on MissingPluginException {
      _inMemory.remove('auth_token');
      _inMemory.remove('user_name');
      _inMemory.remove('user_email');
    }
  }

  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } on MissingPluginException {
      return _inMemory['auth_token'];
    }
  }

  static Future<User?> getProfile() async {
    // First try to get from cache
    if (_cachedUser != null) return _cachedUser;
    
    // Then try to load from SharedPreferences
    final savedUser = await _loadUserData();
    if (savedUser != null) {
      _cachedUser = savedUser;
      return _cachedUser;
    }
    
    // Finally, try to fetch from API
    final token = await getToken();
    if (token == null) return null;

    final endpoints = ['/me', '/profile', '/users/me', '/user'];
    for (final ep in endpoints) {
      final uri = Uri.parse('$_base$ep');
      try {
        final res = await http.get(uri, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        }).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final Map<String, dynamic> body = jsonDecode(res.body);
          Map<String, dynamic>? payload = body;
          if (body['data'] is Map) payload = body['data'];
          if (body['user'] is Map) payload = body['user'];

          final name = payload?['name'] ?? payload?['fullName'] ?? payload?['username'] ?? payload?['firstName'];
          final email = payload?['email'] ?? payload?['emailId'];

          if ((name != null && name.toString().isNotEmpty) || (email != null && email.toString().isNotEmpty)) {
            final finalName = (name ?? email ?? 'User').toString();
            final finalEmail = (email ?? '').toString();
            _cachedUser = User(name: finalName, email: finalEmail);
            return _cachedUser;
          }
        }
      } catch (e) {}
    }
    return null;
  }

  static void clearCache() {
    _cachedUser = null;
  }

  // Helper method to save user data to SharedPreferences
  static Future<void> _saveUserData(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', user.name);
      await prefs.setString('user_email', user.email);
    } on MissingPluginException {
      _inMemory['user_name'] = user.name;
      _inMemory['user_email'] = user.email;
    }
  }

  // Helper method to load user data from SharedPreferences
  static Future<User?> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name');
      final email = prefs.getString('user_email');
      
      if (name != null && email != null) {
        return User(name: name, email: email);
      }
    } on MissingPluginException {
      final name = _inMemory['user_name'];
      final email = _inMemory['user_email'];
      
      if (name != null && email != null) {
        return User(name: name, email: email);
      }
    }
    return null;
  }
}

class User {
  final String name;
  final String email;

  User({required this.name, required this.email});
}

final Map<String, String> _inMemory = {};