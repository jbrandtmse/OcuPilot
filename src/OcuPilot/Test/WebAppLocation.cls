/// <p>Pins AD-21's WSGI directory rule on both callers of the web-application create (AD-55,
/// DW-1495), and the unauthenticated consequence a create's proposal carries (DW-1489).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state
/// readable. Every write goes to <class>OcuPilot.Test.ProposalFixture</class>, so nothing here
/// creates a web application; the screen path's name-taken read is live, so
/// <parameter>PROBEAPP</parameter> must be a name the instance does not hold. No arming variable is
/// required.</p>
Class OcuPilot.Test.WebAppLocation Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.WebAppCreate";

Parameter LIST = "OcuPilot.Screen.Descriptor.WebAppList";

/// <p>The shipped screen route with only its port replaced.</p>
Parameter SCREEN = "OcuPilot.Test.CreateFixture";

/// <p>The shipped mint and confirm with the port replaced.</p>
Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter STORE = "OcuPilot.Kernel.State.Propose";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The name every create here proposes; nothing on the instance holds it.</p>
Parameter PROBEAPP = "/csp/ocupilotprobelocation";

/// <p>The one valid directory name the resolved-path legs use.</p>
Parameter VALIDNAME = "probeapp";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    If ##class(OcuPilot.Test.WebAppWire).Exists(..#PROBEAPP) Do ##class(OcuPilot.Test.WebAppWire).Remove(..#PROBEAPP)
    Quit $$$OK
}

