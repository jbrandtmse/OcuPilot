/// <p>The token contract for <code>/api/ocupilot</code>, pinned over the real wire.</p>
/// <p><b>None of this is OcuPilot's code.</b> <code>/login</code>, <code>/refresh</code>,
/// <code>/logout</code> and <code>/revoke</code> are intercepted by the CSP server before
/// dispatch (<file>irissys/%CSP/REST.cls</file>), so <class>OcuPilot.Api.Router</class>'s
/// <code>UrlMap</code> stays empty and this story adds no route. What is pinned here is the
/// behaviour the client's silent-first design is built on: exactly the properties that,
/// if they changed, would make the client wrong with every other suite green.</p>
/// <p><b>One throwaway principal, not <code>_SYSTEM</code> and not impersonated</b> — the
/// <class>OcuPilot.Test.Wire</class> pattern. Its password is generated from
/// <code>$System.Encryption.GenCryptRand</code>, kept in memory for the run so the account
/// can authenticate for real over HTTP, and never written to source; the account and its
/// role are removed in <method>OnAfterAllTests</method>, which reports a leftover through
/// its returned status rather than through an assertion the manager would discard.</p>
Class OcuPilot.Test.Token Extends %UnitTest.TestCase
{

/// <p>The REST API application these tests address, absolute from the origin root.</p>
Parameter APIPATH = "/api/ocupilot";

/// <p>The throwaway principal. It holds read on the install namespace's code database (IRIS
/// will not load the dispatch class without it) plus one administrative resource, so a
/// request carrying its Bearer clears the whole gate chain in
/// <method>OcuPilot.Api.Router.OnPreDispatch</method> and is answered by the framework 404 —
/// which is this story's success signal, since it adds no route.</p>
Parameter TOKENUSER = "OcuPilotTokenPrincipal";

/// <p>See <parameter>TOKENUSER</parameter>.</p>
Parameter TOKENROLE = "OcuPilotTokenRole";

/// <p>The one administrative resource <parameter>TOKENROLE</parameter> grants, chosen for
/// the reason <class>OcuPilot.Test.Wire</class> records: it is safe to grant to a throwaway
/// account, unlike <code>%Operator</code>, which carries <code>%DB_IRISSYS:RW</code>.</p>
Parameter ADMINRESOURCE = "%Admin_Operate";

/// <p>The browser-level cookie the CSP server sets on a successful login and reads on an
/// empty-body one. <code>path=/</code> is what shares it across every
/// <code>%ISCMgtPortal</code> application.</p>
Parameter BROWSERCOOKIE = "CSPBrowserId";

/// <p>The throwaway account's password for the length of this run. Prefix deliberately not
/// "Test" (<file>.claude/rules/objectscript-testing.md</file>).</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back, rather than assumed, that the
/// account holds the administrative resource — <code>Security.Users.Create</code> silently
/// accepts a role name that does not exist.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Install.Installer).Install("")
        If $$$ISERR(tSC) Quit
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotToken" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        Set tNsObj = ##class(Config.Namespaces).Open(tInstallNs)
        If '$IsObject(tNsObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open namespace configuration for " _ tInstallNs)
            Quit
        }
        Set tDbObj = ##class(Config.Databases).Open(tNsObj.Routines)
        If '$IsObject(tDbObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open the routine database " _ tNsObj.Routines)
            Quit
        }
        Set tSysDb = ##class(SYS.Database).%OpenId(tDbObj.Directory)
        If '$IsObject(tSysDb) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open SYS.Database for the routine database directory")
            Quit
        }

        Set tSC = ..EnsurePrincipal(tSysDb.ResourceName _ ":R," _ ..#ADMINRESOURCE _ ":U")
        If $$$ISERR(tSC) Quit

        Set ..PreparedSetupOk = ($SYSTEM.Security.CheckUserPermission(..#TOKENUSER, ..#ADMINRESOURCE, "USE") = 1)
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the throwaway principal holds " _ ..#ADMINRESOURCE)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the throwaway account and its role, and <b>return a failing status</b> if
/// either survives. The status, never an assertion: <code>%UnitTest.Manager</code> pops the
/// per-method frame before calling this, and <code>LogAssert</code> discards an assertion
/// made with an empty method name, so an assertion here would never be red.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        If ##class(Security.Users).Exists(..#TOKENUSER, .tU, .tUS) {
            Do ##class(Security.Users).Delete(..#TOKENUSER)
        }
        If ##class(Security.Users).Exists(..#TOKENUSER, .tU2, .tUS2) Set tLeft = "user " _ ..#TOKENUSER
        If ##class(Security.Roles).Exists(..#TOKENROLE, .tR, .tRS) {
            Do ##class(Security.Roles).Delete(..#TOKENROLE)
        }
        If ##class(Security.Roles).Exists(..#TOKENROLE, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ ..#TOKENROLE
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.Token teardown left throwaway objects on the instance: " _ tLeft)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create (or re-grant) the throwaway role and the account that holds it.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
Method EnsurePrincipal(pResources As %String) As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(..#TOKENROLE, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tModProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(..#TOKENROLE, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(..#TOKENROLE, "OcuPilot test: token principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(..#TOKENUSER, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(..#TOKENUSER)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(..#TOKENUSER, ..#TOKENROLE, ..PreparedPassword, "OcuPilot token test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.Token; deleted in OnAfterAllTests")
}

/// <p>Whether <var>pHeaders</var> carries any <code>Access-Control-Allow-*</code> header.
/// <class>%Net.HttpResponse</class> subscripts headers by upper-case name.</p>
ClassMethod HasCorsAllowance(ByRef pHeaders) As %Boolean
{
    Set tName = ""
    For {
        Set tName = $Order(pHeaders(tName))
        If tName = "" Quit
        If $Extract($ZConvert(tName, "U"), 1, 21) = "ACCESS-CONTROL-ALLOW-" Quit
    }
    Quit (tName '= "")
}

/// <p>The value of one response header, by name, case-insensitively.</p>
ClassMethod HeaderValue(ByRef pHeaders, pName As %String) As %String
{
    Set tWanted = $ZConvert(pName, "U")
    Set tName = ""
    For {
        Set tName = $Order(pHeaders(tName))
        If tName = "" Quit
        If $ZConvert(tName, "U") = tWanted Quit
    }
    If tName = "" Quit ""
    Quit $Get(pHeaders(tName))
}

/// <p>POST to one of the token endpoints and hand back the status, the parsed body and the
/// response headers. <var>pCookie</var> and <var>pBearer</var> are sent only when non-empty,
/// so one helper expresses the credentialled, the cookie-only and the bare request.</p>
ClassMethod PostToken(pEndpoint As %String, pRequestBody As %String, pCookie As %String, pBearer As %String, Output pStatus As %Integer, Output pRaw As %String, Output pHeaders) As %Status
{
    Kill tExtra
    If pCookie '= "" Set tExtra("Cookie") = ..#BROWSERCOOKIE _ "=" _ pCookie
    If pBearer '= "" Set tExtra("Authorization") = "Bearer " _ pBearer
    Set tContentType = $Select(pRequestBody = "": "", 1: "application/json")
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIPATH _ "/" _ pEndpoint, "", "", .pStatus, .pRaw, .pHeaders, pRequestBody, tContentType, .tExtra)
}

/// <p>A JSON login body for the throwaway principal. The field names are
/// <code>user</code> and <code>password</code>, not <code>username</code>.</p>
Method LoginBody() As %String
{
    Set tObj = {}
    Do tObj.%Set("user", ..#TOKENUSER)
    Do tObj.%Set("password", ..PreparedPassword)
    Quit tObj.%ToJSON()
}

/// <p>GET the API root carrying <var>pBearer</var>, or nothing when it is empty.</p>
ClassMethod GetApiRoot(pBearer As %String, Output pStatus As %Integer, Output pRaw As %String, Output pHeaders) As %Status
{
    Kill tExtra
    If pBearer '= "" Set tExtra("Authorization") = "Bearer " _ pBearer
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#APIPATH _ "/", "", "", .pStatus, .pRaw, .pHeaders, "", "", .tExtra)
}

/// <p>AC "silent mint", both halves in one method because the second depends on the cookie
/// the first is issued: a JSON-body login mints a pair and returns
/// <code>Set-Cookie: CSPBrowserId=...; path=/</code>, and that cookie <b>alone</b> mints a
/// fresh pair for the same user on a second, empty-body request.</p>
/// <p><code>path=/</code> is the load-bearing half of the cookie. That it therefore reaches
/// every <code>%ISCMgtPortal</code> application, so a user already signed in to the classic
/// portal never sees OcuPilot's form, is an <i>(inference)</i> from the cookie's path and
/// the shared <code>GroupById</code>: what this method observes is one application minting
/// from the cookie it was issued. No second JWT-enabled application exists on the instance
/// to probe the crossing directly.</p>
/// <p>Mutation: send the empty-body request without the <code>Cookie</code> header -> the
/// silent mint answers 401 and the second half goes red.</p>
Method TestAJsonLoginMintsAPairAndItsCookieMintsSilently()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the throwaway principal")

    Set tSC = ..PostToken("login", ..LoginBody(), "", "", .tStatus, .tRaw, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the login request completes")
    Do $$$AssertEquals(tStatus, 200, "a JSON body {user, password} is accepted")
    Do $$$AssertEquals(..HasCorsAllowance(.tHeaders), 0, "and the response carries no Access-Control-Allow-* header")

    Set tPair = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertNotEquals(tPair.%Get("access_token"), "", "the pair carries an access token")
    Do $$$AssertNotEquals(tPair.%Get("refresh_token"), "", "and a refresh token")
    Do $$$AssertEquals(tPair.%Get("sub"), ..#TOKENUSER, "minted for the principal that signed in")
    ; The client reads exp to decide whether to renew before sending; a pair without one
    ; makes every call renew first, and each renewal rotates. So the field is pinned here.
    Set tIat = tPair.%Get("iat")
    Set tExp = tPair.%Get("exp")
    Do $$$AssertTrue((tIat '= "") && (tIat = +tIat), "the pair carries a numeric iat: " _ tIat)
    Do $$$AssertTrue((tExp '= "") && (tExp = +tExp), "and a numeric exp: " _ tExp)
    Do $$$AssertTrue(tExp > tIat, "which is in the future relative to iat")

    ; The header's VALUE never reaches an assertion message. This cookie alone mints a
    ; token pair for the principal (the next request below proves exactly that), and
    ; %UnitTest.Manager.LogAssert persists every description into ^UnitTest.Result and
    ; prints it, on pass as well as on failure -- so echoing it would write a live
    ; credential into a log OcuPilot's own screens later read (AD-35).
    Set tSetCookie = ..HeaderValue(.tHeaders, "Set-Cookie")
    Do $$$AssertTrue(tSetCookie [ (..#BROWSERCOOKIE _ "="), "the response sets the browser-level cookie")

    ; path=/ is asserted against this cookie's own attribute list rather than the whole
    ; header value. %Net.HttpResponse joins repeated headers with a comma into one node
    ; (irislib/%Net/HttpResponse.cls:52), so on the raw header a second Set-Cookie's
    ; path=/ would satisfy the assertion while CSPBrowserId itself was scoped to the
    ; application path -- and path=/ is what shares the login across the 25
    ; %ISCMgtPortal applications, which is the whole silent-mint design.
    Set tCookieSegment = $Piece(tSetCookie, ..#BROWSERCOOKIE _ "=", 2)
    Set tCookie = $Piece(tCookieSegment, ";", 1)
    Set tAttributes = $ZConvert($Piece(tCookieSegment, ";", 2, *), "L")
    Do $$$AssertNotEquals(tCookie, "", "the cookie has a value to replay")
    Do $$$AssertTrue(tAttributes [ "path=/", "at path=/, which is what shares it across every %ISCMgtPortal application")

    Set tSC2 = ..PostToken("login", "", tCookie, "", .tStatus2, .tRaw2, .tHeaders2)
    Do $$$AssertStatusOK(tSC2, "the silent probe completes")
    Do $$$AssertEquals(tStatus2, 200, "an empty-body login carrying only that cookie mints silently")
    If tStatus2 = 200 {
        Set tPair2 = ##class(%DynamicObject).%FromJSON(tRaw2)
        Do $$$AssertEquals(tPair2.%Get("sub"), ..#TOKENUSER, "for the same user, with no credentials on the wire")
        Do ..Logout(tPair2.%Get("access_token"))
    }
    Do ..Logout(tPair.%Get("access_token"))
}

/// <p>AC "cold browser" — an empty-body login with no cookie and no credentials is refused,
/// and the refusal tells a client nothing: 401, a zero-length body and no
/// <code>WWW-Authenticate</code> challenge. Every 401 on this path is this response, which
/// is why the client's classifier reads a 401 from <code>/login</code> as a credential
/// failure and everything else as "not a credential failure" (DW-1).</p>
Method TestAColdBrowserIsRefusedWithAnEmptyBody()
{
    Set tSC = ..PostToken("login", "", "", "", .tStatus, .tRaw, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes at the transport level")
    Do $$$AssertEquals(tStatus, 401, "no cookie and no credentials is a refusal")
    Do $$$AssertEquals($ZStrip(tRaw, "<>W"), "", "with a zero-length body")
    Do $$$AssertEquals(..HeaderValue(.tHeaders, "WWW-Authenticate"), "", "and no WWW-Authenticate challenge")
    Do $$$AssertEquals(..HasCorsAllowance(.tHeaders), 0, "and no Access-Control-Allow-* header")
}

/// <p>AC "form rejected" — a wrong password is the same 401 with the same empty body, so the
/// client cannot distinguish it from an unknown user or a dead cookie. This is why the
/// classifier keys on <b>where</b> the 401 came from, never on what it says.</p>
Method TestAWrongPasswordIsTheSameRefusal()
{
    Set tObj = {}
    Do tObj.%Set("user", ..#TOKENUSER)
    Do tObj.%Set("password", "definitely-not-the-password")
    Set tSC = ..PostToken("login", tObj.%ToJSON(), "", "", .tStatus, .tRaw, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 401, "a wrong password is refused")
    Do $$$AssertEquals($ZStrip(tRaw, "<>W"), "", "with the same zero-length body as every other 401 on this path")
}

/// <p>AC "refresh rotation" — a successful refresh takes the refresh token in the JSON body
/// and invalidates <b>both</b> old tokens, in place on the same <code>sid</code>
/// (<class>%SYS.TokenAuth</class> holds one access/refresh hash pair per row). The old
/// access token dying, rather than merely being superseded, is what makes DW-4 a
/// single-flight problem and not a retry-on-401 one.</p>
Method TestARefreshRotatesBothTokens()
{
    Set tSC = ..PostToken("login", ..LoginBody(), "", "", .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the login mints a pair")
    If tStatus '= 200 Quit
    Set tPair = ##class(%DynamicObject).%FromJSON(tRaw)
    Set tOldAccess = tPair.%Get("access_token")
    Set tOldRefresh = tPair.%Get("refresh_token")

    Set tBody = {}
    Do tBody.%Set("refresh_token", tOldRefresh)
    Set tSC2 = ..PostToken("refresh", tBody.%ToJSON(), "", "", .tStatus2, .tRaw2, .tHeaders2)
    Do $$$AssertStatusOK(tSC2, "the refresh completes")
    Do $$$AssertEquals(tStatus2, 200, "a refresh token in the JSON body is accepted")
    If tStatus2 '= 200 Quit
    Set tNew = ##class(%DynamicObject).%FromJSON(tRaw2)
    Set tNewAccess = tNew.%Get("access_token")
    Do $$$AssertNotEquals(tNewAccess, tOldAccess, "the refresh issues a new access token")
    Do $$$AssertNotEquals(tNew.%Get("refresh_token"), tOldRefresh, "and a new refresh token")

    Do ..GetApiRoot(tOldAccess, .tStatus3, .tRaw3, .tHeaders3)
    Do $$$AssertEquals(tStatus3, 401, "the OLD access token is dead, not merely superseded")

    Do ..GetApiRoot(tNewAccess, .tStatus4, .tRaw4, .tHeaders4)
    Do $$$AssertEquals(tStatus4, 404, "while the new access token clears the whole gate chain")

    Do ..Logout(tNewAccess)
}

/// <p><b>Replaying a rotated refresh token revokes the whole session</b> — the pair the
/// successful refresh had just issued dies with it. Found on the live instance while writing
/// this suite, and it is the sharp reason DW-4 needs single-flight rather than
/// retry-on-401: a second caller refreshing with the stale token does not merely fail, it
/// destroys the session the first caller established, and every other in-flight request
/// then 401s with nothing left to refresh.</p>
/// <p>The sequence matters. The new access token is exercised <b>before</b> the replay, so
/// its later 401 is attributable to the replay and not to the rotation.</p>
/// <p>Mutation: move the replay above the first <code>GetApiRoot</code> -> the "before"
/// assertion goes red, which is the control that makes the revocation claim readable.</p>
Method TestReplayingARotatedRefreshTokenRevokesTheSession()
{
    Set tSC = ..PostToken("login", ..LoginBody(), "", "", .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the login mints a pair")
    If tStatus '= 200 Quit
    Set tPair = ##class(%DynamicObject).%FromJSON(tRaw)
    Set tStale = {}
    Do tStale.%Set("refresh_token", tPair.%Get("refresh_token"))

    Set tSC2 = ..PostToken("refresh", tStale.%ToJSON(), "", "", .tStatus2, .tRaw2, .tHeaders2)
    Do $$$AssertEquals(tStatus2, 200, "the first refresh succeeds")
    If tStatus2 '= 200 Quit
    Set tNew = ##class(%DynamicObject).%FromJSON(tRaw2)
    Set tNewAccess = tNew.%Get("access_token")
    Set tFresh = {}
    Do tFresh.%Set("refresh_token", tNew.%Get("refresh_token"))

    Do ..GetApiRoot(tNewAccess, .tStatus3, .tRaw3, .tHeaders3)
    Do $$$AssertEquals(tStatus3, 404, "before the replay, the new access token works")

    Do ..PostToken("refresh", tStale.%ToJSON(), "", "", .tStatus4, .tRaw4, .tHeaders4)
    Do $$$AssertEquals(tStatus4, 401, "replaying the rotated refresh token is refused")

    Do ..GetApiRoot(tNewAccess, .tStatus5, .tRaw5, .tHeaders5)
    Do $$$AssertEquals(tStatus5, 401, "and the replay killed the new access token with it")

    Do ..PostToken("refresh", tFresh.%ToJSON(), "", "", .tStatus6, .tRaw6, .tHeaders6)
    Do $$$AssertEquals(tStatus6, 401, "the new refresh token is gone too -- the session is revoked, not just rotated")
}

/// <p>AC "refresh as Bearer" — the refresh token presented in
/// <code>Authorization: Bearer</code> with no body is refused. AD-28 states this; the client
/// treats such a refusal as a failed refresh, so the rule has to hold on the instance rather
/// than only in the design.</p>
Method TestARefreshTokenSentAsABearerIsRefused()
{
    Set tSC = ..PostToken("login", ..LoginBody(), "", "", .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the login mints a pair")
    If tStatus '= 200 Quit
    Set tPair = ##class(%DynamicObject).%FromJSON(tRaw)

    Do ..PostToken("refresh", "", "", tPair.%Get("refresh_token"), .tStatus2, .tRaw2, .tHeaders2)
    Do $$$AssertEquals(tStatus2, 401, "a refresh token sent as a Bearer, with no body, is refused")

    Set tBody = {}
    Do tBody.%Set("refresh_token", tPair.%Get("refresh_token"))
    Do ..PostToken("refresh", tBody.%ToJSON(), "", "", .tStatus3, .tRaw3, .tHeaders3)
    Do $$$AssertEquals(tStatus3, 200, "while the same token in the body is accepted -- the positive control")
    If tStatus3 = 200 {
        Set tNew = ##class(%DynamicObject).%FromJSON(tRaw3)
        Do ..Logout(tNew.%Get("access_token"))
    }
}

/// <p>AC "browser-level sign-in shared" — <code>/logout</code> is per-<code>sid</code>: it
/// kills the session whose Bearer it carries and leaves a sibling session, minted from the
/// same account, live. Two tabs therefore hold two independent sessions, which is what
/// per-tab token storage depends on.</p>
Method TestLogoutIsPerSidAndLeavesASiblingLive()
{
    Set tSC = ..PostToken("login", ..LoginBody(), "", "", .tStatusA, .tRawA, .tHeadersA)
    Set tSC2 = ..PostToken("login", ..LoginBody(), "", "", .tStatusB, .tRawB, .tHeadersB)
    Do $$$AssertEquals(tStatusA, 200, "the first session mints")
    Do $$$AssertEquals(tStatusB, 200, "the second session mints")
    If (tStatusA '= 200) || (tStatusB '= 200) Quit
    Set tPairA = ##class(%DynamicObject).%FromJSON(tRawA)
    Set tPairB = ##class(%DynamicObject).%FromJSON(tRawB)
    Set tA = tPairA.%Get("access_token")
    Set tB = tPairB.%Get("access_token")
    Do $$$AssertNotEquals(tA, tB, "the two sessions are distinct")

    Do ..GetApiRoot(tA, .tS1, .tR1, .tH1)
    Do ..GetApiRoot(tB, .tS2, .tR2, .tH2)
    Do $$$AssertEquals(tS1, 404, "both tokens reach dispatch before the logout")
    Do $$$AssertEquals(tS2, 404, "both tokens reach dispatch before the logout")

    Do ..PostToken("logout", "", "", tA, .tS3, .tR3, .tH3)
    Do $$$AssertEquals(tS3, 200, "the logout is accepted")

    Do ..GetApiRoot(tA, .tS4, .tR4, .tH4)
    Do ..GetApiRoot(tB, .tS5, .tR5, .tH5)
    Do $$$AssertEquals(tS4, 401, "the logged-out session's token is dead")
    Do $$$AssertEquals(tS5, 404, "and the sibling session is untouched")

    Do ..Logout(tB)
}

/// <p>AC "Bearer only" — the wire anchor. A minted access token sent as
/// <code>Authorization: Bearer</code> authenticates past the install gate, the anonymous
/// rejection and the administrative gate and is answered by the framework 404 <b>in
/// OcuPilot's own envelope</b>; the same request with no header is refused with a bare 401
/// before dispatch, so no OcuPilot code runs. The envelope is the proof that the Bearer got
/// all the way through: a 401 carries no envelope at all.</p>
/// <p>Neither response may carry an <code>Access-Control-Allow-*</code> header
/// (<parameter>OcuPilot.Api.Router.HandleCorsRequest</parameter> is 0).</p>
/// <p>Mutation: delete <code>Parameter HandleCorsRequest = 0</code> from
/// <class>OcuPilot.Api.Router</class> -> the CORS assertions still hold today, because no
/// route declares <code>Cors="true"</code>; what goes red is the parameter assertion below,
/// which is the falsifiable half.</p>
Method TestTheBearerAuthenticatesPastTheWholeGateChain()
{
    Set tSC = ..PostToken("login", ..LoginBody(), "", "", .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the login mints a pair")
    If tStatus '= 200 Quit
    Set tPair = ##class(%DynamicObject).%FromJSON(tRaw)
    Set tAccess = tPair.%Get("access_token")

    Do ..GetApiRoot(tAccess, .tStatus2, .tRaw2, .tHeaders2)
    Do $$$AssertEquals(tStatus2, 404, "the Bearer clears every gate and finds no route")
    Do $$$AssertEquals((tRaw2 [ "}{"), 0, "exactly one envelope reaches the wire")
    Set tObj = ##class(%DynamicObject).%FromJSON(tRaw2)
    Do $$$AssertEquals(tObj.%Get("code"), "ROUTE.NOTFOUND", "rendered in OcuPilot's own envelope")
    Do $$$AssertEquals(..HasCorsAllowance(.tHeaders2), 0, "with no Access-Control-Allow-* header")

    Do ..GetApiRoot("", .tStatus3, .tRaw3, .tHeaders3)
    Do $$$AssertEquals(tStatus3, 401, "the same request with no header is refused before dispatch")
    Do $$$AssertEquals($ZStrip(tRaw3, "<>W"), "", "with an empty body -- no OcuPilot code ran, so there is no envelope")
    Do $$$AssertEquals(..HasCorsAllowance(.tHeaders3), 0, "and no Access-Control-Allow-* header")

    Do ..Logout(tAccess)
}

/// <p>AD-47 — CORS processing is off unconditionally on <b>both</b> dispatch classes, stated
/// as a parameter rather than delegated to a route attribute. This is the falsifiable form:
/// absence of an <code>Access-Control-Allow-*</code> header today is also what an
/// unspecified parameter and a route table with no <code>Cors="true"</code> produce.</p>
/// <p>Mutation: delete either parameter, or set it to 1 -> this goes red.</p>
Method TestNeitherDispatchClassEnablesCors()
{
    Do $$$AssertEquals(##class(OcuPilot.Api.Router).#HandleCorsRequest, 0, "the API router refuses CORS processing unconditionally")
    Do $$$AssertEquals(##class(OcuPilot.Api.StaticHandler).#HandleCorsRequest, 0, "and so does the static handler")
}

/// <p>End the session <var>pAccess</var> belongs to, so no test leaves a live
/// <code>sid</code> on the instance. Best effort: a failure here is not the subject of any
/// test, and the tokens expire on their own.</p>
ClassMethod Logout(pAccess As %String)
{
    If pAccess = "" Quit
    Do ..PostToken("logout", "", "", pAccess, .tStatus, .tRaw, .tHeaders)
    Quit
}

}
