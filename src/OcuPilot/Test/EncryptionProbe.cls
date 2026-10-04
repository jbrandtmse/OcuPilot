/// <p>Test-only helper for Story 18.7's encryption key file suites. It seeds, in <code>%SYS</code> by
/// explicit save and restore, a probe directory under the manager directory, probe key files and text
/// files inside it, and probe principals, and it takes canonical snapshots of what a key file write can
/// change, so a run can be compared with the state before it. Every principal it creates or removes is
/// named with <parameter>PREFIX</parameter> (compared upper-cased); every file it creates sits in
/// <method>Directory</method>, which it creates only when absent and marks, and removes only when its
/// marker is there.</p>
/// <p>It never activates or deactivates a key and never changes a <class>Security.System</class>
/// property. <method>EncryptionFacts</method> reads the encryption state a test asserts unchanged.</p>
/// <p><method>Run</method> issues one call through <class>OcuPilot.Port.EncryptionPort</class> (or a
/// named port) and times it; <method>RunAs</method> runs a plan of such calls as a probe principal in a
/// child process.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EncryptionProbe Extends %RegisteredObject
{

/// <p>The prefix every probe user and role name starts with, compared upper-cased.</p>
Parameter PREFIX = "OCUPROBE187";

/// <p>The probe directory's name under the manager directory.</p>
Parameter DIRECTORYNAME = "ocuprobe187";

/// <p>The marker file a probe directory this helper created carries.</p>
Parameter MARKER = "OCUPROBE187.marker";

/// <p>The probe principal the gate tests run as, and its role.</p>
Parameter PRINCIPAL = "OcuProbe187T0User";

Parameter PRINCIPALROLE = "OcuProbe187T0Role";

/// <p>The probe principal's resources by default: Security's two pairs and the file-system pair.</p>
Parameter PRINCIPALRESOURCES = "%Admin_Secure:U,%Admin_FileSystemAccess:U,%DB_IRISSYS:R";

/// <p>The probe key file administrator and its password, a test literal.</p>
Parameter ADMIN = "OcuProbe187Admin";

Parameter PASSWORD = "OcuProbe187-Pass1";

Parameter PORT = "OcuPilot.Port.EncryptionPort";

/// <p>The <class>Security.System</class> properties a key file write must leave as found.</p>
Parameter SYSTEMPROPERTIES = "DBEncStartMode,DBEncJournal,DBEncIRISSecurity,DBEncIRISTemp,AuditEncrypt,DBEncStartKMIPServer,DBEncStartKeyFile,DBEncDefaultKeyID,DBEncJournalKeyID";

/// <p>Whether <var>pName</var> is a probe principal name.</p>
ClassMethod IsProbe(pName As %String) As %Boolean
{
    Quit ($Extract($ZConvert(pName, "U"), 1, $Length(..#PREFIX)) = ..#PREFIX)
}

/// <p>The manager directory, normalized with its trailing separator.</p>
ClassMethod Manager() As %String
{
    Quit ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory())
}

/// <p>The probe directory, with its trailing separator.</p>
ClassMethod Directory() As %String
{
    Quit ##class(%File).NormalizeDirectory(..Manager() _ ..#DIRECTORYNAME)
}

/// <p>The probe directory's root as the Allowed directories screen lists it on a stock instance, the
/// manager directory, and its relative name: what a caller sends as <code>root</code> and the leading
/// part of <code>path</code>.</p>
ClassMethod Root() As %String
{
    Quit $System.Util.ManagerDirectory()
}

/// <p>The relative name of the probe file <var>pName</var> under <method>Root</method>.</p>
ClassMethod RelativeName(pName As %String) As %String
{
    Quit ..#DIRECTORYNAME _ "/" _ pName
}

/// <p>The full path of the probe file <var>pName</var>.</p>
ClassMethod FilePath(pName As %String) As %String
{
    Quit ..Directory() _ pName
}

/// <p>Whether the probe directory exists.</p>
ClassMethod DirectoryExists() As %Boolean
{
    Quit ##class(%File).DirectoryExists(..Directory())
}

/// <p>Create the probe directory and its marker when the directory is absent; <var>pCreated</var> is 1
/// when this call created it. A directory that exists without the marker is not this helper's and is
/// an error.</p>
ClassMethod SeedDirectory(Output pCreated As %Boolean) As %Status
{
    Set pCreated = 0
    Set tDirectory = ..Directory()
    If ##class(%File).DirectoryExists(tDirectory) {
        If '##class(%File).Exists(tDirectory _ ..#MARKER) Quit $$$ERROR($$$GeneralError, "the probe directory exists and carries no probe marker")
        Quit $$$OK
    }
    If '##class(%File).CreateDirectoryChain(tDirectory) Quit $$$ERROR($$$GeneralError, "the probe directory could not be created")
    Set pCreated = 1
    Quit ..WriteText(tDirectory _ ..#MARKER, ..#PREFIX)
}

/// <p>Remove the probe directory and everything in it, only when it carries the marker.</p>
ClassMethod RemoveDirectory() As %Status
{
    Set tDirectory = ..Directory()
    If '##class(%File).DirectoryExists(tDirectory) Quit $$$OK
    If '##class(%File).Exists(tDirectory _ ..#MARKER) Quit $$$ERROR($$$GeneralError, "the probe directory carries no probe marker and is left in place")
    If '##class(%File).RemoveDirectoryTree(tDirectory) Quit $$$ERROR($$$GeneralError, "the probe directory could not be removed")
    Quit $$$OK
}

/// <p>Whether <var>pName</var> is a name a probe file may take: one to eight <code>/</code>-separated
/// names of letters, digits, dots, underscores and dashes, no <code>..</code>.</p>
ClassMethod NameAdmitted(pName As %String) As %Boolean
{
    Quit ##class(OcuPilot.Port.PathPort).NameAdmitted(pName, "file")
}

/// <p>Create the probe key file <var>pName</var> with administrator <var>pAdmin</var>, password
/// <var>pPassword</var>, one key of <var>pKeyLen</var> bits and description <var>pDescription</var>
/// (test-only seeding in <code>%SYS</code> through the vendor's own routine, as the classic create page
/// calls it); <var>pKeyId</var> is the new key's identifier. The probe directory must exist with its
/// marker and the file must be absent.</p>
ClassMethod SeedKeyFile(pName As %String, pAdmin As %String = {..#ADMIN}, pPassword As %String = {..#PASSWORD}, pKeyLen As %Integer = 256, pDescription As %String = "OCUPROBE187 seeded", Output pKeyId As %String) As %Status
{
    Set pKeyId = ""
    If '..NameAdmitted(pName) Quit $$$ERROR($$$GeneralError, "a probe file name is a relative name")
    If '##class(%File).Exists(..Directory() _ ..#MARKER) Quit $$$ERROR($$$GeneralError, "the probe directory is absent")
    Set tPath = ..FilePath(pName)
    If ##class(%File).Exists(tPath) Quit $$$ERROR($$$GeneralError, "the probe key file already exists")
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tCreateSC = $$$OK
        Set pKeyId = $$Create^EncryptionKey(tPath, pAdmin, pPassword, pKeyLen \ 8, .tCreateSC, "2.0", pDescription)
        Set $NAMESPACE = tOrigNS
        Set tSC = tCreateSC
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the probe text file <var>pName</var> holding <var>pText</var>.</p>
ClassMethod SeedTextFile(pName As %String, pText As %String = "OCUPROBE187 is not a key file") As %Status
{
    If '..NameAdmitted(pName) Quit $$$ERROR($$$GeneralError, "a probe file name is a relative name")
    If '##class(%File).Exists(..Directory() _ ..#MARKER) Quit $$$ERROR($$$GeneralError, "the probe directory is absent")
    Quit ..WriteText(..FilePath(pName), pText)
}

/// <p>Write <var>pText</var> as the whole of file <var>pPath</var>.</p>
ClassMethod WriteText(pPath As %String, pText As %String) As %Status [ Private ]
{
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Set tSC = tStream.LinkToFile(pPath)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = tStream.Write(pText)
    If $$$ISERR(tSC) Quit tSC
    Quit tStream.%Save()
}

/// <p>The probe file <var>pName</var> as <code>exists|size</code>.</p>
ClassMethod FileState(pName As %String) As %String
{
    Set tPath = ..FilePath(pName)
    If '##class(%File).Exists(tPath) Quit "0|"
    Quit "1|" _ ##class(%File).GetFileSize(tPath)
}

/// <p>The probe key file <var>pName</var>'s administrators and keys as the vendor's own routine reads
/// them in <code>%SYS</code>: <code>{admins: [name], keys: [{Id, KeyLen, Description}]}</code>, or an
/// object carrying <code>error</code>. No key material is read.</p>
ClassMethod Contents(pName As %String) As %DynamicObject
{
    Set tOut = {}
    Set tPath = ..FilePath(pName)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tAdminSC = $$$OK
        Set tAdmins = $$AdminList^EncryptionKey(tPath, .tAdminSC, 1)
        Set tKeySC = $$$OK
        Set tKeys = $$KeyList^EncryptionKey(tPath, .tKeySC)
        Set tRows = []
        If $$$ISOK(tKeySC) && (tKeys '= "") {
            For tI = 1:1:$Length(tKeys, ",") {
                Set tId = $Piece(tKeys, ",", tI)
                Set tLen = $$KeyLenGet^EncryptionKey(tPath, tId, .tLenSC)
                Set tDesc = $$KeyDescGet^EncryptionKey(tPath, tId, .tDescSC)
                Do tRows.%Push({"Id": (tId), "KeyLen": (tLen), "Description": (tDesc)})
            }
        }
        Set $NAMESPACE = tOrigNS
        Set tNames = []
        If $$$ISOK(tAdminSC) && (tAdmins '= "") {
            For tI = 1:1:$Length(tAdmins, ",") Do tNames.%Push($Piece(tAdmins, ",", tI))
        }
        Do tOut.%Set("admins", tNames)
        Do tOut.%Set("keys", tRows)
        If $$$ISERR(tAdminSC) Do tOut.%Set("adminError", $System.Status.GetErrorCodes(tAdminSC), "string")
        If $$$ISERR(tKeySC) Do tOut.%Set("keyError", $System.Status.GetErrorCodes(tKeySC), "string")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do tOut.%Set("error", ex.DisplayString(), "string")
    }
    Quit tOut
}

/// <p>Create the probe role <var>pRole</var> granting <var>pResources</var> (the
/// <class>Security.Roles</class> form, comma-separated) plus read on the install namespace's routines
/// database, and the probe account <var>pUser</var> holding it alone with password <var>pPassword</var>
/// (a random one when empty), replacing either when it exists.</p>
ClassMethod SeedPrincipal(pUser As %String = {..#PRINCIPAL}, pRole As %String = {..#PRINCIPALROLE}, pResources As %String = {..#PRINCIPALRESOURCES}, pPassword As %String = "") As %Status
{
    If '..IsProbe(pUser) || '..IsProbe(pRole) Quit $$$ERROR($$$GeneralError, "a probe principal's names start with " _ ..#PREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set $NAMESPACE = "%SYS"
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        Set tNamespace = ""
        Set tDatabase = ""
        If ##class(Security.Users).Exists(pUser) Do ##class(Security.Users).Delete(pUser)
        If ##class(Security.Roles).Exists(pRole) Do ##class(Security.Roles).Delete(pRole)
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot encryption probe (throwaway)", tCode _ $Select(pResources = "": "", 1: "," _ pResources), "")
        Set tPassword = $Select(pPassword = "": $System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18)), 1: pPassword)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(pUser, pRole, tPassword, "OcuPilot encryption probe (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.EncryptionProbe")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every probe object: the users and roles, each by its exact name, and the probe directory
/// when it carries the marker. <var>pRemaining</var> is how many survived, and the status is an error
/// when any did.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set pRemaining = 0
    Set tSC = $$$OK
    Set tUsers = ..ProbeNames("Security.Users:List", "Name")
    Set tRoles = ..ProbeNames("Security.Roles:List", "Name")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tUsers) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Delete($List(tUsers, tI)))
        }
        For tI = 1:1:$ListLength(tRoles) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete($List(tRoles, tI)))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Set tSC = $$$ADDSC(tSC, ..RemoveDirectory())
    Set pRemaining = ..Remaining()
    If pRemaining > 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, pRemaining _ " probe object(s) survived their removal"))
    Quit tSC
}

