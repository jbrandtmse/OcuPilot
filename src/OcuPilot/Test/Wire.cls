/// <p>Over-the-wire suite for the API application and the two envelope paths that only a
/// real web application reaches (AC7's second half, AC8, AC9, DW-25).</p>
/// <p><b>Two purpose-built principals, neither of them <code>_SYSTEM</code> and neither
/// impersonated.</b> Every gate here is evaluated by IRIS for a genuinely authenticated HTTP
/// request, so the accounts are created with passwords this class keeps for the length of the
/// run and sends as Basic credentials — <code>New $ROLES</code> appears nowhere, because a
/// process that escalated itself would prove nothing about what the web application admits.
/// One holds read on the install namespace's code database and nothing else; the other holds
/// that plus <code>%Admin_Operate:U</code>. The contrast between them is the whole of
/// AC8.</p>
/// <p><b>Two test-owned web applications</b>, created and removed by this class, let the
/// framework paths run for real: one dispatches to <class>OcuPilot.Test.RouterFixture</class>
/// so the entity-id corpus can be replayed through an actual route, and one to
/// <class>OcuPilot.Test.PreFault</class> so a failing <method>OnPreDispatch</method> reaches
/// <code>%CSP.REST.Page()</code>'s own error path, which no in-process harness runs.</p>
Class OcuPilot.Test.Wire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it, so the principals this class
/// creates exist on the container that script builds and nowhere else. Anything else -- absent,
/// empty, or a value that reads like a refusal such as <code>0</code> -- refuses (DW-289).</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal holding read on the code database and no <code>%Admin_*</code>
/// resource — the account AC8's 403 is observed for.</p>
Parameter NOADMINUSER = "OcuPilotWireNoAdmin";

/// <p>See <parameter>NOADMINUSER</parameter>.</p>
Parameter NOADMINROLE = "OcuPilotWireNoAdminRole";

/// <p>The principal holding the same read plus one administrative resource — the account
/// AC8's contrast is observed for.</p>
Parameter ADMINUSER = "OcuPilotWireAdmin";

/// <p>See <parameter>ADMINUSER</parameter>.</p>
Parameter ADMINROLE = "OcuPilotWireAdminRole";

/// <p>The one administrative resource <parameter>ADMINROLE</parameter> grants. Any member of
/// <parameter>OcuPilot.Api.Router.ADMINRESOURCES</parameter> would do; this one is chosen
/// because <class>OcuPilot.Test.State</class> already establishes that it is safe to grant to
/// a throwaway account (unlike <code>%Operator</code>, which carries
/// <code>%DB_IRISSYS:RW</code> and is a self-escalation primitive).</p>
Parameter ADMINRESOURCE = "%Admin_Operate";

/// <p>The test-owned web application dispatching to <class>OcuPilot.Test.RouterFixture</class>.
/// A wholly distinct literal, nested inside neither OcuPilot application.</p>
Parameter FIXTUREPATH = "/probeocupilotfixture";

/// <p>The test-owned web application dispatching to <class>OcuPilot.Test.PreFault</class>.</p>
Parameter PREFAULTPATH = "/probeocupilotprefault";

/// <p>The two throwaway accounts' password for the length of this run, generated in
/// <method>OnBeforeAllTests</method> from <code>$System.Encryption.GenCryptRand</code> and
/// never written to source. Prefix deliberately not "Test"
/// (<file>.claude/rules/objectscript-testing.md</file>).</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> confirmed, through
/// <code>$SYSTEM.Security.CheckUserPermission</code>, that each account holds what it is
/// supposed to -- <code>Security.Users.Create</code> silently accepts a role name that does
/// not exist, so a grant must be read back to be believed.</p>
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
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.Wire creates and deletes IRIS users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Install.Installer).Install("")
        If $$$ISERR(tSC) Quit
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotWire" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

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
        Set tCodeRead = tSysDb.ResourceName _ ":R"

        Set tSC = ..EnsurePrincipal(..#NOADMINROLE, ..#NOADMINUSER, tCodeRead, ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#ADMINROLE, ..#ADMINUSER, tCodeRead _ "," _ ..#ADMINRESOURCE _ ":U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit

        Set tSC = ..EnsureFixtureApplication(..#FIXTUREPATH, "OcuPilot.Test.RouterFixture", tInstallNs)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsureFixtureApplication(..#PREFAULTPATH, "OcuPilot.Test.PreFault", tInstallNs)
        If $$$ISERR(tSC) Quit

        Set ..PreparedSetupOk = ($SYSTEM.Security.CheckUserPermission(..#ADMINUSER, ..#ADMINRESOURCE, "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#NOADMINUSER, ..#ADMINRESOURCE, "USE") '= 1)
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the two principals differ on " _ ..#ADMINRESOURCE)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove both throwaway accounts, both throwaway roles and both test-owned web
/// applications, and <b>return a failing status</b> if any of them survives.</p>
/// <p>The removal is reported through the returned <code>%Status</code>, not through
/// assertions: <code>%UnitTest.Manager</code> pops the per-method frame before it calls
/// <method>OnAfterAllTests</method> (<file>irislib/%UnitTest/Manager.cls</file>), and
/// <code>LogAssert</code> discards any assertion made while the frame's method name is empty
/// -- so an assertion here would never be recorded, counted or red. A non-OK status from this
/// method <i>is</i> recorded. What this guards is real: the administrative account holds
/// <code>%Admin_Operate:U</code> plus read on the install namespace's code database, which is
/// exactly what clears the gate this suite tests, and its password exists only in memory.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        For tPath = ..#FIXTUREPATH, ..#PREFAULTPATH {
            If ##class(Security.Applications).Exists(tPath, .tA, .tAS) {
                Do ##class(Security.Applications).Delete(tPath)
            }
            If ##class(Security.Applications).Exists(tPath, .tA2, .tAS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "application " _ tPath
        }
        For tUser = ..#NOADMINUSER, ..#ADMINUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) {
                Do ##class(Security.Users).Delete(tUser)
            }
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ tUser
        }
        For tRole = ..#NOADMINROLE, ..#ADMINROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) {
                Do ##class(Security.Roles).Delete(tRole)
            }
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ tRole
        }
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.Wire teardown left throwaway objects on the instance: " _ tLeft)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create (or re-grant) one throwaway role and the account that holds it.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
Method EnsurePrincipal(pRole As %String, pUser As %String, pResources As %String, pPassword As %String) As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(pRole, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tModProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(pRole, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: wire principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(pUser)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(pUser, pRole, pPassword, "OcuPilot wire test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.Wire; deleted in OnAfterAllTests")
}

/// <p>Create the password-authenticated, role-free test application at <var>pPath</var>
/// dispatching to <var>pDispatchClass</var>. <b>Caller contract:</b>
/// <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
Method EnsureFixtureApplication(pPath As %String, pDispatchClass As %String, pInstallNs As %String) As %Status
{
    If ##class(Security.Applications).Exists(pPath, .tA, .tAS) {
        Set tSC = ##class(Security.Applications).Delete(pPath)
        If $$$ISERR(tSC) Quit tSC
    }
    Set tProps("Type") = 2
    Set tProps("Enabled") = 1
    Set tProps("NameSpace") = pInstallNs
    Set tProps("DispatchClass") = pDispatchClass
    Set tProps("AutheEnabled") = 32
    Set tProps("MatchRoles") = ""
    Set tProps("Resource") = ""
    Set tProps("ServeFiles") = 0
    Set tProps("Description") = "OcuPilot wire test fixture (throwaway)"
    Quit ##class(Security.Applications).Create(pPath, .tProps)
}

