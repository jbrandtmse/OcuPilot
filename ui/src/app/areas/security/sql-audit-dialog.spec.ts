import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { SqlAuditDialog, sqlAuditChanges, sqlAuditEventName, sqlAuditGrid, type SqlAuditChange } from './sql-audit-dialog';

/**
 * The Selective SQL auditing dialog (Story 7.11): the twelve granular SQL system events as a 4x3
 * grid, each box starting as the System events list reads it, and Apply emitting only the boxes
 * that changed.
 */

const SOURCES = ['Dynamic', 'Embedded', 'XDBC'];
const KINDS = ['Query', 'DDL', 'DML', 'Utility'];

/** All twelve events, every one enabled except XDBC Utility. */
const ALL = KINDS.flatMap((kind) =>
  SOURCES.map((source) => ({
    EventName: sqlAuditEventName(source, kind),
    Enabled: !(source === 'XDBC' && kind === 'Utility'),
    Total: 0,
    Written: 0,
    Lost: 0,
  }))
);

@Component({
  imports: [SqlAuditDialog],
  template: `<app-sql-audit-dialog [rows]="rows()" (applied)="applied.push($event)" (cancelled)="cancelled = cancelled + 1" />`,
})
class Host {
  readonly rows = signal<readonly unknown[]>(ALL);
  readonly applied: (readonly SqlAuditChange[])[] = [];
  cancelled = 0;
}

const planted: HTMLElement[] = [];

async function mount(rows: readonly unknown[] = ALL): Promise<{ fixture: ComponentFixture<Host>; host: HTMLElement }> {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.rows.set(rows);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await fixture.whenStable();
  return { fixture, host: fixture.nativeElement as HTMLElement };
}

const boxes = (host: HTMLElement) => Array.from(host.querySelectorAll('input[type="checkbox"]')) as HTMLInputElement[];

describe('the Selective SQL auditing dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('draws a 4x3 grid, kinds down and sources across, each box named "<source> <kind>" and set as the list reads it', async () => {
    const { host } = await mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.auditSqlWizardAction);
    expect(host.querySelector('.ocu-sql-audit-prompt')?.textContent?.trim()).toBe(STRINGS.auditSqlWizardPrompt);
    expect(Array.from(host.querySelectorAll('th[scope="col"]')).map((th) => th.textContent?.trim())).toEqual([
      '',
      STRINGS.auditSqlSourceDynamic,
      STRINGS.auditSqlSourceEmbedded,
      STRINGS.auditSqlSourceXdbc,
    ]);
    expect(Array.from(host.querySelectorAll('th[scope="row"]')).map((th) => th.textContent?.trim())).toEqual([
      STRINGS.auditSqlKindQuery,
      STRINGS.auditSqlKindDdl,
      STRINGS.auditSqlKindDml,
      STRINGS.auditSqlKindUtility,
    ]);
    const drawn = boxes(host);
    expect(drawn).toHaveLength(12);
    expect(drawn[0].getAttribute('aria-label')).toBe(`${STRINGS.auditSqlSourceDynamic} ${STRINGS.auditSqlKindQuery}`);
    expect(drawn[11].getAttribute('aria-label')).toBe(`${STRINGS.auditSqlSourceXdbc} ${STRINGS.auditSqlKindUtility}`);
    expect(drawn.map((box) => box.checked)).toEqual(ALL.map((row) => row.Enabled));
    const apply = host.querySelector('.ocu-dialog-actions .ocu-button-primary') as HTMLButtonElement;
    expect(apply.textContent?.trim()).toBe(STRINGS.actionApply);
  });

  it('Apply emits exactly the changed boxes, and nothing for an unchanged one', async () => {
    // Mutation (Rule 19): emit every drawn box from `sqlAuditChanges` -> both expectations go red.
    const { fixture, host } = await mount();
    const drawn = boxes(host);
    drawn[0].click(); // Dynamic Query: on -> off
    drawn[11].click(); // XDBC Utility: off -> on
    drawn[5].click(); // Embedded DDL: on -> off ...
    drawn[5].click(); // ... and back, so unchanged
    (host.querySelector('.ocu-dialog-actions .ocu-button-primary') as HTMLButtonElement).click();
    expect(fixture.componentInstance.applied).toEqual([
      [
        { id: sqlAuditEventName('Dynamic', 'Query'), action: 'disable' },
        { id: sqlAuditEventName('XDBC', 'Utility'), action: 'enable' },
      ],
    ]);
  });

  it('Apply with nothing changed emits an empty list', async () => {
    const { fixture, host } = await mount();
    (host.querySelector('.ocu-dialog-actions .ocu-button-primary') as HTMLButtonElement).click();
    expect(fixture.componentInstance.applied).toEqual([[]]);
  });

  it('Cancel and Escape emit cancelled and apply nothing', async () => {
    const { fixture, host } = await mount();
    boxes(host)[0].click();
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    expect(fixture.componentInstance.cancelled).toBe(1);
    expect(fixture.componentInstance.applied).toEqual([]);

    const escaped = await mount();
    boxes(escaped.host)[0].click();
    expect(TestBed.inject(OverlayStack).closeTop()).toBe(true);
    expect(escaped.fixture.componentInstance.cancelled).toBe(1);
    expect(escaped.fixture.componentInstance.applied).toEqual([]);
  });

  it('draws no box for an event the list does not report', async () => {
    const { host } = await mount(ALL.filter((row) => row.EventName !== sqlAuditEventName('Embedded', 'DML')));
    expect(boxes(host)).toHaveLength(11);
    expect(host.querySelector(`input[data-event="${sqlAuditEventName('Embedded', 'DML')}"]`)).toBeNull();
  });
});

describe('the grid and change rules', () => {
  it('matches an event without case and keeps the row\u2019s own spelling as the id', () => {
    const grid = sqlAuditGrid([{ EventName: '%system/%sql/dynamicstatementquery', Enabled: false }]);
    expect(grid).toHaveLength(4);
    expect(grid[0][0]).toEqual({ id: '%system/%sql/dynamicstatementquery', name: `${STRINGS.auditSqlSourceDynamic} ${STRINGS.auditSqlKindQuery}`, enabled: false });
    expect(grid[0][1]).toBeNull();
  });

  it('answers no change for a box set back to its read state', () => {
    const grid = sqlAuditGrid(ALL);
    const id = sqlAuditEventName('Embedded', 'DML');
    expect(sqlAuditChanges(grid, new Map([[id, true]]))).toEqual([]);
    expect(sqlAuditChanges(grid, new Map([[id, false]]))).toEqual([{ id, action: 'disable' }]);
  });
});