/// <p>How many probe objects the instance holds: users, roles and the probe directory.</p>
ClassMethod Remaining() As %Integer
{
    Quit $ListLength(..ProbeNames("Security.Users:List", "Name")) + $ListLength(..ProbeNames("Security.Roles:List", "Name")) + ..DirectoryExists()
}

/// <p>The names column <var>pColumn</var> of query <var>pQuery</var> answers that start with
/// <parameter>PREFIX</parameter>, compared upper-cased, read in <code>%SYS</code>.</p>
ClassMethod ProbeNames(pQuery As %String, pColumn As %String) As %List
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New(pQuery)
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get(pColumn)
                If $Extract($ZConvert(tName, "U"), 1, $Length(..#PREFIX)) = ..#PREFIX Set tNames = tNames _ $ListBuild(tName)
            }
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tNames
}

/// <p>One call through <parameter>PORT</parameter> (or <var>pPort</var>), timed: <var>pMethod</var> is
/// <code>Invoke</code> or, on <class>OcuPilot.Port.EncryptionPort</class>, <code>Call</code>, which
/// passes the port's own rules. The answer is
/// <code>{endpoint, type, ok, http, seconds, result, fault, status, codes, location}</code>,
/// <code>seconds</code> the wall clock to four decimals.</p>
ClassMethod Run(pEndpoint As %String, pType As %String, pQuery As %DynamicObject = "", pBody As %DynamicAbstractObject = "", pPort As %String = "", pMethod As %String = "Invoke") As %DynamicObject
{
    Set tOut = {}
    Do tOut.%Set("endpoint", pEndpoint, "string")
    Do tOut.%Set("type", pType, "string")
    Kill tQuery
    If $IsObject(pQuery) {
        Set tIterator = pQuery.%GetIterator()
        While tIterator.%GetNext(.tName, .tValue) {
            Set tQuery(tName) = tValue
        }
    }
    Set tPort = $Select(pPort = "": ..#PORT, 1: pPort)
    Set tLocation = ""
    Set tStart = $ZHorolog
    Try {
        If pMethod = "Call" {
            Set tSC = $ClassMethod(tPort, "Call", pEndpoint, pType, .tQuery, pBody, .tResult, .tHttp, .tFault, .tLocation)
        } Else {
            Set tSC = $ClassMethod(tPort, "Invoke", pEndpoint, pType, .tQuery, pBody, .tResult, .tHttp, .tFault)
        }
        Do tOut.%Set("ok", $$$ISOK(tSC), "boolean")
        If $$$ISERR(tSC) Do tOut.%Set("status", $System.Status.GetErrorText(tSC), "string")
    } Catch ex {
        Do tOut.%Set("ok", 0, "boolean")
        Do tOut.%Set("status", ex.DisplayString(), "string")
    }
    Do tOut.%Set("seconds", $Normalize($ZHorolog - tStart, 4), "number")
    Do tOut.%Set("http", +$Get(tHttp), "number")
    If $Get(tLocation) '= "" Do tOut.%Set("location", tLocation, "string")
    If $IsObject($Get(tResult)) Do tOut.%Set("result", tResult)
    If $IsObject($Get(tFault)) Do tOut.%Set("fault", tFault)
    Quit tOut
}

/// <p>Run the JSON array <var>pPlan</var> of <method>Run</method> steps,
/// <code>[{endpoint, type, query, body, port, method}]</code>, as the probe account <var>pUser</var> in a
/// child process, and answer <code>{username, loggedIn, steps}</code>, or an object carrying
/// <code>error</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray, pWaitSeconds As %Integer = 120) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.EncryptionProbe).Child($Job, pUser, tPlan)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", pWaitSeconds)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within " _ pWaitSeconds _ " seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child process <method>RunAs</method> starts: log in as <var>pUser</var>, run each step of
/// <var>pPlan</var> through <method>Run</method>, and signal the answers to <var>pParent</var>.</p>
ClassMethod Child(pParent As %Integer, pUser As %String, pPlan As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUser), "boolean")
        Do tOut.%Set("username", $Username, "string")
        Set tSteps = []
        Set tIterator = ##class(%DynamicArray).%FromJSON(pPlan).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            Set tMethod = tStep.%Get("method")
            Do tSteps.%Push(..Run(tStep.%Get("endpoint"), tStep.%Get("type"), tStep.%Get("query"), tStep.%Get("body"), tStep.%Get("port"), $Select(tMethod = "": "Invoke", 1: tMethod)))
        }
        Do tOut.%Set("steps", tSteps)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Whether the instance needs a restart to activate a modified configuration parameter
