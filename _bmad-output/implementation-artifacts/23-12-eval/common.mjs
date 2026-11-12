// Shared plumbing for Story 23.12's measurement (measure.mjs) and live evaluation (eval.mjs).
// Measurement tooling, not product code; no test runs it.
//
// The only runtime it touches is the slot A throwaway `ocupilot-ci` (web 52776). The provider key
// is read from .env.local at the point of use, kept in one variable, and redacted from every
// message this module formats; nothing here prints, logs or writes it.

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';

export const CONTAINER = 'ocupilot-ci';
export const WEB_PORT = '52776';
export const ORIGIN = `http://localhost:${WEB_PORT}`;
export const API = `${ORIGIN}/api/ocupilot`;
export const MODEL = 'claude-haiku-5-5';
const AUTH = `Basic ${Buffer.from('_SYSTEM:SYS').toString('base64')}`;
const ENV_FILE = '/Users/jbrandt/git/OcuPilot/.env.local';

let secret = null;

/** Replace the provider key, if loaded, with *** in any text. */
export function redact(value) {
  let text = String(value instanceof Error ? (value.stack ?? value.message) : value);
  if (secret) text = text.split(secret).join('***');
  return text;
}

/** The provider key, parsed from .env.local. Never logged; remembered only so redact() can scrub it. */
export function providerKey() {
  const lines = fs.readFileSync(ENV_FILE, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const match = /^\s*(?:export\s+)?ANTHROPIC_API_KEY\s*=\s*(.*?)\s*$/.exec(line);
    if (!match) continue;
    let value = match[1];
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) value = value.slice(1, -1);
    if (value === '') break;
    secret = value;
    return value;
  }
  throw new Error('ANTHROPIC_API_KEY is not set in .env.local');
}

/** Write an output file, refusing if the key could be in it. */
export function writeOutput(file, text) {
  if (secret && text.includes(secret)) throw new Error(`refused to write ${file}: it would hold the provider key`);
  fs.writeFileSync(file, text);
}

export function log(...parts) {
  console.log(redact(parts.join(' ')));
}

export function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Throw unless the throwaway is the one on 52776 and its readiness answers installed. */
export async function preflight() {
  const port = spawnSync('docker', ['port', CONTAINER, '52773/tcp'], { encoding: 'utf8' });
  const ports = (port.stdout ?? '').trim().split(/\r?\n/).map((line) => line.split(':').pop());
  if (port.status !== 0 || !ports.includes(WEB_PORT)) throw new Error(`docker port ${CONTAINER} 52773/tcp does not read ${WEB_PORT}: ${port.stdout}${port.stderr}`);
  const response = await fetch(`${API}/readiness/`, { headers: { Authorization: AUTH } });
  const body = await response.json().catch(() => ({}));
  if (response.status !== 200 || body.state !== 'installed') throw new Error(`readiness answered ${response.status} ${JSON.stringify(body)}`);
  return { port: WEB_PORT, readiness: body.state };
}

/** Pipe ObjectScript lines into a terminal session on the throwaway, starting in `namespace`. */
export function runIris(lines, namespace = 'HSCUSTOM') {
  const result = spawnSync('docker', ['exec', '-i', CONTAINER, 'iris', 'session', 'iris', '-U', namespace], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
    maxBuffer: 64 * 1024 * 1024,
  });
  return `${result.stdout ?? ''}${result.stderr ?? ''}`;
}

/** The value a line wrote between OCU-<name>-START: and :OCU-<name>-END, or null. */
export function marker(output, name) {
  const match = new RegExp(`OCU-${name}-START:([\\s\\S]*?):OCU-${name}-END`).exec(output);
  return match ? match[1] : null;
}

/** Every value written under a marker name, in order. */
export function markers(output, name) {
  return [...output.matchAll(new RegExp(`OCU-${name}-START:([\\s\\S]*?):OCU-${name}-END`, 'g'))].map((m) => m[1]);
}

/** Read a file inside the container. */
export function containerFile(path) {
  const result = spawnSync('docker', ['exec', CONTAINER, 'cat', path], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (result.status !== 0) throw new Error(`could not read ${path}: ${result.stderr}`);
  return result.stdout;
}

/** Doubles " for an ObjectScript string literal. */
export function os(value) {
  return `"${String(value).replace(/"/g, '""')}"`;
}

/** One request to the OcuPilot API as _SYSTEM. Answers {status, body}; body is parsed JSON when it parses. */
export async function api(method, path, body) {
  const init = { method, headers: { Authorization: AUTH } };
  if (body !== undefined) {
    init.headers['Content-Type'] = 'application/json';
    init.body = JSON.stringify(body);
  }
  const response = await fetch(`${API}${path}`, init);
  const text = await response.text();
  let parsed = text;
  try {
    parsed = JSON.parse(text);
  } catch {
    // not JSON: keep the text
  }
  return { status: response.status, body: parsed };
}

/** POST count_tokens on claude-haiku-5-5 for an Anthropic Messages body, sending only the fields that endpoint takes. */
export async function countTokens(body) {
  const key = providerKey();
  const request = { model: MODEL, messages: body.messages };
  if (body.system !== undefined) request.system = body.system;
  if (body.tools !== undefined) request.tools = body.tools;
  const response = await fetch('https://api.anthropic.com/v1/messages/count_tokens', {
    method: 'POST',
    headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
    body: JSON.stringify(request),
  });
  const text = await response.text();
  if (response.status !== 200) throw new Error(`count_tokens answered ${response.status}: ${redact(text).slice(0, 400)}`);
  return JSON.parse(text).input_tokens;
}
