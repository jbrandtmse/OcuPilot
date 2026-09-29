/// <p>Dashboard (Story 16.7): the declaration, and the <code>monitor</code> part of its parts read
/// (AD-29, AD-36 as amended) -- the sensors' CPU merged beside <code>DASHBOARDMAIN</code>, a monitor
/// part's refusal or fault failing the whole read with no sensor call on a refusal,
/// <method>OcuPilot.Port.MonitorPort.Invoke</method> refusing any other endpoint or type, and Home's
/// <method>OcuPilot.Port.MonitorPort.Performance</method> still answering its five members.</p>
/// <p>The read runs through <class>OcuPilot.Test.Read.ReadFixture</class>: the admin part over
/// <class>OcuPilot.Test.ReadSource.Endpoint</class>'s canned answer and the monitor part over
/// <class>OcuPilot.Test.MonitorPortFixture</class>'s sensor text and gate
/// (<class>OcuPilot.Test.ScreenGate</class>). Needs a compiled instance; makes no request and
/// writes only process-private globals.</p>
Class OcuPilot.Test.Dashboard Extends %UnitTest.TestCase
{

/// <p>The descriptor under test.</p>
Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.Dashboard";

/// <p>The tool identifier the screen read and the derived read tool share.</p>
Parameter TOOL = "osmgmt.dashboard";

/// <p><code>%Api.Admin.Endpoints.Monitor</code>'s <code>DASHBOARDMAIN</code> type number, which
/// <class>OcuPilot.Test.ReadSource.Endpoint</class> dispatches on.</p>
Parameter DASHBOARDMAINTYPE = 12;

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.ReadSource.Endpoint")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

/// <p>A <code>DASHBOARDMAIN</code> answer shaped as the vendor answers it.</p>
ClassMethod Main() As %DynamicObject
{
    Quit {
        "Performance": {"GlobalRefsPerSecond": 219, "GlobalRefs": 64649129276, "GlobalSetKill": 4300249416, "RoutineRefs": 14225921180, "LogicalRequests": 18953306300, "DiskReads": 88675, "DiskWrites": 15858093, "CacheEfficiency": 4054.06},
        "ECP": {"ECPClients": "Normal", "ECPClientTraffic": 0, "ECPServers": "Normal", "ECPServerTraffic": 0, "ShadowConnections": "Normal", "Shadows": "Normal"},
        "Status": {"UpTime": "8d 18h 25m", "LastBackup": "Never", "SystemMonitor": false},
        "SystemUsage": {"DatabaseSpace": "Normal", "DatabaseJournal": "Normal", "JournalSpace": "Normal", "JournalEntries": 1392479607, "LockTable": "Normal", "WriteDaemon": "Normal", "Processes": 5, "CSPSessions": 0, "BusyProcesses": [{"Process": 1974, "Commands": 86}]},
        "Alerts": {"SeriousAlerts": 3, "ApplicationErrors": 0},
        "Licensing": {"LicenseLimit": 8, "LicenseUse": 13, "LicenseUseHigh": 38},
        "UpcomingTasks": [{"Task": "OcuPilotDemo nightly purge", "Time": "03:00", "Status": "Suspended"}]
    }
}

/// <p>Sensor text in the vendor's exposition form carrying the unlabeled CPU line at
/// <var>pCpu</var>, a labeled per-process CPU line and one other metric, or no CPU line at all when
/// <var>pCpu</var> is <code>""</code>.</p>
ClassMethod Sensors(pCpu As %String) As %String
{
    Set tCpu = ..Metric("cpu_usage")
    Set tText = "# HELP " _ ..Metric("cpu_pct") _ " CPU usage (percentage) by process type" _ $Char(10) _ ..Metric("cpu_pct") _ "{id=""WRTDMN""} 90" _ $Char(10)
    If pCpu '= "" Set tText = tText _ "# HELP " _ tCpu _ " CPU usage (percentage) system-wide" _ $Char(10) _ "# TYPE " _ tCpu _ " gauge" _ $Char(10) _ tCpu _ " " _ pCpu _ $Char(10)
    Quit tText _ ..Metric("glo_ref_per_sec") _ " 47089" _ $Char(10)
}

/// <p>The vendor's full metric name for <var>pSuffix</var>, spelled here rather than read from the
/// port, so a port that read the wrong metric is caught (as <class>OcuPilot.Test.MonitorPort</class>
/// spells them).</p>
ClassMethod Metric(pSuffix As %String) As %String
{
    Quit ##class(OcuPilot.Test.MonitorPort).Name(pSuffix)
}

/// <p>Arm the admin part's canned answer.</p>
ClassMethod ArmMain()
{
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byType", ..Main().%ToJSON(), ..#DASHBOARDMAINTYPE)
}

/// <p>The declaration passes the read grammar; its route and tool identifier resolve to it; it is
/// the OS management area's eighth entry, a <code>meters</code> screen on no entity type at instance
/// scope with no id, refreshing at 5, 10, 30 and 60 seconds with no default rate, over the two OS
/// management pairs, with the three aliases, the three prompts in their groups, its classic page
/// and no action. Its read is a parts <code>GET</code> of <code>Monitor</code>:
/// <code>DASHBOARDMAIN</code> as <code>Dashboard</code>, then the monitor port's
/// <code>SENSORS</code> as <code>Sensors</code>, projecting thirty fields, every one filterable,
/// sortable and a column, with <code>Dashboard.Status.UpTime</code> the name column.</p>
/// <p>Mutation: declare <code>refreshes</code> false on the descriptor -&gt; the refresh row goes
/// red.</p>
Method TestTheDeclarationIsTheDashboardsThirtyFieldsOverTwoParts()
{
    Set tClass = ..#DESCRIPTOR
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read and table are the declared grammar")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and it links out to nothing, meters being a none link-out archetype")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/dashboard"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool(..#TOOL), tClass, "and so does its tool identifier")

    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "os-management", "in the OS management area")
    Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), 8, "the eighth entry, after License usage")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "meters", "on the meters archetype")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ $ClassMethod(tClass, "IdKind"), "|instance|none", "no entity type, instance scope, no id")
    Do $$$AssertEquals($ClassMethod(tClass, "Refreshes"), 1, "it refreshes")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "RefreshRates")), "5,10,30,60", "at the AD-43 roster")
    Do $$$AssertEquals(+$ClassMethod(tClass, "RefreshDefault"), 0, "and defaults off")
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseUsage).PairsText($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Operate:USE,%DB_IRISSYS:READ", "the two pairs, in order")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("os-management", $ClassMethod(tClass, "PrivilegePairs")), "", "which the area covers")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "CommandAliases")), "dashboard,system dashboard,cpu", "its three aliases")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%cspapp.op.utildashboard", "the classic page it replaces")
    Do $$$AssertEquals($ClassMethod(tClass, "EmptyStateKey"), "dashboardEmpty", "its empty text")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")) + ($ClassMethod(tClass, "PrimaryActionId") '= ""), 0, "no action")
    Set tPrompts = ""
    Set tIterator = tDeclaration.suggestedPrompts.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPrompt) {
        Set tPrompts = tPrompts _ $Select(tPrompts = "": "", 1: ",") _ tPrompt.groupKey _ ":" _ tPrompt.textKey
    }
    Do $$$AssertEquals(tPrompts, "promptGroupTroubleshooting:dashboardPrompt1,promptGroupCapacity:dashboardPrompt2,promptGroupTroubleshooting:dashboardPrompt3", "its three prompts in their groups")

    Set tSource = tDeclaration.read.source
    Do $$$AssertEquals(tSource.port _ "|" _ tSource.endpoint _ "|" _ tSource.type, "admin|Monitor|GET", "a parts GET of Monitor")
    Do $$$AssertEquals(tSource.parts.%ToJSON(), [{"type": "DASHBOARDMAIN", "as": "Dashboard"}, {"port": "monitor", "type": "SENSORS", "as": "Sensors"}].%ToJSON(), "DASHBOARDMAIN, then the sensors through the monitor port")
    Do $$$AssertEquals(tDeclaration.read.fields.%Size(), 30, "thirty declared fields")
    Do $$$AssertEquals(tDeclaration.read.filter.%ToJSON(), tDeclaration.read.fields.%ToJSON(), "every field filterable")
    Do $$$AssertEquals(tDeclaration.read.sort.fields.%ToJSON(), tDeclaration.read.fields.%ToJSON(), "and sortable")
    Set tColumns = []
    Set tNames = 0
    Set tIterator = tDeclaration.table.columns.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) {
        Do tColumns.%Push(tColumn.field)
        If tColumn.kind = "name" Set tNames = tNames + 1, tName = tColumn.field
    }
    Do $$$AssertEquals(tColumns.%ToJSON(), tDeclaration.read.fields.%ToJSON(), "and a column, in order")
    Do $$$AssertEquals(tNames _ "|" _ $Get(tName), "1|Dashboard.Status.UpTime", "Uptime is the one name column")
}

