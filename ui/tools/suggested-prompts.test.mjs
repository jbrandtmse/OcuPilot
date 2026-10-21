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

/** The spec's catalog table: each workflow, the screen that offers it, the prompt's task group and string key, and its text. */
const WORKFLOW_OFFERS = [
  ['InteropProductionList', 'promptGroupTroubleshooting', 'interopProductionsWorkflowRecover', 'recoverproduction', 'Recover a stuck production, step by step'],
  ['InteropMessageList', 'promptGroupTroubleshooting', 'interopMessagesWorkflowResend', 'resendmessages', 'Resend failed messages, step by step'],
  ['InteropMessageList', 'promptGroupTroubleshooting', 'interopMessagesWorkflowTrace', 'tracemessage', 'Trace a message through its session, step by step'],
  ['Dashboard', 'promptGroupTroubleshooting', 'dashboardWorkflowHealth', 'systemhealth', "Check this instance's health, step by step"],
  ['RoleList', 'userPromptGroupAccess', 'roleListWorkflowSecurity', 'securityposture', 'Review the security posture, step by step'],
  ['ExplorerSqlQuery', 'webAppPromptGroupCode', 'explorerSqlQueryWorkflowSlow', 'slowquery', 'Find out why a query is slow, step by step'],
  ['ExplorerClassList', 'webAppPromptGroupCode', 'explorerClassListWorkflowCompile', 'compileclass', 'Fix a class until it compiles, step by step'],
  ['ExplorerClassList', 'webAppPromptGroupCode', 'explorerClassListWorkflowReview', 'reviewclass', "Review a class's ObjectScript, step by step"],
  ['NamespaceList', 'promptGroupGettingStarted', 'namespaceListWorkflowProject', 'newproject', "Set up a new project's namespace, step by step"],
];

test('each workflow is offered by the screen, group and text the catalog names, and by no other screen (Story 20.12)', () => {
  // Mutation (Rule 19): move a workflow prompt to another screen's descriptor, or give it another workflow id in
  // `screens.generated.ts` -> this goes red naming the row; the server-side pins cover only three of the seven
  // descriptors, so this is the one place the other four are held.
  const built = SCREENS.filter((screen) => screen.built);
  for (const [name, groupKey, textKey, workflow, text] of WORKFLOW_OFFERS) {
    const screen = built.find((candidate) => candidate.descriptor === `OcuPilot.Screen.Descriptor.${name}`);
    assert.ok(screen !== undefined, `${name} is a built screen`);
    const group = promptGroups(screen).find((candidate) => candidate.key === groupKey);
    assert.ok(group !== undefined, `${name} has the '${groupKey}' task group`);
    assert.deepEqual(
      group.prompts.filter((prompt) => prompt.workflow === workflow),
      [{ text, workflow }],
      `${name} offers '${workflow}' once, as "${text}", under '${groupKey}'`
    );
    assert.equal(STRINGS[textKey], text, `'${textKey}' is the prompt's text`);
  }
  const offeredOn = new Map();
  for (const screen of built) {
    for (const prompt of promptGroups(screen).flatMap((group) => group.prompts)) {
      if (prompt.workflow !== null) offeredOn.set(prompt.workflow, [...(offeredOn.get(prompt.workflow) ?? []), screen.descriptor]);
    }
  }
  for (const [name, , , workflow] of WORKFLOW_OFFERS) {
    assert.deepEqual(offeredOn.get(workflow), [`OcuPilot.Screen.Descriptor.${name}`], `'${workflow}' is offered on ${name} alone`);
  }
  assert.equal(offeredOn.size, WORKFLOW_OFFERS.length, 'and no screen offers a workflow the table does not name');
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
