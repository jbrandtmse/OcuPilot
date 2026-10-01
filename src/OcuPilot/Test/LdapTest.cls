/// <p>Pins the LDAP editor's Test authentication (AD-26, AD-35, AD-39): <code>POST /ldap/:id/test</code>
/// runs the vendor's <code>Security.LDAP</code> <code>TEST</code> in process and answers
/// <code>{lines}</code>, the instance's own console lines, with no verdict; it queues nothing, so the
/// vendor's async task table gains no row, the tested password is found in none of that table's
/// globals, the application error log or <code>messages.log</code>, and neither log gains a line of
/// the output; and it refuses an empty user name
/// or password, a user name with a domain, a short name, an absent configuration and a caller without
/// the form's pairs, each before the vendor is reached.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the test principal
/// holding <code>%All</code>, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PRINCIPALSVARIABLE</parameter> reading <code>1</code>: it creates and deletes one
/// <code>ocup99*</code> LDAP configuration per test, pointing at <code>127.0.0.1:1</code>, where no
/// LDAP server answers, and one throwaway principal; any async task row a test leaves is deleted as an
/// object. Each test of authentication takes about five seconds, the vendor's own wait. Every
/// password is synthetic and is never written to an assertion message.</p>
Class OcuPilot.Test.LdapTest Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's LDAP writes.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

/// <p>The environment variable that arms its throwaway principal.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ServiceLdapProbe";

Parameter FIXTURE = "OcuPilot.Test.PortFixture";

/// <p>The probe configuration every test tests against, an enabled one whose host refuses.</p>
Parameter NAME = "ocup99test.invalid";

Parameter HOST = "127.0.0.1:1";

Parameter TESTPATH = "/ldap/:id/test";

/// <p>A principal holding the form's second pair and not its first, with
/// <code>%Admin_Operate:USE</code> so it clears the API's administrative floor.</p>
Parameter LACKINGUSER = "OcuPilotWire99LdapTest";

Parameter LACKINGROLE = "OcuPilotWire99LdapTestRole";

/// <p>The vendor's last line of a completed test (measured).</p>
Parameter COMPLETED = "Test completed";

/// <p>The start of the vendor's line naming the configuration a test uses, followed by its name
/// (measured).</p>
Parameter CONFIGURATIONLINE = "Authenticating using LDAP Configuration ";

