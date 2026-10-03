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
/// structure as rows with its text beside them. The two list endpoints also serve a set of documents
/// (<parameter>NAMESKEY</parameter>): <parameter>TYPEDOCS</parameter> and
/// <parameter>TYPEEXPORTDOCS</parameter>, which of them the namespace holds, and the writes
/// <parameter>TYPECOMPILE</parameter>, <parameter>TYPEDELETE</parameter> and
/// <parameter>TYPEEXPORT</parameter>; and an import of one file (<parameter>IDKEY</parameter>
/// <parameter>IMPORTID</parameter>): <parameter>TYPEIMPORTTARGET</parameter>, its target,
/// <parameter>TYPEPREVIEW</parameter>, what the file would do, and the write
/// <parameter>TYPEIMPORT</parameter>; and a save of one document's text, its fresh read
/// <parameter>TYPESAVEDOCS</parameter> and the write <parameter>TYPESAVE</parameter>. Each write is
/// composed here from the caller's declared values (AD-51); a compile, a delete, an import and a save
/// are gated on WRITE on the namespace's routines database as well (AD-61).</p>
/// <p><b>Two reads find code</b> (<parameter>ENDPOINTSEARCH</parameter> and
/// <parameter>ENDPOINTMACRO</parameter>). A search is always plain text: it sends
/// <code>regex=0</code>, never <code>word</code> or <code>wild</code>, and its
/// <code>documents</code> comes from <parameter>SEARCHDOCUMENTS</parameter> alone (AD-61 rule 7). A
/// macro lookup's body names the include, import and superclass names the document's own text gives
/// (<method>MacroContext</method>), read first through the document route, never a caller's list.
/// Each answers rows only; a match's line and a macro's definition are row fields, never a
/// document's whole text (AD-36).</p>
/// <p><b>A server file is never a caller's path</b> (AD-21's sixth case): an export or an import
/// names it by <code>root</code> and <code>path</code>, resolved through
/// <method>PathPortClass</method> at each call, the export as an overwriting <code>file</code>
/// (<parameter>EXPORTOVERWRITES</parameter>, a constant) and the import as a <code>source</code>. A
/// local file is the screen's <code>fileName</code> and <code>content</code>, never a path.</p>
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
Parameter MINVERSIONS = "GetNamespace:1,GetDocNames:1,Index:1,GetDoc:2,Compile:1,DeleteDocs:1,ExportToXMLFile:7,ListDocumentsInXMLFiles:7,LoadXMLFiles:7,PutDoc:1,Search:2,GetMacroDefinition:2,GetMacroLocation:2";

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

/// <p>The endpoint answering a plain-text search of a namespace's code (<method>SearchRows</method>).</p>
Parameter ENDPOINTSEARCH = "Search";

/// <p>The endpoint answering one macro's definition and location in one document's context
/// (<method>MacroRows</method>).</p>
Parameter ENDPOINTMACRO = "Macro";

/// <p>The query keys carrying a search's text, the documents it looks in (<code>all</code>,
/// <code>classes</code> or <code>routines</code>) and whether it matches case (<code>yes</code> or
/// <code>no</code>).</p>
Parameter TEXTKEY = "text";

Parameter SCOPEKEY = "scope";

Parameter CASEKEY = "case";

/// <p>The longest text a search takes.</p>
Parameter MAXSEARCHTEXT As INTEGER = 256;

/// <p>The vendor's <code>documents</code> for each search scope, as <code>scope=masks</code>
/// separated by <code>;</code>. A search's <code>documents</code> is taken from here alone, never
/// from a caller's text, because the vendor splices a bracketed part of it into SQL (AD-61 rule
/// 7).</p>
Parameter SEARCHDOCUMENTS = "all=*.cls,*.mac,*.int,*.inc,*.bas,*.mvi,*.mvb;classes=*.cls;routines=*.mac,*.int,*.inc,*.bas,*.mvi,*.mvb";

/// <p>The most matches a search asks the vendor for when its caller names no row cap.</p>
Parameter SEARCHMAX As INTEGER = 200;

/// <p>The query keys carrying a macro lookup's document, whose text gives the macro's context, and
/// the macro, as <code>Name</code> or <code>$$$Name</code>.</p>
Parameter MACRODOCUMENTKEY = "document";

Parameter MACROKEY = "macro";

/// <p>The shape a macro's name must take, its leading <code>$$$</code> optional.</p>
Parameter MACRONAMEPATTERN = "^(\$\$\$)?%?[A-Za-z][A-Za-z0-9]*$";

/// <p>The shape a name <method>MacroContext</method> keeps, and the most it keeps per list.</p>
Parameter CONTEXTNAMEPATTERN = "^%?[A-Za-z][A-Za-z0-9.]*$";

Parameter MAXCONTEXTNAMES As INTEGER = 50;

/// <p>The one request type every endpoint serves.</p>
Parameter REQUESTTYPE = "LIST";

/// <p>The list endpoints' read of a set of documents: <code>{Present, Modified, Absent, Namespace}</code>,
/// each a canonical string (<method>Docs</method>), with the compile's three declared values empty
/// beside them.</p>
Parameter TYPEDOCS = "DOCS";

/// <p>The list endpoints' compile of a set of documents (<method>CompileSet</method>).</p>
Parameter TYPECOMPILE = "COMPILE";

/// <p>The list endpoints' delete of a set of documents (<method>DeleteSet</method>).</p>
Parameter TYPEDELETE = "DELETE";

/// <p>The list endpoints' read of a set of documents an export makes: <method>Docs</method>, with
/// <code>root</code> and <code>path</code> answered <code>null</code> beside it.</p>
Parameter TYPEEXPORTDOCS = "EXPORTDOCS";

/// <p>The list endpoints' export of a set of documents (<method>ExportSet</method>).</p>
Parameter TYPEEXPORT = "EXPORT";

/// <p>The list endpoints' read of an import's target: its arguments, empty (<method>Invoke</method>).</p>
Parameter TYPEIMPORTTARGET = "IMPORTTARGET";

/// <p>The list endpoints' read of what an import's file would do (<method>Preview</method>).</p>
Parameter TYPEPREVIEW = "PREVIEW";

/// <p>The list endpoints' import of one file (<method>ImportSet</method>).</p>
Parameter TYPEIMPORT = "IMPORT";

/// <p>The list endpoints' read of the one document a save names: <method>Docs</method>, with
/// <code>content</code>, <code>version</code> and <code>Compile</code> answered <code>null</code>
/// beside it.</p>
Parameter TYPESAVEDOCS = "SAVEDOCS";

/// <p>The list endpoints' save of one document's text (<method>SaveSet</method>).</p>
Parameter TYPESAVE = "SAVE";

/// <p>The writes whose vendor call this port composes from the caller's declared values, as
/// <code>endpoint/type</code> (AD-51): a compile from its three booleans, a delete from the set
/// alone, an export from the set and its file, an import from its file, and a save from its text,
/// its version and its compile choice.</p>
Parameter COMPOSEDTYPES = "Classes/COMPILE,Routines/COMPILE,Classes/DELETE,Routines/DELETE,Classes/EXPORT,Routines/EXPORT,Classes/IMPORT,Routines/IMPORT,Classes/SAVE,Routines/SAVE";

/// <p>The query key carrying an import's target, and the one target it takes, compared without
/// regard to case.</p>
Parameter IDKEY = "id";

Parameter IMPORTID = "import";

/// <p>The query keys carrying a server file: an allowed directory and a relative name under it
/// (AD-21's sixth case).</p>
Parameter ROOTKEY = "root";

Parameter PATHKEY = "path";

/// <p>The query keys carrying a local file the screen sends: its name, which names no directory, and
/// its text. A save's text travels under <parameter>CONTENTKEY</parameter> too.</p>
Parameter FILENAMEKEY = "fileName";

Parameter CONTENTKEY = "content";

/// <p>The query key carrying the version of the document a save's text was read from: the
/// <code>ts</code> the document read answers as <code>modified</code>, sent to the vendor as its
/// <code>If-None-Match</code> (AD-61 rule 3).</p>
Parameter VERSIONKEY = "version";

/// <p>The request variable the vendor's save reads the client's version from.</p>
Parameter IFNONEMATCHVARIABLE = "HTTP_IF_NONE_MATCH";

/// <p>The query key carrying the reviewed summary an import's write compares
/// (<method>Examine</method>).</p>
Parameter DOCUMENTSKEY = "documents";

/// <p>The query key carrying whether an import compiles what it loads, <code>1</code> or
/// <code>0</code> (<code>true</code> or <code>false</code> are read the same).</p>
Parameter COMPILEKEY = "Compile";

/// <p>Whether an export replaces a file already at its name: declared by the export itself, never a
/// caller value (AD-21).</p>
Parameter EXPORTOVERWRITES As BOOLEAN = 1;

/// <p>The most characters an import reads from one file, and the most one save sends.</p>
Parameter MAXIMPORTCHARACTERS As INTEGER = 3000000;

/// <p>The longest local file name an import takes.</p>
Parameter MAXFILENAME As INTEGER = 255;

/// <p>The extensions an import reads, lower case: an XML export, or one UDL document.</p>
Parameter IMPORTEXTENSIONS = "xml,cls,mac,inc,int";

/// <p>The compiler flags an import or a save that compiles sends: <method>CompileFlags</method> with
/// source kept and documents already up to date skipped.</p>
Parameter IMPORTCOMPILEFLAGS = "cuk";

/// <p>The separator between two entries of an import's summary.</p>
Parameter SUMMARYSEPARATOR = ", ";

/// <p>The label of the digest that ends an import's summary (<method>Digest</method>).</p>
Parameter SUMMARYDIGEST = "sha256";

/// <p>How many characters of one line <method>Digest</method> converts to UTF-8 at a time, so a long
/// line never becomes one string longer than the instance's longest.</p>
Parameter DIGESTCHUNK As INTEGER = 32000;

/// <p>The longest line the vendor's export route answers whole: it reads its stream with
/// <code>ReadLine</code>'s default length, so a longer line arrives as pieces of exactly this many
/// characters followed by the rest (measured on this build, 2026-10-02). <method>WholeLines</method>
/// puts such a line back together.</p>
Parameter VENDORLINE As INTEGER = 32000;

/// <p>The query key carrying a set of documents: their names, comma-separated.</p>
Parameter NAMESKEY = "names";

/// <p>The query keys carrying a compile's three declared values, each <code>1</code> or
/// <code>0</code> (<code>true</code> or <code>false</code> are read the same): keep the generated
/// source (<code>k</code>), compile dependents (<code>b</code>) and skip documents already up to date
/// (<code>u</code>).</p>
Parameter KEEPSOURCEKEY = "KeepSource";

Parameter COMPILEDEPENDENTSKEY = "CompileDependents";

Parameter SKIPUPTODATEKEY = "SkipUpToDate";

/// <p>The most documents one set names.</p>
Parameter MAXDOCUMENTS As INTEGER = 100;

/// <p>The vendor's message numbers for a privilege or read-only refusal, which the source code API
/// answers as a soft error rather than as <code>&lt;PROTECT&gt;</code> (AD-61 rule 6).</p>
Parameter ACCESSDENIEDCODES = "5838,5883,302";

/// <p>The vendor's message number for a document another process holds.</p>
Parameter LOCKEDCODE = 5864;

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
Parameter REASONVERSION = "This instance's source code API answers version {highest}, and this operation needs version {needed} or later.";

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
Parameter REASONTOOLARGE = "The source code API's answer is too large to read in one call.";

/// <p>The reason a missing or malformed set of documents is refused with.</p>
Parameter REASONNAMES = "Name 1 to 100 documents of this list, separated by commas.";

/// <p>The reason a missing or malformed compile value is refused with.</p>
Parameter REASONFLAGS = "KeepSource, CompileDependents and SkipUpToDate must each be true or false.";

/// <p>The reason an import whose file is named twice, or not at all, is refused with.</p>
Parameter REASONSOURCE = "Name the file to import once: root and path for a file on the server, or fileName and content for one on this computer.";

/// <p>The reason a malformed local file name is refused with.</p>
Parameter REASONFILENAME = "fileName must be 1 to 255 characters, with no /, \ or control character.";

/// <p>The reason a missing or malformed import compile value is refused with.</p>
Parameter REASONIMPORTCOMPILE = "Compile must be true or false.";

/// <p>The reason an import target other than <parameter>IMPORTID</parameter> is refused with.</p>
Parameter REASONIMPORTID = "An import's target is import.";

/// <p>The reason a save naming more than one document is refused with.</p>
Parameter REASONSAVENAMES = "A save names exactly one document.";

/// <p>The reason a save carrying no version is refused with.</p>
Parameter REASONSAVEVERSION = "version must be the document's version as it was read.";

