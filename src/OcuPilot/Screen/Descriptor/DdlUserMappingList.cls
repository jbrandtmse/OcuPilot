/// <p>User DDL mappings: the mappings this instance's administrators added from a DDL type name to a datatype class
/// (<code>Config.SqlUserDatatypes</code>), each shown with its datatype, read through <class>OcuPilot.Port.ConfigPort</class> (source kind
/// <code>config</code>, endpoint <code>UserDDL</code>) and rendered by the <code>list</code> archetype's page from the declared
/// <code>table</code> (AD-5, AD-29, AD-36, AD-53, AD-55, Story 21.13). It is OS management's thirty-fifth side-bar entry.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code> (AD-8, AD-44). Its tools add
/// <code>%DB_IRISSYS:WRITE</code>, which the vendor's <code>Config</code> writes need.</p>
/// <p><b>Its id is the mapping's DDL type name</b>, kept exactly (AD-13). Its primary action New mapping is the screen's caller of
/// <class>OcuPilot.Screen.Tool.DdlUserMappingCreate</class> through <class>OcuPilot.Area.OsMgmt.DdlMappingSave</class>, and its row actions Set
/// value and Delete are its callers of <class>OcuPilot.Screen.Tool.DdlUserMappingSet</class> and
/// <class>OcuPilot.Screen.Tool.DdlUserMappingDelete</class> (AD-53); Delete types the mapping's name. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.DdlUserMappingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/user-ddl-mappings",
  "area": "os-management",
  "labelKey": "userDdlMappingsLabel",
  "sideBarPosition": 35,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "user-ddl-mapping",
  "entityLabelKey": "aboutUserDdlMapping",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}, {"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly", "Purges"], "secretFields": []},
  "emptyStateKey": "userDdlMappingsEmpty",
  "commandAliases": ["user ddl mappings"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "userDdlMappingsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "systemDdlMappingsPrompt3"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "systemDdlMappingsPrompt2"}
  ],
  "classicPage": "%CSP.UI.Portal.Config.SQLDataTypes",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "user DDL mapping",
    "label": "The instance's user DDL mappings, each a DDL type name and the datatype class it maps to. The system DDL mappings are in osmgmt.systemddlmappings.",
    "source": {"port": "config", "endpoint": "UserDDL", "type": "LIST"},
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
    "emptyAgentKey": "userDdlMappingsEmptyAgent"
  },
  "toolIdentifier": "osmgmt.userddlmappings"
}
}

}
