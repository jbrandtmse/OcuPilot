/// <p>Story 7.11's server half, short of a write: the five audit event tools' declarations, the
/// port's split of an event's row key, the prohibited set's arm for both event types, their fold
/// rules, and the card's audit warning on OcuPilot's own marker event.</p>
/// <p>Nothing here writes the instance; the mint leg stores one proposal on a seeded turn and
/// removes both. The port and prohibited-set legs read
/// <code>%System/%Security/AuditChange</code> and <code>OcuPilot/Security/ConfigChange</code>
/// through the real <class>OcuPilot.Port.AdminPort</class>, so they need
/// <code>%Admin_Secure:USE</code> and OcuPilot's audit events registered, which install does.</p>
Class OcuPilot.Test.AuditEventTools Extends %UnitTest.TestCase
{

Parameter SYSTEMUPDATE = "OcuPilot.Screen.Tool.AuditEventUpdate";

Parameter USERUPDATE = "OcuPilot.Screen.Tool.AuditUserEventUpdate";

Parameter SYSTEMRESET = "OcuPilot.Screen.Tool.AuditEventReset";

Parameter USERRESET = "OcuPilot.Screen.Tool.AuditUserEventReset";

Parameter USERDELETE = "OcuPilot.Screen.Tool.AuditUserEventDelete";

/// <p>A system event every instance defines.</p>
Parameter SYSTEMEVENT = "%System/%Security/AuditChange";

/// <p>A user event install registers, and which is not the marker event.</p>
Parameter USEREVENT = "OcuPilot/Security/ConfigChange";

Parameter MARKER = "OcuPilot/Security/AgentWrite";

Parameter ENDPOINT = "Security.Audit.Event";

/// <p>The system update tool writes <code>Enabled</code> alone and the user one
/// <code>Description</code> too (Story 9.10), over the class-derived
/// <code>Security.Audit.Event:Security.Events</code> list, through the vendor's own endpoint, and
/// each agrees with the prohibited set's permitted list for its entity type.</p>
Method TestTheUpdateToolsAdmitEnabledAloneOverTheClassDerivedList()
{
    For tPair = $ListBuild(..#SYSTEMUPDATE, "security.auditsystemevents.update", "OcuPilot.Screen.Descriptor.AuditSystemEventList", "audit-event", "Enabled"), $ListBuild(..#USERUPDATE, "security.audituserevents.update", "OcuPilot.Screen.Descriptor.AuditUserEventList", "audit-user-event", "Description,Enabled") {
        Set tClass = $List(tPair, 1)
        Do $$$AssertEquals($Parameter(tClass, "TOOLNAME"), $List(tPair, 2), tClass _ " is " _ $List(tPair, 2))
        Do $$$AssertEquals($Parameter(tClass, "DESCRIPTORCLASS"), $List(tPair, 3), "and writes for " _ $List(tPair, 3))
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "|" _ $ClassMethod(tClass, "IdArgument") _ "|" _ $ClassMethod(tClass, "IdParam"), ..#ENDPOINT _ "|EventName|event", "over Security.Audit.Event, keyed by the row's EventName sent as the port's event key")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), $List(tPair, 5), "admitting " _ $List(tPair, 5) _ " of the derived Description and Enabled")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "PermittedFields")), $ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields($List(tPair, 4))), "which is what the prohibited set permits for " _ $List(tPair, 4))
        Do $$$AssertEquals($ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "Destructive"), "PUT|1|0", "a merge PUT, not destructive")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")), "enable,disable", "carrying Enable and Disable")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Operation).MovesMarking(tClass), 1, "and moving the marking")
        Set tProperties = $ClassMethod(tClass, "InputSchema").properties
        Do $$$AssertEquals(tProperties.%GetTypeOf("Enabled"), "object", "the schema advertises Enabled")
        Do $$$AssertEquals(tProperties.%GetTypeOf("Description"), $Select($List(tPair, 5) [ "Description": "object", 1: "unassigned"), "and Description only where it admits it")
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved, "its pairs resolve")
        Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Admin_Secure", "USE")) > 0, "including %Admin_Secure:USE, once")
    }
}

