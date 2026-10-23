import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the session trace's own view state (AD-19, Story 20.30): `SessionTraceView`, which the Trace tab's body component holds and
// mirrors into a signal. The diagram is shown until the person chooses the Mermaid text, choosing the view already shown changes
// and says nothing, every subscriber hears a change once, and a subscriber that lets go hears no more.
//
// Mutations (Rule 19):
// - drop the same-view guard from `setView` -> the "already shown" leg goes red.
// - make the function `subscribe` returns do nothing -> the "lets go" leg goes red.
// - start `viewValue` at 'mermaid' -> the default leg goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { SESSION_TRACE_VIEWS, SessionTraceView } = await import(join(uiRoot, 'src', 'app', 'areas', 'interoperability', 'session-trace.store.ts'));

test('the views are the diagram then the Mermaid text, and the diagram is shown until one is chosen', () => {
  assert.deepEqual([...SESSION_TRACE_VIEWS], ['diagram', 'mermaid']);
  assert.equal(new SessionTraceView().view(), 'diagram');
});

test('choosing the other view changes it and tells every subscriber once', () => {
  const trace = new SessionTraceView();
  const heard = [];
  trace.subscribe(() => heard.push(['first', trace.view()]));
  trace.subscribe(() => heard.push(['second', trace.view()]));
  trace.setView('mermaid');
  assert.equal(trace.view(), 'mermaid');
  assert.deepEqual(heard, [['first', 'mermaid'], ['second', 'mermaid']]);
  trace.setView('diagram');
  assert.equal(trace.view(), 'diagram');
  assert.equal(heard.length, 4);
});

test('choosing the view already shown changes nothing and tells no one', () => {
  const trace = new SessionTraceView();
  let heard = 0;
  trace.subscribe(() => (heard += 1));
  trace.setView('diagram');
  assert.equal(heard, 0);
  trace.setView('mermaid');
  trace.setView('mermaid');
  assert.equal(heard, 1);
});

test('a subscriber that lets go hears no more, and the others still do', () => {
  const trace = new SessionTraceView();
  let kept = 0;
  let dropped = 0;
  trace.subscribe(() => (kept += 1));
  const stop = trace.subscribe(() => (dropped += 1));
  trace.setView('mermaid');
  stop();
  trace.setView('diagram');
  assert.equal(kept, 2);
  assert.equal(dropped, 1);
  stop();
  trace.setView('mermaid');
  assert.equal(kept, 3);
  assert.equal(dropped, 1);
});
