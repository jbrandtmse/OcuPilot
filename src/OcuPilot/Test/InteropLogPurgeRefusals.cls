/// <p>Pins Story 24.17 Batch 2's refusals and containment (AD-7, AD-8, AD-9, AD-15, AD-39, AD-56, AD-62): days that are not a whole number from 0 to 99999 are 422 <code>INTEROP.PURGE.DAYS</code> from
/// the port, 400 <code>TOOL.ARGUMENTS</code> from the person's Purge and the agent's mint, before any vendor call and with nothing deleted; a vendor error is never a 200, is audited as not completed
/// and leaves no vendor text in the log; no log line is written while the namespace is switched; and the process's roles, user and namespace read the same after a purge returns, for a principal
/// without <code>%All</code> and for <code>_SYSTEM</code>, on success and on a raised error.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropLogPurgeCase</class> needs; it creates and removes one principal.</p>
Class OcuPilot.Test.InteropLogPurgeRefusals Extends OcuPilot.Test.InteropLogPurgeCase
{

Parameter CHILD = "OcuPilot.Test.InteropLogPurgeChild";

Parameter GENERATOR = "OcuPilot.Test.InteropArchiveFixture";

/// <p>The principal the roles legs run as: the purges' pairs, WRITE on the database and the SQL SELECT the reads need, and no administrative role.</p>
Parameter ROLESPRINCIPAL = "OcuP2417rRoles:%Ens_Portal:U,%Ens_RuleLog:U,%Ens_Jobs:R,%Ens_Purge:U,%DB_USER:RW,%DB_HSCUSTOM:R";

Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    Set tSC = ##super()
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = "OcuP2417r" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ##super()
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit tSC
    Do $ClassMethod(..#FIXTURE, "RevokeSelect", "OcuP2417rRolesRole")
    Quit $$$ADDSC(tSC, $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#ROLESPRINCIPAL))
}

/// <p>AC3: days that are not a whole number from 0 to 99999 (negative, fractional, past the top, text, empty, with a leading zero or an exponent) are refused 422 <code>INTEROP.PURGE.DAYS</code> by the
/// port, with the sentence the instance publishes, by the person's Purge and by the agent's mint, before any vendor call, and nothing is deleted; 99999 is accepted and deletes nothing, because
/// no probe is that old.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PurgeDaysOK</method> accept a negative number -- the first leg goes red.</p>
Method TestDaysThatAreNotAWholeNumberFrom0To99999AreRefusedBeforeAnyVendorCall()
{
    Set tReason = ##class(OcuPilot.Api.InteropError).ReasonFor("INTEROP.PURGE.DAYS")
    For tKind = "rule", "process" {
        Kill ^IRIS.Temp.OcuProbe2417LogMode
        Set tOld = ..Probe(tKind, ..#SOURCE, 7300, 1)
        For tDays = "-1", "1.5", "100000", "x", "", "07", "1e3" {
            Do $$$AssertEquals(..Purge(tKind, tDays, ..#SOURCE, ..#SEAM, .tResult, .tFault), "422 INTEROP.PURGE.DAYS", tKind _ ", days '" _ tDays _ "': the port refuses them")
            Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("reason"), 1: ""), tReason, tKind _ ", days '" _ tDays _ "': with the published sentence")
            Set tText = ..Act(tKind, tDays, .tAnswer)
            Do $$$AssertEquals(tText, "400 TOOL.ARGUMENTS", tKind _ ", days '" _ tDays _ "': the person's Purge is refused as the tool's argument rule, as the mint is")
            ; An empty value never reaches the days rule: the screen action's own argument check refuses it first, with its own sentence.
            If tDays '= "" Do $$$AssertEquals($Select($IsObject($Get(tAnswer)) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("problem"), 1: ""), tReason, tKind _ ", days '" _ tDays _ "': with the published sentence")
            Do $$$AssertEquals(..Mint(tKind, tDays, .tMintReason, .tProposal, .tTurn), "TOOL.ARGUMENTS", tKind _ ", days '" _ tDays _ "': the agent's mint is refused")
            Do $$$AssertEquals(tMintReason, tReason, tKind _ ", days '" _ tDays _ "': with the same sentence")
            Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
            Do $$$AssertEquals(..Exists(tKind, ..#SOURCE, tOld), 1, tKind _ ", days '" _ tDays _ "': nothing was deleted")
        }
        Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417LogMode("before")), "", tKind _ ": no refusal reached the vendor call")
        Do $$$AssertEquals(..Purge(tKind, "99999", ..#SOURCE, ..#SEAM), "200 ", tKind _ ": 99999 days is accepted")
        Do $$$AssertEquals(..Exists(tKind, ..#SOURCE, tOld), 1, tKind _ ": and deletes nothing, because no probe is that old")
        Do $ClassMethod(..#FIXTURE, "DropProbes")
    }
}

/// <p>AC4: a vendor error is never a 200: the vendor's status, after it deleted one probe, answers 500 <code>INTERNAL</code>, and a raised error does too; OcuPilot's audit row reads
/// <code>completed</code> false in each, and neither the vendor's text nor the status's reaches the log, the envelope or the audit row.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformLogPurge</method> ignore the vendor's status -- the status leg goes red.</p>
Method TestAVendorErrorIsNeverA200AndIsAuditedAsNotCompleted()
{
    Set tSeam = ..#SEAM
    Set tMarker = $Parameter(tSeam, "MARKER")
    For tKind = "rule", "process" {
        Set tOldA = ..Probe(tKind, ..#SOURCE, 7300, 1)
        Set tOldB = ..Probe(tKind, ..#SOURCE, 7300, 1)
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tExpect = 0
        For tMode = "status", "fault" {
            Set ^IRIS.Temp.OcuProbe2417LogMode = tMode
            Do $ClassMethod(tSeam, "ClearLog")
            Set tExpect = tExpect + 1
            Do $$$AssertEquals(..Purge(tKind, 3650, ..#SOURCE, tSeam, .tResult, .tFault), "500 INTERNAL", tKind _ ", " _ tMode _ ": the answer is 500, never 200")
            Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() '[ tMarker), tKind _ ", " _ tMode _ ": and the envelope carries no vendor text")
            Set tRows = ..OwnRows(tKind, tSince, .tData, tExpect)
            Do $$$AssertEquals(tRows, tExpect, tKind _ ", " _ tMode _ ": OcuPilot records one ConfigChange for each purge (since " _ tSince _ "; -1 is a failed audit read)")
            Do $$$AssertTrue((tData [ """completed"":false") && (tData '[ tMarker), tKind _ ", " _ tMode _ ": it reads completed false and carries no vendor text: " _ tData)
            Set tLog = $ClassMethod(tSeam, "LoggedText")
            Do $$$AssertTrue((tLog '= "") && (tLog '[ tMarker), tKind _ ", " _ tMode _ ": the log line names no vendor text: " _ tLog)
            If tMode = "status" Do $$$AssertEquals(..Exists(tKind, ..#SOURCE, tOldA) _ ..Exists(tKind, ..#SOURCE, tOldB), "01", tKind _ ", status: the vendor had deleted one probe before it answered, and the answer was still not a 200")
        }
        Kill ^IRIS.Temp.OcuProbe2417LogMode
        Do $$$AssertEquals(..Purge(tKind, 3650, ..#SOURCE, tSeam), "200 ", tKind _ ": with the vendor's own call the same purge answers 200")
        Do $ClassMethod(..#FIXTURE, "DropProbes")
    }
}

/// <p>AC7: no OcuPilot call and no log line runs while the namespace is switched: a fault raised inside the purge's switched block, the state read's and the privilege check's is logged after the
/// namespace is restored, in the namespace the call was made from.</p>
/// <p>Mutation (Rule 19): log a line inside the switched <code>Catch</code> of <method>OcuPilot.Port.InteropPort.PerformLogPurge</method> -- the purge leg goes red.</p>
Method TestNothingIsLoggedWhileTheNamespaceIsSwitched()
{
    Set tSeam = ..#SEAM
    For tKind = "rule", "process" {
        Set tOld = ..Probe(tKind, ..#SOURCE, 7300, 1)
        Set ^IRIS.Temp.OcuProbe2417LogMode = "fault"
        Do $ClassMethod(tSeam, "ClearLog")
        Do $$$AssertEquals(..Purge(tKind, 3650, ..#SOURCE, tSeam), "500 INTERNAL", tKind _ ": a fault inside the purge's switched block is a 500")
        Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417LogMode("ranIn")), ..#SOURCE, tKind _ ": the vendor call ran in the log's namespace")
        Do $$$AssertEquals($ClassMethod(tSeam, "LoggedIn"), $NAMESPACE, tKind _ ": and the one line it caused was written in the namespace the call came from")
        Set ^IRIS.Temp.OcuProbe2417LogMode = "here"
        Do $ClassMethod(tSeam, "ClearLog")
        Kill tQuery
        Do $$$AssertEquals(..Verdict(tKind, "state", .tRow, .tFault, .tQuery, ..#SOURCE, tSeam), "500 INTERNAL", tKind _ ": a fault inside the state read's switched block is a 500")
        Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417LogMode("hereIn")), ..#SOURCE, tKind _ ": the hook ran in the log's namespace")
        Do $$$AssertEquals($ClassMethod(tSeam, "LoggedIn"), $NAMESPACE, tKind _ ": and its line was written after the namespace was restored")
        Do $ClassMethod(tSeam, "ClearLog")
        Kill ^IRIS.Temp.OcuProbe2417LogMode("hereIn")
        Kill tQuery
        Do $$$AssertEquals(..Verdict(tKind, "LIST", .tRows, .tFault, .tQuery, ..#SOURCE, tSeam), "500 INTERNAL", tKind _ ": and one inside the list's privilege check is a 500")
        Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417LogMode("hereIn")) _ "|" _ $ClassMethod(tSeam, "LoggedIn"), ..#SOURCE _ "|" _ $NAMESPACE, tKind _ ": whose line, too, was written after the namespace was restored")
        Kill ^IRIS.Temp.OcuProbe2417LogMode
        Do $$$AssertEquals(..Exists(tKind, ..#SOURCE, tOld), 1, tKind _ ": the probe is as it was")
        Do $ClassMethod(..#FIXTURE, "DropProbes")
    }
}

/// <p>The answer of <var>pOut</var> for <var>pLabel</var>, for a message: its error when the probe raised.</p>
ClassMethod ProbeFailure(pOut) As %String
{
    Quit $Select($IsObject(pOut): pOut.%Get("error"), 1: pOut)
}

/// <p>AC5: the process's roles, user and namespace read the same after the purge returns, whichever way it ends. The legs, each in a child process, for each log: (a) a principal holding no
/// administrative role purges through the vendor; (b) <code>_SYSTEM</code> purges through a seam that runs the vendor's purge and then changes the process's roles inside the call; (c) the same
/// seam changes them and raises. A principal cannot change its own roles, so (a) holds whether or not the frame gives them back, and (b) and (c) are the legs the frame's removal reddens.</p>
/// <p>Mutation (Rule 19): call <method>OcuPilot.Port.InteropPort.VendorLogPurge</method> in <method>OcuPilot.Port.InteropPort.PerformLogPurge</method> in place of <method>OcuPilot.Port.InteropPort.PurgeFrame</method>
/// -- legs (b) and (c) go red.</p>
Method TestTheProcessRolesAreGivenBackOnSuccessAndOnAnError()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#ROLESPRINCIPAL, ..PreparedPassword)
    Do $$$AssertStatusOK(tSC, "the principal is created")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "GrantSelect", "OcuP2417rRolesRole"), "and holds the SQL SELECT the reads need")
    For tKind = "rule", "process" {
        Set tOld = ..Probe(tKind, ..#SOURCE, 7300, 1)
        Set tOut = $ClassMethod(..#CHILD, "ProbeAs", "OcuP2417rRoles", "roles", tKind)
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tKind _ " (a): the probe ran: " _ ..ProbeFailure(tOut))
        If $IsObject(tOut) && (tOut.%Get("error") = "") {
            Do $$$AssertTrue(tOut.loggedIn, tKind _ " (a): the principal logged in")
            Do $$$AssertEquals(tOut.http, 200, tKind _ " (a): the purge answered 200: " _ tOut.%ToJSON())
            Do $$$AssertTrue(tOut.before '[ "%All", tKind _ " (a): the principal holds no administrative role: " _ tOut.before)
            Do $$$AssertEquals(tOut.after, tOut.before, tKind _ " (a): the process's roles after the call are the roles before it: " _ tOut.before)
            Do $$$AssertTrue(tOut.sameUser && tOut.sameNamespace, tKind _ " (a): and so are its user and namespace")
        }
        Do $$$AssertEquals(..Exists(tKind, ..#SOURCE, tOld), 0, tKind _ " (a): the purge deleted the probe")
        Do $ClassMethod(..#FIXTURE, "DropProbes")
        Do ..Probe(tKind, ..#SOURCE, 7300, 1)
        Set ^IRIS.Temp.OcuProbe2417LogMode = "rolesok"
        Set tOut = $ClassMethod(..#CHILD, "ProbeAs", "_SYSTEM", "roles", tKind, ..#SEAM)
        Do $$$AssertTrue($IsObject(tOut) && (tOut.%Get("error") = ""), tKind _ " (b): the probe as _SYSTEM ran: " _ ..ProbeFailure(tOut))
        If $IsObject(tOut) && (tOut.%Get("error") = "") {
            Do $$$AssertEquals(tOut.http, 200, tKind _ " (b): the purge that changed the roles inside the call answered 200: " _ tOut.%ToJSON())
            Do $$$AssertTrue(tOut.before [ "%All", tKind _ " (b): the process holds the administrative role: " _ tOut.before)
            Do $$$AssertEquals(tOut.after, tOut.before, tKind _ " (b): the process's roles after the call are exactly the roles before it: " _ tOut.before)
            Do $$$AssertTrue($Get(^IRIS.Temp.OcuProbe2417LogMode("inside")) '= tOut.before, tKind _ " (b): and inside the call the process held other roles: " _ $Get(^IRIS.Temp.OcuProbe2417LogMode("inside")))
            Do $$$AssertTrue(tOut.sameUser && tOut.sameNamespace, tKind _ " (b): its user and namespace are the same too")
        }
        Do $ClassMethod(..#FIXTURE, "DropProbes")
        Do ..Probe(tKind, ..#SOURCE, 7300, 1)
        Set ^IRIS.Temp.OcuProbe2417LogMode = "roles"
        Set tOut = $ClassMethod(..#CHILD, "ProbeAs", "_SYSTEM", "roles", tKind, ..#SEAM)
        Do $$$AssertTrue($IsObject(tOut) && (tOut.%Get("error") = ""), tKind _ " (c): the raised-error probe as _SYSTEM ran: " _ ..ProbeFailure(tOut))
        If $IsObject(tOut) && (tOut.%Get("error") = "") {
            Do $$$AssertEquals(tOut.http, 500, tKind _ " (c): the purge that raised answered 500: " _ tOut.%ToJSON())
            Do $$$AssertEquals(tOut.after, tOut.before, tKind _ " (c): the process's roles after the call are exactly the roles before it: " _ tOut.before)
            Do $$$AssertTrue($Get(^IRIS.Temp.OcuProbe2417LogMode("inside")) '= tOut.before, tKind _ " (c): and inside the call the process held other roles: " _ $Get(^IRIS.Temp.OcuProbe2417LogMode("inside")))
        }
        Kill ^IRIS.Temp.OcuProbe2417LogMode
        Do $ClassMethod(..#FIXTURE, "DropProbes")
    }
}

}
