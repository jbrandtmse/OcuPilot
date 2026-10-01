/// <p>The port to the instance's source-code API, the route methods behind
/// <code>/api/atelier</code> (AD-61). <b>This is the only product class that names an
/// <code>%Api.Atelier.*</code> class</b>, and it names them only through
/// <parameter>DISPATCHCLASS</parameter> and <parameter>VERSIONCLASSPREFIX</parameter>. The route
/// methods are called in the caller's process, as the signed-in user, one route at a time; nothing
/// here issues an HTTP request.</p>
/// <p><method>Invoke</method> is the one way in. It serves four read endpoints of request type
/// <parameter>REQUESTTYPE</parameter>: <parameter>ENDPOINTCLASSES</parameter> and
/// <parameter>ENDPOINTROUTINES</parameter>, a namespace's classes and routines as rows, and
/// <parameter>ENDPOINTCLASS</parameter> and <parameter>ENDPOINTROUTINE</parameter>, one document's
/// structure as rows with its text beside them.</p>
/// <p><b>The order of every call is fixed</b> (AD-61): the gate, in the caller's process
/// (<parameter>PAIRS</parameter>, then READ on the target namespace's routines and globals
/// databases and on every other database it maps code from, resolved at call time); the endpoint;
/// the version; the arguments; and only then the vendor routes, each behind fresh
/// <code>%request</code>/<code>%response</code> stubs with its output captured (the index route's
/// through a temporary file) and the namespace switched by explicit save and restore around the
/// route call alone. A route's outcome is read from its status, <code>%response.Status</code>, the envelope's
/// <code>status.errors</code> and the result's own <code>status</code>.</p>
/// <p><b>Every list filter is applied here, to the parsed rows, before the cap</b> (AD-21, AD-36).
/// The <code>docnames</code> route's own <code>filter</code> parameter is never sent, and
/// <code>POST modified</code> is never called.</p>
/// <p><b>Every refusal is a written reason</b> (AD-39). Vendor text and captured output go to
/// <method>OcuPilot.Kernel.Fault.LogRaw</method> and nowhere else, and a read answered 404 is not
/// logged (AD-2).</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>ImplClass</method>,
/// <method>HighestVersion</method>, <method>DatabaseResources</method> and <method>LogFault</method>.
/// Production overrides none of them.</p>
Class OcuPilot.Port.AtelierPort Extends %RegisteredObject
{

/// <p>The vendor class whose URL map names the version classes.</p>
Parameter DISPATCHCLASS = "%Api.Atelier";

/// <p>The vendor's version classes, completed by a version number.</p>
Parameter VERSIONCLASSPREFIX = "%Api.Atelier.v";

/// <p>The highest version this port calls, whatever higher one an instance offers.</p>
Parameter PINNEDVERSION As INTEGER = 8;

/// <p>The lowest version each route this port calls needs, as <code>method:version</code>.</p>
Parameter MINVERSIONS = "GetNamespace:1,GetDocNames:1,Index:1,GetDoc:2";

/// <p>The pair set every call requires whatever its namespace, comma-separated as
/// <code>resource:permission</code>, in the order the gate reports in (AD-8, AD-29). READ on the
/// target namespace's routines and globals databases is added at call time
/// (<method>NamespacePairs</method>).</p>
Parameter PAIRS = "%Development:USE";

/// <p>The class the pair set is evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The request stub a route that reads a JSON body is handed.</p>
Parameter REQUESTCLASS = "OcuPilot.Port.AtelierRequest";

/// <p>The endpoint answering a namespace's classes.</p>
Parameter ENDPOINTCLASSES = "Classes";

/// <p>The endpoint answering a namespace's routines and include files.</p>
Parameter ENDPOINTROUTINES = "Routines";

/// <p>The endpoint answering one class's structure and text.</p>
Parameter ENDPOINTCLASS = "Class";

/// <p>The endpoint answering one routine's structure and text.</p>
Parameter ENDPOINTROUTINE = "Routine";

/// <p>The one request type every endpoint serves.</p>
Parameter REQUESTTYPE = "LIST";

/// <p>The query key carrying the namespace the read runs in.</p>
Parameter NAMESPACEKEY = "namespace";

/// <p>The query key carrying the row cap.</p>
Parameter MAXROWSKEY = "maxRows";

/// <p>The query key carrying a list's name pattern.</p>
Parameter PATTERNKEY = "pattern";

/// <p>The query key choosing whether a list keeps <code>%</code> names.</p>
Parameter SYSTEMKEY = "system";

/// <p>The query key choosing whether a list keeps generated documents.</p>
Parameter GENERATEDKEY = "generated";

/// <p>The query key choosing whether a list keeps documents another database maps in.</p>
Parameter MAPPEDKEY = "mapped";

/// <p>The query key carrying a list's earliest modified time.</p>
Parameter FROMKEY = "from";

/// <p>The query key carrying a list's latest modified time.</p>
Parameter TOKEY = "to";

/// <p>The query key carrying a document's name.</p>
Parameter NAMEKEY = "name";

/// <p>The query key choosing a document's form.</p>
Parameter FORMKEY = "form";

/// <p>The forms a document read answers, comma-separated.</p>
Parameter FORMS = "udl,xml,int";

/// <p>The shape a namespace name must take.</p>
Parameter NAMESPACEPATTERN = "^%?[A-Za-z0-9][A-Za-z0-9_-]*$";

/// <p>The shape a class document's name must take.</p>
Parameter CLASSNAMEPATTERN = "^%?[A-Za-z][A-Za-z0-9]*(\.%?[A-Za-z][A-Za-z0-9]*)*\.cls$";

/// <p>The shape a routine document's name must take.</p>
Parameter ROUTINENAMEPATTERN = "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z0-9]+)*\.(mac|int|inc|bas|mvi|mvb)$";

/// <p>The shape one comma-separated piece of a name pattern must take.</p>
Parameter PATTERNPIECE = "^'?[A-Za-z0-9%.*]+$";

/// <p>The routine types a pattern piece's last segment names, comma-separated.</p>
Parameter ROUTINETYPES = "mac,int,inc,bas,mvi,mvb";

/// <p>The shape a modified-time bound must take: the instance's own local time.</p>
Parameter DATETIMEPATTERN = "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?$";

/// <p>The longest string the capture can hold in one line, and so the largest answer one route can
/// give: the instance's maximum string length.</p>
Parameter CAPTURECEILING As INTEGER = 3641144;

/// <p>The vendor's message number for a document it does not hold.</p>
Parameter NODOCUMENTCODE = 16005;

/// <p>The routes whose answer is written to a temporary file rather than captured: the index route
/// builds its documents while it writes the device, and a process whose output is redirected
/// through the capture while it does so can end abnormally (measured on the instance).</p>
Parameter FILEDEVICEROUTES = "Index";

/// <p>How long opening that temporary file may wait, in seconds.</p>
Parameter FILEOPENSECONDS As INTEGER = 5;

/// <p>The subsystem raw vendor text is logged under.</p>
Parameter LOGSUBSYSTEM = "atelierport";

/// <p>The reason a request the port does not serve is refused with.</p>
Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

/// <p>The reason an instance whose API is too old is refused with; <code>{highest}</code> and
/// <code>{needed}</code> are the two versions.</p>
Parameter REASONVERSION = "This instance's source code API answers version {highest}, and this read needs version {needed} or later.";

/// <p>The reason a missing or malformed namespace is refused with.</p>
Parameter REASONNAMESPACESHAPE = "Name the namespace the read runs in.";

/// <p>The reason a namespace whose code databases' resources cannot be resolved is refused
/// with.</p>
Parameter REASONNAMESPACEUNKNOWN = "This instance cannot name the databases that namespace reads code from.";

/// <p>The reason a malformed row cap is refused with.</p>
Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

/// <p>The reason a malformed name pattern is refused with.</p>
Parameter REASONPATTERN = "pattern must be a comma-separated list of names made of letters, digits, %, . and *, each optionally preceded by ' to exclude it.";

/// <p>The reason a malformed include choice is refused with.</p>
Parameter REASONCHOICE = "system, generated and mapped must each be yes or no.";

/// <p>The reason a malformed modified-time bound is refused with.</p>
Parameter REASONDATETIME = "from and to must each be a date and time, as YYYY-MM-DD HH:MM:SS.";

/// <p>The reason a missing or malformed class name is refused with.</p>
Parameter REASONCLASSNAME = "Name one class, as Package.Name.cls.";

/// <p>The reason a missing or malformed routine name is refused with.</p>
Parameter REASONROUTINENAME = "Name one routine or include file, as Name.mac, .int, .inc, .bas, .mvi or .mvb.";

/// <p>The reason a malformed form is refused with.</p>
Parameter REASONFORM = "form must be udl, xml or int.";

/// <p>The reason a document the namespace does not hold is refused with.</p>
Parameter REASONNOTFOUND = "This namespace holds no document by that name.";

/// <p>The reason a vendor 400 is refused with.</p>
Parameter REASONVALIDATION = "The source code API refused one of the values supplied.";

/// <p>The reason the vendor's own privilege refusal is answered with.</p>
Parameter REASONACCESSDENIED = "The source code API refused this read for this account.";

/// <p>The reason an answer above <parameter>CAPTURECEILING</parameter> is refused with.</p>
Parameter REASONTOOLARGE = "The answer is too large to read in one call; narrow the name pattern.";

/// <p>The class the pair set is evaluated through. Overridable so a fixture can drive a denial in
/// process; production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>The vendor class <var>pVersion</var>'s routes are called on. Overridable so a fixture can
/// answer what the live instance cannot produce on demand; production never overrides it.</p>
ClassMethod ImplClass(pVersion As %Integer) As %String
{
    Quit ..#VERSIONCLASSPREFIX _ pVersion
}

/// <p>The highest version <parameter>DISPATCHCLASS</parameter>'s URL map forwards to, or 0 when
/// the map cannot be read. Overridable so a fixture can stand in for an older instance; production
/// never overrides it.</p>
ClassMethod HighestVersion() As %Integer
{
    Set tVersion = 0
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(..#DISPATCHCLASS, "UrlMap", , .tSC)
        If '$IsObject(tXData) Quit
        Set tMarker = "Forward=""" _ ..#VERSIONCLASSPREFIX
        Do tXData.Data.Rewind()
        While 'tXData.Data.AtEnd {
            Set tLine = tXData.Data.ReadLine()
            If tLine '[ tMarker Continue
            Set tFound = +$Piece(tLine, tMarker, 2)
            If tFound > tVersion Set tVersion = tFound
        }
    } Catch {
        Set tVersion = 0
    }
    Quit tVersion
}

