import { describe, expect, it } from 'vitest';

import { STRINGS } from '../../core/strings';
import {
  COLUMN_WIDTH,
  HEAD_CHARACTERS,
  ROW_HEIGHT,
  arrowName,
  headText,
  participantName,
  traceLayout,
  traceMermaid,
  traceModel,
} from './session-trace';

/** One row as the Trace tab's read answers it. */
function row(step: number, source: string, target: string, extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    Message: '11',
    Step: step,
    ID: String(10 + step),
    TimeCreated: '2026-10-14T10:00:00.000',
    Type: 'Request',
    Status: 'Completed',
    Source: source,
    Target: target,
    BodyClass: '',
    Error: false,
    SessionId: '11',
    ...extra,
  };
}

const MARKER = 'OcuPilotProbe2030ab12cd34';

/** The plan's fixture: a service, a process whose name holds a space and a semicolon, and an operation that answers with an error. */
const FIXTURE = [
  row(1, `${MARKER}Svc`, `${MARKER} Proc;1`, { BodyClass: 'Ens.StringRequest' }),
  row(2, `${MARKER} Proc;1`, `${MARKER}Op`),
  row(3, `${MARKER}Op`, `${MARKER} Proc;1`, { Type: 'Response', Status: 'Error', Error: true }),
  row(4, `${MARKER} Proc;1`, `${MARKER}Svc`, { Type: 'Response', BodyClass: 'Ens.StringResponse' }),
];

/** The Mermaid text of rows built from `names` as `[source, target]` pairs, one request each. */
function mermaidOf(...pairs: [string, string][]): string {
  return traceMermaid(traceModel(pairs.map(([source, target], index) => row(index + 1, source, target))));
}

/**
 * The session trace's model and Mermaid text (Story 20.30, AD-5, AD-11): participants in the order the arrows first name them,
 * one arrow to a row in `Step` order, a response dashed and anything else solid, an error marked; and the Mermaid rules ported from the
 * sibling project's `Diagram/Writer.cls` -- ids, escapes and labels.
 */
describe('traceModel', () => {
  // Mutation (Rule 19): register a row's target before its source -> the participants leg goes red.
  it('lists the participants in the order the arrows first name them, the source before the target', () => {
    const model = traceModel(FIXTURE);
    expect(model.participants).toEqual([`${MARKER}Svc`, `${MARKER} Proc;1`, `${MARKER}Op`]);
    expect(model.arrows.map((arrow) => [arrow.step, arrow.id, arrow.from, arrow.to])).toEqual([
      [1, '11', `${MARKER}Svc`, `${MARKER} Proc;1`],
      [2, '12', `${MARKER} Proc;1`, `${MARKER}Op`],
      [3, '13', `${MARKER}Op`, `${MARKER} Proc;1`],
      [4, '14', `${MARKER} Proc;1`, `${MARKER}Svc`],
    ]);
  });

  // Mutation (Rule 19): keep the rows in the order they were given -> the order leg goes red.
  it('puts the arrows in Step order whatever order the rows come in, and a row with no numeric Step keeps its place', () => {
    const model = traceModel([row(3, 'c', 'a'), row(1, 'a', 'b'), row(2, 'b', 'c')]);
    expect(model.arrows.map((arrow) => arrow.step)).toEqual([1, 2, 3]);
    expect(model.participants).toEqual(['a', 'b', 'c']);
    const ragged = traceModel([row(1, 'a', 'b'), row(2, 'b', 'a', { Step: 'two' })]);
    expect(ragged.arrows.map((arrow) => arrow.id)).toEqual(['11', '12']);
  });

  it('is a call a participant makes to itself when the source equals the target, with one participant', () => {
    const model = traceModel([row(1, 'Svc', 'Svc')]);
    expect(model.participants).toEqual(['Svc']);
    expect(model.arrows[0].from).toBe(model.arrows[0].to);
  });

  it('keeps an empty source or target as a participant of its own, drawn and announced as "(no name)"', () => {
    const model = traceModel([row(1, '', 'Op'), row(2, 'Op', '')]);
    expect(model.participants).toEqual(['', 'Op']);
    expect(participantName('')).toBe(STRINGS.interopTraceNoName);
    expect(headText('')).toBe(STRINGS.interopTraceNoName);
    expect(arrowName(model.arrows[0])).toBe(
      STRINGS.interopTraceArrow
        .replace('<id>', '11')
        .replace('<type>', 'Request')
        .replace('<source>', STRINGS.interopTraceNoName)
        .replace('<target>', 'Op')
        .replace('<status>', 'Completed')
    );
  });

  // Mutation (Rule 19): substitute the placeholders one after another in `arrowName` -> this goes red.
  it('writes a name that holds a placeholder into an arrow\'s accessible name as the text it is', () => {
    const [arrow] = traceModel([row(1, 'A<target>', 'B<status>')]).arrows;
    expect(arrowName(arrow)).toBe('Message 11: Request from A<target> to B<status>, Completed');
  });

  // Mutation (Rule 19): make every arrow a request -> the kinds leg goes red.
  it('makes a Response arrow a response and every other type a request', () => {
    const kinds = traceModel([row(1, 'a', 'b', { Type: 'Response' }), row(2, 'a', 'b', { Type: 'Request' }), row(3, 'a', 'b', { Type: 'Terminate' }), row(4, 'a', 'b', { Type: '' })]).arrows.map((arrow) => arrow.kind);
    expect(kinds).toEqual(['response', 'request', 'request', 'request']);
  });

  // Mutation (Rule 19): drop the error mark from `labelOf` -> the label leg goes red.
  it('labels an arrow with its body class or "(no body)", and an error with the mark after it', () => {
    const labels = traceModel([
      row(1, 'a', 'b', { BodyClass: 'Ens.StringRequest' }),
      row(2, 'a', 'b'),
      row(3, 'a', 'b', { BodyClass: '  \t ' }),
      row(4, 'a', 'b', { Error: true }),
      row(5, 'a', 'b', { Error: true, BodyClass: 'Ens.StringResponse' }),
      row(6, 'a', 'b', { Error: 'true' }),
    ]).arrows;
    expect(labels.map((arrow) => arrow.label)).toEqual([
      'Ens.StringRequest',
      STRINGS.interopTraceNoBody,
      STRINGS.interopTraceNoBody,
      `${STRINGS.interopTraceNoBody} ${STRINGS.interopTraceErrorMark}`,
      `Ens.StringResponse ${STRINGS.interopTraceErrorMark}`,
      STRINGS.interopTraceNoBody,
    ]);
    expect(labels.map((arrow) => arrow.error)).toEqual([false, false, false, true, true, false]);
  });

  it('cuts a participant\'s head at 24 characters with an ellipsis and keeps its whole name for the title', () => {
    const exact = 'a'.repeat(HEAD_CHARACTERS);
    const long = `${exact}b`;
    expect(headText(exact)).toBe(exact);
    expect(headText(long)).toBe(`${'a'.repeat(HEAD_CHARACTERS - 1)}\u2026`);
    expect(headText(long)).toHaveLength(HEAD_CHARACTERS);
    expect(participantName(long)).toBe(long);
  });
});

