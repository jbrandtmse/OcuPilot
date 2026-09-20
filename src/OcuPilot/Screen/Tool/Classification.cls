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
XData Entries
{
{
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
