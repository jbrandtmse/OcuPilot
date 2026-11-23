/// <p>Pins Story 24.16's Suspended messages list end to end (AD-29, AD-36, AD-62): the port's list, the screen's read and the agent's read tool each answer exactly the
/// suspended headers of the namespace, newest first, with the declared fields and no status column, and not a Completed, a Discarded or another namespace's header; a
/// read capped below the number of headers reports its truncation; the list is gated by the message viewer's pairs.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, an
/// interoperability-enabled <code>USER</code> namespace, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe
/// production in <code>USER</code></b> and stores probe headers in <code>USER</code> and <code>HSCUSTOM</code> (<class>OcuPilot.Test.InteropSuspendedCase</class>). One
/// class per run.</p>
Class OcuPilot.Test.InteropSuspendedList Extends OcuPilot.Test.InteropSuspendedCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.InteropSuspendedMessageList";

/// <p>The ids of <var>pRows</var> (a JSON array of row objects), comma-separated in the order given, restricted to those above <var>pAbove</var>.</p>
ClassMethod Ids(pRows, pAbove As %Integer = 0) As %String
{
    Set tIds = ""
    If '$IsObject(pRows) Quit tIds
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If +tRow.%Get("ID") > pAbove Set tIds = tIds _ $Select(tIds = "": "", 1: ",") _ tRow.%Get("ID")
    }
    Quit tIds
}

