/// <p>The port to the instance's own management API, the business logic behind
/// <code>/api/mgmnt</code> (AD-1, AD-29). <b>This is the only product class that names
/// <code>%Api.Mgmnt.*</code>, <code>%REST.*</code> or <code>%SYS.REST</code></b>, and it names the
/// vendor's implementation class only through <parameter>IMPLCLASS</parameter>.</p>
/// <p><method>Invoke</method> is the one way in. It serves two endpoints, both of request type
/// <parameter>REQUESTTYPE</parameter>: <parameter>ENDPOINTAPPLICATIONS</parameter>, the REST
/// applications a namespace offers, and <parameter>ENDPOINTDOCUMENT</parameter>, one application's
/// OpenAPI document with a row per operation. The vendor methods are called in process, never over
/// HTTP.</p>
/// <p><b>The order of every call is fixed.</b> The declared pair set <parameter>PAIRS</parameter> is
/// evaluated in the calling process first, before any argument is read and before any vendor call,
/// so a denial reaches no vendor code. The arguments are shape-checked next. Each vendor method then
/// runs behind fresh <code>%request</code>/<code>%response</code> stubs with its device output
/// captured, and its outcome is read from both its return value and <code>%response.Status</code>.
/// The vendor methods switch namespace for themselves; this class never sets
/// <code>$NAMESPACE</code>.</p>
/// <p><b>Every refusal is a written reason.</b> A vendor status maps to a slug, a code and a sentence
/// chosen here per vendor method (AD-12, AD-39); the vendor's own text and anything it wrote to the
/// device go to <method>OcuPilot.Kernel.Fault.LogRaw</method> and nowhere else.</p>
/// <p>Seams a test subclass overrides (<class>OcuPilot.Test.MgmntPortFixture</class>):
/// <method>GateClass</method>, <method>ImplClass</method> and <method>LogFault</method>. Production
/// overrides none of them.</p>
Class OcuPilot.Port.MgmntPort Extends %RegisteredObject
{

/// <p>The vendor's management API business-logic class.</p>
Parameter IMPLCLASS = "%Api.Mgmnt.v2.impl";

/// <p>The pair set every call requires, comma-separated as <code>resource:permission</code>, in the
/// order the gate reports in (AD-8). It is the web-applications area's own set, and both descriptors
/// over this port declare exactly it. Without <code>%DB_IRISSYS:READ</code> the vendor does not
/// refuse a <code>%SYS</code> read: it silently runs it in its user namespace instead.</p>
Parameter PAIRS = "%Admin_Secure:USE,%DB_IRISSYS:READ";

/// <p>The class the pair set is evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The endpoint answering a namespace's REST applications.</p>
Parameter ENDPOINTAPPLICATIONS = "Applications";

/// <p>The endpoint answering one application's OpenAPI document.</p>
Parameter ENDPOINTDOCUMENT = "Document";

/// <p>The one request type either endpoint serves.</p>
Parameter REQUESTTYPE = "LIST";

/// <p>The query key carrying the namespace the read runs in.</p>
Parameter NAMESPACEKEY = "namespace";

/// <p>The query key carrying the document's application name.</p>
Parameter APPLICATIONKEY = "application";

/// <p>The query key carrying the row cap.</p>
Parameter MAXROWSKEY = "maxRows";

/// <p>The shape a namespace name must take.</p>
Parameter NAMESPACEPATTERN = "^%?[A-Za-z0-9][A-Za-z0-9_-]*$";

/// <p>The shape a spec-based service's package name must take.</p>
Parameter PACKAGEPATTERN = "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$";

/// <p>The longest application name the document endpoint reads.</p>
Parameter APPLICATIONMAXLENGTH As INTEGER = 256;

/// <p>The vendor's <code>swaggerSpec</code> prefix for a service built from a specification.</p>
Parameter SPECPREFIX = "/api/mgmnt/v2/";

/// <p>The class-name suffix of a spec-based service's dispatch class.</p>
Parameter DISPATCHSUFFIX = ".disp";

/// <p>The prefix of a parameter reference this port resolves from the document.</p>
Parameter PARAMETERREFPREFIX = "#/parameters/";

/// <p>The path-item keys that name an operation, comma-separated.</p>
Parameter VERBS = "get,put,post,delete,options,head,patch";

/// <p>The subsystem raw vendor text is logged under.</p>
Parameter LOGSUBSYSTEM = "mgmntport";

/// <p>The reason a request the port does not serve is refused with.</p>
Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

/// <p>The reason a missing or malformed namespace is refused with.</p>
Parameter REASONNAMESPACESHAPE = "Name the namespace the read runs in.";

/// <p>The reason a malformed row cap is refused with.</p>
Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

/// <p>The reason a missing or malformed application name is refused with.</p>
Parameter REASONAPPLICATIONSHAPE = "Name one REST application: a web application path starting with /, or a spec-based service's package name.";

/// <p>The reason a web application name the namespace does not list is refused with.</p>
Parameter REASONUNLISTED = "This namespace lists no REST application by that name.";

/// <p>The reason <code>GetApplication</code>'s 404 is refused with.</p>
Parameter REASONNOAPPLICATION = "The management API refused this document: it reports no REST application by that name.";

/// <p>The reason <code>GetWebRESTApplication</code>'s 404 is refused with.</p>
Parameter REASONNOSPECIFICATION = "The management API refused this document: it reports no REST specification for that web application.";

/// <p>The reason a document method's 400 is refused with.</p>
Parameter REASONBUILD = "The management API could not build this document.";

/// <p>The reason the vendor's refused namespace switch (its 403) is refused with.</p>
Parameter REASONNAMESPACE = "The management API refused to enter this namespace for this account.";

/// <p>The class the pair set is evaluated through. Overridable so a fixture can drive a denial in
/// process; production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>The vendor class the calls are issued to. Overridable so a fixture can answer the statuses the
/// live instance cannot produce on demand; production never overrides it.</p>
ClassMethod ImplClass() As %String
{
    Quit ..#IMPLCLASS
}

/// <p><parameter>PAIRS</parameter> as the <code>%List</code> of two-element <code>%List</code>s the
/// gate evaluates.</p>
ClassMethod Pairs() As %List
{
    Set tPairs = ""
    Set tDeclared = ..#PAIRS
    For tI = 1:1:$Length(tDeclared, ",") {
        Set tPair = $Piece(tDeclared, ",", tI)
        If tPair = "" Continue
        Set tPairs = tPairs _ $ListBuild($ListBuild($Piece(tPair, ":", 1), $Piece(tPair, ":", 2)))
    }
    Quit tPairs
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var>.</p>
/// <p><var>pQuery</var> carries <code>namespace</code> (required), <code>maxRows</code> (optional,
/// a whole number above zero that bounds the rows) and, for <parameter>ENDPOINTDOCUMENT</parameter>,
/// <code>application</code>: a web application path that the namespace's own list names exactly, or
/// a spec-based service's package name. <var>pBody</var> is not read.</p>
/// <p>On success <var>pResult</var> is a <class>%DynamicArray</class> of rows and
/// <var>pHttpStatus</var> is 200. An <parameter>ENDPOINTAPPLICATIONS</parameter> row carries
/// <code>Name</code>, <code>Namespace</code>, <code>DispatchClass</code>, <code>SpecBased</code> and
/// <code>Enabled</code> (<code>null</code> for a service no web application deploys); a
/// spec-based service a listed web application dispatches to appears once, under that web
/// application. An <parameter>ENDPOINTDOCUMENT</parameter> row is one operation
/// (<method>DocumentRows</method>), and <var>pDocument</var> is the vendor's document, unmodified
/// and never cut by the row cap.</p>
/// <p>Otherwise an error status is returned with <var>pResult</var> and <var>pDocument</var> empty,
/// <var>pHttpStatus</var> the status to answer with and <var>pFault</var> the wire fault: 403
/// <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code> before anything else is read,
/// 501 <code>PORT.NOTIMPLEMENTED</code>, 400 <code>PORT.VALIDATION</code> for a malformed argument
/// or a document the vendor could not build, 404 <code>PORT.NOTFOUND</code>, 403
/// <code>PORT.ACCESSDENIED</code> for a namespace the vendor refused to enter, and 500
/// <code>INTERNAL</code> for anything else.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace,
/// <code>%request</code>, <code>%response</code> and <code>%session</code> are unchanged on
/// return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pDocument As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pDocument = ""
    Try {
        Set tFailedPair = ""
        ; EvaluateRequired, not EvaluatePairs: a PAIRS parameter mis-edited to empty must fail
        ; closed rather than open the port to everyone (DW-1120).
        If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(), .tFailedPair) {
            Set tDenial = ##class(OcuPilot.Kernel.Denial).Detail(tFailedPair)
            Set tSC = ..Refuse(##class(OcuPilot.Kernel.Denial).#STATUS, ##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason(), .pHttpStatus, .pFault, tDenial)
            Quit
        }

        If (pType '= ..#REQUESTTYPE) || ((pEndpoint '= ..#ENDPOINTAPPLICATIONS) && (pEndpoint '= ..#ENDPOINTDOCUMENT)) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
        If '$Match(tNamespace, ..#NAMESPACEPATTERN) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACESHAPE, .pHttpStatus, .pFault)
            Quit
        }
        Set tMax = $Get(pQuery(..#MAXROWSKEY))
        If (tMax '= "") && '$Match(tMax, "^[1-9][0-9]*$") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
            Quit
        }

        If pEndpoint = ..#ENDPOINTAPPLICATIONS {
            Set tSC = ..Applications(tNamespace, +tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }

        Set tApplication = $Get(pQuery(..#APPLICATIONKEY))
        If '..ApplicationShapeOk(tApplication) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONAPPLICATIONSHAPE, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Document(tNamespace, tApplication, +tMax, .pResult, .pDocument, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set pDocument = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether <var>pApplication</var> is a name the document endpoint reads: at most
/// <parameter>APPLICATIONMAXLENGTH</parameter> characters, and either a path starting with
/// <code>/</code> carrying no control character or a package name.</p>
ClassMethod ApplicationShapeOk(pApplication As %String) As %Boolean
{
    If (pApplication = "") || ($Length(pApplication) > ..#APPLICATIONMAXLENGTH) Quit 0
    If $Extract(pApplication) = "/" Quit '$Locate(pApplication, "[\x00-\x1F\x7F]")
    Quit $Match(pApplication, ..#PACKAGEPATTERN)
}

/// <p>The <parameter>ENDPOINTAPPLICATIONS</parameter> rows for <var>pNamespace</var>, at most
/// <var>pMax</var> of them when it is above zero: the namespace's web applications, then the
/// spec-based services no listed web application dispatches to.</p>
ClassMethod Applications(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = ""
    Try {
        Set tSC = ..Call("GetWebRESTApps", pNamespace, "", .tWeb, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tSC = ..Call("GetRESTApps", pNamespace, "", .tServices, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tRows = []
        Kill tDeployed
        Set tIterator = tWeb.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tApp) {
            If '$IsObject(tApp) || 'tApp.%IsA("%Library.DynamicObject") Continue
            Set tNs = tApp.%Get("namespace")
            Set tDispatch = tApp.%Get("dispatchClass")
            If (tNs '= "") && (tDispatch '= "") Set tDeployed(tNs, tDispatch) = ""
            If (pMax > 0) && (tRows.%Size() = pMax) Continue
            Set tRow = {}
            Do tRow.%Set("Name", tApp.%Get("name"))
            Do tRow.%Set("Namespace", tNs)
            Do tRow.%Set("DispatchClass", tDispatch)
            Do tRow.%Set("SpecBased", ..IsSpecBased(tApp), "boolean")
            If tApp.%GetTypeOf("enabled") = "boolean" {
                Do tRow.%Set("Enabled", tApp.%Get("enabled"), "boolean")
            } Else {
                Do tRow.%Set("Enabled", "", "null")
            }
            Do tRows.%Push(tRow)
        }
        Set tIterator = tServices.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tService) {
            If (pMax > 0) && (tRows.%Size() = pMax) Quit
            If '$IsObject(tService) || 'tService.%IsA("%Library.DynamicObject") Continue
            Set tNs = tService.%Get("namespace")
            Set tDispatch = tService.%Get("dispatchClass")
            If (tNs '= "") && (tDispatch '= "") && $Data(tDeployed(tNs, tDispatch)) Continue
            Set tRow = {}
            Do tRow.%Set("Name", tService.%Get("name"))
            Do tRow.%Set("Namespace", tNs)
            Do tRow.%Set("DispatchClass", tDispatch)
            Do tRow.%Set("SpecBased", 1, "boolean")
            Do tRow.%Set("Enabled", "", "null")
            Do tRows.%Push(tRow)
        }
        Set pRows = tRows
        Set pHttpStatus = 200
    } Catch ex {
        Set pRows = ""
        Set tSC = ..Fail("the application list failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether a vendor web application row names a service built from a specification: its
/// <code>swaggerSpec</code> is a <parameter>SPECPREFIX</parameter> URL.</p>
ClassMethod IsSpecBased(pApp As %DynamicObject) As %Boolean [ Private ]
{
    Quit $Extract(pApp.%Get("swaggerSpec"), 1, $Length(..#SPECPREFIX)) = ..#SPECPREFIX
}

/// <p>The <parameter>ENDPOINTDOCUMENT</parameter> answer for <var>pApplication</var> in
/// <var>pNamespace</var>.</p>
/// <p>A name starting with <code>/</code> must equal a <code>name</code> the namespace's own web
/// application list carries, exactly; a name it does not carry is refused before any document is
/// requested. A listed spec-based web application resolves to its service's document in the row's
/// own namespace, and any other listed web application to the document generated from its dispatch
/// class. A package name resolves to that service's document in <var>pNamespace</var>.</p>
ClassMethod Document(pNamespace As %String, pApplication As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pDocument As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = ""
    Set pDocument = ""
    Try {
        Set tMethod = "GetApplication"
        Set tNs = pNamespace
        Set tName = pApplication
        If $Extract(pApplication) = "/" {
            Set tSC = ..Call("GetWebRESTApps", pNamespace, "", .tWeb, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            Set tListed = ""
            Set tIterator = tWeb.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tApp) {
                If '$IsObject(tApp) || 'tApp.%IsA("%Library.DynamicObject") Continue
                If tApp.%GetTypeOf("name") '= "string" Continue
                If tApp.%Get("name") '= pApplication Continue
                Set tListed = tApp
                Quit
            }
            If '$IsObject(tListed) {
                Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ..#REASONUNLISTED, .pHttpStatus, .pFault)
                Quit
            }
            Set tNs = tListed.%Get("namespace")
            Set tDispatch = tListed.%Get("dispatchClass")
            Set tSuffix = $Length(..#DISPATCHSUFFIX)
            If ..IsSpecBased(tListed) && ($Extract(tDispatch, *-(tSuffix - 1), *) = ..#DISPATCHSUFFIX) {
                Set tName = $Extract(tDispatch, 1, *-tSuffix)
            } Else {
                Set tMethod = "GetWebRESTApplication"
            }
        }
        Set tSC = ..Call(tMethod, tNs, tName, .tDocument, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pRows = ..DocumentRows(tDocument, pMax)
        Set pDocument = tDocument
        Set pHttpStatus = 200
    } Catch ex {
        Set pRows = ""
        Set pDocument = ""
        Set tSC = ..Fail("the document read failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>One row per operation of <var>pDocument</var>, at most <var>pMax</var> of them when it is above
/// zero, in the order <code>paths</code> iterates and, within a path item, in that item's own key
/// order over <parameter>VERBS</parameter>.</p>
/// <p>A row carries <code>Order</code> (1-based), <code>Path</code>, <code>Verb</code> (the
/// document's own key), <code>Summary</code> and <code>OperationId</code> (<code>""</code> when
/// absent), <code>Parameters</code> and <code>Responses</code>. <code>Parameters</code> is
/// <code>[{name, in, required, type}]</code>: the path item's parameters in their order, each
/// replaced in place by the operation's own parameter of the same <code>name</code> and
/// <code>in</code>, followed by the operation's remaining parameters. A
/// <parameter>PARAMETERREFPREFIX</parameter> reference is resolved from the document's own
/// <code>parameters</code>, and one that resolves to nothing is left out. <code>Responses</code> is
/// <code>[{code, description}]</code> in the operation's key order.</p>
ClassMethod DocumentRows(pDocument As %DynamicObject, pMax As %Integer = 0) As %DynamicArray
{
    Set tRows = []
    Set tPaths = pDocument.%Get("paths")
    If '$IsObject(tPaths) || 'tPaths.%IsA("%Library.DynamicObject") Quit tRows
    Set tVerbs = $ListFromString(..#VERBS)
    Set tPathIterator = tPaths.%GetIterator()
    While tPathIterator.%GetNext(.tPath, .tItem) {
        If (pMax > 0) && (tRows.%Size() = pMax) Quit
        If '$IsObject(tItem) || 'tItem.%IsA("%Library.DynamicObject") Continue
        Set tShared = ..ResolvedParameters(pDocument, tItem.%Get("parameters"))
        Set tVerbIterator = tItem.%GetIterator()
        While tVerbIterator.%GetNext(.tVerb, .tOperation) {
            If (pMax > 0) && (tRows.%Size() = pMax) Quit
            If '$ListFind(tVerbs, tVerb) Continue
            If '$IsObject(tOperation) || 'tOperation.%IsA("%Library.DynamicObject") Continue
            Set tRow = {}
            Do tRow.%Set("Order", tRows.%Size() + 1, "number")
            Do tRow.%Set("Path", tPath)
            Do tRow.%Set("Verb", tVerb)
            Do tRow.%Set("Summary", ..StringOf(tOperation, "summary"))
            Do tRow.%Set("OperationId", ..StringOf(tOperation, "operationId"))
            Do tRow.%Set("Parameters", ..MergedParameters(tShared, ..ResolvedParameters(pDocument, tOperation.%Get("parameters"))))
            Do tRow.%Set("Responses", ..ResponseList(tOperation.%Get("responses")))
            Do tRows.%Push(tRow)
        }
    }
    Quit tRows
}

/// <p><var>pDeclared</var>, a document's parameter array, as <code>{name, in, required, type}</code>
/// objects with every resolvable reference resolved; <code>[]</code> when it is not an array.</p>
ClassMethod ResolvedParameters(pDocument As %DynamicObject, pDeclared) As %DynamicArray [ Private ]
{
    Set tOut = []
    If '$IsObject(pDeclared) || 'pDeclared.%IsA("%Library.DynamicArray") Quit tOut
    Set tIterator = pDeclared.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tParameter) {
        If '$IsObject(tParameter) || 'tParameter.%IsA("%Library.DynamicObject") Continue
        If tParameter.%GetTypeOf("$ref") = "string" {
            Set tParameter = ..ParameterFor(pDocument, tParameter.%Get("$ref"))
            If '$IsObject(tParameter) Continue
        }
        Set tEntry = {}
        Do tEntry.%Set("name", ..StringOf(tParameter, "name"))
        Do tEntry.%Set("in", ..StringOf(tParameter, "in"))
        Do tEntry.%Set("required", (tParameter.%GetTypeOf("required") = "boolean") && tParameter.%Get("required"), "boolean")
        Do tEntry.%Set("type", ..StringOf(tParameter, "type"))
        Do tOut.%Push(tEntry)
    }
    Quit tOut
}

/// <p>The parameter object <var>pRef</var> names in <var>pDocument</var>'s own
/// <code>parameters</code>, or <code>""</code> when it names none there.</p>
ClassMethod ParameterFor(pDocument As %DynamicObject, pRef As %String) As %DynamicObject [ Private ]
{
    Set tPrefix = ..#PARAMETERREFPREFIX
    If $Extract(pRef, 1, $Length(tPrefix)) '= tPrefix Quit ""
    Set tName = $Extract(pRef, $Length(tPrefix) + 1, *)
    ; A JSON pointer escapes / as ~1 and ~ as ~0, in that order of decoding.
    Set tName = $Replace($Replace(tName, "~1", "/"), "~0", "~")
    Set tDeclared = pDocument.%Get("parameters")
    If '$IsObject(tDeclared) || 'tDeclared.%IsA("%Library.DynamicObject") Quit ""
    If tDeclared.%GetTypeOf(tName) '= "object" Quit ""
    Quit tDeclared.%Get(tName)
}

/// <p><var>pShared</var> with each entry replaced by the <var>pOwn</var> entry of the same
/// <code>name</code> and <code>in</code>, followed by the rest of <var>pOwn</var>.</p>
ClassMethod MergedParameters(pShared As %DynamicArray, pOwn As %DynamicArray) As %DynamicArray [ Private ]
{
    Kill tOwnAt
    Set tIterator = pOwn.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tOwnAt($ListBuild(tEntry.%Get("in"), tEntry.%Get("name"))) = tIndex
    }
    Set tOut = []
    Kill tUsed
    Set tIterator = pShared.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tKey = $ListBuild(tEntry.%Get("in"), tEntry.%Get("name"))
        If $Data(tOwnAt(tKey)) {
            Do tOut.%Push(pOwn.%Get(tOwnAt(tKey)))
            Set tUsed(tOwnAt(tKey)) = ""
        } Else {
            Do tOut.%Push(tEntry)
        }
    }
    Set tIterator = pOwn.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If $Data(tUsed(tIndex)) Continue
        Do tOut.%Push(tEntry)
    }
    Quit tOut
}

/// <p>An operation's <code>responses</code> object as <code>[{code, description}]</code> in its key
/// order; <code>[]</code> when it is not an object.</p>
ClassMethod ResponseList(pResponses) As %DynamicArray [ Private ]
{
    Set tOut = []
    If '$IsObject(pResponses) || 'pResponses.%IsA("%Library.DynamicObject") Quit tOut
    Set tIterator = pResponses.%GetIterator()
    While tIterator.%GetNext(.tCode, .tResponse) {
        Set tEntry = {}
        Do tEntry.%Set("code", tCode, "string")
        Set tDescription = ""
        If $IsObject(tResponse) && tResponse.%IsA("%Library.DynamicObject") Set tDescription = ..StringOf(tResponse, "description")
        Do tEntry.%Set("description", tDescription)
        Do tOut.%Push(tEntry)
    }
    Quit tOut
}

/// <p><var>pObject</var>'s <var>pKey</var> when it is a JSON string, and <code>""</code>
/// otherwise.</p>
ClassMethod StringOf(pObject As %DynamicObject, pKey As %String) As %String [ Private ]
{
    If pObject.%GetTypeOf(pKey) '= "string" Quit ""
    Quit pObject.%Get(pKey)
}

/// <p>Call vendor method <var>pMethod</var> with <var>pNamespace</var> and, when it is not
/// <code>""</code>, <var>pName</var>, and answer its value as <var>pAnswer</var>.</p>
/// <p>The call runs behind <code>New</code>ed <code>%request</code>, <code>%response</code> and
/// <code>%session</code>, with fresh request and response stubs and the device captured, so neither
/// the caller's CSP objects nor its response device is read or written. A 2xx status carrying the
/// value the method answers on success -- an array from a list method, an object from a document
/// method -- is success; every other outcome is an error status built by
/// <method>Outcome</method>.</p>
ClassMethod Call(pMethod As %String, pNamespace As %String, pName As %String, Output pAnswer, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set tAnswer = ""
    Set tHttp = 0
    Set tCaptured = ""
    Set tCapturing = 0
    New %request, %response, %session
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %response = ##class(%CSP.Response).%New()
        Set tCallSC = $$BeginCapture^%SYS.Capture(.tCookie)
        If $$$ISOK(tCallSC) {
            Set tCapturing = 1
            If pName = "" {
                Set tAnswer = $ClassMethod(..ImplClass(), pMethod, pNamespace)
            } Else {
                Set tAnswer = $ClassMethod(..ImplClass(), pMethod, pNamespace, pName)
            }
        }
    } Catch exCall {
        Set tAnswer = ""
        Set tCallSC = exCall.AsStatus()
    }
    If tCapturing {
        Try {
            Kill tLines
            Set tEndSC = $$EndCapture^%SYS.Capture(tCookie, .tLines)
            If $IsObject($Get(tLines)) {
                Set tIterator = tLines.%GetIterator()
                While tIterator.%GetNext(.tIndex, .tLine) {
                    Set tCaptured = tCaptured _ $Select(tCaptured = "": "", 1: " ") _ tLine
                }
            }
        } Catch exEnd {
            If $$$ISOK(tCallSC) Set tCallSC = exEnd.AsStatus()
        }
    }
    If $IsObject($Get(%response)) Set tHttp = +%response.Status
    Set tSC = ..Outcome(pMethod, tCallSC, tAnswer, tHttp, tCaptured, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Set pAnswer = tAnswer
    Quit tSC
}

/// <p>What one vendor call's outcome means.</p>
/// <p>A call that did not raise, under a 2xx status, answering an array from a list method or an
/// object from a document method, is success. A 403 is the vendor's refused namespace switch. A 404
/// from <code>GetApplication</code> or <code>GetWebRESTApplication</code> is that method's own
/// refusal, and a 400 from either is a document the vendor could not build. Anything else is an
/// internal failure. The vendor's own status and captured output are logged on every error path and
/// never put on the wire.</p>
ClassMethod Outcome(pMethod As %String, pCallSC As %Status, pAnswer, pHttp As %Integer, pCaptured As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDocumentMethod = (pMethod = "GetApplication") || (pMethod = "GetWebRESTApplication")
    Set tWanted = $Select(tDocumentMethod: "%Library.DynamicObject", 1: "%Library.DynamicArray")
    If $$$ISOK(pCallSC) && (pHttp >= 200) && (pHttp < 300) && $IsObject(pAnswer) && pAnswer.%IsA(tWanted) {
        Set pHttpStatus = pHttp
        Quit $$$OK
    }
    Set tRaw = pMethod _ " answered HTTP " _ pHttp
    If $$$ISERR(pCallSC) Set tRaw = tRaw _ "; " _ $System.Status.GetErrorText(pCallSC)
    If pCaptured '= "" Set tRaw = tRaw _ "; " _ pCaptured
    Set tRawSC = $$$ERROR($$$GeneralError, tRaw)
    If $$$ISERR(pCallSC) || ((pHttp >= 200) && (pHttp < 300)) Quit ..Fail(pMethod _ " failed", tRawSC, .pHttpStatus, .pFault)
    If pHttp = 403 {
        Set tSC = ..Refuse(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED, ..#REASONNAMESPACE, .pHttpStatus, .pFault)
    } ElseIf tDocumentMethod && (pHttp = 404) {
        Set tReason = $Select(pMethod = "GetApplication": ..#REASONNOAPPLICATION, 1: ..#REASONNOSPECIFICATION)
        Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, tReason, .pHttpStatus, .pFault)
    } ElseIf tDocumentMethod && (pHttp = 400) {
        Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONBUILD, .pHttpStatus, .pFault)
    } Else {
        Quit ..Fail(pMethod _ " failed", tRawSC, .pHttpStatus, .pFault)
    }
    Do ..LogFault(pMethod _ " was refused", tRawSC, pFault.code)
    Quit tSC
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture
/// the line; production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>A refusal this port decided, with a written reason. <var>pDetail</var>, when supplied, becomes
/// the fault's <code>detail</code> (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDetail As %DynamicObject = "") As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    If $IsObject(pDetail) Do pFault.%Set("detail", pDetail)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p><code>""</code>: no write reaches the management API through this port, so no request type
/// has a script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ""
}

/// <p>No step: every branch of <method>Invoke</method> is a read (AD-59).</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    Quit []
}

}
