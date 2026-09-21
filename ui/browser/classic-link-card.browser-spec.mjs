/**
 * The classic-link card's geometry and hover, measured in a real browser.
 *
 * jsdom computes no layout and paints nothing, so `classic-link-card.spec.ts` can pin which
 * elements render and `design-tokens.test.mjs` which declarations the stylesheet carries, but
 * neither can say that a long page name stays inside its pill or that hovering the action
 * changes what is painted. This spec renders the card's own inline template, read out of
 * `classic-link-card.ts`, under the stylesheet the real build emitted, and measures both.
 *
 * **It needs `npm run build` and no instance.** The page is served from `dist/` by a server this
 * spec starts on a loopback port and stops when it finishes.
 *
 * Run: `npm run test:browser` (after `npm run build`), or this file alone with `node --test`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, extname, join, normalize, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const config = browserConfig();
const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const distBrowserDir = join(uiRoot, 'dist', 'ocupilot-ui', 'browser');
const cardSourcePath = join(uiRoot, 'src', 'app', 'shell', 'classic-link-card.ts');

/** The column the card is laid out in, and the label that has to fit in it. */
const COLUMN_WIDTH_PX = 320;
const LONG_LABEL = 'Classic portal page with a declared name long enough to overrun its pill '.padEnd(120, 'x');
const HREF = '/csp/sys/OcuPilotTestClassicPage.csp';

const PAGE_PATH = '/classic-link-card.html';

const CONTENT_TYPES = {
  '.css': 'text/css',
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.png': 'image/png',
  '.woff2': 'font/woff2',
};

/**
 * The card's markup: its inline template with the `@if` wrapper removed and every binding
 * resolved. Every binding the template carries must be one this function knows, so a template
 * that grows a binding fails here rather than rendering a literal `{{ }}`.
 */