/// <p>AC7, AC8 -- an anonymous request to the password-authenticated API is refused by the
/// CSP server <b>before</b> dispatch: 401 with an empty body and no OcuPilot envelope,
/// because <code>%CSP.REST.Login</code>'s generated dispatch map cannot load the router class
/// as the pre-login <code>UnknownUser</code>. The refusal is correct and no OcuPilot code
/// runs, which is why the readiness endpoint cannot live here (AD-45).</p>
Method TestAnonymousApiRequestIsRefusedBeforeDispatch()
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/", "", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 401, "an anonymous API request is refused")
    Do $$$AssertEquals($ZStrip(tBody, "<>W"), "", "with an empty body -- no OcuPilot code ran, so there is no envelope")
}

/// <p>AC8 -- a signed-in caller holding no <code>%Admin_*</code> resource receives exactly
/// one 403 envelope whose code is <code>AUTH.NOADMIN</code> and whose reason names the
/// missing administrative privilege; a caller holding one reaches dispatch, observed as the
/// route-not-found envelope since no route is mapped at the application root.</p>
/// <p>Mutation: delete the administrative gate from
/// <method>OcuPilot.Api.Router.OnPreDispatch</method> -> the no-admin principal reaches
/// dispatch too and the first half goes red.</p>
Method TestAdministrativeGateSeparatesTheTwoPrincipals()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the two principals differ on the administrative resource")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/", ..#NOADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 403, "a caller with no administrative resource is refused")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "forbidden", "rendered through the one error writer")
    Do $$$AssertEquals(tObj.code, "AUTH.NOADMIN", "with the stable machine code")
    Do $$$AssertTrue(tObj.reason [ "administrative", "and a reason naming the missing administrative privilege")

    Set tSC2 = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/", ..#ADMINUSER, ..PreparedPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC2, "the request completes")
    Do $$$AssertEquals(tStatus2, 404, "a caller holding one administrative resource reaches dispatch")
    Set tObj2 = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tObj2.code, "ROUTE.NOTFOUND", "and is answered by the framework 404, since no route is mapped at the application root")
}

/// <p>AC1, over the wire -- a signed-in administrator gets one 200 carrying the seven
/// identity fields, the admin API version this instance actually publishes, and the version
/// row's build identity byte for byte. Every value is compared against a source this handler
/// does not own: the port's own derivation, the five system reads, and the row itself.</p>
/// <p>Mutation: drop <code>buildIdentity</code> from
/// <method>OcuPilot.Api.Instance.Payload</method> -> the stamp assertion goes red; remove
/// the route from <parameter>OcuPilot.Api.Router.UrlMap</parameter> -> the status assertion
/// goes red with a 404.</p>
Method TestTheIdentityRouteReportsTheInstance()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the two principals differ on the administrative resource")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/instance", ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the identity route answers an administrator")
    ; Consistency Conventions: every handler gets an HTTP integration test asserting status,
    ; content type and body shape. The content type was the one of the three this class never
    ; asserted, and scripts/check-objectscript.py's handler-coverage rule (Story 1.17) is what
    ; made that visible rather than leaving it to review.
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")

    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.adminApiVersion, 2, "this instance's admin API is the v2 OcuPilot needs")
    Do $$$AssertEquals(tObj.instanceName, ##class(%SYS.System).GetInstanceName(), "the instance names itself")
    Do $$$AssertEquals(tObj.instanceVersion, $ZVersion, "and reports its own version banner")

    ; Story 1.10's three status-bar fields, over the same wire. The flag is asserted through
    ; the same read the handler makes rather than against a literal: this container has no
    ; system mode set, and a test that hardcoded "" would go green on an instance that does.
    Do $$$AssertEquals(tObj.serverFlag, $SYSTEM.Version.SystemMode(), "the system mode travels verbatim")
    Do $$$AssertEquals(tObj.licensedTo, $SYSTEM.License.KeyCustomerName(), "as does the licensee")
    Do $$$AssertEquals(tObj.serverName, ##class(%SYS.System).GetNodeName(), "and the host node")
    Do $$$AssertTrue(tObj.%IsDefined("serverFlag"), "an unflagged instance still carries the key, so the client drops the badge deliberately")

    Set tRowSC = ##class(OcuPilot.Install.Installer).CurrentVersionRow("", .tRow)
    Do $$$AssertStatusOK(tRowSC, "the production version row reads")
    Do $$$AssertTrue($IsObject(tRow), "and exists on an installed instance")
    If $IsObject(tRow) {
        Do $$$AssertEquals(tObj.buildIdentity, tRow.BuildIdentity, "the build stamp is the version row's own value")
    }
}

/// <p>The wrong-verb matrix row -- a mapped route with no matching verb is the framework's
/// <method>OcuPilot.Api.Router.Http405</method>, which renders through the one error writer
/// and sets <code>Allow</code>. It costs no route of its own, and it could not be observed
/// at all until a route was mapped.</p>
/// <p><code>OPTIONS</code> is in the list because <code>%CSP.REST.DispatchRequest</code>
/// composes the supported-verb list itself and always includes it; OcuPilot maps one verb
/// and passes the list through unchanged. The value is asserted whole rather than by
/// substring, so a vendor change to that list is caught here.</p>
/// <p>Mutation: map a second route, <code>POST /instance</code>, to the same handler ->
/// the POST is dispatched and answers 200, so all three assertions here go red. Dropping
/// the <code>Method</code> attribute instead does not compile at all:
/// <code>%CSP.REST</code> refuses a route without one (ERROR #5001).</p>
Method TestTheIdentityRouteRefusesAPostAndNamesTheVerbItAllows()
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/instance", ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 405, "a POST to the identity route is refused")
    Do $$$AssertEquals($Get(tHeaders("ALLOW")), "GET,OPTIONS", "and the response names the verbs that are allowed")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.code, "ROUTE.METHODNOTALLOWED", "through the one error writer")
}