/// <p>The resources guarding <var>pNamespace</var>'s routines and globals databases, as
/// <method>%SYS.Namespace.GetAllNSInfo</method> reports them, and, as <var>pMapped</var>, the
/// resource of every other database the namespace maps classes or routines from, except the
/// instance's system database (the manager directory's), whose code index the routes read without
/// its resource. The mapped databases are the ones the source code API's own namespace route
/// lists (<code>findmappings^%R</code>), each resolved through its implied namespace.
/// <var>pResolved</var> is 0, and the caller refuses, when the routines database or any mapped
/// database reports no resource. Overridable so a fixture can name others; production never
/// overrides it.</p>
ClassMethod DatabaseResources(pNamespace As %String, Output pRoutineResource As %String, Output pGlobalResource As %String, Output pMapped As %List, Output pResolved As %Boolean)
{
    Set pRoutineResource = ""
    Set pGlobalResource = ""
    Set pMapped = ""
    Set pResolved = 0
    Try {
        Kill tInfo
        Do ##class(%SYS.Namespace).GetAllNSInfo(pNamespace, .tInfo, 1)
        Set pRoutineResource = $Get(tInfo("RoutineDB", "Resource"))
        Set pGlobalResource = $Get(tInfo("GlobalDB", "Resource"))
        Set tSystemDirectory = "^^" _ $System.Util.ManagerDirectory()
        Kill tDirectories
        Do findmappings^%R(pNamespace, .tDirectories)
        Set tDirectory = ""
        For {
            Set tDirectory = $Order(tDirectories(tDirectory))
            If tDirectory = "" Quit
            If tDirectory = tSystemDirectory Continue
            Kill tMappedInfo
            Do ##class(%SYS.Namespace).GetAllNSInfo(tDirectory, .tMappedInfo, 1)
            Set tResource = $Get(tMappedInfo("RoutineDB", "Resource"))
            If tResource = "" Quit
            If '$ListFind(pMapped, tResource) Set pMapped = pMapped _ $ListBuild(tResource)
        }
        Set pResolved = (pRoutineResource '= "") && (tDirectory = "")
    } Catch {
        Set pRoutineResource = ""
        Set pGlobalResource = ""
        Set pMapped = ""
        Set pResolved = 0
    }
}

/// <p><parameter>PAIRS</parameter> as the <code>%List</code> of two-element <code>%List</code>s the
/// gate evaluates.</p>
ClassMethod Pairs() As %List
{
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(..#PAIRS)
}

/// <p>READ on <var>pNamespace</var>'s routines database, on its globals database where that is
/// another one, and on every database it maps classes or routines from but the system database
/// (<method>DatabaseResources</method>), as the gate's <code>%List</code> of pairs in that order;
/// <code>""</code> when any of those resources cannot be resolved, which the caller refuses rather
/// than admits. Entering a namespace needs READ on its globals database, and a
/// list read answers 200 with no rows when a mapped code database cannot be read.</p>
ClassMethod NamespacePairs(pNamespace As %String) As %List
{
    Do ..DatabaseResources(pNamespace, .tRoutine, .tGlobal, .tMapped, .tResolved)
    If 'tResolved Quit ""
    Set tResources = $ListBuild(tRoutine)
    If (tGlobal '= "") && '$ListFind(tResources, tGlobal) Set tResources = tResources _ $ListBuild(tGlobal)
    For tI = 1:1:$ListLength(tMapped) {
        Set tResource = $List(tMapped, tI)
        If '$ListFind(tResources, tResource) Set tResources = tResources _ $ListBuild(tResource)
    }
    Set tPairs = ""
    For tI = 1:1:$ListLength(tResources) {
        Set tPairs = tPairs _ $ListBuild($ListBuild($List(tResources, tI), "READ"))
    }
    Quit tPairs
}

/// <p>The lowest version <var>pEndpoint</var>'s routes need: the highest of its routes'
/// <parameter>MINVERSIONS</parameter>.</p>
ClassMethod MinVersion(pEndpoint As %String) As %Integer
{
    Set tRoutes = $Select((pEndpoint = ..#ENDPOINTCLASS) || (pEndpoint = ..#ENDPOINTROUTINE): $ListBuild("Index", "GetDoc"), 1: $ListBuild("GetNamespace", "GetDocNames"))
    Set tNeeded = 1
    For tI = 1:1:$ListLength(tRoutes) {
        Set tRoute = $List(tRoutes, tI)
        For tJ = 1:1:$Length(..#MINVERSIONS, ",") {
            Set tEntry = $Piece(..#MINVERSIONS, ",", tJ)
            If $Piece(tEntry, ":", 1) '= tRoute Continue
            If +$Piece(tEntry, ":", 2) > tNeeded Set tNeeded = +$Piece(tEntry, ":", 2)
        }
    }
    Quit tNeeded
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var>.</p>
/// <p><var>pQuery</var> carries <code>namespace</code> (required) and <code>maxRows</code>
/// (optional, a whole number above zero that bounds the rows). A list endpoint also reads
/// <code>pattern</code>, <code>system</code>, <code>generated</code>, <code>mapped</code>,
/// <code>from</code> and <code>to</code>, each optional (<method>ListRows</method>); a document
/// endpoint reads <code>name</code> (required) and <code>form</code> (<code>udl</code> when absent).
/// <var>pBody</var> is not read.</p>
/// <p>On success <var>pResult</var> is a <class>%DynamicArray</class> of rows and
/// <var>pHttpStatus</var> is 200. A list row is <code>{Name, Modified, Database, Generated}</code>;
/// a document endpoint answers <method>DocumentRows</method>'s rows and <var>pDocument</var>
/// <code>{name, form, available, content, modified, database, generates}</code>, which the row cap
/// never cuts.</p>
/// <p>Otherwise an error status is returned with <var>pResult</var> and <var>pDocument</var> empty,
/// <var>pHttpStatus</var> the status to answer with and <var>pFault</var> the wire fault: 403
/// <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>, before any vendor call; 501
/// <code>PORT.NOTIMPLEMENTED</code> for an endpoint not served or an instance whose version is too
/// old; 400 <code>PORT.VALIDATION</code> for a malformed argument or a value the vendor refused;
/// 404 <code>PORT.NOTFOUND</code>; 403 <code>PORT.ACCESSDENIED</code> for the vendor's own
/// privilege refusal; 503 <code>PORT.UNAVAILABLE</code> for an answer above
/// <parameter>CAPTURECEILING</parameter>; and 500 <code>INTERNAL</code> for anything else.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace,
/// <code>%request</code>, <code>%response</code>, <code>%session</code> and
/// <code>%SourceControl</code> are unchanged on return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pDocument As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pDocument = ""
    Try {
        Set tFailedPair = ""
        ; EvaluateRequired, not EvaluatePairs: a PAIRS parameter mis-edited to empty fails closed.
        If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(), .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
        If '$Match(tNamespace, ..#NAMESPACEPATTERN) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACESHAPE, .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespacePairs = ..NamespacePairs(tNamespace)
        If tNamespacePairs = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
            Quit
        }
        If '$ClassMethod(..GateClass(), "EvaluateRequired", tNamespacePairs, .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }

        Set tList = (pEndpoint = ..#ENDPOINTCLASSES) || (pEndpoint = ..#ENDPOINTROUTINES)
        Set tOne = (pEndpoint = ..#ENDPOINTCLASS) || (pEndpoint = ..#ENDPOINTROUTINE)
        If (pType '= ..#REQUESTTYPE) || ('tList && 'tOne) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tNeeded = ..MinVersion(pEndpoint)
        Set tHighest = +..HighestVersion()
        If tHighest < tNeeded {
            Set tReason = $Replace($Replace(..#REASONVERSION, "{highest}", tHighest), "{needed}", tNeeded)
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, tReason, .pHttpStatus, .pFault)
            Quit
        }
        Set tVersion = $Select(tHighest > ..#PINNEDVERSION: ..#PINNEDVERSION, 1: tHighest)

        Set tMax = $Get(pQuery(..#MAXROWSKEY))
        If (tMax '= "") && '$Match(tMax, "^[1-9][0-9]*$") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
            Quit
        }
        If tList {
            Set tSC = ..ListRows(tVersion, tNamespace, pEndpoint, .pQuery, +tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Document(tVersion, tNamespace, pEndpoint, .pQuery, +tMax, .pResult, .pDocument, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set pDocument = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The rows of a list endpoint, at most <var>pMax</var> of them when it is above zero, every
/// filter applied before the cut:</p>
/// <ul>
/// <li><code>pattern</code>: comma-separated pieces matched case-sensitively, <code>*</code> the one
/// wildcard; a row is kept when it matches any piece that does not begin with <code>'</code> (or
/// when there is none) and no piece that does (<method>PatternMatches</method>).</li>
/// <li><code>system</code> <code>no</code> drops names starting with <code>%</code>.</li>
/// <li><code>generated</code> <code>yes</code> asks the vendor for generated documents too.</li>
/// <li><code>mapped</code> <code>no</code> drops rows held by any database but the namespace's
/// routines database.</li>
/// <li><code>from</code> and <code>to</code> drop rows modified outside the bounds, compared as the
/// instance's own local time text.</li>
/// </ul>
/// <p>An absent or empty criterion applies no filter of its own.</p>
ClassMethod ListRows(pVersion As %Integer, pNamespace As %String, pEndpoint As %String, ByRef pQuery, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = ""
    Try {
        Set tCategory = $Select(pEndpoint = ..#ENDPOINTCLASSES: "CLS", 1: "RTN")
        Set tPattern = $Get(pQuery(..#PATTERNKEY))
        If (tPattern '= "") && '..PatternShapeOk(tPattern) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONPATTERN, .pHttpStatus, .pFault)
            Quit
        }
        Set tSystem = $Get(pQuery(..#SYSTEMKEY))
        Set tGenerated = $Get(pQuery(..#GENERATEDKEY))
        Set tMapped = $Get(pQuery(..#MAPPEDKEY))
        Set tChoicesOk = 1
        For tChoice = tSystem, tGenerated, tMapped {
            If (tChoice '= "") && (tChoice '= "yes") && (tChoice '= "no") Set tChoicesOk = 0
        }
        If 'tChoicesOk {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONCHOICE, .pHttpStatus, .pFault)
            Quit
        }
        Set tFrom = $Get(pQuery(..#FROMKEY))
        Set tTo = $Get(pQuery(..#TOKEY))
        If ((tFrom '= "") && '$Match(tFrom, ..#DATETIMEPATTERN)) || ((tTo '= "") && '$Match(tTo, ..#DATETIMEPATTERN)) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONDATETIME, .pHttpStatus, .pFault)
            Quit
        }

        Set tDefaultDb = ""
        If tMapped = "no" {
            Kill tNoParams
            Set tSC = ..Route(pVersion, pNamespace, "GetNamespace", "", .tNoParams, "", .tSpace, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            Set tDefaultDb = ..DefaultDatabase(tSpace)
            If tDefaultDb = "" {
                Set tSC = ..Fail("GetNamespace named no default database", $$$ERROR($$$GeneralError, "no db entry with default true for " _ pNamespace), .pHttpStatus, .pFault)
                Quit
            }
        }

        Kill tParams
        If tGenerated = "yes" Set tParams("generated") = 1
        Set tSC = ..Route(pVersion, pNamespace, "GetDocNames", tCategory, .tParams, "", .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tContent = $Select($IsObject(tAnswer): tAnswer.%Get("content"), 1: "")
        If '$IsObject(tContent) || 'tContent.%IsA("%Library.DynamicArray") {
            Set tSC = ..Fail("GetDocNames answered no content array", $$$ERROR($$$GeneralError, "docnames answered no content array"), .pHttpStatus, .pFault)
            Quit
        }

        Set tRows = []
        Set tIterator = tContent.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tDoc) {
            If (pMax > 0) && (tRows.%Size() = pMax) Quit
            If '$IsObject(tDoc) || 'tDoc.%IsA("%Library.DynamicObject") Continue
            Set tName = tDoc.%Get("name")
            If tName = "" Continue
            If (tSystem = "no") && ($Extract(tName) = "%") Continue
            If (tDefaultDb '= "") && (tDoc.%Get("db") '= tDefaultDb) Continue
            Set tStamp = tDoc.%Get("ts")
            If (tFrom '= "") && ((tStamp = "") || (tFrom ] tStamp)) Continue
            If (tTo '= "") && ((tStamp = "") || ($Extract(tStamp, 1, $Length(tTo)) ] tTo)) Continue
            If (tPattern '= "") && '..PatternMatches(tName, tCategory, tPattern) Continue
            Set tRow = {}
            Do tRow.%Set("Name", tName)
            Do tRow.%Set("Modified", tStamp)
            Do tRow.%Set("Database", tDoc.%Get("db"))
            Do tRow.%Set("Generated", ''tDoc.%Get("gen"), "boolean")
            Do tRows.%Push(tRow)
        }
        Set pRows = tRows
        Set pHttpStatus = 200
    } Catch ex {
        Set pRows = ""
        Set tSC = ..Fail("the list read failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The name of the database a <code>GetNamespace</code> answer marks <code>default</code>: the
/// namespace's routines database. <code>""</code> when none is marked.</p>
ClassMethod DefaultDatabase(pAnswer) As %String [ Private ]
{
    Set tName = ""
    If '$IsObject(pAnswer) Quit ""
    Set tContent = pAnswer.%Get("content")
    If '$IsObject(tContent) Quit ""
    Set tDatabases = tContent.%Get("db")
    If '$IsObject(tDatabases) || 'tDatabases.%IsA("%Library.DynamicArray") Quit ""
    Set tIterator = tDatabases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tDb) {
        If '$IsObject(tDb) Continue
        If (tDb.%GetTypeOf("default") = "boolean") && tDb.%Get("default") {
            Set tName = tDb.%Get("name")
            Quit
        }
    }
    Quit tName
}

/// <p>Whether <var>pPattern</var> is a comma-separated list of pieces each matching
/// <parameter>PATTERNPIECE</parameter>, with no empty piece.</p>
ClassMethod PatternShapeOk(pPattern As %String) As %Boolean
{
    If pPattern = "" Quit 0
    Set tOk = 1
    For tI = 1:1:$Length(pPattern, ",") {
        If '$Match($Piece(pPattern, ",", tI), ..#PATTERNPIECE) {
            Set tOk = 0
            Quit
        }
    }
    Quit tOk
}

/// <p>Whether document <var>pName</var> of category <var>pCategory</var> (<code>CLS</code> or
/// <code>RTN</code>) matches <var>pPattern</var>: at least one including piece, or none declared,
/// and no excluding piece (<method>PieceMatches</method>).</p>
ClassMethod PatternMatches(pName As %String, pCategory As %String, pPattern As %String) As %Boolean
{
    Set tIncluded = 0
    Set tIncludes = 0
    Set tExcluded = 0
    For tI = 1:1:$Length(pPattern, ",") {
        Set tPiece = $Piece(pPattern, ",", tI)
        If tPiece = "" Continue
        If $Extract(tPiece) = "'" {
            If ..PieceMatches(pName, pCategory, $Extract(tPiece, 2, *)) Set tExcluded = 1
            Continue
        }
        Set tIncludes = tIncludes + 1
        If ..PieceMatches(pName, pCategory, tPiece) Set tIncluded = 1
    }
    If tExcluded Quit 0
    Quit tIncluded || (tIncludes = 0)
}

/// <p>Whether one pattern piece matches. A class is matched without its <code>.cls</code>, and a
/// piece's own <code>.cls</code> is ignored. A routine piece whose last segment is a routine type
/// matches that type alone; any other routine piece matches every type, against the name without
/// its type or with it.</p>
ClassMethod PieceMatches(pName As %String, pCategory As %String, pPiece As %String) As %Boolean
{
    Set tBase = $Piece(pName, ".", 1, $Length(pName, ".") - 1)
    Set tType = $ZConvert($Piece(pName, ".", $Length(pName, ".")), "L")
    If pCategory = "CLS" {
        Set tGlob = pPiece
        If $ZConvert($Extract(tGlob, *-3, *), "L") = ".cls" Set tGlob = $Extract(tGlob, 1, *-4)
        Quit ..GlobMatches(tBase, tGlob)
    }
    Set tPieceType = $ZConvert($Piece(pPiece, ".", $Length(pPiece, ".")), "L")
    If ($Length(pPiece, ".") > 1) && $ListFind($ListFromString(..#ROUTINETYPES), tPieceType) {
        If tPieceType '= tType Quit 0
        Quit ..GlobMatches(tBase, $Piece(pPiece, ".", 1, $Length(pPiece, ".") - 1))
    }
    Quit ..GlobMatches(tBase, pPiece) || ..GlobMatches(pName, pPiece)
}

/// <p>Whether <var>pSubject</var> matches <var>pGlob</var>, case-sensitively, where
/// <code>*</code> matches any run of characters, an empty run included, and every other character
/// matches itself.</p>
ClassMethod GlobMatches(pSubject As %String, pGlob As %String) As %Boolean
{
    If pGlob '[ "*" Quit (pSubject = pGlob)
    Set tCount = $Length(pGlob, "*")
    Set tFirst = $Piece(pGlob, "*", 1)
    Set tLast = $Piece(pGlob, "*", tCount)
    If $Length(pSubject) < ($Length(tFirst) + $Length(tLast)) Quit 0
    If $Extract(pSubject, 1, $Length(tFirst)) '= tFirst Quit 0
    If (tLast '= "") && ($Extract(pSubject, $Length(pSubject) - $Length(tLast) + 1, $Length(pSubject)) '= tLast) Quit 0
    Set tEnd = $Length(pSubject) - $Length(tLast)
    Set tPos = $Length(tFirst) + 1
    Set tMatched = 1
    For tI = 2:1:tCount - 1 {
        Set tSegment = $Piece(pGlob, "*", tI)
        If tSegment = "" Continue
        Set tFound = $Find(pSubject, tSegment, tPos)
        If (tFound = 0) || ((tFound - 1) > tEnd) {
            Set tMatched = 0
            Quit
        }
        Set tPos = tFound
    }
    Quit tMatched
}

/// <p>One document's structure as rows, and its text in the requested form as
/// <var>pDocument</var>.</p>
/// <p>The name is checked against the endpoint's own shape and the form against
/// <parameter>FORMS</parameter> before any vendor call. The document's index is read first: a
/// document the namespace does not hold is 404 <code>PORT.NOTFOUND</code>. The text is then read
/// as the name itself (<code>udl</code>), its XML export (<code>xml</code>), or the first
/// generated <code>.int</code> the index names (<code>int</code>; an <code>.int</code> document is
/// its own). A form the instance keeps no text for answers <code>available</code> false and an empty
/// <code>content</code>; that is not a fault.</p>
ClassMethod Document(pVersion As %Integer, pNamespace As %String, pEndpoint As %String, ByRef pQuery, pMax As %Integer, Output pRows As %DynamicArray, Output pDocument As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = ""
    Set pDocument = ""
    Try {
        Set tIsClass = (pEndpoint = ..#ENDPOINTCLASS)
        Set tName = $Get(pQuery(..#NAMEKEY))
        If '$Match(tName, $Select(tIsClass: ..#CLASSNAMEPATTERN, 1: ..#ROUTINENAMEPATTERN)) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, $Select(tIsClass: ..#REASONCLASSNAME, 1: ..#REASONROUTINENAME), .pHttpStatus, .pFault)
            Quit
        }
        Set tForm = $Get(pQuery(..#FORMKEY))
        If tForm = "" Set tForm = "udl"
        If '$ListFind($ListFromString(..#FORMS), tForm) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONFORM, .pHttpStatus, .pFault)
            Quit
        }

        Kill tNoParams
        Set tBody = [(tName)]
        Set tSC = ..Route(pVersion, pNamespace, "Index", "", .tNoParams, tBody.%ToJSON(), .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tContent = $Select($IsObject(tAnswer): tAnswer.%Get("content"), 1: "")
        If '$IsObject(tContent) || 'tContent.%IsA("%Library.DynamicArray") || (tContent.%Size() '= 1) || '$IsObject(tContent.%Get(0)) {
            Set tSC = ..Fail("Index answered no one document", $$$ERROR($$$GeneralError, "index answered no one document for " _ tName), .pHttpStatus, .pFault)
            Quit
        }
        Set tIndex = tContent.%Get(0)
        Set tStatus = tIndex.%Get("status")
        If tStatus '= "" {
            Set tSC = ..IndexRefusal(tStatus, .pHttpStatus, .pFault)
            Quit
        }

        Set tGenerates = []
        Set tFirstInt = ""
        Set tOthers = tIndex.%Get("others")
        If $IsObject(tOthers) && tOthers.%IsA("%Library.DynamicArray") {
            Set tIterator = tOthers.%GetIterator()
            While tIterator.%GetNext(.tI, .tOther) {
                Set tOther = $Piece(tOther, ":", 1)
                If $ZConvert($Piece(tOther, ".", $Length(tOther, ".")), "L") '= "int" Continue
                Do tGenerates.%Push(tOther)
                If tFirstInt = "" Set tFirstInt = tOther
            }
        }
        Set tTextName = tName
        Kill tParams
        If tForm = "xml" Set tParams("format") = "xml"
        If tForm = "int" {
            Set tTextName = $Select($ZConvert($Piece(tName, ".", $Length(tName, ".")), "L") = "int": tName, 1: tFirstInt)
        }
        Set tAvailable = 0
        Set tLines = []
        If tTextName '= "" {
            Set tSC = ..Route(pVersion, pNamespace, "GetDoc", tTextName, .tParams, "", .tText, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            Set tTextContent = $Select($IsObject(tText): tText.%Get("content"), 1: "")
            If $IsObject(tTextContent) && tTextContent.%IsA("%Library.DynamicArray") {
                Set tLines = tTextContent
                Set tAvailable = 1
            }
        }

        Set pRows = ..DocumentRows(tIndex, tName, tIsClass, tGenerates, pMax)
        Set tDocument = {}
        Do tDocument.%Set("name", tName)
        Do tDocument.%Set("form", tForm)
        Do tDocument.%Set("available", tAvailable, "boolean")
        Do tDocument.%Set("content", tLines)
        Do tDocument.%Set("modified", tIndex.%Get("ts"))
        Do tDocument.%Set("database", tIndex.%Get("db"))
        Do tDocument.%Set("generates", tGenerates)
        Set pDocument = tDocument
        Set pHttpStatus = 200
    } Catch ex {
        Set pRows = ""
        Set pDocument = ""
        Set tSC = ..Fail("the document read failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The refusal for an index entry whose own <code>status</code> is <var>pStatus</var>: 404
/// <code>PORT.NOTFOUND</code>, unlogged, for a document the namespace does not hold; 403
/// <code>PORT.ACCESSDENIED</code> for a <code>&lt;PROTECT&gt;</code>; the internal fault
/// otherwise.</p>
ClassMethod IndexRefusal(pStatus As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tRawSC = $$$ERROR($$$GeneralError, "Index answered status " _ pStatus)
    If pStatus [ ("#" _ ..#NODOCUMENTCODE _ ":") {
        Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ..#REASONNOTFOUND, .pHttpStatus, .pFault)
    }
    If pStatus [ "<PROTECT>" {
        Set tSC = ..Refuse(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED, ..#REASONACCESSDENIED, .pHttpStatus, .pFault)
        Do ..LogFault("Index was refused", tRawSC, pFault.code)
        Quit tSC
    }
    Quit ..Fail("Index failed", tRawSC, .pHttpStatus, .pFault)
}

/// <p>The rows of one document's structure, at most <var>pMax</var> of them when it is above zero:
/// first the document's own row, then, for a class, one row per parameter, property and method in
/// that order, each group in the index's order.</p>
/// <p>A row is <code>{Order, Kind, Name, Type, Flags, Description, Modified, Database,
/// Generates}</code>. The document's row carries <code>Kind</code> <code>class</code> or
/// <code>routine</code>, <code>Type</code> the superclasses or the routine type, and the
/// modified time, database and generated <code>.int</code> names; a member row carries its own
/// type, and <code>null</code> for the last three. <code>Flags</code> names the flags that are set,
/// comma-separated, and <code>Description</code> is the documentation as plain text
/// (<method>PlainText</method>).</p>
ClassMethod DocumentRows(pIndex As %DynamicObject, pName As %String, pIsClass As %Boolean, pGenerates As %DynamicArray, pMax As %Integer = 0) As %DynamicArray
{
    Set tRows = []
    Set tContent = pIndex.%Get("content")
    If '$IsObject(tContent) || 'tContent.%IsA("%Library.DynamicObject") Set tContent = {}
    Set tGenerated = ""
    Set tIterator = pGenerates.%GetIterator()
    While tIterator.%GetNext(.tI, .tOne) {
        Set tGenerated = tGenerated _ $Select(tGenerated = "": "", 1: ", ") _ tOne
    }
    Set tRow = {}
    Do tRow.%Set("Order", 1, "number")
    Do tRow.%Set("Kind", $Select(pIsClass: "class", 1: "routine"))
    Do tRow.%Set("Name", pName)
    If pIsClass {
        Do tRow.%Set("Type", ..Joined(tContent.%Get("super")))
        Do tRow.%Set("Flags", ..FlagText(tContent, $ListBuild("depl:deployed", "depr:deprecated", "final:final", "hidden:hidden")))
        Do tRow.%Set("Description", ..PlainText(tContent.%Get("desc")))
    } Else {
        Do tRow.%Set("Type", $ZConvert($Piece(pName, ".", $Length(pName, ".")), "L"))
        Do tRow.%Set("Flags", "")
        Do tRow.%Set("Description", "")
    }
    Do tRow.%Set("Modified", pIndex.%Get("ts"))
    Do tRow.%Set("Database", pIndex.%Get("db"))
    Do tRow.%Set("Generates", tGenerated)
    Do tRows.%Push(tRow)
    If 'pIsClass Quit tRows

    For tGroup = $ListBuild("parameters", "parameter"), $ListBuild("properties", "property"), $ListBuild("methods", "method") {
        Set tMembers = tContent.%Get($List(tGroup, 1))
        If '$IsObject(tMembers) || 'tMembers.%IsA("%Library.DynamicArray") Continue
        Set tIterator = tMembers.%GetIterator()
        While tIterator.%GetNext(.tI, .tMember) {
            If (pMax > 0) && (tRows.%Size() = pMax) Quit
            If '$IsObject(tMember) || 'tMember.%IsA("%Library.DynamicObject") Continue
            Set tKind = $List(tGroup, 2)
            Set tRow = {}
            Do tRow.%Set("Order", tRows.%Size() + 1, "number")
            Do tRow.%Set("Kind", tKind)
            Do tRow.%Set("Name", tMember.%Get("name"))
            Do tRow.%Set("Type", $Select(tKind = "method": tMember.%Get("returntype"), 1: tMember.%Get("type")))
            Do tRow.%Set("Flags", ..FlagText(tMember, $ListBuild("scope:class", "final:final", "private:private", "internal:internal", "depr:deprecated")))
            Do tRow.%Set("Description", ..PlainText(tMember.%Get("desc")))
            Do tRow.%Set("Modified", "", "null")
            Do tRow.%Set("Database", "", "null")
            Do tRow.%Set("Generates", "", "null")
            Do tRows.%Push(tRow)
        }
    }
    Quit tRows
}

/// <p>The words of <var>pFlags</var>, each <code>key:word</code>, whose key is set on
/// <var>pObject</var>, comma-separated. A boolean key is set when true; <code>scope</code> is set
/// when it reads <code>class</code>.</p>
ClassMethod FlagText(pObject As %DynamicObject, pFlags As %List) As %String [ Private ]
{
    Set tText = ""
    For tI = 1:1:$ListLength(pFlags) {
        Set tKey = $Piece($List(pFlags, tI), ":", 1)
        Set tWord = $Piece($List(pFlags, tI), ":", 2)
        Set tSet = 0
        If tKey = "scope" {
            Set tSet = (pObject.%Get("scope") = "class")
        } ElseIf pObject.%GetTypeOf(tKey) = "boolean" {
            Set tSet = pObject.%Get(tKey)
        }
        If tSet Set tText = tText _ $Select(tText = "": "", 1: ", ") _ tWord
    }
    Quit tText
}

/// <p>The strings of <var>pArray</var> joined by <code>", "</code>; <code>""</code> when it is not
/// an array.</p>
ClassMethod Joined(pArray) As %String [ Private ]
{
    Set tText = ""
    If '$IsObject(pArray) || 'pArray.%IsA("%Library.DynamicArray") Quit ""
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tI, .tValue) {
        If $IsObject(tValue) Continue
        Set tText = tText _ $Select(tText = "": "", 1: ", ") _ tValue
    }
    Quit tText
}

/// <p>Documentation as plain text: <var>pDesc</var>'s lines (or one string) joined by a space, every
/// <code>&lt;...&gt;</code> tag removed, <code>&amp;lt; &amp;gt; &amp;quot; &amp;#39;</code> and
/// then <code>&amp;amp;</code> decoded, and whitespace runs collapsed to one space.</p>
ClassMethod PlainText(pDesc) As %String
{
    Set tText = ""
    If $IsObject(pDesc) {
        If 'pDesc.%IsA("%Library.DynamicArray") Quit ""
        Set tIterator = pDesc.%GetIterator()
        While tIterator.%GetNext(.tI, .tLine) {
            If $IsObject(tLine) Continue
            Set tText = tText _ $Select(tText = "": "", 1: " ") _ tLine
        }
    } Else {
        Set tText = pDesc
    }
    Set tPlain = ""
    Set tInTag = 0
    For tI = 1:1:$Length(tText) {
        Set tChar = $Extract(tText, tI)
        If tInTag {
            If tChar = ">" Set tInTag = 0
            Continue
        }
        If tChar = "<" {
            Set tInTag = 1
            Continue
        }
        Set tPlain = tPlain _ tChar
    }
    Set tPlain = $Replace(tPlain, "&lt;", "<")
    Set tPlain = $Replace(tPlain, "&gt;", ">")
    Set tPlain = $Replace(tPlain, "&quot;", """")
    Set tPlain = $Replace(tPlain, "&#39;", "'")
    Set tPlain = $Replace(tPlain, "&amp;", "&")
    Quit $ZStrip(tPlain, "<=>W")
}

/// <p>Call route method <var>pMethod</var> of version <var>pVersion</var> with
/// <var>pNamespace</var> and, when it is not <code>""</code>, <var>pArg</var>, and answer the
/// envelope's <code>result</code> as <var>pResult</var>. <var>pParams</var> is seeded into
/// <code>%request.Data</code> and <var>pBody</var>, when it is not <code>""</code>, is a JSON text
/// sent as an <code>application/json</code> body. Trailing route arguments are omitted rather than
/// passed empty.</p>
/// <p>The call runs behind <code>New</code>ed <code>%request</code>, <code>%response</code>,
/// <code>%session</code> and <code>%SourceControl</code>, with fresh stubs. Its output is captured,
/// or, for a route <parameter>FILEDEVICEROUTES</parameter> names, written to a temporary file that is
/// read back and deleted; either way it never reaches the caller's device, which is current again
/// on return. <code>$NAMESPACE</code> is switched to <var>pNamespace</var> immediately around the
/// route call and restored before anything else runs, on every path; no <code>OcuPilot.*</code>
/// class is called while it is switched. The outcome is <method>Outcome</method>'s.</p>
ClassMethod Route(pVersion As %Integer, pNamespace As %String, pMethod As %String, pArg As %String, ByRef pParams, pBody As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Set tCallSC = $$$OK
    Set tHttp = 0
    Set tCapturing = 0
    Set tFileOpen = 0
    Set tFile = ""
    Set tOverflow = 0
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Set tDevice = $IO
    Set tToFile = ''$ListFind($ListFromString(..#FILEDEVICEROUTES), pMethod)
    Set tClass = ..ImplClass(pVersion)
    New %request, %response, %session, %SourceControl
    Try {
        If pBody '= "" {
            Set %request = $ClassMethod(..#REQUESTCLASS, "%New")
            Set tCallSC = %request.SetJsonBody(pBody)
        } Else {
            Set %request = ##class(%CSP.Request).%New()
        }
        Set tKey = ""
        For {
            Set tKey = $Order(pParams(tKey))
            If tKey = "" Quit
            Set %request.Data(tKey, 1) = pParams(tKey)
        }
        Set %response = ##class(%CSP.Response).%New()
        Set %session = ""
        If $$$ISOK(tCallSC) && tToFile {
            Set tFile = ##class(%File).TempFilename("json")
            Open tFile:("WNS":/IOTABLE="UTF8"):..#FILEOPENSECONDS
            If $Test {
                Set tFileOpen = 1
                Use tFile
            } Else {
                Set tCallSC = $$$ERROR($$$GeneralError, "the route's output file could not be opened")
            }
        } ElseIf $$$ISOK(tCallSC) {
            Set tCallSC = $$BeginCapture^%SYS.Capture(.tCookie)
            If $$$ISOK(tCallSC) Set tCapturing = 1
        }
        If tCapturing || tFileOpen {
            Set $NAMESPACE = pNamespace
            If pArg = "" {
                Set tCallSC = $ClassMethod(tClass, pMethod, pNamespace)
            } Else {
                Set tCallSC = $ClassMethod(tClass, pMethod, pNamespace, pArg)
            }
            Set $NAMESPACE = tOrigNS
        }
    } Catch exCall {
        If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
        Set tCallSC = exCall.AsStatus()
    }
    If tCapturing {
        Try {
            Kill tLines
            Set tEndSC = $$EndCapture^%SYS.Capture(tCookie, .tLines)
            If $IsObject($Get(tLines)) {
                Set tIterator = tLines.%GetIterator()
                While tIterator.%GetNext(.tIndex, .tLine) {
                    If ($Length(tText) + $Length(tLine)) >= ..#CAPTURECEILING {
                        Set tOverflow = 1
                        Quit
                    }
                    Set tText = tText _ tLine
                }
            }
        } Catch exEnd {
            If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
            Set tOverflow = 1
            Set tText = ""
        }
    }
    If tFileOpen {
        Try {
            Use tDevice
            Close tFile
            Set tStream = ##class(%Stream.FileCharacter).%New()
            Set tStream.TranslateTable = "UTF8"
            Set tLinkSC = tStream.LinkToFile(tFile)
            If $$$ISERR(tLinkSC) {
                If $$$ISOK(tCallSC) Set tCallSC = tLinkSC
            } Else {
                While 'tStream.AtEnd {
                    Set tChunk = tStream.Read(32000)
                    If ($Length(tText) + $Length(tChunk)) >= ..#CAPTURECEILING {
                        Set tOverflow = 1
                        Quit
                    }
                    Set tText = tText _ tChunk
                }
            }
            Kill tStream
        } Catch exFile {
            If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
            Use tDevice
            If $$$ISOK(tCallSC) Set tCallSC = exFile.AsStatus()
        }
        Do ##class(%File).Delete(tFile)
    }
    If $IsObject($Get(%response)) Set tHttp = +%response.Status
    If $$$ISERR(tCallSC) && ($System.Status.GetErrorText(tCallSC) [ "<MAXSTRING>") Set tOverflow = 1
    Set tSC = ..Outcome(pMethod, tCallSC, tHttp, tText, tOverflow, .pResult, .pHttpStatus, .pFault)
    Quit tSC
}

/// <p>What one route call's outcome means. <var>pText</var> is the captured envelope.</p>
/// <p>An answer at the capture's ceiling is 503 <code>PORT.UNAVAILABLE</code>. A non-2xx status is
/// 404 <code>PORT.NOTFOUND</code> (not logged: a read answered 404 has found an absence), 400
/// <code>PORT.VALIDATION</code>, 403 <code>PORT.ACCESSDENIED</code>, or the internal fault. Under a
/// 2xx status, an error in the route's own status, in <code>status.errors</code> or in the result's
/// own <code>status</code> is 403 <code>PORT.ACCESSDENIED</code> when it is a
/// <code>&lt;PROTECT&gt;</code> and the internal fault otherwise, as is an envelope that does not
/// parse. Otherwise <var>pResult</var> is the envelope's <code>result</code>. The vendor's own text
/// is logged on every logged path and never put on the wire.</p>
ClassMethod Outcome(pMethod As %String, pCallSC As %Status, pHttp As %Integer, pText As %String, pOverflow As %Boolean, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tRaw = pMethod _ " answered HTTP " _ pHttp
    If $$$ISERR(pCallSC) Set tRaw = tRaw _ "; " _ $System.Status.GetErrorText(pCallSC)
    If pOverflow {
        Set tSC = ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PORTUNAVAILABLE, ..#REASONTOOLARGE, .pHttpStatus, .pFault)
        Do ..LogFault(pMethod _ " answered above the capture ceiling", $$$ERROR($$$GeneralError, tRaw), pFault.code)
        Quit tSC
    }
    Set tEnvelope = ""
    Try {
        If pText '= "" Set tEnvelope = ##class(%DynamicAbstractObject).%FromJSON(pText)
    } Catch {
        Set tEnvelope = ""
    }
    Set tErrors = ""
    If $IsObject(tEnvelope) && tEnvelope.%IsA("%Library.DynamicObject") {
        Set tStatusPart = tEnvelope.%Get("status")
        If $IsObject(tStatusPart) && $IsObject(tStatusPart.%Get("errors")) && (tStatusPart.%Get("errors").%Size() > 0) {
            Set tErrors = tStatusPart.%Get("errors").%ToJSON()
        }
        Set tResultPart = tEnvelope.%Get("result")
        If $IsObject(tResultPart) && tResultPart.%IsA("%Library.DynamicObject") && (tResultPart.%GetTypeOf("status") = "string") && (tResultPart.%Get("status") '= "") {
            Set tErrors = tErrors _ $Select(tErrors = "": "", 1: "; ") _ tResultPart.%Get("status")
        }
    }
    If tErrors '= "" Set tRaw = tRaw _ "; " _ tErrors
    Set tRawSC = $$$ERROR($$$GeneralError, tRaw)

    If (pHttp < 200) || (pHttp >= 300) {
        If pHttp = 404 {
            Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ..#REASONNOTFOUND, .pHttpStatus, .pFault)
        }
        If pHttp = 400 {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONVALIDATION, .pHttpStatus, .pFault)
        } ElseIf pHttp = 403 {
            Set tSC = ..Refuse(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED, ..#REASONACCESSDENIED, .pHttpStatus, .pFault)
        } Else {
            Quit ..Fail(pMethod _ " failed", tRawSC, .pHttpStatus, .pFault)
        }
        Do ..LogFault(pMethod _ " was refused", tRawSC, pFault.code)
        Quit tSC
    }
    If $$$ISERR(pCallSC) || (tErrors '= "") || '$IsObject(tEnvelope) || 'tEnvelope.%IsA("%Library.DynamicObject") {
        If tRaw [ "<PROTECT>" {
            Set tSC = ..Refuse(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED, ..#REASONACCESSDENIED, .pHttpStatus, .pFault)
            Do ..LogFault(pMethod _ " was refused", tRawSC, pFault.code)
            Quit tSC
        }
        Quit ..Fail(pMethod _ " failed", tRawSC, .pHttpStatus, .pFault)
    }
    Set pResult = tEnvelope.%Get("result")
    Set pHttpStatus = pHttp
    Quit $$$OK
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture
/// the line; production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>The privilege refusal naming <var>pFailedPair</var> (AD-8, AD-39).</p>
ClassMethod Deny(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDenial = ##class(OcuPilot.Kernel.Denial).Detail(pFailedPair)
    Quit ..Refuse(##class(OcuPilot.Kernel.Denial).#STATUS, ##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason(), .pHttpStatus, .pFault, tDenial)
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

/// <p><code>""</code>: no write reaches the source code API through this port, so no request type
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
