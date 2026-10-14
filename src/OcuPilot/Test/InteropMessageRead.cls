/// <p>Pins Story 20.9's message search and header reads (AD-21, AD-29, AD-36, AD-37, AD-62) on synthetic message headers it stores
/// in the install namespace: each criterion of <code>Messages</code> narrows alone and together, newest first; the window is the
/// classic viewer's ID bounds (a header made two days earlier is left out of the default window); a cap truncates through the read
/// route; each malformed criterion is refused by name and an empty begin is refused; a caller's value is bound, never run as SQL;
/// <code>MessageHeader</code> answers the twenty-three properties in order, with local stamps and the error text; an id no header
/// holds reads as no rows and a malformed one is refused; and the read route, the read tool and the port answer the same rows.</p>
/// <p><b>What it needs from the environment:</b> the install namespace running interoperability, and the account running it holding
/// the pairs the gate asks. It needs no production: the headers are stored directly, found by a marker in their source and target,
/// and removed with their bodies after each test. It reads and writes no other header.</p>
Class OcuPilot.Test.InteropMessageRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter MARKER = "OcuPilotProbe209";

Parameter SCREENPREFIX = "OcuPilot.Screen.Descriptor.";

/// <p>This run's token, so a leftover of an earlier run is told from this run's rows. The prefix must not begin with "Test"
/// (<file>.claude/rules/objectscript-testing.md</file>).</p>
Property PreparedRun As %String;

/// <p>The ids of the five headers: the one made two days ago, the XML one, the HL7 one, the one with no body and the one with a
/// source and target of its own (<method>CreateFixture</method>).</p>
Property PreparedIds As %List;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedRun = ""
    Set ..PreparedIds = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ..RemoveAll()
    Set ..PreparedRun = $Extract($Translate($System.Util.CreateGUID(), "-", ""), 1, 8)
    Set tSC = ..CreateFixture(..PreparedRun, .tIds)
    Set ..PreparedIds = tIds
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ..RemoveAll()
    Do $$$AssertEquals(..LeftBehind(), 0, "no header of this class's marker is left")
    Quit $$$OK
}

/// <p>The marker this run's headers carry in their source and target: <parameter>MARKER</parameter>, the run token.</p>
Method Marker() As %String
{
    Quit ..#MARKER _ ..PreparedRun
}

/// <p>The UTC stamp <var>pSeconds</var> before now, in the form a header's <code>TimeCreated</code> is stored in.</p>
ClassMethod UtcAgo(pSeconds As %Integer) As %String
{
    Set tNow = $ZTimeStamp
    Set tDays = $Piece(tNow, ",", 1)
    Set tSeconds = $Piece(tNow, ",", 2) - pSeconds
    While tSeconds < 0 {
        Set tSeconds = tSeconds + 86400
        Set tDays = tDays - 1
    }
    Quit $ZDateTime(tDays _ "," _ tSeconds, 3, , 3)
}

/// <p>The instance's local clock time <var>pSeconds</var> before now, as <code>YYYY-MM-DD HH:MM:SS</code>, converted by the
/// vendor's own datatype.</p>
ClassMethod LocalAgo(pSeconds As %Integer) As %String
{
    Quit $Extract(##class(Ens.DataType.UTC).LogicalToOdbc(..UtcAgo(pSeconds)), 1, 19)
}

/// <p>Store one header whose source is <var>pRun</var>'s marker plus <code>Src</code> and whose target is the marker plus
/// <code>Op</code>, each followed by <var>pSuffix</var>, made <var>pAgo</var> seconds ago, naming the body <var>pBodyClass</var>
/// <var>pBodyId</var>, and answer its id (0 when it could not be stored). <var>pSession</var>, when given, is the session id it
/// carries; <var>pErrorText</var>, when given, marks it as an error with that text; <var>pSetOwnSession</var> makes its own id its
/// session.</p>
ClassMethod StoreHeader(pRun As %String, pBodyClass As %String, pBodyId As %String, pType As %Integer, pStatus As %Integer, pAgo As %Integer, pSession As %String, pErrorText As %String = "", pSetOwnSession As %Boolean = 0, pSuffix As %String = "") As %Integer
{
    Set tHeader = ##class(Ens.MessageHeader).%New()
    Set tHeader.SourceConfigName = ..#MARKER _ pRun _ "Src" _ pSuffix
    Set tHeader.TargetConfigName = ..#MARKER _ pRun _ "Op" _ pSuffix
    Set tHeader.MessageBodyClassName = pBodyClass
    Set tHeader.MessageBodyId = pBodyId
    Set tHeader.Type = pType
    Set tHeader.Priority = 6
    Set tHeader.Status = pStatus
    Set tHeader.TimeCreated = ..UtcAgo(pAgo)
    Set tHeader.TimeProcessed = ..UtcAgo(pAgo)
    If pSession '= "" Set tHeader.SessionId = pSession
    If pErrorText '= "" {
        Set tHeader.IsError = 1
        Set tHeader.ErrorStatus = $$$ERROR($$$GeneralError, pErrorText)
    }
    Set tSC = tHeader.%Save()
    If $$$ISERR(tSC) Quit 0
    If pSetOwnSession {
        Set tHeader.SessionId = tHeader.%Id()
        Set tSC = tHeader.%Save()
        If $$$ISERR(tSC) Quit 0
    }
    Quit tHeader.%Id()
}