/// <p>AC4 -- a signed-in caller holding none of the router's thirteen administrative
/// resources meets the identity call's 403 and the machine code the shell reads, never a
/// version report. The principal is this suite's throwaway one, created in
/// <method>OnBeforeAllTests</method> and removed in <method>OnAfterAllTests</method>; it
/// holds read on the install namespace's code database, without which IRIS could not load
/// the router for the request and the framework would answer a bare 403 with no envelope --
/// which would pass a status-only assertion while pinning nothing.</p>
/// <p>Mutation: delete the administrative gate from
/// <method>OcuPilot.Api.Router.OnPreDispatch</method> -> this answers 200 with a version
/// report and every assertion here goes red.</p>
Method TestTheIdentityRouteRefusesACallerHoldingNoAdminResource()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the two principals differ on the administrative resource")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/instance", ..#NOADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 403, "the identity call is refused")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.code, "AUTH.NOADMIN", "with the code the no-privileges notice is driven by")
    Do $$$AssertEquals((tBody [ "adminApiVersion"), 0, "and no version report, which the shell must never read as a mismatch")
}

/// <p>Story 1.9's Integration AC, over the wire and against the <b>real</b>
/// <code>$System.Security.Check</code>: a signed-in principal holding exactly one
/// administrative resource gets 200 with the areas that resource reaches allowed and the others
/// denied, each naming the <code>(resource, permission)</code> pair that failed. None is
/// hidden, and the list is never partial.</p>
/// <p>This is the only place in the suite where a denial is observed against the instance's own
/// check rather than a fixture seam: <code>%UnitTest</code> runs as an account holding
/// <code>%All</code>, for which the real check answers yes to every resource name.
/// <class>OcuPilot.Test.Navigation</class> carries the set semantics; this carries the
/// evidence that the semantics are wired to the instance.</p>
/// <p>The principal is this suite's throwaway one, created in
/// <method>OnBeforeAllTests</method> and removed in <method>OnAfterAllTests</method>. No real
/// account is created, modified or expired, and no role is granted to one.</p>
/// <p>Mutation: give the <code>agent</code> area a privilege pair in
/// <class>OcuPilot.Screen.Area</class>'s declaration -> the "never gates" assertion goes red.
/// Delete the classic-resource union from <method>OcuPilot.Screen.Gate.RequiredPairs</method>
/// -> nothing here moves, which is why <class>OcuPilot.Test.Navigation</class> carries that
/// half.</p>
Method TestTheNavigationMapGatesEveryAreaForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the two principals differ on the administrative resource")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the navigation route answers an administrator")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")

    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.areas.%Size(), 8, "every area is listed, denied ones included -- nothing is hidden")

    Kill tVerdict, tFailed, tHasFailed
    Set tIterator = tObj.areas.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tArea) {
        Set tVerdict(tArea.key) = ''tArea.allowed
        Set tFailed(tArea.key) = tArea.%Get("failedPair")
        ; %Get answers "" both for an absent key and for one set to "", so definedness is read
        ; separately -- otherwise "the key is omitted on an allowed entry" cannot be observed.
        Set tHasFailed(tArea.key) = ''tArea.%IsDefined("failedPair")
    }

    ; The principal holds %Admin_Operate and nothing else, so only Home and Agent co-pilot -- which
    ; declare no pair at all -- are reachable, and the six gated areas are not. Since Story 2.10 no
    ; gated area opens on %Admin_Operate alone: Logs was the last one, and its first screen, the
    ; audit database viewer, declares %Admin_Secure:USE for the endpoint's own gate and
    ; %DB_IRISSYS:READ because the read runs in %SYS, so AD-8's area coverage puts both on the area.
    ; All six denials are asserted, not a sample: ui/src/app/shell/rail-wire.spec.ts and
    ; ui/tools/navigation-wire.test.mjs read the same eight verdicts off a payload captured for this
    ; principal, and a claim that the three readings agree has to cover the same eight.
    Do $$$AssertEquals($Get(tVerdict("home")), 1, "Home never gates")
    Do $$$AssertEquals($Get(tVerdict("agent")), 1, "and the agent rail item never gates")
    Do $$$AssertEquals($Get(tVerdict("logs")), 0, "while Logs, which this principal's resource used to reach alone, now wants two more pairs")
    Do $$$AssertEquals($Get(tFailed("logs")), "%Admin_Secure:USE", "naming the audit endpoint's own gate, which this principal does not hold")
    ; os-management is denied on a different resource again, since Story 2.9: the query behind its
    ; first screen checks %Admin_Manage:USE for itself and the read runs in %SYS. This principal
    ; holds only the first of its three pairs, so the gate names the second.
    ; OcuPilot.Test.WireSecurityRead observes both sets with real principals that hold one, two and
    ; all three of the pairs.
    Do $$$AssertEquals($Get(tVerdict("os-management")), 0, "while its sibling on the same resource now wants two more pairs")
    Do $$$AssertEquals($Get(tFailed("os-management")), "%Admin_Manage:USE", "naming the second pair, which this principal does not hold")

    Do $$$AssertEquals($Get(tVerdict("permissions")), 0, "an area wanting another resource is denied")
    Do $$$AssertEquals($Get(tFailed("permissions")), "%Admin_Secure:USE", "naming the pair that failed")
    ; The security area declares %DB_IRISSYS:READ as well, and the failed pair named is still
    ; %Admin_Secure:USE: the gate reports the first pair the caller does not hold, and this
    ; principal holds neither.
    Do $$$AssertEquals($Get(tVerdict("security")), 0, "and so is the security area")
    Do $$$AssertEquals($Get(tFailed("security")), "%Admin_Secure:USE", "with its own pair named")
    Do $$$AssertEquals($Get(tVerdict("web-applications")), 0, "and the web-applications area")
    Do $$$AssertEquals($Get(tFailed("web-applications")), "%Admin_Secure:USE", "on the same pair its two siblings name")
    Do $$$AssertEquals($Get(tVerdict("tasks")), 0, "and the tasks area")
    Do $$$AssertEquals($Get(tFailed("tasks")), "%Admin_Task:USE", "which wants a different resource again")
    Do $$$AssertEquals($Get(tHasFailed("home")), 0, "an allowed entry omits the failed-pair key rather than sending it empty")
    Do $$$AssertEquals($Get(tHasFailed("permissions")), 1, "while a denied one carries it")
}

