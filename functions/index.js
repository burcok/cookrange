'use strict';

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const fetch = require('node-fetch');

admin.initializeApp();

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const DEFAULT_MODEL = 'tngtech/deepseek-r1t-chimera:free';

/**
 * AI proxy endpoint — keeps OPENROUTER_API_KEY server-side.
 *
 * Set the secret before deploying:
 *   firebase functions:secrets:set OPENROUTER_API_KEY
 *
 * Request body (JSON):
 *   { messages: [...], model?: string, temperature?: number }
 *
 * Authorization:
 *   Bearer <Firebase ID token>
 */
exports.aiProxy = functions
  .runWith({ secrets: ['OPENROUTER_API_KEY'] })
  .https.onRequest(async (req, res) => {
    // CORS headers (Flutter app uses HTTPS, not a browser, so this is minimal)
    res.set('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'POST');
      res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    // Verify Firebase ID token
    const authHeader = req.headers.authorization || '';
    const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization header' });
      return;
    }

    try {
      await admin.auth().verifyIdToken(idToken);
    } catch (e) {
      res.status(401).json({ error: 'Invalid or expired ID token' });
      return;
    }

    // Verify App Check token (if present — clients without App Check still work
    // during rollout; enforce strictly once all clients are updated).
    const appCheckToken = req.headers['x-firebase-appcheck'];
    if (appCheckToken) {
      try {
        await admin.appCheck().verifyToken(appCheckToken);
      } catch (e) {
        functions.logger.warn('App Check token verification failed', e);
        res.status(401).json({ error: 'Invalid App Check token' });
        return;
      }
    }

    const { messages, model, temperature } = req.body || {};
    if (!Array.isArray(messages) || messages.length === 0) {
      res.status(400).json({ error: 'messages array is required' });
      return;
    }

    const apiKey = process.env.OPENROUTER_API_KEY;
    if (!apiKey) {
      functions.logger.error('OPENROUTER_API_KEY secret not set');
      res.status(500).json({ error: 'AI proxy not configured' });
      return;
    }

    try {
      const upstream = await fetch(OPENROUTER_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
          'HTTP-Referer': 'https://cookrangeapp.com',
          'X-Title': 'Cookrange',
        },
        body: JSON.stringify({
          model: model || DEFAULT_MODEL,
          messages,
          temperature: temperature ?? 0.7,
        }),
      });

      const data = await upstream.json();

      if (!upstream.ok) {
        functions.logger.warn('OpenRouter error', { status: upstream.status, data });
        res.status(upstream.status).json(data);
        return;
      }

      res.status(200).json(data);
    } catch (e) {
      functions.logger.error('aiProxy fetch error', e);
      res.status(502).json({ error: 'Upstream AI request failed' });
    }
  });