/// (<code>Config.CPF.PendingRestart</code>, read in <code>%SYS</code>), with its reasons' text in
/// <var>pReasons</var>, one per <code>pReasons(n)</code>; -1 when it cannot be read.</p>
ClassMethod PendingRestart(Output pReasons) As %Integer
{
    Kill pReasons
    Set pReasons = 0
    Set tPending = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tReasons
        Set tPending = +##class(Config.CPF).PendingRestart(.tReasons)
        Set $NAMESPACE = tOrigNS
        For tI = 1:1:+$Get(tReasons) {
            Set pReasons(tI) = $Get(tReasons(tI))
        }
        Set pReasons = +$Get(tReasons)
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tPending = -1
    }
    Quit tPending
}

/// <p>The instance's encryption state as one object: each <parameter>SYSTEMPROPERTIES</parameter>
/// value of <class>Security.System</class> and whether a startup username is stored; the activated
/// database and data-element keys, the default and the journal key; journal encryption now and at
/// startup; how many databases are encrypted and each encrypted one's directory and key; and whether a
/// restart is pending, with its reasons. A key file write leaves every member as found.</p>
ClassMethod EncryptionFacts() As %DynamicObject
{
    Set tOut = {}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSystem = ##class(Security.System).%OpenId("SYSTEM")
        For tI = 1:1:$Length(..#SYSTEMPROPERTIES, ",") {
            Set tName = $Piece(..#SYSTEMPROPERTIES, ",", tI)
            Do tOut.%Set(tName, $Property(tSystem, tName) _ "", "string")
        }
        Do tOut.%Set("DBEncStartUsernameSet", (tSystem.DBEncStartUsername '= ""), "boolean")
        Set tSystem = ""
        Do tOut.%Set("activeKey", $SYSTEM.Security.System.GetDBEncKeyID() _ "", "string")
        Do tOut.%Set("activeKeys", $SYSTEM.Security.System.GetDBEncKeyIDList() _ "", "string")
        Do tOut.%Set("activeKeyLengths", $SYSTEM.Security.System.GetDBEncKeyLenList() _ "", "string")
        Do tOut.%Set("dataElementKeys", $SYSTEM.Security.System.GetMKEncKeyIDList() _ "", "string")
        Do tOut.%Set("journalKey", $SYSTEM.Security.System.GetJrnEncKeyID(2) _ "", "string")
        Do tOut.%Set("journalEncryptedNow", ##class(%SYS.Journal.System).IsJournalEncryptionEnabled(1) _ "", "string")
        Do tOut.%Set("journalEncryptedAtStart", ##class(%SYS.Journal.System).IsJournalEncryptionEnabled(2) _ "", "string")
        Set tEncrypted = []
        Set tRS = ##class(%ResultSet).%New("SYS.Database:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                If tRS.Get("Encrypted") Do tEncrypted.%Push(tRS.Get("Directory") _ "|" _ tRS.Get("EncryptionKeyID"))
            }
        }
        Set tRS = ""
        Do tOut.%Set("encryptedDatabases", tEncrypted)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do tOut.%Set("error", ex.DisplayString(), "string")
    }
    Set tPending = ..PendingRestart(.tReasons)
    Set tReasonList = []
    For tI = 1:1:+$Get(tReasons) Do tReasonList.%Push($Get(tReasons(tI)))
    Do tOut.%Set("pendingRestart", tPending, "number")
    Do tOut.%Set("pendingReasons", tReasonList)
    Quit tOut
}

/// <p>A canonical snapshot of what a key file write can reach, as a sorted array of lines: the
/// encryption facts (<method>EncryptionFacts</method>); each process with its job type; the line counts
/// of <code>messages.log</code> and <code>alerts.log</code>; the monitor state; whether the probe
/// directory exists; and OcuPilot's own applications, roles and resources and the probe accounts.</p>
ClassMethod Snapshot() As %DynamicArray
{
    Kill tLines
    Set tFacts = ..EncryptionFacts()
    Set tIterator = tFacts.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tLines("encryption|" _ tKey _ "|" _ $Select($IsObject(tValue): tValue.%ToJSON(), 1: tValue)) = ""
    }
    Set tLines("probedirectory|" _ ..DirectoryExists()) = ""
    Set tPrefix = ..#PREFIX
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Security.Applications:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                If $ZConvert(tName, "L") '[ "ocupilot" Continue
                Kill tProperties
                Do ##class(Security.Applications).Get(tName, .tProperties)
                Set tLines("application|" _ tName _ "|" _ $Get(tProperties("NameSpace")) _ "|" _ $Get(tProperties("MatchRoles")) _ "|" _ $Get(tProperties("Enabled"))) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Roles:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                Set tProbe = ($Extract($ZConvert(tName, "U"), 1, $Length(tPrefix)) = tPrefix)
                If ($ZConvert(tName, "U") '[ "OCUPILOT") && 'tProbe Continue
                Kill tProperties
                Do ##class(Security.Roles).Get(tName, .tProperties)
                Set tLines("role|" _ tName _ "|" _ $Get(tProperties("Resources")) _ "|" _ $Get(tProperties("GrantedRoles"))) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Resources:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                If $ZConvert(tName, "U") '[ "OCUPILOT" Continue
                Set tLines("resource|" _ tName _ "|" _ tRS.Get("PublicPermission")) = ""
            }
        }
        Set tRS = ##class(%ResultSet).%New("Security.Users:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                If $Extract($ZConvert(tName, "U"), 1, $Length(tPrefix)) '= tPrefix Continue
                Set tLines("user|" _ tName _ "|" _ tRS.Get("Enabled") _ "|" _ tRS.Get("Roles")) = ""
            }
        }
        Set tRS = ""
        Set tLines("monitor|" _ $SYSTEM.Monitor.State()) = ""
        Set tPid = ""
        For {
            Set tPid = $Order(^$JOB(tPid))
            If tPid = "" Quit
            Set tType = ""
            Try {
                Set tProcess = ##class(%SYS.ProcessQuery).%OpenId(tPid)
                If $IsObject(tProcess) Set tType = tProcess.JobType
                Set tProcess = ""
            } Catch { Set tType = "?" }
            Set tLines("process|" _ tPid _ "|" _ tType) = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tLines("error|" _ ex.DisplayString()) = ""
    }
    For tFile = "messages.log", "alerts.log" {
        Set tLines("log|" _ tFile _ "|" _ ..LineCount(tFile)) = ""
    }
    Set tOut = []
    Set tLine = ""
    For {
        Set tLine = $Order(tLines(tLine))
        If tLine = "" Quit
        Do tOut.%Push(tLine)
    }
    Quit tOut
}

