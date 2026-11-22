/// <p>Interoperability's Credentials: the credentials a namespace's production settings name to sign in to other systems, which the classic Credentials
/// page keeps, read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>Credentials</code>) and rendered
/// from the declared <code>table</code> (AD-5, AD-29, AD-35, AD-36, AD-62, Story 24.15).</p>
/// <p><b>Its primary action</b> New credential and <b>its row actions</b> Edit, Set password and Remove are the screen's callers of
/// <class>OcuPilot.Screen.Tool.InteropCredentialAdd</class>, <class>OcuPilot.Screen.Tool.InteropCredentialUpdate</class>,
/// <class>OcuPilot.Screen.Tool.InteropCredentialPassword</class> and <class>OcuPilot.Screen.Tool.InteropCredentialRemove</class> (AD-53, AD-55); each
/// is stored at once. New credential and Edit open one dialog; Edit shows the name read-only, because a name cannot be changed. Set password reuses the
/// shell's password dialog and Remove types the credential's name.</p>
/// <p><b>The password is never read.</b> A row says only whether one is stored (<code>Password</code>: <code>stored</code> or <code>not stored</code>),
/// and the password is the screen's one declared secret argument (<code>secretArguments</code>, AD-35, AD-56): it is typed in the dialog or on the
/// card and reaches the vendor alone. The <code>Password</code> field of a row holds no credential, which is why <code>secretFields</code> is empty here.
/// A name, a user name and a business partner are untrusted content (AD-11, AD-60).</p>
/// <p><b>Its id is the credential's name</b>, kept exactly (AD-13), and its scope is <code>namespace</code>. Its pairs are the classic page's:
/// <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_Credentials:READ</code>; the four tools add <code>%Ens_Credentials:WRITE</code> and WRITE on
/// the namespace's globals database (AD-8, AD-62). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropCredentialList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/credentials",
  "area": "interoperability",
  "labelKey": "sslTabCredentials",
  "sideBarPosition": 14,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_Credentials", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_Credentials", "permission": "READ"}],
  "entityType": "interop-credential",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "edit", "selfProtection": ""}, {"id": "password", "selfProtection": ""}, {"id": "remove", "selfProtection": ""}],
  "context": {"fields": ["Name", "Username", "BusinessPartner", "Password"], "secretFields": []},
  "secretArguments": ["Password"],
  "emptyStateKey": "interopCredentialsEmpty",
  "commandAliases": ["credentials"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopCredentialsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopCredentialsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopCredentialsPrompt3"}
  ],
  "classicPage": "EnsPortal.Credentials",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "credential",
    "source": {"port": "interop", "endpoint": "Credentials", "type": "LIST"},
    "fields": ["Name", "Username", "BusinessPartner", "Password"],
    "filter": ["Name", "Username", "BusinessPartner"],
    "sort": {"fields": ["Name", "Username", "BusinessPartner"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Username", "labelKey": "fieldUserName", "kind": "text"},
      {"field": "BusinessPartner", "labelKey": "interopCredentialBusinessPartner", "kind": "text"},
      {"field": "Password", "labelKey": "fieldPassword", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopCredentialsEmptyAgent"
  },
  "toolIdentifier": "interop.credentials"
}
}

}
