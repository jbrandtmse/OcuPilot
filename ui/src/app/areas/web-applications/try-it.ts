/**
 * The try-it console's rules (Story 16.1, AD-57), framework-free so `ui/tools/try-it.test.mjs` pins
 * them under `node --test`.
 *
 * - `composeRequest` builds the one request an operation's form describes, from the document alone:
 *   the application's path, the operation's path and verb, and its declared parameters. A path
 *   parameter fills one segment; a segment that would read `.` or `..` is refused; a URL that does
 *   not stay on the page's own origin is never produced.
 * - `resolveTarget` resolves a URL's path the way the browser and the instance will, so
 *   `refusal` compares what is actually reached rather than how it was spelled.
 * - `refusal` is AD-57 (2): OcuPilot's own applications for any verb, and `/api/admin` for a write.
 * - `refuseRequest` is the one function the console asks: every reading of a URL's path, and
 *   `refusal` over each.
 * - `maskedRecord` is what the console shows of a request once sent: every secret masked (AD-57 (4)).
 * - `curlCommand` is the same request as one POSIX curl command (Story 16.24, AD-57 (5)): refused
 *   whenever `refuseRequest` refuses it, and every value the record masks reads `<name>`.
 * - `renderBody` turns an answer's bytes into text, and never into markup (AD-11 rule 4).
 */

import { MASKED_VALUE } from '../../core/proposal-view.ts';
import { isSecretName } from '../../core/secret-names.ts';
import { STRINGS } from '../../core/strings.ts';
import type { OpenApiParameter } from './openapi-viewer.store';

/** OcuPilot's own applications (AD-10, AD-45): nothing under them is ever sent. */
export const OWN_APPLICATIONS: readonly string[] = ['/ocupilot', '/api/ocupilot', '/api/ocupilot/readiness'];

/** The admin API, whose writes OcuPilot's own write path carries instead (AD-57 (2)). */
export const ADMIN_API = '/api/admin';

/** The verbs sent without a confirmation. */
export const SAFE_VERBS: readonly string[] = ['GET', 'HEAD', 'OPTIONS'];

/** The verbs refused under the admin API. */
export const WRITE_VERBS: readonly string[] = ['POST', 'PUT', 'PATCH', 'DELETE'];

/** The verbs whose form carries a body. */
export const BODY_VERBS: readonly string[] = ['POST', 'PUT', 'PATCH'];

/** The parameter locations the form offers a field for; a `body` parameter is the body field itself. */
export const FIELD_LOCATIONS: readonly string[] = ['path', 'query', 'header', 'formData'];

/** How much of a text answer is shown, in bytes. */
export const TEXT_CAP_BYTES = 256 * 1024;

/** What `refusal` answers: which of AD-57's two refusals applies. */
export type TryItRefusal = 'own-application' | 'admin-write';

/** The operation a console sends. */
export interface TryItOperation {
  readonly verb: string;
  readonly path: string;
  readonly parameters: readonly OpenApiParameter[];
}

/** What the form holds: one value per declared parameter, by index, and the body. */
export interface TryItValues {
  readonly parameters: readonly string[];
  readonly body: string;
}

/** A request ready to send, and the same request as the console displays it. */
export interface ComposedRequest {
  /** The verb, upper-cased. */
  readonly method: string;
  /** The absolute URL, on the page's own origin. */
  readonly url: string;
  /** `url` with every secret-named path or query value masked. */
  readonly displayUrl: string;
  /** The declared headers the form filled, and the body's content type when there is one. */
  readonly headers: readonly (readonly [string, string])[];
  /** The body, or `null` when none is sent. */
  readonly body: string | null;
  /** The body as the record shows it: every secret-named top-level member masked. */
  readonly displayBody: string | null;
  /** `url` with every secret-named path or query value reading `<name>`; `url` itself when none. */
  readonly curlUrl: string;
  /** `body` with every value the record masks reading `<name>`; `body` itself when none. */
  readonly curlBody: string | null;
}

/** What `curlCommand` answers: the command, or the refusal `refuseRequest` gives. */
export type CurlCommand =
  | { readonly kind: 'ok'; readonly command: string }
  | { readonly kind: 'refused'; readonly refusal: TryItRefusal };

/** What `composeRequest` answers. */
export type Composition =
  | { readonly kind: 'ok'; readonly request: ComposedRequest }
  /** A path parameter would fill its segment with `.` or `..`: the parameter's index. */
  | { readonly kind: 'traversal'; readonly index: number }
  /** The operation has no address on this origin. */
  | { readonly kind: 'no-address' };

