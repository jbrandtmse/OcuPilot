/// <p>On-demand tasks and Upcoming tasks (Story 6.5): both declarations against the grammar, the
/// registry and the Tasks area's pair set; each read over the wire as the configured test principal
/// (<class>OcuPilot.Test.Http</class>) against the vendor's own <code>%SYS.Task</code> queries -- the
/// on-demand rows, the default horizon, a date horizon, both criteria sent, a refused criterion and
/// the cap -- and each derived read tool, which answers the route's rows narrowed by its cap.</p>
/// <p>Needs the API application installed in <code>HSCUSTOM</code>, the demo fixture's task, and both
/// the test principal and the process running this class holding <code>%Admin_Task:USE</code> and
/// <code>%DB_IRISSYS:READ</code>. It issues reads only and creates nothing; the pair set's denials
/// are <class>OcuPilot.Test.WireSecurityRead</class>'s.</p>
Class OcuPilot.Test.TaskLists Extends %UnitTest.TestCase
{

/// <p>The screen read route's prefix.</p>
Parameter READPATH = "/api/ocupilot/screens/";

/// <p>The On-demand tasks descriptor.</p>
Parameter ONDEMAND = "OcuPilot.Screen.Descriptor.TaskOnDemandList";

/// <p>The Upcoming tasks descriptor.</p>
Parameter UPCOMING = "OcuPilot.Screen.Descriptor.TaskUpcomingList";

/// <p>The demo fixture's task.</p>
Parameter DEMOTASK = "OcuPilotDemo nightly purge";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Request <var>pTool</var>'s read with the query string <var>pQuery</var> as the test principal.
/// <var>pAnswer</var> is the parsed body, or <code>""</code>.</p>
Method Read(pTool As %String, pQuery As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#READPATH _ pTool _ "/read?" _ pQuery, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set pAnswer = ""
    }
    Do $$$AssertTrue($IsObject(pAnswer), pTool _ ": the body parses as JSON")
    Quit tSC
}

/// <p>The ids <code>%SYS.Task:OnDemandTasksFilter("")</code> answers, sorted and comma-separated, or
/// text naming the error when the query fails.</p>
ClassMethod OnDemandIds() As %String
{
    Set tOrigNS = $NAMESPACE
    Kill tIds
    Set tText = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("%SYS.Task:OnDemandTasksFilter")
        $$$ThrowOnError(tRS.Execute(""))
        While tRS.Next() {
            Set tIds(+tRS.GetData(1)) = ""
        }
        Set $NAMESPACE = tOrigNS
        Set tText = ..Joined(.tIds)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "query failed: " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>The occurrences <code>%SYS.Task:UpcomingTasksFilter</code> answers for <var>pHours</var>,
/// <var>pToDate</var> and <var>pToTime</var> at <var>pMaxRows</var>, as <code>Id@Datetime</code>
/// comma-separated in the query's order, <code>Datetime</code> written as the endpoint writes it, or
/// text naming the error when the query fails.</p>
ClassMethod UpcomingOccurrences(pHours As %String, pToDate As %String, pToTime As %String, pMaxRows As %Integer) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("%SYS.Task:UpcomingTasksFilter")
        $$$ThrowOnError(tRS.Execute("", pHours, pToDate, pToTime, pMaxRows))
        While tRS.Next() {
            Set tDate = tRS.Get("Date")
            Set tDatetime = $Select((tDate = "") || (tDate < 1): "", 1: $ZDate(tDate, 3) _ " " _ $ZTime(+tRS.Get("Time")))
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ (+tRS.Get("ID")) _ "@" _ tDatetime
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "query failed: " _ ex.DisplayString()
    }
    Quit tText
}

/// <p><var>pRows</var> as <code>Id@Datetime</code>, comma-separated, in order.</p>
ClassMethod Occurrences(pRows As %DynamicArray) As %String
{
    Set tText = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.Id _ "@" _ tRow.Datetime
    }
    Quit tText
}

/// <p>The subscripts of <var>pSet</var>, in order, comma-separated.</p>
ClassMethod Joined(ByRef pSet) As %String
{
    Set tText = ""
    Set tKey = ""
    For {
        Set tKey = $Order(pSet(tKey))
        If tKey = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tKey
    }
    Quit tText
}

