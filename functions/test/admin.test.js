'use strict';

// Unit tests for the pure logic inside admin.js -- diffDocs specifically.
// syncAdminClaim/logAdminUsersChange themselves are Firestore triggers
// (Admin SDK + functions.firestore.document(...).onWrite), which this repo
// doesn't have a harness for (rules.test.mjs's emulator only exercises
// firestore.rules, not Cloud Functions triggers) -- same scope boundary as
// app_config_admin.test.js's own header comment.
//
//   node --test functions/test/admin.test.js

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const { diffDocs, actorUidFromWrite } = require('../admin');

describe('diffDocs', () => {
  test('no before, some after: every field is a from:null diff', () => {
    assert.deepEqual(diffDocs(null, { role: 'owner', status: 'active' }), [
      { key: 'role', from: null, to: 'owner' },
      { key: 'status', from: null, to: 'active' },
    ]);
  });

  test('some before, no after: every field is a to:null diff', () => {
    assert.deepEqual(diffDocs({ is_admin: true }, null), [
      { key: 'is_admin', from: true, to: null },
    ]);
  });

  test('identical before/after produces an empty diff', () => {
    assert.deepEqual(diffDocs({ role: 'owner' }, { role: 'owner' }), []);
  });

  test('only changed keys appear, unchanged sibling keys are excluded', () => {
    const before = { role: 'support', status: 'active', permissions_version: 1 };
    const after = { role: 'owner', status: 'active', permissions_version: 1 };
    assert.deepEqual(diffDocs(before, after), [{ key: 'role', from: 'support', to: 'owner' }]);
  });

  test('array-valued fields (grants/denials) diff by value, not reference', () => {
    assert.deepEqual(diffDocs({ grants: ['a', 'b'] }, { grants: ['a', 'b'] }), []);
    assert.deepEqual(
      diffDocs({ grants: ['a'] }, { grants: ['a', 'b'] }),
      [{ key: 'grants', from: ['a'], to: ['a', 'b'] }]
    );
  });

  test('both null (a delete-of-nonexistent edge case) produces an empty diff', () => {
    assert.deepEqual(diffDocs(null, null), []);
  });
});

describe('actorUidFromWrite', () => {
  test('returns last_changed_by when the write set it (the admin_users Server Action path)', () => {
    assert.equal(actorUidFromWrite({ role: 'owner', last_changed_by: 'uid-1' }), 'uid-1');
  });

  test('returns null when last_changed_by is absent (a Console/Admin-SDK-direct write)', () => {
    assert.equal(actorUidFromWrite({ role: 'owner' }), null);
  });

  test('returns null for a delete (after is null)', () => {
    assert.equal(actorUidFromWrite(null), null);
  });
});