/// <p>The screen context carries exactly the read's thirty fields, CPU among them, so the agent is
/// sent the fields the screen draws (AD-24, AC6).</p>
/// <p>Mutation: drop <code>Sensors.cpuUsage</code> from the descriptor's <code>context.fields</code>
/// -&gt; this goes red.</p>
Method TestTheScreenContextCarriesTheReadsFields()
{
    Set tRead = $ClassMethod(..#DESCRIPTOR, "Read")
    Set tFields = ""
    Set tIterator = tRead.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tFields = tFields _ $ListBuild(tField)
    }
    Do $$$AssertEquals($ListToString($ClassMethod(..#DESCRIPTOR, "ContextFields")), $ListToString(tFields), "the context carries the read's fields, in order")
    Do $$$AssertTrue($ListFind($ClassMethod(..#DESCRIPTOR, "ContextFields"), "Sensors.cpuUsage") > 0, "CPU among them")
}

/// <p>The sensors' unlabeled system-wide CPU line is merged as <code>Sensors.cpuUsage</code>, a
/// JSON number, beside the <code>DASHBOARDMAIN</code> fields, in one row from one collection taken
/// in <code>%SYS</code>; the labeled per-process line is not read.</p>
/// <p>Mutation: drop the monitor part from the descriptor -&gt; <code>Sensors.cpuUsage</code> reads
/// null and the collection count is zero, and this goes red.</p>
Method TestTheSensorsCpuIsMerged()
{
    Do ..ArmMain()
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText(..Sensors("42.5"))
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the merged read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%Size(), 1, "exactly one row")
    If tResult.rows.%Size() '= 1 Quit
    Set tRow = tResult.rows.%Get(0)
    Do $$$AssertEquals(tRow.%Get("Sensors.cpuUsage") _ ":" _ tRow.%GetTypeOf("Sensors.cpuUsage"), "42.5:number", "CPU from the unlabeled line, as a number")
    Do $$$AssertEquals(tRow.%Get("Dashboard.Status.UpTime"), "8d 18h 25m", "beside the DASHBOARDMAIN fields")
    Do $$$AssertEquals(tRow.%Get("Dashboard.Licensing.LicenseUse"), 13, "a nested member two segments deep")
    Do $$$AssertEquals(tRow.%Get("Dashboard.ECP.ECPClients"), "Normal", "and the vendor's own status word")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceCalls(), 1, "from one collection")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceNamespace(), "%SYS", "taken in %SYS")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("monitorTypes"), ..#DASHBOARDMAINTYPE, "and DASHBOARDMAIN issued once, the sensors never through the admin endpoint")
}

/// <p>A monitor part refused or faulting fails the whole read with no partial row: a caller the
/// monitor port's gate refuses is answered 403 naming the failed pair, with no sensor call; a
/// collection lacking the CPU line is 500 <code>INTERNAL</code>; a collection that raises is 500
/// <code>INTERNAL</code>, logged once, with the caller's namespace restored; and a
/// <code>DASHBOARDMAIN</code> fault fails the read with that part's own fault before the sensors are
/// read.</p>
/// <p>Mutation: drop the gate call from <method>OcuPilot.Port.MonitorPort.Invoke</method> -&gt; the
/// refused read answers 200 with one collection, and the refusal rows go red.</p>
Method TestAMonitorPartRefusalOrFaultFailsTheWholeRead()
{
    Do ..ArmMain()
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText(..Sensors("7"))
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a refused monitor part fails the read")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Set tPair = ""
    If $IsObject(tFault) && $IsObject(tFault.%Get("detail")) Set tPair = tFault.detail.failedPair
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: "") _ " " _ tPair, "AUTH.NOPRIVILEGE %Admin_Operate:USE", "naming the pair the monitor port's gate refused")
    Do $$$AssertEquals(tResult, "", "with no partial row")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceCalls(), 0, "and no sensor call")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).LogCalls(), 0, "and a refusal is not logged as a fault")

    Do ..ClearFixtures()
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.ReadSource.Endpoint")
    Do ..ArmMain()
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText(..Sensors(""))
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusNotOK(tSC, "a collection with no CPU line fails the read")
    Do $$$AssertEquals(tHttp2, 500, "at 500")
    Do $$$AssertEquals($Select($IsObject(tFault2): tFault2.code, 1: ""), "INTERNAL", "as the generic internal fault")
    Do $$$AssertEquals(tResult2, "", "with no partial row")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).LogCalls(), 1, "logged once")

    Do ..ClearFixtures()
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.ReadSource.Endpoint")
    Do ..ArmMain()
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetRaise(1)
    Set tNamespace = $NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tResult4, .tHttp4, .tFault4)
    Do $$$AssertStatusNotOK(tSC, "a collection that raises fails the read")
    Do $$$AssertEquals(tHttp4, 500, "at 500")
    Do $$$AssertEquals($Select($IsObject(tFault4): tFault4.code, 1: ""), "INTERNAL", "as the generic internal fault")
    Do $$$AssertEquals(tResult4, "", "with no partial row")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).LogCalls(), 1, "logged once")
    Do $$$AssertEquals($NAMESPACE, tNamespace, "and the caller's namespace restored")

    Do ..ClearFixtures()
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.ReadSource.Endpoint")
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byTypeFault", "errorstatus", ..#DASHBOARDMAINTYPE)
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText(..Sensors("7"))
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tResult3, .tHttp3, .tFault3)
    Do $$$AssertStatusNotOK(tSC, "a DASHBOARDMAIN fault fails the read")
    Do $$$AssertEquals(tHttp3, 500, "with that part's own status")
    Do $$$AssertEquals(tResult3, "", "with no partial row")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceCalls(), 0, "and the sensors are never read")
}

