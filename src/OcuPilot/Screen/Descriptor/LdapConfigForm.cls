/// <p>The LDAP and Kerberos editor: one LDAP configuration, created at its bare route and edited at its
/// id route on one tabbed page -- General, Groups and Attributes, over every input of the classic
/// <code>%CSP.UI.Portal.LDAP</code> in its own order -- rendered by the <code>form-page</code>
/// archetype (AD-5). Its create Save and the agent's confirmed <code>security.ldap.create</code>, its
/// edit Save and <code>security.ldap.update</code>, and its search password and
/// <code>security.ldap.password</code> are each two callers of one tool (AD-55). Test authentication
/// is a dialog on the editor, run in process (AD-26, AD-39).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.LdapConfigList</class>'s Create and from a
/// row's name cell, at that list's own route with <code>/edit</code> appended, with the name as its
/// one id segment when it edits.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36); its privilege set is
/// the list's own (AD-8). Its classic equivalent is <code>%CSP.UI.Portal.LDAP</code>, in the class's
/// own case (AD-44); it declares no exemption and does not refresh (AD-43). No search password is
/// ever read, and the one being typed is secret-typed in its context (AD-24, AD-35). It declares
/// three suggested prompts (Story 11.3's contract).</p>
Class OcuPilot.Screen.Descriptor.LdapConfigForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/ldap/edit",
  "area": "security",
  "labelKey": "ldapFormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "ldap-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": ["LDAPSearchPassword"]},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "sslPromptGroupConnections", "textKey": "ldapPromptEnabled"},
    {"groupKey": "sslPromptGroupConnections", "textKey": "ldapPromptServers"},
    {"groupKey": "sslPromptGroupConnections", "textKey": "ldapPromptUsers"}
  ],
  "classicPage": "%CSP.UI.Portal.LDAP",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.ldapform"
}
}

}
