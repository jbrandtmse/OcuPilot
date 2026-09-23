/// <p>Story 7.11's server half, short of a write: the five audit event tools' declarations, the
/// port's split of an event's row key, the prohibited set's arm for both event types, their fold
/// rules, and the card's audit warning on OcuPilot's own marker event.</p>
/// <p>Nothing here writes the instance. The port and prohibited-set legs read
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

/// <p>Both update tools write <code>Enabled</code> alone, over the class-derived
/// <code>Security.Audit.Event:Security.Events</code> list, through the vendor's own endpoint, and
/// agree with the prohibited set's permitted list for their entity type.</p>
Method TestTheUpdateToolsAdmitEnabledAloneOverTheClassDerivedList()
{
    For tPair = $ListBuild(..#SYSTEMUPDATE, "security.auditsystemevents.update", "OcuPilot.Screen.Descriptor.AuditSystemEventList", "audit-event"), $ListBuild(..#USERUPDATE, "security.audituserevents.update", "OcuPilot.Screen.Descriptor.AuditUserEventList", "audit-user-event") {
        Set tClass = $List(tPair, 1)
        Do $$$AssertEquals($Parameter(tClass, "TOOLNAME"), $List(tPair, 2), tClass _ " is " _ $List(tPair, 2))
        Do $$$AssertEquals($Parameter(tClass, "DESCRIPTORCLASS"), $List(tPair, 3), "and writes for " _ $List(tPair, 3))
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "|" _ $ClassMethod(tClass, "IdArgument") _ "|" _ $ClassMethod(tClass, "IdParam"), ..#ENDPOINT _ "|EventName|event", "over Security.Audit.Event, keyed by the row's EventName sent as the port's event key")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), "Enabled", "admitting Enabled alone of the derived Description and Enabled")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "PermittedFields")), $ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields($List(tPair, 4))), "which is what the prohibited set permits for " _ $List(tPair, 4))
        Do $$$AssertEquals($ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "Destructive"), "PUT|1|0", "a merge PUT, not destructive")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")), "enable,disable", "carrying Enable and Disable")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Operation).MovesMarking(tClass), 1, "and moving the marking")
        Set tProperties = $ClassMethod(tClass, "InputSchema").properties
        Do $$$AssertEquals(tProperties.%GetTypeOf("Enabled"), "object", "the schema advertises Enabled")
        Do $$$AssertEquals(tProperties.%GetTypeOf("Description"), "unassigned", "and not Description (IG-1)")
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved, "its pairs resolve")
        Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Admin_Secure", "USE")) > 0, "including %Admin_Secure:USE, once")
    }
}

/// <p>A no-op screen action is refused before anything is sent, and an action that changes the
/// state is not.</p>
Method TestAScreenActionThatChangesNothingIsRefusedAtTheRead()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.AuditEventUpdate).ScreenActionDelta("enable", {}, {"Description": "d", "Enabled": true}, .tArgs, .tProblem)
    Do $$$AssertStatusOK(tSC, "the delta answers")
    Do $$$AssertTrue(tProblem '= "", "enabling an enabled event is a problem: " _ tProblem)
    Set tSC = ##class(OcuPilot.Screen.Tool.AuditEventUpdate).ScreenActionDelta("disable", {}, {"Description": "d", "Enabled": true}, .tArgs, .tProblem)
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
        Set tSC = $ClassMethod(tClass, "StateDiff", {"Description": "d", "Enabled": true}, .tRows, .tProblem)
        Do $$$AssertStatusOK(tSC, "the state diff answers")
        Do $$$AssertEquals(tProblem, "", "for an event the read reported")
        Do $$$AssertEquals(tRows.%ToJSON(), "[{""field"":""Total"",""before"":"""",""after"":""0""}]", "one Total row moving to 0")
        Set tSC = $ClassMethod(tClass, "StateDiff", {}, .tRows, .tProblem)
        Do $$$AssertTrue(tProblem '= "", "and an unreported event is a problem")
    }
    Set tConstant = ##class(OcuPilot.Port.AdminPort).ConstantBody(..#ENDPOINT, "CLEARCOUNT")
    Do $$$AssertTrue($IsObject(tConstant), "the port holds CLEARCOUNT's constant body")
    If $IsObject(tConstant) Do $$$AssertEquals(tConstant.%ToJSON(), "{}", "which is {}")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating(..#ENDPOINT, "CLEARCOUNT"), "and admits the type")
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

/// <p>The prohibited set covers both event types, permits a change to <code>Enabled</code> and
/// refuses one to <code>Description</code> as an unreviewed field, for either type (AD-10).</p>
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
        Do $$$AssertEquals(tProhibits _ "|" _ tCode, "1|" _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#UNCOVEREDFIELD, "and refuses it as unreviewed for " _ tType)
    }
    ; A reset's Total row is its state label and a delete's rows are its fingerprint subject, so the
    ; sweep reads neither as a changed field and neither write is refused.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("audit-user-event", "instance", ..#USEREVENT, .tRef), "a user event reference builds")
    Kill tQuery
    Set tQuery("event") = ..#USEREVENT
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .tLive, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the live user event reads")
    If $$$ISERR(tSC) Quit
    Set tEnabled = $Select(tLive.Enabled: "true", 1: "false")
    For tCase = $ListBuild("security.audituserevents.reset", "[{""field"":""Total"",""before"":"""",""after"":""0""}]"), $ListBuild("security.audituserevents.delete", "[{""field"":""Description"",""before"":""" _ tLive.Description _ """,""after"":"""",""removed"":true},{""field"":""Enabled"",""before"":""" _ tEnabled _ """,""after"":"""",""removed"":true}]") {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($List(tCase, 1), tRef, tLive.%ToJSON(), $List(tCase, 2), .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, "the set answers " _ $List(tCase, 1))
        Do $$$AssertEquals(tProhibits _ "|" _ tCode, "0|", $List(tCase, 1) _ "'s own rows are prohibited by nothing")
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
