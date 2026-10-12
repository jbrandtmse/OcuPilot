import { test } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Pins `ui/src/app/core/long-blocks.ts` (Story 20.17, AD-19): the line estimate at its boundaries,
// the deterministic region id, and the framework-free store of opened blocks.
//
// Mutation (Rule 19): make `isLong` answer false -> the boundary assertions go red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { LONG_BLOCK_LINES, LONG_BLOCK_WIDTH, LongBlocks, blockId, estimateLines, isLong } = await import(
  join(uiRoot, 'src', 'app', 'core', 'long-blocks.ts')
);

test('the estimate counts each source line, and each further 80 characters of a long one', () => {
  assert.equal(LONG_BLOCK_LINES, 8);
  assert.equal(LONG_BLOCK_WIDTH, 80);
  assert.equal(estimateLines(''), 1);
  assert.equal(estimateLines('x'.repeat(80)), 1);
  assert.equal(estimateLines('x'.repeat(81)), 2);
  assert.equal(estimateLines('x'.repeat(721)), 10);
  assert.equal(estimateLines(Array(8).fill('line').join('\n')), 8);
  assert.equal(estimateLines(Array(9).fill('line').join('\n')), 9);
  assert.equal(estimateLines('a\n\nb'), 3);
});

test('a block is long above eight estimated lines and not at eight', () => {
  assert.equal(isLong(8), false);
  assert.equal(isLong(9), true);
  assert.equal(isLong(estimateLines(Array(8).fill('x'.repeat(80)).join('\n'))), false);
  assert.equal(isLong(estimateLines('x'.repeat(721))), true);
});

test('the region id derives from the key alone', () => {
  assert.equal(blockId('c1:t0:reply'), 'ocu-long-block-c1_t0_reply');
  assert.equal(blockId('p:ab-1_x:diff'), 'ocu-long-block-p_ab-1_x_diff');
  assert.equal(blockId('c1:t0:reply'), blockId('c1:t0:reply'));
  assert.notEqual(blockId('c1:t0:reply'), blockId('c1:t1:reply'));
});

test('the store remembers an opened block by key, closes it, and ignores an empty key', () => {
  const store = new LongBlocks();
  assert.equal(store.isOpen('a'), false);
  store.setOpen('a', true);
  assert.equal(store.isOpen('a'), true);
  assert.equal(store.isOpen('b'), false);
  store.setOpen('a', false);
  assert.equal(store.isOpen('a'), false);
  store.setOpen('', true);
  assert.equal(store.isOpen(''), false);
});

test('endSession forgets every opened block', () => {
  const store = new LongBlocks();
  store.setOpen('a', true);
  store.setOpen('b', true);
  store.endSession();
  assert.equal(store.isOpen('a'), false);
  assert.equal(store.isOpen('b'), false);
});

test('listeners hear a change once, stop when released, and hear nothing for a no-op', () => {
  const store = new LongBlocks();
  let heard = 0;
  const release = store.subscribe(() => {
    heard += 1;
  });
  store.setOpen('a', true);
  assert.equal(heard, 1);
  store.setOpen('a', true);
  store.setOpen('', true);
  assert.equal(heard, 1);
  store.endSession();
  assert.equal(heard, 2);
  release();
  store.setOpen('a', true);
  assert.equal(heard, 2);
});
