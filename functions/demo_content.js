'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// BLK-09 fix — demo marketplace content used to be seeded CLIENT-SIDE
// (lib/core/services/demo_content_seeder.dart, pre-fix) by writing directly
// to the public `programs` collection, gated only by firestore.rules'
// `coach_uid == 'demo'` bypass ("reserved for the DemoContentSeeder"). That
// bypass could never actually distinguish "the real seeder" from "an
// attacker copying the same write" — both are ordinary authenticated
// writes with an identical shape, and every other field (title,
// description, tags, coach_name: 'Cookrange Team') was fully
// attacker-controlled. Any authenticated user could inject unlimited fake
// listings into a marketplace that K5 (DECISIONS.md, this session) keeps
// permanently visible rather than deferring to M6 — this made the gap live
// and reachable, not a latent M6 problem.
//
// Fix: move the write server-side. This callable is invoked by every
// client on app start (unchanged — see AppInitializationService), but the
// actual Firestore write now happens only via the Admin SDK, from a fixed,
// hardcoded catalog a client can never influence. firestore.rules' `'demo'`
// bypass on `programs`/`weeks` is removed entirely alongside this — see
// that file's own comment at the Programs section.
//
// Idempotent via the SAME `seeds/demo` marker doc the retired client-side
// version used (now written only here, never by any client) — same
// check-existence-then-skip discipline as groups.js's seedOfficialGroups,
// just user-invoked instead of admin-invoked: safe because every write this
// callable can ever perform is fixed and idempotent, so a malicious or
// merely repeated invocation is a harmless no-op after the first real one.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { assertCallable } = require('./notifications');

const SEED_KEY = 'demo_programs_v1';
const CONTENT_SEED_KEY = 'demo_programs_content_v1';

// Verbatim port of the retired demo_content_seeder.dart's `_demoProgramData`
// — field names match ProgramModel.toFirestore() exactly; category/
// difficulty values match ProgramCategory/ProgramDifficulty.firestoreValue
// (Dart enum .name, confirmed via lib/core/models/program_model.dart:15,26).
const DEMO_PROGRAMS = [
  {
    coach_uid: 'demo',
    coach_name: 'Cookrange Team',
    title: '30-Day Fat Burn Challenge',
    description: 'A science-backed 30-day program combining HIIT workouts with '
      + 'calorie-controlled meal plans to maximize fat loss. Suitable for all levels.',
    difficulty: 'intermediate',
    category: 'weightLoss',
    duration_weeks: 4,
    sessions_per_week: 5,
    price: 0.0,
    tags: ['fat_burn', 'hiit', 'beginner_friendly'],
    highlights: ['Daily workout plans', 'AI meal pairing', 'Progress tracking'],
    is_published: true,
    enrollment_count: 128,
    rating: 0.0,
    rating_count: 0,
  },
  {
    coach_uid: 'demo',
    coach_name: 'Cookrange Team',
    title: 'Lean Muscle Builder 8-Week',
    description: 'Build lean muscle with progressive overload training and high-protein '
      + 'meal plans. Tailored for those who want to gain strength without bulk.',
    difficulty: 'intermediate',
    category: 'muscleGain',
    duration_weeks: 8,
    sessions_per_week: 4,
    price: 0.0,
    tags: ['muscle', 'strength', 'protein'],
    highlights: ['Progressive overload plans', 'Macro-optimized recipes', 'Weekly check-ins'],
    is_published: true,
    enrollment_count: 84,
    rating: 0.0,
    rating_count: 0,
  },
  {
    coach_uid: 'demo',
    coach_name: 'Cookrange Team',
    title: 'Healthy Habits — 21-Day Reset',
    description: 'A gentle 21-day program for beginners focused on building sustainable '
      + 'healthy habits: balanced nutrition, light movement, and better sleep.',
    difficulty: 'beginner',
    category: 'lifestyle',
    duration_weeks: 3,
    sessions_per_week: 3,
    price: 0.0,
    tags: ['beginner', 'wellness', 'habits'],
    highlights: ['Daily habit checklist', 'Balanced meal ideas', 'Mindfulness tips'],
    is_published: true,
    enrollment_count: 213,
    rating: 0.0,
    rating_count: 0,
  },
];

