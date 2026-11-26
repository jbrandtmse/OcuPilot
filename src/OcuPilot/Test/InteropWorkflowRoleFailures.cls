/// <p>Pins Story 24.17 Batch 3b's failures (AD-6, AD-15, AD-39, AD-62), for the workflow roles and their members: a vendor error status or fault on a role's add, edit and remove and a member's add and
/// remove is 500 <code>INTERNAL</code>, never 200, even where the vendor saved the membership first, and its audit row reads not completed; a member remove that deletes nothing and answers OK, as the
/// vendor's <code>RemoveUserFromRole</code> does when its delete fails, is 500 too; no line the port logs carries a description, a title or a vendor's text, and none is written while the namespace is
/// switched; an edit that moves no field calls no vendor, and a role another process holds locked is 503.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs.</p>
Class OcuPilot.Test.InteropWorkflowRoleFailures Extends OcuPilot.Test.InteropWorkflowCase
{

Parameter SCREEN = "/screens/interop.workflowroles";

Parameter SAVE = "/interop/workflow-roles";

Parameter ENDPOINT = "WorkflowRoles";

Parameter TOOLPREFIX = "OcuPilot.Screen.Tool.InteropWorkflowRole";

Parameter ENTITY = "interop-workflow-role";

Parameter READTYPE = "WORKFLOWROLE";

Parameter ROLEA = "OcuP2417wGra";

Parameter ROLEB = "OcuP2417wGrb";

Parameter USERA = "OcuP2417wGua";

/// <p>A description and a title no log line may carry.</p>
Parameter SECRETTEXT = "OcuSecretText2417";

/// <p>How many <code>ConfigChange</code> rows of the entity <var>pEntity</var> name <var>pNeedle</var> since <var>pSince</var>, and whether the last reads completed, as <code>count|completed</code>.
/// The audit database shows a row a moment after it is written, so the read is made again until it finds <var>pExpect</var> rows; with <var>pSettle</var> it goes on until the count has stopped moving.</p>
ClassMethod Audit(pSince As %String, pEntity As %String, pNeedle As %String, pExpect As %Integer = 1, pSettle As %Boolean = 0) As %String
{
    Set tRows = 0
    For tTry = 1:1:20 {
        Set tRows = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", pEntity, .tData, pNeedle)
        If tRows '< pExpect Quit
        Hang 0.25
    }
    If pSettle {
        Set tStable = $ZHorolog
        While ($ZHorolog - tStable) < ..#SETTLE {
            Hang 0.25
            Set tNow = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", pEntity, .tData, pNeedle)
            If tNow '= tRows {
                Set tRows = tNow
                Set tStable = $ZHorolog
            }
        }
    }
    Quit tRows _ "|" _ $Select($Get(tData) [ """completed"":false": "false", $Get(tData) [ """completed"":true": "true", 1: "?")
}

/// <p>AC6: a vendor error status or a fault the vendor raises on a role's add, edit and remove is 500 <code>INTERNAL</code>, never 200, and the audit row reads not completed, naming the namespace and the
/// role and never a value; the role is as it was; and no line the port logged carries the vendor's text, a name or a description, the vendor's refusal reaching the log by its code alone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformWorkflowRole</method> ignore the vendor's status -- the status rows go red; make it log the vendor's text -- the log legs go
/// red; record the audit row only on success -- the not-completed legs go red.</p>
Method TestAVendorErrorOnARoleWriteIsNeverA200AndItsAuditRowReadsNotCompleted()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Set tSuffix("status") = "s"
    Set tSuffix("fault") = "f"
    For tMode = "status", "fault" {
        Set tHeld = ..#ROLEA _ tSuffix(tMode)
        Set tFree = ..#ROLEB _ tSuffix(tMode)
        Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", tHeld, ..#SOURCE, ..#SECRETTEXT, 20), tMode _ ": a role is held")
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Do $ClassMethod(tSeam, "ClearLog")
        Kill ^IRIS.Temp.OcuProbe2417wMode
        Set ^IRIS.Temp.OcuProbe2417wMode = tMode
        Kill tRows
        For tCase = $ListBuild("ADDWORKFLOWROLE", tFree, "{""Description"":""OcuSecretText2417""}"), $ListBuild("SETWORKFLOWROLE", tHeld, "{""Description"":""OcuSecretOther2417""}"), $ListBuild("REMOVEWORKFLOWROLE", tHeld, "") {
            Set tBody = $Select($List(tCase, 3) = "": "", 1: ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 3)))
            Set tVerdict = ..Put($List(tCase, 1), $List(tCase, 2), tBody, .tResult, .tFault, ..#SOURCE, tSeam)
            Do $$$AssertEquals(tVerdict, "500 INTERNAL", tMode _ ": " _ $List(tCase, 1) _ " answers 500 INTERNAL, never 200")
            Set tRows($List(tCase, 2)) = $Get(tRows($List(tCase, 2))) + 1
            Do $$$AssertEquals(..Audit(tSince, ..#ENTITY, """" _ $List(tCase, 2) _ """", tRows($List(tCase, 2))), tRows($List(tCase, 2)) _ "|false", tMode _ ": " _ $List(tCase, 1) _ ": its audit row reads not completed")
        }
        Set tLogged = $ClassMethod(tSeam, "LoggedText")
        Do $$$AssertTrue($ClassMethod(tSeam, "Logged") > 0, tMode _ ": the failure was logged: " _ tLogged)
        Do $$$AssertTrue((tLogged '[ $Parameter(tSeam, "MARKER")) && (tLogged '[ ..#ROLEA) && (tLogged '[ ..#ROLEB) && (tLogged '[ "OcuSecret"), tMode _ ": no line carries the vendor's text, a name or a description: " _ tLogged)
        Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, tHeld) _ "|" _ $ClassMethod(tFx, "RoleCount", ..#SOURCE), ..#SECRETTEXT _ "|20|" _ $Select(tMode = "status": 1, 1: 2), tMode _ ": the held role is as it was and nothing was added")
        Do $$$AssertEquals(+$Get(^IRIS.Temp.OcuProbe2417wMode("ran")), 3, tMode _ ": the vendor was called once for each write")
        Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417wMode("ranIn")), ..#SOURCE, tMode _ ": in the namespace the write is for")
    }
    Kill ^IRIS.Temp.OcuProbe2417wMode
    Do $$$AssertEquals(..Put("SETWORKFLOWROLE", ..#ROLEA _ "f", {"Description": "Fine"}, .tResult, .tFault, ..#SOURCE, tSeam), "200 ", "with no mode the seam answers the vendor's own: the edit is made")
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLEA _ "f"), "Fine|20", "and stored")
}

/// <p>AC6: a vendor error status or fault on a member's add and remove is 500 <code>INTERNAL</code>, never 200, even where the vendor saved the membership first (the add's error status after its save) or
/// deleted it first, and the audit row reads not completed; a remove that deletes nothing and answers OK is 500 too, because the port reads the membership again, and its row reads not completed; no log
/// line carries a title, a name or the vendor's text.</p>
/// <p>Mutation (Rule 19): skip the membership's re-read after <method>OcuPilot.Port.InteropPort.WorkflowMemberVendor</method>'s remove in <method>OcuPilot.Port.InteropPort.PerformWorkflowMember</method> -- the
/// kept leg goes red; ignore the vendor's status -- the status legs go red.</p>
Method TestAVendorErrorOnAMemberWriteIsNeverA200AndARemoveThatDeletesNothingIsNot()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Set tRole = ..#ROLEA
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", tRole), "a role is stored")
    Set tSuffix("status") = "s"
    Set tSuffix("fault") = "f"
    Set tSuffix("keep") = "k"
    For tMode = "status", "fault", "keep" {
        Set tHeld = ..#USERA _ tSuffix(tMode) _ "h"
        Set tFree = ..#USERA _ tSuffix(tMode) _ "n"
        Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", tHeld, "Held", 0), tMode _ ": a workflow user is a member")
        Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeMember", tRole, tHeld, ..#SOURCE, 2, ..#SECRETTEXT), tMode _ ": of the role")
        Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", tFree, "Free", 0), tMode _ ": and another is not")
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Do $ClassMethod(tSeam, "ClearLog")
        Kill ^IRIS.Temp.OcuProbe2417wMode
        Set ^IRIS.Temp.OcuProbe2417wMode = tMode
        Set tCalls = 0
        If tMode '= "keep" {
            Set tVerdict = ..PutMember("ADDWORKFLOWMEMBER", tRole, tFree, {"Ranking": 3, "Title": "OcuSecretTitle2417"}, .tResult, .tFault, ..#SOURCE, tSeam)
            Do $$$AssertEquals(tVerdict, "500 INTERNAL", tMode _ ": the add answers 500 INTERNAL, never 200")
            Set tCalls = tCalls + 1
            Do $$$AssertEquals(..Audit(tSince, "interop-workflow-member", """user"":""" _ tFree _ """"), "1|false", tMode _ ": its audit row reads not completed")
        }
        Set tVerdict = ..PutMember("REMOVEWORKFLOWMEMBER", tRole, tHeld, "", .tResult, .tFault, ..#SOURCE, tSeam)
        Do $$$AssertEquals(tVerdict, "500 INTERNAL", tMode _ ": the remove answers 500 INTERNAL, never 200")
        Set tCalls = tCalls + 1
        Do $$$AssertEquals(..Audit(tSince, "interop-workflow-member", """user"":""" _ tHeld _ """"), "1|false", tMode _ ": its audit row reads not completed")
        Set tLogged = $ClassMethod(tSeam, "LoggedText")
        Do $$$AssertTrue($ClassMethod(tSeam, "Logged") > 0, tMode _ ": the failure was logged: " _ tLogged)
        Do $$$AssertTrue((tLogged '[ $Parameter(tSeam, "MARKER")) && (tLogged '[ tHeld) && (tLogged '[ tFree) && (tLogged '[ "OcuSecret"), tMode _ ": no line carries the vendor's text, a name or a title: " _ tLogged)
        Do $$$AssertEquals(+$Get(^IRIS.Temp.OcuProbe2417wMode("ran")), tCalls, tMode _ ": the vendor was called once for each write")
        ; The vendor ran before it answered an error (status) or deleted nothing (keep); a fault raised before it did anything.
        Do $$$AssertEquals($ClassMethod(tFx, "MemberText", ..#SOURCE, tRole, tHeld) _ "|" _ $ClassMethod(tFx, "MemberText", ..#SOURCE, tRole, tFree), $Case(tMode, "status": "<absent>|3|OcuSecretTitle2417", "fault": "2|" _ ..#SECRETTEXT _ "|<absent>", : "2|" _ ..#SECRETTEXT _ "|<absent>"), tMode _ ": the memberships are as the vendor left them")
    }
    Kill ^IRIS.Temp.OcuProbe2417wMode
}

/// <p>AC6, AC8: nothing is logged while the namespace is switched: a fault raised inside the switched block of a role write, a one-role read, a member write or a one-member read is logged once the
/// namespace is restored, in the namespace the call was made in, and answers 500; the vendor's own call runs in the namespace the write is for and the process's namespace is the caller's after each call.</p>
/// <p>Mutation (Rule 19): log inside <method>OcuPilot.Port.InteropPort.WorkflowFactsOf</method> before its namespace is restored -- the namespace leg goes red.</p>
Method TestNothingIsLoggedWhileTheNamespaceIsSwitched()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", ..#ROLEA, ..#SOURCE, "held", 20), "a role is held")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#USERA, "Ann", 0), "and a workflow user")
    Set tHome = $NAMESPACE
    Set ^IRIS.Temp.OcuProbe2417wMode = "here"
    Do $ClassMethod(tSeam, "ClearLog")
    Do $$$AssertEquals(..Put("SETWORKFLOWROLE", ..#ROLEA, {"Description": "x"}, .tResult, .tFault, ..#SOURCE, tSeam), "500 INTERNAL", "a fault in a role write's switched block is 500")
    Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417wMode("hereIn")), ..#SOURCE, "it was raised in the namespace the write is for")
    Do $$$AssertEquals($NAMESPACE, tHome, "the process is back in the caller's namespace")
    Do $$$AssertEquals(..Read(..#ROLEA, "", .tRow, .tFault, ..#SOURCE, tSeam), "500 INTERNAL", "a fault in the one-role read is 500")
    Do $$$AssertEquals(..PutMember("ADDWORKFLOWMEMBER", ..#ROLEA, ..#USERA, {}, .tResult, .tFault, ..#SOURCE, tSeam), "500 INTERNAL", "and in a member write")
    Do $$$AssertEquals(..ReadMember(..#ROLEA, ..#USERA, "", .tRow, .tFault, ..#SOURCE, tSeam), "500 INTERNAL", "and in the one-member read")
    Do $$$AssertEquals($NAMESPACE, tHome, "the process is back in the caller's namespace after each")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 4, "each fault was logged once")
    Do $$$AssertEquals($ClassMethod(tSeam, "LoggedIn"), tHome _ "," _ tHome _ "," _ tHome _ "," _ tHome, "every line was written in the caller's namespace, never the switched one")
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLEA) _ "|" _ $ClassMethod(tFx, "MemberText", ..#SOURCE, ..#ROLEA, ..#USERA), "held|20|<absent>", "the held role is unchanged and no member was added")
}

/// <p>AC2: an edit that moves no field calls no vendor and records no audit row, and a role another process holds locked is 503 <code>PORT.UNAVAILABLE</code> for an edit, with nothing changed and no
/// audit row.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformWorkflowRole</method> call the vendor for an edit that changes nothing -- the unchanged leg goes red; open the role without a
/// concurrency -- the locked leg goes red.</p>
Method TestAnUnchangedEditCallsNothingAndALockedRoleIsUnavailable()
{
    Set tFx = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", ..#ROLEA, ..#SOURCE, "held", 20), "a role is held")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set ^IRIS.Temp.OcuProbe2417wMode = ""
    Do $$$AssertEquals(..Put("SETWORKFLOWROLE", ..#ROLEA, {"Description": "held", "Capacity": 20}, .tResult, .tFault, ..#SOURCE, tSeam), "200 ", "an edit that sends what the role holds is accepted")
    Do $$$AssertEquals(+$Get(^IRIS.Temp.OcuProbe2417wMode("ran")), 0, "and calls no vendor")
    Do $$$AssertEquals(..Audit(tSince, ..#ENTITY, """" _ ..#ROLEA _ """", 0, 1), "0|?", "and records no audit row")
    ; The request that answers the person's Edit runs in another process, so the lock this process takes is one the Edit meets.
    Set tOrigNS = $NAMESPACE
    Set tLocked = 0
    Try {
        Set $NAMESPACE = ..#SOURCE
        Lock +^EnsLib.W.RoleDefinitionD(..#ROLEA):5
        Set tLocked = $Test
        Set $NAMESPACE = tOrigNS
        Do $$$AssertTrue(tLocked, "this process holds the role's lock")
        If tLocked {
            Set tText = ..Act("edit", ..#ROLEA, {"Description": "changed"}, .tAnswer)
            Do $$$AssertEquals($Piece(tText, " ", 1), 503, "the Edit of the locked role is refused unavailable: " _ tText)
            Do $$$AssertEquals(..Audit(tSince, ..#ENTITY, """" _ ..#ROLEA _ """", 0, 1), "0|?", "no audit row was recorded")
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the lock leg raised")
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If tLocked {
        Set $NAMESPACE = ..#SOURCE
        Lock -^EnsLib.W.RoleDefinitionD(..#ROLEA)
        Set $NAMESPACE = tOrigNS
    }
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLEA), "held|20", "the role is unchanged")
}

}