/// <p>Store the fixture's other header (<method>CreateFixture</method>) and answer its id (0 when it could not be stored): a Response,
/// Deferred, ten minutes after the default window opens, with a source and a target of its own and a distinct, non-default value for
/// every other header property, so a Header read that put a value under another property's name is told from a right one.</p>
ClassMethod StoreFullHeader(pRun As %String) As %Integer
{
    Set tId = ..StoreHeader(pRun, "", "body-77", 2, 6, 85800, 9001, "", 0, "Other")
    If 'tId Quit 0
    Set tHeader = ##class(Ens.MessageHeader).%OpenId(tId)
    Set tHeader.Priority = 3
    Set tHeader.Invocation = 2
    Set tHeader.SourceBusinessType = 1
    Set tHeader.TargetBusinessType = 3
    Set tHeader.SuperSession = "OcuPilotSuper209"
    Set tHeader.CorrespondingMessageId = 4242
    Set tHeader.BusinessProcessId = 5151
    Set tHeader.TargetQueueName = "OcuPilotTargetQueue209"
    Set tHeader.ReturnQueueName = "OcuPilotReturnQueue209"
    Set tHeader.Description = "OcuPilot full header 209"
    Set tHeader.Resent = 3
    If $$$ISERR(tHeader.%Save()) Quit 0
    Quit tId
}

