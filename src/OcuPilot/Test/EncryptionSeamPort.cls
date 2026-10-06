/// <p>Test-only <class>OcuPilot.Port.EncryptionPort</class> subclass: Story 18.7's seam. Every vendor
/// call the port makes through <method>Call</method> is recorded, in order, in
/// <code>^||OcuPilotEncryptionSeam</code> with its body's key names and its <code>file</code> query, and
/// never a body value, and then sent to the vendor unless an armed mode below answers it.</p>
/// <p>Armed with a key id (<method>Arm</method>), a read through <method>Invoke</method> answers as if the
/// instance depended on that key, without any database being encrypted, naming the key lower-cased and in
/// braces rather than as the key file lists it: <code>protected</code> reads
/// OcuPilot's own database as encrypted with it, <code>system</code> IRISSYS and <code>namespace</code>
/// the install namespace's globals database, each in the instance's own <code>Database.SysCRUD</code>
/// <code>LIST</code> rows; <code>unreadable</code> reads OcuPilot's own database as encrypted with no key
/// id; <code>other</code> reads the first database that is none of OcuPilot's or the instance's own as
/// encrypted with the key, recording its directory (<method>Armed</method>); <code>journal</code> answers
/// the key as <code>Security.Encryption.Settings</code>' <code>DBEncJournalKeyID</code>; and
/// <code>readfails</code>, <code>namesfail</code>, <code>dirsfail</code> and <code>settingsfail</code>
/// fail the <code>Database.SysCRUD</code> <code>LIST</code>, <code>Namespace.Namespace</code>
/// <code>GET</code>, <code>Database.ConfigCRUD</code> <code>LIST</code> and
/// <code>Security.Encryption.Settings</code> <code>GET</code> read. Armed <code>keysfail</code>,
/// <method>Call</method> answers a key file's key list with a 500 that is not the vendor's, without the
/// vendor.</p>
/// <p>Story 18.22's modes. <code>journalfiles</code> answers <code>Security.Encryption.Key</code>
/// <code>JOURNALUSE</code> <code>{InUse: true}</code> for the armed key, compared exactly as the vendor's
/// <code>IsEncKeyInUse</code> compares it, as a journal file still needed for recovery would, and
/// <code>journalfails</code> fails that read. Armed <code>activation</code>,
/// <code>inuse</code> or <code>role</code>, <method>Call</method> answers the active-key lists
/// (<code>Key</code> <code>LIST</code> and <code>DATAELEMENTLIST</code>) from the seam's own list
/// (<method>Hold</method>, <method>Held</method>) and never asks the vendor to activate or deactivate
/// anything: under <code>activation</code> a <code>File</code> <code>ACTIVATE</code> whose body carries the
/// armed administrator and password (<method>ArmCredentials</method>) adds the key file's keys (read from
/// the file through the vendor) to the list of its <code>Action</code>'s kind, the first database key the
/// default, and any other is the vendor's measured refusal, 500 #1219; a <code>Key</code>
/// <code>DEACTIVATE</code> removes its key; under <code>inuse</code> and <code>role</code> a
/// <code>DEACTIVATE</code> answers the vendor's measured refusal, 500 #1208 or #1214, and removes nothing.
/// Each refusal goes through the admin port's own failure path (<method>Fail</method>).</p>
/// <p>Under any other mode, armed or not, a <code>File</code> <code>ACTIVATE</code> reaches the vendor only
/// when its password is the wrong one a test armed (<method>ArmRefusable</method>) and none of the probe
/// key files' passwords (<method>Refusable</method>), so the vendor can only refuse it; any other is
/// answered 500 without the vendor. A real first activation persistently changes the instance's key
/// activation at startup, which no test can restore.</p>
/// <p>Story 18.23's modes. Armed <code>startup</code>, <code>startupfails</code>, <code>kmip</code> or
/// <code>settingsv1</code>, <method>Call</method> answers <code>Security.Encryption.Settings</code>
/// <code>GET</code> from a seam-held settings object (<method>HoldSettings</method>,
/// <method>HeldSettings</method>, first copied from the instance's own) and the active-key lists from
/// <method>Held</method>, and never sends a settings <code>PUT</code> to the vendor: it records the body's
/// key names and its non-secret settings values (<method>SentOf</method>; a password never) and applies them
/// to the held object, as the vendor's <code>RunPut</code> would; under <code>startupfails</code> it
/// answers the vendor's measured refusal armed with <method>ArmFailure</method> through
/// <method>Fail</method> instead. <code>kmip</code> also answers the configured KMIP servers from
/// <method>ArmKmip</method>, and <code>settingsv1</code> answers the settings endpoint's body template
/// without <code>AdminName</code> and <code>AdminPassword</code>, as an API version 1 instance would. Under
/// any other mode, armed or not, a settings <code>PUT</code> reaches the vendor only when it carries the
/// instance's current settings unchanged and no key id or credential; any other is answered 500 without
/// the vendor.</p>
/// <p>Under those modes the read of which startup databases are encrypted on disk
/// (<method>EncryptedOnDisk</method>) answers the names <method>ArmOnDisk</method> armed, none unless armed,
/// and <code>ondiskfails</code>, a further Story 18.23 mode, fails it; outside them it is the instance's own
/// read, which changes nothing.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EncryptionSeamPort Extends OcuPilot.Port.EncryptionPort
{

ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pLocation As %String) As %Status
{
    Set tPair = pEndpoint _ "/" _ pType
    Set tIndex = $Increment(^||OcuPilotEncryptionSeam("calls"))
    Set ^||OcuPilotEncryptionSeam("calls", tIndex) = tPair
    Set tKeys = ""
    If $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
        Set tIterator = pBody.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tNames(tKey) = ""
        }
        Set tKey = ""
        For {
            Set tKey = $Order(tNames(tKey))
            If tKey = "" Quit
            Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
        }
    }
    Set ^||OcuPilotEncryptionSeam("keys", tPair) = tKeys
    Set ^||OcuPilotEncryptionSeam("file", tPair) = $Get(pQuery("file"))
    If (pEndpoint = ..#SETTINGSENDPOINT) || (tPair = "Security.Encryption.Key/LIST") || (tPair = "Security.Encryption.Key/DATAELEMENTLIST") {
        Set tAnswered = ..StartupAnswer(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .tSC)
        If tAnswered {
            Set pLocation = ""
            Quit tSC
        }
    }
    If (tPair = "Security.Encryption.File/ACTIVATE") && ($Get(^||OcuPilotEncryptionSeam("mode")) '= "activation") && '..Refusable(pBody) {
        Set pResult = ""
        Set pLocation = ""
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Quit $$$ERROR($$$GeneralError, "the seam sends the vendor no activation it could apply")
    }
    If $ListFind($ListBuild("activation", "inuse", "role"), $Get(^||OcuPilotEncryptionSeam("mode"))) {
        Set tAnswered = ..ActiveAnswer(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .tSC)
        If tAnswered {
            Set pLocation = ""
            Quit tSC
        }
    }
    If ($Get(^||OcuPilotEncryptionSeam("mode")) = "keysfail") && (tPair = "Security.Encryption.KeyInFile/LIST") {
        Set pResult = ""
        Set pLocation = ""
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Quit $$$ERROR($$$GeneralError, "the key list fails, as the seam was armed")
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .pLocation)
}

