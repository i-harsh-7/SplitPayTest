import 'package:flutter/material.dart';

// Enum for group status
enum GroupStatus { owe, owed, settled }

// Data model for a group
class GroupModel {
  final String? id;           // Group ID from backend
  final String name;          // Group name
  final int members;          // Number of members
  final GroupStatus status;   // Owe / Owed / Settled
  final int amount;           // Amount owed or owed to user
  final List<String> avatars; // Member avatars
  final IconData? icon;       // Group icon
  final String? description;  // Group description

  GroupModel({
    this.id,
    required this.name,
    required this.members,
    required this.status,
    required this.amount,
    this.avatars = const [],
    this.icon,
    this.description,
  });
}