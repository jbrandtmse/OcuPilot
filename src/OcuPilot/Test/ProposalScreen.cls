/// <p>Fixture descriptor for the proposal suite: an <code>instance</code>-scoped
/// <code>web-application</code> screen that declares one secret argument and one fingerprint
/// exclusion, so the two halves of AD-6's closed confirm channel can be driven against a mint.</p>
/// <p>The excluded path is one of this screen's own declared read fields, so the exclusion is one
/// <method>OcuPilot.Screen.Registry.ConfirmChannelProblem</method> accepts on its merits rather than
/// one that is never validated because the class sits outside
/// <parameter>OcuPilot.Screen.Registry.DESCRIPTORPACKAGE</parameter>.</p>
/// <p><b>Its <code>secretArguments</code> entry is one that validator refuses</b>: a declared secret
/// must be a top-level secret row of the screen's write tools, and its tool identifier owns no
/// field list. The class is never registered, so the refusal costs nothing, and the entry gives the
/// proposal suite a real declaration: <class>OcuPilot.Test.SecretTool.Probe</class> authors the
/// matching secret row, so <method>OcuPilot.Kernel.Proposal.Confirm.ChannelProblem</method>'s accept
/// arm runs against it rather than against a name list a test supplies.</p>
/// <p><b>Its read declaration is a fixture, not a description of <code>WebApp.App</code>.</b>
/// That endpoint's <code>LIST</code> answers no <code>Password</code>, and this screen mints no read.
/// Do not mine these field names as a claim about the vendor endpoint.</p>
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
    "fields": ["Name", "LastModified", "Password"],
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
