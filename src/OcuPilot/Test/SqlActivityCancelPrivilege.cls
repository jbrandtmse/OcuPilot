/// <p>Pins what the SQL activity cancel asks of the caller beyond the port's pairs (AC1, AD-8, Story 21.20), against a real principal
/// holding exactly <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>, and read and write on <code>USER</code>'s
/// database so that its own probe job can run there: it cancels its own statement without the SQL
/// privilege <code>%CANCEL_QUERY</code>; another user's statement is refused 403 <code>SQLACTIVITY.NOPRIVILEGE</code> with its
/// sentence and keeps running; and with the privilege granted to its role the same cancel succeeds, the statement ending and its
/// process surviving.</p>
/// <p>The cancels run in child processes (<method>OcuPilot.Test.SqlActivityProbe.CancelAs</method>) that log in as the principal, so
/// this process never changes identity.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace and <parameter>PRINCIPALSVARIABLE</parameter> reading
/// <code>1</code>, because it creates a user and a role named <code>OcuP1910CancelPlain*</code> and grants and revokes
/// <code>%CANCEL_QUERY</code> on that role. Every probe job is stopped and the grant revoked after each test, and the principal is
/// removed after the last.</p>
Class OcuPilot.Test.SqlActivityCancelPrivilege Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms its throwaway principal.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.SqlActivityProbe";

Parameter PORT = "OcuPilot.Port.SqlActivityPort";

Parameter NAMESPACE = "USER";

/// <p>The principal, <code>&lt;user&gt;:&lt;the grants it holds beyond the code database's READ&gt;</code>.</p>
Parameter PRINCIPALS = "OcuP1910CancelPlain:%Admin_Operate:U,%DB_IRISSYS:R,%DB_USER:RW";

Parameter USERNAME = "OcuP1910CancelPlain";

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
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlActivityCancelPrivilege creates and deletes users and roles and grants an SQL privilege on this instance and runs on a throwaway container only. " _ ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP2120Cancel" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $ClassMethod(..#PROBE, "EnsurePrincipals", ..#PRINCIPALS, ..PreparedPassword)
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "StopAll")
    Set tSC = $$$ADDSC(tSC, ..Revoke())
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipals", ..#PRINCIPALS))
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK(..Revoke(), "the SQL privilege is revoked from the principal's role")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "StopAll"), "every probe job is stopped")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Running"), 0, "and none is left running")
    Quit $$$OK
}

