/// <p>Pins Story 20.9's message contents read (AD-11, AD-29, AD-36, AD-62) on synthetic headers and bodies stored in the install
/// namespace: an XML body is indented XML and an HL7 body its segments, one line to a row, a line over 4,000 characters ending
/// <code>TESTCUT</code>; a character stream is its text split on any line end; the text is cut at its overall cap and the rows at
/// the row cap; a binary stream and an object that is neither a document, XML nor a character stream are refused 409
/// <code>INTEROP.MESSAGE.CONTENTS</code> after the vendor's view is audited; a header with no body, a body that no longer opens
/// and a class that is gone read as no rows and record no view; an alarm body is read and not audited; and each read that opens a
/// body leaves one <code>%Ensemble/%Message/ViewContents</code> row naming the header, described <code>OcuPilot</code>.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropMessageRead</class> needs, whose fixture it uses, and
/// the audit event <code>%Ensemble/%Message/ViewContents</code> enabled with auditing on (the throwaway's default). It compiles the
/// persistent class <parameter>PLAIN</parameter> in the install namespace for the not-text leg and removes it, with its extent, after
/// the last test; the headers and bodies each test stores are removed after it.</p>
Class OcuPilot.Test.InteropMessageContents Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter FIXTURE = "OcuPilot.Test.InteropMessageRead";

Parameter PLAIN = "OcuPilotProbe.Msg209.Plain";

/// <p>The cut a long line or text ends with.</p>
Parameter CUT = " ... [cut]";

/// <p>This test's run token and its fixture headers' ids, oldest first (see <class>OcuPilot.Test.InteropMessageRead</class>). The
/// prefix must not begin with "Test" (<file>.claude/rules/objectscript-testing.md</file>).</p>
Property PreparedRun As %String;

Property PreparedIds As %List;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedRun = ""
    Set ..PreparedIds = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    Do ..RemovePlain()
    Set tClass = ##class(%Dictionary.ClassDefinition).%New(..#PLAIN)
    Set tClass.Super = "%Persistent"
    Set tProperty = ##class(%Dictionary.PropertyDefinition).%New()
    Set tProperty.Name = "Note"
    Set tProperty.Type = "%String"
    Do tClass.Properties.Insert(tProperty)
    Set tSC = tClass.%Save()
    If $$$ISOK(tSC) Set tSC = $System.OBJ.Compile(..#PLAIN, "-d")
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Do ..RemovePlain()
    Do $$$AssertEquals(##class(%Dictionary.ClassDefinition).%ExistsId(..#PLAIN), 0, "the probe class is removed")
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "RemoveAll")
    Set ..PreparedRun = $Extract($Translate($System.Util.CreateGUID(), "-", ""), 1, 8)
    Set tSC = $ClassMethod(..#FIXTURE, "CreateFixture", ..PreparedRun, .tIds)
    Set ..PreparedIds = tIds
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "RemoveAll")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "LeftBehind"), 0, "no header of the fixture's marker is left")
    Quit $$$OK
}

/// <p>Drop the probe class's extent and the class itself.</p>
ClassMethod RemovePlain()
{
    Try {
        If ##class(%Dictionary.CompiledClass).%ExistsId(..#PLAIN) Do $ClassMethod(..#PLAIN, "%KillExtent")
    } Catch {
    }
    Try {
        If ##class(%Dictionary.ClassDefinition).%ExistsId(..#PLAIN) Do $System.OBJ.Delete(..#PLAIN, "-d")
    } Catch {
    }
}

