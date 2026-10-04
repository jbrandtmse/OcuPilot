import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import type { TreeObject, TreeSchema } from './data-browser.store';

/** One visible node of the tree, in the order Up and Down walk them. */
interface TreeRow {
  readonly id: string;
  readonly level: 1 | 2;
  /** A schema, a table or view, or a line under a schema that opens nothing. */
  readonly kind: 'schema' | 'object' | 'line';
  readonly schema: string;
  readonly object: TreeObject | null;
  readonly parentId: string;
}

/** A schema node as drawn, with its children. */
interface SchemaView {
  readonly id: string;
  readonly name: string;
  readonly expanded: boolean;
  /** The decorative marker of an expanded or a collapsed schema. */
  readonly chevron: string;
  readonly loading: boolean;
  readonly posinset: number;
  readonly children: readonly ChildView[];
}

/** A child of a schema as drawn: a table or view, or a line. */
interface ChildView {
  readonly id: string;
  readonly object: TreeObject | null;
  readonly label: string;
  readonly view: boolean;
  readonly current: boolean;
  readonly posinset: number;
  readonly setsize: number;
}

/** Whether `a` and `b` name the same table or view. */
function same(a: TreeObject | null, b: TreeObject | null): boolean {
  return a !== null && b !== null && a.schema === b.schema && a.name === b.name && a.view === b.view;
}

/**
 * Data browser's schema tree (Story 19.7): an APG tree with one Tab stop, focus held on the tree and
 * `aria-activedescendant` naming the active node. Each schema holding a table or a view is a node;
 * expanded, its tables then its views, each view marked "View", with a line for a schema with nothing
 * to show and one for a read cut at its cap.
 *
 * Keys: Up and Down move; Home and End go to the first and last node; Right expands a schema or
 * moves to its first child; Left collapses it or moves to the parent; Enter and Space open a table or
 * a view, and toggle a schema. A click does the same. The tree emits intents; the page's state holds
 * what was read (AD-19).
 *
 * The keyboard model follows iris-table-editor v0.2.3's schema tree
 * (`packages/webview/src/main.js:329-382,773-869`, MIT, `ui/licenses/iris-table-editor.txt`),
 * re-expressed as the APG tree with one Tab stop.
 */
