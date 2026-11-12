// Pins that the users route constants have one declaration in the client: the create form's store
// owns them and the editor's store imports them (DW-2260).
//
// Mutation (Rule 19): re-declare `USERS_PATH` or `USERS_FORM_PATH` in `user-editor.store.ts` -> red.

import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const SRC = fileURLToPath(new URL('../src', import.meta.url));

function clientSources(dir) {
  const files = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) files.push(...clientSources(full));
    else if (entry.name.endsWith('.ts') && !entry.name.endsWith('.spec.ts')) files.push(full);
  }
  return files;
}

const declarations = (name) =>
  clientSources(SRC)
    .filter((file) => new RegExp(`\\bconst ${name}\\s*[:=]`).test(readFileSync(file, 'utf8')))
    .map((file) => relative(SRC, file));

for (const name of ['USERS_PATH', 'USERS_FORM_PATH']) {
  test(`${name} is declared once in the client sources`, () => {
    assert.deepEqual(declarations(name), ['app/areas/permissions/user-create-form.store.ts']);
  });
}