/// <p>The reason a missing or malformed search text is refused with.</p>
Parameter REASONSEARCHTEXT = "Name the text to search for: 1 to 256 characters, with no control character.";

/// <p>The reason a search scope outside its options is refused with.</p>
Parameter REASONSEARCHSCOPE = "scope must be all, classes or routines.";

/// <p>The reason a search case choice outside its options is refused with.</p>
Parameter REASONSEARCHCASE = "case must be yes or no.";

/// <p>The reason a malformed macro lookup is refused with.</p>
Parameter REASONMACRO = "Name a class or routine as the macro's context, and a macro, as Name or $$$Name.";

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
/// <code>""</code> when the routines database's or a mapped database's resource cannot be resolved,
/// which the caller refuses rather than admits. A globals database that reports no resource adds no
/// pair. Entering a namespace needs READ on its globals database, and a
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

/// <p><method>NamespacePairs</method> plus WRITE on the resource guarding <var>pNamespace</var>'s
/// routines database, which a compile, a delete, an import or a save writes and the source code API
/// itself does not check (AD-61 rule 1, measured); <code>""</code> when the namespace's pairs cannot
/// be resolved, which the caller refuses rather than admits.</p>
ClassMethod WritePairs(pNamespace As %String) As %List
{
    Set tPairs = ..NamespacePairs(pNamespace)
    If tPairs = "" Quit ""
    Do ..DatabaseResources(pNamespace, .tRoutine, .tGlobal, .tMapped, .tResolved)
    If 'tResolved || (tRoutine = "") Quit ""
    Quit tPairs _ $ListBuild($ListBuild(tRoutine, "WRITE"))
}

