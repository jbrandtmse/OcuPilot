/// <p>System DDL mappings: the mappings the instance ships from a DDL type name to a datatype class (<code>Config.SqlSysDatatypes</code>), each
/// shown with its datatype, read through <class>OcuPilot.Port.ConfigPort</class> (source kind <code>config</code>, endpoint
/// <code>SystemDDL</code>) and rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29, AD-36,
/// AD-53, Story 21.13). It is OS management's thirty-fourth side-bar entry. The user mappings are on their own screen.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code> (AD-8, AD-44). Its tools add
/// <code>%DB_IRISSYS:WRITE</code>, which the vendor's <code>Config</code> writes need.</p>
/// <p><b>Its id is the mapping's DDL type name</b>, kept exactly (AD-13). Its row actions Set value and Delete are the screen's callers of
/// <class>OcuPilot.Screen.Tool.DdlSystemMappingSet</class> and <class>OcuPilot.Screen.Tool.DdlSystemMappingDelete</class> (AD-53); Delete types the
/// mapping's name. The classic page offers no create of a system mapping, so this screen has none. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.DdlSystemMappingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/system-ddl-mappings",
  "area": "os-management",
  "labelKey": "systemDdlMappingsLabel",
  "sideBarPosition": 34,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "system-ddl-mapping",
  "entityLabelKey": "aboutSystemDdlMapping",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}, {"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly", "Purges"], "secretFields": []},
  "emptyStateKey": "systemDdlMappingsEmpty",
  "commandAliases": ["system ddl mappings"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "systemDdlMappingsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "systemDdlMappingsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "systemDdlMappingsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Config.SQLDataTypes",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "system DDL mapping",
    "label": "The instance's system DDL mappings, each a DDL type name and the datatype class it maps to. The user DDL mappings are in osmgmt.userddlmappings.",
    "source": {"port": "config", "endpoint": "SystemDDL", "type": "LIST"},
    "fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly", "Purges"],
    "filter": ["Name", "Value"],
    "sort": {"fields": ["Name", "Value"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Value", "labelKey": "ddlMappingColumnDatatype", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "systemDdlMappingsEmptyAgent"
  },
  "toolIdentifier": "osmgmt.systemddlmappings"
}
}

}
