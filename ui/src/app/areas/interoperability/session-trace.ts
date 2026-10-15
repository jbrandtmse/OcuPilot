/**
 * A session's trace as the client draws it (Story 20.30, AD-5, AD-11, AD-47): the model the sequence diagram and the Mermaid text
 * are both built from, the diagram's geometry, and the Mermaid text itself. Framework-free: it takes the rows the Trace tab's read
 * answered and returns plain values, which the body component binds into its template as attribute values and interpolated text,
 * never as markup.
 *
 * The Mermaid rules (a participant's id, the escaping of a name and a label, the `participant` line) are a port of the sibling project
 * iris-execute-mcp-v2's `Diagram/Writer.cls` (MIT, Copyright (c) 2026 jbrandtmse), without its compression, its correlation of a
 * request with its response, or its comment lines: one arrow to a row, in `Step` order.
 */

import { textOf } from '../../core/screen-read';
import { STRINGS } from '../../core/strings';
import { fieldOf } from '../../core/table-model';

/** One message of the session, as an arrow between two participants. */
export interface TraceArrow {
  /** The header's `ID`, kept exactly (AD-13). */
  readonly id: string;
  readonly step: number;
  /** The source's configuration name; `''` for a header that names none. */
  readonly from: string;
  /** The target's configuration name; `''` for a header that names none. */
  readonly to: string;
  /** A `Response` is dashed; every other type is solid. */
  readonly kind: 'request' | 'response';
  readonly error: boolean;
  /** The type and status as the header's display words. */
  readonly type: string;
  readonly status: string;
  /** The body class, whitespace-collapsed; `''` for a message with none. */
  readonly body: string;
  /** What the diagram writes on the arrow: the body class or "(no body)", then the error mark. */
  readonly label: string;
}

/** The session's participants and arrows. */
export interface TraceModel {
  /** In first-appearance order: for each arrow in `Step` order, its source, then its target. */
  readonly participants: readonly string[];
  readonly arrows: readonly TraceArrow[];
}

/** Collapse CR, LF and TAB to a space, then trim a space, a tab or a no-break space from both ends (Writer's single-line rule). */
function collapse(text: string): string {
  return text.replace(/[\r\n\t]/g, ' ').replace(/^[ \t\u00a0]+|[ \t\u00a0]+$/g, '');
}

/** The label an arrow carries: the collapsed body class, or "(no body)", then the error mark. */
function labelOf(body: string, error: boolean): string {
  return (body === '' ? STRINGS.interopTraceNoBody : body) + (error ? ` ${STRINGS.interopTraceErrorMark}` : '');
}

/**
 * The model of the rows the Trace tab's read answered: one arrow to a row, in `Step` order (a row without a numeric `Step` takes its
 * place in the answer), and the participants in the order the arrows first name them.
 */
export function traceModel(rows: readonly unknown[]): TraceModel {
  const ordered = rows
    .map((row, index) => {
      const step = fieldOf(row, 'Step');
      return { row, index, step: typeof step === 'number' && Number.isFinite(step) ? step : index + 1 };
    })
    .sort((a, b) => a.step - b.step || a.index - b.index);
  const participants: string[] = [];
  const arrows: TraceArrow[] = ordered.map(({ row, step }) => {
    const from = textOf(fieldOf(row, 'Source'));
    const to = textOf(fieldOf(row, 'Target'));
    for (const name of [from, to]) if (!participants.includes(name)) participants.push(name);
    const type = textOf(fieldOf(row, 'Type'));
    const error = fieldOf(row, 'Error') === true;
    const body = collapse(textOf(fieldOf(row, 'BodyClass')));
    return {
      id: textOf(fieldOf(row, 'ID')),
      step,
      from,
      to,
      kind: type === 'Response' ? 'response' : 'request',
      error,
      type,
      status: textOf(fieldOf(row, 'Status')),
      body,
      label: labelOf(body, error),
    };
  });
  return { participants, arrows };
}

/** The name a participant is drawn and announced under: its configuration name, or "(no name)" for none. */
export function participantName(name: string): string {
  return name === '' ? STRINGS.interopTraceNoName : name;
}

