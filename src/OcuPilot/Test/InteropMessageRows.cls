/// <p>Pins what Story 20.9's Messages search answers beyond which headers it finds (AD-29, AD-36, AD-62), on the synthetic headers
/// <class>OcuPilot.Test.InteropMessageRead</class> stores: a row defines every field the screen declares, each under its own name
/// and type, with the stamp in local time and the status and type as their words; a window whose end precedes every stored header
/// holds none, and a begin before every stored header opens at the first; and each word the form's status, type and error-flag
/// choices offer is one the port takes.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropMessageRead</class> needs, whose fixture it uses. It
/// writes nothing but that fixture, removed after each test.</p>
Class OcuPilot.Test.InteropMessageRows Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter FIXTURE = "OcuPilot.Test.InteropMessageRead";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.InteropMessageList";

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

/// <p>The rows the port's <code>Messages</code> answers for <var>pQuery</var>, which gets the last 24 hours and this run's source
/// unless it names its own; the HTTP status in <var>pHttp</var> and the fault in <var>pFault</var>.</p>
Method Search(ByRef pQuery, Output pHttp As %Integer, Output pFault) As %DynamicArray
{
    If '$Data(pQuery("beginDateTime")) Set pQuery("beginDateTime") = $ClassMethod(..#FIXTURE, "LocalAgo", 86400)
    If '$Data(pQuery("source")) Set pQuery("source") = $Parameter(..#FIXTURE, "MARKER") _ ..PreparedRun _ "Src"
    Quit $ClassMethod(..#FIXTURE, "Rows", "Messages", .pQuery, .pHttp, .pFault)
}

/// <p>The declaration of the Messages screen.</p>
ClassMethod Declaration() As %DynamicObject
{
    Set tSC = $ClassMethod(..#SCREEN, "DeclarationJson", .tDeclaration)
    Quit $Select($$$ISOK(tSC) && $IsObject($Get(tDeclaration)): tDeclaration, 1: "")
}

/// <p>The row <var>pRow</var> as <code>ID|TimeCreated|Status|Type|Source|Target|BodyClass|SessionId|Error:type</code>.</p>
ClassMethod Line(pRow As %DynamicObject) As %String
{
    Quit pRow.%Get("ID") _ "|" _ pRow.%Get("TimeCreated") _ "|" _ pRow.%Get("Status") _ "|" _ pRow.%Get("Type") _ "|" _ pRow.%Get("Source") _ "|" _ pRow.%Get("Target") _ "|" _ pRow.%Get("BodyClass") _ "|" _ pRow.%Get("SessionId") _ "|" _ pRow.%Get("Error") _ ":" _ pRow.%GetTypeOf("Error")
}

/// <p>AC1: a search row defines every field the screen declares, in every row, so a field the port forgets cannot hide behind the
/// route and the tool answering the same empty cell; and each carries its own value: the identifier a string, the stamp in the
/// instance's local time by the vendor's own conversion, the status and the type as their words, the source, target, body class and
/// session as stored, and the error flag a JSON boolean.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.MessageRow</method> reads <code>TimeCreated</code> without
/// <method>OcuPilot.Port.InteropPort.LocalStamp</method> -- the first line goes red; leaves the search columns <code>Type</code> and
/// <code>Error</code> out -- the field legs go red.</p>
Method TestASearchRowCarriesEveryFieldItDeclaresUnderItsOwnNameAndType()
{
    Set tDeclaration = ..Declaration()
    Do $$$AssertTrue($IsObject(tDeclaration), "the Messages declaration is read")
    If '$IsObject(tDeclaration) Quit
    Set tRows = ..Search(.tQuery, .tHttp)
    Do $$$AssertEquals(tHttp, 200, "the search answers")
    Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() = 3), "with the three recent headers")
    If '$IsObject(tRows) || (tRows.%Size() '= 3) Quit
    Set tFields = tDeclaration.read.fields.%GetIterator()
    While tFields.%GetNext(.tAt, .tField) {
        For tI = 0:1:2 {
            Do $$$AssertTrue(tRows.%Get(tI).%IsDefined(tField), "row " _ tI _ " defines " _ tField)
        }
    }
    Set tMarker = $Parameter(..#FIXTURE, "MARKER") _ ..PreparedRun
    Set tXml = $List(..PreparedIds, 2)
    Set tHl7 = $List(..PreparedIds, 3)
    Set tNone = $List(..PreparedIds, 4)
    Set tLocalNone = ##class(OcuPilot.Test.InteropHostRead).LocalForm($ClassMethod(..#FIXTURE, "StoredCreated", tNone))
    Set tLocalHl7 = ##class(OcuPilot.Test.InteropHostRead).LocalForm($ClassMethod(..#FIXTURE, "StoredCreated", tHl7))
    Set tLocalXml = ##class(OcuPilot.Test.InteropHostRead).LocalForm($ClassMethod(..#FIXTURE, "StoredCreated", tXml))
    Do $$$AssertEquals(..Line(tRows.%Get(0)), tNone _ "|" _ tLocalNone _ "|Completed|Response|" _ tMarker _ "Src|" _ tMarker _ "Op|||0:boolean", "the response with no body and no session")
    Do $$$AssertEquals(..Line(tRows.%Get(1)), tHl7 _ "|" _ tLocalHl7 _ "|Error|Request|" _ tMarker _ "Src|" _ tMarker _ "Op|EnsLib.HL7.Message|" _ tXml _ "|1:boolean", "the error header, in the XML header's session")
    Do $$$AssertEquals(..Line(tRows.%Get(2)), tXml _ "|" _ tLocalXml _ "|Completed|Request|" _ tMarker _ "Src|" _ tMarker _ "Op|Ens.StringRequest|" _ tXml _ "|0:boolean", "the XML header, its own session")
    Do $$$AssertEquals(tRows.%Get(0).%GetTypeOf("ID") _ "|" _ tRows.%Get(0).%GetTypeOf("SessionId"), "string|string", "the identifier and the session are strings")
}