/// <p>The encryption port's call, with the reads <method>Arm</method> armed answered as armed.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tMode = $Get(^||OcuPilotEncryptionSeam("mode"))
    If (pEndpoint = "Security.Encryption.Key") && (pType = "JOURNALUSE") {
        If tMode = "journalfails" {
            Set pResult = ""
            Set pHttpStatus = 500
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
            Quit $$$ERROR($$$GeneralError, "the journal's use of a key fails, as the seam was armed")
        }
        If (tMode = "journalfiles") && ($Get(pQuery("id")) '= "") && ($Get(pQuery("id")) = $Get(^||OcuPilotEncryptionSeam("key"))) {
            Set pResult = {"InUse": true}
            Set pHttpStatus = 200
            Set pFault = ""
            Quit $$$OK
        }
    }
    Set tDatabases = (pEndpoint = "Database.SysCRUD") && (pType = "LIST")
    Set tFails = $Case(tMode, "readfails": "Database.SysCRUD/LIST", "namesfail": "Namespace.Namespace/GET", "dirsfail": "Database.ConfigCRUD/LIST", "settingsfail": "Security.Encryption.Settings/GET", : "")
    If (tFails '= "") && (tFails = (pEndpoint _ "/" _ pType)) {
        Set pResult = ""
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Quit $$$ERROR($$$GeneralError, tFails _ " fails, as the seam was armed")
    }
    Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) || '$IsObject($Get(pResult)) Quit tSC
    Set tKey = "{" _ $ZConvert($Get(^||OcuPilotEncryptionSeam("key")), "L") _ "}"
    If (tMode = "journal") && (pEndpoint = "Security.Encryption.Settings") && (pType = "GET") {
        Do pResult.%Set("DBEncJournalKeyID", tKey, "string")
        Quit tSC
    }
    If 'tDatabases || '$ListFind($ListBuild("protected", "system", "namespace", "unreadable", "other"), tMode) Quit tSC
    Set tOwn = ..OwnDirectories()
    Set tDirectory = $Case(tMode, "system": ..DirectoryOf("IRISSYS"), "namespace": ..DirectoryOf(..GlobalsOf($NAMESPACE)), "other": "", : ..DirectoryOf(##class(OcuPilot.Kernel.State.Base).#DATABASENAME))
    Set tIterator = pResult.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If tMode = "other" {
            If ..Within(tOwn, tRow.%Get("Directory")) || ($Get(^||OcuPilotEncryptionSeam("armed")) '= "") Continue
            Set ^||OcuPilotEncryptionSeam("armed") = tRow.%Get("Directory")
        } ElseIf '##class(OcuPilot.Port.DatabasePort).SameDirectory(tRow.%Get("Directory"), tDirectory) {
            Continue
        }
        Do tRow.%Set("Encrypted", 1, "boolean")
        If tMode = "unreadable" {
            Do tRow.%Remove("EncryptionKeyID")
        } Else {
            Do tRow.%Set("EncryptionKeyID", tKey, "string")
        }
    }
    Quit tSC
}

