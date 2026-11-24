/// <p>Pins Story 24.17 Batch 1's reads (AD-5, AD-29, AD-36, AD-62): the Managed alerts list and the Alert history of one alert, each newest first, through the port, the screen's read route
/// and the agent's read tool, which answer the same rows; the <code>open</code> criterion; both lists' caps and one over; the owner choices; and that a read writes nothing. The probes are
/// <code>Ens.Alerting.ManagedAlert</code> rows in <code>USER</code>, saved and updated through the vendor's own methods.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropAlertCase</class> needs, and <code>%Ens_AlertAdministration</code> held by the test account, which it holds as an
/// administrator.</p>
Class OcuPilot.Test.InteropAlertList Extends OcuPilot.Test.InteropAlertCase
{

/// <p>AC1: the list answers every probe, open, closed, owned and unassigned, newest first, with the columns the screen declares and the namespace, and <code>open=yes</code> and
/// <code>open=no</code> answer the open ones and the closed ones.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListAlerts</method> ignore the <code>open</code> criterion -- this goes red.</p>
Method TestTheListAnswersEveryProbeNewestFirstAndTheCriterionNarrowsIt()
{
    Set tFx = ..#FIXTURE
    Set tOpen = $ClassMethod(tFx, "Probe", ..#SOURCE, "", 1, 0, "open and unassigned")
    Set tOwned = $ClassMethod(tFx, "Probe", ..#SOURCE, "irisowner", 1, 2, "open and owned")
    Set tClosed = $ClassMethod(tFx, "Probe", ..#SOURCE, "", 0, 0, "closed")
    Do $$$AssertTrue((tOpen > 0) && (tOwned > tOpen) && (tClosed > tOwned), "three probes are stored under rising ids")
    Kill tQuery
    Set tVerdict = ..Verdict(..#ENDPOINT, "LIST", .tRows, .tFault, .tQuery)
    Do $$$AssertEquals(tVerdict, "200 ", "the list answers 200")
    Do $$$AssertEquals(..Ids(tRows), tClosed _ "," _ tOwned _ "," _ tOpen, "every probe, newest first")
    Set tRow = tRows.%Get(0)
    Do $$$AssertEquals(tRow.IsOpen _ "|" _ tRow.CurrentOwner _ "|" _ tRow.EscalationLevel _ "|" _ tRow.Namespace, "0||0|" _ ..#SOURCE, "a row carries its open state, owner, level and namespace")
    Do $$$AssertTrue((tRow.AlertTime '= "") && (tRow.NextActionTime '= "") && (tRow.LastActionTime '= "") && (tRow.AlertText = "closed") && (tRow.SourceConfigName = $Parameter(tFx, "MARKER")), "and its times, text and source")
    Kill tQuery
    Set tQuery("open") = "yes"
    Do ..Verdict(..#ENDPOINT, "LIST", .tYes, .tFault, .tQuery)
    Do $$$AssertEquals(..Ids(tYes), tOwned _ "," _ tOpen, "open=yes lists the open alerts only")
    Kill tQuery
    Set tQuery("open") = "no"
    Do ..Verdict(..#ENDPOINT, "LIST", .tNo, .tFault, .tQuery)
    Do $$$AssertEquals(..Ids(tNo), tClosed, "open=no lists the closed one")
    Kill tQuery
    Set tQuery("open") = "maybe"
    Do $$$AssertEquals(..Verdict(..#ENDPOINT, "LIST", .tBad, .tFault, .tQuery), "400 PORT.VALIDATION", "another value of the criterion is refused by name")
    Do $$$AssertEquals($ClassMethod(tFx, "Count", ..#OTHER, 1), 0, "HSCUSTOM's probes are none, and the list of USER never reads them")
}

/// <p>AC1: the history of one alert is one row for each update, newest first, naming the caller, the action in the vendor's words, the reason and the old and new values as
/// <code>Name: value</code>, and an alert with no update has none.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListAlertActions</method> order the rows oldest first -- this goes red.</p>
Method TestTheHistoryIsOneRowForEachUpdateNewestFirst()
{
    Set tFx = ..#FIXTURE
    Set tId = $ClassMethod(tFx, "Probe", ..#SOURCE)
    Kill tQuery
    Set tQuery("alert") = tId
    Do ..Verdict("ManagedAlertActions", "LIST", .tNone, .tFault, .tQuery)
    Do $$$AssertEquals($Select($IsObject(tNone): tNone.%Size(), 1: -1), 0, "an alert with no update has no history")
    Set tValues("CurrentOwner") = "irisowner"
    Do $$$AssertStatusOK($ClassMethod(tFx, "Touch", ..#SOURCE, tId, 1, .tValues, "first reason"), "the first update is made")
    Kill tValues
    Set tValues("IsOpen") = 0
    Set tValues("EscalationLevel") = 1
    Do $$$AssertStatusOK($ClassMethod(tFx, "Touch", ..#SOURCE, tId, 6, .tValues, "second reason"), "the second update is made")
    Kill tQuery
    Set tQuery("alert") = tId
    Set tVerdict = ..Verdict("ManagedAlertActions", "LIST", .tRows, .tFault, .tQuery)
    Do $$$AssertEquals(tVerdict, "200 ", "the history answers 200")
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size(), 1: -1), 2, "two rows")
    If $Get(tRows) = "" Quit
    Set tNewest = tRows.%Get(0)
    Set tOldest = tRows.%Get(1)
    Do $$$AssertEquals(tNewest.Username _ "|" _ tNewest.Action _ "|" _ tNewest.Reason, "irisowner|Close | Change Escalation Level|second reason", "the newest row names the caller, the actions and the reason")
    Do $$$AssertEquals(tNewest.OldValues _ "|" _ tNewest.NewValues, "EscalationLevel: 0; IsOpen: 1|EscalationLevel: 1; IsOpen: 0", "and the old and new values, each as name and value")
    Do $$$AssertEquals(tOldest.Action _ "|" _ tOldest.Reason _ "|" _ tOldest.OldValues _ "|" _ tOldest.NewValues, "Assign|first reason|CurrentOwner: |CurrentOwner: irisowner", "the oldest row is the first update")
    Do $$$AssertTrue(tNewest.ActionTime '= "", "with its time")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("ManagedAlertActions", "LIST", .tMissing, .tFault, .tQuery), "400 PORT.VALIDATION", "a history asked for no alert is refused by name")
    Set tQuery("alert") = "12x"
    Do $$$AssertEquals(..Verdict("ManagedAlertActions", "LIST", .tShape, .tFault, .tQuery), "400 PORT.VALIDATION", "and so is an id of the wrong shape")
}

/// <p>AC1: the screen's read route and the agent's read tool answer the rows the port answers, for the list, its <code>open</code> criterion and the history, in the fields each screen declares.</p>
/// <p>Mutation (Rule 19): rename the <code>alert</code> criterion in <class>OcuPilot.Screen.Descriptor.InteropManagedAlertHistory</class> -- the route and the tool answer a different
/// alert's rows or none, and this goes red.</p>
Method TestTheReadRouteAndTheReadToolAnswerTheSameRows()
{
    Set tFx = ..#FIXTURE
    Set tOpen = $ClassMethod(tFx, "Probe", ..#SOURCE, "", 1, 0, "open")
    Set tClosed = $ClassMethod(tFx, "Probe", ..#SOURCE, "", 0, 0, "closed")
    Set tValues("CurrentOwner") = "irisowner"
    Do $ClassMethod(tFx, "Touch", ..#SOURCE, tClosed, 1, .tValues, "assigned")
    Set tEntries = $ListBuild($ListBuild("InteropManagedAlertList", "ManagedAlerts", "", "", "ID,CurrentOwner,IsOpen"), $ListBuild("InteropManagedAlertList", "ManagedAlerts", "open", "yes", "ID,CurrentOwner,IsOpen"), $ListBuild("InteropManagedAlertHistory", "ManagedAlertActions", "alert", tClosed, "ActionTime,Username,Action,Reason,OldValues,NewValues"))
    Do ##class(OcuPilot.Kernel.Scope).Set(..#SOURCE)
    For tI = 1:1:$ListLength(tEntries) {
        Set tEntry = $List(tEntries, tI)
        Set tClass = "OcuPilot.Screen.Descriptor." _ $List(tEntry, 1)
        Kill tQuery, tCriteria
        Set tArgs = {}
        If $List(tEntry, 3) '= "" {
            Set tQuery($List(tEntry, 3)) = $List(tEntry, 4)
            Set tCriteria($List(tEntry, 3)) = $List(tEntry, 4)
            Do tArgs.%Set($List(tEntry, 3), $List(tEntry, 4), "string")
        }
        Do ..Verdict($List(tEntry, 2), "LIST", .tPortRows, .tPortFault, .tQuery)
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
        Set tCanon = ..Canon(tPortRows, $List(tEntry, 5))
        Do $$$AssertEquals(..Canon(tAnswer.rows, $List(tEntry, 5)), tCanon, tI _ ": the route's rows are the port's")
        Do $$$AssertEquals(..Canon(tResult.rows, $List(tEntry, 5)), tCanon, tI _ ": and so are the tool's")
    }
}

/// <p><var>pRows</var> reduced to <var>pFields</var> (comma-separated), one line for each row, in order.</p>
ClassMethod Canon(pRows As %DynamicArray, pFields As %String) As %String
{
    Set tText = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        For tI = 1:1:$Length(pFields, ",") {
            Set tField = $Piece(pFields, ",", tI)
            Set tText = tText _ tField _ "=" _ tRow.%Get(tField) _ "|"
        }
        Set tText = tText _ $Char(10)
    }
    Quit tText
}

/// <p>AC1: both lists are cut at a named limit, and truncation is the caller's to read from the row it asks for beyond its own cap: at the limit all rows come, one over the limit answers the limit,
/// and a caller that asks for fewer gets fewer. The shipped limits are 2,000 alerts and 1,000 history rows, measured.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.AlertCap</method> answer <var>pLimit</var> plus one -- this goes red.</p>
Method TestBothListsStopAtTheirNamedLimit()
{
    Set tCap = ..#CAPSEAM
    Do $$$AssertEquals($Parameter("OcuPilot.Port.InteropPort", "ALERTSMAX") _ "|" _ $Parameter("OcuPilot.Port.InteropPort", "ALERTACTIONSMAX"), "2000|1000", "the shipped limits are 2,000 alerts and 1,000 history rows")
    Do $$$AssertEquals($Parameter(tCap, "ALERTSMAX") _ "|" _ $Parameter(tCap, "ALERTACTIONSMAX"), "3|3", "the seam lowers both to three")
    Set tFx = ..#FIXTURE
    For tI = 1:1:3 {
        Set tIds(tI) = $ClassMethod(tFx, "Probe", ..#SOURCE, "", 1, 0, "alert " _ tI)
    }
    Kill tQuery
    Do ..Verdict(..#ENDPOINT, "LIST", .tAt, .tFault, .tQuery, ..#SOURCE, tCap)
    Do $$$AssertEquals(..Ids(tAt), tIds(3) _ "," _ tIds(2) _ "," _ tIds(1), "three alerts at the limit: all three, newest first")
    Set tIds(4) = $ClassMethod(tFx, "Probe", ..#SOURCE, "", 1, 0, "alert 4")
    Kill tQuery
    Do ..Verdict(..#ENDPOINT, "LIST", .tOver, .tFault, .tQuery, ..#SOURCE, tCap)
    Do $$$AssertEquals(..Ids(tOver), tIds(4) _ "," _ tIds(3) _ "," _ tIds(2), "four alerts, one over: the limit, the newest three")
    Kill tQuery
    Set tQuery("maxRows") = 4
    Do ..Verdict(..#ENDPOINT, "LIST", .tAsked, .tFault, .tQuery, ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tAsked)): tAsked.%Size(), 1: -1), 3, "a caller that asks for more than the limit is answered the limit")
    Kill tQuery
    Set tQuery("maxRows") = 2
    Do ..Verdict(..#ENDPOINT, "LIST", .tFewer, .tFault, .tQuery, ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tFewer)): tFewer.%Size(), 1: -1), 2, "and one that asks for fewer gets fewer")
    Set tId = tIds(4)
    For tN = 1:1:3 {
        Kill tValues
        Set tValues("EscalationLevel") = tN
        Do $ClassMethod(tFx, "Touch", ..#SOURCE, tId, 4, .tValues, "step " _ tN)
    }
    Kill tQuery
    Set tQuery("alert") = tId
    Do ..Verdict("ManagedAlertActions", "LIST", .tHistoryAt, .tFault, .tQuery, ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tHistoryAt)): tHistoryAt.%Size(), 1: -1), 3, "three history rows at the limit: all three")
    Kill tValues
    Set tValues("EscalationLevel") = 4
    Do $ClassMethod(tFx, "Touch", ..#SOURCE, tId, 4, .tValues, "step 4")
    Kill tQuery
    Set tQuery("alert") = tId
    Do ..Verdict("ManagedAlertActions", "LIST", .tHistoryOver, .tFault, .tQuery, ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tHistoryOver)): tHistoryOver.%Size() _ "|" _ tHistoryOver.%Get(0).Reason, 1: ""), "3|step 4", "four history rows, one over: the limit, the newest three")
}

/// <p>AC1: the owner choices are the users the classic form offers for the namespace: a user holding <code>%EnsRole_AlertOperator</code> and WRITE on <code>USER</code>'s database is listed for
/// <code>USER</code> and not for <code>HSCUSTOM</code>; reading the list, the history and the owners writes no node of the alert globals.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.AlertOwnerNames</method> limit the list to no namespace -- the user is listed for HSCUSTOM too and this goes red.</p>
Method TestTheOwnersAreTheUsersTheClassicFormOffersAndReadingWritesNothing()
{
    Set tFx = ..#FIXTURE
    Set tUser = "OcuP2417Own"
    Set tPassword = "OcuP2417" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tId = $ClassMethod(tFx, "Probe", ..#SOURCE, "")
    Do $$$AssertStatusOK($ClassMethod(tFx, "CreateOwner", tUser, tPassword), "the owner is created")
    Try {
        Set tBefore = $Get(^|"USER"|Ens.Alerting.ManagedAlertD) _ "|" _ $Order(^|"USER"|Ens.Alerting.ManagedAlertD(""), -1)
        Kill tQuery
        Do ..Verdict(..#ENDPOINT, "LIST", .tList, .tFault, .tQuery)
        Kill tQuery
        Set tQuery("alert") = tId
        Do ..Verdict("ManagedAlertActions", "LIST", .tHistory, .tFault, .tQuery)
        Kill tQuery
        Set tVerdict = ..Verdict(..#ENDPOINT, "ALERTOWNERS", .tOwners, .tFault, .tQuery)
        Do $$$AssertEquals(tVerdict, "200 ", "the owners answer 200")
        Set tNames = ","
        If $IsObject($Get(tOwners)) {
            Set tIterator = tOwners.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                Set tNames = tNames _ tRow.Name _ ","
            }
        }
        Do $$$AssertTrue(tNames [ ("," _ tUser _ ","), "the owner is offered for USER: " _ tNames)
        Kill tQuery
        Do ..Verdict(..#ENDPOINT, "ALERTOWNERS", .tOther, .tFault, .tQuery, ..#OTHER)
        Set tOtherNames = ","
        If $IsObject($Get(tOther)) {
            Set tIterator = tOther.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                Set tOtherNames = tOtherNames _ tRow.Name _ ","
            }
        }
        Do $$$AssertTrue(tOtherNames '[ ("," _ tUser _ ","), "and not for HSCUSTOM, whose database the user cannot write: " _ tOtherNames)
        Do $$$AssertEquals($Get(^|"USER"|Ens.Alerting.ManagedAlertD) _ "|" _ $Order(^|"USER"|Ens.Alerting.ManagedAlertD(""), -1), tBefore, "no read wrote the alert globals")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the owners leg raised")
    }
    Do $$$AssertStatusOK($ClassMethod(tFx, "DropOwner", tUser), "the owner is removed")
}

}
