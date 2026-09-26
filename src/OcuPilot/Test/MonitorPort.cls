/// <p>Pins <class>OcuPilot.Port.MonitorPort</class> (Story 16.18, AD-29): the five values are parsed
/// from the unlabeled Prometheus lines alone, a missing or non-numeric metric fails the whole read
/// with nothing partial, and the pair set refuses before any sensor call.</p>
/// <p>Runs through <class>OcuPilot.Test.MonitorPortFixture</class>, whose <method>Source</method>
/// answers the text a test supplies and whose gate a test can swap for
/// <class>OcuPilot.Test.ScreenGate</class>, since <code>%UnitTest</code> runs as an account the real
/// check admits to everything. One method reads the live sensors as that account. Live-safe: it
/// creates nothing and writes only process-private globals.</p>
Class OcuPilot.Test.MonitorPort Extends %UnitTest.TestCase
{

/// <p>The fixture under test.</p>
Parameter FIXTURE = "OcuPilot.Test.MonitorPortFixture";

/// <p>The prefix of every metric name the sensors answer.</p>
Parameter PREFIX = "iris";

/// <p>The five wire members, in the port's order.</p>
Parameter MEMBERS = "cacheEfficiency,globalReferencesPerSecond,globalUpdatesPerSecond,diskReadsPerSecond,diskWritesPerSecond";

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
    Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

/// <p>Sensor text carrying every metric the port reads, with the values in <var>pValues</var>
/// (five, comma-separated, in <parameter>MEMBERS</parameter>' order) and the vendor's
/// <code>HELP</code>/<code>TYPE</code> comments around them.</p>
ClassMethod Text(pValues As %String) As %String
{
    Set tNames = $ListBuild("cache_efficiency", "glo_ref_per_sec", "glo_update_per_sec", "phys_reads_per_sec", "phys_writes_per_sec")
    Set tText = "# HELP " _ ..Name("cpu_usage") _ " CPU usage" _ $Char(10) _ ..Name("cpu_usage") _ " 3" _ $Char(10)
    For tI = 1:1:5 {
        Set tName = ..Name($List(tNames, tI))
        Set tText = tText _ "# HELP " _ tName _ " a metric" _ $Char(10) _ "# TYPE " _ tName _ " gauge" _ $Char(10)
        Set tText = tText _ tName _ " " _ $Piece(pValues, ",", tI) _ $Char(10)
    }
    Quit tText
}

/// <p>The vendor's full metric name for <var>pSuffix</var>, spelled here rather than read from the
/// port, so a port that read the wrong metric is caught.</p>
ClassMethod Name(pSuffix As %String) As %String
{
    Quit ..#PREFIX _ "_" _ pSuffix
}

/// <p>The five values of <var>pValues</var> as one comparable line, or <code>absent</code>.</p>
ClassMethod ValuesText(pValues As %DynamicObject) As %String
{
    If '$IsObject(pValues) Quit "absent"
    Set tOut = ""
    For tI = 1:1:$Length(..#MEMBERS, ",") {
        Set tMember = $Piece(..#MEMBERS, ",", tI)
        Set tOut = tOut _ $Select(tI > 1: " ", 1: "") _ tMember _ "=" _ pValues.%Get(tMember) _ ":" _ pValues.%GetTypeOf(tMember)
    }
    Quit tOut
}

/// <p>Matrix, Present: five unlabeled lines answer 200 with five JSON numbers, read in
/// <code>%SYS</code>, one collection per read, and the caller's namespace unchanged.</p>
/// <p>Mutation: map <code>globalUpdatesPerSecond</code> to <code>glo_ref_per_sec</code> in
/// <parameter>OcuPilot.Port.MonitorPort.METRICS</parameter> -&gt; the value line goes red.</p>
Method TestFiveUnlabeledLinesAnswerFiveNumbers()
{
    Set tNamespace = $NAMESPACE
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText(..Text("8745.8,47089,1203,12,34"))
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Performance(.tValues, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Do $$$AssertEquals(..ValuesText(tValues), "cacheEfficiency=8745.8:number globalReferencesPerSecond=47089:number globalUpdatesPerSecond=1203:number diskReadsPerSecond=12:number diskWritesPerSecond=34:number", "carrying the five values as numbers")
    Do $$$AssertEquals(tFault, "", "and no fault")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceCalls(), 1, "from one collection")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceNamespace(), "%SYS", "taken in %SYS")
    Do $$$AssertEquals($NAMESPACE, tNamespace, "and the caller's namespace is restored")
}

/// <p>Matrix, Labeled line: a labeled line for a metric the port reads is ignored, whether it
/// stands beside the bare line or in place of it; only the bare line counts.</p>
/// <p>Mutation: match on <code>$Piece(tName, "{", 1)</code> in
/// <method>OcuPilot.Port.MonitorPort.Parse</method> -&gt; the labeled value wins and the first
/// assertion goes red, and the second read succeeds.</p>
Method TestALabeledLineIsIgnored()
{
    Set tText = ..Name("glo_ref_per_sec") _ "{id=""x""} 5" _ $Char(10) _ ..Text("100,200,300,400,500")
    Set tSC = ##class(OcuPilot.Port.MonitorPort).Parse(tText, .tValues)
    Do $$$AssertStatusOK(tSC, "text with a labeled line and the bare one parses")
    Do $$$AssertEquals(..ValuesText(tValues), "cacheEfficiency=100:number globalReferencesPerSecond=200:number globalUpdatesPerSecond=300:number diskReadsPerSecond=400:number diskWritesPerSecond=500:number", "and the bare line's value is the one read")

    Set tOnlyLabeled = $Replace(..Text("100,200,300,400,500"), ..Name("glo_ref_per_sec") _ " 200", ..Name("glo_ref_per_sec") _ "{id=""x""} 200")
    Set tSC = ##class(OcuPilot.Port.MonitorPort).Parse(tOnlyLabeled, .tValues2)
    Do $$$AssertStatusNotOK(tSC, "a metric present only as a labeled line is missing")
    Do $$$AssertEquals(tValues2, "", "and nothing is answered")
}

/// <p>Matrix, Metric missing: a sensor text lacking one metric, or carrying one whose value is not
/// a number, answers 500 <code>INTERNAL</code> with no values at all, logged once.</p>
/// <p>Mutation: <code>Continue</code> past a missing metric in
/// <method>OcuPilot.Port.MonitorPort.Parse</method> (accept a partial parse) -&gt; the read answers
/// 200 with four values and every row goes red.</p>
Method TestAMissingOrNonNumericMetricFailsTheWholeRead()
{
    Set tMissing = $Replace(..Text("1,2,3,4,5"), ..Name("phys_writes_per_sec") _ " 5", "")
    For tCase = $ListBuild("missing", tMissing), $ListBuild("non-numeric", ..Text("1,2,NaN,4,5")), $ListBuild("empty value", ..Text("1,2,3,,5")) {
        Set tWhere = $List(tCase, 1)
        Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
        Do ##class(OcuPilot.Test.MonitorPortFixture).SetText($List(tCase, 2))
        Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Performance(.tValues, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tWhere _ ": the read fails")
        Do $$$AssertEquals(tHttp, 500, tWhere _ ": with 500")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "INTERNAL " _ ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, tWhere _ ": as the generic internal fault")
        Do $$$AssertEquals(tValues, "", tWhere _ ": answering nothing partial")
        Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).LogCalls(), 1, tWhere _ ": logged once")
    }
}