/// <p>Each descriptor passes the read, criteria and classic-link grammar and the whole registry
/// validates; its route and tool identifier resolve to it; its classic page is a class compiled on
/// this instance; it is the declared Tasks entry at its side-bar position, on <code>task</code> at
/// instance scope, with no refresh; On-demand declares the one row action Run (Story 7.5) and Upcoming
/// none; its pair set is the task schedule's; and the Tasks area covers it.</p>
/// <p>Mutation: drop <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.TaskUpcomingList</class> -&gt; its read-grammar and pair-set
/// assertions go red.</p>
Method TestBothDescriptorsValidateAsTheTasksEntriesTheyReplace()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the registry validates")
    Do $$$AssertEquals($Get(tProblem), "", "with no problem")
    For tCase = $ListBuild(..#ONDEMAND, "tasks/on-demand", "tasks.ondemand", 2, "%CSP.UI.Portal.TasksOnDemand", "run"), $ListBuild(..#UPCOMING, "tasks/upcoming", "tasks.upcoming", 3, "%CSP.UI.Portal.TasksUpcoming", "") {
        Set tClass = $List(tCase, 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tClass _ ": its read and table are the declared grammar")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", tClass _ ": and so are its criteria")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", tClass _ ": and it links out to nothing")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute($List(tCase, 2)), tClass, tClass _ ": the route resolves to it")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($List(tCase, 3)), tClass, tClass _ ": and so does its tool identifier")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), $List(tCase, 5), tClass _ ": the classic page is the vendor's own")
        Do $$$AssertTrue($IsObject(##class(%Dictionary.CompiledClass).%OpenId($List(tCase, 5))), tClass _ ": which compiles on this instance")
        Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "tasks", tClass _ ": in the Tasks area")
        Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), $List(tCase, 4), tClass _ ": at its side-bar position")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "EntityTypes")), "task", tClass _ ": on the task entity type")
        Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "instance", tClass _ ": at instance scope")
        Do $$$AssertEquals($ClassMethod(tClass, "Refreshes"), 0, tClass _ ": and it does not refresh")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "RowActionIds")), $List(tCase, 6), tClass _ ": its row actions are exactly '" _ $List(tCase, 6) _ "'")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId"), "", tClass _ ": and it declares no primary action")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Task"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", tClass _ ": its pair set is the task schedule's")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("tasks", $ClassMethod(tClass, "PrivilegePairs")), "", tClass _ ": and the Tasks area covers it")
    }
}

/// <p>Matrix "On-demand" -- the read answers its seven declared fields, and its rows are, by
/// <code>Id</code>, exactly the tasks <code>%SYS.Task:OnDemandTasksFilter("")</code> answers, the demo
/// task among them.</p>
/// <p>On this build the vendor's on-demand set is every task, so the fixed parameter itself is pinned
/// by <method>OcuPilot.Test.ScreenReadSource.TestAFixedQueryParameterReachesThePortWhateverTheCallerSends</method>.</p>
Method TestOnDemandReadsTheVendorsOnDemandTasks()
{
    Set tSC = ..Read("tasks.ondemand", "maxRows=1000", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), "[""Name"",""Namespace"",""Type"",""Description"",""Id"",""LastFinished"",""NextScheduled""]", "with its seven declared fields")
    Kill tIds
    Set tDemo = 0
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tIds(+tRow.Id) = ""
        If tRow.Name = ..#DEMOTASK Set tDemo = 1
    }
    Do $$$AssertEquals(..Joined(.tIds), ..OnDemandIds(), "its rows are the vendor's on-demand tasks, by Id")
    Do $$$AssertTrue(tDemo, "and the demo task is one of them")
}