/// <p>Story 3.5 AC5, against the <b>real</b> <code>$System.Security.Check</code> -- the pairing
/// EXPERIENCE.md requires of the agent co-pilot area: the rail item never gates, and the screens
/// inside it gate on OcuPilot's own administrative resource. A principal holding
/// <code>%Admin_Operate:USE</code> and nothing of OcuPilot's therefore reads the area allowed and
/// every screen in it denied, naming <code>OcuPilotAdmin:USE</code>.</p>
/// <p>This is the pairing <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method> was
/// restated to admit: an area declaring no pairs is a never-gating area whose screens gate
/// independently. Asserting it here is what keeps that restatement from also admitting an area
/// whose screens are reachable when they should not be.</p>
/// <p>The form's entry is asserted too, and its <code>sideBarPosition</code> 0 with it: the map is
/// where the client learns which screens an area lists, so the sentinel has to survive the wire
/// as a declared 0 rather than as an absent key. Switches, the area's second listed screen, gates
/// on the same resource (FR-29).</p>
/// <p>Mutation: declare <code>"privileges": []</code> in
/// <class>OcuPilot.Screen.Descriptor.AgentDefinitionList</class> -> its entry reads allowed and
/// the denial assertion goes red. Give the <code>agent</code> area a pair in
/// <class>OcuPilot.Screen.Area</class> -> the area assertion goes red instead.</p>
Method TestTheAgentAreaNeverGatesWhileItsScreensGateOnOcuPilotsOwnResource()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the two principals differ on the administrative resource")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the navigation request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    If tStatus '= 200 Quit

    Set tAgent = ""
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Set tIterator = tObj.areas.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tArea) {
        If tArea.key = "agent" Set tAgent = tArea
    }
    Do $$$AssertTrue($IsObject(tAgent), "the map lists the Agent co-pilot area")
    If '$IsObject(tAgent) Quit

    Do $$$AssertEquals(''tAgent.allowed, 1, "the rail item never gates, whatever the caller holds")
    Do $$$AssertEquals(''tAgent.%IsDefined("failedPair"), 0, "so it carries no failed pair")

    Do $$$AssertEquals(tAgent.screens.%Size(), 3, "and lists all three built screens, the form included: " _ tAgent.screens.%ToJSON())
    Kill tPosition, tAllowed, tFailed
    Set tScreenIterator = tAgent.screens.%GetIterator()
    While tScreenIterator.%GetNext(.tScreenIndex, .tScreen) {
        Set tPosition(tScreen.route) = +tScreen.sideBarPosition
        Set tAllowed(tScreen.route) = ''tScreen.allowed
        Set tFailed(tScreen.route) = tScreen.%Get("failedPair")
    }
    Do $$$AssertEquals($Get(tPosition("agent/definitions")), 1, "Definitions takes the area's first side-bar position")
    Do $$$AssertEquals($Get(tPosition("agent/switches")), 2, "Switches takes the second")
    Do $$$AssertEquals($Get(tPosition("agent/definitions/edit")), 0, "and the form declares 0, the sentinel for routable but not listed")
    Do $$$AssertEquals($Get(tAllowed("agent/definitions")), 0, "Definitions is denied to a principal holding nothing of OcuPilot's")
    Do $$$AssertEquals($Get(tFailed("agent/definitions")), "OcuPilotAdmin:USE", "naming OcuPilot's own administrative pair")
    Do $$$AssertEquals($Get(tAllowed("agent/definitions/edit")), 0, "and so is the form")
    Do $$$AssertEquals($Get(tFailed("agent/definitions/edit")), "OcuPilotAdmin:USE", "on the same pair")
    Do $$$AssertEquals($Get(tAllowed("agent/switches")), 0, "and so is Switches, which gates on the same resource (FR-29)")
    Do $$$AssertEquals($Get(tFailed("agent/switches")), "OcuPilotAdmin:USE", "on the same pair")
}

/// <p>Story 2.5 AC4, against the <b>real</b> <code>$System.Security.Check</code> -- for a principal
/// holding <code>%Admin_Operate:USE</code> and not <code>%Admin_Secure</code>, the navigation map
/// lists the web applications list denied on <code>%Admin_Secure:USE</code>, and the screen's read
/// route refuses it with <code>AUTH.NOPRIVILEGE</code> naming that pair. The screen entry is compared
/// whole, because <file>ui/tools/navigation-wire.test.mjs</file> and
/// <file>ui/src/app/shell/rail-wire.spec.ts</file> carry the same entry in their captured
/// payloads.</p>
/// <p>Mutation: declare <code>"privileges": []</code> in
/// <class>OcuPilot.Screen.Descriptor.WebAppList</class> -> the entry is allowed and the read answers
/// 200, so the entry and the <code>failedPair</code> assertions go red.</p>
Method TestTheWebApplicationsListIsDeniedToAPrincipalWithoutAdminSecure()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the two principals differ on the administrative resource")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the navigation request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Set tScreens = ""
    If tStatus = 200 {
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
        Set tIterator = tObj.areas.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tArea) {
            If tArea.key = "web-applications" Set tScreens = tArea.screens.%ToJSON()
        }
    }
    Do $$$AssertEquals(tScreens, "[{""route"":""web-applications/rest-apis/document"",""labelKey"":""openApiViewerLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""web-applications/list/edit"",""labelKey"":""proposalEntityWebApplication"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""web-applications/list"",""labelKey"":""webAppListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""web-applications/rest-apis"",""labelKey"":""restApiListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Secure:USE""}]", "the area lists its four built screens -- the document viewer, the create form, the list and the REST API explorer -- each denied on the pair it declares first")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/webapp.list/read?maxRows=5", ..#ADMINUSER, ..PreparedPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC, "the read request completes")
    Do $$$AssertEquals(tStatus2, 403, "the read is refused")
    Do $$$AssertEquals((tBody2 [ "}{"), 0, "with exactly one envelope")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", "on the screen-privilege code")
    Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), "%Admin_Secure:USE", "naming the failed pair")
    Do $$$AssertEquals($IsObject(tRefusal.%Get("rows")), 0, "and no rows reach the refused caller")
}