describe('traceMermaid', () => {
  // Mutation (Rule 19): drop the `;` escape from `mermaidText` -> this goes red; make the keyword suffix a no-op -> the keyword test goes red alone.
  it('writes the plan\'s fixture exactly', () => {
    expect(traceMermaid(traceModel(FIXTURE))).toBe(
      [
        'sequenceDiagram',
        `participant ${MARKER}Svc`,
        `participant ${MARKER}_Proc_1 as ${MARKER} Proc#59;1`,
        `participant ${MARKER}Op`,
        `${MARKER}Svc->>${MARKER}_Proc_1: Ens.StringRequest`,
        `${MARKER}_Proc_1->>${MARKER}Op: ${STRINGS.interopTraceNoBody}`,
        `${MARKER}Op-->>${MARKER}_Proc_1: ${STRINGS.interopTraceNoBody} ${STRINGS.interopTraceErrorMark}`,
        `${MARKER}_Proc_1-->>${MARKER}Svc: Ens.StringResponse`,
      ].join('\n')
    );
  });

  it('has no trailing line feed, comment line, loop or compression, and draws a self call as an arrow to the same id', () => {
    const text = traceMermaid(traceModel([row(1, 'Svc', 'Svc'), row(2, 'Svc', 'Svc')]));
    expect(text).toBe('sequenceDiagram\nparticipant Svc\nSvc->>Svc: (no body)\nSvc->>Svc: (no body)');
    expect(text.endsWith('\n')).toBe(false);
    expect(text).not.toContain('%%');
    expect(text).not.toContain('loop');
  });

  it('gives a name that is a Mermaid keyword, in any letter case, a trailing underscore', () => {
    const text = mermaidOf(['end', 'Loop'], ['PARTICIPANT', 'sequenceDiagram'], ['Note', 'plain']);
    expect(text.split('\n').filter((line) => line.startsWith('participant '))).toEqual([
      'participant end_ as end',
      'participant Loop_ as Loop',
      'participant PARTICIPANT_ as PARTICIPANT',
      'participant sequenceDiagram_ as sequenceDiagram',
      'participant Note_ as Note',
      'participant plain',
    ]);
  });

  it('gives a taken id _2, then _3, in the order the participants are declared, and a name always the same id', () => {
    const text = mermaidOf(['a b', 'a_b'], ['a-b', 'a b']);
    const lines = text.split('\n');
    expect(lines.filter((line) => line.startsWith('participant '))).toEqual([
      'participant a_b as a b',
      'participant a_b_2 as a_b',
      'participant a_b_3 as a-b',
    ]);
    expect(lines.filter((line) => line.includes('->>'))).toEqual(['a_b->>a_b_2: (no body)', 'a_b_3->>a_b: (no body)']);
  });

  it('turns each UTF-16 code unit outside [A-Za-z0-9_.] into an underscore, so a non-ASCII character and a surrogate pair differ in length', () => {
    const text = mermaidOf(['caf\u00e9.x', 'smile\ud83d\ude00']);
    expect(text.split('\n').slice(1, 3)).toEqual(['participant caf_.x as caf\u00e9.x', 'participant smile__ as smile\ud83d\ude00']);
  });

  it('declares an empty name as P and gives a later P the next id', () => {
    const text = mermaidOf(['', 'P']);
    expect(text.split('\n')).toEqual(['sequenceDiagram', 'participant P', 'participant P_2 as P', 'P->>P_2: (no body)']);
  });

  it('writes no "as" clause when the escaped name equals its id', () => {
    const text = mermaidOf(['Plain.Name_1', 'Other']);
    expect(text).toContain('participant Plain.Name_1\n');
    expect(text).not.toContain(' as ');
  });

  it('turns ; into #59;, CR, LF and TAB into a space and trims both ends of a name and a label, and escapes nothing else', () => {
    const text = traceMermaid(
      traceModel([row(1, '  line\r\nbreak\there;', 'Op', { BodyClass: '\u00a0Body;Class<&>"\' ' })])
    );
    const lines = text.split('\n');
    expect(lines[1]).toBe('participant __line__break_here_ as line  break here#59;');
    expect(lines[3]).toBe('__line__break_here_->>Op: Body#59;Class<&>"\'');
  });

  it('writes a response with --> and a request with ->', () => {
    const text = traceMermaid(traceModel([row(1, 'a', 'b'), row(2, 'b', 'a', { Type: 'Response' })]));
    expect(text.split('\n').slice(-2)).toEqual(['a->>b: (no body)', 'b-->>a: (no body)']);
  });
});