/// <p>The fixture of Design Notes: the headers <var>pIds</var> (<code>$ListBuild(old, xml, hl7, none, other)</code>), created in the
/// order old, other, xml, hl7, none so their ids rise with their times. Old: Completed, two days ago. Other: <method>StoreFullHeader</method>'s
/// header, ten minutes after the default window opens, with a source and a target of its own. It anchors the default window's first ID bound at a header
/// the fixture made, so a header another test or a production left behind cannot move the bound below Old, and it is the header
/// every criterion test must leave out. XML: an <code>Ens.StringRequest</code> holding the marker and <code>&lt;&amp;&gt;</code>,
/// Completed, 30 minutes ago, its session its own id. HL7: an <code>EnsLib.HL7.Message</code> read from text through a character
/// stream, with a PID segment of 5,000 characters, Error with an error status, 20 minutes ago, in the XML header's session. None: a
/// Response with no body and no session, 10 minutes ago.</p>
ClassMethod CreateFixture(pRun As %String, Output pIds As %List) As %Status
{
    Set pIds = ""
    Set tSC = $$$OK
    Try {
        Set tOld = ..StoreHeader(pRun, "", "", 1, 9, 172800, "")
        Set tOther = ..StoreFullHeader(pRun)
        Set tText = ##class(Ens.StringRequest).%New()
        Set tText.StringValue = ..#MARKER _ pRun _ " <&> text"
        Set tSC = tText.%Save()
        If $$$ISERR(tSC) Quit
        Set tXml = ..StoreHeader(pRun, "Ens.StringRequest", tText.%Id(), 1, 9, 1800, "", "", 1)
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        Do tStream.Write("MSH|^~\&|SND|FAC|RCV|FAC|20260101120000||ADT^A01|" _ pRun _ "|P|2.5" _ $Char(13) _ "PID|1||" _ $Translate($Justify("", 4993), " ", "X") _ $Char(13))
        Do tStream.Rewind()
        Set tDocument = ##class(EnsLib.HL7.Message).ImportFromLibraryStream(tStream, .tSC)
        If $$$ISERR(tSC) Quit
        Set tSC = tDocument.%Save()
        If $$$ISERR(tSC) Quit
        Set tHl7 = ..StoreHeader(pRun, "EnsLib.HL7.Message", tDocument.%Id(), 1, 8, 1200, tXml, "OcuPilot probe error " _ pRun)
        Set tNone = ..StoreHeader(pRun, "", "", 2, 9, 600, "")
        If '(tOld && tOther && tXml && tHl7 && tNone) Set tSC = $$$ERROR($$$GeneralError, "a fixture header could not be stored")
        Set pIds = $ListBuild(tOld, tXml, tHl7, tNone, tOther)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every header whose source starts with <parameter>MARKER</parameter>, with the body each names, so a leftover of an
/// earlier run goes too.</p>
ClassMethod RemoveAll()
{
    Try {
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT ID, MessageBodyClassName, MessageBodyId FROM Ens.MessageHeader WHERE SourceConfigName %STARTSWITH ?", ..#MARKER)
        Kill tFound
        While tResult.%Next() {
            Set tFound($Increment(tFound)) = $ListBuild(tResult.%GetData(1), tResult.%GetData(2), tResult.%GetData(3))
        }
        For tI = 1:1:+$Get(tFound) {
            Set tLine = tFound(tI)
            Do ##class(Ens.MessageHeader).%DeleteId($List(tLine, 1))
            If ($List(tLine, 2) '= "") && $Match($List(tLine, 2), "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") && ##class(%Dictionary.CompiledClass).%ExistsId($List(tLine, 2)) {
                Try {
                    Do $ClassMethod($List(tLine, 2), "%DeleteId", $List(tLine, 3))
                } Catch {
                }
            }
        }
    } Catch {
    }
}

/// <p>How many headers of this class's marker are stored.</p>
ClassMethod LeftBehind() As %Integer
{
    Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT COUNT(*) FROM Ens.MessageHeader WHERE SourceConfigName %STARTSWITH ?", ..#MARKER)
    If tResult.%Next() Quit tResult.%GetData(1)
    Quit -1
}

/// <p>The <code>TimeCreated</code> header <var>pId</var> is stored with, UTC, as the instance keeps it.</p>
ClassMethod StoredCreated(pId As %String) As %String
{
    Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT TimeCreated FROM Ens.MessageHeader WHERE ID = ?", pId)
    If tResult.%Next() Quit tResult.%GetData(1)
    Quit ""
}

/// <p>The rows the port's <var>pEndpoint</var> answers for the query <var>pQuery</var>, in the install namespace, or <code>""</code>
/// when it refuses; the HTTP status in <var>pHttp</var> and the fault in <var>pFault</var>.</p>
ClassMethod Rows(pEndpoint As %String, ByRef pQuery, Output pHttp As %Integer, Output pFault) As %DynamicArray
{
    Set pQuery("namespace") = $NAMESPACE
    Set pQuery("maxRows") = $Get(pQuery("maxRows"), 1000)
    Set pHttp = 0
    Set pFault = ""
    Set tSC = $ClassMethod(..#PORT, "Invoke", pEndpoint, "LIST", .pQuery, "", .tResult, .pHttp, .pFault)
    Quit $Select($IsObject($Get(tResult)): tResult, 1: "")
}

/// <p>The ids of <var>pRows</var>, in the order they come, comma-separated.</p>
ClassMethod Ids(pRows As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pRows) Quit "none"
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.%Get("ID")
    }
    Quit tText
}

/// <p>The ids a search for this run's headers answers, newest first, with <var>pQuery</var> narrowing it further; the search always
/// carries the marker as its source unless <var>pQuery</var> names a source or a target of its own.</p>
Method Search(ByRef pQuery, Output pHttp As %Integer, Output pFault) As %String
{
    If '$Data(pQuery("beginDateTime")) Set pQuery("beginDateTime") = ..LocalAgo(86400)
    If '$Data(pQuery("source")) && '$Data(pQuery("target")) Set pQuery("source") = ..Marker() _ "Src"
    Quit ..Ids(..Rows("Messages", .pQuery, .pHttp, .pFault))
}

/// <p>The fixture's ids, <code>xml,hl7,none</code> newest first: the three headers the default window holds.</p>
Method Newest() As %String
{
    Quit $List(..PreparedIds, 4) _ "," _ $List(..PreparedIds, 3) _ "," _ $List(..PreparedIds, 2)
}

/// <p>AC1: each criterion narrows the search alone, beside the marker that keeps it to this run's rows, and together; rows come
/// newest first. The default window holds the three recent headers and not the one made two days ago. The fixture's other header
/// sits in the window with a source and a target of its own, so a search by this run's source or target must leave it out.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ListMessages</method> without its <code>Status = ?</code> fragment -- the status
/// leg goes red; without its <code>IsError = ?</code> fragment -- the errors leg goes red; without its
/// <code>SourceConfigName = ?</code> or its <code>TargetConfigName = ?</code> fragment -- the other header joins the rows and the
/// source or the target legs go red.</p>
Method TestEveryCriterionNarrowsAloneAndTogether()
{
    Set tHl7 = $List(..PreparedIds, 3)
    Set tNone = $List(..PreparedIds, 4)
    Set tXml = $List(..PreparedIds, 2)
    Do $$$AssertEquals(..Search(.tQ0, .tHttp), ..Newest(), "the default window and the marker's source give the three recent headers, newest first")
    Do $$$AssertEquals(tHttp, 200, "answered 200")
    Kill tQ1
    Set tQ1("status") = "Error"
    Do $$$AssertEquals(..Search(.tQ1), tHl7, "status Error leaves the error header")
    Kill tQ2
    Set tQ2("type") = "Response"
    Do $$$AssertEquals(..Search(.tQ2), tNone, "type Response leaves the response")
    Kill tQ3
    Set tQ3("target") = ..Marker() _ "Op"
    Do $$$AssertEquals(..Search(.tQ3), ..Newest(), "the target alone, with no source, gives the three and not the other header")
    Kill tQ11
    Set tQ11("source") = ..Marker() _ "SrcOther"
    Do $$$AssertEquals(..Search(.tQ11), $List(..PreparedIds, 5), "the other header's own source leaves it alone")
    Kill tQ12
    Set tQ12("target") = ..Marker() _ "OpOther"
    Do $$$AssertEquals(..Search(.tQ12), $List(..PreparedIds, 5), "and its own target leaves it alone")
    Kill tQ4
    Set tQ4("bodyClass") = "EnsLib.HL7.Message"
    Do $$$AssertEquals(..Search(.tQ4), tHl7, "the body class leaves the HL7 header")
    Kill tQ5
    Set tQ5("session") = tXml
    Do $$$AssertEquals(..Search(.tQ5), tHl7 _ "," _ tXml, "the session gives the two headers that share it, the first among them")
    Kill tQ6
    Set tQ6("errors") = "yes"
    Do $$$AssertEquals(..Search(.tQ6), tHl7, "errors yes leaves the header marked as an error")
    Kill tQ7
    Set tQ7("errors") = "no"
    Do $$$AssertEquals(..Search(.tQ7), tNone _ "," _ tXml, "errors no leaves the others")
    Kill tQ8
    Set tQ8("source") = $ZConvert(..Marker() _ "Src", "L")
    Do $$$AssertEquals(..Search(.tQ8), ..Newest(), "a source in another letter case matches, as the column's collation does")
    Kill tQ9
    Set tQ9("status") = "Error", tQ9("type") = "Request", tQ9("bodyClass") = "EnsLib.HL7.Message", tQ9("session") = tXml, tQ9("errors") = "yes", tQ9("target") = ..Marker() _ "Op"
    Do $$$AssertEquals(..Search(.tQ9), tHl7, "every criterion together leaves the one header that meets them all")
    Set tQ9("status") = "Completed"
    Do $$$AssertEquals(..Search(.tQ9, .tHttp), "", "and one criterion that does not hold leaves none: " _ tHttp)
    Kill tQ10
    Set tQ10("source") = "x' OR '1'='1", tQ10("target") = "x' OR '1'='1"
    Do $$$AssertEquals(..Search(.tQ10, .tHttp) _ "|" _ tHttp, "|200", "a caller's value is bound, never run as SQL")
}

/// <p>AC1: the window is the first ID at or after the start and the last ID at or before the end. The default window leaves out the
/// header made two days earlier and a wider one holds it, last; an end at the XML header's own second holds it (the end runs to
/// the last millisecond of its second); a begin between the HL7 and the last header leaves the last; a window in the future holds
/// none.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ListMessages</method> without its lower ID bound -- the first leg goes red;
/// without its <code>.999</code> -- the end-second leg goes red.</p>
Method TestTheWindowIsTheIdRangeBetweenTheBounds()
{
    Set tOld = $List(..PreparedIds, 1)
    Set tXml = $List(..PreparedIds, 2)
    Set tNone = $List(..PreparedIds, 4)
    Kill tQ
    Set tQ("beginDateTime") = ..LocalAgo(86400)
    Do $$$AssertEquals(..Search(.tQ), ..Newest(), "the default window leaves out the header made two days ago")
    Kill tQ
    Set tQ("beginDateTime") = ..LocalAgo(259200)
    Do $$$AssertEquals(..Search(.tQ), ..Newest() _ "," _ tOld, "a three-day window holds it, last")
    Kill tQ
    Set tQ("beginDateTime") = ..LocalAgo(259200), tQ("endDateTime") = ..LocalAgo(1500)
    Do $$$AssertEquals(..Search(.tQ), tXml _ "," _ tOld, "an end 25 minutes ago leaves the two headers made before it")
    Kill tQ
    Set tXmlSecond = $Extract(##class(Ens.DataType.UTC).LogicalToOdbc(..StoredCreated(tXml)), 1, 19)
    Set tQ("beginDateTime") = ..LocalAgo(259200), tQ("endDateTime") = tXmlSecond
    Do $$$AssertEquals(..Search(.tQ), tXml _ "," _ tOld, "an end at the second the XML header was made in holds it, with its fraction, and the one before: " _ tXmlSecond)
    Kill tQ
    Set tQ("beginDateTime") = ..LocalAgo(900)
    Do $$$AssertEquals(..Search(.tQ), tNone, "a begin between the HL7 and the last header leaves the last")
    Kill tQ
    Set tQ("beginDateTime") = ..LocalAgo(-3600)
    Do $$$AssertEquals(..Search(.tQ, .tHttp), "", "a window that begins in the future holds none: " _ tHttp)
    Kill tQ
    Set tQ("beginDateTime") = ..LocalAgo(86400), tQ("endDateTime") = ..LocalAgo(259200)
    Do $$$AssertEquals(..Search(.tQ, .tHttp), "", "an end before the begin holds none: " _ tHttp)
}

/// <p>AC1: more matches than <code>maxRows</code> answer the newest <code>maxRows</code> through the port, and through the read
/// route, which says it truncated.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ListMessages</method> ignores <code>maxRows</code> and always asks for
/// <parameter>OcuPilot.Port.InteropPort.SQLMAX</parameter> -- this goes red.</p>
Method TestACapTruncatesThroughTheReadRoute()
{
    Kill tQ
    Set tQ("maxRows") = 2
    Do $$$AssertEquals(..Search(.tQ), $List(..PreparedIds, 4) _ "," _ $List(..PreparedIds, 3), "the port answers the newest two of the three")
    Kill tCriteria
    Set tCriteria("source") = ..Marker() _ "Src"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREENPREFIX _ "InteropMessageList", 2, .tAnswer, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(tHttp, 200, "the read route answers")
    Do $$$AssertTrue($IsObject($Get(tAnswer)), "with an answer")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(tAnswer.rows.%Size() _ "|" _ tAnswer.truncated, "2|1", "two rows and the truncated flag")
    Do $$$AssertEquals(..Ids(tAnswer.rows), $List(..PreparedIds, 4) _ "," _ $List(..PreparedIds, 3), "the newest two")
}

/// <p>AC1: each malformed criterion is refused 400 <code>PORT.VALIDATION</code> naming it, and a begin that is empty or absent is
/// refused too; a choice or a datetime form is refused by the read route before the port. No row is returned for any.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ListMessages</method> without its session check -- the session leg goes red.</p>
Method TestEachMalformedCriterionIsRefusedByName()
{
    Set tNames = $ListBuild("session", "bodyClass", "status", "type", "errors", "endDateTime", "beginDateTime")
    Set tValues = $ListBuild("12ab", "1 Bad Class", "Nope", "Terminate", "maybe", "2026-02-30 10:00:00", "")
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Kill tQ
        Set tQ("beginDateTime") = ..LocalAgo(86400), tQ("source") = ..Marker() _ "Src"
        Set tQ(tName) = $List(tValues, tI)
        Set tRows = ..Rows("Messages", .tQ, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "400|PORT.VALIDATION", tName _ " '" _ $List(tValues, tI) _ "' is refused 400 PORT.VALIDATION")
        Do $$$AssertTrue($IsObject(tFault) && ($Extract(tFault.reason, 1, $Length(tName)) = tName), tName _ ": the reason names the criterion: " _ $Select($IsObject(tFault): tFault.reason, 1: ""))
        Do $$$AssertEquals($IsObject(tRows), 0, tName _ ": no row is returned")
    }
    Kill tQ
    Set tQ("maxRows") = 5
    Set tRows = ..Rows("Messages", .tQ, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "400|PORT.VALIDATION", "a search with no begin is refused")
    Kill tCriteria
    Set tCriteria("status") = "Nope"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREENPREFIX _ "InteropMessageList", 5, .tAnswer, .tReadHttp, .tReadFault, .tCriteria)
    Do $$$AssertEquals(tReadHttp _ "|" _ $Select($IsObject($Get(tReadFault)): tReadFault.code, 1: ""), "400|READ.CRITERION", "the read route refuses a status that is no choice")
    Kill tCriteria
    Set tCriteria("beginDateTime") = "yesterday"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREENPREFIX _ "InteropMessageList", 5, .tAnswer, .tReadHttp, .tReadFault, .tCriteria)
    Do $$$AssertEquals(tReadHttp _ "|" _ $Select($IsObject($Get(tReadFault)): tReadFault.code, 1: ""), "400|READ.CRITERION", "and a begin that is no date and time")
    Kill tCriteria
    Set tCriteria("beginDateTime") = ""
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREENPREFIX _ "InteropMessageList", 5, .tAnswer, .tReadHttp, .tReadFault, .tCriteria)
    Do $$$AssertEquals(tReadHttp _ "|" _ $Select($IsObject($Get(tReadFault)): tReadFault.code, 1: ""), "400|PORT.VALIDATION", "an emptied begin passes the route unset and is refused by the port")
}