/// <p>The lowest version <var>pEndpoint</var>'s routes need for request type <var>pType</var>: the
/// highest of its routes' <parameter>MINVERSIONS</parameter>. An export's read and write take the
/// export route's, and an import's target, preview and write each take every route an import may
/// call, so an instance too old for the write refuses its fresh read too; a save's read and write
/// take every route a save may call, the same way. A search takes the search route's, and a macro
/// lookup the document read's and both macro routes'.</p>
ClassMethod MinVersion(pEndpoint As %String, pType As %String = {..#REQUESTTYPE}) As %Integer
{
    Set tImport = (pType = ..#TYPEIMPORTTARGET) || (pType = ..#TYPEPREVIEW) || (pType = ..#TYPEIMPORT)
    Set tExport = (pType = ..#TYPEEXPORTDOCS) || (pType = ..#TYPEEXPORT)
    Set tSave = (pType = ..#TYPESAVEDOCS) || (pType = ..#TYPESAVE)
    Set tRoutes = $Select(pEndpoint = ..#ENDPOINTSEARCH: $ListBuild("Search"), pEndpoint = ..#ENDPOINTMACRO: $ListBuild("GetDoc", "GetMacroDefinition", "GetMacroLocation"), (pEndpoint = ..#ENDPOINTCLASS) || (pEndpoint = ..#ENDPOINTROUTINE): $ListBuild("Index", "GetDoc"), pType = ..#TYPEDOCS: $ListBuild("GetDocNames"), pType = ..#TYPECOMPILE: $ListBuild("GetDocNames", "Compile"), pType = ..#TYPEDELETE: $ListBuild("GetDocNames", "DeleteDocs"), tExport: $ListBuild("GetDocNames", "ExportToXMLFile"), tImport: $ListBuild("GetDocNames", "ListDocumentsInXMLFiles", "LoadXMLFiles", "PutDoc", "Compile"), tSave: $ListBuild("GetDocNames", "PutDoc", "Compile"), 1: $ListBuild("GetNamespace", "GetDocNames"))
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
/// <parameter>ENDPOINTSEARCH</parameter> reads <code>text</code>, <code>scope</code> and
/// <code>case</code> (<method>SearchRows</method>), and <parameter>ENDPOINTMACRO</parameter>
/// <code>document</code> and <code>macro</code> (<method>MacroRows</method>). <var>pBody</var> is not
/// read.</p>
/// <p>On success <var>pResult</var> is a <class>%DynamicArray</class> of rows and
/// <var>pHttpStatus</var> is 200. A list row is <code>{Name, Modified, Database, Generated}</code>;
/// a document endpoint answers <method>DocumentRows</method>'s rows and <var>pDocument</var>
/// <code>{name, form, available, content, modified, database, generates}</code>, which the row cap
/// never cuts; a search row is <code>{Order, Document, Member, Line, Attribute, Text}</code> and a
/// macro row <code>{Macro, Document, Line, Definition}</code>, with no document beside them.</p>
/// <p>The list endpoints also serve a set of documents, named in <code>names</code>
/// (<method>SetNames</method>), in <code>namespace</code> or, where it is absent, the request's
/// resolved scope (<method>OcuPilot.Kernel.Scope.Current</method>): <parameter>TYPEDOCS</parameter>
/// and <parameter>TYPEEXPORTDOCS</parameter> answer <method>Docs</method>'s object;
/// <parameter>TYPECOMPILE</parameter>, <parameter>TYPEDELETE</parameter> and
/// <parameter>TYPEEXPORT</parameter> answer <method>CompileSet</method>'s,
/// <method>DeleteSet</method>'s and <method>ExportSet</method>'s, and the first two require WRITE on
/// the namespace's routines database (<method>WritePairs</method>).</p>
/// <p>They serve an import too, in the same namespace, its target <code>id</code>
/// <parameter>IMPORTID</parameter>: <parameter>TYPEIMPORTTARGET</parameter> answers
/// <code>{Namespace, root, path, fileName, content, documents}</code>, the namespace and five empty
/// strings, with <code>Compile</code> <code>null</code>, and makes no vendor call, any other id
/// being 404 <code>PORT.NOTFOUND</code>; <parameter>TYPEPREVIEW</parameter> answers
/// <method>Preview</method>'s <code>{documents, count}</code>; and <parameter>TYPEIMPORT</parameter>
/// answers <method>ImportSet</method>'s, requiring <method>WritePairs</method>.</p>
/// <p>And a save of one document, named in <code>names</code>: <parameter>TYPESAVEDOCS</parameter>
/// answers <method>Docs</method>'s object, and <parameter>TYPESAVE</parameter> answers
/// <method>SaveSet</method>'s, requiring <method>WritePairs</method>.</p>
/// <p>Otherwise an error status is returned with <var>pResult</var> and <var>pDocument</var> empty,
/// <var>pHttpStatus</var> the status to answer with and <var>pFault</var> the wire fault: 403
/// <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>, before any vendor call; 501
/// <code>PORT.NOTIMPLEMENTED</code> for an endpoint not served or an instance whose version is too
/// old; 400 <code>PORT.VALIDATION</code> for a malformed argument or a value the vendor refused;
/// 404 <code>PORT.NOTFOUND</code>; 404 <code>EXPLORER.DOCUMENT.ABSENT</code> for a write naming a
/// document the namespace does not hold, with nothing sent; a file's own refusals
/// (<method>ExportFile</method>, <method>ImportSource</method>, <method>ImportSet</method>); a save's
/// own (<method>SaveSet</method>); 403
/// <code>PORT.ACCESSDENIED</code> for
/// the vendor's own privilege refusal; 503 <code>PORT.UNAVAILABLE</code> for an answer above
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
        Set tSetType = (pType = ..#TYPEDOCS) || (pType = ..#TYPECOMPILE) || (pType = ..#TYPEDELETE) || (pType = ..#TYPEEXPORTDOCS) || (pType = ..#TYPEEXPORT) || (pType = ..#TYPESAVEDOCS) || (pType = ..#TYPESAVE)
        Set tImportType = (pType = ..#TYPEIMPORTTARGET) || (pType = ..#TYPEPREVIEW) || (pType = ..#TYPEIMPORT)
        Set tWrite = (pType = ..#TYPECOMPILE) || (pType = ..#TYPEDELETE) || (pType = ..#TYPEIMPORT) || (pType = ..#TYPESAVE)
        Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
        If (tNamespace = "") && (tSetType || tImportType) Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        If '$Match(tNamespace, ..#NAMESPACEPATTERN) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACESHAPE, .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespacePairs = $Select(tWrite: ..WritePairs(tNamespace), 1: ..NamespacePairs(tNamespace))
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
        Set tFind = (pEndpoint = ..#ENDPOINTSEARCH) || (pEndpoint = ..#ENDPOINTMACRO)
        Set tServed = ((pType = ..#REQUESTTYPE) && (tList || tOne || tFind)) || ((tSetType || tImportType) && tList)
        If 'tServed {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tNeeded = ..MinVersion(pEndpoint, pType)
        Set tHighest = +..HighestVersion()
        If tHighest < tNeeded {
            Set tReason = $Replace($Replace(..#REASONVERSION, "{highest}", tHighest), "{needed}", tNeeded)
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, tReason, .pHttpStatus, .pFault)
            Quit
        }
        Set tVersion = $Select(tHighest > ..#PINNEDVERSION: ..#PINNEDVERSION, 1: tHighest)

        If tImportType {
            If $ZConvert($Get(pQuery(..#IDKEY)), "L") '= ..#IMPORTID {
                Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ..#REASONIMPORTID, .pHttpStatus, .pFault)
                Quit
            }
            If pType = ..#TYPEIMPORTTARGET {
                Set pResult = {}
                Do pResult.%Set("Namespace", tNamespace, "string")
                For tKey = ..#ROOTKEY, ..#PATHKEY, ..#FILENAMEKEY, ..#CONTENTKEY, ..#DOCUMENTSKEY {
                    Do pResult.%Set(tKey, "", "string")
                }
                Do pResult.%Set(..#COMPILEKEY, "", "null")
                Set pHttpStatus = 200
                Quit
            }
            If pType = ..#TYPEPREVIEW {
                Set tSC = ..Preview(tVersion, tNamespace, .pQuery, .pResult, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ImportSet(tVersion, tNamespace, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }

        If tSetType {
            Set tNames = ..SetNames(pEndpoint, $Get(pQuery(..#NAMESKEY)))
            If tNames = "" {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMES, .pHttpStatus, .pFault)
                Quit
            }
            If pType = ..#TYPEDOCS {
                Set tSC = ..Docs(tVersion, tNamespace, pEndpoint, tNames, .pResult, .pHttpStatus, .pFault)
                Quit
            }
            If pType = ..#TYPEEXPORTDOCS {
                Set tSC = ..Docs(tVersion, tNamespace, pEndpoint, tNames, .pResult, .pHttpStatus, .pFault, $ListBuild(..#ROOTKEY, ..#PATHKEY))
                Quit
            }
            If pType = ..#TYPEEXPORT {
                Set tSC = ..ExportSet(tVersion, tNamespace, pEndpoint, tNames, .pQuery, .pResult, .pHttpStatus, .pFault)
                Quit
            }
            If pType = ..#TYPESAVEDOCS {
                Set tSC = ..Docs(tVersion, tNamespace, pEndpoint, tNames, .pResult, .pHttpStatus, .pFault, $ListBuild(..#CONTENTKEY, ..#VERSIONKEY, ..#COMPILEKEY))
                Quit
            }
            If pType = ..#TYPESAVE {
                Set tSC = ..SaveSet(tVersion, tNamespace, pEndpoint, tNames, .pQuery, .pResult, .pHttpStatus, .pFault)
                Quit
            }
            If pType = ..#TYPECOMPILE {
                Set tSC = ..CompileSet(tVersion, tNamespace, pEndpoint, tNames, .pQuery, .pResult, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..DeleteSet(tVersion, tNamespace, pEndpoint, tNames, .pResult, .pHttpStatus, .pFault)
            Quit
        }

        Set tMax = $Get(pQuery(..#MAXROWSKEY))
        If (tMax '= "") && '$Match(tMax, "^[1-9][0-9]*$") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTSEARCH {
            Set tSC = ..SearchRows(tVersion, tNamespace, .pQuery, +tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTMACRO {
            Set tSC = ..MacroRows(tVersion, tNamespace, .pQuery, .pResult, .pHttpStatus, .pFault)
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

/// <p>The rows of a plain-text search of the namespace's code, at most <var>pMax</var> of them when it
/// is above zero, in the vendor's order. <code>text</code> is required, 1 to
/// <parameter>MAXSEARCHTEXT</parameter> characters with no control character; <code>scope</code> is
/// <code>all</code> when absent and <code>case</code> <code>no</code>. Each is checked before the
/// route is called, and a bad one is refused 400 <code>PORT.VALIDATION</code> with its own
/// reason.</p>
/// <p>The route is sent exactly <code>query</code>, <code>documents</code> (the scope's
/// <parameter>SEARCHDOCUMENTS</parameter> entry), <code>regex=0</code>, <code>case</code>,
/// <code>sys=0</code>, <code>gen=0</code> and <code>max</code> (<var>pMax</var>, else
/// <parameter>SEARCHMAX</parameter>), and nothing else (AD-61 rule 7).</p>
/// <p>A row is <code>{Order, Document, Member, Line, Attribute, Text}</code>: <code>Order</code>
/// counts from 1, <code>Line</code> is the match's line, else its attribute's line, else
/// <code>null</code>, and an absent member or attribute is <code>""</code>.</p>
ClassMethod SearchRows(pVersion As %Integer, pNamespace As %String, ByRef pQuery, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = ""
    Try {
        Set tText = $Get(pQuery(..#TEXTKEY))
        If (tText = "") || ($Length(tText) > ..#MAXSEARCHTEXT) || ($ZStrip(tText, "*C") '= tText) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONSEARCHTEXT, .pHttpStatus, .pFault)
            Quit
        }
        Set tScope = $Get(pQuery(..#SCOPEKEY))
        If tScope = "" Set tScope = "all"
        Set tDocuments = ..SearchDocuments(tScope)
        If tDocuments = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONSEARCHSCOPE, .pHttpStatus, .pFault)
            Quit
        }
        Set tCase = $Get(pQuery(..#CASEKEY))
        If tCase = "" Set tCase = "no"
        If (tCase '= "yes") && (tCase '= "no") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONSEARCHCASE, .pHttpStatus, .pFault)
            Quit
        }
        Kill tParams
        Set tParams("query") = tText
        Set tParams("documents") = tDocuments
        Set tParams("regex") = 0
        Set tParams("case") = $Select(tCase = "yes": 1, 1: 0)
        Set tParams("sys") = 0
        Set tParams("gen") = 0
        Set tParams("max") = $Select(pMax > 0: pMax, 1: ..#SEARCHMAX)
        Set tSC = ..Route(pVersion, pNamespace, "Search", "", .tParams, "", .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tAnswer) || 'tAnswer.%IsA("%Library.DynamicArray") {
            Set tSC = ..Fail("Search answered no result array", $$$ERROR($$$GeneralError, "search answered no result array"), .pHttpStatus, .pFault)
            Quit
        }
        Set tRows = []
        Set tDocs = tAnswer.%GetIterator()
        While tDocs.%GetNext(.tDocIndex, .tDoc) {
            If (pMax > 0) && (tRows.%Size() >= pMax) Quit
            If '$IsObject(tDoc) || 'tDoc.%IsA("%Library.DynamicObject") Continue
            Set tMatches = tDoc.%Get("matches")
            If '$IsObject(tMatches) || 'tMatches.%IsA("%Library.DynamicArray") Continue
            Set tIterator = tMatches.%GetIterator()
            While tIterator.%GetNext(.tMatchIndex, .tMatch) {
                If (pMax > 0) && (tRows.%Size() >= pMax) Quit
                If '$IsObject(tMatch) || 'tMatch.%IsA("%Library.DynamicObject") Continue
                Set tLine = tMatch.%Get("line")
                If tLine = "" Set tLine = tMatch.%Get("attrline")
                Set tRow = {}
                Do tRow.%Set("Order", tRows.%Size() + 1, "number")
                Do tRow.%Set("Document", tDoc.%Get("doc"), "string")
                Do tRow.%Set("Member", tMatch.%Get("member"), "string")
                If tLine = "" {
                    Do tRow.%Set("Line", "", "null")
                } Else {
                    Do tRow.%Set("Line", +tLine, "number")
                }
                Do tRow.%Set("Attribute", tMatch.%Get("attr"), "string")
                Do tRow.%Set("Text", tMatch.%Get("text"), "string")
                Do tRows.%Push(tRow)
            }
        }
        Set pRows = tRows
        Set pHttpStatus = 200
    } Catch ex {
        Set pRows = ""
        Set tSC = ..Fail("the search failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The vendor's <code>documents</code> for search scope <var>pScope</var>, from
/// <parameter>SEARCHDOCUMENTS</parameter>; <code>""</code> for a scope it does not declare.</p>
ClassMethod SearchDocuments(pScope As %String) As %String
{
    Set tMasks = ""
    For tI = 1:1:$Length(..#SEARCHDOCUMENTS, ";") {
        Set tEntry = $Piece(..#SEARCHDOCUMENTS, ";", tI)
        If $Piece(tEntry, "=", 1) = pScope Set tMasks = $Piece(tEntry, "=", 2, *)
    }
    Quit tMasks
}

/// <p>The rows of one macro's lookup in one document's context: none when nothing in that context
/// defines it, else one <code>{Macro, Document, Line, Definition}</code> row, where
/// <code>Macro</code> is the name without <code>$$$</code>, <code>Document</code> and
/// <code>Line</code> are where it is defined (<code>Line</code> <code>null</code> when the instance
/// names none), and <code>Definition</code> is its definition's lines joined by LF.</p>
/// <p><code>document</code> must match <parameter>CLASSNAMEPATTERN</parameter> or
/// <parameter>ROUTINENAMEPATTERN</parameter> and <code>macro</code>
/// <parameter>MACRONAMEPATTERN</parameter>; either refused is 400 <code>PORT.VALIDATION</code> before
/// any route. The document's text is read first (<code>udl</code>), so one the namespace does not
/// hold is 404 <code>PORT.NOTFOUND</code>, unlogged. Both macro routes are then sent
/// <code>{docname, macroname, includes, superclasses, imports}</code>, built here from
/// <method>MacroContext</method>; the location is asked only for a macro the definition route
/// answers.</p>
ClassMethod MacroRows(pVersion As %Integer, pNamespace As %String, ByRef pQuery, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = ""
    Try {
        Set tDocument = $Get(pQuery(..#MACRODOCUMENTKEY))
        Set tMacro = $Get(pQuery(..#MACROKEY))
        Set tShaped = $Match(tDocument, ..#CLASSNAMEPATTERN) || $Match(tDocument, ..#ROUTINENAMEPATTERN)
        If 'tShaped || '$Match(tMacro, ..#MACRONAMEPATTERN) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMACRO, .pHttpStatus, .pFault)
            Quit
        }
        If $Extract(tMacro, 1, 3) = ("$$" _ "$") Set tMacro = $Extract(tMacro, 4, *)

        Kill tNoParams
        Set tSC = ..Route(pVersion, pNamespace, "GetDoc", tDocument, .tNoParams, "", .tSource, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tLines = $Select($IsObject(tSource): tSource.%Get("content"), 1: "")
        If '$IsObject(tLines) || 'tLines.%IsA("%Library.DynamicArray") Set tLines = []
        Set tContext = ..MacroContext(tDocument, tLines)
        Set tBody = {}
        Do tBody.%Set("docname", tDocument, "string")
        Do tBody.%Set("macroname", tMacro, "string")
        Do tBody.%Set("includes", tContext.includes)
        Do tBody.%Set("superclasses", tContext.superclasses)
        Do tBody.%Set("imports", tContext.imports)

        Set tSC = ..Route(pVersion, pNamespace, "GetMacroDefinition", "", .tNoParams, tBody, .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tContent = $Select($IsObject(tAnswer): tAnswer.%Get("content"), 1: "")
        Set tDefinition = $Select($IsObject(tContent): tContent.%Get("definition"), 1: "")
        Set tText = ""
        Set tDefined = 0
        If $IsObject(tDefinition) && tDefinition.%IsA("%Library.DynamicArray") {
            Set tIterator = tDefinition.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tLine) {
                If $IsObject(tLine) Continue
                Set tText = tText _ $Select(tDefined: $Char(10), 1: "") _ tLine
                Set tDefined = 1
            }
        }
        Set pRows = []
        Set pHttpStatus = 200
        If 'tDefined Quit

        Set tSC = ..Route(pVersion, pNamespace, "GetMacroLocation", "", .tNoParams, tBody, .tWhere, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) {
            Set pRows = ""
            Quit
        }
        Set tLocation = $Select($IsObject(tWhere): tWhere.%Get("content"), 1: "")
        Set tAt = $Select($IsObject(tLocation): tLocation.%Get("document"), 1: "")
        Set tLineNo = $Select($IsObject(tLocation): tLocation.%Get("line"), 1: "")
        Set tRow = {}
        Do tRow.%Set("Macro", tMacro, "string")
        Do tRow.%Set("Document", tAt, "string")
        If tLineNo = "" {
            Do tRow.%Set("Line", "", "null")
        } Else {
            Do tRow.%Set("Line", +tLineNo, "number")
        }
        Do tRow.%Set("Definition", tText, "string")
        Do pRows.%Push(tRow)
        Set pHttpStatus = 200
    } Catch ex {
        Set pRows = ""
        Set tSC = ..Fail("the macro lookup failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The context a macro in document <var>pName</var> resolves in, from the document's own UDL
/// lines <var>pLines</var>: <code>{includes, superclasses, imports}</code>, each an array of
/// names.</p>
/// <ul>
/// <li>A class (<code>.cls</code>): every <code>Include</code> and <code>IncludeGenerator</code>
/// line before its <code>Class</code> line joins <code>includes</code>, every <code>Import</code>
/// line <code>imports</code>, each naming one name or a parenthesized, comma-separated list; and the
/// <code>Class</code> line's <code>Extends</code> list is <code>superclasses</code>. A line inside a
/// <code>/* */</code> comment is skipped.</li>
/// <li>A routine: every <code>#include</code> line, matched without regard to case, joins
/// <code>includes</code>, and an include file names itself there first.</li>
/// </ul>
/// <p>A list keeps each name matching <parameter>CONTEXTNAMEPATTERN</parameter> once, in the order
/// the text gives them, and at most <parameter>MAXCONTEXTNAMES</parameter>.</p>
ClassMethod MacroContext(pName As %String, pLines As %DynamicArray) As %DynamicObject
{
    Set tContext = {"includes": [], "superclasses": [], "imports": []}
    Set tExtension = $ZConvert($Piece(pName, ".", $Length(pName, ".")), "L")
    If '$IsObject(pLines) || 'pLines.%IsA("%Library.DynamicArray") Set pLines = []
    If tExtension '= "cls" {
        If tExtension = "inc" Do ..ContextAdd(tContext.includes, $Piece(pName, ".", 1, $Length(pName, ".") - 1))
        Set tIterator = pLines.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLine) {
            If $IsObject(tLine) Continue
            Set tTrimmed = $ZStrip($Translate(tLine, $Char(9), " "), "<>W")
            If $ZConvert($Extract(tTrimmed, 1, 8), "L") '= "#include" Continue
            Set tRest = $ZStrip($Extract(tTrimmed, 9, *), "<W")
            If (tRest = "") || ($Extract(tTrimmed, 9) '= " ") Continue
            Do ..ContextAdd(tContext.includes, $Piece(tRest, " ", 1))
        }
        Quit tContext
    }
    Set tInComment = 0
    Set tIterator = pLines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If $IsObject(tLine) Continue
        Set tTrimmed = $ZStrip($Translate(tLine, $Char(9), " "), "<>W")
        If tInComment {
            If tTrimmed [ "*/" Set tInComment = 0
            Continue
        }
        If $Extract(tTrimmed, 1, 2) = "/*" {
            If $Find(tTrimmed, "*/", 3) = 0 Set tInComment = 1
            Continue
        }
        Set tWord = $ZConvert($Piece(tTrimmed, " ", 1), "L")
        Set tRest = $ZStrip($Piece(tTrimmed, " ", 2, *), "<W")
        If tWord = "class" {
            Set tLower = $ZConvert(tRest, "L")
            Set tAt = $Find(tLower, " extends ")
            If tAt > 0 Do ..ContextList(tContext.superclasses, $ZStrip($Extract(tRest, tAt, *), "<W"))
            Quit
        }
        If (tWord = "include") || (tWord = "includegenerator") {
            Do ..ContextList(tContext.includes, tRest)
        } ElseIf tWord = "import" {
            Do ..ContextList(tContext.imports, tRest)
        }
    }
    Quit tContext
}

/// <p>Add each name <var>pText</var> begins with to <var>pList</var> (<method>ContextAdd</method>):
/// a parenthesized, comma-separated list, or one name ending at the first space or
/// <code>[</code>.</p>
ClassMethod ContextList(pList As %DynamicArray, pText As %String) [ Private ]
{
    If $Extract(pText) = "(" {
        Set tInner = $Piece($Extract(pText, 2, *), ")", 1)
        For tI = 1:1:$Length(tInner, ",") {
            Do ..ContextAdd(pList, $ZStrip($Piece(tInner, ",", tI), "<>W"))
        }
        Quit
    }
    Do ..ContextAdd(pList, $Piece($Piece(pText, " ", 1), "[", 1))
}

/// <p>Push <var>pName</var> onto <var>pList</var> when it matches
/// <parameter>CONTEXTNAMEPATTERN</parameter>, the list does not hold it yet, and it holds fewer than
/// <parameter>MAXCONTEXTNAMES</parameter>.</p>
ClassMethod ContextAdd(pList As %DynamicArray, pName As %String) [ Private ]
{
    If '$Match(pName, ..#CONTEXTNAMEPATTERN) Quit
    If pList.%Size() >= ..#MAXCONTEXTNAMES Quit
    Set tHeld = 0
    Set tIterator = pList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        If tName = pName Set tHeld = 1
    }
    If 'tHeld Do pList.%Push(pName, "string")
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

/// <p><var>pValue</var> as a canonical set of document names of <var>pEndpoint</var>'s kind, as a
/// <class>%List</class>: split on commas, empty pieces dropped, each name once, sorted by character
/// code. <code>""</code> when the set is empty, names more than <parameter>MAXDOCUMENTS</parameter>,
/// or holds a name that is not a class (<parameter>CLASSNAMEPATTERN</parameter>) on the classes
/// list or a routine (<parameter>ROUTINENAMEPATTERN</parameter>) on the routines list.</p>
ClassMethod SetNames(pEndpoint As %String, pValue As %String) As %List
{
    Set tPattern = $Select(pEndpoint = ..#ENDPOINTCLASSES: ..#CLASSNAMEPATTERN, 1: ..#ROUTINENAMEPATTERN)
    Kill tSorted
    Set tValid = 1
    For tI = 1:1:$Length(pValue, ",") {
        Set tName = $Piece(pValue, ",", tI)
        If tName = "" Continue
        If '$Match(tName, tPattern) {
            Set tValid = 0
            Quit
        }
        ; Subscripted behind a letter so every name collates as a string, never as a number.
        Set tSorted("n" _ tName) = tName
    }
    If 'tValid Quit ""
    Set tNames = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey), 1, tName)
        If tKey = "" Quit
        Set tNames = tNames _ $ListBuild(tName)
    }
    If ($ListLength(tNames) = 0) || ($ListLength(tNames) > ..#MAXDOCUMENTS) Quit ""
    Quit tNames
}

/// <p>Which of the documents <var>pNames</var> the namespace holds, from one <code>docnames</code> read
/// of the endpoint's category with its generated documents: <code>{Present, Modified, Absent,
/// Namespace}</code>, where <code>Present</code> and <code>Absent</code> are the held and the missing
/// names comma-joined in the set's order, <code>Modified</code> is each held name and its modified
/// time as <code>name=time</code>, comma-joined, and <code>Namespace</code> is <var>pNamespace</var>.
/// Each name of <var>pNullKeys</var> is answered <code>null</code> beside them, so a write's declared
/// values merge over this read (AD-4, AD-51): <code>KeepSource</code>,
/// <code>CompileDependents</code> and <code>SkipUpToDate</code> when it names none.</p>
ClassMethod Docs(pVersion As %Integer, pNamespace As %String, pEndpoint As %String, pNames As %List, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pNullKeys As %List = "") As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Kill tParams
        Set tParams("generated") = 1
        Set tSC = ..Route(pVersion, pNamespace, "GetDocNames", $Select(pEndpoint = ..#ENDPOINTCLASSES: "CLS", 1: "RTN"), .tParams, "", .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tContent = $Select($IsObject(tAnswer): tAnswer.%Get("content"), 1: "")
        If '$IsObject(tContent) || 'tContent.%IsA("%Library.DynamicArray") {
            Set tSC = ..Fail("GetDocNames answered no content array", $$$ERROR($$$GeneralError, "docnames answered no content array"), .pHttpStatus, .pFault)
            Quit
        }
        Kill tWanted, tFound
        For tI = 1:1:$ListLength(pNames) {
            Set tWanted($List(pNames, tI)) = ""
        }
        Set tIterator = tContent.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tDoc) {
            If '$IsObject(tDoc) || 'tDoc.%IsA("%Library.DynamicObject") Continue
            Set tName = tDoc.%Get("name")
            If (tName = "") || '$Data(tWanted(tName)) Continue
            Set tFound(tName) = tDoc.%Get("ts")
        }
        Set tPresent = ""
        Set tModified = ""
        Set tAbsent = ""
        For tI = 1:1:$ListLength(pNames) {
            Set tName = $List(pNames, tI)
            If $Data(tFound(tName)) {
                Set tPresent = tPresent _ $Select(tPresent = "": "", 1: ",") _ tName
                Set tModified = tModified _ $Select(tModified = "": "", 1: ",") _ tName _ "=" _ tFound(tName)
            } Else {
                Set tAbsent = tAbsent _ $Select(tAbsent = "": "", 1: ",") _ tName
            }
        }
        Set pResult = {}
        Do pResult.%Set("Present", tPresent, "string")
        Do pResult.%Set("Modified", tModified, "string")
        Do pResult.%Set("Absent", tAbsent, "string")
        Do pResult.%Set("Namespace", pNamespace, "string")
        Set tNullKeys = $Select(pNullKeys = "": $ListBuild(..#KEEPSOURCEKEY, ..#COMPILEDEPENDENTSKEY, ..#SKIPUPTODATEKEY), 1: pNullKeys)
        For tI = 1:1:$ListLength(tNullKeys) {
            Do pResult.%Set($List(tNullKeys, tI), "", "null")
        }
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the document set read failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The fresh read every write of a set makes first: <method>Docs</method>, refused 404
/// <code>EXPLORER.DOCUMENT.ABSENT</code> with <code>detail.documents</code> naming each absent
/// document when the namespace no longer holds them all, so nothing is sent.</p>
ClassMethod PresentSet(pVersion As %Integer, pNamespace As %String, pEndpoint As %String, pNames As %List, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..Docs(pVersion, pNamespace, pEndpoint, pNames, .tDocs, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tAbsent = tDocs.%Get("Absent")
    If tAbsent = "" Quit $$$OK
    Quit ..AbsentRefusal(tAbsent, .pHttpStatus, .pFault)
}

/// <p>The refusal of a write naming documents the namespace does not hold, <var>pAbsent</var>
/// comma-joined: 404 <code>EXPLORER.DOCUMENT.ABSENT</code>, its <code>detail.documents</code> naming
/// each. The one producer of that refusal, for the port's write and the agent's mint alike.</p>
ClassMethod AbsentRefusal(pAbsent As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tDetail = {"documents": []}
    For tI = 1:1:$Length(pAbsent, ",") {
        If $Piece(pAbsent, ",", tI) '= "" Do tDetail.documents.%Push($Piece(pAbsent, ",", tI), "string")
    }
    Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.AtelierError).#DOCUMENTABSENT, ##class(OcuPilot.Api.AtelierError).#REASONDOCUMENTABSENT, .pHttpStatus, .pFault, tDetail)
}

/// <p>Whether <var>pValue</var> is one of the spellings a compile value takes, in
/// <var>pOn</var>.</p>
ClassMethod FlagValue(pValue As %String, Output pOn As %Boolean) As %Boolean [ Private ]
{
    Set pOn = 0
    If (pValue = "1") || (pValue = "true") {
        Set pOn = 1
        Quit 1
    }
    Quit (pValue = "0") || (pValue = "false")
}

/// <p>The compiler flags a compile sends: <code>c</code>, then <code>u</code>, <code>k</code> and
/// <code>b</code> for each of <var>pSkipUpToDate</var>, <var>pKeepSource</var> and
/// <var>pCompileDependents</var> that is on. Nothing else ever reaches the compiler.</p>
ClassMethod CompileFlags(pKeepSource As %Boolean, pCompileDependents As %Boolean, pSkipUpToDate As %Boolean) As %String
{
    Quit "c" _ $Select(pSkipUpToDate: "u", 1: "") _ $Select(pKeepSource: "k", 1: "") _ $Select(pCompileDependents: "b", 1: "")
}

/// <p>Compile the documents <var>pNames</var> in one call, with <method>CompileFlags</method> built
/// from <var>pQuery</var>'s three values, after <method>PresentSet</method>. <var>pResult</var> is
/// <code>{lines, errors}</code>: the compiler's console lines and whether it reported an error. A
/// compile error is the compile's own result, never a fault: the route answers it as a soft error,
/// whose first error alone is in its status, so the lines are the record.</p>
ClassMethod CompileSet(pVersion As %Integer, pNamespace As %String, pEndpoint As %String, pNames As %List, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tFlagsOk = ..FlagValue($Get(pQuery(..#KEEPSOURCEKEY)), .tKeep) && ..FlagValue($Get(pQuery(..#COMPILEDEPENDENTSKEY)), .tDependents) && ..FlagValue($Get(pQuery(..#SKIPUPTODATEKEY)), .tSkip)
        If 'tFlagsOk {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONFLAGS, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..PresentSet(pVersion, pNamespace, pEndpoint, pNames, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tBody = []
        For tI = 1:1:$ListLength(pNames) {
            Do tBody.%Push($List(pNames, tI), "string")
        }
        Kill tParams
        Set tParams("flags") = ..CompileFlags(tKeep, tDependents, tSkip)
        Set tParams("source") = 0
        Set tSC = ..Route(pVersion, pNamespace, "Compile", "", .tParams, tBody.%ToJSON(), .tAnswer, .pHttpStatus, .pFault, 1, .tConsole, .tErrors)
        If $$$ISERR(tSC) Quit
        Set pResult = {}
        Do pResult.%Set("lines", $Select($IsObject(tConsole): tConsole, 1: []))
        Do pResult.%Set("errors", ''tErrors, "boolean")
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the compile failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Delete the documents <var>pNames</var> in one call, after <method>PresentSet</method>.
/// <var>pResult</var> is <code>{documents}</code>, one <code>{name, deleted, reason}</code> per
/// document the route answered, where a refused document carries its port-owned reason
/// (<method>DeleteReason</method>) and its vendor text is logged, never sent (AD-39). A refused
/// document is not a fault.</p>
ClassMethod DeleteSet(pVersion As %Integer, pNamespace As %String, pEndpoint As %String, pNames As %List, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tSC = ..PresentSet(pVersion, pNamespace, pEndpoint, pNames, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tBody = []
        For tI = 1:1:$ListLength(pNames) {
            Do tBody.%Push($List(pNames, tI), "string")
        }
        Kill tNoParams
        Set tSC = ..Route(pVersion, pNamespace, "DeleteDocs", "", .tNoParams, tBody.%ToJSON(), .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tAnswer) || 'tAnswer.%IsA("%Library.DynamicArray") {
            Set tSC = ..Fail("DeleteDocs answered no result array", $$$ERROR($$$GeneralError, "deletedocs answered no result array"), .pHttpStatus, .pFault)
            Quit
        }
        Set tDocuments = []
        Set tIterator = tAnswer.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tItem) {
            If '$IsObject(tItem) || 'tItem.%IsA("%Library.DynamicObject") Continue
            Set tStatus = tItem.%Get("status")
            Set tDocument = {}
            Do tDocument.%Set("name", tItem.%Get("name"), "string")
            Do tDocument.%Set("deleted", (tStatus = ""), "boolean")
            Do tDocument.%Set("reason", ..DeleteReason(tStatus), "string")
            Do tDocuments.%Push(tDocument)
            If tStatus '= "" Do ..LogFault("DeleteDocs refused one document", $$$ERROR($$$GeneralError, tItem.%Get("name") _ ": " _ tStatus))
        }
        Set pResult = {}
        Do pResult.%Set("documents", tDocuments)
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the delete failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The class an export's or an import's file is resolved through (AD-21). Overridable so a
/// fixture can observe the resolve; production never overrides it.</p>
ClassMethod PathPortClass() As %String
{
    Quit "OcuPilot.Port.PathPort"
}

/// <p>The export's file for <var>pRoot</var> and <var>pPath</var>, resolved and checked exactly as
/// <method>ExportSet</method> checks it before its vendor call, for a mint that must refuse what the
/// write would: <parameter>PAIRS</parameter>, then <method>ExportFile</method>. Nothing is
/// written.</p>
ClassMethod CheckExport(pRoot As %String, pPath As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tFailedPair = ""
        If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(), .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ExportFile(pRoot, pPath, .tResolved, .tAbsent, .pHttpStatus, .pFault)
    } Catch ex {
        Set tSC = ..Fail("the export's file could not be checked", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The export's file: <var>pRoot</var> and <var>pPath</var> resolved through
/// <method>PathPortClass</method> as a <code>file</code> with <parameter>EXPORTOVERWRITES</parameter>,
/// each refusal on its field, then <code>EXPLORER.EXPORT.DIRECTORY</code>, 400 with one violation on
/// <code>path</code>, when the resolved name's directory does not exist; a directory is never
/// created. On success <var>pResolved</var> is the path and <var>pAbsent</var> whether no file stood
/// at it.</p>
ClassMethod ExportFile(pRoot As %String, pPath As %String, Output pResolved As %String, Output pAbsent As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResolved = ""
    Set pAbsent = 0
    Set tPathPort = ..PathPortClass()
    Set tSC = $ClassMethod(tPathPort, "Resolve", pRoot, pPath, $Parameter(tPathPort, "KINDFILE"), ..#ROOTKEY, ..#PATHKEY, .pResolved, .pHttpStatus, .pFault, ..#EXPORTOVERWRITES)
    If $$$ISERR(tSC) {
        Set pResolved = ""
        Quit tSC
    }
    If '##class(%File).DirectoryExists(##class(%File).GetDirectory(pResolved)) {
        Set pResolved = ""
        Quit ..Violation(##class(OcuPilot.Api.AtelierError).#EXPORTDIRECTORY, ##class(OcuPilot.Api.AtelierError).#REASONEXPORTDIRECTORY, ..#PATHKEY, .pHttpStatus, .pFault)
    }
    Set pAbsent = '##class(%File).Exists(pResolved)
    Quit $$$OK
}

/// <p>Export the documents <var>pNames</var> in one call, after <method>PresentSet</method>, its lines
/// the vendor's with each long line put back whole (<method>WholeLines</method>). When
/// <var>pQuery</var> names <code>root</code> or <code>path</code>, the file is resolved and checked
/// (<method>ExportFile</method>) before the vendor call, the lines are written to it
/// (<method>WriteLines</method>), and <var>pResult</var> is <code>{root, path}</code>; a file the call
/// created is deleted when the write fails. Otherwise nothing is written and <var>pResult</var> is
/// <code>{lines}</code>.</p>
ClassMethod ExportSet(pVersion As %Integer, pNamespace As %String, pEndpoint As %String, pNames As %List, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tRoot = $Get(pQuery(..#ROOTKEY))
        Set tPath = $Get(pQuery(..#PATHKEY))
        Set tToFile = (tRoot '= "") || (tPath '= "")
        Set tSC = ..PresentSet(pVersion, pNamespace, pEndpoint, pNames, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If tToFile {
            Set tSC = ..ExportFile(tRoot, tPath, .tResolved, .tAbsent, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
        }
        Set tBody = []
        For tI = 1:1:$ListLength(pNames) {
            Do tBody.%Push($List(pNames, tI), "string")
        }
        Kill tNoParams
        Set tSC = ..Route(pVersion, pNamespace, "ExportToXMLFile", "", .tNoParams, tBody, .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tLines = $Select($IsObject(tAnswer): tAnswer.%Get("content"), 1: "")
        If '$IsObject(tLines) || 'tLines.%IsA("%Library.DynamicArray") {
            Set tSC = ..Fail("ExportToXMLFile answered no content array", $$$ERROR($$$GeneralError, "export answered no content array"), .pHttpStatus, .pFault)
            Quit
        }
        Set tLines = ..WholeLines(tLines)
        If 'tToFile {
            Set pResult = {}
            Do pResult.%Set("lines", tLines)
            Set pHttpStatus = 200
            Quit
        }
        Set tWriteSC = ..WriteLines(tResolved, tLines)
        If $$$ISERR(tWriteSC) {
            If tAbsent && ##class(%File).Exists(tResolved) Do ##class(%File).Delete(tResolved)
            Set tSC = ..Fail("the export's file could not be written", tWriteSC, .pHttpStatus, .pFault)
            Quit
        }
        Set pResult = {}
        Do pResult.%Set(..#ROOTKEY, tRoot, "string")
        Do pResult.%Set(..#PATHKEY, tPath, "string")
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the export failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The export's lines <var>pLines</var>, as the vendor answers them, with each line longer than
/// <parameter>VENDORLINE</parameter> put back together: a line of exactly that length is taken for
/// one such piece and joined to the line after it.</p>
ClassMethod WholeLines(pLines As %DynamicArray) As %DynamicArray
{
    Set tWhole = []
    Set tPending = ""
    Set tJoining = 0
    Set tIterator = pLines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tPending = $Select(tJoining: tPending _ tLine, 1: tLine)
        Set tJoining = ($Length(tLine) = ..#VENDORLINE)
        If 'tJoining Do tWhole.%Push(tPending, "string")
    }
    If tJoining Do tWhole.%Push(tPending, "string")
    Quit tWhole
}

/// <p>Write <var>pLines</var> to <var>pFile</var> as UTF-8 text, each line ended by a line feed,
/// replacing any file at that name once every line is written: the stream writes beside it and its
/// save puts the new file in its place.</p>
ClassMethod WriteLines(pFile As %String, pLines As %DynamicArray) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Set tStream.TranslateTable = "UTF8"
        Set tStream.LineTerminator = $Char(10)
        Set tSC = tStream.LinkToFile(pFile)
        If $$$ISERR(tSC) Quit
        Set tIterator = pLines.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLine) {
            Set tSC = tStream.WriteLine(tLine)
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        Set tSC = tStream.%Save()
        Kill tStream
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The text of the file an import names in <var>pQuery</var>, in <var>pText</var>, with
/// <var>pLabel</var> the name the vendor is handed for it and <var>pExtension</var> its extension in
/// lower case: the server file <code>root</code> and <code>path</code> name, resolved through
/// <method>PathPortClass</method> as a <code>source</code> and read as UTF-8 text
/// (<method>ReadText</method>), or the local file <code>fileName</code> and <code>content</code>
/// send. Refused before any vendor call: 400 <code>PORT.VALIDATION</code> when both files or neither
/// is named, or a <code>fileName</code> is longer than <parameter>MAXFILENAME</parameter> or holds
/// <code>/</code>, <code>\</code> or a control character; the resolve's own refusal on its field; 422
/// <code>EXPLORER.IMPORT.UNREADABLE</code> for an extension outside
/// <parameter>IMPORTEXTENSIONS</parameter>; and 400 <code>EXPLORER.IMPORT.TOOLARGE</code> for text
/// longer than <parameter>MAXIMPORTCHARACTERS</parameter>.</p>
ClassMethod ImportSource(ByRef pQuery, Output pText As %String, Output pLabel As %String, Output pExtension As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pText = ""
    Set pLabel = ""
    Set pExtension = ""
    Set tRoot = $Get(pQuery(..#ROOTKEY))
    Set tPath = $Get(pQuery(..#PATHKEY))
    Set tFileName = $Get(pQuery(..#FILENAMEKEY))
    Set tContent = $Get(pQuery(..#CONTENTKEY))
    Set tServer = (tRoot '= "") || (tPath '= "")
    Set tLocal = (tFileName '= "") || (tContent '= "")
    If tServer = tLocal Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONSOURCE, .pHttpStatus, .pFault)
    If tLocal {
        If (tFileName = "") || ($Length(tFileName) > ..#MAXFILENAME) || (tFileName [ "/") || (tFileName [ "\") || ($ZStrip(tFileName, "*C") '= tFileName) {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONFILENAME, .pHttpStatus, .pFault)
        }
        Set pLabel = tFileName
    } Else {
        Set tPathPort = ..PathPortClass()
        Set tSC = $ClassMethod(tPathPort, "Resolve", tRoot, tPath, $Parameter(tPathPort, "KINDSOURCE"), ..#ROOTKEY, ..#PATHKEY, .tResolved, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Set pLabel = tPath
    }
    Set pExtension = $ZConvert($Piece(pLabel, ".", $Length(pLabel, ".")), "L")
    If ($Length(pLabel, ".") < 2) || '$ListFind($ListFromString(..#IMPORTEXTENSIONS), pExtension) {
        Quit ..Unreadable(.pHttpStatus, .pFault)
    }
    If tLocal {
        If $Length(tContent) > ..#MAXIMPORTCHARACTERS Quit ..TooLarge(.pHttpStatus, .pFault)
        Set pText = tContent
        Quit $$$OK
    }
    Set tSC = ..ReadText(tResolved, .pText, .tTooLarge)
    If $$$ISERR(tSC) Quit ..Fail("the import's file could not be read", tSC, .pHttpStatus, .pFault)
    If tTooLarge {
        Set pText = ""
        Quit ..TooLarge(.pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p><var>pFile</var>'s text, read as UTF-8, in <var>pText</var>; <var>pTooLarge</var> is 1, and
/// <var>pText</var> empty, once it passes <parameter>MAXIMPORTCHARACTERS</parameter>.</p>
ClassMethod ReadText(pFile As %String, Output pText As %String, Output pTooLarge As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pText = ""
    Set pTooLarge = 0
    Try {
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Set tStream.TranslateTable = "UTF8"
        Set tSC = tStream.LinkToFile(pFile)
        If $$$ISERR(tSC) Quit
        While 'tStream.AtEnd {
            Set tChunk = tStream.Read(32000, .tSC)
            If $$$ISERR(tSC) Quit
            If ($Length(pText) + $Length(tChunk)) > ..#MAXIMPORTCHARACTERS {
                Set pTooLarge = 1
                Set pText = ""
                Quit
            }
            Set pText = pText _ tChunk
        }
        Kill tStream
    } Catch ex {
        Set pText = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><var>pText</var> as its lines: split on line feeds, a line feed ending the text adding no empty
/// line, each line's trailing carriage return dropped, and a byte order mark (U+FEFF) leading the
/// first line dropped.</p>
ClassMethod Lines(pText As %String) As %DynamicArray
{
    Set tLines = []
    Set tLength = $Length(pText)
    Set tStart = 1
    While tStart <= tLength {
        Set tEnd = $Find(pText, $Char(10), tStart)
        If tEnd = 0 {
            Set tLine = $Extract(pText, tStart, tLength)
            Set tStart = tLength + 1
        } Else {
            Set tLine = $Extract(pText, tStart, tEnd - 2)
            Set tStart = tEnd
        }
        If $Extract(tLine, *) = $Char(13) Set tLine = $Extract(tLine, 1, *-1)
        If (tLines.%Size() = 0) && ($Extract(tLine) = $Char(65279)) Set tLine = $Extract(tLine, 2, *)
        Do tLines.%Push(tLine, "string")
    }
    Quit tLines
}

/// <p>The document a UDL file's lines <var>pLines</var> hold, named from its header, or
/// <code>""</code> when the header does not parse. Leading lines that are blank, documentation
/// (<code>///</code>), a <code>/* ... */</code> comment, which the vendor's own text keeps above a
/// class, or an <code>Include</code>, <code>IncludeGenerator</code> or <code>Import</code> line are
/// skipped, and the first other line decides, its keyword read in any case:
/// <code>Class &lt;name&gt; ...</code> is <code>&lt;name&gt;.cls</code>, and
/// <code>ROUTINE &lt;name&gt;</code> is <code>&lt;name&gt;.mac</code>, or <code>.inc</code> or
/// <code>.int</code> where it carries <code>[Type=INC]</code> or <code>[Type=INT]</code>. The name must
/// take <parameter>CLASSNAMEPATTERN</parameter>'s or <parameter>ROUTINENAMEPATTERN</parameter>'s
/// shape.</p>
ClassMethod Header(pLines As %DynamicArray) As %String
{
    Set tName = ""
    Set tInComment = 0
    Set tIterator = pLines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tWords = $ZStrip($Translate(tLine, $Char(9), " "), "<=>W")
        If tInComment {
            If tWords [ "*/" Set tInComment = 0
            Continue
        }
        If tWords = "" Continue
        If $Extract(tWords, 1, 3) = "///" Continue
        If $Extract(tWords, 1, 2) = "/*" {
            If '$Find(tWords, "*/", 3) Set tInComment = 1
            Continue
        }
        Set tKeyword = $ZConvert($Piece(tWords, " ", 1), "L")
        If (tKeyword = "include") || (tKeyword = "includegenerator") || (tKeyword = "import") Continue
        If tKeyword = "class" {
            Set tCandidate = $Piece(tWords, " ", 2) _ ".cls"
            If $Match(tCandidate, ..#CLASSNAMEPATTERN) Set tName = tCandidate
            Quit
        }
        If tKeyword '= "routine" Quit
        Set tType = "mac"
        Set tRest = $Piece(tWords, " ", 3, *)
        If tRest '= "" {
            Set tType = ""
            If ($Extract(tRest) = "[") && ($Extract(tRest, *) = "]") {
                Set tType = "mac"
                Set tAttributes = $Extract(tRest, 2, *-1)
                For tI = 1:1:$Length(tAttributes, ",") {
                    Set tAttribute = $ZStrip($Piece(tAttributes, ",", tI), "<>W")
                    If $ZConvert($ZStrip($Piece(tAttribute, "=", 1), "<>W"), "L") '= "type" Continue
                    Set tType = $ZConvert($ZStrip($Piece(tAttribute, "=", 2), "<>W"), "L")
                }
                If '$ListFind($ListBuild("mac", "inc", "int"), tType) Set tType = ""
            }
        }
        If tType = "" Quit
        Set tCandidate = $Piece(tWords, " ", 2) _ "." _ tType
        If $Match(tCandidate, ..#ROUTINENAMEPATTERN) Set tName = tCandidate
        Quit
    }
    Quit tName
}

/// <p>What an import of the file <var>pLabel</var>, whose extension is <var>pExtension</var> and whose
/// lines are <var>pLines</var>, would do in <var>pNamespace</var>: <var>pSummary</var>, one entry per
/// document, <code>&lt;name&gt; new</code> or <code>&lt;name&gt; replaces &lt;ts&gt;</code> where
/// <code>ts</code> is the instance's own version, sorted by character code and joined by
/// <parameter>SUMMARYSEPARATOR</parameter>, then <code> (sha256 &lt;digest&gt;)</code>, the
/// <method>Digest</method> of <var>pLines</var>, so a file rewritten with the same documents reads a
/// different summary (AD-6); <var>pCount</var>, how many; <var>pSelected</var>, the
/// names as the vendor spells them; and <var>pName</var>, a UDL file's one document. An XML export is
/// read through <code>xml/list</code>, whose per-file <code>status</code> or empty list is 422
/// <code>EXPLORER.IMPORT.UNREADABLE</code> with the status logged; a UDL file is named by
/// <method>Header</method>, a header that does not parse being the same refusal, and read through
/// <method>Docs</method>.</p>
ClassMethod Examine(pVersion As %Integer, pNamespace As %String, pLabel As %String, pExtension As %String, pLines As %DynamicArray, Output pSummary As %String, Output pCount As %Integer, Output pSelected As %DynamicArray, Output pName As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pSummary = ""
    Set pCount = 0
    Set pSelected = []
    Set pName = ""
    If pExtension '= "xml" {
        Set pName = ..Header(pLines)
        If pName = "" Quit ..Unreadable(.pHttpStatus, .pFault)
        Set tEndpoint = $Select($ZConvert($Piece(pName, ".", $Length(pName, ".")), "L") = "cls": ..#ENDPOINTCLASSES, 1: ..#ENDPOINTROUTINES)
        Set tSC = ..Docs(pVersion, pNamespace, tEndpoint, $ListBuild(pName), .tDocs, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Set tModified = tDocs.%Get("Modified")
        Set pSummary = pName _ $Select(tModified = "": " new", 1: " replaces " _ $Piece(tModified, "=", 2, *)) _ ..DigestNote(pLines)
        Set pCount = 1
        Do pSelected.%Push(pName, "string")
        Quit $$$OK
    }
    Set tFile = {}
    Do tFile.%Set("file", pLabel, "string")
    Do tFile.%Set("content", pLines)
    Kill tNoParams
    Set tSC = ..Route(pVersion, pNamespace, "ListDocumentsInXMLFiles", "", .tNoParams, [(tFile)], .tAnswer, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tContent = $Select($IsObject(tAnswer): tAnswer.%Get("content"), 1: "")
    Set tEntry = ""
    If $IsObject(tContent) && tContent.%IsA("%Library.DynamicArray") && (tContent.%Size() = 1) Set tEntry = tContent.%Get(0)
    If '$IsObject(tEntry) || 'tEntry.%IsA("%Library.DynamicObject") Quit ..Fail("ListDocumentsInXMLFiles answered no one file", $$$ERROR($$$GeneralError, "xml/list answered no one file"), .pHttpStatus, .pFault)
    Set tStatus = tEntry.%Get("status")
    Set tDocuments = tEntry.%Get("documents")
    If (tStatus '= "") || '$IsObject(tDocuments) || 'tDocuments.%IsA("%Library.DynamicArray") || (tDocuments.%Size() = 0) {
        If tStatus '= "" Do ..LogFault("ListDocumentsInXMLFiles could not read the file", $$$ERROR($$$GeneralError, tStatus), ##class(OcuPilot.Api.AtelierError).#IMPORTUNREADABLE)
        Quit ..Unreadable(.pHttpStatus, .pFault)
    }
    Kill tSorted
    Set tIterator = tDocuments.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tDocument) {
        If '$IsObject(tDocument) Continue
        Set tDocName = tDocument.%Get("name")
        If tDocName = "" Continue
        Set tTs = tDocument.%Get("ts")
        ; Subscripted behind a letter so every name collates as a string, never as a number.
        Set tSorted("n" _ tDocName) = $ListBuild(tDocName, $Select((tTs = "") || (tTs = -1): "", 1: tTs))
    }
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey), 1, tPair)
        If tKey = "" Quit
        Set pSummary = pSummary _ $Select(pSummary = "": "", 1: ..#SUMMARYSEPARATOR) _ $List(tPair, 1) _ $Select($List(tPair, 2) = "": " new", 1: " replaces " _ $List(tPair, 2))
        Do pSelected.%Push($List(tPair, 1), "string")
        Set pCount = pCount + 1
    }
    If pCount = 0 Quit ..Unreadable(.pHttpStatus, .pFault)
    Set pSummary = pSummary _ ..DigestNote(pLines)
    Quit $$$OK
}

/// <p>The note that ends an import's summary: <code> (sha256 &lt;digest&gt;)</code>, the
/// <method>Digest</method> of <var>pLines</var>.</p>
ClassMethod DigestNote(pLines As %DynamicArray) As %String [ Private ]
{
    Quit " (" _ ..#SUMMARYDIGEST _ " " _ ..Digest(pLines) _ ")"
}

/// <p>The SHA-256 digest, as lower-case hexadecimal, of the lines <var>pLines</var> an import read
/// from its file, each written as UTF-8 and ended by a line feed. The import's write compares it as
/// part of the reviewed summary, so it refuses a file whose text changed even where its documents
/// did not (AD-6).</p>
ClassMethod Digest(pLines As %DynamicArray) As %String
{
    Set tStream = ##class(%Stream.TmpBinary).%New()
    Set tIterator = pLines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        For tStart = 1:..#DIGESTCHUNK:$Length(tLine) {
            Do tStream.Write($ZConvert($Extract(tLine, tStart, tStart + ..#DIGESTCHUNK - 1), "O", "UTF8"))
        }
        Do tStream.Write($Char(10))
    }
    Do tStream.Rewind()
    Set tSC = $$$OK
    Set tHash = $System.Encryption.SHAHashStream(256, tStream, .tSC)
    If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD(tHash), "L")
}

/// <p>What an import of the file <var>pQuery</var> names would do in <var>pNamespace</var>
/// (<method>ImportSource</method>, <method>Examine</method>), as <code>{documents, count}</code>.
/// Nothing is written.</p>
ClassMethod Preview(pVersion As %Integer, pNamespace As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tSC = ..ImportSource(.pQuery, .tText, .tLabel, .tExtension, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tLines = ..Lines(tText)
        Set tText = ""
        Set tSC = ..Examine(pVersion, pNamespace, tLabel, tExtension, tLines, .tSummary, .tCount, .tSelected, .tName, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pResult = {}
        Do pResult.%Set(..#DOCUMENTSKEY, tSummary, "string")
        Do pResult.%Set("count", tCount, "number")
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the import preview failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Import the file <var>pQuery</var> names into <var>pNamespace</var>, compiling what it loads when
/// <code>Compile</code> is on, and answer <code>{imported, lines, errors}</code>. In order: a
/// <code>Compile</code> that is not true or false is 400 <code>PORT.VALIDATION</code>; the file is read
/// (<method>ImportSource</method>) and examined (<method>Examine</method>); a summary that differs from
/// the reviewed <code>documents</code> is 409 <code>EXPLORER.IMPORT.CHANGED</code>, with nothing
/// loaded. An XML export is then loaded through <code>xml/load</code> with <code>selected</code> the
/// names the list answered and <parameter>IMPORTCOMPILEFLAGS</parameter> or no flag; a UDL document is
/// saved with <code>PUT doc/&lt;name&gt;?ignoreConflict=1</code> and, when it saved and
/// <code>Compile</code> is on, compiled with <parameter>IMPORTCOMPILEFLAGS</parameter>.</p>
/// <p><code>imported</code> names each document loaded as the vendor spells it, <code>lines</code> is
/// the vendor's console, and <code>errors</code> is true when the compile or the save reported an error
/// or the file carries a <code>status</code>. None of those is a fault: a file's <code>status</code> and
/// a save's error are logged, and never sent (AD-39, AD-61 rule 6).</p>
ClassMethod ImportSet(pVersion As %Integer, pNamespace As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If '..FlagValue($Get(pQuery(..#COMPILEKEY)), .tCompile) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIMPORTCOMPILE, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ImportSource(.pQuery, .tText, .tLabel, .tExtension, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tLines = ..Lines(tText)
        Set tText = ""
        Set tSC = ..Examine(pVersion, pNamespace, tLabel, tExtension, tLines, .tSummary, .tCount, .tSelected, .tName, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If tSummary '= $Get(pQuery(..#DOCUMENTSKEY)) {
            Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.AtelierError).#IMPORTCHANGED, ##class(OcuPilot.Api.AtelierError).#REASONIMPORTCHANGED, .pHttpStatus, .pFault)
            Quit
        }
        Set tImported = []
        Set tConsole = []
        Set tErrors = 0
        If tExtension = "xml" {
            Set tFile = {}
            Do tFile.%Set("file", tLabel, "string")
            Do tFile.%Set("content", tLines)
            Do tFile.%Set("selected", tSelected)
            Kill tParams
            Set tParams("flags") = $Select(tCompile: ..#IMPORTCOMPILEFLAGS, 1: "")
            Set tSC = ..Route(pVersion, pNamespace, "LoadXMLFiles", "", .tParams, [(tFile)], .tAnswer, .pHttpStatus, .pFault, 1, .tLoadConsole, .tLoadErrors)
            If $$$ISERR(tSC) Quit
            Do ..Append(tConsole, tLoadConsole)
            Set tErrors = tLoadErrors
            Set tContent = $Select($IsObject(tAnswer): tAnswer.%Get("content"), 1: "")
            Set tEntry = $Select($IsObject(tContent) && tContent.%IsA("%Library.DynamicArray") && (tContent.%Size() > 0): tContent.%Get(0), 1: "")
            If $IsObject(tEntry) {
                Do ..Append(tImported, tEntry.%Get("imported"))
                If tEntry.%Get("status") '= "" {
                    Set tErrors = 1
                    Do ..LogFault("LoadXMLFiles reported a status for the file", $$$ERROR($$$GeneralError, tEntry.%Get("status")))
                }
            }
        } Else {
            Set tDocument = {"enc": false}
            Do tDocument.%Set("content", tLines)
            Kill tParams
            Set tParams("ignoreConflict") = 1
            Set tSC = ..Route(pVersion, pNamespace, "PutDoc", tName, .tParams, tDocument, .tAnswer, .pHttpStatus, .pFault, 1, .tPutConsole, .tPutErrors)
            If $$$ISERR(tSC) Quit
            Do ..Append(tConsole, tPutConsole)
            If tPutErrors {
                Set tErrors = 1
                Do ..LogFault("PutDoc reported an error saving the document", $$$ERROR($$$GeneralError, tName _ ": " _ $Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: "")))
            } Else {
                Do tImported.%Push(tName, "string")
                If tCompile {
                    Kill tParams
                    Set tParams("flags") = ..#IMPORTCOMPILEFLAGS
                    Set tParams("source") = 0
                    Set tSC = ..Route(pVersion, pNamespace, "Compile", "", .tParams, [(tName)], .tCompiled, .pHttpStatus, .pFault, 1, .tCompileConsole, .tCompileErrors)
                    If $$$ISERR(tSC) Quit
                    Do ..Append(tConsole, tCompileConsole)
                    If tCompileErrors Set tErrors = 1
                }
            }
        }
        Set pResult = {}
        Do pResult.%Set("imported", tImported)
        Do pResult.%Set("lines", tConsole)
        Do pResult.%Set("errors", ''tErrors, "boolean")
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the import failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Save the text <var>pQuery</var> carries as the one document <var>pNames</var> names, in
/// <var>pNamespace</var>, against the version it was read at, and compile it when
/// <code>Compile</code> is on (AD-51, AD-61 rule 3). In order, each refusal sending nothing:</p>
/// <ol>
/// <li>a set of more than one document, a <code>Compile</code> that is not true or false, or an empty
/// <code>version</code>, is 400 <code>PORT.VALIDATION</code>;</li>
/// <li>a <code>content</code> longer than <parameter>MAXIMPORTCHARACTERS</parameter> is 400
/// <code>EXPLORER.SAVE.TOOLARGE</code>;</li>
/// <li>a text whose header (<method>Header</method> of <method>Lines</method>) does not name the
/// document exactly, kind included, is 422 <code>EXPLORER.SAVE.HEADER</code>;</li>
/// <li>a document the namespace no longer holds is <method>PresentSet</method>'s 404, so a save never
/// creates one;</li>
/// <li>the text's lines (<method>Lines</method>, plus an empty last line when the text ends with a line
/// feed) are put with <code>PUT doc/&lt;name&gt;</code>, carrying <code>version</code> as
/// the vendor's <code>If-None-Match</code> and never <code>ignoreConflict</code>, so a document changed
/// since the read is refused 409 <code>EXPLORER.DOCUMENT.CONFLICT</code> and one another process holds
/// 409 <code>EXPLORER.DOCUMENT.LOCKED</code>, neither logged as a fault, and a text the vendor refuses under 200
/// is 422 <code>EXPLORER.SAVE.REFUSED</code>, or 403 <code>PORT.ACCESSDENIED</code> for an access
/// refusal (<method>Outcome</method>);</li>
/// <li>once it saved, with <code>Compile</code> on, the document is compiled with
/// <parameter>IMPORTCOMPILEFLAGS</parameter>.</li>
/// </ol>
/// <p><var>pResult</var> is <code>{lines, errors}</code>, the compiler's console lines and whether it
/// reported an error, when it compiled, and <code>{}</code> otherwise. A compile error is the compile's
/// own result and does not undo the save. The text is never stored or logged.</p>
ClassMethod SaveSet(pVersion As %Integer, pNamespace As %String, pEndpoint As %String, pNames As %List, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If $ListLength(pNames) '= 1 {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONSAVENAMES, .pHttpStatus, .pFault)
            Quit
        }
        Set tName = $List(pNames, 1)
        If '..FlagValue($Get(pQuery(..#COMPILEKEY)), .tCompile) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIMPORTCOMPILE, .pHttpStatus, .pFault)
            Quit
        }
        Set tReadVersion = $Get(pQuery(..#VERSIONKEY))
        If tReadVersion = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONSAVEVERSION, .pHttpStatus, .pFault)
            Quit
        }
        If $Length($Get(pQuery(..#CONTENTKEY))) > ..#MAXIMPORTCHARACTERS {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AtelierError).#SAVETOOLARGE, ##class(OcuPilot.Api.AtelierError).#REASONSAVETOOLARGE, .pHttpStatus, .pFault)
            Quit
        }
        Set tLines = ..Lines($Get(pQuery(..#CONTENTKEY)))
        If $Extract($Get(pQuery(..#CONTENTKEY)), *) = $Char(10) Do tLines.%Push("", "string")
        If ..Header(tLines) '= tName {
            Set tSC = ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AtelierError).#SAVEHEADER, ##class(OcuPilot.Api.AtelierError).#REASONSAVEHEADER, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..PresentSet(pVersion, pNamespace, pEndpoint, pNames, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tDocument = {"enc": false}
        Do tDocument.%Set("content", tLines)
        Kill tNoParams
        Set tSC = ..Route(pVersion, pNamespace, "PutDoc", tName, .tNoParams, tDocument, .tAnswer, .pHttpStatus, .pFault, 0, , , tReadVersion)
        If $$$ISERR(tSC) Quit
        Set pResult = {}
        If tCompile {
            Kill tParams
            Set tParams("flags") = ..#IMPORTCOMPILEFLAGS
            Set tParams("source") = 0
            Set tSC = ..Route(pVersion, pNamespace, "Compile", "", .tParams, [(tName)], .tCompiled, .pHttpStatus, .pFault, 1, .tConsole, .tErrors)
            If $$$ISERR(tSC) Quit
            Do pResult.%Set("lines", $Select($IsObject(tConsole): tConsole, 1: []))
            Do pResult.%Set("errors", ''tErrors, "boolean")
        }
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the save failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Push each string of <var>pFrom</var>, where it is an array, onto <var>pTo</var>.</p>
ClassMethod Append(pTo As %DynamicArray, pFrom) [ Private ]
{
    If '$IsObject(pFrom) || 'pFrom.%IsA("%Library.DynamicArray") Quit
    Set tIterator = pFrom.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        If '$IsObject(tValue) Do pTo.%Push(tValue, "string")
    }
}

/// <p>The refusal of a file an import cannot read: 422 <code>EXPLORER.IMPORT.UNREADABLE</code>.</p>
ClassMethod Unreadable(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AtelierError).#IMPORTUNREADABLE, ##class(OcuPilot.Api.AtelierError).#REASONIMPORTUNREADABLE, .pHttpStatus, .pFault)
}

/// <p>The refusal of a file longer than an import reads: 400 <code>EXPLORER.IMPORT.TOOLARGE</code>.</p>
ClassMethod TooLarge(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AtelierError).#IMPORTTOOLARGE, ##class(OcuPilot.Api.AtelierError).#REASONIMPORTTOOLARGE, .pHttpStatus, .pFault)
}

/// <p>A 400 refusal on one field, as <var>pCode</var> with its sentence, carried again as that field's
/// one violation (AD-39).</p>
ClassMethod Violation(pCode As %String, pReason As %String, pField As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tViolation = {}
    Do tViolation.%Set("field", pField, "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", pReason, "string")
    Set tDetail = {}
    Do tDetail.%Set("violations", [(tViolation)])
    Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, pCode, pReason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The port-owned reason for a deleted document whose vendor status is <var>pStatus</var>:
/// <code>""</code> for one deleted; otherwise, by the vendor's message number, the access sentence
/// for a privilege refusal or a <code>&lt;PROTECT&gt;</code>, the locked sentence for a document
/// another process holds, the absent sentence for one the vendor no longer found, and the failed
/// sentence for anything else (<class>OcuPilot.Api.AtelierError</class>).</p>
ClassMethod DeleteReason(pStatus As %String) As %String
{
    If pStatus = "" Quit ""
    If pStatus [ "<PROTECT>" Quit ##class(OcuPilot.Api.AtelierError).#DELETEACCESS
    Set tCode = ..MessageNumber(pStatus)
    If (tCode '= "") && $ListFind($ListFromString(..#ACCESSDENIEDCODES), tCode) Quit ##class(OcuPilot.Api.AtelierError).#DELETEACCESS
    If tCode = ..#LOCKEDCODE Quit ##class(OcuPilot.Api.AtelierError).#DELETELOCKED
    If (tCode = ..#NODOCUMENTCODE) || ((tCode = 5001) && (pStatus [ "Does Not Exist")) Quit ##class(OcuPilot.Api.AtelierError).#DELETEABSENT
    Quit ##class(OcuPilot.Api.AtelierError).#DELETEFAILED
}

/// <p>The first vendor message number <var>pText</var> names as <code>#&lt;number&gt;:</code>, or
/// <code>""</code>.</p>
ClassMethod MessageNumber(pText As %String) As %String [ Private ]
{
    Set tAt = $Locate(pText, "#[0-9]+:", 1, tEnd, tMatched)
    If tAt = 0 Quit ""
    Quit $Extract(tMatched, 2, *-1)
}

/// <p>One document's structure as rows, and its text in the requested form as
/// <var>pDocument</var>.</p>
/// <p>The name is checked against the endpoint's own shape and the form against
/// <parameter>FORMS</parameter> before any vendor call. The document's index is read first: a
/// document the namespace does not hold is 404 <code>PORT.NOTFOUND</code>. The text is then read
/// as the name itself (<code>udl</code>), its XML export (<code>xml</code>), or the first
/// generated <code>.int</code> the index names (<code>int</code>; an <code>.int</code> document is
/// its own). A form the instance keeps no text for answers <code>available</code> false and an empty
/// <code>content</code>; that is not a fault. A routine the index holds and whose text read answers
/// 404 with no status and no timestamp of its own is kept only as object code, and its document also
/// carries <code>reason</code> <code>objectonly</code>.</p>
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
        Set tObjectOnly = 0
        Set tLines = []
        If tTextName '= "" {
            Set tSC = ..Route(pVersion, pNamespace, "GetDoc", tTextName, .tParams, "", .tText, .pHttpStatus, .pFault)
            ; A routine the index holds whose text the read answers 404 with an empty status and an
            ; empty timestamp is one the instance keeps only as object code; a name it does not hold
            ; answers #16005.
            If $$$ISERR(tSC) && 'tIsClass && (pHttpStatus = 404) && $IsObject($Get(tText)) && (tText.%Get("status") = "") && (tText.%Get("ts") = "") {
                Set tSC = $$$OK
                Set pHttpStatus = 0
                Set pFault = ""
                Set tObjectOnly = 1
                Set tText = ""
            }
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
        If tObjectOnly Do tDocument.%Set("reason", "objectonly", "string")
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
/// <code>&lt;...&gt;</code> tag removed (a <code>&lt;</code> followed by a letter, <code>/</code>,
/// <code>!</code> or <code>?</code>; any other <code>&lt;</code> is text), <code>&amp;lt; &amp;gt; &amp;quot; &amp;#39;</code> and
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
        If (tChar = "<") && ($Extract(tText, tI + 1)?1(1A,1"/",1"!",1"?")) {
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
/// <code>%request.Data</code> and <var>pBody</var>, when it is not <code>""</code>, is a JSON text or
/// a <class>%DynamicAbstractObject</class> sent as an <code>application/json</code> body
/// (<method>OcuPilot.Port.AtelierRequest.SetJsonBody</method>). Trailing route arguments are omitted
/// rather than passed empty. <var>pIfNoneMatch</var>, when it is not <code>""</code>, is seeded as the
/// request's <parameter>IFNONEMATCHVARIABLE</parameter>, the version a save read (AD-61 rule 3).</p>
/// <p>The call runs behind <code>New</code>ed <code>%request</code>, <code>%response</code>,
/// <code>%session</code> and <code>%SourceControl</code>, with fresh stubs. Its output is captured,
/// or, for a route <parameter>FILEDEVICEROUTES</parameter> names, written to a temporary file that is
/// read back and deleted; either way it never reaches the caller's device, which is current again
/// on return. <code>$NAMESPACE</code> is switched to <var>pNamespace</var> immediately around the
/// route call and restored before anything else runs, on every path; no <code>OcuPilot.*</code>
/// class is called while it is switched. The outcome is <method>Outcome</method>'s, to which
/// <var>pSoft</var>, <var>pConsole</var> and <var>pErrors</var> are passed through.</p>
ClassMethod Route(pVersion As %Integer, pNamespace As %String, pMethod As %String, pArg As %String, ByRef pParams, pBody, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pSoft As %Boolean = 0, Output pConsole As %DynamicArray, Output pErrors As %Boolean, pIfNoneMatch As %String = "") As %Status [ Private ]
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
        If $IsObject(pBody) || (pBody '= "") {
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
        If pIfNoneMatch '= "" Set %request.CgiEnvs(..#IFNONEMATCHVARIABLE) = pIfNoneMatch
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
    }
    ; TempFilename creates the file, so it is deleted whether or not it was opened.
    If tFile '= "" Do ##class(%File).Delete(tFile)
    If $IsObject($Get(%response)) Set tHttp = +%response.Status
    If $$$ISERR(tCallSC) && ($System.Status.GetErrorText(tCallSC) [ "<MAXSTRING>") Set tOverflow = 1
    Set tSC = ..Outcome(pMethod, tCallSC, tHttp, tText, tOverflow, .pResult, .pHttpStatus, .pFault, pSoft, .pConsole, .pErrors)
    Quit tSC
}

/// <p>What one route call's outcome means. <var>pText</var> is the captured envelope.</p>
/// <p>An answer at the capture's ceiling is 503 <code>PORT.UNAVAILABLE</code>. A non-2xx status is
/// 404 <code>PORT.NOTFOUND</code> (not logged: a read answered 404 has found an absence), with the
/// envelope's <code>result</code> in <var>pResult</var> where it parses, 400
/// <code>PORT.VALIDATION</code>, 403 <code>PORT.ACCESSDENIED</code>, or the internal fault. Under a
/// 2xx status, an error in the route's own status, in <code>status.errors</code> or in the result's
/// own <code>status</code> is 403 <code>PORT.ACCESSDENIED</code> when it is a
/// <code>&lt;PROTECT&gt;</code> or one of <parameter>ACCESSDENIEDCODES</parameter> (AD-61 rule 6) and
/// the internal fault otherwise, as is an envelope that does not parse. Otherwise <var>pResult</var>
/// is the envelope's <code>result</code>. The vendor's own text is logged on every logged path and
/// never put on the wire.</p>
/// <p>With <var>pSoft</var> (a compile, or an import's load or save), such an error under a 2xx
/// status is the call's own result rather than a fault: <var>pErrors</var> is 1, and <var>pConsole</var> is the envelope's
/// <code>console</code> array on every 2xx answer that parses.</p>
/// <p><code>PutDoc</code>'s own answers (AD-61 rule 6): 409, a version that no longer matches, is 409
/// <code>EXPLORER.DOCUMENT.CONFLICT</code>, and 423, a document another process holds, is 409
/// <code>EXPLORER.DOCUMENT.LOCKED</code>, neither logged as a fault and neither carrying the vendor's
/// text, the lock's text going to the log at information severity (<method>LogNote</method>); and,
/// without <var>pSoft</var>, an error under a 2xx status that is not an access refusal is 422
/// <code>EXPLORER.SAVE.REFUSED</code>, logged.</p>
ClassMethod Outcome(pMethod As %String, pCallSC As %Status, pHttp As %Integer, pText As %String, pOverflow As %Boolean, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pSoft As %Boolean = 0, Output pConsole As %DynamicArray, Output pErrors As %Boolean) As %Status [ Private ]
{
    Set pResult = ""
    Set pConsole = ""
    Set pErrors = 0
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
    Set tCodes = ""
    Set tParsed = $IsObject(tEnvelope) && tEnvelope.%IsA("%Library.DynamicObject")
    If tParsed {
        Set tStatusPart = tEnvelope.%Get("status")
        If $IsObject(tStatusPart) && $IsObject(tStatusPart.%Get("errors")) && (tStatusPart.%Get("errors").%Size() > 0) {
            Set tErrors = tStatusPart.%Get("errors").%ToJSON()
            Set tErrorIterator = tStatusPart.%Get("errors").%GetIterator()
            While tErrorIterator.%GetNext(.tErrorIndex, .tError) {
                If $IsObject(tError) && (tError.%Get("code") '= "") Set tCodes = tCodes _ $ListBuild("" _ tError.%Get("code"))
            }
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
            If tParsed Set pResult = tEnvelope.%Get("result")
            Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ..#REASONNOTFOUND, .pHttpStatus, .pFault)
        }
        ; A save's version that no longer matches, and a document another process holds, are answers
        ; rather than faults, so neither is logged as one; the lock's text names a user and a process,
        ; so it is logged at information severity and never sent (AD-61 rule 6).
        If (pMethod = "PutDoc") && (pHttp = 409) {
            Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.AtelierError).#DOCUMENTCONFLICT, ##class(OcuPilot.Api.AtelierError).#REASONDOCUMENTCONFLICT, .pHttpStatus, .pFault)
        }
        If (pMethod = "PutDoc") && (pHttp = 423) {
            Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.AtelierError).#DOCUMENTLOCKED, ##class(OcuPilot.Api.AtelierError).#REASONDOCUMENTLOCKED, .pHttpStatus, .pFault)
            Do ..LogNote(pMethod _ " found the document held by another process", tRawSC, pFault.code)
            Quit tSC
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
    If tParsed && pSoft {
        Set tConsolePart = tEnvelope.%Get("console")
        Set pConsole = $Select($IsObject(tConsolePart) && tConsolePart.%IsA("%Library.DynamicArray"): tConsolePart, 1: [])
        Set pErrors = ($$$ISERR(pCallSC) || (tErrors '= ""))
        Set pResult = tEnvelope.%Get("result")
        Set pHttpStatus = pHttp
        Quit $$$OK
    }
    If $$$ISERR(pCallSC) || (tErrors '= "") || 'tParsed {
        If (tRaw [ "<PROTECT>") || ..AccessDenied(tCodes, tRaw) {
            Set tSC = ..Refuse(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED, ..#REASONACCESSDENIED, .pHttpStatus, .pFault)
            Do ..LogFault(pMethod _ " was refused", tRawSC, pFault.code)
            Quit tSC
        }
        If (pMethod = "PutDoc") && tParsed {
            Set tSC = ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AtelierError).#SAVEREFUSED, ##class(OcuPilot.Api.AtelierError).#REASONSAVEREFUSED, .pHttpStatus, .pFault)
            Do ..LogFault(pMethod _ " refused the text", tRawSC, pFault.code)
            Quit tSC
        }
        Quit ..Fail(pMethod _ " failed", tRawSC, .pHttpStatus, .pFault)
    }
    Set pResult = tEnvelope.%Get("result")
    Set pHttpStatus = pHttp
    Quit $$$OK
}

/// <p>Whether a soft error is the vendor's privilege or read-only refusal: a message number in
/// <var>pCodes</var>, or one <var>pRaw</var> names as <code>#&lt;number&gt;:</code>, is one of
/// <parameter>ACCESSDENIEDCODES</parameter>.</p>
ClassMethod AccessDenied(pCodes As %List, pRaw As %String) As %Boolean [ Private ]
{
    Set tDenied = $ListFromString(..#ACCESSDENIEDCODES)
    Set tFound = 0
    For tI = 1:1:$ListLength(tDenied) {
        Set tCode = $List(tDenied, tI)
        If $ListFind(pCodes, tCode) || (pRaw [ ("#" _ tCode _ ":")) {
            Set tFound = 1
            Quit
        }
    }
    Quit tFound
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture
/// the line; production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>Send a raw status that answers rather than faults to the log at information severity, and
/// nowhere else (AD-39, AD-61 rule 6): it never reaches the alert log. Overridable so a fixture can
/// capture the line; production never overrides it.</p>
ClassMethod LogNote(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Try {
        Set tData = {}
        Do tData.%Set("code", pCode, "string")
        Do tData.%Set("status", $System.Status.GetErrorText(pStatus), "string")
        Do ##class(OcuPilot.Kernel.Audit.Log).Info(..#LOGSUBSYSTEM, pMessage, tData)
    } Catch {
    }
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

/// <p><code>objectscript</code> for a list endpoint's <parameter>TYPECOMPILE</parameter>,
/// <parameter>TYPEDELETE</parameter>, <parameter>TYPEEXPORT</parameter>,
/// <parameter>TYPEIMPORT</parameter> and <parameter>TYPESAVE</parameter>, the writes this port
/// carries; <code>""</code> for every read, which has no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint '= ..#ENDPOINTCLASSES) && (pEndpoint '= ..#ENDPOINTROUTINES) Quit ""
    If (pType = ..#TYPECOMPILE) || (pType = ..#TYPEDELETE) || (pType = ..#TYPEEXPORT) || (pType = ..#TYPEIMPORT) || (pType = ..#TYPESAVE) Quit "objectscript"
    Quit ""
}

/// <p><method>Invoke</method>'s branches as a script (AD-59), in the namespace <code>namespace</code>
/// names: <parameter>TYPECOMPILE</parameter> is the compile the route makes,
/// <code>$System.OBJ.CompileList</code> over the set with the flags <method>CompileFlags</method>
/// builds, <parameter>TYPEDELETE</parameter> the route's <code>%RoutineMgr</code>
/// <code>Delete</code> of each document, <parameter>TYPEEXPORT</parameter> the file
/// <code>##class(%File).NormalizeFilename(path, root)</code> names and
/// <code>$System.OBJ.Export</code> of the set to it, and <parameter>TYPEIMPORT</parameter> that file
/// and <code>$System.OBJ.Load</code> of it, with <parameter>IMPORTCOMPILEFLAGS</parameter> when
/// <code>Compile</code> is on, and <parameter>TYPESAVE</parameter> the text saved as the one document
/// <code>names</code> holds -- <code>%Compiler.UDL.TextServices.SetTextFromString</code> for a class,
/// a <code>%Routine</code> for a routine -- then, when <code>Compile</code> is on,
/// <code>$System.OBJ.CompileList</code> of it with <parameter>IMPORTCOMPILEFLAGS</parameter>. The
/// save's text is rendered as the placeholder <code>"&lt;content&gt;"</code>, never as the text. A
/// read writes nothing and answers no step. Every value is rendered as a string literal, so nothing
/// the query carries runs as code.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tText = " Set $NAMESPACE = " _ ..Literal($Get(pQuery(..#NAMESPACEKEY)))
    Set tNames = $Get(pQuery(..#NAMESKEY))
    If pType = ..#TYPECOMPILE {
        Do ..FlagValue($Get(pQuery(..#KEEPSOURCEKEY)), .tKeep)
        Do ..FlagValue($Get(pQuery(..#COMPILEDEPENDENTSKEY)), .tDependents)
        Do ..FlagValue($Get(pQuery(..#SKIPUPTODATEKEY)), .tSkip)
        Set tText = tText _ $Char(10) _ " Set tSC = $System.OBJ.CompileList(" _ ..Literal(tNames) _ ", " _ ..Literal(..CompileFlags(tKeep, tDependents, tSkip)) _ ")"
        Set tText = tText _ $Char(10) _ " Do $System.Status.DisplayError(tSC)"
    } ElseIf (pType = ..#TYPEEXPORT) || (pType = ..#TYPEIMPORT) {
        Set tText = tText _ $Char(10) _ " Set tFile = ##class(%File).NormalizeFilename(" _ ..Literal($Get(pQuery(..#PATHKEY))) _ ", " _ ..Literal($Get(pQuery(..#ROOTKEY))) _ ")"
        If pType = ..#TYPEEXPORT {
            Set tText = tText _ $Char(10) _ " Set tSC = $System.OBJ.Export(" _ ..Literal(tNames) _ ", tFile, ""-d"")"
        } Else {
            Do ..FlagValue($Get(pQuery(..#COMPILEKEY)), .tCompile)
            Set tText = tText _ $Char(10) _ " Set tSC = $System.OBJ.Load(tFile, " _ ..Literal($Select(tCompile: ..#IMPORTCOMPILEFLAGS, 1: "")) _ ")"
        }
        Set tText = tText _ $Char(10) _ " Do $System.Status.DisplayError(tSC)"
    } ElseIf pType = ..#TYPESAVE {
        Set tPlaceholder = ..Literal("<" _ ..#CONTENTKEY _ ">")
        If pEndpoint = ..#ENDPOINTCLASSES {
            Set tText = tText _ $Char(10) _ " Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString($NAMESPACE, " _ ..Literal($Piece(tNames, ".", 1, $Length(tNames, ".") - 1)) _ ", " _ tPlaceholder _ ", $Char(10))"
        } Else {
            Set tText = tText _ $Char(10) _ " Set tRoutine = ##class(%Routine).%New(" _ ..Literal(tNames) _ ")"
            Set tText = tText _ $Char(10) _ " Do tRoutine.Clear()"
            Set tText = tText _ $Char(10) _ " Do tRoutine.Write(" _ tPlaceholder _ ")"
            Set tText = tText _ $Char(10) _ " Set tSC = tRoutine.Save()"
        }
        Set tText = tText _ $Char(10) _ " Do $System.Status.DisplayError(tSC)"
        Do ..FlagValue($Get(pQuery(..#COMPILEKEY)), .tCompile)
        If tCompile {
            Set tText = tText _ $Char(10) _ " Set tSC = $System.OBJ.CompileList(" _ ..Literal(tNames) _ ", " _ ..Literal(..#IMPORTCOMPILEFLAGS) _ ")"
            Set tText = tText _ $Char(10) _ " Do $System.Status.DisplayError(tSC)"
        }
    } Else {
        Set tText = tText _ $Char(10) _ " For tI = 1:1:$Length(" _ ..Literal(tNames) _ ", "","") {"
        Set tText = tText _ $Char(10) _ "     Set tSC = ##class(%RoutineMgr).Delete($Piece(" _ ..Literal(tNames) _ ", "","", tI))"
        Set tText = tText _ $Char(10) _ "     Do $System.Status.DisplayError(tSC)"
        Set tText = tText _ $Char(10) _ " }"
    }
    Set tStep = {}
    Do tStep.%Set("kind", "objectscript", "string")
    Do tStep.%Set("text", tText, "string")
    Quit [(tStep)]
}

/// <p><var>pValue</var> as an ObjectScript string literal, a control character spelled as a
/// <code>$Char</code>.</p>
ClassMethod Literal(pValue As %String) As %String [ Private ]
{
    Set tText = """" _ $Replace(pValue, """", """""") _ """"
    For tCode = 0:1:31 {
        If tText [ $Char(tCode) Set tText = $Replace(tText, $Char(tCode), """_$Char(" _ tCode _ ")_""")
    }
    Quit tText
}

}
