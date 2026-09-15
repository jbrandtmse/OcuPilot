#!/usr/bin/env node
/**
 * Generates and drift-checks `module.xml` at the repository root from
 * `src/OcuPilot/Install/Roster.cls`'s `XData Manifest` block (AD-17, AD-18, AD-3).
 *
 * **One source, two readers.** `OcuPilot.Install.Roster` reads that block through
 * `%Dictionary.XDataDefinition`, and `OcuPilot.Install.Installer` asserts what it declares at
 * install time; this reads the same block off disk and writes the manifest IPM reads. The
 * manifest is therefore derived from the declaration rather than maintained beside it, and a
 * roster edit that is not regenerated fails `prebuild`, `prestart` and the pre-commit hook.
 * "Generated" means a checked-in artifact, reviewed like any other source (AD-3) -- never
 * runtime reflection and never a second hand-written source.
 *
 * **The comparison is an equality, in both directions.** A roster edited without regenerating
 * and a `module.xml` edited by hand are the same refusal: the committed bytes and this
 * generator's output must match exactly. A floor -- "the manifest declares at least what the
 * roster does" -- would pass a hand-added `<WebApplication>` the roster never declared, which
 * is precisely the second declaration this module exists to prevent.
 *
 * **It reports on every run, clean or refused.** Every run prints the package, application,
 * resource and class counts it compared, so a run that looked at nothing is distinguishable
 * from a run that found nothing wrong.
 *
 * **The tree is a second population, keyed differently from the roster.** The roster names
 * seven package folders; the scan lists the directories that actually exist under
 * `src/OcuPilot/` and requires the two sets to be equal, so a folder added or removed without
 * the roster is a refusal either way round. Every `.cls` under that tree must declare a class
 * in the `OcuPilot` package, because `<Resource Name="OcuPilot.PKG"/>` ships that package and
 * nothing else -- a class named otherwise compiles locally and is silently absent from the
 * shipped module. And `src/cls/` must not exist: IPM's document processor prefers a `cls`
 * sub-directory of `SourcesRoot` when one is on disk, so creating that directory would move
 * every resource's resolved path with no edit to this manifest at all.
 *
 * **An unreadable roster is reported, never read as an empty one.** `readRoster` answers
 * `null` rather than `{}` for that reason (`scripts/check-objectscript.py`'s `read_fixed_packages` states
 * the rule), and an empty roster would generate a manifest that declares no application, no
 * package and no resource -- and compare equal to itself forever.
 *
 * Usage: `node tools/ipm-manifest.mjs` writes the manifest; `--check` only reports drift.
 * Exit 1 on any refusal, 0 otherwise.
 */

import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { basename, dirname, isAbsolute, join, relative } from 'node:path';

import { extractClassName, extractXData } from './screen-mirror.mjs';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

/** The one declaration every consumer reads. */
export const ROSTER_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Install', 'Roster.cls');

/** The `XData` block inside it; the same name `OcuPilot.Install.Roster`'s parameter carries. */
export const ROSTER_XDATA = 'Manifest';

/** IPM's `SourcesRoot` on disk -- the directory `<SourcesRoot>src</SourcesRoot>` names. */
export const SRC_ROOT = join(REPO_ROOT, 'src');

/** Every project ObjectScript source lives here. */
export const SOURCE_ROOT = join(SRC_ROOT, 'OcuPilot');

/** The generated artifact, at the repository root where `zpm load .` looks for it. */
export const MANIFEST_PATH = join(REPO_ROOT, 'module.xml');

/** The package every shipped class must be declared in, and the `.PKG` resource that ships it. */
export const SHIPPED_PACKAGE = 'OcuPilot';

/**
 * The directory IPM's document processor prefers over `SourcesRoot` itself when it exists.
 * Its presence silently moves every resource's resolved path, so this checker refuses it.
 */
export const SHADOW_DIR = 'cls';

/**
 * Properties no manifest may ever carry, whatever the roster says (AD-10, AD-21): a privilege
 * set is asserted by the installer at install time, never widened by a distribution manifest.
 */
const PRIVILEGE_PROPERTIES = ['MatchRoles', 'Roles', 'AddedRoles'];

/** A value that would widen privilege however it is spelled. */
const PRIVILEGE_VALUE_RE = /%All/i;

/** The roster's `XData Manifest` block, parsed and shape-checked, or `null`. */
export function readRoster(text) {
  const body = extractXData(text, ROSTER_XDATA);
  if (body === null) return null;
  let parsed;
  try {
    parsed = JSON.parse(body);
  } catch {
    return null;
  }
  if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) return null;
  if (rosterShapeProblem(parsed) !== null) return null;
  return parsed;
}

/**
 * What is structurally missing from `roster`, or `null` when nothing is. Every field the
 * generator emits is required: a roster missing one would otherwise produce a manifest missing
 * an element, and that manifest would then compare equal to itself on every later run.
 */
