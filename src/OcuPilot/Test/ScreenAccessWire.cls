/// <p>Story 20.15's Screen permissions over HTTP, as two real principals (AD-8, AD-15, AD-44, AD-53, AD-64):
/// Dev, who holds <code>%Development:USE</code>, and Op, who does not
/// (<class>OcuPilot.Test.ScreenAccessFixture</class>). It pins the View, Not an adjuster, Raise, Reset,
/// Lower, Lower past the vendor, Audit and Classic union rows of the spec's matrix: the list answers every
/// built screen with the caller's own verdict; a caller without the pair is refused naming it on the read
/// and each action; an adjustment is followed by the navigation map, the screen's read and the write
/// action's gate and undone by a reset; a lowering opens the screen while a port's or the vendor's own check
/// still refuses by name; each accepted write is one <code>SecurityChange</code> row; and the classic page's
/// custom resource stays in force.</p>
/// <p>It needs <parameter>ARMINGVARIABLE</parameter> armed: the principals are created in
/// <method>OnBeforeAllTests</method>, which reads their grants back, and removed in
/// <method>OnAfterAllTests</method>; every adjustment is removed before and after each test.</p>
Class OcuPilot.Test.ScreenAccessWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it: <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.ScreenAccessFixture";

Parameter SCREEN = "agent.screenpermissions";

Parameter LOCKS = "osmgmt.locks";

Parameter PROCESSES = "osmgmt.processes";

Parameter WEBAPPS = "webapp.list";

/// <p>The resource a Raise adds, which Op does not hold.</p>
Parameter RAISED = "%Admin_Secure:USE";

/// <p>The resource the Classic union leg assigns to Locks' classic page.</p>
Parameter CLASSICRESOURCE = "OcuPilotProbeClassic";

Property PreparedPassword As %String;

Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

/// <p>Locks' classic page's custom resource as found, restored in <method>OnAfterOneTest</method>.</p>
Property PreparedClassic As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Set ..PreparedClassic = $c(0)
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ScreenAccessWire creates IRIS users and roles, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set ..PreparedPassword = "OcuPilotAcc" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#FIXTURE, "Prepare", ..PreparedPassword)
    Set ..PreparedSetupOk = $$$ISOK(tSC)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "ResetAll")
}

