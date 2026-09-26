import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins `core/suggested-prompts.ts` (Story 11.3): prompts grouped by task in first-appearance order,
// `[]` for no declaration, and every built screen in the generated mirror yielding at least three.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { promptGroups } = await import(core('suggested-prompts.ts'));
const { STRINGS } = await import(core('strings.ts'));
const { SCREENS } = await import(core('screens.generated.ts'));

test('groups follow first appearance, and each group keeps its prompts in declaration order', () => {
  // Mutation (Rule 19): put every prompt in the first group -> this goes red.
  const groups = promptGroups({
    suggestedPrompts: [
      { groupKey: 'userPromptGroupSignIn', textKey: 'userListPrompt1' },
      { groupKey: 'userPromptGroupAccess', textKey: 'userListPrompt2' },
      { groupKey: 'userPromptGroupSignIn', textKey: 'homeStarterPromptExplainLog' },
      { groupKey: 'userPromptGroupAccess', textKey: 'userListPrompt3' },
    ],
  });
  assert.deepEqual(groups, [
    {
      key: 'userPromptGroupSignIn',
      label: STRINGS.userPromptGroupSignIn,
      prompts: [STRINGS.userListPrompt1, STRINGS.homeStarterPromptExplainLog],
    },
    {
      key: 'userPromptGroupAccess',
      label: STRINGS.userPromptGroupAccess,
      prompts: [STRINGS.userListPrompt2, STRINGS.userListPrompt3],
    },
  ]);
});

test('no declaration, or one declaring no prompts, yields no groups', () => {
  assert.deepEqual(promptGroups(null), []);
  assert.deepEqual(promptGroups({}), []);
  assert.deepEqual(promptGroups({ suggestedPrompts: [] }), []);
});

test('every built screen in the generated mirror yields at least three non-empty prompts under labeled groups', () => {
  const built = SCREENS.filter((screen) => screen.built);
  assert.ok(built.length >= 58, `the built roster is read (read ${built.length})`);
  for (const screen of built) {
    const groups = promptGroups(screen);
    const prompts = groups.flatMap((group) => group.prompts);
    assert.ok(prompts.length >= 3, `${screen.descriptor} yields at least three prompts`);
    assert.ok(prompts.every((text) => typeof text === 'string' && text !== ''), `${screen.descriptor}'s prompts resolve`);
    for (const group of groups) {
      assert.ok(typeof group.label === 'string' && group.label !== '', `${screen.descriptor}: '${group.key}' has a label`);
    }
  }
});
