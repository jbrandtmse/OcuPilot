import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins `core/suggested-prompts.ts` (Story 11.3, Story 20.12): prompts grouped by task in
// first-appearance order, each carrying the workflow id its descriptor names or `null`, `[]` for no
// declaration, and every built screen in the generated mirror yielding at least three.

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
      prompts: [
        { text: STRINGS.userListPrompt1, workflow: null },
        { text: STRINGS.homeStarterPromptExplainLog, workflow: null },
      ],
    },
    {
      key: 'userPromptGroupAccess',
      label: STRINGS.userPromptGroupAccess,
      prompts: [
        { text: STRINGS.userListPrompt2, workflow: null },
        { text: STRINGS.userListPrompt3, workflow: null },
      ],
    },
  ]);
});

test('a prompt that names a workflow carries its id beside its resolved text (Story 20.12)', () => {
  // Mutation (Rule 19): drop `workflow` from the projection in `promptGroups` -> this goes red.
  const groups = promptGroups({
    suggestedPrompts: [
      { groupKey: 'webAppPromptGroupCode', textKey: 'explorerClassListPrompt1' },
      { groupKey: 'webAppPromptGroupCode', textKey: 'explorerClassListWorkflowCompile', workflow: 'compileclass' },
    ],
  });
  assert.deepEqual(groups[0].prompts, [
    { text: STRINGS.explorerClassListPrompt1, workflow: null },
    { text: 'Fix a class until it compiles, step by step', workflow: 'compileclass' },
  ]);
  assert.equal(STRINGS.explorerClassListWorkflowCompile, 'Fix a class until it compiles, step by step');
});

test('the generated mirror offers each of the nine catalog workflows through a built screen prompt (Story 20.12)', () => {
  const offered = new Set();
  for (const screen of SCREENS.filter((candidate) => candidate.built)) {
    for (const group of promptGroups(screen)) {
      for (const prompt of group.prompts) if (prompt.workflow !== null) offered.add(prompt.workflow);
    }
  }
  assert.deepEqual(
    [...offered].sort(),
    ['compileclass', 'newproject', 'recoverproduction', 'resendmessages', 'reviewclass', 'securityposture', 'slowquery', 'systemhealth', 'tracemessage']
  );
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
    assert.ok(prompts.every((prompt) => typeof prompt.text === 'string' && prompt.text !== ''), `${screen.descriptor}'s prompts resolve`);
    for (const group of groups) {
      assert.ok(typeof group.label === 'string' && group.label !== '', `${screen.descriptor}: '${group.key}' has a label`);
    }
  }
});
