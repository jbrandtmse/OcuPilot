/// <p>NLS configured defaults: the translation, collation and date, time and number defaults this instance starts with, each shown with the
/// table the instance uses and where it comes from, read through <class>OcuPilot.Port.ConfigPort</class> (source kind <code>config</code>,
/// endpoint <code>NLSDefaults</code>) and rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29,
/// AD-36, AD-53, Story 21.14). It is OS management's thirty-sixth side-bar entry.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code> (AD-8, AD-44). Its tool adds
/// <code>%DB_IRISSYS:WRITE</code>, which the <code>^SYS("NLS")</code> node needs.</p>
/// <p><b>Its id is the default's name</b>, kept exactly (AD-13). Its row action Set value is the screen's caller of
/// <class>OcuPilot.Screen.Tool.NlsDefaultSet</class> (AD-53): only the locale-format switch is offered it, and every table row, which the port
/// reads as shown and never changed, offers none. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.NlsDefaultList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/nls-defaults",
  "area": "os-management",
  "labelKey": "nlsDefaultsLabel",
  "sideBarPosition": 36,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "nls-default",
  "entityLabelKey": "aboutNlsDefault",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly", "Purges", "Source"], "secretFields": []},
  "emptyStateKey": "configSettingsEmpty",
  "commandAliases": ["nls defaults", "nls configured defaults"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "nlsDefaultsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "localesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "localesPrompt2"}
  ],
  "classicPage": "%CSP.UI.Portal.NLSConfigDefs",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "NLS configured default",
    "label": "The table the instance uses for each NLS category, the configured one or else the current locale's, and the locale-format switch; only the locale-format switch is changed here. The locales are in osmgmt.locales.",
    "source": {"port": "config", "endpoint": "NLSDefaults", "type": "LIST"},
    "fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly", "Purges", "Source"],
    "filter": ["Name", "Value", "Source"],
    "sort": {"fields": ["Name", "Value", "Source"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "text"},
      {"field": "Source", "labelKey": "auditEventFieldSource", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "nlsDefaultsEmptyAgent"
  },
  "toolIdentifier": "osmgmt.nlsdefaults"
}
}

}
