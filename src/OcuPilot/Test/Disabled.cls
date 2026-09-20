/// <p>DW-444 over the real wire (Story 5.4, AC7): an account disabled <b>after</b> its token pair
/// was issued is refused 401 <code>AUTH.DISABLED</code> on every dispatched
/// <code>/api/ocupilot</code> route, and so is a pair <code>/refresh</code> has since minted for
/// it.</p>
/// <p><b>The refusal is at use, not at the mint, and that is measured rather than assumed.</b> The
/// four token paths are handled by the CSP server before <code>DispatchRequest</code>
/// (<file>irissys/%CSP/REST.cls</file>), so OcuPilot has no hook at which to refuse a disabled
/// account a pair. What this class pins is the sequence that makes the hole inert: the vendor
/// still mints, and the minted pair is refused at its first use.</p>
/// <p><b>It creates and disables IRIS principals, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>), and <method>OnBeforeAllTests</method> refuses anywhere
/// <parameter>ARMINGVARIABLE</parameter> does not arm it. The account's password is generated for
/// the run and never written to source; the account and its role are removed in
/// <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.Disabled Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The REST API application these tests address, absolute from the origin root.</p>
Parameter APIPATH = "/api/ocupilot";

/// <p>The principal whose account is disabled mid-run.</p>
Parameter DISABLEDUSER = "OcuPilotDisabledPrincipal";

/// <p>See <parameter>DISABLEDUSER</parameter>.</p>
Parameter DISABLEDROLE = "OcuPilotDisabledRole";

/// <p>The one administrative resource the role grants, so a request by this account clears the
/// API's own instance-level gate and the account's <code>Enabled</code> flag is the only thing
/// left to refuse it. <code>%Admin_Operate</code>, never <code>%Operator</code>.</p>
Parameter ADMINRESOURCE = "%Admin_Operate";

/// <p>The routes a disabled account is asked for: every one is dispatched, so every one meets
/// <method>OcuPilot.Api.Router.OnPreDispatch</method>.</p>
Parameter ROUTES = "/navigation,/agent/switches,/agent/definitions,/logs/errors/namespaces";

/// <p>A turn identifier no turn carries, used to ask for a progress poll that the handler would
/// answer as unknown.</p>
Parameter ABSENTTURN = "ocupilotdisabledabsentturn";

/// <p>The account's password for this run. Prefix deliberately not "Test".</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back the account's resource and its enabled
/// state.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

