/// <p>The port to the instance's own management API, the business logic behind
/// <code>/api/mgmnt</code> (AD-1, AD-29). <b>This is the only product class that names
/// <code>%Api.Mgmnt.*</code>, <code>%REST.*</code> or <code>%SYS.REST</code></b>, and it names the
/// vendor's implementation class only through <parameter>IMPLCLASS</parameter>.</p>
/// <p><method>Invoke</method> is the one way in. It serves two read endpoints, both of request type
/// <parameter>REQUESTTYPE</parameter>: <parameter>ENDPOINTAPPLICATIONS</parameter>, the REST
/// applications a namespace offers, and <parameter>ENDPOINTDOCUMENT</parameter>, one application's
/// OpenAPI document with a row per operation. Its third, <parameter>ENDPOINTSERVICE</parameter>
/// (Story 18.32), reads and writes one spec-based service by its package name:
/// <parameter>TYPESTATE</parameter> and <parameter>TYPESERVICE</parameter> read it,
/// <parameter>TYPECREATE</parameter> builds it from an OpenAPI 2.0 document and
/// <parameter>TYPEDELETE</parameter> removes its specification and dispatch classes (<method>Service</method>).
/// The vendor methods are called in process, never over HTTP.</p>
/// <p><b>The order of every call is fixed.</b> The declared pair set <parameter>PAIRS</parameter> is
/// evaluated in the calling process first, before any argument is read and before any vendor call,
/// so a denial reaches no vendor code. The arguments are shape-checked next. Each vendor method then
/// runs behind fresh <code>%request</code>/<code>%response</code> stubs with its device output
/// captured, and its outcome is read from both its return value and <code>%response.Status</code>.
/// The vendor methods switch namespace for themselves; this class sets <code>$NAMESPACE</code> only to read a
/// dispatch class's <code>UrlMap</code> (<method>Forwards</method>), by explicit save and restore.</p>
/// <p><b>Every refusal is a written reason.</b> A vendor status maps to a slug, a code and a sentence
/// chosen here per vendor method (AD-12, AD-39); the vendor's own text and anything it wrote to the
/// device go to <method>OcuPilot.Kernel.Fault.LogRaw</method> and nowhere else.</p>
/// <p>Seams a test subclass overrides (<class>OcuPilot.Test.MgmntPortFixture</class>):
/// <method>GateClass</method>, <method>ImplClass</method>, <method>Namespaces</method> and <method>LogFault</method>.
/// Production overrides none of them.</p>
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

/// <p>How many <code>Forward</code> hops from a web application's dispatch class <method>Resolved</method> follows
/// looking for a service's dispatch class.</p>
Parameter FORWARDDEPTH As INTEGER = 8;

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

/// <p>The same refusal for another namespace a REST service delete reads (<method>DeployedAnywhere</method>), naming it
/// in place of <code>&lt;namespace&gt;</code>.</p>
Parameter REASONNAMESPACEOTHER = "A REST service is deleted only after every namespace's web applications are read, and the management API refused to enter <namespace> for this account.";

/// <p>The endpoint reading and writing one spec-based service (Story 18.32).</p>
Parameter ENDPOINTSERVICE = "Service";

/// <p>The request type answering <code>{Name, Namespace}</code> for a service the namespace lists, or whose
/// specification or dispatch class it holds, in any letter case: the fresh read of a create.</p>
Parameter TYPESTATE = "STATE";

/// <p>The request type answering <code>{Name, Namespace, Implementation}</code> for a service the namespace lists
/// exactly and no web application dispatches to: the fresh read of a delete.</p>
Parameter TYPESERVICE = "SERVICE";

/// <p>The request type building a service from the body's <parameter>DOCUMENTFIELD</parameter>
/// (<code>CreateApplication</code>).</p>
Parameter TYPECREATE = "POST";

/// <p>The request type removing a service's specification and dispatch classes (<code>DeleteApplication</code>).</p>
Parameter TYPEDELETE = "DELETE";

/// <p>The pairs a create or a delete requires beyond <parameter>PAIRS</parameter>, comma-separated as
/// <code>resource:permission</code> (AD-8): the code editors' resource. WRITE on the namespace's routines database
/// is added for the namespace written (<method>WritePairs</method>).</p>
Parameter WRITEPAIRS = "%Development:USE";