/// <p>Matrix "Upcoming default" -- at <code>hoursOffset=24</code> the read answers its five declared
/// fields, its occurrences are the vendor query's for 24 hours at the cap plus one, in order, each
/// <code>Datetime</code> is <code>YYYY-MM-DD HH:MM:SS</code>, and each row's <code>Suspended</code>
/// is what <code>Task.CRUD</code>'s INFO answers for that task.</p>
/// <p>Mutation: issue <code>LIST</code> for every admin read in
/// <method>OcuPilot.Screen.Read.Execute</method> -&gt; the read answers task rows and the occurrence
/// and <code>Datetime</code> assertions go red.</p>
Method TestUpcomingAtTheDefaultHorizonIsTheVendorsOccurrences()
{
    Set tSC = ..Read("tasks.upcoming", "maxRows=1000&hoursOffset=24", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), "[""Id"",""Name"",""Namespace"",""Datetime"",""Suspended""]", "with its five declared fields")
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "the daily system tasks fall inside 24 hours: " _ tAnswer.rows.%Size())
    Do $$$AssertEquals(..Occurrences(tAnswer.rows), ..UpcomingOccurrences(24, "", "", 1001), "its occurrences are the vendor query's, in order")
    Set tBad = ""
    Kill tInfo
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$Match(tRow.Datetime, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$") Set tBad = "row " _ tIndex _ " Datetime " _ tRow.Datetime
        If tBad '= "" Quit
        If '$Data(tInfo(tRow.Id)) {
            Kill tQuery
            Set tQuery("id") = tRow.Id
            Set tInfoSC = ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "INFO", .tQuery, "", .tDetail, .tHttp, .tFault)
            Set tInfo(tRow.Id) = $Select($$$ISOK(tInfoSC) && $IsObject(tDetail): $Select(tDetail.Suspended: "true", 1: "false"), 1: "unread")
        }
        If tRow.%GetTypeOf("Suspended") '= "boolean" Set tBad = "row " _ tIndex _ " Suspended is " _ tRow.%GetTypeOf("Suspended")
        If (tBad = "") && ($Select(tRow.Suspended: "true", 1: "false") '= tInfo(tRow.Id)) Set tBad = "task " _ tRow.Id _ " Suspended reads " _ tRow.Suspended _ " where INFO answers " _ tInfo(tRow.Id)
        If tBad '= "" Quit
    }
    Do $$$AssertEquals(tBad, "", "every Datetime is YYYY-MM-DD HH:MM:SS and every Suspended is INFO's")
}