/// <p>Story 2.6 -- for the same principal, the navigation map lists the users list denied on
/// <code>%Admin_Secure:USE</code>, the first pair it declares, and its read route refuses it with
/// <code>AUTH.NOPRIVILEGE</code>. The roles, resources and services lists follow it, each denied on
/// the same first pair. The area's entries are compared whole, as the captured payloads in
/// <file>ui/tools/navigation-wire.test.mjs</file> and <file>ui/src/app/shell/rail-wire.spec.ts</file>
/// carry them.</p>
Method TestTheUsersListIsDeniedToAPrincipalWithoutAdminSecure()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the two principals differ on the administrative resource")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the navigation request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Set tScreens = ""
    If tStatus = 200 {
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
        Set tIterator = tObj.areas.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tArea) {
            If tArea.key = "permissions" Set tScreens = tArea.screens.%ToJSON()
        }
    }
    Do $$$AssertEquals(tScreens, "[{""route"":""permissions/roles/edit"",""labelKey"":""userRoleField"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""permissions/users/edit"",""labelKey"":""processColumnUser"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""permissions/users"",""labelKey"":""userListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""permissions/roles"",""labelKey"":""userColumnRoles"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""permissions/resources"",""labelKey"":""resourceListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""permissions/services"",""labelKey"":""serviceListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Secure:USE""}]", "the permissions area lists its six built screens -- the two unlisted create forms, then the four lists in side-bar order -- each denied on its first pair")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/permissions.users/read?maxRows=5", ..#ADMINUSER, ..PreparedPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC, "the read request completes")
    Do $$$AssertEquals(tStatus2, 403, "the read is refused")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", "on the screen-privilege code")
    Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), "%Admin_Secure:USE", "naming the failed pair")
    Do $$$AssertEquals($IsObject(tRefusal.%Get("rows")), 0, "and no rows reach the refused caller")
}

/// <p>Story 2.7 -- for the same principal, the navigation map lists the SSL/TLS configurations list
/// denied on <code>%Admin_Secure:USE</code>, the first pair it declares, and its read route refuses
/// it with <code>AUTH.NOPRIVILEGE</code>. The entry is compared whole, as the captured payloads in
/// <file>ui/tools/navigation-wire.test.mjs</file> and <file>ui/src/app/shell/rail-wire.spec.ts</file>
/// carry it.</p>
/// <p>Story 6.3 and 6.4 -- the Security and secrets area lists sixteen built screens: the unlisted
/// audit event lists, OAuth 2.0 tabs, SSL/TLS configuration form (Story 9.5), wallet secret form
/// (Story 8.6), Secrets list and X.509 credential form (Story 8.5) first, at position 0, then
/// SSL/TLS, X.509, LDAP / Kerberos, Wallet, OAuth 2.0 and Auditing. Each is denied on the first pair
/// it declares: the wallet pair for the three wallet screens, an OAuth resource for four OAuth tabs, and <code>%Admin_Secure:USE</code> for the rest,
/// which is also the first pair the area declares.</p>
Method TestTheSslConfigurationsListIsDeniedToAPrincipalWithoutAdminSecure()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the two principals differ on the administrative resource")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the navigation request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Set tScreens = ""
    Set tArea = ""
    If tStatus = 200 {
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
        Set tIterator = tObj.areas.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If tEntry.key = "security" {
                Set tScreens = tEntry.screens.%ToJSON()
                Set tArea = $Select(tEntry.allowed: "true", 1: "false") _ $Select(tEntry.%IsDefined("failedPair"): ":" _ tEntry.failedPair, 1: "")
            }
        }
    }
    Do $$$AssertEquals(tScreens, "[{""route"":""security/auditing/system-events"",""labelKey"":""auditSystemEventListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/auditing/user-events"",""labelKey"":""auditUserEventListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/clients"",""labelKey"":""oauthTabClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/resource-servers"",""labelKey"":""oauthTabResourceServers"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/server-clients"",""labelKey"":""oauthTabServerClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/server"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/ssl/edit"",""labelKey"":""sslFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/wallet/secrets/edit"",""labelKey"":""walletSecretFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/wallet/secrets"",""labelKey"":""walletSecretListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/x509/edit"",""labelKey"":""x509FormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/x509"",""labelKey"":""x509ListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ldap"",""labelKey"":""ldapListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/wallet"",""labelKey"":""walletListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/oauth"",""labelKey"":""oauthLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/auditing"",""labelKey"":""auditingConfigurationLink"",""sideBarPosition"":6,""allowed"":false,""failedPair"":""%Admin_Secure:USE""}]", "the security area lists its sixteen built screens in side-bar order, each denied on its first pair")
    Do $$$AssertEquals(tArea, "false:%Admin_Secure:USE", "and the area itself is denied on the same pair")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/security.ssl/read?maxRows=5", ..#ADMINUSER, ..PreparedPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC, "the read request completes")
    Do $$$AssertEquals(tStatus2, 403, "the read is refused")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", "on the screen-privilege code")
    Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), "%Admin_Secure:USE", "naming the failed pair")
    Do $$$AssertEquals($IsObject(tRefusal.%Get("rows")), 0, "and no rows reach the refused caller")
}