/// <p>Store a header made a minute ago naming the body <var>pBodyClass</var> <var>pBodyId</var>, with this test's marker, and answer
/// its id.</p>
Method HeaderFor(pBodyClass As %String, pBodyId As %String) As %Integer
{
    Quit $ClassMethod(..#FIXTURE, "StoreHeader", ..PreparedRun, pBodyClass, pBodyId, 1, 9, 60, "")
}

/// <p>The rows the port's <code>MessageContents</code> answers for header <var>pId</var>, or <code>""</code> when it refuses; the
/// HTTP status in <var>pHttp</var> and the fault in <var>pFault</var>. <var>pMax</var> caps the lines.</p>
ClassMethod Lines(pId As %String, Output pHttp As %Integer, Output pFault, pMax As %Integer = 1000) As %DynamicArray
{
    Set tQuery("message") = pId
    Set tQuery("maxRows") = pMax
    Quit $ClassMethod(..#FIXTURE, "Rows", "MessageContents", .tQuery, .pHttp, .pFault)
}

/// <p>Store a character stream of <var>pLines</var> lines of 999 <code>x</code> and a line feed (1,000 characters each), then
/// <var>pTail</var>, and answer it. The caller deletes it.</p>
ClassMethod CapStream(pLines As %Integer, pTail As %String = "") As %Stream.GlobalCharacter
{
    Set tStream = ##class(%Stream.GlobalCharacter).%New()
    Set tLine = $Translate($Justify("", 999), " ", "x") _ $Char(10)
    For tI = 1:1:pLines Do tStream.Write(tLine)
    If pTail '= "" Do tStream.Write(pTail)
    Do tStream.%Save()
    Quit tStream
}

/// <p>The <code>Text</code> of each of <var>pRows</var>, joined by <code>/</code>.</p>
ClassMethod Texts(pRows As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pRows) Quit "none"
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tIndex = 0: "", 1: "/") _ tRow.Text
    }
    Quit tText
}

/// <p>The audit database's own clock (<method>OcuPilot.Test.AuditEvent.Now</method>).</p>
ClassMethod Now() As %String
{
    Quit ##class(OcuPilot.Test.AuditEvent).Now()
}

/// <p>How many <code>%Ensemble/%Message/ViewContents</code> rows since <var>pSince</var> name header <var>pId</var>, with the last such
/// row's description in <var>pDescription</var>; <code>-1</code> when the read failed. Read as
/// <method>OcuPilot.Test.AuditEvent.RowsCarrying</method> reads OcuPilot's own events.</p>
ClassMethod Views(pSince As %String, pId As %String, Output pDescription As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ViewContents", "MessageHeaderId = " _ pId _ ",", .tData, "", "%Ensemble", "%Message", .pDescription)
}