/** The record of a sent request: every value masked that the credential pattern names. */
export interface RequestRecord {
  readonly line: string;
  readonly headers: readonly string[];
  readonly body: string | null;
}

/** An answer's body, as the console renders it. */
export interface RenderedBody {
  /** `json` pretty-printed, `text` decoded, `binary` shown only as its byte count. */
  readonly kind: 'json' | 'text' | 'binary';
  readonly text: string;
  readonly byteCount: number;
  /** Whether `text` is the first `TEXT_CAP_BYTES` of a longer answer. */
  readonly cut: boolean;
}

/** Whether `verb` is sent without a confirmation. */
export function isSafeVerb(verb: string): boolean {
  return SAFE_VERBS.includes(verb.toUpperCase());
}

/** Whether a form for `verb` carries a body field. */
export function takesBody(verb: string): boolean {
  return BODY_VERBS.includes(verb.toUpperCase());
}

/** A literal path segment, percent-encoded so the document's own text cannot end the path early. */
function encodeLiteral(text: string): string {
  return encodeURI(text).replace(/[?#]/g, (character) => encodeURIComponent(character));
}

/** A single `%XX` run decoded as UTF-8, or byte by byte where it is not valid UTF-8. */
function decodeRun(run: string): string {
  try {
    return decodeURIComponent(run);
  } catch {
    return run.replace(/%([0-9a-fA-F]{2})/g, (_, hex: string) => String.fromCharCode(parseInt(hex, 16)));
  }
}

/** Every percent-encoded run in `path` decoded once. */
function decodeOnce(path: string): string {
  return path.replace(/(?:%[0-9a-fA-F]{2})+/g, decodeRun);
}

/** `path` with `.` and `..` segments removed, as RFC 3986 section 5.2.4 removes them. */
function removeDotSegments(path: string): string {
  const out: string[] = [];
  for (const segment of path.split('/').slice(1)) {
    if (segment === '.') continue;
    if (segment === '..') {
      out.pop();
      continue;
    }
    out.push(segment);
  }
  return `/${out.join('/')}`;
}

/**
 * `url`'s path as parsed by `new URL` (which removes dot segments), then percent-decoded once per
 * entry, up to eight times, until nothing changes. `null` when `url` does not parse.
 */
function decodings(url: string): string[] | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  const paths = [parsed.pathname];
  for (let pass = 0; pass < 8; pass += 1) {
    const decoded = decodeOnce(paths[paths.length - 1]);
    if (decoded === paths[paths.length - 1]) break;
    paths.push(decoded);
  }
  return paths;
}

/**
 * `path` for comparison: backslashes read as slashes, repeated slashes collapsed, dot segments
 * removed when `dots` is set, a trailing slash dropped, and case folded both ways (IRIS matches an
 * application name case-insensitively, AD-13).
 */
function normalize(path: string, dots: boolean): string {
  let out = path.replace(/\\/g, '/').replace(/\/+/g, '/');
  if (!out.startsWith('/')) out = `/${out}`;
  if (dots) out = removeDotSegments(out).replace(/\/+/g, '/');
  if (out.length > 1 && out.endsWith('/')) out = out.slice(0, -1);
  return out.toUpperCase().toLowerCase();
}

/**
 * `url`'s path fully decoded and normalized: what it reaches when every layer decodes it (so `%6F`,
 * `%2e` and a doubly encoded `%252e` hide nothing). `null` when `url` does not parse.
 */
export function resolveTarget(url: string): string | null {
  const paths = decodings(url);
  return paths === null ? null : normalize(paths[paths.length - 1], true);
}

/**
 * Every path `url` can be read as: each of its decodings, with and without dot segments removed.
 * The web server, the gateway and the application each decode at most once, so which reading the
 * instance routes on cannot be told from the client; a refusal holds when any reading is refused.
 * `null` when `url` does not parse.
 */
export function resolveTargets(url: string): string[] | null {
  const paths = decodings(url);
  if (paths === null) return null;
  const readings = new Set<string>();
  for (const path of paths) {
    readings.add(normalize(path, true));
    readings.add(normalize(path, false));
  }
  return [...readings];
}

/** Whether `target` is `prefix` or lies under it, on whole segments. */
function isUnder(target: string, prefix: string): boolean {
  return target === prefix || target.startsWith(`${prefix}/`);
}

/**
 * AD-57 (2), both arms in one place: `own-application` for any request whose resolved `target` lies
 * under one of OcuPilot's own applications, whatever the verb; `admin-write` for a `POST`, `PUT`,
 * `PATCH` or `DELETE` under the admin API; otherwise `null`. A `target` that did not resolve is
 * refused as the own-application arm, since where it goes cannot be told.
 */
export function refusal(verb: string, target: string | null): TryItRefusal | null {
  if (target === null) return 'own-application';
  if (OWN_APPLICATIONS.some((application) => isUnder(target, application))) return 'own-application';
  if (WRITE_VERBS.includes(verb.toUpperCase()) && isUnder(target, ADMIN_API)) return 'admin-write';
  return null;
}

/**
 * AD-57 (2) for a request to `url` by `verb`: `refusal` over every reading `resolveTargets` gives,
 * the own-application arm first. A URL that does not parse is refused as `refusal` refuses `null`.
 */
export function refuseRequest(verb: string, url: string): TryItRefusal | null {
  const targets = resolveTargets(url);
  if (targets === null) return refusal(verb, null);
  const verdicts = targets.map((target) => refusal(verb, target));
  if (verdicts.includes('own-application')) return 'own-application';
  if (verdicts.includes('admin-write')) return 'admin-write';
  return null;
}

/** `body` parsed, when it is a JSON object; else `null`. */
function jsonObject(body: string): Record<string, unknown> | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    return null;
  }
  return parsed === null || typeof parsed !== 'object' || Array.isArray(parsed) ? null : (parsed as Record<string, unknown>);
}

