import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins DESIGN.md's Yield order at every width its table names, the resize bounds, and what the
// panel remembers (Story 4.3): `resolveLayout` and `PanelState` in `core/panel-layout.ts`.
//
// Mutations (Rule 19):
// - drop `input.sideBarReopened ||` from `resolveLayout` -> the reopen row goes red.
// - replace `Math.min(target, panelMax)` with `target` -> six tests go red: the 1,280 reopened, 1,024
//   and 900 rows, the clamped stored width, the reopen that writes no preference, and the unchanged step.
// - make `panelWidth` read `fallback` only for a missing value -> the unusable-stored-width rows go red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { resolveLayout, PanelState, PANEL_MIN_WIDTH, PANEL_DEFAULT_WIDTH, CONTENT_MIN_WIDTH } = await import(
  core('panel-layout.ts')
);
const { PreferenceStore, PANEL_WIDTH_KEY } = await import(core('preferences.ts'));
const { ShellState } = await import(core('shell-state.ts'));

function memoryStorage(seed = {}) {
  const map = new Map(Object.entries(seed));
  return {
    map,
    getItem: (k) => (map.has(k) ? map.get(k) : null),
    setItem: (k, v) => map.set(k, v),
    removeItem: (k) => map.delete(k),
  };
}

function layoutAt(viewport, overrides = {}) {
  return resolveLayout({
    viewport,
    sideBarPreferred: true,
    sideBarReopened: false,
    remembered: 400,
    fullScreen: false,
    ...overrides,
  });
}

/** A panel store over a shell whose side bar is open on an area with a screen list. */
function panelOver(storage = memoryStorage(), viewport = 1920) {
  const preferences = new PreferenceStore({ storage });
  const shell = new ShellState({ preferences });
  shell.setActiveArea('permissions');
  const panel = new PanelState({ preferences, shell });
  panel.setViewport(viewport);
  return { panel, shell, storage };
}

test('the widths DESIGN.md publishes: rail 48, side bar 240, content minimum 640, panel minimum 320, default 400', () => {
  assert.equal(PANEL_MIN_WIDTH, 320);
  assert.equal(PANEL_DEFAULT_WIDTH, 400);
  assert.equal(CONTENT_MIN_WIDTH, 640);
});

test('1,920px with the side bar open: nothing yields', () => {
  const layout = layoutAt(1920);
  assert.equal(layout.sideBarShown, true);
  assert.equal(layout.panelWidth, 400);
  assert.equal(layout.contentWidth, 1232);
  assert.equal(layout.contentScrolls, false);
});

test('1,280px with the side bar open by preference: the side bar yields first, and the panel keeps 400', () => {
  const layout = layoutAt(1280);
  assert.equal(layout.sideBarShown, false);
  assert.equal(layout.panelWidth, 400);
  assert.equal(layout.contentWidth, 832);
  assert.equal(layout.panelMax, 592, 'the 640px content point at 1,280px');
});

test('1,280px, reopened by the user: the panel takes the next concession, to 352, and content holds 640', () => {
  const layout = layoutAt(1280, { sideBarReopened: true });
  assert.equal(layout.sideBarShown, true);
  assert.equal(layout.panelWidth, 352);
  assert.equal(layout.contentWidth, 640);
  assert.equal(layout.panelMax, 352);
});

test('1,024px: side bar collapsed, panel shrinks to 336, content holds 640', () => {
  const layout = layoutAt(1024);
  assert.equal(layout.sideBarShown, false);
  assert.equal(layout.panelWidth, 336);
  assert.equal(layout.contentWidth, 640);
  assert.equal(layout.contentScrolls, false);
});

test('900px: panel at its minimum and a 532px content region that scrolls its 640px floor', () => {
  const layout = layoutAt(900);
  assert.equal(layout.sideBarShown, false);
  assert.equal(layout.panelWidth, 320);
  assert.equal(layout.contentWidth, 532);
  assert.equal(layout.contentScrolls, true);
  assert.equal(layout.panelMax, 320, 'both stops are the same width here');
});

