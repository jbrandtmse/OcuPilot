/// <p>The port to the instance's dashboard sensors (AD-1, AD-29). <b>This is the only product class
/// that names <code>SYS.Monitor.SAM.Sensors</code></b>, the class whose
/// <code>PrometheusMetrics()</code> <code>/api/monitor/metrics</code> serves; it is called in process
/// in <code>%SYS</code>, never over HTTP.</p>
/// <p>Four ways in, each evaluating <parameter>PAIRS</parameter> in the calling process before
/// anything else, so a denial reaches no vendor code. Three take one sensor collection each.
/// <method>Performance</method> parses it into the five values <parameter>METRICS</parameter> names,
/// for Home's performance row. <method>Invoke</method> answers a declared read's
/// <code>monitor</code> part (AD-36) with the value <parameter>PARTMETRICS</parameter> names, for
/// the Dashboard's CPU meter, and a declared <code>monitor</code> read with every sample the
/// collection holds (<method>Samples</method>), for the Prometheus metrics table. The per-second
/// values are the sensors' own, each over the interval since the previous collection on the
/// instance. The fourth answers a declared <code>monitor</code> read of the interoperability usage
/// the classic Interoperability Usage page shows, by running the vendor class queries of the classes
/// that page reads in <code>%SYS</code> as the signed-in user (<method>Usage</method>); it takes no
/// sensor collection.</p>
/// <p><b>Every collection rewrites the vendor's sensor baseline</b> (AD-7, AD-29): measured on
/// <code>ocupilot-ci</code> 2026-09-28, each <code>PrometheusMetrics()</code> call rewrites 24
/// sensor-baseline nodes of the vendor's SAM temporary global (the previous values, the CPU state
/// and the last-collection time) and never its alerts cursor. So a read here shortens an external
/// scraper's per-second intervals, and advances nothing the vendor's alerts read keeps; this class
/// never calls that alerts read.</p>
/// <p>Seams a test subclass overrides (<class>OcuPilot.Test.MonitorPortFixture</class>):
/// <method>GateClass</method>, <method>Source</method>, <method>UsageSource</method> and
/// <method>LogFault</method>. Production overrides none of them.</p>
Class OcuPilot.Port.MonitorPort Extends %RegisteredObject
{

/// <p>The pair set every call requires, comma-separated as <code>resource:permission</code>, in the
/// order the gate reports in (AD-8). <code>%Admin_Operate:USE</code> is the dashboard's own
/// requirement; without <code>%DB_IRISSYS:READ</code> the switch to <code>%SYS</code> raises
/// <code>&lt;PROTECT&gt;</code>.</p>
Parameter PAIRS = "%Admin_Operate:USE,%DB_IRISSYS:READ";

/// <p>The class the pair set is evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The vendor class the sensors are collected from. Reached by name because it exists only in
/// <code>%SYS</code>.</p>
Parameter SENSORSCLASS = "SYS.Monitor.SAM.Sensors";

/// <p>The five values a read answers, as <code>member:suffix</code> pairs: the wire member, and the
/// unlabeled Prometheus metric it is read from, named by <method>MetricName</method>.</p>
Parameter METRICS = "cacheEfficiency:cache_efficiency,globalReferencesPerSecond:glo_ref_per_sec,globalUpdatesPerSecond:glo_update_per_sec,diskReadsPerSecond:phys_reads_per_sec,diskWritesPerSecond:phys_writes_per_sec";

/// <p>The endpoint a declared read's <code>monitor</code> part names: the sensors (AD-36).</p>
Parameter SENSORSENDPOINT = "Sensors";

/// <p>The request type a <code>monitor</code> part declares.</p>
Parameter SENSORSTYPE = "SENSORS";

/// <p>The values a <code>monitor</code> part answers, in the grammar of <parameter>METRICS</parameter>:
/// the system-wide CPU use, a percentage.</p>
Parameter PARTMETRICS = "cpuUsage:cpu_usage";

/// <p>The endpoint answering every sample of one collection (AD-36).</p>
Parameter ENDPOINT = "Metrics";

/// <p>The endpoints a declared <code>monitor</code> read names (AD-36): <parameter>ENDPOINT</parameter>
/// and the three interoperability usage lists, <parameter>ENDPOINTINTERFACES</parameter>,
/// <parameter>ENDPOINTMESSAGEVOLUME</parameter> and <parameter>ENDPOINTDATABASEIMPACT</parameter>.</p>
Parameter ENDPOINTS = "Metrics,Interfaces,MessageVolume,DatabaseImpact";

/// <p>The endpoint answering the interoperability interfaces: the classic page's
/// <parameter>QUERYINTERFACES</parameter>.</p>
Parameter ENDPOINTINTERFACES = "Interfaces";

/// <p>The endpoint answering the message totals per namespace and direction:
/// <parameter>QUERYMESSAGEVOLUME</parameter>, the vendor's total over all dates, where the classic page
/// lists the same counts per day.</p>
Parameter ENDPOINTMESSAGEVOLUME = "MessageVolume";

/// <p>The endpoint answering the data created per database: the classic page's
/// <parameter>QUERYDATABASEIMPACT</parameter>.</p>
Parameter ENDPOINTDATABASEIMPACT = "DatabaseImpact";

/// <p>The vendor class query behind <parameter>ENDPOINTINTERFACES</parameter>, in the
/// <code>class:query</code> form <code>%ResultSet</code> takes. It exists only in <code>%SYS</code>.</p>
Parameter QUERYINTERFACES = "SYS.Monitor.Interop.Interface.Utils:InteropInterfaces";

/// <p>The vendor class query behind <parameter>ENDPOINTMESSAGEVOLUME</parameter>.</p>
Parameter QUERYMESSAGEVOLUME = "%SYS.Monitor.Interop.Messages.Utils:MetricsTotalPerNamespace";

/// <p>The vendor class query behind <parameter>ENDPOINTDATABASEIMPACT</parameter>.</p>
Parameter QUERYDATABASEIMPACT = "%SYS.Monitor.Interop.DatabaseImpact.Utils:Impact";

/// <p>The fields of an interfaces row, as <code>name:kind</code> in the order the row answers
/// them: <code>text</code> or <code>number</code>. A row is one grouping: <code>Count</code> is
/// every interface enabled at any time and <code>ActiveNow</code> those active now.</p>
Parameter FIELDSINTERFACES = "Type:text,Namespace:text,Protocol:text,ActiveNow:number,Count:number";

/// <p>The columns <parameter>QUERYINTERFACES</parameter> answers that the port reads. Called with no start
/// date, as <method>UsageSource</method> calls it, the query answers each grouping as two rows,
/// <code>Active</code> <code>1</code> counting the interfaces active now and
/// <code>Active</code> <code>0</code> every interface enabled at any time, active ones included.</p>
Parameter COLUMNSINTERFACES = "Type,Namespace,Protocol,Active,Count";

/// <p>The fields of a message volume row, in the grammar of <parameter>FIELDSINTERFACES</parameter>.</p>
Parameter FIELDSMESSAGEVOLUME = "Namespace:text,Type:text,Volume:number";

/// <p>The fields of a database impact row, in the grammar of <parameter>FIELDSINTERFACES</parameter>.</p>
Parameter FIELDSDATABASEIMPACT = "Database:text,DataCreated:number";

/// <p>The one request type a declared <code>monitor</code> read names.</p>
Parameter TYPELIST = "LIST";

/// <p>The query key bounding a list's rows.</p>
Parameter MAXROWSKEY = "maxRows";

/// <p>The cap a list that names none is read under.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

/// <p>The prefix every metric name the sensors answer carries, before an underscore.</p>
Parameter METRICPREFIX = "iris";

/// <p>The subsystem a failed read is logged under.</p>
Parameter LOGSUBSYSTEM = "monitorport";

/// <p>The class the pair set is evaluated through. Overridable so a fixture can drive a denial in
/// process; production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p><parameter>PAIRS</parameter> as the <code>%List</code> of two-element <code>%List</code>s the
/// gate evaluates.</p>
ClassMethod Pairs() As %List
{
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(..#PAIRS)
}

/// <p><parameter>ENDPOINTS</parameter> as a <code>%List</code>: the endpoints a declared
/// <code>monitor</code> read may name.</p>
ClassMethod Endpoints() As %List
{
    Quit $ListFromString(..#ENDPOINTS)
}

/// <p>Read the five values once.</p>
/// <p>On success <var>pValues</var> is a <class>%DynamicObject</class> carrying each member of
/// <parameter>METRICS</parameter> as a JSON number, and <var>pHttpStatus</var> is 200. Otherwise an
/// error status is returned with <var>pValues</var> empty, <var>pHttpStatus</var> the status to
/// answer with and <var>pFault</var> the wire fault: 403 <code>AUTH.NOPRIVILEGE</code> with
/// <code>detail.failedPair</code> before any sensor call, or 500 <code>INTERNAL</code> when the
/// collection raised or did not carry all five values -- never a partial answer.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is
/// unchanged on return.</p>
ClassMethod Performance(Output pValues As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pValues = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tFailedPair = ""
        If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(), .tFailedPair) {
            Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason())
            Set tDetail = ##class(OcuPilot.Kernel.Denial).Detail(tFailedPair)
            If $IsObject(tDetail) Do pFault.%Set("detail", tDetail)
            Set tSC = $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
            Quit
        }

        Set tSC = ..Take(.tText, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tParseSC = ..Parse(tText, .tValues)
        If $$$ISERR(tParseSC) {
            Set tSC = ..Fail("the sensor collection could not be read", tParseSC, .pHttpStatus, .pFault)
            Quit
        }
        Set pValues = tValues
        Set pHttpStatus = 200
    } Catch ex {
        Set pValues = ""
        Set tSC = ..Fail("the performance read raised", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Answer a declared read's <code>monitor</code> part or its <code>monitor</code> list (AD-36),
/// with <method>OcuPilot.Port.AdminPort.Invoke</method>'s signature so the read issues either
/// through either port the same way. <var>pBody</var> is accepted and unused, and so is
/// <var>pQuery</var> except for <parameter>MAXROWSKEY</parameter>.</p>
/// <p>First <parameter>PAIRS</parameter> is evaluated in the calling process: a caller lacking
/// either pair is answered 403 <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>
/// and no sensor call is made. Then:</p>
/// <ul>
/// <li><parameter>ENDPOINT</parameter> with <parameter>TYPELIST</parameter> takes one collection
/// and answers <method>Samples</method>' rows, at most <parameter>MAXROWSKEY</parameter> of them
/// (<parameter>DEFAULTMAXROWS</parameter> when absent); a cap that is not a whole number above zero
/// is 400 <code>PORT.VALIDATION</code>, before any collection.</li>
/// <li>Each other member of <parameter>ENDPOINTS</parameter> with <parameter>TYPELIST</parameter>
/// answers <method>Usage</method>'s rows under the same cap and the same refusal, taking no
/// collection.</li>
/// <li><parameter>SENSORSENDPOINT</parameter> with <parameter>SENSORSTYPE</parameter> takes one
/// collection and answers a <class>%DynamicObject</class> carrying each member of
/// <parameter>PARTMETRICS</parameter> as a JSON number.</li>
/// <li>Anything else is 500 <code>INTERNAL</code>, logged once.</li>
/// </ul>
/// <p>A collection that raises, or that lacks a member or answers it as no number, and a usage query
/// that raises or answers an error status, is 500 <code>INTERNAL</code>, logged once, with
/// <var>pResult</var> empty -- never a partial answer. A collection holding a sample line
/// <method>Samples</method> cannot read answers 200 with every other row and one log line naming how
/// many lines were skipped. <var>pHttpStatus</var> is 200 otherwise.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is
/// unchanged on return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSC = ..Gate(.pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        If (pType = ..#TYPELIST) && $ListFind(..Endpoints(), pEndpoint) {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            If pEndpoint '= ..#ENDPOINT {
                Set tSC = ..Usage(pEndpoint, $Select(tMaxText = "": ..#DEFAULTMAXROWS, 1: +tMaxText), .tUsageRows, .pHttpStatus, .pFault)
                If $$$ISERR(tSC) Quit
                Set pResult = tUsageRows
                Set pHttpStatus = 200
                Quit
            }
            Set tSC = ..Take(.tText, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            Set tSamplesSC = ..Samples(tText, $Select(tMaxText = "": ..#DEFAULTMAXROWS, 1: +tMaxText), .tRows, .tSkipped)
            If $$$ISERR(tSamplesSC) {
                Set tSC = ..Fail("the sensor collection could not be read", tSamplesSC, .pHttpStatus, .pFault)
                Quit
            }
            If tSkipped Do ..LogFault("the sensor collection held " _ tSkipped _ " sample line(s) the port could not read, which were skipped", $$$ERROR($$$GeneralError, tSkipped _ " unreadable sample line(s)"))
            Set pResult = tRows
            Set pHttpStatus = 200
            Quit
        }

        If (pEndpoint '= ..#SENSORSENDPOINT) || (pType '= ..#SENSORSTYPE) {
            Set tSC = ..Fail("the monitor port answers no " _ pEndpoint _ " " _ pType, $$$ERROR($$$GeneralError, "unknown endpoint or type"), .pHttpStatus, .pFault)
            Quit
        }

        Set tSC = ..Collect(..#PARTMETRICS, .tValues, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pResult = tValues
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the monitor read raised", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Evaluate <parameter>PAIRS</parameter> in the calling process. On a refusal the status is an
/// error, <var>pHttpStatus</var> is 403 and <var>pFault</var> the <class>OcuPilot.Kernel.Denial</class>
/// envelope naming the failed pair.</p>
ClassMethod Gate(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tFailedPair = ""
    If $ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(), .tFailedPair) Quit $$$OK
    Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason())
    Set tDetail = ##class(OcuPilot.Kernel.Denial).Detail(tFailedPair)
    If $IsObject(tDetail) Do pFault.%Set("detail", tDetail)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p>Take one collection in <code>%SYS</code>, as the exposition text. On a raise the status is an
/// error and the fault is the generic internal one, logged once; the caller's namespace is restored
/// either way.</p>
ClassMethod Take(Output pText As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pText = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set pText = ..Source()
        Set $NAMESPACE = tOrigNS
    } Catch exSource {
        Set $NAMESPACE = tOrigNS
        Set pText = ""
        Set tSC = ..Fail("the sensor collection raised", exSource.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Take one collection (<method>Take</method>) and parse the members <var>pMetrics</var> names
/// (<method>Parse</method>'s grammar). On a failure the status is an error and the fault is the
/// generic internal one, logged once.</p>
ClassMethod Collect(pMetrics As %String, Output pValues As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pValues = ""
    Set tSC = ..Take(.tText, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC

    Set tParseSC = ..Parse(tText, .tValues, pMetrics)
    If $$$ISERR(tParseSC) Quit ..Fail("the sensor collection could not be read", tParseSC, .pHttpStatus, .pFault)
    Set pValues = tValues
    Quit $$$OK
}

/// <p>The full Prometheus metric name for <var>pSuffix</var>, one of the suffixes
/// <parameter>METRICS</parameter> declares.</p>
ClassMethod MetricName(pSuffix As %String) As %String
{
    Quit ..#METRICPREFIX _ "_" _ pSuffix
}

/// <p>One sensor collection, as the Prometheus exposition text the vendor answers.</p>
/// <p><b>Caller contract: <code>$NAMESPACE</code> is already <code>%SYS</code></b> --
/// <method>Take</method> switches and restores around this call. Raises whatever the
/// collection raises. A stream answer is read into a string. Overridable so a test can supply the
/// text; production never overrides it.</p>
ClassMethod Source() As %String
{
    Set tAnswer = $ClassMethod(..#SENSORSCLASS, "PrometheusMetrics")
    If '$IsObject(tAnswer) Quit tAnswer
    Set tText = ""
    Do tAnswer.Rewind()
    While 'tAnswer.AtEnd {
        Set tText = tText _ tAnswer.Read(32000)
    }
    Quit tText
}

/// <p>Parse <var>pText</var> into the members <var>pMetrics</var> names, in
/// <parameter>METRICS</parameter>' grammar; <code>""</code> means <parameter>METRICS</parameter>
/// itself, the five values <method>Performance</method> answers.</p>
/// <p>Only an unlabeled line counts: its first space-separated token is the metric's exact name,
/// and its second is the value, which must be a number. A labeled line
/// (<code>name{id="x"} 5</code>), a comment and any other metric are ignored. A metric that is
/// absent, or whose value is not a number, fails the whole parse with <var>pValues</var>
/// empty.</p>
ClassMethod Parse(pText As %String, Output pValues As %DynamicObject, pMetrics As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pValues = ""
    Try {
        Kill tFound
        Set tLines = $Length(pText, $Char(10))
        For tI = 1:1:tLines {
            Set tLine = $ZStrip($Piece(pText, $Char(10), tI), "<>W", $Char(13))
            If (tLine = "") || ($Extract(tLine) = "#") Continue
            Set tName = $Piece(tLine, " ", 1)
            If $Data(tFound(tName)) Continue
            Set tFound(tName) = $Piece(tLine, " ", 2)
        }
        Set tValues = {}
        Set tMetrics = $Select(pMetrics = "": ..#METRICS, 1: pMetrics)
        For tI = 1:1:$Length(tMetrics, ",") {
            Set tMember = $Piece($Piece(tMetrics, ",", tI), ":", 1)
            Set tMetric = ..MetricName($Piece($Piece(tMetrics, ",", tI), ":", 2))
            If '$Data(tFound(tMetric), tRaw) {
                Set tSC = $$$ERROR($$$GeneralError, "the sensors answered no unlabeled " _ tMetric)
                Quit
            }
            If (tRaw = "") || '$IsValidNum(tRaw) {
                Set tSC = $$$ERROR($$$GeneralError, "the sensors answered " _ tMetric _ " as a value that is not a number")
                Quit
            }
            Do tValues.%Set(tMember, +tRaw, "number")
        }
        If $$$ISERR(tSC) Quit
        Set pValues = tValues
    } Catch ex {
        Set pValues = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every sample of <var>pText</var>, one collection's exposition, as <var>pRows</var>: a
/// <class>%DynamicArray</class> of at most <var>pMax</var> objects <code>{Metric, Labels, Value,
/// Help}</code>, in exposition order.</p>
/// <p>A blank line and a comment are skipped, except <code># HELP &lt;name&gt; &lt;text&gt;</code>,
/// whose text is <code>Help</code> for every sample of that name. A sample is
/// <code>&lt;name&gt;[{&lt;labels&gt;}] &lt;value&gt;[ &lt;timestamp&gt;]</code>:</p>
/// <ul>
/// <li><code>Metric</code> runs to the first <code>{</code> or space.</li>
/// <li><code>Labels</code> is the text between the braces as answered, <code>""</code> when there
/// are none. The closing brace is the first <code>}</code> outside a double-quoted value, in which
/// <code>\"</code> does not end the value. A line whose label set does not close that way is read
/// once more with a backslash taken as plain text, so a value ending in an unescaped backslash, as a
/// Windows directory does, still reads.</li>
/// <li><code>Value</code> is a JSON number when it is a valid number, otherwise its text
/// (<code>NaN</code>, <code>+Inf</code>).</li>
/// </ul>
/// <p>The whole exposition is read before the cut, so <var>pSkipped</var> does not depend on
/// <var>pMax</var>. A sample with no name or no value, or whose label set closes in neither reading,
/// is skipped and counted in <var>pSkipped</var>, and the other rows are answered.
/// <method>Parse</method>, which reads only the unlabeled lines it is asked for, is a separate and
/// tolerant reader.</p>
ClassMethod Samples(pText As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pSkipped As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pRows = ""
    Set pSkipped = 0
    Try {
        Kill tHelp
        Set tLines = $ListFromString(pText, $Char(10))
        Set tAt = 0
        While $ListNext(tLines, tAt, tRaw) {
            Set tLine = $ZStrip($Get(tRaw), "<>WC")
            If $Extract(tLine, 1, 7) '= "# HELP " Continue
            Set tHelpName = $Piece($Extract(tLine, 8, *), " ", 1)
            If (tHelpName '= "") && '$Data(tHelp(tHelpName)) Set tHelp(tHelpName) = $Piece($Extract(tLine, 8, *), " ", 2, *)
        }

        Set tRows = []
        Set tAt = 0
        While $ListNext(tLines, tAt, tRaw) {
            Set tLine = $ZStrip($Get(tRaw), "<>WC")
            If (tLine = "") || ($Extract(tLine) = "#") Continue
            If '..SampleParts(tLine, 0, .tName, .tLabels, .tValue) && '..SampleParts(tLine, 1, .tName, .tLabels, .tValue) {
                Set pSkipped = pSkipped + 1
                Continue
            }
            If tRows.%Size() < pMax {
                Set tRow = {}
                Do tRow.%Set("Metric", tName, "string")
                Do tRow.%Set("Labels", tLabels, "string")
                If $IsValidNum(tValue) {
                    Do tRow.%Set("Value", +tValue, "number")
                } Else {
                    Do tRow.%Set("Value", tValue, "string")
                }
                Do tRow.%Set("Help", $Get(tHelp(tName)), "string")
                Do tRows.%Push(tRow)
            }
        }
        Set pRows = tRows
    } Catch ex {
        Set pRows = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One sample line <var>pLine</var> split into its metric name, label text and value, or 0 when it has no name, no
/// value, or a label set that does not close. <var>pLiteral</var> 1 reads a backslash inside a quoted label value as plain
/// text (<method>LabelsEnd</method>).</p>
ClassMethod SampleParts(pLine As %String, pLiteral As %Boolean, Output pName As %String, Output pLabels As %String, Output pValue As %String) As %Boolean [ Private ]
{
    Set pName = ""
    Set pLabels = ""
    Set pValue = ""
    Set tLength = $Length(pLine)
    Set tNameEnd = 1
    While (tNameEnd <= tLength) && ($Extract(pLine, tNameEnd) '= "{") && ($Extract(pLine, tNameEnd) '= " ") && ($Extract(pLine, tNameEnd) '= $Char(9)) {
        Set tNameEnd = tNameEnd + 1
    }
    Set pName = $Extract(pLine, 1, tNameEnd - 1)
    If pName = "" Quit 0
    Set tRest = $Extract(pLine, tNameEnd, *)
    If $Extract(tRest) = "{" {
        Set tClose = ..LabelsEnd(pLine, tNameEnd, pLiteral)
        If 'tClose Quit 0
        Set pLabels = $Extract(pLine, tNameEnd + 1, tClose - 1)
        Set tRest = $Extract(pLine, tClose + 1, *)
    }
    Set pValue = $Piece($ZStrip($Translate(tRest, $Char(9), " "), "<>WC"), " ", 1)
    Quit (pValue '= "")
}

/// <p>The position of the brace closing the label set that opens at <var>pOpen</var> in
/// <var>pLine</var>, or 0 when it is not closed. A brace inside a double-quoted value does not
/// close it, and a backslash inside a quoted value escapes the character after it -- unless
/// <var>pLiteral</var> is 1, when a backslash is plain text and a quote after it ends the value.</p>
ClassMethod LabelsEnd(pLine As %String, pOpen As %Integer, pLiteral As %Boolean = 0) As %Integer [ Private ]
{
    Set tQuoted = 0
    Set tI = pOpen + 1
    Set tLength = $Length(pLine)
    While tI <= tLength {
        Set tChar = $Extract(pLine, tI)
        If tQuoted {
            If (tChar = "\") && 'pLiteral {
                Set tI = tI + 1
            } ElseIf tChar = """" {
                Set tQuoted = 0
            }
        } ElseIf tChar = """" {
            Set tQuoted = 1
        } ElseIf tChar = "}" {
            Quit
        }
        Set tI = tI + 1
    }
    Quit $Select(tI <= tLength: tI, 1: 0)
}

/// <p>The rows of the interoperability usage list <var>pEndpoint</var> names -- one of
/// <parameter>ENDPOINTINTERFACES</parameter>, <parameter>ENDPOINTMESSAGEVOLUME</parameter> and
/// <parameter>ENDPOINTDATABASEIMPACT</parameter> -- as <var>pRows</var>: a <class>%DynamicArray</class>
/// of at most <var>pMax</var> objects carrying the fields <parameter>FIELDSINTERFACES</parameter>,
/// <parameter>FIELDSMESSAGEVOLUME</parameter> or <parameter>FIELDSDATABASEIMPACT</parameter> name,
/// typed as they declare: <code>number</code> is a JSON number when the value is a valid number,
/// and <code>text</code> is kept as answered, <code>""</code> included (a totals row leaves its
/// namespace and protocol empty).</p>
/// <p>The interfaces rows are <method>Groupings</method>' rows: the query answers each grouping twice,
/// so its answer is read whole and the cut counts groupings. <method>UsageSource</method> runs in
/// <code>%SYS</code>, as the signed-in user; the caller's namespace is restored before anything else, on
/// the error path too. A query that raises or answers an error status is 500 <code>INTERNAL</code>,
/// logged once, with <var>pRows</var> empty.</p>
ClassMethod Usage(pEndpoint As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tUsageSC = ..UsageSource(pEndpoint, $Select(pEndpoint = ..#ENDPOINTINTERFACES: 0, 1: pMax), .tRaw)
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tUsageSC) {
            Set tSC = ..Fail("the interoperability usage could not be read", tUsageSC, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTINTERFACES Set tRaw = ..Groupings(tRaw)
        Set tFields = ..UsageFields(pEndpoint)
        Set tRows = []
        Set tIterator = tRaw.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRawRow) {
            If tRows.%Size() >= pMax Quit
            Set tRow = {}
            For tI = 1:1:$Length(tFields, ",") {
                Set tName = $Piece($Piece(tFields, ",", tI), ":", 1)
                Set tKind = $Piece($Piece(tFields, ",", tI), ":", 2)
                Set tValue = tRawRow.%Get(tName)
                If (tKind = "number") && $IsValidNum(tValue) {
                    Do tRow.%Set(tName, +tValue, "number")
                } Else {
                    Do tRow.%Set(tName, tValue, "string")
                }
            }
            Do tRows.%Push(tRow)
        }
        Set pRows = tRows
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pRows = ""
        Set tSC = ..Fail("the interoperability usage read raised", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The fields of <var>pEndpoint</var>'s rows, as <code>name:kind</code> separated by commas:
/// <parameter>FIELDSINTERFACES</parameter>, <parameter>FIELDSMESSAGEVOLUME</parameter> or
/// <parameter>FIELDSDATABASEIMPACT</parameter>; <code>""</code> for any other endpoint.</p>
ClassMethod UsageFields(pEndpoint As %String) As %String [ Private ]
{
    If pEndpoint = ..#ENDPOINTINTERFACES Quit ..#FIELDSINTERFACES
    If pEndpoint = ..#ENDPOINTMESSAGEVOLUME Quit ..#FIELDSMESSAGEVOLUME
    If pEndpoint = ..#ENDPOINTDATABASEIMPACT Quit ..#FIELDSDATABASEIMPACT
    Quit ""
}

/// <p>The columns of the vendor query behind <var>pEndpoint</var> that the port reads, separated by
/// commas: <parameter>COLUMNSINTERFACES</parameter> for the interfaces, the names of
/// <method>UsageFields</method> for the other two; <code>""</code> for any other endpoint.</p>
ClassMethod UsageColumns(pEndpoint As %String) As %String [ Private ]
{
    If pEndpoint = ..#ENDPOINTINTERFACES Quit ..#COLUMNSINTERFACES
    Set tFields = ..UsageFields(pEndpoint)
    Set tColumns = ""
    For tI = 1:1:$Length(tFields, ",") {
        Set tColumns = tColumns _ $Select(tColumns = "": "", 1: ",") _ $Piece($Piece(tFields, ",", tI), ":", 1)
    }
    Quit tColumns
}

/// <p>The interfaces rows <var>pRaw</var> holds, one object per vendor row carrying
/// <parameter>COLUMNSINTERFACES</parameter>, merged into a <class>%DynamicArray</class> with one object per
/// grouping (<code>Type</code>, <code>Namespace</code>, <code>Protocol</code>), in the order its first row
/// appears. <code>Count</code> is the <code>Active</code> <code>0</code> row's and <code>ActiveNow</code>
/// the <code>Active</code> <code>1</code> row's; a grouping the query answers one of leaves the other
/// <code>0</code>, and a row whose <code>Active</code> is not <code>1</code> counts as the
/// <code>Active</code> <code>0</code> row.</p>
ClassMethod Groupings(pRaw As %DynamicArray) As %DynamicArray [ Private ]
{
    Set tGroups = 0
    Set tIterator = pRaw.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRawRow) {
        Set tKey = $ListBuild(tRawRow.%Get("Type"), tRawRow.%Get("Namespace"), tRawRow.%Get("Protocol"))
        If '$Data(tSeen(tKey)) {
            Set tGroups = tGroups + 1
            Set tSeen(tKey) = 1
            Set tKeys(tGroups) = tKey
            Set tActiveNow(tKey) = 0
            Set tCount(tKey) = 0
        }
        If tRawRow.%Get("Active") = 1 {
            Set tActiveNow(tKey) = tRawRow.%Get("Count")
        } Else {
            Set tCount(tKey) = tRawRow.%Get("Count")
        }
    }
    Set tRows = []
    For tI = 1:1:tGroups {
        Set tKey = tKeys(tI)
        Set tRow = {}
        Do tRow.%Set("Type", $List(tKey, 1))
        Do tRow.%Set("Namespace", $List(tKey, 2))
        Do tRow.%Set("Protocol", $List(tKey, 3))
        Do tRow.%Set("ActiveNow", tActiveNow(tKey))
        Do tRow.%Set("Count", tCount(tKey))
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>Run the vendor class query behind <var>pEndpoint</var> and answer up to <var>pMax</var> of its
/// rows as <var>pRows</var> (every row when <var>pMax</var> is below one): a <class>%DynamicArray</class>
/// of objects holding each column of <method>UsageColumns</method> as the query answered it, a string.
/// The queries run over every date the instance keeps: the interfaces with their totals, per namespace
/// and per protocol (the classic page's own query, with every grouping on); the message totals per
/// namespace and direction; and the data created per database (the classic page's own query).</p>
/// <p><b>Caller contract: <code>$NAMESPACE</code> is already <code>%SYS</code></b> --
/// <method>Usage</method> switches and restores around this call. Raises whatever the query
/// raises; an error status when the query cannot be run or fails while it is read. Overridable so a
/// test can supply the rows; production never overrides it.</p>
ClassMethod UsageSource(pEndpoint As %String, pMax As %Integer, Output pRows As %DynamicArray) As %Status
{
    Set pRows = []
    If pEndpoint = ..#ENDPOINTINTERFACES {
        Set tRS = ##class(%ResultSet).%New(..#QUERYINTERFACES)
        If '$IsObject(tRS) Quit $$$ERROR($$$GeneralError, "the interfaces query could not be opened")
        Set tSC = tRS.Execute("", "", "", "", "", 1, 1, 1, 0)
    } ElseIf pEndpoint = ..#ENDPOINTMESSAGEVOLUME {
        Set tRS = ##class(%ResultSet).%New(..#QUERYMESSAGEVOLUME)
        If '$IsObject(tRS) Quit $$$ERROR($$$GeneralError, "the message volume query could not be opened")
        Set tSC = tRS.Execute("", "", "")
    } ElseIf pEndpoint = ..#ENDPOINTDATABASEIMPACT {
        Set tRS = ##class(%ResultSet).%New(..#QUERYDATABASEIMPACT)
        If '$IsObject(tRS) Quit $$$ERROR($$$GeneralError, "the database impact query could not be opened")
        Set tSC = tRS.Execute($ZDateTime(0, 3), $ZDateTime(2980013, 3), "")
    } Else {
        Quit $$$ERROR($$$GeneralError, "the monitor port reads no usage list " _ pEndpoint)
    }
    If $$$ISERR(tSC) Quit tSC
    Set tColumns = ..UsageColumns(pEndpoint)
    Set tCount = 0
    While ((pMax < 1) || (tCount < pMax)) && tRS.Next(.tSC) {
        Set tRow = {}
        For tI = 1:1:$Length(tColumns, ",") {
            Set tName = $Piece(tColumns, ",", tI)
            Do tRow.%Set(tName, tRS.Get(tName), "string")
        }
        Do pRows.%Push(tRow)
        Set tCount = tCount + 1
    }
    Do tRS.Close()
    If $$$ISERR(tSC) Set pRows = []
    Quit tSC
}

/// <p>A refusal this port decided, with a written reason (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture
/// the line; production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p><code>""</code>: no write reaches the sensors through this port, so no request type has a
/// script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ""
}

/// <p>No step: every branch of <method>Invoke</method> is a read (AD-59).</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    Quit []
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log
/// once.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

}