export function rosterShapeProblem(roster) {
  const module = roster.module;
  if (module === null || typeof module !== 'object') return 'carries no "module" object';
  for (const field of ['name', 'version', 'description', 'packaging', 'sourcesRoot']) {
    if (typeof module[field] !== 'string' || module[field] === '') {
      return `module.${field} is missing or empty`;
    }
  }
  const requirements = roster.systemRequirements;
  if (requirements === null || typeof requirements !== 'object') {
    return 'carries no "systemRequirements" object';
  }
  for (const field of ['version', 'ipmVersion']) {
    if (typeof requirements[field] !== 'string' || requirements[field] === '') {
      return `systemRequirements.${field} is missing or empty`;
    }
  }
  if (!Array.isArray(roster.packages) || roster.packages.length === 0) {
    return 'carries no non-empty "packages" array';
  }
  for (const name of roster.packages) {
    if (typeof name !== 'string' || name === '') return 'packages holds an entry that is not a name';
  }
  if (!Array.isArray(roster.resources) || roster.resources.length === 0) {
    return 'carries no non-empty "resources" array';
  }
  for (const resource of roster.resources) {
    if (resource === null || typeof resource !== 'object') return 'resources holds an entry that is not an object';
    if (typeof resource.name !== 'string' || resource.name === '') return 'a resource carries no name';
    // Required, not optional: IPM loads a .PKG resource with ImportDir over "*" _
    // FilenameExtension, and its default for that property is empty -- a wildcard that tries
    // to import every file under the sources root, .gitkeep placeholders included.
    if (resource.name.endsWith('.PKG') && (typeof resource.filenameExtension !== 'string' || resource.filenameExtension === '')) {
      return `resource "${resource.name}" declares no filenameExtension, and a package resource loaded with IPM's empty default imports every file under the sources root`;
    }
    if ('filenameExtension' in resource && (typeof resource.filenameExtension !== 'string' || resource.filenameExtension === '')) {
      return `resource "${resource.name}" declares a filenameExtension that is not a name`;
    }
  }
  const bundle = roster.bundle;
  if (bundle === null || typeof bundle !== 'object') return 'carries no "bundle" object';
  if (typeof bundle.source !== 'string' || bundle.source === '') return 'bundle.source is missing or empty';
  if (typeof bundle.destinationApplication !== 'string' || bundle.destinationApplication === '') {
    return 'bundle.destinationApplication is missing or empty';
  }
  const templateFault = bundleTemplateProblem(bundle.destinationTemplate);
  if (templateFault !== null) return `bundle.destinationTemplate ${templateFault}`;
  if (!Array.isArray(roster.applications) || roster.applications.length === 0) {
    return 'carries no non-empty "applications" array';
  }
  for (const application of roster.applications) {
    const problem = applicationShapeProblem(application);
    if (problem !== null) return problem;
  }
  // The bundle lands in an application's own directory, so the path that names it is declared
  // once -- under "applications" -- and referred to here. Without this the roster would carry
  // two spellings of one path and a rename would move only the half the renamer remembered.
  if (!roster.applications.some((application) => application.path === bundle.destinationApplication)) {
    return `bundle.destinationApplication "${bundle.destinationApplication}" names no application the roster declares`;
  }
  const invoke = roster.invoke;
  if (invoke === null || typeof invoke !== 'object') return 'carries no "invoke" object';
  for (const field of ['class', 'method', 'phase', 'when']) {
    if (typeof invoke[field] !== 'string' || invoke[field] === '') {
      return `invoke.${field} is missing or empty`;
    }
  }
  return null;
}

/**
 * What is wrong with one application's declaration, or `null`.
 *
 * The `manifest`/`installer` split is the rule this enforces: a property is declared on
 * exactly one side, `manifest` never names a privilege property (AD-10) and never carries a
 * `%All`, and neither half may be empty -- an application whose `manifest` declares nothing
 * would emit an attribute-less `<WebApplication>`, and one whose `installer` declares nothing
 * would leave the install namespace to whatever IPM happened to default it to.
 */
