import 'package:cloud_firestore/cloud_firestore.dart';

// `geofence` (Faz 1 §1.5) is deliberately absent from firestore.rules'
// checkins/create allowlist — like `qr`, it is written only by a Cloud
// Function (recordPresenceEvent, Admin SDK bypasses rules), never accepted
// as a direct client write. Only `gps`/`manual` remain client-writable.
enum CheckInMethod { qr, gps, manual, geofence }

extension CheckInMethodX on CheckInMethod {
  String get firestoreValue => name;

  static CheckInMethod fromString(String? v) => switch (v) {
        'qr' => CheckInMethod.qr,
        'gps' => CheckInMethod.gps,
        'geofence' => CheckInMethod.geofence,
        _ => CheckInMethod.manual,
      };

  String get displayLabel => switch (this) {
        CheckInMethod.qr => 'QR',
        CheckInMethod.gps => 'GPS',
        CheckInMethod.manual => 'Manual',
        CheckInMethod.geofence => 'Auto',
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
