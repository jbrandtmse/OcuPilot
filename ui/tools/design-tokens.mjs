/**
 * Pure exports over the shipped color token stylesheet
 * (`ui/src/styles/_tokens.scss`): the 64-role roster, the two non-role literals,
 * WCAG 2.1 relative luminance and contrast, and the three pair inventories
 * (`LOAD_BEARING`, `MARGINAL_GUARDED`, `REJECTED`) DESIGN.md's Colors > Contrast
 * section publishes. One file because all of it reads the same parsed token map
 * (Task list) -- `design-tokens.test.mjs` is the only consumer that also touches
 * the filesystem; everything here is a pure function or a literal data table.
 *
 * Every published figure below is transcribed from DESIGN.md's Colors > Contrast
 * tables (lines 772-845) -- never recomputed into a different number, per this
 * story's own rule. `design-tokens.test.mjs` computes its *own* ratio from the
 * shipped hexes and compares it to the published figure; a mismatch means a hex
 * was mistyped, not that the published figure is wrong.
 */

// --- Roster --------------------------------------------------------------------

/** The 64 color roles (DESIGN.md `colors:` frontmatter key set, light side). */
export const COLOR_ROLES = [
  // 30 Material 3 roles
  'primary',
  'on-primary',
  'primary-container',
  'on-primary-container',
  'secondary',
  'on-secondary',
  'secondary-container',
  'on-secondary-container',
  'tertiary',
  'on-tertiary',
  'tertiary-container',
  'on-tertiary-container',
  'error',
  'on-error',
  'error-container',
  'on-error-container',
  'surface',
  'surface-dim',
  'surface-bright',
  'surface-container-lowest',
  'surface-container-low',
  'surface-container',
  'surface-container-high',
  'surface-container-highest',
  'on-surface',
  'on-surface-variant',
  'outline',
  'outline-variant',
  'inverse-surface',
  'inverse-on-surface',
  // 34 OcuPilot roles
  'shell',
  'on-shell',
  'shell-edge',
  'agent-accent',
  'on-agent-accent',
  'agent-container',
  'on-agent-container',
  'change-highlight',
  'egress-warning',
  'egress-warning-container',
  'restrained',
  'restrained-container',
  'destructive',
  'on-destructive',
  'destructive-container',
  'on-destructive-container',
  'success',
  'success-container',
  'warning',
  'warning-container',
  'info',
  'info-container',
  'code-surface',
  'on-code-surface',
  'focus-ring',
  'focus-ring-inner',
  'server-flag-live',
  'server-flag-live-container',
  'server-flag-test',
  'server-flag-test-container',
  'server-flag-failover',
  'server-flag-failover-container',
  'server-flag-development',
  'server-flag-development-container',
];

/**
 * Custom properties the token stylesheet declares that carry a literal color
 * value but are explicitly documented as NOT color roles (DESIGN.md rules 2 and
 * 8) -- excluded from `COLOR_ROLES` and from the 64-role count. `hasDark` says
 * whether a `-dark` sibling is expected for that name.
 */
export const NON_ROLE_TOKENS = {
  'logo-gradient-stop': { hasDark: false },
  'elevation-1': { hasDark: true },
  'elevation-2': { hasDark: true },
  'elevation-3': { hasDark: true },
};

// --- Parsing ---------------------------------------------------------------

/**
 * Parses DESIGN.md's own frontmatter `colors:` block directly out of the raw
 * document text, into the same `{light, dark}` shape `parseTokens` returns, so
 * `design-tokens.test.mjs` can compare the shipped stylesheet against the
 * document itself rather than against a second hand-typed copy of the same 128
 * hexes -- a duplicate table risks the same transcription slip appearing on both
 * sides and proving nothing. `markdown` is the whole file's raw text.
 */
export function parseDesignDocColors(markdown) {
  const lines = markdown.split('\n');
  const light = {};
  const dark = {};
  let inColors = false;
  for (const line of lines) {
    if (/^colors:\s*$/.test(line)) {
      inColors = true;
      continue;
    }
    if (!inColors) continue;
    // A non-indented, non-comment line ends the colors: block (the next
    // top-level frontmatter key, e.g. "typography:").
    if (/^\S/.test(line)) break;
    const m = /^\s+([a-z0-9-]+):\s*'(#[0-9A-Fa-f]{6})'/.exec(line);
    if (!m) continue; // a "# ..." comment line inside the block
    const [, name, hex] = m;
    if (name.endsWith('-dark')) {
      dark[name.slice(0, -'-dark'.length)] = hex;
    } else {
      light[name] = hex;
    }
  }
  return { light, dark };
}