/// <p>The screen is declared as the plan places it: in the Interoperability area at side bar 18 as a list over the interoperability port's <code>SuspendedMessages</code>, with
/// Resubmit, Edit and resubmit, Discard and Delete as its row actions, the first, third and last over the checked rows (at most 100), over <code>%Ens_MessageHeader:USE</code>, naming
/// the entity type <code>interop-message</code> and the classic page it replaces.</p>
/// <p>Mutation (Rule 19): change the screen's <code>sideBarPosition</code> to 17 -- this goes red.</p>
Method TestTheDeclarationRegisters()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the screen declares JSON")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.area, "interoperability/suspended-messages|18|list|interoperability", "its route, place, archetype and area")
    Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.toolIdentifier, "interop-message|namespace|interop.suspendedmessages", "its entity type, its scope and its tool identifier")
    Set tActions = ""
    For tI = 0:1:tDeclaration.rowActions.%Size() - 1 {
        Set tActions = tActions _ $Select(tActions = "": "", 1: ",") _ tDeclaration.rowActions.%Get(tI).id
    }
    Do $$$AssertEquals(tActions, "resubmit,editresubmit,discard,delete", "its row actions, the destructive Delete last")
    Do $$$AssertEquals(tDeclaration.multiSelect.%ToJSON(), "{""action"":""resubmit"",""max"":100,""extraActions"":[""discard"",""delete""]}", "the checked rows resubmit, discard and delete, at most the port's cap")
    Do $$$AssertEquals(tDeclaration.classicPage, "EnsPortal.SuspendedMsg", "its classic page")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_MessageHeader"",""permission"":""USE""}]", "its pairs are the classic page's")
    Do $$$AssertEquals(tDeclaration.multiSelect.max, $Parameter(..#PORT, "RESENDMAX"), "and the cap is the port's")
}

/// <p>AC1: with three suspended headers, a Completed one and a Discarded one in USER, the port's list, the screen's read and the agent's read tool each answer the three
/// suspended ones, newest first, and not the other two; a row carries <code>ID</code>, <code>TimeCreated</code>, <code>SessionId</code>, <code>Error</code>,
/// <code>Type</code>, <code>Source</code>, <code>Target</code> and <code>BodyClass</code>, and no <code>Status</code>.</p>
/// <p>Mutation (Rule 19): drop the status from the <code>WHERE</code> of <parameter>OcuPilot.Port.InteropPort.SUSPENDEDSQL</parameter> -- the Completed and Discarded
/// headers are listed and every leg goes red.</p>
Method TestTheListHoldsTheSuspendedHeadersNewestFirstForEveryReader()
{
    Set tMark = +$ClassMethod(..#FIXTURE, "TopId")
    Set tA = ..Susp("alpha")
    Set tB = ..Susp("beta")
    Set tC = ..Susp("gamma")
    Set tDone = ..Make("delta")
    Set tOut = ..Susp("epsilon")
    Do $$$AssertStatusOK(..Move(tOut, 4), "a fifth header is discarded")
    Set tExpected = tC _ "," _ tB _ "," _ tA
    Do $$$AssertEquals(..SPort("LIST", "", .tRows), "200 ", "the port lists")
    Do $$$AssertEquals(..Ids(tRows, tMark), tExpected, "the port's list is the three suspended headers, newest first")
    If $IsObject(tRows) && (tRows.%Size() > 0) {
        Set tRow = tRows.%Get(0)
        Do $$$AssertEquals(tRow.%GetTypeOf("Error") _ "|" _ tRow.Type _ "|" _ tRow.Source _ "|" _ tRow.Target _ "|" _ tRow.BodyClass _ "|" _ tRow.%GetTypeOf("Status"), "boolean|Request|" _ ..#SVCNAME _ "|" _ ..#OPNAME _ "|Ens.StringRequest|unassigned", "a row names its type, source, target and body class, an error flag and no status")
        Do $$$AssertTrue((tRow.TimeCreated '= "") && (tRow.SessionId = $ClassMethod(..#FIXTURE, "Property", tC, "SessionId")), "and its time and session")
    }
    Do $ClassMethod(..#CONTROL, "Call", "GET", ..#SCREEN _ "/read?maxRows=1000", "", .tStatus, .tScreen)
    Do $$$AssertEquals(tStatus, 200, "the screen's read answers: " _ $Select($IsObject(tScreen): $Extract(tScreen.%ToJSON(), 1, 300), 1: ""))
    Do $$$AssertEquals($Select($IsObject(tScreen): ..Ids(tScreen.%Get("rows"), tMark), 1: ""), tExpected, "the screen's read is the same three")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.suspendedmessages.read", .tTool)
    Do $$$AssertStatusOK(tSC, "the agent's read tool is registered")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 1000, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertEquals(+$Get(tToolHttp), 200, "the agent's read tool answers")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): ..Ids(tResult.%Get("rows"), tMark), 1: ""), tExpected, "the agent's read is the same three")
    Do $$$AssertEquals(tDone > 0, 1, "the Completed header exists and is not listed: " _ tDone)
}

/// <p>AC1: a read capped below the number of suspended headers answers that many of the newest and says it was cut (AD-36), and a call that names no cap lists every header.</p>
/// <p>Mutation (Rule 19): bind the cap of <method>OcuPilot.Port.InteropPort.ListSuspended</method> as 1 -- the cap legs go red.</p>
Method TestACappedReadAnswersTheNewestAndReportsTheCut()
{
    Set tMark = +$ClassMethod(..#FIXTURE, "TopId")
    Set tA = ..Susp("alpha")
    Set tB = ..Susp("beta")
    Set tC = ..Susp("gamma")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("maxRows") = 2
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ "|" _ ..Ids(tRows, tMark), "200|" _ tC _ "," _ tB, "a cap of two lists the two newest")
    Do $ClassMethod(..#CONTROL, "Call", "GET", ..#SCREEN _ "/read?maxRows=2", "", .tStatus, .tScreen)
    Do $$$AssertEquals($Select($IsObject(tScreen): (tScreen.%Get("rows").%Size() _ "|" _ tScreen.%Get("truncated")), 1: ""), "2|1", "the screen's read of two rows reports that it was cut")
    Kill tBad
    Set tBad("namespace") = ..#NAMESPACE
    Set tBad("maxRows") = "0"
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "LIST", .tBad, "", .tNone, .tBadHttp, .tBadFault)
    Do $$$AssertEquals(+$Get(tBadHttp) _ " " _ $Select($IsObject($Get(tBadFault)): tBadFault.%Get("code"), 1: ""), "400 PORT.VALIDATION", "a cap that is not a whole number above zero is refused")
}

/// <p>AC1: the list reads the namespace it is asked for: HSCUSTOM's own suspended probe is listed there and not in USER, and USER's are not listed in HSCUSTOM.</p>
/// <p>Mutation (Rule 19): read <code>USER</code> in <method>OcuPilot.Port.InteropPort.ListSuspended</method> whatever the namespace -- the HSCUSTOM leg goes red.</p>
Method TestTheListReadsTheNamespaceItIsAskedFor()
{
    Set tMark = +$ClassMethod(..#FIXTURE, "TopId")
    Set tUser = ..Susp("alpha")
    Set tOther = ..OtherSuspended("L1")
    Do $$$AssertTrue(tOther > 0, "a suspended probe is stored in HSCUSTOM")
    Do $$$AssertEquals(..SPort("LIST", "", .tOwn, , , , , ..#OTHERNAMESPACE), "200 ", "HSCUSTOM lists")
    Do $$$AssertTrue($ListFind($ListFromString(..Ids(tOwn)), tOther) && '$ListFind($ListFromString(..Ids(tOwn)), tUser), "HSCUSTOM's list holds its probe and not USER's")
    Do $$$AssertEquals(..SPort("LIST", "", .tHere), "200 ", "USER lists")
    Do $$$AssertEquals(..Ids(tHere, tMark), tUser, "USER's list holds its own and not HSCUSTOM's")
}

/// <p>AC4: the list asks the message viewer's pairs and no more: a caller holding neither the Interoperability menu's nor the viewer's is refused 403 naming the pair, and one
/// holding both lists, before any vendor call.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_MessageHeader:USE</code> from the Suspended messages branch of <method>OcuPilot.Port.InteropPort.Pairs</method> -- the second leg
/// goes red.</p>
Method TestTheListAsksTheViewersPairs()
{
    Do $ClassMethod(..#SEAM, "Arm")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Set tCode = ..SPort("LIST", "", .tRows, , , , .tFault, ..#NAMESPACE, ..#SEAM)
    Do $$$AssertEquals(tCode _ "|" _ $Select($IsObject(tFault): tFault.detail.failedPair, 1: ""), "403 AUTH.NOPRIVILEGE|%Ens_MessageHeader:USE", "without the viewer's pair the list is refused naming it")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageHeader", "USE")
    Do $$$AssertEquals(..SPort("LIST", "", .tRows, , , , .tFault, ..#NAMESPACE, ..#SEAM), "200 ", "holding both pairs the list is answered")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Set tCode = ..SPort("LIST", "", .tRows, , , , .tFault, ..#NAMESPACE, ..#SEAM)
    Do $$$AssertEquals(tCode _ "|" _ $Select($IsObject(tFault): tFault.detail.failedPair, 1: ""), "403 AUTH.NOPRIVILEGE|%Ens_Portal:USE", "without the menu's pair it is refused naming that one")
}

}