export function applicationShapeProblem(application) {
  if (application === null || typeof application !== 'object') {
    return 'applications holds an entry that is not an object';
  }
  for (const field of ['key', 'path', 'description']) {
    if (typeof application[field] !== 'string' || application[field] === '') {
      return `an application is missing "${field}"`;
    }
  }
  // The same guard OcuPilot.Install.Installer.RosterNames applies at install time. Without it
  // the generator emits <WebApplication Name="ocupilot">, every gate reports clean, and the
  // install the manifest exists for is the thing that refuses.
  if (!application.path.startsWith('/')) {
    return `application "${application.key}" declares the path "${application.path}", which is not absolute`;
  }
  const declared = application.manifest;
  if (declared === null || typeof declared !== 'object' || Array.isArray(declared)) {
    return `application "${application.key}" carries no "manifest" object`;
  }
  const manifestKeys = Object.keys(declared);
  if (manifestKeys.length === 0) {
    return `application "${application.key}" declares no manifest property`;
  }
  if (!Array.isArray(application.installer) || application.installer.length === 0) {
    return `application "${application.key}" declares no instance-derived property`;
  }
  // The privilege rule is checked before the split rule, so that a privilege property named in
  // the manifest is refused for being a privilege property -- the reason that matters -- and
  // not merely for appearing on both halves.
  for (const key of manifestKeys) {
    if (PRIVILEGE_PROPERTIES.includes(key)) {
      return `application "${application.key}" declares "${key}" in its manifest; a privilege set is asserted by the installer, never by the manifest (AD-10)`;
    }
  }
  for (const name of application.installer) {
    if (typeof name !== 'string' || name === '') {
      return `application "${application.key}" names an instance-derived property that is not a name`;
    }
    if (manifestKeys.includes(name)) {
      return `application "${application.key}" declares "${name}" both in its manifest and as instance-derived`;
    }
  }
  for (const key of manifestKeys) {
    const value = declared[key];
    if (typeof value !== 'string' && typeof value !== 'number') {
      return `application "${application.key}" declares "${key}" as neither a string nor a number`;
    }
    if (PRIVILEGE_VALUE_RE.test(String(value))) {
      return `application "${application.key}" declares "${key}" as "${value}", which widens privilege from the manifest (AD-10)`;
    }
  }
  // Named, not merely absent: a `MatchRoles` in neither half is a matching-role set nothing
  // asserts, which IPM would leave at whatever `Security.Applications` defaults it to and no
  // install would ever repair (AD-10, AD-21).
  if (!application.installer.includes('MatchRoles')) {
    return `application "${application.key}" must name "MatchRoles" as instance-derived, so the installer asserts it and the manifest never states it (AD-10, AD-21)`;
  }
  // The privilege floor itself, declared per application (Story 1.17, AD-21). `""` is a
  // declaration -- it is what the password-authenticated API says, so that a request runs with
  // exactly the privileges its own account holds (AD-8) -- but an ABSENT one is refused, so a
  // new application cannot arrive with its floor unstated. `OcuPilot.Install.Installer`'s own
  // `RosterNames` applies the identical guard at install time.
  if (!('matchRole' in application)) {
    return `application "${application.key}" declares no "matchRole"; name the one purpose-built matching role the installer asserts for it, or "" for an application that carries none (AD-21)`;
  }
  if (typeof application.matchRole !== 'string') {
    return `application "${application.key}" declares a "matchRole" that is not a name`;
  }
  if (PRIVILEGE_VALUE_RE.test(application.matchRole)) {
    return `application "${application.key}" declares the matchRole "${application.matchRole}", which widens privilege (AD-10)`;
  }
  return null;
}

// --- The manifest as XML, not only as bytes (DW-197) ---------------------------------------

/** One well-formedness fault: what is wrong and where. */
const xmlFault = (message, offset) => ({ message, offset });

/**
 * Scan `text` as an XML document and return `{elements, error}`.
 *
 * **Why a scanner and not a parser library.** `firstDrift` compares the generated bytes with
 * the committed bytes, and two byte-identical documents are equally malformed: a generator bug
 * that emitted an unclosed element, an unquoted attribute value or a `--` inside a comment would
 * pass the drift check on every run and fail only inside IPM's own SAX reader, reported as a
 * line offset with no mention of OcuPilot. This reads the committed manifest as a document
 * instead, so the gate refuses it here, naming the fault and its offset. It adds no dependency:
 * this toolchain has no XML parser and the story does not add one (the same decision
 * `compose.test.mjs` records for YAML).
 *
 * Its scope, stated plainly: it checks tag balance and nesting, attribute syntax and quoting,
 * duplicate attributes, the XML comment rules IPM's reader enforces, and that exactly one root
 * element exists. It is not a validating parser and makes no claim about entities, namespaces,
 * DTDs or character-level content rules. `elements` is every element name in document order,
 * which is what `checkManifest` asserts the shape of.
 */
export function scanXml(text) {
  const elements = [];
  const stack = [];
  let index = 0;
  let sawRoot = false;

  const source = String(text);
  while (index < source.length) {
    const next = source.indexOf('<', index);
    if (next === -1) break;

    if (source.startsWith('<!--', next)) {
      const end = source.indexOf('-->', next + 4);
      if (end === -1) return { elements, error: xmlFault('an XML comment is never closed', next) };
      const body = source.slice(next + 4, end);
      if (body.includes('--')) {
        return { elements, error: xmlFault("a '--' sequence inside an XML comment, which XML forbids and IPM's SAX reader refuses the whole manifest over", next) };
      }
      index = end + 3;
      continue;
    }
    if (source.startsWith('<?', next)) {
      const end = source.indexOf('?>', next + 2);
      if (end === -1) return { elements, error: xmlFault('a processing instruction is never closed', next) };
      index = end + 2;
      continue;
    }
    if (source.startsWith('<![CDATA[', next)) {
      const end = source.indexOf(']]>', next + 9);
      if (end === -1) return { elements, error: xmlFault('a CDATA section is never closed', next) };
      index = end + 3;
      continue;
    }

    const close = findTagEnd(source, next);
    if (close === -1) return { elements, error: xmlFault('a tag is never closed', next) };
    const raw = source.slice(next + 1, close);
    if (raw === '') return { elements, error: xmlFault('an empty tag', next) };

    if (raw.startsWith('/')) {
      const name = raw.slice(1).trim();
      if (!isXmlName(name)) return { elements, error: xmlFault(`'${name}' is not a usable element name in a closing tag`, next) };
      if (stack.length === 0) return { elements, error: xmlFault(`closing tag </${name}> with nothing open`, next) };
      const open = stack.pop();
      if (open !== name) return { elements, error: xmlFault(`closing tag </${name}> does not match the open <${open}>`, next) };
      index = close + 1;
      continue;
    }

    const selfClosing = raw.endsWith('/');
    const body = selfClosing ? raw.slice(0, -1) : raw;
    const nameMatch = /^([^\s/>]+)/.exec(body);
    if (nameMatch === null || !isXmlName(nameMatch[1])) {
      return { elements, error: xmlFault(`'${body.trim().split(/\s/)[0]}' is not a usable element name`, next) };
    }
    const name = nameMatch[1];
    const attributeFault = scanAttributes(body.slice(name.length), next, name);
    if (attributeFault !== null) return { elements, error: attributeFault };

    if (stack.length === 0) {
      if (sawRoot) return { elements, error: xmlFault(`a second root element <${name}>; an XML document has exactly one`, next) };
      sawRoot = true;
    }
    elements.push(name);
    if (!selfClosing) stack.push(name);
    index = close + 1;
  }

  if (stack.length > 0) {
    return { elements, error: xmlFault(`<${stack[stack.length - 1]}> is never closed`, source.length) };
  }
  if (!sawRoot) return { elements, error: xmlFault('the document carries no element at all', 0) };
  return { elements, error: null };
}

