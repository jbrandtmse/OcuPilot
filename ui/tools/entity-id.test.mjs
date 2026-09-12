import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the client half of AD-13's wire contract against the server half.
//
// `ui/src/app/core/entity-id.ts` and `OcuPilot.Kernel.EntityId` must produce the SAME
// segment for the same id: the client writes the URL and the ObjectScript route target
// decodes it, so a change to either alone breaks a deep link with every other suite green.
// The expectations below are the same table `OcuPilot.Test.EntityId` asserts the server
// codec against, so the two tests fail together rather than drifting apart.
//
// The server side is unreachable from here (it runs inside IRIS), which is why the contract
// is expressed as literals on both sides rather than as a cross-process comparison.
//
// Mutations (Rule 19):
// - make `encodeEntityId` a single `encodeURIComponent` -> every non-trivial row goes red.
// - make `decodeEntityId` decode twice -> the round-trip rows go red.
const entityIdPath = join(
  dirname(fileURLToPath(import.meta.url)),
  '..',
  'src',
  'app',
  'core',
  'entity-id.ts'
);
const { encodeEntityId, decodeEntityId, joinCompositeId, splitCompositeId, COMPOSITE_SEPARATOR } =
  await import(entityIdPath);

// original -> the segment a browser must put in the URL (percent-encoded twice, UTF-8
// first). Every value is authored as an ASCII escape rather than a literal byte.
const CORPUS = [
  ['_SYSTEM', '_SYSTEM'],
  ['a/b', 'a%252Fb'],
  ['a b', 'a%2520b'],
  ['100%', '100%2525'],
  ['caf\u00E9', 'caf%25C3%25A9'],
  ['x?y', 'x%253Fy'],
  ['#frag', '%2523frag'],
  ['/csp/myapp', '%252Fcsp%252Fmyapp'],
  // DW-97. Neither corpus carried a dot, so a one-sided change to either codec would have
  // left both parity suites green. An id whose encoded form still held a literal ".." would
  // be refused by the static handler (AD-21) before the shell document was ever served.
  ['a..b', 'a%252E%252Eb'],
  ['..leading', '%252E%252Eleading'],
  ['trailing.', 'trailing%252E'],
];

// What the front web server and %CSP.REST do to a path segment before the route target
// sees it: percent-decode exactly once. (UTF-8 decoding happens there too; in JavaScript
// `decodeURIComponent` does both at once, which is why one call models the whole hop.)
function serverDecode(segment) {
  return decodeURIComponent(segment);
}

test('the client encodes an entity id into exactly the segment the server codec expects', () => {
  for (const [original, expected] of CORPUS) {
    assert.equal(
      encodeEntityId(original),
      expected,
      `encodeEntityId(${JSON.stringify(original)}) must match OcuPilot.Kernel.EntityId.Encode`
    );
  }
});

test('no encoded segment carries a raw / or a literal %2F', () => {
  for (const [original] of CORPUS) {
    const encoded = encodeEntityId(original);
    assert.ok(!encoded.includes('/'), `${JSON.stringify(original)} must encode to one path segment`);
    assert.ok(
      !/%2F/i.test(encoded.replace(/%25/g, '')),
      `${JSON.stringify(original)} must not encode to a literal %2F — the front web server refuses one`
    );
  }
});

test('no encoded segment carries a literal .., which the static handler refuses outright', () => {
  for (const [original] of CORPUS) {
    const encoded = encodeEntityId(original);
    assert.ok(
      !encoded.includes('..'),
      `${JSON.stringify(original)} must not encode to a segment holding a literal .. (AD-21, DW-97)`
    );
    // And the hop the web server performs must not produce one either: it decodes exactly
    // once, so what StaticHandler sees is this, not the original.
    assert.ok(
      !serverDecode(encoded).includes('..'),
      `${JSON.stringify(original)} must not arrive at the handler carrying a literal ..`
    );
  }
});

test('a segment survives the wire trip: encode twice, the server decodes once, the client decodes once', () => {
  for (const [original] of CORPUS) {
    assert.equal(
      decodeEntityId(serverDecode(encodeEntityId(original))),
      original,
      `${JSON.stringify(original)} must survive the round trip byte for byte`
    );
  }
});

test('a composite id is still one path segment, and its parts come back in order', () => {
  // AD-13: the descriptor names the parts and this codec joins them. The whole trip, so the
  // grammar is pinned end to end rather than against itself: join -> encode twice -> the
  // server's one decode -> decode -> split.
  const parts = ['HSCUSTOM', '/csp/myapp'];
  const encoded = encodeEntityId(joinCompositeId(parts));
  assert.ok(!encoded.includes('/'), 'a composite id must still occupy exactly one path segment');
  assert.deepEqual(splitCompositeId(decodeEntityId(serverDecode(encoded))), parts);
  assert.equal(COMPOSITE_SEPARATOR, '\u0001', 'the separator mirrors OcuPilot.Kernel.EntityId');
  assert.deepEqual(splitCompositeId(joinCompositeId(['only'])), ['only'], 'one part is a degenerate composite');
});

test('decodeEntityId returns a malformed segment unchanged rather than throwing', () => {
  assert.equal(decodeEntityId('%'), '%');
  assert.equal(decodeEntityId('%zz'), '%zz');
});
