/// <p>The REST API explorer and the OpenAPI document viewer over the wire, against the live management
/// API: <code>GET /api/ocupilot/screens/:screen/read</code> as the configured test principal
/// (<class>OcuPilot.Test.Http</class>), for the explorer in <code>HSCUSTOM</code> and
/// <code>%SYS</code>, a generated and a stored document, the vendor's refused service, an unlisted
/// web application, a malformed argument and the row cap; and the read tool over the same two
/// screens, which answers the route's rows narrowed by the cap and no document.</p>
/// <p>Needs the API application installed in <code>HSCUSTOM</code> and the test principal holding
/// <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>. It issues reads only; the one
/// direct request to <code>/api/mgmnt</code> is this test's comparison, never product code's.</p>
Class OcuPilot.Test.MgmntPortWire Extends %UnitTest.TestCase
{

/// <p>The screen read route's prefix.</p>
Parameter READPATH = "/api/ocupilot/screens/";

/// <p>The one application both documents legs read.</p>
Parameter OCUPILOTAPI = "/api/ocupilot";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Request <var>pTool</var>'s read with query string <var>pQuery</var> as the test principal.
/// <var>pAnswer</var> is the parsed body, or <code>""</code>.</p>
Method Read(pTool As %String, pQuery As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject, Output pHeaders) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#READPATH _ pTool _ "/read?" _ pQuery, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tBody, .pHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set pAnswer = ""
    }
    Quit tSC
}

/// <p>The first row of <var>pRows</var> whose <code>Name</code> is <var>pName</var>, or
/// <code>""</code>.</p>
ClassMethod RowNamed(pRows As %DynamicArray, pName As %String) As %DynamicObject
{
    Set tFound = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Name = pName {
            Set tFound = tRow
            Quit
        }
    }
    Quit tFound
}

/// <p>A row's <code>Namespace</code>, <code>SpecBased</code> and <code>Enabled</code> as one line.</p>
ClassMethod RowText(pRow As %DynamicObject) As %String
{
    If '$IsObject(pRow) Quit "absent"
    Quit pRow.Namespace _ " spec=" _ pRow.%Get("SpecBased") _ " enabled=" _ $Select(pRow.%GetTypeOf("Enabled") = "null": "null", 1: pRow.%Get("Enabled"))
}