function renderCardTemplate() {
  const source = readFileSync(cardSourcePath, 'utf8');
  const template = /template:\s*`([\s\S]*?)`/.exec(source);
  assert.ok(template, 'classic-link-card.ts declares an inline template');
  const glyph = /externalGlyph = '((?:[^'\\]|\\.)*)'/.exec(source);
  assert.ok(glyph, 'classic-link-card.ts declares its external glyph');

  const strings = loadStrings();
  const values = {
    label: LONG_LABEL,
    externalGlyph: glyph[1].replace(/\\u([0-9a-fA-F]{4})/g, (_, hex) => String.fromCharCode(parseInt(hex, 16))),
  };

  let html = template[1].trim();
  const wrapper = /^@if \(present\) \{([\s\S]*)\}$/.exec(html);
  assert.ok(wrapper, 'the template is one @if (present) block');
  html = wrapper[1];

  html = html.replace(/\{\{\s*([\w.]+)\s*\}\}/g, (whole, expression) => {
    const key = expression.startsWith('STRINGS.') ? expression.slice('STRINGS.'.length) : null;
    if (key !== null && key in strings) return escapeHtml(strings[key]);
    if (expression in values) return escapeHtml(values[expression]);
    assert.fail(`the card template binds ${whole}, which this spec does not resolve`);
  });
  html = html.replace(/\[href\]="href"/g, `href="${HREF}"`);
  assert.doesNotMatch(html, /\{\{|\[[\w.-]+\]=|\(\w+\)=|@if|@for/, 'every binding in the template was resolved');
  return html;
}

function escapeHtml(text) {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function builtStylesheet() {
  let files;
  try {
    files = readdirSync(distBrowserDir);
  } catch {
    assert.fail(`expected ${distBrowserDir} -- run npm run build before this spec`);
  }
  const name = files.find((file) => /^styles-[0-9A-Za-z]{6,}\.css$/.test(file));
  assert.ok(name, `expected a built styles-<HASH>.css in ${distBrowserDir}`);
  return name;
}

let server = null;
let origin = '';
let browser = null;

before(async () => {
  const page = `<!doctype html>
<html>
  <head><meta charset="utf-8"><link rel="stylesheet" href="/${builtStylesheet()}"></head>
  <body><div id="column" style="width: ${COLUMN_WIDTH_PX}px">${renderCardTemplate()}</div></body>
</html>`;

  server = createServer((request, response) => {
    const path = new URL(request.url, 'http://localhost').pathname;
    if (path === PAGE_PATH) {
      response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      response.end(page);
      return;
    }
    const file = normalize(join(distBrowserDir, path));
    if (!file.startsWith(distBrowserDir + sep)) {
      response.writeHead(404);
      response.end();
      return;
    }
    try {
      const body = readFileSync(file);
      response.writeHead(200, { 'content-type': CONTENT_TYPES[extname(file)] ?? 'application/octet-stream' });
      response.end(body);
    } catch {
      response.writeHead(404);
      response.end();
    }
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  origin = `http://127.0.0.1:${server.address().port}`;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (server !== null) await new Promise((resolve) => server.close(resolve));
});

async function cardPage() {
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  await page.goto(`${origin}${PAGE_PATH}`, { waitUntil: 'networkidle0' });
  await page.waitForSelector('.ocu-classic-link-card-action');
  return { context, page };
}

/** The RGBA of the pixel at the viewport point (x, y), read from a real screenshot. */
async function paintedPixel(page, x, y) {
  const shot = await page.screenshot({
    clip: { x, y, width: 1, height: 1 },
    encoding: 'base64',
    type: 'png',
  });
  return page.evaluate(async (data) => {
    const image = new Image();
    image.src = `data:image/png;base64,${data}`;
    await image.decode();
    const canvas = document.createElement('canvas');
    canvas.width = 1;
    canvas.height = 1;
    const context = canvas.getContext('2d');
    context.drawImage(image, 0, 0);
    return Array.from(context.getImageData(0, 0, 1, 1).data);
  }, shot);
}

test('a long page name stays inside a control-height pill, ends in an ellipsis, and keeps the glyph', async () => {
  const { context, page } = await cardPage();
  try {
    const measured = await page.evaluate(() => {
      const rect = (element) => {
        const box = element.getBoundingClientRect();
        return { left: box.left, top: box.top, right: box.right, bottom: box.bottom, width: box.width, height: box.height };
      };
      const card = document.querySelector('.ocu-classic-link-card');
      const pill = document.querySelector('.ocu-classic-link-card-action');
      const label = document.querySelector('.ocu-classic-link-card-label');
      const glyph = document.querySelector('.ocu-classic-link-card-action .ocu-external-glyph');
      return {
        controlHeight: parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--ocu-control-height')),
        card: rect(card),
        pill: rect(pill),
        pillClientHeight: pill.clientHeight,
        label: rect(label),
        labelOverflows: label.scrollWidth > label.clientWidth,
        labelTextOverflow: getComputedStyle(label).textOverflow,
        glyph: rect(glyph),
      };
    });

    assert.ok(measured.controlHeight > 0, `the token layer loaded: --ocu-control-height is ${measured.controlHeight}`);
    assert.equal(
      measured.pillClientHeight,
      measured.controlHeight,
      `the pill's inner height is --ocu-control-height: ${JSON.stringify(measured.pill)}`
    );
    assert.ok(
      measured.label.height <= measured.pillClientHeight,
      `the label is one line inside the pill: label ${JSON.stringify(measured.label)}, pill ${JSON.stringify(measured.pill)}`
    );
    assert.ok(
      measured.pill.left >= measured.card.left && measured.pill.right <= measured.card.right,
      `the pill stays inside the card: pill ${JSON.stringify(measured.pill)}, card ${JSON.stringify(measured.card)}`
    );
    assert.ok(
      measured.label.left >= measured.pill.left && measured.label.right <= measured.pill.right,
      `the label stays inside the pill: label ${JSON.stringify(measured.label)}, pill ${JSON.stringify(measured.pill)}`
    );
    assert.equal(measured.labelTextOverflow, 'ellipsis', 'the label ends in an ellipsis');
    assert.ok(measured.labelOverflows, 'and there is more label than room, so the ellipsis is showing');
    assert.ok(measured.glyph.width > 0, `the glyph keeps a width: ${JSON.stringify(measured.glyph)}`);
    assert.ok(
      measured.glyph.left >= measured.label.right - 0.5 && measured.glyph.right <= measured.pill.right,
      `the glyph sits after the label, inside the pill: glyph ${JSON.stringify(measured.glyph)}`
    );
  } finally {
    await context.close();
  }
});

test("hovering the action paints a background distinct from its resting state and from the card's", async () => {
  const { context, page } = await cardPage();
  try {
    const points = await page.evaluate(() => {
      const card = document.querySelector('.ocu-classic-link-card').getBoundingClientRect();
      const pill = document.querySelector('.ocu-classic-link-card-action').getBoundingClientRect();
      // Inside the pill's left padding, clear of its border and its label; and inside the card's
      // own padding, clear of every child.
      return {
        pill: { x: Math.round(pill.left + 8), y: Math.round(pill.top + pill.height / 2) },
        card: { x: Math.round(card.left + 4), y: Math.round(card.top + 4) },
      };
    });

    const resting = await paintedPixel(page, points.pill.x, points.pill.y);
    const cardGround = await paintedPixel(page, points.card.x, points.card.y);
    await page.hover('.ocu-classic-link-card-action');
    const hovered = await paintedPixel(page, points.pill.x, points.pill.y);

    assert.notDeepEqual(hovered, resting, `hover changes the painted background: rest ${resting}, hover ${hovered}`);
    assert.notDeepEqual(hovered, cardGround, `and is distinct from the card: card ${cardGround}, hover ${hovered}`);
  } finally {
    await context.close();
  }
});
