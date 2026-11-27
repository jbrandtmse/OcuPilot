/// <p>Pins Story 24.17 Batch 5's reads (AD-5, AD-29, AD-36, AD-62): System monitor's one row of the vendor's scalar meters and the three drill-downs' tables, through the port, the screen's read route
/// and the agent's read tool; the stable meters equal to the vendor's own call made beside the port's, with the probe production running in <code>USER</code> and then stopped; the tables' rows in the
/// vendor's order with the padding dropped; the named limit and one over it; the same answer whichever namespace the call names; no script form; and how the four screens are declared.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropSystemMonitorCase</class> needs.</p>
Class OcuPilot.Test.InteropSystemMonitorRead Extends OcuPilot.Test.InteropSystemMonitorCase
{

/// <p>The four screens as the plan declares them: route, side bar position, archetype, tool, refresh rates and whether the screen refreshes.</p>
Parameter DECLARED = "OcuPilot.Screen.Descriptor.InteropSystemMonitor=interoperability/system-monitor|29|meters|interop.systemmonitor|[60]|1,OcuPilot.Screen.Descriptor.InteropSystemMonitorProcesses=interoperability/system-monitor/processes|0|list|interop.systemmonitorprocesses|[]|0,OcuPilot.Screen.Descriptor.InteropSystemMonitorQueues=interoperability/system-monitor/queues|0|list|interop.systemmonitorqueues|[]|0,OcuPilot.Screen.Descriptor.InteropSystemMonitorTasks=interoperability/system-monitor/tasks|0|list|interop.systemmonitortasks|[]|0";

/// <p>The screens are declared as the plan places them: in the Interoperability area, instance-wide with no entity type and no action, over the three pairs, with the classic page's own refresh rate
/// as the one rate System monitor offers (60 seconds, <code>EnsembleMonitor.cls</code> <code>RefreshRate = 60000</code>) and none for the drill-downs.</p>
Method TestTheFourScreensAreDeclaredAsThePlanPlacesThem()
{
    For tI = 1:1:$Length(..#DECLARED, ",") {
        Set tEntry = $Piece(..#DECLARED, ",", tI)
        Set tClass = $Piece(tEntry, "=", 1)
        Set tExpected = $Piece(tEntry, "=", 2)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tD)
        Do $$$AssertStatusOK(tSC, tClass _ " declares JSON")
        If '$IsObject($Get(tD)) Continue
        Do $$$AssertEquals(tD.route _ "|" _ tD.sideBarPosition _ "|" _ tD.archetype _ "|" _ tD.toolIdentifier _ "|" _ tD.refreshRates.%ToJSON() _ "|" _ ''tD.refreshes, tExpected, tClass _ ": its route, position, archetype, tool and refresh rates")
        Do $$$AssertEquals(tD.area _ "|" _ tD.scope _ "|" _ tD.entityType _ "|" _ tD.id.kind _ "|" _ tD.rowActions.%Size() _ "|" _ tD.primaryAction.id _ "|" _ tD.classicPage, "interoperability|instance||none|0||%CSP.UI.Portal.EnsembleMonitor", tClass _ ": an instance-wide screen with no entity type, id or action over the classic monitor page")
        Do $$$AssertEquals(tD.privileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_Dashboard"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", tClass _ ": its three pairs")
    }
}

/// <p>AC1: the System monitor row is one object of the twenty-five meters, each the vendor's value as text, and its stable meters equal the vendor's own call made beside it: with the probe production
/// running in <code>USER</code> it counts one production, and once it is stopped it counts none. The screen's read route and the agent's read tool answer the same row as the port.</p>
/// <p>Mutation (Rule 19): read the row's <code>EnsProductionsRunning</code> from <code>EnsJobs</code> in <method>OcuPilot.Port.InteropPort.SystemMonitorRow</method> -- the running leg goes red.</p>
Method TestTheRowEqualsTheVendorBesideItWithTheProbeProductionRunningAndStopped()
{
    Do ..AgeSnapshot()
    Kill tQuery
    Set tVerdict = ..Verdict("SystemMonitor", .tRows, .tFault, .tQuery)
    Do $$$AssertEquals(tVerdict, "200 ", "idle: the port answers 200")
    Do $$$AssertEquals(..Size(tRows), 1, "idle: one row")
    Do $$$AssertStatusOK(..VendorBeside(.tVendor), "idle: the vendor's own call answers")
    Do $$$AssertEquals(..StableText(tRows.%Get(0)), ..StableText(, .tVendor), "idle: the stable meters equal the vendor's call made beside the port's")
    Do $$$AssertEquals(tRows.%Get(0).EnsProductionsRunning, "0", "idle: no production runs")
    Do $$$AssertTrue($Match(tRows.%Get(0).UpTime, "^[0-9]+d +[0-9]+h +[0-9]+m$"), "idle: the up time reads as the classic page writes it: " _ tRows.%Get(0).UpTime)
    Set tNames = $Parameter(..#PORT, "SYSTEMMONITORMETERS")
    Do $$$AssertEquals($Length(tNames, ","), 25, "the row names twenty-five meters")
    Set tPresent = 0
    For tI = 1:1:25 {
        If tRows.%Get(0).%GetTypeOf($Piece(tNames, ",", tI)) = "string" Set tPresent = tPresent + 1
    }
    Do $$$AssertEquals(tPresent, 25, "idle: each meter is present as text")
    Set tUnknown = ""
    For tI = 1:1:25 {
        If '$Data(tVendor($Piece(tNames, ",", tI))) Set tUnknown = tUnknown _ $Piece(tNames, ",", tI) _ ","
    }
    Do $$$AssertEquals(tUnknown, "", "idle: every meter the row names is one the vendor answers: " _ tUnknown)
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs in USER")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("SystemMonitor", .tRunning, .tFault, .tQuery), "200 ", "running: the port answers 200")
    Do $$$AssertStatusOK(..VendorBeside(.tVendor2), "running: the vendor's own call answers")
    Do $$$AssertEquals(..StableText(tRunning.%Get(0)), ..StableText(, .tVendor2), "running: the stable meters equal the vendor's call made beside the port's")
    Do $$$AssertEquals(tRunning.%Get(0).EnsProductionsRunning, "1", "running: USER's production is counted")
    ; Both readers: the route and the tool, over the real port, with the production running.
    Do $$$AssertStatusOK(..Route("interop.systemmonitor", .tStatus, .tAnswer), "the route answers")
    Do $$$AssertEquals(tStatus, 200, "the screen's read route answers 200")
    Do $$$AssertEquals(..StableText(tAnswer.rows.%Get(0)), ..StableText(, .tVendor2), "the route's row has the same stable meters")
    Do $$$AssertStatusOK(..ReadTool("interop.systemmonitor", .tToolResult, .tToolHttp), "the tool answers")
    Do $$$AssertEquals(tToolHttp, 200, "the agent's read tool answers 200")
    Do $$$AssertEquals(..StableText(tToolResult.rows.%Get(0)), ..StableText(, .tVendor2), "the tool's row has the same stable meters")
    Do $ClassMethod(..#PROBE, "Remove")
    Do ..AgeSnapshot()
    Kill tQuery
    Do ..Verdict("SystemMonitor", .tStopped, .tFault, .tQuery)
    Do ..VendorBeside(.tVendor3)
    Do $$$AssertEquals(tStopped.%Get(0).EnsProductionsRunning, "0", "stopped: the production is no longer counted")
    Do $$$AssertEquals(..StableText(tStopped.%Get(0)), ..StableText(, .tVendor3), "stopped: the stable meters equal the vendor's call made beside the port's")
}

/// <p>AC2: each drill-down lists the vendor's rows in the order the vendor gives them, a row whose columns are all empty dropped, a whole number written with thousands separators as a number, and the
/// vendor's own text left as it is. The seam's tables hold padding between and after the rows.</p>
/// <p>Mutation (Rule 19): keep the padding rows in <method>OcuPilot.Port.InteropPort.MonitorTableRows</method> -- this goes red.</p>
Method TestTheDrillDownsListTheVendorsRowsInOrderWithoutPadding()
{
    Set ^IRIS.Temp.OcuProbe2417SmMode = "values"
    Kill tQuery
    Do $$$AssertEquals(..Verdict("SystemMonitorProcesses", .tProcesses, .tFault, .tQuery, "USER", ..#SEAM), "200 ", "the processes answer 200")
    Do $$$AssertEquals(..Canon(tProcesses, "Namespace,Item,Pid,Commands"), "|[System]|1879|1200;USER|OcuItem|42|9;USER|OcuItemTwo|43|8;USER|OcuItemThree|44|7", "four processes in the vendor's order, the padding dropped, the commands read as numbers")
    Do $$$AssertEquals(tProcesses.%GetTypeOf(0) _ "|" _ tProcesses.%Get(0).%GetTypeOf("Commands") _ "|" _ tProcesses.%Get(0).%GetTypeOf("Item"), "object|number|string", "a count is a number and a name is text")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("SystemMonitorQueues", .tQueues, .tFault, .tQuery, "USER", ..#SEAM), "200 ", "the queues answer 200")
    Do $$$AssertEquals(..Canon(tQueues, "Namespace,Queue,Messages"), "USER|Queue.A|5;HSCUSTOM|Queue.B|4;USER|Queue.C|3;USER|Queue.D|2", "four queues in the vendor's order, the padding dropped")
    Do $$$AssertEquals(tQueues.%Get(0).%GetTypeOf("Messages") _ "|" _ tProcesses.%Get(1).%GetTypeOf("Pid"), "number|number", "a queue's messages and a process ID are numbers")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("SystemMonitorTasks", .tTasks, .tFault, .tQuery, "USER", ..#SEAM), "200 ", "the tasks answer 200")
    Do $$$AssertEquals(..Canon(tTasks, "Task,ScheduledFor,Status"), "Task one|13:01|Scheduled;Task two|13:05|Suspended;Task three|13:10|Scheduled;Task four|13:15|Scheduled", "four tasks in the vendor's order, the blank row dropped")
    Kill tQuery
    Do ..Verdict("SystemMonitor", .tRow, .tFault, .tQuery, "USER", ..#SEAM)
    Do $$$AssertEquals(tRow.%Get(0).EnsNamespace _ "|" _ tRow.%Get(0).EnsProductionsRunning _ "|" _ tRow.%Get(0).UpTime _ "|" _ tRow.%Get(0).LicenseLimit, "Seam Namespaces|7|1d  2h 03m|", "the row carries the vendor's value as text, and an absent meter is empty")
    Do $$$AssertEquals(+$Get(^IRIS.Temp.OcuProbe2417SmMode("calls")), 4, "each read made one vendor call")
}

/// <p>AC2: each drill-down stops at its named limit when the caller names no cap: the shipped limit is 100; at three, three come whole, four are cut at three, a caller that asks for one row beyond a cap
/// at the limit is answered it and so reads the truncation, and one that asks for fewer gets fewer.</p>
Method TestEachDrillDownStopsAtItsNamedLimit()
{
    Do $$$AssertEquals($Parameter(..#PORT, "SYSTEMMONITORROWSMAX") _ "|" _ $Parameter(..#CAPSEAM, "SYSTEMMONITORROWSMAX"), "100|3", "the shipped limit is 100 and the seam lowers it to three")
    Set ^IRIS.Temp.OcuProbe2417SmMode = "values"
    For tEndpoint = "SystemMonitorProcesses", "SystemMonitorQueues", "SystemMonitorTasks" {
        Kill tQuery
        Do $$$AssertEquals(..Verdict(tEndpoint, .tAt, .tFault, .tQuery, "USER", ..#CAPSEAM), "200 ", tEndpoint _ ": answers 200")
        Do $$$AssertEquals(..Size(tAt), 3, tEndpoint _ ": four rows are cut at the limit, three")
        Kill tQuery
        Set tQuery("maxRows") = 4
        Do ..Verdict(tEndpoint, .tAsked, .tFault, .tQuery, "USER", ..#CAPSEAM)
        Do $$$AssertEquals(..Size(tAsked), 4, tEndpoint _ ": a caller whose cap is the limit asks for one row more and is answered it, so it reads the truncation")
        Kill tQuery
        Set tQuery("maxRows") = 2
        Do ..Verdict(tEndpoint, .tFewer, .tFault, .tQuery, "USER", ..#CAPSEAM)
        Do $$$AssertEquals(..Size(tFewer), 2, tEndpoint _ ": and one that asks for fewer gets fewer")
    }
    Set ^IRIS.Temp.OcuProbe2417SmMode = "three"
    Kill tQuery
    Do ..Verdict("SystemMonitorQueues", .tThree, .tFault, .tQuery, "USER", ..#CAPSEAM)
    Do $$$AssertEquals(..Canon(tThree, "Queue"), "Queue.A;Queue.B;Queue.C", "three rows at the limit of three come whole")
    Kill tQuery
    Set tQuery("maxRows") = "x"
    Do $$$AssertEquals(..Verdict("SystemMonitorQueues", .tBad, .tFault, .tQuery), "400 PORT.VALIDATION", "a cap that is not a whole number is refused by name")
}

/// <p>AC1: the read is instance-wide: asked in <code>USER</code>, in <code>HSCUSTOM</code> and in a namespace without interoperability, the four endpoints answer the same, so the read never takes the
/// request's namespace.</p>
Method TestEveryNamespaceAnswersTheSame()
{
    Set tFirst = ""
    For tNamespace = "USER", "HSCUSTOM", "%SYS" {
        Kill tQuery
        Set tVerdict = ..Verdict("SystemMonitor", .tRows, .tFault, .tQuery, tNamespace)
        Do $$$AssertEquals(tVerdict, "200 ", tNamespace _ ": the System monitor answers 200")
        Set tText = ..StableText(tRows.%Get(0))
        If tFirst = "" Set tFirst = tText
        Do $$$AssertEquals(tText, tFirst, tNamespace _ ": the same stable meters")
        Kill tQuery
        Do $$$AssertEquals(..Verdict("SystemMonitorQueues", .tQueues, .tFault, .tQuery, tNamespace), "200 ", tNamespace _ ": so does Most active queues")
    }
}

/// <p>AC6: the four endpoints serve <code>LIST</code> alone, take no criterion, and have no script form, so no draft is rendered for them.</p>
Method TestTheFourEndpointsAreReadsWithNoScriptForm()
{
    For tI = 1:1:4 {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", tEndpoint, "LIST"), "", tEndpoint _ ": no script form")
        Do $$$AssertTrue($ClassMethod(..#PORT, "Serves", tEndpoint, "LIST"), tEndpoint _ ": serves LIST")
        Do $$$AssertTrue('$ClassMethod(..#PORT, "Serves", tEndpoint, "UPDATE") && '$ClassMethod(..#PORT, "Serves", tEndpoint, "PURGE"), tEndpoint _ ": serves no write")
        Do $$$AssertTrue('$ListFind($ListFromString($Parameter(..#PORT, "SEARCHENDPOINTS")), tEndpoint), tEndpoint _ ": takes no search criterion")
        Kill tQuery
        Do $$$AssertEquals(..Verdict(tEndpoint, .tRows, .tFault, .tQuery, "USER", ..#PORT), "200 ", tEndpoint _ ": answers 200")
    }
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", "SystemMonitor", "UPDATEALERT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 501, "a write type is not implemented on an endpoint of this family")
}

/// <p>AC1: the screen's read route and the agent's read tool answer for each drill-down over the real vendor with the probe production running: the processes with their columns, and Most active queues
/// listing the probe operation's queue, whichever reader asks.</p>
Method TestTheRouteAndTheToolListTheRunningProductionsQueue()
{
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs in USER")
    Set tQueue = $Parameter(..#PROBE, "OPNAME")
    Set tRoutes = $ListBuild("interop.systemmonitorprocesses", "interop.systemmonitorqueues", "interop.systemmonitortasks")
    For tI = 1:1:3 {
        Set tRoute = $List(tRoutes, tI)
        Do $$$AssertStatusOK(..Route(tRoute, .tStatus, .tAnswer), tRoute _ ": the route answers")
        Do $$$AssertEquals(tStatus, 200, tRoute _ ": the route answers 200")
        Do $$$AssertStatusOK(..ReadTool(tRoute, .tResult, .tToolHttp), tRoute _ ": the tool answers")
        Do $$$AssertEquals(tToolHttp, 200, tRoute _ ": the tool answers 200")
        If tRoute = "interop.systemmonitorqueues" {
            Do $$$AssertTrue(("," _ ..Canon(tAnswer.rows, "Queue") _ ",") [ tQueue, "the route lists the probe operation's queue: " _ ..Canon(tAnswer.rows, "Queue"))
            Do $$$AssertTrue(("," _ ..Canon(tResult.rows, "Queue") _ ",") [ tQueue, "the tool lists it too")
        }
    }
}

/// <p>The number of rows <var>pRows</var> holds, or -1 when it is not an array.</p>
ClassMethod Size(pRows) As %Integer
{
    Quit $Select($IsObject($Get(pRows)): pRows.%Size(), 1: -1)
}

}
