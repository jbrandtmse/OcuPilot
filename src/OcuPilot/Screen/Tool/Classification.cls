/// <p>The reviewed classification of every write tool's derived fields (AD-3). Hand-written, and
/// the only hand-written part of a write tool's field list: <file>ui/tools/field-lists.mjs</file>
/// joins each entry with the list it names in <class>OcuPilot.Screen.Tool.FieldLists</class> and
/// writes <class>OcuPilot.Screen.Tool.ToolFields</class>; <code>npm run build</code> fails on any
/// entry it refuses.</p>
/// <p><b>Grammar.</b> The block is one JSON object keyed by tool name
/// (<code>&lt;area&gt;.&lt;screen&gt;.&lt;verb&gt;</code>, lower case, dots only). Each entry holds
/// <code>fieldList</code>, a list key <class>OcuPilot.Screen.Tool.FieldLists</class> carries, and
/// <code>classification</code>, an object mapping a classifiable path of that list (a row no other
/// row's path extends) to <code>ordinary</code>, <code>secret</code> or <code>opaque</code>. The
/// keys <code>required</code>, <code>enum</code> and <code>description</code> are reserved for the
/// semantic half of a tool's schema and accept no content yet; no other key is accepted.</p>
/// <p><b>It fails closed.</b> A classifiable path the entry does not name is emitted
/// <code>secret</code>. <code>opaque</code> is for a member-less object or array only, and a
/// member-less object or array may not be <code>ordinary</code>. A string literal whose last path
/// segment matches the credential pattern (Conventions, Secrets) may be nothing but
/// <code>secret</code>.</p>
Class OcuPilot.Screen.Tool.Classification Extends %RegisteredObject
{

/// <p>The reviewed entries, one per write tool.</p>
/// <p><b><code>webapp.list.update</code></b> classifies every classifiable row of
/// <code>WebApp.App</code> as <code>ordinary</code> except the <code>MatchRoles</code> subtree,
/// which is left unnamed and so emitted <code>secret</code> by the generator's fail-closed default.
/// That subtree sets a web application's roles, which AD-10 forbids granting through any path, so
/// no write tool may carry it into a payload, a diff or the ledger.
/// <class>OcuPilot.Screen.Tool.WebAppUpdate</class> also excludes it by name, so the exclusion is
/// stated where a reader of the tool looks for it as well as here.</p>
/// <p><b><code>ordinary</code> here is not "the tool admits it".</b> Classification decides how a
/// path may be carried; which paths a write tool advertises is that tool's own positive list
/// (<parameter>OcuPilot.Screen.Tool.WebAppUpdate.PERMITTEDFIELDS</parameter>, four of these rows),
/// and <code>DispatchClass</code> and the rest stay <code>ordinary</code> and unadvertised.</p>
/// <p><b><code>security.auditing.update</code></b> classifies the one row of
/// <code>Security.Audit.Enabled</code> -- the derived <code>Enabled</code> boolean --
/// <code>ordinary</code>. A path no entry names is emitted <code>secret</code>, and a secret row
/// never reaches a schema (<method>OcuPilot.Screen.Tool.Write.FieldRows</method>), so without this
/// entry the tool would advertise the id property and nothing to change.</p>
/// <p><b><code>webapp.list.create</code></b> classifies the same <code>WebApp.App</code> list the
/// same way, and for the same reason: classification decides how a path may be carried, not which
/// paths a tool advertises. The two tools' <b>advertised</b> sets differ -- a create admits
/// <code>DispatchClass</code> and a change does not (AD-54) -- and that difference lives in each
/// tool's own positive list, never here.</p>
/// <p><b><code>permissions.users.update</code></b> classifies <code>Security.User</code>'s fourteen
/// literals <code>ordinary</code> and its two arrays -- <code>Roles</code> and
/// <code>EscalationRoles</code> -- <code>opaque</code>: the endpoint's template answers
/// <code>[]</code> for both, which types no member, and AD-3 names this endpoint's empty
/// <code>Roles</code> as its own <code>opaque</code> example. The generator refuses
/// <code>ordinary</code> on a member-less array, so <code>opaque</code> is also the only class
/// either row can carry. The tool's one authored array argument is its semantic half
/// (<class>OcuPilot.Screen.Tool.UserUpdate</class>), not a derived field.</p>
XData Entries
{
{
  "permissions.users.update": {
    "fieldList": "Security.User",
    "classification": {
      "AccountNeverExpires": "ordinary",
      "AutheEnabled": "ordinary",
      "ChangePassword": "ordinary",
      "Comment": "ordinary",
      "EmailAddress": "ordinary",
      "Enabled": "ordinary",
      "ExpirationDate": "ordinary",
      "FullName": "ordinary",
      "HOTPKeyDisplay": "ordinary",
      "NameSpace": "ordinary",
      "PasswordNeverExpires": "ordinary",
      "PhoneNumber": "ordinary",
      "PhoneProvider": "ordinary",
      "Roles": "opaque",
      "EscalationRoles": "opaque",
      "Routine": "ordinary"
    }
  },
  "security.auditing.update": {
    "fieldList": "Security.Audit.Enabled",
    "classification": {
      "Enabled": "ordinary"
    }
  },
  "webapp.list.create": {
    "fieldList": "WebApp.App",
    "classification": {
      "AutheEnabled": "ordinary",
      "AutoCompile": "ordinary",
      "ChangePasswordPage": "ordinary",
      "CookiePath": "ordinary",
      "CorsAllowlist[]": "ordinary",
      "CorsCredentialsAllowed": "ordinary",
      "CorsHeadersList[]": "ordinary",
      "CSPZENEnabled": "ordinary",
      "CSRFToken": "ordinary",
      "DeepSeeEnabled": "ordinary",
      "Description": "ordinary",
      "DispatchClass": "ordinary",
      "Enabled": "ordinary",
      "ErrorPage": "ordinary",
      "EventClass": "ordinary",
      "GroupById": "ordinary",
      "iKnowEnabled": "ordinary",
      "InbndWebServicesEnabled": "ordinary",
      "IsNameSpaceDefault": "ordinary",
      "JWTAuthEnabled": "ordinary",
      "JWTAccessTokenTimeout": "ordinary",
      "JWTRefreshTokenTimeout": "ordinary",
      "LockCSPName": "ordinary",
      "LoginPage": "ordinary",
      "NameSpace": "ordinary",
      "Package": "ordinary",
      "Path": "ordinary",
      "PermittedClasses": "ordinary",
      "Recurse": "ordinary",
      "RedirectEmptyPath": "ordinary",
      "Resource": "ordinary",
      "ServeFiles": "ordinary",
      "ServeFilesTimeout": "ordinary",
      "SuperClass": "ordinary",
      "Timeout": "ordinary",
      "TraceEnabled": "ordinary",
      "TwoFactorEnabled": "ordinary",
      "UseCookies": "ordinary",
      "SessionScope": "ordinary",
      "UserCookieScope": "ordinary",
      "WSGIAppLocation": "ordinary",
      "WSGIAppName": "ordinary",
      "WSGICallable": "ordinary",
      "WSGIDebug": "ordinary",
      "WSGIType": "ordinary"
    }
  },
  "webapp.list.update": {
    "fieldList": "WebApp.App",
    "classification": {
      "AutheEnabled": "ordinary",
      "AutoCompile": "ordinary",
      "ChangePasswordPage": "ordinary",
      "CookiePath": "ordinary",
      "CorsAllowlist[]": "ordinary",
      "CorsCredentialsAllowed": "ordinary",
      "CorsHeadersList[]": "ordinary",
      "CSPZENEnabled": "ordinary",
      "CSRFToken": "ordinary",
      "DeepSeeEnabled": "ordinary",
      "Description": "ordinary",
      "DispatchClass": "ordinary",
      "Enabled": "ordinary",
      "ErrorPage": "ordinary",
      "EventClass": "ordinary",
      "GroupById": "ordinary",
      "iKnowEnabled": "ordinary",
      "InbndWebServicesEnabled": "ordinary",
      "IsNameSpaceDefault": "ordinary",
      "JWTAuthEnabled": "ordinary",
      "JWTAccessTokenTimeout": "ordinary",
      "JWTRefreshTokenTimeout": "ordinary",
      "LockCSPName": "ordinary",
      "LoginPage": "ordinary",
      "NameSpace": "ordinary",
      "Package": "ordinary",
      "Path": "ordinary",
      "PermittedClasses": "ordinary",
      "Recurse": "ordinary",
      "RedirectEmptyPath": "ordinary",
      "Resource": "ordinary",
      "ServeFiles": "ordinary",
      "ServeFilesTimeout": "ordinary",
      "SuperClass": "ordinary",
      "Timeout": "ordinary",
      "TraceEnabled": "ordinary",
      "TwoFactorEnabled": "ordinary",
      "UseCookies": "ordinary",
      "SessionScope": "ordinary",
      "UserCookieScope": "ordinary",
      "WSGIAppLocation": "ordinary",
      "WSGIAppName": "ordinary",
      "WSGICallable": "ordinary",
      "WSGIDebug": "ordinary",
      "WSGIType": "ordinary"
    }
  }
}
}

}
