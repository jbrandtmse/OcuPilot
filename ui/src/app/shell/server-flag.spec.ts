import { ComponentFixture, TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';

import { STRINGS } from '../core/strings';
import { ServerFlag } from './server-flag';

/**
 * The server-flag badge's `unbounded` input and the host attribute the style sheet keys off
 * (DW-163): Home's instance line sets it, the status bar does not.
 */
describe('the server-flag badge', () => {
  let fixture: ComponentFixture<ServerFlag>;

  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [ServerFlag] });
    fixture = TestBed.createComponent(ServerFlag);
    fixture.componentRef.setInput('value', 'LIVE');
  });

  const host = (): HTMLElement => fixture.nativeElement as HTMLElement;

  // Mutation (Rule 19): drop the `[attr.data-unbounded]` host binding -> this goes red.
  it('data-unbounded is present exactly when [unbounded] is true, in both directions', () => {
    fixture.detectChanges();
    expect(host().hasAttribute('data-unbounded')).toBe(false);
    expect(host().querySelector('.ocu-server-flag')?.textContent?.trim()).toBe(STRINGS.serverFlagLive);

    fixture.componentRef.setInput('unbounded', true);
    fixture.detectChanges();
    expect(host().hasAttribute('data-unbounded')).toBe(true);
    expect(host().getAttribute('data-unbounded')).toBe('');

    fixture.componentRef.setInput('unbounded', false);
    fixture.detectChanges();
    expect(host().hasAttribute('data-unbounded')).toBe(false);
  });
});
