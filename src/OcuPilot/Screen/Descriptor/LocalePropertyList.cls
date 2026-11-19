/// <p>Locale properties: the properties, tables and input/output tables one locale holds, one row each, read through
/// <class>OcuPilot.Port.LocalePort</class> (source kind <code>locale</code>, endpoint <code>Properties</code>) and rendered by the <code>list</code>
/// archetype's page from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-53, Story 21.16). The seven groups are a <code>Group</code> column.</p>
/// <p><b>It is a sub-resource of the Locale definitions list and never listed</b> (<code>sideBarPosition</code> 0): it declares
/// <code>parentScope</code> <code>os-management/locales</code> and is reached from that list's name cell. Its one declared criterion,
/// <code>locale</code>, is the route id, required as a single-object read's is (AD-36); a locale the instance does not list is refused 404.</p>
/// <p><b>Its id is the composite <code>[Locale, Name]</code></b>, each part kept exactly (AD-13); a table's <code>Name</code> is
/// <code>&lt;list&gt;:&lt;table&gt;</code>. Its pairs are the Locale definitions list's. Its primary action Add table and its row actions Set value, Remove
/// table and Load table are the screen's callers of <class>OcuPilot.Screen.Tool.LocaleTableAdd</class>,
/// <class>OcuPilot.Screen.Tool.LocalePropertySet</class>, <class>OcuPilot.Screen.Tool.LocaleTableRemove</class> and
/// <class>OcuPilot.Screen.Tool.LocaleTableLoad</class> (AD-53). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.LocalePropertyList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/locales/properties",
  "area": "os-management",
  "labelKey": "localePropertiesLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "locale-property",
  "entityLabelKey": "aboutLocaleProperty",
  "secondaryEntityTypes": ["locale"],
  "scope": "instance",
  "parentScope": "os-management/locales",
  "id": {"kind": "composite", "parts": ["Locale", "Name"]},
  "primaryAction": {"id": "add-table", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}, {"id": "remove-table", "selfProtection": "locale-table"}, {"id": "load-table", "selfProtection": "locale-loadable"}],
  "context": {"fields": ["Locale", "Group", "Name", "Value", "Kind", "ReadOnly", "Refusal", "Loadable"], "secretFields": []},
  "emptyStateKey": "configSettingsEmpty",
  "commandAliases": ["locale properties"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "localePropertiesPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "localePropertiesPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "localePropertiesPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.NLSEdit",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "locale property",
    "label": "One locale's properties, tables and input/output tables, one row each, by Group. Only a custom locale that is not current can be changed; Refusal says why not. Loadable is true for a table the instance can load.",
    "source": {"port": "locale", "endpoint": "Properties", "type": "LIST"},
    "fields": ["Locale", "Group", "Name", "Value", "Kind", "Accepts", "ReadOnly", "Refusal", "Loadable"],
    "filter": ["Group", "Name", "Value"],
    "sort": {"fields": ["Group", "Name", "Value"], "default": "Group", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "locale", "labelKey": "aboutLocaleDefinition", "kind": "text", "maxLength": 64, "hint": "One locale, spelled as osmgmt.locales answers its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Group", "labelKey": "analyticsColumnGroup", "kind": "text"},
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "localePropertiesEmptyAgent"
  },
  "toolIdentifier": "osmgmt.localeproperties"
}
}

}
