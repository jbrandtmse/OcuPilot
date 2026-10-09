import { ChangeDetectionStrategy, Component, input } from '@angular/core';

import { STRINGS } from '../core/strings';
import {
  CONTEXT_LINES,
  type DiffLine,
  type DiffSegment,
  changeCounts,
  hunks,
  lineDiff,
} from '../areas/system-explorer/line-diff';

/**
 * The lines of one side of a changed-lines hunk: its LF pieces, with the empty piece a final LF
 * leaves dropped, so `"a\nb\n"` is two lines and `""` is none.
 */
export function hunkLines(text: string): string[] {
  const pieces = text.split('\n');
  if (pieces.length > 0 && pieces[pieces.length - 1] === '') pieces.pop();
  return pieces;
}

/**
 * The edit script of a hunk's two sides. Where the line diff answers `null` (more edits than it
 * computes), every before line is a removal and every after line an addition, in that order.
 */
export function hunkScript(before: string, after: string): DiffLine[] {
  const left = hunkLines(before);
  const right = hunkLines(after);
  const script = lineDiff(left, right);
  if (script !== null) return script;
  return [
    ...left.map((text, index): DiffLine => ({ kind: 'removed', left: index + 1, text })),
    ...right.map((text, index): DiffLine => ({ kind: 'added', right: index + 1, text })),
  ];
}

/** The lines a hunk removes and adds, for the card's summary line. */
export function hunkCounts(before: string, after: string): { readonly removed: number; readonly added: number } {
  return changeCounts(hunkScript(before, after));
}

/**
 * The rows `app-text-diff` draws for a hunk, as text: each drawn line's text, and an empty row for each
 * collapsed run of unchanged lines. The card's long-block estimate counts these, not the hunk's two sides.
 */
export function hunkRowTexts(before: string, after: string): string[] {
  return hunks(hunkScript(before, after), CONTEXT_LINES).flatMap((segment: DiffSegment): string[] =>
    segment.kind === 'collapsed' ? [''] : segment.lines.map((line) => line.text)
  );
}

/** The sign each kind of line carries before its text. */
const SIGNS: Readonly<Record<DiffLine['kind'], string>> = { same: ' ', removed: '\u2212', added: '+' };

/** The direction each kind of line announces. */
const DIRECTIONS: Readonly<Record<DiffLine['kind'], string>> = {
  same: '',
  removed: STRINGS.proposalDiffRemoved,
  added: STRINGS.explorerDiffAdded,
};

/** One drawn line: its key, its sign, its announced direction, its number and its text. */
export interface TextDiffLineView {
  readonly key: string;
  readonly kind: DiffLine['kind'];
  readonly sign: string;
  readonly direction: string;
  readonly number: string;
  readonly text: string;
}

/** One drawn segment: its lines, or the collapsed run's caption when it is one. */
export interface TextDiffSegmentView {
  readonly key: string;
  readonly lines: readonly TextDiffLineView[];
  readonly collapsed: string;
}

/**
 * A changed-lines hunk of a document's text (Story 20.21), drawn as a line diff: the same markup and
 * classes Compare draws (`code-compare.page.ts`), its region labeled by `label`. The hunk is the
 * instance's own; this component only computes the diff of its two sides, with three lines of
 * context and the unchanged runs between changes collapsed to a count.
 *
 * `line` is the number of the hunk's first line in the document, so numbers are offset by `line - 1`.
 */
@Component({
  selector: 'app-text-diff',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'ocu-text-diff' },
  template: `<div class="ocu-line-diff" tabindex="0" role="region" [attr.aria-label]="label()">
    @for (segment of segmentList; track segment.key) {
      @if (segment.collapsed) {
        <div class="ocu-line-diff-collapsed" data-ocu-diff="collapsed">{{ segment.collapsed }}</div>
      } @else {
        @for (line of segment.lines; track line.key) {
          <div class="ocu-line-diff-line" [attr.data-ocu-diff]="line.kind" [class.ocu-line-diff-removed]="line.kind === 'removed'" [class.ocu-line-diff-added]="line.kind === 'added'">
            <span class="ocu-line-diff-number">{{ line.number }}</span>
            <span class="ocu-line-diff-sign" aria-hidden="true">{{ line.sign }}</span>
            @if (line.direction) {
              <span class="ocu-diff-direction">{{ line.direction }}</span>
            }
            <span class="ocu-line-diff-text">{{ line.text }}</span>
          </div>
        }
      }
    }
  </div>`,
})
export class TextDiff {
  /** The hunk's old lines, as one LF-terminated text. */
  readonly before = input<string>('');

  /** The hunk's new lines, as one LF-terminated text. */
  readonly after = input<string>('');

  /** The document line number of the hunk's first line. */
  readonly line = input<number>(1);

  /** The name the region is labeled with, the card's own name for the document. */
  readonly label = input<string>('');

  /** The segments for the template's `@for`, whose clause stays a plain property read. */
  protected get segmentList(): readonly TextDiffSegmentView[] {
    return this.segmentsOf(hunkScript(this.before(), this.after()));
  }

  private segmentsOf(script: readonly DiffLine[]): TextDiffSegmentView[] {
    const offset = Math.max(1, Math.floor(this.line())) - 1;
    return hunks(script, CONTEXT_LINES).map((segment: DiffSegment, index: number): TextDiffSegmentView => {
      if (segment.kind === 'collapsed') {
        return {
          key: `${index}`,
          lines: [],
          collapsed: STRINGS.explorerCompareUnchanged.split('<n>').join(String(segment.count)),
        };
      }
      return {
        key: `${index}`,
        collapsed: '',
        lines: segment.lines.map((line, lineIndex): TextDiffLineView => {
          const number = (line.kind === 'added' ? line.right : line.left) ?? 0;
          return {
            key: `${index}.${lineIndex}`,
            kind: line.kind,
            sign: SIGNS[line.kind],
            direction: DIRECTIONS[line.kind],
            number: `${number + offset}`,
            text: line.text,
          };
        }),
      };
    });
  }
}
