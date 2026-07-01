'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Uploaded-image safety scan. On every new image in a user-content prefix, runs
// Cloud Vision SafeSearch and DELETES adult/violent/racy uploads. EXIF/GPS is
// already stripped client-side before upload (StorageUploadService), so this
// function only moderates content — it does not re-encode (which would rotate
// download tokens and break stored URLs).
//
// Best-effort: if the Cloud Vision API is not enabled (e.g. development), the
// image is kept and a warning is logged. Enable Cloud Vision in production to
// activate enforcement.
// ─────────────────────────────────────────────────────────────────────────────

const functions = require('firebase-functions');
const admin = require('firebase-admin');

let visionClient = null;
try {
  // eslint-disable-next-line global-require
  const vision = require('@google-cloud/vision');
  visionClient = new vision.ImageAnnotatorClient();
} catch (e) {
  visionClient = null;
}

// PUBLIC content only — these are broadcast to all users, so the legal/policy
// risk is highest. Private 1:1 chat images are NOT proactively scanned: they are
// restricted to the two participants, high-volume, and best handled reactively
// (on report). This keeps Cloud Vision spend low.
const SCAN_PREFIXES = [
  'post_images/',
  'profile_photos/',
  'gyms/',
];
const UNSAFE = ['LIKELY', 'VERY_LIKELY'];

// HARD cost ceiling: never call Cloud Vision more than this many times per day,
// no matter the upload volume or abuse. Tune via VISION_DAILY_CAP in
// functions/.env. At ~$1.5 / 1000 images, a cap of 1000/day bounds worst-case
// spend to roughly $1.5/day.
const VISION_DAILY_CAP = parseInt(process.env.VISION_DAILY_CAP || '1000', 10);

/// Returns true if today's scan count is under the cap (and reserves one slot).
async function underDailyCap() {
  const db = admin.firestore();
  const ref = db.collection('system').doc('vision_usage');
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
  try {
    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const d = snap.exists ? snap.data() || {} : {};
      const count = d.date === today ? d.count || 0 : 0;
      if (count >= VISION_DAILY_CAP) return false;
      tx.set(ref, { date: today, count: count + 1 }, { merge: true });
      return true;
    });
  } catch (e) {
    // Fail SAFE on counter errors: skip the scan rather than risk runaway cost.
    functions.logger.warn('scanImage: cap check failed — skipping scan', {
      error: e.message,
    });
    return false;
  }
}

exports.scanImage = functions
  .runWith({ memory: '512MB', timeoutSeconds: 60 })
  .storage.object()
  .onFinalize(async (object) => {
    const name = object.name || '';
    const contentType = object.contentType || '';

    if (!contentType.startsWith('image/')) return;
    if (!SCAN_PREFIXES.some((p) => name.startsWith(p))) return;

    if (!visionClient) {
      functions.logger.warn(
        'scanImage: Cloud Vision unavailable — skipping scan',
        { name }
      );
      return;
    }

    // Enforce the hard daily spend ceiling BEFORE calling the paid API.
    if (!(await underDailyCap())) {
      functions.logger.warn('scanImage: daily Vision cap reached — skipping', {
        name,
      });
      return;
    }

    try {
      const [res] = await visionClient.safeSearchDetection(
        `gs://${object.bucket}/${name}`
      );
      const s = (res && res.safeSearchAnnotation) || {};
      const unsafe =
        UNSAFE.includes(s.adult) ||
        UNSAFE.includes(s.violence) ||
        UNSAFE.includes(s.racy);

      if (unsafe) {
        functions.logger.warn('scanImage: unsafe content deleted', {
          name,
          adult: s.adult,
          violence: s.violence,
          racy: s.racy,
        });
        await admin
          .storage()
          .bucket(object.bucket)
          .file(name)
          .delete()
          .catch((e) =>
            functions.logger.error('scanImage: delete failed', {
              name,
              error: e.message,
            })
          );
      } else {
        functions.logger.info('scanImage: clean', { name });
      }
    } catch (e) {
      // Vision API not enabled / transient error → keep the image, log it.
      functions.logger.warn('scanImage: SafeSearch failed (image kept)', {
        name,
        error: e.message,
      });
    }
  });
