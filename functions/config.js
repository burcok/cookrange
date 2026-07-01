'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Environment gating. Set APP_ENV in functions/.env (or .env.<projectId>).
//   development (default): prod-only requirements are relaxed — App Check is
//     NOT enforced and store-purchase validation is inert if creds are absent,
//     so functions deploy + run without Apple/Google credentials.
//   production: App Check is enforced and purchase validation requires the
//     store credentials.
// APP_CHECK_ENFORCE can override the App Check decision explicitly ('true' /
// 'false') regardless of APP_ENV.
// ─────────────────────────────────────────────────────────────────────────────

const APP_ENV = (process.env.APP_ENV || 'development').toLowerCase();
const IS_PROD = APP_ENV === 'production';

const APP_CHECK_ENFORCE =
  process.env.APP_CHECK_ENFORCE === 'true'
    ? true
    : process.env.APP_CHECK_ENFORCE === 'false'
      ? false
      : IS_PROD;

module.exports = { APP_ENV, IS_PROD, APP_CHECK_ENFORCE };
