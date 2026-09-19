import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
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

const {
  resolveLayout,
  PanelState,
  PANEL_MIN_WIDTH,
  PANEL_DEFAULT_WIDTH,
  CONTENT_MIN_WIDTH,
  RAIL_WIDTH,
  PANEL_KEYBOARD_STEP,
  HOME_PANEL_FRACTION,
  panelHomeTarget,
} = await import(core('panel-layout.ts'));
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
    homeTarget: 0,
    fullScreen: false,
    ...overrides,
  });
}

/** A panel store on Home, whose area has no screen list, so nothing but the panel takes width. */
function panelOnHome(storage = memoryStorage(), viewport = 1920) {
  const preferences = new PreferenceStore({ storage });
  const shell = new ShellState({ preferences });
  shell.setActiveArea('home');
  const panel = new PanelState({ preferences, shell });
  panel.setViewport(viewport);
  return { panel, shell, storage };
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

// --- Home's wider panel (Story 4.10, DW-160) ------------------------------------

test("DESIGN.md's five published Home widths, resolved through the one layout computation", () => {
  // Mutation (Rule 19): `HOME_PANEL_FRACTION` 0.5 -> 0.4 -> this test goes red on the 1,920,
  // 1,440 and 1,280 rows (960/720/592 become 768/576/512); the two narrowest rows are already at
  // the subtracted operand and the panel floor, so they are unmoved by the fraction.
  //
  // DESIGN.md `:904`'s table, read straight: `Panel on Home` and `Content on Home` at each
  // published viewport, with the side bar preferred (which is what its `Side bar` column names).
  const published = [
    { viewport: 1920, sideBar: 240, panel: 960, content: 672, scrolls: false },
    { viewport: 1440, sideBar: 0, panel: 720, content: 672, scrolls: false },
    { viewport: 1280, sideBar: 0, panel: 592, content: 640, scrolls: false },
    { viewport: 1024, sideBar: 0, panel: 336, content: 640, scrolls: false },
    { viewport: 900, sideBar: 0, panel: 320, content: 532, scrolls: true },
  ];
  for (const row of published) {
    const layout = layoutAt(row.viewport, { homeTarget: panelHomeTarget(row.viewport) });
    assert.deepEqual(
      {
        sideBar: layout.sideBarShown ? 240 : 0,
        panel: layout.panelWidth,
        content: layout.contentWidth,
        scrolls: layout.contentScrolls,
      },
      { sideBar: row.sideBar, panel: row.panel, content: row.content, scrolls: row.scrolls },
      `${row.viewport}px`
    );
  }
});

test('an unmeasured viewport has no Home target, so a first render never widens a panel it has not measured', () => {
  assert.equal(panelHomeTarget(0), 0);
  assert.equal(panelHomeTarget(-1), 0);
});

test('the Home target is floored at 0, so a viewport the rail and content already fill never returns a negative', () => {
  // Mutation (Rule 19): drop the `Math.max(0, ...)` from `panelHomeTarget` -> this goes red.
  //
  // Below RAIL_WIDTH + CONTENT_MIN_WIDTH the subtracted operand is negative, and a negative
  // target would be a third meaning for a field whose doc comment gives it two: a measured width,
  // or 0 for "not on Home".
  assert.equal(panelHomeTarget(RAIL_WIDTH + CONTENT_MIN_WIDTH), 0);
  assert.equal(panelHomeTarget(RAIL_WIDTH + CONTENT_MIN_WIDTH - 8), 0);
  assert.ok(panelHomeTarget(RAIL_WIDTH + CONTENT_MIN_WIDTH + 24) > 0, 'and is positive above it');
});

test('an arrow step that lands on the remembered width still moves the panel off the Home target, and says so', () => {
  // Mutation (Rule 19): capture `rendered` AFTER `this.homeWidthReleased = true` in `applyWidth`
  // (or drop the notify from the equal-width branch) -> this goes red.
  //
  // At 1,440 the Home target is 720 and the remembered width is one keyboard step above it, so the
  // step's result equals the post-release layout and the early return fires. The release has
  // already moved the panel, so a silent return leaves the rendered width and `aria-valuenow` at
  // 720 while the store answers 736.
  const storage = memoryStorage();
  storage.map.set(PANEL_WIDTH_KEY, String(720 + PANEL_KEYBOARD_STEP));
  const { panel } = panelOnHome(storage, 1440);
  assert.equal(panel.layout().panelWidth, 720, 'the Home target is what is on screen');

  let notified = 0;
  panel.subscribe(() => {
    notified += 1;
  });
  panel.resizeBy(PANEL_KEYBOARD_STEP);
  assert.equal(panel.layout().panelWidth, 736, 'the step lands on the remembered width');
  assert.equal(notified, 1, 'and consumers are told the panel moved');
});

test('a homeTarget of 0 means "not on Home": the layout stays on the remembered width', () => {
  const layout = layoutAt(1920, { homeTarget: 0, remembered: 480 });
  assert.equal(layout.panelWidth, 480);
});

test('DW-379: --ocu-panel-home and panelHomeTarget are built from the same three numbers', () => {
  // Mutation (Rule 19): change `--ocu-content-min-width` in `_metrics.scss` without changing
  // `CONTENT_MIN_WIDTH` -> this goes red.
  //
  // The token's one consumer. `typography.test.mjs:330` asserts its SHAPE -- that it is
  // `min(50vw, calc(100vw - var(--ocu-rail-width) - var(--ocu-content-min-width)))` -- and this
  // asserts that the numbers those three operands resolve to are the ones `panelHomeTarget`
  // computes with, so changing either side alone is red. There is no runtime CSS consumer: the
  // inline `[style.width.px]` binding wins, and CSS cannot see the side bar.
  const metrics = readFileSync(join(uiRoot, 'src', 'styles', '_metrics.scss'), 'utf8');
  const px = (token) => {
    const match = new RegExp(`--ocu-${token}\\s*:\\s*(\\d+(?:\\.\\d+)?)px`).exec(metrics);
    assert.ok(match, `expected --ocu-${token} to declare a px value in _metrics.scss`);
    return Number(match[1]);
  };
  const home = /--ocu-panel-home:\s*min\(([\s\S]*?)\n  \);/.exec(metrics);
  assert.ok(home, 'expected --ocu-panel-home in _metrics.scss');
  const vw = /(\d+(?:\.\d+)?)vw\s*,/.exec(home[1]);
  assert.ok(vw, `expected a <n>vw operand in --ocu-panel-home, got: ${JSON.stringify(home[1])}`);
  const referenced = [...home[1].matchAll(/var\(--ocu-([a-z0-9-]+)\)/g)].map((m) => m[1]);
  assert.deepEqual(referenced, ['rail-width', 'content-min-width'], 'the two subtracted operands');

  assert.equal(Number(vw[1]) / 100, HOME_PANEL_FRACTION, 'the 50vw half is HOME_PANEL_FRACTION');
  assert.equal(px('rail-width'), RAIL_WIDTH);
  assert.equal(px('content-min-width'), CONTENT_MIN_WIDTH);
  // And the function itself, over the token's own arithmetic at one published width.
  assert.equal(
    panelHomeTarget(1920),
    Math.min(1920 * HOME_PANEL_FRACTION, 1920 - RAIL_WIDTH - CONTENT_MIN_WIDTH)
  );
  // Mutation (Rule 19): drop the `Math.floor` from `panelHomeTarget` -> this goes red, and nothing
  // else does: all five published viewports are even, so the floor never bites on any of them,
  // while a real window is any width the user drags it to and `[style.width.px]` would carry a
  // half-pixel panel edge.
  assert.equal(panelHomeTarget(1441), 720, 'a whole number of pixels at an odd viewport');
});

test('the panel takes the Home target on Home, and the remembered width everywhere else', () => {
  // Mutation (Rule 19): write the Home target into `rememberedWidth` inside `homeTargetWidth()` ->
  // the leave-Home assertions go red.
  const { panel, shell, storage } = panelOnHome(memoryStorage(), 1920);
  assert.equal(panel.layout().panelWidth, 960, 'the published Home width');
  assert.equal(panel.layout().sideBarShown, false, 'Home has no screen list to show');
  assert.equal(panel.remembered(), 400, 'the Home target never writes the remembered width');
  assert.equal(storage.map.has(PANEL_WIDTH_KEY), false, 'and stores nothing');

  shell.setActiveArea('permissions');
  assert.equal(panel.layout().panelWidth, 400, 'leaving Home restores the remembered width');
  assert.equal(panel.remembered(), 400);

  shell.setActiveArea('home');
  assert.equal(panel.layout().panelWidth, 960, 'and returning takes the target again');
});

test('a width gesture on Home releases the target for that visit and stores the width it lands on', () => {
  // Mutation (Rule 19): set `homeWidthReleased` AFTER reading `this.layout()` in `applyWidth`
  // instead of before -> the drag-at-the-target assertions go red, because `applyWidth`'s
  // rendered-width early return then matches the Home target and the gesture is dropped.
  const { panel, shell, storage } = panelOnHome(memoryStorage(), 1920);
  panel.beginDrag(1000);
  panel.dragTo(920);
  assert.equal(panel.layout().panelWidth, 1040, 'the drag lands where the pointer is');
  panel.endDrag();
  assert.equal(panel.remembered(), 1040);
  assert.equal(storage.map.get(PANEL_WIDTH_KEY), '1040', 'and that width is the stored one');

  // Leaving and returning is a new visit, so the target applies again.
  shell.setActiveArea('permissions');
  assert.equal(panel.layout().panelWidth, 1040);
  shell.setActiveArea('home');
  assert.equal(panel.layout().panelWidth, 960);

  // A drag that ends at exactly the Home target is still a gesture: it releases the target and
  // stores 960, where a release taken after the layout read would read "unchanged" and drop it.
  const second = panelOnHome(memoryStorage(), 1920);
  second.panel.beginDrag(1000);
  second.panel.dragTo(1000);
  second.panel.endDrag();
  assert.equal(second.panel.remembered(), 960);
  assert.equal(second.storage.map.get(PANEL_WIDTH_KEY), '960');
  second.shell.setActiveArea('permissions');
  assert.equal(second.panel.layout().panelWidth, 960, 'so leaving Home keeps the dragged width');
});

test('an arrow step on Home moves from the Home width, not from the remembered one', () => {
  const { panel, storage } = panelOnHome(memoryStorage(), 1440);
  assert.equal(panel.layout().panelWidth, 720);
  panel.resizeBy(-16);
  assert.equal(panel.layout().panelWidth, 704);
  assert.equal(panel.remembered(), 704);
  assert.equal(storage.map.get(PANEL_WIDTH_KEY), '704');
});

test('signing out ends the Home visit, so the next principal opens Home at the published width', () => {
  // Mutation (Rule 19): drop `this.homeWidthReleased = false` from `endSession()` -> this goes red.
  //
  // A sign-out does not change the area -- `ShellState.setActiveArea` returns early on an
  // unchanged key -- so nothing else in this store ever clears the release. Without it the panel
  // opens the next sign-in on the departed principal's dragged width, on the one route whose
  // width is the product's own rather than the user's.
  const { panel } = panelOnHome(memoryStorage(), 1920);
  panel.resizeBy(-16);
  assert.equal(panel.layout().panelWidth, 944, 'the gesture released the target for this visit');

  panel.endSession();
  assert.equal(panel.layout().panelWidth, 960, 'and the next visit takes the target again');
  assert.equal(panel.remembered(), 944, 'while the width the user chose is still remembered');
});