/// <p>The directories of OcuPilot's own database, the seven protected databases and the install
/// namespace's globals and routines databases, read in <code>%SYS</code>.</p>
ClassMethod OwnDirectories() As %List
{
    Set tNames = $ListBuild(##class(OcuPilot.Kernel.State.Base).#DATABASENAME) _ $ListFromString($Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SYSTEMDATABASES")) _ $ListBuild(..GlobalsOf($NAMESPACE), ..RoutinesOf($NAMESPACE))
    Set tOut = ""
    For tI = 1:1:$ListLength(tNames) {
        Set tDirectory = ..DirectoryOf($List(tNames, tI))
        If tDirectory '= "" Set tOut = tOut _ $ListBuild(tDirectory)
    }
    Quit tOut
}

/// <p>Whether <var>pDirectory</var> is one of <var>pDirectories</var>.</p>
ClassMethod Within(pDirectories As %List, pDirectory As %String) As %Boolean
{
    Set tWithin = 0
    For tI = 1:1:$ListLength(pDirectories) {
        If ##class(OcuPilot.Port.DatabasePort).SameDirectory($List(pDirectories, tI), pDirectory) Set tWithin = 1 Quit
    }
    Quit tWithin
}

/// <p>The globals database of namespace <var>pNamespace</var>, read in <code>%SYS</code>.</p>
ClassMethod GlobalsOf(pNamespace As %String) As %String
{
    Quit ..NamespaceField(pNamespace, "Globals")
}

/// <p>The routines database of namespace <var>pNamespace</var>, read in <code>%SYS</code>.</p>
ClassMethod RoutinesOf(pNamespace As %String) As %String
{
    Quit ..NamespaceField(pNamespace, "Routines")
}

/// <p>Field <var>pField</var> of namespace <var>pNamespace</var>'s configuration, or <code>""</code>.</p>
ClassMethod NamespaceField(pNamespace As %String, pField As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Config.Namespaces).Get(pNamespace, .tProps)) Set tValue = $Get(tProps(pField))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tValue
}

