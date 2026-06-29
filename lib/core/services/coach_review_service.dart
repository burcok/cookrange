import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/coach_review_model.dart';
import 'crashlytics_service.dart';

class CoachReviewService {
  static final CoachReviewService _instance = CoachReviewService._internal();
  factory CoachReviewService() => _instance;
  CoachReviewService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _reviews(String coachUid) =>
      _db.collection('coach_profiles').doc(coachUid).collection('reviews');

  DocumentReference<Map<String, dynamic>> _coachDoc(String coachUid) =>
      _db.collection('coach_profiles').doc(coachUid);

  DocumentReference<Map<String, dynamic>> _clientDoc(
          String coachUid, String clientUid) =>
      _db
          .collection('coach_profiles')
          .doc(coachUid)
          .collection('clients')
          .doc(clientUid);

  /// Writes a review doc and atomically updates avgRating + ratingCount on
  /// the coach_profiles/{coachUid} document via a Firestore transaction.
  Future<void> addReview(String coachUid, CoachReviewModel review) async {
    debugPrint(
        'CoachReviewService.addReview: coachUid=$coachUid reviewer=${review.reviewerUid} rating=${review.rating}');
    try {
      await _db.runTransaction((tx) async {
        final coachSnap = await tx.get(_coachDoc(coachUid));
        final currentAvg =
            (coachSnap.data()?['avg_rating'] as num?)?.toDouble() ?? 0.0;
        final currentCount =
            (coachSnap.data()?['rating_count'] as int?) ?? 0;

        final newCount = currentCount + 1;
        final newAvg =
            ((currentAvg * currentCount) + review.rating) / newCount;

        tx.set(_reviews(coachUid).doc(review.reviewerUid), review.toFirestore());
        tx.update(_coachDoc(coachUid), {
          'avg_rating': double.parse(newAvg.toStringAsFixed(2)),
          'rating_count': newCount,
        });
      });
      debugPrint(
          'CoachReviewService.addReview: review written for coachUid=$coachUid');
    } catch (e, stack) {
      debugPrint('CoachReviewService.addReview error: $e');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'CoachReviewService.addReview coachUid=$coachUid'));
      rethrow;
    }
  }

  /// Stream of reviews for a coach, ordered by createdAt descending.
  Stream<List<CoachReviewModel>> getReviewsStream(String coachUid) {
    debugPrint('CoachReviewService.getReviewsStream: coachUid=$coachUid');
    return _reviews(coachUid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CoachReviewModel.fromFirestore).toList());
  }

  /// Returns true if [reviewerUid] is a linked client of [coachUid], has not
  /// already submitted a review, AND has at least one food log entry (anti-fraud
  /// signal that the account has had a real user session).
  Future<bool> canReview(String coachUid, String reviewerUid) async {
    debugPrint(
        'CoachReviewService.canReview: coachUid=$coachUid reviewerUid=$reviewerUid');
    try {
      final clientSnap = await _clientDoc(coachUid, reviewerUid).get();
      if (!clientSnap.exists) {
        debugPrint(
            '[CoachReviewService] canReview: $reviewerUid is not a linked client of $coachUid');
        return false;
      }

      final reviewSnap = await _reviews(coachUid).doc(reviewerUid).get();
      if (reviewSnap.exists) {
        debugPrint(
            '[CoachReviewService] canReview: $reviewerUid already has a review for $coachUid');
        return false;
      }

      final foodLogSnap = await _db
          .collection('users')
          .doc(reviewerUid)
          .collection('food_logs')
          .limit(1)
          .get();
      if (foodLogSnap.docs.isEmpty) {
        debugPrint(
            '[CoachReviewService] canReview: no food logs for $reviewerUid');
        return false;
      }

      return true;
    } catch (e, stack) {
      debugPrint('CoachReviewService.canReview error: $e');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'CoachReviewService.canReview coachUid=$coachUid'));
      return false;
    }
  }

  /// Returns the existing review by [reviewerUid] for [coachUid], or null.
  Future<CoachReviewModel?> getUserReview(
      String coachUid, String reviewerUid) async {
    debugPrint(
        'CoachReviewService.getUserReview: coachUid=$coachUid reviewerUid=$reviewerUid');
    try {
      final snap = await _reviews(coachUid).doc(reviewerUid).get();
      if (!snap.exists) return null;
      return CoachReviewModel.fromFirestore(snap);
    } catch (e, stack) {
      debugPrint('CoachReviewService.getUserReview error: $e');
      unawaited(CrashlyticsService().recordError(e, stack,
          reason:
              'CoachReviewService.getUserReview coachUid=$coachUid reviewerUid=$reviewerUid'));
      return null;
    }
  }
}
