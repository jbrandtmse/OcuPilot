/// <p>Task history, per task and across tasks (Story 6.6): both declarations against the grammar,
/// the registry and the Tasks area's pair set; each read over the wire as the configured test
/// principal (<class>OcuPilot.Test.Http</class>) against the vendor's own
/// <code>%SYS.Task.History</code> queries -- every field a key of the live row, search, the
/// user-defined-only filter, a refused criterion, one task, an unknown task, no task id and the cap
/// -- <method>OcuPilot.Screen.Registry.RouteEntityType</method> over the three sub-resource
/// screens this epic has built, and the Integration AC.</p>
/// <p>Needs the API application installed in <code>HSCUSTOM</code>, <code>_SYSTEM</code>, and the
/// demo fixture (AD-25): the demo task's own install-time run is what gives this suite a failed run
/// to find. It waits for that row the way <class>OcuPilot.Test.Demo</class> waits for the demo
/// task's own suspension -- polling, up to a budget, re-reading fresh each time -- but creates
/// nothing of its own: no task, run or suspension. Both the test principal and the process running
/// this class need <code>%Admin_Task:USE</code> and <code>%DB_IRISSYS:READ</code>; the pair set's
/// denials are <class>OcuPilot.Test.WireSecurityRead</class>'s.</p>
Class OcuPilot.Test.TaskHistory Extends %UnitTest.TestCase
{

/// <p>The screen read route's prefix.</p>
Parameter READPATH = "/api/ocupilot/screens/";

/// <p>Task history (all tasks).</p>
Parameter HISTORY = "OcuPilot.Screen.Descriptor.TaskHistoryList";

/// <p>History (one task).</p>
Parameter TASKRUN = "OcuPilot.Screen.Descriptor.TaskRunList";

/// <p>Task schedule, whose composite id names the task <parameter>TASKRUN</parameter> is scoped
/// to.</p>
Parameter TASKSCHEDULE = "OcuPilot.Screen.Descriptor.TaskScheduleList";

/// <p>The Wallet list, the other parent-scoped screen's parent, for the
/// <method>TestRouteEntityTypeResolvesThroughTheParent</method> comparison.</p>
Parameter WALLET = "OcuPilot.Screen.Descriptor.WalletCollectionList";

/// <p>Secrets, the Wallet list's own sub-resource, for the same comparison.</p>
Parameter WALLETSECRET = "OcuPilot.Screen.Descriptor.WalletSecretList";

/// <p>The demo fixture's task.</p>
Parameter DEMOTASK = "OcuPilotDemo nightly purge";

/// <p>How long, in seconds, <method>DemoHistoryRow</method> waits for the demo task's
/// install-time run to land a history row before it fails, the same budget
/// <class>OcuPilot.Test.Demo</class>'s own suspend wait gives (rework iteration 5's evidence: the
/// run itself completes in well under a minute once nothing holds it back).</p>
Parameter WAITSECONDS As %Integer = 180;

/// <p>Seconds between the fresh re-reads <method>DemoHistoryRow</method> makes while it waits.</p>
Parameter POLLSECONDS As %Integer = 5;

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

/// <p>Request <var>pTool</var>'s read with the query string <var>pQuery</var> as the test
/// principal. <var>pAnswer</var> is the parsed body, or <code>""</code>.</p>
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

/// <p>The demo task's numeric <code>Id</code>, read from the live Task schedule list, or
/// <code>""</code> when it cannot be found.</p>
ClassMethod DemoTaskId() As %String
{
    Set tId = ""
    Try {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/tasks.schedule/read?maxRows=1000", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
        If $$$ISERR(tSC) || (tStatus '= 200) Quit
        Set tAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
        Set tIterator = tAnswer.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.Name = ..#DEMOTASK Set tId = tRow.Id
        }
    } Catch {
        Set tId = ""
    }
    Quit tId
}

/// <p>Poll <code>tasks.history</code> filtered to <code>OcuPilotDemo</code> until a row answers
/// <code>Status</code> non-zero (a failed run, <code>Result</code> carrying error text) or
/// <parameter name="WAITSECONDS"/> passes. Creates nothing: the demo fixture's own install-time
/// request of the task is what the container already asked for (AD-25); this only waits for the
/// Task Manager to have logged it, the way <class>OcuPilot.Test.Demo</class> waits for suspension.</p>
/// <p><var>pRows</var> is the last answer's rows (whatever it held, failed run present or not) so a
/// timeout still leaves a caller something to report against, and <var>pWaited</var> is how long
/// this call actually took.</p>
ClassMethod DemoHistoryRow(Output pRows As %DynamicArray, Output pWaited As %Numeric) As %Boolean
{
    Set pRows = []
    Set tFound = 0
    Set tBudget = ..#WAITSECONDS
    Set tPoll = ..#POLLSECONDS
    Set tStart = $ZHorolog
    For {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/tasks.history/read?maxRows=1000&search=OcuPilotDemo", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
        If $$$ISOK(tSC) && (tStatus = 200) {
            Set tAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
            If $IsObject(tAnswer) && $IsObject(tAnswer.rows) {
                Set pRows = tAnswer.rows
                Set tIterator = pRows.%GetIterator()
                While tIterator.%GetNext(.tIndex, .tRow) {
                    If +tRow.Status '= 0 Set tFound = 1
                }
            }
        }
        If tFound Quit
        If ($ZHorolog - tStart) >= tBudget Quit
        Hang tPoll
    }
    Set pWaited = $ZHorolog - tStart
    Quit tFound
}

/// <p>Each descriptor passes the read, criteria and classic-link grammar and the whole registry
/// validates; its route and tool identifier resolve to it; its classic page is a class compiled on
/// this instance; it is the declared Tasks entry at its side-bar position, on
/// <code>task-history-entry</code> at instance scope, with no action and no refresh; its pair set is
/// the task schedule's; and the Tasks area covers it.</p>
/// <p>Mutation: drop <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.TaskHistoryList</class> or
/// <class>OcuPilot.Screen.Descriptor.TaskRunList</class> -&gt; the pair-set assertion for that
/// descriptor goes red.</p>
Method TestBothDescriptorsValidateAsTheTasksEntriesTheyReplace()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the registry validates")
    Do $$$AssertEquals($Get(tProblem), "", "with no problem")
    For tCase = $ListBuild(..#HISTORY, "tasks/history", "tasks.history", 4, "%CSP.UI.Portal.TaskHistory"), $ListBuild(..#TASKRUN, "tasks/schedule/history", "tasks.taskhistory", 0, "%CSP.UI.Portal.TaskHistoryId") {
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
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "EntityTypes")), "task-history-entry", tClass _ ": on the task-history-entry entity type")
        Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "instance", tClass _ ": at instance scope")
        Do $$$AssertEquals($ClassMethod(tClass, "Refreshes"), 0, tClass _ ": and it does not refresh")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")) + ($ClassMethod(tClass, "PrimaryActionId") '= ""), 0, tClass _ ": it declares no action")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Task"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", tClass _ ": its pair set is the task schedule's")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("tasks", $ClassMethod(tClass, "PrivilegePairs")), "", tClass _ ": and the Tasks area covers it")
    }
    Do $$$AssertEquals($ClassMethod(..#TASKRUN, "ParentScope"), "tasks/schedule", "History declares its parent")
    Do $$$AssertEquals($ClassMethod(..#TASKSCHEDULE, "IdKind"), "composite", "and Task schedule's own id is composite over the vendor's numeric Id")
    Do $$$AssertEquals($ClassMethod(..#TASKSCHEDULE, "IdParts"), $ListBuild("Id"), "one part, Id")
}

/// <p>DW-1020 -- <method>OcuPilot.Screen.Registry.RouteEntityType</method> answers the parent's
/// primary entity type for a sub-resource screen, resolved through <code>parentScope</code>, while
/// each screen's own rows keep their own type: <code>task</code> for History (one task), scoped
/// under Task schedule, and <code>wallet-collection</code> for Secrets, scoped under the Wallet
/// list -- both resolved the same way, over the two sub-resource screens the epic has built. A
/// screen with no parent, Task history (all tasks), answers its own primary type.</p>
/// <p>Mutation: make <method>RouteEntityType</method> return the child's own
/// <code>PrimaryEntityType</code> unconditionally -&gt; both parented cases go red, reading
/// <code>task-history-entry</code> and <code>wallet-secret</code>, while the unparented case stays
/// green by coincidence.</p>
Method TestRouteEntityTypeResolvesThroughTheParent()
{
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RouteEntityType(..#TASKRUN), "task", "History (one task) names the task its route id identifies")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RouteEntityType(..#WALLETSECRET), "wallet-collection", "and Secrets names the wallet collection its route id identifies")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RouteEntityType(..#HISTORY), "task-history-entry", "Task history (all tasks) declares no parent, so its route id names its own primary type")
    Do $$$AssertEquals($ClassMethod(..#TASKRUN, "PrimaryEntityType"), "task-history-entry", "its rows keep their own type regardless")
    Do $$$AssertEquals($ClassMethod(..#WALLETSECRET, "PrimaryEntityType"), "wallet-secret", "and so do the Secrets list's")
}

/// <p>Matrix "All tasks" -- the read answers the table's thirteen declared fields, each a key of the
/// live row, and its rows are, by <code>(TaskId, Status)</code>, the vendor's own
/// <code>DescendingTaskHistoryFilter("", 0)</code> rows in the same order, up to the cap.</p>
Method TestAllTasksReadsTheVendorsHistory()
{
    Set tSC = ..Read("tasks.history", "maxRows=1000", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), "[""LastStart"",""Completed"",""Name"",""Status"",""Result"",""TaskId"",""Namespace"",""Routine"",""Pid"",""ErrDate"",""ErrNumber"",""Username"",""LogDatetime""]", "the table's thirteen declared fields, in order")
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "the instance already carries run history: " _ tAnswer.rows.%Size())
    Set tField = ""
    Set tIterator = tAnswer.rows.%Get(0).%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) { Set tField = tField _ $Select(tField = "": "", 1: ",") _ tKey }
    Do $$$AssertEquals($ListToString($ListFromString(tField)), $ListToString($ListFromString("LastStart,Completed,Name,Status,Result,TaskId,Namespace,Routine,Pid,ErrDate,ErrNumber,Username,LogDatetime")), "every declared field is a key of the live row, in declared order")

    Set tOrigNS = $NAMESPACE
    Set tVendor = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("%SYS.Task.History:DescendingTaskHistoryFilter")
        $$$ThrowOnError(tRS.Execute("", 0))
        Set tI = 0
        While tRS.Next() && (tI < 1000) {
            Set tVendor = tVendor _ $ListBuild((+tRS.GetData(6)) _ "@" _ tRS.GetData(4))
            Set tI = tI + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do $$$AssertTrue(0, "the vendor query ran: " _ ex.DisplayString())
        Quit
    }
    Set tRoute = ""
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tIndex >= $ListLength(tVendor) Quit
        Set tRoute = tRoute _ $ListBuild((+tRow.TaskId) _ "@" _ tRow.Status)
    }
    Do $$$AssertEquals($ListToString(tRoute), $ListToString($List(tVendor, 1, $ListLength(tRoute))), "each row's (TaskId, Status) matches the vendor's own, in order")
}

/// <p>Matrix "Search" -- <code>search=OcuPilotDemo</code> is sent to the vendor as <code>filter</code>
/// (Story 6.6's <code>vendorParam</code>), every rendered row's joined text contains it
/// case-insensitively, and the demo task's own failed install-time run is present, its
/// <code>Result</code> carrying error text rather than "Success".</p>
Method TestSearchReachesTheVendorAsFilterAndFindsTheDemoTasksFailedRun()
{
    Do $$$AssertTrue(..DemoHistoryRow(.tRows, .tWaited), "the demo task's install-time run landed a history row within " _ ..#WAITSECONDS _ "s (waited " _ tWaited _ "s)")
    Do $$$AssertTrue(tRows.%Size() > 0, "and the search-filtered read answers at least one row")
    If 'tRows.%Size() Quit

    Set tDemo = 0
    Set tDemoFailed = 0
    Set tBad = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tJoined = $ZConvert(tRow.LastStart _ tRow.Completed _ tRow.Name _ tRow.Status _ tRow.Result _ tRow.TaskId _ tRow.Namespace _ tRow.Routine _ tRow.Pid _ tRow.ErrDate _ tRow.ErrNumber _ tRow.Username _ tRow.LogDatetime, "U")
        If tJoined '[ "OCUPILOTDEMO" Set tBad = "row " _ tIndex _ " does not contain OcuPilotDemo: " _ tRow.%ToJSON()
        If tBad '= "" Quit
        If tRow.Name = ..#DEMOTASK {
            Set tDemo = 1
            If (tRow.Result '= "") && (tRow.Result '= "Success") Set tDemoFailed = 1
        }
    }
    Do $$$AssertEquals(tBad, "", "every row's joined text contains the search text")
    Do $$$AssertTrue(tDemo, "and the demo task's own run is among the rows")
    Do $$$AssertTrue(tDemoFailed, "with a failed run whose Result carries error text rather than Success")
}

/// <p>Matrix "User-defined only" -- <code>userOnly=1</code> answers the same number of rows, under
/// the cap, as the vendor's own <code>DescendingTaskHistoryFilter("", 1)</code>.</p>
Method TestUserOnlyMatchesTheVendorsUserOnlyQuery()
{
    Set tSC = ..Read("tasks.history", "maxRows=1000&userOnly=1", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit

    Set tOrigNS = $NAMESPACE
    Set tVendorCount = -1
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("%SYS.Task.History:DescendingTaskHistoryFilter")
        $$$ThrowOnError(tRS.Execute("", 1))
        Set tVendorCount = 0
        While tRS.Next() { Set tVendorCount = tVendorCount + 1 }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do $$$AssertTrue(0, "the vendor query ran: " _ ex.DisplayString())
        Quit
    }
    Do $$$AssertEquals(tAnswer.rows.%Size(), $Select(tVendorCount > 1000: 1000, 1: tVendorCount), "the row count matches the vendor's own UserOnly query, under the cap")
}

/// <p>Matrix "Bad criterion" -- <code>userOnly=2</code> and a 101-character <code>search</code> are
/// each refused 400 <code>READ.CRITERION</code> naming the parameter, with no rows in the
/// refusal.</p>
Method TestBadCriteriaAreRefusedByNameBeforeThePort()
{
    Set tLong = ""
    For tI = 1:1:101 { Set tLong = tLong _ "a" }
    For tCase = $ListBuild("userOnly", "2"), $ListBuild("search", tLong) {
        Set tParam = $List(tCase, 1)
        Set tSC = ..Read("tasks.history", "maxRows=5&" _ tParam _ "=" _ $List(tCase, 2), .tStatus, .tAnswer)
        Do $$$AssertStatusOK(tSC, tParam _ ": the request completes")
        Do $$$AssertEquals(tStatus, 400, tParam _ ": refused 400")
        If '$IsObject(tAnswer) Continue
        Do $$$AssertEquals(tAnswer.code, "READ.CRITERION", tParam _ ": on the criterion code")
        Do $$$AssertTrue(tAnswer.reason [ tParam, tParam _ ": naming the parameter: " _ tAnswer.reason)
        Do $$$AssertEquals(tAnswer.%GetTypeOf("rows"), "unassigned", tParam _ ": with no rows")
    }
}

/// <p>Matrix "One task" -- <code>tasks.taskhistory?taskId=&lt;demo Id&gt;</code> answers only that
/// task's runs, every row's <code>TaskId</code> the demo task's own, its failed run's
/// <code>Result</code> carrying its error text, and <code>Username</code> present.</p>
Method TestOneTaskReadsOnlyTheDemoTasksOwnRuns()
{
    Do $$$AssertTrue(..DemoHistoryRow(.tIgnored, .tWaited), "the demo task's run has landed by the time this test asks for it by id")
    Set tId = ..DemoTaskId()
    Do $$$AssertNotEquals(tId, "", "the demo task's numeric Id is found on the live schedule")
    If tId = "" Quit

    Set tSC = ..Read("tasks.taskhistory", "maxRows=1000&taskId=" _ tId, .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "the demo task carries at least one run")
    Set tBad = ""
    Set tFailed = 0
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (+tRow.TaskId) '= tId Set tBad = "row " _ tIndex _ " TaskId " _ tRow.TaskId _ " is not " _ tId
        If tBad '= "" Quit
        If tRow.Username = "" Set tBad = "row " _ tIndex _ " carries no Username"
        If tBad '= "" Quit
        If (tRow.Result '= "") && (tRow.Result '= "Success") Set tFailed = 1
    }
    Do $$$AssertEquals(tBad, "", "every row names the demo task and carries a user")
    Do $$$AssertTrue(tFailed, "the demo task's failed run, its Result carrying error text, is among its rows")
}

/// <p>Matrix "Unknown task" -- <code>taskId=999999</code> and <code>taskId=abc</code> each answer
/// 200 with no rows, so the per-task empty state renders rather than a refusal.</p>
Method TestAnUnknownTaskIdIsNotARefusal()
{
    For tId = "999999", "abc" {
        Set tSC = ..Read("tasks.taskhistory", "maxRows=5&taskId=" _ tId, .tStatus, .tAnswer)
        Do $$$AssertStatusOK(tSC, tId _ ": the request completes")
        Do $$$AssertEquals(tStatus, 200, tId _ ": 200, not a refusal")
        If (tStatus '= 200) || '$IsObject(tAnswer) Continue
        Do $$$AssertEquals(tAnswer.rows.%Size(), 0, tId _ ": no rows")
    }
}

/// <p>Matrix "No task id" -- <code>tasks.taskhistory</code> with no <code>taskId</code> answers the
/// same rows, by count, as the unscoped Task history read (accepted vendor behaviour).</p>
Method TestNoTaskIdReadsAsAllTasks()
{
    Set tSC = ..Read("tasks.taskhistory", "maxRows=1000", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    Set tSC2 = ..Read("tasks.history", "maxRows=1000", .tStatus2, .tAnswer2)
    Do $$$AssertStatusOK(tSC2, "the all-tasks request completes")
    Do $$$AssertEquals(tStatus2, 200, "and answers")
    If (tStatus '= 200) || (tStatus2 '= 200) || '$IsObject(tAnswer) || '$IsObject(tAnswer2) Quit
    Do $$$AssertEquals(tAnswer.rows.%Size(), tAnswer2.rows.%Size(), "a missing taskId reads the same row count as the unscoped read")
}

/// <p>Matrix "Cap" -- both routes at <code>maxRows=1</code> answer one row reported truncated.</p>
Method TestEachRouteIsCutAtACapOfOne()
{
    For tTool = "tasks.history", "tasks.taskhistory" {
        Set tSC = ..Read(tTool, "maxRows=1", .tStatus, .tAnswer)
        Do $$$AssertStatusOK(tSC, tTool _ ": the capped request completes")
        Do $$$AssertEquals(tStatus, 200, tTool _ ": and answers")
        If (tStatus '= 200) || '$IsObject(tAnswer) Continue
        Do $$$AssertEquals(tAnswer.rows.%Size(), 1, tTool _ ": one row at maxRows=1")
        Do $$$AssertEquals(tAnswer.truncated, 1, tTool _ ": reported truncated")
    }
}

/// <p>The Integration AC -- the read tool over each screen, at a context cap of two, answers only
/// <code>fields</code>, <code>rows</code> and <code>truncated</code>: the route's fields and the
/// first two of the route's rows in the declared default order, Task history read with
/// <code>search</code> "OcuPilotDemo" and History (one task) with the demo <code>taskId</code>; and
/// the input schema offers <code>search</code>, <code>userOnly</code> (an enum of
/// <code>["1"]</code>) and <code>taskId</code> as criteria, while <code>filter</code> stays the
/// tool's own view argument.</p>
/// <p>Mutation: change the <code>userOnly</code> options on
/// <class>OcuPilot.Screen.Descriptor.TaskHistoryList</class> only, with the mirror regenerated -&gt;
/// the enum assertion goes red.</p>
Method TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap()
{
    Set tSchema = ##class(OcuPilot.Screen.Tool.Read).InputSchema(..#HISTORY)
    Do $$$AssertTrue($IsObject(tSchema), "Task history's tool has a schema")
    If $IsObject(tSchema) {
        Do $$$AssertTrue(tSchema.properties.%IsDefined("search"), "offering search")
        Do $$$AssertTrue(tSchema.properties.%IsDefined("userOnly"), "and userOnly")
        Do $$$AssertEquals(tSchema.properties.userOnly.enum.%ToJSON(), "[""1""]", "userOnly as an enum of its one option")
        Do $$$AssertTrue($IsObject(tSchema.properties.filter), "filter is still the tool's own view argument, never the criterion's")
    }
    Set tRunSchema = ##class(OcuPilot.Screen.Tool.Read).InputSchema(..#TASKRUN)
    Do $$$AssertTrue($IsObject(tRunSchema), "History (one task)'s tool has a schema")
    If $IsObject(tRunSchema) {
        Do $$$AssertTrue(tRunSchema.properties.%IsDefined("taskId"), "offering taskId")
    }

    Do $$$AssertTrue(..DemoHistoryRow(.tIgnored, .tWaited), "the demo task's run has landed before the tool is asked for it")
    Set tId = ..DemoTaskId()
    Do $$$AssertNotEquals(tId, "", "the demo task's numeric Id is found on the live schedule")
    For tCase = $ListBuild(..#HISTORY, "tasks.history", "search", "OcuPilotDemo"), $ListBuild(..#TASKRUN, "tasks.taskhistory", "taskId", tId) {
        Set tDescriptor = $List(tCase, 1)
        Set tTool = $List(tCase, 2) _ ".read"
        Set tCriterion = $List(tCase, 3)
        Set tValue = $List(tCase, 4)
        If tValue = "" Continue
        Set tCap = 2
        Set tArgs = {}
        Do tArgs.%Set(tCriterion, tValue, "string")

        Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
        Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(tDescriptor, tArgs, tCap, .tView)
        Do ##class(OcuPilot.Kernel.Scope).Clear()
        Do $$$AssertStatusOK(tSC, tTool _ ": the tool reads")
        If $$$ISERR(tSC) || '$IsObject(tView) Continue
        Do $$$AssertTrue(tView.rows.%Size() > 0, tTool _ ": and answers at least one of the demo task's rows")

        Set tSC = ..Read($List(tCase, 2), "maxRows=1000&" _ tCriterion _ "=" _ tValue, .tStatus, .tRoute)
        Do $$$AssertEquals(tStatus, 200, tTool _ ": the route answers the same read")
        If (tStatus '= 200) || '$IsObject(tRoute) Continue
        Set tOrdered = ##class(OcuPilot.Screen.Read).ApplyView(tRoute.rows, $ClassMethod(tDescriptor, "Read"))
        Set tWanted = []
        Set tWantedCount = $Select(tOrdered.%Size() < tCap: tOrdered.%Size(), 1: tCap)
        For tJ = 0:1:(tWantedCount - 1) Do tWanted.%Push(tOrdered.%Get(tJ))
        Do $$$AssertEquals(tView.fields.%ToJSON(), tRoute.fields.%ToJSON(), tTool _ ": the route's fields")
        Do $$$AssertEquals(tView.rows.%ToJSON(), tWanted.%ToJSON(), tTool _ ": the route's rows in default order, narrowed by the cap")
        Set tKeys = ""
        Set tIterator = tView.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue2) {
            Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
        }
        Do $$$AssertEquals(tKeys, "fields,rows,truncated,rowsAvailable", tTool _ ": and nothing else")
    }
}

}