/// <p>The directory the <code>other</code> mode armed, or <code>""</code>.</p>
ClassMethod Armed() As %String
{
    Quit $Get(^||OcuPilotEncryptionSeam("armed"))
}

/// <p>The directory of database <var>pName</var>, read in <code>%SYS</code>.</p>
ClassMethod DirectoryOf(pName As %String) As %String
{
    Set tDirectory = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Config.Databases).Get(pName, .tProps)) Set tDirectory = $Get(tProps("Directory"))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tDirectory
}

/// <p>Arm <var>pMode</var> (one of the modes this class's header names, or <code>""</code> for none) with
/// key <var>pKey</var>.</p>
ClassMethod Arm(pMode As %String, pKey As %String = "")
{
    Set ^||OcuPilotEncryptionSeam("mode") = pMode
    Set ^||OcuPilotEncryptionSeam("key") = pKey
}

/// <p>Under the active-list modes, the answer <method>Call</method> gives without the vendor for the
/// active-key lists, an activation and a deactivation; <var>pAnswered</var> 0 for every other call, which
/// goes to the vendor.</p>
ClassMethod ActiveAnswer(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pSC As %Status) As %Boolean [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pSC = $$$OK
    Set tPair = pEndpoint _ "/" _ pType
    If (tPair = "Security.Encryption.Key/LIST") || (tPair = "Security.Encryption.Key/DATAELEMENTLIST") {
        Set pResult = ..Held($Select(pType = "LIST": "database", 1: "dataElement"))
        Set pHttpStatus = 200
        Quit 1
    }
    Set tAction = $Select($IsObject(pBody) && pBody.%IsA("%Library.DynamicObject"): pBody.%Get("Action"), 1: "")
    Set tKind = $Select((tAction = "ActivateMK") || (tAction = "DeactivateMK"): "dataElement", 1: "database")
    If tPair = "Security.Encryption.File/ACTIVATE" {
        If $Get(^||OcuPilotEncryptionSeam("mode")) '= "activation" Quit 0
        If '$IsObject(pBody) || (pBody.%Get("AdminName") '= ..ArmedAdmin()) || (pBody.%Get("AdminPassword") '= ..ArmedPassword()) {
            ; The vendor's measured answer to a name and password that do not open the key file.
            Set pSC = ..Fail(pEndpoint, 500, $$$ERROR(1219), .pHttpStatus, .pFault, "", pBody, 0, pType)
            Quit 1
        }
        Set pSC = ..Keys($Get(pQuery("file")), .tRows, .pHttpStatus, .pFault)
        If $$$ISERR(pSC) Quit 1
        Set tHeld = ..Held(tKind)
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) || ..Active(tHeld, tRow.%Get("Id")) Continue
            If tKind = "dataElement" {
                Do tHeld.%Push({"Id": (tRow.%Get("Id"))})
            } Else {
                Set tAdded = {"Id": (tRow.%Get("Id")), "KeyLen": (+tRow.%Get("KeyLen"))}
                Do tAdded.%Set("IsDefault", (tHeld.%Size() = 0), "boolean")
                Do tHeld.%Push(tAdded)
            }
        }
        Do ..Hold(tKind, tHeld)
        Set pResult = {}
        Set pHttpStatus = 200
        Quit 1
    }
    If tPair = "Security.Encryption.Key/DEACTIVATE" {
        Set tMode = $Get(^||OcuPilotEncryptionSeam("mode"))
        If tMode '= "activation" {
            Set pSC = ..Fail(pEndpoint, 500, $$$ERROR($Select(tMode = "inuse": 1208, 1: 1214)), .pHttpStatus, .pFault, "", pBody, 0, pType)
            Quit 1
        }
        Set tHeld = ..Held(tKind)
        Set tKept = []
        Set tIterator = tHeld.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If $IsObject(tRow) && (tRow.%Get("Id") '= $Get(pQuery("id"))) Do tKept.%Push(tRow)
        }
        Do ..Hold(tKind, tKept)
        Set pResult = {}
        Set pHttpStatus = 200
        Quit 1
    }
    Quit 0
}

