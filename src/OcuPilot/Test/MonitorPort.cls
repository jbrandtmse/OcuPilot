/// <p>Pins <class>OcuPilot.Port.MonitorPort</class> (Story 16.18, AD-29): the five values are parsed
/// from the unlabeled Prometheus lines alone, a missing or non-numeric metric fails the whole read
/// with nothing partial, and the pair set refuses before any sensor call. The metrics list
/// (Story 18.11) answers every sample of one collection as <code>{Metric, Labels, Value, Help}</code>
/// rows, cut at the cap, and a sample it cannot read fails the whole read.</p>
/// <p>Runs through <class>OcuPilot.Test.MonitorPortFixture</class>, whose <method>Source</method>
/// answers the text a test supplies and whose gate a test can swap for
/// <class>OcuPilot.Test.ScreenGate</class>, since <code>%UnitTest</code> runs as an account the real
/// check admits to everything. One method reads the live sensors as that account. Live-safe: it
/// creates nothing and writes only process-private globals; its one live collection moves the
/// sensors' stored previous values, as every read does (AD-29).</p>
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


/// <p>The metrics list's rows as comparable lines, <code>Metric|Labels|Value:type|Help</code>, one
/// per row in order, joined by a newline; <code>absent</code> when <var>pRows</var> is no array.</p>
ClassMethod RowsText(pRows As %DynamicArray) As %String
{
    If '$IsObject(pRows) Quit "absent"
    Set tOut = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ $Select(tIndex > 0: $Char(10), 1: "") _ tRow.%Get("Metric") _ "|" _ tRow.%Get("Labels") _ "|" _ tRow.%Get("Value") _ ":" _ tRow.%GetTypeOf("Value") _ "|" _ tRow.%Get("Help")
    }
    Quit tOut
}

/// <p>The exposition made of <var>pLines</var>, a <code>%List</code>, joined by a line feed.</p>
ClassMethod Joined(pLines As %List) As %String
{
    Quit $ListToString(pLines, $Char(10))
}

/// <p>The metrics list over the fixture, with <var>pMaxRows</var> as the cap (<code>""</code> sends
/// none).</p>
ClassMethod ReadList(pMaxRows As %String, Output pRows, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    If pMaxRows '= "" Set tQuery("maxRows") = pMaxRows
    Quit ##class(OcuPilot.Test.MonitorPortFixture).Invoke(##class(OcuPilot.Port.MonitorPort).#ENDPOINT, ##class(OcuPilot.Port.MonitorPort).#TYPELIST, .tQuery, "", .pRows, .pHttp, .pFault)
}