test('a side bar the user closed takes no width at any viewport', () => {
  const layout = layoutAt(1280, { sideBarPreferred: false, sideBarReopened: true });
  assert.equal(layout.sideBarShown, false);
  assert.equal(layout.contentWidth, 832);
});

test('an unmeasured viewport yields nothing, so a first render never collapses a side bar it has not measured', () => {
  const layout = layoutAt(0);
  assert.equal(layout.sideBarShown, true);
  assert.equal(layout.panelWidth, 400);
});

test('the stored width is read back, and an absent, non-numeric or sub-minimum value reads as 400', () => {
  for (const [seed, expected] of [
    [{}, 400],
    [{ [PANEL_WIDTH_KEY]: 'wide' }, 400],
    [{ [PANEL_WIDTH_KEY]: '' }, 400],
    [{ [PANEL_WIDTH_KEY]: '319' }, 400],
    [{ [PANEL_WIDTH_KEY]: 'NaN' }, 400],
    [{ [PANEL_WIDTH_KEY]: '512' }, 512],
  ]) {
    const { panel } = panelOver(memoryStorage(seed));
    assert.equal(panel.remembered(), expected, `stored ${JSON.stringify(seed)}`);
  }
});

test('a stored width wider than the viewport allows is clamped by the layout, and the stored value is kept', () => {
  const { panel, storage } = panelOver(memoryStorage({ [PANEL_WIDTH_KEY]: '5000' }), 1280);
  assert.equal(panel.layout().panelWidth, 592);
  assert.equal(storage.map.get(PANEL_WIDTH_KEY), '5000', 'reading never rewrites the preference');
});

test('a preference store that throws on read still yields the default width', () => {
  const throwing = { getItem: () => { throw new Error('blocked'); }, setItem: () => {}, removeItem: () => {} };
  const { panel } = panelOver(throwing);
  assert.equal(panel.remembered(), 400);
});

test('keyboard resize moves 16px within [320, the 640px content point], and stores each step', () => {
  const { panel, storage } = panelOver(memoryStorage(), 1280);
  panel.resizeBy(16);
  assert.equal(panel.layout().panelWidth, 416);
  assert.equal(storage.map.get(PANEL_WIDTH_KEY), '416');
  for (let step = 0; step < 40; step += 1) panel.resizeBy(16);
  assert.equal(panel.layout().panelWidth, 592, 'never past the point where content reaches 640');
  assert.equal(panel.layout().contentWidth, 640);
  assert.equal(storage.map.get(PANEL_WIDTH_KEY), '592');
  for (let step = 0; step < 40; step += 1) panel.resizeBy(-16);
  assert.equal(panel.layout().panelWidth, 320, 'never below the minimum');
  assert.equal(storage.map.get(PANEL_WIDTH_KEY), '320');
  // Narrow enough that the preferred side bar fits again, so the yield is undone and the maximum is
  // the width that leaves content at 640 beside it.
  assert.equal(panel.layout().sideBarShown, true);
  assert.equal(panel.layout().panelMax, 352);
});

test('a step that leaves the rendered width unchanged changes nothing: 1,024px, remembered 400, rendered 336', () => {
  // Mutation (Rule 19): drop the rendered-width early return from `applyWidth` -> `remembered()`
  // reads 336 and "336" is stored, and both assertions go red.
  const { panel, storage } = panelOver(memoryStorage(), 1024);
  assert.equal(panel.layout().panelWidth, 336);
  panel.resizeBy(16);
  assert.equal(panel.remembered(), 400);
  assert.equal(storage.map.has(PANEL_WIDTH_KEY), false, 'nothing stored');
});