/** The most characters of a participant's name its head draws; a longer one ends with an ellipsis, and its `<title>` holds it whole. */
export const HEAD_CHARACTERS = 24;

/** A participant's name as its head draws it. */
export function headText(name: string): string {
  const shown = participantName(name);
  return shown.length > HEAD_CHARACTERS ? `${shown.slice(0, HEAD_CHARACTERS - 1)}\u2026` : shown;
}

/** One arrow's accessible name: its message, type, participants and status. */
export function arrowName(arrow: TraceArrow): string {
  const values: Readonly<Record<string, string>> = {
    id: arrow.id,
    type: arrow.type,
    source: participantName(arrow.from),
    target: participantName(arrow.to),
    status: arrow.status,
  };
  return STRINGS.interopTraceArrow.replace(/<(id|type|source|target|status)>/g, (_placeholder, key: string) => values[key] ?? '');
}

// --- The diagram's geometry ---------------------------------------------------------------------

/** Pixels between two lifelines, the width of a participant's head, and the height of the heads' band. */
export const COLUMN_WIDTH = 200;
export const HEAD_WIDTH = 176;
export const HEAD_HEIGHT = 34;
/** The height of one arrow's band, which is its link's hit area. */
export const ROW_HEIGHT = 48;
const TOP = 8;
const BOTTOM = 12;
const ARROWHEAD = 8;
const LOOP_WIDTH = 36;

/** One participant's head and lifeline. */
export interface DrawnHead {
  readonly name: string;
  /** The name as the head draws it, cut at `HEAD_CHARACTERS`. */
  readonly text: string;
  /** The lifeline's x. */
  readonly x: number;
  readonly left: number;
  readonly top: number;
}

/** One arrow's geometry: its band, its line, its head, and where its label and `ID` sit. */
export interface DrawnArrow {
  readonly arrow: TraceArrow;
  /** The band the arrow's link covers. */
  readonly bandTop: number;
  /** The line's end points, or `null` for a call a participant makes to itself, which draws `loop`. */
  readonly line: { readonly x1: number; readonly y1: number; readonly x2: number; readonly y2: number } | null;
  /** A self call's path, or `''`. */
  readonly loop: string;
  /** The arrowhead's path. */
  readonly head: string;
  readonly labelX: number;
  readonly labelY: number;
  readonly labelAnchor: 'middle' | 'start';
  readonly idY: number;
}

/** The diagram of a model: its size and every head, lifeline and arrow placed. */
export interface TraceLayout {
  readonly width: number;
  readonly height: number;
  /** The width of the `ID` gutter at the left. */
  readonly gutter: number;
  readonly heads: readonly DrawnHead[];
  /** Where the lifelines end. */
  readonly lifelineEnd: number;
  readonly arrows: readonly DrawnArrow[];
}

/** An arrowhead whose tip is at `(x, y)`, pointing right when `direction` is 1 and left when it is -1. */
function arrowheadPath(x: number, y: number, direction: number): string {
  const back = x - direction * ARROWHEAD;
  return `M ${x} ${y} L ${back} ${y - 4} L ${back} ${y + 4} Z`;
}

