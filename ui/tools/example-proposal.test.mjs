import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { loadStrings, STRINGS_TS_PATH } from './strings.mjs';

// Pins the static example proposal card's CONTENT against EXPERIENCE.md's UJ-3 step 3.
//
// The example is data, not copy: in a live card the entity type, the name, the field names, the
// values, the rationale, the impact and the reversal all come from the instance and the model, so
// none of them can be a string-table key and none of them is covered by `strings.test.mjs`. What
// covers them is this: every value is re-derived from the document at run time, the way
// `strings.test.mjs` re-derives the version-mismatch sentence, rather than copied into a second
// static list here -- which would only check the parser against itself.
//
// The card's CHROME is the other half and is copy: the title pattern, the two direction words, the
// two headings, `Reverse:`, the unchanged caption and the example band are Fixed strings rows, and
// `strings.test.mjs` holds those. What this file adds on top is the composition -- the pattern with
// both of its placeholders resolved has to equal the header the document quotes.
//
// Mutations (Rule 19):
// - change any value in `EXAMPLE_PROPOSAL` (`38` to `39`, a word in the rationale) -> the matching
//   assertion below goes red naming the document's own value.
// - resolve the title's placeholders in the wrong order in `formatProposalTitle` -> the composed
//   title no longer equals the quoted header and the composition test goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const experienceMdPath = join(
  uiRoot,
  '..',
  '_bmad-output',
  'planning-artifacts',
  'ux-designs',
  'ux-OcuPilot-2026-09-08',
  'EXPERIENCE.md'
);

const experienceMdRaw = readFileSync(experienceMdPath, 'utf8');
const strings = loadStrings(readFileSync(STRINGS_TS_PATH, 'utf8'));

const { EXAMPLE_PROPOSAL, formatProposalTitle, formatUnchangedCaption } = await import(
  join(uiRoot, 'src', 'app', 'shell', 'example-proposal.ts')
);

/**
 * UJ-3's step 3, located by its own anchor rather than by line number (DW-110): a hardcoded range
 * reads the wrong line after any insertion above it, and this document has already moved once --
 * the intent contract's `:705` is `:710` after the five Fixed strings rows were appended.
 */
function uj3Step(markdown) {
  const line = markdown
    .split('\n')
    .find((candidate) => candidate.includes('The values that make this demo concrete:'));
  assert.ok(line, "EXPERIENCE.md must carry UJ-3's step 3, which states the example card's values");
  return line;
}

const STEP = uj3Step(experienceMdRaw);

/** `the header "..."` -- the composed title, entity type and name together. */
function extractHeader(step) {
  const match = /the header "([^"]+)"/.exec(step);
  assert.ok(match, 'that step must quote the card header');
  return match[1];
}

/**
 * The two changed rows, read as a span and split rather than typed here: `two diff-rows (em dash)
 * Enabled: No (arrow) Yes, Resource: (none) (arrow) %Development (em dash) with`.
 */
function extractDiffRows(step) {
  const match = /two diff-rows \u2014 (.+?) \u2014 with/.exec(step);
  assert.ok(match, 'that step must list the two diff rows between em dashes');
  return match[1].split(', ').map((entry) => {
    const parts = /^(.+?): (.+?) \u2192 (.+)$/.exec(entry.trim());
    assert.ok(parts, `a diff row reads "<field>: <before> -> <after>": ${JSON.stringify(entry)}`);
    return { field: parts[1], before: parts[2], after: parts[3] };
  });
}

function extractUnchangedCount(step) {
  const match = /with "(\d+) unchanged fields" collapsed/.exec(step);
  assert.ok(match, 'that step must state how many fields the payload also sends unchanged');
  return Number(match[1]);
}

function extractAgentText(step, heading) {
  const match = new RegExp(`"${heading}" reading "([^"]+)"`).exec(step);
  assert.ok(match, `that step must quote the text under "${heading}"`);
  return match[1];
}

function extractReverse(step) {
  const match = /"Reverse: ([^"]+)"/.exec(step);
  assert.ok(match, 'that step must quote the reversal line');
  return match[1];
}

test('the example card names UJ-3\'s own target, and the composed title is the header the document quotes', () => {
  const header = extractHeader(STEP);
  assert.equal(
    formatProposalTitle(strings.proposalCardTitle, EXAMPLE_PROPOSAL.entityType, EXAMPLE_PROPOSAL.name),
    header,
    'the published pattern with both placeholders resolved IS the quoted header'
  );
  // And the two halves are the halves, not one string that happens to concatenate: a fixture that
  // put the whole header in `entityType` would pass the line above and render a title the live
  // card could never produce.
  assert.ok(header.includes(EXAMPLE_PROPOSAL.entityType), 'the entity type is a part of it');
  assert.ok(header.endsWith(EXAMPLE_PROPOSAL.name), 'and the name is its last part');
  assert.equal(EXAMPLE_PROPOSAL.entityType, 'Web application');
  assert.equal(EXAMPLE_PROPOSAL.name, '/csp/myapp');
});

test('the two changed rows are the document\'s own, field, before and after', () => {
  assert.deepEqual(
    EXAMPLE_PROPOSAL.changed.map((row) => ({ field: row.field, before: row.before, after: row.after })),
    extractDiffRows(STEP)
  );
});

test('the unchanged count is the document\'s, and the published caption resolves to its sentence', () => {
  const count = extractUnchangedCount(STEP);
  assert.equal(EXAMPLE_PROPOSAL.unchangedCount, count);
  const caption = formatUnchangedCaption(strings.proposalUnchangedFieldsDisclosure, count);
  assert.ok(
    STEP.includes(`"${caption}"`),
    `the resolved caption is the document's own: ${JSON.stringify(caption)}`
  );
});

test("the agent's rationale and expected impact are quoted verbatim, under the published headings", () => {
  assert.equal(EXAMPLE_PROPOSAL.rationale, extractAgentText(STEP, strings.proposalRationaleHeading));
  assert.equal(EXAMPLE_PROPOSAL.expectedImpact, extractAgentText(STEP, strings.proposalExpectedImpactHeading));
});

test('the reversal line is the document\'s, and the published label is what precedes it', () => {
  assert.equal(EXAMPLE_PROPOSAL.reverse, extractReverse(STEP));
  assert.ok(
    STEP.includes(`"${strings.proposalReverseLabel} ${EXAMPLE_PROPOSAL.reverse}"`),
    'the published "Reverse:" label plus the reversal is what the document quotes'
  );
});

test('the example carries no countdown and no footer: the two things a live card adds are absent', () => {
  // UJ-3's card has a countdown ("Expires in 9:59") and Confirm/Cancel; the example variant has
  // neither (DESIGN.md's Example row). The fixture is the whole of what the card draws, so the
  // way to say "no countdown" here is that the view model has no key for one -- everything
  // live-only is a projected slot the example leaves empty, never a field set to nothing.
  assert.deepEqual(
    Object.keys(EXAMPLE_PROPOSAL).sort(),
    ['changed', 'entityType', 'expectedImpact', 'name', 'rationale', 'reverse', 'unchangedCount']
  );
});

// Story 7.10. Mutation (Rule 19): drop `displayEntityId` from `formatProposalTitle` -> the title
// carries the control character and goes red.
test('a composite target reads as its breadcrumb in the card title', () => {
  const title = formatProposalTitle(strings.proposalCardTitle, strings.errorLogListLabel, 'user\u000109/23/2026\u00014');
  assert.ok(title.endsWith('user \u203a 09/23/2026 \u203a 4'), title);
  assert.ok(!title.includes('\u0001'), 'no control character reaches the title');
});