Method OnAfterOneTest() As %Status
{
    Do ..RestoreClassic()
    Quit $ClassMethod(..#FIXTURE, "ResetAll")
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Do $ClassMethod(..#FIXTURE, "ResetAll")
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ScreenAccessWire teardown left:" _ tLeft)
    Quit $$$OK
}

/// <p>One request as <var>pUser</var>; <var>pObject</var> is the parsed body, or <code>""</code>.</p>
Method As(pUser As %String, pMethod As %String, pPath As %String, Output pStatus As %Integer, Output pObject, pBody As %String = "") As %Status
{
    Set pObject = ""
    Set tSC = $ClassMethod(..#FIXTURE, "Call", pMethod, pPath, pUser, ..PreparedPassword, .pStatus, .tText, pBody)
    Try {
        If $Get(tText) '= "" Set pObject = ##class(%DynamicAbstractObject).%FromJSON(tText)
    } Catch {
        Set pObject = ""
    }
    Quit tSC
}

/// <p>One action of Screen permissions as <var>pUser</var>: <var>pAction</var> on <var>pScreen</var>
/// with <var>pPair</var> as the one value, when it names one.</p>
Method Act(pUser As %String, pAction As %String, pScreen As %String, pPair As %String, Output pStatus As %Integer, Output pObject) As %Status
{
    Set tBody = {"action": (pAction), "id": (pScreen)}
    If pPair '= "" Do tBody.%Set("values", {"Pair": (pPair)})
    Quit ..As(pUser, "POST", "/screens/" _ ..#SCREEN _ "/action", .pStatus, .pObject, tBody.%ToJSON())
}

/// <p>The code, failed pair and structured detail of the refusal <var>pObject</var>.</p>
ClassMethod Refusal(pObject) As %String
{
    If '$IsObject(pObject) Quit "|"
    Quit pObject.%Get("code") _ "|" _ $Select($IsObject(pObject.%Get("detail")): pObject.detail.%Get("failedPair"), 1: "")
}

/// <p>Whether the map opens <var>pTool</var>'s screen to <var>pUser</var>, in <var>pAllowed</var>, and the
/// pair it names when it does not.</p>
Method Verdict(pUser As %String, pTool As %String, Output pAllowed As %Boolean, Output pFailedPair As %String) As %Status
{
    Set pAllowed = -1
    Set pFailedPair = ""
    Set tRoute = $ClassMethod(##class(OcuPilot.Screen.Registry).DescriptorForTool(pTool), "Route")
    Set tSC = ..As(pUser, "GET", "/navigation", .tStatus, .tMap)
    If $$$ISERR(tSC) || (tStatus '= 200) || '$IsObject(tMap) Quit $$$ERROR($$$GeneralError, "the navigation map answered " _ tStatus)
    Set tAreas = tMap.areas.%GetIterator()
    While tAreas.%GetNext(.tIndex, .tArea) {
        Set tScreens = tArea.screens.%GetIterator()
        While tScreens.%GetNext(.tScreenIndex, .tScreen) {
            If tScreen.route '= tRoute Continue
            Set pAllowed = ''tScreen.allowed
            Set pFailedPair = tScreen.%Get("failedPair")
        }
    }
    Quit $$$OK
}

/// <p>The list's row for screen <var>pScreen</var> as <var>pUser</var> reads it, or <code>""</code>.</p>
Method Row(pUser As %String, pScreen As %String, Output pRows As %Integer) As %DynamicObject
{
    Set pRows = 0
    Set tSC = ..As(pUser, "GET", "/screens/" _ ..#SCREEN _ "/read", .tStatus, .tRead)
    If $$$ISERR(tSC) || (tStatus '= 200) || '$IsObject(tRead) Quit ""
    Set pRows = tRead.rows.%Size()
    Set tFound = ""
    Set tRows = tRead.rows.%GetIterator()
    While tRows.%GetNext(.tIndex, .tRow) {
        If tRow.Screen = pScreen {
            Set tFound = tRow
            Quit
        }
    }
    Quit tFound
}

/// <p>The pairs of <var>pList</var> spelled <code>resource:permission</code>, separated by a comma and a space,
/// as the list spells a set.</p>
ClassMethod Spelled(pList As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pList) {
        Set tPair = $List(pList, tI)
        Set tText = tText _ $Select(tText = "": "", 1: ", ") _ $List(tPair, 1) _ ":" _ $List(tPair, 2)
    }
    Quit tText
}

/// <p>Restore Locks' classic page to the custom resource <method>AssignClassic</method> found.</p>
Method RestoreClassic()
{
    If ..PreparedClassic = $c(0) Quit
    Set tPage = $ClassMethod(##class(OcuPilot.Screen.Registry).DescriptorForTool(..#LOCKS), "ClassicPage")
    Do ##class(%CSP.Portal.Utils).%SetCustomResource($ZConvert(tPage, "O", "URL"), ..PreparedClassic)
    Set ..PreparedClassic = $c(0)
}

/// <p><b>View (AC1)</b> -- Dev's read answers one row per built screen, each carrying the declared set, the
/// adjustment, the classic resource, what <method>OcuPilot.Screen.Gate.RequiredPairs</method> evaluates, and
/// the caller's own verdict; the read tool answers the same screens. An adjusted screen's row shows the
/// adjustment as its <code>Effective</code>.</p>
/// <p>Mutation (Rule 19): make <class>OcuPilot.Screen.Access</class> take <code>Effective</code> from the
/// declared set -- the adjusted-row leg goes red.</p>
Method TestTheViewListsEveryBuiltScreenWithTheCallersVerdict()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tDev = $ClassMethod(..#FIXTURE, "Dev")
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tAll)
    Set tBuilt = 0
    For tI = 1:1:$ListLength(tAll) {
        If $ClassMethod($List(tAll, tI), "IsBuilt") Set tBuilt = tBuilt + 1
    }
    Set tLocks = ..Row(tDev, ..#LOCKS, .tRows)
    Do $$$AssertEquals(tRows, tBuilt, "one row per built screen")
    Do $$$AssertTrue($IsObject(tLocks), "Locks has a row")
    If '$IsObject(tLocks) Quit
    Set tDescriptor = ##class(OcuPilot.Screen.Registry).DescriptorForTool(..#LOCKS)
    Set tEffective = ..Spelled(##class(OcuPilot.Screen.Gate).RequiredPairs(tDescriptor))
    Do $$$AssertEquals(tLocks.Effective, tEffective, "Effective is what the gate evaluates")
    Do $$$AssertEquals(tLocks.Declared, ..Spelled($ClassMethod(tDescriptor, "PrivilegePairs")), "Declared is the descriptor's set")
    Do $$$AssertEquals(tLocks.Adjustment _ "|" _ ''tLocks.Adjustable _ "|" _ ''tLocks.Holds _ "|" _ tLocks.FailedPair, "|1|0|%Admin_Operate:USE", "unadjusted, adjustable, not held by Dev, naming the first pair Dev lacks")
    Set tHome = ..Row(tDev, "shell.home", .tCount)
    Do $$$AssertTrue($IsObject(tHome), "Home has a row")
    If $IsObject(tHome) Do $$$AssertEquals(''tHome.Adjustable _ "|" _ ''tHome.Holds, "0|1", "Home cannot be adjusted and requires nothing")
    Set tOwn = ..Row(tDev, ..#SCREEN, .tCount)
    Do $$$AssertTrue($IsObject(tOwn), "Screen permissions has a row")
    If $IsObject(tOwn) Do $$$AssertEquals(''tOwn.Holds _ "|" _ ''tOwn.Adjustable, "1|0", "Dev holds its own pair and it cannot be adjusted")

    Set tAct = ..Act(tDev, "add-pair", ..#LOCKS, ..#RAISED, .tStatus, .tChanged)
    Do $$$AssertEquals(tStatus, 200, "Dev raises Locks")
    Set tRaised = ..Row(tDev, ..#LOCKS, .tCount)
    Do $$$AssertTrue($IsObject(tRaised), "Locks still has a row")
    If $IsObject(tRaised) {
        Do $$$AssertEquals(tRaised.Adjustment, tEffective _ ", " _ ..#RAISED, "the row shows the adjustment")
        Do $$$AssertEquals(tRaised.Effective, tEffective _ ", " _ ..#RAISED, "and Effective follows it")
    }

    Set tTool = ""
    Do ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#SCREEN _ ".read", .tTool, 1)
    Do $$$AssertTrue($IsObject(tTool), "the read tool resolves")
    If $IsObject(tTool) {
        Set tViewSC = $ClassMethod(tTool.class, "View", tTool.descriptor, {}, 1000, .tView, .tHttp, .tFault)
        Do $$$AssertStatusOK(tViewSC, "the read tool answers")
        Do $$$AssertEquals($Select($IsObject($Get(tView)): tView.rows.%Size(), 1: -1), tBuilt, "the same screens")
    }
}

/// <p><b>Not an adjuster (AC2)</b> -- Op, who lacks <code>%Development:USE</code>, is refused the read and each
/// of the three actions naming it, nothing is stored, and the map lists the screen unavailable naming the
/// same pair. The stock <code>%Developer</code>, <code>%Manager</code> and <code>%All</code> roles hold it.</p>
/// <p>Mutation (Rule 19): set the descriptor's <code>privileges</code> to <code>[]</code> -- every leg goes
/// red.</p>
Method TestAnAccountWithoutDevelopmentUseIsRefusedNamingIt()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tOp = $ClassMethod(..#FIXTURE, "Op")
    Set tSC = ..As(tOp, "GET", "/screens/" _ ..#SCREEN _ "/read", .tStatus, .tRefused)
    Do $$$AssertEquals(tStatus _ "|" _ ..Refusal(tRefused), "403|AUTH.NOPRIVILEGE|%Development:USE", "the read is refused naming the pair")
    For tCase = $ListBuild("add-pair", ..#RAISED), $ListBuild("remove-pair", "%Admin_Operate:USE"), $ListBuild("reset", "") {
        Set tSC = ..Act(tOp, $List(tCase, 1), ..#LOCKS, $List(tCase, 2), .tStatus, .tRefused)
        Do $$$AssertEquals(tStatus _ "|" _ ..Refusal(tRefused), "403|AUTH.NOPRIVILEGE|%Development:USE", $List(tCase, 1) _ ": refused naming the pair")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Access).GuardedAll(.tStored), "the store reads")
    Do $$$AssertEquals($Data(tStored), 0, "and nothing was stored")
    Do $$$AssertStatusOK(..Verdict(tOp, ..#SCREEN, .tAllowed, .tFailed), "the map reads")
    Do $$$AssertEquals(tAllowed _ "|" _ tFailed, "0|%Development:USE", "the side bar lists the screen unavailable, naming it")
}

/// <p><b>Raise and Reset (AC3)</b> -- after Dev adds <code>%Admin_Secure:USE</code> to Locks, Op's map, the
/// screen's read route and its Remove locks action each refuse naming it, and the read tool requires it; a
/// reset restores every one, and a second reset is 409 <code>ACCESS.NOTADJUSTED</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Gate.RequiredPairs</method> ignore the store -- every
/// Raise leg goes red.</p>
Method TestARaiseIsFollowedByEveryGateAndAResetUndoesIt()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tDev = $ClassMethod(..#FIXTURE, "Dev")
    Set tOp = $ClassMethod(..#FIXTURE, "Op")
    Do $$$AssertStatusOK(..Verdict(tOp, ..#LOCKS, .tAllowed, .tFailed), "the map reads")
    Do $$$AssertEquals(tAllowed, 1, "Op opens Locks before the change")
    Set tSC = ..Act(tDev, "add-pair", ..#LOCKS, ..#RAISED, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "Dev raises Locks")
    Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id, "updated|screen-permission|" _ ..#LOCKS, "as an update of that screen-permission")
    Do $$$AssertStatusOK(..Verdict(tOp, ..#LOCKS, .tAllowed, .tFailed), "the map reads again")
    Do $$$AssertEquals(tAllowed _ "|" _ tFailed, "0|" _ ..#RAISED, "the map lists Locks unavailable naming the raised pair")
    Set tSC = ..As(tOp, "GET", "/screens/" _ ..#LOCKS _ "/read", .tStatus, .tRead)
    Do $$$AssertEquals(tStatus _ "|" _ ..Refusal(tRead), "403|AUTH.NOPRIVILEGE|" _ ..#RAISED, "Locks' read route refuses naming it")
    Set tRemoveBody = {"action": "remove", "id": "OcuPilotProbeNoSuchLock", "values": {"RemoveInTransaction": "false"}}
    Set tSC = ..As(tOp, "POST", "/screens/" _ ..#LOCKS _ "/action", .tStatus, .tRemove, tRemoveBody.%ToJSON())
    Do $$$AssertEquals(tStatus _ "|" _ ..Refusal(tRemove), "403|AUTH.NOPRIVILEGE|" _ ..#RAISED, "and so does Remove locks")
    Kill tReadTool
    Do ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#LOCKS _ ".read", .tReadTool, 1)
    If $IsObject($Get(tReadTool)) {
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tReadTool, .tResolved)
        Do $$$AssertTrue(tResolved && $ListFind(tPairs, $ListBuild("%Admin_Secure", "USE")), "osmgmt.locks.read requires the raised pair")
    }
    Set tSC = ..Act(tDev, "reset", ..#LOCKS, "", .tStatus, .tReset)
    Do $$$AssertEquals(tStatus _ "|" _ tReset.action, "200|deleted", "Dev resets Locks")
    Do $$$AssertStatusOK(..Verdict(tOp, ..#LOCKS, .tAllowed, .tFailed), "the map reads once more")
    Do $$$AssertEquals(tAllowed, 1, "Op opens Locks again")
    Set tSC = ..Act(tDev, "reset", ..#LOCKS, "", .tStatus, .tAgain)
    Do $$$AssertEquals(tStatus _ "|" _ ..Refusal(tAgain), "409|ACCESS.NOTADJUSTED|", "a second reset is refused as nothing to reset")
}

/// <p><b>Lower and Lower past the vendor (AC4)</b> -- Dev removes <code>%Admin_Manage:USE</code> from
/// Processes, and Op's map opens it while the admin port's own gate still refuses its read naming that pair
/// (<code>PORT.ACCESSDENIED</code>, measured at Task 0). Dev gives Web applications
/// <code>%Admin_Operate:USE</code> and takes away <code>%Admin_Secure:USE</code> and
/// <code>%DB_IRISSYS:READ</code>: Op's map opens it, and its read is refused by the vendor's own check
/// (<code>PORT.ACCESSDENIED</code>, measured), not by the screen gate (<code>AUTH.NOPRIVILEGE</code>).</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.ScreenAccessPort.Apply</method> refuse the removal of a
/// declared pair -- the first leg goes red.</p>
Method TestLoweringOpensTheScreenAndThePortsOwnCheckStillRefuses()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tDev = $ClassMethod(..#FIXTURE, "Dev")
    Set tOp = $ClassMethod(..#FIXTURE, "Op")
    Do $$$AssertStatusOK(..Verdict(tOp, ..#PROCESSES, .tAllowed, .tFailed), "the map reads")
    Do $$$AssertEquals(tAllowed _ "|" _ tFailed, "0|%Admin_Manage:USE", "Op cannot open Processes before the change")
    Set tSC = ..Act(tDev, "remove-pair", ..#PROCESSES, "%Admin_Manage:USE", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "Dev lowers Processes")
    Do $$$AssertStatusOK(..Verdict(tOp, ..#PROCESSES, .tAllowed, .tFailed), "the map reads again")
    Do $$$AssertEquals(tAllowed, 1, "Op's side bar opens Processes")
    Set tSC = ..As(tOp, "GET", "/screens/" _ ..#PROCESSES _ "/read", .tStatus, .tRead)
    Do $$$AssertEquals(tStatus _ "|" _ ..Refusal(tRead), "403|PORT.ACCESSDENIED|%Admin_Manage:USE", "the read is refused by the admin port's own gate, naming the pair the screen no longer requires")

    Set tSC = ..Act(tDev, "add-pair", ..#WEBAPPS, "%Admin_Operate:USE", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "Dev adds the pair Op holds to Web applications")
    Set tSC = ..Act(tDev, "remove-pair", ..#WEBAPPS, "%Admin_Secure:USE", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "and removes %Admin_Secure:USE")
    Set tSC = ..Act(tDev, "remove-pair", ..#WEBAPPS, "%DB_IRISSYS:READ", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "and %DB_IRISSYS:READ")
    Do $$$AssertStatusOK(..Verdict(tOp, ..#WEBAPPS, .tAllowed, .tFailed), "the map reads")
    Do $$$AssertEquals(tAllowed, 1, "Op's side bar opens Web applications")
    Set tSC = ..As(tOp, "GET", "/screens/" _ ..#WEBAPPS _ "/read", .tStatus, .tRead)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tRead): tRead.%Get("code"), 1: ""), "403|PORT.ACCESSDENIED", "the vendor's own check refuses the read, not the screen gate")
}

/// <p><b>Audit (AC5)</b> -- each accepted write is one <code>SecurityChange</code> row naming the screen and
/// the pairs before and after: an add and a remove are <code>updated</code>, a reset is <code>reset</code>.</p>
/// <p>Mutation (Rule 19): remove the <code>Event.Record</code> call from
/// <method>OcuPilot.Port.ScreenAccessPort.Audit</method> -- every leg goes red.</p>
Method TestEachAcceptedWriteIsOneSecurityChangeRow()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tDev = $ClassMethod(..#FIXTURE, "Dev")
    Set tDescriptor = ##class(OcuPilot.Screen.Registry).DescriptorForTool(..#LOCKS)
    Set tDeclared = $Replace(..Spelled($ClassMethod(tDescriptor, "PrivilegePairs")), ", ", ",")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Act(tDev, "add-pair", ..#LOCKS, ..#RAISED, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "an add is accepted")
    Set tData = ##class(OcuPilot.Test.AuditRecord).RowFor(tSince, 1, ..#LOCKS, "updated", .tRows)
    Do $$$AssertEquals(tRows, 1, "exactly one security-change row records it: " _ tRows)
    If tRows = 1 {
        Set tRow = ##class(%DynamicAbstractObject).%FromJSON(tData)
        Do $$$AssertEquals(tRow.actor _ "|" _ tRow.target.type _ "|" _ tRow.target.scope _ "|" _ tRow.target.id, tDev _ "|screen-permission|instance|" _ ..#LOCKS, "naming the actor and the screen-permission")
        Do $$$AssertEquals(tRow.changes.pairs.old _ "|" _ tRow.changes.pairs.new, tDeclared _ "|" _ tDeclared _ "," _ ..#RAISED, "and the pairs before and after")
    }
    Set tSC = ..Act(tDev, "remove-pair", ..#LOCKS, ..#RAISED, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "a remove is accepted")
    Set tSC = ..Act(tDev, "reset", ..#LOCKS, "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "and a reset")
    Set tReset = ##class(OcuPilot.Test.AuditRecord).RowFor(tSince, 1, ..#LOCKS, "reset", .tResetRows)
    Do $$$AssertEquals(tResetRows, 1, "the reset is one row of its own: " _ tResetRows)
}

/// <p><b>Classic union (AD-44)</b> -- a custom resource assigned to Locks' classic page stays in force on an
/// adjusted screen: its <code>Effective</code> is the adjusted set and that resource at <code>USE</code>, and
/// the declared <code>Adjustment</code> does not carry it.</p>
/// <p>Mutation (Rule 19): drop the classic union from <method>OcuPilot.Screen.Gate.RequiredPairs</method>
/// -- this goes red.</p>
Method TestTheClassicResourceStaysInForceOnAnAdjustedScreen()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principals' grants")
    Set tDev = $ClassMethod(..#FIXTURE, "Dev")
    Set tDescriptor = ##class(OcuPilot.Screen.Registry).DescriptorForTool(..#LOCKS)
    Set tPage = $ZConvert($ClassMethod(tDescriptor, "ClassicPage"), "O", "URL")
    Do $$$AssertNotEquals(tPage, "", "Locks replaces a classic page")
    If tPage = "" Quit
    Set ..PreparedClassic = ##class(%CSP.Portal.Utils).%GetCustomResource(tPage)
    Do $$$AssertStatusOK(##class(%CSP.Portal.Utils).%SetCustomResource(tPage, ..#CLASSICRESOURCE), "the probe resource is assigned to Locks' classic page")
    Set tSC = ..Act(tDev, "add-pair", ..#LOCKS, ..#RAISED, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "Dev adjusts Locks")
    Set tRow = ..Row(tDev, ..#LOCKS, .tCount)
    Do $$$AssertTrue($IsObject(tRow), "Locks has a row")
    If '$IsObject(tRow) Quit
    Do $$$AssertEquals(tRow.ClassicResource, ..#CLASSICRESOURCE, "the row names the classic resource")
    Do $$$AssertEquals(tRow.Effective, tRow.Adjustment _ ", " _ ..#CLASSICRESOURCE _ ":USE", "Effective is the adjusted set and the custom resource")
}

}
