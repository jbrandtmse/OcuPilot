/// <p>Interoperability's Archive errors: the last archive run's error log of the namespace, one row for each message the vendor could not archive, as the classic Archive Manager page's
/// error log shows them, read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>ArchiveErrors</code>) and rendered by the
/// <code>list</code> archetype's page over the declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 24.16 Batch 4). It is read-only: a longer log than the cap is reported as
/// truncation, never dropped silently (AD-36), and a description is the vendor's text, shown and never run (AD-11).</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_ArchiveManager:READ</code> (AD-8). Its scope is <code>namespace</code>. It does not
/// refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropArchiveErrorList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/archive-errors",
  "area": "interoperability",
  "labelKey": "interopArchiveErrorsLabel",
  "sideBarPosition": 21,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ArchiveManager", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_ArchiveManager", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["ErrorNumber", "Time", "Description", "MessageId"], "secretFields": []},
  "emptyStateKey": "interopArchiveErrorsEmpty",
  "commandAliases": ["archive errors", "archive error log"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopArchivePrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopArchivePrompt3"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopArchiveErrorsPrompt1"}
  ],
  "classicPage": "EnsPortal.ArchiveManager",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "archive error",
    "source": {"port": "interop", "endpoint": "ArchiveErrors", "type": "LIST"},
    "fields": ["ErrorNumber", "Time", "Description", "MessageId"],
    "filter": ["Description", "MessageId"],
    "sort": {"fields": ["ErrorNumber", "Time", "MessageId"], "default": "ErrorNumber", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "ErrorNumber", "labelKey": "errorLogColumnNumber", "kind": "name"},
      {"field": "Time", "labelKey": "auditColumnTime", "kind": "text"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "MessageId", "labelKey": "interopColumnMessageId", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "interop.archiveerrors"
}
}

}
