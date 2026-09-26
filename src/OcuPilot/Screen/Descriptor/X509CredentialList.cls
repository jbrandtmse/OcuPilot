/// <p>The X.509 credentials list: every X.509 credential on this instance, read through the vendor's
/// own <code>Security.X509Credential</code> LIST and, once per surviving row, its
/// <code>CERTINFO</code> (AD-2, AD-36), and rendered by the <code>list</code> archetype's page from
/// the declared <code>table</code> (AD-5).</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> An X.509
/// credential is instance security configuration keyed by its alias alone (AD-13).</p>
/// <p><b>Its id is <code>single</code>:</b> the credential's alias, one percent-encoded path segment,
/// with no second part.</p>
/// <p><b>Subject, issuer and validity come from the certificate read.</b> The LIST row carries the
/// alias, owners, peer names and CA file and none of those three, so
/// <code>read.source.rowGet</code> issues <code>CERTINFO</code> by <code>Alias</code> for each row
/// that survives the cap and merges <code>SubjectDN</code>, <code>IssuerDN</code>,
/// <code>ValidityNotBefore</code> and <code>ValidityNotAfter</code>. Validity is the vendor's
/// <code>YYYY-MM-DD HH:MM:SS</code> text. A credential deleted between the two calls is dropped from
/// the list.</p>
/// <p><b>Nothing secret is read.</b> The LIST row's <code>HasPrivateKey</code> and the certificate
/// read's <code>HasPrivateKey</code> and <code>SerialNumber</code> are not declared, so the read
/// projects them away; no certificate body, private key or key password is on either answer, and
/// <code>context.secretFields</code> is empty because the read carries no secret to strip (AD-35,
/// Conventions, Secrets).</p>
/// <p><b>The privilege set is <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>.</b>
/// The first is the vendor's <code>ResourcesOR()</code> and the classic page's own resource; without
/// the second the vendor endpoint fails inside <code>%SYS</code> and the port answers 500 (AD-8).</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.X509Credentials</code></b>, in the class's own case
/// (AD-44). As a list archetype it links out to nothing.</p>
/// <p><b>Its primary action is Create, labelled Import</b>: it opens
/// <class>OcuPilot.Screen.Descriptor.X509Form</class> at <code>security/x509/edit</code>, and a row's
/// name cell opens the same form for that credential. Both save through the X.509 tools (AD-55).
/// Its row action is Delete (AD-53), through <class>OcuPilot.Screen.Tool.X509Delete</class>, with no
/// self-protection rule: OcuPilot creates and relies on no X.509 credential. Its empty state invites
/// the agent. It does not refresh (AD-43).</p>
/// <p><b><code>Certificate</code>, <code>PrivateKey</code> and <code>PrivateKeyPassword</code> are its
/// <code>secretArguments</code></b> (AD-3, AD-6): the import's authored secrets, supplied only at
/// confirm and never read back by any read.</p>
Class OcuPilot.Screen.Descriptor.X509CredentialList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/x509",
  "area": "security",
  "labelKey": "x509ListLabel",
  "sideBarPosition": 2,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "x509-credential",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Alias", "OwnerList", "PeerNames", "CAFile", "SubjectDN", "IssuerDN", "ValidityNotBefore", "ValidityNotAfter"], "secretFields": []},
  "secretArguments": ["Certificate", "PrivateKey", "PrivateKeyPassword"],
  "emptyStateKey": "x509ListEmpty",
  "commandAliases": ["x509"],
  "suggestedPrompts": [
    {"groupKey": "sslPromptGroupConnections", "textKey": "x509CredentialListPrompt1"},
    {"groupKey": "sslPromptGroupConnections", "textKey": "x509CredentialListPrompt2"},
    {"groupKey": "sslPromptGroupConnections", "textKey": "x509CredentialListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.X509Credentials",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Security.X509Credential",
      "type": "LIST",
      "rowGet": {
        "key": "Alias",
        "param": "alias",
        "type": "CERTINFO",
        "fields": ["SubjectDN", "IssuerDN", "ValidityNotBefore", "ValidityNotAfter"],
        "derived": []
      }
    },
    "fields": ["Alias", "OwnerList", "PeerNames", "CAFile", "SubjectDN", "IssuerDN", "ValidityNotBefore", "ValidityNotAfter"],
    "filter": ["Alias", "SubjectDN", "IssuerDN"],
    "sort": {"fields": ["Alias", "SubjectDN", "IssuerDN", "ValidityNotAfter"], "default": "Alias", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Alias", "labelKey": "x509ColumnAlias", "kind": "name"},
      {"field": "SubjectDN", "labelKey": "x509ColumnSubject", "kind": "text"},
      {"field": "IssuerDN", "labelKey": "x509ColumnIssuer", "kind": "text"},
      {"field": "ValidityNotBefore", "labelKey": "x509ColumnValidFrom", "kind": "text"},
      {"field": "ValidityNotAfter", "labelKey": "x509ColumnValidUntil", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "x509ListEmptyAgent"
  },
  "toolIdentifier": "security.x509"
}
}

}
