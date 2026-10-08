// Pins DW-2190: the SQL privilege dialog's lists (the types, each type's actions, the column actions and the
// 31 admin privileges) equal the lists OcuPilot.Port.SqlPrivilegePort declares, so a list that grows on the
// port cannot leave the dialog offering the old one. Both sides are read from source: the port's class
// parameters and the dialog's exported constants. Neither list is copied into this file.
//
// Mutation (Rule 19): drop one admin privilege from SQL_ADMIN_PRIVILEGES in sql-privilege-dialog.ts -> the
// admin privileges test goes red naming it; add a type to the port's TYPES parameter -> the types test goes red.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const PORT_PATH = join(here, '..', '..', 'src', 'OcuPilot', 'Port', 'SqlPrivilegePort.cls');
const DIALOG_PATH = join(here, '..', 'src', 'app', 'areas', 'permissions', 'sql-privilege-dialog.ts');

const portSource = readFileSync(PORT_PATH, 'utf8');
const dialogSource = readFileSync(DIALOG_PATH, 'utf8');

/** A class parameter's comma-separated string value, as a list. */
function portList(name) {
  const match = new RegExp(`^Parameter ${name} = "([^"]*)";`, 'm').exec(portSource);
  assert.ok(match, `SqlPrivilegePort.cls must declare Parameter ${name} as a string`);
  return match[1].split(',').map((entry) => entry.trim());
}

/** The string elements of the dialog's exported `readonly string[]` constant of that name. */
function dialogList(name) {
  const match = new RegExp(`export const ${name}: readonly string\\[\\] = \\[([^\\]]*)\\];`).exec(dialogSource);
  assert.ok(match, `sql-privilege-dialog.ts must export ${name} as a literal readonly string[]`);
  return [...match[1].matchAll(/'([^']*)'/g)].map((entry) => entry[1]);
}

/** The dialog's `SQL_PRIVILEGE_ACTIONS` map: each key (quoted or not) to the name of a list or a literal array. */
function dialogActionMap() {
  const match = /export const SQL_PRIVILEGE_ACTIONS: Readonly<Record<string, readonly string\[\]>> = \{([^}]*)\};/.exec(dialogSource);
  assert.ok(match, 'sql-privilege-dialog.ts must export SQL_PRIVILEGE_ACTIONS');
  const map = new Map();
  for (const entry of match[1].split(/,\s*\n/)) {
    const pair = /^\s*(?:'([^']+)'|([A-Z_]+)):\s*(.+?)\s*,?\s*$/s.exec(entry);
    if (!pair) continue;
    const key = pair[1] ?? pair[2];
    const value = pair[3];
    const literal = /^\[([^\]]*)\]$/.exec(value);
    map.set(key, literal ? [...literal[1].matchAll(/'([^']*)'/g)].map((item) => item[1]) : dialogList(value));
  }
  return map;
}

test('the dialog offers the port\'s types, in its order', () => {
  assert.deepEqual(dialogList('SQL_PRIVILEGE_TYPES'), portList('TYPES'));
});

test('each type\'s action list is the port\'s', () => {
  const actions = dialogActionMap();
  assert.deepEqual([...actions.keys()], portList('TYPES'), 'every type has an action list, in the types\' order');
  assert.deepEqual(actions.get('TABLE'), portList('TABLEACTIONS'));
  assert.deepEqual(actions.get('VIEW'), portList('VIEWACTIONS'));
  assert.deepEqual(actions.get('SCHEMA'), portList('SCHEMAACTIONS'));
  assert.deepEqual(actions.get('STORED PROCEDURE'), portList('PROCEDUREACTIONS'));
  assert.deepEqual(actions.get('ML CONFIGURATION'), portList('USEACTIONS'));
  assert.deepEqual(actions.get('FOREIGN SERVER'), portList('USEACTIONS'));
  assert.deepEqual(actions.get('ADMIN'), portList('ADMINPRIVILEGES'));
});

test('the dialog\'s lists are the port\'s, one by one', () => {
  assert.deepEqual(dialogList('SQL_TABLE_ACTIONS'), portList('TABLEACTIONS'));
  assert.deepEqual(dialogList('SQL_VIEW_ACTIONS'), portList('VIEWACTIONS'));
  assert.deepEqual(dialogList('SQL_SCHEMA_ACTIONS'), portList('SCHEMAACTIONS'));
});

test('the column actions are the port\'s COLUMNACTIONS', () => {
  assert.deepEqual(dialogList('SQL_COLUMN_ACTIONS'), portList('COLUMNACTIONS'));
});

test('the admin privileges are the port\'s ADMINPRIVILEGES, all 31, each once', () => {
  const dialog = dialogList('SQL_ADMIN_PRIVILEGES');
  const port = portList('ADMINPRIVILEGES');
  assert.equal(port.length, 31, 'the port names the 31 privileges the instance takes');
  assert.equal(new Set(dialog).size, dialog.length, 'no privilege is listed twice');
  assert.deepEqual(
    port.filter((name) => !dialog.includes(name)),
    [],
    'the dialog lacks a privilege the port names'
  );
  assert.deepEqual(dialog, port);
});