/// <p>The words the search maps to stored values are the vendor's own display and value lists, so a map that drifts from the
/// datatype is caught here.</p>
/// <p>Mutation (Rule 19): swap two words in <parameter>OcuPilot.Port.InteropPort.STATUSWORDS</parameter> -- this goes red.</p>
Method TestTheStatusAndTypeWordsAreTheVendorsOwn()
{
    Do $$$AssertEquals($Parameter("Ens.DataType.MessageStatus", "DISPLAYLIST"), "," _ $Parameter(..#PORT, "STATUSWORDS"), "the status words are the datatype's display list")
    Do $$$AssertEquals($Parameter("Ens.DataType.MessageStatus", "VALUELIST"), ",1,2,3,4,5,6,7,8,9", "and the nine stored values run 1 to 9 in that order")
    Do $$$AssertEquals($Piece($Parameter("Ens.DataType.MessageType", "DISPLAYLIST"), ",", 1, 3), "," _ $Parameter(..#PORT, "TYPEWORDS"), "the type words are the first two of the datatype's display list")
    Do $$$AssertEquals($Piece($Parameter("Ens.DataType.MessageType", "VALUELIST"), ",", 1, 3), ",1,2", "stored 1 and 2")
}

/// <p>AC2: the Header read answers the twenty-three properties in order -- <code>Position</code> and <code>Line</code> JSON numbers,
/// every value a string -- with the enumerations as display words, the stamps in local time, <code>IsError</code> 1 and the error
/// status as its text.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ReadMessageHeader</method> reads <code>TimeCreated</code> without
/// <method>OcuPilot.Port.InteropPort.LocalStamp</method> -- the stamp leg goes red; <code>%EXTERNAL(Priority)</code> and
/// <code>%EXTERNAL(Invocation)</code> swapped in <parameter>OcuPilot.Port.InteropPort.HEADERSQL</parameter> -- the last leg goes red.</p>
Method TestTheHeaderReadsTwentyThreePropertiesInOrder()
{
    Set tHl7 = $List(..PreparedIds, 3)
    Kill tQ
    Set tQ("message") = tHl7
    Set tRows = ..Rows("MessageHeader", .tQ, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the header answers")
    Do $$$AssertTrue($IsObject(tRows), "with rows")
    If '$IsObject(tRows) Quit
    Do $$$AssertEquals(tRows.%Size(), 23, "twenty-three rows")
    Set tOrder = ""
    For tI = 1:1:tRows.%Size() {
        Set tRow = tRows.%Get(tI - 1)
        Set tOrder = tOrder _ $Select(tOrder = "": "", 1: ",") _ tRow.Name
        Set tByName(tRow.Name) = tRow.Value
        Do $$$AssertEquals(tRow.%GetTypeOf("Position") _ "|" _ tRow.Position _ "|" _ tRow.%GetTypeOf("Value") _ "|" _ tRow.%GetTypeOf("Message"), "number|" _ tI _ "|string|string", "row " _ tI _ ": a numeric position and string values")
    }
    Do $$$AssertEquals(tOrder, "ID,Type,Priority,Invocation,TimeCreated,TimeProcessed,Status,IsError,ErrorStatus,SourceConfigName,TargetConfigName,SourceBusinessType,TargetBusinessType,SessionId,SuperSession,CorrespondingMessageId,BusinessProcessId,TargetQueueName,ReturnQueueName,MessageBodyClassName,MessageBodyId,Description,Resent", "in the classic pane's order")
    Do $$$AssertEquals(tByName("ID") _ "|" _ tByName("Type") _ "|" _ tByName("Status") _ "|" _ tByName("IsError"), tHl7 _ "|Request|Error|1", "the id, the type and status as words, and IsError 1")
    Do $$$AssertEquals(tByName("ErrorStatus") [ ("OcuPilot probe error " _ ..PreparedRun), 1, "ErrorStatus reads the error text: " _ tByName("ErrorStatus"))
    Do $$$AssertEquals(tByName("SourceConfigName") _ "|" _ tByName("TargetConfigName") _ "|" _ tByName("MessageBodyClassName"), ..Marker() _ "Src|" _ ..Marker() _ "Op|EnsLib.HL7.Message", "source, target and body class")
    Do $$$AssertEquals(tByName("SessionId"), $List(..PreparedIds, 2), "the session is the XML header's")
    Set tStored = ..StoredCreated(tHl7)
    Do $$$AssertEquals(tByName("TimeCreated"), ##class(OcuPilot.Test.InteropHostRead).LocalForm(tStored), "TimeCreated reads in the instance's local time, by the vendor's own conversion, in the log readers' form (YYYY-MM-DDTHH:MM:SS.fff): " _ tByName("TimeCreated") _ " from " _ tStored)
    Do $$$AssertEquals($Length(tByName("TimeProcessed")), 23, "TimeProcessed reads in the same form")
    Kill tQ
    Set tQ("message") = $List(..PreparedIds, 2)
    Set tXmlRows = ..Rows("MessageHeader", .tQ)
    Set tOkText = "unread"
    For tI = 1:1:$Select($IsObject(tXmlRows): tXmlRows.%Size(), 1: 0) {
        If tXmlRows.%Get(tI - 1).Name = "ErrorStatus" Set tOkText = tXmlRows.%Get(tI - 1).Value
    }
    Do $$$AssertEquals(tOkText, "", "a header with no error reads an empty ErrorStatus")
    Kill tQ
    Set tOther = $List(..PreparedIds, 5)
    Set tQ("message") = tOther
    Set tFull = ..Rows("MessageHeader", .tQ)
    Do $$$AssertTrue($IsObject(tFull), "the header with a value for every property answers")
    If '$IsObject(tFull) Quit
    Set tLocal = ##class(OcuPilot.Test.InteropHostRead).LocalForm(..StoredCreated(tOther))
    Set tPairs = ""
    For tI = 1:1:tFull.%Size() Set tPairs = tPairs _ tFull.%Get(tI - 1).Name _ "=" _ tFull.%Get(tI - 1).Value _ "|"
    Set tExpected = "ID=" _ tOther _ "|Type=Response|Priority=Normal|Invocation=Inproc|TimeCreated=" _ tLocal _ "|TimeProcessed=" _ tLocal _ "|Status=Deferred|IsError=0|ErrorStatus=|SourceConfigName=" _ ..Marker() _ "SrcOther|TargetConfigName=" _ ..Marker() _ "OpOther|SourceBusinessType=BusinessService|TargetBusinessType=BusinessOperation|SessionId=9001|SuperSession=OcuPilotSuper209|CorrespondingMessageId=4242|BusinessProcessId=5151|TargetQueueName=OcuPilotTargetQueue209|ReturnQueueName=OcuPilotReturnQueue209|MessageBodyClassName=|MessageBodyId=body-77|Description=OcuPilot full header 209|Resent=3|"
    Do $$$AssertEquals(tPairs, tExpected, "each of the twenty-three properties reads its own value under its own name")
}

/// <p>AC2: an id no header holds reads as no rows; a message that is not digits, begins with zero or is empty is refused 400
/// <code>PORT.VALIDATION</code> naming <code>message</code>, on both message endpoints.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.InvokeRuntime</method> without its id-shape check -- the malformed legs go
/// red.</p>
Method TestAnUnknownIdIsNoRowsAndAMalformedIdIsRefused()
{
    For tEndpoint = "MessageHeader", "MessageContents" {
        Kill tQ
        Set tQ("message") = "9223372036854775"
        Set tRows = ..Rows(tEndpoint, .tQ, .tHttp)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tRows): tRows.%Size(), 1: "none"), "200|0", tEndpoint _ ": an id no header holds reads as no rows")
        For tBad = "abc", "0", "01", "-5", "1.5", "", "12345678901234567890" {
            Kill tQ
            Set tQ("message") = tBad
            Set tRows = ..Rows(tEndpoint, .tQ, .tHttp, .tFault)
            Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "400|PORT.VALIDATION", tEndpoint _ ": '" _ tBad _ "' is refused")
            Do $$$AssertTrue($IsObject(tFault) && ($Extract(tFault.reason, 1, 7) = "message"), tEndpoint _ ": the reason names message")
        }
    }
}

/// <p>AD-36: the read route, the read tool and the port answer the same rows for the search, the Header and the Contents, in the
/// fields each screen declares.</p>
/// <p>Mutation (Rule 19): rename the <code>source</code> criterion in <class>OcuPilot.Screen.Descriptor.InteropMessageList</class> -- the route
/// and the tool answer every header of the window while the port answers the fixture's, and the search leg goes red.</p>
Method TestTheReadRouteAndTheReadToolAnswerTheSameRows()
{
    Set tXml = $List(..PreparedIds, 2)
    Set tEntries = $ListBuild($ListBuild("InteropMessageList", "Messages", "source", ..Marker() _ "Src", "ID,TimeCreated,Status,Type,Source,Target,BodyClass,SessionId,Error"), $ListBuild("InteropMessageHeaderTab", "MessageHeader", "message", tXml, "Message,Position,Name,Value"), $ListBuild("InteropMessageContentsTab", "MessageContents", "message", tXml, "Message,Line,Text"))
    For tI = 1:1:$ListLength(tEntries) {
        Set tEntry = $List(tEntries, tI)
        Set tClass = ..#SCREENPREFIX _ $List(tEntry, 1)
        Set tName = $List(tEntry, 2)
        Kill tQ, tCriteria
        Set tQ($List(tEntry, 3)) = $List(tEntry, 4)
        If tName = "Messages" Set tQ("beginDateTime") = ..LocalAgo(86400)
        Set tCriteria($List(tEntry, 3)) = $List(tEntry, 4)
        Set tArgs = {}
        Do tArgs.%Set($List(tEntry, 3), $List(tEntry, 4), "string")
        Set tPortRows = ..Rows(tName, .tQ, .tPortHttp)
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(tClass, 1000, .tAnswer, .tRouteHttp, .tRouteFault, .tCriteria)
        Set tToolName = $ClassMethod(tClass, "ToolIdentifier") _ ".read"
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tToolName, .tTool)
        Do $$$AssertTrue($IsObject($Get(tTool)), tToolName _ " is a registered read tool")
        Kill tResult
        Set tToolHttp = 0
        If $IsObject($Get(tTool)) Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, tArgs, 1000, .tResult, .tToolHttp, .tToolFault)
        Do $$$AssertEquals(tPortHttp _ "|" _ tRouteHttp _ "|" _ tToolHttp, "200|200|200", tName _ ": the port, the route and the tool answer")
        If '$IsObject(tPortRows) || '$IsObject($Get(tAnswer)) || '$IsObject($Get(tResult)) Continue
        Do $$$AssertTrue(tPortRows.%Size() > 0, tName _ ": the port answers rows")
        Set tPortCanon = ..Canon(tPortRows, $List(tEntry, 5))
        Do $$$AssertEquals(..Canon(tAnswer.rows, $List(tEntry, 5)), tPortCanon, tName _ ": the route's rows are the port's")
        Do $$$AssertEquals(..Canon(tResult.rows, $List(tEntry, 5)), tPortCanon, tName _ ": and so are the tool's")
    }
}

/// <p><var>pRows</var> reduced to <var>pFields</var> (comma-separated), one line for each row, in order.</p>
ClassMethod Canon(pRows As %DynamicArray, pFields As %String) As %String
{
    Set tText = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        For tI = 1:1:$Length(pFields, ",") {
            Set tField = $Piece(pFields, ",", tI)
            Set tText = tText _ tField _ "=" _ tRow.%Get(tField) _ "|"
        }
        Set tText = tText _ $Char(10)
    }
    Quit tText
}

}
