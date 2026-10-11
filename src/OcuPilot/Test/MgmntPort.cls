/// <p>The management API port in process (AD-1, AD-29): the gate evaluated before anything else,
/// the argument checks before any vendor call, the explorer's join, the document's rows and
/// references, the resolution of a name to a vendor method, the written reasons for each vendor
/// refusal, the internal fault for everything else, and the read executor's mgmnt branch.</p>
/// <p>The vendor is <class>OcuPilot.Test.MgmntImplFixture</class> behind
/// <class>OcuPilot.Test.MgmntPortFixture</class>; denials are driven through
/// <class>OcuPilot.Test.ScreenGate</class>, because <code>%UnitTest</code> runs as an account holding
/// <code>%All</code>. The real gate against a real principal is
/// <class>OcuPilot.Test.MgmntPortDenial</class>'s. One leg calls the real port against the live
/// instance to pin that it leaves the caller's namespace where it was; that read may rebuild the
/// vendor's own REST discovery cache (AD-7) and writes nothing of OcuPilot's.</p>
Class OcuPilot.Test.MgmntPort Extends %UnitTest.TestCase
{

/// <p>The explorer descriptor.</p>
Parameter EXPLORER = "OcuPilot.Screen.Descriptor.RestApiList";

/// <p>The document viewer descriptor.</p>
Parameter VIEWER = "OcuPilot.Screen.Descriptor.OpenApiViewer";

/// <p>Canned vendor answers.</p>
XData Canned [ MimeType = application/json ]
{
{
  "web": [
    {"name": "/api/probe", "dispatchClass": "Probe.v1.disp", "namespace": "PROBENS", "swaggerSpec": "/api/mgmnt/v2/PROBENS/Probe.v1", "enabled": true},
    {"name": "/api/legacy", "dispatchClass": "Legacy.Router", "namespace": "LEGACYNS", "resource": "%Development", "swaggerSpec": "/api/mgmnt/v1/LEGACYNS/spec/api/legacy", "enabled": false}
  ],
  "services": [
    {"name": "Probe.v1", "webApplications": "/api/probe", "dispatchClass": "Probe.v1.disp", "namespace": "PROBENS", "swaggerSpec": "/api/mgmnt/v2/PROBENS/Probe.v1"},
    {"name": "Orphan.v2", "dispatchClass": "Orphan.v2.disp", "namespace": "USER", "swaggerSpec": "/api/mgmnt/v2/USER/Orphan.v2"}
  ],
  "document": {
    "swagger": "2.0",
    "parameters": {
      "ns": {"name": "namespace", "in": "path", "required": true, "type": "string"},
      "a/b": {"name": "slashed", "in": "query", "required": false, "type": "integer"}
    },
    "paths": {
      "/zeta": {
        "post": {"summary": "Create a zeta", "operationId": "ZetaCreate", "responses": {"201": {"description": "Created"}, "default": {"description": "An error"}}},
        "get": {"summary": "List zetas", "operationId": "ZetaList", "parameters": [{"$ref": "#/parameters/ns"}], "responses": {"200": {"description": "The list"}}}
      },
      "/alpha/{namespace}": {
        "parameters": [{"$ref": "#/parameters/ns"}, {"name": "verbose", "in": "query", "type": "boolean"}],
        "x-note": "not an operation",
        "delete": {"operationId": "AlphaDelete", "parameters": [{"name": "verbose", "in": "query", "required": true, "type": "string"}, {"$ref": "#/parameters/a~1b"}, {"$ref": "#/parameters/missing"}, {"name": "verbose", "in": "header", "type": "string"}], "responses": {}},
        "get": {"description": "no summary and no operation id"}
      },
      "/middle": {"head": {"summary": "Probe", "parameters": [{"in": "query", "type": "string"}]}}
    }
  }
}
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
    Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
    Do ##class(OcuPilot.Test.MgmntPortFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>One canned value from <code>XData Canned</code>, as JSON text.</p>
ClassMethod CannedJson(pKey As %String) As %String
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Canned")
    Do tXData.Data.Rewind()
    Quit ##class(%DynamicObject).%FromJSON(tXData.Data).%Get(pKey).%ToJSON()
}

/// <p>Arm the fixture vendor with the canned lists and document, every call answering 200.</p>
ClassMethod ArmCanned()
{
    Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("GetWebRESTApps", "200 OK", ..CannedJson("web"))
    Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("GetRESTApps", "200 OK", ..CannedJson("services"))
    Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("GetApplication", "200 OK", ..CannedJson("document"))
    Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("GetWebRESTApplication", "200 OK", ..CannedJson("document"))
}

/// <p>Invoke the fixture port for <var>pEndpoint</var> in <var>pNamespace</var>, naming
/// <var>pApplication</var> when it is not <code>""</code>.</p>
ClassMethod Call(pEndpoint As %String, pNamespace As %String, pApplication As %String, Output pRows, Output pHttp As %Integer, Output pFault As %DynamicObject, Output pDocument, pMaxRows As %String = "") As %Status
{
    Kill tQuery
    If pNamespace '= "" Set tQuery("namespace") = pNamespace
    If pApplication '= "" Set tQuery("application") = pApplication
    If pMaxRows '= "" Set tQuery("maxRows") = pMaxRows
    Quit ##class(OcuPilot.Test.MgmntPortFixture).Invoke(pEndpoint, "LIST", .tQuery, "", .pRows, .pHttp, .pFault, .pDocument)
}

/// <p>A fault as <code>status code reason failedPair</code>, for one-line comparisons.</p>
ClassMethod FaultText(pHttp As %Integer, pFault As %DynamicObject) As %String
{
    If '$IsObject(pFault) Quit pHttp
    Set tPair = ""
    If $IsObject(pFault.%Get("detail")) Set tPair = pFault.detail.%Get("failedPair")
    Quit pHttp _ " " _ pFault.code _ " " _ pFault.reason _ $Select(tPair = "": "", 1: " " _ tPair)
}

/// <p>The pair set is evaluated before any vendor call, and before the arguments are read: a caller
/// short of <code>%Admin_Secure:USE</code> is answered 403 <code>AUTH.NOPRIVILEGE</code> naming it on
/// either endpoint, with no vendor call and whatever the arguments; a caller short of
/// <code>%DB_IRISSYS:READ</code> is named that pair; a caller holding both reaches the vendor.</p>
/// <p>Mutation: move the <code>EvaluateRequired</code> call in
/// <method>OcuPilot.Port.MgmntPort.Invoke</method> below the argument checks -&gt; the malformed-call
/// legs answer 400 or 501 and go red.</p>
Method TestTheGateIsEvaluatedBeforeAnyArgumentOrVendorCall()
{
    Do ..ArmCanned()
    Do ##class(OcuPilot.Test.MgmntPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")

    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    For tEndpoint = "Applications", "Document" {
        Set tSC = ..Call(tEndpoint, "USER", "/api/probe", .tRows, .tHttp, .tFault, .tDocument)
        Do $$$AssertStatusNotOK(tSC, tEndpoint _ ": the call is refused")
        Do $$$AssertEquals(..FaultText(tHttp, tFault), "403 AUTH.NOPRIVILEGE This account does not hold the privilege this request requires. %Admin_Secure:USE", tEndpoint _ ": naming the pair the caller lacks")
        Do $$$AssertEquals(tDocument, "", tEndpoint _ ": with no document")
    }
    Set tSC = ..Call("Nothing", "", "", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "403 AUTH.NOPRIVILEGE This account does not hold the privilege this request requires. %Admin_Secure:USE", "an unknown endpoint with no namespace is refused by the gate first")
    Set tSC = ..Call("Document", "bad namespace", "", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertEquals(tHttp, 403, "and so is a malformed document call")
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallCount(), 0, "and no vendor method was called")

    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Set tSC = ..Call("Applications", "USER", "", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "403 AUTH.NOPRIVILEGE This account does not hold the privilege this request requires. %DB_IRISSYS:READ", "a caller short of the system read is named that pair")
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallCount(), 0, "still with no vendor call")

    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = ..Call("Applications", "USER", "", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertStatusOK(tSC, "a caller holding both pairs is served")
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallText(), "GetWebRESTApps(USER)|GetRESTApps(USER)", "through the two list methods, in the route's namespace")
}

