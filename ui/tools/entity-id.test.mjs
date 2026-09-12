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
const { encodeEntityId, decodeEntityId } = await import(entityIdPath);

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

test('a segment survives the wire trip: encode twice, the server decodes once, the client decodes once', () => {
  for (const [original] of CORPUS) {
    assert.equal(
      decodeEntityId(serverDecode(encodeEntityId(original))),
      original,
      `${JSON.stringify(original)} must survive the round trip byte for byte`
    );
  }
});

test('decodeEntityId returns a malformed segment unchanged rather than throwing', () => {
  assert.equal(decodeEntityId('%'), '%');
  assert.equal(decodeEntityId('%zz'), '%zz');
});
