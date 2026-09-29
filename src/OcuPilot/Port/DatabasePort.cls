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
/// <p><b>The disk operations are built here</b> (AD-51 as amended 2026-09-29, Story 18.4): a
/// <parameter>ACTIONSENDPOINT</parameter> call. Its <parameter>STATETYPE</parameter> is a read this
/// port composes from the file's <code>GET</code> and <code>INFO</code> (<method>State</method>), for
/// one directory, a configuration <code>name</code>, or a set of directories as a JSON array
/// (<method>CanonicalSet</method>). Its writes take no caller body: the port reads the target's state,
/// refuses a state the operation's precondition forbids or an argument its rules refuse
/// (<method>ActionViolations</method>) before any vendor call, and builds the vendor body from the
/// operation's declared arguments in the query (<method>ActionBody</method>). A queued operation still
/// running at the bound has started: success with HTTP <parameter>STARTEDHTTP</parameter> (AD-26).</p>
/// <p><b>A new volume directory is refused here too</b> (DW-1791): a file edit whose
/// <parameter>VOLUMEROOTQUERY</parameter> resolves to another database's directory or volume directory,
/// or to a directory holding a database file other than the target's own, is refused on
/// <parameter>VOLUMEPATHQUERY</parameter> before the <code>PUT</code>
/// (<method>VolumeDirectoryInUse</method>).</p>
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

/// <p>The disk operations' endpoint (Story 18.4).</p>
Parameter ACTIONSENDPOINT = "Database.Actions";

/// <p>The read type this port composes for <parameter>ACTIONSENDPOINT</parameter>, the disk
/// operations' fresh read.</p>
Parameter STATETYPE = "STATE";

/// <p>The disk operations' write types, comma-separated.</p>
Parameter ACTIONTYPES = "MOUNT,DISMOUNT,TRUNCATE,COMPACT,DEFRAGMENT,EXPANDVOL,MODIFYSIZE,INTEGRITYCHECK";

/// <p>The fields <parameter>STATETYPE</parameter> answers for one database, comma-separated:
/// <code>Mounted</code>, <code>Size</code>, <code>FreeSpace</code> (<code>AvailableSpace</code>) and
/// <code>ReadOnly</code> (a non-empty <code>ReadOnlyReason</code>) from <code>INFO</code>; the rest from
/// <code>GET</code> (measured on <code>ocupilot-b-ci</code>, Story 18.4 Task 0); <code>Directory</code>
/// the directory read, and <code>Dismounted</code> that directory when it is not mounted.</p>
Parameter STATEFIELDS = "Directory,Mounted,ReadOnly,Size,MaxSize,FreeSpace,ResourceName,NewVolumeDirectory,NewVolumeThreshold,Dismounted";

/// <p>The disk tools' argument fields, which <parameter>STATETYPE</parameter> answers as
/// <code>null</code> so a merge of an argument makes its diff row, comma-separated.</p>
Parameter ARGUMENTFIELDS = "TargetSize,TargetFreeSpace,InitialSize,Globals";

/// <p>The query keys the disk operations' declared arguments travel under.</p>
Parameter READONLYQUERY = "ReadOnly";

Parameter TARGETSIZEQUERY = "TargetSize";

Parameter TARGETFREEQUERY = "TargetFreeSpace";

Parameter INITIALSIZEQUERY = "InitialSize";

/// <p>The integrity check's global names, a JSON array of strings in the query.</p>
Parameter GLOBALSQUERY = "Globals";

/// <p>The field an integrity check's set refusal is named on.</p>
Parameter DATABASESFIELD = "Databases";

/// <p>A global name an integrity check takes: an optional <code>%</code>, a letter, then letters,
/// digits or dots, at most 31 characters, never <code>^</code>.</p>
Parameter GLOBALPATTERN = "%?[A-Za-z][A-Za-z0-9.]{0,30}";

/// <p>The pairs whose body this port composes from the query rather than takes from its caller
/// (AD-51 as amended by Story 12.3), in <method>ActionBody</method>: Story 18.4's mount, truncate,
/// compact, Add a volume, size grow and integrity check.</p>
Parameter COMPOSEDTYPES = "Database.Actions/MOUNT,Database.Actions/TRUNCATE,Database.Actions/COMPACT,Database.Actions/EXPANDVOL,Database.Actions/MODIFYSIZE,Database.Actions/INTEGRITYCHECK";