/// <p>A <code>..</code>, an absolute path and a sibling escape are each refused on the screen route
/// and on <code>webapp.list.create</code>, and neither reaches the port.</p>
/// <p>Mutation: make <method>OcuPilot.Area.WebApp.Location.Resolve</method> return 1 with the
/// caller's text -> every leg below goes red, on both callers.</p>
Method TestAnEscapingLocationIsRefusedOnBothCallers()
{
    For tLocation = "..", "/tmp/ocupilotprobe", "../wsgiprobe" {
        Set tArgs = ..Args(tLocation)

        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Set tSC = $ClassMethod(..#SCREEN, "Perform", ..#PROBEAPP, tArgs, .tCreated, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(..CodeFor(.tViolations, "WSGIAppLocation"), ##class(OcuPilot.Api.Error).#WEBAPPWSGIAPPLOCATIONSHAPE, "the screen route refuses '" _ tLocation _ "' on the directory field")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and '" _ tLocation _ "' never reaches the port from the screen")

        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
        Set tSC = ..Mint(tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, "the agent's mint refuses '" _ tLocation _ "'")
        Do $$$AssertEquals(tHttp, 400, "at 400")
        Set tProblem = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("problem"), 1: "")
        Do $$$AssertTrue(tProblem [ "'WSGIAppLocation': ", "naming the directory field: " _ tProblem)
    }
}

/// <p>A valid name is sent as its directory under the fixed root, computed at the call, as both
/// <code>WSGIAppLocation</code> and <code>Path</code>, from the screen route and from the agent's
/// confirm alike -- the caller's own text is sent by neither.</p>
/// <p>Mutation: make <method>OcuPilot.Area.WebApp.Location.Resolve</method> return 1 with the
/// caller's text -> both bodies carry <code>probeapp</code> and this goes red on both callers.</p>
Method TestAValidNameIsSentAsItsDirectoryUnderTheRootOnBothCallers()
{
    Set tRoot = ##class(OcuPilot.Area.WebApp.Location).Root()
    Do $$$AssertTrue($Extract(tRoot, *-4, *) = "wsgi/", "the root is the manager directory's wsgi directory: " _ tRoot)
    Set tExpected = tRoot _ ..#VALIDNAME _ "/"
    Set tArgs = ..Args(..#VALIDNAME)

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#SCREEN, "Perform", ..#PROBEAPP, tArgs, .tCreated, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen route accepts a valid directory name")
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Set tScreen = ..LastBody()
    Do $$$AssertEquals(tScreen.%Get("WSGIAppLocation"), tExpected, "the screen sends the resolved directory as WSGIAppLocation")
    Do $$$AssertEquals(tScreen.%Get("Path"), tExpected, "and as Path")

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's mint accepts it")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and its confirm applies it")
    Set tAgent = ..LastBody()
    Do $$$AssertEquals(tAgent.%Get("WSGIAppLocation"), tExpected, "the confirm sends the resolved directory as WSGIAppLocation")
    Do $$$AssertEquals(tAgent.%Get("Path"), tExpected, "and as Path")
}

/// <p>The prefix check on its own: a normalized sibling of the root, the root itself and an empty
/// candidate are outside, and a directory beneath the root is inside.</p>
/// <p>Mutation: drop the root's trailing separator from the comparison in
/// <method>OcuPilot.Area.WebApp.Location.IsInsideRoot</method> -> the sibling leg goes red.</p>
Method TestThePrefixCheckRefusesANormalizedSibling()
{
    Set tRoot = ##class(OcuPilot.Area.WebApp.Location).Root()
    Do $$$AssertNotEquals(tRoot, "", "the root is computed")
    Set tManager = ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory())
    Do $$$AssertEquals($Extract(tRoot, 1, $Length(tManager)), tManager, "under the manager directory")
    Set tSibling = ##class(%File).NormalizeDirectory(tManager _ "wsgiprobe")
    Do $$$AssertEquals(##class(OcuPilot.Area.WebApp.Location).IsInsideRoot(tRoot, tSibling), 0, "a sibling sharing the root's name as a prefix is outside: " _ tSibling)
    Do $$$AssertEquals(##class(OcuPilot.Area.WebApp.Location).IsInsideRoot(tRoot, tRoot), 0, "the root itself is refused")
    Do $$$AssertEquals(##class(OcuPilot.Area.WebApp.Location).IsInsideRoot(tRoot, ""), 0, "and so is an empty candidate")
    Do $$$AssertEquals(##class(OcuPilot.Area.WebApp.Location).IsInsideRoot(tRoot, tRoot _ ..#VALIDNAME _ "/"), 1, "a directory beneath the root is inside")
    For tName = "a..b", "x/y", "", "-lead", $Translate($Justify("", 65), " ", "a") {
        Do $$$AssertEquals(##class(OcuPilot.Area.WebApp.Location).Resolve(tName, .tPath), 0, "'" _ tName _ "' does not resolve")
        Do $$$AssertEquals(tPath, "", "and yields no path")
    }
}

/// <p>The confirm-time half of the rule: <method>OcuPilot.Screen.Tool.WebAppCreate.DerivedFields</method>
/// drops both <code>WSGIAppLocation</code> and <code>Path</code> from a body whose name does not
/// resolve, rather than passing the caller's text through, and sets both to the resolved directory
/// for one that does.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Tool.WebAppCreate.DerivedFields</method> leave the body
/// alone when the name does not resolve -> the dropped-keys legs go red.</p>
Method TestAnUnresolvableLocationDropsBothKeys()
{
    For tLocation = "..", "/tmp/ocupilotprobe", "../wsgiprobe" {
        Set tPayload = {"WSGIAppLocation": (tLocation), "Path": (tLocation)}
        Do $ClassMethod(..#TOOL, "DerivedFields", tPayload)
        Do $$$AssertEquals(tPayload.%GetTypeOf("WSGIAppLocation"), "unassigned", "'" _ tLocation _ "' is not sent as the location")
        Do $$$AssertEquals(tPayload.%GetTypeOf("Path"), "unassigned", "nor as the path")
    }
    Set tPayload = {"WSGIAppLocation": (..#VALIDNAME)}
    Do $ClassMethod(..#TOOL, "DerivedFields", tPayload)
    Set tExpected = ##class(OcuPilot.Area.WebApp.Location).Root() _ ..#VALIDNAME _ "/"
    Do $$$AssertEquals(tPayload.%Get("WSGIAppLocation"), tExpected, "a name that resolves is sent as its directory")
    Do $$$AssertEquals(tPayload.%Get("Path"), tExpected, "as both keys")
}

/// <p>DW-1489: a create choosing Unauthenticated is minted, not refused, and its proposal carries
/// <code>WEBAPP.UNAUTHENTICATED</code> on the stored row and on the wire; one that does not carries
/// <code>""</code>.</p>
/// <p>Mutation: return <code>""</code> from
/// <method>OcuPilot.Screen.Tool.WebAppCreate.Consequence</method> -> the first half goes red.</p>
Method TestTheUnauthenticatedConsequenceIsStoredAndNotRefused()
{
    Set tArgs = ..Args(..#VALIDNAME)
    Do tArgs.%Set("AutheEnabled", 96, "number")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(tArgs, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a create choosing Unauthenticated is minted, not refused")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(..StoredConsequence(tProposal.%Get("proposalId")), "WEBAPP.UNAUTHENTICATED", "its stored row carries the unauthenticated consequence")
    Do $$$AssertEquals(..WireConsequence(tTurnKey, tProposal.%Get("proposalId")), "WEBAPP.UNAUTHENTICATED", "and so does its wire row")

    Do tArgs.%Set("AutheEnabled", 32, "number")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(tArgs, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a password-only create is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(..StoredConsequence(tProposal.%Get("proposalId")), "", "and carries no consequence")
    Do $$$AssertEquals(..WireConsequence(tTurnKey, tProposal.%Get("proposalId")), "", "on the wire either")
}

/// <p>A WSGI create's arguments with <var>pLocation</var> as its directory.</p>
ClassMethod Args(pLocation As %String) As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set("NameSpace", $Namespace, "string")
    Do tArgs.%Set("AutheEnabled", 32, "number")
    Do tArgs.%Set("WSGIAppName", "probe.py", "string")
    Do tArgs.%Set("WSGICallable", "app", "string")
    Do tArgs.%Set("WSGIAppLocation", pLocation, "string")
    Do tArgs.%Set("WSGIType", "WSGI", "string")
    Quit tArgs
}

/// <p>Mint one create of <parameter>PROBEAPP</parameter> from <var>pArgs</var> through the fixture
/// mint, as <method>OcuPilot.Screen.Tool.Write.View</method> would.</p>
Method Mint(pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTurnKey As %String) As %Status
{
    Set pTurnKey = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#MINT, "Mint", ..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), ..#PROBEAPP, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>The body the fixture port last received, parsed, or <code>{}</code>.</p>
ClassMethod LastBody() As %DynamicObject
{
    Set tText = ##class(OcuPilot.Test.ProposalFixture).LastWriteBody()
    If tText = "" Quit {}
    Quit ##class(%DynamicAbstractObject).%FromJSON(tText)
}

/// <p>The consequence proposal <var>pKey</var>'s stored row carries.</p>
ClassMethod StoredConsequence(pKey As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pKey, .tFound, .tValues)
    If $$$ISERR(tSC) || 'tFound Quit "<unread>"
    Quit $Get(tValues("consequence"), "<absent>")
}

/// <p>The consequence turn <var>pTurnKey</var>'s wire row for <var>pKey</var> carries.</p>
ClassMethod WireConsequence(pTurnKey As %String, pKey As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(pTurnKey, $Username, .tRows)
    If $$$ISERR(tSC) Quit "<unread>"
    Set tFound = "<absent>"
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("proposalId") '= pKey Continue
        If tRow.%GetTypeOf("consequence") '= "string" Quit
        Set tFound = tRow.%Get("consequence")
    }
    Quit tFound
}

/// <p>The code <var>pViolations</var> carries for <var>pField</var>, or <code>""</code>.</p>
ClassMethod CodeFor(ByRef pViolations, pField As %String) As %String
{
    Set tCode = ""
    For tI = 1:1:+$Get(pViolations) {
        If $List(pViolations(tI), 1) = pField Set tCode = $List(pViolations(tI), 2) Quit
    }
    Quit tCode
}

}