/// <p>AC1: a window whose end precedes every stored header holds none (the end finds no last header), and a begin before every
/// stored header opens at the first header, so every header of the run's source comes back, the old one last.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.InteropPort.ListMessages</method> drops the test that an end with no last header means no
/// rows -- the first leg answers the whole store and goes red.</p>
Method TestAWindowEndingBeforeEveryHeaderHoldsNoneAndABeginBeforeEveryHeaderOpensAtTheFirst()
{
    Kill tQuery
    Set tQuery("beginDateTime") = "2000-01-01 00:00:00", tQuery("endDateTime") = "2000-01-02 00:00:00"
    Set tRows = ..Search(.tQuery, .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#FIXTURE, "Ids", tRows), "200|", "a window that ends before every header holds none")
    Kill tQuery
    Set tQuery("beginDateTime") = "2000-01-01 00:00:00"
    Set tRows = ..Search(.tQuery, .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#FIXTURE, "Ids", tRows), "200|" _ $List(..PreparedIds, 4) _ "," _ $List(..PreparedIds, 3) _ "," _ $List(..PreparedIds, 2) _ "," _ $List(..PreparedIds, 1), "a begin before every header holds the run's four, the old one last")
}

/// <p>AC1: the words the form offers for the status, the type and the error flag are the port's own words, in order, and the port
/// takes each, so a word the form offers is never refused.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Descriptor.InteropMessageList</class> offers <code>Defered</code> for
/// <code>Deferred</code> -- the status list leg and that word's leg go red.</p>
Method TestEveryChoiceTheFormOffersIsOneThePortTakes()
{
    Set tDeclaration = ..Declaration()
    Do $$$AssertTrue($IsObject(tDeclaration), "the Messages declaration is read")
    If '$IsObject(tDeclaration) Quit
    Set tChoices = $ListBuild($ListBuild("status", $Parameter(..#PORT, "STATUSWORDS")), $ListBuild("type", $Parameter(..#PORT, "TYPEWORDS")), $ListBuild("errors", "yes,no"))
    For tI = 1:1:$ListLength(tChoices) {
        Set tParam = $List($List(tChoices, tI), 1)
        Set tCriterion = ""
        Set tCriteria = tDeclaration.read.criteria.fields.%GetIterator()
        While tCriteria.%GetNext(.tAt, .tField) {
            If tField.param = tParam Set tCriterion = tField
        }
        Do $$$AssertTrue($IsObject(tCriterion), tParam _ " is a criterion")
        If '$IsObject(tCriterion) Continue
        Set tOptions = ""
        Set tOffered = tCriterion.options.%GetIterator()
        While tOffered.%GetNext(.tAtOption, .tOption) {
            Set tOptions = tOptions _ $Select(tOptions = "": "", 1: ",") _ tOption
        }
        Do $$$AssertEquals(tOptions, $List($List(tChoices, tI), 2), tParam _ ": the form offers the port's words, in its order")
        For tJ = 1:1:$Length(tOptions, ",") {
            Kill tQuery
            Set tQuery(tParam) = $Piece(tOptions, ",", tJ)
            Set tRows = ..Search(.tQuery, .tHttp, .tFault)
            Do $$$AssertEquals(tHttp _ "|" _ $IsObject(tRows), "200|1", tParam _ " '" _ $Piece(tOptions, ",", tJ) _ "' is taken by the port")
        }
    }
}

}
