/// <p>Story 18.36's four Dashboard drill-downs (AD-5, AD-36): their declarations, the two statistics screens' one
/// row, System resource statistics cut at the cap, Most active processes without the vendor's padded rows, a vendor
/// answer of another shape failing the read closed with one log line, and the four reads against the live instance.</p>
/// <p>The fixture legs run through <class>OcuPilot.Test.Read.ReadFixture</class> over
/// <class>OcuPilot.Test.ReadSource.Endpoint</class>, whose answer each test arms; the live legs read this instance as
/// this account. Needs a compiled instance with OcuPilot installed; writes only process-private globals and creates no
/// principal.</p>
Class OcuPilot.Test.DashboardDrillDown Extends %UnitTest.TestCase
{

/// <p>The package the four descriptors sit in.</p>
Parameter PACKAGE = "OcuPilot.Screen.Descriptor.";

/// <p>The four screens as <code>descriptor:route:tool:archetype:classicPage:promptStem</code>.</p>
Parameter SCREENS = "DashboardGlobals:os-management/global-statistics:osmgmt.globalstatistics:detail:%cspapp.op.utilsysstatisticsglobal:globalStatistics,DashboardEcp:os-management/ecp-statistics:osmgmt.ecpstatistics:detail:%cspapp.op.utilsysstatisticsecp:ecpStatistics,DashboardResources:os-management/resource-statistics:osmgmt.resourcestatistics:list:%cspapp.op.utilsysstatisticsresource:resourceStatistics,DashboardProcesses:os-management/active-processes:osmgmt.activeprocesses:list:%cspapp.op.utildashboard:activeProcesses";

/// <p>Global and routine statistics' eighteen fields, in declared order.</p>
Parameter GLOBALFIELDS = "Statistics.Globals.RefLocal,Statistics.Globals.RefUpdateLocal,Statistics.Globals.RefRemote,Statistics.Globals.RefUpdateRemote,Statistics.Globals.RefPrivate,Statistics.Globals.RefUpdatePrivate,Statistics.Globals.LogicalBlocks,Statistics.Globals.PhysBlockReads,Statistics.Globals.PhysBlockWrites,Statistics.Globals.WIJWrites,Statistics.Globals.JrnEntries,Statistics.Globals.JrnBlocks,Statistics.Routines.RtnCallsLocal,Statistics.Routines.RtnFetchLocal,Statistics.Routines.RtnCallsRemote,Statistics.Routines.RtnFetchRemote,Statistics.Routines.RtnCommands,Statistics.Routines.RtnNotCached";

/// <p>ECP statistics' thirty-three fields: the application server's sixteen, then the data server's seventeen.</p>
Parameter ECPFIELDS = "Ecp.AppServer.MaxConn,Ecp.AppServer.ActConn,Ecp.AppServer.GloRef,Ecp.AppServer.ByteSent,Ecp.AppServer.ByteRcvd,Ecp.AppServer.BlockAdd,Ecp.AppServer.BlockBuffPurge,Ecp.AppServer.BlockSvrPurge,Ecp.AppServer.GloRefLocal,Ecp.AppServer.GloRefRemote,Ecp.AppServer.GloUpdateLocal,Ecp.AppServer.GloUpdateRemote,Ecp.AppServer.RoutineCallLocal,Ecp.AppServer.RoutineCallRemote,Ecp.AppServer.RoutineBuffLocal,Ecp.AppServer.RoutineBuffRemote,Ecp.DataServer.MaxConn,Ecp.DataServer.ActConn,Ecp.DataServer.GloRef,Ecp.DataServer.ByteSent,Ecp.DataServer.ByteRcvd,Ecp.DataServer.GloUpdate,Ecp.DataServer.ReqRcvd,Ecp.DataServer.ReqBuff,Ecp.DataServer.BlockSent,Ecp.DataServer.LockGrant,Ecp.DataServer.LockFail,Ecp.DataServer.LockQueGrant,Ecp.DataServer.LockQueFail,Ecp.DataServer.SvrBlockPurge,Ecp.DataServer.RoutinePurge,Ecp.DataServer.BigKill,Ecp.DataServer.BigString";

Parameter RESOURCEFIELDS = "Name,Seize,Nseize,Aseize,Bseize,BusySet";

Parameter PROCESSFIELDS = "Process,Commands";

/// <p>The vendor's request type numbers <class>OcuPilot.Test.ReadSource.Endpoint</class> dispatches on.</p>
Parameter ECPTYPE = 10;

Parameter GLOBALSTYPE = 11;

Parameter MAINTYPE = 12;

Parameter RESOURCESTYPE = 13;

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
}

