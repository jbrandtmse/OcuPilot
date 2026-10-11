/// <p>Pins the Prometheus metrics list's gate against real principals (AD-8, AD-29, Story 18.11), each
/// reading <code>GET /screens/osmgmt.metrics/read</code> over the wire: a principal holding exactly the
/// monitor port's two pairs reads the instance's samples as <code>{Metric, Labels, Value, Help}</code>
/// rows and takes a sensor collection by it; a principal missing either pair is refused 403 naming it,
/// and takes none; and a request with no credentials is refused 401.</p>
/// <p>A collection is observed through the vendor's own <code>LastCollection</code> baseline node
/// (AD-7), which every collection rewrites.</p>
/// <p><b>What it needs from the environment:</b> <parameter>PRINCIPALSVARIABLE</parameter> reading
/// <code>1</code>, because it creates three users and roles named <code>OcuProbe1811*</code>, each also
/// holding READ on the install namespace's code database, as every caller must. The principals are
/// removed after the last test.</p>
Class OcuPilot.Test.MetricsGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms its throwaway principals.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.MetricsProbe";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the grants it holds beyond the code database's
/// READ&gt;</code>, separated by <code>;</code>: the holder of exactly the port's pairs; one past the API
/// floor with <code>%Admin_Manage</code> in place of <code>%Admin_Operate</code>; and one without the system
/// database's read.</p>
Parameter PRINCIPALS = "OcuProbe1811Exact:%Admin_Operate:U,%DB_IRISSYS:R;OcuProbe1811NoOperate:%Admin_Manage:U,%DB_IRISSYS:R;OcuProbe1811NoSys:%Admin_Operate:U";

/// <p>The read under the API.</p>
Parameter READPATH = "/screens/osmgmt.metrics/read?maxRows=5";

/// <p>The principals' password for this run.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.MetricsGate creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe1811Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "RemovePrincipals", ..#PRINCIPALS)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    If $$$ISERR(tSC) Quit tSC
    If $ClassMethod(..#PROBE, "Remaining") '= (2 * $Length(..#PRINCIPALS, ";")) Quit $$$ERROR($$$GeneralError, "the probe principals and their roles were not all created")
    Quit $$$OK
}

/// <p>Remove the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemovePrincipals", ..#PRINCIPALS)
}

/// <p>The holder of exactly the port's two pairs reads the samples as rows of the four members, cut at
/// the cap with the cut reported, and its read takes a sensor collection.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.MonitorPort.Take</method> answer no text -- the
/// rows leg goes red.</p>
Method TestTheExactPairsReadTheSamples()
{
    Set tUser = "OcuProbe1811Exact"
    Set tBefore = ..LastCollection()
    Hang 1.1
    Do $$$AssertEquals(..Wire(..#READPATH, tUser, .tAnswer), "200 ", "the read answers the principal holding exactly the port's pairs")
    Do $$$AssertTrue($IsObject(tAnswer), "with a JSON answer")
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON() _ "|" _ tAnswer.rows.%Size() _ "|" _ tAnswer.truncated, "[""Metric"",""Labels"",""Value"",""Help""]|5|1", "five rows of the four fields, the cut reported")
    Set tRow = tAnswer.rows.%Get(0)
    Do $$$AssertTrue($IsObject(tRow) && ($Piece(tRow.%Get("Metric"), "_", 1) = "iris") && (tRow.%GetTypeOf("Help") = "string"), "each a vendor metric")
    Do $$$AssertNotEquals(..LastCollection(), tBefore, "and the read took a sensor collection")
}

/// <p>A principal missing <code>%Admin_Operate:USE</code>, or <code>%DB_IRISSYS:READ</code>, is refused
/// 403 naming it, and the refusals take no sensor collection.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.MonitorPort.Gate</method> answer OK, declare
/// <code>%Admin_Operate:USE</code> alone in <class>OcuPilot.Screen.Descriptor.MetricsList</class> and
/// relax <method>OcuPilot.Screen.Registry.ReadProblem</method>'s system-database arm for
/// <code>monitor</code>, since both gates refuse -- the NoSys leg goes red.</p>
Method TestEachMissingPairIsRefusedByNameAndTakesNoCollection()
{
    Set tBefore = ..LastCollection()
    Hang 1.1
    For tCase = $ListBuild("OcuProbe1811NoOperate", "%Admin_Operate:USE"), $ListBuild("OcuProbe1811NoSys", "%DB_IRISSYS:READ") {
        Do $$$AssertEquals(..Wire(..#READPATH, $List(tCase, 1), .tAnswer), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": refused naming the pair")
    }
    Do $$$AssertEquals(..LastCollection(), tBefore, "and neither took a sensor collection")
}

/// <p>A request with no credentials is refused 401.</p>
Method TestARequestWithNoCredentialsIsRefused()
{
    Do $$$AssertEquals(..Wire(..#READPATH, "", .tAnswer), "401 ", "no credentials, no read")
}

/// <p>A request for <var>pPath</var> under the API over the wire as <var>pUser</var> (no credentials
/// when <code>""</code>), answered as <code>status failedPair</code>: the failed pair, or <code>""</code>;
/// <var>pAnswer</var> is the parsed body, or <code>""</code>.</p>
Method Wire(pPath As %String, pUser As %String, Output pAnswer As %DynamicObject) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ pPath, pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set pAnswer = ""
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON($Get(tBody, "{}")) } Catch {}
    Set tDetail = $Select($IsObject(pAnswer): pAnswer.%Get("detail"), 1: "")
    Quit $Get(tStatus) _ " " _ $Select($IsObject(tDetail): tDetail.%Get("failedPair"), 1: "")
}

/// <p>The vendor's sensor baseline stamp, which every collection rewrites (AD-7).</p>
ClassMethod LastCollection() As %String
{
    Quit $Get(^IRIS.Temp.SAM("LastCollection"))
}

}
