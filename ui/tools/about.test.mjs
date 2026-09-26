// Pins the four framework-free halves of Story 15.3: the About store's late-answer guard and its
// hold on a transport failure, the help resolver's three answers, the shortcuts roster's drop of a
// route no built screen declares, and `isStale`'s refusal to call anything stale when either side
// is empty. All four are decided in `core/`, which is where `node --test` can execute them --
// jsdom has no layout and the browser tier has no way to make a read fail on demand.
//
// Mutations (Rule 19):
// - drop the `if (request !== this.request) return;` guard in `About.load` -> the "a late answer
//   does not overwrite a newer one" row goes red.
// - drop the `if (result.kind !== 'ok')` park in `About.load` -> the "a failed read leaves the
//   previous answer standing" row goes red, and an offline About would blank its thirteen fields.
// - make `helpHrefFor` ignore `available` -> the "an unavailable answer resolves to no address"
//   row goes red, and a screen whose classic page publishes no address would get a control whose
//   href is empty.
// - make `shortcutScreens` return `SHORTCUT_ROUTES.map(screenForRoute)` without dropping the
//   nulls -> the "a route no built screen declares is dropped" row goes red. Dropping the
//   `!screen.built` half alone would NOT redden it: every screen the shipped mirror declares is
//   built, so the seven roster routes it does not resolve return null, and null is what that
//   filter's other half rejects.
// - make `isStale` compare unconditionally -> the "either side empty is never stale" row goes red,
//   and every dev serve would carry the reload prompt.
// - restore `isStale`'s empty-string guard in place of the bundle-name guard -> the "compares two
//   bundle names and nothing else" row goes red, and an instance whose row carries the installer's
//   "dev" fallback would show every tab a reload prompt that reloading cannot clear.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { About, ABOUT_PATH, ABOUT_FIELDS, ABOUT_LINKS } = await import(core('about.ts'));
const { HelpLinks, HELP_PATH, hasClassicPage, helpHrefFor } = await import(core('help.ts'));
const { SHORTCUT_KEYS, SHORTCUT_ROUTES, shortcutScreens } = await import(core('shortcuts.ts'));
const { STRINGS } = await import(core('strings.ts'));
const { bundleIdentity, isStale } = await import(core('build-identity.ts'));
const { screenForRoute } = await import(core('navigation.ts'));

/** An answer in the shape `GET /ui/about` publishes. */
function aboutBody(overrides = {}) {
  const body = {};
  for (const field of ABOUT_FIELDS) body[field] = `${field}-value`;
  body.links = {};
  for (const link of ABOUT_LINKS) body.links[link] = `https://ocupilot.invalid/${link}`;
  return { ...body, ...overrides };
}

function ok(value) {
  return { kind: 'ok', status: 200, body: value };
}

function transportError() {
  return { kind: 'error', status: 0, code: null, reason: null, detail: null };
}

/** A stub API whose every call resolves from a queue, recording what was asked. */
function stubApi(answers) {
  const calls = [];
  const queue = [...answers];
  return {
    calls,
    requestJson(path, init = {}) {
      calls.push({ path, method: init.method ?? 'GET' });
      const next = queue.length > 1 ? queue.shift() : queue[0];
      return Promise.resolve(next);
    },
  };
}

/** A stub API each of whose calls is settled by hand, so two can be in flight at once. */
function deferredApi() {
  const pending = [];
  return {
    pending,
    requestJson(path) {
      let settle;
      const promise = new Promise((resolve) => {
        settle = resolve;
      });
      pending.push({ path, settle });
      return promise;
    },
  };
}

// --- core/about.ts --------------------------------------------------------------

test('a read settles all thirteen members and the three links, and notifies once', async () => {
  const api = stubApi([ok(aboutBody())]);
  const store = new About({ api });
  let notified = 0;
  store.subscribe(() => (notified += 1));

  assert.equal(store.answered(), false);
  await store.load();

  assert.equal(store.answered(), true);
  assert.equal(store.failed(), false);
  assert.equal(notified, 1);
  assert.equal(api.calls[0].path, ABOUT_PATH);
  assert.equal(api.calls[0].method, 'GET');
  for (const field of ABOUT_FIELDS) assert.equal(store.fields()[field], `${field}-value`);
  for (const link of ABOUT_LINKS) assert.equal(store.links()[link], `https://ocupilot.invalid/${link}`);
});

test('a member the instance could not report reads as the empty string, never as absent', async () => {
  const api = stubApi([ok(aboutBody({ journalFile: '', encryptionKeyId: '' }))]);
  const store = new About({ api });
  await store.load();
  assert.equal(store.fields().journalFile, '');
  assert.equal(store.fields().encryptionKeyId, '');
  assert.equal(store.fields().version, 'version-value');
  assert.ok('journalFile' in store.fields(), 'the member is still a key the dialog renders a row for');
});