/// <p>The lines of <var>pAfter</var> not in <var>pBefore</var>, as <code>added</code>, and of
/// <var>pBefore</var> not in <var>pAfter</var>, as <code>removed</code>.</p>
ClassMethod Diff(pBefore As %DynamicArray, pAfter As %DynamicArray) As %DynamicObject
{
    Kill tBefore, tAfter
    Set tIterator = pBefore.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tBefore(tLine) = ""
    }
    Set tIterator = pAfter.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tAfter(tLine) = ""
    }
    Set tAdded = []
    Set tRemoved = []
    Set tLine = ""
    For {
        Set tLine = $Order(tAfter(tLine))
        If tLine = "" Quit
        If '$Data(tBefore(tLine)) Do tAdded.%Push(tLine)
    }
    Set tLine = ""
    For {
        Set tLine = $Order(tBefore(tLine))
        If tLine = "" Quit
        If '$Data(tAfter(tLine)) Do tRemoved.%Push(tLine)
    }
    Quit {"added": (tAdded), "removed": (tRemoved)}
}

/// <p>The number of lines of the manager directory's file <var>pFile</var>, or of those containing
/// <var>pContaining</var> when it is given; -1 when the file cannot be read.</p>
ClassMethod LineCount(pFile As %String, pContaining As %String = "") As %Integer
{
    Set tCount = 0
    If '##class(%File).Exists(..Manager() _ pFile) Quit 0
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If $$$ISERR(tStream.LinkToFile(..Manager() _ pFile)) Quit -1
    While 'tStream.AtEnd {
        Set tLine = tStream.ReadLine()
        If (pContaining = "") || (tLine [ pContaining) Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The lines of the manager directory's file <var>pFile</var> after its first <var>pFrom</var>
/// lines, as an array.</p>
ClassMethod LinesAfter(pFile As %String, pFrom As %Integer) As %DynamicArray
{
    Set tOut = []
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If $$$ISERR(tStream.LinkToFile(..Manager() _ pFile)) Quit tOut
    Set tCount = 0
    While 'tStream.AtEnd {
        Set tLine = tStream.ReadLine()
        Set tCount = tCount + 1
        If tCount > pFrom Do tOut.%Push(tLine)
    }
    Quit tOut
}

/// <p>The UTC instant the audit database stamps rows with, as <method>AuditSince</method> compares
/// it.</p>
ClassMethod Now() As %String
{
    Quit $ZDateTime($ZTimeStamp, 3, , 3)
}

/// <p>The audit rows recorded at or after <var>pSince</var> (<method>Now</method>'s form), as
/// <code>Source/Type/Name|Description|Username</code> lines in order, OcuPilot's own source
/// included; read in <code>%SYS</code>.</p>
ClassMethod AuditSince(pSince As %String) As %DynamicArray
{
    Set tOut = []
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventSource, EventType, Event, Description, Username FROM %SYS.Audit WHERE UTCTimeStamp >= ? ORDER BY UTCTimeStamp", pSince)
        While tRS.%Next() {
            Do tOut.%Push(tRS.%Get("EventSource") _ "/" _ tRS.%Get("EventType") _ "/" _ tRS.%Get("Event") _ "|" _ tRS.%Get("Description") _ "|" _ tRS.%Get("Username"))
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do tOut.%Push("error|" _ ex.DisplayString())
    }
    Quit tOut
}

/// <p>The composite id of the probe key file <var>pName</var>: the manager directory and its relative
/// name (AD-13).</p>
ClassMethod KeyFileId(pName As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..Root(), ..RelativeName(pName)))
}