/// <p>Arm the key file administrator and password an activation's body must carry under
/// <code>activation</code>; unarmed, the probe's own (<class>OcuPilot.Test.EncryptionKeyProbe</class>).
/// <method>Clear</method> forgets them and <method>ClearCalls</method> keeps them.</p>
ClassMethod ArmCredentials(pAdmin As %String, pPassword As %String)
{
    Set ^||OcuPilotEncryptionSeam("admin") = pAdmin
    Set ^||OcuPilotEncryptionSeam("password") = pPassword
}

/// <p>The administrator <method>ArmCredentials</method> armed, else the probe's.</p>
ClassMethod ArmedAdmin() As %String
{
    Quit $Get(^||OcuPilotEncryptionSeam("admin"), $Parameter("OcuPilot.Test.EncryptionKeyProbe", "ADMIN"))
}

/// <p>The password <method>ArmCredentials</method> armed, else the probe's.</p>
ClassMethod ArmedPassword() As %String
{
    Quit $Get(^||OcuPilotEncryptionSeam("password"), $Parameter("OcuPilot.Test.EncryptionKeyProbe", "PASSWORD"))
}

/// <p>Arm the one wrong password a test sends the vendor outside <code>activation</code>, so
/// <method>Refusable</method> forwards an activation carrying exactly it. <method>Clear</method> forgets it
/// and <method>ClearCalls</method> keeps it.</p>
ClassMethod ArmRefusable(pPassword As %String)
{
    Set ^||OcuPilotEncryptionSeam("refusable") = pPassword
}

