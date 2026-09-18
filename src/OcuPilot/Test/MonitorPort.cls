/// <p>The monitoring API port in process (AD-1, AD-29): the gate evaluated before any argument is
/// read and before any vendor call, tag mode on every call, the instance-wide cursor left
/// untouched, the written reasons for an oversized answer and for a failed one, the raw vendor text
/// reaching the log and nowhere else, and the row projection the declared read consumes.</p>
/// <p>The vendor is <class>OcuPilot.Test.MonitorSensorFixture</class> behind
/// <class>OcuPilot.Test.MonitorPortFixture</class>; denials are driven through
/// <class>OcuPilot.Test.ScreenGate</class>, because <code>%UnitTest</code> runs as an account holding
/// <code>%All</code>. The real gate against a real least-privileged principal is
/// <class>OcuPilot.Test.MonitorPortDenial</class>'s. One leg calls the <b>real</b> port against the
/// live instance, which needs an instance whose <code>SYS.Monitor.SAM.Sensors</code> answers; it
/// reads <code>alerts.log</code> and writes nothing.</p>
Class OcuPilot.Test.MonitorPort Extends %UnitTest.TestCase
{

/// <p>The instance-wide cursor the no-tag path advances, which every call must leave alone
/// (AD-7).</p>
Parameter CURSOR = "^IRIS.Temp.SAM";

/// <p>Two entries as the vendor reports them: a local stamp with a false <code>Z</code>, a quoted
/// severity, and the text with pid and category already dropped.</p>
Parameter BODY = "[{""time"":""2026-09-18T07:33:42.173Z"",""severity"":""2"",""message"":""first""},{""time"":""2026-09-18T07:33:56.057Z"",""severity"":""0"",""message"":""second""}]";

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
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Clear()
    Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

/// <p>Arm the gate to hold both declared pairs, so a test of the vendor path is not refused at the
/// gate.</p>
Method HoldDeclaredPairs()
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")
}

/// <p>AC2's falsifiable half -- every call seeds <code>%request.Data("tag",1)</code>, which is what
/// decides <b>which rows</b> the vendor answers. The tag the vendor was handed is read back off the
/// fixture's own record of the request, so this observes what the vendor saw rather than what the
/// port meant.</p>
/// <p>The cursor assertions below are over the <b>fixture's</b> sensor, which never writes
/// <parameter>CURSOR</parameter>; they say only that no fixture call touched it. What the real vendor
/// does with that global is DW-1116.</p>
/// <p>Mutation: drop the <code>%request.Data("tag",1)</code> seed in
/// <method>OcuPilot.Port.MonitorPort.Call</method> -&gt; the tag-mode assertion reddens (observed).</p>
Method TestEveryCallUsesTagModeAndLeavesTheInstanceCursorAlone()
{
    Do ..HoldDeclaredPairs()
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("200 OK", ..#BODY, "09/18/26-07:33:56:057 (892)")

    Set tBefore = ..CursorSnapshot()
    Kill tQuery
    Set tQuery("tag") = "09/18/26-00:50:22:421 (892)"
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Set tAfter = ..CursorSnapshot()

    Do $$$AssertStatusOK(tSC, "the armed answer is served")
    Do $$$AssertEquals(tHttp, 200, "with the vendor's own status")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorSensorFixture).EntryCount(), 1, "the vendor was entered exactly once")
    Do $$$AssertTrue(##class(OcuPilot.Test.MonitorSensorFixture).TaggedAt(1), "and it found the tag key defined, which is tag mode (AD-7)")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorSensorFixture).TagAt(1), "09/18/26-00:50:22:421 (892)", "carrying the caller's own cursor")
    Do $$$AssertEquals(tAfter, tBefore, "and no fixture call touched the instance-wide cursor")
    Do $$$AssertEquals(tTag, "09/18/26-07:33:56:057 (892)", "the next cursor is the vendor's own header")
}