// Verbatim port of the retired _fatBurnWeeks/_leanMuscleWeeks/_healthyHabitsWeeks.
const FAT_BURN_WEEKS = [
  {
    week_number: 1,
    title: 'Foundation Week',
    description: 'Build your base with introductory HIIT and calorie-aware meals.',
    days: [
      {
        day_number: 1,
        title: 'Kickoff HIIT',
        sessions: [
          { title: '20-min Full Body HIIT', type: 'workout', duration_minutes: 20, description: 'Jump squats, burpees, mountain climbers — 40s on / 20s off.' },
          { title: 'High-protein breakfast', type: 'meal', description: 'Eggs & avocado toast, 400 kcal.' },
        ],
      },
      {
        day_number: 2,
        title: 'Active Recovery',
        sessions: [
          { title: 'Rest & stretch', type: 'rest', duration_minutes: 15 },
          { title: 'Meal prep guide', type: 'article', description: 'How to batch-cook proteins for the week.' },
        ],
      },
      {
        day_number: 3,
        title: 'Cardio Blast',
        sessions: [
          { title: '25-min Cardio Circuit', type: 'workout', duration_minutes: 25 },
          { title: 'Calorie counting basics', type: 'video', duration_minutes: 8 },
        ],
      },
    ],
  },
  {
    week_number: 2,
    title: 'Intensity Up',
    description: 'Increase workout density and tighten up your nutrition.',
    days: [
      {
        day_number: 1,
        title: 'Tabata Training',
        sessions: [
          { title: '30-min Tabata', type: 'workout', duration_minutes: 30 },
          { title: 'Low-carb dinner idea', type: 'meal', description: 'Grilled chicken & roasted vegetables, 500 kcal.' },
        ],
      },
      {
        day_number: 2,
        title: 'Strength & Burn',
        sessions: [
          { title: 'Dumbbell circuit', type: 'workout', duration_minutes: 35 },
        ],
      },
      {
        day_number: 3,
        title: 'Rest Day',
        sessions: [{ title: 'Full rest', type: 'rest' }],
      },
    ],
  },
  {
    week_number: 3,
    title: 'Metabolic Push',
    description: 'Unlock your metabolic rate with compound movements.',
    days: [
      {
        day_number: 1,
        title: 'Compound HIIT',
        sessions: [{ title: '35-min Compound Cardio', type: 'workout', duration_minutes: 35 }],
      },
      {
        day_number: 2,
        title: 'Nutrition Focus',
        sessions: [
          { title: 'Macro tracking walkthrough', type: 'video', duration_minutes: 12 },
          { title: 'Balanced lunch bowl', type: 'meal', description: 'Quinoa, chickpeas, greens — 550 kcal.' },
        ],
      },
      {
        day_number: 3,
        title: 'Active Rest',
        sessions: [{ title: '20-min yoga flow', type: 'workout', duration_minutes: 20 }],
      },
    ],
  },
  {
    week_number: 4,
    title: 'Peak & Finish Strong',
    description: 'Maximum intensity final week — see your transformation.',
    days: [
      {
        day_number: 1,
        title: 'Max HIIT',
        sessions: [{ title: '40-min Max Effort HIIT', type: 'workout', duration_minutes: 40 }],
      },
      {
        day_number: 2,
        title: 'Celebration Meal',
        sessions: [
          { title: 'Progress check & reflection', type: 'article' },
          { title: 'Celebration healthy meal', type: 'meal', description: 'Your favourite balanced meal — stay on track!' },
        ],
      },
      {
        day_number: 3,
        title: 'Final Push',
        sessions: [{ title: '30-min Cardio Finisher', type: 'workout', duration_minutes: 30 }],
      },
    ],
  },
];

const LEAN_MUSCLE_WEEKS = [
  {
    week_number: 1,
    title: 'Foundation Strength',
    description: 'Establish your base lifts and high-protein nutrition.',
    days: [
      {
        day_number: 1,
        title: 'Push Day A',
        sessions: [
          { title: 'Bench press 4×8', type: 'workout', duration_minutes: 45, description: 'Rest 90s between sets.' },
          { title: 'High-protein post-workout shake', type: 'meal', description: '40g whey, banana, oat milk.' },
        ],
      },
      {
        day_number: 2,
        title: 'Pull Day A',
        sessions: [{ title: 'Pull-ups & rows 4×8', type: 'workout', duration_minutes: 45 }],
      },
      {
        day_number: 3,
        title: 'Rest',
        sessions: [{ title: 'Active recovery walk', type: 'rest', duration_minutes: 20 }],
      },
      {
        day_number: 4,
        title: 'Leg Day A',
        sessions: [
          { title: 'Squat 4×8 + Romanian deadlift', type: 'workout', duration_minutes: 50 },
          { title: 'Post-leg meal', type: 'meal', description: 'Rice, chicken, broccoli — 700 kcal.' },
        ],
      },
    ],
  },
  {
    week_number: 2,
    title: 'Progressive Overload',
    description: 'Add 2.5 kg to each lift from Week 1.',
    days: [
      {
        day_number: 1,
        title: 'Push Day B',
        sessions: [{ title: 'Incline press & dips', type: 'workout', duration_minutes: 50 }],
      },
      {
        day_number: 2,
        title: 'Pull Day B',
        sessions: [{ title: 'Weighted pull-ups & seated cable row', type: 'workout', duration_minutes: 50 }],
      },
      {
        day_number: 3,
        title: 'Leg Day B',
        sessions: [{ title: 'Front squat & leg press', type: 'workout', duration_minutes: 55 }],
      },
      {
        day_number: 4,
        title: 'Rest',
        sessions: [{ title: 'Foam rolling & mobility', type: 'rest', duration_minutes: 25 }],
      },
    ],
  },
];