/// <p>Whether an activation carrying <var>pBody</var> can only be refused by the vendor: its password is
/// the one <method>ArmRefusable</method> armed, non-empty, and none of the probe key files' passwords --
/// the armed credentials' and both probes' own.</p>
ClassMethod Refusable(pBody As %DynamicAbstractObject) As %Boolean [ Private ]
{
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Set tPassword = pBody.%Get("AdminPassword")
    If (tPassword = "") || (tPassword '= $Get(^||OcuPilotEncryptionSeam("refusable"))) Quit 0
    Quit '$ListFind($ListBuild(..ArmedPassword(), $Parameter("OcuPilot.Test.EncryptionKeyProbe", "PASSWORD"), $Parameter("OcuPilot.Test.EncryptionProbe", "PASSWORD")), tPassword)
}

/// <p>Set the seam's active keys of kind <var>pKind</var> (<code>database</code> or
/// <code>dataElement</code>) to <var>pRows</var>, as the vendor's list answers them.</p>
ClassMethod Hold(pKind As %String, pRows As %DynamicArray)
{
    Set ^||OcuPilotEncryptionSeam("active", pKind) = pRows.%ToJSON()
}

/// <p>The seam's active keys of kind <var>pKind</var>, <code>[]</code> when none was held.</p>
ClassMethod Held(pKind As %String) As %DynamicArray
{
    Set tText = $Get(^||OcuPilotEncryptionSeam("active", pKind))
    If tText = "" Quit []
    Quit ##class(%DynamicArray).%FromJSON(tText)
}

/// <p>Whether a Story 18.23 mode is armed.</p>
ClassMethod StartupArmed() As %Boolean
{
    Quit ''$ListFind($ListBuild("startup", "startupfails", "kmip", "settingsv1", "ondiskfails"), $Get(^||OcuPilotEncryptionSeam("mode")))
}

/// <p>The answer <method>Call</method> gives without the vendor for a settings read or write, or for an
/// active-key list, under a Story 18.23 mode; <var>pAnswered</var> 0 for every call the vendor answers.
/// Outside those modes a settings <code>PUT</code> that would change anything is answered 500.</p>
ClassMethod StartupAnswer(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pSC As %Status) As %Boolean [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pSC = $$$OK
    Set tPair = pEndpoint _ "/" _ pType
    If '..StartupArmed() {
        If tPair '= (..#SETTINGSENDPOINT _ "/PUT") Quit 0
        If ..Unchanged(pBody) Quit 0
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Set pSC = $$$ERROR($$$GeneralError, "the seam sends the vendor no settings PUT that changes anything")
        Quit 1
    }
    If (tPair = "Security.Encryption.Key/LIST") || (tPair = "Security.Encryption.Key/DATAELEMENTLIST") {
        Set pResult = ..Held($Select(pType = "LIST": "database", 1: "dataElement"))
        Set pHttpStatus = 200
        Quit 1
    }
    If pType = "GET" {
        Set pResult = ..HeldSettings()
        Set pHttpStatus = 200
        Quit 1
    }
    If pType '= "PUT" Quit 0
    Kill ^||OcuPilotEncryptionSeam("sent")
    If $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
        Set tIterator = pBody.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If (tKey = "AdminPassword") || $IsObject(tValue) Continue
            Set ^||OcuPilotEncryptionSeam("sent", tKey) = $Select(pBody.%GetTypeOf(tKey) = "boolean": $Select(tValue: "true", 1: "false"), 1: tValue)
        }
    }
    If $Get(^||OcuPilotEncryptionSeam("mode")) = "startupfails" {
        Set pSC = ..Fail(pEndpoint, 500, $$$ERROR(+$Get(^||OcuPilotEncryptionSeam("failcode"), 1217)), .pHttpStatus, .pFault, "", pBody, 0, pType)
        Quit 1
    }
    Set tHeld = ..HeldSettings()
    For tField = "DBEncStartMode", "DBEncStartKMIPServer", "DBEncStartKeyFile", "DBEncDefaultKeyID", "DBEncJournalKeyID" {
        If $IsObject(pBody) && (pBody.%GetTypeOf(tField) = "string") Do tHeld.%Set(tField, pBody.%Get(tField), "string")
    }
    For tField = "DBEncJournal", "DBEncIRISSecurity", "DBEncIRISTemp", "AuditEncrypt" {
        If $IsObject(pBody) && (pBody.%GetTypeOf(tField) '= "unassigned") Do tHeld.%Set(tField, ''pBody.%Get(tField), "boolean")
    }
    Do ..HoldSettings(tHeld)
    Set pResult = tHeld
    Set pHttpStatus = 200
    Quit 1
}