/// <p>Mint <var>pToolClass</var>'s proposal for the probe key file <var>pName</var> from <var>pArgs</var>
/// (<code>root</code> and <code>path</code> added) for <var>pUser</var>, this process's user by default,
/// through the tool's own mint class over a completed turn seeded for that user; <var>pProposal</var>
/// is <code>""</code> when the mint refused, with its <code>detail.problem</code>, or the first
/// violation's <code>field:code</code>, or its code, in <var>pProblem</var>.</p>
ClassMethod Mint(pToolClass As %String, pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pProblem As %String, pUser As %String = {$Username}) As %Status
{
    Set pProposal = ""
    Set pHttp = 0
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tArgs = $Select($IsObject(pArgs): pArgs, 1: {})
    If tArgs.%GetTypeOf("root") = "unassigned" Do tArgs.%Set("root", ..Root(), "string")
    If tArgs.%GetTypeOf("path") = "unassigned" Do tArgs.%Set("path", ..RelativeName(pName), "string")
    Set tSC = $ClassMethod($ClassMethod(pToolClass, "MintClass"), "Mint", $Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), pUser, "", tTurnKey, tArgs, "OcuPilot.Kernel.Agent.Limits", .tResult, .pHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), tArgs.%Get("path"), $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
    If $IsObject($Get(tResult)) Set pProposal = tResult
    If $IsObject($Get(tFault)) {
        Set tDetail = tFault.%Get("detail")
        If $IsObject(tDetail) && (tDetail.%Get("problem") '= "") Set pProblem = tDetail.%Get("problem")
        If (pProblem = "") && $IsObject(tDetail) && (tDetail.%GetTypeOf("violations") = "array") && (tDetail.%Get("violations").%Size() > 0) Set pProblem = tDetail.%Get("violations").%Get(0).%Get("field") _ ":" _ tDetail.%Get("violations").%Get(0).%Get("code")
        If pProblem = "" Set pProblem = tFault.%Get("code")
    }
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal: " _ pHttp _ " " _ pProblem)
    Quit $$$OK
}

