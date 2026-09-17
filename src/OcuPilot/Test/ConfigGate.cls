/// <p>AC1, AC4's floor and AC5's API half -- the gate on every configuration route, swept over the
/// <b>shipped <code>UrlMap</code></b> and over the screen registry rather than over a list somebody
/// maintains here. A route or an administratively-gated screen read added later is swept by
/// arriving in the map or the registry; it never needs a line in this class.</p>
/// <p><b>Two purpose-built principals, neither impersonated.</b> Every gate is evaluated by IRIS
/// for a genuinely authenticated HTTP request, so each account is created with a password this
/// class keeps for the length of the run and sends as Basic credentials. One holds
/// <code>%Admin_Operate:USE</code> and <b>not</b> OcuPilot's administrative resource -- the
/// account AC1 is observed for; the other holds no <code>%Admin_*</code> resource at all, which is
/// AC4's floor. Both hold read on the install namespace's code database, without which IRIS could
/// not load the dispatch class and the framework would answer a bare 403 with no envelope -- a
/// status-only assertion would pass while pinning nothing.</p>
/// <p><b>Why a real principal is the only thing that proves this.</b>
/// <method>OcuPilot.Screen.Gate.HoldsPrivilege</method> is overridable so unit tests can drive the
/// gate's set semantics, and <code>%UnitTest</code> itself runs as an account holding
/// <code>%All</code>, for which the real check answers yes to every resource name -- including one
/// the instance does not define.</p>
/// <p><b>The sweep's scope, stated plainly.</b> AC1's sweep is every route the map declares under
/// <parameter>CONFIGPREFIX</parameter>: those are the routes OcuPilot's own administrative resource
/// gates. The map's other routes are gated on IRIS resources their own suites cover
/// (<class>OcuPilot.Test.Wire</class>, <class>OcuPilot.Test.WireSecurityRead</class>), and they are
/// still swept here -- for the floor, which every route inherits from
/// <method>OcuPilot.Api.Router.OnPreDispatch</method> whatever it declares.</p>
/// <p><b>It creates IRIS principals, so <method>OnBeforeAllTests</method> refuses to run unless
/// <parameter>ARMINGVARIABLE</parameter> arms it</b> (DW-289). Only
/// <file>scripts/ci-throwaway.sh</file> sets it.</p>
Class OcuPilot.Test.ConfigGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Anything else -- absent, empty, or a value that reads like a refusal such as
/// <code>0</code> -- refuses.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal holding <code>%Admin_Operate:USE</code> and not OcuPilot's administrative
/// resource.</p>
Parameter OPERATEUSER = "OcuPilotConfigGateOperate";

/// <p>See <parameter>OPERATEUSER</parameter>.</p>
Parameter OPERATEROLE = "OcuPilotConfigGateOperateRole";

/// <p>The principal holding no <code>%Admin_*</code> resource at all.</p>
Parameter NOADMINUSER = "OcuPilotConfigGateNoAdmin";

/// <p>See <parameter>NOADMINUSER</parameter>.</p>
Parameter NOADMINROLE = "OcuPilotConfigGateNoAdminRole";

/// <p>The one administrative resource <parameter>OPERATEROLE</parameter> grants -- enough to clear
/// <method>OcuPilot.Api.Router.OnPreDispatch</method>'s floor and nothing more.
/// <code>%Operator</code> is deliberately not used: it carries <code>%DB_IRISSYS:RW</code> and is
/// a self-escalation primitive.</p>
Parameter OPERATERESOURCE = "%Admin_Operate";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The route prefix AC1's sweep covers: the configuration surface OcuPilot's own administrative
/// resource gates.</p>
Parameter CONFIGPREFIX = "/agent/";

/// <p>The permission OcuPilot's administrative resource is required at, as the refusal names the
/// pair.</p>
Parameter ADMINPERMISSION = "USE";

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The screen the <code>:screen</code> parameter is filled with when a swept route carries one
/// -- the one screen whose descriptor declares OcuPilot's administrative resource and a read.</p>
Parameter SCREENKEY = "agent.definitions";

/// <p>The accounts' password for this run, generated in <method>OnBeforeAllTests</method> and never
/// written to source.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back, through
/// <code>$SYSTEM.Security.CheckUserPermission</code>, that each account holds exactly what it is
/// meant to.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

/// <p>The definition the refusals are aimed at, created as the suite's own account.</p>
Property PreparedDefinitionId As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Set ..PreparedDefinitionId = ""
    Quit $$$OK
}