test('a member the answer does not shape as a string is dropped to empty rather than rendered', async () => {
  const api = stubApi([ok({ ...aboutBody(), superServerPort: 1972, links: null })]);
  const store = new About({ api });
  await store.load();
  assert.equal(store.fields().superServerPort, '');
  for (const link of ABOUT_LINKS) assert.equal(store.links()[link], '');
});

test('a failed read leaves the previous answer standing and says the read failed', async () => {
  const api = stubApi([ok(aboutBody()), transportError()]);
  const store = new About({ api });
  await store.load();
  await store.load();

  assert.equal(store.answered(), true, 'the answer it had is still an answer');
  assert.equal(store.failed(), true, 'and the failure is reported');
  assert.equal(store.fields().version, 'version-value', 'with the previous values still held');
});

test('a failed read with nothing held is what the dialog renders its error state from', async () => {
  const api = stubApi([transportError()]);
  const store = new About({ api });
  let notified = 0;
  store.subscribe(() => (notified += 1));
  await store.load();
  assert.equal(store.answered(), false);
  assert.equal(store.failed(), true);
  assert.equal(notified, 1, 'and the dialog is told once');
  await store.load();
  assert.equal(notified, 1, 'a second failure re-announces nothing');
});

test('a late answer does not overwrite a newer one', async () => {
  const api = deferredApi();
  const store = new About({ api });
  const first = store.load();
  const second = store.load();
  assert.equal(api.pending.length, 2, 'both reads are in flight');

  // The newer read settles first, then the older one answers with what it fetched earlier.
  api.pending[1].settle(ok(aboutBody({ version: 'newest' })));
  await second;
  api.pending[0].settle(ok(aboutBody({ version: 'stale' })));
  await first;

  assert.equal(store.fields().version, 'newest');
});

test('reset forgets the answer, so the next read asks again', async () => {
  const api = stubApi([ok(aboutBody())]);
  const store = new About({ api });
  await store.load();
  store.reset();
  assert.equal(store.answered(), false);
  assert.equal(store.fields().version, '');
  assert.equal(store.links().documentation, '');
});

test('an answer already on the wire when reset ran settles nothing', async () => {
  const api = deferredApi();
  const store = new About({ api });
  const pending = store.load();
  store.reset();
  api.pending[0].settle(ok(aboutBody()));
  await pending;
  assert.equal(store.answered(), false, 'a departed principal\u2019s answer never lands on the next one');
});

// --- core/help.ts ---------------------------------------------------------------

test('hasClassicPage reads the mirror, so a screen with no classic equivalent costs no request', () => {
  const withPage = screenForRoute('permissions/users');
  assert.ok(withPage !== null && withPage.classicPage !== '', 'the Users list declares a classic page');
  assert.equal(hasClassicPage('permissions/users'), true);

  const without = screenForRoute('agent/definitions');
  assert.ok(without !== null && without.classicPage === '', 'the Definitions list declares none');
  assert.equal(hasClassicPage('agent/definitions'), false);

  assert.equal(hasClassicPage(''), false, "Home's own empty route asks for nothing");
  assert.equal(hasClassicPage('no-such-area/no-such-screen'), false);
});

test('helpHrefFor answers the resolved address, and nothing for an unavailable or refused answer', async () => {
  const available = stubApi([ok({ available: true, href: 'https://docs.invalid/page?KEY=A%2CB' })]);
  assert.equal(
    await helpHrefFor(available, 'permissions/users'),
    'https://docs.invalid/page?KEY=A%2CB'
  );
  assert.equal(available.calls[0].path, `${HELP_PATH}?route=permissions%2Fusers`);

  const unavailable = stubApi([ok({ available: false, href: '' })]);
  assert.equal(await helpHrefFor(unavailable, 'logs/alerts'), '');

  const refused = stubApi([{ kind: 'error', status: 422, code: 'HELP.ROUTE', reason: 'no', detail: null }]);
  assert.equal(await helpHrefFor(refused, 'no-such-area/no-such-screen'), '');
});

test('HelpLinks asks once per screen, and never for a screen the mirror says has no classic page', async () => {
  const api = stubApi([ok({ available: true, href: 'https://docs.invalid/page' })]);
  const links = new HelpLinks({ api });
  let notified = 0;
  links.subscribe(() => (notified += 1));

  await links.load('permissions/users');
  await links.load('permissions/users');
  assert.equal(api.calls.length, 1, 'a screen visited twice is asked for once');
  assert.equal(links.hrefFor('permissions/users'), 'https://docs.invalid/page');
  assert.equal(notified, 1);

  await links.load('agent/definitions');
  assert.equal(api.calls.length, 1, 'a screen with no classic page is never asked for');
  assert.equal(links.hrefFor('agent/definitions'), '');

  links.reset();
  assert.equal(links.hrefFor('permissions/users'), '');
});