/// <p>The throwaway principal's password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The async task rows that existed before the running test.</p>
Property PreparedTasks As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedTasks = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LdapTest creates and deletes LDAP configurations, a user and a role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PRINCIPALSVARIABLE _ " must both read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll")
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = "OcuPilotLdapTest" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $ClassMethod(..#PROBE, "EnsurePrincipal", ..#LACKINGUSER, ..#LACKINGROLE, "%Admin_Operate:U,%DB_IRISSYS:R", ..PreparedPassword)
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedTasks = $ClassMethod(..#FIXTURE, "TaskGuids")
    Quit $ClassMethod(..#PROBE, "CreateLdap", ..#NAME, 72, ..#HOST)
}

/// <p>Deletes, as objects, any async task row the test left, and every probe configuration.</p>
Method OnAfterOneTest() As %Status
{
    Set tLeft = ..NewTasks()
    For tI = 1:1:$ListLength(tLeft) {
        Do $ClassMethod(..#FIXTURE, "RemoveTaskRow", $List(tLeft, tI))
    }
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll")
    Do $$$AssertStatusOK(tSC, "every probe configuration is removed")
    Do $$$AssertEquals(##class(OcuPilot.Test.LdapCreate).Residue(), "", "and no ocup99 configuration remains")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipal", ..#LACKINGUSER, ..#LACKINGROLE))
}

/// <p>AC2, AC3, AC4: the test answers 200 <code>{lines}</code> -- the instance's own lines, the
/// unreachable host's refusal and the completed line among them, and no <code>passed</code>; the
/// vendor's async task table gains no row; the password is in none of that table's globals, the
/// application error log or <code>messages.log</code>, nor in the answer; and the lines are logged
/// nowhere: the count of the run's configuration line in <code>messages.log</code> and in today's
/// application error log is the same after the test as before it.</p>
/// <p>Mutations (Rule 19): <method>OcuPilot.Port.AdminPort.Sequence</method> hands the pair to the
/// queue -- the no-row and lines legs go red; <method>OcuPilot.Port.AdminPort.TestOutcome</method> drops
/// the captured lines -- the lines legs go red; it passes them to
/// <method>OcuPilot.Port.AdminPort.LogFault</method> -- the configuration line's
/// <code>messages.log</code> leg goes red.</p>
Method TestTheTestAnswersTheInstancesLinesAndKeepsNothing()
{
    Set tPassword = ..Secret("lines")
    Set tLine = ..#CONFIGURATIONLINE _ ..#NAME
    Set tLogBefore = ..LogCount(tLine)
    Set tErrorsBefore = ..ErrorsCount(tLine)
    Set tSC = ..PostTest(..#NAME, {"Username": "ocup99user", "Password": (tPassword)}.%ToJSON(), .tStatus, .tRaw, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the test answers 200")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Set tLines = $Select($IsObject($Get(tAnswer)) && (tAnswer.%GetTypeOf("lines") = "array"): tAnswer.%Get("lines"), 1: "")
    Do $$$AssertTrue($IsObject(tLines) && (tLines.%Size() > 0), "with the instance's lines")
    Do $$$AssertTrue(..Holds(tLines, ..#COMPLETED), "the last of them the vendor's completed line")
    Do $$$AssertTrue(..Holds(tLines, "Can't contact LDAP server"), "and the unreachable host's refusal among them")
    Do $$$AssertEquals($Select($IsObject($Get(tAnswer)): tAnswer.%GetTypeOf("passed"), 1: ""), "unassigned", "carrying no verdict")
    Do $$$AssertEquals($Get(tRaw) [ tPassword, 0, "and not the password")
    Do $$$AssertEquals($ListLength(..NewTasks()), 0, "the vendor's async task table gains no row")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TaskGlobalsCarry", tPassword), 0, "and its globals carry no password")
    Do $$$AssertEquals(..ErrorsCarry(tPassword), 0, "the application error log carries none")
    Do $$$AssertEquals(..LogCarries(tPassword), 0, "and messages.log carries none")
    Do $$$AssertTrue(..Holds(tLines, tLine), "the lines name the configuration tested")
    Do $$$AssertTrue((tLogBefore >= 0) && (tErrorsBefore >= 0), "messages.log and the application error log are read")
    Do $$$AssertEquals(..LogCount(tLine), tLogBefore, "messages.log gains no line of the test's output")
    Do $$$AssertEquals(..ErrorsCount(tLine), tErrorsBefore, "and neither does today's application error log")
}

/// <p>AC2 on the port: the pair is a connection test whose outcome is its console, and a call run
/// through the port answers the lines with no async task row, so the vendor's queue, which writes the
/// body into its task row, is never reached.</p>
Method TestThePortRunsTheTestInProcess()
{
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).IsConnectionTest("Security.LDAP", "TEST") _ " " _ ##class(OcuPilot.Port.AdminPort).IsConsoleTest("Security.LDAP", "TEST"), "1 1", "the port admits the test as a connection test answered by its console")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).IsMutating("Security.LDAP", "TEST"), 0, "and never as a write")
    Set tPassword = ..Secret("port")
    Set tBody = {}
    Do tBody.%Set("Username", "ocup99user@" _ ..#NAME, "string")
    Do tBody.%Set("Password", tPassword, "string")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.LDAP", "TEST", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Set tBody = ""
    Do $$$AssertEquals(tHttp, 200, "the port answers 200")
    Do $$$AssertTrue($IsObject($Get(tResult)) && ..Holds(tResult.%Get("lines"), ..#COMPLETED), "with the console lines, which only a run in this process yields")
    Do $$$AssertEquals($ListLength(..NewTasks()), 0, "and no async task row")
}

/// <p>AC8, AC11, AD-13: an empty user name or password and a user name with a domain are 422 on their
/// field; a short name is 422 <code>LDAP.NAME.FORM</code>; an absent configuration is 404
/// <code>LDAP.ABSENT</code>; a caller lacking the form's <code>%Admin_Secure:USE</code> is 403 naming
/// it; none of them reaches the vendor, so no async task row is made.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.LdapRules.Test</method> skips the
/// <code>@</code> check -- the domain leg answers 200 and goes red.</p>
Method TestTheTestRefusesBeforeSending()
{
    For tCase = $ListBuild({"Username": "", "Password": "x"}.%ToJSON(), "422 Username LDAP.TEST.REQUIRED"), $ListBuild({"Username": "ocup99user", "Password": ""}.%ToJSON(), "422 Password LDAP.TEST.REQUIRED"), $ListBuild({"Username": "ocup99user@example.com", "Password": "x"}.%ToJSON(), "422 Username LDAP.TEST.USERNAME") {
        Set tSC = ..PostTest(..#NAME, $List(tCase, 1), .tStatus, .tRaw, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LdapEdit).FirstViolation($Get(tAnswer)), $List(tCase, 2), $List(tCase, 2) _ " is refused")
    }
    Set tSC = ..PostTest("OcuP99Test", {"Username": "ocup99user", "Password": "x"}.%ToJSON(), .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LdapEdit).FirstViolation($Get(tAnswer)), "422 Name LDAP.NAME.FORM", "a short name is refused")
    Set tSC = ..PostTest("ocup99nosuch.invalid", {"Username": "ocup99user", "Password": "x"}.%ToJSON(), .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "404 LDAP.ABSENT", "an absent configuration is 404")
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ $Replace(..#TESTPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(..#NAME))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tPath, ..#LACKINGUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders, "{""Username"":""ocup99user"",""Password"":""x""}", "application/json")
    Set tDenied = ""
    Try { Set tDenied = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tDenied) && (tDenied.%GetTypeOf("detail") = "object"): tDenied.%Get("code") _ " " _ tDenied.%Get("detail").%Get("failedPair"), 1: $Get(tText)), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE", "a caller without the form's pairs is refused naming the pair")
    Do $$$AssertEquals($ListLength(..NewTasks()), 0, "and none of them made an async task row")
}

/// <p>Post the test of authentication for configuration <var>pName</var> with the JSON body
/// <var>pBody</var> as the test principal, with the raw answer in <var>pRaw</var>, its parse in
/// <var>pAnswer</var> and the response headers in <var>pHeaders</var>.</p>
Method PostTest(pName As %String, pBody As %String, Output pStatus As %Integer, Output pRaw As %String, Output pAnswer As %DynamicObject, Output pHeaders) As %Status
{
    Set pAnswer = ""
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ $Replace(..#TESTPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pName))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pRaw, .pHeaders, pBody, "application/json")
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON($Get(pRaw)) } Catch { Set pAnswer = "" }
    Quit tSC
}

/// <p>The async task rows that exist now and did not before the running test.</p>
Method NewTasks() As %List
{
    Set tNow = $ClassMethod(..#FIXTURE, "TaskGuids")
    Set tNew = ""
    For tI = 1:1:$ListLength(tNow) {
        If '$ListFind(..PreparedTasks, $List(tNow, tI)) Set tNew = tNew _ $ListBuild($List(tNow, tI))
    }
    Quit tNew
}

/// <p>Whether one of <var>pLines</var> contains <var>pText</var>.</p>
ClassMethod Holds(pLines, pText As %String) As %Boolean
{
    If '$IsObject(pLines) Quit 0
    Set tHolds = 0
    Set tIterator = pLines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If tLine [ pText Set tHolds = 1
    }
    Quit tHolds
}

/// <p>Whether today's application error log, in this namespace or <code>%SYS</code>, carries
/// <var>pText</var> in a subscript or a value.</p>
ClassMethod ErrorsCarry(pText As %String) As %Boolean
{
    Set tCarries = 0
    Set tOrigNS = $NAMESPACE
    Try {
        For tNamespace = tOrigNS, "%SYS" {
            Set $NAMESPACE = tNamespace
            Set tDay = +$Horolog
            Set tNode = $Name(^ERRORS(tDay))
            For {
                Set tNode = $Query(@tNode)
                If (tNode = "") || ($QSubscript(tNode, 1) '= tDay) Quit
                If (tNode [ pText) || ($Get(@tNode) [ pText) Set tCarries = 1 Quit
            }
            If tCarries Quit
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCarries = 1
    }
    Quit tCarries
}

/// <p>How many nodes of today's application error log, in this namespace and <code>%SYS</code>,
/// carry <var>pText</var> in a subscript or a value; <code>-1</code> when the log could not be
/// read.</p>
ClassMethod ErrorsCount(pText As %String) As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        For tNamespace = tOrigNS, "%SYS" {
            Set $NAMESPACE = tNamespace
            Set tDay = +$Horolog
            Set tNode = $Name(^ERRORS(tDay))
            For {
                Set tNode = $Query(@tNode)
                If (tNode = "") || ($QSubscript(tNode, 1) '= tDay) Quit
                If (tNode [ pText) || ($Get(@tNode) [ pText) Set tCount = tCount + 1
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>How many lines of the instance's <code>messages.log</code> carry <var>pText</var>;
/// <code>-1</code> when the file could not be read.</p>
ClassMethod LogCount(pText As %String) As %Integer
{
    Set tCount = -1
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If $$$ISOK(tStream.LinkToFile($System.Util.ManagerDirectory() _ "messages.log")) {
        Set tCount = 0
        While 'tStream.AtEnd {
            If tStream.ReadLine() [ pText Set tCount = tCount + 1
        }
    }
    Set tStream = ""
    Quit tCount
}

/// <p>Whether any line of the instance's <code>messages.log</code> carries <var>pText</var>.</p>
ClassMethod LogCarries(pText As %String) As %Boolean
{
    Set tCarries = 0
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If $$$ISOK(tStream.LinkToFile($System.Util.ManagerDirectory() _ "messages.log")) {
        While 'tStream.AtEnd {
            If tStream.ReadLine() [ pText Set tCarries = 1 Quit
        }
    }
    Set tStream = ""
    Quit tCarries
}

/// <p>A synthetic password unique to this run and <var>pPurpose</var>.</p>
ClassMethod Secret(pPurpose As %String) As %String
{
    Quit ##class(OcuPilot.Test.LdapPassword).Secret("test" _ pPurpose)
}

}