/// <p>Whether a settings <code>PUT</code> body <var>pBody</var> carries the instance's current settings
/// unchanged, sends no key id and no credential, read through the vendor now.</p>
ClassMethod Unchanged(pBody As %DynamicAbstractObject) As %Boolean [ Private ]
{
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    For tField = "DBEncDefaultKeyID", "DBEncJournalKeyID", "AdminName", "AdminPassword" {
        If pBody.%GetTypeOf(tField) '= "unassigned" Quit
        Set tField = ""
    }
    If $Get(tField) '= "" Quit 0
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#SETTINGSENDPOINT, "GET", .tQuery, "", .tNow, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tNow)) Quit 0
    Set tSame = 1
    For tField = "DBEncStartMode", "DBEncStartKMIPServer", "DBEncStartKeyFile", "DBEncJournal", "DBEncIRISSecurity", "DBEncIRISTemp", "AuditEncrypt" {
        If ##class(OcuPilot.Kernel.Proposal.Mint).Display(pBody.%Get(tField), pBody.%GetTypeOf(tField)) '= ##class(OcuPilot.Kernel.Proposal.Mint).Display(tNow.%Get(tField), tNow.%GetTypeOf(tField)) Set tSame = 0 Quit
    }
    Quit tSame
}

/// <p>The seam-held settings object, first copied from the instance's own read.</p>
ClassMethod HeldSettings() As %DynamicObject
{
    Set tText = $Get(^||OcuPilotEncryptionSeam("settings"))
    If tText '= "" Quit ##class(%DynamicObject).%FromJSON(tText)
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#SETTINGSENDPOINT, "GET", .tQuery, "", .tNow, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tNow)) Quit {}
    Do ..HoldSettings(tNow)
    Quit tNow
}

/// <p>Hold <var>pSettings</var> as the settings the seam answers.</p>
ClassMethod HoldSettings(pSettings As %DynamicObject)
{
    Set ^||OcuPilotEncryptionSeam("settings") = pSettings.%ToJSON()
}

/// <p>Set the held settings' <var>pField</var> to <var>pValue</var>, a boolean for an encryption setting,
/// as another writer could between a mint and its confirm.</p>
ClassMethod SetHeld(pField As %String, pValue As %String)
{
    Set tHeld = ..HeldSettings()
    If $ListFind($ListBuild("DBEncJournal", "DBEncIRISSecurity", "DBEncIRISTemp", "AuditEncrypt"), pField) {
        Do tHeld.%Set(pField, ''pValue, "boolean")
    } Else {
        Do tHeld.%Set(pField, pValue, "string")
    }
    Do ..HoldSettings(tHeld)
}

/// <p>The value the last settings <code>PUT</code> carried under <var>pField</var>, booleans as
/// <code>true</code> or <code>false</code>, <code>""</code> for a field it did not carry; a password is
/// never recorded.</p>
ClassMethod SentOf(pField As %String) As %String
{
    Quit $Get(^||OcuPilotEncryptionSeam("sent", pField))
}

/// <p>Arm the vendor code <code>startupfails</code> answers a settings <code>PUT</code> with.</p>
ClassMethod ArmFailure(pCode As %Integer)
{
    Set ^||OcuPilotEncryptionSeam("failcode") = pCode
}

/// <p>Arm the KMIP server names <code>kmip</code> answers as configured, comma-separated.</p>
ClassMethod ArmKmip(pNames As %String)
{
    Set ^||OcuPilotEncryptionSeam("kmipnames") = pNames
}

/// <p>The configured KMIP servers: the names <method>ArmKmip</method> armed under <code>kmip</code>, and the
/// instance's own otherwise.</p>
ClassMethod KmipNames(Output pNames As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If $Get(^||OcuPilotEncryptionSeam("mode")) '= "kmip" Quit ##super(.pNames, .pHttpStatus, .pFault)
    Set pNames = []
    Set pHttpStatus = 200
    Set pFault = ""
    Set tNames = $Get(^||OcuPilotEncryptionSeam("kmipnames"))
    For tI = 1:1:$Length(tNames, ",") {
        If $Piece(tNames, ",", tI) '= "" Do pNames.%Push($Piece(tNames, ",", tI))
    }
    Quit $$$OK
}

/// <p>Arm the startup databases the Story 18.23 modes answer as encrypted on disk, comma-separated.
/// <method>Clear</method> forgets them and <method>ClearCalls</method> keeps them.</p>
ClassMethod ArmOnDisk(pNames As %String)
{
    Set ^||OcuPilotEncryptionSeam("ondisk") = pNames
}

