/// <p>The LDAP configuration form: one LDAP configuration, edited at its id route as a reduced form --
/// its description, whether it is enabled, its host names and how users are found -- rendered by the
/// <code>form-page</code> archetype (AD-5) and ended by a <code>classic-link-card</code> to the
/// classic LDAP configurations page, which keeps the group, attribute, Kerberos, TLS and search
/// password settings until Story 16.14's full editor replaces this form and removes its exemption
/// (AD-44). Its Save and the agent's confirmed <code>security.ldap.update</code> are two callers of
/// one tool (AD-55).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.LdapConfigList</class>'s name cell, at
/// that list's own route with <code>/edit</code> appended and the name as its one id segment. It
/// edits and never creates.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36); its privilege set is
/// the list's own (AD-8). Its classic equivalent is <code>%CSP.UI.Portal.LDAP</code>, in the class's
/// own case (AD-44). It does not refresh (AD-43). No search password is read, so its context carries
/// no secret.</p>
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
  "context": {"fields": [], "secretFields": []},
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
  "classicLinkExemption": {"exempt": true, "reason": "Reduced until the full LDAP and Kerberos editor ships (Story 16.14); counted against SM-C1", "label": "Security LDAP Configs", "href": "/csp/sys/sec/%25CSP.UI.Portal.LDAPs.zen"},
  "toolIdentifier": "security.ldapform"
}
}

}
