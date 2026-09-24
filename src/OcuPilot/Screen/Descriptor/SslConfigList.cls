/// <p>The SSL/TLS configurations list: every SSL/TLS configuration on this instance, read through
/// the vendor's own <code>Security.SSLConfig</code> LIST (AD-2, AD-36) and rendered by the
/// <code>list</code> archetype's page from the declared <code>table</code> (AD-5).</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> An
/// SSL/TLS configuration is instance security configuration keyed by its name alone, so the list is
/// the same whatever namespace the route names (AD-13).</p>
/// <p><b>Its id is <code>single</code>:</b> the configuration's name, one percent-encoded path
/// segment, with no second part.</p>
/// <p><b>The four read fields are the live LIST row's whole key set</b>, in the vendor's own order:
/// <code>Name</code>, <code>Description</code>, <code>Enabled</code> and <code>Type</code>. The
/// vendor builds that row by excluding two columns from <code>Security.SSLConfigs</code>' own
/// <code>List</code> query, so no key material is in it by construction.
/// <class>OcuPilot.Test.ScreenRead</class> holds every declared field to the live first row.</p>
/// <p><b>It declares no <code>rowGet</code>.</b> The endpoint's GET carries seventeen further fields
/// the list does not show -- file locations among them, which are locations and not key material --
/// and never the private key password, so <code>context.secretFields</code> is empty because the
/// read carries no secret to strip (AD-35, Conventions, Secrets).</p>
/// <p><b>The privilege set is the vendor's <code>ResourcesOR()</code> for this endpoint,
/// <code>%Admin_Secure:USE</code>, plus <code>%DB_IRISSYS:READ</code></b>: without the database read
/// the vendor endpoint fails inside <code>%SYS</code> and the port answers 500, so the pair is what
/// turns that into a named refusal (AD-8). <class>OcuPilot.Screen.Gate</class> does not add the
/// area's pairs to a screen's, so the screen declares them itself (AD-8, AD-29).</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.SSLList</code></b>, spelled in the class's own
/// case because the custom-resource lookup does not case-fold (AD-44). As a list archetype it links
/// out to nothing.</p>
/// <p><b>Its primary action is Create</b>: it opens <class>OcuPilot.Screen.Descriptor.SslForm</class>
/// at <code>security/ssl/edit</code>, and a row's name cell opens the same form for that
/// configuration; both save through the SSL/TLS tools (AD-55). <b>Its row action is Delete</b>
/// (AD-53), through <class>OcuPilot.Screen.Tool.SslDelete</class>, drawn refused on OcuPilot's own
/// provider configuration (<code>ocupilot-ssl</code>), which the instance refuses whatever the
/// caller (AD-10). Its empty state invites the agent, and it does not refresh (AD-43).</p>
/// <p><b><code>PrivateKeyPassword</code> is its <code>secretArguments</code></b> (AD-3, AD-6): the
/// change tool's one secret, supplied only at confirm and never read back by any read.</p>
Class OcuPilot.Screen.Descriptor.SslConfigList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/ssl",
  "area": "security",
  "labelKey": "sslListLabel",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "ssl-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": "ocupilot-ssl"}],
  "context": {"fields": ["Name", "Description", "Enabled", "Type"], "secretFields": []},
  "secretArguments": ["PrivateKeyPassword"],
  "emptyStateKey": "sslListEmpty",
  "commandAliases": ["certificates"],
  "classicPage": "%CSP.UI.Portal.SSLList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.SSLConfig", "type": "LIST"},
    "fields": ["Name", "Description", "Enabled", "Type"],
    "filter": ["Name", "Description", "Type"],
    "sort": {"fields": ["Name", "Description", "Type"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "sslListEmptyAgent"
  },
  "toolIdentifier": "security.ssl"
}
}

}
