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
    ; The identity pair is instance-wide: a method that raised between breaking it and repairing
    ; it would leave every route on this container answering 503 for every account, including
    ; every later class in the sweep.
    Do ..SetIdentityApplicationEnabled(1)
    Do ..SetIdentityRoleResources(##class(OcuPilot.Kernel.State.Base).#IDENTITYRESOURCES)
    Quit $$$OK
}

/// <p>Set the identity privileged routine application's <code>Enabled</code> flag, and answer
/// whether the instance read it back that way.</p>
Method SetIdentityApplicationEnabled(pEnabled As %Boolean) As %Boolean
{
    Set tOk = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tName = ##class(OcuPilot.Kernel.State.Base).#IDENTITYAPPLICATION
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Kill tProps
        Set tProps("Enabled") = pEnabled
        Set tSC = ##class(Security.Applications).Modify(tName, .tProps)
        If $$$ISERR(tSC) Quit
        Kill tRead
        Set tSC = ##class(Security.Applications).Get(tName, .tRead)
        If $$$ISERR(tSC) Quit
        Set tOk = (+$Get(tRead("Enabled")) = +pEnabled)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOk = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit tOk
}

/// <p>Set the identity role's <code>Resources</code>, and answer whether the instance read them
/// back. Used to drive the case <method>Security.Applications.Modify</method> cannot:
/// <code>AddRoles</code> still succeeds and the frame still gains the role, but the role no
/// longer carries what the read needs.</p>
Method SetIdentityRoleResources(pResources As %String) As %Boolean
{
    Set tOk = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tRole = ##class(OcuPilot.Kernel.State.Base).#IDENTITYAPPLICATION
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Kill tProps
        Set tProps("Resources") = pResources
        Set tProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(tRole, .tProps)
        If $$$ISERR(tSC) Quit
        Kill tRead
        Set tSC = ##class(Security.Roles).Get(tRole, .tRead)
        If $$$ISERR(tSC) Quit
        Set tOk = ($Get(tRead("Resources")) = pResources)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOk = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit tOk
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
        ; Not 401 alone would be satisfied by a principal that never had working access -- a 403
        ; at the administrative gate, or an anonymous request whose token never arrived, would
        ; both pass it. These name the two states that would make the refusals below vacuous.
        Do $$$AssertNotEquals($Piece(tAnswer, "|", 2), ##class(OcuPilot.Api.Error).#AUTHANONYMOUS, tRoute _ ": the token authenticated: " _ tAnswer)
        Do $$$AssertNotEquals($Piece(tAnswer, "|", 2), ##class(OcuPilot.Api.Error).#AUTHNOADMIN, tRoute _ ": and cleared the administrative gate: " _ tAnswer)
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

/// <p><b>AD-38, added at Story 5.4's code review.</b> A broken identity escalation refuses every
/// account on the instance. It must not be reported as <code>AUTH.DISABLED</code>: that names the
/// wrong cause, offers no repair, and is indistinguishable from the account genuinely being
/// disabled -- so a total lockout reads to an operator as "everyone was disabled at once". It is
/// answered as AD-38's 503 <code>INSTALL.UNREADABLE</code>, whose sentence names the repair.</p>
/// <p>Two faults, because they fail at different points: an application that is absent or
/// disabled (<code>AddRoles</code> refuses) and a role that no longer grants
/// <parameter>OcuPilot.Kernel.State.Base.IDENTITYRESOURCES</parameter> (<code>AddRoles</code>
/// succeeds and the read is still denied). The second is what
/// <method>OcuPilot.Kernel.State.Base.IdentityGrantsInEffect</method> exists for.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Identity.IsEnabled</method> report
/// <var>pUnavailable</var> 0 unconditionally, or delete the <code>tIdentityUnavailable</code>
/// branch from <method>OcuPilot.Api.Router.OnPreDispatch</method> -> both faults answer
/// <code>401|AUTH.DISABLED</code> and this goes red. Removing the
/// <method>IdentityGrantsInEffect</method> call alone reddens the role leg only.</p>
Method TestABrokenIdentityEscalationIsNotReportedAsADisabledAccount()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal")
    Set tPair = ..SignIn()
    Do $$$AssertTrue($IsObject(tPair), "the enabled account signs in")
    If '$IsObject(tPair) Quit
    Set tAccess = tPair.%Get("access_token")
    Do $$$AssertNotEquals(tAccess, "", "and is issued an access token")
    ; The absent-turn progress poll, for the reason TestADisabledAccountsProgressPollIsRefused
    ; uses it: while the request is served it answers a deterministic 404 from the handler, so
    ; "served" and "refused before the handler" are told apart by the answer itself rather than
    ; by a not-401 that any error would satisfy.
    Set tRoute = "/turn/" _ ..#ABSENTTURN _ "/progress"
    Set tServed = "404|" _ ##class(OcuPilot.Api.Error).#TURNNOTFOUND

    ; The control: with the escalation intact the same token on the same route reaches the
    ; handler, so every refusal below is about the fault this method induces and nothing else.
    Do $$$AssertEquals(..GetAs(tRoute, tAccess), tServed, "with the identity escalation intact the request reaches the handler")

    ; Fault one: the privileged routine application is disabled, so AddRoles refuses.
    Do $$$AssertTrue(..SetIdentityApplicationEnabled(0), "the identity routine application is disabled and the instance reads it back disabled")
    Set tAnswer = ..GetAs(tRoute, tAccess)
    Do $$$AssertEquals(tAnswer, "503|" _ ##class(OcuPilot.Api.Error).#INSTALLUNREADABLE, "a disabled identity application answers AD-38's unreadable refusal, which names the repair")
    Do $$$AssertNotEquals($Piece(tAnswer, "|", 2), ##class(OcuPilot.Kernel.Identity).#AUTHDISABLED, "and never AUTH.DISABLED, which would name the account as the cause")
    Do $$$AssertTrue(..SetIdentityApplicationEnabled(1), "the identity routine application is repaired")
    Do $$$AssertEquals(..GetAs(tRoute, tAccess), tServed, "and the same token reaches the handler again, so the refusal was the fault and not the token")

    ; Fault two: the application is enabled and AddRoles succeeds, but the role no longer carries
    ; the resources the read needs. This is the drift AddRoles cannot report.
    ; %DB_IRISSYS:R is deliberately left in place: without it the read raises <PROTECT> and the
    ; Catch would answer "unavailable" anyway. Dropping only %Admin_Secure is the case where
    ; AddRoles succeeds AND Security.Users.Get returns an ordinary access-denied status, which is
    ; what IdentityGrantsInEffect exists to catch.
    Do $$$AssertTrue(..SetIdentityRoleResources("%DB_IRISSYS:R"), "the identity role loses %Admin_Secure and the instance reads the narrower set back")
    Set tAnswer2 = ..GetAs(tRoute, tAccess)
    Do $$$AssertEquals(tAnswer2, "503|" _ ##class(OcuPilot.Api.Error).#INSTALLUNREADABLE, "a role that no longer grants %Admin_Secure answers the same unreadable refusal, although AddRoles succeeded")
    Do $$$AssertNotEquals($Piece(tAnswer2, "|", 2), ##class(OcuPilot.Kernel.Identity).#AUTHDISABLED, "and never AUTH.DISABLED")
    Do $$$AssertTrue(..SetIdentityRoleResources(##class(OcuPilot.Kernel.State.Base).#IDENTITYRESOURCES), "the identity role is repaired")
    Do $$$AssertEquals(..GetAs(tRoute, tAccess), tServed, "and the route is served again")

    ; And the two answers are different facts: a genuinely disabled account still reads 401.
    Do $$$AssertTrue(..SetEnabled(0), "the account itself is disabled")
    Do $$$AssertEquals(..GetAs(tRoute, tAccess), "401|" _ ##class(OcuPilot.Kernel.Identity).#AUTHDISABLED, "which is the other answer, so the two causes are distinguishable on the wire")
    Do $$$AssertTrue(..SetEnabled(1), "the account is re-enabled for the teardown")
}

}