const HEALTHY_HABITS_WEEKS = [
  {
    week_number: 1,
    title: 'Awareness Week',
    description: 'Track what you eat and move gently every day.',
    days: [
      {
        day_number: 1,
        title: 'Start Strong',
        sessions: [
          { title: '10-min morning walk', type: 'workout', duration_minutes: 10 },
          { title: 'Mindful eating intro', type: 'article', description: 'Eat without screens for one meal today.' },
          { title: 'Balanced breakfast', type: 'meal', description: 'Oats, berries, nuts — 350 kcal.' },
        ],
      },
      {
        day_number: 2,
        title: 'Hydration Day',
        sessions: [
          { title: 'Drink 8 glasses of water', type: 'article' },
          { title: 'Light stretching', type: 'workout', duration_minutes: 15 },
        ],
      },
      {
        day_number: 3,
        title: 'Sleep Habits',
        sessions: [
          { title: 'Sleep hygiene tips', type: 'video', duration_minutes: 7 },
          { title: 'Rest day', type: 'rest' },
        ],
      },
    ],
  },
  {
    week_number: 2,
    title: 'Building Routines',
    description: 'Lock in your morning and evening rituals.',
    days: [
      {
        day_number: 1,
        title: 'Morning Ritual',
        sessions: [
          { title: '15-min yoga', type: 'workout', duration_minutes: 15 },
          { title: 'Journaling prompt', type: 'article', description: "Write 3 things you're grateful for." },
        ],
      },
      {
        day_number: 2,
        title: 'Nutrition Audit',
        sessions: [
          { title: 'Review your food log', type: 'article' },
          { title: 'Prep healthy snacks', type: 'meal', description: 'Hummus, carrot sticks, apple with nut butter.' },
        ],
      },
      {
        day_number: 3,
        title: 'Evening Wind-down',
        sessions: [
          { title: '10-min evening walk', type: 'workout', duration_minutes: 10 },
          { title: 'Digital sunset hour', type: 'rest' },
        ],
      },
    ],
  },
  {
    week_number: 3,
    title: 'Consistency is Key',
    description: 'Solidify your habits and celebrate progress.',
    days: [
      {
        day_number: 1,
        title: 'Habit Stacking',
        sessions: [
          { title: 'Combine 2 habits from Week 1 & 2', type: 'article' },
          { title: 'Balanced lunch', type: 'meal', description: 'Salad with protein + whole grain roll.' },
        ],
      },
      {
        day_number: 2,
        title: 'Active Day',
        sessions: [{ title: '20-min light jog', type: 'workout', duration_minutes: 20 }],
      },
      {
        day_number: 3,
        title: 'Celebrate!',
        sessions: [
          { title: 'Reflect on 21-day journey', type: 'article' },
          { title: 'Treat yourself to a healthy reward meal', type: 'meal' },
        ],
      },
    ],
  },
];

function contentForTitle(title) {
  if (title.includes('Fat Burn')) return FAT_BURN_WEEKS;
  if (title.includes('Lean Muscle')) return LEAN_MUSCLE_WEEKS;
  if (title.includes('Healthy Habits')) return HEALTHY_HABITS_WEEKS;
  return null;
}

/**
 * seedDemoContent() — BLK-09 fix. Callable by any authenticated user
 * (assertCallable, not admin-gated — matches the old app-start trigger's
 * reach exactly); safe because every write is fixed content behind an
 * idempotent marker, never influenced by the caller in any way.
 */
exports.seedDemoContent = functions.https.onCall(async (data, context) => {
  assertCallable(context);
  const db = admin.firestore();
  const seedRef = db.collection('seeds').doc('demo');

  const seedSnap = await seedRef.get();
  const seedData = seedSnap.exists ? (seedSnap.data() || {}) : {};

  let seededPrograms = 0;
  if (seedData[SEED_KEY] !== true) {
    const now = admin.firestore.FieldValue.serverTimestamp();
    const batch = db.batch();
    for (const program of DEMO_PROGRAMS) {
      batch.set(db.collection('programs').doc(), {
        ...program,
        is_demo: true,
        created_at: now,
        updated_at: now,
      });
    }
    batch.set(seedRef, { [SEED_KEY]: true }, { merge: true });
    await batch.commit();
    seededPrograms = DEMO_PROGRAMS.length;
    functions.logger.info('seedDemoContent: seeded demo programs', { count: seededPrograms });
  }

  let seededContentFor = 0;
  if (seedData[CONTENT_SEED_KEY] !== true) {
    const demoProgramsSnap = await db.collection('programs').where('coach_uid', '==', 'demo').get();
    for (const progDoc of demoProgramsSnap.docs) {
      const title = progDoc.data().title || '';
      const weeks = contentForTitle(title);
      if (!weeks) continue;
      // eslint-disable-next-line no-await-in-loop
      const existingWeeks = await progDoc.ref.collection('weeks').limit(1).get();
      if (!existingWeeks.empty) continue;
      const batch = db.batch();
      for (const week of weeks) {
        batch.set(progDoc.ref.collection('weeks').doc(), week);
      }
      // eslint-disable-next-line no-await-in-loop
      await batch.commit();
      seededContentFor++;
    }
    await seedRef.set({ [CONTENT_SEED_KEY]: true }, { merge: true });
    functions.logger.info('seedDemoContent: seeded program content', { programs: seededContentFor });
  }

  return { ok: true, seededPrograms, seededContentFor };
});
