/// <p>The LDAP / Kerberos configurations list: every LDAP configuration on this instance, read through
/// the vendor's own <code>Security.LDAP</code> LIST (AD-2, AD-36) and rendered by the
/// <code>list</code> archetype's page from the declared <code>table</code> (AD-5). Kerberos is a flag
/// on an LDAP configuration rather than an object of its own, so this one list serves both.</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> An LDAP
/// configuration is instance security configuration keyed by its name alone (AD-13).</p>
/// <p><b>Its id is <code>single</code>:</b> the configuration's name, one percent-encoded path
/// segment, with no second part.</p>
/// <p><b>The read fields are the LIST row's keys and the configuration's flags</b>:
/// <code>Name</code>, <code>Enabled</code>, <code>Description</code>, <code>LDAPCACertFile</code> and
/// <code>LDAPFlags</code>. The vendor's LIST answers <code>Enabled</code> false for every
/// configuration, so a per-row <code>GET</code> (<code>rowGet</code>) reads <code>LDAPFlags</code> and
/// derives <code>Enabled</code> from its bit 64 (<code>bit64</code>, DW-1639); screen and tool read
/// the same value. No search password is on either read, so <code>context.secretFields</code> is empty
/// (AD-35); <code>secretArguments</code> declares <code>LDAPSearchPassword</code>, which only the
/// password tool's confirm and the editor's Save carry. <code>LDAPCACertFile</code> is a vendor value
/// displayed, never a path any caller supplies (AD-21).</p>
/// <p><b>The privilege set is <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>.</b>
/// The first is one of the vendor's <code>ResourcesOR()</code> pair for a LIST and the classic page's
/// own resource; without the second the vendor endpoint fails inside <code>%SYS</code> and the port
/// answers 500 (AD-8).</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.LDAPs</code></b>, in the class's own case (AD-44).
/// As a list archetype it links out to nothing.</p>
/// <p><b>Create and a row's name cell open <class>OcuPilot.Screen.Descriptor.LdapConfigForm</class></b>,
/// the LDAP and Kerberos editor at this list's route with <code>/edit</code> appended (Story 16.14). A
/// row's Delete removes the configuration (FR-45). Its write tools are
/// <class>OcuPilot.Screen.Tool.LdapUpdate</class>, <class>OcuPilot.Screen.Tool.LdapCreate</class>,
/// <class>OcuPilot.Screen.Tool.LdapPassword</class> and <class>OcuPilot.Screen.Tool.LdapDelete</class>.
/// Being write-capable, its empty state invites the agent, and it does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.LdapConfigList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/ldap",
  "area": "security",
  "labelKey": "ldapListLabel",
  "sideBarPosition": 3,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "ldap-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "Enabled", "Description", "LDAPCACertFile", "LDAPFlags"], "secretFields": []},
  "secretArguments": ["LDAPSearchPassword"],
  "emptyStateKey": "ldapListEmpty",
  "commandAliases": ["kerberos"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupSignIn", "textKey": "ldapConfigListPrompt1"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "ldapConfigListPrompt2"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "ldapConfigListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.LDAPs",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Security.LDAP",
      "type": "LIST",
      "rowGet": {"key": "Name", "param": "name", "fields": ["LDAPFlags"], "derived": [{"field": "Enabled", "rule": "bit64", "from": "LDAPFlags"}]}
    },
    "fields": ["Name", "Enabled", "Description", "LDAPCACertFile", "LDAPFlags"],
    "filter": ["Name", "Description"],
    "sort": {"fields": ["Name", "Description"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "ldapListEmptyAgent"
  },
  "toolIdentifier": "security.ldap"
}
}

}
