// lib/models/user_model.dart
import 'package:flutter/material.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String profilePicture; // URL
  final double youOweBalance;      // Amount the user owes
  final double youAreOwedBalance;  // Amount owed to the user

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.profilePicture,
    this.youOweBalance = 0.0,
    this.youAreOwedBalance = 0.0,
  });

  factory UserModel.fromLoginUser(Map<String, dynamic> map) {
    return UserModel(
      id: map['_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      // Backend login response does not include picture/balances; default safely
      profilePicture: '',
      youOweBalance: 0.0,
      youAreOwedBalance: 0.0,
    );
  }
}