/** The index of the `>` that ends the tag opening at `start`, honouring quoted attribute values. */
function findTagEnd(source, start) {
  let quote = '';
  for (let cursor = start + 1; cursor < source.length; cursor += 1) {
    const character = source[cursor];
    if (quote !== '') {
      if (character === quote) quote = '';
      continue;
    }
    if (character === '"' || character === "'") {
      quote = character;
      continue;
    }
    if (character === '>') return cursor;
    if (character === '<') return -1;
  }
  return -1;
}

/** Whether `name` is usable as an element or attribute name here. */
function isXmlName(name) {
  return /^[A-Za-z_][A-Za-z0-9._:-]*$/.test(name);
}

/** What is wrong with one element's attribute list, or `null`. */
function scanAttributes(text, offset, elementName) {
  const seen = new Set();
  let cursor = 0;
  while (cursor < text.length) {
    if (/\s/.test(text[cursor])) {
      cursor += 1;
      continue;
    }
    const nameMatch = /^([^\s=]+)\s*/.exec(text.slice(cursor));
    if (nameMatch === null) return xmlFault(`<${elementName}> carries an attribute this reader cannot read`, offset);
    const name = nameMatch[1];
    if (!isXmlName(name)) return xmlFault(`<${elementName}> carries '${name}', which is not a usable attribute name`, offset);
    cursor += nameMatch[0].length;
    if (text[cursor] !== '=') return xmlFault(`<${elementName}>'s attribute '${name}' has no value; XML has no bare attributes`, offset);
    cursor += 1;
    while (cursor < text.length && /\s/.test(text[cursor])) cursor += 1;
    const quote = text[cursor];
    if (quote !== '"' && quote !== "'") {
      return xmlFault(`<${elementName}>'s attribute '${name}' has an unquoted value`, offset);
    }
    const end = text.indexOf(quote, cursor + 1);
    if (end === -1) return xmlFault(`<${elementName}>'s attribute '${name}' has an unterminated value`, offset);
    const value = text.slice(cursor + 1, end);
    if (value.includes('<')) return xmlFault(`<${elementName}>'s attribute '${name}' carries a raw '<', which XML forbids`, offset);
    if (seen.has(name)) return xmlFault(`<${elementName}> carries the attribute '${name}' twice`, offset);
    seen.add(name);
    cursor = end + 1;
  }
  return null;
}

/**
 * The element names a manifest generated from `roster` must carry, in document order -- the
 * shape assertion that sits beside the byte comparison (DW-197). Derived from the roster, so a
 * fourth application is one more `WebApplication` here by arriving in the roster and nowhere
 * else.
 */
export function expectedElements(roster) {
  const names = ['Export', 'Document', 'Module', 'Name', 'Version', 'Description', 'Packaging', 'SourcesRoot', 'SystemRequirements'];
  for (let index = 0; index < roster.resources.length; index += 1) names.push('Resource');
  for (let index = 0; index < roster.applications.length; index += 1) names.push('WebApplication');
  names.push('FileCopy', 'Invoke');
  return names;
}

