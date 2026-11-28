import { ChangeDetectionStrategy, Component } from '@angular/core';

import { DetailPage } from '../../shell/detail-page';
import {
  EXPLORER_SQL_TABLE,
  SQL_TABLE_CLEAR_STATISTICS,
  SQL_TABLE_REBUILD_INDICES,
  SQL_TABLE_SET_EXTENT_SIZE,
  SQL_TABLE_TUNE,
} from '../../shell/screen-action-handler';
import { registerRouteTargetActions } from './route-target-actions';

/**
 * A SQL table's Table info tab (Story 21.25, AD-5): the shared detail page, with Rebuild all indices, Collect statistics, Clear fixed statistics and
 * Set extent size (Story 21.31) registered on it, each on the table the route names (`registerRouteTargetActions`).
 */
@Component({
  selector: 'app-sql-table-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DetailPage],
  // The height chain every page host carries, so the tab's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<app-detail-page />`,
})
export class SqlTablePage {
  constructor() {
    registerRouteTargetActions(EXPLORER_SQL_TABLE, 'table', [SQL_TABLE_REBUILD_INDICES, SQL_TABLE_TUNE, SQL_TABLE_CLEAR_STATISTICS, SQL_TABLE_SET_EXTENT_SIZE]);
  }
}