/// <p>Matrix: the explorer in <code>HSCUSTOM</code> answers 200 as JSON, and its rows include
/// <code>/api/ocupilot</code> (not spec-based, in <code>HSCUSTOM</code>) and <code>/api/mgmnt</code>
/// (spec-based, in <code>%SYS</code>), each carrying exactly the declared fields.</p>
/// <p>Mutation: set <code>SpecBased</code> from a <code>/api/mgmnt/v1/</code> prefix in
/// <method>OcuPilot.Port.MgmntPort.IsSpecBased</method> -&gt; both row assertions go red.</p>
Method TestTheExplorerInHSCUSTOMListsWebApplicationsWithTheirSpecKind()
{
    Set tSC = ..Read("webapp.restapis", "maxRows=1000&ns=HSCUSTOM", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the explorer is read")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertTrue($IsObject(tAnswer.rows), "with a rows array")
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), "[""Name"",""Namespace"",""DispatchClass"",""SpecBased"",""Enabled""]", "projecting the declared fields")
    Do $$$AssertEquals(..RowText(..RowNamed(tAnswer.rows, ..#OCUPILOTAPI)), "HSCUSTOM spec=0 enabled=1", "/api/ocupilot is listed, not spec-based, in HSCUSTOM")
    Do $$$AssertEquals(..RowText(..RowNamed(tAnswer.rows, "/api/mgmnt")), "%SYS spec=1 enabled=1", "/api/mgmnt is listed, spec-based, in %SYS")
    Do $$$AssertEquals(tAnswer.%IsDefined("document"), 0, "and the explorer carries no document")
}

/// <p>Matrix: the explorer in <code>%SYS</code> lists <code>%Api.InteropEditors.v7</code> as a
/// spec-based service with <code>Enabled</code> <code>null</code>, lists
/// <code>/api/interop-editors</code>, and does not list <code>%Api.Mgmnt.v2</code> separately,
/// because <code>/api/mgmnt</code> deploys it.</p>
Method TestTheExplorerInSYSListsUndeployedServicesOnce()
{
    Set tSC = ..Read("webapp.restapis", "maxRows=1000&ns=%25SYS", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the explorer is read in %SYS")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(..RowText(..RowNamed(tAnswer.rows, "%Api.InteropEditors.v7")), "%SYS spec=1 enabled=null", "%Api.InteropEditors.v7 is a spec-based service no web application deploys")
    Do $$$AssertEquals(..RowText(..RowNamed(tAnswer.rows, "/api/interop-editors")), "%SYS spec=0 enabled=1", "/api/interop-editors is listed")
    Do $$$AssertEquals(..RowNamed(tAnswer.rows, "%Api.Mgmnt.v2"), "", "%Api.Mgmnt.v2 is not a row of its own")
    Do $$$AssertTrue($IsObject(..RowNamed(tAnswer.rows, "/api/mgmnt")), "because /api/mgmnt deploys it")
}

/// <p>Matrix: the generated document for <code>/api/ocupilot</code> in <code>HSCUSTOM</code> answers
/// one row per operation with <code>Order</code> counting from 1, and its <code>document</code>
/// equals the body the management API itself serves for
/// <code>GET /api/mgmnt/v1/HSCUSTOM/spec/api/ocupilot</code>.</p>
Method TestTheGeneratedDocumentIsTheManagementAPIsOwn()
{
    Set tSC = ..Read("webapp.openapi", "application=%2Fapi%2Focupilot&maxRows=1000&ns=HSCUSTOM", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the document is read")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Set tOperations = ..OperationCount(tAnswer.document)
    Do $$$AssertTrue(tOperations > 0, "the document declares operations: " _ tOperations)
    Do $$$AssertEquals(tAnswer.rows.%Size(), tOperations, "one row per operation")
    Set tOrdered = 1
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Order '= (tIndex + 1) Set tOrdered = 0
    }
    Do $$$AssertTrue(tOrdered, "Order counts from 1 in document order")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/mgmnt/v1/HSCUSTOM/spec" _ ..#OCUPILOTAPI, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tMgmntStatus, .tMgmntBody, .tMgmntHeaders)
    Do $$$AssertStatusOK(tSC, "the management API's own request completes")
    Do $$$AssertEquals(tMgmntStatus, 200, "and answers")
    Set tMgmnt = ##class(%DynamicObject).%FromJSON($ZConvert(tMgmntBody, "I", "UTF8"))
    Do $$$AssertEquals(tAnswer.document.%ToJSON(), tMgmnt.%ToJSON(), "the document equals the management API's own body")
}

/// <p>How many operations <var>pDocument</var>'s <code>paths</code> declare.</p>
ClassMethod OperationCount(pDocument As %DynamicObject) As %Integer
{
    Set tCount = 0
    If '$IsObject(pDocument) || '$IsObject(pDocument.paths) Quit 0
    Set tPaths = pDocument.paths.%GetIterator()
    While tPaths.%GetNext(.tPath, .tItem) {
        Set tVerbs = tItem.%GetIterator()
        While tVerbs.%GetNext(.tVerb, .tOperation) {
            If $ListFind($ListFromString("get,put,post,delete,options,head,patch"), tVerb) Set tCount = tCount + 1
        }
    }
    Quit tCount
}

/// <p>Matrix: the stored document for <code>/api/mgmnt</code> read from <code>HSCUSTOM</code> is
/// Swagger 2.0, and each of its nine <code>#/parameters/</code> references on this build appears in
/// its operation's row resolved to the parameter it names.</p>
/// <p>Mutation: skip every <code>$ref</code> in
/// <method>OcuPilot.Port.MgmntPort.ResolvedParameters</method> -&gt; the resolved count reads 0 and goes
/// red.</p>
Method TestTheStoredDocumentsReferencesAreResolved()
{
    Set tSC = ..Read("webapp.openapi", "application=%2Fapi%2Fmgmnt&maxRows=1000&ns=HSCUSTOM", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the stored document is read")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.document.swagger, "2.0", "it is Swagger 2.0")

    Set tReferences = 0
    Set tResolved = 0
    Set tRowAt = 0
    Set tPaths = tAnswer.document.paths.%GetIterator()
    While tPaths.%GetNext(.tPath, .tItem) {
        Set tVerbs = tItem.%GetIterator()
        While tVerbs.%GetNext(.tVerb, .tOperation) {
            If '$ListFind($ListFromString("get,put,post,delete,options,head,patch"), tVerb) Continue
            Set tRow = tAnswer.rows.%Get(tRowAt)
            Set tRowAt = tRowAt + 1
            If '$IsObject(tOperation.parameters) Continue
            Set tParameters = tOperation.parameters.%GetIterator()
            While tParameters.%GetNext(.tIndex, .tParameter) {
                If tParameter.%GetTypeOf("$ref") '= "string" Continue
                Set tReferences = tReferences + 1
                Set tTarget = tAnswer.document.parameters.%Get($Piece(tParameter.%Get("$ref"), "/", 3))
                Set tWanted = {}
                Do tWanted.%Set("name", tTarget.name)
                Do tWanted.%Set("in", tTarget.in)
                Do tWanted.%Set("required", ''tTarget.required, "boolean")
                Do tWanted.%Set("type", tTarget.type)
                Set tFound = 0
                Set tEntries = tRow.Parameters.%GetIterator()
                While tEntries.%GetNext(.tEntryIndex, .tEntry) {
                    If tEntry.%ToJSON() = tWanted.%ToJSON() Set tFound = 1
                }
                If tFound Set tResolved = tResolved + 1
            }
        }
    }
    Do $$$AssertEquals(tReferences, 9, "the document declares nine parameter references on this build")
    Do $$$AssertEquals(tResolved, tReferences, "and every one appears resolved in its row")
}

/// <p>Matrix: the management API's refused service is 404 <code>PORT.NOTFOUND</code> with the reason
/// written for the method that refused it -- <code>%Api.InteropEditors.v7</code> as a package and
/// <code>/api/interop-editors</code> as a web application, both in <code>%SYS</code> -- and neither
/// reason carries the vendor's status text or a class name.</p>
Method TestTheRefusedServiceIsAnsweredByTheMethodThatRefusedIt()
{
    For tCase = $ListBuild("%25Api.InteropEditors.v7", "The management API refused this document: it reports no REST application by that name."), $ListBuild("%2Fapi%2Finterop-editors", "The management API refused this document: it reports no REST specification for that web application.") {
        Set tSC = ..Read("webapp.openapi", "application=" _ $List(tCase, 1) _ "&maxRows=1000&ns=%25SYS", .tStatus, .tAnswer, .tHeaders)
        Set tWhere = $ZConvert($List(tCase, 1), "I", "URL")
        Do $$$AssertStatusOK(tSC, tWhere _ ": the request completes")
        Do $$$AssertEquals(tStatus, 404, tWhere _ ": is refused")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tWhere _ ": as application/json")
        If (tStatus '= 404) || '$IsObject(tAnswer) Continue
        Do $$$AssertEquals(tAnswer.code, "PORT.NOTFOUND", tWhere _ ": on the not-found code")
        Do $$$AssertEquals(tAnswer.reason, $List(tCase, 2), tWhere _ ": with the reason written for its method")
        Do $$$AssertTrue('(tAnswer.%ToJSON() [ "ERROR #") && '(tAnswer.reason [ "%Api"), tWhere _ ": naming no vendor status or class")
    }
}

/// <p>Matrix: a web application the namespace does not list is 404 with its own reason, and a
/// missing or malformed application is 400 <code>PORT.VALIDATION</code>.</p>
Method TestAnUnlistedOrMalformedApplicationIsRefused()
{
    Set tSC = ..Read("webapp.openapi", "application=%2Fapi%2Fnosuch&ns=HSCUSTOM", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus, 404, "an unlisted web application is refused")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code _ " " _ tAnswer.reason, 1: ""), "PORT.NOTFOUND This namespace lists no REST application by that name.", "with its own reason")
    For tQuery = "ns=HSCUSTOM", "application=bad%20name&ns=HSCUSTOM" {
        Set tSC = ..Read("webapp.openapi", tQuery, .tStatus, .tAnswer, .tHeaders)
        Do $$$AssertEquals(tStatus, 400, tQuery _ ": is refused")
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code, 1: ""), "PORT.VALIDATION", tQuery _ ": on the validation code")
    }
}

/// <p>Matrix: <code>maxRows=5</code> on a document with more operations answers five rows,
/// <code>truncated</code> true and the whole document: the same document an uncapped read answers.</p>
Method TestTheRowCapNeverCutsTheDocument()
{
    Set tSC = ..Read("webapp.openapi", "application=%2Fapi%2Focupilot&maxRows=5&ns=HSCUSTOM", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the capped document is read")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Set tOperations = ..OperationCount(tAnswer.document)
    Do $$$AssertTrue(tOperations > 5, "the document has more than five operations: " _ tOperations)
    Do $$$AssertEquals(tAnswer.rows.%Size(), 5, "five rows")
    Do $$$AssertEquals(tAnswer.truncated, 1, "reported as cut")
    Set tSC = ..Read("webapp.openapi", "application=%2Fapi%2Focupilot&maxRows=1000&ns=HSCUSTOM", .tFullStatus, .tFull, .tFullHeaders)
    Do $$$AssertEquals(tFullStatus, 200, "the uncapped document is read")
    If (tFullStatus '= 200) || '$IsObject(tFull) Quit
    Do $$$AssertEquals(tFull.truncated, 0, "and is not cut")
    Do $$$AssertTrue(tAnswer.document.%ToJSON() = tFull.document.%ToJSON(), "the capped read's document is the uncapped read's, whole")
}

/// <p>Integration: the read tool over <code>webapp.restapis.read</code> and
/// <code>webapp.openapi.read</code> (<code>application=/api/ocupilot</code>) in scope
/// <code>HSCUSTOM</code> answers exactly the route's rows in the declared default order, narrowed by
/// the context cap, reports the cut, and carries no <code>document</code>.</p>
/// <p>Mutation: point <method>OcuPilot.Screen.Read.MgmntPortClass</method> at
/// <class>OcuPilot.Port.AdminPort</class> -&gt; both tool reads fail and go red.</p>
Method TestTheReadToolAnswersTheRoutesRowsNarrowedAndNoDocument()
{
    For tCase = $ListBuild("OcuPilot.Screen.Descriptor.RestApiList", "webapp.restapis", "", 3), $ListBuild("OcuPilot.Screen.Descriptor.OpenApiViewer", "webapp.openapi", ..#OCUPILOTAPI, 4) {
        Set tDescriptor = $List(tCase, 1)
        Set tTool = $List(tCase, 2) _ ".read"
        Set tApplication = $List(tCase, 3)
        Set tCap = $List(tCase, 4)

        Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
        Set tArgs = {}
        If tApplication '= "" Do tArgs.%Set("application", tApplication)
        Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(tDescriptor, tArgs, tCap, .tView)
        Do ##class(OcuPilot.Kernel.Scope).Clear()
        Do $$$AssertStatusOK(tSC, tTool _ ": the tool reads")
        If $$$ISERR(tSC) || '$IsObject(tView) Continue

        Set tQuery = "maxRows=1000&ns=HSCUSTOM"
        If tApplication '= "" Set tQuery = "application=" _ $ZConvert(tApplication, "O", "URL") _ "&" _ tQuery
        Set tSC = ..Read($List(tCase, 2), tQuery, .tStatus, .tRoute, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tTool _ ": the route answers the same read")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tTool _ ": as application/json")
        If (tStatus '= 200) || '$IsObject(tRoute) Continue
        Set tOrdered = ##class(OcuPilot.Screen.Read).ApplyView(tRoute.rows, $ClassMethod(tDescriptor, "Read"))
        Set tWanted = []
        For tI = 0:1:(tCap - 1) Do tWanted.%Push(tOrdered.%Get(tI))

        Do $$$AssertEquals(tView.rows.%ToJSON(), tWanted.%ToJSON(), tTool _ ": the route's rows in default order, narrowed by the cap")
        Do $$$AssertEquals(tView.truncated, 1, tTool _ ": reporting the cut")
        Set tKeys = ""
        Set tIterator = tView.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
        }
        ; A read that declares criteria also reports the ones it applied (AD-36, Story 11.11).
        Do $$$AssertEquals(tKeys, "fields,rows,truncated,rowsAvailable" _ $Select(##class(OcuPilot.Screen.Read).CriteriaParams(tDescriptor) '= "": ",criteria", 1: ""), tTool _ ": and no document key")
    }
}

}
