import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/signal_model.dart';
import '../services/auth_service.dart';

class SignalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();
  final Uuid _uuid = const Uuid();

  // Create a new signal
  Future<void> sendSignal({
    required SignalType type,
    required String message,
    required int durationMinutes,
    Map<String, dynamic> metadata = const {},
  }) async {
    final user = _auth.currentUser; // Basic User object
    if (user == null) return;

    // Fetch full user data to get name/image if needed, or rely on what we have
    // Ideally we store minimal sender info in the signal for fast read
    final userData = await _auth.getUserData(user.uid);

    final id = _uuid.v4();
    final now = DateTime.now();
    final expiresAt = now.add(Duration(minutes: durationMinutes));

    final signal = SignalModel(
      id: id,
      senderId: user.uid,
      senderName: userData?.displayName ?? 'Anonymous',
      senderImage: userData?.photoURL,
      type: type,
      message: message,
      metadata: metadata,
      createdAt: now,
      expiresAt: expiresAt,
      ignoredBy: [],
    );

    await _firestore.collection('signals').doc(id).set(signal.toJson());
  }

  // Get active signals visible to the current user
  // In a real app, this would query based on friends or location (GeoFlutterFire)
  // For now, we'll fetch all active signals and filter client-side or assume globally visible for beta
  Stream<List<SignalModel>> getActiveSignals() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    final now = Timestamp.now();

    return _firestore
        .collection('signals')
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt',
            descending: false) // Order by soonest expiry or creation?
        // Firestore requires composite index for 'expiresAt' and 'createdAt' if we mix them.
        // Let's just filter for active ones.
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SignalModel.fromJson(doc.data(), doc.id))
          .where((signal) =>
                  signal.senderId !=
                      uid && // Don't show my own signals in the "Help Needed" list (optional)
                  !signal.ignoredBy.contains(uid) // Filter ignored
              )
          .toList();
    });
  }

  // Ignore/Dismiss a signal
  Future<void> ignoreSignal(String signalId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('signals').doc(signalId).update({
      'ignoredBy': FieldValue.arrayUnion([uid])
    });
  }
}