/// <p><method>OcuPilot.Port.MonitorPort.Invoke</method> answers the sensors endpoint's one type with
/// <code>{cpuUsage}</code> and nothing else, and refuses another endpoint or another type 500
/// <code>INTERNAL</code>, logged once, with no sensor call.</p>
/// <p>Mutation: drop the endpoint and type check from
/// <method>OcuPilot.Port.MonitorPort.Invoke</method> -&gt; both refusals answer 200 and go red.</p>
Method TestInvokeRefusesAnotherEndpointOrType()
{
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText(..Sensors("3"))
    Kill tQuery
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Sensors", "SENSORS", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the sensors endpoint's one type is answered")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals($Select($IsObject(tResult): tResult.%ToJSON(), 1: ""), {"cpuUsage": 3}.%ToJSON(), "with the CPU member alone")

    For tCase = $ListBuild("Monitor", "SENSORS"), $ListBuild("Sensors", "DASHBOARDMAIN"), $ListBuild("Sensors", "sensors") {
        Set tWhere = $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": "
        Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
        Do ##class(OcuPilot.Test.MonitorPortFixture).SetText(..Sensors("3"))
        Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke($List(tCase, 1), $List(tCase, 2), .tQuery, "", .tResult2, .tHttp2, .tFault2)
        Do $$$AssertStatusNotOK(tSC, tWhere _ "refused")
        Do $$$AssertEquals(tHttp2, 500, tWhere _ "at 500")
        Do $$$AssertEquals($Select($IsObject(tFault2): tFault2.code, 1: ""), "INTERNAL", tWhere _ "as the generic internal fault")
        Do $$$AssertEquals(tResult2, "", tWhere _ "answering nothing")
        Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).LogCalls(), 1, tWhere _ "logged once")
        Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceCalls(), 0, tWhere _ "with no sensor call")
    }
}

/// <p>Home's performance read is unchanged: <method>OcuPilot.Port.MonitorPort.Performance</method>
/// still answers exactly its five members, and not the CPU a monitor part reads.</p>
Method TestPerformanceStillAnswersFiveMembers()
{
    Set tText = ..Sensors("3") _ ..Metric("cache_efficiency") _ " 10" _ $Char(10) _ ..Metric("glo_update_per_sec") _ " 2" _ $Char(10) _ ..Metric("phys_reads_per_sec") _ " 4" _ $Char(10) _ ..Metric("phys_writes_per_sec") _ " 5" _ $Char(10)
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText(tText)
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Performance(.tValues, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the performance read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Set tKeys = ""
    If $IsObject(tValues) {
        Set tIterator = tValues.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
        }
    }
    Do $$$AssertEquals(tKeys, "cacheEfficiency,globalReferencesPerSecond,globalUpdatesPerSecond,diskReadsPerSecond,diskWritesPerSecond", "its five members, and no CPU")
}

}