/// <p>A no-op screen action is refused before anything is sent, and an action that changes the
/// state is not.</p>
Method TestAScreenActionThatChangesNothingIsRefusedAtTheRead()
{
    Set tValues = {}
    Do tValues.%Set("EventName", ..#SYSTEMEVENT, "string")
    Set tSC = ##class(OcuPilot.Screen.Tool.AuditEventUpdate).ScreenActionDelta("enable", tValues, {"Description": "d", "Enabled": true}, .tArgs, .tProblem)
    Do $$$AssertStatusOK(tSC, "the delta answers")
    Do $$$AssertTrue(tProblem '= "", "enabling an enabled event is a problem: " _ tProblem)
    Set tSC = ##class(OcuPilot.Screen.Tool.AuditEventUpdate).ScreenActionDelta("disable", tValues, {"Description": "d", "Enabled": true}, .tArgs, .tProblem)
    Do $$$AssertEquals(tProblem, "", "disabling an enabled one is not")
    Do $$$AssertEquals(tArgs.%ToJSON(), "{""Enabled"":false}", "and sends Enabled false")
}

/// <p>Both resets are action-style writes of the vendor's <code>CLEARCOUNT</code>, whose ignored
/// body is the port's constant, with one <code>Total</code> row and an adequate subject.</p>
Method TestTheResetToolsAreActionWritesWithOneStateRow()
{
    For tPair = $ListBuild(..#SYSTEMRESET, "security.auditsystemevents.reset"), $ListBuild(..#USERRESET, "security.audituserevents.reset") {
        Set tClass = $List(tPair, 1)
        Do $$$AssertEquals($Parameter(tClass, "TOOLNAME"), $List(tPair, 2), tClass _ " is " _ $List(tPair, 2))
        Do $$$AssertEquals($ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "ChangeAction"), "CLEARCOUNT|0|updated", "a bodyless CLEARCOUNT that updates the event")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")), "reset", "carrying Reset counters")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "SettableFields")), 0, "admitting no field")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")), "Enabled", "fingerprinting whether the event is enabled")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", "which registration holds adequate")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Operation).MovesMarking(tClass), 0, "a reset moves no marking")
        Set tSC = $ClassMethod(tClass, "StateDiff", {"EventName": "S/T/N", "Enabled": true, "Total": 25184, "Written": 0, "Lost": 0}, .tRows, .tProblem)
        Do $$$AssertStatusOK(tSC, "the state diff answers")
        Do $$$AssertEquals(tProblem, "", "for an event the read reported")
        Do $$$AssertEquals(tRows.%ToJSON(), "[{""field"":""Total"",""before"":""25184"",""after"":""0""}]", "one Total row moving from the read's own Total to 0")
        Do $$$AssertEquals($ClassMethod(tClass, "ReadType") _ "|" _ $ClassMethod(tClass, "ReadIdParam") _ "|" _ $ClassMethod(tClass, "ReadRowKey") _ "|" _ $ClassMethod(tClass, "IdParam"), "LIST|names|EventName|event", "read from the event list filtered to its row, written by the event key")
        Set tSC = $ClassMethod(tClass, "StateDiff", {}, .tRows, .tProblem)
        Do $$$AssertTrue(tProblem '= "", "and an unreported event is a problem")
    }
    Set tConstant = ##class(OcuPilot.Port.AdminPort).ConstantBody(..#ENDPOINT, "CLEARCOUNT")
    Do $$$AssertTrue($IsObject(tConstant), "the port holds CLEARCOUNT's constant body")
    If $IsObject(tConstant) Do $$$AssertEquals(tConstant.%ToJSON(), "{}", "which is {}")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating(..#ENDPOINT, "CLEARCOUNT"), "and admits the type")
}

/// <p>DW-1576, AD-51 as amended: a reset's fresh read is the vendor's event list filtered to the one
/// row whose <code>EventName</code> is the id, in any case, so the card's <code>Total</code> row
/// starts at the list's own count; an event the list does not hold reads as absent.</p>
/// <p>Mutation (Rule 19): hardcode the row's before to <code>""</code> in
/// <method>OcuPilot.Screen.Tool.AuditEventReset.StateDiff</method> -- the before leg goes red.
/// Clear <parameter>OcuPilot.Screen.Tool.AuditEventReset.READROWKEY</parameter> -- the read legs go
/// red.</p>
Method TestAResetsBeforeIsTheListsOwnTotal()
{
    Set tClass = ..#SYSTEMRESET
    For tId = ..#SYSTEMEVENT, $ZConvert(..#SYSTEMEVENT, "L") {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Read(tClass, "OcuPilot.Port.AdminPort", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), tId, "", .tFresh, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, "'" _ tId _ "' reads through the filtered list")
        Do $$$AssertTrue($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"), "as one row")
        If '$IsObject(tFresh) Continue
        Do $$$AssertEquals($ZConvert(tFresh.EventName, "L"), $ZConvert(..#SYSTEMEVENT, "L"), "the row the id names")
        Do $$$AssertEquals(tFresh.%GetTypeOf("Total"), "number", "carrying its Total")
        Set tListed = ..ListedTotal(.tListSC, .tListSize)
        Do $$$AssertStatusOK(tListSC, "the event list reads")
        Do $$$AssertEquals(tListSize, 1, "answering one row for the event")
        Set tSC = $ClassMethod(tClass, "StateDiff", tFresh, .tRows, .tProblem)
        Do $$$AssertEquals(tProblem, "", "the state diff answers")
        Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size(), 1: 0), 1, "with one row")
        If '$IsObject($Get(tRows)) || (tRows.%Size() '= 1) Continue
        Do $$$AssertTrue((tRows.%Get(0).before = tFresh.Total) && (tListed '= "") && (tListed >= tFresh.Total), "before is the list's own Total, " _ tFresh.Total _ " of " _ tListed)
    }
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Read(tClass, "OcuPilot.Port.AdminPort", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), "OcuPilot/NoSuch/Event", "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "an event the list does not hold is refused")
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "404 PORT.NOTFOUND", "as absent")
}