/// <p>Story 2.8 -- for the same principal, the navigation map lists the task schedule denied on
/// <code>%Admin_Task:USE</code>, the first pair its descriptor declares, and its read route refuses
/// it with <code>AUTH.NOPRIVILEGE</code>. The entry is compared whole, as the captured payloads in
/// <file>ui/tools/navigation-wire.test.mjs</file> and <file>ui/src/app/shell/rail-wire.spec.ts</file>
/// carry it -- which is what makes those two hand-added fixtures a record of a live response rather
/// than a hand-written string.</p>
/// <p>Story 6.5 -- On-demand tasks and Upcoming tasks follow at positions 2 and 3, each denied on the
/// same first pair.</p>
/// <p>Story 6.6 -- Task history (all tasks) follows at position 4, denied the same way; the
/// per-task history joins the roster too, unlisted at position 0 and therefore sorted first,
/// carrying the same pair and the same denial.</p>
/// <p>This principal holds neither of the screen's pairs, so it is the one that reads the
/// <b>descriptor's</b> pair order; <class>OcuPilot.Test.WireSecurityRead</class>'s task principals
/// each hold <code>%Admin_Task</code>, for which <code>%DB_IRISSYS:READ</code> is the first unheld
/// pair under either ordering.</p>
/// <p>Mutation: swap the two pairs in
/// <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class> -> the entry's
/// <code>failedPair</code> reads <code>%DB_IRISSYS:READ</code> and both assertions below go red.</p>
Method TestTheTaskScheduleIsDeniedToAPrincipalWithoutAdminTask()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the two principals differ on the administrative resource")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the navigation request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Set tScreens = ""
    Set tArea = ""
    If tStatus = 200 {
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
        Set tIterator = tObj.areas.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If tEntry.key = "tasks" {
                Set tScreens = tEntry.screens.%ToJSON()
                Set tArea = $Select(tEntry.allowed: "true", 1: "false") _ $Select(tEntry.%IsDefined("failedPair"): ":" _ tEntry.failedPair, 1: "")
            }
        }
    }
    Do $$$AssertEquals(tScreens, "[{""route"":""tasks/schedule/details"",""labelKey"":""taskDetailsLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Task:USE""},{""route"":""tasks/schedule/edit"",""labelKey"":""proposalEntityTask"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Task:USE""},{""route"":""tasks/schedule/history"",""labelKey"":""taskRunsLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Task:USE""},{""route"":""tasks/schedule"",""labelKey"":""taskListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Task:USE""},{""route"":""tasks/on-demand"",""labelKey"":""taskOnDemandLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Task:USE""},{""route"":""tasks/upcoming"",""labelKey"":""taskUpcomingLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Task:USE""},{""route"":""tasks/history"",""labelKey"":""taskHistoryLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Task:USE""}]", "the tasks area lists its seven built screens in side-bar order (the unlisted task details, the New Task wizard and per-task history first, at position 0, task details sorting first by class name), each denied on its first pair")
    Do $$$AssertEquals(tArea, "false:%Admin_Task:USE", "and the area itself is denied on the same pair")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/tasks.schedule/read?maxRows=5", ..#ADMINUSER, ..PreparedPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC, "the read request completes")
    Do $$$AssertEquals(tStatus2, 403, "the read is refused")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", "on the screen-privilege code")
    Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), "%Admin_Task:USE", "naming the failed pair")
    Do $$$AssertEquals($IsObject(tRefusal.%Get("rows")), 0, "and no rows reach the refused caller")
}

/// <p>Story 2.9 -- for the same principal, the navigation map lists the processes list denied on
/// <code>%Admin_Manage:USE</code> -- the <b>second</b> of the three pairs its descriptor declares,
/// and the first one this principal does not hold, since it does hold <code>%Admin_Operate</code> --
/// and its read route refuses it with <code>AUTH.NOPRIVILEGE</code>. The entry is compared whole, as
/// the captured payloads in <file>ui/tools/navigation-wire.test.mjs</file> and
/// <file>ui/src/app/shell/rail-wire.spec.ts</file> carry it.</p>
/// <p><b>This principal is the one that reads the pair set as an AND rather than as an order.</b>
/// The four sibling legs above each name a screen's first pair, because their principal holds none
/// of them; here the first pair is held and the second is not, so a gate that stopped at the first
/// pair would answer allowed and the read would then fail with an
/// <code>&lt;INVALID OREF&gt;</code> 500 out of the vendor's own class-query helper.</p>
/// <p>Mutation: remove <code>%Admin_Manage:USE</code> from
/// <class>OcuPilot.Screen.Descriptor.ProcessList</class> -> the entry reads denied on
/// <code>%DB_IRISSYS:READ</code> instead and the entry assertion goes red; remove it from the
/// screen and the area both -> the entry reads allowed and the read answers 500 rather than a named
/// 403, so every assertion below goes red.
/// <method>OcuPilot.Test.WireSecurityRead.TestTheProcessesListsPairSetIsEnforcedForARealPrincipal</method>
/// carries the declared order, with a principal that holds none of the three.</p>
Method TestTheProcessesListIsDeniedToAPrincipalWithoutAdminManage()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the two principals differ on the administrative resource")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the navigation request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Set tScreens = ""
    Set tArea = ""
    If tStatus = 200 {
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
        Set tIterator = tObj.areas.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If tEntry.key = "os-management" {
                Set tScreens = tEntry.screens.%ToJSON()
                Set tArea = $Select(tEntry.allowed: "true", 1: "false") _ $Select(tEntry.%IsDefined("failedPair"): ":" _ tEntry.failedPair, 1: "")
            }
        }
    }
    ; Story 6.11 took the roster from four screens to eight, and Story 6.12 took it from eight to
    ; nine, in ScreensForArea's own (sideBarPosition, class name) collation: the four unlisted
    ; sideBarPosition-0 screens sort first, alphabetically by descriptor class name (Database
    ; details, Database free-space, Database volumes, then Process details), ahead of the listed
    ; ones in position order (Processes, Locks, System usage, Databases, Devices last).
    Do $$$AssertEquals(tScreens, "[{""route"":""os-management/databases/details"",""labelKey"":""databaseDetailsLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""os-management/database-free-space"",""labelKey"":""databaseFreeSpaceLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/databases/volumes"",""labelKey"":""databaseVolumeListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/devices/edit"",""labelKey"":""deviceFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/processes/details"",""labelKey"":""processDetailsLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/processes"",""labelKey"":""processListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/locks"",""labelKey"":""lockListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""os-management/system-usage"",""labelKey"":""systemUsageLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""os-management/databases"",""labelKey"":""databaseListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/devices"",""labelKey"":""deviceListLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_Manage:USE""}]", "the os-management area lists its ten built screens, each denied on the first pair this principal lacks: Database details, Locks and System usage's own two-pair sets name %DB_IRISSYS:READ, since this principal already holds %Admin_Operate:USE, while the Free-space view, Database volumes, the device editor, Process details, the processes list, the General view and Devices all name %Admin_Manage:USE")
    Do $$$AssertEquals(tArea, "false:%Admin_Manage:USE", "and the area itself is denied on the same pair")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/osmgmt.processes/read?maxRows=5", ..#ADMINUSER, ..PreparedPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC, "the read request completes")
    Do $$$AssertEquals(tStatus2, 403, "the read is refused")
    Do $$$AssertEquals((tBody2 [ "}{"), 0, "with exactly one envelope")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", "on the screen-privilege code")
    Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), "%Admin_Manage:USE", "naming the failed pair")
    Do $$$AssertEquals($IsObject(tRefusal.%Get("rows")), 0, "and no rows reach the refused caller")
}

