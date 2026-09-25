/// <p>The LDAP / Kerberos configurations list: every LDAP configuration on this instance, read through
/// the vendor's own <code>Security.LDAP</code> LIST (AD-2, AD-36) and rendered by the
/// <code>list</code> archetype's page from the declared <code>table</code> (AD-5). Kerberos is a flag
/// on an LDAP configuration rather than an object of its own, so this one list serves both.</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> An LDAP
/// configuration is instance security configuration keyed by its name alone (AD-13).</p>
/// <p><b>Its id is <code>single</code>:</b> the configuration's name, one percent-encoded path
/// segment, with no second part.</p>
/// <p><b>The four read fields are the live LIST row's whole key set</b>, in the vendor's own order:
/// <code>Name</code>, <code>Enabled</code> (a boolean), <code>Description</code> and
/// <code>LDAPCACertFile</code>. No search password is on the LIST row, and the list declares no
/// <code>rowGet</code>, so none is ever read and <code>context.secretFields</code> is empty (AD-35).
/// <code>LDAPCACertFile</code> is a vendor value displayed, never a path any caller supplies
/// (AD-21).</p>
/// <p><b>The privilege set is <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>.</b>
/// The first is one of the vendor's <code>ResourcesOR()</code> pair for a LIST and the classic page's
/// own resource; without the second the vendor endpoint fails inside <code>%SYS</code> and the port
/// answers 500 (AD-8).</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.LDAPs</code></b>, in the class's own case (AD-44).
/// As a list archetype it links out to nothing.</p>
/// <p><b>A row's name cell opens <class>OcuPilot.Screen.Descriptor.LdapConfigForm</class></b>, the reduced
/// form at this list's route with <code>/edit</code> appended (Story 9.9); the form, not this list,
/// carries the classic-portal card. This list's write tool is
/// <class>OcuPilot.Screen.Tool.LdapUpdate</class>.</p>
/// <p>It declares no primary or row action, so its empty state names what to do next, and it does
/// not refresh (AD-43).</p>
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
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Enabled", "Description", "LDAPCACertFile"], "secretFields": []},
  "emptyStateKey": "ldapListEmpty",
  "commandAliases": ["kerberos"],
  "classicPage": "%CSP.UI.Portal.LDAPs",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.LDAP", "type": "LIST"},
    "fields": ["Name", "Enabled", "Description", "LDAPCACertFile"],
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
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "security.ldap"
}
}

}