/// <p>Confirm <var>pProposal</var> with the secrets <var>pSecrets</var> through
/// <class>OcuPilot.Test.DatabaseConfirm</class> as this process's user, answering <code>http code</code>,
/// the first violation's <code>field:code</code> for a field refusal, with the confirm's answer in
/// <var>pResult</var>.</p>
ClassMethod Confirm(pProposal As %DynamicObject, pSecrets As %DynamicObject = "", Output pResult As %DynamicObject) As %String
{
    Set pResult = ""
    If '$IsObject(pProposal) Quit "no proposal"
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(pProposal.%Get("proposalId"), pSecrets, $Username, .pResult, .tHttp, .tCode, .tDetail)
    If $$$ISOK(tSC) && ($Get(tCode) = "") Quit "200 "
    If $IsObject($Get(tDetail)) && (tDetail.%GetTypeOf("violations") = "array") && (tDetail.violations.%Size() > 0) Set tCode = tDetail.violations.%Get(0).%Get("field") _ ":" _ tDetail.violations.%Get(0).%Get("code")
    Quit +$Get(tHttp) _ " " _ $Get(tCode)
}

/// <p>The parsed JSON object <var>pText</var> holds, or <code>""</code>.</p>
ClassMethod Parsed(pText As %String) As %DynamicObject
{
    Set tObject = ""
    Try {
        Set tObject = ##class(%DynamicObject).%FromJSON(pText)
    } Catch {
        Set tObject = ""
    }
    Quit tObject
}

