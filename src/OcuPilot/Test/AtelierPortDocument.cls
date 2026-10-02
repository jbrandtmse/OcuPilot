/// <p>The source code API port's document endpoints and its fault mapping (AD-61): a class's or
/// routine's rows built from the index route, the text read in the chosen form, the name and form
/// checked before any route, a document the namespace does not hold answered 404 and not logged,
/// each vendor outcome mapped to its <code>PORT.*</code> code with the vendor text logged and never
/// sent, an answer above the capture's ceiling refused with the capture closed, the index route's
/// answer written through a port-owned temporary file that is gone afterwards on every path, and
/// the caller's own CSP objects left as they were.</p>
/// <p>The vendor is <class>OcuPilot.Test.AtelierPortFixture</class>'s canned routes, read in the
/// install namespace; one leg reads through the live instance's routes, one of OcuPilot's own
/// classes in the install namespace and a library class in <code>USER</code>, which holds none of
/// OcuPilot's code. Nothing is written but the port's own temporary files.</p>
Class OcuPilot.Test.AtelierPortDocument Extends %UnitTest.TestCase
{

/// <p>An <code>index</code> answer for class <var>pName</var> naming <var>pOthers</var> (a JSON
/// array) as its other documents.</p>
ClassMethod IndexAnswer(pName As %String, pOthers As %String = "[]") As %String
{
    Quit "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""name"":""" _ pName _ """,""db"":""HOME"",""ts"":""2026-01-10 10:00:00.000"",""gen"":false,""others"":" _ pOthers _ ",""cat"":""CLS"",""status"":"""",""content"":{""desc"":[""<p>Line &lt;one&gt; &amp; two</p>"",""next""],""depl"":false,""depr"":true,""final"":false,""hidden"":false,""super"":[""%RegisteredObject"",""Probe.Mixin""],""methods"":[{""name"":""Go"",""desc"":[""Runs <b>it</b>.""],""depr"":false,""final"":true,""internal"":false,""private"":false,""scope"":""class"",""returntype"":""%Library.Status"",""args"":[]}],""parameters"":[{""name"":""LIMIT"",""depr"":false,""desc"":[""The limit.""],""internal"":true}],""properties"":[{""name"":""Size"",""desc"":[],""depr"":false,""internal"":false,""final"":false,""private"":true,""type"":""%Library.Integer""}]}}]}}"
}

/// <p>A <code>doc</code> answer for <var>pName</var> whose text carries markup.</p>
ClassMethod DocAnswer(pName As %String) As %String
{
    Quit "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""name"":""" _ pName _ """,""db"":""HOME"",""ts"":""2026-01-10 10:00:00.000"",""cat"":""CLS"",""status"":"""",""enc"":false,""flags"":0,""content"":[""Class Probe {"",""<b>not markup</b>"",""}""]}}"
}

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
    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

/// <p>Arm the canned routes with <var>pOthers</var> as the index's other documents.</p>
ClassMethod ArmDocument(pName As %String = "Alpha.One.cls", pOthers As %String = "[""Alpha.One.1.int""]")
{
    Do ##class(OcuPilot.Test.AtelierPortFixture).UseFakeRoutes()
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetVersion(8)
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetResources("%DB_PROBEHOME", "%DB_PROBEHOME", "")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Index", "200 OK", ..IndexAnswer(pName, pOthers))
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDoc", "200 OK", ..DocAnswer(pName))
}

/// <p>Invoke <var>pEndpoint</var> for <var>pName</var> in form <var>pForm</var>.</p>
ClassMethod Read(pEndpoint As %String, pName As %String, pForm As %String, Output pRows, Output pDocument, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tQuery("name") = pName
    If pForm '= "" Set tQuery("form") = pForm
    Quit ##class(OcuPilot.Test.AtelierPortFixture).Invoke(pEndpoint, "LIST", .tQuery, "", .pRows, .pHttp, .pFault, .pDocument)
}

/// <p>A class's rows: its own row, then one per parameter, property and method, each with its type,
/// its set flags and its documentation as plain text; the document carries the source as read, its
/// markup untouched, and the generated <code>.int</code> names. The index is asked for the one name
/// as a JSON body; the text is the name's own.</p>
/// <p>Mutation: drop the tag stripping from <method>OcuPilot.Port.AtelierPort.PlainText</method>
/// -&gt; the rows assertion goes red; treat every <code>&lt;</code> as a tag's start -&gt; the
/// comparison assertion goes red.</p>
Method TestAClassReadsItsRowsAndItsSource()
{
    Do $$$AssertEquals(##class(OcuPilot.Port.AtelierPort).PlainText("Quits 1 if x<5 and y>3, or 0 <b>otherwise</b>. If n<0"), "Quits 1 if x<5 and y>3, or 0 otherwise. If n<0", "a < that starts no tag is text")
    Do ..ArmDocument()
    Set tSC = ..Read("Class", "Alpha.One.cls", "", .tRows, .tDocument, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the class reads")
    Do $$$AssertEquals(tRows.%ToJSON(), "[{""Order"":1,""Kind"":""class"",""Name"":""Alpha.One.cls"",""Type"":""%RegisteredObject, Probe.Mixin"",""Flags"":""deprecated"",""Description"":""Line <one> & two next"",""Modified"":""2026-01-10 10:00:00.000"",""Database"":""HOME"",""Generates"":""Alpha.One.1.int""},{""Order"":2,""Kind"":""parameter"",""Name"":""LIMIT"",""Type"":"""",""Flags"":""internal"",""Description"":""The limit."",""Modified"":null,""Database"":null,""Generates"":null},{""Order"":3,""Kind"":""property"",""Name"":""Size"",""Type"":""%Library.Integer"",""Flags"":""private"",""Description"":"""",""Modified"":null,""Database"":null,""Generates"":null},{""Order"":4,""Kind"":""method"",""Name"":""Go"",""Type"":""%Library.Status"",""Flags"":""class, final"",""Description"":""Runs it."",""Modified"":null,""Database"":null,""Generates"":null}]", "the class row, then parameters, properties and methods")
    Do $$$AssertEquals(tDocument.%ToJSON(), "{""name"":""Alpha.One.cls"",""form"":""udl"",""available"":true,""content"":[""Class Probe {"",""<b>not markup</b>"",""}""],""modified"":""2026-01-10 10:00:00.000"",""database"":""HOME"",""generates"":[""Alpha.One.1.int""]}", "the document carries the source as read")
    Set tIndex = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(1)
    Do $$$AssertEquals(tIndex.method _ " " _ tIndex.contentType _ " " _ tIndex.body, "Index application/json [""Alpha.One.cls""]", "the index is asked for the one name as a JSON body")
    Set tDoc = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(2)
    Do $$$AssertEquals(tDoc.method _ " " _ tDoc.arg _ " " _ tDoc.params.%ToJSON(), "GetDoc Alpha.One.cls {}", "then the name's own text")
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 2, "and nothing else")
}

/// <p>Each form reads its own text: XML through the vendor's <code>format=xml</code>, intermediate
/// code from the first <code>.int</code> the index names, and a class that names none answers
/// <code>available</code> false with no text and no second call.</p>
Method TestEachFormReadsItsOwnText()
{
    Do ..ArmDocument()
    Set tSC = ..Read("Class", "Alpha.One.cls", "xml", .tRows, .tDocument, .tHttp, .tFault)
    Set tDoc = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(2)
    Do $$$AssertEquals(tDoc.arg _ " " _ tDoc.params.%ToJSON() _ " " _ tDocument.form, "Alpha.One.cls {""format"":""xml""} xml", "xml asks the vendor for its XML export")

    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ..ArmDocument("Alpha.One.cls", "[""Alpha.One.mac"",""Alpha.One.1.int"",""Alpha.One.2.int""]")
    Set tSC = ..Read("Class", "Alpha.One.cls", "int", .tRows, .tDocument, .tHttp, .tFault)
    Set tDoc = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(2)
    Do $$$AssertEquals(tDoc.arg _ " " _ tDocument.available _ " " _ tDocument.generates.%ToJSON(), "Alpha.One.1.int 1 [""Alpha.One.1.int"",""Alpha.One.2.int""]", "int reads the first generated .int")

    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ..ArmDocument("Alpha.One.cls", "[]")
    Set tSC = ..Read("Class", "Alpha.One.cls", "int", .tRows, .tDocument, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a class with no intermediate code still reads")
    Do $$$AssertEquals(tHttp _ " " _ tDocument.available _ " " _ tDocument.content.%ToJSON(), "200 0 []", "and answers no text, which is not a fault")
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 1, "with no text read")
}

/// <p>A routine answers its one row, typed by its extension and naming the intermediate code it
/// generates; an <code>.int</code> routine's intermediate code is its own text.</p>
Method TestARoutineReadsItsOneRow()
{
    Do ..ArmDocument("Probe.Code.mac", "[""Probe.Code.int""]")
    Set tSC = ..Read("Routine", "Probe.Code.mac", "int", .tRows, .tDocument, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the routine reads")
    Do $$$AssertEquals(tRows.%Size() _ " " _ tRows.%Get(0).Kind _ " " _ tRows.%Get(0).Type _ " " _ tRows.%Get(0).Generates, "1 routine mac Probe.Code.int", "one routine row")
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallAt(2).arg, "Probe.Code.int", "whose intermediate code is the .int it generates")

    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ..ArmDocument("Probe.Code.int", "[""Probe.Code.mac""]")
    Set tSC = ..Read("Routine", "Probe.Code.int", "int", .tRows, .tDocument, .tHttp, .tFault)
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallAt(2).arg _ " " _ tDocument.generates.%ToJSON(), "Probe.Code.int []", "an .int routine reads its own text and generates nothing")
}

/// <p>A malformed name or form is refused 400 <code>PORT.VALIDATION</code> before any route.</p>
Method TestMalformedNamesAreRefusedBeforeAnyRoute()
{
    Do ..ArmDocument()
    For tCase = $ListBuild("Class", ""), $ListBuild("Class", "../x.cls"), $ListBuild("Class", "A.cls;B"), $ListBuild("Class", "HS.HC.Info.mac"), $ListBuild("Routine", "Probe.cls"), $ListBuild("Routine", "A.mac;B") {
        Set tSC = ..Read($List(tCase, 1), $List(tCase, 2), "", .tRows, .tDocument, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "400 PORT.VALIDATION", $List(tCase, 1) _ " '" _ $List(tCase, 2) _ "' is refused")
    }
    Set tSC = ..Read("Class", "Alpha.One.cls", "html", .tRows, .tDocument, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.reason, "400 " _ ##class(OcuPilot.Port.AtelierPort).#REASONFORM, "and so is a form outside udl, xml and int")
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "with no route called")
}

/// <p>A document the namespace does not hold is 404 <code>PORT.NOTFOUND</code>, from the index's own
/// status or the text's 404, and nothing is logged (AD-2).</p>
/// <p>Mutation: log the index's not-found status -&gt; the unlogged assertion goes red.</p>
Method TestAMissingDocumentIsNotFoundAndUnlogged()
{
    Do ..ArmDocument()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Index", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""name"":""No.Such.Class.cls"",""db"":"""",""ts"":"""",""cat"":""CLS"",""gen"":false,""others"":[],""status"":""ERROR #16005: Document 'No.Such.Class.cls' does NOT exist"",""content"":{}}]}}")
    Set tSC = ..Read("Class", "No.Such.Class.cls", "", .tRows, .tDocument, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code _ " " _ tFault.reason, "404 PORT.NOTFOUND " _ ##class(OcuPilot.Port.AtelierPort).#REASONNOTFOUND, "the index's own status is a 404")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and nothing is logged")

    Do ..ArmDocument()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDoc", "404 Not Found", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{}}")
    Set tSC = ..Read("Class", "Alpha.One.cls", "", .tRows, .tDocument, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code, "404 PORT.NOTFOUND", "so is the text's 404")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "unlogged too")
}

