/**
 * How Page resources names the write actions a classic page's resource gates (Story 21.38, AD-44, AD-64).
 *
 * A page's resource gates opening each OcuPilot screen that replaces the page, and it gates each write a tool declares on the page. The instance
 * names a write by the descriptor class of the screen that carries it and that screen's action id; the client alone holds the words (`actionLabel`
 * for the action, the `SCREENS` mirror's title for the screen). An action with a published label reads `pageResourcesActionItem`; one with none, a
 * tool with no screen action included, reads `pageResourcesActionItemUnnamed`.
 *
 * Framework-free, like the rest of `core/`, so `node --test` executes it.
 */

import { actionLabel } from './screen-actions.ts';
import { SCREENS } from './screens.generated.ts';
import { STRINGS, stringFor } from './strings.ts';

/** The most phrases a line names before it counts the rest. */
export const PAGE_RESOURCE_TITLE_CAP = 5;

/** One write a page's resource gates: the descriptor class of its screen, and its screen-action id or `''`. */
export interface PageResourceActionRef {
  readonly screen: string;
  readonly action: string;
}

/** The title the screen of `descriptor` publishes, or `''` for a descriptor the mirror does not hold. */
export function screenTitleOf(descriptor: string): string {
  const screen = SCREENS.find((entry) => entry.descriptor === descriptor);
  return screen === undefined ? '' : stringFor(screen.labelKey);
}

/** `template` with `<name>` replaced by each of `values`, in one pass, so a value that holds a placeholder is shown as written. */
function fillAll(template: string, values: Readonly<Record<string, string>>): string {
  return template.replace(/<(action|screen|actions|n)>/g, (whole, name: string) => (Object.hasOwn(values, name) ? values[name] : whole));
}

/** One action's phrase, or `''` where its screen is unknown. */
export function actionPhrase(ref: PageResourceActionRef): string {
  const title = screenTitleOf(ref.screen);
  if (title === '') return '';
  const label = ref.action === '' ? '' : actionLabel(ref.screen, ref.action);
  if (label === '' || label === ref.action) return fillAll(STRINGS.pageResourcesActionItemUnnamed, { screen: title });
  return fillAll(STRINGS.pageResourcesActionItem, { action: label, screen: title });
}

/** The phrases of `refs`, in order, each once. */
export function actionPhrases(refs: readonly PageResourceActionRef[]): readonly string[] {
  const phrases: string[] = [];
  for (const ref of refs) {
    const phrase = actionPhrase(ref);
    if (phrase !== '' && !phrases.includes(phrase)) phrases.push(phrase);
  }
  return phrases;
}

/** The list `<actions>` stands for: at most `PAGE_RESOURCE_TITLE_CAP` phrases joined by ", ", then how many more, or `''` for none. */
export function actionsText(refs: readonly PageResourceActionRef[]): string {
  const phrases = actionPhrases(refs);
  const named = phrases.slice(0, PAGE_RESOURCE_TITLE_CAP);
  const rest = phrases.length - named.length;
  if (rest > 0) named.push(fillAll(STRINGS.pageResourcesMore, { n: String(rest) }));
  return named.join(', ');
}

/** `template` (one of the three action sentences) with the list of `refs` in place of `<actions>`. */
export function actionSentence(template: string, refs: readonly PageResourceActionRef[]): string {
  return fillAll(template, { actions: actionsText(refs) });
}

/** What a card's `Action` row carries: the writes, and the screens that open the page where a write is named as well. */
export interface PageResourceActionRow {
  readonly actions: readonly PageResourceActionRef[];
  /** The descriptor classes of the screens that open the page, listed in the row beside the writes. */
  readonly opens: readonly string[];
}

/**
 * The entries of an `Action` row's value: `<descriptor>#<action id>` for a write, a bare `<descriptor>` for a screen that opens the page. Empty
 * entries are dropped.
 */
export function parseActionRow(value: string): PageResourceActionRow {
  const actions: PageResourceActionRef[] = [];
  const opens: string[] = [];
  for (const entry of value.split(',')) {
    const text = entry.trim();
    if (text === '') continue;
    const at = text.indexOf('#');
    if (at < 0) opens.push(text);
    else actions.push({ screen: text.slice(0, at), action: text.slice(at + 1) });
  }
  return { actions, opens };
}
