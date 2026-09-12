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

/// <p>AC1, over the wire -- a signed-in administrator gets one 200 carrying the four
/// identity fields, the admin API version this instance actually publishes, and the version
/// row's build identity byte for byte. Every value is compared against a source this handler
/// does not own: the port's own derivation, the two system reads, and the row itself.</p>
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
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")

    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.adminApiVersion, 2, "this instance's admin API is the v2 OcuPilot needs")
    Do $$$AssertEquals(tObj.instanceName, ##class(%SYS.System).GetInstanceName(), "the instance names itself")
    Do $$$AssertEquals(tObj.instanceVersion, $ZVersion, "and reports its own version banner")

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

}
