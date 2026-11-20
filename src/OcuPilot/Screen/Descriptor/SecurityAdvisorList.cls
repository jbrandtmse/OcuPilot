/// <p>The Security advisor: the instance's security recommendations, one row each with its area, the item it is about, the
/// recommendation and whether it is ignored, read through <class>OcuPilot.Port.AdvisorPort</class> (source kind
/// <code>advisor</code>, endpoint <code>SecurityAdvisor</code>) and rendered by the <code>list</code> archetype's page from the
/// declared <code>table</code> (AD-5, AD-29, AD-36, AD-53, Story 21.19). It is Security's sixteenth side-bar entry.</p>
/// <p><b>Its pairs</b> are the port's: <code>%Admin_Secure:USE</code>, the classic page's own, <code>%DB_IRISSYS:READ</code> and
/// <code>%DB_IRISSYS:WRITE</code>, which the advisor's recommendations raise <code>&lt;PROTECT&gt;</code> without even to read
/// (AD-8, AD-44). <code>%DB_IRISSYS:WRITE</code> is declared in <code>ownPrivileges</code>, so Security's other screens stay open
/// to a holder of the area's two pairs. The classic page asks for <code>%Admin_Secure</code> alone, so this screen is stricter,
/// never looser.</p>
/// <p><b>Its id is composite</b> (AD-13): the type, the element and the code, the element being a single space for a type's
/// general row. Its row actions Ignore and Stop ignoring are the screen's callers of
/// <class>OcuPilot.Screen.Tool.SecurityAdvisorIgnore</class> and <class>OcuPilot.Screen.Tool.SecurityAdvisorUnignore</class>
/// (AD-53), neither self-protected. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.SecurityAdvisorList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/advisor",
  "area": "security",
  "labelKey": "securityAdvisorLabel",
  "sideBarPosition": 16,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}, {"resource": "%DB_IRISSYS", "permission": "WRITE"}],
  "ownPrivileges": [{"resource": "%DB_IRISSYS", "permission": "WRITE"}],
  "entityType": "security-recommendation",
  "entityLabelKey": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Type", "Element", "Code"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "ignore", "selfProtection": ""}, {"id": "unignore", "selfProtection": ""}],
  "context": {"fields": ["Type", "Area", "Element", "Code", "Recommendation", "Ignored"], "secretFields": []},
  "emptyStateKey": "securityAdvisorEmpty",
  "commandAliases": ["security advisor", "security recommendations"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "securityAdvisorPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "userListPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "roleListPrompt1"}
  ],
  "classicPage": "%cspapp.sec.utilsyssecurityadvisor",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "security recommendation",
    "source": {"port": "advisor", "endpoint": "SecurityAdvisor", "type": "LIST"},
    "fields": ["Type", "Area", "Element", "Code", "Recommendation", "Ignored"],
    "filter": ["Area", "Element", "Recommendation"],
    "sort": {"fields": ["Area", "Element", "Recommendation", "Ignored"], "default": "Area", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Area", "labelKey": "screenPermissionsColumnArea", "kind": "text"},
      {"field": "Element", "labelKey": "interopItemSettingsCriterionItem", "kind": "name"},
      {"field": "Recommendation", "labelKey": "securityAdvisorColumnRecommendation", "kind": "text"},
      {"field": "Ignored", "labelKey": "securityAdvisorColumnIgnored", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "securityAdvisorEmptyAgent"
  },
  "toolIdentifier": "security.advisor"
}
}

}