/** `object` serialized as the record shows a body, each secret-named top-level member read as `mask(name)`. */
function maskMembers(object: Record<string, unknown>, mask: (name: string) => string): string {
  const masked = Object.fromEntries(Object.entries(object).map(([name, value]) => [name, isSecretName(name) ? mask(name) : value]));
  return JSON.stringify(masked, null, 2);
}

/** `body` with each secret-named top-level member masked, when it is a JSON object; else as typed. */
function maskBody(body: string): string {
  const object = jsonObject(body);
  return object === null ? body : maskMembers(object, () => MASKED_VALUE);
}

/** The placeholder a masked value reads as in a copied command. */
function placeholder(name: string): string {
  return `<${name}>`;
}

/**
 * `body` as the copied command sends it: a JSON object with a secret-named top-level member
 * serialized as the record serializes it, each such member reading `"<Name>"`; else as typed.
 */
function curlJsonBody(body: string): string {
  const object = jsonObject(body);
  if (object === null || !Object.keys(object).some(isSecretName)) return body;
  return maskMembers(object, placeholder);
}

/** A piece of the copied command's URL: literal text, or the placeholder for a secret-named value. */
type CurlPart = string | { readonly name: string };

/**
 * The URL `parts` describe after `pageOrigin`, through the same `new URL` the request's own URL
 * takes, with each placeholder `<name>` in its value's place. Each placeholder travels the parser
 * as a marker of letters and digits, which it never encodes and never joins to its neighbours, and
 * the marker is lengthened until it occurs nowhere else in the text, so nothing but a placeholder is
 * put back.
 */
function curlHref(parts: readonly CurlPart[], pageOrigin: string): string {
  const names = parts.filter((part): part is { readonly name: string } => typeof part !== 'string').map((part) => part.name);
  let marker = 'ocucurl';
  for (;;) {
    let slot = 0;
    const text = parts.map((part) => (typeof part === 'string' ? part : `${marker}${slot++}${marker}`)).join('');
    if (text.split(marker).length - 1 === 2 * names.length) {
      const href = new URL(text, pageOrigin).href;
      return href.replace(new RegExp(`${marker}(\\d+)${marker}`, 'g'), (_, index: string) => placeholder(names[Number(index)]));
    }
    marker += 'x';
  }
}

/**
 * The request `operation` describes under `basePath`, filled from `values`, on `origin`.
 *
 * A path parameter's value fills its placeholder through `encodeURIComponent`, so it cannot add a
 * segment; a segment that would then read `.` or `..` is refused, naming the parameter. Query and
 * header parameters are sent when filled; form parameters become a URL-encoded body. The body field
 * is sent for a verb that takes one when it holds text, as JSON. `basePath` must be a path on this
 * origin, and the composed URL must resolve to `origin`, or there is no address.
 */
