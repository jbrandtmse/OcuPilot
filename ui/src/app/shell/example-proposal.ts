/**
 * The proposal card's framework-free half: the view model every card renders, the one placeholder
 * resolver over it, and the static example the configuration-empty state shows.
 *
 * It is a module of its own rather than part of `proposal-card.ts` so `node --test` can execute
 * it: `ui/tools/example-proposal.test.mjs` re-derives every value below from `EXPERIENCE.md`'s
 * UJ-3 step 3 and composes the title exactly as the component does, which a file importing
 * `@angular/core` could not offer it.
 *
 * **The example's content is data, not copy.** In a live card the entity type, the name, the field
 * names, the values, the rationale, the impact and the reversal all come from the instance and the
 * model, so none of them can be a string-table key. The static example is that same shape filled
 * with UJ-3's values, which is why it lives here and why its own test re-derives it from the
 * document rather than from this file. The card's *chrome* -- the title pattern, the two direction
 * words, the two headings, `Reverse:`, the unchanged caption and the example band -- is copy, and
 * comes from `core/strings.ts`.
 */

/** One changed field, as the card draws it: the label, the before value and the after value. */
export interface ProposalDiffRow {
  readonly field: string;
  readonly before: string;
  readonly after: string;
}

/** Everything a proposal card renders. Story 5.2 mints one of these per live proposal. */
export interface ProposalCardView {
  /** The kind of thing the write is about, as the instance names it ("Web application"). */
  readonly entityType: string;
  /** The target's own name, as the instance stores it ("/csp/myapp"). */
  readonly name: string;
  /** The changed fields, first in the card and one `diff-row` each. */
  readonly changed: readonly ProposalDiffRow[];
  /** How many fields the payload also sends unchanged (AD-4), for the collapsed caption. */
  readonly unchangedCount: number;
  /** The agent's own words, rendered under their published headings and on the agent tint. */
  readonly rationale: string;
  readonly expectedImpact: string;
  /** How to undo the write, or `''` where no reversal exists (a delete has none). */
  readonly reverse: string;
}

/** The placeholders the published card title leaves for the target's two halves. */
export const ENTITY_TYPE_PLACEHOLDER = '<entity type>';
export const ENTITY_NAME_PLACEHOLDER = '<name>';

/**
 * `Proposal (middle dot) <entity type> <name>` with both slots resolved from the view model.
 *
 * A function rather than a `replace` inside the template, for the reason `formatVersionMismatch`
 * is one: renaming a placeholder on one side only would ship the placeholder to the reader, and a
 * source-text pin cannot see that.
 */
export function formatProposalTitle(template: string, entityType: string, name: string): string {
  return template
    .split(ENTITY_TYPE_PLACEHOLDER)
    .join(entityType)
    .split(ENTITY_NAME_PLACEHOLDER)
    .join(name);
}

/** The placeholder the published unchanged-fields caption leaves for the count. */
export const UNCHANGED_COUNT_PLACEHOLDER = 'N';

/** `N unchanged fields` with the payload's own count in place of the `N`. */
export function formatUnchangedCaption(template: string, count: number): string {
  return template.split(UNCHANGED_COUNT_PLACEHOLDER).join(String(count));
}

/**
 * UJ-3's card, verbatim: the write the contest demo makes, shown before any key exists so a
 * visitor can see what a proposal looks like.
 *
 * Every value is `EXPERIENCE.md`'s own, and `ui/tools/example-proposal.test.mjs` re-derives each
 * one from that step rather than from this constant -- the technique `strings.test.mjs` already
 * uses for the version-mismatch sentence.
 */
export const EXAMPLE_PROPOSAL: ProposalCardView = {
  entityType: 'Web application',
  name: '/csp/myapp',
  changed: [
    { field: 'Enabled', before: 'No', after: 'Yes' },
    { field: 'Resource', before: '(none)', after: '%Development' },
  ],
  unchangedCount: 38,
  rationale: 'The application is disabled and carries no resource, so nobody can reach it.',
  expectedImpact: 'users holding %Development can reach the application',
  reverse: 'disable /csp/myapp and clear its resource',
};
