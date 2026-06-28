import 'package:cloud_firestore/cloud_firestore.dart';

enum CheckInMethod { qr, gps, manual }

extension CheckInMethodX on CheckInMethod {
  String get firestoreValue => name;

  static CheckInMethod fromString(String? v) => switch (v) {
        'qr' => CheckInMethod.qr,
        'gps' => CheckInMethod.gps,
        _ => CheckInMethod.manual,
      };

  String get displayLabel => switch (this) {
        CheckInMethod.qr => 'QR',
        CheckInMethod.gps => 'GPS',
        CheckInMethod.manual => 'Manual',
      };
}

class CheckInModel {
  final String id;
  final String uid;
  final String? displayName;
  final String? photoURL;
  final DateTime timestamp;
  final CheckInMethod method;

  const CheckInModel({
    required this.id,
    required this.uid,
    this.displayName,
    this.photoURL,
    required this.timestamp,
    required this.method,
  });

  factory CheckInModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CheckInModel(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      displayName: d['display_name'] as String?,
      photoURL: d['photo_url'] as String?,
      timestamp: d['timestamp'] is Timestamp
          ? (d['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      method: CheckInMethodX.fromString(d['method'] as String?),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        if (displayName != null) 'display_name': displayName,
        if (photoURL != null) 'photo_url': photoURL,
        'timestamp': Timestamp.fromDate(timestamp),
        'method': method.firestoreValue,
      };
}