/** The geometry of `model`: columns in participant order, one band to an arrow, an `ID` gutter as wide as its longest `ID`. */
export function traceLayout(model: TraceModel): TraceLayout {
  const longestId = model.arrows.reduce((longest, arrow) => Math.max(longest, arrow.id.length), 0);
  const gutter = Math.max(48, 20 + longestId * 8);
  const columns = Math.max(1, model.participants.length);
  const centre = (name: string): number => gutter + COLUMN_WIDTH / 2 + model.participants.indexOf(name) * COLUMN_WIDTH;
  const bandsTop = TOP + HEAD_HEIGHT;
  const height = bandsTop + model.arrows.length * ROW_HEIGHT + BOTTOM;
  const heads = model.participants.map((name, index) => {
    const x = gutter + COLUMN_WIDTH / 2 + index * COLUMN_WIDTH;
    return { name, text: headText(name), x, left: x - HEAD_WIDTH / 2, top: TOP };
  });
  const arrows = model.arrows.map((arrow, index): DrawnArrow => {
    const bandTop = bandsTop + index * ROW_HEIGHT;
    const y = bandTop + 28;
    const x1 = centre(arrow.from);
    const x2 = centre(arrow.to);
    if (arrow.from === arrow.to) {
      const loop = `M ${x1} ${y - 2} H ${x1 + LOOP_WIDTH} V ${y + 12} H ${x1 + ARROWHEAD}`;
      return {
        arrow,
        bandTop,
        line: null,
        loop,
        head: arrowheadPath(x1, y + 12, -1),
        labelX: x1 + LOOP_WIDTH + 8,
        labelY: y + 8,
        labelAnchor: 'start',
        idY: y + 4,
      };
    }
    const direction = x2 > x1 ? 1 : -1;
    return {
      arrow,
      bandTop,
      line: { x1, y1: y, x2: x2 - direction * ARROWHEAD, y2: y },
      loop: '',
      head: arrowheadPath(x2, y, direction),
      labelX: (x1 + x2) / 2,
      labelY: bandTop + 16,
      labelAnchor: 'middle',
      idY: y + 4,
    };
  });
  return {
    width: gutter + columns * COLUMN_WIDTH + 8,
    height,
    gutter,
    heads,
    lifelineEnd: height - 8,
    arrows,
  };
}

// --- Mermaid ------------------------------------------------------------------------------------

/** Mermaid statement keywords, which cannot serve as a bare participant id (Writer's list, 27 of them). */
const KEYWORDS = new Set(
  'end,loop,alt,opt,par,and,else,rect,break,critical,option,box,participant,actor,activate,deactivate,note,over,autonumber,title,sequencediagram,create,destroy,links,link,properties,details'.split(',')
);

/**
 * A participant's name as a Mermaid id: each UTF-16 code unit outside `[A-Za-z0-9_.]` becomes `_`, an empty id becomes `P`, and an id
 * equal in any letter case to a keyword takes a trailing `_`.
 */
function mermaidBase(name: string): string {
  let id = '';
  for (let at = 0; at < name.length; at += 1) {
    const code = name.charCodeAt(at);
    const keep = (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || (code >= 48 && code <= 57) || code === 95 || code === 46;
    id += keep ? name.charAt(at) : '_';
  }
  if (id === '') id = 'P';
  return KEYWORDS.has(id.toLowerCase()) ? `${id}_` : id;
}

/** A name or a label as one Mermaid line of text: whitespace collapsed (`collapse`), then `;` written as `#59;`. */
function mermaidText(text: string): string {
  return collapse(text).split(';').join('#59;');
}

/**
 * The Mermaid `sequenceDiagram` text of `model`, built from the rows the diagram draws: one `participant` line for each participant,
 * in order, then one arrow line for each row, `->>` for a request and `-->>` for a response, lines joined by a line feed with none at
 * the end. A taken id takes `_2`, then `_3`, in the order the participants are declared; a name always has the one id.
 */
export function traceMermaid(model: TraceModel): string {
  const taken = new Set<string>();
  const ids = new Map<string, string>();
  const lines = ['sequenceDiagram'];
  for (const name of model.participants) {
    const base = mermaidBase(name);
    let id = base;
    for (let suffix = 2; taken.has(id); suffix += 1) id = `${base}_${suffix}`;
    taken.add(id);
    ids.set(name, id);
    const shown = mermaidText(name);
    lines.push(shown === '' || shown === id ? `participant ${id}` : `participant ${id} as ${shown}`);
  }
  for (const arrow of model.arrows) {
    const text = arrow.body === '' ? STRINGS.interopTraceNoBody : mermaidText(arrow.body);
    const label = text + (arrow.error ? ` ${STRINGS.interopTraceErrorMark}` : '');
    lines.push(`${ids.get(arrow.from)}${arrow.kind === 'response' ? '-->>' : '->>'}${ids.get(arrow.to)}: ${label}`);
  }
  return lines.join('\n');
}