/// <p>The <var>pPiece</var>th piece of <parameter>SCREENS</parameter>' <var>pIndex</var>th entry.</p>
ClassMethod Screen(pIndex As %Integer, pPiece As %Integer) As %String
{
    Quit $Piece($Piece(..#SCREENS, ",", pIndex), ":", pPiece)
}

/// <p>The declared fields of screen <var>pIndex</var>, comma-separated.</p>
ClassMethod FieldsOf(pIndex As %Integer) As %String
{
    Quit $Case(pIndex, 1: ..#GLOBALFIELDS, 2: ..#ECPFIELDS, 3: ..#RESOURCEFIELDS, : ..#PROCESSFIELDS)
}

/// <p>The members of the array <var>pArray</var>, comma-separated.</p>
ClassMethod Joined(pArray As %DynamicArray) As %String
{
    Quit ##class(OcuPilot.Test.JournalDescriptor).Joined(pArray)
}

/// <p>The vendor's answer for screen <var>pIndex</var>'s statistics type: one object per group, one number per
/// field -- the field's position, so no value is mistaken for another field's.</p>
ClassMethod StatisticsAnswer(pIndex As %Integer) As %DynamicObject
{
    Set tAnswer = {}
    Set tFields = ..FieldsOf(pIndex)
    For tI = 1:1:$Length(tFields, ",") {
        Set tPath = $Piece(tFields, ",", tI)
        Set tGroup = $Piece(tPath, ".", 2)
        If tAnswer.%GetTypeOf(tGroup) = "unassigned" Do tAnswer.%Set(tGroup, {})
        Do tAnswer.%Get(tGroup).%Set($Piece(tPath, ".", 3), tI * 100 + tI)
    }
    Quit tAnswer
}

/// <p>Arm the stand-in endpoint's answer to the vendor request type <var>pType</var> with <var>pAnswer</var>.</p>
ClassMethod Arm(pType As %Integer, pAnswer As %DynamicAbstractObject)
{
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byType", pAnswer.%ToJSON(), pType)
}

/// <p>A <code>DASHBOARDMAIN</code> answer whose busy process list is <var>pRows</var>.</p>
ClassMethod MainAnswer(pRows As %DynamicArray) As %DynamicObject
{
    Quit {"SystemUsage": {"BusyProcesses": (pRows)}}
}

/// <p>The read of <var>pClass</var> (a descriptor without its package) through the fixture port, capped at
/// <var>pMax</var> rows.</p>
ClassMethod Fixture(pClass As %String, pMax As %String, Output pResult As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#PACKAGE _ pClass, pMax, .pResult, .pHttp, .pFault)
}

/// <p>How many lines the fixture port has logged since its last <method>OcuPilot.Test.PortFixture.Clear</method>.</p>
ClassMethod Logged() As %Integer
{
    Quit +##class(OcuPilot.Test.PortFixture).Recorded("logCalls")
}

/// <p>The four declarations pass the registry's read grammar and resolve by route and by tool; each is built,
/// unlisted, in OS management behind the two OS management pairs and no pair of its own, administers nothing, takes
/// no action, criterion or refresh, declares its classic page without an exemption, and carries exactly its fields as
/// context, read, sort and table, filtering the statistics screens on every field, the resources on
/// <code>Name</code> and the processes on <code>Process</code>.</p>
/// <p>Mutation: declare <code>DASHBOARDECP</code> as the global statistics part -&gt; its source row goes red.</p>
Method TestTheFourDeclarations()
{
    Set tValidateSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tValidateSC, "the registry validates with the four screens in it: " _ $Get(tProblem))
    For tI = 1:1:4 {
        Set tClass = ..#PACKAGE _ ..Screen(tI, 1)
        Set tWhere = ..Screen(tI, 1) _ ": "
        Set tFields = ..FieldsOf(tI)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tWhere _ "the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tWhere _ "its read and table are the declared grammar")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", tWhere _ "and it links out to nothing")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute(..Screen(tI, 2)), tClass, tWhere _ "its route resolves to it")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool(..Screen(tI, 3)), tClass, tWhere _ "and so does its tool identifier")
        Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition") _ "|" _ $ClassMethod(tClass, "IsBuilt") _ "|" _ $ClassMethod(tClass, "AreaKey") _ "|" _ $ClassMethod(tClass, "Archetype"), "0|1|os-management|" _ ..Screen(tI, 4), tWhere _ "unlisted, built, in OS management, on its archetype")
        Do $$$AssertEquals(##class(OcuPilot.Test.LicenseUsage).PairsText($ClassMethod(tClass, "PrivilegePairs")) _ "|" _ $ListLength($ClassMethod(tClass, "OwnPrivilegePairs")), "%Admin_Operate:USE,%DB_IRISSYS:READ|0", tWhere _ "the Dashboard's two pairs, none its own")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("os-management", $ClassMethod(tClass, "PrivilegePairs")), "", tWhere _ "which the area covers")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ $ClassMethod(tClass, "IdKind") _ "|" _ $ListLength($ClassMethod(tClass, "RowActionIds")) _ "|" _ $ClassMethod(tClass, "PrimaryActionId"), "|instance|none|0|", tWhere _ "no entity type, instance scope, no id, no action")
        Do $$$AssertEquals($ClassMethod(tClass, "Refreshes") _ "|" _ $ListLength($ClassMethod(tClass, "RefreshRates")) _ "|" _ $ListLength($ClassMethod(tClass, "CommandAliases")) _ "|" _ $ListLength($ClassMethod(tClass, "ContextSecretFields")), "0|0|0|0", tWhere _ "no refresh, alias or secret field")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), ..Screen(tI, 5), tWhere _ "the classic page it replaces")

        Set tRead = tDeclaration.read
        Do $$$AssertEquals(..Joined(tRead.fields), tFields, tWhere _ "the read's fields")
        Do $$$AssertEquals(..Joined(tDeclaration.context.fields), tFields, tWhere _ "and the context carry the same fields")
        Do $$$AssertEquals(..Joined(tRead.sort.fields), tFields, tWhere _ "and so does the sort")
        Do $$$AssertEquals(..Joined(tRead.filter), $Case(tI, 3: "Name", 4: "Process", : tFields), tWhere _ "the filter fields")
        Do $$$AssertEquals(tRead.sort.default _ " " _ tRead.sort.direction, $Case(tI, 3: "Seize desc", 4: "Commands desc", : $Piece(tFields, ",", 1) _ " asc"), tWhere _ "the default sort")
        Do $$$AssertEquals(tRead.paging _ "|" _ tDeclaration.table.emptyNextKey _ "|" _ tDeclaration.table.emptyAgentKey, "cap|tableReadOnlyEmptyNext|", tWhere _ "bounded by the cap, with the read-only next step")
        Do $$$AssertEquals(tDeclaration.emptyStateKey, $Case(tI, 3: "resourceStatisticsEmpty", 4: "activeProcessesEmpty", : "statisticsEmpty"), tWhere _ "its own empty-state text")
        Set tKinds = ""
        Set tIterator = tDeclaration.table.columns.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tColumn) {
            Set tKinds = tKinds _ $Select(tKinds = "": "", 1: ",") _ tColumn.field _ "=" _ tColumn.kind
        }
        Set tExpected = ""
        For tJ = 1:1:$Length(tFields, ",") {
            Set tExpected = tExpected _ $Select(tExpected = "": "", 1: ",") _ $Piece(tFields, ",", tJ) _ "=" _ $Select(tJ = 1: "name", 1: "number")
        }
        Do $$$AssertEquals(tKinds, tExpected, tWhere _ "the first column is the name column and the rest numbers")

        Set tSource = tRead.source
        Set tSourceText = tSource.port _ "|" _ tSource.endpoint _ "|" _ tSource.type
        If tI <= 2 {
            Set tPart = tSource.parts.%Get(0)
            Do $$$AssertEquals(tSourceText _ "|" _ tSource.parts.%Size() _ "|" _ tPart.type _ "|" _ tPart.as, "admin|Monitor|GET|1|" _ $Case(tI, 1: "DASHBOARDGLOBALS|Statistics", : "DASHBOARDECP|Ecp"), tWhere _ "one part of the Monitor endpoint")
        } Else {
            Do $$$AssertEquals(tSourceText _ "|" _ tSource.rows, "admin|Monitor|" _ $Case(tI, 3: "RESOURCEROWS|Resources", : "BUSYPROCESSES|BusyProcesses"), tWhere _ "one member of a composed read")
        }
        Set tPrompts = ""
        Set tPromptIterator = tDeclaration.suggestedPrompts.%GetIterator()
        While tPromptIterator.%GetNext(.tIndex, .tPrompt) {
            Set tPrompts = tPrompts _ $Select(tPrompts = "": "", 1: ",") _ tPrompt.groupKey _ ":" _ tPrompt.textKey
        }
        Set tStem = ..Screen(tI, 6)
        Do $$$AssertEquals(tPrompts, "promptGroupTroubleshooting:" _ tStem _ "Prompt1,promptGroupTroubleshooting:" _ tStem _ "Prompt2,promptGroupCapacity:" _ tStem _ "Prompt3", tWhere _ "two Troubleshooting prompts and one Capacity prompt of its own")
    }
}

