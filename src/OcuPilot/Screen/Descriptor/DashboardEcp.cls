/// <p>ECP statistics: this instance's counters as an ECP application server and as an ECP data server,
/// read as one row of sixteen and seventeen fields from the vendor's <code>Monitor</code>
/// <code>DASHBOARDECP</code> answer, as <code>Ecp</code> (<code>source.parts</code>, AD-36). An unlisted
/// drill-down of the Dashboard's ECP group (Story 18.36).</p>
/// <p>It administers nothing: <code>entityType</code> is <code>""</code>, its <code>id</code> is
/// <code>none</code>, it declares no action, it does not refresh (AD-43) and it takes no criterion.</p>
/// <p>Its pairs are the Dashboard's, <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>
/// (AD-8, AD-29), which OS management's set covers. Its classic page is
/// <code>%cspapp.op.utilsysstatisticsecp</code> (AD-44); it links out to nothing.</p>
Class OcuPilot.Screen.Descriptor.DashboardEcp Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/ecp-statistics",
  "area": "os-management",
  "labelKey": "ecpStatisticsLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {
    "fields": ["Ecp.AppServer.MaxConn", "Ecp.AppServer.ActConn", "Ecp.AppServer.GloRef", "Ecp.AppServer.ByteSent", "Ecp.AppServer.ByteRcvd", "Ecp.AppServer.BlockAdd", "Ecp.AppServer.BlockBuffPurge", "Ecp.AppServer.BlockSvrPurge", "Ecp.AppServer.GloRefLocal", "Ecp.AppServer.GloRefRemote", "Ecp.AppServer.GloUpdateLocal", "Ecp.AppServer.GloUpdateRemote", "Ecp.AppServer.RoutineCallLocal", "Ecp.AppServer.RoutineCallRemote", "Ecp.AppServer.RoutineBuffLocal", "Ecp.AppServer.RoutineBuffRemote", "Ecp.DataServer.MaxConn", "Ecp.DataServer.ActConn", "Ecp.DataServer.GloRef", "Ecp.DataServer.ByteSent", "Ecp.DataServer.ByteRcvd", "Ecp.DataServer.GloUpdate", "Ecp.DataServer.ReqRcvd", "Ecp.DataServer.ReqBuff", "Ecp.DataServer.BlockSent", "Ecp.DataServer.LockGrant", "Ecp.DataServer.LockFail", "Ecp.DataServer.LockQueGrant", "Ecp.DataServer.LockQueFail", "Ecp.DataServer.SvrBlockPurge", "Ecp.DataServer.RoutinePurge", "Ecp.DataServer.BigKill", "Ecp.DataServer.BigString"],
    "secretFields": []
  },
  "emptyStateKey": "statisticsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "ecpStatisticsPrompt1"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "ecpStatisticsPrompt2"}, {"groupKey": "promptGroupCapacity", "textKey": "ecpStatisticsPrompt3"}],
  "classicPage": "%cspapp.op.utilsysstatisticsecp",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": [{"type": "DASHBOARDECP", "as": "Ecp"}]},
    "fields": ["Ecp.AppServer.MaxConn", "Ecp.AppServer.ActConn", "Ecp.AppServer.GloRef", "Ecp.AppServer.ByteSent", "Ecp.AppServer.ByteRcvd", "Ecp.AppServer.BlockAdd", "Ecp.AppServer.BlockBuffPurge", "Ecp.AppServer.BlockSvrPurge", "Ecp.AppServer.GloRefLocal", "Ecp.AppServer.GloRefRemote", "Ecp.AppServer.GloUpdateLocal", "Ecp.AppServer.GloUpdateRemote", "Ecp.AppServer.RoutineCallLocal", "Ecp.AppServer.RoutineCallRemote", "Ecp.AppServer.RoutineBuffLocal", "Ecp.AppServer.RoutineBuffRemote", "Ecp.DataServer.MaxConn", "Ecp.DataServer.ActConn", "Ecp.DataServer.GloRef", "Ecp.DataServer.ByteSent", "Ecp.DataServer.ByteRcvd", "Ecp.DataServer.GloUpdate", "Ecp.DataServer.ReqRcvd", "Ecp.DataServer.ReqBuff", "Ecp.DataServer.BlockSent", "Ecp.DataServer.LockGrant", "Ecp.DataServer.LockFail", "Ecp.DataServer.LockQueGrant", "Ecp.DataServer.LockQueFail", "Ecp.DataServer.SvrBlockPurge", "Ecp.DataServer.RoutinePurge", "Ecp.DataServer.BigKill", "Ecp.DataServer.BigString"],
    "filter": ["Ecp.AppServer.MaxConn", "Ecp.AppServer.ActConn", "Ecp.AppServer.GloRef", "Ecp.AppServer.ByteSent", "Ecp.AppServer.ByteRcvd", "Ecp.AppServer.BlockAdd", "Ecp.AppServer.BlockBuffPurge", "Ecp.AppServer.BlockSvrPurge", "Ecp.AppServer.GloRefLocal", "Ecp.AppServer.GloRefRemote", "Ecp.AppServer.GloUpdateLocal", "Ecp.AppServer.GloUpdateRemote", "Ecp.AppServer.RoutineCallLocal", "Ecp.AppServer.RoutineCallRemote", "Ecp.AppServer.RoutineBuffLocal", "Ecp.AppServer.RoutineBuffRemote", "Ecp.DataServer.MaxConn", "Ecp.DataServer.ActConn", "Ecp.DataServer.GloRef", "Ecp.DataServer.ByteSent", "Ecp.DataServer.ByteRcvd", "Ecp.DataServer.GloUpdate", "Ecp.DataServer.ReqRcvd", "Ecp.DataServer.ReqBuff", "Ecp.DataServer.BlockSent", "Ecp.DataServer.LockGrant", "Ecp.DataServer.LockFail", "Ecp.DataServer.LockQueGrant", "Ecp.DataServer.LockQueFail", "Ecp.DataServer.SvrBlockPurge", "Ecp.DataServer.RoutinePurge", "Ecp.DataServer.BigKill", "Ecp.DataServer.BigString"],
    "sort": {
      "fields": ["Ecp.AppServer.MaxConn", "Ecp.AppServer.ActConn", "Ecp.AppServer.GloRef", "Ecp.AppServer.ByteSent", "Ecp.AppServer.ByteRcvd", "Ecp.AppServer.BlockAdd", "Ecp.AppServer.BlockBuffPurge", "Ecp.AppServer.BlockSvrPurge", "Ecp.AppServer.GloRefLocal", "Ecp.AppServer.GloRefRemote", "Ecp.AppServer.GloUpdateLocal", "Ecp.AppServer.GloUpdateRemote", "Ecp.AppServer.RoutineCallLocal", "Ecp.AppServer.RoutineCallRemote", "Ecp.AppServer.RoutineBuffLocal", "Ecp.AppServer.RoutineBuffRemote", "Ecp.DataServer.MaxConn", "Ecp.DataServer.ActConn", "Ecp.DataServer.GloRef", "Ecp.DataServer.ByteSent", "Ecp.DataServer.ByteRcvd", "Ecp.DataServer.GloUpdate", "Ecp.DataServer.ReqRcvd", "Ecp.DataServer.ReqBuff", "Ecp.DataServer.BlockSent", "Ecp.DataServer.LockGrant", "Ecp.DataServer.LockFail", "Ecp.DataServer.LockQueGrant", "Ecp.DataServer.LockQueFail", "Ecp.DataServer.SvrBlockPurge", "Ecp.DataServer.RoutinePurge", "Ecp.DataServer.BigKill", "Ecp.DataServer.BigString"],
      "default": "Ecp.AppServer.MaxConn",
      "direction": "asc"
    },
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Ecp.AppServer.MaxConn", "labelKey": "licenseUsageMaxConnections", "kind": "name"},
      {"field": "Ecp.AppServer.ActConn", "labelKey": "statsEcpActiveConnections", "kind": "number"},
      {"field": "Ecp.AppServer.GloRef", "labelKey": "processDetailsGlobalReferences", "kind": "number"},
      {"field": "Ecp.AppServer.ByteSent", "labelKey": "statsEcpBytesSent", "kind": "number"},
      {"field": "Ecp.AppServer.ByteRcvd", "labelKey": "statsEcpBytesReceived", "kind": "number"},
      {"field": "Ecp.AppServer.BlockAdd", "labelKey": "statsEcpBlocksAdded", "kind": "number"},
      {"field": "Ecp.AppServer.BlockBuffPurge", "labelKey": "statsEcpBlocksPurgedForBuffers", "kind": "number"},
      {"field": "Ecp.AppServer.BlockSvrPurge", "labelKey": "statsEcpBlocksPurgedByDataServer", "kind": "number"},
      {"field": "Ecp.AppServer.GloRefLocal", "labelKey": "statsGlobalReferencesLocal", "kind": "number"},
      {"field": "Ecp.AppServer.GloRefRemote", "labelKey": "statsGlobalReferencesRemote", "kind": "number"},
      {"field": "Ecp.AppServer.GloUpdateLocal", "labelKey": "statsGlobalUpdatesLocal", "kind": "number"},
      {"field": "Ecp.AppServer.GloUpdateRemote", "labelKey": "statsGlobalUpdatesRemote", "kind": "number"},
      {"field": "Ecp.AppServer.RoutineCallLocal", "labelKey": "statsRoutineCallsLocal", "kind": "number"},
      {"field": "Ecp.AppServer.RoutineCallRemote", "labelKey": "statsRoutineCallsRemote", "kind": "number"},
      {"field": "Ecp.AppServer.RoutineBuffLocal", "labelKey": "statsRoutineLoadsLocal", "kind": "number"},
      {"field": "Ecp.AppServer.RoutineBuffRemote", "labelKey": "statsRoutineLoadsRemote", "kind": "number"},
      {"field": "Ecp.DataServer.MaxConn", "labelKey": "licenseUsageMaxConnections", "kind": "number"},
      {"field": "Ecp.DataServer.ActConn", "labelKey": "statsEcpActiveConnections", "kind": "number"},
      {"field": "Ecp.DataServer.GloRef", "labelKey": "processDetailsGlobalReferences", "kind": "number"},
      {"field": "Ecp.DataServer.ByteSent", "labelKey": "statsEcpBytesSent", "kind": "number"},
      {"field": "Ecp.DataServer.ByteRcvd", "labelKey": "statsEcpBytesReceived", "kind": "number"},
      {"field": "Ecp.DataServer.GloUpdate", "labelKey": "systemUsageGlobalUpdates", "kind": "number"},
      {"field": "Ecp.DataServer.ReqRcvd", "labelKey": "statsEcpRequestsReceived", "kind": "number"},
      {"field": "Ecp.DataServer.ReqBuff", "labelKey": "statsEcpRequestBuffers", "kind": "number"},
      {"field": "Ecp.DataServer.BlockSent", "labelKey": "statsEcpBlocksSent", "kind": "number"},
      {"field": "Ecp.DataServer.LockGrant", "labelKey": "statsEcpLocksGranted", "kind": "number"},
      {"field": "Ecp.DataServer.LockFail", "labelKey": "statsEcpLocksFailed", "kind": "number"},
      {"field": "Ecp.DataServer.LockQueGrant", "labelKey": "statsEcpQueuedLocksGranted", "kind": "number"},
      {"field": "Ecp.DataServer.LockQueFail", "labelKey": "statsEcpQueuedLocksFailed", "kind": "number"},
      {"field": "Ecp.DataServer.SvrBlockPurge", "labelKey": "statsEcpBlockPurgesRequested", "kind": "number"},
      {"field": "Ecp.DataServer.RoutinePurge", "labelKey": "statsEcpRoutinePurgesSent", "kind": "number"},
      {"field": "Ecp.DataServer.BigKill", "labelKey": "statsEcpBigKills", "kind": "number"},
      {"field": "Ecp.DataServer.BigString", "labelKey": "statsEcpBigStrings", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.ecpstatistics"
}
}

}
