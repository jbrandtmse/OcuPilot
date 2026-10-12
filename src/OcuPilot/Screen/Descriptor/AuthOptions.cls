/// <p>Authentication and web session options: which authentication methods the instance accepts, the login
/// cookies, two-factor authentication and the JWT settings, one <code>form-page</code> over the vendor's
/// <code>Security.WebAuth</code> <code>GET</code> (AD-5, AD-36, Story 18.8), so the form and
/// <code>security.authoptions.read</code> answer one read of the twenty-one settings. The SMTP password is
/// never read: <code>SMTPPassword</code> is the descriptor's one declared secret (AD-56). Security's eleventh
/// listed entry.</p>
/// <p><b>Its pairs are Security's</b>, <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>: the
/// endpoint's <code>ResourcesOR()</code> and the classic page's <code>RESOURCE</code> are
/// <code>%Admin_Secure</code>, and a principal holding exactly the two read the settings, wrote them, set
/// and cleared the SMTP password and read each of OcuPilot's own applications and the web gateway service
/// (AD-8, measured at Task 0).</p>
/// <p><b>Its writes are <class>OcuPilot.Screen.Tool.AuthOptionsUpdate</class> and
/// <class>OcuPilot.Screen.Tool.AuthOptionsSmtpPassword</class></b>, reached by the page's own Save
/// (<class>OcuPilot.Area.Security.AuthOptionsSave</class>) and by the agent's confirmed proposals (AD-55);
/// its form read is <code>GET /authentication-options/form</code>
/// (<class>OcuPilot.Area.Security.AuthOptionsRules</class>), which names the flags whose turning off
/// OcuPilot refuses. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AuthOptions Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/authentication",
  "area": "security",
  "labelKey": "authOptionsLabel",
  "sideBarPosition": 11,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "authentication-options",
  "entityLabelKey": "authOptionsLabel",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["AutheUnauthenticated", "AutheOS", "AutheOSDelegated", "AutheOSLDAP", "AutheCache", "AutheDelegated", "AutheAlwaysTryDelegated", "AutheKB", "AutheLDAP", "AutheLDAPCache", "AutheOAuth2", "AutheLoginToken", "AutheTwoFactorSMS", "AutheTwoFactorPW", "LoginCookieTimeout", "SMTPServer", "SMTPUsername", "TwoFactorFrom", "TwoFactorTimeout", "JWTIssuer", "JWTSigAlg"], "secretFields": []},
  "secretArguments": ["SMTPPassword"],
  "emptyStateKey": "",
  "commandAliases": ["authentication", "authentication options"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "authOptionsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "authOptionsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "authOptionsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Authentication",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.WebAuth", "type": "GET"},
    "fields": ["AutheUnauthenticated", "AutheOS", "AutheOSDelegated", "AutheOSLDAP", "AutheCache", "AutheDelegated", "AutheAlwaysTryDelegated", "AutheKB", "AutheLDAP", "AutheLDAPCache", "AutheOAuth2", "AutheLoginToken", "AutheTwoFactorSMS", "AutheTwoFactorPW", "LoginCookieTimeout", "SMTPServer", "SMTPUsername", "TwoFactorFrom", "TwoFactorTimeout", "JWTIssuer", "JWTSigAlg"],
    "filter": ["JWTSigAlg"],
    "sort": {"fields": ["JWTSigAlg"], "default": "JWTSigAlg", "direction": "asc"},
    "paging": "cap"
  },
  "toolIdentifier": "security.authoptions"
}
}

}