const CUSTOM_PROPERTY_RE = /--ocu-([a-z0-9-]+):\s*([^;]+);/g;

/**
 * Parses every `--ocu-<name>` custom property declared anywhere in `css` into
 * `{light, dark}` maps, keyed by the role/token name with any `-dark` suffix
 * stripped from the *key* (the value itself is untouched). Generic over the
 * whole file rather than scoped to a particular selector -- correct for
 * `_tokens.scss`, where both sides of every role are declared unconditionally on
 * the bare `:root` (Design Notes' "the mechanism, in short").
 */
export function parseTokens(css) {
  const light = {};
  const dark = {};
  for (const m of css.matchAll(CUSTOM_PROPERTY_RE)) {
    const name = m[1];
    const value = m[2].trim();
    if (name.endsWith('-dark')) {
      dark[name.slice(0, -'-dark'.length)] = value;
    } else {
      light[name] = value;
    }
  }
  return { light, dark };
}

/** Resolves `{role, variant}` against a parsed `{light, dark}` token map. */
export function resolveHex(tokens, ref) {
  const map = ref.variant === 'dark' ? tokens.dark : tokens.light;
  const hex = map[ref.role];
  if (!hex) {
    throw new Error(
      `resolveHex: no ${ref.variant} value declared for role ${JSON.stringify(ref.role)}`
    );
  }
  return hex;
}

// --- WCAG 2.1 contrast -------------------------------------------------------

const HEX_RE = /^#[0-9a-fA-F]{6}$/;

