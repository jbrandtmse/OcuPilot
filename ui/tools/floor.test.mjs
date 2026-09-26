// Pins Story 9.9's AC4, the 2026-09-27 floor, over the built descriptors themselves: the screen
// mirror `ui/src/app/core/screens.generated.ts` and the archetype vocabulary
// `src/OcuPilot/Screen/Archetype.cls` it was generated beside.
//
// - Each of the five areas that administers an object has at least one built `form-page`.
// - Logs has none, asserted as a tripwire rather than assumed: the feature catalog lists no Logs
//   editor at any tier, so a Logs form arriving is a story that has to say so here.
// - No descriptor whose archetype is `list`-class declares a classic-link exemption or a row link:
//   a link-out on a list counts against SM-C1, and one on an editor is a recorded cost (AD-44).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = join(uiRoot, '..');
const { SCREENS, AREAS } = await import(join(uiRoot, 'src', 'app', 'core', 'screens.generated.ts'));

/** The five areas that administer an object, by the key the mirror declares each under. */
export const ADMINISTERING_AREAS = ['web-applications', 'permissions', 'security', 'tasks', 'os-management'];

/** The area with no editor to build at any tier. */
export const EDITORLESS_AREA = 'logs';

/** Each archetype key's link-out class, read from `Archetype.cls`'s own declaration block. */
export function archetypeLinkOut(source) {
  const classes = new Map();
  for (const match of source.matchAll(/\{"key":"([^"]+)","linkOut":"([^"]+)"\}/g)) classes.set(match[1], match[2]);
  return classes;
}

const linkOut = archetypeLinkOut(readFileSync(join(repoRoot, 'src', 'OcuPilot', 'Screen', 'Archetype.cls'), 'utf8'));

function builtFormPages(area) {
  return SCREENS.filter((screen) => screen.built && screen.area === area && screen.archetype === 'form-page');
}

test('AC4: the vocabulary and the areas the floor is about are the ones the mirror declares', () => {
  assert.ok(linkOut.size >= 16, `Archetype.cls declares every archetype's link-out class, read ${linkOut.size}`);
  const declared = AREAS.map((area) => area.key);
  for (const area of [...ADMINISTERING_AREAS, EDITORLESS_AREA]) {
    assert.ok(declared.includes(area), `the mirror declares the ${area} area`);
  }
});

test('AC4: each of the five administering areas has at least one built form-page', () => {
  for (const area of ADMINISTERING_AREAS) {
    const forms = builtFormPages(area);
    assert.ok(forms.length > 0, `${area} has a built create or edit form`);
  }
  assert.ok(
    builtFormPages('permissions').some((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ServiceForm'),
    'the reduced service form is one of the permissions forms'
  );
  assert.ok(
    builtFormPages('security').some((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.LdapConfigForm'),
    'and the reduced LDAP configuration form one of the security forms'
  );
});

test('AC4: Logs has no form at all -- a tripwire, since the catalog lists no Logs editor at any tier', () => {
  // Temporary only in the sense AD-44 is: a story that adds a Logs editor replaces this zero with
  // its own form and says why in the same pass.
  const logsForms = SCREENS.filter(
    (screen) => screen.area === EDITORLESS_AREA && ['form-page', 'form-page (tabs)', 'wizard'].includes(screen.archetype)
  );
  assert.deepEqual(logsForms.map((screen) => screen.descriptor), []);
});

test('AC4: no list-class archetype declares a classic-link exemption or a row link', () => {
  // Mutation (Rule 19): set LdapConfigList's exemption to exempt and regenerate -> red naming it.
  let lists = 0;
  for (const screen of SCREENS) {
    const kind = linkOut.get(screen.archetype);
    assert.notEqual(kind, undefined, `${screen.descriptor}'s archetype "${screen.archetype}" is one the vocabulary declares`);
    if (kind !== 'list') continue;
    lists += 1;
    assert.equal(screen.classicLinkExemption.exempt, false, `${screen.descriptor} is a list and declares no exemption`);
    assert.ok(!screen.classicLinkExemption.rowLink, `${screen.descriptor} is a list and declares no row link`);
  }
  assert.ok(lists > 0, 'the check read at least one list screen');
});

test('AC2, AD-44: the two reduced forms each end with an honoured exemption to the classic page they name', () => {
  for (const [descriptor, label, href] of [
    ['OcuPilot.Screen.Descriptor.ServiceForm', 'Services', '/csp/sys/sec/%25CSP.UI.Portal.Services.zen'],
    ['OcuPilot.Screen.Descriptor.LdapConfigForm', 'Security LDAP Configs', '/csp/sys/sec/%25CSP.UI.Portal.LDAPs.zen'],
  ]) {
    const screen = SCREENS.find((entry) => entry.descriptor === descriptor);
    assert.ok(screen !== undefined, `${descriptor} is mirrored`);
    assert.equal(screen.classicLinkExemption.exempt, true, `${descriptor} is exempt`);
    assert.equal(screen.classicLinkExemption.label, label, `${descriptor} names the classic page`);
    assert.equal(screen.classicLinkExemption.href, href, `${descriptor} links to it`);
    assert.equal(screen.sideBarPosition, 0, `${descriptor} takes no side-bar position`);
  }
});