/// <p>AC8 -- the administrative gate's <b>position</b> in
/// <method>OcuPilot.Api.Router.OnPreDispatch</method>, not merely its presence: a caller the
/// gate refuses learns nothing from the request, including whether the namespace it named
/// exists. Every other test sends either no <code>?ns=</code> or sends one as an identity
/// holding <code>%All</code>, so the two orderings are indistinguishable to all of them.</p>
/// <p>Mutation: move the <code>HoldsAdminResource</code> block below the <code>?ns=</code>
/// validation in <method>OcuPilot.Api.Router.OnPreDispatch</method> -> this answers
/// <code>400</code> / <code>NS.UNKNOWN</code> and both assertions go red, which is the
/// signal a non-administrator would use to enumerate the instance's namespaces.</p>
Method TestAdministrativeGateRefusesBeforeTheNamespaceIsValidated()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the two principals differ on the administrative resource")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/?ns=NOSUCHNS12345", ..#NOADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 403, "the administrative refusal comes first, whatever namespace was named")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.code, "AUTH.NOADMIN", "so the refused caller cannot tell an unknown namespace from a known one")
}

/// <p>AC1, over the wire and against the <b>real</b> <code>$System.Security.Check</code> -- the
/// namespace list is the set the principal can read, and nothing else. This suite's
/// administrative principal holds read on the install namespace's code database and
/// <code>%Admin_Operate:U</code>, so the install namespace is listed and <code>%SYS</code>, whose
/// <code>%DB_IRISSYS</code> it does not hold, is not. <code>scope</code> echoes the namespace the
/// request resolved to.</p>
/// <p>This is the only place the filter is observed against the instance's own check:
/// <code>%UnitTest</code> runs as an account holding <code>%All</code>, for which every resource
/// name answers yes. <class>OcuPilot.Test.Namespaces</class> carries the rules; this carries the
/// evidence that they are wired to the instance.</p>
/// <p>Mutation: drop the read filter from
/// <method>OcuPilot.Api.Namespaces.Payload</method> -> <code>%SYS</code> appears and the
/// exclusion assertion goes red.</p>
Method TestTheNamespacesRouteListsOnlyWhatThePrincipalMayEnter()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the two principals differ on the administrative resource")
    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/namespaces", ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the namespaces route answers an administrator")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")

    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.scope, tInstallNs, "the body echoes the namespace the request resolved to")

    Kill tListed
    Set tIterator = tObj.namespaces.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tListed(tEntry.name) = ''tEntry.writable
    }
    Do $$$AssertEquals($Data(tListed(tInstallNs)), 1, "the namespace the principal can read is listed")
    Do $$$AssertEquals($Data(tListed("%SYS")), 0, "and one whose database resource it does not hold is absent")
}

/// <p><b>DW-8</b>, over the wire -- a request scoped to a namespace that exists and that the
/// principal may not enter is refused with the <code>NS.DENIED</code> code and the
/// <code>(resource, permission)</code> pair that failed, rendered through the one error writer.
/// A namespace that does not exist is still the 400, told apart by its code.</p>
/// <p>Mutation: delete the <method>OcuPilot.Api.Router.MayEnterNamespace</method> block from
/// <method>OcuPilot.Api.Router.OnPreDispatch</method> -> the first half answers 200 with a
/// version report and every assertion in it goes red.</p>
Method TestANamespaceThisPrincipalCannotEnterIsRefusedOverTheWire()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the two principals differ on the administrative resource")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/instance?ns=%25SYS", ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 403, "a namespace this principal may not enter is refused")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "forbidden", "through the one error writer")
    Do $$$AssertEquals(tObj.code, "NS.DENIED", "with the machine code the shell reads")
    Do $$$AssertEquals(tObj.detail.failedPair, "%DB_IRISSYS:READ", "naming the pair that failed")
    Do $$$AssertEquals((tBody [ "adminApiVersion"), 0, "and no version report reaches a caller the gate refused")

    Set tSC2 = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/instance?ns=NOSUCHNS12345", ..#ADMINUSER, ..PreparedPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC2, "the request completes")
    Do $$$AssertEquals(tStatus2, 400, "while a namespace that does not exist is a bad request")
    Set tObj2 = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tObj2.code, "NS.UNKNOWN", "told apart from the denial by its code")
}

