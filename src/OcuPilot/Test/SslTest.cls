/// <p>Pins Story 9.5's Test connection (AC4, AD-11, AD-39's named exception): <code>POST
/// /ssl/:id/test</code> over a real request answers the instance's own result lines, pass or fail,
/// at 200; a host or port that is not one is 422 on its field and a configuration the instance does
/// not hold is 404 <code>SSL.NAME.ABSENT</code>; no agent tool issues it; and a failed test's text
/// reaches no server-side sink -- no <code>messages.log</code> line, audit row or ledger row.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving on the container's
/// own web port 52773, an account holding <code>%Admin_Secure</code>, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes a
/// probe SSL/TLS configuration by exact name. <method>OnBeforeAllTests</method> refuses anywhere it
/// does not.</p>
Class OcuPilot.Test.SslTest Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SSL_CONFIG";

Parameter PROBE = "OcuPilotProbeSslTest";

Parameter PROBEMARKER = "OcuPilot SSL test probe";

/// <p>The instance's own plain-HTTP web port inside the container: a TLS handshake there fails with
/// the vendor's "wrong version number" line, measured on this build.</p>
Parameter PLAINPORT As %Integer = 52773;

/// <p>The words of that failure line the assertions look for.</p>
Parameter FAILUREMARK = "wrong version number";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SslTest creates and deletes an SSL/TLS configuration on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ..EnsureProbe()
}

Method OnAfterAllTests() As %Status
{
    Quit ..RemoveProbe()
}

