import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Pins `shell/rail-icons.ts` (Story 15.7) to DESIGN.md's `mockups/key-home.html`: both of the
// mockup's frames draw the same icons, every rail icon and tile icon in the module equals the
// mockup's element for element and attribute for attribute (order included), each root carries the
// module's viewBox, fill, stroke and stroke width, and the module's keys are the registry's `AREAS`.
// It also pins DESIGN.md's `rail` paragraph to the mockup's icons.
//
// Mutations (Rule 19):
// - change one coordinate in `AREA_ICONS.logs.rail` -> "the module equals the mockup" goes red.
// - drop the `tile` entry from one tile area -> the roster test goes red naming it.
// - restore the "Material Symbols" sentence in DESIGN.md's `rail` paragraph -> the DESIGN test goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = join(uiRoot, '..');
const uxRoot = join(repoRoot, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08');

const { AREA_ICONS, AREA_ICON_STROKE_WIDTH, areaIcon, areaIconViewBox } = await import(
  join(uiRoot, 'src', 'app', 'shell', 'rail-icons.ts')
);
const { AREAS } = await import(join(uiRoot, 'src', 'app', 'core', 'screens.generated.ts'));
const { stringFor } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const mockup = readFileSync(join(uxRoot, 'mockups', 'key-home.html'), 'utf8');
const design = readFileSync(join(uxRoot, 'DESIGN.md'), 'utf8');

/** `name="value"` pairs of one tag's attribute text, in source order. */
function attributes(text) {
  return [...text.matchAll(/([\w-]+)="([^"]*)"/g)].map((m) => [m[1], m[2]]);
}

/** One `<svg ...>...</svg>`: its root attributes and its drawing elements. */
function parseSvg(rootText, body) {
  const shapes = [...body.matchAll(/<(\w+)\s+([^>]*?)\s*\/>/g)].map((m) => ({ tag: m[1], attrs: attributes(m[2]) }));
  return { root: attributes(rootText), shapes };
}

/** Every frame's rail icons, in rail order, with each item's `title` where it has one. */
function railFrames() {
  const frames = [...mockup.matchAll(/<nav class="rail"[^>]*>([\s\S]*?)<\/nav>/g)].map((m) => m[1]);
  return frames.map((frame) =>
    [...frame.matchAll(/<div class="rit[^"]*"(?: title="([^"]*)")?>\s*<svg ([^>]*)>([\s\S]*?)<\/svg>/g)].map((m) => ({
      title: m[1] ?? null,
      ...parseSvg(m[2], m[3]),
    }))
  );
}

/** Every frame's tile icons, in grid order, with each tile's `.nm`. */
function tileFrames() {
  const frames = [...mockup.matchAll(/<div class="tiles">([\s\S]*?)<div class="instline">/g)].map((m) => m[1]);
  return frames.map((frame) =>
    [...frame.matchAll(/<div class="tile[^"]*">\s*<svg ([^>]*)>([\s\S]*?)<\/svg>\s*<span class="nm">([^<]*)<\/span>/g)].map((m) => ({
      name: m[3],
      ...parseSvg(m[1], m[2]),
    }))
  );
}

/** The module's shapes in the parsed form, or null. */
function moduleShapes(key, size) {
  const shapes = areaIcon(key, size);
  return shapes === null ? null : shapes.map((shape) => ({ tag: shape.tag, attrs: Object.entries(shape.attrs) }));
}

/** The root attributes the module's component sets, in the mockup's order. */
function moduleRoot(size) {
  return [
    ['viewBox', areaIconViewBox(size)],
    ['fill', 'none'],
    ['stroke', 'currentColor'],
    ['stroke-width', AREA_ICON_STROKE_WIDTH],
  ];
}

const railOrder = [...AREAS].sort((a, b) => a.railPosition - b.railPosition);
const tileAreas = AREAS.filter((area) => !area.navigates && !area.pinBottom);

test('the mockup has two frames that draw identical rail and tile icons', () => {
  const rails = railFrames();
  const tiles = tileFrames();
  assert.equal(rails.length, 2, 'two rails');
  assert.equal(tiles.length, 2, 'two tile grids');
  assert.equal(rails[0].length, AREAS.length, 'one rail icon per area');
  assert.equal(tiles[0].length, tileAreas.length, 'one tile icon per tile area');
  const shapesOnly = (frame) => frame.map(({ root, shapes }) => ({ root, shapes }));
  assert.deepEqual(shapesOnly(rails[1]), shapesOnly(rails[0]), 'both rails draw the same icons');
  assert.deepEqual(tiles[1], tiles[0], 'both tile grids draw the same icons under the same names');
});

test('each rail icon in the module equals the mockup, mapped by rail position and checked against the title', () => {
  const [rail] = railFrames();
  for (const [index, area] of railOrder.entries()) {
    const drawn = rail[index];
    if (drawn.title !== null) assert.equal(drawn.title, stringFor(area.labelKey), `rail position ${area.railPosition} is ${area.key}`);
    assert.deepEqual(drawn.root, moduleRoot(20), `${area.key}: the rail root`);
    assert.deepEqual(moduleShapes(area.key, 20), drawn.shapes, `${area.key}: the rail shapes`);
  }
  // The gated frame omits one title; the other frame names every position.
  const [, titled] = railFrames();
  assert.deepEqual(
    titled.map((drawn) => drawn.title),
    railOrder.map((area) => stringFor(area.labelKey)),
    'the second frame titles every rail position with its area name'
  );
});

test('each tile icon in the module equals the mockup, mapped by the tile name', () => {
  const [tiles] = tileFrames();
  const byName = new Map(tiles.map((tile) => [tile.name, tile]));
  for (const area of tileAreas) {
    const drawn = byName.get(stringFor(area.labelKey));
    assert.ok(drawn !== undefined, `the mockup draws a tile named ${stringFor(area.labelKey)}`);
    assert.deepEqual(drawn.root, moduleRoot(24), `${area.key}: the tile root`);
    assert.deepEqual(moduleShapes(area.key, 24), drawn.shapes, `${area.key}: the tile shapes`);
  }
});

test('the roster: the module keys are the registry areas, and every tile area has a tile drawing', () => {
  assert.deepEqual(Object.keys(AREA_ICONS).sort(), AREAS.map((area) => area.key).sort(), 'AREA_ICONS keys equal AREAS keys');
  for (const area of AREAS) assert.ok(areaIcon(area.key, 20) !== null, `${area.key} has a rail drawing`);
  for (const area of tileAreas) assert.ok(areaIcon(area.key, 24) !== null, `${area.key} is a tile area and has a tile drawing`);
  assert.equal(areaIcon('no-such-area', 20), null, 'an unknown key has no drawing');
  assert.equal(areaIcon('toString', 20), null, 'nor does an inherited property name');
});

test("DESIGN.md's rail paragraph names the mockup's icons, not the interim Material Symbols set", () => {
  const section = /^#### `rail`\n\n([^\n]+)/m.exec(design);
  assert.ok(section !== null, 'DESIGN.md has a #### `rail` paragraph');
  // An amendment marker records what the text used to say; the claim is the text outside it.
  const claim = section[1].replace(/\[AMENDED [^\]]*\]/g, '');
  assert.match(claim, /mockups\/key-home\.html/, 'it names the mockup');
  assert.doesNotMatch(claim, /Material Symbols/, 'and no longer names the interim set');
  assert.match(section[1], /\[AMENDED 2026-09-24, Story 15\.7/, 'and carries the amendment marker');
});