/// <p>Metrics list, the grammar: a bare sample, a labeled one whose value follows a timestamp, a
/// label value holding a space, a <code>}</code> and an escaped quote, empty braces, <code>NaN</code>
/// and <code>+Inf</code> as text, a carriage return and blank lines. <code>HELP</code> sets the help
/// of the samples of its name, <code>TYPE</code> and <code>UNIT</code> are skipped, and the rows come
/// in exposition order from one collection taken in <code>%SYS</code>.</p>
/// <p>Mutation: split a sample on its first space in
/// <method>OcuPilot.Port.MonitorPort.Samples</method> -&gt; the labeled rows go red; answer every
/// <code>Value</code> as a number -&gt; the <code>NaN</code> and <code>+Inf</code> rows go red; drop the
/// backslash branch of <method>OcuPilot.Port.MonitorPort.LabelsEnd</method> -&gt; the escaped-quote row
/// goes red.</p>
Method TestTheSampleGrammarAnswersEveryLineShape()
{
    Set tNamespace = $NAMESPACE
    Set tQuote = """"
    ; The label sets as the exposition spells them: a space inside a value; a brace and an escaped
    ; quote inside values; and an escaped quote followed by a brace inside one value.
    Set tLabelsB = "id=" _ tQuote _ "x" _ tQuote _ ",name=" _ tQuote _ "has space" _ tQuote
    Set tLabelsC = "p=" _ tQuote _ "a}b" _ tQuote _ ",q=" _ tQuote _ "say \" _ tQuote _ "hi\" _ tQuote _ tQuote
    Set tLabelsD = "x=" _ tQuote _ "a\" _ tQuote _ "}b" _ tQuote
    Set tText = ..Joined($ListBuild("# HELP probe_a first metric", "# TYPE probe_a gauge", "# UNIT probe_a bytes", "probe_a 5", "", "# HELP probe_b second metric, with a comma", "# TYPE probe_b gauge", "probe_b{" _ tLabelsB _ "} 1.5 1700000000", "probe_c{" _ tLabelsC _ "} 2", "probe_d NaN", "probe_e +Inf", "probe_f{} 7" _ $Char(13), "probe_g 1E3", "probe_h{" _ tLabelsD _ "} 3"))
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText(tText)
    Set tSC = ..ReadList("", .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Do $$$AssertEquals(tFault, "", "and no fault")
    Set tExpected = ..Joined($ListBuild("probe_a||5:number|first metric", "probe_b|" _ tLabelsB _ "|1.5:number|second metric, with a comma", "probe_c|" _ tLabelsC _ "|2:number|", "probe_d||NaN:string|", "probe_e||+Inf:string|", "probe_f||7:number|", "probe_g||1000:number|", "probe_h|" _ tLabelsD _ "|3:number|"))
    Do $$$AssertEquals(..RowsText(tRows), tExpected, "one row per sample in exposition order, help by name, values numeric unless they are not numbers")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceCalls(), 1, "from one collection")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceNamespace(), "%SYS", "taken in %SYS")
    Do $$$AssertEquals($NAMESPACE, tNamespace, "and the caller's namespace is restored")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).LogCalls(), 0, "and nothing is logged")

    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText("")
    Set tSC = ..ReadList("", .tNone, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "an exposition with no sample reads")
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tNone): tNone.%Size(), 1: "absent"), "200 0", "and answers no rows")
}

/// <p>Metrics list, the cut: at most the cap's rows come back, the first ones, whatever follows them;
/// no cap reads the port's default; a cap that is not a whole number above zero is 400
/// <code>PORT.VALIDATION</code> before any collection is taken.</p>
/// <p>Mutation: drop the <code>pMax</code> test in
/// <method>OcuPilot.Port.MonitorPort.Samples</method> -&gt; the cut rows go red.</p>
Method TestTheListIsCutAtTheCap()
{
    Set tText = ..Joined($ListBuild("probe_a 1", "probe_b 2", "probe_c 3", "probe_d 4"))
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText(tText)
    Set tSC = ..ReadList(2, .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a cap of two reads")
    Do $$$AssertEquals(..RowsText(tRows), ..Joined($ListBuild("probe_a||1:number|", "probe_b||2:number|")), "the first two rows")
    Set tSC = ..ReadList("", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tRows.%Size(), 4, "no cap reads every row up to the default")

    For tBad = "0", "-1", "abc", "1.5", "2 " {
        Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
        Do ##class(OcuPilot.Test.MonitorPortFixture).SetText(tText)
        Set tSC = ..ReadList(tBad, .tRows, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, "maxRows '" _ tBad _ "' is refused")
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "400 PORT.VALIDATION", "'" _ tBad _ "' as 400 PORT.VALIDATION")
        Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceCalls(), 0, "'" _ tBad _ "': before any collection")
    }
}

/// <p>Metrics list, a sample the port cannot read: no value, a label set that is not closed (also when
/// its only brace sits inside a quoted value) and no metric name each fail the whole read 500
/// <code>INTERNAL</code>, logged once, with no rows -- also when the sample lies past the cap.</p>
/// <p>Mutation: skip a sample with no value in <method>OcuPilot.Port.MonitorPort.Samples</method>
/// -&gt; the no-value rows go red.</p>
Method TestAMalformedSampleFailsTheWholeRead()
{
    Set tQuote = """"
    For tCase = $ListBuild("no value", "probe_a 1" _ $Char(10) _ "probe_b"), $ListBuild("labels without a value", "probe_a{id=" _ tQuote _ "x" _ tQuote _ "}"), $ListBuild("unclosed labels", "probe_a{id=" _ tQuote _ "x" _ tQuote _ " 5"), $ListBuild("a brace only inside a quote", "probe_a{id=" _ tQuote _ "x}" _ tQuote _ " 5"), $ListBuild("no name", "{id=" _ tQuote _ "x" _ tQuote _ "} 5") {
        Set tWhere = $List(tCase, 1)
        For tCap = "", 1 {
            Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
            Do ##class(OcuPilot.Test.MonitorPortFixture).SetText("probe_first 1" _ $Char(10) _ $List(tCase, 2))
            Set tSC = ..ReadList(tCap, .tRows, .tHttp, .tFault)
            Set tHow = tWhere _ $Select(tCap = "": "", 1: " past a cap of " _ tCap)
            Do $$$AssertStatusNotOK(tSC, tHow _ ": the read fails")
            Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "500 INTERNAL " _ ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, tHow _ ": as the generic internal fault")
            Do $$$AssertEquals(tRows, "", tHow _ ": answering no rows")
            Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).LogCalls(), 1, tHow _ ": logged once")
        }
    }
}

