/// <p>The Users list: every user on this instance, read through the vendor's own
/// <code>Security.User</code> LIST and, once per surviving row, its GET (AD-2, AD-36), and rendered
/// by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5).</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> A user
/// is instance security configuration keyed by its name alone (AD-13).</p>
/// <p><b>Its id is <code>single</code>:</b> the user's name, one percent-encoded path segment
/// (<code>_SYSTEM</code> travels as itself), with no second part.</p>
/// <p><b>The privilege set is <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>.</b>
/// The first is the vendor's <code>ResourcesOR()</code> and the classic page's own resource; without
/// the second the vendor endpoint fails inside <code>%SYS</code> and the port answers 500 (AD-8).
/// <code>%DB_IRISSECURITY</code> is not declared: IRIS refuses to grant it to a role.</p>
/// <p><b>Roles and expiry come from the detail call.</b> The LIST row carries neither, so
/// <code>read.source.rowGet</code> issues the GET by <code>Name</code> for each row that survives
/// the cap, merges <code>Roles</code> (an array) and <code>ExpirationDate</code>
/// (<code>""</code> or <code>YYYY-MM-DD</code>), and derives <code>Expired</code> with
/// <code>beforeToday</code> on the instance clock, so the screen and the read tool agree and the
/// client computes no expiry. A user deleted between the two calls is dropped from the list.</p>
/// <p><b>Account expired is a <code>text</code> column</b>: a status disc would draw an expired
/// account in the healthy colour, so the word carries the state.</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.Users</code></b>, in the class's own case
/// (AD-44). As a list archetype it links out to nothing. The context carries no secret field.</p>
/// <p><b>Its primary action is Create</b>, which opens <class>OcuPilot.Screen.Descriptor.UserForm</class>;
/// being write-capable, its empty state invites the agent rather than naming a next step. It does
/// not refresh (AD-43).</p>
/// <p><b>It declares seven row actions</b> (AD-5, AD-53), destructive last: <code>enable</code>,
/// <code>disable</code>, <code>require-password-change</code> and the two role actions carried out
/// by <class>OcuPilot.Screen.Tool.UserUpdate</class>, <code>set-password</code> by
/// <class>OcuPilot.Screen.Tool.UserPassword</class> and <code>delete</code> by
/// <class>OcuPilot.Screen.Tool.UserDelete</class>. <code>require-password-change</code> is declared
/// so the route admits the flag the set-password dialog sends first (AD-56); no menu draws it.
/// Disable and delete declare the <code>protected-account</code> rule, which <i>explains</i> the
/// refusal the prohibited set makes at the write (AD-10).</p>
/// <p><b><code>Password</code> is its one secret argument</b> (AD-3, AD-6): the create tool's
/// authored wrapper field, supplied on the screen once and at confirm on the card, and never
/// accepted from the model. The declaration opens the update tool's confirm channel to the same
/// name, which that tool's card never asks for because no update diff names it.</p>
/// <p><b>Its eighth row action is <code>revoke-tokens</code></b>, carried out by
/// <class>OcuPilot.Screen.Tool.UserTokenRevoke</class>: every OAuth 2.0 access token this instance
/// issued under the account's stored name is revoked, behind the typed-name dialog. It declares no self-protection
/// rule, because the prohibited set refuses none of it (AD-10).</p>
Class OcuPilot.Screen.Descriptor.UserList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/users",
  "area": "permissions",
  "labelKey": "userListLabel",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "user",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [
    {"id": "enable", "selfProtection": ""},
    {"id": "disable", "selfProtection": "protected-account"},
    {"id": "set-password", "selfProtection": ""},
    {"id": "add-role", "selfProtection": ""},
    {"id": "remove-role", "selfProtection": ""},
    {"id": "require-password-change", "selfProtection": ""},
    {"id": "delete", "selfProtection": "protected-account"}
    , {"id": "revoke-tokens", "selfProtection": ""}
  ],
  "context": {"fields": ["Name", "FullName", "Enabled", "Type", "Roles", "ExpirationDate", "Expired"], "secretFields": []},
  "secretArguments": ["Password"],
  "emptyStateKey": "userListEmpty",
  "commandAliases": ["accounts"],
  "classicPage": "%CSP.UI.Portal.Users",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Security.User",
      "type": "LIST",
      "rowGet": {
        "key": "Name",
        "param": "name",
        "fields": ["Roles", "ExpirationDate"],
        "derived": [{"field": "Expired", "rule": "beforeToday", "from": "ExpirationDate"}]
      }
    },
    "fields": ["Name", "FullName", "Enabled", "Type", "Roles", "ExpirationDate", "Expired"],
    "filter": ["Name", "FullName", "Type", "Roles"],
    "sort": {"fields": ["Name", "FullName", "Type", "Roles"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "FullName", "labelKey": "userColumnFullName", "kind": "text"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "Expired", "labelKey": "userColumnExpired", "kind": "text"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Roles", "labelKey": "userColumnRoles", "kind": "identifier"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "userListEmptyAgent"
  },
  "toolIdentifier": "permissions.users"
}
}

}