/** The top-level directories under `sourceRoot`, sorted -- the package folders on disk. */
export function packageDirectories(sourceRoot) {
  return readdirSync(sourceRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

/**
 * Every `.cls` under `sourceRoot`, as `{file, className}` with a repository-relative path,
 * sorted. A file whose class declaration cannot be read carries `className: null` rather than
 * being skipped, so the caller refuses it by name.
 */
export function declaredClasses(sourceRoot) {
  const found = [];
  const walk = (current) => {
    for (const entry of readdirSync(current, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : 1))) {
      const full = join(current, entry.name);
      if (entry.isDirectory()) {
        walk(full);
        continue;
      }
      if (!entry.isFile() || !entry.name.endsWith('.cls')) continue;
      found.push({ file: shortPath(full), className: extractClassName(readFileSync(full, 'utf8')) });
    }
  };
  walk(sourceRoot);
  return found.sort((a, b) => (a.file < b.file ? -1 : a.file > b.file ? 1 : 0));
}

/** An XML attribute value or element text, escaped. */
export function xmlEscape(value) {
  return String(value)
    .split('&')
    .join('&amp;')
    .split('<')
    .join('&lt;')
    .split('>')
    .join('&gt;')
    .split('"')
    .join('&quot;');
}

/**
 * What is wrong with a bundle destination template, or `null`.
 *
 * The template is the one place the manifest names a filesystem path, so the rules are narrow:
 * it resolves under `${dataDir}` (the writable data directory), never under `${cspdir}` (the
 * install directory's `csp`, which `src/OcuPilot/Api/StaticHandler.cls` records as not writable
 * on the pinned image), it is a directory, and it carries a placeholder rather than a literal
 * absolute path that would only be right on one instance.
 *
 * **IPM's arbitrary-ObjectScript `#{...}` form cannot be used here**, which is why the template
 * is a placeholder string and not a call to the handler. Verified on a throwaway container:
 * `<FileCopy>`'s `InstallDirectory` is `Required` and is validated in the `Validate` phase,
 * which runs before `Compile` -- so the handler class this module is installing is loaded but
 * not yet compiled, the expression evaluates to `""`, and the module fails validation. The pin
 * that keeps this template and the handler from drifting is
 * `OcuPilot.Test.Manifest.TestBundleDestinationIsTheHandlersOwnAnswer`, which expands the
 * template against a live instance and compares it with the handler's own answer.
 */
export function bundleTemplateProblem(template) {
  if (typeof template !== 'string' || template === '') return 'is missing or empty';
  // The install-directory placeholder is checked first, so a template that names it is refused
  // for the reason that matters rather than for also lacking ${dataDir}.
  if (/cspdir/i.test(template)) {
    return "resolves under ${cspdir}, the install directory's csp, which is not writable on the pinned image";
  }
  if (!/\$\{dataDir\}/i.test(template) && !/\{\$dataDir\}/i.test(template)) {
    return 'does not resolve under ${dataDir}, so it would name a path that is right on one instance only';
  }
  if (!template.endsWith('/')) {
    return 'does not end in "/", so IPM would copy the bundle as a file rather than into a directory';
  }
  return null;
}

/**
 * The header comment's text, without its delimiters.
 *
 * **It carries no `--`**, which the rest of this tree's prose uses freely as a dash. XML forbids
 * that sequence inside a comment, and IPM parses the manifest with a strict SAX reader: a `--`
 * here is not a style problem but a module that cannot be loaded at all, reported as
 * "'--' sequence is illegal in comment" with a line offset and no mention of OcuPilot.
 * `commentProblem` refuses to emit one.
 */
const HEADER_COMMENT_TEXT = `  GENERATED FILE. DO NOT EDIT.

  OcuPilot's IPM manifest, derived from the XData Manifest block in
  src/OcuPilot/Install/Roster.cls, which is also what OcuPilot.Install.Installer reads (AD-17).
  Edit the roster and regenerate; editing this file alone fails the drift check.

  Regenerate:  cd ui && node tools/ipm-manifest.mjs
  Drift check: the same command with a "check" flag, which ui/package.json's prebuild and
               prestart, and .githooks/pre-commit, all run.

  That flag is described rather than written out because XML forbids a double hyphen inside
  a comment, and IPM's SAX reader refuses the whole manifest over one.`;

/**
 * What makes `text` unusable as the body of an XML comment, or `null` when nothing does.
 * Refused rather than escaped: a comment is prose a human wrote, and silently rewriting it
 * would hide the mistake in a generated file nobody reads.
 */
export function commentProblem(text) {
  if (text.includes('--')) {
    return "carries a '--' sequence, which XML forbids inside a comment; IPM's SAX reader refuses the whole manifest";
  }
  if (text.trimEnd().endsWith('-')) {
    return "ends on '-', which would close the comment as '--->'";
  }
  return null;
}

/** The manifest this roster produces. */
export function buildManifest(roster) {
  const lines = [];
  const commentFault = commentProblem(HEADER_COMMENT_TEXT);
  if (commentFault !== null) {
    throw new Error(`ipm-manifest: the header comment ${commentFault}`);
  }
  lines.push('<?xml version="1.0" encoding="UTF-8"?>');
  lines.push(`<!--\n${HEADER_COMMENT_TEXT}\n-->`);
  lines.push('<Export generator="Cache" version="25">');
  lines.push(`  <Document name="${xmlEscape(roster.module.name)}.ZPM">`);
  lines.push('    <Module>');
  lines.push(`      <Name>${xmlEscape(roster.module.name)}</Name>`);
  lines.push(`      <Version>${xmlEscape(roster.module.version)}</Version>`);
  lines.push(`      <Description>${xmlEscape(roster.module.description)}</Description>`);
  lines.push(`      <Packaging>${xmlEscape(roster.module.packaging)}</Packaging>`);
  lines.push(`      <SourcesRoot>${xmlEscape(roster.module.sourcesRoot)}</SourcesRoot>`);
  // Health is omitted rather than set: <SystemRequirements Health="0"/> is a refusal of IRIS
  // for Health, which is the platform this project targets.
  lines.push(
    `      <SystemRequirements Version="${xmlEscape(roster.systemRequirements.version)}" ` +
      `IPMVersion="${xmlEscape(roster.systemRequirements.ipmVersion)}"/>`
  );

  for (const resource of roster.resources) {
    const scope = typeof resource.scope === 'string' && resource.scope !== '' ? ` Scope="${xmlEscape(resource.scope)}"` : '';
    // FilenameExtension narrows IPM's recursive ImportDir wildcard from "*" to "*cls"; without
    // it the load fails on the first non-source file under the sources root.
    const extension =
      typeof resource.filenameExtension === 'string' && resource.filenameExtension !== ''
        ? ` FilenameExtension="${xmlEscape(resource.filenameExtension)}"`
        : '';
    lines.push(`      <Resource Name="${xmlEscape(resource.name)}"${extension}${scope}/>`);
  }

  for (const application of roster.applications) {
    const attributes = { Description: application.description, ...application.manifest };
    lines.push(`      <WebApplication Name="${xmlEscape(application.path)}"`);
    for (const key of Object.keys(attributes).sort()) {
      lines.push(`                      ${key}="${xmlEscape(attributes[key])}"`);
    }
    lines.push('      />');
  }

  // Defer is left off, so the copy runs in Activate's OnBeforePhase -- strictly before the
  // When="After" <Invoke> below. The bundle is therefore in place before Install() runs, and
  // Install()'s empty pBundleSource correctly leaves it alone.
  lines.push(
    `      <FileCopy Name="${xmlEscape(roster.bundle.source)}" ` +
      `Target="${xmlEscape(roster.bundle.destinationTemplate)}"/>`
  );

  // No <Arg> children (DW-92): pUnexpire keeps its 0 default, so the IPM path can never reach
  // EnsureUnexpired. Phase is stated explicitly -- its default is Configure, which is not in
  // the activate chain, so a bare <Invoke> would never run at all.
  lines.push(
    `      <Invoke Class="${xmlEscape(roster.invoke.class)}" Method="${xmlEscape(roster.invoke.method)}" ` +
      `Phase="${xmlEscape(roster.invoke.phase)}" When="${xmlEscape(roster.invoke.when)}"/>`
  );

  lines.push('    </Module>');
  lines.push('  </Document>');
  lines.push('</Export>');
  return `${lines.join('\n')}\n`;
}

/** One report line per early refusal, so a run that cannot compare anything still says so. */
function refusedBeforeComparing(report, what) {
  report.push('ipm-manifest: compared 0 package(s), 0 application(s), 0 resource(s), 0 class(es)');
  report.push(`ipm-manifest: refused before comparing anything -- ${what}`);
}

/** The element name a generated or committed manifest line opens, or `""`. */
export function elementOf(line) {
  const match = /^\s*<\/?([A-Za-z][A-Za-z0-9]*)/.exec(line ?? '');
  return match === null ? '' : match[1];
}

/**
 * The element a given line belongs to: the one it opens, or -- for a continuation line of a
 * multi-line element, which is how a `<WebApplication>`'s attributes are written -- the last
 * element opened at or above it.
 */
export function elementAt(lines, index) {
  for (let cursor = Math.min(index, lines.length - 1); cursor >= 0; cursor -= 1) {
    const element = elementOf(lines[cursor]);
    if (element !== '') return element;
  }
  return '';
}

/**
 * The first line at which `expected` and `actual` differ, as a problem string naming the
 * element and the regenerate command, or `null` when they are byte-identical.
 *
 * Reported as an element rather than as a diff because the two documents are generated from
 * one roster in a fixed order: the first line that differs is the first declaration that
 * drifted, in whichever direction.
 */
export function firstDrift(expected, actual, manifestPath) {
  if (expected === actual) return null;
  const want = expected.split('\n');
  const have = actual.split('\n');
  for (let index = 0; index < Math.max(want.length, have.length); index += 1) {
    if (want[index] === have[index]) continue;
    const element = elementAt(want, index) || elementAt(have, index) || 'Module';
    const wantText = want[index] === undefined ? '(end of file)' : want[index].trim();
    const haveText = have[index] === undefined ? '(end of file)' : have[index].trim();
    return (
      `${manifestPath}:${index + 1}: <${element}> drifted from src/OcuPilot/Install/Roster.cls -- ` +
      `the roster generates \`${wantText}\` and the committed manifest carries \`${haveText}\`. ` +
      `Edit the roster, never the manifest, then run: cd ui && node tools/ipm-manifest.mjs`
    );
  }
  return null;
}

/**
 * Runs the check and returns `{ok, report, problems, expected, counts}`.
 *
 * `report` is what `main()` prints on every run, clean or not; `problems` is empty exactly
 * when `ok`. The sources are injectable so both drift directions and every refusal can be
 * exercised over a synthetic tree, and default to the real ones -- which is what a bare
 * `node tools/ipm-manifest.mjs --check` compares.
 */
export function checkManifest({
  rosterSource = ROSTER_SOURCE,
  srcRoot = SRC_ROOT,
  sourceRoot = srcRoot === SRC_ROOT ? SOURCE_ROOT : join(srcRoot, SHIPPED_PACKAGE),
  manifestPath = MANIFEST_PATH,
  compare = true,
} = {}) {
  const report = [];
  const problems = [];
  const empty = { packages: 0, applications: 0, resources: 0, classes: 0 };

  let rosterText = null;
  try {
    rosterText = readFileSync(rosterSource, 'utf8');
  } catch (error) {
    rosterText = null;
    problems.push(
      `${shortPath(rosterSource)}: the roster could not be read -- ${error.message}; ` +
        `an unreadable roster is a refusal, never an empty roster (AD-17)`
    );
  }
  const roster = rosterText === null ? null : readRoster(rosterText);
  if (roster === null) {
    if (rosterText !== null) {
      const body = extractXData(rosterText, ROSTER_XDATA);
      const why =
        body === null
          ? `carries no readable 'XData ${ROSTER_XDATA}' block`
          : `carries an 'XData ${ROSTER_XDATA}' block that is not a usable roster` +
            (() => {
              try {
                const problem = rosterShapeProblem(JSON.parse(body));
                return problem === null ? '' : ` -- it ${problem}`;
              } catch {
                return ' -- it is not parseable JSON';
              }
            })();
      problems.push(
        `${shortPath(rosterSource)}: ${why}; an unreadable roster is a refusal, never an empty roster (AD-17)`
      );
    }
    refusedBeforeComparing(report, `${shortPath(rosterSource)} is unreadable`);
    return { ok: false, report, problems, expected: null, counts: empty };
  }

  // The two facts this checker holds as its own constants -- which directory is <SourcesRoot>
  // and which package <Resource> ships -- are also declared by the roster, and the manifest is
  // generated from the roster's spelling while the tree below is walked at this checker's. A
  // roster that moved either would ship a module resolving somewhere nothing looked at, and
  // both halves would report clean. Held equal here so the drift is a refusal instead.
  if (roster.module.sourcesRoot !== basename(srcRoot)) {
    problems.push(
      `${shortPath(rosterSource)}: declares sourcesRoot "${roster.module.sourcesRoot}", but this ` +
        `check walks ${shortPath(srcRoot)}; <SourcesRoot> and the tree the shipped resources are ` +
        `read from must be the same directory, or the manifest names a tree nothing looked at`
    );
    refusedBeforeComparing(report, `${shortPath(rosterSource)} names a different sources root`);
    return { ok: false, report, problems, expected: null, counts: empty };
  }
  if (!roster.resources.some((resource) => resource.name === `${SHIPPED_PACKAGE}.PKG`)) {
    problems.push(
      `${shortPath(rosterSource)}: declares no resource named "${SHIPPED_PACKAGE}.PKG", yet every ` +
        `class under ${shortPath(sourceRoot)} is required to be in the ${SHIPPED_PACKAGE} package; ` +
        `the shipped package and the package this check enforces must be the same one`
    );
    refusedBeforeComparing(report, `${shortPath(rosterSource)} ships no ${SHIPPED_PACKAGE}.PKG`);
    return { ok: false, report, problems, expected: null, counts: empty };
  }

  // IPM's document processor prefers <SourcesRoot>/cls over <SourcesRoot> itself when that
  // directory is on disk, so its mere existence moves every resource's resolved path with no
  // edit to the manifest. Checked before the tree is walked: a tree that has already moved is
  // not one to report package counts about.
  const shadow = join(srcRoot, SHADOW_DIR);
  if (existsSync(shadow) && statSync(shadow).isDirectory()) {
    problems.push(
      `${shortPath(shadow)}: exists, and IPM resolves <Resource Name="${SHIPPED_PACKAGE}.PKG"/> ` +
        `under <SourcesRoot>/${SHADOW_DIR}/ whenever that directory is present -- silently, with ` +
        `no edit to module.xml. Remove it, or the shipped module resolves somewhere this ` +
        `manifest does not name`
    );
    refusedBeforeComparing(report, `${shortPath(shadow)} exists`);
    return { ok: false, report, problems, expected: null, counts: empty };
  }

  let directories = [];
  let classes = [];
  try {
    directories = packageDirectories(sourceRoot);
    classes = declaredClasses(sourceRoot);
  } catch (error) {
    problems.push(`${shortPath(sourceRoot)}: the source tree could not be read -- ${error.message}`);
    refusedBeforeComparing(report, `${shortPath(sourceRoot)} is unreadable`);
    return { ok: false, report, problems, expected: null, counts: empty };
  }

  // A population of nothing passes every rule below it: the class-package loop asserts once per
  // class, so an empty scan reports "0 class(es)" and exits 0 having looked at no class at all.
  // The counts line says so on every run, but only a person reads that -- the gates read the
  // exit code. Held as a refusal for the same reason an unreadable roster is one.
  if (classes.length === 0) {
    problems.push(
      `${shortPath(sourceRoot)}: holds no .cls at all; the rule that every shipped class is in ` +
        `the ${SHIPPED_PACKAGE} package would then be asserted over nothing, and this check would ` +
        `pass having looked at no class`
    );
    refusedBeforeComparing(report, `${shortPath(sourceRoot)} holds no class`);
    return { ok: false, report, problems, expected: null, counts: empty };
  }

  const declaredPackages = [...roster.packages].sort();
  const missingFromRoster = directories.filter((name) => !declaredPackages.includes(name));
  const missingFromTree = declaredPackages.filter((name) => !directories.includes(name));
  for (const name of missingFromRoster) {
    problems.push(
      `${shortPath(join(sourceRoot, name))}: is a package folder the roster does not declare; ` +
        `add it to "packages" in ${shortPath(ROSTER_SOURCE)} and regenerate`
    );
  }
  for (const name of missingFromTree) {
    problems.push(
      `${shortPath(ROSTER_SOURCE)}: declares the package folder "${name}", which does not exist ` +
        `under ${shortPath(sourceRoot)}; the roster and the tree must agree, or the roster names ` +
        `a tree nothing looked at`
    );
  }

  for (const entry of classes) {
    if (entry.className === null) {
      problems.push(`${entry.file}: carries no class declaration this reader can find; a file it cannot read is a refusal, never a skip`);
      continue;
    }
    if (entry.className !== SHIPPED_PACKAGE && !entry.className.startsWith(`${SHIPPED_PACKAGE}.`)) {
      problems.push(
        `${entry.file}: declares class "${entry.className}", which is outside the ${SHIPPED_PACKAGE} ` +
          `package; <Resource Name="${SHIPPED_PACKAGE}.PKG"/> would not ship it, so it would compile ` +
          `here and be absent from every installed module`
      );
    }
  }

  const expected = buildManifest(roster);
  const counts = {
    packages: declaredPackages.length,
    applications: roster.applications.length,
    resources: roster.resources.length,
    classes: classes.length,
  };

  report.push(
    `ipm-manifest: compared ${counts.packages} package(s), ${counts.applications} application(s), ` +
      `${counts.resources} resource(s), ${counts.classes} class(es)`
  );
  report.push(
    `ipm-manifest: roster declares module ${roster.module.name} ${roster.module.version}, ` +
      `sources root "${roster.module.sourcesRoot}", against ${directories.length} package folder(s) on disk`
  );
  for (const application of roster.applications) {
    report.push(
      `ipm-manifest: application ${application.path} -- ${Object.keys(application.manifest).length} ` +
        `manifest propert(ies), ${application.installer.length} asserted by the installer ` +
        `(${[...application.installer].sort().join(', ')})`
    );
  }

  if (compare) {
    let committed = null;
    try {
      committed = readFileSync(manifestPath, 'utf8');
    } catch (error) {
      problems.push(
        `${shortPath(manifestPath)}: the generated manifest could not be read -- ${error.message}; ` +
          `run: cd ui && node tools/ipm-manifest.mjs`
      );
    }
    if (committed !== null) {
      const drift = firstDrift(expected, committed, shortPath(manifestPath));
      if (drift !== null) problems.push(drift);

      // DW-197: the committed manifest is read as a DOCUMENT as well as compared as bytes.
      // Two byte-identical manifests are equally malformed, so a generator bug that emitted
      // an unclosed element would pass the comparison above on every run and fail only inside
      // IPM's own SAX reader, at a line offset with no mention of OcuPilot.
      const scanned = scanXml(committed);
      if (scanned.error !== null) {
        problems.push(
          `${shortPath(manifestPath)}: is not well-formed XML -- ${scanned.error.message}, at offset ${scanned.error.offset}. ` +
            `IPM parses this file with a strict SAX reader and refuses the whole module over it`
        );
      } else {
        const want = expectedElements(roster);
        if (scanned.elements.join(',') !== want.join(',')) {
          problems.push(
            `${shortPath(manifestPath)}: carries the elements [${scanned.elements.join(', ')}], and the roster declares ` +
              `[${want.join(', ')}]. Edit the roster, never the manifest, then run: cd ui && node tools/ipm-manifest.mjs`
          );
        }
        report.push(`ipm-manifest: parsed ${scanned.elements.length} XML element(s) in ${shortPath(manifestPath)}`);
      }
    }
  }

  return { ok: problems.length === 0, report, problems, expected, counts };
}

/**
 * A repository-relative path, so the report reads the same whether the check was run from
 * `ui/` or from the repository root. A path outside the repository -- a synthetic tree in a
 * temporary directory -- is reported as itself.
 */
function shortPath(target) {
  const fromRepoRoot = relative(REPO_ROOT, target).split('\\').join('/');
  if (fromRepoRoot === '' || fromRepoRoot.startsWith('..') || isAbsolute(fromRepoRoot)) return target;
  return fromRepoRoot;
}

function main() {
  // Anything that is not exactly `--check` is refused rather than treated as "write": the
  // write path rewrites a committed file, so a typo'd gate flag (`--chek`) must not silently
  // regenerate the manifest and exit 0 where the caller asked for a drift report.
  const unknown = process.argv.slice(2).filter((argument) => argument !== '--check');
  if (unknown.length > 0) {
    console.error(`ipm-manifest: unknown argument ${unknown[0]}; usage: ipm-manifest.mjs [--check]`);
    process.exitCode = 1;
    return;
  }
  const write = !process.argv.includes('--check');
  const result = checkManifest({ compare: !write });
  for (const line of result.report) {
    console.log(line);
  }
  if (!result.ok) {
    console.error('ipm-manifest: found violations --');
    for (const problem of result.problems) {
      console.error(`  ${problem}`);
    }
    console.error(`\nipm-manifest: ${result.problems.length} violation(s)`);
    // `process.exitCode` rather than `process.exit(1)`: the report above is the point of this
    // check, and `process.exit` tears the process down without draining writes still queued
    // when stdout is a pipe -- which is what it is under the pre-commit hook and under npm.
    process.exitCode = 1;
    return;
  }
  if (write) {
    writeFileSync(MANIFEST_PATH, result.expected);
    console.log(`ipm-manifest: wrote ${shortPath(MANIFEST_PATH)}`);
    return;
  }
  console.log('ipm-manifest: up to date.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