/// <p>Matrix "Until a date" and "Both sent" -- <code>toDatetime</code> at the end of tomorrow answers
/// the vendor query's occurrences to tomorrow at 86399; with <code>hoursOffset=1</code> sent beside a
/// date two days ahead, the vendor honours the hours, and neither is refused.</p>
/// <p>Mutation: seed only <code>hoursOffset</code> in <method>OcuPilot.Screen.Read.SeedCriteria</method>
/// -&gt; the date read answers the 24-hour default and the date assertion goes red.</p>
Method TestADateHorizonAndBothCriteriaReadAsTheVendorAnswers()
{
    Set tDay = +$Horolog + 1
    Set tTomorrow = $ZDate(tDay, 3)
    Set tSC = ..Read("tasks.upcoming", "maxRows=1000&toDatetime=" _ $ZConvert(tTomorrow _ " 23:59:59", "O", "URL"), .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the date request completes")
    Do $$$AssertEquals(tStatus, 200, "the date read answers")
    If (tStatus = 200) && $IsObject(tAnswer) {
        Do $$$AssertEquals(..Occurrences(tAnswer.rows), ..UpcomingOccurrences("", tDay, 86399, 1001), "its occurrences run to the end of tomorrow")
    }

    Set tSC = ..Read("tasks.upcoming", "maxRows=1000&hoursOffset=1&toDatetime=" _ $ZConvert($ZDate(tDay + 1, 3) _ " 23:59:59", "O", "URL"), .tStatus2, .tAnswer2)
    Do $$$AssertStatusOK(tSC, "the request with both completes")
    Do $$$AssertEquals(tStatus2, 200, "both sent is not refused")
    If (tStatus2 = 200) && $IsObject(tAnswer2) {
        Do $$$AssertEquals(..Occurrences(tAnswer2.rows), ..UpcomingOccurrences(1, "", "", 1001), "and the vendor honours the hours")
    }
}

/// <p>Matrix "Bad criterion" -- <code>hoursOffset=5</code> and <code>toDatetime=2026-09-20</code> are
/// each refused 400 <code>READ.CRITERION</code> with a reason naming the parameter.</p>
/// <p>Mutation: add <code>5</code> to the declared <code>hoursOffset</code> options -&gt; the first
/// refusal goes red.</p>
Method TestAnUndeclaredHorizonIsRefusedByName()
{
    For tCase = $ListBuild("hoursOffset", "5"), $ListBuild("toDatetime", "2026-09-20") {
        Set tParam = $List(tCase, 1)
        Set tSC = ..Read("tasks.upcoming", "maxRows=5&" _ tParam _ "=" _ $List(tCase, 2), .tStatus, .tAnswer)
        Do $$$AssertStatusOK(tSC, tParam _ ": the request completes")
        Do $$$AssertEquals(tStatus, 400, tParam _ ": refused 400")
        If '$IsObject(tAnswer) Continue
        Do $$$AssertEquals(tAnswer.code, "READ.CRITERION", tParam _ ": on the criterion code")
        Do $$$AssertTrue(tAnswer.reason [ tParam, tParam _ ": naming the parameter: " _ tAnswer.reason)
        Do $$$AssertEquals(tAnswer.%GetTypeOf("rows"), "unassigned", tParam _ ": with no rows")
    }
}

/// <p>Matrix "Cap" -- Upcoming at <code>hoursOffset=168&amp;maxRows=1</code>, and On-demand at
/// <code>maxRows=1</code>, each answer one row reported truncated.</p>
Method TestEachListIsCutAtACapOfOne()
{
    For tCase = $ListBuild("tasks.upcoming", "maxRows=1&hoursOffset=168"), $ListBuild("tasks.ondemand", "maxRows=1") {
        Set tTool = $List(tCase, 1)
        Set tSC = ..Read(tTool, $List(tCase, 2), .tStatus, .tAnswer)
        Do $$$AssertStatusOK(tSC, tTool _ ": the capped request completes")
        Do $$$AssertEquals(tStatus, 200, tTool _ ": and answers")
        If (tStatus '= 200) || '$IsObject(tAnswer) Continue
        Do $$$AssertEquals(tAnswer.rows.%Size(), 1, tTool _ ": one row at maxRows=1")
        Do $$$AssertEquals(tAnswer.truncated, 1, tTool _ ": reported truncated")
    }
}

/// <p>The Integration AC -- the read tool over each screen, at a context cap of two, answers only
/// <code>fields</code>, <code>rows</code> and <code>truncated</code>: the route's fields and the first
/// two of the route's rows in the declared default order, Upcoming read with <code>hoursOffset</code>
/// 24; and Upcoming's input schema offers <code>hoursOffset</code> as an enum of its six options.</p>
/// <p>Mutation: change the <code>hoursOffset</code> options on
/// <class>OcuPilot.Screen.Descriptor.TaskUpcomingList</class> only, with the mirror regenerated -&gt;
/// the enum assertion goes red.</p>
Method TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap()
{
    Set tSchema = ##class(OcuPilot.Screen.Tool.Read).InputSchema(..#UPCOMING)
    Do $$$AssertTrue($IsObject(tSchema), "the Upcoming tool has a schema")
    If $IsObject(tSchema) {
        Do $$$AssertEquals(tSchema.properties.hoursOffset.enum.%ToJSON(), "[""1"",""4"",""12"",""24"",""72"",""168""]", "offering hoursOffset as an enum of the six options")
    }
    For tCase = $ListBuild(..#ONDEMAND, "tasks.ondemand", ""), $ListBuild(..#UPCOMING, "tasks.upcoming", "24") {
        Set tDescriptor = $List(tCase, 1)
        Set tTool = $List(tCase, 2) _ ".read"
        Set tHours = $List(tCase, 3)
        Set tCap = 2
        Set tArgs = {}
        If tHours '= "" Do tArgs.%Set("hoursOffset", tHours)

        Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
        Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(tDescriptor, tArgs, tCap, .tView)
        Do ##class(OcuPilot.Kernel.Scope).Clear()
        Do $$$AssertStatusOK(tSC, tTool _ ": the tool reads")
        If $$$ISERR(tSC) || '$IsObject(tView) Continue

        Set tSC = ..Read($List(tCase, 2), "maxRows=1000" _ $Select(tHours = "": "", 1: "&hoursOffset=" _ tHours), .tStatus, .tRoute)
        Do $$$AssertEquals(tStatus, 200, tTool _ ": the route answers the same read")
        If (tStatus '= 200) || '$IsObject(tRoute) Continue
        Set tOrdered = ##class(OcuPilot.Screen.Read).ApplyView(tRoute.rows, $ClassMethod(tDescriptor, "Read"))
        Do $$$AssertTrue(tOrdered.%Size() > tCap, tTool _ ": the route has more rows than the cap: " _ tOrdered.%Size())
        Set tWanted = []
        For tJ = 0:1:(tCap - 1) Do tWanted.%Push(tOrdered.%Get(tJ))
        Do $$$AssertEquals(tView.fields.%ToJSON(), tRoute.fields.%ToJSON(), tTool _ ": the route's fields")
        Do $$$AssertEquals(tView.rows.%ToJSON(), tWanted.%ToJSON(), tTool _ ": the route's rows in default order, narrowed by the cap")
        Do $$$AssertEquals(tView.truncated, 1, tTool _ ": reporting the cut")
        Set tKeys = ""
        Set tIterator = tView.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
        }
        Do $$$AssertEquals(tKeys, "fields,rows,truncated,rowsAvailable", tTool _ ": and nothing else")
    }
}

}