/// <p>Grant <code>%CANCEL_QUERY</code> to the principal's role.</p>
Method Grant() As %Status
{
    Quit ..Sql("GRANT %CANCEL_QUERY TO " _ ..#USERNAME _ "Role")
}

/// <p>Revoke <code>%CANCEL_QUERY</code> from the principal's role, and the table privilege its own probe statement needs; a role that
/// never held either is no failure.</p>
Method Revoke() As %Status
{
    Do ..Sql("REVOKE %CANCEL_QUERY FROM " _ ..#USERNAME _ "Role")
    Do ..Sql("REVOKE SELECT ON %Dictionary.CompiledClass FROM " _ ..#USERNAME _ "Role", ..#NAMESPACE)
    Quit $$$OK
}

/// <p>Run the SQL statement <var>pText</var> in <var>pNamespace</var>, this process's own by default, restoring the namespace.</p>
Method Sql(pText As %String, pNamespace As %String = {$NAMESPACE}) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pText)
        If tRS.%SQLCODE < 0 Set tSC = $$$ERROR($$$GeneralError, "SQLCODE " _ tRS.%SQLCODE _ ": " _ tRS.%Message)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Run <var>pMethod</var> of the probe in a child process with <var>pArgs</var> and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
Method Child(pMethod As %String, pArg As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        If pMethod = "CancelAs" {
            Job ##class(OcuPilot.Test.SqlActivityProbe).CancelAs($Job, ..#USERNAME, pArg)::10
        } Else {
            Job ##class(OcuPilot.Test.SqlActivityProbe).OwnCancelAs($Job, ..#USERNAME, ..#NAMESPACE)::10
        }
        If '$Test {
            Do tOut.%Set("error", "the child process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 90)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the child process signalled nothing within 90 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Whether the probe job <var>pPid</var> still runs its statement.</p>
ClassMethod Listed(pPid As %Integer) As %Boolean
{
    Quit $ClassMethod(..#PROBE, "Listed", pPid)
}

/// <p>Wait up to <var>pSeconds</var> for probe job <var>pPid</var>'s statement to stop being listed.</p>
ClassMethod Ended(pPid As %Integer, pSeconds As %Integer) As %Boolean
{
    Set tEnd = $ZHorolog + pSeconds
    While $ZHorolog < tEnd {
        If '..Listed(pPid) Quit
        Hang 0.25
    }
    Quit '..Listed(pPid)
}

/// <p>A probe statement of the suite's own account, in <code>USER</code>, that outlives its statement; its pid and composite id.</p>
Method StartProbe(Output pPid As %Integer, Output pId As %String) As %Status
{
    Set pId = ""
    Set tSC = $ClassMethod(..#PROBE, "Start", ..#NAMESPACE, "OcuSeedCancelPriv2120" _ (10000000 + $Random(90000000)), "OcuSecretPriv2120" _ (10000000 + $Random(90000000)), .pPid, 0, 1)
    If $$$ISERR(tSC) Quit tSC
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", "CurrentStatements", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("ProcessID") = pPid Set pId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tRow.%Get("Server"), tRow.%Get("ProcessID"), tRow.%Get("StatementHash")))
    }
    If pId = "" Quit $$$ERROR($$$GeneralError, "the list does not report the probe job " _ pPid)
    Quit $$$OK
}

/// <p><b>AC1.</b> The principal cancels its own statement with no SQL privilege, and its process survives.</p>
/// <p>Mutation (Rule 19): refuse a cancel the caller holds no privilege for before the vendor is called -> this goes red.</p>
Method TestAPrincipalCancelsItsOwnStatementWithoutThePrivilege()
{
    Do $$$AssertStatusOK(..Sql("GRANT SELECT ON %Dictionary.CompiledClass TO " _ ..#USERNAME _ "Role", ..#NAMESPACE), "the principal's role may run the probe statement, which reads a dictionary table")
    Set tOut = ..Child("OwnCancelAs", "")
    Do $$$AssertEquals(tOut.%Get("error"), "", "the child process ran: " _ $Select(tOut.%Get("error") '= "": tOut.%Get("error"), 1: "ok"))
    Do $$$AssertEquals(tOut.%Get("loggedIn") _ "|" _ tOut.%Get("http"), "1|200", "the principal's cancel of its own statement succeeds")
    Do $$$AssertEquals(..Ended(tOut.%Get("pid"), 10), 1, "its statement stops")
    Do $$$AssertTrue($Data(^$JOB(tOut.%Get("pid"))) > 0, "and its process still runs")
}

/// <p><b>AC1.</b> Another user's statement is refused 403 <code>SQLACTIVITY.NOPRIVILEGE</code> with its sentence and keeps
/// running; with <code>%CANCEL_QUERY</code> granted to the principal's role the same cancel succeeds, the statement ends and its
/// process survives.</p>
/// <p>Mutation (Rule 19): map the vendor's #5521 to 500 in <method>OcuPilot.Port.SqlActivityPort.Statement</method> -> the refusal leg
/// goes red.</p>
Method TestAnotherUsersStatementNeedsThePrivilege()
{
    Do $$$AssertStatusOK(..StartProbe(.tPid, .tId), "a probe statement of the suite's account runs")
    Set tOut = ..Child("CancelAs", tId)
    Do $$$AssertEquals(tOut.%Get("error"), "", "the child process ran: " _ $Select(tOut.%Get("error") '= "": tOut.%Get("error"), 1: "ok"))
    Do $$$AssertEquals(tOut.%Get("loggedIn") _ "|" _ tOut.%Get("http") _ "|" _ tOut.%Get("code"), "1|403|SQLACTIVITY.NOPRIVILEGE", "another user's statement is refused 403 SQLACTIVITY.NOPRIVILEGE")
    Do $$$AssertEquals(tOut.%Get("reason"), $Parameter("OcuPilot.Api.SqlActivityError", "REASONNOPRIVILEGE"), "with its sentence")
    Do $$$AssertEquals(..Listed(tPid), 1, "and the statement keeps running")
    Do $$$AssertStatusOK(..Grant(), "%CANCEL_QUERY is granted to the principal's role")
    Set tGranted = ..Child("CancelAs", tId)
    Do $$$AssertEquals(tGranted.%Get("loggedIn") _ "|" _ tGranted.%Get("http"), "1|200", "with the privilege the same cancel succeeds: " _ tGranted.%Get("error"))
    Do $$$AssertEquals(..Ended(tPid, 10), 1, "the statement ends")
    Do $$$AssertTrue($Data(^$JOB(tPid)) > 0, "and its process still runs")
}

}
