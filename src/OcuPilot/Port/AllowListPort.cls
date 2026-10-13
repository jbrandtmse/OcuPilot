/// <p>The port to a person's write of the directory allow-list (AD-21's tenth case, AD-51, AD-52, Story 18.42):
/// <class>OcuPilot.Port.AdminPort</class> with one composed endpoint, <parameter>ENDPOINT</parameter>, that adds,
/// changes and removes entries of the purpose <parameter>OcuPilot.Port.PathPort.PURPOSE</parameter> alone, through
/// <code>FSAccess.Path</code> <code>PUT</code> and <code>DELETE</code> and <code>FSAccess.Purpose</code>
/// <code>PUT</code>. It names no vendor class.</p>
/// <p><b>Its gate is <class>OcuPilot.Port.PathPort</class>'s</b> (AD-29): <parameter>OcuPilot.Port.PathPort.PAIRS</parameter>,
/// checked in the calling process before any other step, refused 403 <code>PORT.ACCESSDENIED</code> naming the pair that
/// failed. Every <code>FSAccess</code> call goes through <method>AdminPortClass</method> and every read of the roots
/// through <method>PathPortClass</method>, so a test counts them.</p>
/// <p><b><code>GET</code></b> reads the roots fresh (<method>OcuPilot.Port.PathPort.Roots</method>) and, while the list is
/// unrestricted, the stored paths, and answers <code>{Purpose, Restricted, Paths, Roots, Action, Directory,
/// NewDirectory, Result}</code>: <code>Roots</code> what the list allows now, <code>Paths</code> what it stores, and
/// <code>Result</code> the roots the change in the query would leave (the roots themselves when the query names none).
/// A change the matrix refuses is refused here, so the route's read, the write and its read-back all read one verdict.</p>
/// <p><b><code>PUT</code></b> reads again, applies the same matrix and runs its sequence, one vendor write after
/// another, stopping at the first that fails. It records <code>SecurityChange</code> with the roots before and after
/// when every step ran, or when a partial run moved the roots or the stored paths. It answers the state it left, or the
/// fault of the step that failed, the steps before it kept. The matrix, over a
/// directory that is absolute, at most <parameter>OcuPilot.Api.AllowListError.DIRECTORYMAX</parameter> characters once
/// normalized and free of control characters, compared as <code>%File.NormalizeDirectory</code> spells it:</p>
/// <ul>
/// <li><b>add, restricted</b>: refused <code>LISTED</code> when listed, <code>NODIRECTORY</code> when the server has no
/// such directory; else <code>Path</code> <code>PUT</code>.</li>
/// <li><b>add, unrestricted</b> (the purpose absent or its flag off): refused <code>NODIRECTORY</code>; else the
/// manager directory is stored unless it is, the directory is stored unless it is, and <code>Purpose</code>
/// <code>PUT {Restricted: true}</code> last, so a step that fails leaves the roots as they were. A path the list
/// already stores becomes a root with them, as the vendor's own restriction keeps it.</li>
/// <li><b>change</b>: the old directory must be listed (<code>NOTLISTED</code>), the new one as for an add; <code>PUT</code>
/// the new, then <code>DELETE</code> the old.</li>
/// <li><b>remove</b>: the directory must be listed (<code>NOTLISTED</code>); <code>DELETE</code>. Removing the last entry
/// leaves a restricted list with no root, which allows nothing.</li>
/// <li>While unrestricted, the list's one entry is the manager directory: a change or a remove of it is
/// <code>FALLBACK</code>, and any other directory is <code>NOTLISTED</code>.</li>
/// </ul>
/// <p>A refusal made before a write is exact and logs nothing; no write is sent for it. A name other than
/// <parameter>ACTIONS</parameter>, a missing directory and a new directory outside a change are 400
/// <code>TOOL.ARGUMENTS</code>, and a query naming another purpose is too.</p>
/// <p>Seams a test subclass overrides: <method>AdminPortClass</method> and <method>PathPortClass</method>. Production
/// overrides neither.</p>
Class OcuPilot.Port.AllowListPort Extends OcuPilot.Port.AdminPort
{

/// <p>The one composed endpoint.</p>
Parameter ENDPOINT = "AllowList";

/// <p>The writes whose vendor calls this port composes from the query's <code>Action</code>, <code>Directory</code> and
/// <code>NewDirectory</code> and sends no body for (AD-51).</p>
Parameter COMPOSEDTYPES = "AllowList/PUT";

/// <p>The admin API writes this port issues of its own for the endpoint's one write type, reached through that tool.</p>
Parameter DELEGATEDTYPES = "FSAccess.Path/PUT,FSAccess.Path/DELETE,FSAccess.Purpose/PUT";

/// <p>The query keys: the vendor's own for the purpose and the root path, and the tool's for the change.</p>
Parameter PURPOSEKEY = "purpose";

Parameter ROOTPATHKEY = "rootPath";

Parameter ACTIONKEY = "Action";

Parameter DIRECTORYKEY = "Directory";

Parameter NEWDIRECTORYKEY = "NewDirectory";

/// <p>The actions a change names, comma-separated.</p>
Parameter ACTIONS = "add,change,remove";

/// <p>The read ceiling the roots and the stored paths are read under.</p>
Parameter ROOTSMAX As INTEGER = 1000;

/// <p>The entity type and verbs the audit row carries.</p>
Parameter ENTITYTYPE = "allowed-directory";

Parameter VERBADDED = "added";

Parameter VERBCHANGED = "changed";

Parameter VERBREMOVED = "removed";

/// <p>The script's note on an add (<method>Snippet</method>): the calls the write adds on a list that is not
/// restricted yet, which a script cannot know to make.</p>
Parameter UNRESTRICTEDNOTE = "On a list that is not restricted yet, the add first stores the manager directory with an FSAccess.Path PUT and ends with an FSAccess.Purpose PUT that sets Restricted to true.";

/// <p>The log subsystem a raw fault is written under.</p>
Parameter LOGSUBSYSTEM = "allowlistport";

/// <p>The class every <code>FSAccess</code> call goes through. Overridable so a fixture can count the calls; production
/// never overrides it.</p>
ClassMethod AdminPortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>The class the roots and the gate are read through. Overridable for the reason <method>AdminPortClass</method>
/// is; production never overrides it.</p>
ClassMethod PathPortClass() As %String
{
    Quit "OcuPilot.Port.PathPort"
}

/// <p>One <code>FSAccess</code> call through <method>AdminPortClass</method>.</p>
ClassMethod Send(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit $ClassMethod(..AdminPortClass(), "Invoke", pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var> (the header above). <var>pQuery</var> carries
/// <parameter>PURPOSEKEY</parameter> and the change's <parameter>ACTIONKEY</parameter>,
/// <parameter>DIRECTORYKEY</parameter> and <parameter>NEWDIRECTORYKEY</parameter>; <var>pBody</var> is not read. Any
/// other endpoint is the admin port's own.</p>
/// <p>On success, at 200, <var>pResult</var> is the answer the header describes. Otherwise an error status is returned,
/// <var>pHttpStatus</var> is the status to answer with and <var>pFault</var> the wire fault.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the route holds the target (AD-34).</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint '= ..#ENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If (pType '= "GET") && (pType '= "PUT") {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "This instance does not implement that operation", .pHttpStatus, .pFault)
            Quit
        }
        If '$ClassMethod(..PathPortClass(), "Gate", .tFailedPair) {
            Set tSC = ..GateDenied(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tPurpose = $Parameter(..PathPortClass(), "PURPOSE")
        If $Data(pQuery(..#PURPOSEKEY)) && ($Get(pQuery(..#PURPOSEKEY)) '= tPurpose) {
            Set tSC = ..Arguments("the allow-list is the purpose " _ tPurpose _ " and no other", .pHttpStatus, .pFault)
            Quit
        }
        Set tAction = $Get(pQuery(..#ACTIONKEY))
        Set tDirectory = $Get(pQuery(..#DIRECTORYKEY))
        Set tNew = $Get(pQuery(..#NEWDIRECTORYKEY))
        ; Pure checks first: a request that names no change reads nothing, and one that is malformed reads nothing either.
        Set tChange = (tAction '= "") || (tDirectory '= "") || (tNew '= "")
        If (pType = "PUT") && (tAction = "") {
            Set tSC = ..Arguments("name the action: add, change or remove", .pHttpStatus, .pFault)
            Quit
        }
        If tChange {
            Set tSC = ..ShapeProblems(tAction, tDirectory, tNew, .tDirectoryNormal, .tNewNormal, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
        }

        Set tSC = ..State(.tRestricted, .tPaths, .tRoots, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tResult = tRoots
        If tChange {
            Set tSC = ..Plan(tAction, tDirectory, tNew, tDirectoryNormal, tNewNormal, tRestricted, tPaths, tRoots, .tSteps, .tResult, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
        }
        If pType = "GET" {
            Set pResult = ..Row(tPurpose, tRestricted, tPaths, tRoots, tAction, tDirectory, tNew, tResult)
            Set pHttpStatus = 200
            Quit
        }

        Set tSC = ..Execute(tSteps, tPurpose, .tAllRan, .pHttpStatus, .pFault)
        ; The roots as the instance holds them now, which the audit row and the answer both carry.
        Set tAfterSC = ..State(.tAfterRestricted, .tAfterPaths, .tAfterRoots, .tAfterHttp, .tAfterFault)
        If $$$ISERR(tAfterSC) {
            Set tAfterRestricted = tRestricted
            Set tAfterPaths = tPaths
            Set tAfterRoots = $Select($$$ISOK(tSC): tResult, 1: tRoots)
        }
        If tAllRan || (tAfterRoots '= tRoots) || (tAfterPaths '= tPaths) Do ..Audit(tAction, tPurpose, tRoots, tAfterRoots)
        If $$$ISERR(tSC) Quit
        Set pResult = ..Row(tPurpose, tAfterRestricted, tAfterPaths, tAfterRoots, tAction, tDirectory, tNew, tAfterRoots)
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Internal("the allow-list call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The codes a write's fresh read refuses with once the change has run, which the tool names as its
/// <method>OcuPilot.Screen.Tool.Write.PreconditionCodes</method> without naming <class>OcuPilot.Api.AllowListError</class>.</p>
ClassMethod PreconditionCodes() As %List
{
    Quit ##class(OcuPilot.Api.AllowListError).PreconditionCodes()
}

/// <p>The state of the list now: whether it is restricted in <var>pRestricted</var>, the paths it stores in
/// <var>pPaths</var> and the roots it allows in <var>pRoots</var>, each a <class>%List</class> of normalized
/// directories in the vendor's order. The roots are <method>OcuPilot.Port.PathPort.Roots</method>'s; while the list is
/// unrestricted the stored paths are read from <code>FSAccess.Path</code> <code>LIST</code>, where a 404 is a purpose
/// that does not exist and so no path. Restricted, the stored paths are the roots. An error status carries
/// <var>pHttpStatus</var> and <var>pFault</var>.</p>
ClassMethod State(Output pRestricted As %Boolean, Output pPaths As %List, Output pRoots As %List, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRestricted = 0
    Set pPaths = ""
    Set pRoots = ""
    Set tSC = $ClassMethod(..PathPortClass(), "Roots", ..#ROOTSMAX, .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set pRoots = pRoots _ $ListBuild(tRow.%Get("Directory"))
    }
    ; A restricted list with no root answers no row; an unrestricted one answers its one fallback row, flag off.
    Set pRestricted = (tRows.%Size() = 0) || (tRows.%Get(0).%Get("Restricted") = 1)
    If pRestricted {
        Set pPaths = pRoots
        Quit $$$OK
    }
    Set tPurpose = $Parameter(..PathPortClass(), "PURPOSE")
    Kill tQuery
    Set tQuery(..#PURPOSEKEY) = tPurpose
    Set tQuery("maxRows") = ..#ROOTSMAX
    Set tListSC = ..Send("FSAccess.Path", "LIST", .tQuery, "", .tList, .tHttp, .tFault)
    If $$$ISERR(tListSC) {
        If tHttp = 404 Quit $$$OK
        Set pHttpStatus = tHttp
        Set pFault = tFault
        Quit tListSC
    }
    If '$IsObject(tList) || 'tList.%IsA("%Library.DynamicArray") {
        Quit ..Internal("the stored paths answered something other than a list", $$$ERROR($$$GeneralError, "not a list"), .pHttpStatus, .pFault)
    }
    Set tIterator = tList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If $IsObject(tEntry) && (tEntry.%Get("RootPath") '= "") Set pPaths = pPaths _ $ListBuild(tEntry.%Get("RootPath"))
    }
    Quit $$$OK
}

/// <p>The pure checks of a change, before anything is read: <var>pAction</var> is one of
/// <parameter>ACTIONS</parameter>, <var>pDirectory</var> is named and <var>pNewDirectory</var> is named by a change
/// and by no other action (400 <code>TOOL.ARGUMENTS</code>), and each directory is one
/// <method>Normalized</method> admits (400 <code>ALLOWLIST.PATH</code> on its field). The normalized directories come
/// back in <var>pDirectoryNormal</var> and <var>pNewNormal</var>.</p>
ClassMethod ShapeProblems(pAction As %String, pDirectory As %String, pNewDirectory As %String, Output pDirectoryNormal As %String, Output pNewNormal As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pDirectoryNormal = ""
    Set pNewNormal = ""
    If '$ListFind($ListFromString(..#ACTIONS), pAction) Quit ..Arguments("the action is add, change or remove", .pHttpStatus, .pFault)
    If pDirectory = "" Quit ..Arguments("name the directory", .pHttpStatus, .pFault)
    If (pAction = "change") && (pNewDirectory = "") Quit ..Arguments("a change names the new directory", .pHttpStatus, .pFault)
    If (pAction '= "change") && (pNewDirectory '= "") Quit ..Arguments("only a change names a new directory", .pHttpStatus, .pFault)
    Set pDirectoryNormal = ..Normalized(pDirectory)
    If pDirectoryNormal = "" Quit ..Violation(##class(OcuPilot.Api.AllowListError).#PATH, ..#DIRECTORYKEY, 400, .pHttpStatus, .pFault)
    If pAction = "change" {
        Set pNewNormal = ..Normalized(pNewDirectory)
        If pNewNormal = "" Quit ..Violation(##class(OcuPilot.Api.AllowListError).#PATH, ..#NEWDIRECTORYKEY, 400, .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>The matrix over the state read: the steps of the change and the roots it would leave, or a refusal. Each step is
/// <code>$ListBuild("put", directory)</code>, <code>$ListBuild("delete", directory)</code> or
/// <code>$ListBuild("restrict")</code>, in the order they run. A refusal is an error status with its
/// <code>ALLOWLIST.*</code> code on the field it concerns; nothing has been sent. The directories are
/// <var>pDirectoryNormal</var> and <var>pNewNormal</var> from <method>ShapeProblems</method>.</p>
ClassMethod Plan(pAction As %String, pDirectory As %String, pNewDirectory As %String, pDirectoryNormal As %String, pNewNormal As %String, pRestricted As %Boolean, pPaths As %List, pRoots As %List, Output pSteps As %List, Output pResult As %List, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pSteps = ""
    Set pResult = pRoots
    Set tManager = ..ManagerNormalized()
    Set tField = ..#DIRECTORYKEY
    If pAction = "add" {
        If 'pRestricted {
            If '..DirectoryExists(pDirectoryNormal) Quit ..Violation(##class(OcuPilot.Api.AllowListError).#NODIRECTORY, tField, 422, .pHttpStatus, .pFault)
            If '$ListFind(pPaths, tManager) Set pSteps = pSteps _ $ListBuild($ListBuild("put", tManager))
            If (pDirectoryNormal '= tManager) && '$ListFind(pPaths, pDirectoryNormal) Set pSteps = pSteps _ $ListBuild($ListBuild("put", pDirectoryNormal))
            Set pSteps = pSteps _ $ListBuild($ListBuild("restrict"))
            Set pResult = ..Ordered(pPaths _ $ListBuild(tManager, pDirectoryNormal))
            Quit $$$OK
        }
        If $ListFind(pRoots, pDirectoryNormal) Quit ..Violation(##class(OcuPilot.Api.AllowListError).#LISTED, tField, 409, .pHttpStatus, .pFault)
        If '..DirectoryExists(pDirectoryNormal) Quit ..Violation(##class(OcuPilot.Api.AllowListError).#NODIRECTORY, tField, 422, .pHttpStatus, .pFault)
        Set pSteps = $ListBuild($ListBuild("put", pDirectoryNormal))
        Set pResult = ..Ordered(pRoots _ $ListBuild(pDirectoryNormal))
        Quit $$$OK
    }
    ; A change or a remove names an entry of the list as it is shown: while unrestricted, that is the manager directory.
    If 'pRestricted {
        If pDirectoryNormal = tManager Quit ..Violation(##class(OcuPilot.Api.AllowListError).#FALLBACK, tField, 409, .pHttpStatus, .pFault)
        Quit ..Violation(##class(OcuPilot.Api.AllowListError).#NOTLISTED, tField, 409, .pHttpStatus, .pFault)
    }
    If '$ListFind(pRoots, pDirectoryNormal) Quit ..Violation(##class(OcuPilot.Api.AllowListError).#NOTLISTED, tField, 409, .pHttpStatus, .pFault)
    Set tKept = ..Without(pRoots, pDirectoryNormal)
    If pAction = "remove" {
        Set pSteps = $ListBuild($ListBuild("delete", pDirectoryNormal))
        Set pResult = tKept
        Quit $$$OK
    }
    Set tField = ..#NEWDIRECTORYKEY
    If $ListFind(pRoots, pNewNormal) Quit ..Violation(##class(OcuPilot.Api.AllowListError).#LISTED, tField, 409, .pHttpStatus, .pFault)
    If '..DirectoryExists(pNewNormal) Quit ..Violation(##class(OcuPilot.Api.AllowListError).#NODIRECTORY, tField, 422, .pHttpStatus, .pFault)
    Set pSteps = $ListBuild($ListBuild("put", pNewNormal), $ListBuild("delete", pDirectoryNormal))
    Set pResult = ..Ordered(tKept _ $ListBuild(pNewNormal))
    Quit $$$OK
}

/// <p>Run <var>pSteps</var> in order, stopping at the first that fails, whose status, <var>pHttpStatus</var> and
/// <var>pFault</var> are the answer. <var>pAllRan</var> is 1 when every step ran. The vendor writes are
/// <code>FSAccess.Path</code> <code>PUT</code> and <code>DELETE</code> of one directory and
/// <code>FSAccess.Purpose</code> <code>PUT</code> of <code>{Restricted: true}</code>.</p>
ClassMethod Execute(pSteps As %List, pPurpose As %String, Output pAllRan As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pAllRan = 0
    Set pHttpStatus = 200
    Set pFault = ""
    For tI = 1:1:$ListLength(pSteps) {
        Set tStep = $List(pSteps, tI)
        Kill tQuery
        Set tQuery(..#PURPOSEKEY) = pPurpose
        If $List(tStep, 1) = "restrict" {
            Set tSC = ..Send("FSAccess.Purpose", "PUT", .tQuery, {"Restricted": true}, .tResult, .pHttpStatus, .pFault)
        } Else {
            Set tQuery(..#ROOTPATHKEY) = $List(tStep, 2)
            Set tSC = ..Send("FSAccess.Path", $Select($List(tStep, 1) = "put": "PUT", 1: "DELETE"), .tQuery, "", .tResult, .pHttpStatus, .pFault)
        }
        If $$$ISERR(tSC) Quit
    }
    Set pAllRan = $$$ISOK(tSC)
    Quit tSC
}

/// <p>Record <code>SecurityChange</code> for an allow-list write: the roots before and after (AD-15). It never fails the
/// write.</p>
ClassMethod Audit(pAction As %String, pPurpose As %String, pBefore As %List, pAfter As %List) [ Private ]
{
    Try {
        Set tRoots = {}
        Do tRoots.%Set("old", ..ArrayOf(pBefore))
        Do tRoots.%Set("new", ..ArrayOf(pAfter))
        Set tChanges = {}
        Do tChanges.%Set("roots", tRoots)
        Do ##class(OcuPilot.Kernel.Audit.Event).Record($Case(pAction, "add": ..#VERBADDED, "change": ..#VERBCHANGED, : ..#VERBREMOVED), ..#ENTITYTYPE, pPurpose, tChanges, 1)
    } Catch ex {
        Do ..LogFault("the allow-list change could not be audited", ex.AsStatus())
    }
}

/// <p>The answer row (the header).</p>
ClassMethod Row(pPurpose As %String, pRestricted As %Boolean, pPaths As %List, pRoots As %List, pAction As %String, pDirectory As %String, pNewDirectory As %String, pResult As %List) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Purpose", pPurpose, "string")
    Do tRow.%Set("Restricted", $Select(pRestricted: 1, 1: 0), "boolean")
    Do tRow.%Set("Paths", ..ArrayOf(pPaths))
    Do tRow.%Set("Roots", ..ArrayOf(pRoots))
    Do tRow.%Set("Action", pAction, "string")
    Do tRow.%Set("Directory", pDirectory, "string")
    Do tRow.%Set("NewDirectory", pNewDirectory, "string")
    Do tRow.%Set("Result", ..ArrayOf(pResult))
    Quit tRow
}

/// <p>The list <var>pList</var> as a JSON array of strings.</p>
ClassMethod ArrayOf(pList As %List) As %DynamicArray
{
    Set tArray = []
    For tI = 1:1:$ListLength(pList) Do tArray.%Push($List(pList, tI), "string")
    Quit tArray
}

/// <p>The directories of <var>pList</var> less <var>pOut</var>, order kept.</p>
ClassMethod Without(pList As %List, pOut As %String) As %List [ Private ]
{
    Set tKept = ""
    For tI = 1:1:$ListLength(pList) {
        If $List(pList, tI) '= pOut Set tKept = tKept _ $ListBuild($List(pList, tI))
    }
    Quit tKept
}

/// <p>The directories of <var>pList</var>, each once, in the vendor's order: upper-cased, then as spelled.</p>
ClassMethod Ordered(pList As %List) As %List
{
    Kill tOrder
    For tI = 1:1:$ListLength(pList) {
        Set tPath = $List(pList, tI)
        Set tOrder($ZConvert(tPath, "U"), tPath) = ""
    }
    Set tOrdered = ""
    Set tUpper = ""
    For {
        Set tUpper = $Order(tOrder(tUpper))
        If tUpper = "" Quit
        Set tPath = ""
        For {
            Set tPath = $Order(tOrder(tUpper, tPath))
            If tPath = "" Quit
            Set tOrdered = tOrdered _ $ListBuild(tPath)
        }
    }
    Quit tOrdered
}

/// <p>The normalized spelling of <var>pDirectory</var> (<code>%File.NormalizeDirectory</code>, trailing separator
/// included), or <code>""</code> when it is empty, longer than <parameter>OcuPilot.Api.AllowListError.DIRECTORYMAX</parameter>
/// characters, holds a control character, is not absolute on the server's platform (a leading <code>/</code> on
/// UNIX; a drive or a <code>\\</code> share on Windows), or normalizes to nothing or to something longer than the
/// bound. A string test; nothing here reaches the filesystem.</p>
ClassMethod Normalized(pDirectory As %String) As %String
{
    Set tMax = ##class(OcuPilot.Api.AllowListError).#DIRECTORYMAX
    If (pDirectory = "") || ($Length(pDirectory) > tMax) Quit ""
    If $ZStrip(pDirectory, "*C") '= pDirectory Quit ""
    If '$Match(pDirectory, $Select($System.Version.GetOS() = "Windows": "^([A-Za-z]:[\\/]|\\\\).*", 1: "^/.*")) Quit ""
    Set tNormal = ##class(%File).NormalizeDirectory(pDirectory)
    If $Length(tNormal) > tMax Quit ""
    Quit tNormal
}

/// <p>The manager directory, normalized, read through <method>PathPortClass</method> so a fixture names the same one the
/// roots do.</p>
ClassMethod ManagerNormalized() As %String [ Private ]
{
    Quit ##class(%File).NormalizeDirectory($ClassMethod(..PathPortClass(), "ManagerDirectory"))
}

/// <p>Whether the server has directory <var>pDirectory</var>.</p>
ClassMethod DirectoryExists(pDirectory As %String) As %Boolean
{
    Quit ''##class(%File).DirectoryExists(pDirectory)
}

/// <p>The 403 the gate answers, as <class>OcuPilot.Port.PathPort</class> words it: <code>PORT.ACCESSDENIED</code> on its
/// written sentence, with <code>detail.failedPair</code>.</p>
ClassMethod GateDenied(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tMapSC = ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tIgnored)
    If $$$ISERR(tMapSC) Quit ..Internal("the port's own refusal could not be mapped", tMapSC, .pHttpStatus, .pFault)
    Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, {"failedPair": (pFailedPair)})
}

/// <p>The refusal <var>pCode</var> on <var>pField</var> at <var>pHttp</var>, with its published sentence, carried again as
/// the field's one violation (AD-39). Nothing has been sent.</p>
ClassMethod Violation(pCode As %String, pField As %String, pHttp As %Integer, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tReason = ##class(OcuPilot.Api.AllowListError).ReasonFor(pCode)
    Set tSlug = $Select(pHttp = 400: ##class(OcuPilot.Api.Error).#BADREQUEST, pHttp = 422: ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, 1: ##class(OcuPilot.Api.Error).#CONFLICT)
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push({"field": (pField), "code": (pCode), "reason": (tReason)})
    Quit ..Refuse(pHttp, tSlug, pCode, tReason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The 400 <code>TOOL.ARGUMENTS</code> refusal carrying <var>pProblem</var> as <code>detail.problem</code>.</p>
ClassMethod Arguments(pProblem As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS, .pHttpStatus, .pFault, {"problem": (pProblem)})
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Internal(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p>The script form of the composed write: <code>rest</code>, each step being one of the admin API's own routes. The
/// read has none. Every other pair is the admin port's.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If pEndpoint = ..#ENDPOINT Quit $Select(pType = "PUT": "rest", 1: "")
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s <code>PUT</code> as a script (AD-59): the vendor calls of the change in the query, in the
/// order they run over a restricted list, each through the admin port's script. A script reads no state, so an add
/// ends with a <code>comment</code> step, <parameter>UNRESTRICTEDNOTE</parameter>, naming the two calls the write also
/// makes on a list that is not restricted yet. An action or a directory the port would refuse renders one
/// <code>comment</code> step carrying the refusal's sentence and no call. Every other pair is the admin port's
/// script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint '= ..#ENDPOINT) || (pType '= "PUT") Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    Set tAction = $Get(pQuery(..#ACTIONKEY))
    Set tDirectory = $Get(pQuery(..#DIRECTORYKEY))
    Set tNew = $Get(pQuery(..#NEWDIRECTORYKEY))
    Set tSC = ..ShapeProblems(tAction, tDirectory, tNew, .tDirectoryNormal, .tNewNormal, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit [(..Step("comment", $Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)))]
    Set tPurpose = $Parameter(..PathPortClass(), "PURPOSE")
    Set tSteps = []
    If (tAction = "add") || (tAction = "change") {
        Kill tQuery
        Set tQuery(..#PURPOSEKEY) = tPurpose
        Set tQuery(..#ROOTPATHKEY) = $Select(tAction = "add": tDirectoryNormal, 1: tNewNormal)
        Do ..Append(tSteps, ##super("FSAccess.Path", "PUT", .tQuery, "", pContext))
    }
    If (tAction = "remove") || (tAction = "change") {
        Kill tQuery
        Set tQuery(..#PURPOSEKEY) = tPurpose
        Set tQuery(..#ROOTPATHKEY) = tDirectoryNormal
        Do ..Append(tSteps, ##super("FSAccess.Path", "DELETE", .tQuery, "", pContext))
    }
    If tAction = "add" Do tSteps.%Push(..Step("comment", ..#UNRESTRICTEDNOTE))
    Quit tSteps
}

/// <p>Push every step of <var>pMore</var> onto <var>pSteps</var>.</p>
ClassMethod Append(pSteps As %DynamicArray, pMore As %DynamicArray) [ Private ]
{
    If '$IsObject(pMore) Quit
    Set tIterator = pMore.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        Do pSteps.%Push(tStep)
    }
}

}
