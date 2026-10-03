import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { screenForRoute } from '../../core/navigation';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { createScreenRead } from '../../core/screen-read';
import { ENTITY_SINGLETON_ID } from '../../core/screens.generated';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The screen this store serves (Story 18.18). */
export const JOURNAL_SETTINGS_ROUTE = 'os-management/journal-settings';

/** The Save's route (AD-20, AD-55). */
export const JOURNAL_SETTINGS_PATH = '/api/ocupilot/journal/settings';

/** The change event's triple (AD-13, AD-14): the instance's one set of journal settings. */
export const JOURNAL_SETTINGS_ENTITY = 'journal-settings';
export const JOURNAL_SETTINGS_SCOPE = 'instance';

/** The declared read answers one object, so one row is the whole answer. */
export const JOURNAL_SETTINGS_MAX_ROWS = 1;

/** The two directories, each set by a root and a relative name (AD-21's sixth case). */
export type JournalDirectory = 'primary' | 'alternate';
export const JOURNAL_DIRECTORIES: readonly JournalDirectory[] = ['primary', 'alternate'];

/** The vendor's key each directory is read under. */
export const DIRECTORY_FIELD: Readonly<Record<JournalDirectory, string>> = { primary: 'CurrentDirectory', alternate: 'AlternateDirectory' };

/** The argument a directory's root travels under. */
export function rootField(which: JournalDirectory): string {
  return `${which}Root`;
}

/** The argument a directory's relative name travels under. */
export function pathField(which: JournalDirectory): string {
  return `${which}Path`;
}

/** The settable text fields, as `Journal.Settings` names them. */
export const TEXT_FIELDS: readonly string[] = ['FileSizeLimit', 'JournalFilePrefix', 'DaysBeforePurge', 'BackupsBeforePurge'];

/** The text fields sent as numbers when they read as a whole number. */
export const NUMBER_FIELDS: readonly string[] = ['FileSizeLimit', 'DaysBeforePurge', 'BackupsBeforePurge'];

/** The settable flags. */
export const FLAG_FIELDS: readonly string[] = ['PurgeArchived', 'FreezeOnError', 'JournalcspSession', 'CompressFiles'];

/** The purge rule's fields (the classic page's own rule, which the server applies to every body). */
export const PURGE_ARCHIVED_FIELD = 'PurgeArchived';
export const PURGE_COUNT_FIELDS: readonly string[] = ['DaysBeforePurge', 'BackupsBeforePurge'];

/** The fields shown and never sent (AD-4's named exception). */
export const ARCHIVE_FIELD = 'ArchiveName';
export const WIJ_DIRECTORY_FIELD = 'wijdir';
export const WIJ_SIZE_FIELD = 'targwijsz';

export const FREEZE_FIELD = 'FreezeOnError';