/// <p>Refuse to run at all unless <parameter>ARMINGVARIABLE</parameter> arms this class, then
/// create the two principals and one definition for them to be refused on.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ConfigGate creates and deletes IRIS users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    ; Read before the switch: OcuPilot's classes are not mapped into %SYS, so a
    ; ##class(...).#PARAMETER reference evaluated there raises <CLASS DOES NOT EXIST>.
    Set tAdminResource = ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE
    Try {
        Set tSC = ##class(OcuPilot.Install.Installer).Install("")
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "Gate", 0, 0, .tRow)
        If $$$ISERR(tSC) Quit
        Set ..PreparedDefinitionId = tRow.%Id()
        Set tRow = ""

        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotGate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

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

        Set tSC = ..EnsurePrincipal(..#OPERATEROLE, ..#OPERATEUSER, tCodeRead _ "," _ ..#OPERATERESOURCE _ ":U")
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#NOADMINROLE, ..#NOADMINUSER, tCodeRead)
        If $$$ISERR(tSC) Quit

        Set tOperateHolds = ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, ..#OPERATERESOURCE, "USE") = 1)
        Set tOperateLacks = ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, tAdminResource, "USE") '= 1)
        Set tFloorLacks = ($SYSTEM.Security.CheckUserPermission(..#NOADMINUSER, ..#OPERATERESOURCE, "USE") '= 1)
        Set ..PreparedSetupOk = tOperateHolds && tOperateLacks && tFloorLacks && (..PreparedDefinitionId '= "")
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the two principals' pairs: operate holds " _ ..#OPERATERESOURCE _ " " _ tOperateHolds _ ", operate lacks " _ tAdminResource _ " " _ tOperateLacks _ ", floor lacks " _ ..#OPERATERESOURCE _ " " _ tFloorLacks _ ", definition id '" _ ..PreparedDefinitionId _ "'")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove both principals and the definition, and <b>return a failing status</b> if any
/// survives. Reported through the status rather than assertions, which
/// <class>%UnitTest.Manager</class> does not record from this method.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tLeft = ""
    Try {
        Set tRemoveSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
        If $$$ISERR(tRemoveSC) || (tRemaining '= 0) {
            Set tLeft = tLeft _ "agent definitions (" _ tRemaining _ " left, " _ $System.Status.GetErrorText(tRemoveSC) _ ")"
        }
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        For tUser = ..#OPERATEUSER, ..#NOADMINUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ tUser
        }
        For tRole = ..#OPERATEROLE, ..#NOADMINROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ tRole
        }
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.ConfigGate teardown left throwaway objects on the instance: " _ tLeft)
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
Method EnsurePrincipal(pRole As %String, pUser As %String, pResources As %String) As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(pRole, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tModProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(pRole, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: configuration gate principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(pUser)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(pUser, pRole, ..PreparedPassword, "OcuPilot configuration gate test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.ConfigGate; deleted in OnAfterAllTests")
}

/// <p>Every route the shipped <code>UrlMap</code> declares, as
/// <code>pRoutes(i,"url")</code> / <code>pRoutes(i,"method")</code> with the count in
/// <code>pRoutes</code>. Read from the compiled XData rather than restated, so the population
/// swept is the population served.</p>
ClassMethod Routes(Output pRoutes) As %Status
{
    Kill pRoutes
    Set pRoutes = 0
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Api.Router", "UrlMap", , .tOpenSC)
    If '$IsObject(tXData) Quit $$$ERROR($$$GeneralError, "the router's UrlMap could not be read")
    Do tXData.Data.Rewind()
    ; Read to the end rather than one 32000-character bite: a map that outgrew one read would be
    ; silently truncated, and every "count > 0" guard below would keep passing over the short list.
    Set tMap = ""
    While 'tXData.Data.AtEnd {
        Set tMap = tMap _ tXData.Data.Read(32000)
    }
    Set tPos = 1
    For {
        Set tStart = $Find(tMap, "<Route", tPos)
        If tStart = 0 Quit
        Set tEnd = $Find(tMap, ">", tStart)
        If tEnd = 0 Quit
        Set tTag = $Extract(tMap, tStart, tEnd - 1)
        Set tPos = tEnd
        Set tUrl = ..Attribute(tTag, "Url")
        Set tMethod = ..Attribute(tTag, "Method")
        If (tUrl = "") || (tMethod = "") Continue
        Set pRoutes = pRoutes + 1
        Set pRoutes(pRoutes, "url") = tUrl
        Set pRoutes(pRoutes, "method") = tMethod
    }
    Quit $$$OK
}

/// <p>One double-quoted XML attribute's value out of <var>pTag</var>, or <code>""</code>.</p>
ClassMethod Attribute(pTag As %String, pName As %String) As %String
{
    Set tStart = $Find(pTag, pName _ "=""")
    If tStart = 0 Quit ""
    Quit $Piece($Extract(pTag, tStart, *), """", 1)
}

/// <p><var>pUrl</var> with every <code>:param</code> segment replaced by a value a request can
/// carry: the prepared definition's id, or <parameter>SCREENKEY</parameter> for the screen-read
/// route. A concrete id matters -- an ungated handler would answer 404 for one no row holds, and
/// a 404 is not a refusal.</p>
Method ConcretePath(pUrl As %String) As %String
{
    Set tOut = ""
    For tI = 2:1:$Length(pUrl, "/") {
        Set tSegment = $Piece(pUrl, "/", tI)
        If $Extract(tSegment) = ":" {
            Set tSegment = $Select(tSegment = ":screen": ..#SCREENKEY, 1: ..PreparedDefinitionId)
        }
        Set tOut = tOut _ "/" _ tSegment
    }
    Quit tOut
}

/// <p>The closed exception list AC1 allows: the two <parameter>CONFIGPREFIX</parameter> routes
/// that answer a caller holding no OcuPilot administrative resource, each with the reason it
/// does. Entries are <code>$ListBuild(method, url, reason)</code>, and the url is the route as the
/// map declares it -- a list naming a route the map does not carry fails the sweep.</p>
ClassMethod Exceptions() As %List
{
    Quit $ListBuild($ListBuild("GET", "/agent/definitions", "the selection projection is what the switcher needs and what every portal user may see (AD-46)"), $ListBuild("GET", "/agent/restraint", "it answers the calling user their own verdict, and the audience for the kill-switch banner is precisely the people who cannot change it"), $ListBuild("GET", "/agent/context", "it answers the calling user their own screen-context sharing choice and instance facts (Story 4.4), caller-own like /agent/restraint"), $ListBuild("PUT", "/agent/context", "it stores only the calling user's own sharing choice (Story 4.4), never another user's row or an instance setting"))
}

/// <p>The exception entry for <var>pMethod</var> <var>pUrl</var>, or <code>""</code>.</p>
ClassMethod ExceptionFor(pMethod As %String, pUrl As %String) As %List
{
    Set tList = ..Exceptions()
    For tI = 1:1:$ListLength(tList) {
        Set tEntry = $List(tList, tI)
        If ($List(tEntry, 1) = pMethod) && ($List(tEntry, 2) = pUrl) Quit
        Set tEntry = ""
    }
    Quit $Get(tEntry)
}

/// <p>One request to <var>pPath</var> as <var>pUser</var>.</p>
Method Call(pMethod As %String, pPath As %String, pUser As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Set tBody = $Select($ListFind($ListBuild("POST", "PUT"), pMethod): "{}", 1: "")
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ pPath, pUser, ..PreparedPassword, .pStatus, .pBody, .pHeaders, tBody, "application/json")
}

/// <p>AC1 -- <b>every configuration route the shipped map declares is refused</b> to a principal
/// holding <code>%Admin_Operate</code> and not OcuPilot's administrative resource, with
/// <code>AUTH.NOPRIVILEGE</code> and the failed pair named (AD-8), except the two the closed
/// exception list carries with its reason. The sweep is over the map, so a route added later is
/// covered by arriving there.</p>
/// <p><b>Nothing is written.</b> The definition count is asserted around the refused writes and
/// the prepared definition is read back, because a 403 that had already written would still be a
/// 403.</p>
/// <p>Mutation (Rule 19): delete the <code>IsAdministrator()</code> arm from any one handler --
/// the sweep goes red naming that route.</p>
Method TestEveryConfigurationRouteRefusesAPrincipalWithoutTheAdministrativeResource()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal holds %Admin_Operate and not OcuPilot's administrative resource")
    Set tExpectedPair = ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE _ ":" _ ..#ADMINPERMISSION
    Set tRoutesSC = ..Routes(.tRoutes)
    Do $$$AssertStatusOK(tRoutesSC, "the shipped UrlMap is readable")
    If $$$ISERR(tRoutesSC) Quit

    ; A route count of zero is a sweep that asserted nothing, which is the vacuous pass this
    ; test exists to make impossible.
    Set tConfig = 0
    For tI = 1:1:tRoutes {
        If $Extract(tRoutes(tI, "url"), 1, $Length(..#CONFIGPREFIX)) = ..#CONFIGPREFIX Set tConfig = tConfig + 1
    }
    Do $$$AssertTrue(tConfig > 0, "the map declares configuration routes to sweep: " _ tConfig)

    ; And an exception naming a route the map does not carry is a stale exemption, which would
    ; silently excuse nothing while reading as an excuse.
    Set tExceptions = ..Exceptions()
    For tE = 1:1:$ListLength(tExceptions) {
        Set tEntry = $List(tExceptions, tE)
        Set tSeen = 0
        For tI = 1:1:tRoutes {
            If (tRoutes(tI, "method") = $List(tEntry, 1)) && (tRoutes(tI, "url") = $List(tEntry, 2)) Set tSeen = 1
        }
        Do $$$AssertTrue(tSeen, "the exception list names a route the map declares: " _ $List(tEntry, 1) _ " " _ $List(tEntry, 2))
        Do $$$AssertTrue($List(tEntry, 3) '= "", "and carries the reason it is one: " _ $List(tEntry, 2))
    }

    Set tBefore = ##class(OcuPilot.Test.AgentFixture).ProbeCount()
    Do $$$AssertTrue(tBefore > 0, "a definition exists for the refusals to be aimed at: " _ tBefore)

    Set tSwept = 0
    For tI = 1:1:tRoutes {
        Set tUrl = tRoutes(tI, "url")
        Set tMethod = tRoutes(tI, "method")
        If $Extract(tUrl, 1, $Length(..#CONFIGPREFIX)) '= ..#CONFIGPREFIX Continue
        Set tSwept = tSwept + 1
        Set tPath = ..ConcretePath(tUrl)
        Set tSC = ..Call(tMethod, tPath, ..#OPERATEUSER, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tMethod _ " " _ tUrl _ ": the request completes")
        Set tException = ..ExceptionFor(tMethod, tUrl)
        If tException '= "" {
            ; A GET exception is answered 200. A PUT exception's trivial {} body can be refused on
            ; its own shape (422), which still proves the admin gate, a 403, never ran.
            If tMethod = "GET" {
                Do $$$AssertEquals(tStatus, 200, tMethod _ " " _ tUrl _ ": is answered, because " _ $List(tException, 3) _ " (" _ $Extract(tBody, 1, 200) _ ")")
            } Else {
                Do $$$AssertTrue((tStatus '= 403) && (tStatus < 500), tMethod _ " " _ tUrl _ ": is answered, not gated, because " _ $List(tException, 3) _ " (" _ tStatus _ ": " _ $Extract(tBody, 1, 200) _ ")")
            }
            Continue
        }
        Do $$$AssertEquals(tStatus, 403, tMethod _ " " _ tUrl _ ": is refused (" _ $Extract(tBody, 1, 300) _ ")")
        Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, tMethod _ " " _ tUrl _ ": as JSON")
        If tStatus '= 403 Continue
        Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", tMethod _ " " _ tUrl _ ": on the screen-privilege code")
        Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), tExpectedPair, tMethod _ " " _ tUrl _ ": naming " _ tExpectedPair)
    }
    ; No tSwept-versus-tConfig assertion: both counters are produced by the same predicate over the
    ; same array, so they are equal by construction and the comparison could not fail (Rule 19).
    ; The guard that does work is tConfig > 0 above.

    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), tBefore, "the refused writes left the definition count unchanged")
    Set tOpenSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(..PreparedDefinitionId, .tRow)
    Do $$$AssertStatusOK(tOpenSC, "the definition the refusals were aimed at still opens")
    If $$$ISERR(tOpenSC) Quit
    Do $$$AssertEquals(tRow.Name, ..#PROBEPREFIX _ "Gate", "and the refused delete left it where it was")
    Set tRow = ""
}

/// <p>AC4's floor -- <b>every route the map declares</b>, configuration or not, refuses a principal
/// holding no <code>%Admin_*</code> resource with <code>AUTH.NOADMIN</code> and the FR-3 sentence.
/// The refusal is on the dispatcher, so a route added later inherits it rather than declaring its
/// own.</p>
/// <p>Mutation (Rule 19): delete the administrative floor from
/// <method>OcuPilot.Api.Router.OnPreDispatch</method> -- this goes red on every route at once.</p>
Method TestEveryDeclaredRouteRefusesAPrincipalHoldingNoAdministrativeResource()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the floor principal holds no administrative resource")
    Set tRoutesSC = ..Routes(.tRoutes)
    Do $$$AssertStatusOK(tRoutesSC, "the shipped UrlMap is readable")
    If $$$ISERR(tRoutesSC) Quit
    Do $$$AssertTrue(tRoutes > 0, "the map declares routes to sweep: " _ tRoutes)

    For tI = 1:1:tRoutes {
        Set tUrl = tRoutes(tI, "url")
        Set tMethod = tRoutes(tI, "method")
        Set tPath = ..ConcretePath(tUrl)
        Set tSC = ..Call(tMethod, tPath, ..#NOADMINUSER, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tMethod _ " " _ tUrl _ ": the request completes")
        Do $$$AssertEquals(tStatus, 403, tMethod _ " " _ tUrl _ ": is refused (" _ $Extract(tBody, 1, 300) _ ")")
        If tStatus '= 403 Continue
        Do $$$AssertEquals((tBody [ "}{"), 0, tMethod _ " " _ tUrl _ ": exactly one envelope reaches the wire")
        Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tRefusal.code, "AUTH.NOADMIN", tMethod _ " " _ tUrl _ ": on the no-administrative-privilege code")
        Do $$$AssertTrue(tRefusal.reason [ "%Admin_", tMethod _ " " _ tUrl _ ": with the FR-3 sentence naming the resource class: " _ tRefusal.reason)
    }
}

/// <p>AC5's API half -- <b>every screen descriptor that declares OcuPilot's administrative
/// resource and a read</b> is refused over
/// <code>GET /screens/&lt;toolIdentifier&gt;/read</code> to the same principal, with the failed
/// pair named. Derived from the registry, so a screen that gains an administratively-gated read
/// is swept by declaring one.</p>
/// <p>Mutation (Rule 19): drop the <code>OcuPilotAdmin:USE</code> pair from
/// <class>OcuPilot.Screen.Descriptor.AgentDefinitionList</class> -- the route answers 200 to this
/// principal and this goes red. (It also empties the swept set, which the count assertion catches
/// separately.)</p>
Method TestEveryAdministrativelyGatedScreenReadIsRefusedToTheSamePrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal holds %Admin_Operate and not OcuPilot's administrative resource")
    Set tAdminResource = ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE
    Set tExpectedPair = tAdminResource _ ":" _ ..#ADMINPERMISSION
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
    Do $$$AssertStatusOK(tSC, "the screen registry is readable")
    If $$$ISERR(tSC) Quit

    Set tSwept = 0
    For tI = 1:1:$ListLength(tList) {
        Set tClass = $List(tList, tI)
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs")
        Set tGated = 0
        For tJ = 1:1:$ListLength(tPairs) {
            Set tPair = $List(tPairs, tJ)
            If ($List(tPair, 1) = tAdminResource) && ($List(tPair, 2) = ..#ADMINPERMISSION) Set tGated = 1
        }
        If 'tGated Continue
        If '$IsObject($ClassMethod(tClass, "Read")) Continue
        Set tIdentifier = $ClassMethod(tClass, "ToolIdentifier")
        Do $$$AssertTrue(tIdentifier '= "", tClass _ ": declares a tool identifier to build its read route from")
        If tIdentifier = "" Continue
        Set tSwept = tSwept + 1
        Set tRequestSC = ..Call("GET", "/screens/" _ tIdentifier _ "/read?maxRows=5", ..#OPERATEUSER, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tRequestSC, tIdentifier _ ": the read request completes")
        Do $$$AssertEquals(tStatus, 403, tIdentifier _ ": the screen read is refused (" _ $Extract(tBody, 1, 300) _ ")")
        If tStatus '= 403 Continue
        Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, tIdentifier _ ": as JSON")
        Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", tIdentifier _ ": on the screen-privilege code")
        Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), tExpectedPair, tIdentifier _ ": naming " _ tExpectedPair)
    }
    Do $$$AssertTrue(tSwept > 0, "at least one descriptor declares OcuPilot's administrative resource and a read, so the sweep asserted something: " _ tSwept)
}

}