/// <p>DW-1576 on the agent's caller: a minted <code>security.auditsystemevents.reset</code>
/// proposal's one state row moves <code>Total</code> from the event list's own count to
/// <code>0</code>.</p>
/// <p>Mutation (Rule 19): make the mint's fresh read in
/// <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> send the id under the tool's own
/// <code>IdParam</code> through a direct port call -- the event reads as absent and the mint leg goes
/// red.</p>
Method TestAMintedResetStartsAtTheListsOwnTotal()
{
    Set tClass = ..#SYSTEMRESET
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = $ClassMethod(tClass, "View", "", {"EventName": (..#SYSTEMEVENT)}, 0, .tProposal, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(tSC, "the reset is proposed: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: $System.Status.GetErrorText(tSC)))
    Set tListed = ..ListedTotal(.tListSC, .tListSize)
    Do $$$AssertStatusOK(tListSC, "the event list reads")
    Do $$$AssertEquals(tListSize, 1, "answering one row for the event")
    Set tRows = $Select($IsObject($Get(tProposal)): tProposal.%Get("changed"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%Size(), 1: 0), 1, "the proposal carries one row")
    If $IsObject(tRows) && (tRows.%Size() = 1) {
        Set tRow = tRows.%Get(0)
        Do $$$AssertEquals(tRow.field _ "|" _ tRow.before _ "|" _ tRow.after, "Total|" _ tListed _ "|0", "Total moving from the list's own count to 0")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe turn and its proposal are removed")
}

/// <p><parameter>SYSTEMEVENT</parameter>'s <code>Total</code> as the vendor's event list filtered by
/// name answers it now, with the read's status in <var>pSC</var> and the number of rows it answered
/// in <var>pSize</var>.</p>
ClassMethod ListedTotal(Output pSC As %Status, Output pSize As %Integer) As %String
{
    Set pSize = 0
    Kill tQuery
    Set tQuery("names") = ..#SYSTEMEVENT
    Set pSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "LIST", .tQuery, "", .tList, .tHttp, .tFault)
    If '$IsObject($Get(tList)) || 'tList.%IsA("%Library.DynamicArray") Quit ""
    Set pSize = tList.%Size()
    If pSize = 0 Quit ""
    Quit tList.%Get(0).Total
}

/// <p>The user event delete is a destructive, bodyless <code>DELETE</code> that moves the marking,
/// and the system list offers none.</p>
Method TestTheUserEventDeleteIsADestructiveActionWrite()
{
    Set tClass = ..#USERDELETE
    Do $$$AssertEquals($Parameter(tClass, "TOOLNAME"), "security.audituserevents.delete", "the delete is security.audituserevents.delete")
    Do $$$AssertEquals($ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "ChangeAction") _ "|" _ $ClassMethod(tClass, "Destructive"), "DELETE|0|deleted|1", "a bodyless, destructive DELETE")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Operation).MovesMarking(tClass), 1, "that moves the marking")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")), "Description,Enabled", "fingerprinting what the user reviewed")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", "which registration holds adequate")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsBodyless(..#ENDPOINT, "DELETE"), "the port sends it with no body")
    Set tSC = $ClassMethod(tClass, "StateDiff", {"Description": "d", "Enabled": true}, .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "the state diff answers")
    Do $$$AssertEquals(tRows.%Size(), 2, "one removal row per subject field")
    Do $$$AssertEquals($ListFind($ClassMethod("OcuPilot.Screen.Descriptor.AuditSystemEventList", "RowActionIds"), "delete"), 0, "and the System events list declares no delete")
}

