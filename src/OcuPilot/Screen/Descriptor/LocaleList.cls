/// <p>Locale definitions: the locales this instance defines, each with its description, whether it is the current locale and whether it is a
/// custom one, read through <class>OcuPilot.Port.LocalePort</class> (source kind <code>locale</code>, endpoint <code>Locales</code>) and
/// rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-53, Story 21.14). It is OS
/// management's thirty-seventh side-bar entry.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code> (AD-8, AD-44). Its tools add
/// <code>%DB_IRISSYS:WRITE</code>, which the vendor's install and delete need.</p>
/// <p><b>Its id is the locale's name</b>, kept exactly (AD-13). Its row actions Validate, Install and Delete are the screen's callers of
/// <class>OcuPilot.Area.OsMgmt.LocaleRules</class>'s validation route (a read, so no proposal and no write tool),
/// <class>OcuPilot.Screen.Tool.LocaleInstall</class> and <class>OcuPilot.Screen.Tool.LocaleDelete</class> (AD-53); Install and Delete type the
/// locale's name. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.LocaleList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/locales",
  "area": "os-management",
  "labelKey": "localesLabel",
  "sideBarPosition": 37,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "locale",
  "entityLabelKey": "aboutLocaleDefinition",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "validate", "selfProtection": ""}, {"id": "install", "selfProtection": ""}, {"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "Description", "Current", "Custom"], "secretFields": []},
  "emptyStateKey": "localesEmpty",
  "commandAliases": ["locale definitions", "locales"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "localesPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "nlsDefaultsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "localesPrompt2"}
  ],
  "classicPage": "%CSP.UI.Portal.NLS",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "locale",
    "label": "The locales this instance defines: the current one, and the custom ones, whose names start with y and which can be deleted. Validate answers whether a locale is valid and installable. The NLS defaults are in osmgmt.nlsdefaults.",
    "source": {"port": "locale", "endpoint": "Locales", "type": "LIST"},
    "fields": ["Name", "Description", "Current", "Custom"],
    "filter": ["Name", "Description"],
    "sort": {"fields": ["Name", "Description"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "Current", "labelKey": "interopItemClassesColumnCurrent", "kind": "status"},
      {"field": "Custom", "labelKey": "walletUsageCustom", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "localesEmptyAgent"
  },
  "toolIdentifier": "osmgmt.locales"
}
}

}