/// <p>AC4: a test that cannot connect answers 200 <code>{passed: false, lines}</code>, the lines the
/// vendor's own error text -- here the handshake against a plain-HTTP port.</p>
/// <p>Mutation (Rule 19): answer the ordinary fault for a <code>TEST</code> in
/// <method>OcuPilot.Port.AdminPort.Invoke</method> -- the route answers 500 and this goes red.</p>
Method TestAFailedTestAnswersTheInstancesOwnLines()
{
    Set tSC = ..Send(..#PROBE, {"Host": "localhost", "Port": (..#PLAINPORT)}, .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "at 200")
    Do $$$AssertEquals($Select($IsObject($Get(tAnswer)): tAnswer.%Get("passed"), 1: ""), 0, "reporting that it did not connect")
    Set tLines = $Select($IsObject($Get(tAnswer)): tAnswer.%Get("lines"), 1: "")
    Do $$$AssertTrue($IsObject(tLines) && (tLines.%Size() > 0), "with at least one line")
    Do $$$AssertTrue($IsObject(tLines) && (tLines.%ToJSON() [ ..#FAILUREMARK), "among them the vendor's own: " _ $Select($IsObject(tLines): tLines.%ToJSON(), 1: ""))
}

/// <p>A host or port that is not one is 422 on its field, and a configuration the instance does not
/// hold is 404 <code>SSL.NAME.ABSENT</code>; nothing is tested in either case.</p>
Method TestTheHostPortAndNameAreRefused()
{
    For tCase = $ListBuild("{""Host"":""https://x"",""Port"":443}", "Host", "SSLTESTHOST"), $ListBuild("{""Host"":""a b"",""Port"":443}", "Host", "SSLTESTHOST"), $ListBuild("{""Host"":""localhost"",""Port"":0}", "Port", "SSLTESTPORT"), $ListBuild("{""Host"":""localhost"",""Port"":65536}", "Port", "SSLTESTPORT"), $ListBuild("{""Host"":""localhost"",""Port"":""x""}", "Port", "SSLTESTPORT") {
        Set tSC = ..Send(..#PROBE, ##class(%DynamicObject).%FromJSON($List(tCase, 1)), .tStatus, .tAnswer)
        Set tRow = $Select($IsObject($Get(tAnswer)) && (tAnswer.%GetTypeOf("detail") = "object"): tAnswer.detail.violations.%Get(0), 1: "")
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tRow): tRow.field _ " " _ tRow.code, 1: ""), "422 " _ $List(tCase, 2) _ " " _ $Parameter("OcuPilot.Api.Error", $List(tCase, 3)), $List(tCase, 1) _ " is refused on its field")
    }
    Set tSC = ..Send("OcuPilotProbeSslTestGone", {"Host": "localhost", "Port": (..#PLAINPORT)}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "404 " _ ##class(OcuPilot.Api.Error).#SSLNAMEABSENT, "an absent configuration is 404 on its own code")
}

/// <p>AD-39's named exception, AD-11: Test connection is the screen's alone -- no registered tool
/// issues it -- and a failed test's text reaches no server-side sink: no <code>messages.log</code>
/// line, no audit row and no ledger row written meanwhile carries it.</p>
/// <p>Named to run first in the class: the instance holds a line identical to the one a process
/// logged last until that process logs a different one, so a failure line logged by an earlier test
/// here would hold this test's own out of the scan.</p>
/// <p>Mutation (Rule 19): log the vendor status in
/// <method>OcuPilot.Port.AdminPort.TestOutcome</method>'s failure branch -- the
/// <code>messages.log</code> leg goes red.</p>
Method TestAAFailuresTextReachesNoToolLogAuditOrLedger()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tool registry lists")
    Set tReaches = ""
    Set tWrites = 0
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tClass = tTool.%Get("class")
        If tTool.%Get("kind") '= "write" Continue
        Set tWrites = tWrites + 1
        If $ClassMethod(tClass, "WriteType") = "TEST" Set tReaches = tReaches _ $ListBuild(tTool.%Get("name"))
        If $ClassMethod(tClass, "ReadType") = "TEST" Set tReaches = tReaches _ $ListBuild(tTool.%Get("name"))
    }
    Do $$$AssertTrue(tWrites > 0, "the registry lists write tools to look through")
    Do $$$AssertEquals($ListToString(tReaches), "", "and none of them issues a test")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsConnectionTest("Security.SSLConfig", "TEST"), "the port admits the test as a connection test")
    Do $$$AssertTrue('##class(OcuPilot.Port.AdminPort).IsMutating("Security.SSLConfig", "TEST"), "never as a write")

    Set tOffset = ##class(OcuPilot.Test.SslSinks).LogOffset()
    Set tMark = ##class(OcuPilot.Test.SslSinks).AuditMark()
    Set tSC = ..Send(..#PROBE, {"Host": "localhost", "Port": (..#PLAINPORT)}, .tStatus, .tAnswer)
    Do $$$AssertTrue($IsObject($Get(tAnswer)) && (tAnswer.%ToJSON() [ ..#FAILUREMARK), "the failed test answered its text to the caller")
    Do $$$AssertTrue(##class(OcuPilot.Test.SslSinks).Flush(tOffset), "messages.log is written up to a line logged after the test")
    Do $$$AssertEquals(##class(OcuPilot.Test.SslSinks).LogSince(tOffset) [ ..#FAILUREMARK, 0, "no messages.log line written meanwhile carries it")
    Do $$$AssertEquals(##class(OcuPilot.Test.SslSinks).AuditSince(tMark) [ ..#FAILUREMARK, 0, "nor any audit row")
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE Arguments LIKE ? OR Code LIKE ? OR Target LIKE ?", "%" _ ..#FAILUREMARK _ "%", "%" _ ..#FAILUREMARK _ "%", "%" _ ..#FAILUREMARK _ "%")
    Do $$$AssertTrue(tResult.%Next(), "the ledger is read")
    Do $$$AssertEquals(tResult.%GetData(1), 0, "nor any ledger row")
}

/// <p>POST the test route for <var>pName</var> with <var>pBody</var> as the suite's HTTP account.</p>
ClassMethod Send(pName As %String, pBody As %DynamicObject, Output pStatus As %Integer, Output pAnswer) As %Status
{
    Quit ##class(OcuPilot.Test.Http).MakeRequest("POST", "/ssl/" _ ##class(OcuPilot.Kernel.EntityId).Encode(pName) _ "/test", .pStatus, .pAnswer, pBody.%ToJSON(), "application/json")
}

/// <p>Create the probe client afresh: removed first when it is this class's own, refused when a
/// configuration of that name is anybody else's.</p>
Method EnsureProbe() As %Status
{
    Set tSC = ..RemoveProbe()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProps("Type") = 0
        Set tProps("VerifyPeer") = 0
        Set tProps("Enabled") = 1
        Set tProps("Description") = ..#PROBEMARKER
        Set tSC = ##class(Security.SSLConfigs).Create(..#PROBE, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the probe when its description says it is this class's own; a configuration of that
/// name that is anybody else's is an error and is left alone.</p>
Method RemoveProbe() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.SSLConfigs).Exists(..#PROBE, .tConfig) {
            If $Extract(tConfig.Description, 1, $Length(..#PROBEMARKER)) '= ..#PROBEMARKER {
                Set tSC = $$$ERROR($$$GeneralError, "the SSL/TLS configuration " _ ..#PROBE _ " is not this class's own, so it was left alone")
            } Else {
                Set tConfig = ""
                Set tSC = ##class(Security.SSLConfigs).Delete(..#PROBE)
            }
        }
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