/// <p>A collection that raises -- a refused <code>%SYS</code> read -- answers 500 and restores the
/// caller's namespace.</p>
Method TestACollectionThatRaisesAnswersTheInternalFault()
{
    Set tNamespace = $NAMESPACE
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetRaise(1)
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Performance(.tValues, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the read fails")
    Do $$$AssertEquals(tHttp, 500, "with 500")
    Do $$$AssertEquals(tValues, "", "answering nothing")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).LogCalls(), 1, "logged once")
    Do $$$AssertEquals($NAMESPACE, tNamespace, "and the caller's namespace is restored")
}

/// <p>Matrix, Denied: a caller lacking either pair is refused 403 <code>AUTH.NOPRIVILEGE</code>
/// naming that pair, before any sensor call.</p>
/// <p>Mutation: drop the <code>EvaluateRequired</code> call from
/// <method>OcuPilot.Port.MonitorPort.Performance</method> -&gt; both reads answer 200 with one
/// collection each, and every row goes red.</p>
Method TestTheGateRefusesBeforeAnySensorCall()
{
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText(..Text("1,2,3,4,5"))
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    For tCase = $ListBuild("%DB_IRISSYS", "READ", "%Admin_Operate:USE"), $ListBuild("%Admin_Operate", "USE", "%DB_IRISSYS:READ") {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tCase, 1), $List(tCase, 2))
        Set tWhere = "holding only " _ $List(tCase, 1) _ ":" _ $List(tCase, 2)
        Set tBefore = ##class(OcuPilot.Test.MonitorPortFixture).SourceCalls()
        Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Performance(.tValues, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tWhere _ ": the read is refused")
        Do $$$AssertEquals(tHttp, 403, tWhere _ ": with 403")
        Set tPair = ""
        If $IsObject(tFault) && $IsObject(tFault.%Get("detail")) Set tPair = tFault.detail.failedPair
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: "") _ " " _ tPair, "AUTH.NOPRIVILEGE " _ $List(tCase, 3), tWhere _ ": naming the pair that failed")
        Do $$$AssertEquals(tValues, "", tWhere _ ": answering nothing")
        Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceCalls() - tBefore, 0, tWhere _ ": with no sensor call")
    }

    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Performance(.tValues, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "holding both pairs, the read is served")
    Do $$$AssertEquals(tHttp, 200, "with 200")
}

/// <p>The live sensors, read as this account through the production port, answer the five values
/// as numbers.</p>
Method TestTheLiveSensorsAnswerFiveNumbers()
{
    Set tSC = ##class(OcuPilot.Port.MonitorPort).Performance(.tValues, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the live read succeeds")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Set tNumbers = 0
    For tI = 1:1:$Length(..#MEMBERS, ",") {
        If $IsObject(tValues) && (tValues.%GetTypeOf($Piece(..#MEMBERS, ",", tI)) = "number") Set tNumbers = tNumbers + 1
    }
    Do $$$AssertEquals(tNumbers, 5, "carrying five numbers: " _ ..ValuesText(tValues))
}

}
