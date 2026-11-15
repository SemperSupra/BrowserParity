import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

// Exact upstream official Violentmonkey source. No production tabs, profiles,
// credentials, userscripts, or BrowserParity private files enter this test.
const file = process.env.VM_GRANT_SOURCE;
assert.ok(file, 'VM_GRANT_SOURCE is required');
const code = fs.readFileSync(file, 'utf8');
const sourceUrl = 'data:text/javascript;base64,' + Buffer.from(code).toString('base64');
const { grantTab, revokeTab, hasGrant, listGrants } = await import(sourceUrl);

test('a foreign/adjacent tab is not granted', () => {
  assert.equal(hasGrant(82), false);
  grantTab(81);
  assert.equal(hasGrant(81), true);
  assert.equal(hasGrant(82), false);
});

test('negative tab identifiers are refused', () => {
  grantTab(-1);
  assert.equal(hasGrant(-1), false);
  assert.equal(listGrants().includes(-1), false);
});

test('revocation denies subsequent calls', () => {
  assert.equal(revokeTab(81), true);
  assert.equal(hasGrant(81), false);
  assert.equal(revokeTab(81), false);
});

test('grant enumeration reflects only currently granted tabs', () => {
  grantTab(91);
  grantTab(92);
  assert.deepEqual(listGrants().slice().sort((a, b) => a - b), [91, 92]);
  revokeTab(91);
  revokeTab(92);
  assert.deepEqual(listGrants(), []);
});

test('upstream grant API offers tab-ID semantics, not action/effect admission', () => {
  assert.equal(typeof grantTab, 'function');
  assert.equal(typeof revokeTab, 'function');
  // Deliberately do not treat this interface as full origin/effect authority.
  assert.equal(grantTab.length, 1);
});
