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
  static const _contentSeedKey = 'demo_programs_content_v1';

  Future<void> seedIfEmpty() async {
    try {
      final seedDoc = await _db.collection('seeds').doc('demo').get();
      final data = seedDoc.data() ?? {};

      if (data[_seedKey] != true) {
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
        batch.set(
          _db.collection('seeds').doc('demo'),
          {_seedKey: true},
          SetOptions(merge: true),
        );
        await batch.commit();
        debugPrint(
            'DemoContentSeeder: seeded ${_demoProgramData.length} demo programs');
      }

      if (data[_contentSeedKey] != true) {
        await _seedProgramContent();
      }
    } catch (e) {
      debugPrint('DemoContentSeeder: seeding failed (non-fatal) — $e');
    }
  }

  /// Seeds week/day/session content for existing demo programs.
  /// Finds programs by `coach_uid == 'demo'` and seeds weeks subcollection.
  Future<void> _seedProgramContent() async {
    debugPrint('DemoContentSeeder: seeding program content...');
    try {
      final demoPrograms = await _db
          .collection('programs')
          .where('coach_uid', isEqualTo: 'demo')
          .get();

      for (final progDoc in demoPrograms.docs) {
        final title = progDoc.data()['title'] as String? ?? '';
        final contentKey = _contentForTitle(title);
        if (contentKey == null) continue;

        final existingWeeks =
            await progDoc.reference.collection('weeks').limit(1).get();
        if (existingWeeks.docs.isNotEmpty) continue;

        final batch = _db.batch();
        for (final week in contentKey) {
          final weekRef = progDoc.reference.collection('weeks').doc();
          batch.set(weekRef, week);
        }
        await batch.commit();
        debugPrint('DemoContentSeeder: content seeded for "${progDoc.data()['title']}"');
      }

      await _db.collection('seeds').doc('demo').set(
        {_contentSeedKey: true},
        SetOptions(merge: true),
      );
      debugPrint('DemoContentSeeder: program content seeding complete');
    } catch (e) {
      debugPrint('DemoContentSeeder: content seeding error (non-fatal) — $e');
    }
  }

  List<Map<String, dynamic>>? _contentForTitle(String title) {
    if (title.contains('Fat Burn')) return _fatBurnWeeks;
    if (title.contains('Lean Muscle')) return _leanMuscleWeeks;
    if (title.contains('Healthy Habits')) return _healthyHabitsWeeks;
    return null;
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

  // ── Week content data ───────────────────────────────────────────────────────

  static const _fatBurnWeeks = [
    {
      'week_number': 1,
      'title': 'Foundation Week',
      'description': 'Build your base with introductory HIIT and calorie-aware meals.',
      'days': [
        {
          'day_number': 1, 'title': 'Kickoff HIIT',
          'sessions': [
            {'title': '20-min Full Body HIIT', 'type': 'workout', 'duration_minutes': 20, 'description': 'Jump squats, burpees, mountain climbers — 40s on / 20s off.'},
            {'title': 'High-protein breakfast', 'type': 'meal', 'description': 'Eggs & avocado toast, 400 kcal.'},
          ]
        },
        {
          'day_number': 2, 'title': 'Active Recovery',
          'sessions': [
            {'title': 'Rest & stretch', 'type': 'rest', 'duration_minutes': 15},
            {'title': 'Meal prep guide', 'type': 'article', 'description': 'How to batch-cook proteins for the week.'},
          ]
        },
        {
          'day_number': 3, 'title': 'Cardio Blast',
          'sessions': [
            {'title': '25-min Cardio Circuit', 'type': 'workout', 'duration_minutes': 25},
            {'title': 'Calorie counting basics', 'type': 'video', 'duration_minutes': 8},
          ]
        },
      ],
    },
    {
      'week_number': 2,
      'title': 'Intensity Up',
      'description': 'Increase workout density and tighten up your nutrition.',
      'days': [
        {
          'day_number': 1, 'title': 'Tabata Training',
          'sessions': [
            {'title': '30-min Tabata', 'type': 'workout', 'duration_minutes': 30},
            {'title': 'Low-carb dinner idea', 'type': 'meal', 'description': 'Grilled chicken & roasted vegetables, 500 kcal.'},
          ]
        },
        {
          'day_number': 2, 'title': 'Strength & Burn',
          'sessions': [
            {'title': 'Dumbbell circuit', 'type': 'workout', 'duration_minutes': 35},
          ]
        },
        {
          'day_number': 3, 'title': 'Rest Day',
          'sessions': [
            {'title': 'Full rest', 'type': 'rest'},
          ]
        },
      ],
    },
    {
      'week_number': 3,
      'title': 'Metabolic Push',
      'description': 'Unlock your metabolic rate with compound movements.',
      'days': [
        {
          'day_number': 1, 'title': 'Compound HIIT',
          'sessions': [
            {'title': '35-min Compound Cardio', 'type': 'workout', 'duration_minutes': 35},
          ]
        },
        {
          'day_number': 2, 'title': 'Nutrition Focus',
          'sessions': [
            {'title': 'Macro tracking walkthrough', 'type': 'video', 'duration_minutes': 12},
            {'title': 'Balanced lunch bowl', 'type': 'meal', 'description': 'Quinoa, chickpeas, greens — 550 kcal.'},
          ]
        },
        {
          'day_number': 3, 'title': 'Active Rest',
          'sessions': [
            {'title': '20-min yoga flow', 'type': 'workout', 'duration_minutes': 20},
          ]
        },
      ],
    },
    {
      'week_number': 4,
      'title': 'Peak & Finish Strong',
      'description': 'Maximum intensity final week — see your transformation.',
      'days': [
        {
          'day_number': 1, 'title': 'Max HIIT',
          'sessions': [
            {'title': '40-min Max Effort HIIT', 'type': 'workout', 'duration_minutes': 40},
          ]
        },
        {
          'day_number': 2, 'title': 'Celebration Meal',
          'sessions': [
            {'title': 'Progress check & reflection', 'type': 'article'},
            {'title': 'Celebration healthy meal', 'type': 'meal', 'description': 'Your favourite balanced meal — stay on track!'},
          ]
        },
        {
          'day_number': 3, 'title': 'Final Push',
          'sessions': [
            {'title': '30-min Cardio Finisher', 'type': 'workout', 'duration_minutes': 30},
          ]
        },
      ],
    },
  ];

  static const _leanMuscleWeeks = [
    {
      'week_number': 1,
      'title': 'Foundation Strength',
      'description': 'Establish your base lifts and high-protein nutrition.',
      'days': [
        {
          'day_number': 1, 'title': 'Push Day A',
          'sessions': [
            {'title': 'Bench press 4×8', 'type': 'workout', 'duration_minutes': 45, 'description': 'Rest 90s between sets.'},
            {'title': 'High-protein post-workout shake', 'type': 'meal', 'description': '40g whey, banana, oat milk.'},
          ]
        },
        {
          'day_number': 2, 'title': 'Pull Day A',
          'sessions': [
            {'title': 'Pull-ups & rows 4×8', 'type': 'workout', 'duration_minutes': 45},
          ]
        },
        {
          'day_number': 3, 'title': 'Rest',
          'sessions': [
            {'title': 'Active recovery walk', 'type': 'rest', 'duration_minutes': 20},
          ]
        },
        {
          'day_number': 4, 'title': 'Leg Day A',
          'sessions': [
            {'title': 'Squat 4×8 + Romanian deadlift', 'type': 'workout', 'duration_minutes': 50},
            {'title': 'Post-leg meal', 'type': 'meal', 'description': 'Rice, chicken, broccoli — 700 kcal.'},
          ]
        },
      ],
    },
    {
      'week_number': 2,
      'title': 'Progressive Overload',
      'description': 'Add 2.5 kg to each lift from Week 1.',
      'days': [
        {
          'day_number': 1, 'title': 'Push Day B',
          'sessions': [
            {'title': 'Incline press & dips', 'type': 'workout', 'duration_minutes': 50},
          ]
        },
        {
          'day_number': 2, 'title': 'Pull Day B',
          'sessions': [
            {'title': 'Weighted pull-ups & seated cable row', 'type': 'workout', 'duration_minutes': 50},
          ]
        },
        {
          'day_number': 3, 'title': 'Leg Day B',
          'sessions': [
            {'title': 'Front squat & leg press', 'type': 'workout', 'duration_minutes': 55},
          ]
        },
        {
          'day_number': 4, 'title': 'Rest',
          'sessions': [
            {'title': 'Foam rolling & mobility', 'type': 'rest', 'duration_minutes': 25},
          ]
        },
      ],
    },
  ];

  static const _healthyHabitsWeeks = [
    {
      'week_number': 1,
      'title': 'Awareness Week',
      'description': 'Track what you eat and move gently every day.',
      'days': [
        {
          'day_number': 1, 'title': 'Start Strong',
          'sessions': [
            {'title': '10-min morning walk', 'type': 'workout', 'duration_minutes': 10},
            {'title': 'Mindful eating intro', 'type': 'article', 'description': 'Eat without screens for one meal today.'},
            {'title': 'Balanced breakfast', 'type': 'meal', 'description': 'Oats, berries, nuts — 350 kcal.'},
          ]
        },
        {
          'day_number': 2, 'title': 'Hydration Day',
          'sessions': [
            {'title': 'Drink 8 glasses of water', 'type': 'article'},
            {'title': 'Light stretching', 'type': 'workout', 'duration_minutes': 15},
          ]
        },
        {
          'day_number': 3, 'title': 'Sleep Habits',
          'sessions': [
            {'title': 'Sleep hygiene tips', 'type': 'video', 'duration_minutes': 7},
            {'title': 'Rest day', 'type': 'rest'},
          ]
        },
      ],
    },
    {
      'week_number': 2,
      'title': 'Building Routines',
      'description': 'Lock in your morning and evening rituals.',
      'days': [
        {
          'day_number': 1, 'title': 'Morning Ritual',
          'sessions': [
            {'title': '15-min yoga', 'type': 'workout', 'duration_minutes': 15},
            {'title': 'Journaling prompt', 'type': 'article', 'description': 'Write 3 things you\'re grateful for.'},
          ]
        },
        {
          'day_number': 2, 'title': 'Nutrition Audit',
          'sessions': [
            {'title': 'Review your food log', 'type': 'article'},
            {'title': 'Prep healthy snacks', 'type': 'meal', 'description': 'Hummus, carrot sticks, apple with nut butter.'},
          ]
        },
        {
          'day_number': 3, 'title': 'Evening Wind-down',
          'sessions': [
            {'title': '10-min evening walk', 'type': 'workout', 'duration_minutes': 10},
            {'title': 'Digital sunset hour', 'type': 'rest'},
          ]
        },
      ],
    },
    {
      'week_number': 3,
      'title': 'Consistency is Key',
      'description': 'Solidify your habits and celebrate progress.',
      'days': [
        {
          'day_number': 1, 'title': 'Habit Stacking',
          'sessions': [
            {'title': 'Combine 2 habits from Week 1 & 2', 'type': 'article'},
            {'title': 'Balanced lunch', 'type': 'meal', 'description': 'Salad with protein + whole grain roll.'},
          ]
        },
        {
          'day_number': 2, 'title': 'Active Day',
          'sessions': [
            {'title': '20-min light jog', 'type': 'workout', 'duration_minutes': 20},
          ]
        },
        {
          'day_number': 3, 'title': 'Celebrate!',
          'sessions': [
            {'title': 'Reflect on 21-day journey', 'type': 'article'},
            {'title': 'Treat yourself to a healthy reward meal', 'type': 'meal'},
          ]
        },
      ],
    },
  ];
}
