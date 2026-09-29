/// <p>The local databases' port (AD-52, Story 18.3): <class>OcuPilot.Port.AdminPort</class> with four
/// things added, each on a named endpoint, and every other call the admin port's own, unchanged.</p>
/// <p><b>A file read or edit by name finds its directory here.</b> A
/// <parameter>FILEENDPOINT</parameter> <code>GET</code> or <code>PUT</code> whose query carries
/// <code>name</code> and no <code>dir</code> reads the configuration first and addresses its
/// <code>Directory</code>; a remote configuration answers 409
/// <parameter>OcuPilot.Api.DatabaseError.REMOTE</parameter> with no further call. The read answers the
/// vendor's object with <parameter>DIRECTORYFIELD</parameter> added, and the two volume-directory
/// arguments added as <code>null</code>, so a merge of those arguments has a property to set; the
/// edit sends none of the three, and a <parameter>VOLUMEROOTQUERY</parameter> in its query is
/// resolved through <class>OcuPilot.Port.PathPort</class> and sent as
/// <code>NewVolumeDirectory</code>.</p>
/// <p><b>The create is sequenced here</b> (AD-52 as amended 2026-09-29): a
/// <parameter>CONFIGENDPOINT</parameter> <code>PUT</code> whose query carries
/// <parameter>ROOTQUERY</parameter> resolves the directory, refuses one already holding
/// <parameter>DATABASEFILE</parameter>, creates <code>%DB_&lt;NAME&gt;</code> unless the query names a
/// resource or it exists, creates the file with a body built here, and sends the configuration
/// <code>PUT</code> with <parameter>DIRECTORYFIELD</parameter>. A failed configuration
/// <code>PUT</code> deletes the file it created and answers its fault with
/// <code>detail.rolledBack</code>.</p>
/// <p><b>The delete is sequenced here</b>: a <parameter>CONFIGENDPOINT</parameter>
/// <code>DELETE</code> deletes the configuration (a 409 is
/// <parameter>OcuPilot.Api.DatabaseError.INUSE</parameter>) and then, only when
/// <parameter>DELETEFILEQUERY</parameter> is true, the database is local and no other configuration
/// name shares its directory, the file. It answers <code>{fileDeleted}</code>.</p>
/// <p><b>A configuration read answers <parameter>DELETEFILEQUERY</parameter> as <code>null</code></b>,
/// so the delete's one argument merges into a diff row, and a configuration <code>PUT</code> sends no
/// such key.</p>
/// <p><b>It names no administration API class.</b> Every vendor call goes through
/// <method>Call</method>, which is <method>OcuPilot.Port.AdminPort.Invoke</method>, so the gate, the
/// stubs, the namespace switch and the fault mapping are the admin port's (AD-27).</p>
Class OcuPilot.Port.DatabasePort Extends OcuPilot.Port.AdminPort
{

/// <p>The configuration endpoint, keyed by name.</p>
Parameter CONFIGENDPOINT = "Database.ConfigCRUD";

/// <p>The file endpoint, keyed by directory.</p>
Parameter FILEENDPOINT = "Database.SysCRUD";

/// <p>The endpoint a missing <code>%DB_&lt;NAME&gt;</code> resource is created through.</p>
Parameter RESOURCEENDPOINT = "Security.Resource";

/// <p>The query keys the create's declared arguments travel under.</p>
Parameter ROOTQUERY = "root";

Parameter PATHQUERY = "path";

Parameter SIZEQUERY = "Size";

Parameter JOURNALQUERY = "GlobalJournalState";

Parameter RESOURCEQUERY = "ResourceName";

/// <p>The create's arguments, comma-separated: none of them is sent in the configuration body.</p>
Parameter CREATEARGUMENTS = "root,path,Size,GlobalJournalState,ResourceName";

/// <p>The query keys the file edit's new volume directory travels under.</p>
Parameter VOLUMEROOTQUERY = "volumeRoot";

Parameter VOLUMEPATHQUERY = "volumePath";

/// <p>The delete's one argument, and the query key it travels under.</p>
Parameter DELETEFILEQUERY = "DeleteFile";

/// <p>The configuration's directory, which a file read by name answers too.</p>
Parameter DIRECTORYFIELD = "Directory";

/// <p>A configuration's data server; non-empty for a remote database.</p>
Parameter SERVERFIELD = "Server";

/// <p>The file a database directory holds.</p>
Parameter DATABASEFILE = "IRIS.DAT";

/// <p>The prefix every database's resource name carries (Conventions, IRIS security objects).</p>
Parameter RESOURCEPREFIX = "%DB_";

Parameter NAMEPARAM = "name";

Parameter DIRPARAM = "dir";

/// <p>The file's initial size in megabytes when the query names none.</p>
Parameter DEFAULTSIZE As INTEGER = 1;

/// <p>The admin API writes this port issues of its own for its tools' request types, reached through
/// those tools: the resource and the file the create makes, and the file the delete or a rolled-back
/// create removes.</p>
Parameter DELEGATEDTYPES = "Security.Resource/PUT,Database.SysCRUD/POST,Database.SysCRUD/DELETE";

/// <p>One vendor call: <method>OcuPilot.Port.AdminPort.Invoke</method>. Every call this port makes
/// goes through here, so a test port overrides this one method to record or refuse a call.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The admin port's call, with the four branches this class's header names.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s. The create answers the configuration
/// <code>PUT</code>'s own answer; the delete answers <code>{fileDeleted}</code> at 200; a refused
/// directory or resource answers 422 <parameter>OcuPilot.Api.DatabaseError.VALIDATION</parameter> with
/// <code>detail.violations</code>, and a path refusal is <class>OcuPilot.Port.PathPort</class>'s own
/// envelope.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If pEndpoint = ..#CONFIGENDPOINT {
        If pType = "GET" {
            Set tSC = ..Call(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            If $$$ISOK(tSC) && ..IsObjectAnswer($Get(pResult)) Do pResult.%Set(..#DELETEFILEQUERY, "", "null")
            Quit tSC
        }
        If (pType = "PUT") && ($Get(pQuery(..#ROOTQUERY)) '= "") Quit ..Create(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
        If pType = "PUT" Quit ..Call(pEndpoint, pType, .pQuery, ..Without(pBody, $ListBuild(..#DELETEFILEQUERY)), .pResult, .pHttpStatus, .pFault)
        If pType = "DELETE" Quit ..Delete(.pQuery, .pResult, .pHttpStatus, .pFault)
    }
    If (pEndpoint = ..#FILEENDPOINT) && ((pType = "GET") || (pType = "PUT")) && ($Get(pQuery(..#NAMEPARAM)) '= "") && '($Data(pQuery(..#DIRPARAM)) # 2) {
        Set tSC = ..DirectoryOf(pQuery(..#NAMEPARAM), .tDirectory, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Kill tQuery
        Set tQuery(..#DIRPARAM) = tDirectory
        If pType = "GET" {
            Set tSC = ..Call(pEndpoint, pType, .tQuery, "", .pResult, .pHttpStatus, .pFault)
            If $$$ISOK(tSC) && ..IsObjectAnswer($Get(pResult)) {
                Do pResult.%Set(..#DIRECTORYFIELD, tDirectory, "string")
                Do pResult.%Set(..#VOLUMEROOTQUERY, "", "null")
                Do pResult.%Set(..#VOLUMEPATHQUERY, "", "null")
            }
            Quit tSC
        }
        Set tBody = ..Without(pBody, $ListBuild(..#DIRECTORYFIELD, ..#VOLUMEROOTQUERY, ..#VOLUMEPATHQUERY))
        If $Get(pQuery(..#VOLUMEROOTQUERY)) '= "" {
            Set tSC = ##class(OcuPilot.Port.PathPort).Resolve(pQuery(..#VOLUMEROOTQUERY), $Get(pQuery(..#VOLUMEPATHQUERY)), ##class(OcuPilot.Port.PathPort).#KINDDIRECTORY, ..#VOLUMEROOTQUERY, ..#VOLUMEPATHQUERY, .tVolume, .pHttpStatus, .pFault, 0, 1)
            If $$$ISERR(tSC) Quit tSC
            If $IsObject(tBody) Do tBody.%Set("NewVolumeDirectory", tVolume, "string")
        }
        Quit ..Call(pEndpoint, pType, .tQuery, tBody, .pResult, .pHttpStatus, .pFault)
    }
    Quit ..Call(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The create's sequence (AD-52 as amended 2026-09-29), in order: the directory resolved from
/// <parameter>ROOTQUERY</parameter> and <parameter>PATHQUERY</parameter>; a directory holding
/// <parameter>DATABASEFILE</parameter> refused; <code>%DB_&lt;NAME&gt;</code> created when
/// <parameter>RESOURCEQUERY</parameter> is empty and no such resource exists; the file created; the
/// configuration written with <parameter>DIRECTORYFIELD</parameter> added to the caller's body less
/// the create's arguments. A failed configuration write deletes the file created here and answers
/// that write's fault with <code>detail.rolledBack</code>; a resource created here stays.</p>
ClassMethod Create(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tName = $Get(pQuery(..#NAMEPARAM))
    Set tSC = ##class(OcuPilot.Port.PathPort).Resolve($Get(pQuery(..#ROOTQUERY)), $Get(pQuery(..#PATHQUERY)), ##class(OcuPilot.Port.PathPort).#KINDDIRECTORY, ..#ROOTQUERY, ..#PATHQUERY, .tDirectory, .pHttpStatus, .pFault, 0, 1)
    If $$$ISERR(tSC) Quit tSC
    If ..HoldsDatabase(tDirectory) Quit ..Refused(..#PATHQUERY, ##class(OcuPilot.Api.DatabaseError).#DIRECTORYINUSE, .pHttpStatus, .pFault)
    Set tResource = ..ResourceFor(tName, $Get(pQuery(..#RESOURCEQUERY)))
    If $Get(pQuery(..#RESOURCEQUERY)) = "" {
        Set tSC = ..EnsureResource(tResource, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    Kill tNone
    Set tSC = ..Call(..#FILEENDPOINT, "POST", .tNone, ..FileBody(tDirectory, .pQuery, tResource), .tFile, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Kill tQuery
    Set tQuery(..#NAMEPARAM) = tName
    Set tBody = ..Without(pBody, $ListFromString(..#CREATEARGUMENTS _ "," _ ..#DELETEFILEQUERY))
    If '$IsObject(tBody) Set tBody = {}
    Do tBody.%Set(..#DIRECTORYFIELD, tDirectory, "string")
    Set tSC = ..Call(..#CONFIGENDPOINT, "PUT", .tQuery, tBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Quit tSC
    Kill tDirQuery
    Set tDirQuery(..#DIRPARAM) = tDirectory
    Set tRollbackSC = ..Call(..#FILEENDPOINT, "DELETE", .tDirQuery, "", .tIgnored, .tRollbackHttp, .tRollbackFault)
    If $$$ISERR(tRollbackSC) Do ..LogFault(..#CONFIGENDPOINT _ " create's file could not be deleted after its configuration was refused", tRollbackSC, $Select($IsObject($Get(tRollbackFault)): tRollbackFault.%Get("code"), 1: ""))
    If '$IsObject($Get(pFault)) Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    If pFault.%GetTypeOf("detail") '= "object" Do pFault.%Set("detail", {})
    Do pFault.%Get("detail").%Set("rolledBack", $$$ISOK(tRollbackSC), "boolean")
    Quit tSC
}

/// <p>The delete's sequence: the configuration read, its delete, and only then, when
/// <parameter>DELETEFILEQUERY</parameter> is true, the configuration named no data server and no other
/// configuration name's directory is its directory (compared by <method>SameDirectory</method>), the
/// file's delete. A failed file delete after a deleted configuration answers 200 with
/// <code>fileDeleted</code> false and logs the fault.</p>
ClassMethod Delete(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tName = $Get(pQuery(..#NAMEPARAM))
    Kill tQuery
    Set tQuery(..#NAMEPARAM) = tName
    Set tSC = ..Call(..#CONFIGENDPOINT, "GET", .tQuery, "", .tConfig, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Call(..#CONFIGENDPOINT, "DELETE", .tQuery, "", .tAnswer, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        If +pHttpStatus = 409 {
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.DatabaseError).#INUSE, ##class(OcuPilot.Api.DatabaseError).#REASONINUSE)
            Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.DatabaseError).#INUSE)
        }
        Quit tSC
    }
    Set tDeleted = 0
    Set tDirectory = ..Text(tConfig, ..#DIRECTORYFIELD)
    If ..Truthy($Get(pQuery(..#DELETEFILEQUERY))) && (..Text(tConfig, ..#SERVERFIELD) = "") && (tDirectory '= "") {
        Set tShared = 1
        Kill tNone
        Set tListSC = ..Call(..#CONFIGENDPOINT, "LIST", .tNone, "", .tRows, .tListHttp, .tListFault)
        If $$$ISOK(tListSC) Set tShared = ..SharedBy(tRows, tName, tDirectory)
        If $$$ISERR(tListSC) Do ..LogFault(..#CONFIGENDPOINT _ " delete could not list the configurations sharing its file, so the file stays", tListSC, "")
        If 'tShared {
            Kill tDirQuery
            Set tDirQuery(..#DIRPARAM) = tDirectory
            Set tFileSC = ..Call(..#FILEENDPOINT, "DELETE", .tDirQuery, "", .tIgnored, .tFileHttp, .tFileFault)
            Set tDeleted = $$$ISOK(tFileSC)
            If $$$ISERR(tFileSC) Do ..LogFault(..#CONFIGENDPOINT _ " delete removed the configuration and its file delete failed", tFileSC, $Select($IsObject($Get(tFileFault)): tFileFault.%Get("code"), 1: ""))
        }
    }
    Set pResult = {}
    Do pResult.%Set("fileDeleted", tDeleted, "boolean")
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>The directory of the configuration <var>pName</var>, read through <method>Call</method>, in
/// <var>pDirectory</var>. A remote configuration is 409
/// <parameter>OcuPilot.Api.DatabaseError.REMOTE</parameter>; an absent one is the read's own 404.</p>
ClassMethod DirectoryOf(pName As %String, Output pDirectory As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pDirectory = ""
    Kill tQuery
    Set tQuery(..#NAMEPARAM) = pName
    Set tSC = ..Call(..#CONFIGENDPOINT, "GET", .tQuery, "", .tConfig, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If ..Text(tConfig, ..#SERVERFIELD) '= "" {
        Set pHttpStatus = 409
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.DatabaseError).#REMOTE, ##class(OcuPilot.Api.DatabaseError).#REASONREMOTE)
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.DatabaseError).#REMOTE)
    }
    Set pDirectory = ..Text(tConfig, ..#DIRECTORYFIELD)
    If pDirectory = "" {
        Set pHttpStatus = 404
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.DatabaseError).#NAMEABSENT, ##class(OcuPilot.Api.DatabaseError).#REASONNAMEABSENT)
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.DatabaseError).#NAMEABSENT)
    }
    Quit $$$OK
}

/// <p>Whether normalized directory <var>pDirectory</var> already holds
/// <parameter>DATABASEFILE</parameter> (DW-1791).</p>
ClassMethod HoldsDatabase(pDirectory As %String) As %Boolean
{
    If pDirectory = "" Quit 0
    Quit ''##class(%File).Exists(##class(%File).NormalizeDirectory(pDirectory) _ ..#DATABASEFILE)
}

/// <p>The resource the create guards its file with: <var>pNamed</var>, or
/// <parameter>RESOURCEPREFIX</parameter> and <var>pName</var> upper-cased.</p>
ClassMethod ResourceFor(pName As %String, pNamed As %String = "") As %String
{
    If pNamed '= "" Quit pNamed
    Quit ..#RESOURCEPREFIX _ $ZConvert(pName, "U")
}

/// <p>Create resource <var>pResource</var> with no description and no public permission, unless it
/// exists (Conventions, IRIS security objects).</p>
ClassMethod EnsureResource(pResource As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery(..#NAMEPARAM) = pResource
    Set tSC = ..Call(..#RESOURCEENDPOINT, "GET", .tQuery, "", .tHeld, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Quit tSC
    If +pHttpStatus '= 404 Quit tSC
    Set tBody = {}
    Do tBody.%Set("Description", "", "string")
    Do tBody.%Set("PublicPermission", "", "string")
    Quit ..Call(..#RESOURCEENDPOINT, "PUT", .tQuery, tBody, .tCreated, .pHttpStatus, .pFault)
}

/// <p>The body the create's file is made with: <code>{Directory, Size, GlobalJournalState,
/// ResourceName}</code>, the size and journal state from the query, defaulting to
/// <parameter>DEFAULTSIZE</parameter> and on.</p>
ClassMethod FileBody(pDirectory As %String, ByRef pQuery, pResource As %String) As %DynamicObject
{
    Set tSize = $Get(pQuery(..#SIZEQUERY))
    If tSize = "" Set tSize = ..#DEFAULTSIZE
    Set tJournal = $Get(pQuery(..#JOURNALQUERY))
    Set tBody = {}
    Do tBody.%Set("Directory", pDirectory, "string")
    Do tBody.%Set("Size", +tSize, "number")
    Do tBody.%Set("GlobalJournalState", $Select(tJournal = "": 1, 1: ..Truthy(tJournal)), "boolean")
    Do tBody.%Set("ResourceName", pResource, "string")
    Quit tBody
}

/// <p>Whether a row of <var>pRows</var> other than <var>pName</var> (compared without regard to case)
/// carries <var>pDirectory</var> (compared by <method>SameDirectory</method>).</p>
ClassMethod SharedBy(pRows As %DynamicArray, pName As %String, pDirectory As %String) As %Boolean
{
    If '$IsObject(pRows) Quit 1
    Set tShared = 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If $ZConvert(tRow.%Get("Name"), "U") = $ZConvert(pName, "U") Continue
        If ..SameDirectory(tRow.%Get(..#DIRECTORYFIELD), pDirectory) {
            Set tShared = 1
            Quit
        }
    }
    Quit tShared
}

/// <p>Whether two directories name one place: equal without regard to case once every trailing
/// separator is removed. <code>""</code> names none.</p>
ClassMethod SameDirectory(pA As %String, pB As %String) As %Boolean
{
    Set tA = $ZConvert($ZStrip(pA, ">", "/\"), "L")
    Set tB = $ZConvert($ZStrip(pB, ">", "/\"), "L")
    If (tA = "") || (tB = "") Quit 0
    Quit (tA = tB)
}

/// <p>A copy of <var>pBody</var> without the keys of <var>pNames</var>; a body that is not an object
/// is answered as it is.</p>
ClassMethod Without(pBody As %DynamicAbstractObject, pNames As %List) As %DynamicAbstractObject
{
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit pBody
    Set tCopy = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
    For tI = 1:1:$ListLength(pNames) {
        If tCopy.%GetTypeOf($List(pNames, tI)) '= "unassigned" Do tCopy.%Remove($List(pNames, tI))
    }
    Quit tCopy
}

/// <p>A 422 <parameter>OcuPilot.Api.DatabaseError.VALIDATION</parameter> refusal carrying one
/// violation, <var>pCode</var> on <var>pField</var>, with no vendor call made.</p>
ClassMethod Refused(pField As %String, pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(pCode)
    Set pHttpStatus = 422
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.DatabaseError).#VALIDATION, tReason)
    Set tViolation = {}
    Do tViolation.%Set("field", pField, "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", tReason, "string")
    Set tDetail = {}
    Do tDetail.%Set("violations", [(tViolation)])
    Do pFault.%Set("detail", tDetail)
    Quit $$$ERROR($$$GeneralError, pCode)
}

/// <p>Whether <var>pValue</var> reads as true: <code>1</code> or <code>true</code>.</p>
ClassMethod Truthy(pValue As %String) As %Boolean
{
    Quit (pValue = 1) || ($ZConvert(pValue, "L") = "true")
}

/// <p>Whether <var>pAnswer</var> is a JSON object.</p>
ClassMethod IsObjectAnswer(pAnswer) As %Boolean [ Private ]
{
    Quit $IsObject(pAnswer) && pAnswer.%IsA("%Library.DynamicObject")
}

/// <p><var>pObject</var>'s <var>pField</var> as text: absent or null as <code>""</code>.</p>
ClassMethod Text(pObject, pField As %String) As %String [ Private ]
{
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") Quit ""
    Quit pObject.%Get(pField)
}

/// <p>The admin port's answer: each branch is the vendor's own routes.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): the create is
/// <method>ResourceIfAbsentStep</method> when no resource is named, the file's <code>POST</code> and
/// the configuration's <code>PUT</code>, with the directory the write resolved (<var>pBody</var>'s
/// <parameter>DIRECTORYFIELD</parameter>); the delete is the configuration's <code>DELETE</code> when
/// <parameter>DELETEFILEQUERY</parameter> is false, and no step when it is true, because the write
/// deletes the file only when no other configuration name shares its directory, read at the write,
/// which a script cannot carry; a file read or edit by name addresses <var>pBody</var>'s
/// <parameter>DIRECTORYFIELD</parameter> and sends none of the three names the read adds. Every other
/// call is the admin port's script. A create or a file edit with no directory answers no step.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint = ..#CONFIGENDPOINT) && (pType = "PUT") && ($Get(pQuery(..#ROOTQUERY)) '= "") {
        Set tDirectory = ..Text(pBody, ..#DIRECTORYFIELD)
        If tDirectory = "" Quit []
        Set tName = $Get(pQuery(..#NAMEPARAM))
        Set tResource = ..ResourceFor(tName, $Get(pQuery(..#RESOURCEQUERY)))
        Set tSteps = []
        If $Get(pQuery(..#RESOURCEQUERY)) = "" Do tSteps.%Push(..ResourceIfAbsentStep(tResource))
        Kill tNone
        Set tFile = ##super(..#FILEENDPOINT, "POST", .tNone, ..FileBody(tDirectory, .pQuery, tResource), pContext)
        Kill tQuery
        Set tQuery(..#NAMEPARAM) = tName
        Set tBody = ..Without(pBody, $ListFromString(..#CREATEARGUMENTS _ "," _ ..#DELETEFILEQUERY))
        Set tConfig = ##super(..#CONFIGENDPOINT, "PUT", .tQuery, tBody, pContext)
        Quit ..Joined(tSteps, tFile, tConfig)
    }
    If (pEndpoint = ..#CONFIGENDPOINT) && (pType = "DELETE") {
        If ..Truthy($Get(pQuery(..#DELETEFILEQUERY))) Quit []
        Kill tQuery
        Set tQuery(..#NAMEPARAM) = $Get(pQuery(..#NAMEPARAM))
        Quit ##super(pEndpoint, pType, .tQuery, "", pContext)
    }
    If (pEndpoint = ..#CONFIGENDPOINT) && (pType = "PUT") {
        Quit ##super(pEndpoint, pType, .pQuery, ..Without(pBody, $ListBuild(..#DELETEFILEQUERY)), pContext)
    }
    If (pEndpoint = ..#FILEENDPOINT) && ((pType = "GET") || (pType = "PUT")) && ($Get(pQuery(..#NAMEPARAM)) '= "") && '($Data(pQuery(..#DIRPARAM)) # 2) {
        Set tDirectory = ..Text(pBody, ..#DIRECTORYFIELD)
        If tDirectory = "" Quit []
        Kill tQuery
        Set tQuery(..#DIRPARAM) = tDirectory
        Quit ##super(pEndpoint, pType, .tQuery, ..Without(pBody, $ListBuild(..#DIRECTORYFIELD, ..#VOLUMEROOTQUERY, ..#VOLUMEPATHQUERY)), pContext)
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

/// <p><method>EnsureResource</method> as one <code>objectscript</code> step: resource
/// <var>pResource</var> created with no description and no public permission only when
/// <class>Security.Resources</class> answers that it does not exist, so a resource that exists is
/// left as it is.</p>
ClassMethod ResourceIfAbsentStep(pResource As %String) As %DynamicObject
{
    Set tName = ..Literal(pResource)
    Quit ..ObjectScriptStep($ListBuild("If '##class(Security.Resources).Exists(" _ tName _ ") { Set tSC = ##class(Security.Resources).Create(" _ tName _ ", """", """") Do $System.Status.DisplayError(tSC) }"))
}

/// <p>The steps of each array argument, in order, as one array.</p>
ClassMethod Joined(pA As %DynamicArray = "", pB As %DynamicArray = "", pC As %DynamicArray = "") As %DynamicArray [ Private ]
{
    Set tAll = []
    For tPart = pA, pB, pC {
        If '$IsObject(tPart) Continue
        Set tIterator = tPart.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            Do tAll.%Push(tStep)
        }
    }
    Quit tAll
}

}
