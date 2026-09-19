/// <p>Fixture descriptor for the proposal suite: an <code>instance</code>-scoped
/// <code>web-application</code> screen that declares one secret argument and one fingerprint
/// exclusion, so the two halves of AD-6's closed confirm channel can be driven against a mint.</p>
/// <p>It lives under <package>OcuPilot.Test</package>, which
/// <parameter>OcuPilot.Screen.Registry.DESCRIPTORPACKAGE</parameter> does not enumerate, so it
/// reaches no roster, no route table and no read tool. Nothing but a test names it.</p>
Class OcuPilot.Test.ProposalScreen Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/proposal-probe",
  "area": "web-applications",
  "labelKey": "webAppListLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "web-application",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": [], "secretFields": []},
  "secretArguments": ["Password"],
  "fingerprintExcludes": ["LastModified"],
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "webAppListEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "WebApp.App", "type": "LIST"},
    "fields": ["Name"],
    "filter": ["Name"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "probe.proposal"
}
}

}