/// <p>Leave the account enabled whatever a test did to it. A method that raises between
/// <method>SetEnabled</method> 0 and its re-enable would otherwise hand the next method a
/// disabled account and fail it for an unrelated reason.</p>
Method OnAfterOneTest() As %Status
{
    Do ..SetEnabled(1)
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.Disabled creates, disables and deletes IRIS users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotDisabled" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

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

        Kill tProps
        Set tGetSC = ##class(Security.Users).Get(..#DISABLEDUSER, .tProps)
        Set ..PreparedSetupOk = $$$ISOK(tGetSC) && (+$Get(tProps("Enabled")) = 1) && ($SYSTEM.Security.CheckUserPermission(..#DISABLEDUSER, ..#ADMINRESOURCE, "USE") = 1)
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the principal exists, is enabled and holds " _ ..#ADMINRESOURCE)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        If ##class(Security.Users).Exists(..#DISABLEDUSER, .tU, .tUS) Do ##class(Security.Users).Delete(..#DISABLEDUSER)
        If ##class(Security.Users).Exists(..#DISABLEDUSER, .tU2, .tUS2) Set tLeft = "user " _ ..#DISABLEDUSER
        If ##class(Security.Roles).Exists(..#DISABLEDROLE, .tR, .tRS) Do ##class(Security.Roles).Delete(..#DISABLEDROLE)
        If ##class(Security.Roles).Exists(..#DISABLEDROLE, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ ..#DISABLEDROLE
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.Disabled teardown left throwaway objects on the instance: " _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create (or re-grant) the throwaway role and the account that holds it, enabled.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
Method EnsurePrincipal(pResources As %String) As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(..#DISABLEDROLE, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tModProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(..#DISABLEDROLE, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(..#DISABLEDROLE, "OcuPilot test: disabled-account principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(..#DISABLEDUSER, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(..#DISABLEDUSER)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(..#DISABLEDUSER, ..#DISABLEDROLE, ..PreparedPassword, "OcuPilot disabled-account test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.Disabled; deleted in OnAfterAllTests")
}

/// <p>Set the account's <code>Enabled</code> flag to <var>pEnabled</var>, and answer whether the
/// instance read it back that way.</p>
Method SetEnabled(pEnabled As %Boolean) As %Boolean
{
    Set tOk = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Kill tProps
        Set tProps("Enabled") = pEnabled
        Set tSC = ##class(Security.Users).Modify(..#DISABLEDUSER, .tProps)
        If $$$ISERR(tSC) Quit
        Kill tRead
        Set tSC = ##class(Security.Users).Get(..#DISABLEDUSER, .tRead)
        If $$$ISERR(tSC) Quit
        Set tOk = (+$Get(tRead("Enabled")) = +pEnabled)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOk = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit tOk
}

/// <p>POST to one of the API's token endpoints, unauthenticated: the refresh token travels in
/// the JSON body (AD-28), never as a Bearer.</p>
ClassMethod PostToken(pEndpoint As %String, pRequestBody As %String, Output pStatus As %Integer, Output pRaw As %String) As %Status
{
    Kill tExtra
    Set tContentType = $Select(pRequestBody = "": "", 1: "application/json")
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIPATH _ "/" _ pEndpoint, "", "", .pStatus, .pRaw, .tHeaders, pRequestBody, tContentType, .tExtra)
}

/// <p>GET <var>pRoute</var> under the API application carrying <var>pBearer</var>, as
/// <code>&lt;status&gt;|&lt;code&gt;</code>.</p>
ClassMethod GetAs(pRoute As %String, pBearer As %String) As %String
{
    Kill tExtra
    If pBearer '= "" Set tExtra("Authorization") = "Bearer " _ pBearer
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#APIPATH _ pRoute, "", "", .tStatus, .tBody, .tHeaders, "", "", .tExtra)
    If $$$ISERR(tSC) Quit "requestfailed|"
    Set tCode = ""
    Try {
        Set tAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
        If $IsObject(tAnswer) Set tCode = tAnswer.%Get("code")
    } Catch {
        Set tCode = ""
    }
    Quit tStatus _ "|" _ tCode
}

/// <p>A JSON login body for the throwaway principal.</p>
Method LoginBody() As %String
{
    Set tObj = {}
    Do tObj.%Set("user", ..#DISABLEDUSER)
    Do tObj.%Set("password", ..PreparedPassword)
    Quit tObj.%ToJSON()
}

/// <p>Sign in and answer the minted pair, or <code>""</code>.</p>
Method SignIn() As %DynamicObject
{
    Set tSC = ..PostToken("login", ..LoginBody(), .tStatus, .tRaw)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tRaw)
}

/// <p><b>AC7</b> -- a pair issued while the account was enabled is refused on every dispatched
/// route once the account is disabled, and a pair <code>/refresh</code> mints afterwards is
/// refused the same way.</p>
/// <p>Mutation (Rule 19): remove the disabled branch from
/// <method>OcuPilot.Api.Router.OnPreDispatch</method> -> every leg below answers 200 and this goes
/// red.</p>
Method TestADisabledAccountsTokenIsRefused()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal is enabled and administratively admitted")

    Set tPair = ..SignIn()
    Do $$$AssertTrue($IsObject(tPair), "the enabled account signs in")
    If '$IsObject(tPair) Quit
    Set tAccess = tPair.%Get("access_token")
    Set tRefresh = tPair.%Get("refresh_token")
    Do $$$AssertNotEquals(tAccess, "", "and is issued an access token")

    ; The control: while the account is enabled, the same pair is served. Without this the
    ; refusals below could be a principal that never had access at all.
    For tI = 1:1:$Length(..#ROUTES, ",") {
        Set tRoute = $Piece(..#ROUTES, ",", tI)
        Set tAnswer = ..GetAs(tRoute, tAccess)
        Do $$$AssertNotEquals($Piece(tAnswer, "|", 1), 401, tRoute _ ": is served while the account is enabled: " _ tAnswer)
    }

    Do $$$AssertTrue(..SetEnabled(0), "the account is disabled and the instance reads it back disabled")

    For tI = 1:1:$Length(..#ROUTES, ",") {
        Set tRoute = $Piece(..#ROUTES, ",", tI)
        Do $$$AssertEquals(..GetAs(tRoute, tAccess), "401|" _ ##class(OcuPilot.Kernel.Identity).#AUTHDISABLED, tRoute _ ": the already-issued pair is refused 401 AUTH.DISABLED")
    }

    ; The /refresh half: the vendor mints for a disabled account -- not preventable from OcuPilot
    ; code, because the CSP server handles that path before DispatchRequest -- and the pair it
    ; mints is inert, because every route it can be presented to refuses it.
    Set tBody = {}
    Do tBody.%Set("refresh_token", tRefresh, "string")
    Set tSC = ..PostToken("refresh", tBody.%ToJSON(), .tRefreshStatus, .tRefreshRaw)
    Do $$$AssertStatusOK(tSC, "the refresh request completes")
    If tRefreshStatus = 200 {
        Set tNewPair = ##class(%DynamicObject).%FromJSON(tRefreshRaw)
        Do $$$AssertNotEquals(tNewPair.%Get("access_token"), "", "the vendor still mints a pair for a disabled account -- a named limitation, not a defect this story can fix")
        Do $$$AssertEquals(..GetAs("/navigation", tNewPair.%Get("access_token")), "401|" _ ##class(OcuPilot.Kernel.Identity).#AUTHDISABLED, "and the newly minted pair is refused at its first use")
    } Else {
        ; The branch condition already says the status is not 200, so asserting that again would
        ; assert nothing. What is worth pinning is that the refusal is a refusal rather than a
        ; fault: a 5xx here would be the endpoint breaking, which closes no hole.
        Do $$$AssertTrue((tRefreshStatus >= 400) && (tRefreshStatus < 500), "the instance refused the refresh itself, which closes the hole one step earlier -- and refused it rather than failing: " _ tRefreshStatus)
    }

    Do $$$AssertTrue(..SetEnabled(1), "the account is re-enabled for the teardown")
}

/// <p><b>AC7</b> -- a disabled account's progress poll is refused, which is what bounds a turn it
/// left running. Only the turn owner's authenticated polls renew the 120 s lease (AD-31), so a
/// poll that answers 401 cannot renew it; the lapse itself, and the abandon at the next step
/// boundary, are pinned by <method>OcuPilot.Test.TurnLong.TestALapsedLeaseAbandonsTheTurn</method>
/// and <method>OcuPilot.Test.TurnLoop.TestTheLeaseAndTheWallClockAbandonTheTurn</method>.</p>
/// <p>The turn id is fabricated on purpose: the refusal is <method>OnPreDispatch</method>'s and
/// runs before the handler resolves ownership, so the same id answers 404 while the account is
/// enabled and 401 once it is not. A poll that still reached the handler would answer 404 in both
/// states, which is why the enabled leg is asserted too.</p>
/// <p>Mutation (Rule 19): remove the disabled branch from
/// <method>OcuPilot.Api.Router.OnPreDispatch</method> -> the disabled leg answers 404 and this goes
/// red.</p>
Method TestADisabledAccountsProgressPollIsRefused()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal is enabled and administratively admitted")

    Set tPair = ..SignIn()
    Do $$$AssertTrue($IsObject(tPair), "the enabled account signs in")
    If '$IsObject(tPair) Quit
    Set tAccess = tPair.%Get("access_token")

    Set tRoute = "/turn/" _ ..#ABSENTTURN _ "/progress"
    Do $$$AssertEquals(..GetAs(tRoute, tAccess), "404|" _ ##class(OcuPilot.Api.Error).#TURNNOTFOUND, "while enabled, the poll reaches the handler and is answered as an unknown turn")

    Do $$$AssertTrue(..SetEnabled(0), "the account is disabled and the instance reads it back disabled")
    Do $$$AssertEquals(..GetAs(tRoute, tAccess), "401|" _ ##class(OcuPilot.Kernel.Identity).#AUTHDISABLED, "and once disabled the poll is refused before the handler runs, so it renews no lease")

    Do $$$AssertTrue(..SetEnabled(1), "the account is re-enabled for the teardown")
}

/// <p><b>AC7</b> -- an <code>Enabled</code> flag the identity read could not read refuses, never
/// admits. A read that answered nothing says nothing about whether the account is enabled.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Identity.IsEnabled</method> admit when
/// <method>OcuPilot.Kernel.State.Base.GuardedUserEnabled</method> answers <var>pKnown</var> 0 ->
/// this goes red.</p>
Method TestAnUnreadableEnabledFlagRefuses()
{
    ; The fixture answers "enabled" and "could not read it" together, which is the one shape no
    ; instance produces on demand.
    Do $$$AssertEquals(##class(OcuPilot.Test.IdentityUnknownState).GuardedUserEnabled(..#DISABLEDUSER, .tKnown), 1, "the fixture answers enabled")
    Do $$$AssertEquals(tKnown, 0, "while reporting the flag was not read")
    Do $$$AssertEquals(##class(OcuPilot.Test.IdentityProbe).IsEnabled(..#DISABLEDUSER), 0, "so the policy face refuses: an unreadable flag is not an admission")

    ; The control: the shipped read of a real enabled account admits, so the refusal above is
    ; about the unreadable flag and not about the class refusing everything.
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Identity).IsEnabled(..#DISABLEDUSER), 1, "while the real read of the same enabled account admits")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Identity).IsEnabled("OcuPilotNoSuchAccountAtAll"), 0, "and an account the instance does not hold is refused")
}

}
