/// <p>The encryption key file port (AD-21's sixth case, AD-51, AD-52, AD-56 (i), Story 18.7):
/// <class>OcuPilot.Port.AdminPort</class> with every key file named by an allowed <code>root</code> and a
/// relative <code>path</code>, resolved through <class>OcuPilot.Port.PathPort</class> at the call, and
/// sent to the vendor as the resolved path alone. It names no vendor class.</p>
/// <p><b><method>Invoke</method>'s branches</b>, each locating the key file first, from the tools'
/// composite <parameter>KEYFILEPARAM</parameter> or from <code>root</code> and <code>path</code> (a
/// missing one is 400 <code>READ.CRITERION</code> on a read, <code>TOOL.ARGUMENTS</code> on a write):</p>
/// <ul>
/// <li><code>AdminInFile</code> and <code>KeyInFile</code> <code>LIST</code>, the screens' reads: a
/// <code>source</code>; a file whose administrator list names nobody is not a key file, 422
/// <parameter>OcuPilot.Api.EncryptionError.KEYFILEUNREADABLE</parameter> on <code>path</code>, decided
/// before the key list is read, so a chosen non-key file logs nothing; a key file whose key list the
/// vendor refuses as holding no key it can read (#5022) holds none (measured: removing a file's last key
/// leaves one), and any other key list fault fails the read.</li>
/// <li><parameter>KEYFILETYPE</parameter>, the key-file tools' fresh read: both lists as
/// <code>{Administrators, Keys}</code> beside the tools' arguments, empty; a missing file is 404
/// <code>PORT.NOTFOUND</code>, unlogged (a create's absence, AD-54).</li>
/// <li><code>File</code> <code>POST</code>: <class>OcuPilot.Area.Security.EncryptionRules</class>, then a
/// <code>file</code> that never overwrites, whose folder must exist
/// (<parameter>OcuPilot.Api.EncryptionError.KEYFILEDIRECTORY</parameter>), because the vendor creates a
/// missing folder chain; it answers the new key's id from the vendor's <code>Location</code>.</li>
/// <li><code>AdminInFile</code> <code>POST</code> and <code>DELETE</code>, <code>KeyInFile</code>
/// <code>POST</code> and <code>DELETE</code>: a <code>source</code>, the rules, and for an add the existing
/// administrator listed, before any write. A taken or last administrator and an absent administrator or
/// key are the tools' state refusals; the port maps the vendor's own answers for them.</li>
/// <li><parameter>DATABASEKEYSTYPE</parameter> and <parameter>DATAELEMENTKEYSTYPE</parameter>, Story 18.22's
/// fresh reads: the instance's active keys of one kind, <code>Key</code> <code>LIST</code> or
/// <code>DATAELEMENTLIST</code>, as <code>{Keys}</code> beside the tools' arguments, empty.</li>
/// <li><code>File</code> <code>ACTIVATE</code> and <code>Key</code> <code>DEACTIVATE</code>: the activation's
/// key file a <code>source</code>, its administrator listed and a key in it not yet active, and the
/// deactivation's key active, each before any vendor call; the vendor's credentials, in-use and role
/// refusals are mapped (<method>KeyMapped</method>).</li>
/// <li><parameter>JOURNALUSETYPE</parameter>, AD-27's named case: whether a journal file the instance
/// still needs for recovery uses a key, from the vendor's own <code>%SYS.Journal.System</code>.</li>
/// <li><code>Settings</code> <code>GET</code> and <code>PUT</code> (Story 18.23): the read takes no
/// query; the write is <method>StartupWrite</method>, behind <method>SettingsGate</method> and
/// <method>StartupProblems</method>, with <code>DBEncStartKeyFile</code> composed here alone.</li>
/// <li><parameter>KMIPSERVERSTYPE</parameter>, AD-27's named case: the configured KMIP servers'
/// names.</li>
/// <li><parameter>ENCRYPTEDDATABASESTYPE</parameter>, AD-27's named case: which of
/// <parameter>STARTUPDATABASES</parameter> are encrypted on disk.</li>
/// </ul>
/// <p>Every body is built here from the declared arguments in the query and the declared secrets in
/// the body, and a password is held in a local cleared right after the call (AD-35, AD-56 (i)). Any
/// other call is the admin port's own, refused 400 <code>PATH.NAME</code> when it names a server file.
/// Every vendor call goes through <method>Call</method>, which a test port overrides.</p>
Class OcuPilot.Port.EncryptionPort Extends OcuPilot.Port.AdminPort
{

/// <p>This port sends a key file only as a path it resolved (AD-21).</p>
Parameter PATHRESOLVED As BOOLEAN = 1;

/// <p>The three key file endpoints.</p>
Parameter FILEENDPOINT = "Security.Encryption.File";

Parameter ADMINSENDPOINT = "Security.Encryption.AdminInFile";

Parameter KEYSENDPOINT = "Security.Encryption.KeyInFile";

/// <p>The port-composed read of one key file: both lists in one answer.</p>
Parameter KEYFILETYPE = "KEYFILE";

/// <p>The query key a key-file tool names its target by: the composite of <code>root</code> and
/// <code>path</code> (AD-13).</p>
Parameter KEYFILEPARAM = "keyfile";

/// <p>The query keys a read names the key file by, and the vendor's own query keys.</p>
Parameter ROOTPARAM = "root";

Parameter PATHPARAM = "path";

Parameter FILEPARAM = "file";

Parameter ADMINPARAM = "admin";

Parameter KEYPARAM = "key";

/// <p>The arguments the key-file tools declare and send in the query, comma-separated: every one a
/// fresh read answers empty so the write's merge can carry it (AD-51).</p>
Parameter ARGUMENTS = "AdminName,KeyLen,Description,OldAdminName,NewAdminName,Admin,KeyId";

/// <p>The members the fresh read answers the two lists under.</p>
Parameter ADMINISTRATORS = "Administrators";

Parameter KEYS = "Keys";

/// <p>The endpoint the instance's active keys are listed and deactivated through (Story 18.22).</p>
Parameter ACTIVEENDPOINT = "Security.Encryption.Key";

/// <p>The port-composed fresh reads of Story 18.22's activate and deactivate tools: the active
/// database keys and the active data-element keys, each beside the tools' arguments, empty.</p>
Parameter DATABASEKEYSTYPE = "DATABASEKEYS";

Parameter DATAELEMENTKEYSTYPE = "DATAELEMENTKEYS";

/// <p>The port-composed read of whether a journal file the instance still needs for recovery uses a key
/// (AD-27's named case, Story 18.22): <code>{InUse}</code>.</p>
Parameter JOURNALUSETYPE = "JOURNALUSE";

/// <p>The query key carrying a tool's constant vendor action.</p>
Parameter ACTIONPARAM = "Action";

/// <p>The vendor actions each write admits, comma-separated: a database activation or deactivation
/// first, then the data-element one.</p>
Parameter ACTIVATIONS = "ActivateDB,ActivateMK";

Parameter DEACTIVATIONS = "DeactivateDB,DeactivateMK";

/// <p>The arguments Story 18.22's tools declare, each answered empty by their fresh read so the merge
/// carries it into the stored payload (AD-51).</p>
Parameter KEYARGUMENTS = "root,path,AdminName,KeyId";

/// <p>The writes whose vendor body this port composes from its own constants and no caller value
/// (AD-51): a deactivation's <code>{Action, AdminName: "", AdminPassword: ""}</code>, whose two names the
/// vendor requires present and never reads.</p>
Parameter COMPOSEDTYPES = "Security.Encryption.Key/DEACTIVATE";

/// <p>The startup settings endpoint (Story 18.23).</p>
Parameter SETTINGSENDPOINT = "Security.Encryption.Settings";

/// <p>The port-composed read of what the admin API does not answer about the startup settings (AD-27's
/// named case): <code>{Names}</code>, the configured KMIP servers.</p>
Parameter KMIPSERVERSTYPE = "KMIPSERVERS";

/// <p>The port-composed read of which of <parameter>STARTUPDATABASES</parameter> are encrypted on disk
/// (AD-27's named case), which AD-10's start arm reads: <code>{Encrypted}</code>.</p>
Parameter ENCRYPTEDDATABASESTYPE = "ENCRYPTEDDATABASES";

/// <p>The databases whose encryption makes every start activate its key, comma-separated: the audit log's,
/// IRISSECURITY and IRISTEMP.</p>
Parameter STARTUPDATABASES = "IRISAUDIT,IRISSECURITY,IRISTEMP";

/// <p>The start modes, in the vendor's order (0 to 3).</p>
Parameter STARTMODES = "None,Interactive,Unattended,KMIP";

/// <p>The four encryption flags: turning one on needs a start mode other than None and an active database
/// key.</p>
Parameter STARTUPFLAGS = "DBEncJournal,DBEncIRISSecurity,DBEncIRISTemp,AuditEncrypt";

/// <p>The key ids, sent only when changed.</p>
Parameter KEYIDFIELDS = "DBEncDefaultKeyID,DBEncJournalKeyID";

Parameter MODEFIELD = "DBEncStartMode";

Parameter KMIPSERVERFIELD = "DBEncStartKMIPServer";

Parameter STARTKEYFILEFIELD = "DBEncStartKeyFile";

/// <p>The class the key file is resolved through. Overridable so a fixture can observe the resolve;
/// production never overrides it.</p>
ClassMethod PathPortClass() As %String
{
    Quit "OcuPilot.Port.PathPort"
}

/// <p>One vendor call, through the admin port's own sequence in this class's context, so
/// <parameter>PATHRESOLVED</parameter> applies. <var>pLocation</var> is a 2xx answer's
/// <code>Location</code> header.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pLocation As %String) As %Status
{
    Quit ..InvokeLocated(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .pLocation)
}

/// <p>Resolve <var>pRoot</var> and <var>pPath</var> through <method>PathPortClass</method>: as a
/// <code>file</code> that never overwrites when <var>pKind</var> is <code>file</code>, otherwise as a
/// <code>source</code>, each refusal on the <code>root</code> or <code>path</code> field.</p>
ClassMethod Resolve(pRoot As %String, pPath As %String, pKind As %String, Output pResolved As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tPathPort = ..PathPortClass()
    Set tKind = $Select(pKind = "file": $Parameter(tPathPort, "KINDFILE"), 1: $Parameter(tPathPort, "KINDSOURCE"))
    Quit $ClassMethod(tPathPort, "Resolve", pRoot, pPath, tKind, ..#ROOTPARAM, ..#PATHPARAM, .pResolved, .pHttpStatus, .pFault, 0)
}

/// <p>A new key file at <var>pRoot</var> and <var>pPath</var>, checked as the create's write checks it
/// before its vendor call: resolved as a <code>file</code> that never overwrites, and its folder
/// present. Nothing is written.</p>
ClassMethod CheckCreate(pRoot As %String, pPath As %String, Output pResolved As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ..Resolve(pRoot, pPath, "file", .pResolved, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '##class(%File).DirectoryExists(##class(%File).GetDirectory(pResolved)) {
        Set pResolved = ""
        Quit ..Violation(##class(OcuPilot.Api.EncryptionError).#KEYFILEDIRECTORY, ..#PATHPARAM, .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The admin port's call, with this class's header's branches for the three key file endpoints.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        If pEndpoint = ..#SETTINGSENDPOINT {
            Set tStartup = 1
            If pType = "PUT" {
                Set tSC = ..StartupWrite(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            } ElseIf pType = "GET" {
                Kill tQuery
                Set tSC = ..Call(..#SETTINGSENDPOINT, "GET", .tQuery, "", .pResult, .pHttpStatus, .pFault)
            } ElseIf pType = ..#KMIPSERVERSTYPE {
                Set tSC = ..KmipServers(.pResult, .pHttpStatus, .pFault)
            } ElseIf pType = ..#ENCRYPTEDDATABASESTYPE {
                Set tSC = ..EncryptedDatabases(.pResult, .pHttpStatus, .pFault)
            } Else {
                Set tStartup = 0
            }
            If tStartup Quit
        }
        ; AD-21: a caller never names a server file, not even through this port.
        If ..NamesKeyFile(pEndpoint, .pQuery, pBody) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PATHNAME, ##class(OcuPilot.Api.Error).#REASONPATHNAME, .pHttpStatus, .pFault)
            Quit
        }
        If ((pType = ..#DATABASEKEYSTYPE) || (pType = ..#DATAELEMENTKEYSTYPE)) && ((pEndpoint = ..#FILEENDPOINT) || (pEndpoint = ..#ACTIVEENDPOINT)) {
            Set tSC = ..ReadActiveKeys(pType, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#ACTIVEENDPOINT) && (pType = ..#JOURNALUSETYPE) {
            Set tSC = ..JournalUse(.pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#FILEENDPOINT) && (pType = "ACTIVATE") {
            Set tSC = ..Activate(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#ACTIVEENDPOINT) && (pType = "DEACTIVATE") {
            Set tSC = ..Deactivate(.pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tKeyFile = (pEndpoint = ..#FILEENDPOINT) || (pEndpoint = ..#ADMINSENDPOINT) || (pEndpoint = ..#KEYSENDPOINT)
        If tKeyFile && (pType = ..#KEYFILETYPE) {
            Set tSC = ..ReadKeyFile(.pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pType = "LIST") && ((pEndpoint = ..#ADMINSENDPOINT) || (pEndpoint = ..#KEYSENDPOINT)) {
            Set tSC = ..List(pEndpoint, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#FILEENDPOINT) && (pType = "POST") {
            Set tSC = ..CreateFile(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#ADMINSENDPOINT) && (pType = "POST") {
            Set tSC = ..AddAdmin(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#ADMINSENDPOINT) && (pType = "DELETE") {
            Set tSC = ..RemoveAdmin(.pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#KEYSENDPOINT) && (pType = "POST") {
            Set tSC = ..AddKey(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#KEYSENDPOINT) && (pType = "DELETE") {
            Set tSC = ..RemoveKey(.pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Do ..LogFault(pEndpoint _ " failed inside the encryption port", ex.AsStatus(), pFault.code)
        Set tSC = $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
    }
    Quit tSC
}

/// <p>The key file <var>pQuery</var> names: its <parameter>KEYFILEPARAM</parameter> composite, or its
/// <code>root</code> and <code>path</code>, in <var>pRoot</var> and <var>pPath</var>; 0 when either is
/// missing.</p>
ClassMethod Named(ByRef pQuery, Output pRoot As %String, Output pPath As %String) As %Boolean
{
    Set pRoot = ""
    Set pPath = ""
    If $Get(pQuery(..#KEYFILEPARAM)) '= "" {
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pQuery(..#KEYFILEPARAM))
        If $ListLength(tParts) '= 2 Quit 0
        Set pRoot = $ListGet(tParts, 1)
        Set pPath = $ListGet(tParts, 2)
    } Else {
        Set pRoot = $Get(pQuery(..#ROOTPARAM))
        Set pPath = $Get(pQuery(..#PATHPARAM))
    }
    Quit (pRoot '= "") && (pPath '= "")
}

/// <p>Locate an existing key file for a write: the query's key file resolved as a <code>source</code>,
/// in <var>pFile</var>. A missing name is 400 <code>TOOL.ARGUMENTS</code>.</p>
ClassMethod Source(ByRef pQuery, Output pFile As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFile = ""
    If '..Named(.pQuery, .tRoot, .tPath) Quit ..Arguments("'root' and 'path' name the key file and cannot be empty", .pHttpStatus, .pFault)
    Quit ..Resolve(tRoot, tPath, "source", .pFile, .pHttpStatus, .pFault)
}

/// <p>The administrators of key file <var>pFile</var> as the vendor lists them, upper case, in
/// <var>pNames</var>; a list naming nobody is 422
/// <parameter>OcuPilot.Api.EncryptionError.KEYFILEUNREADABLE</parameter> on <code>path</code>.</p>
ClassMethod Administrators(pFile As %String, Output pNames As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pNames = []
    Kill tQuery
    Set tQuery(..#FILEPARAM) = pFile
    Set tSC = ..Call(..#ADMINSENDPOINT, "LIST", .tQuery, "", .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tReadable = $IsObject($Get(tRows)) && tRows.%IsA("%Library.DynamicArray") && (tRows.%Size() > 0)
    If tReadable {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tName = $Select($IsObject(tRow): tRow.%Get("Name") _ "", 1: "")
            If tName = "" Set tReadable = 0 Quit
            Do pNames.%Push(tName)
        }
    }
    If 'tReadable {
        Set pNames = []
        Quit ..Violation(##class(OcuPilot.Api.EncryptionError).#KEYFILEUNREADABLE, ..#PATHPARAM, .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The keys of key file <var>pFile</var> as the vendor lists them, in <var>pRows</var>:
/// <code>[{Id, KeyLen, Description}]</code>. The vendor's refusal of the list as a file holding no key it
/// can read (#5022, which <parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter> names
/// <parameter>OcuPilot.Api.EncryptionError.KEYFILEUNREADABLE</parameter>) is a key file holding none
/// (measured on a key file whose last key was removed), answered <code>[]</code>; the caller has already
/// read its administrators. Any other fault fails the read (AD-2).</p>
ClassMethod Keys(pFile As %String, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = []
    Kill tQuery
    Set tQuery(..#FILEPARAM) = pFile
    Set tSC = ..Call(..#KEYSENDPOINT, "LIST", .tQuery, "", .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        If (+$Get(pHttpStatus) '= 500) || '..NamesNoKey($Get(pFault)) Quit tSC
        Set pHttpStatus = 200
        Set pFault = ""
        Quit $$$OK
    }
    If $IsObject($Get(tRows)) && tRows.%IsA("%Library.DynamicArray") Set pRows = tRows
    Quit tSC
}

/// <p>Whether fault <var>pFault</var> carries the violation the admin port maps the vendor's #5022 to on a
/// key list: <parameter>OcuPilot.Api.EncryptionError.KEYFILEUNREADABLE</parameter>.</p>
ClassMethod NamesNoKey(pFault) As %Boolean [ Private ]
{
    If '$IsObject(pFault) || (pFault.%GetTypeOf("detail") '= "object") || (pFault.%Get("detail").%GetTypeOf("violations") '= "array") Quit 0
    Set tNamed = 0
    Set tIterator = pFault.%Get("detail").%Get("violations").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && (tRow.%Get("code") = ##class(OcuPilot.Api.EncryptionError).#KEYFILEUNREADABLE) Set tNamed = 1 Quit
    }
    Quit tNamed
}

/// <p>One list of the key file the query's <code>root</code> and <code>path</code> name (the screens'
/// reads): administrators as <code>[{Name}]</code>, keys as <code>[{Id, KeyLen, Description}]</code>.</p>
ClassMethod List(pEndpoint As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If '..Named(.pQuery, .tRoot, .tPath) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#READCRITERION, "root and path are required", .pHttpStatus, .pFault)
    }
    Set tSC = ..Resolve(tRoot, tPath, "source", .tFile, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Administrators(tFile, .tNames, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If pEndpoint = ..#ADMINSENDPOINT {
        Set pResult = []
        Set tIterator = tNames.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) {
            Do pResult.%Push({"Name": (tName)})
        }
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set tSC = ..Keys(tFile, .pResult, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Set pHttpStatus = 200
    Quit tSC
}

/// <p>The key-file tools' fresh read (AD-51): <code>{Administrators: [name], Keys: [{Id, KeyLen,
/// Description}]}</code> with every <parameter>ARGUMENTS</parameter> member <code>""</code>. A key file
/// that is not there is 404 <code>PORT.NOTFOUND</code>, unlogged.</p>
ClassMethod ReadKeyFile(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If '..Named(.pQuery, .tRoot, .tPath) Quit ..Absent(.pHttpStatus, .pFault)
    Set tSC = ..Resolve(tRoot, tPath, "source", .tFile, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        If $IsObject($Get(pFault)) && (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#PATHNOFILE) Quit ..Absent(.pHttpStatus, .pFault)
        Quit tSC
    }
    Set tSC = ..Administrators(tFile, .tNames, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Keys(tFile, .tKeys, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pResult = {}
    Do pResult.%Set(..#ADMINISTRATORS, tNames)
    Do pResult.%Set(..#KEYS, tKeys)
    For tI = 1:1:$Length(..#ARGUMENTS, ",") {
        Do pResult.%Set($Piece(..#ARGUMENTS, ",", tI), "", "string")
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Create a key file (<code>File</code> <code>POST</code>): the query's key file, administrator,
/// key length and description and the body's <code>AdminPassword</code>. <var>pResult</var> is
/// <code>{Id}</code>, the new key's id, at 201.</p>
ClassMethod CreateFile(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If '..Named(.pQuery, .tRoot, .tPath) Quit ..Arguments("'root' and 'path' name the key file and cannot be empty", .pHttpStatus, .pFault)
    Set tValues = ..Values(.pQuery, pBody, $ListBuild("AdminName", "KeyLen", "Description"), $ListBuild("AdminPassword"))
    Kill tViolations
    Do ##class(OcuPilot.Area.Security.EncryptionRules).Violations(tValues, $ListBuild("AdminName", "AdminPassword", "KeyLen"), .tViolations)
    If +$Get(tViolations) > 0 {
        Set tValues = ""
        Quit ##class(OcuPilot.Area.Security.EncryptionRules).Fault(.tViolations, .pHttpStatus, .pFault)
    }
    Set tSC = ..CheckCreate(tRoot, tPath, .tFile, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        Set tValues = ""
        Quit tSC
    }
    Set tSend = {}
    Do tSend.%Set("File", tFile, "string")
    Do tSend.%Set("AdminName", tValues.%Get("AdminName"), "string")
    Do tSend.%Set("AdminPassword", tValues.%Get("AdminPassword"), "string")
    Do tSend.%Set("KeyLen", +tValues.%Get("KeyLen"), "number")
    Do tSend.%Set("Description", tValues.%Get("Description"), "string")
    Set tValues = ""
    Kill tQuery
    Set tSC = ..Call(..#FILEENDPOINT, "POST", .tQuery, tSend, .tWritten, .pHttpStatus, .pFault, .tLocation)
    Set tSend = ""
    If $$$ISERR(tSC) Quit tSC
    Set pResult = {}
    Do pResult.%Set("Id", $Piece($Piece($Get(tLocation), "id=", 2), "&", 1), "string")
    Quit tSC
}

/// <p>Add an administrator (<code>AdminInFile</code> <code>POST</code>): the query's key file and
/// <code>OldAdminName</code> and <code>NewAdminName</code>, and the body's two passwords. The vendor's
/// 409 for a taken new name is <code>TOOL.ARGUMENTS</code>; an existing name not listed, or a vendor
/// answer that the name and password do not open the file, is 422
/// <parameter>OcuPilot.Api.EncryptionError.KEYFILECREDENTIALS</parameter>.</p>
ClassMethod AddAdmin(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tValues = ..Values(.pQuery, pBody, $ListBuild("OldAdminName", "NewAdminName"), $ListBuild("OldAdminPassword", "NewAdminPassword"))
    Kill tViolations
    Do ##class(OcuPilot.Area.Security.EncryptionRules).Violations(tValues, $ListBuild("OldAdminName", "OldAdminPassword", "NewAdminName", "NewAdminPassword"), .tViolations)
    If +$Get(tViolations) > 0 {
        Set tValues = ""
        Quit ##class(OcuPilot.Area.Security.EncryptionRules).Fault(.tViolations, .pHttpStatus, .pFault)
    }
    Set tSC = ..Source(.pQuery, .tFile, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        Set tValues = ""
        Quit tSC
    }
    Set tSC = ..Administrators(tFile, .tNames, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        Set tValues = ""
        Quit tSC
    }
    If '..Listed(tNames, tValues.%Get("OldAdminName")) {
        Set tValues = ""
        Quit ..Violation(##class(OcuPilot.Api.EncryptionError).#KEYFILECREDENTIALS, "OldAdminName", .pHttpStatus, .pFault)
    }
    Set tSend = {}
    For tName = "OldAdminName", "OldAdminPassword", "NewAdminName", "NewAdminPassword" {
        Do tSend.%Set(tName, tValues.%Get(tName), "string")
    }
    Set tValues = ""
    Kill tQuery
    Set tQuery(..#FILEPARAM) = tFile
    Set tSC = ..Call(..#ADMINSENDPOINT, "POST", .tQuery, tSend, .pResult, .pHttpStatus, .pFault)
    Set tSend = ""
    If $$$ISERR(tSC) Quit ..Mapped(tSC, ##class(OcuPilot.Api.EncryptionError).#REASONADMINTAKEN, .pHttpStatus, .pFault)
    Quit tSC
}

/// <p>Remove an administrator (<code>AdminInFile</code> <code>DELETE</code>): the query's key file and
/// <code>Admin</code>. The vendor's 404 for an administrator not listed is <code>PORT.NOTFOUND</code>,
/// and its 409 for the last one <code>TOOL.ARGUMENTS</code>.</p>
ClassMethod RemoveAdmin(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tAdmin = $Get(pQuery("Admin"))
    If tAdmin = "" Quit ..Arguments("'Admin' names the administrator to remove and cannot be empty", .pHttpStatus, .pFault)
    Set tSC = ..Source(.pQuery, .tFile, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Administrators(tFile, .tNames, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Kill tQuery
    Set tQuery(..#FILEPARAM) = tFile
    Set tQuery(..#ADMINPARAM) = tAdmin
    Set tSC = ..Call(..#ADMINSENDPOINT, "DELETE", .tQuery, "", .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit ..Mapped(tSC, ##class(OcuPilot.Api.EncryptionError).#REASONADMINLAST, .pHttpStatus, .pFault)
    Quit tSC
}

/// <p>Add a key (<code>KeyInFile</code> <code>POST</code>): the query's key file,
/// <code>AdminName</code>, <code>KeyLen</code> and <code>Description</code>, and the body's
/// <code>AdminPassword</code>. A name not listed, or a vendor answer that the name and password do not
/// open the file, is 422 <parameter>OcuPilot.Api.EncryptionError.KEYFILECREDENTIALS</parameter>.</p>
ClassMethod AddKey(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tValues = ..Values(.pQuery, pBody, $ListBuild("AdminName", "KeyLen", "Description"), $ListBuild("AdminPassword"))
    Kill tViolations
    Do ##class(OcuPilot.Area.Security.EncryptionRules).Violations(tValues, $ListBuild("AdminName", "AdminPassword", "KeyLen"), .tViolations)
    If +$Get(tViolations) > 0 {
        Set tValues = ""
        Quit ##class(OcuPilot.Area.Security.EncryptionRules).Fault(.tViolations, .pHttpStatus, .pFault)
    }
    Set tSC = ..Source(.pQuery, .tFile, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        Set tValues = ""
        Quit tSC
    }
    Set tSC = ..Administrators(tFile, .tNames, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        Set tValues = ""
        Quit tSC
    }
    If '..Listed(tNames, tValues.%Get("AdminName")) {
        Set tValues = ""
        Quit ..Violation(##class(OcuPilot.Api.EncryptionError).#KEYFILECREDENTIALS, "AdminName", .pHttpStatus, .pFault)
    }
    Set tSend = {}
    Do tSend.%Set("AdminName", tValues.%Get("AdminName"), "string")
    Do tSend.%Set("AdminPassword", tValues.%Get("AdminPassword"), "string")
    Do tSend.%Set("Description", tValues.%Get("Description"), "string")
    Do tSend.%Set("KeyLen", +tValues.%Get("KeyLen"), "number")
    Set tValues = ""
    Kill tQuery
    Set tQuery(..#FILEPARAM) = tFile
    Set tSC = ..Call(..#KEYSENDPOINT, "POST", .tQuery, tSend, .pResult, .pHttpStatus, .pFault)
    Set tSend = ""
    If $$$ISERR(tSC) Quit ..Mapped(tSC, "", .pHttpStatus, .pFault)
    Quit tSC
}

/// <p>Remove a key (<code>KeyInFile</code> <code>DELETE</code>): the query's key file and
/// <code>KeyId</code>, sent as the vendor's <code>key</code>. The vendor's 404 for a key not listed is
/// <code>PORT.NOTFOUND</code>.</p>
ClassMethod RemoveKey(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tKey = $Get(pQuery("KeyId"))
    If tKey = "" Quit ..Arguments("'KeyId' names the key to remove and cannot be empty", .pHttpStatus, .pFault)
    Set tSC = ..Source(.pQuery, .tFile, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Administrators(tFile, .tNames, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Kill tQuery
    Set tQuery(..#FILEPARAM) = tFile
    Set tQuery(..#KEYPARAM) = tKey
    Set tSC = ..Call(..#KEYSENDPOINT, "DELETE", .tQuery, "", .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit ..Mapped(tSC, "", .pHttpStatus, .pFault)
    Quit tSC
}

/// <p>The active keys of the kind fresh read <var>pType</var> names: the database keys
/// (<code>Key</code> <code>LIST</code>, <code>[{Id, KeyLen, IsDefault}]</code>) for
/// <parameter>DATABASEKEYSTYPE</parameter>, the data-element keys (<code>DATAELEMENTLIST</code>,
/// <code>[{Id}]</code>) for <parameter>DATAELEMENTKEYSTYPE</parameter>, in <var>pRows</var>.</p>
ClassMethod ActiveKeys(pType As %String, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRows = []
    Kill tQuery
    Set tSC = ..Call(..#ACTIVEENDPOINT, $Select(pType = ..#DATAELEMENTKEYSTYPE: "DATAELEMENTLIST", 1: "LIST"), .tQuery, "", .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject($Get(tRows)) && tRows.%IsA("%Library.DynamicArray") Set pRows = tRows
    Quit tSC
}

/// <p>Story 18.22's tools' fresh read (AD-51): <code>{Keys: [the active keys of the kind]}</code> with
/// every <parameter>KEYARGUMENTS</parameter> member <code>""</code>.</p>
ClassMethod ReadActiveKeys(pType As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..ActiveKeys(pType, .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pResult = {}
    Do pResult.%Set(..#KEYS, tRows)
    For tI = 1:1:$Length(..#KEYARGUMENTS, ",") {
        Do pResult.%Set($Piece(..#KEYARGUMENTS, ",", tI), "", "string")
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether active-key rows <var>pRows</var> list <var>pId</var>, compared exactly.</p>
ClassMethod Active(pRows As %DynamicArray, pId As %String) As %Boolean
{
    Set tFound = 0
    If '$IsObject($Get(pRows)) Quit 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && (tRow.%Get("Id") = pId) Set tFound = 1 Quit
    }
    Quit tFound
}

/// <p>Whether a journal file the instance still needs for recovery uses key <var>pQuery</var>
/// <code>id</code> (AD-27's named case, Story 18.22): <code>{InUse}</code>, from the vendor's own
/// <code>%SYS.Journal.System.IsEncKeyInUse</code> in <code>%SYS</code>, after the endpoint's
/// <code>%Admin_Secure:USE</code> gate. An empty id is 400 <code>TOOL.ARGUMENTS</code>; a refusal or a
/// throw fails the read.</p>
ClassMethod JournalUse(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tId = $Get(pQuery("id"))
    If tId = "" Quit ..Arguments("'id' names the key and cannot be empty", .pHttpStatus, .pFault)
    If '$System.Security.Check("%Admin_Secure", "USE") {
        Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tDetail)
        Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, {"failedPair": "%Admin_Secure:USE"})
    }
    Set tInUse = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tInUse = ''##class(%SYS.Journal.System).IsEncKeyInUse(tId)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tInUse = ""
        Set tError = ex.AsStatus()
    }
    If tInUse = "" {
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault("the journal's use of an encryption key could not be read", $Get(tError, $$$ERROR($$$GeneralError, "no answer")), pFault.code)
        Quit tSC
    }
    Set pResult = {}
    Do pResult.%Set("InUse", tInUse, "boolean")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The kind an activation or deactivation <var>pAction</var> acts on: the fresh read type of its
/// active keys, or <code>""</code> for an action outside <var>pAdmitted</var>.</p>
ClassMethod KindOf(pAction As %String, pAdmitted As %String) As %String [ Private ]
{
    Set tAt = $ListFind($ListFromString(pAdmitted), pAction)
    If tAt = 0 Quit ""
    Quit $Select(tAt = 1: ..#DATABASEKEYSTYPE, 1: ..#DATAELEMENTKEYSTYPE)
}

/// <p>The keys of the key file <var>pRoot</var> and <var>pPath</var> name that activation
/// <var>pAction</var> would make active, in <var>pIds</var> (a <class>%DynamicArray</class>), checked as
/// the write checks them before its vendor call: resolved as a <code>source</code>, its administrators
/// read (a file naming none is not a key file), administrator <var>pAdminName</var>, when given, listed
/// (else 422 <code>ENCRYPTION.KEYFILE.CREDENTIALS</code> on <code>AdminName</code>), and its keys compared
/// with the active keys of the action's kind, a file whose every key is active refused 400
/// <code>TOOL.ARGUMENTS</code> (<parameter>OcuPilot.Api.EncryptionError.REASONKEYSALLACTIVE</parameter>).
/// The activate tools' mint asks this; nothing is written.</p>
ClassMethod FileKeys(pRoot As %String, pPath As %String, pAction As %String, Output pIds As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pNames As %DynamicArray, Output pFile As %String, pAdminName As %String = "") As %Status
{
    Set pIds = []
    Set pNames = []
    Set pFile = ""
    Set tKind = ..KindOf(pAction, ..#ACTIVATIONS)
    If tKind = "" Quit ..Arguments("'" _ ..#ACTIONPARAM _ "' is one of " _ $Translate(..#ACTIVATIONS, ",", " or "), .pHttpStatus, .pFault)
    If (pRoot = "") || (pPath = "") Quit ..Arguments("'root' and 'path' name the key file and cannot be empty", .pHttpStatus, .pFault)
    Set tSC = ..Resolve(pRoot, pPath, "source", .pFile, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Administrators(pFile, .pNames, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If (pAdminName '= "") && '..Listed(pNames, pAdminName) Quit ..Violation(##class(OcuPilot.Api.EncryptionError).#KEYFILECREDENTIALS, "AdminName", .pHttpStatus, .pFault)
    Set tSC = ..Keys(pFile, .tKeys, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ActiveKeys(tKind, .tActive, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tInactive = 0
    Set tIterator = tKeys.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Do pIds.%Push(tRow.%Get("Id") _ "")
        If '..Active(tActive, tRow.%Get("Id")) Set tInactive = tInactive + 1
    }
    If tInactive = 0 Quit ..Arguments(##class(OcuPilot.Api.EncryptionError).#REASONKEYSALLACTIVE, .pHttpStatus, .pFault)
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>Activate the keys of a key file (<code>File</code> <code>ACTIVATE</code>, Story 18.22): the
/// query's key file, <code>AdminName</code> and constant <code>Action</code>, and the body's
/// <code>AdminPassword</code>. The rules, then the key file and the name listed in it
/// (<method>FileKeys</method>), are checked first; the body <code>{Action, AdminName, AdminPassword}</code>
/// goes with the resolved path as <code>file</code>, and the password is cleared right after the call.</p>
ClassMethod Activate(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tAction = $Get(pQuery(..#ACTIONPARAM))
    If ..KindOf(tAction, ..#ACTIVATIONS) = "" Quit ..Arguments("'" _ ..#ACTIONPARAM _ "' is one of " _ $Translate(..#ACTIVATIONS, ",", " or "), .pHttpStatus, .pFault)
    If '..Named(.pQuery, .tRoot, .tPath) Quit ..Arguments("'root' and 'path' name the key file and cannot be empty", .pHttpStatus, .pFault)
    Set tValues = ..Values(.pQuery, pBody, $ListBuild("AdminName"), $ListBuild("AdminPassword"))
    Kill tViolations
    Do ##class(OcuPilot.Area.Security.EncryptionRules).Violations(tValues, $ListBuild("AdminName", "AdminPassword"), .tViolations)
    If +$Get(tViolations) > 0 {
        Set tValues = ""
        Quit ##class(OcuPilot.Area.Security.EncryptionRules).Fault(.tViolations, .pHttpStatus, .pFault)
    }
    Set tSC = ..FileKeys(tRoot, tPath, tAction, .tIds, .pHttpStatus, .pFault, .tNames, .tFile, tValues.%Get("AdminName"))
    If $$$ISERR(tSC) {
        Set tValues = ""
        Quit tSC
    }
    Set tSend = {}
    Do tSend.%Set(..#ACTIONPARAM, tAction, "string")
    Do tSend.%Set("AdminName", tValues.%Get("AdminName"), "string")
    Do tSend.%Set("AdminPassword", tValues.%Get("AdminPassword"), "string")
    Set tValues = ""
    Kill tQuery
    Set tQuery(..#FILEPARAM) = tFile
    Set tSC = ..Call(..#FILEENDPOINT, "ACTIVATE", .tQuery, tSend, .pResult, .pHttpStatus, .pFault)
    Set tSend = ""
    If $$$ISERR(tSC) Quit ..KeyMapped(tSC, .pHttpStatus, .pFault)
    Quit tSC
}

/// <p>Deactivate one active key (<code>Key</code> <code>DEACTIVATE</code>, Story 18.22): the query's
/// <code>KeyId</code> and constant <code>Action</code>. A key the active list of the action's kind does
/// not hold is 400 <code>TOOL.ARGUMENTS</code>
/// (<parameter>OcuPilot.Api.EncryptionError.REASONKEYINACTIVE</parameter>); the vendor's body is
/// composed here (<parameter>COMPOSEDTYPES</parameter>), its in-use and role refusals mapped.</p>
ClassMethod Deactivate(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tAction = $Get(pQuery(..#ACTIONPARAM))
    Set tKind = ..KindOf(tAction, ..#DEACTIVATIONS)
    If tKind = "" Quit ..Arguments("'" _ ..#ACTIONPARAM _ "' is one of " _ $Translate(..#DEACTIVATIONS, ",", " or "), .pHttpStatus, .pFault)
    Set tKey = $Get(pQuery("KeyId"))
    If tKey = "" Quit ..Arguments("'KeyId' names the key to deactivate and cannot be empty", .pHttpStatus, .pFault)
    Set tSC = ..ActiveKeys(tKind, .tActive, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '..Active(tActive, tKey) Quit ..Arguments(##class(OcuPilot.Api.EncryptionError).#REASONKEYINACTIVE, .pHttpStatus, .pFault)
    Set tSend = {}
    Do tSend.%Set(..#ACTIONPARAM, tAction, "string")
    Do tSend.%Set("AdminName", "", "string")
    Do tSend.%Set("AdminPassword", "", "string")
    Kill tQuery
    Set tQuery("id") = tKey
    Set tSC = ..Call(..#ACTIVEENDPOINT, "DEACTIVATE", .tQuery, tSend, .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit ..KeyMapped(tSC, .pHttpStatus, .pFault)
    Quit tSC
}

/// <p>A vendor refusal of an activation or deactivation in the product's terms: a credentials violation
/// the admin port mapped is 422 on its field; an in-use or role violation is 409 with its code and
/// sentence; anything else is the fault as it is.</p>
ClassMethod KeyMapped(pSC As %Status, ByRef pHttpStatus As %Integer, ByRef pFault As %DynamicObject) As %Status [ Private ]
{
    For tCode = ##class(OcuPilot.Api.EncryptionError).#KEYINUSE, ##class(OcuPilot.Api.EncryptionError).#KEYROLE {
        If ..Carries(pFault, tCode) Quit
        Set tCode = ""
    }
    If tCode '= "" Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, tCode, ##class(OcuPilot.Api.EncryptionError).ReasonFor(tCode), .pHttpStatus, .pFault)
    Quit ..Mapped(pSC, "", .pHttpStatus, .pFault)
}

/// <p>Whether fault <var>pFault</var> carries a violation of code <var>pCode</var>.</p>
ClassMethod Carries(pFault, pCode As %String) As %Boolean [ Private ]
{
    If '$IsObject($Get(pFault)) || (pFault.%GetTypeOf("detail") '= "object") || (pFault.%Get("detail").%GetTypeOf("violations") '= "array") Quit 0
    Set tFound = 0
    Set tIterator = pFault.%Get("detail").%Get("violations").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && (tRow.%Get("code") = pCode) Set tFound = 1 Quit
    }
    Quit tFound
}

/// <p>Whether this instance's admin API takes the startup administrator in the settings write's body
/// (Story 18.23's explicit version gate, AD-26): the endpoint's own body template, built at
/// <parameter>APIVERSION</parameter>, must carry <code>AdminName</code> and <code>AdminPassword</code>.
/// Otherwise, or when the template cannot be read, 501 <code>PORT.NOTIMPLEMENTED</code> with
/// <parameter>OcuPilot.Api.EncryptionError.REASONSETTINGSVERSION</parameter>. The write, the tool's mint
/// and the screen's Save ask it before anything is sent.</p>
ClassMethod SettingsGate(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tCarries = 0
    Try {
        Set tSC = ..Template(..#SETTINGSENDPOINT, .tTemplate, .tMethod)
        If $$$ISOK(tSC) && $IsObject($Get(tTemplate)) && tTemplate.%IsA("%Library.DynamicObject") {
            Set tCarries = tTemplate.%IsDefined("AdminName") && tTemplate.%IsDefined("AdminPassword")
        }
    } Catch {
        Set tCarries = 0
    }
    If tCarries Quit $$$OK
    Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ##class(OcuPilot.Api.EncryptionError).#REASONSETTINGSVERSION, .pHttpStatus, .pFault)
}

/// <p>The startup settings write (<code>Settings</code> <code>PUT</code>, Story 18.23, AD-4's named
/// exception). A query or body naming a file is 400 <code>PATH.NAME</code>; then the version gate
/// (<method>SettingsGate</method>), the fresh read, the settings asked for (<method>Wanted</method>) and the
/// rules (<method>StartupProblems</method>), each before any write. The body is
/// <method>StartupBody</method>'s; <code>AdminName</code> comes from the query, else the body, and
/// <code>AdminPassword</code> from the body. The password is cleared right after the call, and the
/// vendor's refusals are mapped (<method>StartupMapped</method>).</p>
ClassMethod StartupWrite(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    ; AD-21: a caller never names the startup key file; this port composes it.
    If ..NamesKeyFile(..#SETTINGSENDPOINT, .pQuery, pBody) Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PATHNAME, ##class(OcuPilot.Api.Error).#REASONPATHNAME, .pHttpStatus, .pFault)
    Set tSC = ..SettingsGate(.pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit ..Arguments("the startup settings are sent as an object", .pHttpStatus, .pFault)
    Kill tQuery
    Set tSC = ..Call(..#SETTINGSENDPOINT, "GET", .tQuery, "", .tFresh, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault("the startup settings read answered no object", $$$ERROR($$$GeneralError, "no settings object"), pFault.code)
        Quit tSC
    }
    Set tWanted = ..Wanted(tFresh, pBody, .tProblem)
    If tProblem '= "" Quit ..Arguments(tProblem, .pHttpStatus, .pFault)
    Set tAdmin = $Get(pQuery("AdminName"))
    If (tAdmin = "") && (pBody.%GetTypeOf("AdminName") = "string") Set tAdmin = pBody.%Get("AdminName")
    Set tValues = ..Values(.pQuery, pBody, "", $ListBuild("AdminPassword"))
    Set tSC = ..StartupProblems(tWanted, tFresh, $Get(pQuery(..#ROOTPARAM)), $Get(pQuery(..#PATHPARAM)), tAdmin, tValues.%Get("AdminPassword"), 1, .tKeyFile, .tNewFile, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        Set tValues = ""
        Quit tSC
    }
    Set tSend = ..StartupBody(tWanted, tFresh, tKeyFile, tNewFile, tAdmin, tValues.%Get("AdminPassword"))
    Set tValues = ""
    Set tCredentials = (tSend.%GetTypeOf("AdminPassword") '= "unassigned")
    Kill tQuery
    Set tSC = ..Call(..#SETTINGSENDPOINT, "PUT", .tQuery, tSend, .pResult, .pHttpStatus, .pFault)
    Set tSend = ""
    If $$$ISERR(tSC) Quit ..StartupMapped(tSC, tCredentials, .pHttpStatus, .pFault)
    Quit tSC
}

/// <p>The startup settings <var>pBody</var> asks for over the fresh read <var>pFresh</var>: the start
/// mode, the four <parameter>STARTUPFLAGS</parameter> and the KMIP server as the body sends each, else as
/// read, so a flag the body leaves out keeps its read value; each <parameter>KEYIDFIELDS</parameter> member
/// only as the body sends it. A mode outside <parameter>STARTMODES</parameter>, a flag that is not true or
/// false, or a value that is not text is <var>pProblem</var>, one sentence naming the field.</p>
ClassMethod Wanted(pFresh As %DynamicObject, pBody As %DynamicObject, Output pProblem As %String) As %DynamicObject
{
    Set pProblem = ""
    Set tWanted = {}
    For tField = ..#MODEFIELD, ..#KMIPSERVERFIELD {
        Set tValue = ..StartupText(pFresh, tField)
        Set tType = $Select($IsObject(pBody): pBody.%GetTypeOf(tField), 1: "unassigned")
        If tType = "string" Set tValue = pBody.%Get(tField)
        If (tType '= "unassigned") && (tType '= "string") Set pProblem = "'" _ tField _ "' is text" Quit
        Do tWanted.%Set(tField, tValue, "string")
    }
    If pProblem '= "" Quit tWanted
    If '$ListFind($ListFromString(..#STARTMODES), tWanted.%Get(..#MODEFIELD)) {
        Set pProblem = "'" _ ..#MODEFIELD _ "' is one of " _ $Replace(..#STARTMODES, ",", ", ")
        Quit tWanted
    }
    For tI = 1:1:$Length(..#STARTUPFLAGS, ",") {
        Set tField = $Piece(..#STARTUPFLAGS, ",", tI)
        Set tValue = ''$Select($IsObject(pFresh): +pFresh.%Get(tField), 1: 0)
        Set tType = $Select($IsObject(pBody): pBody.%GetTypeOf(tField), 1: "unassigned")
        If tType = "boolean" {
            Set tValue = ''pBody.%Get(tField)
        } ElseIf (tType = "number") && ((pBody.%Get(tField) = 0) || (pBody.%Get(tField) = 1)) {
            Set tValue = +pBody.%Get(tField)
        } ElseIf tType '= "unassigned" {
            Set pProblem = "'" _ tField _ "' is true or false"
            Quit
        }
        Do tWanted.%Set(tField, tValue, "boolean")
    }
    If pProblem '= "" Quit tWanted
    For tI = 1:1:$Length(..#KEYIDFIELDS, ",") {
        Set tField = $Piece(..#KEYIDFIELDS, ",", tI)
        Set tType = $Select($IsObject(pBody): pBody.%GetTypeOf(tField), 1: "unassigned")
        If (tType = "unassigned") || (tType = "null") Continue
        If tType '= "string" {
            Set pProblem = "'" _ tField _ "' is a key id"
            Quit
        }
        Do tWanted.%Set(tField, pBody.%Get(tField), "string")
    }
    Quit tWanted
}

/// <p>The rules the startup settings write answers before any vendor call, on both callers (Story
/// 18.23), over <var>pWanted</var> (<method>Wanted</method>'s answer) and the fresh read
/// <var>pFresh</var>:</p>
/// <ul>
/// <li>KMIP names a configured KMIP server (<method>KmipNames</method>);</li>
/// <li>Unattended has a key file: <var>pRoot</var> and <var>pPath</var> resolved as a <code>source</code>,
/// or the stored one when neither is given, in <var>pKeyFile</var>, with <var>pNewFile</var> 1 when it is not
/// the stored file; a new file needs administrator <var>pAdminName</var> listed in it and, when
/// <var>pCheckPassword</var>, a password the key-file rules admit
/// (<class>OcuPilot.Area.Security.EncryptionRules</class>);</li>
/// <li>turning a <parameter>STARTUPFLAGS</parameter> member on needs a start mode other than None and an
/// active database key;</li>
/// <li>a changed key id names an active database key.</li>
/// </ul>
/// <p>Each broken rule is a violation on its field, all answered as one 422; a read that fails answers
/// its own fault. Nothing is written.</p>
ClassMethod StartupProblems(pWanted As %DynamicObject, pFresh As %DynamicObject, pRoot As %String, pPath As %String, pAdminName As %String, pPassword As %String, pCheckPassword As %Boolean, Output pKeyFile As %String, Output pNewFile As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pKeyFile = ""
    Set pNewFile = 0
    Set pHttpStatus = 0
    Set pFault = ""
    Kill tViolations
    Set tViolations = 0
    Set tMode = ..StartupText(pWanted, ..#MODEFIELD)
    If tMode = "KMIP" {
        Set tSC = ..KmipNames(.tNames, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Set tServer = ..StartupText(pWanted, ..#KMIPSERVERFIELD)
        Set tFound = 0
        Set tIterator = tNames.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) {
            If (tServer '= "") && (tName = tServer) Set tFound = 1 Quit
        }
        If 'tFound Set tViolations($Increment(tViolations)) = $ListBuild(..#KMIPSERVERFIELD, ##class(OcuPilot.Api.EncryptionError).#STARTUPKMIPSERVER)
    }
    If tMode = "Unattended" {
        Set tStored = ..StartupText(pFresh, ..#STARTKEYFILEFIELD)
        If ($Get(pRoot) '= "") || ($Get(pPath) '= "") {
            Set tSC = ..Resolve($Get(pRoot), $Get(pPath), "source", .pKeyFile, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit tSC
            Set pNewFile = '..SameFile(pKeyFile, tStored)
        } Else {
            Set pKeyFile = tStored
            If pKeyFile = "" Set tViolations($Increment(tViolations)) = $ListBuild(..#PATHPARAM, ##class(OcuPilot.Api.EncryptionError).#STARTUPKEYFILE)
        }
        If pNewFile {
            Set tValues = {}
            Do tValues.%Set("AdminName", $Get(pAdminName), "string")
            Do tValues.%Set("AdminPassword", $Get(pPassword), "string")
            Set tBefore = tViolations
            Do ##class(OcuPilot.Area.Security.EncryptionRules).Violations(tValues, $ListBuild("AdminName") _ $Select(pCheckPassword: $ListBuild("AdminPassword"), 1: ""), .tViolations)
            Set tValues = ""
            Set tNameBroken = 0
            For tI = tBefore + 1:1:tViolations {
                If $List(tViolations(tI), 1) = "AdminName" Set tNameBroken = 1
            }
            If 'tNameBroken {
                Set tSC = ..Administrators(pKeyFile, .tAdmins, .pHttpStatus, .pFault)
                If $$$ISERR(tSC) Quit tSC
                If '..Listed(tAdmins, pAdminName) Set tViolations($Increment(tViolations)) = $ListBuild("AdminName", ##class(OcuPilot.Api.EncryptionError).#KEYFILECREDENTIALS)
            }
        }
    }
    Set tActive = ""
    For tI = 1:1:$Length(..#STARTUPFLAGS, ",") {
        Set tField = $Piece(..#STARTUPFLAGS, ",", tI)
        If '+pWanted.%Get(tField) Continue
        If $IsObject(pFresh) && +pFresh.%Get(tField) Continue
        If tMode = "None" {
            Set tViolations($Increment(tViolations)) = $ListBuild(tField, ##class(OcuPilot.Api.EncryptionError).#STARTUPNEEDSSTART)
            Continue
        }
        If '$IsObject(tActive) {
            Set tSC = ..ActiveKeys(..#DATABASEKEYSTYPE, .tActive, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Return tSC
        }
        If tActive.%Size() = 0 Set tViolations($Increment(tViolations)) = $ListBuild(tField, ##class(OcuPilot.Api.EncryptionError).#STARTUPNOKEY)
    }
    For tI = 1:1:$Length(..#KEYIDFIELDS, ",") {
        Set tField = $Piece(..#KEYIDFIELDS, ",", tI)
        If pWanted.%GetTypeOf(tField) '= "string" Continue
        If pWanted.%Get(tField) = ..StartupText(pFresh, tField) Continue
        If '$IsObject(tActive) {
            Set tSC = ..ActiveKeys(..#DATABASEKEYSTYPE, .tActive, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Return tSC
        }
        If '..Active(tActive, pWanted.%Get(tField)) Set tViolations($Increment(tViolations)) = $ListBuild(tField, ##class(OcuPilot.Api.EncryptionError).#STARTUPKEYINACTIVE)
    }
    Set pHttpStatus = 0
    Set pFault = ""
    If tViolations = 0 Quit $$$OK
    Quit ..StartupFault(.tViolations, .pHttpStatus, .pFault)
}

/// <p>The vendor body of the startup settings write: <parameter>MODEFIELD</parameter>, the four
/// <parameter>STARTUPFLAGS</parameter> and <parameter>KMIPSERVERFIELD</parameter> as <var>pWanted</var>
/// holds them, so <code>AuditEncrypt</code> goes as read unless it was changed; the startup key file
/// <var>pKeyFile</var> for Unattended and <code>""</code> for every other mode, as the classic page sends
/// it; each <parameter>KEYIDFIELDS</parameter> member only when it differs from the fresh read
/// <var>pFresh</var>; and <code>AdminName</code> and <code>AdminPassword</code> only for a new Unattended
/// key file (<var>pNewFile</var>).</p>
ClassMethod StartupBody(pWanted As %DynamicObject, pFresh As %DynamicObject, pKeyFile As %String, pNewFile As %Boolean, pAdminName As %String, pPassword As %String) As %DynamicObject
{
    Set tSend = {}
    Set tMode = ..StartupText(pWanted, ..#MODEFIELD)
    Do tSend.%Set(..#MODEFIELD, tMode, "string")
    For tI = 1:1:$Length(..#STARTUPFLAGS, ",") {
        Set tField = $Piece(..#STARTUPFLAGS, ",", tI)
        Do tSend.%Set(tField, ''pWanted.%Get(tField), "boolean")
    }
    Do tSend.%Set(..#KMIPSERVERFIELD, ..StartupText(pWanted, ..#KMIPSERVERFIELD), "string")
    Do tSend.%Set(..#STARTKEYFILEFIELD, $Select(tMode = "Unattended": $Get(pKeyFile), 1: ""), "string")
    For tI = 1:1:$Length(..#KEYIDFIELDS, ",") {
        Set tField = $Piece(..#KEYIDFIELDS, ",", tI)
        If pWanted.%GetTypeOf(tField) '= "string" Continue
        If pWanted.%Get(tField) = ..StartupText(pFresh, tField) Continue
        Do tSend.%Set(tField, pWanted.%Get(tField), "string")
    }
    If (tMode = "Unattended") && $Get(pNewFile) {
        Do tSend.%Set("AdminName", $Get(pAdminName), "string")
        Do tSend.%Set("AdminPassword", $Get(pPassword), "string")
    }
    Quit tSend
}

/// <p>The 422 refusal for the startup rules' violations <var>pViolations</var>
/// (<code>pViolations(n) = $ListBuild(field, code)</code>): the first violation's code and sentence, with
/// <code>detail.violations</code> naming each.</p>
ClassMethod StartupFault(ByRef pViolations, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tRows = []
    For tI = 1:1:+$Get(pViolations) {
        Set tCode = $List(pViolations(tI), 2)
        Do tRows.%Push({"field": ($List(pViolations(tI), 1)), "code": (tCode), "reason": (##class(OcuPilot.Api.EncryptionError).ReasonFor(tCode))})
    }
    Set tCode = $List(pViolations(1), 2)
    Set pHttpStatus = 422
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, tCode, ##class(OcuPilot.Api.EncryptionError).ReasonFor(tCode))
    Do pFault.%Set("detail", {"violations": (tRows)})
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>A vendor refusal of the startup settings write in the product's terms: a violation the admin port
/// mapped to <parameter>OcuPilot.Api.EncryptionError.STARTUPREQUIRED</parameter> is 409 with its sentence.
/// The vendor's #5001, which <parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter> maps to a
/// credentials violation, is 422 on <code>AdminPassword</code> only when the write carried credentials
/// (<var>pCredentials</var>): it is also the code of the vendor's internal faults, so any other #5001 is the
/// fault as it is, without that row. The admin port has logged each.</p>
ClassMethod StartupMapped(pSC As %Status, pCredentials As %Boolean, ByRef pHttpStatus As %Integer, ByRef pFault As %DynamicObject) As %Status [ Private ]
{
    Set tCode = ##class(OcuPilot.Api.EncryptionError).#STARTUPREQUIRED
    If ..Carries(pFault, tCode) Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, tCode, ##class(OcuPilot.Api.EncryptionError).ReasonFor(tCode), .pHttpStatus, .pFault)
    Set tCredentials = ##class(OcuPilot.Api.EncryptionError).#KEYFILECREDENTIALS
    If ..Carries(pFault, tCredentials) {
        If pCredentials Quit ..Violation(tCredentials, "AdminPassword", .pHttpStatus, .pFault)
        If $IsObject(pFault) Do pFault.%Remove("detail")
        Quit pSC
    }
    Quit ..Mapped(pSC, "", .pHttpStatus, .pFault)
}

/// <p>The configured KMIP servers' names, in <var>pNames</var>, read through the vendor's own
/// <code>Security.KMIPServer:List</code> in <code>%SYS</code> (AD-16) after the endpoint's
/// <code>%Admin_Secure:USE</code> gate (AD-27's named case, Story 18.23). A refusal or a throw fails the
/// read.</p>
ClassMethod KmipNames(Output pNames As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pNames = []
    Set pHttpStatus = 0
    Set pFault = ""
    If '$System.Security.Check("%Admin_Secure", "USE") {
        Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tDetail)
        Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, {"failedPair": "%Admin_Secure:USE"})
    }
    Set tError = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Security.KMIPServer:List")
        Set tError = tRS.Execute("*")
        If $$$ISOK(tError) {
            Set tNextSC = $$$OK
            While tRS.Next(.tNextSC) {
                Do pNames.%Push(tRS.Get("Name") _ "")
            }
            If $$$ISERR(tNextSC) Set tError = tNextSC
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tError = ex.AsStatus()
    }
    If $$$ISERR(tError) {
        Set pNames = []
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault("the configured KMIP servers could not be read", tError, pFault.code)
        Quit tSC
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p><parameter>KMIPSERVERSTYPE</parameter>: <code>{Names}</code>, <method>KmipNames</method>'s answer.</p>
ClassMethod KmipServers(Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..KmipNames(.tNames, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pResult = {}
    Do pResult.%Set("Names", tNames)
    Quit $$$OK
}

/// <p>Which of <parameter>STARTUPDATABASES</parameter> are encrypted on disk, by name in that order, in
/// <var>pNames</var>: each database read by <method>DatabaseEncryption</method>, after the endpoint's
/// <code>%Admin_Secure:USE</code> gate (AD-27's named case, Story 18.23). A setting turned off leaves its
/// database encrypted until the next start converts it, so this answers what the next start needs where the
/// settings cannot. A refusal, a database that cannot be found or opened, or a throw fails the read.</p>
ClassMethod EncryptedOnDisk(Output pNames As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pNames = []
    Set pHttpStatus = 0
    Set pFault = ""
    If '$System.Security.Check("%Admin_Secure", "USE") {
        Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tDetail)
        Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, {"failedPair": "%Admin_Secure:USE"})
    }
    Set tError = $$$OK
    Try {
        For tI = 1:1:$Length(..#STARTUPDATABASES, ",") {
            Set tName = $Piece(..#STARTUPDATABASES, ",", tI)
            Set tError = ..DatabaseEncryption(tName, .tDirectory, .tEncrypted)
            If $$$ISERR(tError) Quit
            If tEncrypted Do pNames.%Push(tName)
        }
    } Catch ex {
        Set tError = ex.AsStatus()
    }
    If $$$ISERR(tError) {
        Set pNames = []
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault("the startup databases' encryption on disk could not be read", tError, pFault.code)
        Quit tSC
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether database <var>pName</var> is encrypted on disk, in <var>pEncrypted</var>, and its configured
/// directory, in <var>pDirectory</var>: the directory <code>Config.Databases</code> holds, opened through the
/// vendor's own <code>SYS.Database</code> and its <code>EncryptedDB</code> read, in <code>%SYS</code> (AD-16).
/// A database that cannot be found or opened, or a throw, answers an error. Called by
/// <method>EncryptedOnDisk</method> after its gate, never by a caller of the port.</p>
ClassMethod DatabaseEncryption(pName As %String, Output pDirectory As %String, Output pEncrypted As %Boolean) As %Status [ Private ]
{
    Set pDirectory = ""
    Set pEncrypted = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tSC = ##class(Config.Databases).Get(pName, .tProps)
        If $$$ISOK(tSC) {
            Set pDirectory = $Get(tProps("Directory"))
            Set tOpenSC = $$$OK
            Set tDatabase = ##class(SYS.Database).%OpenId(pDirectory, , .tOpenSC)
            If $IsObject(tDatabase) {
                Set pEncrypted = ''tDatabase.EncryptedDB
            } Else {
                Set tSC = $Select($$$ISERR(tOpenSC): tOpenSC, 1: $$$ERROR($$$GeneralError, pName _ " could not be opened"))
            }
            Set tDatabase = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><parameter>ENCRYPTEDDATABASESTYPE</parameter>: <code>{Encrypted}</code>, <method>EncryptedOnDisk</method>'s
/// answer.</p>
ClassMethod EncryptedDatabases(Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..EncryptedOnDisk(.tNames, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pResult = {}
    Do pResult.%Set("Encrypted", tNames)
    Quit $$$OK
}

/// <p>Whether <var>pA</var> and the non-empty <var>pB</var> name one file once normalized, compared
/// exactly.</p>
ClassMethod SameFile(pA As %String, pB As %String) As %Boolean
{
    If ($Get(pA) = "") || ($Get(pB) = "") Quit 0
    Quit (##class(%File).NormalizeFilename(pA) = ##class(%File).NormalizeFilename(pB))
}

/// <p><var>pObject</var>'s scalar <var>pField</var> as text, or <code>""</code>.</p>
ClassMethod StartupText(pObject, pField As %String) As %String
{
    If '$IsObject($Get(pObject)) || 'pObject.%IsA("%Library.DynamicObject") Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType '= "string") && (tType '= "number") Quit ""
    Quit pObject.%Get(pField) _ ""
}

/// <p>The values a branch reads: each of <var>pPlain</var> from the query, each of <var>pSecret</var>
/// from the body, as strings.</p>
ClassMethod Values(ByRef pQuery, pBody As %DynamicAbstractObject, pPlain As %List, pSecret As %List) As %DynamicObject [ Private ]
{
    Set tValues = {}
    For tI = 1:1:$ListLength(pPlain) {
        Set tName = $List(pPlain, tI)
        Do tValues.%Set(tName, $Get(pQuery(tName)) _ "", "string")
    }
    For tI = 1:1:$ListLength(pSecret) {
        Set tName = $List(pSecret, tI)
        Set tValue = ""
        If $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
            Set tType = pBody.%GetTypeOf(tName)
            If (tType = "string") || (tType = "number") Set tValue = pBody.%Get(tName) _ ""
        }
        Do tValues.%Set(tName, tValue, "string")
        Set tValue = ""
    }
    Quit tValues
}

/// <p>Whether <var>pNames</var> lists <var>pName</var>, compared without regard to case, as the vendor
/// compares administrators (measured).</p>
ClassMethod Listed(pNames As %DynamicArray, pName As %String) As %Boolean [ Private ]
{
    Set tListed = 0
    Set tWanted = $ZConvert(pName, "U")
    Set tIterator = pNames.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        If $ZConvert(tName, "U") = tWanted Set tListed = 1 Quit
    }
    Quit tListed
}

/// <p>A vendor refusal of a write, in the product's terms: a credentials violation the admin port
/// mapped (<parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter>) is 422 on its field; a 409 is
/// <code>TOOL.ARGUMENTS</code> carrying <var>pConflict</var>; anything else is the fault as it is.</p>
ClassMethod Mapped(pSC As %Status, pConflict As %String, ByRef pHttpStatus As %Integer, ByRef pFault As %DynamicObject) As %Status [ Private ]
{
    If $IsObject($Get(pFault)) && (pFault.%GetTypeOf("detail") = "object") && (pFault.%Get("detail").%GetTypeOf("violations") = "array") {
        Set tIterator = pFault.%Get("detail").%Get("violations").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) || (tRow.%Get("code") '= ##class(OcuPilot.Api.EncryptionError).#KEYFILECREDENTIALS) Continue
            Quit
        }
        If $IsObject($Get(tRow)) && (tRow.%Get("code") = ##class(OcuPilot.Api.EncryptionError).#KEYFILECREDENTIALS) Quit ..Violation(tRow.%Get("code"), tRow.%Get("field"), .pHttpStatus, .pFault)
    }
    If (+$Get(pHttpStatus) = 409) && (pConflict '= "") Quit ..Arguments(pConflict, .pHttpStatus, .pFault)
    Quit pSC
}

/// <p>The 422 refusal <var>pCode</var> on <var>pField</var>, with nothing sent.</p>
ClassMethod Violation(pCode As %String, pField As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill tViolations
    Set tViolations = 1
    Set tViolations(1) = $ListBuild(pField, pCode)
    Quit ##class(OcuPilot.Area.Security.EncryptionRules).Fault(.tViolations, .pHttpStatus, .pFault)
}

/// <p>The 400 <code>TOOL.ARGUMENTS</code> refusal carrying <var>pProblem</var> as
/// <code>detail.problem</code>, with nothing sent.</p>
ClassMethod Arguments(pProblem As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS, .pHttpStatus, .pFault, {"problem": (pProblem)})
}

/// <p>404 <code>PORT.NOTFOUND</code>, logging nothing: the target is not there (AD-2).</p>
ClassMethod Absent(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Do ##class(OcuPilot.Kernel.Fault).Outcome(404, $$$OK, .pFault, .tDetail)
    Set pHttpStatus = 404
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
}

/// <p>The admin port's answer: each branch is the vendor's own routes.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s write branches as a script (AD-59): each is one <code>rest</code> step
/// against the vendor's route with the key file as the resolved path, the body built as
/// <method>Invoke</method> builds it from the query and the body handed here, whose passwords are
/// placeholders. A key file the port would refuse, or a rule a non-secret argument breaks, renders no
/// call and one <code>comment</code> step carrying the refusal's sentence. The lists' state checks are
/// guards a script cannot carry. An activation and a deactivation are <method>KeySnippet</method>'s, and
/// a startup settings write <method>StartupSnippet</method>'s. Every other call is the admin port's
/// script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ((pEndpoint = ..#FILEENDPOINT) && (pType = "ACTIVATE")) || ((pEndpoint = ..#ACTIVEENDPOINT) && (pType = "DEACTIVATE")) Quit ..KeySnippet(pEndpoint, pType, .pQuery, pBody, pContext)
    If (pEndpoint = ..#SETTINGSENDPOINT) && (pType = "PUT") Quit ..StartupSnippet(.pQuery, pBody, pContext)
    Set tWrite = ((pEndpoint = ..#FILEENDPOINT) && (pType = "POST")) || ((pEndpoint = ..#ADMINSENDPOINT) && ((pType = "POST") || (pType = "DELETE"))) || ((pEndpoint = ..#KEYSENDPOINT) && ((pType = "POST") || (pType = "DELETE")))
    If 'tWrite Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    If '..Named(.pQuery, .tRoot, .tPath) Quit [(..Step("comment", ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS))]
    Set tPlain = $Case(pEndpoint _ "/" _ pType, ..#FILEENDPOINT _ "/POST": $ListBuild("AdminName", "KeyLen", "Description"), ..#ADMINSENDPOINT _ "/POST": $ListBuild("OldAdminName", "NewAdminName"), ..#KEYSENDPOINT _ "/POST": $ListBuild("AdminName", "KeyLen", "Description"), : "")
    Set tSecret = $Case(pEndpoint _ "/" _ pType, ..#FILEENDPOINT _ "/POST": $ListBuild("AdminPassword"), ..#ADMINSENDPOINT _ "/POST": $ListBuild("OldAdminPassword", "NewAdminPassword"), ..#KEYSENDPOINT _ "/POST": $ListBuild("AdminPassword"), : "")
    Set tValues = ..Values(.pQuery, pBody, tPlain, tSecret)
    Kill tViolations
    Do ##class(OcuPilot.Area.Security.EncryptionRules).Violations(tValues, $ListBuild("AdminName", "KeyLen", "OldAdminName", "NewAdminName"), .tViolations)
    Set tBroken = ""
    For tI = 1:1:+$Get(tViolations) {
        If $ListFind(tPlain, $List(tViolations(tI), 1)) Set tBroken = $List(tViolations(tI), 2) Quit
    }
    If tBroken '= "" Quit [(..Step("comment", ##class(OcuPilot.Api.EncryptionError).ReasonFor(tBroken)))]
    If pEndpoint = ..#FILEENDPOINT {
        Set tSC = ..CheckCreate(tRoot, tPath, .tFile, .tHttp, .tFault)
    } Else {
        Set tSC = ..Resolve(tRoot, tPath, "source", .tFile, .tHttp, .tFault)
    }
    If $$$ISERR(tSC) Quit [(..Step("comment", $Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)))]
    Kill tQuery
    Set tSend = ""
    If pEndpoint = ..#FILEENDPOINT {
        Set tSend = {"File": (tFile)}
        Do tSend.%Set("AdminName", tValues.%Get("AdminName"), "string")
        Do tSend.%Set("AdminPassword", tValues.%Get("AdminPassword"), "string")
        Do tSend.%Set("KeyLen", +tValues.%Get("KeyLen"), "number")
        Do tSend.%Set("Description", tValues.%Get("Description"), "string")
    } Else {
        Set tQuery(..#FILEPARAM) = tFile
        If (pEndpoint = ..#ADMINSENDPOINT) && (pType = "DELETE") Set tQuery(..#ADMINPARAM) = $Get(pQuery("Admin"))
        If (pEndpoint = ..#KEYSENDPOINT) && (pType = "DELETE") Set tQuery(..#KEYPARAM) = $Get(pQuery("KeyId"))
        If (pEndpoint = ..#ADMINSENDPOINT) && (pType = "POST") {
            Set tSend = {}
            For tName = "OldAdminName", "OldAdminPassword", "NewAdminName", "NewAdminPassword" Do tSend.%Set(tName, tValues.%Get(tName), "string")
        }
        If (pEndpoint = ..#KEYSENDPOINT) && (pType = "POST") {
            Set tSend = {}
            Do tSend.%Set("AdminName", tValues.%Get("AdminName"), "string")
            Do tSend.%Set("AdminPassword", tValues.%Get("AdminPassword"), "string")
            Do tSend.%Set("Description", tValues.%Get("Description"), "string")
            Do tSend.%Set("KeyLen", +tValues.%Get("KeyLen"), "number")
        }
    }
    Set tStep = ..RestStep(pEndpoint, pType, .tQuery, tSend, pContext)
    If '$IsObject(tStep) Quit []
    Quit [(tStep)]
}

/// <p>The startup settings write as a script (AD-59, Story 18.23): one <code>rest</code> step to
/// <code>Settings</code> <code>PUT</code> carrying <method>StartupBody</method>'s body over the settings read
/// now, with the startup key file resolved and the password the placeholder
/// <code>&lt;AdminPassword&gt;</code>. The version gate's refusal, a file named by the caller, and a rule
/// <method>StartupProblems</method> answers without the password each render one <code>comment</code> step
/// carrying the refusal's sentence and no call.</p>
ClassMethod StartupSnippet(ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray [ Private ]
{
    Set tSC = ..SettingsGate(.tHttp, .tFault)
    If $$$ISERR(tSC) Quit [(..Step("comment", ..FaultReason($Get(tFault))))]
    If ..NamesKeyFile(..#SETTINGSENDPOINT, .pQuery, pBody) Quit [(..Step("comment", ##class(OcuPilot.Api.Error).#REASONPATHNAME))]
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit [(..Step("comment", ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS))]
    Kill tRead
    Set tSC = ..Call(..#SETTINGSENDPOINT, "GET", .tRead, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Quit [(..Step("comment", ..FaultReason($Get(tFault))))]
    Set tWanted = ..Wanted(tFresh, pBody, .tProblem)
    If tProblem '= "" Quit [(..Step("comment", ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS))]
    Set tAdmin = $Get(pQuery("AdminName"))
    If (tAdmin = "") && (pBody.%GetTypeOf("AdminName") = "string") Set tAdmin = pBody.%Get("AdminName")
    Set tSC = ..StartupProblems(tWanted, tFresh, $Get(pQuery(..#ROOTPARAM)), $Get(pQuery(..#PATHPARAM)), tAdmin, "", 0, .tKeyFile, .tNewFile, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit [(..Step("comment", ..FaultReason($Get(tFault))))]
    Set tSend = ..StartupBody(tWanted, tFresh, tKeyFile, tNewFile, tAdmin, "<AdminPassword>")
    Kill tQuery
    Set tStep = ..RestStep(..#SETTINGSENDPOINT, "PUT", .tQuery, tSend, pContext)
    If '$IsObject(tStep) Quit []
    Quit [(tStep)]
}

/// <p>The sentence fault <var>pFault</var> carries, or the generic one.</p>
ClassMethod FaultReason(pFault) As %String [ Private ]
{
    If $IsObject(pFault) && (pFault.%Get("reason") '= "") Quit pFault.%Get("reason")
    Quit ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
}

/// <p>Story 18.22's two writes as a script (AD-59): an activation is one <code>rest</code> step to
/// <code>File</code> <code>ACTIVATE</code> with the resolved key file as <code>file</code> and the body
/// <code>{Action, AdminName, AdminPassword}</code>, the password the placeholder of the body handed here;
/// a deactivation is one to <code>Key</code> <code>DEACTIVATE</code> with <code>id</code> the
/// <code>KeyId</code> and the composed body, its password the placeholder. An action outside the write's own, a missing key file or
/// key, an administrator name the rules refuse, and a key file location <class>OcuPilot.Port.PathPort</class>
/// refuses each render one <code>comment</code> step carrying the refusal's sentence and no call; the key
/// file's administrators and keys, and the active list, are guards a script cannot carry.</p>
ClassMethod KeySnippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray [ Private ]
{
    Set tAction = $Get(pQuery(..#ACTIONPARAM))
    Kill tQuery
    If pType = "DEACTIVATE" {
        Set tKey = $Get(pQuery("KeyId"))
        If (..KindOf(tAction, ..#DEACTIVATIONS) = "") || (tKey = "") Quit [(..Step("comment", ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS))]
        Set tQuery("id") = tKey
        Set tSend = {}
        Do tSend.%Set(..#ACTIONPARAM, tAction, "string")
        Do tSend.%Set("AdminName", "", "string")
        ; AD-59: a name the credential pattern matches reads as its placeholder, though the vendor
        ; never reads this one.
        Do tSend.%Set("AdminPassword", "<AdminPassword>", "string")
    } Else {
        If (..KindOf(tAction, ..#ACTIVATIONS) = "") || '..Named(.pQuery, .tRoot, .tPath) Quit [(..Step("comment", ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS))]
        Set tValues = ..Values(.pQuery, pBody, $ListBuild("AdminName"), $ListBuild("AdminPassword"))
        Kill tViolations
        Do ##class(OcuPilot.Area.Security.EncryptionRules).Violations(tValues, $ListBuild("AdminName"), .tViolations)
        If +$Get(tViolations) > 0 Quit [(..Step("comment", ##class(OcuPilot.Api.EncryptionError).ReasonFor($List(tViolations(1), 2))))]
        Set tSC = ..Resolve(tRoot, tPath, "source", .tFile, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit [(..Step("comment", $Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)))]
        Set tQuery(..#FILEPARAM) = tFile
        Set tSend = {}
        Do tSend.%Set(..#ACTIONPARAM, tAction, "string")
        Do tSend.%Set("AdminName", tValues.%Get("AdminName"), "string")
        Do tSend.%Set("AdminPassword", tValues.%Get("AdminPassword"), "string")
        Set tValues = ""
    }
    Set tStep = ..RestStep(pEndpoint, pType, .tQuery, tSend, pContext)
    Set tSend = ""
    If '$IsObject(tStep) Quit []
    Quit [(tStep)]
}

}
