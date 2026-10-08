/// <p>Pins what dispatch's privilege refusal names (Story 20.18, AD-8, AD-31, AD-39, AD-64), in process through
/// <class>OcuPilot.Test.ToolDispatchProbe</class> over the shipped tool registry, with one pair denied at the
/// probe's pair seam because the suite's account holds <code>%All</code>: a tool whose screen's pairs the caller
/// lacks is refused naming the failed pair and the screen, a screen's adjustment included; a tool whose screen
/// the caller can open is refused naming the pair alone; and every registered write tool resolves a screen and
/// requires all of that screen's pairs.</p>
/// <p>It creates no principal. It snapshots the stored governance policy and puts it back, and removes every
/// screen adjustment before and after each test.</p>
Class OcuPilot.Test.ScreenRefusal Extends %UnitTest.TestCase
{

Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

Parameter PROBE = "OcuPilot.Test.ToolDispatchProbe";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Kernel.State.Access).DeleteAllGuarded()
    Do $ClassMethod(..#PROBE, "Reset")
    Do $ClassMethod(..#PROBE, "SetRegistryClass", ..#REGISTRY)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Access).DeleteAllGuarded(), "every screen adjustment is removed")
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Quit $$$OK
}

/// <p>One call of the tool <var>pWire</var> through the probe with <var>pDenied</var> (a
/// <code>resource:permission</code> pair) denied: the content, the step's <code>failedPair</code> and
/// <code>failedScreen</code>, joined by bars.</p>
Method Refused(pWire As %String, pDenied As %String) As %String
{
    Do $ClassMethod(..#PROBE, "DenyPair", $Piece(pDenied, ":", 1), $Piece(pDenied, ":", 2))
    Set tUse = {"type": "tool_use", "id": "toolu_refusal", "input": {}}
    Do tUse.%Set("name", pWire, "string")
    Set tSC = $ClassMethod(..#PROBE, "Answer", "refusal", $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    If $$$ISERR(tSC) Quit "dispatchfailed"
    Set tDetail = tDetails.%Get(0)
    Quit tResults.%Get(0).%Get("content") _ "|" _ tDetail.failedPair _ "|" _ tDetail.failedScreen
}

/// <p><b>Screen open</b> -- Locks' own pairs are held and only the removal's write pair is not: the refusal
/// names the pair and no screen.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.Registry.ScreenRequirement</method> answer the
/// tool's whole pair set -- this goes red.</p>
Method TestAToolWhoseScreenIsOpenIsRefusedNamingThePairAlone()
{
    Set tResult = ..Refused("osmgmt_locks_remove", "%DB_IRISSYS:WRITE")
    Do $$$AssertEquals(tResult, "{""code"":""AUTH.NOPRIVILEGE"",""detail"":{""failedPair"":""%DB_IRISSYS:WRITE""}}|%DB_IRISSYS:WRITE|", "the write pair is named and no screen")
}

/// <p><b>Demo operator</b> -- an account lacking <code>%Admin_Secure:USE</code> asking for
/// <code>webapp_list_update</code> is refused naming Web applications and that pair.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.Registry.ScreenRequirement</method> answer
/// <code>""</code> -- this goes red.</p>
Method TestAToolWhoseScreenIsClosedIsRefusedNamingTheScreen()
{
    Set tResult = ..Refused("webapp_list_update", "%Admin_Secure:USE")
    Do $$$AssertEquals(tResult, "{""code"":""AUTH.NOPRIVILEGE"",""detail"":{""failedPair"":""%Admin_Secure:USE"",""screen"":""webapp.list""}}|%Admin_Secure:USE|webapp.list", "the pair and the screen are named")
}

/// <p><b>Adjusted</b> -- a pair an adjustment added to Locks is the failed pair, and Locks is the screen named.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Gate.RequiredPairs</method> ignore the store -- this goes
/// red.</p>
Method TestAnAdjustmentIsFollowedByTheRefusal()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Access).GuardedPut("osmgmt.locks", "%Admin_Operate:USE,%DB_IRISSYS:READ,%Admin_Secure:USE", 0, $Username), "Locks is raised")
    Set tResult = ..Refused("osmgmt_locks_remove", "%Admin_Secure:USE")
    Do $$$AssertEquals(tResult, "{""code"":""AUTH.NOPRIVILEGE"",""detail"":{""failedPair"":""%Admin_Secure:USE"",""screen"":""osmgmt.locks""}}|%Admin_Secure:USE|osmgmt.locks", "the added pair and Locks are named")
}

/// <p><b>Roster</b> -- every registered write tool resolves a screen through <method>ScreenRequirement</method>,
/// and its <method>OcuPilot.Screen.Tool.Registry.RequiredPairs</method> holds each of that screen's pairs.</p>
/// <p>Mutation (Rule 19): empty one write tool's <code>DESCRIPTORCLASS</code> -- this goes red.</p>
Method TestEveryWriteToolResolvesItsScreenAndRequiresAllItsPairs()
{
    Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ListTools", .tTools), "the registry lists")
    Set tWrites = 0
    Set tUnresolved = ""
    Set tMissing = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.%Get("kind") '= "write" Continue
        Set tWrites = tWrites + 1
        Set tScreenPairs = $ClassMethod(..#REGISTRY, "ScreenRequirement", tEntry, .tScreen, .tResolved)
        If 'tResolved || (tScreen = "") {
            Set tUnresolved = tUnresolved _ " " _ tEntry.%Get("name")
            Continue
        }
        Set tToolPairs = $ClassMethod(..#REGISTRY, "RequiredPairs", tEntry, .tToolResolved)
        If 'tToolResolved {
            Set tUnresolved = tUnresolved _ " " _ tEntry.%Get("name") _ "(pairs)"
            Continue
        }
        Set tHeld = ""
        For tI = 1:1:$ListLength(tToolPairs) {
            Set tPair = $List(tToolPairs, tI)
            Set tHeld = tHeld _ $ListBuild($ZConvert($List(tPair, 1) _ ":" _ $List(tPair, 2), "U"))
        }
        For tI = 1:1:$ListLength(tScreenPairs) {
            Set tPair = $List(tScreenPairs, tI)
            If '$ListFind(tHeld, $ZConvert($List(tPair, 1) _ ":" _ $List(tPair, 2), "U")) Set tMissing = tMissing _ " " _ tEntry.%Get("name") _ ":" _ $List(tPair, 1) _ ":" _ $List(tPair, 2)
        }
    }
    Do $$$AssertTrue(tWrites > 0, "the registry lists write tools: " _ tWrites)
    Do $$$AssertEquals(tUnresolved, "", "every write tool resolves a screen")
    Do $$$AssertEquals(tMissing, "", "and requires every pair of it")
}

}
