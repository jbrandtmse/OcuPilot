/// <p>Pins how <method>OcuPilot.Port.AdminPort.Fail</method> answers and logs a refusal the vendor makes (AD-2, Story 18.47):
/// a 404 carrying the vendor's Access Denied (#822) is 403 <code>PORT.ACCESSDENIED</code>, logged, where a 404 without it is
/// <code>PORT.NOTFOUND</code> for a read and unlogged; an <code>UNLOGGEDREFUSALS</code> entry ending <code>/#&lt;code&gt;</code>
/// leaves its code alone unlogged and every other code of that endpoint, type and status logged; and a SQL privilege refusal the
/// port maps by SQLCODE logs nothing.</p>
/// <p>It runs through <class>OcuPilot.Test.PortFixture</class>, so a log line lands in <class>OcuPilot.Test.LogProbe</class>'s
/// capture and <code>messages.log</code> is untouched. <b>What it needs from the environment:</b> OcuPilot installed, and an
/// account holding <code>%All</code>; it creates nothing, and the one vendor call it makes is a grant on an object the
/// instance does not hold, which the vendor refuses.</p>
Class OcuPilot.Test.AdminPortRefusals Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Test.PortFixture";

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

/// <p>Fail for <var>pEndpoint</var>'s <var>pType</var> with <var>pVendorSC</var> answered at <var>pHttp</var> and answer
/// <code>status code logged</code> as one text; <var>logged</var> is 1 when a line reached the capture.</p>
Method Outcome(pEndpoint As %String, pType As %String, pHttp As %Integer, pVendorSC As %Status, pRead As %Boolean) As %String
{
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Set tSC = $ClassMethod(..#PORT, "FailWith", pEndpoint, pType, pHttp, pVendorSC, pRead, .tHttp, .tFault)
    Quit tHttp _ " " _ tFault.code _ " " _ (##class(OcuPilot.Test.LogProbe).Captured("message") '= "")
}

/// <p>Whether <method>OcuPilot.Port.AdminPort.Fail</method> logs the outcome <var>pVendorSC</var> answered at
/// <var>pHttp</var> to a write of type <var>pType</var> on <var>pEndpoint</var>: <code>1</code> or <code>0</code>.</p>
Method Logged(pEndpoint As %String, pType As %String, pHttp As %Integer, pVendorSC As %Status) As %Boolean
{
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Set tSC = $ClassMethod(..#PORT, "FailWith", pEndpoint, pType, pHttp, pVendorSC, 0, .tHttp, .tFault)
    Quit (##class(OcuPilot.Test.LogProbe).Captured("message") '= "")
}

/// <p>DW-2167: a read answered 404 whose status carries #822 is 403 <code>PORT.ACCESSDENIED</code> and logged; a read answered
/// 404 without it is <code>PORT.NOTFOUND</code> and unlogged; a write answered 404 stays logged either way.</p>
/// <p>Mutation (Rule 19): drop the #822 remap from <method>OcuPilot.Port.AdminPort.Fail</method> -- the first leg goes red.</p>
Method TestAnAccessDeniedUnderA404IsARefusalAndLogged()
{
    Set tDenied = $$$ERROR(822)
    Set tOther = $$$ERROR($$$GeneralError, "not there")
    Do $$$AssertEquals(..Outcome("Security.LDAP", "GET", 404, tDenied, 1), "403 PORT.ACCESSDENIED 1", "a read refused for the caller reads as a refusal, logged")
    Do $$$AssertEquals(..Outcome("Security.LDAP", "GET", 404, tOther, 1), "404 PORT.NOTFOUND 0", "a read answered 404 without #822 is an absence, unlogged")
    Do $$$AssertEquals(..Outcome("Security.LDAP", "GET", 404, $$$OK, 1), "404 PORT.NOTFOUND 0", "and one carrying no error status too")
    Do $$$AssertEquals(..Outcome("Security.LDAP", "PUT", 404, tOther, 0), "404 PORT.NOTFOUND 1", "a write answered 404 stays logged")
    Do $$$AssertEquals(..Outcome("Security.LDAP", "GET", 500, tDenied, 1), "500 PORT.ACCESSDENIED 1", "and #822 under another status keeps that status")
}

/// <p>DW-2007: <code>ECP.DataServer/PUT/500/#1454</code> and <code>Security.MFT/DELETE/500/#5809</code> are answers, not faults:
/// unlogged for their own code and logged for any other code on the same endpoint, type and status, for the same code on another
/// type or status, and for a status that carries no code. The unscoped entries keep matching every answer.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AdminPort.IsUnloggedRefusal</method> ignore the code (match on the
/// endpoint, type and status of a <code>/#</code> entry alone) -- the other-code legs go red; drop the two entries from
/// <parameter>OcuPilot.Port.AdminPort.UNLOGGEDREFUSALS</parameter> -- the unlogged legs go red.</p>
Method TestACodeScopedEntryUnlogsItsCodeAlone()
{
    Set tPort = "OcuPilot.Port.AdminPort"
    Do $$$AssertEquals(..Logged("ECP.DataServer", "PUT", 500, $$$ERROR(1454, "x")), 0, "a data server saved with SSL/TLS and no %ECPClient is unlogged")
    Do $$$AssertEquals(..Logged("ECP.DataServer", "PUT", 500, $$$ERROR(1455, "x")), 1, "another code on that endpoint, type and status is logged")
    Do $$$AssertEquals(..Logged("ECP.DataServer", "PUT", 500, $$$ERROR($$$GeneralError, "x")), 1, "so is one that carries only the general error")
    Do $$$AssertEquals(..Logged("ECP.DataServer", "DELETE", 500, $$$ERROR(1454, "x")), 1, "the same code on another type is logged")
    Do $$$AssertEquals(..Logged("ECP.DataServer", "PUT", 400, $$$ERROR(1454, "x")), 1, "and on another status")
    Do $$$AssertEquals(..Logged("Security.MFT", "DELETE", 500, $$$ERROR(5809, "x")), 0, "a connection deleted whose OAuth 2.0 client is absent is unlogged")
    Do $$$AssertEquals(..Logged("Security.MFT", "DELETE", 500, $$$ERROR(5810, "x")), 1, "another code on it is logged")
    Do $$$AssertEquals(..Logged("Lock", "DELETE", 409, $$$ERROR($$$GeneralError, "x")), 0, "an entry without a code still matches every answer")
    Do $$$AssertEquals(..Logged("Security.Superserver", "PUT", 500, $$$ERROR($$$GeneralError, "x")), 1, "and the superserver's general error stays logged")
    Do $$$AssertEquals($ClassMethod(tPort, "IsUnloggedRefusal", "ECP.DataServer", "PUT", 500, $$$ERROR(1454, "x")) _ $ClassMethod(tPort, "IsUnloggedRefusal", "ECP.DataServer", "PUT", 500) _ $ClassMethod(tPort, "IsUnloggedRefusal", "ECP.DataServer", "PUT", 500, $$$OK), "100", "a code-scoped entry needs the status that carries the code")
}

/// <p>DW-2427, DW-2429: the encryption key file's field refusals -- no readable key (#5022 on a key list), a wrong
/// administrator password (#1219 on an added key and on an activation) and an administrator the file does not list (#1204)
/// -- and the startup settings' refusals (#1217, #1231, #1233 on a settings write) are answers: unlogged for their
/// own code at their own endpoint, type and status, and logged for any other code, for the same code on another type
/// and for the same code on another status.</p>
/// <p>Mutation (Rule 19): drop any one of the seven entries from <parameter>OcuPilot.Port.AdminPort.UNLOGGEDREFUSALS</parameter>
/// -- its unlogged leg goes red.</p>
Method TestTheEncryptionRefusalsAreUnloggedForTheirOwnCodeAlone()
{
    For tCase = $ListBuild("Security.Encryption.KeyInFile", "LIST", 5022, "POST"), $ListBuild("Security.Encryption.KeyInFile", "POST", 1219, "DELETE"), $ListBuild("Security.Encryption.File", "ACTIVATE", 1219, "POST"), $ListBuild("Security.Encryption.KeyInFile", "POST", 1204, "DELETE"), $ListBuild("Security.Encryption.Settings", "PUT", 1217, "GET"), $ListBuild("Security.Encryption.Settings", "PUT", 1231, "GET"), $ListBuild("Security.Encryption.Settings", "PUT", 1233, "GET") {
        Set tEndpoint = $List(tCase, 1)
        Set tType = $List(tCase, 2)
        Set tCode = $List(tCase, 3)
        Set tNamed = tEndpoint _ "/" _ tType _ " #" _ tCode
        Do $$$AssertEquals(..Logged(tEndpoint, tType, 500, $$$ERROR(tCode, "x")), 0, tNamed _ " is unlogged")
        Do $$$AssertEquals(..Logged(tEndpoint, tType, 500, $$$ERROR(tCode + 1, "x")), 1, tNamed _ ": another code on that endpoint, type and status is logged")
        Do $$$AssertEquals(..Logged(tEndpoint, $List(tCase, 4), 500, $$$ERROR(tCode, "x")), 1, tNamed _ ": the same code on another type is logged")
        Do $$$AssertEquals(..Logged(tEndpoint, tType, 400, $$$ERROR(tCode, "x")), 1, tNamed _ ": and on another status")
    }
    Do $$$AssertEquals(..Logged("Security.Encryption.File", "POST", 500, $$$ERROR(1219, "x")), 1, "a key file create refused with #1219 is logged: only the activation's is listed")
    Do $$$AssertEquals(..Logged("Security.Encryption.Settings", "PUT", 500, $$$ERROR(1212, "x")), 1, "and #1212 on a settings write is logged")
}

/// <p>DW-2007: a SQL privilege refusal mapped by its SQLCODE (a grant on an object the instance does not hold, SQLCODE -30,
/// answered 404 <code>SQLPRIV.NOOBJECT</code>) is a named answer: nothing reaches the log.</p>
/// <p>Mutation (Rule 19): restore the log line to the SQLCODE-mapped branch of <method>OcuPilot.Port.AdminPort.Invoke</method>
/// -- the capture holds a line and this goes red.</p>
Method TestASqlCodeMappedRefusalLogsNothing()
{
    Kill tQuery
    Set tQuery("grantee") = "_SYSTEM"
    Set tQuery("namespace") = "USER"
    Set tQuery("type") = "TABLE"
    Set tQuery("object") = "OcuPilotNoSuchSchema1847.T"
    Set tQuery("action") = "SELECT"
    Set tQuery("withGrant") = 0
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Security.SQLPrivilege.Standard", "GRANT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the grant on an object the instance does not hold is refused")
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404 SQLPRIV.NOOBJECT", "as the named refusal the SQLCODE maps to")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and logs nothing")
}

}
