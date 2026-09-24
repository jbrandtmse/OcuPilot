import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins `core/theme.ts` (Story 15.6): light until the instance's read settles, the remembered
// theme adopted once and without a write, a toggle that flips the root class at once and writes
// once, and sign-out back to light.
//
// Mutations (Rule 19):
// - make `adoptRemembered` ignore the stored value -> "dark is adopted once" goes red.
// - drop the `account.setValue` call in `setTheme` -> "a toggle ... writes once" goes red.
// - make `endSession` return early -> "endSession removes the class" goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { ThemeState, THEME_DARK_CLASS } = await import(join(uiRoot, 'src', 'app', 'core', 'theme.ts'));
const { AccountPreferences, SHELL_THEME, THEME_DARK, THEME_LIGHT } = await import(
  join(uiRoot, 'src', 'app', 'core', 'account-preferences.ts')
);
const { stubAccountPreferences, settledAccountPreferences, lastRemembered, SHELL_SIDE_BAR_OPEN, SHELL_KIND } =
  await import(new URL('../src/app/testing/account-preferences.ts', import.meta.url).href);

/** A stand-in for `document.documentElement`: a class list and nothing else. */
function fakeRoot() {
  const classes = new Set();
  return {
    classes,
    classList: {
      toggle(token, force) {
        const on = force ?? !classes.has(token);
        if (on) classes.add(token);
        else classes.delete(token);
        return on;
      },
    },
  };
}

/** The theme writes the stubbed transport was asked for. */
function themeWrites(account) {
  return account.calls.filter((call) => call.method === 'POST' && call.body !== null && JSON.parse(call.body).name === SHELL_THEME);
}

async function flush() {
  await new Promise((resolve) => setTimeout(resolve, 0));
}

test('the published default is light, and it stands while the read has not settled', () => {
  const account = stubAccountPreferences({ shell: { [SHELL_THEME]: THEME_DARK } });
  const root = fakeRoot();
  const theme = new ThemeState({ account, root });
  assert.equal(account.loaded(), false);
  assert.equal(theme.theme(), THEME_LIGHT);
  assert.equal(theme.isDark(), false);
  assert.equal(root.classes.has(THEME_DARK_CLASS), false, 'no class before the read settles');
});

test('a read that fails keeps light', async () => {
  const account = new AccountPreferences({
    api: { requestJson: async () => ({ kind: 'error', status: 0, code: null, reason: null, detail: null }) },
  });
  const root = fakeRoot();
  const theme = new ThemeState({ account, root });
  await account.load();
  assert.equal(theme.theme(), THEME_LIGHT);
  assert.equal(root.classes.has(THEME_DARK_CLASS), false);
});

test('dark is adopted once from the settled read, sets the class, and writes nothing', async () => {
  const account = stubAccountPreferences({ shell: { [SHELL_THEME]: THEME_DARK } });
  const root = fakeRoot();
  const theme = new ThemeState({ account, root });
  let notified = 0;
  theme.subscribe(() => {
    notified += 1;
  });
  await account.load();
  assert.equal(theme.theme(), THEME_DARK);
  assert.equal(root.classes.has(THEME_DARK_CLASS), true, 'the root carries the dark class');
  assert.equal(notified, 1, 'one notification for the one adoption');
  assert.deepEqual(themeWrites(account), [], 'adopting writes nothing');

  // Once: the user's own choice is not undone by a later, unrelated preference answer.
  theme.toggle();
  assert.equal(theme.theme(), THEME_LIGHT);
  await account.setValue(SHELL_KIND, SHELL_SIDE_BAR_OPEN, '0');
  await flush();
  assert.equal(theme.theme(), THEME_LIGHT, 'a later answer does not re-apply the remembered theme');
  assert.equal(root.classes.has(THEME_DARK_CLASS), false);
});

test('a toggle flips the class at once and writes the choice once', async () => {
  const account = await settledAccountPreferences();
  const root = fakeRoot();
  const theme = new ThemeState({ account, root });
  assert.equal(theme.theme(), THEME_LIGHT);

  theme.toggle();
  assert.equal(root.classes.has(THEME_DARK_CLASS), true, 'the class is set before any answer');
  assert.equal(theme.isDark(), true);
  assert.equal(themeWrites(account).length, 1, 'one write');
  assert.equal(lastRemembered(account.calls, SHELL_THEME), THEME_DARK, 'naming dark');
  await flush();

  theme.toggle();
  assert.equal(root.classes.has(THEME_DARK_CLASS), false);
  await flush();
  assert.equal(themeWrites(account).length, 2);
  assert.equal(lastRemembered(account.calls, SHELL_THEME), THEME_LIGHT);

  theme.setTheme(THEME_LIGHT);
  assert.equal(themeWrites(account).length, 2, 'choosing the theme already on screen writes nothing');
});

test('light on a settled read with no row writes nothing either', async () => {
  const account = await settledAccountPreferences();
  const theme = new ThemeState({ account, root: fakeRoot() });
  assert.equal(theme.theme(), THEME_LIGHT);
  assert.deepEqual(themeWrites(account), []);
});

test('endSession removes the class, and the next principal adopts their own answer', async () => {
  const account = stubAccountPreferences({ shell: { [SHELL_THEME]: THEME_DARK } });
  const root = fakeRoot();
  const theme = new ThemeState({ account, root });
  await account.load();
  assert.equal(root.classes.has(THEME_DARK_CLASS), true);

  theme.endSession();
  account.reset();
  assert.equal(theme.theme(), THEME_LIGHT);
  assert.equal(root.classes.has(THEME_DARK_CLASS), false, 'back to light before the next read');

  await account.load();
  assert.equal(theme.theme(), THEME_DARK, "the next sign-in's read is adopted in its turn");
});

test('an unknown stored value reads as light', async () => {
  const account = await settledAccountPreferences({ shell: { [SHELL_THEME]: 'purple' } });
  const root = fakeRoot();
  const theme = new ThemeState({ account, root });
  assert.equal(theme.theme(), THEME_LIGHT);
  assert.equal(root.classes.has(THEME_DARK_CLASS), false);
});

test('a refused theme write surfaces through the store fault and leaves the chosen theme on screen', async () => {
  const account = await settledAccountPreferences({ writeAnswer: 'refused', refusalReason: 'That preference takes one of a fixed set of values.' });
  const root = fakeRoot();
  const theme = new ThemeState({ account, root });
  assert.equal(account.fault(), '');
  theme.toggle();
  await flush();
  assert.equal(account.fault(), 'That preference takes one of a fixed set of values.', "the instance's sentence reaches fault()");
  assert.equal(theme.theme(), THEME_DARK, 'the refusal does not undo the choice');
  assert.equal(root.classes.has(THEME_DARK_CLASS), true);
});