/** sRGB 6-digit hex -> relative luminance (WCAG 2.1 section 1.4.3, formula in section G17). */
export function relativeLuminance(hex) {
  if (!HEX_RE.test(hex)) {
    throw new Error(`relativeLuminance: expected a 6-digit hex color, got ${JSON.stringify(hex)}`);
  }
  const toLinear = (channel255) => {
    const s = channel255 / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  };
  const r = toLinear(parseInt(hex.slice(1, 3), 16));
  const g = toLinear(parseInt(hex.slice(3, 5), 16));
  const b = toLinear(parseInt(hex.slice(5, 7), 16));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** WCAG contrast ratio between two 6-digit hex colors; always >= 1. */
export function contrastRatio(hexA, hexB) {
  const la = relativeLuminance(hexA);
  const lb = relativeLuminance(hexB);
  const lighter = Math.max(la, lb);
  const darker = Math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/** Rounds to 2 decimal places -- DESIGN.md's own published precision. */
export function round2(n) {
  return Math.round(n * 100) / 100;
}

// --- Pair inventories --------------------------------------------------------

/**
 * The load-bearing contrast pairs (DESIGN.md Colors > Contrast, lines 774-802).
 * `fg`/`bg` are role names resolved against the *matching* mode (light fg on
 * light bg, dark fg on dark bg) -- every one of these is an ordinary same-mode
 * text-or-non-text-on-background pair, unlike two of the three marginal guards.
 */
export const LOAD_BEARING = [
  { label: 'body text on content ground', fg: 'on-surface', bg: 'surface', floor: 4.5, published: { light: 16.02, dark: 14.50 } },
  { label: 'secondary text on content ground', fg: 'on-surface-variant', bg: 'surface', floor: 4.5, published: { light: 7.36, dark: 9.58 } },
  { label: 'table, card, panel', fg: 'on-surface', bg: 'surface-container-lowest', floor: 4.5, published: { light: 16.60, dark: 15.60 } },
  { label: 'on-surface on surface-container-highest', fg: 'on-surface', bg: 'surface-container-highest', floor: 4.5, published: { light: 12.23, dark: 9.39 } },
  { label: 'on-primary on primary', fg: 'on-primary', bg: 'primary', floor: 4.5, published: { light: 9.97, dark: 8.64 } },
  { label: 'user message bubble', fg: 'on-primary-container', bg: 'primary-container', floor: 4.5, published: { light: 12.19, dark: 7.21 } },
  { label: 'primary button', fg: 'on-secondary', bg: 'secondary', floor: 4.5, published: { light: 5.76, dark: 7.95 } },
  { label: 'selection', fg: 'on-secondary-container', bg: 'secondary-container', floor: 4.5, published: { light: 10.42, dark: 7.14 } },
  { label: 'chrome text on chrome', fg: 'on-shell', bg: 'shell', floor: 4.5, published: { light: 10.35, dark: 12.85 } },
  { label: 'header gradient end', fg: 'on-shell', bg: 'shell-edge', floor: 4.5, published: { light: 5.35, dark: 6.43 } },
  { label: 'agent-accent as text on agent-container', fg: 'agent-accent', bg: 'agent-container', floor: 4.5, published: { light: 5.97, dark: 8.86 } },
  { label: 'on-agent-container on agent-container', fg: 'on-agent-container', bg: 'agent-container', floor: 4.5, published: { light: 14.14, dark: 11.36 } },
  { label: 'changed row text', fg: 'on-surface', bg: 'change-highlight', floor: 4.5, published: { light: 14.83, dark: 8.17 } },
  { label: 'egress-warning on its container', fg: 'egress-warning', bg: 'egress-warning-container', floor: 4.5, published: { light: 5.88, dark: 7.87 } },
  { label: 'restrained on its container', fg: 'restrained', bg: 'restrained-container', floor: 4.5, published: { light: 5.42, dark: 6.73 } },
  { label: 'destructive as text on surface', fg: 'destructive', bg: 'surface', floor: 4.5, published: { light: 6.31, dark: 10.54 } },
  { label: 'on-destructive on destructive', fg: 'on-destructive', bg: 'destructive', floor: 4.5, published: { light: 6.54, dark: 7.66 } },
  { label: 'on-error-container on error-container', fg: 'on-error-container', bg: 'error-container', floor: 4.5, published: { light: 12.77, dark: 7.17 } },
  { label: 'success on its container', fg: 'success', bg: 'success-container', floor: 4.5, published: { light: 5.46, dark: 7.81 } },
  { label: 'warning on its container', fg: 'warning', bg: 'warning-container', floor: 4.5, published: { light: 6.18, dark: 7.30 } },
  { label: 'info on its container', fg: 'info', bg: 'info-container', floor: 4.5, published: { light: 5.62, dark: 6.64 } },
  { label: 'on-code-surface on code-surface', fg: 'on-code-surface', bg: 'code-surface', floor: 4.5, published: { light: 11.96, dark: 14.01 } },
  { label: 'toast', fg: 'inverse-on-surface', bg: 'inverse-surface', floor: 4.5, published: { light: 11.63, dark: 12.44 } },
  { label: 'server flag: Live', fg: 'server-flag-live', bg: 'server-flag-live-container', floor: 4.5, published: { light: 5.27, dark: 6.72 } },
  { label: 'server flag: Test', fg: 'server-flag-test', bg: 'server-flag-test-container', floor: 4.5, published: { light: 6.18, dark: 7.30 } },
  { label: 'server flag: Failover', fg: 'server-flag-failover', bg: 'server-flag-failover-container', floor: 4.5, published: { light: 6.60, dark: 7.85 } },
  { label: 'server flag: Development', fg: 'server-flag-development', bg: 'server-flag-development-container', floor: 4.5, published: { light: 5.46, dark: 7.81 } },
  { label: 'focus-ring on surface', fg: 'focus-ring', bg: 'surface', floor: 3.0, published: { light: 9.62, dark: 9.94 } },
  { label: 'focus-ring on its inner halo', fg: 'focus-ring', bg: 'focus-ring-inner', floor: 3.0, published: { light: 9.97, dark: 9.94 } },
  { label: 'control border', fg: 'outline', bg: 'surface', floor: 3.0, published: { light: 4.43, dark: 5.35 } },
];

/**
 * The three marginal guards (DESIGN.md's derived table, lines 826, 830 and 835 --
 * "guard with a test"). `light`/`dark` each carry a `{role, variant}` tuple for fg
 * and bg, resolved with `resolveHex` -- most guards use the matching variant for
 * both sides, but the toast link swaps *which role* is foreground between modes
 * (DESIGN.md rule 1: "the chrome does not change with the theme", so text drawn
 * against `inverse-surface` in light mode takes `secondary-dark`, and in dark
 * mode `inverse-surface-dark` takes plain `secondary`), so it cannot be expressed
 * as one role pair evaluated at two variants the way every `LOAD_BEARING` entry
 * can.
 */
export const MARGINAL_GUARDED = [
  {
    label: 'restrained gated reason on secondary-container (keyboard-active menu row)',
    floor: 4.5,
    light: { fg: { role: 'restrained', variant: 'light' }, bg: { role: 'secondary-container', variant: 'light' } },
    dark: { fg: { role: 'restrained', variant: 'dark' }, bg: { role: 'secondary-container', variant: 'dark' } },
    published: { light: 5.18, dark: 4.497 },
    failsInDark: true,
    // The remedy DESIGN.md names for the dark failure: the active row draws the
    // caption in on-secondary-container instead, which is LOAD_BEARING's
    // "selection" entry (10.42 / 7.14) -- re-asserted here so a hex mutation on
    // either role turns this guard red too, not only the load-bearing test.
    remedy: { fg: 'on-secondary-container', bg: 'secondary-container', published: { light: 10.42, dark: 7.14 } },
  },
  {
    label: 'secondary name link on secondary-container (selected row)',
    floor: 4.5,
    light: { fg: { role: 'secondary', variant: 'light' }, bg: { role: 'secondary-container', variant: 'light' } },
    dark: { fg: { role: 'secondary', variant: 'dark' }, bg: { role: 'secondary-container', variant: 'dark' } },
    published: { light: 4.56, dark: 5.17 },
  },
  {
    label: 'toast link (secondary text on inverse-surface)',
    floor: 4.5,
    light: { fg: { role: 'secondary', variant: 'dark' }, bg: { role: 'inverse-surface', variant: 'light' } },
    dark: { fg: { role: 'secondary', variant: 'light' }, bg: { role: 'inverse-surface', variant: 'dark' } },
    // Dark is marginal (4.64 against a 4.5 floor) but still passes -- unlike the
    // restrained/secondary-container guard above, this one is not a documented
    // failure, only a close call DESIGN.md flags for a regression test.
    published: { light: 7.42, dark: 4.64 },
  },
];

/**
 * The four measured-and-rejected pairs (DESIGN.md, "Measured and rejected --
 * never drawn", lines 838-845). Two are plain opaque hex-on-hex pairs
 * (`tokenPair: true`) and are recomputed here from the shipped tokens, exactly
 * like `LOAD_BEARING`, so a token mutation is caught. The other two describe an
 * *alpha-blended* treatment (`on-shell` at a stated opacity; a card at 60%
 * opacity) -- Design Notes #5 is explicit that this checker does not cover
 * browser-composited alpha blending ("not tokens and belong to the stories that
 * draw them"), so those two (`tokenPair: false`) are not recomputed from hex;
 * their `published` figure is instead asserted directly against the floor, as
 * the historical fact DESIGN.md already measured and rejected.
 */
export const REJECTED = [
  {
    label: 'on-shell at 72% opacity on shell-edge -- the header eyebrow ships at 100% instead',
    floor: 4.5,
    tokenPair: false,
    published: { light: 3.60, dark: 4.17 },
  },
  {
    // Not a clean hex-pair check, deliberately: the gradient's contrast against
    // `shell` varies continuously from 1.94 (at the `shell-edge` end) up to 3.10
    // (at the `#2090A0` far end, light mode) -- the far endpoint alone actually
    // *clears* the 3.0 floor (verified: contrastRatio of logo-gradient-stop
    // against shell computes to ~3.10, not a failure), so no single role-pair
    // stands in for "the gradient". The recorded published figure is therefore
    // the range's own low (failing) end, taken as the historical fact DESIGN.md
    // measured and rejected -- not recomputed here, matching Design Notes #5's
    // scope carve-out for composited/interpolated treatments.
    label: 'retired gradient indicator (shell-edge to the logo teal) against the chrome -- low end of the range',
    floor: 3.0,
    tokenPair: false,
    published: { light: 1.94, dark: 2.00 },
  },
  {
    label: 'expired card at 60% opacity -- the "labels" sub-case',
    floor: 4.5,
    tokenPair: false,
    published: { light: 2.89, dark: 4.33 },
  },
  {
    label: 'agent-accent (light) as the attention dot on shell -- rule 1',
    floor: 3.0,
    tokenPair: true,
    fg: 'agent-accent',
    bg: 'shell',
    published: { light: 1.80, dark: null },
  },
];
