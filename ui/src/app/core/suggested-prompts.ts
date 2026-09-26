/**
 * A screen's suggested prompts, grouped by task (Story 11.3, AD-5).
 *
 * The descriptor names keys only; the text is `strings.ts`'s. Groups come in the order each first
 * appears in the declaration, and each group's prompts in declaration order.
 *
 * Framework-free like the rest of `core/` (AD-19), so `ui/tools/suggested-prompts.test.mjs`
 * executes it under `node --test`.
 */

// The `.ts` extensions are what let `node --test` resolve these at runtime.
import type { ScreenDeclaration } from './screens.generated.ts';
import { stringFor } from './strings.ts';

/** One task group: its string key, its resolved label, and its prompts' resolved text. */
export interface PromptGroup {
  readonly key: string;
  readonly label: string;
  readonly prompts: readonly string[];
}

/** The declaration's prompts grouped by task, or `[]` for no declaration or no prompts. */
export function promptGroups(
  declaration: Pick<ScreenDeclaration, 'suggestedPrompts'> | null
): readonly PromptGroup[] {
  const groups: { key: string; label: string; prompts: string[] }[] = [];
  for (const prompt of declaration?.suggestedPrompts ?? []) {
    let group = groups.find((candidate) => candidate.key === prompt.groupKey);
    if (group === undefined) {
      group = { key: prompt.groupKey, label: stringFor(prompt.groupKey), prompts: [] };
      groups.push(group);
    }
    group.prompts.push(stringFor(prompt.textKey));
  }
  return groups;
}