export function composeRequest(
  basePath: string,
  operation: TryItOperation,
  values: TryItValues,
  origin: string
): Composition {
  if (!basePath.startsWith('/')) return { kind: 'no-address' };
  let pageOrigin: string;
  try {
    pageOrigin = new URL(origin).origin;
  } catch {
    return { kind: 'no-address' };
  }
  const valueOf = (index: number): string => values.parameters[index] ?? '';
  const indexOf = new Map<string, number>();
  operation.parameters.forEach((parameter, index) => {
    if (parameter.in === 'path' && !indexOf.has(parameter.name)) indexOf.set(parameter.name, index);
  });

  const base = basePath.replace(/\/+$/, '');
  const realSegments: string[] = [];
  const shownSegments: string[] = [];
  // The copied command's URL, piece by piece: the real URL's text with a placeholder at each
  // value the record masks.
  const curlParts: CurlPart[] = [base];
  const operationPath = operation.path.startsWith('/') ? operation.path : `/${operation.path}`;
  for (const [at, segment] of operationPath.split('/').entries()) {
    const placeholders: number[] = [];
    let real = '';
    let shown = '';
    if (at > 0) curlParts.push('/');
    for (const part of segment.split(/(\{[^{}]*\})/)) {
      const match = /^\{([^{}]*)\}$/.exec(part);
      const index = match === null ? undefined : indexOf.get(match[1]);
      if (match === null || index === undefined) {
        const literal = encodeLiteral(part);
        real += literal;
        shown += literal;
        curlParts.push(literal);
        continue;
      }
      placeholders.push(index);
      const value = encodeURIComponent(valueOf(index));
      const secret = isSecretName(match[1]);
      real += value;
      shown += secret ? MASKED_VALUE : value;
      curlParts.push(secret ? { name: match[1] } : value);
    }
    if (placeholders.length > 0 && (real === '.' || real === '..')) {
      return { kind: 'traversal', index: placeholders[0] };
    }
    realSegments.push(real);
    shownSegments.push(shown);
  }

  const query: string[] = [];
  const shownQuery: string[] = [];
  const curlQuery: CurlPart[][] = [];
  const headers: [string, string][] = [];
  const form: string[] = [];
  const shownForm: string[] = [];
  const curlForm: string[] = [];
  operation.parameters.forEach((parameter, index) => {
    const value = valueOf(index);
    if (value === '') return;
    const name = encodeURIComponent(parameter.name);
    const secret = isSecretName(parameter.name);
    const pair = `${name}=${encodeURIComponent(value)}`;
    const shown = `${name}=${secret ? MASKED_VALUE : encodeURIComponent(value)}`;
    if (parameter.in === 'query') {
      query.push(pair);
      shownQuery.push(shown);
      curlQuery.push(secret ? [`${name}=`, { name: parameter.name }] : [pair]);
    } else if (parameter.in === 'header') {
      headers.push([parameter.name, value]);
    } else if (parameter.in === 'formData') {
      form.push(pair);
      shownForm.push(shown);
      curlForm.push(secret ? `${name}=${placeholder(parameter.name)}` : pair);
    }
  });

  const search = query.length > 0 ? `?${query.join('&')}` : '';
  let resolved: URL;
  try {
    resolved = new URL(`${base}${realSegments.join('/')}${search}`, pageOrigin);
  } catch {
    return { kind: 'no-address' };
  }
  if (resolved.origin !== pageOrigin) return { kind: 'no-address' };
  const shownSearch = shownQuery.length > 0 ? `?${shownQuery.join('&')}` : '';
  const displayUrl = `${pageOrigin}${base}${shownSegments.join('/')}${shownSearch}`;
  curlQuery.forEach((pair, at) => curlParts.push(at === 0 ? '?' : '&', ...pair));
  const curlUrl = curlParts.every((part) => typeof part === 'string') ? resolved.href : curlHref(curlParts, pageOrigin);

  const declaresType = headers.some(([name]) => name.toLowerCase() === 'content-type');
  let body: string | null = null;
  let displayBody: string | null = null;
  let curlBody: string | null = null;
  if (form.length > 0) {
    body = form.join('&');
    displayBody = shownForm.join('&');
    curlBody = curlForm.join('&');
    if (!declaresType) headers.push(['Content-Type', 'application/x-www-form-urlencoded']);
  } else if (takesBody(operation.verb) && values.body !== '') {
    body = values.body;
    displayBody = maskBody(values.body);
    curlBody = curlJsonBody(values.body);
    if (!declaresType) headers.push(['Content-Type', 'application/json']);
  }

  return {
    kind: 'ok',
    request: { method: operation.verb.toUpperCase(), url: resolved.href, displayUrl, headers, body, displayBody, curlUrl, curlBody },
  };
}

