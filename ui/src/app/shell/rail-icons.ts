/**
 * The area icons: the rail's eight 20x20 drawings and Home's six 24x24 tile drawings, transcribed
 * verbatim from DESIGN.md's `mockups/key-home.html` (every element, attribute value and element
 * order), keyed by the registry's area `key` (AD-5). `ui/tools/rail-icons.test.mjs` pins this data
 * to the mockup and the key set to `AREAS`.
 *
 * Framework-free, so `node --test` imports it (AD-19). Every root is `fill="none"`,
 * `stroke="currentColor"` and `stroke-width` {@link AREA_ICON_STROKE_WIDTH}; the shapes carry no
 * color of their own, so each rail and tile state colors the icon through `currentColor`.
 */

/** One drawing element: its tag and its attributes in the mockup's order. */
export interface IconShape {
  readonly tag: 'path' | 'circle' | 'rect';
  readonly attrs: Readonly<Record<string, string>>;
}

/** An area's drawings: the rail's 20px icon, and the 24px tile icon where the area has a tile. */
export interface AreaIconSet {
  readonly rail: readonly IconShape[];
  readonly tile?: readonly IconShape[];
}

/** The stroke width every icon root carries. */
export const AREA_ICON_STROKE_WIDTH = '1.5';

/** The root `viewBox` for an icon drawn at `size`. */
export function areaIconViewBox(size: 20 | 24): string {
  return `0 0 ${size} ${size}`;
}

export const AREA_ICONS: Readonly<Record<string, AreaIconSet>> = {
  home: {
    rail: [{ tag: 'path', attrs: { d: 'M3 8.5 10 3l7 5.5V16a1 1 0 0 1-1 1h-4v-5H8v5H4a1 1 0 0 1-1-1z' } }],
  },
  logs: {
    rail: [
      { tag: 'path', attrs: { d: 'M5 2.5h7l3.5 3.5v11a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-13a1 1 0 0 1 1-1z' } },
      { tag: 'path', attrs: { d: 'M11.5 2.5V6.5H15.5M6.5 10h7M6.5 13h7' } },
    ],
    tile: [
      { tag: 'path', attrs: { d: 'M6 3h8l4 4v13a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z' } },
      { tag: 'path', attrs: { d: 'M14 3v4h4M8 12h8M8 16h8' } },
    ],
  },
  'os-management': {
    rail: [
      { tag: 'rect', attrs: { x: '5.5', y: '5.5', width: '9', height: '9', rx: '1.5' } },
      {
        tag: 'path',
        attrs: { d: 'M8 3v2.5M12 3v2.5M8 14.5V17M12 14.5V17M3 8h2.5M3 12h2.5M14.5 8H17M14.5 12H17' },
      },
    ],
    tile: [
      { tag: 'rect', attrs: { x: '7', y: '7', width: '10', height: '10', rx: '1.5' } },
      { tag: 'path', attrs: { d: 'M10 3v4M14 3v4M10 17v4M14 17v4M3 10h4M3 14h4M17 10h4M17 14h4' } },
    ],
  },
  tasks: {
    rail: [
      { tag: 'circle', attrs: { cx: '10', cy: '10', r: '7' } },
      { tag: 'path', attrs: { d: 'M10 5.5V10l3 2' } },
    ],
    tile: [
      { tag: 'circle', attrs: { cx: '12', cy: '12', r: '8.5' } },
      { tag: 'path', attrs: { d: 'M12 6.5V12l4 2.5' } },
    ],
  },
  permissions: {
    rail: [
      { tag: 'circle', attrs: { cx: '7', cy: '9', r: '3.5' } },
      { tag: 'path', attrs: { d: 'M9.8 7.4H17M14.5 7.4v3M16.6 7.4v2.2' } },
    ],
    tile: [
      { tag: 'circle', attrs: { cx: '8.5', cy: '11', r: '4' } },
      { tag: 'path', attrs: { d: 'M12 9h9M18 9v3.5M20.4 9v2.6' } },
    ],
  },
  'web-applications': {
    rail: [
      { tag: 'circle', attrs: { cx: '10', cy: '10', r: '7' } },
      { tag: 'path', attrs: { d: 'M3 10h14M10 3c2 2.4 2 11.6 0 14M10 3c-2 2.4-2 11.6 0 14' } },
    ],
    tile: [
      { tag: 'circle', attrs: { cx: '12', cy: '12', r: '8.5' } },
      { tag: 'path', attrs: { d: 'M3.5 12h17M12 3.5c2.5 3 2.5 14 0 17M12 3.5c-2.5 3-2.5 14 0 17' } },
    ],
  },
  security: {
    rail: [{ tag: 'path', attrs: { d: 'M10 3l6 2.2v4.6c0 3.6-2.4 6.3-6 7.2-3.6-.9-6-3.6-6-7.2V5.2z' } }],
    tile: [{ tag: 'path', attrs: { d: 'M12 3l7.5 2.7v5.6c0 4.4-3 7.7-7.5 8.7-4.5-1-7.5-4.3-7.5-8.7V5.7z' } }],
  },
  agent: {
    rail: [
      { tag: 'rect', attrs: { x: '3', y: '6', width: '14', height: '10', rx: '2.5' } },
      { tag: 'path', attrs: { d: 'M10 6V3.5' } },
      { tag: 'circle', attrs: { cx: '7.4', cy: '11', r: '1.1', fill: 'currentColor', stroke: 'none' } },
      { tag: 'circle', attrs: { cx: '12.6', cy: '11', r: '1.1', fill: 'currentColor', stroke: 'none' } },
    ],
  },
};

/**
 * The shapes for `key` at `size` -- the rail drawing at 20, the tile drawing at 24 -- or `null`
 * when the area has no drawing at that size. A caller renders nothing for `null`, never a letter.
 */
export function areaIcon(key: string, size: 20 | 24): readonly IconShape[] | null {
  const set = Object.prototype.hasOwnProperty.call(AREA_ICONS, key) ? AREA_ICONS[key] : undefined;
  if (set === undefined) return null;
  return (size === 20 ? set.rail : set.tile) ?? null;
}