/// <p>The port splits an event's row key into the vendor's three parameters, in any case, and
/// answers a malformed key 404 without a vendor call; another endpoint's query is untouched.</p>
Method TestThePortSplitsTheEventKeyAndRefusesAMalformedOne()
{
    For tId = ..#SYSTEMEVENT, $ZConvert(..#SYSTEMEVENT, "L") {
        Kill tQuery
        Set tQuery("event") = tId
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, "'" _ tId _ "' is read through the split")
        Do $$$AssertEquals(tHttp, 200, "at 200")
        Do $$$AssertTrue($IsObject(tResult) && (tResult.%GetTypeOf("Enabled") = "boolean"), "answering the event's Enabled flag")
        Do $$$AssertEquals($Get(tQuery("event")), tId, "and the caller's query keeps its one key")
    }
    For tMalformed = "a/b", "a/b/c/d", "/b/c", "a//c", "a/b/", "abc" {
        Kill tQuery
        Set tQuery("event") = tMalformed
        Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).SplitQuery(..#ENDPOINT, .tQuery, .tSplit), 0, "'" _ tMalformed _ "' is not three non-empty pieces")
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, "and is refused")
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "404 PORT.NOTFOUND", "404 PORT.NOTFOUND")
    }
    Kill tQuery
    Set tQuery("event") = "S/T/N"
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).SplitQuery(..#ENDPOINT, .tQuery, .tSplit), 1, "a three-piece key splits")
    Do $$$AssertEquals($Get(tSplit("source")) _ "|" _ $Get(tSplit("type")) _ "|" _ $Get(tSplit("name")) _ "|" _ $Data(tSplit("event")), "S|T|N|0", "into source, type and name, replacing the key")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).SplitQuery("Task.CRUD", .tQuery, .tSplit), 1, "another endpoint's query")
    Do $$$AssertEquals($Get(tSplit("event")), "S/T/N", "is left as it was")
}

/// <p>The prohibited set covers both event types, permits a change to <code>Enabled</code>, refuses
/// one to a system event's <code>Description</code> as an unreviewed field and permits one to a
/// user event's (AD-10, Story 9.10).</p>
Method TestTheProhibitedSetPermitsEnabledAloneForBothTypes()
{
    For tCase = $ListBuild("security.auditsystemevents.update", "audit-event", ..#SYSTEMEVENT), $ListBuild("security.audituserevents.update", "audit-user-event", ..#USEREVENT) {
        Set tTool = $List(tCase, 1)
        Set tType = $List(tCase, 2)
        Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Proposal.Prohibited).CoveredTypes(), tType) > 0, tType _ " is covered")
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key(tType, "instance", $List(tCase, 3), .tRef), "a reference builds")
        Kill tQuery
        Set tQuery("event") = $List(tCase, 3)
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .tLive, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, "the live event reads")
        If $$$ISERR(tSC) Continue
        Set tFlipped = 'tLive.Enabled
        Set tPayload = {}
        Do tPayload.%Set("Description", tLive.Description, "string")
        Do tPayload.%Set("Enabled", tFlipped, "boolean")
        Set tDiff = [{"field": "Enabled", "before": ($Select(tLive.Enabled: "true", 1: "false")), "after": ($Select(tFlipped: "true", 1: "false"))}]
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits(tTool, tRef, tPayload.%ToJSON(), tDiff.%ToJSON(), .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, "the set answers for " _ tType)
        Do $$$AssertEquals(tProhibits _ "|" _ tCode, "0|", "a change to Enabled is permitted for " _ tType)
        Set tPayload = {"Description": "a description nobody reviewed", "Enabled": (tLive.Enabled)}
        Set tDiff = [{"field": "Description", "before": (tLive.Description), "after": "a description nobody reviewed"}]
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits(tTool, tRef, tPayload.%ToJSON(), tDiff.%ToJSON(), .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, "the set answers for a Description change")
        Do $$$AssertEquals(tProhibits _ "|" _ tCode, $Select(tType = "audit-user-event": "0|", 1: "1|" _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#UNCOVEREDFIELD), "and answers a Description change as its field list says for " _ tType)
    }
    ; A reset's Total row is its state label and a delete's rows are its fingerprint subject, so the
    ; sweep reads neither as a changed field and neither write is refused.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("audit-user-event", "instance", ..#USEREVENT, .tRef), "a user event reference builds")
    Kill tQuery
    Set tQuery("event") = ..#USEREVENT
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .tLive, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the live user event reads")
    If $$$ISERR(tSC) Quit
    For tClass = ..#USERRESET, ..#USERDELETE {
        Set tTool = $Parameter(tClass, "TOOLNAME")
        Set tSC = $ClassMethod(tClass, "StateDiff", tLive, .tRows, .tProblem)
        Do $$$AssertStatusOK(tSC, tTool _ "'s own rows are drawn from the live read")
        Do $$$AssertEquals($Get(tProblem), "", "with no problem")
        Do $$$AssertTrue($IsObject($Get(tRows)) && (tRows.%Size() > 0), "and at least one row")
        If '$IsObject($Get(tRows)) Continue
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits(tTool, tRef, tLive.%ToJSON(), tRows.%ToJSON(), .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, "the set answers " _ tTool)
        Do $$$AssertEquals(tProhibits _ "|" _ tCode, "0|", tTool _ "'s own rows are prohibited by nothing")
    }
}