/// <p>Which startup databases are encrypted on disk: under a Story 18.23 mode the names
/// <method>ArmOnDisk</method> armed, a failed read under <code>ondiskfails</code>; the instance's own read
/// otherwise.</p>
ClassMethod EncryptedOnDisk(Output pNames As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If '..StartupArmed() Quit ##super(.pNames, .pHttpStatus, .pFault)
    Set pNames = []
    If $Get(^||OcuPilotEncryptionSeam("mode")) = "ondiskfails" {
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Quit $$$ERROR($$$GeneralError, "the startup databases' encryption on disk cannot be read, as the seam was armed")
    }
    Set pHttpStatus = 200
    Set pFault = ""
    Set tNames = $Get(^||OcuPilotEncryptionSeam("ondisk"))
    For tI = 1:1:$Length(tNames, ",") {
        If $Piece(tNames, ",", tI) '= "" Do pNames.%Push($Piece(tNames, ",", tI))
    }
    Quit $$$OK
}

/// <p>The endpoint's body template, without <code>AdminName</code> and <code>AdminPassword</code> for the
/// settings endpoint under <code>settingsv1</code>.</p>
ClassMethod Template(pEndpoint As %String, Output pTemplate As %DynamicAbstractObject, Output pMethod As %String, pArgument As %String) As %Status
{
    If $Data(pArgument) {
        Set tSC = ##super(pEndpoint, .pTemplate, .pMethod, pArgument)
    } Else {
        Set tSC = ##super(pEndpoint, .pTemplate, .pMethod)
    }
    If $$$ISERR(tSC) || (pEndpoint '= ..#SETTINGSENDPOINT) || ($Get(^||OcuPilotEncryptionSeam("mode")) '= "settingsv1") Quit tSC
    If $IsObject($Get(pTemplate)) && pTemplate.%IsA("%Library.DynamicObject") {
        Do pTemplate.%Remove("AdminName")
        Do pTemplate.%Remove("AdminPassword")
    }
    Quit tSC
}

/// <p>Forget every recorded call and the armed mode.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotEncryptionSeam
}

/// <p>Forget every recorded call, keeping the armed mode, its key and the held active lists.</p>
ClassMethod ClearCalls()
{
    Kill ^||OcuPilotEncryptionSeam("calls"), ^||OcuPilotEncryptionSeam("keys"), ^||OcuPilotEncryptionSeam("file"), ^||OcuPilotEncryptionSeam("sent")
}

/// <p>The recorded calls, comma-joined in order.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotEncryptionSeam("calls")) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $Get(^||OcuPilotEncryptionSeam("calls", tI))
    }
    Quit tOut
}

/// <p>The recorded calls other than reads, <code>LIST</code>, <code>DATAELEMENTLIST</code> and
/// <code>GET</code>, comma-joined. The startup settings' <code>GET</code> reaches this class's
/// <method>Call</method> from the key removal's protected-set check.</p>
ClassMethod Writes() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotEncryptionSeam("calls")) {
        Set tPair = $Get(^||OcuPilotEncryptionSeam("calls", tI))
        If ($Piece(tPair, "/", 2) = "LIST") || ($Piece(tPair, "/", 2) = "DATAELEMENTLIST") || ($Piece(tPair, "/", 2) = "GET") Continue
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tPair
    }
    Quit tOut
}

/// <p>The <code>file</code> query value the last <var>pPair</var> call carried: a resolved key file's
/// path, never a secret.</p>
ClassMethod FileOf(pPair As %String) As %String
{
    Quit $Get(^||OcuPilotEncryptionSeam("file", pPair))
}

/// <p>The body key names the last <var>pPair</var> call carried, sorted and comma-joined.</p>
ClassMethod KeysOf(pPair As %String) As %String
{
    Quit $Get(^||OcuPilotEncryptionSeam("keys", pPair))
}

}
