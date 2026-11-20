/// <p>Pins Story 21.20's System alerts screen (AC4, Integration; AD-5, AD-23, AD-29): its declaration; its read, which answers
/// one row <code>{State, StateText, AlertCount, LastAlert}</code> equal to the instance's own <code>%SYSTEM.Monitor</code>
/// answers at that read and carries no alert list; a caller missing a pair refused naming it; and the reset, which runs only
/// through the port's <code>HarvestCall</code> seam here, so it never reaches <code>Clear()</code>, and is refused for a caller
/// without <code>%Admin_Manage:USE</code> before any harvested body runs.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries. Live-safe: it reads the alert state and changes
/// nothing; the reset legs run against the fixture's canned answers (<class>OcuPilot.Test.MonitorPortFixture</class>). The
/// reset itself is <class>OcuPilot.Test.SystemAlertsWrite</class>.</p>
Class OcuPilot.Test.SystemAlertsRead Extends %UnitTest.TestCase
{

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.SystemAlertsList";

Parameter PORT = "OcuPilot.Port.MonitorPort";

Parameter PORTFIXTURE = "OcuPilot.Test.MonitorPortFixture";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORTFIXTURE, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORTFIXTURE, "Clear")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $$$OK
}

/// <p>The instance's own alert state, read in <code>%SYS</code>: <code>State|StateText|AlertCount|LastAlert</code>.</p>
ClassMethod Instance() As %String
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tState = $SYSTEM.Monitor.State()
    Set tCount = $SYSTEM.Monitor.Alerts()
    Set tLast = ""
    Do $SYSTEM.Monitor.GetAlerts(.tAlerts, .tMessages, .tLast)
    Set $NAMESPACE = tOrigNS
    Quit tState _ "|" _ $Case(tState, -1: "Hung", 0: "OK", 1: "Warning", 2: "Alert", : "Unknown") _ "|" _ tCount _ "|" _ tLast
}

/// <p>A row of <var>pRows</var> as <code>State|StateText|AlertCount|LastAlert</code>.</p>
ClassMethod RowText(pRow As %DynamicObject) As %String
{
    Quit pRow.%Get("State") _ "|" _ pRow.%Get("StateText") _ "|" _ pRow.%Get("AlertCount") _ "|" _ pRow.%Get("LastAlert")
}