/// <p>Metrics list, a collection that raises: 500 <code>INTERNAL</code>, logged once, no rows -- never an
/// empty table answered 200 -- and the caller's namespace is restored.</p>
/// <p>Mutation: drop the status test after <method>OcuPilot.Port.MonitorPort.Take</method> in the list
/// branch of <method>OcuPilot.Port.MonitorPort.Invoke</method> -&gt; the raise is answered 200 with
/// no rows and this goes red.</p>
Method TestAListCollectionThatRaisesAnswersTheInternalFault()
{
    Set tNamespace = $NAMESPACE
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetRaise(1)
    Set tSC = ..ReadList("", .tRows, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the list read fails")
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "500 INTERNAL", "as 500 INTERNAL, not an empty table")
    Do $$$AssertEquals(tRows, "", "answering no rows")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).LogCalls(), 1, "logged once")
    Do $$$AssertEquals($NAMESPACE, tNamespace, "and the caller's namespace is restored")
}

/// <p>Metrics list, the gate: a caller lacking either pair is refused 403 <code>AUTH.NOPRIVILEGE</code>
/// naming that pair, with no collection taken; holding both, it is served.</p>
/// <p>Mutation: make <method>OcuPilot.Port.MonitorPort.Gate</method> answer OK -&gt; both refusals go
/// red (the list answers 200 and one collection each).</p>
Method TestTheGateRefusesTheListBeforeAnyCollection()
{
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText(..Joined($ListBuild("probe_a 1")))
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    For tCase = $ListBuild("%DB_IRISSYS", "READ", "%Admin_Operate:USE"), $ListBuild("%Admin_Operate", "USE", "%DB_IRISSYS:READ") {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tCase, 1), $List(tCase, 2))
        Set tWhere = "holding only " _ $List(tCase, 1) _ ":" _ $List(tCase, 2)
        Set tSC = ..ReadList("", .tRows, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tWhere _ ": the list is refused")
        Set tPair = ""
        If $IsObject(tFault) && $IsObject(tFault.%Get("detail")) Set tPair = tFault.detail.failedPair
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: "") _ " " _ tPair, "403 AUTH.NOPRIVILEGE " _ $List(tCase, 3), tWhere _ ": 403 naming the pair that failed")
        Do $$$AssertEquals(tRows, "", tWhere _ ": answering no rows")
        Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceCalls(), 0, tWhere _ ": with no collection")
    }

    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = ..ReadList("", .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "holding both pairs, the list is served")
    Do $$$AssertEquals(tHttp _ " " _ tRows.%Size(), "200 1", "with its rows")
}

/// <p>The live collection, read as this account through the production port, answers samples whose
/// every row carries the four members, the metric named with the vendor's prefix, and a cut of three
/// answers three.</p>
Method TestTheLiveCollectionAnswersSamples()
{
    Kill tQuery
    Set tQuery("maxRows") = 3
    Set tSC = ##class(OcuPilot.Port.MonitorPort).Invoke(##class(OcuPilot.Port.MonitorPort).#ENDPOINT, ##class(OcuPilot.Port.MonitorPort).#TYPELIST, .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the live read succeeds")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%Size(), 1: "absent"), 3, "cut at the cap")
    Set tWhole = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If ($Extract(tRow.%Get("Metric"), 1, 5) = (..#PREFIX _ "_")) && (tRow.%GetTypeOf("Labels") = "string") && (tRow.%GetTypeOf("Help") = "string") && ((tRow.%GetTypeOf("Value") = "number") || (tRow.%GetTypeOf("Value") = "string")) Set tWhole = tWhole + 1
    }
    Do $$$AssertEquals(tWhole, 3, "each row a vendor metric with its labels, value and help")
}

}