/// <p>The permission a create or a delete requires on the resource guarding its namespace's routines database.</p>
Parameter WRITEPERMISSION = "WRITE";

/// <p>The body member carrying the OpenAPI document.</p>
Parameter DOCUMENTFIELD = "Document";

/// <p>The shape a created service's package name must take: no percent sign.</p>
Parameter NAMEPATTERN = "^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$";

/// <p>The suffix of a spec-based service's implementation class, which a delete keeps.</p>
Parameter IMPLEMENTATIONSUFFIX = ".impl";

/// <p>The suffix of a spec-based service's specification class.</p>
Parameter SPECIFICATIONSUFFIX = ".spec";

/// <p>The reason a namespace whose databases cannot be resolved is refused with.</p>
Parameter REASONNAMESPACEUNKNOWN = "This instance cannot name the databases that namespace reads code from.";

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
/// <p><parameter>ENDPOINTSERVICE</parameter> is answered by <method>Service</method>: its pairs, namespace and
/// argument rules are that method's, and <var>pDocument</var> is not set.</p>
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

        If pEndpoint = ..#ENDPOINTSERVICE {
            Set tSC = ..Service(pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
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

/// <p>The <parameter>ENDPOINTSERVICE</parameter> answer for request type <var>pType</var> (Story 18.32), after
/// <parameter>PAIRS</parameter> has passed. The order is fixed, and nothing reaches the vendor before all of it has
/// passed:</p>
/// <ol>
/// <li>the type: <parameter>TYPESTATE</parameter>, <parameter>TYPESERVICE</parameter>,
/// <parameter>TYPECREATE</parameter> or <parameter>TYPEDELETE</parameter>, else 501;</li>
/// <li>the namespace: the query's <parameter>NAMESPACEKEY</parameter>, or the request's scope
/// (<method>OcuPilot.Kernel.Scope.Current</method>), its shape checked;</li>
/// <li>for a create or a delete, <method>WritePairs</method> for that namespace, refused 403 naming the first pair
/// the caller lacks;</li>
/// <li>the service name (<parameter>APPLICATIONKEY</parameter>): a create's package rules
/// (<method>NameProblem</method>) and then its document rules (<method>DocumentProblem</method>), refused 422;
/// every other type's shape (<method>ApplicationShapeOk</method>), refused 400.</li>
/// </ol>
/// <p>Answers, at 200 unless stated: <parameter>TYPESTATE</parameter> <code>{Name, Namespace}</code> for a service
/// the namespace lists in any letter case, or whose class the namespace holds (<method>Held</method>), else 404
/// <code>PORT.NOTFOUND</code>, not logged;
/// <parameter>TYPESERVICE</parameter> <code>{Name, Namespace, Implementation}</code>, the
/// <parameter>IMPLEMENTATIONSUFFIX</parameter> class a delete keeps (<method>Resolved</method>);
/// <parameter>TYPECREATE</parameter> <code>{Name, Namespace}</code> at the vendor's 201, or 200 where it replaced a
/// service, with a vendor 400 or 404 answered 422 <parameter>OcuPilot.Api.RestServiceError.BUILD</parameter> and not
/// logged; <parameter>TYPEDELETE</parameter> <code>{Name, Namespace}</code>. A delete and a service read refuse 409
/// <parameter>OcuPilot.Api.RestServiceError.DEPLOYED</parameter> for a service a web application of any namespace
/// dispatches to, directly or through <code>Forward</code> routes, and for a name that starts with <code>/</code>.</p>
ClassMethod Service(pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tWrite = (pType = ..#TYPECREATE) || (pType = ..#TYPEDELETE)
        If 'tWrite && (pType '= ..#TYPESTATE) && (pType '= ..#TYPESERVICE) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
        If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        If '$Match(tNamespace, ..#NAMESPACEPATTERN) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACESHAPE, .pHttpStatus, .pFault)
            Quit
        }
        If tWrite {
            Set tPairs = ..WritePairs(tNamespace)
            If tPairs = "" {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
                Quit
            }
            Set tFailedPair = ""
            If '$ClassMethod(..GateClass(), "EvaluateRequired", tPairs, .tFailedPair) {
                Set tDenial = ##class(OcuPilot.Kernel.Denial).Detail(tFailedPair)
                Set tSC = ..Refuse(##class(OcuPilot.Kernel.Denial).#STATUS, ##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason(), .pHttpStatus, .pFault, tDenial)
                Quit
            }
        }

        Set tName = $Get(pQuery(..#APPLICATIONKEY))
        If pType = ..#TYPECREATE {
            Set tSC = ..Build(tNamespace, tName, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If '..ApplicationShapeOk(tName) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONAPPLICATIONSHAPE, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPESTATE {
            Set tSC = ..Listed(tNamespace, tName, 0, .tRow, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) && (pHttpStatus = 404) {
                Set tHeld = ..Held(tNamespace, tName)
                If tHeld '= "" {
                    Set tSC = $$$OK
                    Set pFault = ""
                    Set tRow = {"name": (tHeld)}
                }
            }
            If $$$ISERR(tSC) Quit
            Set pResult = {}
            Do pResult.%Set("Name", tRow.%Get("name"), "string")
            Do pResult.%Set("Namespace", tNamespace, "string")
            Set pHttpStatus = 200
            Quit
        }
        Set tSC = ..Resolved(tNamespace, tName, .tRow, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If pType = ..#TYPESERVICE {
            Set pResult = {}
            Do pResult.%Set("Name", tRow.%Get("name"), "string")
            Do pResult.%Set("Namespace", tNamespace, "string")
            Do pResult.%Set("Implementation", tRow.%Get("name") _ ..#IMPLEMENTATIONSUFFIX, "string")
            Set pHttpStatus = 200
            Quit
        }
        Set tSC = ..Call("DeleteApplication", tNamespace, tName, .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pResult = {}
        Do pResult.%Set("Name", tName, "string")
        Do pResult.%Set("Namespace", tNamespace, "string")
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the service call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The pairs a create or a delete in <var>pNamespace</var> requires beyond <parameter>PAIRS</parameter>:
/// <parameter>WRITEPAIRS</parameter>, then <parameter>WRITEPERMISSION</parameter> on the resource guarding the
/// namespace's routines database; <code>""</code> when that resource cannot be resolved, which the caller refuses
/// rather than admits.</p>
ClassMethod WritePairs(pNamespace As %String) As %List
{
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(pNamespace, .tRoutine, .tGlobal, .tMapped, .tResolved)
    If 'tResolved || (tRoutine = "") Quit ""
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(..#WRITEPAIRS) _ $ListBuild($ListBuild(tRoutine, ..#WRITEPERMISSION))
}

/// <p>The published sentence refusing <var>pName</var> as the package a create builds, or <code>""</code>: it must
/// match <parameter>NAMEPATTERN</parameter> and be at most
/// <parameter>OcuPilot.Api.RestServiceError.NAMEMAX</parameter> characters. Pure.</p>
ClassMethod NameProblem(pName As %String) As %String
{
    If $IsObject(pName) || '$Match(pName, ..#NAMEPATTERN) || ($Length(pName) > ##class(OcuPilot.Api.RestServiceError).#NAMEMAX) Quit ##class(OcuPilot.Api.RestServiceError).#REASONNAME
    Quit ""
}

/// <p>The published sentence refusing the document <var>pBody</var> carries, or <code>""</code>: its
/// <parameter>DOCUMENTFIELD</parameter> must be a parsed JSON object, never a string, whose <code>swagger</code> is
/// the string <code>2.0</code>, and its JSON text at most
/// <parameter>OcuPilot.Api.RestServiceError.DOCUMENTMAX</parameter> characters; a text longer than the instance's
/// longest string is refused, not raised. Pure.</p>
ClassMethod DocumentProblem(pBody As %DynamicAbstractObject) As %String
{
    Set tReason = ##class(OcuPilot.Api.RestServiceError).#REASONDOCUMENT
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit tReason
    If pBody.%GetTypeOf(..#DOCUMENTFIELD) '= "object" Quit tReason
    Set tDocument = pBody.%Get(..#DOCUMENTFIELD)
    If (tDocument.%GetTypeOf("swagger") '= "string") || (tDocument.%Get("swagger") '= "2.0") Quit tReason
    Try {
        Set tLong = ($Length(tDocument.%ToJSON()) > ##class(OcuPilot.Api.RestServiceError).#DOCUMENTMAX)
    } Catch {
        Set tLong = 1
    }
    If tLong Quit tReason
    Quit ""
}

/// <p>Build service <var>pName</var> in <var>pNamespace</var> from the document <var>pBody</var> carries, after the
/// create's rules (<method>NameProblem</method>, <method>DocumentProblem</method>). The vendor is handed a parsed copy
/// of the document, never text: a string would make it fetch a URL or read a server file (AD-21).</p>
ClassMethod Build(pNamespace As %String, pName As %String, pBody As %DynamicAbstractObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If ..NameProblem(pName) '= "" Quit ..Violation(##class(OcuPilot.Api.RestServiceError).#NAME, .pHttpStatus, .pFault)
    If ..DocumentProblem(pBody) '= "" Quit ..Violation(##class(OcuPilot.Api.RestServiceError).#DOCUMENT, .pHttpStatus, .pFault)
    Set tDocument = ##class(%DynamicAbstractObject).%FromJSON(pBody.%Get(..#DOCUMENTFIELD).%ToJSON())
    Set tSC = ..Call("CreateApplication", pNamespace, pName, .tAnswer, .pHttpStatus, .pFault, tDocument)
    If $$$ISERR(tSC) Quit tSC
    Set pResult = {}
    Do pResult.%Set("Name", pName, "string")
    Do pResult.%Set("Namespace", pNamespace, "string")
    Quit $$$OK
}

/// <p>The row of <var>pNamespace</var>'s <code>GetRESTApps</code> whose <code>name</code> is <var>pName</var> --
/// exactly when <var>pExact</var>, else without regard to letter case -- in <var>pRow</var>. A name no row carries is
/// 404 <code>PORT.NOTFOUND</code>, not logged.</p>
ClassMethod Listed(pNamespace As %String, pName As %String, pExact As %Boolean, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set tSC = ..Call("GetRESTApps", pNamespace, "", .tServices, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tWanted = $Select(pExact: pName, 1: $ZConvert(pName, "U"))
    Set tIterator = tServices.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tService) {
        If '$IsObject(tService) || 'tService.%IsA("%Library.DynamicObject") Continue
        If tService.%GetTypeOf("name") '= "string" Continue
        If $Select(pExact: tService.%Get("name"), 1: $ZConvert(tService.%Get("name"), "U")) '= tWanted Continue
        Set pRow = tService
        Quit
    }
    If $IsObject(pRow) Quit $$$OK
    Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ..#REASONUNLISTED, .pHttpStatus, .pFault)
}

/// <p>The package, as the instance spells it, of the class <var>pName</var><parameter>SPECIFICATIONSUFFIX</parameter>
/// or <var>pName</var><parameter>DISPATCHSUFFIX</parameter> that <var>pNamespace</var> holds in any letter case, or
/// <code>""</code>. It reads the class index (<code>^rINDEXCLASS</code>, which follows the namespace's package
/// mappings), as a class create's name check does. The vendor's create rewrites the first and deletes the second, so a
/// create's fresh read counts either as present (AD-54).</p>
ClassMethod Held(pNamespace As %String, pName As %String) As %String [ Private ]
{
    Set tHeld = ""
    For tSuffix = ..#SPECIFICATIONSUFFIX, ..#DISPATCHSUFFIX {
        Set tHeld = $ListGet($Get(^|pNamespace|rINDEXCLASS($ZConvert(pName _ tSuffix, "U"))), 2)
        If tHeld '= "" Quit
    }
    If tHeld = "" Quit ""
    Quit $Piece(tHeld, ".", 1, $Length(tHeld, ".") - 1)
}

/// <p>The listed service a delete or a service read is about, in <var>pRow</var>: a name starting with
/// <code>/</code> is a web application, and a service some web application of any namespace dispatches to is deployed
/// (<method>DeployedAnywhere</method>); both are 409 <parameter>OcuPilot.Api.RestServiceError.DEPLOYED</parameter>,
/// before the service list is read. Any other name must be listed exactly (<method>Listed</method>).</p>
ClassMethod Resolved(pNamespace As %String, pName As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If $Extract(pName) = "/" Quit ..Deployed(.pHttpStatus, .pFault)
    Set tSC = ..DeployedAnywhere(pNamespace, pName, .tDeployed, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If tDeployed Quit ..Deployed(.pHttpStatus, .pFault)
    Quit ..Listed(pNamespace, pName, 1, .pRow, .pHttpStatus, .pFault)
}

/// <p>The namespace names the instance reports, in <var>pList</var> as a <class>%List</class>, implicit ones included.
/// Overridable so a test can supply a roster; production never overrides it.</p>
ClassMethod Namespaces(Output pList As %List) As %Status
{
    Quit ##class(OcuPilot.Kernel.Shell.Namespaces).NamespaceNames(.pList)
}

/// <p>Whether a web application of <var>pNamespace</var> or of any other namespace dispatches to the service
/// <var>pName</var>, in <var>pDeployed</var>: its dispatch class is <var>pName</var><parameter>DISPATCHSUFFIX</parameter>
/// in any letter case, or its compiled <code>UrlMap</code> forwards there, through up to
/// <parameter>FORWARDDEPTH</parameter> hops (<method>ReachesDispatch</method>). The web applications of
/// <var>pNamespace</var> are read first, then each other namespace in the instance's order; an implicit namespace
/// (<parameter>OcuPilot.Kernel.Shell.Namespaces.IMPLICITPREFIX</parameter>) is skipped. A namespace the vendor refuses
/// to enter for the caller refuses the whole question, so a service is never called undeployed on a partial read; when
/// it is not <var>pNamespace</var>, the refusal names it (<parameter>REASONNAMESPACEOTHER</parameter>).</p>
ClassMethod DeployedAnywhere(pNamespace As %String, pName As %String, Output pDeployed As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pDeployed = 0
    Set tSC = ..Namespaces(.tList)
    If $$$ISERR(tSC) Quit ..Fail("the namespace list could not be read", tSC, .pHttpStatus, .pFault)
    Set tImplicit = ##class(OcuPilot.Kernel.Shell.Namespaces).#IMPLICITPREFIX
    Set tOrder = $ListBuild(pNamespace)
    For tI = 1:1:$ListLength(tList) {
        Set tOne = $List(tList, tI)
        If ($Extract(tOne) = tImplicit) || ($ZConvert(tOne, "U") = $ZConvert(pNamespace, "U")) Continue
        Set tOrder = tOrder _ $ListBuild(tOne)
    }
    Set tDispatch = $ZConvert(pName _ ..#DISPATCHSUFFIX, "U")
    Kill tVisited
    For tN = 1:1:$ListLength(tOrder) {
        Set tNamespace = $List(tOrder, tN)
        Set tSC = ..Call("GetWebRESTApps", tNamespace, "", .tWeb, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) && (tN > 1) && (+$Get(pHttpStatus) = 403) {
            Set tSC = ..Refuse(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED, $Replace(..#REASONNAMESPACEOTHER, "<namespace>", tNamespace), .pHttpStatus, .pFault)
        }
        If $$$ISERR(tSC) Quit
        Set tIterator = tWeb.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tApp) {
            If '$IsObject(tApp) || 'tApp.%IsA("%Library.DynamicObject") Continue
            If tApp.%GetTypeOf("dispatchClass") '= "string" Continue
            Set tClass = tApp.%Get("dispatchClass")
            If $ZConvert(tClass, "U") = tDispatch {
                Set pDeployed = 1
                Quit
            }
            Set tSC = ..ReachesDispatch(tNamespace, tClass, tDispatch, 1, .tVisited, .tReached, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            If tReached {
                Set pDeployed = 1
                Quit
            }
        }
        If $$$ISERR(tSC) || pDeployed Quit
    }
    Quit tSC
}

/// <p>Whether the compiled <code>UrlMap</code> of <var>pClass</var>, read in <var>pNamespace</var>, forwards to the
/// upper-cased class <var>pDispatch</var>, directly or through the <code>Forward</code> routes of the classes it
/// forwards to, in <var>pReached</var>. <var>pDepth</var> is the hop being read; a hop past
/// <parameter>FORWARDDEPTH</parameter> and a class already read in <var>pNamespace</var> (<var>pVisited</var>, kept
/// across the calls of one question) forward nowhere, so a cycle ends.</p>
ClassMethod ReachesDispatch(pNamespace As %String, pClass As %String, pDispatch As %String, pDepth As %Integer, ByRef pVisited, Output pReached As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pReached = 0
    If (pClass = "") || (pDepth > ..#FORWARDDEPTH) Quit $$$OK
    Set tKey = $ZConvert(pNamespace, "U") _ $Char(1) _ $ZConvert(pClass, "U")
    If $Data(pVisited(tKey)) Quit $$$OK
    Set pVisited(tKey) = ""
    Set tSC = ..Forwards(pNamespace, pClass, .tTargets)
    If $$$ISERR(tSC) Quit ..Fail("the dispatch map of " _ pClass _ " could not be read", tSC, .pHttpStatus, .pFault)
    For tI = 1:1:$ListLength(tTargets) {
        Set tTarget = $List(tTargets, tI)
        If $ZConvert(tTarget, "U") = pDispatch {
            Set pReached = 1
            Quit
        }
        Set tSC = ..ReachesDispatch(pNamespace, tTarget, pDispatch, pDepth + 1, .pVisited, .pReached, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) || pReached Quit
    }
    Quit tSC
}

/// <p>The classes the compiled <code>UrlMap</code> of <var>pClass</var>, read in <var>pNamespace</var> (AD-16),
/// forwards to, in <var>pTargets</var> as a <class>%List</class>: the <code>Forward</code> attribute of each
/// <code>Map</code> element, as written, in either XML quote and with or without space around its <code>=</code>. A
/// class with no <code>UrlMap</code>, and one the namespace does not hold, forward nowhere. The compiled map includes
/// the one a class inherits.</p>
ClassMethod Forwards(pNamespace As %String, pClass As %String, Output pTargets As %List) As %Status [ Private ]
{
    Set pTargets = ""
    Set tSC = $$$OK
    Set tMap = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tXData = ##class(%Dictionary.CompiledXData).%OpenId(pClass _ "||UrlMap")
        If $IsObject(tXData) {
            Do tXData.Data.Rewind()
            While 'tXData.Data.AtEnd {
                Set tMap = tMap _ tXData.Data.Read(32000)
            }
        }
        Set tXData = ""
        Set $NAMESPACE = tOrigNS
        Set tStart = 1
        While $Locate(tMap, "<Map\s[^>]*>", tStart, tEnd, tElement) {
            Set tStart = tEnd
            If '$Locate(tElement, "\sForward\s*=\s*(""[^""]*""|'[^']*')", 1, , tAttribute) Continue
            Set tTarget = $Extract($ZStrip($Piece(tAttribute, "=", 2, *), "<W"), 2, *-1)
            If tTarget '= "" Set pTargets = pTargets _ $ListBuild(tTarget)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pTargets = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
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
/// <code>""</code>, <var>pName</var> and then <var>pDocument</var>, and answer its value as <var>pAnswer</var>.</p>
/// <p>The call runs behind <code>New</code>ed <code>%request</code>, <code>%response</code> and
/// <code>%session</code>, with fresh request and response stubs and the device captured, so neither
/// the caller's CSP objects nor its response device is read or written. A 2xx status carrying the
/// value the method answers on success -- an array from a list method, an object from a document
/// method, or the message object a write method answers -- is success; every other outcome is an error status built by
/// <method>Outcome</method>.</p>
ClassMethod Call(pMethod As %String, pNamespace As %String, pName As %String, Output pAnswer, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDocument As %DynamicObject = "") As %Status [ Private ]
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
            } ElseIf $IsObject(pDocument) {
                Set tAnswer = $ClassMethod(..ImplClass(), pMethod, pNamespace, pName, pDocument)
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
/// object from a document method or a write method, is success. A 403 is the vendor's refused namespace
/// switch. A 404 from <code>GetApplication</code> or <code>GetWebRESTApplication</code> is that method's own
/// refusal, and a 400 from either is a document the vendor could not build. A 400 or 404 from
/// <code>CreateApplication</code> is a document it could not build too, answered 422
/// <parameter>OcuPilot.Api.RestServiceError.BUILD</parameter> and not logged. Anything else is an internal
/// failure. The vendor's own status and captured output are logged on every other error path and never put on the
/// wire.</p>
ClassMethod Outcome(pMethod As %String, pCallSC As %Status, pAnswer, pHttp As %Integer, pCaptured As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDocumentMethod = (pMethod = "GetApplication") || (pMethod = "GetWebRESTApplication")
    Set tBuildMethod = (pMethod = "CreateApplication")
    Set tWanted = $Select(tDocumentMethod || tBuildMethod || (pMethod = "DeleteApplication"): "%Library.DynamicObject", 1: "%Library.DynamicArray")
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
    } ElseIf tBuildMethod && ((pHttp = 400) || (pHttp = 404)) {
        Quit ..Violation(##class(OcuPilot.Api.RestServiceError).#BUILD, .pHttpStatus, .pFault)
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

/// <p>The 422 refusal <var>pCode</var> on its field: the envelope carries the code and its sentence, and
/// <code>detail.violations</code> the one violation (AD-39).</p>
ClassMethod Violation(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tReason = ##class(OcuPilot.Api.RestServiceError).ReasonFor(pCode)
    Set tViolation = {}
    Do tViolation.%Set("field", ##class(OcuPilot.Api.RestServiceError).FieldOf(pCode), "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", tReason, "string")
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push(tViolation)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pCode, tReason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The 409 refusal <parameter>OcuPilot.Api.RestServiceError.DEPLOYED</parameter>: nothing is sent.</p>
ClassMethod Deployed(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.RestServiceError).#DEPLOYED, ##class(OcuPilot.Api.RestServiceError).#REASONDEPLOYED, .pHttpStatus, .pFault)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p><code>rest</code> for <parameter>TYPECREATE</parameter> and <parameter>TYPEDELETE</parameter> on
/// <parameter>ENDPOINTSERVICE</parameter>, the two writes this port carries; <code>""</code> for every read, which
/// has no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If pEndpoint '= ..#ENDPOINTSERVICE Quit ""
    If (pType = ..#TYPECREATE) || (pType = ..#TYPEDELETE) Quit "rest"
    Quit ""
}

/// <p><method>Service</method>'s write branches as one <code>curl</code> step on
/// <parameter>SPECPREFIX</parameter><code>&lt;namespace&gt;/&lt;name&gt;</code> (AD-59): a create posts the document
/// the body carries, a delete sends no body. Every value is shell-quoted, so nothing the query carries runs as code. A
/// read, and a body carrying no document, answer no step.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tOrigin = ""
    Set tUser = ""
    If $IsObject(pContext) {
        Set tOrigin = pContext.%Get("origin")
        Set tUser = pContext.%Get("user")
    }
    Set tUrl = tOrigin _ ..#SPECPREFIX _ $ZConvert($Get(pQuery(..#NAMESPACEKEY)), "O", "URL") _ "/" _ $ZConvert($Get(pQuery(..#APPLICATIONKEY)), "O", "URL")
    Set tBreak = " \" _ $Char(10) _ "  "
    Set tText = "curl -u " _ ##class(OcuPilot.Port.AdminPort).ShellQuoted(tUser) _ " -X " _ pType _ " " _ ##class(OcuPilot.Port.AdminPort).ShellQuoted(tUrl)
    If pType = ..#TYPECREATE {
        If '$IsObject(pBody) || (pBody.%GetTypeOf(..#DOCUMENTFIELD) '= "object") Quit []
        Set tText = tText _ tBreak _ "-H " _ ##class(OcuPilot.Port.AdminPort).ShellQuoted("Content-Type: application/json") _ tBreak _ "-d " _ ##class(OcuPilot.Port.AdminPort).ShellQuoted(pBody.%Get(..#DOCUMENTFIELD).%ToJSON())
    }
    Quit [(##class(OcuPilot.Port.AdminPort).Step("rest", tText))]
}

}