/// <p>AC3: an XML body is its indented XML, one line to a row, its <code>&lt;&amp;&gt;</code> literal; the read leaves one view row
/// for the header, described <code>OcuPilot</code>, and a second read a second row.</p>
/// <p>Mutation (Rule 19): remove the <code>AuditViewMessage</code> call from <method>OcuPilot.Port.InteropPort.AuditViewHere</method> --
/// the audit legs go red, alone.</p>
Method TestTheXmlBodyIsIndentedXmlAndItsViewIsAudited()
{
    Set tXml = $List(..PreparedIds, 2)
    Set tSince = ..Now()
    Set tRows = ..Lines(tXml, .tHttp)
    Do $$$AssertEquals(tHttp, 200, "the contents answer")
    Do $$$AssertTrue($IsObject(tRows), "with rows")
    If '$IsObject(tRows) Quit
    Do $$$AssertEquals(tRows.%Size(), 3, "three lines")
    Do $$$AssertEquals(tRows.%Get(0).%GetTypeOf("Line") _ "|" _ tRows.%Get(0).Line _ "|" _ tRows.%Get(2).Line _ "|" _ tRows.%Get(0).Message, "number|1|3|" _ tXml, "numbered from 1, as numbers, for the message")
    Do $$$AssertEquals(tRows.%Get(0).Text, "<StringRequest>", "the root opens the first line")
    Do $$$AssertEquals(tRows.%Get(1).Text, "  <StringValue><![CDATA[" _ $Parameter(..#FIXTURE, "MARKER") _ ..PreparedRun _ " <&> text]]></StringValue>", "its value is indented and its <&> is literal")
    Do $$$AssertEquals(tRows.%Get(2).Text, "</StringRequest>", "the root closes the last")
    Do $$$AssertEquals(..Views(tSince, tXml, .tDescription), 1, "one ViewContents row names the header")
    Do $$$AssertEquals(tDescription, "OcuPilot", "described OcuPilot")
    Do ..Lines(tXml)
    Do $$$AssertEquals(..Views(tSince, tXml), 2, "and a second read a second row")
}

/// <p>AC3: an HL7 body is its segments, one to a row, and a segment over 4,000 characters ends <code>TESTCUT</code> after its first
/// 4,000.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ReadMessageContents</method> stops cutting lines -- this goes red.</p>
Method TestTheHl7BodyIsItsSegmentsAndALongLineIsCut()
{
    Set tHl7 = $List(..PreparedIds, 3)
    Set tRows = ..Lines(tHl7, .tHttp)
    Do $$$AssertEquals(tHttp, 200, "the contents answer")
    Do $$$AssertTrue($IsObject(tRows), "with rows")
    If '$IsObject(tRows) Quit
    Do $$$AssertEquals(tRows.%Size(), 2, "two segments, two lines")
    Do $$$AssertEquals($Extract(tRows.%Get(0).Text, 1, 9), "MSH|^~\&|", "the first is the MSH segment")
    Set tPid = tRows.%Get(1).Text
    Do $$$AssertEquals($Extract(tPid, 1, 7), "PID|1||", "the second is the PID segment")
    Do $$$AssertEquals($Length(tPid), 4000 + $Length(..#CUT), "cut at 4,000 characters and the cut added")
    Do $$$AssertEquals($Extract(tPid, $Length(tPid) - $Length(..#CUT) + 1, *), ..#CUT, "and it ends the cut")
    Do $$$AssertEquals($Parameter(..#PORT, "TESTCUT"), ..#CUT, "the cut is the port's own")
}

/// <p>AC3: a character stream is its text, split on <code>CRLF</code>, <code>LF</code> and <code>CR</code>, an empty line kept and a
/// final terminator ending the last line.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ReadMessageContents</method> splits on <code>LF</code> alone -- this goes
/// red.</p>
Method TestACharacterStreamIsItsTextSplitOnAnyLineEnd()
{
    Set tStream = ##class(%Stream.GlobalCharacter).%New()
    Do tStream.Write("alpha" _ $Char(13, 10) _ "beta" _ $Char(10) _ $Char(10) _ "gamma" _ $Char(13) _ "delta" _ $Char(10))
    Set tSC = tStream.%Save()
    Do $$$AssertStatusOK(tSC, "the stream is stored")
    Set tId = ..HeaderFor("%Stream.GlobalCharacter", tStream.%Id())
    Set tRows = ..Lines(tId, .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ ..Texts(tRows), "200|alpha/beta//gamma/delta", "five lines, the empty one kept")
    Do $ClassMethod("%Stream.GlobalCharacter", "%DeleteId", tStream.%Id())
}

/// <p>AC3: a binary stream and an object that is neither a document, XML nor a character stream are refused 409
/// <code>INTEROP.MESSAGE.CONTENTS</code> with the published sentence, after the vendor's view was audited.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ContentsText</method> reads a binary stream as text -- the binary leg goes
/// red.</p>
Method TestABodyThatIsNotTextIsRefusedAfterItsViewIsAudited()
{
    Set tBinary = ##class(%Stream.GlobalBinary).%New()
    Do tBinary.Write("binary body")
    Do tBinary.%Save()
    Set tBinaryId = ..HeaderFor("%Stream.GlobalBinary", tBinary.%Id())
    Set tPlain = $ClassMethod(..#PLAIN, "%New")
    Set tPlain.Note = "an object, not text"
    Do tPlain.%Save()
    Set tPlainId = ..HeaderFor(..#PLAIN, tPlain.%Id())
    For tEntry = $ListBuild("a binary stream", tBinaryId), $ListBuild("a plain persistent object", tPlainId) {
        Set tSince = ..Now()
        Set tRows = ..Lines($List(tEntry, 2), .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code _ "|" _ tFault.reason, 1: ""), "409|INTEROP.MESSAGE.CONTENTS|OcuPilot cannot show this message body as text.", $List(tEntry, 1) _ " is refused with the published sentence")
        Do $$$AssertEquals($IsObject(tRows), 0, $List(tEntry, 1) _ ": no row")
        Do $$$AssertEquals(..Views(tSince, $List(tEntry, 2)), 1, $List(tEntry, 1) _ ": its view was recorded before the refusal")
    }
    Do $ClassMethod("%Stream.GlobalBinary", "%DeleteId", tBinary.%Id())
    Do $ClassMethod(..#PLAIN, "%DeleteId", tPlain.%Id())
}

/// <p>AC3: a header with no body, one whose body no longer opens (an object or a stream) and one whose body class is gone each read
/// as no rows and record no view; an unknown header reads as no rows.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ContentsText</method> audits before it opens the body -- the no-view legs
/// go red; <method>OcuPilot.Port.InteropPort.OpenBodyHere</method> without its <code>%ExistsId</code> test -- the stream leg goes red,
/// alone (a stream class opens an id it does not hold as an empty stream).</p>
Method TestAMessageWithNothingToShowReadsAsNoRowsAndRecordsNoView()
{
    Set tSince = ..Now()
    Set tNone = $List(..PreparedIds, 4)
    Set tText = ##class(Ens.StringRequest).%New()
    Set tText.StringValue = "gone soon"
    Do tText.%Save()
    Set tVanished = ..HeaderFor("Ens.StringRequest", tText.%Id())
    Do ##class(Ens.StringRequest).%DeleteId(tText.%Id())
    Set tStream = ##class(%Stream.GlobalCharacter).%New()
    Do tStream.Write("gone soon")
    Do tStream.%Save()
    Set tStreamGone = ..HeaderFor("%Stream.GlobalCharacter", tStream.%Id())
    Do ##class(%Stream.GlobalCharacter).%DeleteId(tStream.%Id())
    Set tNoClass = ..HeaderFor("OcuPilotProbe.Msg209.NoSuchClass", "1")
    For tEntry = $ListBuild("a header with no body", tNone), $ListBuild("a body that no longer opens", tVanished), $ListBuild("a stream that no longer opens", tStreamGone), $ListBuild("a body class that is gone", tNoClass), $ListBuild("a header no row holds", "9223372036854775") {
        Set tRows = ..Lines($List(tEntry, 2), .tHttp)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tRows): tRows.%Size(), 1: "none"), "200|0", $List(tEntry, 1) _ " reads as no rows")
        Do $$$AssertEquals(..Views(tSince, $List(tEntry, 2)), 0, $List(tEntry, 1) _ ": and records no view")
    }
}

/// <p>AC3: the text is cut at its overall cap of 1,000,000 characters and the last line ends the cut; a lower line cap answers its
/// lines and the read route says it truncated.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ReadMessageContents</method> without its <parameter>TESTOUTPUTMAX</parameter> cut -- row 1,001 reads <code>x ... [cut]</code> and the overall leg goes red.</p>
Method TestTheTextIsCutAtItsOverallCapAndTheLinesAtTheRowCap()
{
    Set tStream = ..CapStream(1200)
    Set tId = ..HeaderFor("%Stream.GlobalCharacter", tStream.%Id())
    Set tQuery("message") = tId
    Set tQuery("maxRows") = 5000
    Set tRows = $ClassMethod(..#FIXTURE, "Rows", "MessageContents", .tQuery, .tHttp)
    Do $$$AssertEquals(tHttp, 200, "the long stream answers")
    Do $$$AssertTrue($IsObject(tRows), "with rows")
    If $IsObject(tRows) {
        Do $$$AssertEquals(tRows.%Size(), 1001, "a thousand full lines, which fill the cap, and the cut")
        Do $$$AssertEquals(tRows.%Get(1000).Text, ..#CUT, "the last line is the cut alone")
        Do $$$AssertEquals($Length(tRows.%Get(0).Text), 999, "the lines before it are whole")
    }
    Do $ClassMethod("%Stream.GlobalCharacter", "%DeleteId", tStream.%Id())
    Set tXml = $List(..PreparedIds, 2)
    Set tCriteria("message") = tXml
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.InteropMessageContentsTab", 2, .tAnswer, .tRouteHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(tRouteHttp, 200, "the read route answers")
    Do $$$AssertTrue($IsObject($Get(tAnswer)), "with an answer")
    If $IsObject($Get(tAnswer)) Do $$$AssertEquals(tAnswer.rows.%Size() _ "|" _ tAnswer.truncated, "2|1", "two lines of three, truncated")
}

/// <p>AC3: a text of exactly the overall cap is shown whole with no cut, and one character more is cut at the cap and ends with the
/// cut alone.</p>
/// <p>Mutation (Rule 19): the length test in <method>OcuPilot.Port.InteropPort.ReadMessageContents</method> is <code>&gt;=</code> -- the
/// exact-cap leg goes red; it is <code>&gt; TESTOUTPUTMAX + 1</code> -- the one-over leg goes red.</p>
Method TestATextAtTheCapIsWholeAndOneCharacterOverIsCut()
{
    Set tExact = ..CapStream(1000)
    Set tOver = ..CapStream(1000, "x")
    Set tExactRows = ..Lines(..HeaderFor("%Stream.GlobalCharacter", tExact.%Id()), .tExactHttp, , 5000)
    Set tOverRows = ..Lines(..HeaderFor("%Stream.GlobalCharacter", tOver.%Id()), .tOverHttp, , 5000)
    Do $$$AssertEquals(tExactHttp _ "|" _ tOverHttp, "200|200", "both streams answer")
    Do $$$AssertTrue($IsObject(tExactRows) && $IsObject(tOverRows), "with rows")
    If $IsObject(tExactRows) && $IsObject(tOverRows) {
        Set tWhole = $Translate($Justify("", 999), " ", "x")
        Do $$$AssertEquals(tExactRows.%Size() _ "|" _ tExactRows.%Get(tExactRows.%Size() - 1).Text, "1000|" _ tWhole, "exactly the cap is its thousand whole lines and no cut")
        Do $$$AssertEquals(tOverRows.%Size() _ "|" _ tOverRows.%Get(tOverRows.%Size() - 1).Text, "1001|" _ ..#CUT, "one character over ends with the cut alone")
    }
    Do $ClassMethod("%Stream.GlobalCharacter", "%DeleteId", tExact.%Id())
    Do $ClassMethod("%Stream.GlobalCharacter", "%DeleteId", tOver.%Id())
}

/// <p>An alarm body is read as any message body and its view is not audited, as the classic Contents pane skips it.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.AuditViewHere</method> without its alarm test -- this goes red.</p>
Method TestAnAlarmBodyIsReadAndItsViewIsNotAudited()
{
    Set tAlarm = ##class(Ens.AlarmRequest).%New()
    Set tAlarm.Timeout = "5"
    Set tSC = tAlarm.%Save()
    Do $$$AssertStatusOK(tSC, "the alarm is stored")
    Set tId = ..HeaderFor("Ens.AlarmRequest", tAlarm.%Id())
    Set tSince = ..Now()
    Set tRows = ..Lines(tId, .tHttp)
    Do $$$AssertEquals(tHttp, 200, "the alarm answers")
    Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() > 0), "with lines")
    Do $$$AssertEquals(..Views(tSince, tId), 0, "and records no view")
    Do ##class(Ens.AlarmRequest).%DeleteId(tAlarm.%Id())
}

}