/// <p>The HTTP status of a queued operation the vendor's worker is still running when
/// <method>AsyncTimeout</method> passes: accepted, and continuing on the instance (AD-26).</p>
Parameter STARTEDHTTP = 202;

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
    If pEndpoint = ..#ACTIONSENDPOINT {
        If pType = ..#STATETYPE Quit ..State(.pQuery, .pResult, .pHttpStatus, .pFault)
        If $ListFind($ListFromString(..#ACTIONTYPES), pType) Quit ..Action(pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
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
            ; DW-1791: another database's directory or volume directory is refused before the PUT.
            Set tSC = ..VolumeDirectoryInUse(tDirectory, tVolume, .tInUse)
            If $$$ISERR(tSC) Quit ..Fail(pEndpoint, 500, tSC, .pHttpStatus, .pFault)
            If tInUse Quit ..Refused(..#VOLUMEPATHQUERY, ##class(OcuPilot.Api.DatabaseError).#DIRECTORYINUSE, .pHttpStatus, .pFault)
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

/// <p><parameter>STATETYPE</parameter>: the disk operations' fresh read. With <code>dir</code> naming one
/// directory, or <code>name</code> a local configuration (<method>DirectoryOf</method>), it answers
/// <method>StateOf</method>'s object, with <parameter>ARGUMENTFIELDS</parameter> added as
/// <code>null</code>. With <code>dir</code> a JSON array of directories (<method>CanonicalSet</method>)
/// it answers <code>{Directory, Dismounted, Globals}</code>: the canonical set, the members not mounted
/// comma-joined or <code>""</code>, and <code>null</code>, one <method>StateOf</method> per member. A
/// directory the instance does not configure is its read's own 404; an empty set answers
/// <code>Dismounted</code> <code>""</code>.</p>
ClassMethod State(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tDirectory = $Get(pQuery(..#DIRPARAM))
    If (tDirectory = "") && ($Get(pQuery(..#NAMEPARAM)) '= "") {
        Set tSC = ..DirectoryOf(pQuery(..#NAMEPARAM), .tDirectory, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    If ..IsSet(tDirectory) {
        Set tMembers = ..SetMembers(tDirectory)
        Set tDismounted = ""
        For tI = 1:1:$ListLength(tMembers) {
            Set tSC = ..StateOf($List(tMembers, tI), .tMember, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            If 'tMember.%Get("Mounted") Set tDismounted = tDismounted _ $Select(tDismounted = "": "", 1: ",") _ $List(tMembers, tI)
        }
        If $$$ISERR($Get(tSC, $$$OK)) Quit tSC
        Set pResult = {}
        Do pResult.%Set(..#DIRECTORYFIELD, ..CanonicalSet(tDirectory), "string")
        Do pResult.%Set("Dismounted", tDismounted, "string")
        Do pResult.%Set(..#GLOBALSQUERY, "", "null")
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set tSC = ..StateOf(tDirectory, .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Length(..#ARGUMENTFIELDS, ",") {
        Do pResult.%Set($Piece(..#ARGUMENTFIELDS, ",", tI), "", "null")
    }
    Quit $$$OK
}

/// <p>The state of the database in directory <var>pDirectory</var>, <parameter>STATEFIELDS</parameter>
/// in <var>pResult</var>, from one <parameter>FILEENDPOINT</parameter> <code>GET</code> and one
/// <code>INFO</code>, which the admin port reads once and deletes (AD-26). A directory the instance
/// does not configure is the <code>GET</code>'s own 404.</p>
ClassMethod StateOf(pDirectory As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If pDirectory = "" Quit ..Fail(..#ACTIONSENDPOINT, 404, $$$OK, .pHttpStatus, .pFault, "", "", 1)
    Kill tQuery
    Set tQuery(..#DIRPARAM) = pDirectory
    Set tSC = ..Call(..#FILEENDPOINT, "GET", .tQuery, "", .tFile, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Call(..#FILEENDPOINT, "INFO", .tQuery, "", .tInfo, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '..IsObjectAnswer($Get(tFile)) || '..IsObjectAnswer($Get(tInfo)) Quit ..Fail(..#ACTIONSENDPOINT, 500, $$$ERROR($$$GeneralError, "a database's state read did not answer two objects"), .pHttpStatus, .pFault)
    Set tMounted = ''tInfo.%Get("Mounted")
    Set pResult = {}
    Do pResult.%Set(..#DIRECTORYFIELD, pDirectory, "string")
    Do pResult.%Set("Mounted", tMounted, "boolean")
    Do pResult.%Set("ReadOnly", (tMounted && (..Text(tInfo, "ReadOnlyReason") '= "")), "boolean")
    Do pResult.%Set("Size", +tInfo.%Get("Size"), "number")
    Do pResult.%Set("MaxSize", +tFile.%Get("MaxSize"), "number")
    Do pResult.%Set("FreeSpace", +tInfo.%Get("AvailableSpace"), "number")
    Do pResult.%Set("ResourceName", ..Text(tFile, "ResourceName"), "string")
    Do pResult.%Set("NewVolumeDirectory", ..Text(tFile, "NewVolumeDirectory"), "string")
    Do pResult.%Set("NewVolumeThreshold", +tFile.%Get("NewVolumeThreshold"), "number")
    Do pResult.%Set("Dismounted", $Select(tMounted: "", 1: pDirectory), "string")
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>A disk operation <var>pType</var>: its target resolved from <code>dir</code> or
/// <code>name</code> (<code>dir</code> a set for <code>INTEGRITYCHECK</code>), its state read
/// (<method>State</method>), <method>ActionViolations</method> asked -- a state refusal answered 409 on
/// its code, argument refusals 422 <parameter>OcuPilot.Api.DatabaseError.VALIDATION</parameter> -- and
/// only then the vendor call with <method>ActionBody</method>'s body. A caller body is refused as the
/// admin port refuses one for a constant-body pair. The vendor's own 409 for a mounted database is
/// <parameter>OcuPilot.Api.DatabaseError.MOUNTED</parameter>; a queued operation not finished within
/// <method>AsyncTimeout</method> returns OK with <var>pHttpStatus</var>
/// <parameter>STARTEDHTTP</parameter> and <var>pResult</var> and <var>pFault</var> empty.</p>
ClassMethod Action(pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If $IsObject(pBody) || (pBody '= "") {
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault(..#ACTIONSENDPOINT _ " " _ pType _ " was given a caller body, and its body is built by the port", $$$ERROR($$$GeneralError, "a disk operation takes no caller body"), pFault.code)
        Quit tSC
    }
    Set tSC = ..State(.pQuery, .tState, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pHttpStatus = 0
    Set tStateCode = ..ActionViolations(pType, tState, .pQuery, .tViolations)
    If tStateCode '= "" Quit ..StateRefused(tStateCode, tState, .pHttpStatus, .pFault)
    If +$Get(tViolations) > 0 Quit ..RefusedAll(.tViolations, .pHttpStatus, .pFault)
    Set tBody = ..ActionBody(pType, tState, .pQuery)
    Kill tQuery
    If pType '= "INTEGRITYCHECK" Set tQuery(..#DIRPARAM) = tState.%Get(..#DIRECTORYFIELD)
    Set tSC = ..Call(..#ACTIONSENDPOINT, pType, .tQuery, tBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Quit tSC
    ; AD-26: past the bound the queued operation has started, and the vendor's worker finishes it.
    If ..IsQueuedWrite(..#ACTIONSENDPOINT, pType) && $IsObject($Get(pFault)) && (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#PORTTIMEOUT) {
        Set pResult = ""
        Set pHttpStatus = ..#STARTEDHTTP
        Set pFault = ""
        Quit $$$OK
    }
    If (pType = "MOUNT") && (+pHttpStatus = 409) Quit ..StateRefused(##class(OcuPilot.Api.DatabaseError).#MOUNTED, tState, .pHttpStatus, .pFault)
    Quit tSC
}

/// <p>What refuses disk operation <var>pType</var> against the state <var>pState</var>
/// (<method>State</method>'s answer) with the arguments <var>pQuery</var> carries: the state
/// refusal's code as the answer, or <code>""</code>; and each argument refusal as
/// <code>pViolations(n) = $ListBuild(field, code)</code>, the count in <code>pViolations</code>.</p>
/// <p><b>The state</b>: a mount of a mounted database is <parameter>OcuPilot.Api.DatabaseError.MOUNTED</parameter>;
/// every other operation of one that is not mounted, and an integrity check naming any member that is
/// not, <parameter>OcuPilot.Api.DatabaseError.DISMOUNTED</parameter>; a truncate, compact or defragment
/// of one mounted read-only <parameter>OcuPilot.Api.DatabaseError.READONLY</parameter>. <b>The
/// arguments</b>, each a whole number of megabytes: a truncate's target 0 or below the size; a
/// compact's target from 0 to the free space; a grow above the size and within a non-zero maximum; a
/// new volume's initial size 1 or more and within a non-zero threshold. An integrity check names one
/// database or more, global names <parameter>GLOBALPATTERN</parameter> admits, and globals only for one
/// database. Pure: it reads nothing.</p>
ClassMethod ActionViolations(pType As %String, pState As %DynamicObject, ByRef pQuery, Output pViolations) As %String
{
    Kill pViolations
    Set pViolations = 0
    Set tDatabaseError = "OcuPilot.Api.DatabaseError"
    If pType = "INTEGRITYCHECK" {
        Set tMembers = ..SetMembers(..Text(pState, ..#DIRECTORYFIELD))
        If $ListLength(tMembers) = 0 {
            Set pViolations($Increment(pViolations)) = $ListBuild(..#DATABASESFIELD, $Parameter(tDatabaseError, "INTEGRITYDATABASES"))
            Quit ""
        }
        If ..Text(pState, "Dismounted") '= "" Quit $Parameter(tDatabaseError, "DISMOUNTED")
        Set tGlobals = $Get(pQuery(..#GLOBALSQUERY))
        If tGlobals '= "" {
            Set tNames = ..GlobalNames(tGlobals, .tValid)
            If 'tValid {
                Set pViolations($Increment(pViolations)) = $ListBuild(..#GLOBALSQUERY, $Parameter(tDatabaseError, "GLOBALSSHAPE"))
            } ElseIf ($ListLength(tNames) > 0) && ($ListLength(tMembers) > 1) {
                Set pViolations($Increment(pViolations)) = $ListBuild(..#GLOBALSQUERY, $Parameter(tDatabaseError, "GLOBALSONEDATABASE"))
            }
        }
        Quit ""
    }
    Set tMounted = ''pState.%Get("Mounted")
    If pType = "MOUNT" Quit $Select(tMounted: $Parameter(tDatabaseError, "MOUNTED"), 1: "")
    If 'tMounted Quit $Parameter(tDatabaseError, "DISMOUNTED")
    If $ListFind($ListBuild("TRUNCATE", "COMPACT", "DEFRAGMENT"), pType) && pState.%Get("ReadOnly") Quit $Parameter(tDatabaseError, "READONLY")
    Set tSize = +pState.%Get("Size")
    If pType = "TRUNCATE" {
        Set tValue = $Get(pQuery(..#TARGETSIZEQUERY))
        If '..Whole(tValue) || ((+tValue '= 0) && (+tValue >= tSize)) Set pViolations($Increment(pViolations)) = $ListBuild(..#TARGETSIZEQUERY, $Parameter(tDatabaseError, "TARGETSIZESHAPE"))
    }
    If pType = "COMPACT" {
        Set tValue = $Get(pQuery(..#TARGETFREEQUERY))
        If '..Whole(tValue) || (+tValue > +pState.%Get("FreeSpace")) Set pViolations($Increment(pViolations)) = $ListBuild(..#TARGETFREEQUERY, $Parameter(tDatabaseError, "TARGETFREESHAPE"))
    }
    If pType = "MODIFYSIZE" {
        Set tValue = $Get(pQuery(..#SIZEQUERY))
        Set tMax = +pState.%Get("MaxSize")
        If '..Whole(tValue) || (+tValue <= tSize) || ((tMax > 0) && (+tValue > tMax)) Set pViolations($Increment(pViolations)) = $ListBuild(..#SIZEQUERY, $Parameter(tDatabaseError, "GROWSIZESHAPE"))
    }
    If pType = "EXPANDVOL" {
        Set tValue = $Get(pQuery(..#INITIALSIZEQUERY))
        Set tThreshold = +pState.%Get("NewVolumeThreshold")
        If '..Whole(tValue) || (+tValue < 1) || ((tThreshold > 0) && (+tValue > tThreshold)) Set pViolations($Increment(pViolations)) = $ListBuild(..#INITIALSIZEQUERY, $Parameter(tDatabaseError, "INITIALSIZESHAPE"))
    }
    Quit ""
}

/// <p>The vendor body disk operation <var>pType</var> is sent with, built from the arguments
/// <var>pQuery</var> carries (AD-51): <code>MOUNT</code> <code>{"ReadOnly":true}</code> when asked,
/// else <code>{}</code>; <code>TRUNCATE</code> <code>{TargetSize}</code>; <code>COMPACT</code>
/// <code>{TargetFreeSpace}</code>; <code>EXPANDVOL</code> <code>{InitialSize}</code>;
/// <code>MODIFYSIZE</code> <code>{Size}</code>; <code>INTEGRITYCHECK</code>
/// <code>{Databases:[{Directory, Globals?}]}</code> over the set <var>pState</var> names;
/// <code>DISMOUNT</code> and <code>DEFRAGMENT</code> none (<code>""</code>).</p>
ClassMethod ActionBody(pType As %String, pState As %DynamicObject, ByRef pQuery) As %DynamicAbstractObject
{
    If (pType = "DISMOUNT") || (pType = "DEFRAGMENT") Quit ""
    Set tBody = {}
    If pType = "MOUNT" {
        If ..Truthy($Get(pQuery(..#READONLYQUERY))) Do tBody.%Set("ReadOnly", 1, "boolean")
        Quit tBody
    }
    If pType = "TRUNCATE" Do tBody.%Set("TargetSize", +$Get(pQuery(..#TARGETSIZEQUERY)), "number")
    If pType = "COMPACT" Do tBody.%Set("TargetFreeSpace", +$Get(pQuery(..#TARGETFREEQUERY)), "number")
    If pType = "EXPANDVOL" Do tBody.%Set("InitialSize", +$Get(pQuery(..#INITIALSIZEQUERY)), "number")
    If pType = "MODIFYSIZE" Do tBody.%Set("Size", +$Get(pQuery(..#SIZEQUERY)), "number")
    If pType = "INTEGRITYCHECK" {
        Set tMembers = ..SetMembers(..Text(pState, ..#DIRECTORYFIELD))
        Set tNames = ..GlobalNames($Get(pQuery(..#GLOBALSQUERY)), .tValid)
        Set tDatabases = []
        For tI = 1:1:$ListLength(tMembers) {
            Set tEntry = {}
            Do tEntry.%Set("Directory", $List(tMembers, tI), "string")
            If tValid && ($ListLength(tNames) > 0) {
                Set tGlobals = []
                For tJ = 1:1:$ListLength(tNames) {
                    Do tGlobals.%Push($List(tNames, tJ), "string")
                }
                Do tEntry.%Set("Globals", tGlobals)
            }
            Do tDatabases.%Push(tEntry)
        }
        Do tBody.%Set("Databases", tDatabases)
    }
    Quit tBody
}

/// <p>Whether <var>pValue</var> is a JSON array of directories rather than one directory: its first
/// character is <code>[</code>.</p>
ClassMethod IsSet(pValue As %String) As %Boolean
{
    Quit ($Extract(pValue) = "[")
}

/// <p>The canonical spelling of a database id (AD-13 as amended 2026-09-29): a value beginning
/// <code>[</code> that is a JSON array of non-empty strings keeps each member's first spelling, drops
/// a later one <method>SameDirectory</method> matches, and sorts the rest by their text; the answer is
/// that array as compact JSON, or its one member when one remains. Any other value is answered
/// exactly. Pure: <class>OcuPilot.Kernel.EntityRef</class>'s <code>directoryset</code> rule is this
/// method.</p>
ClassMethod CanonicalSet(pValue As %String) As %String
{
    If '..IsSet(pValue) Quit pValue
    Set tMembers = ..ParsedMembers(pValue, .tValid)
    If 'tValid Quit pValue
    If $ListLength(tMembers) = 1 Quit $List(tMembers, 1)
    Set tArray = []
    For tI = 1:1:$ListLength(tMembers) {
        Do tArray.%Push($List(tMembers, tI), "string")
    }
    Quit tArray.%ToJSON()
}

/// <p>The directories the database id <var>pValue</var> names, as a <class>%List</class> in
/// <method>CanonicalSet</method>'s order: a set's members, or the one directory; <code>""</code> for
/// an empty value and for a value beginning <code>[</code> that is not a set of directories.</p>
ClassMethod SetMembers(pValue As %String) As %List
{
    If pValue = "" Quit ""
    If '..IsSet(pValue) Quit $ListBuild(pValue)
    Set tMembers = ..ParsedMembers(pValue, .tValid)
    If 'tValid Quit ""
    Quit tMembers
}

/// <p>A JSON array's members for <method>CanonicalSet</method>, deduplicated and sorted, with
/// <var>pValid</var> 0 when <var>pValue</var> is not an array of non-empty strings.</p>
ClassMethod ParsedMembers(pValue As %String, Output pValid As %Boolean) As %List [ Private ]
{
    Set pValid = 0
    Set tKept = ""
    Try {
        Set tArray = ##class(%DynamicAbstractObject).%FromJSON(pValue)
        If '$IsObject(tArray) || 'tArray.%IsA("%Library.DynamicArray") Quit
        Set tIterator = tArray.%GetIterator()
        Set tBad = 0
        While tIterator.%GetNext(.tIndex, .tMember) {
            If (tArray.%GetTypeOf(tIndex) '= "string") || (tMember = "") Set tBad = 1 Quit
            Set tSeen = 0
            For tI = 1:1:$ListLength(tKept) {
                If ..SameDirectory($List(tKept, tI), tMember) Set tSeen = 1 Quit
            }
            If 'tSeen Set tKept = tKept _ $ListBuild(tMember)
        }
        If tBad Quit
        ; Sorted by text, code unit by code unit, with ']' ("follows"), which is what the client's
        ; string comparison answers for the same members.
        For tI = 2:1:$ListLength(tKept) {
            For tJ = tI:-1:2 {
                If $List(tKept, tJ - 1) ] $List(tKept, tJ) {
                    Set tHold = $List(tKept, tJ)
                    Set $List(tKept, tJ) = $List(tKept, tJ - 1)
                    Set $List(tKept, tJ - 1) = tHold
                } Else {
                    Quit
                }
            }
        }
        Set pValid = 1
    } Catch {
        Set pValid = 0
        Set tKept = ""
    }
    Quit $Select(pValid: tKept, 1: "")
}

/// <p>The global names the JSON array text <var>pText</var> carries, as a <class>%List</class>, with
/// <var>pValid</var> 0 when it is not an array of strings each matching
/// <parameter>GLOBALPATTERN</parameter>. An empty text is an empty, valid list.</p>
ClassMethod GlobalNames(pText As %String, Output pValid As %Boolean) As %List
{
    Set pValid = 1
    If pText = "" Quit ""
    Set tNames = ""
    Try {
        Set tArray = ##class(%DynamicAbstractObject).%FromJSON(pText)
        If '$IsObject(tArray) || 'tArray.%IsA("%Library.DynamicArray") {
            Set pValid = 0
            Quit
        }
        Set tIterator = tArray.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) {
            If (tArray.%GetTypeOf(tIndex) '= "string") || '$Match(tName, ..#GLOBALPATTERN) {
                Set pValid = 0
                Quit
            }
            Set tNames = tNames _ $ListBuild(tName)
        }
    } Catch {
        Set pValid = 0
    }
    Quit $Select(pValid: tNames, 1: "")
}

/// <p>Whether <var>pValue</var> is a whole number: a run of at most nine digits.</p>
ClassMethod Whole(pValue As %String) As %Boolean [ Private ]
{
    Quit ''$Match(pValue, "[0-9]{1,9}")
}

/// <p>Whether the new volume directory <var>pVolume</var> chosen for the database in
/// <var>pOwn</var> is in use by another database (DW-1791), in <var>pInUse</var>: it holds a database
/// file and is not <var>pOwn</var>, or it is another configured database's directory or one of its
/// volume directories (<method>OcuPilot.Port.PathPort.DatabaseDirectories</method>), compared by
/// <method>SameDirectory</method>, other than <var>pOwn</var> and its own volume directories. A read
/// that fails is an error status, which the caller refuses on.</p>
ClassMethod VolumeDirectoryInUse(pOwn As %String, pVolume As %String, Output pInUse As %Boolean) As %Status
{
    Set pInUse = 0
    If pVolume = "" Quit $$$OK
    If ..SameDirectory(pOwn, pVolume) Quit $$$OK
    If ..HoldsDatabase(pVolume) {
        Set pInUse = 1
        Quit $$$OK
    }
    Set tSC = ##class(OcuPilot.Port.PathPort).DatabaseDirectories(.tDirectories, .tStreams)
    If $$$ISERR(tSC) Quit tSC
    Set tOwnVolumes = ""
    If pOwn '= "" {
        Set tSC = ##class(OcuPilot.Port.PathPort).VolumeDirectories(##class(%File).NormalizeDirectory(pOwn), .tOwnVolumes)
        If $$$ISERR(tSC) Quit tSC
    }
    For tI = 1:1:$ListLength(tDirectories) {
        Set tDirectory = $List(tDirectories, tI)
        If '..SameDirectory(tDirectory, pVolume) Continue
        Set tOwned = 0
        For tJ = 1:1:$ListLength(tOwnVolumes) {
            If ..SameDirectory($List(tOwnVolumes, tJ), tDirectory) Set tOwned = 1
        }
        If tOwned Continue
        Set pInUse = 1
        Quit
    }
    Quit $$$OK
}

/// <p>A 409 on the state code <var>pCode</var>, with its published sentence; a
/// <parameter>OcuPilot.Api.DatabaseError.DISMOUNTED</parameter> refusal of a set names its members that
/// are not mounted in <code>detail.dismounted</code>.</p>
ClassMethod StateRefused(pCode As %String, pState As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = ""
    If (pCode = ##class(OcuPilot.Api.DatabaseError).#DISMOUNTED) && ..IsSet(..Text(pState, ..#DIRECTORYFIELD)) {
        Set tDetail = {}
        Do tDetail.%Set("dismounted", ..Text(pState, "Dismounted"), "string")
    }
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, pCode, ##class(OcuPilot.Api.DatabaseError).ReasonFor(pCode), .pHttpStatus, .pFault, tDetail)
}

/// <p>A 422 <parameter>OcuPilot.Api.DatabaseError.VALIDATION</parameter> refusal carrying every
/// violation <var>pViolations</var> holds, with no vendor call made.</p>
ClassMethod RefusedAll(ByRef pViolations, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tRows = []
    For tI = 1:1:+$Get(pViolations) {
        Set tRow = {}
        Do tRow.%Set("field", $List(pViolations(tI), 1), "string")
        Do tRow.%Set("code", $List(pViolations(tI), 2), "string")
        Do tRow.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForViolation($List(pViolations(tI), 2)), "string")
        Do tRows.%Push(tRow)
    }
    Set pHttpStatus = 422
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.DatabaseError).#VALIDATION, ##class(OcuPilot.Api.DatabaseError).#REASONVALIDATION)
    Do pFault.%Set("detail", {"violations": (tRows)})
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.DatabaseError).#VALIDATION)
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

/// <p><method>Invoke</method>'s branches as a script (AD-59): a disk operation is the vendor call
/// with <method>ActionBody</method>'s body, addressed to the directory in the query or, for one keyed
/// by name, to the stored payload's <parameter>DIRECTORYFIELD</parameter>, and answers no step without
/// one (the port's own state read is a guard a script cannot carry); the create is
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
    If (pEndpoint = ..#ACTIONSENDPOINT) && $ListFind($ListFromString(..#ACTIONTYPES), pType) {
        Set tDirectory = $Get(pQuery(..#DIRPARAM))
        If (tDirectory = "") && $IsObject(pContext) && $IsObject(pContext.%Get("payload")) Set tDirectory = ..Text(pContext.%Get("payload"), ..#DIRECTORYFIELD)
        If tDirectory = "" Quit []
        Set tState = {}
        Do tState.%Set(..#DIRECTORYFIELD, tDirectory, "string")
        If (pType = "INTEGRITYCHECK") && ($ListLength(..SetMembers(tDirectory)) = 0) Quit []
        Kill tQuery
        If pType '= "INTEGRITYCHECK" Set tQuery(..#DIRPARAM) = tDirectory
        Quit ##super(pEndpoint, pType, .tQuery, ..ActionBody(pType, tState, .pQuery), pContext)
    }
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
