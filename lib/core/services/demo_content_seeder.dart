import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Idempotent seeder for demo programs. Runs once on first install.
/// Uses Firestore `seeds/demo` doc to gate re-seeding.
class DemoContentSeeder {
  static final _instance = DemoContentSeeder._internal();
  factory DemoContentSeeder() => _instance;
  DemoContentSeeder._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _seedKey = 'demo_programs_v1';

  Future<void> seedIfEmpty() async {
    try {
      // Check if already seeded
      final seedDoc = await _db.collection('seeds').doc('demo').get();
      if (seedDoc.data()?[_seedKey] == true) return;

      debugPrint('DemoContentSeeder: seeding demo programs...');

      final batch = _db.batch();

      for (final program in _demoProgramData) {
        final ref = _db.collection('programs').doc();
        batch.set(ref, {
          ...program,
          'is_demo': true,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      // Mark as seeded
      batch.set(
        _db.collection('seeds').doc('demo'),
        {_seedKey: true},
        SetOptions(merge: true),
      );

      await batch.commit();
      debugPrint(
          'DemoContentSeeder: seeded ${_demoProgramData.length} demo programs');
    } catch (e) {
      // Seeding failure is non-fatal; app works without pre-seeded demo programs
      debugPrint('DemoContentSeeder: seeding failed (non-fatal) — $e');
    }
  }

  // Field names match ProgramModel.toFirestore() exactly.
  // category values match ProgramCategory.firestoreValue (enum .name → camelCase).
  // difficulty values match ProgramDifficulty.firestoreValue (enum .name).
  static const List<Map<String, dynamic>> _demoProgramData = [
    {
      'coach_uid': 'demo',
      'coach_name': 'Cookrange Team',
      'title': '30-Day Fat Burn Challenge',
      'description':
          'A science-backed 30-day program combining HIIT workouts with '
              'calorie-controlled meal plans to maximize fat loss. Suitable for all levels.',
      'difficulty': 'intermediate',
      'category': 'weightLoss',
      'duration_weeks': 4,
      'sessions_per_week': 5,
      'price': 0.0,
      'tags': ['fat_burn', 'hiit', 'beginner_friendly'],
      'highlights': [
        'Daily workout plans',
        'AI meal pairing',
        'Progress tracking',
      ],
      'is_published': true,
      'enrollment_count': 128,
      'rating': 0.0,
      'rating_count': 0,
    },
    {
      'coach_uid': 'demo',
      'coach_name': 'Cookrange Team',
      'title': 'Lean Muscle Builder 8-Week',
      'description':
          'Build lean muscle with progressive overload training and high-protein '
              'meal plans. Tailored for those who want to gain strength without bulk.',
      'difficulty': 'intermediate',
      'category': 'muscleGain',
      'duration_weeks': 8,
      'sessions_per_week': 4,
      'price': 0.0,
      'tags': ['muscle', 'strength', 'protein'],
      'highlights': [
        'Progressive overload plans',
        'Macro-optimized recipes',
        'Weekly check-ins',
      ],
      'is_published': true,
      'enrollment_count': 84,
      'rating': 0.0,
      'rating_count': 0,
    },
    {
      'coach_uid': 'demo',
      'coach_name': 'Cookrange Team',
      'title': 'Healthy Habits — 21-Day Reset',
      'description':
          'A gentle 21-day program for beginners focused on building sustainable '
              'healthy habits: balanced nutrition, light movement, and better sleep.',
      'difficulty': 'beginner',
      'category': 'lifestyle',
      'duration_weeks': 3,
      'sessions_per_week': 3,
      'price': 0.0,
      'tags': ['beginner', 'wellness', 'habits'],
      'highlights': [
        'Daily habit checklist',
        'Balanced meal ideas',
        'Mindfulness tips',
      ],
      'is_published': true,
      'enrollment_count': 213,
      'rating': 0.0,
      'rating_count': 0,
    },
  ];
}
