/// <p>The port to the instance's dashboard sensors (AD-1, AD-29). <b>This is the only product class
/// that names <code>SYS.Monitor.SAM.Sensors</code></b>, the class whose
/// <code>PrometheusMetrics()</code> <code>/api/monitor/metrics</code> serves; it is called in process
/// in <code>%SYS</code>, never over HTTP.</p>
/// <p>Two ways in, each evaluating <parameter>PAIRS</parameter> in the calling process before
/// anything else, so a denial reaches no sensor code, and each taking one sensor collection.
/// <method>Performance</method> parses it into the five values <parameter>METRICS</parameter> names,
/// for Home's performance row. <method>Invoke</method> answers a declared read's
/// <code>monitor</code> part (AD-36) with the value <parameter>PARTMETRICS</parameter> names, for
/// the Dashboard's CPU meter. The per-second values are the sensors' own, each over the interval
/// since the previous collection on the instance.</p>
/// <p><b>Every collection rewrites the vendor's sensor baseline</b> (AD-7, AD-29): measured on
/// <code>ocupilot-ci</code> 2026-09-28, each <code>PrometheusMetrics()</code> call rewrites 24
/// sensor-baseline nodes of the vendor's SAM temporary global (the previous values, the CPU state
/// and the last-collection time) and never its alerts cursor. So a read here shortens an external
/// scraper's per-second intervals, and advances nothing the vendor's alerts read keeps; this class
/// never calls that alerts read.</p>
/// <p>Seams a test subclass overrides (<class>OcuPilot.Test.MonitorPortFixture</class>):
/// <method>GateClass</method>, <method>Source</method> and <method>LogFault</method>. Production
/// overrides none of them.</p>
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

/// <p>The one endpoint <method>Invoke</method> answers: the sensors, as a declared read's
/// <code>monitor</code> part names them (AD-36).</p>
Parameter SENSORSENDPOINT = "Sensors";

/// <p>The one request type <method>Invoke</method> answers, the type a <code>monitor</code> part
/// declares.</p>
Parameter SENSORSTYPE = "SENSORS";

/// <p>The values a <code>monitor</code> part answers, in the grammar of <parameter>METRICS</parameter>:
/// the system-wide CPU use, a percentage.</p>
Parameter PARTMETRICS = "cpuUsage:cpu_usage";

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

        Set tText = ""
        Set tOrigNS = $NAMESPACE
        Try {
            Set $NAMESPACE = "%SYS"
            Set tText = ..Source()
            Set $NAMESPACE = tOrigNS
        } Catch exSource {
            Set $NAMESPACE = tOrigNS
            Set tSC = ..Fail("the sensor collection raised", exSource.AsStatus(), .pHttpStatus, .pFault)
        }
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

/// <p>Answer a declared read's <code>monitor</code> part (AD-36), with
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s signature so the read issues a part through
/// either port the same way. <var>pQuery</var> and <var>pBody</var> are accepted and unused.</p>
/// <p>First <parameter>PAIRS</parameter> is evaluated in the calling process: a caller lacking
/// either pair is answered 403 <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>
/// and no sensor call is made. Then <var>pEndpoint</var> must be
/// <parameter>SENSORSENDPOINT</parameter> and <var>pType</var> <parameter>SENSORSTYPE</parameter>;
/// anything else is 500 <code>INTERNAL</code>, logged once. Then one collection is taken and
/// <var>pResult</var> is a <class>%DynamicObject</class> carrying each member of
/// <parameter>PARTMETRICS</parameter> as a JSON number, with <var>pHttpStatus</var> 200. A
/// collection that raises, or that lacks a member or answers it as no number, is 500
/// <code>INTERNAL</code>, logged once, with <var>pResult</var> empty -- never a partial answer.</p>
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
        Set tSC = ..Fail("the monitor part read raised", ex.AsStatus(), .pHttpStatus, .pFault)
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

/// <p>Take one collection in <code>%SYS</code> and parse the members <var>pMetrics</var> names
/// (<method>Parse</method>'s grammar). On a failure the status is an error and the fault is the
/// generic internal one, logged once.</p>
ClassMethod Collect(pMetrics As %String, Output pValues As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pValues = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tText = ..Source()
        Set $NAMESPACE = tOrigNS
    } Catch exSource {
        Set $NAMESPACE = tOrigNS
        Set tSC = ..Fail("the sensor collection raised", exSource.AsStatus(), .pHttpStatus, .pFault)
    }
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
/// <method>Performance</method> switches and restores around this call. Raises whatever the
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