/// <p>AC8 -- every name in <parameter>OcuPilot.Api.Router.ADMINRESOURCES</parameter> is a
/// resource this instance actually defines. The gate quits on the first match, so only the
/// one resource this suite grants is ever evaluated behind a real request: a typo in any of
/// the other twelve would lock out an administrator whose only administrative resource is
/// that one, with every suite green. The parameter's own doc claims the list was read from
/// the instance; this is the check of that claim rather than a restatement of it.</p>
/// <p>Deliberately not asserted the other way round -- that the instance defines no
/// <code>%Admin_*</code> resource missing from the list -- because narrowing as IRIS adds
/// resources is the stated point of a closed list.</p>
/// <p>Mutation: misspell any entry of
/// <parameter>OcuPilot.Api.Router.ADMINRESOURCES</parameter> -> this goes red.</p>
Method TestEveryAdminResourceNamedExistsOnTheInstance()
{
    Set tList = ##class(OcuPilot.Api.Router).#ADMINRESOURCES
    Do $$$AssertTrue($Length(tList, ",") > 1, "the gate names more than one administrative resource")

    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSC, "switch to %SYS")
        For tI = 1:1:$Length(tList, ",") {
            Set tResource = $Piece(tList, ",", tI)
            Do $$$AssertTrue(##class(Security.Resources).Exists(tResource, .tObj, .tExistSC), "the gate names an existing resource at position " _ tI _ ": " _ tResource)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>AC9 -- every corpus id survives the whole trip: encoded by the shared codec, delivered
/// by the web server and <class>%CSP.REST</class>, and decoded exactly once by the route
/// target, which echoes what it received. This is what makes
/// <method>OcuPilot.Test.EntityId.ServerDecode</method> a model of the server rather than an
/// assumption about it.</p>
/// <p>Mutation: drop the second encode from
/// <method>OcuPilot.Kernel.EntityId.Encode</method> -> the two slash-bearing rows
/// (<code>a/b</code>, <code>/csp/myapp</code>) do not arrive at all and the non-ASCII row
/// (<code>café</code>) comes back altered. The ASCII slash-free rows are unaffected, so
/// those three rows are what carry this test.</p>
Method TestEntityIdCorpusSurvivesTheRealWire()
{
    Set tCorpus = ##class(OcuPilot.Test.EntityId).Corpus()
    For tI = 1:1:$ListLength(tCorpus) {
        Set tOriginal = $List(tCorpus, tI)
        Set tPath = ..#FIXTUREPATH _ "/items/" _ ##class(OcuPilot.Kernel.EntityId).Encode(tOriginal)
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "corpus row " _ tI _ " completes")
        Do $$$AssertEquals(tStatus, 200, "corpus row " _ tI _ " reaches the route target")
        If tStatus = 200 {
            Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
            Do $$$AssertEquals(tObj.id, tOriginal, "corpus row " _ tI _ " arrives byte for byte after exactly one decode")
        }
    }
}

/// <p>AC9's recorded stack limitation: the front web server refuses a <b>singly</b>
/// encoded slash outright, before IRIS sees the request, so the same id encoded once never
/// arrives at all. That refusal is why the codec encodes twice; recording it as a test rather
/// than as prose is what keeps a later "simplification" back to a single encode from shipping
/// green.</p>
Method TestSinglyEncodedSlashIsRefusedByTheWebServer()
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#FIXTUREPATH _ "/items/a%2Fb", ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes at the transport level")
    Do $$$AssertNotEquals(tStatus, 200, "a singly encoded slash never reaches the route target")

    Set tDouble = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#FIXTUREPATH _ "/items/a%252Fb", ..#ADMINUSER, ..PreparedPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tDouble, "the request completes")
    Do $$$AssertEquals(tStatus2, 200, "while the double-encoded form of the same id does")
    If tStatus2 = 200 {
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody2)
        Do $$$AssertEquals(tObj.id, "a/b", "and decodes back to the id with the slash intact")
    }
}

/// <p>DW-25, end to end -- a failing <method>OnPreDispatch</method> reaches
/// <code>%CSP.REST.Page()</code>, which is the only caller of the
/// <code>$$$ISERR</code> branch, and exactly one internal-error envelope reaches the wire
/// with the detail logged and not sent. This path could not run at all before this story:
/// it needs a web application.</p>
Method TestPreDispatchFailureRendersOneInternalEnvelope()
{
    Set tPath = ..#PREFAULTPATH _ "/ping?" _ ##class(OcuPilot.Test.PreFault).#FAULTPARAM _ "=1"
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, ..#ADMINUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 500, "a failing pre-dispatch renders a 500")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "server_error", "through the one error writer")
    Do $$$AssertEquals(tObj.code, "INTERNAL", "with the internal machine code")
    Do $$$AssertEquals(tObj.reason, "An internal error occurred", "and a generic reason")
    Do $$$AssertTrue((tBody '[ "pre-dispatch fixture failure"), "the real error text is logged, never sent")

    Set tSC2 = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#PREFAULTPATH _ "/ping", ..#ADMINUSER, ..PreparedPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC2, "the unarmed request completes")
    Do $$$AssertEquals(tStatus2, 200, "and the same route answers normally when the fault is not armed")
}

/// <p>Story 1.17, AD-45 -- the readiness endpoint, over the wire, as an <b>anonymous</b>
/// caller. It is its own web application at a path under <code>/api/ocupilot/</code>, so the
/// request never reaches <method>OcuPilot.Api.Router.OnPreDispatch</method>: the 401 every
/// other anonymous request in this class gets is exactly what readiness must not answer.</p>
/// <p>The trailing slash is IRIS's own rule for a REST web application, not a nesting quirk:
/// verified on this build that the vendor's own <code>/api/atelier</code> answers 404 without
/// it and 200 with it. Without the slash the bare path resolves to the parent
/// <code>/api/ocupilot</code> application instead, which is password-authenticated -- which is
/// what the second half of this test pins, so the two are not confused for each other.</p>
/// <p>Mutation (Rule 19): remove the readiness application from
/// <class>OcuPilot.Install.Roster</class> and re-install -> the anonymous request falls through
/// to the API application and answers 401, so the status assertion goes red.</p>
Method TestReadinessAnswersAnAnonymousCaller()
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/readiness/", "", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the anonymous request completes")
    Do $$$AssertEquals(tStatus, 200, "readiness answers a caller carrying no credentials at all")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")

    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.state, "installed", "and reports this instance as installed")
    Do $$$AssertEquals(tObj.installed, 1, "in both fields")
    Do $$$AssertTrue(tObj.%IsDefined("version"), "carrying the version stamp")

    ; The same path without the trailing slash resolves to the password-authenticated API
    ; application, which has no such route: 401 to an anonymous caller. Asserted so the two
    ; applications cannot be confused for each other, and so README.md's spelling is the one
    ; that works.
    Set tSC2 = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/readiness", "", "", .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC2, "the slashless request completes")
    Do $$$AssertEquals(tStatus2, 401, "without the trailing slash the parent API application answers, and it is authenticated")
}

}
