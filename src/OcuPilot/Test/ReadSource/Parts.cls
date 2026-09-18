/// <p>Fixture descriptor declaring a two-part single-object read (AD-36, Story 6.9): a
/// <code>GET</code> of <code>Monitor</code> merging <code>SYSTEMUSAGE</code> as <code>Usage</code>
/// (an object part) and <code>SYSTEMUSAGESHM</code> as <code>SharedMemory</code> (an array part,
/// merged as its one <code>Total</code> row). The endpoint name is the real one so the read
/// resolves through <class>OcuPilot.Port.AdminPort</class>'s real <code>BARETYPES</code> map
/// unchanged; only the endpoint <b>class</b> is swapped, by
/// <method>OcuPilot.Test.PortFixture.SetEndpointClass</method>, to
/// <class>OcuPilot.Test.ReadSource.Endpoint</class>.</p>
/// <p>It lives in a package of its own so no fixture registry enumerates it.</p>
Class OcuPilot.Test.ReadSource.Parts Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/readsource-parts",
  "area": "security",
  "labelKey": "oauthTabServer",
  "sideBarPosition": 0,
  "archetype": "meters",
  "built": false,
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
  "context": {"fields": ["Usage.AllGlobalReferences", "SharedMemory.SMHUsed"], "secretFields": []},
  "emptyStateKey": "systemUsageEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Monitor",
      "type": "GET",
      "parts": [
        {"type": "SYSTEMUSAGE", "as": "Usage"},
        {"type": "SYSTEMUSAGESHM", "as": "SharedMemory"}
      ]
    },
    "fields": ["Usage.AllGlobalReferences", "SharedMemory.SMHUsed"],
    "filter": [],
    "sort": {"fields": ["Usage.AllGlobalReferences"], "default": "Usage.AllGlobalReferences", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [{"field": "Usage.AllGlobalReferences", "labelKey": "tableColumnName", "kind": "name"}, {"field": "SharedMemory.SMHUsed", "labelKey": "tableColumnName", "kind": "number"}],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "security.readsourceparts"
}
}

}