/// <p>The screen's declaration: OS management's System alerts list, an instance-scoped list over the singleton
/// <code>system-alerts</code> with no id, read through the monitor port's own pairs, with one row action, Reset alerts, and
/// no classic page.</p>
/// <p>Mutation (Rule 19): drop the <code>reset</code> row action from the descriptor -- the action leg goes red.</p>
Method TestTheDescriptorShape()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration reads")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.toolIdentifier, "os-management/system-alerts|os-management|list|instance|system-alerts|osmgmt.systemalerts", "an instance-scoped list of the system-alerts entity")
    Do $$$AssertEquals(tDeclaration.id.%ToJSON(), "{""kind"":""none"",""parts"":[]}", "its id is none")
    Do $$$AssertEquals(##class(OcuPilot.Test.SqlActivityDescriptor).Spelled($ClassMethod(..#DESCRIPTOR, "PrivilegePairs")), $Parameter(..#PORT, "PAIRS"), "its pairs are the port's, in order")
    Do $$$AssertEquals(tDeclaration.rowActions.%ToJSON(), "[{""id"":""reset"",""selfProtection"":""""}]", "its one row action is Reset alerts")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""monitor"",""endpoint"":""Alerts"",""type"":""LIST""}", "its read names the monitor port's Alerts list")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""State"",""StateText"",""AlertCount"",""LastAlert""]", "and the row's fields")
    Do $$$AssertEquals("[" _ tDeclaration.classicPage _ "]", "[]", "no classic page: the classic portal has no alert reset")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "three suggested prompts")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read passes the registry")
}

/// <p>The live read answers one row equal to the instance's own state at that read, and no alert list.</p>
/// <p>Mutation (Rule 19): read <code>AlertCount</code> from <code>state</code> in <method>OcuPilot.Port.MonitorPort.Alerts</method> -- this
/// goes red.</p>
Method TestTheRowEqualsTheInstancesState()
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, "", .tScreen, .tHttp, .tFault)
    Set tInstance = ..Instance()
    Do $$$AssertEquals($Get(tHttp), 200, "the screen's read answers")
    If '$IsObject($Get(tScreen)) Quit
    Do $$$AssertEquals(tScreen.rows.%Size(), 1, "one row")
    Do $$$AssertEquals(..RowText(tScreen.rows.%Get(0)), tInstance, "equal to the instance's state, count and last alert")
    Do $$$AssertEquals(tScreen.rows.%Get(0).%GetTypeOf("alerts"), "unassigned", "carrying no alert list")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.systemalerts.read", .tTool, 1)
    Do $$$AssertStatusOK(tSC, "the read tool resolves")
    If '$IsObject($Get(tTool)) Quit
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 200, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertEquals($Get(tToolHttp), 200, "the read tool answers")
    If $IsObject($Get(tResult)) Do $$$AssertEquals(..RowText(tResult.rows.%Get(0)), ..Instance(), "the same row")
}

/// <p>A canned harvested answer projects to one row without its alert list, the state text and count as the body gave them.</p>
Method TestTheBodysAnswerProjectsToOneRowWithoutTheAlertList()
{
    Do $ClassMethod(..#PORTFIXTURE, "SetHarvest", "SystemAlerts", "{""state"":2,""stateText"":""Alert"",""alertCount"":3,""alerts"":[{""index"":1,""message"":""one""}],""lastAlert"":""the last line""}")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp), 200, "the read answers")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(tAnswer.rows.%Size() _ "|" _ ..RowText(tAnswer.rows.%Get(0)), "1|2|Alert|3|the last line", "one row of the body's state, count and last alert")
    Do $$$AssertEquals(tAnswer.rows.%Get(0).%GetTypeOf("alerts"), "unassigned", "without the alert list")
    Do $$$AssertEquals($ClassMethod(..#PORTFIXTURE, "HarvestCalls", "SystemAlerts"), 1, "the harvested body ran once")
}

/// <p>A caller missing a pair is refused 403 naming it, before any harvested body runs.</p>
Method TestAMissingPairIsRefusedByName()
{
    Do $ClassMethod(..#PORTFIXTURE, "SetHarvest", "SystemAlerts", "{""state"":0,""stateText"":""OK"",""alertCount"":0,""lastAlert"":""""}")
    Do $ClassMethod(..#PORTFIXTURE, "SetGateClass", "OcuPilot.Test.ScreenGate")
    For tCase = $ListBuild("%DB_IRISSYS", "READ", "%Admin_Operate:USE"), $ListBuild("%Admin_Operate", "USE", "%DB_IRISSYS:READ") {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tCase, 1), $List(tCase, 2))
        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tDenied, .tHttp, .tFault)
        Set tPair = ""
        If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set tPair = tFault.detail.failedPair
        Do $$$AssertEquals(tHttp _ " " _ tPair, "403 " _ $List(tCase, 3), "holding only " _ $List(tCase, 1) _ ": 403 naming the pair that failed")
    }
    Do $$$AssertEquals($ClassMethod(..#PORTFIXTURE, "HarvestCalls", "SystemAlerts"), 0, "and no body ran")
}

/// <p>The reset, driven through the harvest seam: it sends the body's one fixed action, answers <code>{}</code> at 200, and the
/// instance's own alert state is untouched. A caller without <code>%Admin_Manage:USE</code> is refused 403 naming it before any
/// body runs.</p>
/// <p>Mutation (Rule 19): gate the reset on <code>PAIRS</code> instead of <code>WRITEPAIRS</code> in
/// <method>OcuPilot.Port.MonitorPort.Invoke</method> -- the refusal leg goes red.</p>
Method TestTheResetThroughTheSeamNeverReachesClear()
{
    Set tBefore = ..Instance()
    Do $ClassMethod(..#PORTFIXTURE, "SetHarvest", "AlertsManage", "{""action"":""reset""}")
    Kill tQuery
    Set tSC = $ClassMethod(..#PORTFIXTURE, "Invoke", "Alerts", "RESET", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ tHttp _ "|" _ $Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: ""), "1|200|{}", "the reset answers {} at 200")
    Do $$$AssertEquals($ClassMethod(..#PORTFIXTURE, "HarvestCalls", "AlertsManage"), 1, "the harvested body ran once")
    Do $$$AssertEquals(..Instance(), tBefore, "and the instance's alert state is untouched")
    Do $ClassMethod(..#PORTFIXTURE, "SetGateClass", "OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = $ClassMethod(..#PORTFIXTURE, "Invoke", "Alerts", "RESET", .tQuery, "", .tDenied, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: ""), "403|%Admin_Manage:USE", "a caller holding only the read's pairs is refused 403 naming %Admin_Manage:USE")
    Do $$$AssertEquals($ClassMethod(..#PORTFIXTURE, "HarvestCalls", "AlertsManage"), 1, "and no further body ran")
}

/// <p>The reset has a script form, one <code>objectscript</code> step calling <code>Clear()</code>; the reads have none.</p>
Method TestTheScriptForms()
{
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Alerts", "RESET"), "objectscript", "the reset has a script form")
    Kill tQuery
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Alerts", "RESET", .tQuery)
    Do $$$AssertTrue($IsObject(tSteps) && (tSteps.%Size() = 1) && (tSteps.%Get(0).text [ "Do $SYSTEM.Monitor.Clear()"), "one step that clears the monitor")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Alerts", "LIST"), "", "the read has none")
}

}