/// <p>An empty tag is sound and still seeds the key, so the whole file is read without advancing the
/// instance-wide cursor.</p>
Method TestAnEmptyTagStillTakesTheTagPath()
{
    Do ..HoldDeclaredPairs()
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("200 OK", ..#BODY)

    Set tBefore = ..CursorSnapshot()
    Kill tQuery
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Set tAfter = ..CursorSnapshot()

    Do $$$AssertStatusOK(tSC, "a call with no tag is served")
    Do $$$AssertTrue(##class(OcuPilot.Test.MonitorSensorFixture).TaggedAt(1), "and still takes the tag path")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorSensorFixture).TagAt(1), "", "with an empty cursor, which reads the whole file")
    Do $$$AssertEquals(tAfter, tBefore, "and no fixture call touched the instance-wide cursor")
}

/// <p>The rows the declared read consumes: the vendor's <code>message</code> renamed to
/// <code>text</code>, the severity kept as the vendor's own text, and the stamp untouched -- the
/// false <code>Z</code> is the client's to normalize, not the port's to guess at.</p>
Method TestRowsCarryTheThreeDeclaredFields()
{
    Do ..HoldDeclaredPairs()
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("200 OK", ..#BODY)

    Kill tQuery
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Do $$$AssertStatusOK(tSC, "the armed answer is served")
    Do $$$AssertTrue($IsObject(tRows) && tRows.%IsA("%Library.DynamicArray"), "the answer is an array of rows")
    Do $$$AssertEquals(tRows.%Size(), 2, "one row per entry")
    Do $$$AssertEquals(tRows.%Get(0).%Get("time"), "2026-09-18T07:33:42.173Z", "the stamp is the vendor's own")
    Do $$$AssertEquals(tRows.%Get(0).%Get("severity"), "2", "the severity is the vendor's own text")
    Do $$$AssertEquals(tRows.%Get(0).%Get("text"), "first", "and the message is projected under the declared field name")
    Do $$$AssertEquals(tRows.%Get(1).%Get("text"), "second", "in the vendor's own order")
}

/// <p>The caller's row cap bounds the rows, which is what makes the executor's cap-plus-one
/// truncation signal work.</p>
Method TestTheRowCapBoundsTheAnswer()
{
    Do ..HoldDeclaredPairs()
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("200 OK", ..#BODY)

    Kill tQuery
    Set tQuery("maxRows") = 1
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Do $$$AssertStatusOK(tSC, "the capped answer is served")
    Do $$$AssertEquals(tRows.%Size(), 1, "at most the cap's rows")
}

/// <p>AC3 -- a vendor throw is one AD-12 envelope with a <code>MONITOR.*</code> code and a written
/// reason, the vendor's own text reaches the log and nowhere else, and no exception escapes.</p>
/// <p>Mutation: remove the <code>Try</code>/<code>Catch</code> around the vendor call in
/// <method>OcuPilot.Port.MonitorPort.Call</method> -&gt; the exception escapes and this method
/// reddens.</p>
Method TestAThrownVendorCallIsOneWrittenEnvelope()
{
    Do ..HoldDeclaredPairs()
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("200 OK", "", "", "throw")

    Kill tQuery
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Do $$$AssertStatusNotOK(tSC, "a thrown vendor call is an error status")
    Do $$$AssertEquals(tHttp, 503, "answered 503")
    Do $$$AssertTrue($IsObject(tFault), "with a wire fault")
    Do $$$AssertEquals(tFault.code, "MONITOR.FAILED", "carrying the named code")
    Do $$$AssertEquals(tFault.reason, ##class(OcuPilot.Port.MonitorPort).#REASONFAILED, "and this port's own written reason")
    Do $$$AssertEquals(tRows, "", "no rows are returned")
    Do $$$AssertTrue($Find(##class(OcuPilot.Test.LogProbe).Captured("message"), "Alerts") > 0, "the raw line names the vendor method: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
}

/// <p>AC3 -- an answer past <parameter>OcuPilot.Port.MonitorPort.MAXANSWERCHARS</parameter> is
/// refused rather than truncated, and so is a <code>&lt;MAXSTRING&gt;</code> raised on the way out
/// of the vendor. The vendor reads the whole file into a scalar string, so both are the same
/// failure.</p>
Method TestAnOversizedAnswerIsRefusedRatherThanCut()
{
    Do ..HoldDeclaredPairs()
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("200 OK", "", "", "maxstring")

    Kill tQuery
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Do $$$AssertStatusNotOK(tSC, "a MAXSTRING is an error status")
    Do $$$AssertEquals(tHttp, 503, "answered 503")
    Do $$$AssertEquals(tFault.code, "MONITOR.TOOLARGE", "carrying the size code rather than the generic one")
    Do $$$AssertEquals(tFault.reason, ##class(OcuPilot.Port.MonitorPort).#REASONTOOLARGE, "and the size reason")
}

/// <p>AC3 -- an answer whose text is longer than
/// <parameter>OcuPilot.Port.MonitorPort.MAXANSWERCHARS</parameter> is refused rather than cut. This
/// is the size bound itself, which the <code>&lt;MAXSTRING&gt;</code> leg above reaches by a
/// different path: that one is the throw, this one is the length test.</p>
/// <p>Mutation: delete the <parameter>MAXANSWERCHARS</parameter> comparison in
/// <method>OcuPilot.Port.MonitorPort.Outcome</method> -&gt; this reddens and the throw leg does
/// not.</p>
Method TestAnAnswerPastTheCharacterCeilingIsRefused()
{
    Do ..HoldDeclaredPairs()
    Set tFiller = $Justify("", ##class(OcuPilot.Port.MonitorPort).#MAXANSWERCHARS)
    Set tBody = "[{""time"":""2026-09-18T07:33:42.173Z"",""severity"":""2"",""message"":""" _ tFiller _ """}]"
    Do $$$AssertTrue($Length(tBody) > ##class(OcuPilot.Port.MonitorPort).#MAXANSWERCHARS, "the armed answer is past the ceiling: " _ $Length(tBody))
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("200 OK", tBody)

    Kill tQuery
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Do $$$AssertStatusNotOK(tSC, "an answer past the character ceiling is an error status")
    Do $$$AssertEquals(tHttp, 503, "answered 503")
    Do $$$AssertTrue($IsObject(tFault), "with a wire fault")
    If '$IsObject(tFault) Quit
    Do $$$AssertEquals(tFault.code, "MONITOR.TOOLARGE", "carrying the size code")
    Do $$$AssertEquals(tRows, "", "and no rows, because a cut list reads as a complete one")
}

/// <p>AC3 -- an answer carrying more rows than
/// <parameter>OcuPilot.Port.MonitorPort.MAXENTRIES</parameter> is refused rather than cut. The
/// vendor's next cursor names the last row of the whole answer, so a silent cut would hand the
/// caller a cursor past rows it never saw.</p>
/// <p>Mutation: put back the clamp <method>OcuPilot.Port.MonitorPort.Rows</method> applied before
/// the ceiling refusal -&gt; the answer is 200 carrying MAXENTRIES rows and this reddens.</p>
Method TestAnAnswerPastTheRowCeilingIsRefusedRatherThanCut()
{
    Do ..HoldDeclaredPairs()
    Set tCeiling = ##class(OcuPilot.Port.MonitorPort).#MAXENTRIES
    Set tRow = "{""time"":""2026-09-18T07:33:42.173Z"",""severity"":""0"",""message"":""e""}"
    Set tBody = "["
    For tI = 1:1:(tCeiling + 1) {
        Set tBody = tBody _ $Select(tI = 1: "", 1: ",") _ tRow
    }
    Set tBody = tBody _ "]"
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("200 OK", tBody, "09/18/26-07:33:56:057 (892)")

    Kill tQuery
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Do $$$AssertStatusNotOK(tSC, "an answer past the row ceiling is an error status")
    Do $$$AssertEquals(tHttp, 503, "answered 503")
    Do $$$AssertTrue($IsObject(tFault), "with a wire fault")
    If '$IsObject(tFault) Quit
    Do $$$AssertEquals(tFault.code, "MONITOR.TOOLARGE", "carrying the size code rather than a truncated list")
    Do $$$AssertEquals(tRows, "", "and no rows")
    Do $$$AssertEquals(tTag, "", "nor a cursor past rows the caller never saw")

    ; A caller's own cap below the ceiling is an ordinary cap: it truncates, because that caller
    ; asked for a bounded page and the executor reads the truncation signal off the row count.
    Kill tQuery
    Set tQuery("maxRows") = 5
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tCapped, .tHttp, .tFault, .tTag)
    Do $$$AssertStatusOK(tSC, "the same answer under a caller cap below the ceiling is served, not refused")
    Do $$$AssertEquals($Select($IsObject(tCapped): tCapped.%Size(), 1: -1), 5, "at the cap the caller asked for")
}

/// <p>The vendor quotes its severity today, but its signature does not promise to. A row whose
/// severity arrives as a JSON number projects as that number's own spelling, not as
/// <code>""</code> -- an empty severity renders a chip with no level of its own.</p>
/// <p>Mutation: delete the <code>number</code> arm of
/// <method>OcuPilot.Port.MonitorPort.StringOf</method> -&gt; the severity reads <code>""</code> and
/// this reddens.</p>
Method TestANumericSeverityProjectsAsItsOwnSpelling()
{
    Do ..HoldDeclaredPairs()
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("200 OK", "[{""time"":""2026-09-18T07:33:42.173Z"",""severity"":2,""message"":""unquoted""}]")

    Kill tQuery
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Do $$$AssertStatusOK(tSC, "the armed answer is served")
    Do $$$AssertEquals(tRows.%Size(), 1, "one row")
    If tRows.%Size() '= 1 Quit
    Do $$$AssertEquals(tRows.%Get(0).%Get("severity"), "2", "an unquoted severity still reaches the client as text")
    Do $$$AssertEquals(tRows.%Get(0).%Get("text"), "unquoted", "beside its message")
}

/// <p>Text that is not a JSON array is a written refusal, never a 500 naming nothing.</p>
Method TestANonArrayAnswerIsRefusedByName()
{
    Do ..HoldDeclaredPairs()
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("200 OK", "not json at all")

    Kill tQuery
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Do $$$AssertStatusNotOK(tSC, "unparseable text is an error status")
    Do $$$AssertEquals(tFault.code, "MONITOR.FAILED", "carrying the named code")
}

/// <p>A non-2xx vendor status is the same refusal, and the vendor's own error body -- written to the
/// device, as the vendor writes it -- reaches the log rather than the wire (AD-39).</p>
Method TestVendorTextReachesTheLogAndNeverTheWire()
{
    Do ..HoldDeclaredPairs()
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("500 Internal Server Error", "", "", "write")

    Kill tQuery
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Do $$$AssertStatusNotOK(tSC, "a non-2xx vendor status is an error status")
    Do $$$AssertEquals(tFault.code, "MONITOR.FAILED", "carrying the named code")
    Do $$$AssertTrue(tFault.reason '[ "ERROR #", "the wire reason carries no vendor text: " _ tFault.reason)
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") '= "", "and a raw line was logged")
}

/// <p>An endpoint or request type the port does not serve is 501, before any vendor call.</p>
Method TestAnUnknownEndpointIsNotImplemented()
{
    Do ..HoldDeclaredPairs()
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("200 OK", ..#BODY)

    Kill tQuery
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Metrics", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Do $$$AssertStatusNotOK(tSC, "an endpoint the port does not serve is refused")
    Do $$$AssertEquals(tHttp, 501, "answered 501")
    Do $$$AssertEquals(tFault.code, "PORT.NOTIMPLEMENTED", "carrying the not-implemented code")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorSensorFixture).EntryCount(), 0, "and no vendor code ran")
}

/// <p>A tag carrying a control character is refused before the vendor is asked.</p>
Method TestAMalformedTagIsRefusedBeforeTheVendorIsAsked()
{
    Do ..HoldDeclaredPairs()
    Do ##class(OcuPilot.Test.MonitorSensorFixture).Arm("200 OK", ..#BODY)

    Kill tQuery
    Set tQuery("tag") = "09/18/26" _ $Char(10) _ "-07:33:42:173 (892)"
    Set tSC = ##class(OcuPilot.Test.MonitorPortFixture).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Do $$$AssertStatusNotOK(tSC, "a tag carrying a control character is refused")
    Do $$$AssertEquals(tHttp, 400, "answered 400")
    Do $$$AssertEquals(tFault.code, "PORT.VALIDATION", "carrying the validation code")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorSensorFixture).EntryCount(), 0, "and no vendor code ran")
}

/// <p>The real port against the live instance: the caller's namespace is where it was on return, and
/// the answer is an array. This is the only leg that enters <code>%SYS</code> for real.</p>
/// <p><b>It asserts nothing about <parameter>CURSOR</parameter>, and that is deliberate.</b> Measured
/// on this build (2026-09-18, throwaway): <b>every</b> <code>Alerts()</code> call advances
/// <code>^IRIS.Temp.SAM("LastAlertSent")</code> to the newest entry it reported -- tag mode included,
/// and with a tag the vendor matched. Tag mode decides which rows come back, not whether the cursor
/// is written. AC2's second half and the port's own "leaves that global byte-identical" are
/// therefore not properties of this code, and an assertion over that global would pin the instance's
/// state rather than the port's behavior -- DW-1116, which is where the decision lives.</p>
Method TestTheRealPortLeavesTheCallersNamespaceWhereItWas()
{
    Set tOrig = $Namespace
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.MonitorPort).Invoke("Alerts", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tTag)
    Do $$$AssertEquals($Namespace, tOrig, "the caller's namespace is unchanged on return")
    Do $$$AssertStatusOK(tSC, "and the live instance answers its own alerts")
    Do $$$AssertTrue($IsObject(tRows) && tRows.%IsA("%Library.DynamicArray"), "as an array of rows")
}

/// <p>The instance-wide cursor as one comparable string: its value and the values of every subscript
/// under it.</p>
ClassMethod CursorSnapshot() As %String
{
    Set tOrig = $Namespace
    Set tText = ""
    Set $Namespace = "%SYS"
    Try {
        Set tText = $Get(^IRIS.Temp.SAM)
        Set tKey = ""
        For {
            Set tKey = $Order(^IRIS.Temp.SAM(tKey))
            If tKey = "" Quit
            Set tText = tText _ "|" _ tKey _ "=" _ $Get(^IRIS.Temp.SAM(tKey))
        }
    } Catch ex {
        Set tText = "unreadable"
    }
    Set $Namespace = tOrig
    Quit tText
}

}