/// <p>Each vendor outcome maps to its code, with the vendor's own text logged and never in the
/// fault: a 400 is <code>PORT.VALIDATION</code>; a <code>&lt;PROTECT&gt;</code> in the envelope's
/// errors or raised by the route, and a privilege soft error the result's own status carries
/// (AD-61 rule 6), are <code>PORT.ACCESSDENIED</code>; any other soft error, an envelope that does
/// not parse, and any other status are the internal fault.</p>
Method TestVendorOutcomesMapToCodesWithTheTextLogged()
{
    For tCase = $ListBuild("GetDocNames", "400 Bad Request", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{}}", "400 PORT.VALIDATION"), $ListBuild("GetDocNames", "200 OK", "{""status"":{""errors"":[{""error"":""ERROR #5002: ObjectScript error: <PROTECT>fetch^Probe""}],""summary"":""x""},""console"":[],""result"":{""content"":[]}}", "403 PORT.ACCESSDENIED"), $ListBuild("GetDocNames", "200 OK", "not an envelope", "500 INTERNAL"), $ListBuild("GetDocNames", "415 Unsupported Media Type", "", "500 INTERNAL") {
        Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
        Do ##class(OcuPilot.Test.LogProbe).Clear()
        Do ..ArmDocument()
        Do ##class(OcuPilot.Test.AtelierPortFixture).Arm($List(tCase, 1), $List(tCase, 2), $List(tCase, 3))
        Kill tQuery
        Set tQuery("namespace") = $Namespace
        Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Classes", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ tFault.code, $List(tCase, 4), $List(tCase, 2) _ " " _ $Extract($List(tCase, 3), 1, 60))
        Do $$$AssertNotEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and is logged")
    }

    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ..ArmDocument()
    Do ##class(OcuPilot.Test.AtelierPortFixture).ArmThrow("GetDocNames", "<PROTECT>")
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Classes", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code, "403 PORT.ACCESSDENIED", "a <PROTECT> the route raises is the vendor's privilege refusal")

    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ..ArmDocument()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDoc", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""name"":""Alpha.One.cls"",""status"":""ERROR #5838: You need %Development:Use privilege to run this application."",""content"":[]}}")
    Set tSC = ..Read("Class", "Alpha.One.cls", "", .tRows, .tDocument, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code _ " " _ tFault.reason, "403 PORT.ACCESSDENIED " _ ##class(OcuPilot.Port.AtelierPort).#REASONACCESSDENIED, "a privilege soft error answered with 200 is the vendor's refusal, in OcuPilot's words")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ "#5838", "with the vendor's text in the log: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
    Do $$$AssertEquals(tRows _ tDocument, "", "and no rows or document")

    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ..ArmDocument()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDoc", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""name"":""Alpha.One.cls"",""status"":""ERROR #5001: something else went wrong"",""content"":[]}}")
    Set tSC = ..Read("Class", "Alpha.One.cls", "", .tRows, .tDocument, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code _ " " _ tFault.reason, "500 INTERNAL " _ ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, "any other soft error answered with 200 is a failure, in OcuPilot's words")
}

/// <p>A routine the index holds whose text read answers 404 with no status of its own is kept only as
/// object code: 200, the routine's row present and the document unavailable with reason
/// <code>objectonly</code>. A name the index does not hold stays 404 <code>PORT.NOTFOUND</code>, and a
/// class's text answered 404 is not object code. One leg reads the live instance's
/// <code>EnsJob.mac</code> in the install namespace.</p>
/// <p>Mutation (Rule 19): answer the object-only 404 as <code>PORT.NOTFOUND</code> in
/// <method>OcuPilot.Port.AtelierPort.Document</method> -- the first leg goes red.</p>
Method TestARoutineKeptOnlyAsObjectCodeReadsAsSo()
{
    Do ##class(OcuPilot.Test.AtelierPortFixture).UseFakeRoutes()
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetVersion(8)
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetResources("%DB_PROBEHOME", "%DB_PROBEHOME", "")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Index", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""name"":""Probe.mac"",""db"":""HOME"",""ts"":"""",""upd"":false,""cat"":""RTN"",""gen"":false,""others"":[],""status"":"""",""content"":{}}]}}")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDoc", "404 Not Found", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""name"":""Probe.mac"",""db"":""HOME"",""ts"":"""",""upd"":false,""cat"":""RTN"",""status"":"""",""enc"":false,""flags"":0,""content"":[]}}")
    Set tSC = ..Read("Routine", "Probe.mac", "", .tRows, .tDocument, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "an object-only routine reads")
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tRows)): tRows.%Size() _ " " _ tRows.%Get(0).Name, 1: ""), "200 1 Probe.mac", "its row is present")
    Do $$$AssertEquals($Select($IsObject($Get(tDocument)): tDocument.available _ " " _ tDocument.%Get("reason") _ " " _ tDocument.content.%ToJSON(), 1: ""), "0 objectonly []", "and its document says it holds only object code")

    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDoc", "404 Not Found", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""name"":""Probe.mac"",""db"":"""",""ts"":"""",""cat"":""RTN"",""enc"":false,""content"":"""",""status"":""ERROR #16005: Document 'Probe.mac' does NOT exist""}}")
    Set tSC = ..Read("Routine", "Probe.mac", "", .tRows, .tDocument, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "404 PORT.NOTFOUND", "a text read naming no document stays not found")

    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ..ArmDocument()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDoc", "404 Not Found", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""name"":""Alpha.One.cls"",""status"":"""",""content"":[]}}")
    Set tSC = ..Read("Class", "Alpha.One.cls", "", .tRows, .tDocument, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "404 PORT.NOTFOUND", "and a class answered so is not object code")

    ; The instance's own interoperability library keeps EnsJob.mac as object code alone.
    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tQuery("name") = "EnsJob.mac"
    Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke("Routine", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tDocument)): tDocument.available _ " " _ tDocument.%Get("reason"), 1: ""), "200 0 objectonly", "the live EnsJob.mac reads as object code alone")
}

