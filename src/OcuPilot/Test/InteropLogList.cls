/// <p>Pins Story 24.17 Batch 2's reads (AD-5, AD-29, AD-36, AD-62): the Business rule log and the Business process log, each newest first, through the port, the screen's read route and the
/// agent's read tool, which answer the same rows; the <code>errors</code> and <code>completed</code> criteria; both lists' caps and one over; the state read's count; and how both screens are declared.
/// The probes are <code>Ens_Rule.Log</code> rows and <class>EnsLib.MsgRouter.RoutingEngine</class> business processes in <code>USER</code>, which this class asserts on by their marker.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropLogPurgeCase</class> needs, and the SQL SELECT privilege the test account holds as an administrator.</p>
Class OcuPilot.Test.InteropLogList Extends OcuPilot.Test.InteropLogPurgeCase
{

/// <p>The ids of the probes among <var>pRows</var> of the log <var>pKind</var> -- the rows whose rule name or configuration name is the marker -- comma-separated in the order they come.</p>
ClassMethod ProbeIds(pKind As %String, pRows) As %String
{
    Set tText = ""
    If '$IsObject($Get(pRows)) Quit tText
    Set tMarker = $Parameter(..#FIXTURE, "MARKER")
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Select(pKind = "rule": tRow.%Get("RuleName"), 1: tRow.%Get("ConfigName")) '= tMarker Continue
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.%Get("ID")
    }
    Quit tText
}

/// <p>The screen of the log <var>pKind</var> is declared as the plan places it: in the Interoperability area at its side bar position, with Purge as its one row action, over the classic page's own
/// resource, naming its entity type and classic page, and with the criterion the read takes.</p>
Method CheckDeclared(pKind As %String)
{
    Set tExpected("rule") = "interoperability/rule-log|23|interop-rule-log|interop.rulelog|EnsPortal.RuleLog|errors"
    Set tExpected("process") = "interoperability/process-log|24|interop-process-log|interop.processlog|EnsPortal.BPInstances|completed"
    Set tSC = $ClassMethod(..Spec(pKind, "descriptor"), "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, pKind _ ": the screen declares JSON")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.toolIdentifier _ "|" _ tDeclaration.classicPage _ "|" _ tDeclaration.read.criteria.fields.%Get(0).param, tExpected(pKind), pKind _ ": its route, place, entity type, tool identifier, classic page and criterion")
    Do $$$AssertEquals(tDeclaration.archetype _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.primaryAction.id _ "|" _ tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.rowActions.%Get(0).id, "list|namespace||1|purge", pKind _ ": a namespace list whose one action is the row action Purge")
    Set tPairs = "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""" _ $Piece(..Spec(pKind, "pair"), ":", 1) _ """,""permission"":""" _ $Piece(..Spec(pKind, "pair"), ":", 2) _ """}]"
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), tPairs, pKind _ ": its pairs are the classic page's")
}

/// <p>The Business rule log screen is declared as the plan places it, at side bar 23 (<method>CheckDeclared</method>).</p>
/// <p>Mutation (Rule 19): change the Business rule log's <code>sideBarPosition</code> to 25 -- this goes red.</p>
Method TestTheRuleLogScreenIsDeclaredAsThePlanPlacesIt()
{
    Do ..CheckDeclared("rule")
}

/// <p>The Business process log screen is declared as the plan places it, at side bar 24 (<method>CheckDeclared</method>).</p>
/// <p>Mutation (Rule 19): change the Business process log's <code>sideBarPosition</code> to 25 -- this goes red.</p>
Method TestTheBusinessProcessLogScreenIsDeclaredAsThePlanPlacesIt()
{
    Do ..CheckDeclared("process")
}

/// <p>AC1: each list answers every probe, newest first, with the columns the screen declares and the namespace, and its criterion narrows it: <code>errors=yes</code> and <code>errors=no</code> answer the
/// entries marked as an error and the others, <code>completed=yes</code> and <code>completed=no</code> the completed business processes and the running one; another value of a criterion is refused by
/// name.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListLog</method> ignore the criterion -- this goes red.</p>
Method TestEachListAnswersItsProbesNewestFirstAndTheCriterionNarrowsIt()
{
    Set tOldError = ..Probe("rule", ..#SOURCE, 7300, 1)
    Set tOldPlain = ..Probe("rule", ..#SOURCE, 7300, 0)
    Set tNewError = ..Probe("rule", ..#SOURCE, 1, 1)
    Do $$$AssertTrue((tOldError > 0) && (tOldPlain > tOldError) && (tNewError > tOldPlain), "three rule log probes are stored under rising ids")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("rule", "LIST", .tRules, .tFault, .tQuery), "200 ", "the rule log answers 200")
    Do $$$AssertEquals(..ProbeIds("rule", tRules), tNewError _ "," _ tOldPlain _ "," _ tOldError, "every rule log probe, newest first")
    Set tRow = tRules.%Get(0)
    Do $$$AssertEquals(tRow.IsError _ "|" _ tRow.RuleName _ "|" _ tRow.ConfigName _ "|" _ tRow.ReturnValue _ "|" _ tRow.Reason _ "|" _ tRow.Namespace, "1|OcuProbe2417|OcuProbe2417Host|probe value|probe reason|" _ ..#SOURCE, "a row carries its error flag, rule, source, return value, reason and namespace")
    Do $$$AssertTrue((tRow.TimeExecuted '= "") && (tRow.SessionId = 7), "and its time and session")
    Kill tQuery
    Set tQuery("errors") = "yes"
    Do ..Verdict("rule", "LIST", .tYes, .tFault, .tQuery)
    Do $$$AssertEquals(..ProbeIds("rule", tYes), tNewError _ "," _ tOldError, "errors=yes lists the entries marked as an error only")
    Kill tQuery
    Set tQuery("errors") = "no"
    Do ..Verdict("rule", "LIST", .tNo, .tFault, .tQuery)
    Do $$$AssertEquals(..ProbeIds("rule", tNo), tOldPlain, "errors=no lists the others")
    Kill tQuery
    Set tQuery("errors") = "maybe"
    Do $$$AssertEquals(..Verdict("rule", "LIST", .tBad, .tFault, .tQuery), "400 PORT.VALIDATION", "another value of the criterion is refused by name")
    Set tOldDone = ..Probe("process", ..#SOURCE, 7300, 1)
    Set tOldRunning = ..Probe("process", ..#SOURCE, 7300, 0)
    Set tNewDone = ..Probe("process", ..#SOURCE, 1, 1)
    Do $$$AssertTrue((tOldDone > 0) && (tOldRunning > tOldDone) && (tNewDone > tOldRunning), "three business process probes are stored under rising ids")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("process", "LIST", .tProcesses, .tFault, .tQuery), "200 ", "the business process log answers 200")
    Do $$$AssertEquals(..ProbeIds("process", tProcesses), tNewDone _ "," _ tOldRunning _ "," _ tOldDone, "every business process probe, newest first")
    Set tProcessRow = tProcesses.%Get(1)
    Do $$$AssertEquals(tProcessRow.IsCompleted _ "|" _ tProcessRow.ConfigName _ "|" _ tProcessRow.TimeCompleted _ "|" _ tProcessRow.Namespace, "0|OcuProbe2417||" _ ..#SOURCE, "a running business process has no completion time and reads not completed")
    Kill tQuery
    Set tQuery("completed") = "yes"
    Do ..Verdict("process", "LIST", .tDone, .tFault, .tQuery)
    Do $$$AssertEquals(..ProbeIds("process", tDone), tNewDone _ "," _ tOldDone, "completed=yes lists the completed ones")
    Kill tQuery
    Set tQuery("completed") = "no"
    Do ..Verdict("process", "LIST", .tRunning, .tFault, .tQuery)
    Do $$$AssertEquals(..ProbeIds("process", tRunning), tOldRunning, "completed=no lists the one still running")
    Kill tQuery
    Set tQuery("completed") = "maybe"
    Do $$$AssertEquals(..Verdict("process", "LIST", .tBad2, .tFault, .tQuery), "400 PORT.VALIDATION", "another value of that criterion is refused by name")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RuleCount", ..#OTHER, 1) _ "|" _ $ClassMethod(..#FIXTURE, "ProcessCount", ..#OTHER, 1), "0|0", "HSCUSTOM holds no probe, and the lists of USER never read it")
}

/// <p>AC1: the screen's read route and the agent's read tool answer the rows the port answers, for each list and its criterion, in the fields each screen declares.</p>
/// <p>Mutation (Rule 19): rename the <code>errors</code> criterion in <class>OcuPilot.Screen.Descriptor.InteropRuleLogList</class> -- the route and the tool answer every row and this goes red.</p>
Method TestTheReadRouteAndTheReadToolAnswerTheSameRows()
{
    Set tEntries = $ListBuild($ListBuild("rule", "", "", "ID,RuleName,IsError,ConfigName"), $ListBuild("rule", "errors", "yes", "ID,RuleName,IsError,ConfigName"), $ListBuild("process", "", "", "ID,ConfigName,IsCompleted"), $ListBuild("process", "completed", "no", "ID,ConfigName,IsCompleted"))
    Do ..Probe("rule", ..#SOURCE, 7300, 1)
    Do ..Probe("rule", ..#SOURCE, 1, 0)
    Do ..Probe("process", ..#SOURCE, 7300, 1)
    Do ..Probe("process", ..#SOURCE, 7300, 0)
    Do ##class(OcuPilot.Kernel.Scope).Set(..#SOURCE)
    For tI = 1:1:$ListLength(tEntries) {
        Set tEntry = $List(tEntries, tI)
        Set tKind = $List(tEntry, 1)
        Set tClass = ..Spec(tKind, "descriptor")
        Kill tQuery, tCriteria
        Set tArgs = {}
        If $List(tEntry, 2) '= "" {
            Set tQuery($List(tEntry, 2)) = $List(tEntry, 3)
            Set tCriteria($List(tEntry, 2)) = $List(tEntry, 3)
            Do tArgs.%Set($List(tEntry, 2), $List(tEntry, 3), "string")
        }
        Do ..Verdict(tKind, "LIST", .tPortRows, .tPortFault, .tQuery)
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(tClass, 1000, .tAnswer, .tRouteHttp, .tRouteFault, .tCriteria)
        Set tToolName = $ClassMethod(tClass, "ToolIdentifier") _ ".read"
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tToolName, .tTool)
        Do $$$AssertTrue($IsObject($Get(tTool)), tToolName _ " is a registered read tool")
        Kill tResult
        Set tToolHttp = 0
        If $IsObject($Get(tTool)) Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, tArgs, 1000, .tResult, .tToolHttp, .tToolFault)
        Do $$$AssertEquals(tRouteHttp _ "|" _ tToolHttp, "200|200", tI _ ": the route and the tool answer")
        If '$IsObject($Get(tPortRows)) || '$IsObject($Get(tAnswer)) || '$IsObject($Get(tResult)) Continue
        Do $$$AssertTrue(tPortRows.%Size() > 0, tI _ ": the port answers rows")
        Set tCanon = ##class(OcuPilot.Test.InteropAlertList).Canon(tPortRows, $List(tEntry, 4))
        Do $$$AssertEquals(##class(OcuPilot.Test.InteropAlertList).Canon(tAnswer.rows, $List(tEntry, 4)), tCanon, tI _ ": the route's rows are the port's")
        Do $$$AssertEquals(##class(OcuPilot.Test.InteropAlertList).Canon(tResult.rows, $List(tEntry, 4)), tCanon, tI _ ": and so are the tool's")
    }
}

/// <p>AC1: both lists are cut at a named limit when the caller names no cap, and truncation is the caller's to read from the row it asks for beyond its own cap: at the limit all rows come, one over
/// the limit answers the limit, a caller that asks for one row beyond a cap at the limit is answered it, and one that asks for fewer gets fewer. The shipped limits are 2,000 each, measured.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.AlertCap</method> answer no more than <var>pLimit</var> -- the row asked for beyond the cap is lost and this goes red.</p>
Method TestBothListsStopAtTheirNamedLimit()
{
    Set tSeam = ..#SEAM
    Do $$$AssertEquals($Parameter(..#PORT, "RULELOGMAX") _ "|" _ $Parameter(..#PORT, "PROCESSLOGMAX"), "2000|2000", "the shipped limits are 2,000 each")
    Do $$$AssertEquals($Parameter(tSeam, "RULELOGMAX") _ "|" _ $Parameter(tSeam, "PROCESSLOGMAX"), "3|3", "the seam lowers both to three")
    For tKind = "rule", "process" {
        For tI = 1:1:3 {
            Set tIds(tI) = ..Probe(tKind, ..#SOURCE, 7300, 1)
        }
        Kill tQuery
        Do ..Verdict(tKind, "LIST", .tAt, .tFault, .tQuery, ..#SOURCE, tSeam)
        Do $$$AssertEquals(..ProbeIds(tKind, tAt), tIds(3) _ "," _ tIds(2) _ "," _ tIds(1), tKind _ ": three at the limit, all three, newest first")
        Set tIds(4) = ..Probe(tKind, ..#SOURCE, 7300, 1)
        Kill tQuery
        Do ..Verdict(tKind, "LIST", .tOver, .tFault, .tQuery, ..#SOURCE, tSeam)
        Do $$$AssertEquals(..ProbeIds(tKind, tOver), tIds(4) _ "," _ tIds(3) _ "," _ tIds(2), tKind _ ": four, one over, the limit, the newest three")
        Kill tQuery
        Set tQuery("maxRows") = 4
        Do ..Verdict(tKind, "LIST", .tAsked, .tFault, .tQuery, ..#SOURCE, tSeam)
        Do $$$AssertEquals(..Size(tAsked), 4, tKind _ ": a caller whose cap is the limit asks for one row more and is answered it, so it reads the truncation")
        Kill tQuery
        Set tQuery("maxRows") = 2
        Do ..Verdict(tKind, "LIST", .tFewer, .tFault, .tQuery, ..#SOURCE, tSeam)
        Do $$$AssertEquals(..Size(tFewer), 2, tKind _ ": and one that asks for fewer gets fewer")
        Do $ClassMethod(..#FIXTURE, "DropProbes")
    }
}

/// <p>AC1: the state read answers <code>{Count, DaysToKeep, Namespace}</code>, <code>Count</code> the vendor's own count of the log's records, <code>DaysToKeep</code> empty, in the namespace the call
/// names, and reading it writes nothing: the count is the same before and after, and a probe added raises it by one.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ReadLogState</method> count the other log -- the process leg goes red.</p>
Method TestTheStateReadCountsTheLogInTheNamespaceItNames()
{
    For tKind = "rule", "process" {
        Kill tQuery
        Do $$$AssertEquals(..Verdict(tKind, "state", .tBefore, .tFault, .tQuery), "200 ", tKind _ ": the state read answers 200")
        Set tBase = tBefore.Count
        Do $$$AssertEquals(tBefore.Count, ..Rows(tKind), tKind _ ": its count is the log's rows")
        Do $$$AssertEquals(tBefore.DaysToKeep _ "|" _ tBefore.Namespace, "|" _ ..#SOURCE, tKind _ ": it carries no days and names the namespace")
        Do ..Probe(tKind, ..#SOURCE, 7300, 1)
        Kill tQuery
        Do ..Verdict(tKind, "state", .tAfter, .tFault, .tQuery)
        Do $$$AssertEquals(tAfter.Count, tBase + 1, tKind _ ": a probe raises the count by one")
        Kill tQuery
        Do ..Verdict(tKind, "state", .tOther, .tFault, .tQuery, ..#OTHER)
        Do $$$AssertEquals(tOther.Namespace _ "|" _ (tOther.Count = ..Rows(tKind, ..#OTHER)), ..#OTHER _ "|1", tKind _ ": the other namespace's read counts its own log")
        Do $ClassMethod(..#FIXTURE, "DropProbes")
    }
}

}