test('a drag clamps at both stops and stores the width it ended at, not every move', () => {
  const { panel, storage } = panelOver(memoryStorage(), 1920);
  panel.beginDrag(1500);
  assert.equal(panel.dragging(), true);
  panel.dragTo(1450);
  assert.equal(panel.layout().panelWidth, 450, 'moving left widens a panel docked right');
  assert.equal(storage.map.has(PANEL_WIDTH_KEY), false, 'nothing stored mid-drag');
  panel.dragTo(-5000);
  assert.equal(panel.layout().panelWidth, 992, 'the max with the side bar shown: 1,920 - 48 - 240 - 640');
  assert.equal(panel.layout().sideBarShown, true, 'dragging to the stop never collapses the side bar');
  panel.dragTo(5000);
  assert.equal(panel.layout().panelWidth, 320);
  panel.endDrag();
  assert.equal(panel.dragging(), false);
  assert.equal(storage.map.get(PANEL_WIDTH_KEY), '320');
});

test('full screen toggles without touching the width, and is not persisted', () => {
  const { panel, storage } = panelOver(memoryStorage({ [PANEL_WIDTH_KEY]: '480' }));
  panel.toggleFullScreen();
  assert.equal(panel.fullScreen(), true);
  assert.equal(panel.layout().fullScreen, true);
  panel.toggleFullScreen();
  assert.equal(panel.fullScreen(), false);
  assert.equal(panel.layout().panelWidth, 480, 'the same width after restore');
  assert.deepEqual([...storage.map.keys()], [PANEL_WIDTH_KEY], 'full screen writes nothing');
});

test('reopening a yielded side bar changes no stored preference, and width returning ends the reopen', () => {
  const { panel, shell, storage } = panelOver(memoryStorage(), 1280);
  assert.equal(panel.sideBarYielded(), true);
  const before = new Map(storage.map);
  panel.reopenSideBar();
  assert.equal(panel.layout().sideBarShown, true);
  assert.equal(panel.layout().panelWidth, 352);
  assert.equal(panel.remembered(), 400, 'the stored panel width stays 400');
  assert.deepEqual(storage.map, before, 'no preference was written');
  assert.equal(shell.open(), true);

  panel.setViewport(1920);
  assert.equal(panel.sideBarReopened(), false, 'the reopen is not a concession any more');
  panel.setViewport(1280);
  assert.equal(panel.layout().sideBarShown, false, 'and a later narrowing yields again');
});

test('closing the side bar ends a reopen, so opening it again at 1,280px yields again', () => {
  // Mutation (Rule 19): drop `if (!this.shell.open()) this.reopened = false;` from the `PanelState`
  // constructor's shell subscription -> the bar shows on reopen, and the last assertion goes red.
  const { panel, shell } = panelOver(memoryStorage(), 1280);
  panel.reopenSideBar();
  assert.equal(panel.layout().sideBarShown, true);
  shell.toggleOpen();
  assert.equal(panel.layout().sideBarShown, false);
  shell.toggleOpen();
  assert.equal(shell.open(), true);
  assert.equal(panel.layout().sideBarShown, false, 'the preference is open again, and the width yields it');
});

test('the side bar is not preferred on Home, which has no screen list', () => {
  const { panel, shell } = panelOver(memoryStorage(), 1920);
  shell.activateArea('home', true);
  assert.equal(panel.layout().sideBarShown, false);
  assert.equal(panel.layout().panelMax, 1920 - 48 - 640);
});

test('the draft is held by the store and survives whatever the router does', () => {
  const { panel } = panelOver();
  let notified = 0;
  panel.subscribe(() => {
    notified += 1;
  });
  panel.setDraft('Why is /csp/myapp disabled?');
  assert.equal(panel.draft(), 'Why is /csp/myapp disabled?');
  assert.equal(notified, 1);
  panel.setDraft('Why is /csp/myapp disabled?');
  assert.equal(notified, 1, 'an unchanged draft does not notify');
});