// --- core/shortcuts.ts ----------------------------------------------------------

test('the shortcuts roster is the classic menu\u2019s seventeen, in its order', () => {
  assert.equal(SHORTCUT_ROUTES.length, 17);
  assert.equal(new Set(SHORTCUT_ROUTES).size, 17, 'and each appears once');
});

test('a roster route no built screen declares is dropped, and the rest keep roster order', () => {
  const resolved = shortcutScreens();
  const routes = resolved.map((screen) => screen.route);

  assert.ok(routes.length > 0, 'some of the roster is built today');
  assert.ok(routes.length < SHORTCUT_ROUTES.length, 'and some of it is not');
  for (const route of routes) {
    const screen = screenForRoute(route);
    assert.ok(screen !== null && screen.built, `${route} names a built screen`);
  }
  for (const route of SHORTCUT_ROUTES) {
    const screen = screenForRoute(route);
    const built = screen !== null && screen.built;
    assert.equal(routes.includes(route), built, `${route} is rendered exactly when it is built`);
  }
  // Order is the roster's, not the mirror's.
  const wanted = SHORTCUT_ROUTES.filter((route) => routes.includes(route));
  assert.deepEqual(routes, wanted);
});

test('every rendered shortcut carries a labelKey the mirror resolves, so none adds a string', () => {
  for (const screen of shortcutScreens()) {
    assert.notEqual(screen.labelKey, '', `${screen.route} names a label key`);
  }
});

// Story 15.8: the one key binding the block lists after its screen rows, by its two string keys.
// Mutation (Rule 19): point `keysKey` at a key the source does not hold -> this goes red.
test('the Shortcuts key bindings are the column resize, each naming a label and keys the string source holds', () => {
  assert.deepEqual(SHORTCUT_KEYS, [{ labelKey: 'tableColumnResizeShortcut', keysKey: 'tableColumnResizeKeys' }]);
  for (const binding of SHORTCUT_KEYS) {
    assert.ok(Object.hasOwn(STRINGS, binding.labelKey), `${binding.labelKey} is a key`);
    assert.ok(Object.hasOwn(STRINGS, binding.keysKey), `${binding.keysKey} is a key`);
  }
  assert.equal(STRINGS.tableColumnResizeKeys, 'Alt/Option+Shift+Left or Right');
});

// --- core/build-identity.ts -----------------------------------------------------

/** A document-like carrying the given script sources. */
function scriptSource(sources) {
  return {
    querySelectorAll: () => sources.map((src) => ({ getAttribute: () => src })),
  };
}

test('bundleIdentity reads the hashed main filename out of the document, whatever the src shape', () => {
  assert.equal(bundleIdentity(scriptSource(['/ocupilot/main-ABC123.js'])), 'main-ABC123.js');
  assert.equal(bundleIdentity(scriptSource(['main-ABC123.js?v=1'])), 'main-ABC123.js');
  assert.equal(
    bundleIdentity(scriptSource(['/ocupilot/polyfills-XYZ.js', '/ocupilot/main-ABC123.js'])),
    'main-ABC123.js'
  );
  assert.equal(bundleIdentity(scriptSource(['/ocupilot/main.js'])), '', 'an unhashed main names nothing');
  assert.equal(bundleIdentity(scriptSource([])), '');
  assert.equal(bundleIdentity(null), '', 'and outside a browser there is nothing to read');
});

test('isStale is false whenever either side is empty -- absence is not a mismatch', () => {
  assert.equal(isStale('', 'main-ABC123.js'), false, 'an instance that cannot say what it installed');
  assert.equal(isStale('main-ABC123.js', ''), false, 'a dev serve with no hashed main');
  assert.equal(isStale('', ''), false);
});

test('isStale compares two bundle names and nothing else -- the installer fallback is not one', () => {
  // `Installer.BundleIdentity` records BUILDIDENTITY ("dev") when the install deployed no hashed
  // main. Comparing it would report a permanent mismatch no reload could clear against a browser
  // that did load a bundle -- the state the documented deploy-after-install workflow produces.
  assert.equal(isStale('dev', 'main-ABC123.js'), false, "the installer's fallback stamp is not a bundle name");
  assert.equal(isStale('main-ABC123.js', 'dev'), false, 'and neither is it on the browser side');
  assert.equal(isStale('main.js', 'main-ABC123.js'), false, 'an unhashed main names no bundle either');
});

test('isStale is true only when both sides are known and differ', () => {
  assert.equal(isStale('main-ABC123.js', 'main-ABC123.js'), false);
  assert.equal(isStale('main-NEW999.js', 'main-ABC123.js'), true);
});