/**
 * What the console shows of `request` once sent: the request line with its secrets masked, every
 * header sent (the `Authorization` the tab's token fills always masked -- a declared header of that
 * name is never sent -- and any other whose name the credential pattern matches masked), and the
 * body with its secret-named members masked.
 */
export function maskedRecord(request: ComposedRequest): RequestRecord {
  const headers = sentHeaders(request).map(([name, value]) => `${name}: ${isSecretName(name) ? MASKED_VALUE : value}`);
  headers.push(`Authorization: ${MASKED_VALUE}`);
  return { line: `${request.method} ${request.displayUrl}`, headers, body: request.displayBody };
}

/**
 * The headers `request` sends besides the tab's token, in order: the declared headers the form
 * filled, then any `Content-Type` the console adds. A declared `Authorization` is never sent.
 */
export function sentHeaders(request: ComposedRequest): (readonly [string, string])[] {
  return request.headers.filter(([name]) => name.toLowerCase() !== 'authorization');
}

/** `value` as one POSIX shell word: single-quoted, each `'` inside written `'\''`. */
export function shellQuote(value: string): string {
  return `'${value.replace(/'/g, "'\\''")}'`;
}

/**
 * `request` as one POSIX curl command that sends what the console sends (AD-57 (5)), or the
 * refusal `refuseRequest` gives it. Its arguments are joined by single spaces, and a body keeps any
 * line break inside its quotes. Every argument but an option name is single-quoted. The tab's
 * token reads `Bearer <AccessToken>` and every value the record masks reads `<name>`; `--data-raw`
 * never reads a leading `@` as a file, `--head` is HEAD's own verb, and `--globoff` keeps curl from
 * expanding brackets or braces in the URL, written whenever the URL holds one as typed or encoded.
 */
export function curlCommand(request: ComposedRequest): CurlCommand {
  const refused = refuseRequest(request.method, request.url);
  if (refused !== null) return { kind: 'refused', refusal: refused };
  const words = ['curl'];
  if (/[[\]{}]|%5B|%5D|%7B|%7D/i.test(request.curlUrl)) words.push('--globoff');
  words.push(...(request.method === 'HEAD' ? ['--head'] : ['--request', shellQuote(request.method)]));
  words.push(shellQuote(request.curlUrl));
  for (const [name, value] of sentHeaders(request)) {
    words.push('--header', shellQuote(`${name}: ${isSecretName(name) ? placeholder(name) : value}`));
  }
  words.push('--header', shellQuote(`Authorization: Bearer ${STRINGS.tryItCurlAccessToken}`));
  if (request.curlBody !== null) words.push('--data-raw', shellQuote(request.curlBody));
  return { kind: 'ok', command: words.join(' ') };
}

/** Whether `contentType` is one the console decodes as text. */
function isTextType(mediaType: string): boolean {
  return (
    mediaType === '' ||
    mediaType.startsWith('text/') ||
    mediaType.endsWith('+json') ||
    mediaType.endsWith('+xml') ||
    ['application/json', 'application/xml', 'application/javascript', 'application/x-www-form-urlencoded'].includes(mediaType)
  );
}

/**
 * An answer's body as text: JSON pretty-printed through `JSON.parse` and `JSON.stringify` only,
 * other text decoded as UTF-8 up to `TEXT_CAP_BYTES` with the cut reported, and a non-text type as
 * its byte count alone. Nothing here is ever markup.
 */
export function renderBody(contentType: string, bytes: Uint8Array): RenderedBody {
  const mediaType = contentType.split(';')[0].trim().toLowerCase();
  const byteCount = bytes.length;
  if (!isTextType(mediaType)) return { kind: 'binary', text: '', byteCount, cut: false };
  const cut = byteCount > TEXT_CAP_BYTES;
  const text = new TextDecoder().decode(cut ? bytes.subarray(0, TEXT_CAP_BYTES) : bytes, { stream: cut });
  if (!cut && (mediaType === 'application/json' || mediaType.endsWith('+json'))) {
    try {
      return { kind: 'json', text: JSON.stringify(JSON.parse(text), null, 2), byteCount, cut: false };
    } catch {
      // Not the JSON it says it is: shown as the text it is.
    }
  }
  return { kind: 'text', text, byteCount, cut };
}