/// <p>An answer above the capture's ceiling is 503 <code>PORT.UNAVAILABLE</code>, logged, with the
/// capture closed, the device and namespace as they were, and the next call reading normally.</p>
Method TestAnAnswerAboveTheCeilingIsUnavailable()
{
    Do ..ArmDocument()
    Do ##class(OcuPilot.Test.AtelierPortFixture).ArmOversize("GetDocNames")
    Set tDevice = $IO
    Set tNamespace = $Namespace
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Classes", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code _ " " _ tFault.reason, "503 PORT.UNAVAILABLE " _ ##class(OcuPilot.Port.AtelierPort).#REASONTOOLARGE, "the answer is refused")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ "<MAXSTRING>", "and the vendor's error is logged")
    Do $$$AssertEquals($Data(^||%capture) _ " " _ $ZUtil(82, 12) _ " " _ $IO _ " " _ $Namespace, "0 0 " _ tDevice _ " " _ tNamespace, "with no capture open and the device and namespace restored")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDocNames", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""name"":""A.cls"",""db"":""HOME"",""ts"":"""",""gen"":false}]}}")
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Classes", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tRows.%Size(), "200 1", "and the next call reads")
}

/// <p>Against the live instance: one of OcuPilot's own classes reads through the real routes, its
/// index answered through the port's temporary file and its intermediate code available.</p>
Method TestALiveClassReads()
{
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tQuery("name") = "OcuPilot.Port.AtelierRequest.cls"
    Set tQuery("form") = "int"
    Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke("Class", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertStatusOK(tSC, "the class reads")
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%Get(0).Kind _ " " _ tRows.%Get(0).Type, 1: ""), "class %CSP.Request", "its own row names its superclass")
    Do $$$AssertTrue($IsObject(tDocument) && tDocument.available && (tDocument.content.%Size() > 0) && (tDocument.generates.%Size() > 0), "and its generated intermediate code is available")
    Do $$$AssertEquals($Data(^||%capture) _ " " _ $ZUtil(82, 12), "0 0", "with no capture open")

    Set tOrigin = $Namespace
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("name") = "%Library.RegisteredObject.cls"
    Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke("Class", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
    Set tAfter = $Namespace
    If $Namespace '= tOrigin Set $Namespace = tOrigin
    Do $$$AssertStatusOK(tSC, "a class reads in USER, where the index route is handed the port's request stub")
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%Get(0).Kind _ " " _ tRows.%Get(0).Name, 1: "") _ " " _ tAfter, "class %Library.RegisteredObject.cls " _ tOrigin, "its own row, with the caller's namespace restored")
}

/// <p>AD-61 rule 5: the index route writes its answer to a temporary file of the port's own
/// rather than under the capture, and that file is gone afterwards -- after a success, after the
/// route raises and after an answer above the ceiling -- with the caller's device and namespace as
/// they were; the text route runs under the capture.</p>
/// <p>Mutation: set <parameter>OcuPilot.Port.AtelierPort.FILEDEVICEROUTES</parameter> to
/// <code>""</code> -&gt; the file-device assertion goes red; delete the file's deletion from
/// <method>OcuPilot.Port.AtelierPort.Route</method> -&gt; the file-gone assertions go red.</p>
Method TestTheIndexRouteWritesAPortOwnedFileItDeletes()
{
    Set tCaller = $IO
    Set tNamespace = $Namespace
    Do ..ArmDocument()
    Set tSC = ..Read("Class", "Alpha.One.cls", "", .tRows, .tDocument, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the class reads")
    Set tIndex = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(1)
    Set tDoc = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(2)
    Do $$$AssertTrue((tIndex.method = "Index") && (tIndex.device '= tCaller) && (tIndex.redirect = 0), "the index route writes to a file of its own, not under the capture: " _ tIndex.%ToJSON())
    Do $$$AssertTrue((tIndex.device '= "") && '##class(%File).Exists(tIndex.device), "and that file is gone afterwards")
    Do $$$AssertTrue((tDoc.method = "GetDoc") && (tDoc.device = tCaller) && (tDoc.redirect = 1), "while the text route runs under the capture: " _ tDoc.%ToJSON())

    For tArm = "raise", "oversize" {
        Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
        Do ##class(OcuPilot.Test.LogProbe).Clear()
        Do ..ArmDocument()
        If tArm = "raise" Do ##class(OcuPilot.Test.AtelierPortFixture).ArmThrow("Index", "<PROTECT>")
        If tArm = "oversize" Do ##class(OcuPilot.Test.AtelierPortFixture).ArmOversize("Index")
        Set tSC = ..Read("Class", "Alpha.One.cls", "", .tRows, .tDocument, .tHttp, .tFault)
        Set tIndex = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(1)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), $Select(tArm = "raise": "403 PORT.ACCESSDENIED", 1: "503 PORT.UNAVAILABLE"), tArm _ ": the index route's outcome")
        Do $$$AssertTrue((tIndex.device '= "") && (tIndex.device '= tCaller) && '##class(%File).Exists(tIndex.device), tArm _ ": its file is gone afterwards: " _ tIndex.%ToJSON())
        Do $$$AssertEquals($IO _ " " _ $Namespace _ " " _ $ZUtil(82, 12), tCaller _ " " _ tNamespace _ " 0", tArm _ ": with the caller's device and namespace as they were")
    }
}

/// <p>AD-61 rule 3: the caller's own <code>%request</code>, <code>%response</code>,
/// <code>%session</code> and <code>%SourceControl</code>, its namespace and its device are
/// unchanged after a read and after a fault, though the routes replace all four.</p>
/// <p>Mutation: drop <code>%session</code> and <code>%SourceControl</code> from
/// <method>OcuPilot.Port.AtelierPort.Route</method>'s <code>New</code> -&gt; the identity
/// assertions go red.</p>
Method TestTheCallersCspObjectsAreUntouched()
{
    New %request, %response, %session, %SourceControl
    Set tNamespace = $Namespace
    Set tDevice = $IO
    Set tRequest = ##class(%CSP.Request).%New()
    Set tRequest.URL = "/caller/own/url"
    Set tResponse = ##class(%CSP.Response).%New()
    Set tResponse.Status = "299 Caller Fixture"
    Set tSession = {"Username": "caller-fixture"}
    Set tSourceControl = {"owner": "caller-fixture"}
    Set %request = tRequest
    Set %response = tResponse
    Set %session = tSession
    Set %SourceControl = tSourceControl
    For tLeg = "read", "fault" {
        Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
        Do ..ArmDocument()
        If tLeg = "fault" Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDoc", "500 Internal Server Error", "")
        Set tSC = ..Read("Class", "Alpha.One.cls", "", .tRows, .tDocument, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, $Select(tLeg = "read": 200, 1: 500), tLeg _ ": the read answers")
        Do $$$AssertTrue((%request = tRequest) && (%response = tResponse) && (%session = tSession) && (%SourceControl = tSourceControl), tLeg _ ": %request, %response, %session and %SourceControl are the caller's own objects")
        Do $$$AssertEquals(%request.URL _ "|" _ %response.Status _ "|" _ %session.Username _ "|" _ %SourceControl.owner _ "|" _ $Namespace _ "|" _ $IO, "/caller/own/url|299 Caller Fixture|caller-fixture|caller-fixture|" _ tNamespace _ "|" _ tDevice, tLeg _ ": and unchanged")
    }
}

}