describe('traceLayout', () => {
  it('places a lifeline for each participant a column apart and a band for each arrow a row apart', () => {
    const layout = traceLayout(traceModel(FIXTURE));
    expect(layout.heads.map((head) => head.x - layout.heads[0].x)).toEqual([0, COLUMN_WIDTH, 2 * COLUMN_WIDTH]);
    expect(layout.arrows.map((drawn) => drawn.bandTop - layout.arrows[0].bandTop)).toEqual([0, ROW_HEIGHT, 2 * ROW_HEIGHT, 3 * ROW_HEIGHT]);
    expect(ROW_HEIGHT).toBeGreaterThanOrEqual(24);
    expect(layout.width).toBeGreaterThan(layout.heads[2].x);
    expect(layout.height).toBeGreaterThan(layout.arrows[3].bandTop + ROW_HEIGHT);
    expect(layout.lifelineEnd).toBeLessThanOrEqual(layout.height);
  });

  // Mutation (Rule 19): point every arrow rightward -> the leftward leg goes red.
  it('draws an arrow toward its target, a line to the left for a call back, and a loop with no line for a self call', () => {
    const layout = traceLayout(traceModel([row(1, 'a', 'b'), row(2, 'b', 'a'), row(3, 'a', 'a')]));
    const [forward, back, self] = layout.arrows;
    expect(forward.line !== null && forward.line.x2 > forward.line.x1).toBe(true);
    expect(back.line !== null && back.line.x2 < back.line.x1).toBe(true);
    // The head's tip is its path's first point, and its line stops short of it: before the tip going right, after it going left.
    const tip = (head: string): number => Number(/^M (\S+) /.exec(head)?.[1]);
    expect(forward.line !== null && forward.line.x2 < tip(forward.head)).toBe(true);
    expect(back.line !== null && back.line.x2 > tip(back.head)).toBe(true);
    expect(self.line).toBeNull();
    expect(self.loop).toMatch(/^M /);
    expect(self.labelAnchor).toBe('start');
    expect(forward.head.startsWith('M ')).toBe(true);
  });

  it('widens the ID gutter for a longer id', () => {
    const narrow = traceLayout(traceModel([row(1, 'a', 'b', { ID: '7' })]));
    const wide = traceLayout(traceModel([row(1, 'a', 'b', { ID: '9223372036854775807' })]));
    expect(wide.gutter).toBeGreaterThan(narrow.gutter);
  });

  it('lays out a model with no arrow as an empty diagram', () => {
    const layout = traceLayout(traceModel([]));
    expect(layout.heads).toEqual([]);
    expect(layout.arrows).toEqual([]);
  });
});
