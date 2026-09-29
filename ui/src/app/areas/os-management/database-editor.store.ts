import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { screenForRoute } from '../../core/navigation';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { createScreenRead } from '../../core/screen-read';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import { DATABASE_CONFIGURATION_ENTITY, DATABASE_FORM_PATH, DATABASE_PATH, DATABASE_SCOPE } from './database-wizard.store';

/** The screen whose declared read the Volume files group issues (AD-5, Story 6.11's pairing). */
export const DATABASE_VOLUMES_ROUTE = 'os-management/databases/volumes';

/** The volumes read's own row cap: a database's own files are never many. */
export const DATABASE_VOLUMES_MAX_ROWS = 200;

/** The groups a Save sends, each one write through its own tool (AD-4, AD-55). */
export const CONFIGURATION_GROUP = 'configuration';
export const FILE_GROUP = 'file';

/** The size grow's group (Story 18.4): the file's size in megabytes, sent after the other two. */
export const SIZE_GROUP = 'size';
export const SIZE_FIELD = 'Size';

/** The mounting group's settable flags, as `Database.ConfigCRUD` names them. */
export const CONFIGURATION_FLAGS: readonly string[] = ['MountAtStartup', 'MountRequired', 'ClusterMountMode'];

/** The file group's settable text fields, as `Database.SysCRUD` names them. */
export const FILE_TEXT_FIELDS: readonly string[] = ['MaxSize', 'ExpansionSize', 'NewVolumeThreshold', 'ResourceName'];

/** The file group's whole-megabyte fields, sent as numbers when they read as one. */
export const FILE_NUMBER_FIELDS: readonly string[] = ['MaxSize', 'ExpansionSize', 'NewVolumeThreshold'];

/** The file group's settable flags. */
export const FILE_FLAGS: readonly string[] = ['NewGlobalIsKeep', 'GlobalJournalState', 'ReadOnly'];

/** The two arguments a new volume directory is named by (AD-21's sixth case). */
export const VOLUME_ROOT_FIELD = 'volumeRoot';
export const VOLUME_PATH_FIELD = 'volumePath';

/** One row of the Volume files group, as the declared read answered it. */
export type VolumeRow = Readonly<Record<string, unknown>>;

function objectAt(source: unknown, key: string): Record<string, unknown> | null {
  if (source === null || typeof source !== 'object') return null;
  const value = (source as Record<string, unknown>)[key];
  return value !== null && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

function textOf(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  return textOf((source as Record<string, unknown>)[key]);
}

function flagOf(value: unknown): boolean {
  return value === true || value === 1 || value === '1' || value === 'true';
}

function stringsAt(source: unknown, key: string): string[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === 'string' && entry !== '') : [];
}

/** A whole number as a JSON number, anything else as the text typed, so the server's rule answers it. */
function numberValue(text: string): number | string {
  return /^[0-9]{1,9}$/.test(text) ? Number(text) : text;
}

/**
 * The local database editor's store (Story 18.3, AD-19, AD-55): the database its route names, in
 * three groups -- General and Volume files, which are the file's settings, and Mounting, which is
 * the configuration entry's.
 *
 * **It composes no payload of its own.** `PUT /database/:id` carries only the groups that changed,
 * each holding only its changed fields; the server merges each over its own fresh read and sends
 * that endpoint's complete set (AD-4), through the tools the agent's `osmgmt.localdatabases.update`
 * and `updatemount` resolve. Size is its own group (Story 18.4), sent as the size grow the agent's
 * `osmgmt.localdatabases.grow` makes, and offered only where the form read answered the file's size. Every sentence is the server's (AD-39). A new volume directory is a
 * root and a relative path from the page's picker, never a path.
 *
 * **The Volume files group issues `DatabaseVolumeList`'s declared read** with its one `dir`
 * criterion -- this database's directory -- under that screen's own gate and cap (AD-5), on open
 * and after every accepted Save.
 */
@Injectable({ providedIn: 'root' })
export class DatabaseEditor {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private nameValue = '';

  private directoryValue = '';

  private newVolumeDirectoryValue = '';

  private textValues: Readonly<Record<string, string>> = {};

  /** The file's size in megabytes as typed, and as the form read answered it; `null` where it did not. */
  private sizeValue: string | null = null;

  private openedSize: string | null = null;

  private flagValues: Readonly<Record<string, boolean>> = {};

  private openedText: Readonly<Record<string, string>> = {};

  private openedFlags: Readonly<Record<string, boolean>> = {};

  private changingVolume = false;

  private volumeRootValue = '';

  private volumePathValue = '';

  private resourcesValue: readonly string[] = [];