/// <p>Both event types fold case (AD-13): the vendor keys events case-insensitively, so two
/// spellings are one reference.</p>
Method TestBothEventTypesFoldCase()
{
    For tType = "audit-event", "audit-user-event" {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId(tType, "%System/%SQL/XDBCStatementUtility"), "%system/%sql/xdbcstatementutility", tType _ " folds to lower case")
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key(tType, "instance", ..#MARKER, .tOne), "a key builds")
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key(tType, "instance", $ZConvert(..#MARKER, "U"), .tTwo), "and so does another spelling's")
        Do $$$AssertEquals(tOne, tTwo, "and the two are one key")
    }
}

/// <p>The card's audit warning (AD-15): disabling or deleting OcuPilot's marker event warns, in any
/// spelling and any boolean form; enabling it, resetting it, and any other event do not; and the
/// auditing write still warns as it did.</p>
Method TestTheCardWarnsOnTheMarkerEventAlone()
{
    Set tScope = ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE
    Set tMint = "OcuPilot.Kernel.Proposal.Mint"
    Set tUpdate = "security.audituserevents.update"
    Do $$$AssertEquals($ClassMethod(tMint, "WarnsAuditingOff", tUpdate, "audit-user-event", tScope, {"EventName": (..#MARKER), "Enabled": false}), 1, "disabling the marker event warns")
    Do $$$AssertEquals($ClassMethod(tMint, "WarnsAuditingOff", tUpdate, "audit-user-event", tScope, {"EventName": ($ZConvert(..#MARKER, "L")), "Enabled": "false"}), 1, "in another spelling, with Enabled spelled as a string")
    Do $$$AssertEquals($ClassMethod(tMint, "WarnsAuditingOff", tUpdate, "audit-user-event", tScope, {"EventName": (..#MARKER), "Enabled": 0}), 1, "or as 0")
    Do $$$AssertEquals($ClassMethod(tMint, "WarnsAuditingOff", tUpdate, "audit-user-event", tScope, {"EventName": (..#MARKER), "Enabled": true}), 0, "enabling it does not")
    Do $$$AssertEquals($ClassMethod(tMint, "WarnsAuditingOff", tUpdate, "audit-user-event", tScope, {"EventName": (..#MARKER)}), 0, "and neither does a call that sets nothing")
    Do $$$AssertEquals($ClassMethod(tMint, "WarnsAuditingOff", tUpdate, "audit-user-event", tScope, {"EventName": (..#USEREVENT), "Enabled": false}), 0, "disabling another event does not")
    Do $$$AssertEquals($ClassMethod(tMint, "WarnsAuditingOff", "security.audituserevents.delete", "audit-user-event", tScope, {"EventName": (..#MARKER)}), 1, "deleting the marker event warns")
    Do $$$AssertEquals($ClassMethod(tMint, "WarnsAuditingOff", "security.audituserevents.delete", "audit-user-event", tScope, {"EventName": (..#USEREVENT)}), 0, "deleting another does not")
    Do $$$AssertEquals($ClassMethod(tMint, "WarnsAuditingOff", "security.audituserevents.reset", "audit-user-event", tScope, {"EventName": (..#MARKER)}), 0, "resetting the marker event's counters does not")
    Do $$$AssertEquals($ClassMethod(tMint, "WarnsAuditingOff", "security.auditing.update", "auditing-configuration", tScope, {"Name": "SYSTEM", "Enabled": false}), 1, "and turning auditing off still does")
}

}