/// <p>The port declares its pair set once, and it is the privileges of every production descriptor
/// whose read names the <code>mgmnt</code> source -- the explorer and the document viewer among
/// them -- and the web-applications area's own set, in that order.</p>
/// <p>Mutation: reorder <parameter>OcuPilot.Port.MgmntPort.PAIRS</parameter> -&gt; the literal and the
/// equality assertions go red.</p>
Method TestThePortsPairsAreBothDescriptorsAndTheAreas()
{
    Do $$$AssertEquals(##class(OcuPilot.Port.MgmntPort).#PAIRS, "%Admin_Secure:USE,%DB_IRISSYS:READ", "the declared pair set, in gate order")
    Set tPorts = ..PairsText(##class(OcuPilot.Port.MgmntPort).Pairs())
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
    Do $$$AssertStatusOK(tSC, "the production descriptors list")
    Set tChecked = ""
    For tI = 1:1:$ListLength(tList) {
        Set tClass = $List(tList, tI)
        Set tRead = $ClassMethod(tClass, "Read")
        If '$IsObject(tRead) Continue
        If '$IsObject(tRead.%Get("source")) Continue
        If tRead.source.%Get("port") '= "mgmnt" Continue
        Set tChecked = tChecked _ $Select(tChecked = "": "", 1: ",") _ tClass
        Do $$$AssertEquals(..PairsText($ClassMethod(tClass, "PrivilegePairs")), tPorts, tClass _ " declares exactly the port's pairs")
    }
    Do $$$AssertTrue((tChecked [ ..#EXPLORER) && (tChecked [ ..#VIEWER), "every mgmnt read was checked, the explorer and the viewer among them: " _ tChecked)
    Do $$$AssertEquals(tPorts, ..PairsText(##class(OcuPilot.Screen.Area).PrivilegePairs("web-applications")), "and they are the web-applications area's")
}

/// <p>A pair list as <code>resource:permission</code> joined by commas.</p>
ClassMethod PairsText(pPairs As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tPair = $List(pPairs, tI)
        Set tText = tText _ $Select(tI = 1: "", 1: ",") _ $List(tPair, 1) _ ":" _ $List(tPair, 2)
    }
    Quit tText
}

/// <p>A malformed argument is refused before any vendor call: no namespace, a malformed namespace or
/// row cap, an absent application, one that is neither a path nor a package name, and one longer than
/// the port reads are each 400 <code>PORT.VALIDATION</code>; an endpoint or request type the port
/// does not serve is 501 <code>PORT.NOTIMPLEMENTED</code>.</p>
/// <p>Mutation: drop <method>OcuPilot.Port.MgmntPort.ApplicationShapeOk</method>'s check from
/// <method>OcuPilot.Port.MgmntPort.Invoke</method> -&gt; the application legs reach the vendor and go
/// red.</p>
Method TestArgumentsAreCheckedBeforeAnyVendorCall()
{
    Do ..ArmCanned()
    Set tShape = "400 PORT.VALIDATION Name one REST application: a web application path starting with /, or a spec-based service's package name."
    For tApplication = "", "bad name", "Probe..v1", "1Probe", "/api/" _ $Char(9) _ "tab", "/api/" _ $Char(13, 10) _ "crlf", "/" _ $Translate($Justify("", 256), " ", "a") {
        Set tSC = ..Call("Document", "USER", tApplication, .tRows, .tHttp, .tFault, .tDocument)
        Do $$$AssertEquals(..FaultText(tHttp, tFault), tShape, "application '" _ $Extract(tApplication, 1, 20) _ "' is refused by shape")
    }
    Set tSC = ..Call("Applications", "", "", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "400 PORT.VALIDATION Name the namespace the read runs in.", "a call with no namespace is refused")
    Set tSC = ..Call("Applications", "US ER", "", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertEquals(tHttp, 400, "and so is a malformed namespace")
    Set tSC = ..Call("Applications", "USER", "", .tRows, .tHttp, .tFault, .tDocument, "0")
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "400 PORT.VALIDATION maxRows must be a whole number above zero.", "and a row cap of zero")
    Set tSC = ..Call("Operations", "USER", "", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "501 PORT.NOTIMPLEMENTED This instance does not implement that operation.", "an endpoint the port does not serve")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tSC = ##class(OcuPilot.Test.MgmntPortFixture).Invoke("Applications", "GET", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertEquals(tHttp, 501, "and a request type it does not serve")
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallCount(), 0, "none of them reached the vendor")

    For tApplication = "/api/probe", "Orphan.v2", "%Api.Probe.v1" {
        Set tSC = ..Call("Document", "USER", tApplication, .tRows, .tHttp, .tFault, .tDocument)
        Do $$$AssertStatusOK(tSC, "application '" _ tApplication _ "' is a shape the port reads")
    }
}

/// <p>The explorer's rows are the namespace's web applications, then the spec-based services no
/// listed web application dispatches to: a service a listed web application deploys appears once,
/// under that web application; <code>SpecBased</code> follows the vendor's <code>swaggerSpec</code>
/// for a web application and is true for a service; <code>Enabled</code> is the web application's
/// and <code>null</code> for a service. The row cap bounds the joined rows.</p>
/// <p>Mutation: drop the <code>tDeployed</code> check in
/// <method>OcuPilot.Port.MgmntPort.Applications</method> -&gt; <code>Probe.v1</code> appears as a
/// fourth row and the rows assertion goes red.</p>
Method TestTheExplorerJoinsWebApplicationsAndUndeployedServices()
{
    Do ..ArmCanned()
    Set tSC = ..Call("Applications", "USER", "", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertStatusOK(tSC, "the explorer read is served")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Do $$$AssertEquals(tRows.%ToJSON(), "[{""Name"":""/api/probe"",""Namespace"":""PROBENS"",""DispatchClass"":""Probe.v1.disp"",""SpecBased"":true,""Enabled"":true},{""Name"":""/api/legacy"",""Namespace"":""LEGACYNS"",""DispatchClass"":""Legacy.Router"",""SpecBased"":false,""Enabled"":false},{""Name"":""Orphan.v2"",""Namespace"":""USER"",""DispatchClass"":""Orphan.v2.disp"",""SpecBased"":true,""Enabled"":null}]", "two web applications, then the one service no web application deploys")
    Do $$$AssertEquals(tDocument, "", "and no document")

    Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
    Do ..ArmCanned()
    Set tSC = ..Call("Applications", "USER", "", .tRows, .tHttp, .tFault, .tDocument, "2")
    Do $$$AssertEquals(tRows.%Size(), 2, "the row cap bounds the joined rows")
}

/// <p>Document rows follow the document: <code>paths</code> in iteration order, and within a path
/// item its own key order over the seven verbs, with <code>Order</code> counting from 1. Path-level
/// parameters are merged in place and the operation's own win on the same <code>name</code> and
/// <code>in</code>; a <code>#/parameters/</code> reference resolves from the document, a JSON-pointer
/// escape included, and one that resolves to nothing is left out; a missing summary or operation id
/// is <code>""</code>; responses keep their key order. The document is returned unmodified.</p>
/// <p>Mutation: sort the rows by <code>Path</code> in <method>OcuPilot.Port.MgmntPort.DocumentRows</method>
/// -&gt; the order assertion goes red.</p>
Method TestDocumentRowsFollowTheDocumentsOwnOrder()
{
    Do ..ArmCanned()
    Set tSC = ..Call("Document", "USER", "Orphan.v2", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertStatusOK(tSC, "the document read is served")
    Do $$$AssertEquals(tRows.%Size(), 5, "one row per operation, and none for the parameters or extension keys")
    Set tOrder = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOrder = tOrder _ $Select(tIndex = 0: "", 1: " | ") _ tRow.Order _ " " _ tRow.Verb _ " " _ tRow.Path
    }
    Do $$$AssertEquals(tOrder, "1 post /zeta | 2 get /zeta | 3 delete /alpha/{namespace} | 4 get /alpha/{namespace} | 5 head /middle", "rows follow the document's path order and each path item's own verb order")
    Do $$$AssertEquals(tRows.%Get(0).%ToJSON(), "{""Order"":1,""Path"":""/zeta"",""Verb"":""post"",""Summary"":""Create a zeta"",""OperationId"":""ZetaCreate"",""Parameters"":[],""Responses"":[{""code"":""201"",""description"":""Created""},{""code"":""default"",""description"":""An error""}]}", "a row carries its summary, id, parameters and responses in key order")
    Do $$$AssertEquals(tRows.%Get(1).Parameters.%ToJSON(), "[{""name"":""namespace"",""in"":""path"",""required"":true,""type"":""string""}]", "a reference resolves from the document")
    Do $$$AssertEquals(tRows.%Get(2).Parameters.%ToJSON(), "[{""name"":""namespace"",""in"":""path"",""required"":true,""type"":""string""},{""name"":""verbose"",""in"":""query"",""required"":true,""type"":""string""},{""name"":""slashed"",""in"":""query"",""required"":false,""type"":""integer""},{""name"":""verbose"",""in"":""header"",""required"":false,""type"":""string""}]", "path-level parameters merge in place, the operation's own win on name and in, an escaped reference resolves and an unresolvable one is left out")
    Do $$$AssertEquals(tRows.%Get(4).Parameters.%ToJSON(), "[{""name"":"""",""in"":""query"",""required"":false,""type"":""string""}]", "a parameter the document leaves unnamed is still listed")
    Do $$$AssertEquals(tRows.%Get(3).%ToJSON(), "{""Order"":4,""Path"":""/alpha/{namespace}"",""Verb"":""get"",""Summary"":"""",""OperationId"":"""",""Parameters"":[{""name"":""namespace"",""in"":""path"",""required"":true,""type"":""string""},{""name"":""verbose"",""in"":""query"",""required"":false,""type"":""boolean""}],""Responses"":[]}", "an operation with no summary, id or responses inherits the path's parameters")
    Do $$$AssertEquals(tDocument.%ToJSON(), ..CannedJson("document"), "the document travels unmodified")

    Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
    Do ..ArmCanned()
    Set tSC = ..Call("Document", "USER", "Orphan.v2", .tRows, .tHttp, .tFault, .tDocument, "2")
    Do $$$AssertEquals(tRows.%Size(), 2, "the row cap bounds the rows")
    Do $$$AssertEquals(tDocument.%ToJSON(), ..CannedJson("document"), "and never the document")
}

/// <p>A name resolves to exactly one vendor method. A web application path must equal a listed
/// <code>name</code> exactly -- a prefix or an extension of one is refused 404 before any document is
/// requested, where the vendor's own lookup would match the longest name it contains. A listed
/// spec-based web application reads its service's stored document, and any other listed web
/// application the document generated from its dispatch class, each in the row's own namespace; a
/// package name reads that service's document in the requested namespace.</p>
/// <p>Mutation: compare names with <code>[</code> in <method>OcuPilot.Port.MgmntPort.Document</method>
/// -&gt; <code>/api/prob</code> resolves and the unlisted legs go red.</p>
Method TestANameResolvesToOneVendorMethod()
{
    For tCase = $ListBuild("/api/probe", "GetWebRESTApps(USER)|GetApplication(PROBENS,Probe.v1)"), $ListBuild("/api/legacy", "GetWebRESTApps(USER)|GetWebRESTApplication(LEGACYNS,/api/legacy)"), $ListBuild("Orphan.v2", "GetApplication(USER,Orphan.v2)") {
        Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
        Do ..ArmCanned()
        Set tSC = ..Call("Document", "USER", $List(tCase, 1), .tRows, .tHttp, .tFault, .tDocument)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ " is served")
        Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallText(), $List(tCase, 2), $List(tCase, 1) _ " reads its document through the one method it resolves to")
    }
    For tUnlisted = "/api/prob", "/api/probe/v9", "/API/PROBE", "/api/nosuch" {
        Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
        Do ..ArmCanned()
        Set tSC = ..Call("Document", "USER", tUnlisted, .tRows, .tHttp, .tFault, .tDocument)
        Do $$$AssertEquals(..FaultText(tHttp, tFault), "404 PORT.NOTFOUND This namespace lists no REST application by that name.", tUnlisted _ " is not a listed name")
        Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallText(), "GetWebRESTApps(USER)", tUnlisted _ ": and no document was requested")
    }
}

/// <p>Each vendor refusal is a written reason and never the vendor's text: a 404 from
/// <code>GetApplication</code> and from <code>GetWebRESTApplication</code> each have their own
/// sentence, a document method's 400 is <code>PORT.VALIDATION</code>, and a refused namespace switch
/// is 403 <code>PORT.ACCESSDENIED</code> on either endpoint. The vendor's text reaches the log.</p>
/// <p>Mutation: answer every non-2xx with empty rows and 200 in
/// <method>OcuPilot.Port.MgmntPort.Outcome</method> -&gt; every refusal assertion goes red.</p>
Method TestVendorRefusalsAreWrittenReasons()
{
    Set tCases = $ListBuild(
        $ListBuild("GetApplication", "404 Not Found", "Document", "Orphan.v2", "404 PORT.NOTFOUND The management API refused this document: it reports no REST application by that name."),
        $ListBuild("GetWebRESTApplication", "404 Not Found", "Document", "/api/legacy", "404 PORT.NOTFOUND The management API refused this document: it reports no REST specification for that web application."),
        $ListBuild("GetApplication", "400 Bad Request", "Document", "/api/probe", "400 PORT.VALIDATION The management API could not build this document."),
        $ListBuild("GetWebRESTApplication", "400 Bad Request", "Document", "/api/legacy", "400 PORT.VALIDATION The management API could not build this document."),
        $ListBuild("GetApplication", "403 Forbidden", "Document", "Orphan.v2", "403 PORT.ACCESSDENIED The management API refused to enter this namespace for this account."),
        $ListBuild("GetWebRESTApps", "403 Forbidden", "Document", "/api/probe", "403 PORT.ACCESSDENIED The management API refused to enter this namespace for this account."),
        $ListBuild("GetRESTApps", "403 Forbidden", "Applications", "", "403 PORT.ACCESSDENIED The management API refused to enter this namespace for this account."))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
        Do ##class(OcuPilot.Test.LogProbe).Clear()
        Do ..ArmCanned()
        Do ##class(OcuPilot.Test.MgmntImplFixture).Arm($List(tCase, 1), $List(tCase, 2), "", "write")
        Set tSC = ..Call($List(tCase, 3), "USER", $List(tCase, 4), .tRows, .tHttp, .tFault, .tDocument)
        Set tWhere = $List(tCase, 1) _ " " _ $List(tCase, 2)
        Do $$$AssertStatusNotOK(tSC, tWhere _ ": the call fails")
        Do $$$AssertEquals(..FaultText(tHttp, tFault), $List(tCase, 5), tWhere _ ": with its written reason")
        Do $$$AssertTrue($IsObject(tFault) && '(tFault.reason [ "ERROR #") && '(tFault.reason [ "%Api") && '(tFault.%ToJSON() [ "8753"), tWhere _ ": naming no vendor status or class")
        Do $$$AssertEquals(tRows, "", tWhere _ ": with no rows")
        Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ ##class(OcuPilot.Test.MgmntImplFixture).#VENDORTEXT, tWhere _ ": and the vendor's text reaches the log")
    }
}

/// <p>Every other vendor outcome is 500 <code>INTERNAL</code> with the generic reason: an exception, a
/// 500, a 404 or 400 from a list method, a 2xx carrying no value or the wrong kind of value, and a
/// capture the process refuses to open. The vendor's text reaches only the log.</p>
/// <p>Mutation: treat any 2xx as success in <method>OcuPilot.Port.MgmntPort.Outcome</method> -&gt; the
/// wrong-kind legs (<code>[]</code> from a document method, <code>{}</code> from a list method) answer
/// 200 and go red; an empty answer still fails later inside the port.</p>
Method TestEveryOtherVendorOutcomeIsAnInternalFault()
{
    Set tGeneric = "500 INTERNAL An internal error occurred"
    Set tCases = $ListBuild(
        $ListBuild("GetRESTApps", "200 OK", "", "throw", "Applications", ""),
        $ListBuild("GetWebRESTApps", "500 Internal Server Error", "", "write", "Applications", ""),
        $ListBuild("GetWebRESTApps", "404 Not Found", "", "write", "Applications", ""),
        $ListBuild("GetRESTApps", "400 Bad Request", "", "write", "Applications", ""),
        $ListBuild("GetApplication", "200 OK", "", "", "Document", "Orphan.v2"),
        $ListBuild("GetApplication", "200 OK", "[]", "", "Document", "Orphan.v2"),
        $ListBuild("GetWebRESTApps", "200 OK", "{}", "", "Applications", ""),
        $ListBuild("GetWebRESTApplication", "302 Found", "", "write", "Document", "/api/legacy"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
        Do ##class(OcuPilot.Test.LogProbe).Clear()
        Do ..ArmCanned()
        Do ##class(OcuPilot.Test.MgmntImplFixture).Arm($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4))
        Set tSC = ..Call($List(tCase, 5), "USER", $List(tCase, 6), .tRows, .tHttp, .tFault, .tDocument)
        Set tWhere = $List(tCase, 1) _ " " _ $List(tCase, 2) _ " " _ $List(tCase, 3) _ " " _ $List(tCase, 4)
        Do $$$AssertEquals(..FaultText(tHttp, tFault), tGeneric, tWhere _ ": is an internal fault")
        Do $$$AssertEquals(tDocument, "", tWhere _ ": with no document")
        If $List(tCase, 4) '= "" Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ ##class(OcuPilot.Test.MgmntImplFixture).#VENDORTEXT, tWhere _ ": whose vendor text reaches the log")
    }

    Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
    Do ..ArmCanned()
    Set tOpenSC = $$BeginCapture^%SYS.Capture(.tCookie)
    ; A capture counts as open once it holds output, so the open one is given some.
    Set tNoise = {"open": true}
    Do tNoise.%ToJSON()
    Set tSC = ..Call("Applications", "USER", "", .tRows, .tHttp, .tFault, .tDocument)
    If $$$ISOK(tOpenSC) Set tEndSC = $$EndCapture^%SYS.Capture(tCookie, .tLines)
    Do $$$AssertStatusOK(tOpenSC, "a capture was already open around the call")
    Do $$$AssertEquals(..FaultText(tHttp, tFault), tGeneric, "so the port's own capture is refused and the call is an internal fault")
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallCount(), 0, "with no vendor call made outside a capture")
}

/// <p>A vendor call leaves the caller's own <code>%request</code>, <code>%response</code> and
/// <code>%session</code> as they were: the stubs the port hands the vendor are its own, and the
/// fixture vendor clears <code>%session</code> as a vendor method that touched it would.</p>
/// <p>Mutation: remove <code>%response</code>, <code>%request</code> or <code>%session</code> from the
/// <code>New</code> in <method>OcuPilot.Port.MgmntPort.Call</method> -&gt; the matching assertion goes
/// red.</p>
Method TestTheCallersResponseIsNotTheVendors()
{
    New %request, %response, %session
    Set %request = ##class(%CSP.Request).%New()
    Set tCallerRequest = %request
    Set %response = ##class(%CSP.Response).%New()
    Set %response.Status = "299 Caller"
    Set %session = "caller session"
    Do ..ArmCanned()
    Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("GetApplication", "404 Not Found", "", "write")
    Set tSC = ..Call("Document", "USER", "Orphan.v2", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertEquals(tHttp, 404, "the vendor answered 404 on its own stub")
    Do $$$AssertEquals(%response.Status, "299 Caller", "and the caller's response still carries its own status")
    Do $$$AssertTrue(%request = tCallerRequest, "and the caller's request is still its own object")
    Do $$$AssertEquals(%session, "caller session", "and the caller's session is untouched")
}

/// <p>Against the live instance, a read in <code>%SYS</code> leaves the caller's namespace where it
/// was, and a document the vendor refuses is answered by name.</p>
Method TestTheLivePortLeavesTheNamespaceWhereItWas()
{
    Set tBefore = $NAMESPACE
    Kill tQuery
    Set tQuery("namespace") = "%SYS"
    Set tSC = ##class(OcuPilot.Port.MgmntPort).Invoke("Applications", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertStatusOK(tSC, "the live explorer read in %SYS is served")
    Do $$$AssertEquals($NAMESPACE, tBefore, "and the caller is still in " _ tBefore)
    Set tQuery("application") = "%Api.InteropEditors.v7"
    Set tSC = ##class(OcuPilot.Port.MgmntPort).Invoke("Document", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "404 PORT.NOTFOUND The management API refused this document: it reports no REST application by that name.", "the refused vendor service is answered by name")
    Do $$$AssertEquals($NAMESPACE, tBefore, "and the caller is still in " _ tBefore)
}

/// <p>The read executor's mgmnt branch hands the port the route's scope as its namespace and the
/// declared criterion as the application, carries the port's document beside the rows under the
/// cap, answers no <code>document</code> for a read that returns none, and refuses an over-long
/// criterion before the port is called.</p>
/// <p>Mutation: hand the port <code>$NAMESPACE</code> instead of
/// <method>OcuPilot.Kernel.Scope.Current</method> in <method>OcuPilot.Screen.Read.Execute</method>
/// -&gt; the recorded call names the test's namespace and goes red.</p>
Method TestTheReadHandsThePortTheScopeAndCarriesTheDocument()
{
    Do ..ArmCanned()
    Do ##class(OcuPilot.Kernel.Scope).Set("PROBENS")
    Kill tCriteria
    Set tCriteria("application") = "Orphan.v2"
    Set tSC = ##class(OcuPilot.Test.MgmntReadFixture).Execute(..#VIEWER, 2, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the document read is served")
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallText(), "GetApplication(PROBENS,Orphan.v2)", "in the route's scope, for the declared criterion")
    Do $$$AssertEquals(tResult.fields.%ToJSON(), "[""Order"",""Path"",""Verb"",""Summary"",""OperationId"",""Parameters"",""Responses""]", "projecting the declared fields")
    Do $$$AssertEquals(tResult.rows.%Size(), 2, "under the cap")
    Do $$$AssertEquals(tResult.truncated, 1, "reporting the cut")
    Do $$$AssertEquals(tResult.document.%ToJSON(), ..CannedJson("document"), "with the whole document beside the rows")

    Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
    Do ..ArmCanned()
    Set tSC = ##class(OcuPilot.Test.MgmntReadFixture).Execute(..#EXPLORER, 10, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the explorer read is served")
    Do $$$AssertEquals(tResult.%IsDefined("document"), 0, "and carries no document key")
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallText(), "GetWebRESTApps(PROBENS)|GetRESTApps(PROBENS)", "reading the route's scope")

    Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
    Kill tCriteria
    Set tCriteria("application") = "/" _ $Translate($Justify("", 256), " ", "a")
    Set tSC = ##class(OcuPilot.Test.MgmntReadFixture).Execute(..#VIEWER, 2, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "400 READ.CRITERION application must be 256 characters or fewer", "an over-long application is refused by the executor")
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallCount(), 0, "before the port is called")
}

/// <p>One Service call (Story 18.32) of request type <var>pType</var> in <var>pNamespace</var> for
/// <var>pName</var> with the body <var>pBody</var>, through the fixture port.</p>
ClassMethod Service(pType As %String, pNamespace As %String, pName As %String, pBody, Output pResult, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill tQuery
    If pNamespace '= "" Set tQuery("namespace") = pNamespace
    If pName '= "" Set tQuery("application") = pName
    Quit ##class(OcuPilot.Test.MgmntPortFixture).Invoke("Service", pType, .tQuery, $Get(pBody), .pResult, .pHttp, .pFault)
}

/// <p>The caller holds every pair a Service write requires: the area's two, <code>%Development:USE</code>, and WRITE on
/// <code>USER</code>'s routines database.</p>
ClassMethod HoldAllWritePairs()
{
    Do ##class(OcuPilot.Test.MgmntPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold(..UserCodeResource(), "WRITE")
}

/// <p>The resource guarding <code>USER</code>'s routines database, as the instance reports it.</p>
ClassMethod UserCodeResource() As %String
{
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources("USER", .tRoutine, .tGlobal, .tMapped, .tResolved)
    Quit tRoutine
}

/// <p>A valid OpenAPI 2.0 document, as the create's body carries it.</p>
ClassMethod CreateBody() As %DynamicObject
{
    Quit {"Document": {"swagger": "2.0", "info": {"title": "probe", "version": "1"}, "paths": {}}}
}

/// <p>The Service endpoint's two reads (Story 18.32). A state read answers the listed spelling of a service the
/// namespace lists in any letter case and 404 <code>PORT.NOTFOUND</code>, not logged, for one it does not; a service
/// read answers the service, its namespace and its implementation class for one listed exactly that no web application
/// dispatches to, 404 for one listed in another case, and 409 <code>RESTSERVICE.DEPLOYED</code> for one a web
/// application dispatches to (in any case) and, without a vendor call, for a name starting with <code>/</code>. The
/// namespace is the scope's when none is named.</p>
/// <p>Mutation (Rule 19): drop the dispatch-class comparison from <method>OcuPilot.Port.MgmntPort.Resolved</method> --
/// the deployed legs answer 200 and go red.</p>
Method TestTheServiceReadsAreExactAndRefuseADeployedService()
{
    Do ..ArmCanned()
    Set tSC = ..Service("STATE", "USER", "ORPHAN.V2", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a state read of a service listed in another case is served")
    Do $$$AssertEquals(tHttp _ " " _ tResult.%ToJSON(), "200 {""Name"":""Orphan.v2"",""Namespace"":""USER""}", "answering the listed spelling and the namespace")
    Set tSC = ..Service("STATE", "USER", "Nosuch.v1", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "404 PORT.NOTFOUND This namespace lists no REST application by that name.", "a service the namespace does not list is not found")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and the refusal is not logged")

    Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
    Do ..ArmCanned()
    Set tSC = ..Service("SERVICE", "USER", "Orphan.v2", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tResult.%ToJSON(), "200 {""Name"":""Orphan.v2"",""Namespace"":""USER"",""Implementation"":""Orphan.v2.impl""}", "a service read answers the service and the implementation class a delete keeps")
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallText(), "GetWebRESTApps(USER)|GetRESTApps(USER)", "after the web applications and the services were listed")
    Set tSC = ..Service("SERVICE", "USER", "orphan.v2", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "404 PORT.NOTFOUND This namespace lists no REST application by that name.", "a service listed in another case is not found")
    For tName = "Probe.v1", "probe.V1" {
        Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
        Do ..ArmCanned()
        Set tSC = ..Service("SERVICE", "USER", tName, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..FaultText(tHttp, tFault), "409 " _ ##class(OcuPilot.Api.RestServiceError).#DEPLOYED _ " " _ ##class(OcuPilot.Api.RestServiceError).#REASONDEPLOYED, tName _ ": a web application dispatches to it")
        Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallText(), "GetWebRESTApps(USER)", tName _ ": and the service list was not read")
    }
    Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
    Set tSC = ..Service("SERVICE", "USER", "/api/probe", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code, "409 " _ ##class(OcuPilot.Api.RestServiceError).#DEPLOYED, "a web application's path is deployed")
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallCount(), 0, "without a vendor call")

    Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
    Do ..ArmCanned()
    Do ##class(OcuPilot.Kernel.Scope).Set("PROBENS")
    Set tSC = ..Service("STATE", "", "Probe.v1", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallText(), "GetRESTApps(PROBENS)", "a read naming no namespace runs in the scope's")
}

/// <p>The create answers each vendor status in its own words (Story 18.32): 201 and 200 are served with the package and
/// the namespace; a 400 or a 404 is 422 <code>RESTSERVICE.BUILD</code> on <code>Document</code> and logs nothing; a 403
/// is <code>PORT.ACCESSDENIED</code> and a 500 the generic internal fault, each logged with the vendor's text and
/// neither putting it on the wire. The vendor is handed a parsed object, never text.</p>
/// <p>Mutation (Rule 19): log the 400 and the 404 in <method>OcuPilot.Port.MgmntPort.Outcome</method> -- the unlogged
/// legs go red; hand the vendor the document's text -- the object leg goes red.</p>
Method TestTheCreateAnswersEachVendorStatusInItsOwnWords()
{
    Set tObject = "%Library.DynamicObject " _ ..CreateBody().Document.%ToJSON()
    Set tCases = $ListBuild(
        $ListBuild("201 Created", "{""msg"":""New application created""}", "", "201 {""Name"":""OcuProbe1832Z"",""Namespace"":""USER""}", 0),
        $ListBuild("200 OK", "{""msg"":""Application updated""}", "", "200 {""Name"":""OcuProbe1832Z"",""Namespace"":""USER""}", 0),
        $ListBuild("400 Bad Request", "", "write", "422 RESTSERVICE.BUILD " _ ##class(OcuPilot.Api.RestServiceError).#REASONBUILD, 0),
        $ListBuild("404 Not Found", "", "write", "422 RESTSERVICE.BUILD " _ ##class(OcuPilot.Api.RestServiceError).#REASONBUILD, 0),
        $ListBuild("403 Forbidden", "", "write", "403 PORT.ACCESSDENIED The management API refused to enter this namespace for this account.", 1),
        $ListBuild("500 Internal Server Error", "", "write", "500 INTERNAL An internal error occurred", 1))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
        Do ##class(OcuPilot.Test.LogProbe).Clear()
        Do ..HoldAllWritePairs()
        Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("CreateApplication", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3))
        Set tSC = ..Service("POST", "USER", "OcuProbe1832Z", ..CreateBody(), .tResult, .tHttp, .tFault)
        Set tWhere = $List(tCase, 1)
        Do $$$AssertEquals($Select($IsObject(tFault): ..FaultText(tHttp, tFault), 1: tHttp _ " " _ tResult.%ToJSON()), $List(tCase, 4), tWhere _ ": answered in its own words")
        Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallText(), "CreateApplication(USER,OcuProbe1832Z)", tWhere _ ": one vendor call")
        Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).DocumentAt(1), tObject, tWhere _ ": handed a parsed object")
        If $List(tCase, 5) {
            Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ ##class(OcuPilot.Test.MgmntImplFixture).#VENDORTEXT, tWhere _ ": the vendor's text reaches the log")
            Do $$$AssertTrue($IsObject(tFault) && '(tFault.%ToJSON() [ "ERROR #"), tWhere _ ": and never the wire")
        } ElseIf $IsObject(tFault) {
            Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", tWhere _ ": a build refusal logs nothing")
            Do $$$AssertEquals(tFault.detail.violations.%Get(0).field _ " " _ tFault.detail.violations.%Get(0).code, "Document RESTSERVICE.BUILD", tWhere _ ": on Document")
        }
    }
}

/// <p>The create's rules are checked before any vendor call (Story 18.32): a package that is empty, holds a space, a
/// percent sign, an underscore, a leading digit or an empty part, or is over 215 characters is 422
/// <code>RESTSERVICE.NAME</code> on <code>Name</code>; a document that is no object (text, an array, none), whose
/// <code>swagger</code> is a number, another version or absent, or whose text is over 1,000,000 characters (or longer
/// than the instance's longest string) is 422
/// <code>RESTSERVICE.DOCUMENT</code> on <code>Document</code>. A document sent as text never reaches the vendor.</p>
/// <p>Mutation (Rule 19): accept any <code>swagger</code> in <method>OcuPilot.Port.MgmntPort.DocumentProblem</method> --
/// the version legs go red; refuse at <code>&gt;=</code> the limits in <method>OcuPilot.Port.MgmntPort.NameProblem</method>
/// and <method>OcuPilot.Port.MgmntPort.DocumentProblem</method> -- the edge legs go red.</p>
Method TestTheCreatesRulesAreCheckedBeforeTheVendor()
{
    Do ..HoldAllWritePairs()
    Set tSentence = ##class(OcuPilot.Api.RestServiceError).#REASONNAME
    For tName = "", "Bad Name", "%Api.Probe", "1Probe", "Probe..v1", "Probe_v1", ("P" _ $Translate($Justify("", 215), " ", "a")) {
        Set tSC = ..Service("POST", "USER", tName, ..CreateBody(), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..FaultText(tHttp, tFault), "422 RESTSERVICE.NAME " _ tSentence, "package '" _ $Extract(tName, 1, 12) _ "' is refused")
        Do $$$AssertEquals(tFault.detail.violations.%Get(0).field, "Name", "on Name")
    }
    Do $$$AssertEquals(##class(OcuPilot.Port.MgmntPort).NameProblem("P" _ $Translate($Justify("", 214), " ", "a")), "", "a package of exactly 215 characters is accepted")
    Set tEdge = ##class(%DynamicObject).%FromJSON("{""swagger"":""2.0"",""a"":""" _ $Translate($Justify("", 999976), " ", "b") _ """}")
    Do $$$AssertEquals($Length(tEdge.%ToJSON()), 1000000, "the edge document is exactly the 1,000,000 characters the limit allows")
    Do $$$AssertEquals(##class(OcuPilot.Port.MgmntPort).DocumentProblem({"Document": (tEdge)}), "", "and is accepted")
    Set tText = ##class(%DynamicObject).%FromJSON("{""a"":""" _ $Translate($Justify("", 1000000), " ", "b") _ """}")
    Do tText.%Set("swagger", "2.0")
    Kill tDocuments
    Set tAsText = "{""swagger"":""2.0""}"
    Set tDocuments(1) = {"Document": (tAsText)}
    Set tDocuments(2) = {"Document": []}
    Set tDocuments(3) = {}
    Set tDocuments(4) = {"Document": {"swagger": 2}}
    Set tDocuments(5) = {"Document": {"swagger": "3.0"}}
    Set tDocuments(6) = {"Document": {"info": {}}}
    Set tDocuments(7) = {"Document": (tText)}
    For tI = 1:1:7 {
        Set tSC = ..Service("POST", "USER", "OcuProbe1832Z", tDocuments(tI), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..FaultText(tHttp, tFault), "422 RESTSERVICE.DOCUMENT " _ ##class(OcuPilot.Api.RestServiceError).#REASONDOCUMENT, "document " _ tI _ " is refused")
        Do $$$AssertEquals(tFault.detail.violations.%Get(0).field, "Document", "on Document")
    }
    Set tChunk = $Translate($Justify("", 1000000), " ", "c")
    Set tHuge = {"swagger": "2.0"}
    For tI = 1:1:4 Do tHuge.%Set("part" _ tI, tChunk)
    Do $$$AssertEquals(##class(OcuPilot.Port.MgmntPort).DocumentProblem({"Document": (tHuge)}), ##class(OcuPilot.Api.RestServiceError).#REASONDOCUMENT, "a document whose text is longer than the instance's longest string is refused, not raised")
    Set tSC = ..Service("POST", "USER", "OcuProbe1832Z", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.code, "422 RESTSERVICE.DOCUMENT", "a call with no body is refused too")
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallCount(), 0, "none of them reached the vendor")
}

/// <p>A create and a delete require the screen's pairs, then <code>%Development:USE</code>, then WRITE on the
/// namespace's routines database, each named in turn and each refused before any vendor call (Story 18.32, AD-8); a
/// caller holding all of them reaches the vendor.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Port.MgmntPort.WRITEPAIRS</parameter> -- the first named pair is
/// no longer <code>%Development:USE</code> and this goes red; drop the empty-pairs refusal from
/// <method>OcuPilot.Port.MgmntPort.Service</method> -- the last leg goes red.</p>
Method TestAWriteIsRefusedByNameUntilTheCallerHoldsTheAddedPairs()
{
    Set tCode = ..UserCodeResource()
    Do $$$AssertEquals(tCode, "%DB_USER", "USER's routines database is guarded by %DB_USER")
    For tType = "POST", "DELETE" {
        Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
        Do ..ArmCanned()
        Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("CreateApplication", "201 Created", "{""msg"":""created""}")
        Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("DeleteApplication", "200 OK", "{""msg"":""deleted""}")
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do ##class(OcuPilot.Test.MgmntPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
        Set tSC = ..Service(tType, "USER", "Orphan.v2", ..CreateBody(), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..FaultText(tHttp, tFault), "403 AUTH.NOPRIVILEGE This account does not hold the privilege this request requires. %Development:USE", tType _ ": the code editors' pair is named first")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
        Set tSC = ..Service(tType, "USER", "Orphan.v2", ..CreateBody(), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..FaultText(tHttp, tFault), "403 AUTH.NOPRIVILEGE This account does not hold the privilege this request requires. " _ tCode _ ":WRITE", tType _ ": then WRITE on the routines database")
        Do ##class(OcuPilot.Test.ScreenGate).Hold(tCode, "READ")
        Set tSC = ..Service(tType, "USER", "Orphan.v2", ..CreateBody(), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 403, tType _ ": READ is not WRITE")
        Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallCount(), 0, tType _ ": no vendor call was made")
        Do ##class(OcuPilot.Test.ScreenGate).Hold(tCode, "WRITE")
        Set tSC = ..Service(tType, "USER", "Orphan.v2", ..CreateBody(), .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tType _ ": a caller holding every pair is served")
    }
    Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
    Do ..HoldAllWritePairs()
    Set tSC = ..Service("POST", "OcuNoSuchNs1832", "OcuProbe1832Z", ..CreateBody(), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "400 PORT.VALIDATION " _ ##class(OcuPilot.Port.MgmntPort).#REASONNAMESPACEUNKNOWN, "a namespace whose databases cannot be resolved is refused by its own sentence")
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallCount(), 0, "and no vendor call was made")
}

/// <p>A delete is sent only for a service listed exactly that no web application dispatches to (Story 18.32): it reads
/// the web applications and the services, then calls <code>DeleteApplication</code>; a deployed service, a web
/// application's path and a name listed in another case send none; a 403 and a 500 from the vendor are answered in
/// their own words and logged.</p>
/// <p>Mutation (Rule 19): skip the <code>Resolved</code> call in the delete branch of
/// <method>OcuPilot.Port.MgmntPort.Service</method> -- the deployed legs send the delete and go red.</p>
Method TestTheDeleteIsSentOnlyForAnUndeployedListedService()
{
    Do ..ArmCanned()
    Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("DeleteApplication", "200 OK", "{""msg"":""deleted""}")
    Do ..HoldAllWritePairs()
    Set tSC = ..Service("DELETE", "USER", "Orphan.v2", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tResult.%ToJSON(), "200 {""Name"":""Orphan.v2"",""Namespace"":""USER""}", "a listed, undeployed service is deleted")
    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).CallText(), "GetWebRESTApps(USER)|GetRESTApps(USER)|DeleteApplication(USER,Orphan.v2)", "after both lists were read")
    For tName = "Probe.v1", "/api/probe", "orphan.v2" {
        Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
        Do ..ArmCanned()
        Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("DeleteApplication", "200 OK", "{""msg"":""deleted""}")
        Set tSC = ..Service("DELETE", "USER", tName, "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tName _ ": is refused")
        Do $$$AssertTrue(##class(OcuPilot.Test.MgmntImplFixture).CallText() '[ "DeleteApplication", tName _ ": and no delete was sent: " _ ##class(OcuPilot.Test.MgmntImplFixture).CallText())
    }
    For tCase = $ListBuild("403 Forbidden", "403 PORT.ACCESSDENIED The management API refused to enter this namespace for this account."), $ListBuild("500 Internal Server Error", "500 INTERNAL An internal error occurred") {
        Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
        Do ##class(OcuPilot.Test.LogProbe).Clear()
        Do ..ArmCanned()
        Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("DeleteApplication", $List(tCase, 1), "", "write")
        Set tSC = ..Service("DELETE", "USER", "Orphan.v2", "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..FaultText(tHttp, tFault), $List(tCase, 2), $List(tCase, 1) _ ": answered in its own words")
        Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ ##class(OcuPilot.Test.MgmntImplFixture).#VENDORTEXT, $List(tCase, 1) _ ": and the vendor's text reaches the log")
    }
}

/// <p>The Service endpoint's two writes have a <code>rest</code> script form and its two reads have none (Story 18.32,
/// AD-59): a create is one <code>curl</code> step posting the document to the management API's route for the namespace
/// and package, a delete one without a body, and a create with no document answers no step.</p>
/// <p>Mutation (Rule 19): answer <code>""</code> from <method>OcuPilot.Port.MgmntPort.SnippetForm</method> for
/// <code>POST</code> -- the form leg goes red.</p>
Method TestTheServiceWritesHaveARestScriptForm()
{
    Set tPort = "OcuPilot.Port.MgmntPort"
    Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "Service", "POST") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Service", "DELETE") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Service", "STATE") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Service", "SERVICE") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Applications", "LIST"), "rest|rest|||", "the writes script as rest, the reads not at all")
    Set tContext = {"origin": "https://draft.example:52773", "user": "probe'user"}
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("application") = "OcuProbe1832Z"
    Set tSteps = $ClassMethod(tPort, "Snippet", "Service", "POST", .tQuery, ..CreateBody(), tContext)
    Do $$$AssertEquals(tSteps.%Size() _ " " _ tSteps.%Get(0).kind, "1 rest", "a create is one rest step")
    Set tText = tSteps.%Get(0).text
    Do $$$AssertTrue((tText [ "curl -u 'probe'\''user' -X POST 'https://draft.example:52773/api/mgmnt/v2/USER/OcuProbe1832Z'") && (tText [ "-d '" _ ..CreateBody().Document.%ToJSON() _ "'"), "naming the caller, the route and the document: " _ tText)
    Set tSteps = $ClassMethod(tPort, "Snippet", "Service", "DELETE", .tQuery, "", tContext)
    Do $$$AssertTrue((tSteps.%Size() = 1) && (tSteps.%Get(0).text [ "-X DELETE") && (tSteps.%Get(0).text '[ "-d "), "a delete is one step with no body")
    Do $$$AssertEquals($ClassMethod(tPort, "Snippet", "Service", "POST", .tQuery, {}, tContext).%Size() _ $ClassMethod(tPort, "Snippet", "Service", "STATE", .tQuery, "", tContext).%Size(), "00", "a create with no document and a read answer no step")
}

}