/// <p>Each statistics screen reads one row carrying every declared field with the vendor's value, issued as its own
/// request type once.</p>
/// <p>Mutation: issue <code>DASHBOARDECP</code> for the global statistics part -&gt; its type row goes red.</p>
Method TestTheStatisticsScreensProjectOneRow()
{
    For tI = 1:1:2 {
        Set tWhere = ..Screen(tI, 1) _ ": "
        Set tType = $Case(tI, 1: ..#GLOBALSTYPE, : ..#ECPTYPE)
        Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
        Do ..Arm(tType, ..StatisticsAnswer(tI))
        Set tSC = ..Fixture(..Screen(tI, 1), "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tWhere _ "the read succeeds")
        Do $$$AssertEquals(tHttp, 200, tWhere _ "at 200")
        If '$IsObject(tResult) Continue
        Do $$$AssertEquals(..Joined(tResult.fields), ..FieldsOf(tI), tWhere _ "the declared fields")
        Do $$$AssertEquals(tResult.rows.%Size() _ "|" _ tResult.truncated, "1|0", tWhere _ "one row, not truncated")
        If tResult.rows.%Size() '= 1 Continue
        Set tRow = tResult.rows.%Get(0)
        Set tFields = ..FieldsOf(tI)
        For tJ = 1:1:$Length(tFields, ",") {
            Set tField = $Piece(tFields, ",", tJ)
            Do $$$AssertEquals(tRow.%Get(tField), tJ * 100 + tJ, tWhere _ tField _ " is the vendor's value")
        }
        Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("monitorTypes"), tType, tWhere _ "issued as its own type, once")
    }
}

/// <p>System resource statistics sends the vendor the cap plus one, keeps at most the cap's rows and reports
/// truncation when the vendor answered the extra row; a vendor answer of exactly the cap is not truncated.</p>
/// <p>Mutation: answer the bare array rather than <code>{"Resources": [...]}</code> from
/// <method>OcuPilot.Port.AdminPort.ComposedAnswer</method> -&gt; every read here fails as not a list.</p>
Method TestResourcesAreCutAtTheCap()
{
    Set tResources = []
    For tI = 1:1:4 {
        Do tResources.%Push({"Name": ("Resource" _ tI), "Seize": (tI), "Nseize": 0, "Aseize": 0, "Bseize": 0, "BusySet": 0})
    }
    Do ..Arm(..#RESOURCESTYPE, tResources)
    Set tSC = ..Fixture("DashboardResources", 3, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the capped read succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("monitorTypes") _ " " _ ##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("monitorQuery"), ..#RESOURCESTYPE _ " maxRows=4", "the vendor is asked for the resource statistics with the cap plus one")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%Size() _ "|" _ tResult.truncated, "3|1", "the cap's rows are kept and truncation is reported")
    Do $$$AssertEquals(tResult.rows.%Get(0).Name _ "," _ tResult.rows.%Get(2).Name, "Resource1,Resource3", "the first rows the vendor answered")

    Set tSC = ..Fixture("DashboardResources", 4, .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC, "a cap the answer fits succeeds")
    If '$IsObject(tResult2) Quit
    Do $$$AssertEquals(tResult2.rows.%Size() _ "|" _ tResult2.truncated, "4|0", "every row is kept and nothing is truncated")
}

/// <p>Most active processes keeps the vendor's rows whose <code>Process</code> is set, in the vendor's order, and
/// drops each row whose <code>Process</code> is empty, however many the vendor pads the list with and wherever they
/// stand.</p>
/// <p>Mutation: keep the empty rows in <method>OcuPilot.Port.AdminPort.ComposedAnswer</method> -&gt; the row count
/// goes red.</p>
Method TestBusyProcessesDropThePaddedRows()
{
    Set tRows = [{"Process": 4101, "Commands": 90}, {"Process": 4102, "Commands": 7}]
    For tI = 1:1:8 {
        Do tRows.%Push({"Process": "", "Commands": 0})
    }
    Do ..Arm(..#MAINTYPE, ..MainAnswer(tRows))
    Set tSC = ..Fixture("DashboardProcesses", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%Size() _ "|" _ tResult.truncated, "2|0", "the two real rows, not truncated")
    Do $$$AssertEquals(tResult.rows.%Get(0).Process _ "," _ tResult.rows.%Get(0).Commands _ ";" _ tResult.rows.%Get(1).Process _ "," _ tResult.rows.%Get(1).Commands, "4101,90;4102,7", "in the vendor's order, with their commands")
    Do $$$AssertEquals(##class(OcuPilot.Test.ReadSource.Endpoint).Recorded("monitorTypes"), ..#MAINTYPE, "issued as the dashboard's type, once")

    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ..Arm(..#MAINTYPE, ..MainAnswer([{"Process": "", "Commands": 0}, {"Process": 6, "Commands": 2}, {"Process": "", "Commands": 0}, {"Process": 5, "Commands": 3}]))
    Set tSC = ..Fixture("DashboardProcesses", "", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC, "a list with empty rows between real ones reads")
    If '$IsObject(tResult2) Quit
    Do $$$AssertEquals(tResult2.rows.%Get(0).Process _ "," _ tResult2.rows.%Get(1).Process _ "|" _ tResult2.rows.%Size(), "6,5|2", "keeps the real rows in the vendor's order, neither by process nor by commands")

    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ..Arm(..#MAINTYPE, ..MainAnswer([{"Process": "", "Commands": 0}]))
    Set tSC = ..Fixture("DashboardProcesses", "", .tResult3, .tHttp3, .tFault3)
    Do $$$AssertStatusOK(tSC, "a list of padding alone reads")
    If '$IsObject(tResult3) Quit
    Do $$$AssertEquals(tResult3.rows.%Size() _ "|" _ tResult3.truncated, "0|0", "as no rows")
}

/// <p>A vendor answer of another shape than a composed type reads fails the whole read as the generic internal fault
/// at 500, with no rows and one line in the log: for the resources, an object, or an array of anything but objects;
/// for the busy processes, an array, a dashboard without its usage, a usage without its list, a list that is an object
/// and a list of anything but objects.</p>
/// <p>Mutation: skip the element check in <method>OcuPilot.Port.AdminPort.ComposedAnswer</method> -&gt; the
/// array-of-strings rows go red.</p>
Method TestAnAnswerOfAnotherShapeFailsTheReadOnceLogged()
{
    Set tCases = $ListBuild($ListBuild("DashboardResources", ..#RESOURCESTYPE, "an object", "{""Resources"": []}"))
    Set tCases = tCases _ $ListBuild($ListBuild("DashboardResources", ..#RESOURCESTYPE, "an array of strings", "[""Pid""]"))
    Set tCases = tCases _ $ListBuild($ListBuild("DashboardResources", ..#RESOURCESTYPE, "an array holding a number", "[{""Name"": ""Pid""}, 1]"))
    Set tCases = tCases _ $ListBuild($ListBuild("DashboardProcesses", ..#MAINTYPE, "an array", "[]"))
    Set tCases = tCases _ $ListBuild($ListBuild("DashboardProcesses", ..#MAINTYPE, "a dashboard without its usage", "{""Performance"": {}}"))
    Set tCases = tCases _ $ListBuild($ListBuild("DashboardProcesses", ..#MAINTYPE, "a usage without its list", "{""SystemUsage"": {}}"))
    Set tCases = tCases _ $ListBuild($ListBuild("DashboardProcesses", ..#MAINTYPE, "a list that is an object", "{""SystemUsage"": {""BusyProcesses"": {}}}"))
    Set tCases = tCases _ $ListBuild($ListBuild("DashboardProcesses", ..#MAINTYPE, "a list of strings", "{""SystemUsage"": {""BusyProcesses"": [""3663""]}}"))
    Set tCases = tCases _ $ListBuild($ListBuild("DashboardProcesses", ..#MAINTYPE, "a list holding an array", "{""SystemUsage"": {""BusyProcesses"": [{""Process"": 1}, []]}}"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tWhere = $List(tCase, 3) _ " for " _ $List(tCase, 1) _ ": "
        Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
        Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byType", $List(tCase, 4), $List(tCase, 2))
        Set tBefore = ..Logged()
        Set tSC = ..Fixture($List(tCase, 1), "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tWhere _ "the read fails")
        Do $$$AssertEquals(tHttp, 500, tWhere _ "at 500")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "INTERNAL " _ ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, tWhere _ "as the generic internal fault")
        Do $$$AssertEquals(tResult, "", tWhere _ "with no rows")
        Do $$$AssertEquals(..Logged() - tBefore, 1, tWhere _ "logged once")
    }
}

/// <p>The four reads against the live instance, as this account (AC1): each statistics screen answers one row with
/// every declared field a number; System resource statistics is cut at the cap it is asked for and every row carries
/// a name; Most active processes answers at most ten rows, none with an empty process.</p>
/// <p>Mutation: leave <code>DASHBOARDGLOBALS</code> out of <parameter>OcuPilot.Port.AdminPort.BARETYPES</parameter>
/// -&gt; the global statistics read answers 501 and goes red.</p>
Method TestTheFourReadsAnswerLive()
{
    For tI = 1:1:2 {
        Set tWhere = ..Screen(tI, 1) _ ": "
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#PACKAGE _ ..Screen(tI, 1), "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tWhere _ "the live read succeeds")
        Do $$$AssertEquals(tHttp, 200, tWhere _ "at 200")
        If '$IsObject(tResult) Continue
        Do $$$AssertEquals(tResult.rows.%Size(), 1, tWhere _ "one row")
        If tResult.rows.%Size() '= 1 Continue
        Set tRow = tResult.rows.%Get(0)
        Set tFields = ..FieldsOf(tI)
        Do $$$AssertEquals(..Joined(tResult.fields), tFields, tWhere _ "every declared field")
        For tJ = 1:1:$Length(tFields, ",") {
            Set tField = $Piece(tFields, ",", tJ)
            Do $$$AssertEquals(tRow.%GetTypeOf(tField), "number", tWhere _ tField _ " is a number")
        }
    }

    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#PACKAGE _ "DashboardResources", 3, .tResources, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC, "the live resource read succeeds")
    Do $$$AssertEquals(tHttp2, 200, "at 200")
    If $IsObject(tResources) {
        Do $$$AssertEquals(tResources.rows.%Size() _ "|" _ tResources.truncated, "3|1", "cut at the cap, with truncation reported")
        Set tIterator = tResources.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow2) {
            Do $$$AssertTrue(tRow2.%Get("Name") '= "", "resource " _ (tIndex + 1) _ " carries its name")
            Do $$$AssertEquals(tRow2.%GetTypeOf("Seize"), "number", "and its seizes as a number")
        }
    }

    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#PACKAGE _ "DashboardProcesses", "", .tProcesses, .tHttp3, .tFault3)
    Do $$$AssertStatusOK(tSC, "the live process read succeeds")
    Do $$$AssertEquals(tHttp3, 200, "at 200")
    If $IsObject(tProcesses) {
        Do $$$AssertTrue(tProcesses.rows.%Size() <= 10, "at most ten rows: " _ tProcesses.rows.%Size())
        Set tIterator = tProcesses.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow3) {
            Do $$$AssertTrue(tRow3.%Get("Process") '= "", "process row " _ (tIndex + 1) _ " carries a process")
            Do $$$AssertEquals(tRow3.%GetTypeOf("Commands"), "number", "and its commands as a number")
        }
    }
}

}