function textOf(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function flagOf(value: unknown): boolean {
  return value === true || value === 1 || value === '1' || value === 'true';
}

/** A whole number as a JSON number, anything else as the text typed, so the server's rule answers it. */
function numberValue(text: string): number | string {
  return /^[0-9]{1,9}$/.test(text) ? Number(text) : text;
}

/**
 * Journal settings' store (Story 18.18, AD-19, AD-55): the instance's journal settings, read through
 * the screen's own declared read, so the form and `osmgmt.journalsettings.read` answer one read
 * (AD-36).
 *
 * **It composes no payload of its own.** `PUT /journal/settings` carries only the changed fields, and
 * a directory's root and relative name only while that directory is being changed; the server merges
 * them over its own fresh read and sends the settable set (AD-4), through the tool the agent's
 * `osmgmt.journalsettings.update` resolves. Every sentence is the server's (AD-39).
 *
 * **The purge rule is drawn, and the server applies it**: Purge archived is unchecked while no
 * archive target is set, and the two counts take no input while it is checked.
 */
@Injectable({ providedIn: 'root' })
export class JournalSettingsForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private shownValues: Readonly<Record<string, string>> = {};

  private directoryValues: Readonly<Record<string, string>> = {};

  private textValues: Readonly<Record<string, string>> = {};

  private flagValues: Readonly<Record<string, boolean>> = {};

  private openedText: Readonly<Record<string, string>> = {};

  private openedFlags: Readonly<Record<string, boolean>> = {};

  private changingValues: Readonly<Record<string, boolean>> = {};

  private rootValues: Readonly<Record<string, string>> = {};

  private pathValues: Readonly<Record<string, string>> = {};

  private loadedValue = false;

  private heldValue = false;

  private faultValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private savedValue = false;

  private readBackValue: ReadBack | null = null;

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

  /** Whether the fields take input: only once the read is held. */
  editable(): boolean {
    return this.heldValue;
  }

  /** Whether the read was refused or failed, which offers Retry. */
  fault(): boolean {
    return this.faultValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  canSave(): boolean {
    return this.heldValue && !this.savingValue;
  }

  /** A field the read answered, as text: a directory, a shown-only field. */
  shown(field: string): string {
    return this.shownValues[field] ?? '';
  }

  /** The directory `which` names now. */
  directory(which: JournalDirectory): string {
    return this.directoryValues[which] ?? '';
  }

  text(field: string): string {
    return this.textValues[field] ?? '';
  }

  flag(field: string): boolean {
    return this.flagValues[field] ?? false;
  }

  /** Whether an archive target is set, which is the only state Purge archived may be checked in. */
  archived(): boolean {
    return this.shown(ARCHIVE_FIELD) !== '';
  }

  /** Whether Purge archived takes input. */
  purgeArchivedEditable(): boolean {
    return this.heldValue && this.archived();
  }

  /** Whether the two purge counts take input: not while Purge archived is checked. */
  purgeCountsEditable(): boolean {
    return this.heldValue && !this.flag(PURGE_ARCHIVED_FIELD);
  }

  /** Whether Change has revealed directory `which`'s picker. */
  changing(which: JournalDirectory): boolean {
    return this.changingValues[which] ?? false;
  }

  root(which: JournalDirectory): string {
    return this.rootValues[which] ?? '';
  }

  path(which: JournalDirectory): string {
    return this.pathValues[which] ?? '';
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

  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the page is left. */
  reset(): void {
    this.generation += 1;
    this.shownValues = {};
    this.directoryValues = {};
    this.textValues = {};
    this.flagValues = {};
    this.openedText = {};
    this.openedFlags = {};
    this.changingValues = {};
    this.rootValues = {};
    this.pathValues = {};
    this.loadedValue = false;
    this.heldValue = false;
    this.faultValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.readBackValue = null;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form over the screen's declared read. `keepSaved` carries the last accepted Save's
   * confirmation across the re-read that follows it.
   */
  async open(keepSaved = false): Promise<void> {
    const saved = keepSaved && this.savedValue;
    const readBack = this.readBackValue;
    this.reset();
    if (saved) {
      this.savedValue = true;
      this.readBackValue = readBack;
    }
    const screen = screenForRoute(JOURNAL_SETTINGS_ROUTE);
    if (screen === null || screen.read === null) return;
    const generation = this.generation;
    const result = await createScreenRead(this.api(), screen)({ maxRows: JOURNAL_SETTINGS_MAX_ROWS });
    if (generation !== this.generation) return;
    this.loadedValue = true;
    const row = result.kind === 'ok' ? result.rows[0] : undefined;
    if (row === null || row === undefined || typeof row !== 'object' || Array.isArray(row)) {
      this.faultValue = true;
      this.notify();
      return;
    }
    this.absorb(row as Record<string, unknown>);
    this.notify();
  }

  setText(field: string, value: string): void {
    if (!this.heldValue || !TEXT_FIELDS.includes(field) || this.text(field) === value) return;
    if (PURGE_COUNT_FIELDS.includes(field) && !this.purgeCountsEditable()) return;
    this.textValues = { ...this.textValues, [field]: value };
    this.change(field);
  }

  setFlag(field: string, value: boolean): void {
    if (!this.heldValue || !FLAG_FIELDS.includes(field) || this.flag(field) === value) return;
    if (field === PURGE_ARCHIVED_FIELD && !this.purgeArchivedEditable()) return;
    this.flagValues = { ...this.flagValues, [field]: value };
    this.change(field);
  }

  /** Change: reveal directory `which`'s picker. */
  changeDirectory(which: JournalDirectory): void {
    if (!this.heldValue || this.changing(which)) return;
    this.changingValues = { ...this.changingValues, [which]: true };
    this.notify();
  }

  /**
   * Cancel Change: hide the picker and send nothing for directory `which`; the form reads dirty only
   * if another field still differs.
   */
  keepDirectory(which: JournalDirectory): void {
    if (!this.changing(which)) return;
    this.changingValues = { ...this.changingValues, [which]: false };
    this.rootValues = { ...this.rootValues, [which]: '' };
    this.pathValues = { ...this.pathValues, [which]: '' };
    this.clearFieldViolation(rootField(which));
    this.clearFieldViolation(pathField(which));
    this.formDirty.setDirty(Object.keys(this.saveBody()).length > 0);
    this.notify();
  }

  /**
   * The picker's root and relative name for directory `which`. A `preselected` report is the
   * picker's own choice of its single root, held without marking the form changed.
   */
  setDirectoryLocation(which: JournalDirectory, root: string, path: string, preselected = false): void {
    if (!this.changing(which) || (root === this.root(which) && path === this.path(which))) return;
    if (root !== this.root(which)) this.clearFieldViolation(rootField(which));
    this.rootValues = { ...this.rootValues, [which]: root };
    this.pathValues = { ...this.pathValues, [which]: path };
    if (preselected) {
      this.notify();
      return;
    }
    this.change(pathField(which));
  }

  /**
   * Save: put the changed fields, and each directory being changed as its root and relative name. An
   * accepted Save publishes one `journal-settings` `updated` change event (AD-14) and re-reads the
   * form; a refused one keeps what was entered.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const body = this.saveBody();
    if (Object.keys(body).length === 0) {
      this.clearRefusal();
      this.readBackValue = null;
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.readBackValue = null;
    this.notify();
    const result = await this.api().requestJson<unknown>(JOURNAL_SETTINGS_PATH, {
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
      this.notify();
      return false;
    }
    const answer = result.body;
    this.readBackValue =
      answer !== null && typeof answer === 'object' ? readBackOf((answer as Record<string, unknown>)['readBack']) : null;
    this.savedValue = true;
    this.formDirty.setDirty(false);
    this.publish();
    this.notify();
    await this.open(true);
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  /**
   * The body of a Save: the changed fields only, and a directory's two arguments only while it is
   * changed and names something, a name with no root chosen included so the Save refuses it on the root.
   */
  private saveBody(): Record<string, unknown> {
    const body: Record<string, unknown> = {};
    for (const field of TEXT_FIELDS) {
      if (this.text(field) === (this.openedText[field] ?? '')) continue;
      body[field] = NUMBER_FIELDS.includes(field) ? numberValue(this.text(field)) : this.text(field);
    }
    for (const field of FLAG_FIELDS) {
      if (this.flag(field) !== (this.openedFlags[field] ?? false)) body[field] = this.flag(field);
    }
    for (const which of JOURNAL_DIRECTORIES) {
      if (!this.changing(which) || (this.root(which) === '' && this.path(which) === '')) continue;
      body[rootField(which)] = this.root(which);
      body[pathField(which)] = this.path(which);
    }
    return body;
  }

  private absorb(row: Record<string, unknown>): void {
    const shown: Record<string, string> = {};
    for (const field of [ARCHIVE_FIELD, WIJ_DIRECTORY_FIELD, WIJ_SIZE_FIELD]) shown[field] = textOf(row[field]);
    this.shownValues = shown;
    const directories: Record<string, string> = {};
    for (const which of JOURNAL_DIRECTORIES) directories[which] = textOf(row[DIRECTORY_FIELD[which]]);
    this.directoryValues = directories;
    const text: Record<string, string> = {};
    for (const field of TEXT_FIELDS) text[field] = textOf(row[field]);
    const flags: Record<string, boolean> = {};
    for (const field of FLAG_FIELDS) flags[field] = flagOf(row[field]);
    // The purge rule's first half as the form draws it: with no archive target, unchecked.
    if (shown[ARCHIVE_FIELD] === '') flags[PURGE_ARCHIVED_FIELD] = false;
    this.textValues = text;
    this.flagValues = flags;
    this.openedText = text;
    this.openedFlags = flags;
    this.heldValue = true;
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

  private publish(): void {
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: JOURNAL_SETTINGS_ENTITY,
      scope: JOURNAL_SETTINGS_SCOPE,
      id: ENTITY_SINGLETON_ID,
      action: 'updated',
      readBack: this.readBackValue,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