/// <p>An envelope's refusal as <code>code</code>, or <code>field:code</code> for its first violation, or
/// <code>code problem</code> for a <code>detail.problem</code>.</p>
ClassMethod Refusal(pText As %String) As %String
{
    Set tAnswer = ..Parsed(pText)
    If '$IsObject(tAnswer) Quit ""
    Set tDetail = tAnswer.%Get("detail")
    If $IsObject(tDetail) && (tDetail.%GetTypeOf("violations") = "array") && (tDetail.%Get("violations").%Size() > 0) Quit tDetail.%Get("violations").%Get(0).%Get("field") _ ":" _ tDetail.%Get("violations").%Get(0).%Get("code")
    If $IsObject(tDetail) && (tDetail.%Get("problem") '= "") Quit tAnswer.%Get("code") _ " " _ tDetail.%Get("problem")
    Quit tAnswer.%Get("code")
}

/// <p>Remove the key <var>pKey</var> from probe key file <var>pName</var>, and the administrator
/// <var>pAdmin</var> when given, through the vendor's own routine in <code>%SYS</code>, as another writer
/// could (test-only, probe files only).</p>
ClassMethod RemoveFromFile(pName As %String, pKey As %String = "", pAdmin As %String = "") As %Status
{
    If '..NameAdmitted(pName) || '##class(%File).Exists(..Directory() _ ..#MARKER) Quit $$$ERROR($$$GeneralError, "only a probe file is changed")
    Set tSC = $$$OK
    Set tPath = ..FilePath(pName)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If pKey '= "" Set tSC = $$KeyRemove^EncryptionKey(tPath, pKey)
        If $$$ISOK(tSC) && (pAdmin '= "") Set tSC = $$AdminRemove^EncryptionKey(tPath, pAdmin)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