  private resourcesRefusedValue = '';

  private loadedValue = false;

  private heldValue = false;

  private absentValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private savedValue = false;

  /** Whether the last accepted Save answered that its size grow continues on the instance (AD-26). */
  private continuesValue = false;

  private readBackValue: ReadBack | null = null;

  private volumeRowsValue: readonly VolumeRow[] = [];

  private volumesLoadedValue = false;

  private volumesFaultValue = false;

  private volumeAsk = 0;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  loaded(): boolean {
    return this.loadedValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  /** Whether the route names a database the instance does not hold, which blocks Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** Whether the fields take input: only once the fresh read is held. */
  editable(): boolean {
    return this.heldValue;
  }

  canSave(): boolean {
    return this.heldValue && !this.savingValue && !this.absentValue;
  }

  name(): string {
    return this.nameValue;
  }

  directory(): string {
    return this.directoryValue;
  }

  newVolumeDirectory(): string {
    return this.newVolumeDirectoryValue;
  }

  text(field: string): string {
    if (field === SIZE_FIELD) return this.sizeValue ?? '';
    return this.textValues[field] ?? '';
  }

  /** Whether the form read answered the file's size, so Size (MB) is offered (Story 18.4). */
  sizeHeld(): boolean {
    return this.sizeValue !== null;
  }

  /** Whether the form holds a change not yet saved: Add a volume waits for a clean form (Story 18.4). */
  dirty(): boolean {
    return this.formDirty.dirty();
  }

  flag(field: string): boolean {
    return this.flagValues[field] ?? false;
  }

  /** Whether Change has revealed the new volume directory's picker. */
  changingVolumeDirectory(): boolean {
    return this.changingVolume;
  }

  volumeRoot(): string {
    return this.volumeRootValue;
  }

  volumePath(): string {
    return this.volumePathValue;
  }

  resources(): readonly string[] {
    return this.resourcesValue;
  }

  /** The pair a caller lacks to list the resources, or `''` when they were listed. */
  resourcesRefused(): string {
    return this.resourcesRefusedValue;
  }

  violations(): readonly Violation[] {
    return this.violationList;
  }

  violationFor(field: string): string {
    return reasonForField(this.violationList, field);
  }

  reason(): string {
    return this.envelopeReason;
  }

  refusalCode(): string {
    return this.refusalCodeValue;
  }

  refusalPair(): string {
    return this.refusalPairValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  /** Whether the last accepted Save is still running on the instance, until the next edit or Save. */
  continues(): boolean {
    return this.savedValue && this.continuesValue;
  }

  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  volumeRows(): readonly VolumeRow[] {
    return this.volumeRowsValue;
  }

  volumesLoaded(): boolean {
    return this.volumesLoadedValue;
  }

  volumesFault(): boolean {
    return this.volumesFaultValue;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the editor is left. */
  reset(): void {
    this.generation += 1;
    this.volumeAsk += 1;
    this.nameValue = '';
    this.directoryValue = '';
    this.newVolumeDirectoryValue = '';
    this.textValues = {};
    this.sizeValue = null;
    this.openedSize = null;
    this.flagValues = {};
    this.openedText = {};
    this.openedFlags = {};
    this.changingVolume = false;
    this.volumeRootValue = '';
    this.volumePathValue = '';
    this.resourcesValue = [];
    this.resourcesRefusedValue = '';
    this.loadedValue = false;
    this.heldValue = false;
    this.absentValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.continuesValue = false;
    this.readBackValue = null;
    this.volumeRowsValue = [];
    this.volumesLoadedValue = false;
    this.volumesFaultValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the editor over a fresh form read of the database `name`, then read its volume files.
   * `keepSaved` carries the last accepted Save's confirmation across the re-read that follows it.
   */
  async open(name: string, keepSaved = false): Promise<void> {
    const saved = keepSaved && this.savedValue;
    const readBack = this.readBackValue;
    const continues = this.continuesValue;
    this.reset();
    if (saved) {
      this.savedValue = true;
      this.continuesValue = continues;
      this.readBackValue = readBack;
    }
    if (name === '') return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${DATABASE_FORM_PATH}?name=${encodeURIComponent(name)}`);
    if (generation !== this.generation) return;
    this.loadedValue = true;
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      if (result.kind === 'error' && result.status === 404) this.absentValue = true;
      this.notify();
      return;
    }
    this.absorb(result.body, name);
    this.notify();
    if (this.heldValue) await this.loadVolumes();
  }

  setText(field: string, value: string): void {
    if (field === SIZE_FIELD) {
      if (!this.heldValue || this.sizeValue === null || this.sizeValue === value) return;
      this.sizeValue = value;
      this.change(field);
      return;
    }
    if (!this.heldValue || !FILE_TEXT_FIELDS.includes(field) || this.text(field) === value) return;
    this.textValues = { ...this.textValues, [field]: value };
    this.change(field);
  }

  setFlag(field: string, value: boolean): void {
    if (!this.heldValue || (!FILE_FLAGS.includes(field) && !CONFIGURATION_FLAGS.includes(field))) return;
    if (this.flag(field) === value) return;
    this.flagValues = { ...this.flagValues, [field]: value };
    this.change(field);
  }

  /** Change: reveal the new volume directory's picker. */
  changeVolumeDirectory(): void {
    if (!this.heldValue || this.changingVolume) return;
    this.changingVolume = true;
    this.notify();
  }

  /**
   * Cancel Change: hide the picker and send no new volume directory, so the picker's preselected
   * root never reaches a Save; the form reads dirty only if another field still differs.
   */
  keepVolumeDirectory(): void {
    if (!this.changingVolume) return;
    this.changingVolume = false;
    this.volumeRootValue = '';
    this.volumePathValue = '';
    this.clearFieldViolation(VOLUME_ROOT_FIELD);
    this.clearFieldViolation(VOLUME_PATH_FIELD);
    this.formDirty.setDirty(Object.keys(this.saveBody()).length > 0);
    this.notify();
  }

  /** The picker's root and relative path for a new volume directory. */
  setVolumeLocation(root: string, path: string): void {
    if (!this.changingVolume || (root === this.volumeRootValue && path === this.volumePathValue)) return;
    if (root !== this.volumeRootValue) this.clearFieldViolation(VOLUME_ROOT_FIELD);
    this.volumeRootValue = root;
    this.volumePathValue = path;
    this.change(VOLUME_PATH_FIELD);
  }

  /**
   * Save: put the changed groups -- the mounting group first, then the file's -- each carrying only
   * its changed fields. An accepted Save publishes one `database-configuration` `updated` change
   * event (AD-14) and re-reads the editor and its volume files; a refused one keeps what was entered,
   * and a group the instance says it applied before the refusal is no longer sent.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const body = this.saveBody();
    if (Object.keys(body).length === 0) {
      this.clearRefusal();
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.continuesValue = false;
    this.readBackValue = null;
    this.notify();
    const result = await this.api().requestJson<unknown>(`${DATABASE_PATH}/${encodeEntityId(this.nameValue)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.absorbApplied(result);
      this.notify();
      return false;
    }
    const answer = result.body;
    // Every group written: the one that does not hold what it sent is the one to show (AD-58).
    const readBacks = [SIZE_GROUP, FILE_GROUP, CONFIGURATION_GROUP].map((group) => readBackOf(objectAt(objectAt(answer, group), 'readBack')));
    this.readBackValue = readBacks.find((back) => back !== null && back.verdict !== 'matches') ?? readBacks.find((back) => back !== null) ?? null;
    this.continuesValue = answer !== null && typeof answer === 'object' && (answer as Record<string, unknown>)['continues'] === true;
    this.savedValue = true;
    this.formDirty.setDirty(false);
    this.publish('updated');
    this.notify();
    await this.open(this.nameValue, true);
    return true;
  }

  /** Re-issue the Volume files group's read. */
  async loadVolumes(): Promise<void> {
    const screen = screenForRoute(DATABASE_VOLUMES_ROUTE);
    const directory = this.directoryValue;
    if (screen === null || screen.read === null || directory === '') return;
    const ask = ++this.volumeAsk;
    const read = createScreenRead(this.api(), screen, () => ({ dir: directory }));
    const result = await read({ maxRows: DATABASE_VOLUMES_MAX_ROWS });
    if (ask !== this.volumeAsk) return;
    this.volumesLoadedValue = true;
    if (result.kind !== 'ok') {
      this.volumesFaultValue = true;
      this.volumeRowsValue = [];
    } else {
      this.volumesFaultValue = false;
      this.volumeRowsValue = result.rows.filter(
        (row): row is VolumeRow => row !== null && typeof row === 'object' && !Array.isArray(row)
      );
    }
    this.notify();
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  /** The body of a Save: the changed groups only, each with its changed fields only (AD-4, the server merges). */
  private saveBody(): Record<string, Record<string, unknown>> {
    const body: Record<string, Record<string, unknown>> = {};
    const configuration = this.changedConfiguration();
    if (Object.keys(configuration).length > 0) body[CONFIGURATION_GROUP] = configuration;
    const file = this.changedFile();
    if (Object.keys(file).length > 0) body[FILE_GROUP] = file;
    if (this.sizeValue !== null && this.sizeValue !== this.openedSize) body[SIZE_GROUP] = { [SIZE_FIELD]: numberValue(this.sizeValue) };
    return body;
  }

  private changedConfiguration(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of CONFIGURATION_FLAGS) {
      if (this.flag(field) !== (this.openedFlags[field] ?? false)) out[field] = this.flag(field);
    }
    return out;
  }

  private changedFile(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of FILE_TEXT_FIELDS) {
      if (this.text(field) === (this.openedText[field] ?? '')) continue;
      out[field] = FILE_NUMBER_FIELDS.includes(field) ? numberValue(this.text(field)) : this.text(field);
    }
    for (const field of FILE_FLAGS) {
      if (this.flag(field) !== (this.openedFlags[field] ?? false)) out[field] = this.flag(field);
    }
    if (this.changingVolume && this.volumeRootValue !== '') {
      out[VOLUME_ROOT_FIELD] = this.volumeRootValue;
      out[VOLUME_PATH_FIELD] = this.volumePathValue;
    }
    return out;
  }

  private absorb(body: unknown, name: string): void {
    this.resourcesValue = stringsAt(body, 'resources');
    this.resourcesRefusedValue = textAt(body, 'resourcesRefused');
    const configuration = objectAt(body, CONFIGURATION_GROUP);
    const file = objectAt(body, FILE_GROUP);
    if (configuration === null || file === null) {
      this.absentValue = true;
      return;
    }
    this.nameValue = textAt(body, 'Name') || name.toUpperCase();
    this.directoryValue = textAt(file, 'Directory') || textAt(configuration, 'Directory');
    this.newVolumeDirectoryValue = textAt(file, 'NewVolumeDirectory');
    const text: Record<string, string> = {};
    for (const field of FILE_TEXT_FIELDS) text[field] = textAt(file, field);
    const flags: Record<string, boolean> = {};
    for (const field of FILE_FLAGS) flags[field] = flagOf(file[field]);
    for (const field of CONFIGURATION_FLAGS) flags[field] = flagOf(configuration[field]);
    this.textValues = text;
    this.flagValues = flags;
    this.openedText = text;
    this.openedFlags = flags;
    const size = objectAt(body, SIZE_GROUP);
    this.sizeValue = size === null ? null : textAt(size, SIZE_FIELD);
    this.openedSize = this.sizeValue;
    this.heldValue = true;
  }

  /**
   * A refused Save whose earlier groups the instance had already written (`detail.applied`): those
   * groups' fields become the opened snapshot, so the next Save does not send them again, and the
   * change they made is published (AD-14). The file group can precede a refused size grow (Story
   * 18.4).
   */
  private absorbApplied(result: JsonResult<unknown>): void {
    if (result.kind !== 'error' || result.detail === null) return;
    const applied = result.detail['applied'];
    if (!Array.isArray(applied) || applied.length === 0) return;
    const flags: Record<string, boolean> = { ...this.openedFlags };
    if (applied.includes(CONFIGURATION_GROUP)) {
      for (const field of CONFIGURATION_FLAGS) flags[field] = this.flag(field);
    }
    if (applied.includes(FILE_GROUP)) {
      for (const field of FILE_FLAGS) flags[field] = this.flag(field);
      const text: Record<string, string> = { ...this.openedText };
      for (const field of FILE_TEXT_FIELDS) text[field] = this.text(field);
      this.openedText = text;
    }
    this.openedFlags = flags;
    if (applied.includes(CONFIGURATION_GROUP) || applied.includes(FILE_GROUP)) this.publish('updated');
  }

  private change(field: string): void {
    this.clearFieldViolation(field);
    this.savedValue = false;
    this.formDirty.setDirty(true);
    this.notify();
  }

  private clearFieldViolation(field: string): void {
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
  }

  private rememberRefusal(result: JsonResult<unknown>): void {
    if (result.kind !== 'error') {
      this.clearRefusal();
      return;
    }
    this.refusalCodeValue = result.code ?? '';
    const pair = result.detail === null ? undefined : result.detail['failedPair'];
    this.refusalPairValue = typeof pair === 'string' ? pair : '';
  }

  private clearRefusal(): void {
    this.envelopeReason = '';
    this.refusalCodeValue = '';
    this.refusalPairValue = '';
  }

  private publish(action: ChangeAction): void {
    if (this.nameValue === '') return;
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: DATABASE_CONFIGURATION_ENTITY,
      scope: DATABASE_SCOPE,
      id: this.nameValue,
      action,
      readBack: this.readBackValue,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