@Component({
  selector: 'app-data-browser-tree',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<ul
    class="ocu-data-browser-tree"
    role="tree"
    tabindex="0"
    data-ocu-data="tree"
    [attr.aria-label]="STRINGS.explorerSqlDataTree"
    [attr.aria-activedescendant]="activeDescendant()"
    [attr.aria-busy]="busy()"
    (keydown)="onKeydown($event)"
    (focus)="onFocus()"
  >
    @for (schema of schemaList; track schema.id) {
      <li
        class="ocu-data-browser-tree-item"
        role="treeitem"
        aria-level="1"
        [id]="schema.id"
        [attr.aria-expanded]="schema.expanded"
        [attr.aria-setsize]="schemaList.length"
        [attr.aria-posinset]="schema.posinset"
        [class.ocu-data-browser-tree-active]="schema.id === activeId()"
      >
        <span class="ocu-data-browser-tree-label" data-ocu-data="tree-schema" (click)="onSchemaClick(schema.id, schema.name)">
          <span class="ocu-data-browser-tree-chevron" aria-hidden="true">{{ schema.chevron }}</span>
          <span class="ocu-data-browser-tree-name">{{ schema.name }}</span>
        </span>
        @if (schema.expanded) {
          <ul class="ocu-data-browser-tree-group" role="group" [attr.aria-busy]="schema.loading">
            @for (child of schema.children; track child.id) {
              <li
                class="ocu-data-browser-tree-item ocu-data-browser-tree-child"
                role="treeitem"
                aria-level="2"
                [id]="child.id"
                [attr.aria-setsize]="child.setsize"
                [attr.aria-posinset]="child.posinset"
                [attr.aria-disabled]="child.object === null ? true : null"
                [attr.aria-current]="child.current ? true : null"
                [class.ocu-data-browser-tree-active]="child.id === activeId()"
                [class.ocu-data-browser-tree-current]="child.current"
              >
                @if (child.object; as object) {
                  <span class="ocu-data-browser-tree-label" data-ocu-data="tree-object" (click)="onObjectClick(child.id, object)">
                    <span class="ocu-data-browser-tree-name">{{ child.label }}</span>
                    @if (child.view) {
                      <span class="ocu-data-browser-tree-view">{{ STRINGS.viewMenuLabel }}</span>
                    }
                  </span>
                } @else {
                  <span class="ocu-data-browser-tree-line" data-ocu-data="tree-line">{{ child.label }}</span>
                }
              </li>
            }
          </ul>
        }
      </li>
    }
  </ul>`,
})
export class DataBrowserTree {
  protected readonly STRINGS = STRINGS;

  /** The schemas read, or `null` before. */
  readonly schemas = input<readonly TreeSchema[] | null>(null);

  /** The table or view open in the grid, marked current. */
  readonly current = input<TreeObject | null>(null);

  readonly busy = input(false);

  /** A schema to expand or collapse. */
  readonly toggled = output<string>();

  /** A table or view to open. */
  readonly opened = output<TreeObject>();

  /** The active node's id, or `''`; the first node when the tree takes focus with none. */
  protected readonly activeId = signal('');

  protected readonly schemaViews = computed<readonly SchemaView[]>(() => {
    const schemas = this.schemas() ?? [];
    const current = this.current();
    return schemas.map((schema, index) => {
      const id = `ocu-data-tree-s${index}`;
      const children: ChildView[] = [];
      const objects = schema.objects ?? [];
      objects.forEach((object, at) => {
        children.push({ id: `${id}-o${at}`, object, label: object.name, view: object.view, current: same(object, current), posinset: 0, setsize: 0 });
      });
      if (schema.objects !== null && objects.length === 0 && schema.fault === '') {
        children.push({ id: `${id}-empty`, object: null, label: STRINGS.explorerSqlDataSchemaEmpty, view: false, current: false, posinset: 0, setsize: 0 });
      }
      if (schema.truncated) {
        children.push({ id: `${id}-cut`, object: null, label: STRINGS.explorerSqlDataTreeCut, view: false, current: false, posinset: 0, setsize: 0 });
      }
      if (schema.fault !== '') {
        children.push({ id: `${id}-fault`, object: null, label: schema.fault, view: false, current: false, posinset: 0, setsize: 0 });
      }
      const numbered = children.map((child, at) => ({ ...child, posinset: at + 1, setsize: children.length }));
      return {
        id,
        name: schema.name,
        expanded: schema.expanded,
        chevron: schema.expanded ? '\u25be' : '\u25b8',
        loading: schema.loading,
        posinset: index + 1,
        children: numbered,
      };
    });
  });

  /** The schemas the template walks, as a paren-free member (see `sign-in.ts`). */
  protected get schemaList(): readonly SchemaView[] {
    return this.schemaViews();
  }

  /** The visible nodes in walking order. */
  private readonly rows = computed<readonly TreeRow[]>(() => {
    const rows: TreeRow[] = [];
    for (const schema of this.schemaViews()) {
      rows.push({ id: schema.id, level: 1, kind: 'schema', schema: schema.name, object: null, parentId: '' });
      if (!schema.expanded) continue;
      for (const child of schema.children) {
        rows.push({ id: child.id, level: 2, kind: child.object === null ? 'line' : 'object', schema: schema.name, object: child.object, parentId: schema.id });
      }
    }
    return rows;
  });

  protected readonly activeDescendant = computed(() => {
    const id = this.activeId();
    return this.rows().some((row) => row.id === id) ? id : null;
  });

  protected onFocus(): void {
    if (this.activeDescendant() !== null) return;
    const rows = this.rows();
    if (rows.length > 0) this.activeId.set(rows[0].id);
  }

  protected onSchemaClick(id: string, name: string): void {
    this.activeId.set(id);
    this.toggled.emit(name);
  }

  protected onObjectClick(id: string, object: TreeObject): void {
    this.activeId.set(id);
    this.opened.emit(object);
  }

  protected onKeydown(event: KeyboardEvent): void {
    const rows = this.rows();
    if (rows.length === 0) return;
    let index = rows.findIndex((row) => row.id === this.activeId());
    const handled = ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Home', 'End', 'Enter', ' '].includes(event.key);
    if (!handled) return;
    event.preventDefault();
    if (index < 0) {
      this.activeId.set(rows[0].id);
      return;
    }
    const row = rows[index];
    switch (event.key) {
      case 'ArrowUp':
        index = Math.max(0, index - 1);
        break;
      case 'ArrowDown':
        index = Math.min(rows.length - 1, index + 1);
        break;
      case 'Home':
        index = 0;
        break;
      case 'End':
        index = rows.length - 1;
        break;
      case 'ArrowRight':
        if (row.kind === 'schema') {
          const schema = this.schemaViews().find((view) => view.id === row.id);
          if (schema !== undefined && !schema.expanded) {
            this.toggled.emit(row.schema);
            return;
          }
          if (index + 1 < rows.length && rows[index + 1].parentId === row.id) index += 1;
        }
        break;
      case 'ArrowLeft':
        if (row.kind === 'schema') {
          const schema = this.schemaViews().find((view) => view.id === row.id);
          if (schema !== undefined && schema.expanded) this.toggled.emit(row.schema);
          return;
        }
        index = rows.findIndex((candidate) => candidate.id === row.parentId);
        break;
      case 'Enter':
      case ' ':
        if (row.kind === 'schema') this.toggled.emit(row.schema);
        else if (row.object !== null) this.opened.emit(row.object);
        return;
    }
    if (index >= 0) {
      this.activeId.set(rows[index].id);
      document.getElementById(rows[index].id)?.scrollIntoView?.({ block: 'nearest' });
    }
  }
}
