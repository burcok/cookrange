import 'package:cloud_firestore/cloud_firestore.dart';

enum SignalType {
  gymHelp, // "Spotter needed", etc.
  mealShare, // "I made too much food"
  general, // General shoutout
}

class SignalModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderImage;
  final SignalType type;
  final String message;
  final Map<String, dynamic>
      metadata; // e.g., activity: "Bench Press", location: "Gym A"
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> ignoredBy; // List of userIds who hid this signal

  SignalModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderImage,
    required this.type,
    required this.message,
    this.metadata = const {},
    required this.createdAt,
    required this.expiresAt,
    this.ignoredBy = const [],
  });

  factory SignalModel.fromJson(Map<String, dynamic> json, String id) {
    return SignalModel(
      id: id,
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'User',
      senderImage: json['senderImage'],
      type: SignalType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SignalType.general,
      ),
      message: json['message'] ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      // Null-safe: signals are globally visible and created by any user — a
      // crafted/in-flight doc with a missing/bad timestamp must not crash the
      // whole feed. A malformed expiry defaults to "expired" (hidden).
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      expiresAt: json['expiresAt'] is Timestamp
          ? (json['expiresAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      ignoredBy: List<String>.from(json['ignoredBy'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderImage': senderImage,
      'type': type.name,
      'message': message,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'ignoredBy': ignoredBy,
    };
  }

  // Helper to check if still valid
  bool get isValid => DateTime.now().isBefore(expiresAt);
}
