/// <p>Encryption startup settings' edit (Story 18.23, AD-4, AD-6, AD-52, AD-55): propose a change to how
/// the instance activates its database encryption keys at startup, which system databases, journal files
/// and audit log it encrypts, and which active key is the default and the journal key. It reads the
/// settings fresh through <class>OcuPilot.Port.EncryptionPort</class>, merges the arguments over that read
/// and mints a proposal the user confirms; the screen's Save
/// (<class>OcuPilot.Area.Security.EncryptionStartupSave</class>) is its second caller. It writes
/// nothing.</p>
/// <p><b>A merge write over the singleton, AD-4's named exception</b>: the payload is the fresh read with
/// the change applied, less the startup key file, which the port composes alone (AD-21), less an
/// <code>AuditEncrypt</code> the arguments do not change, which the port reads at the write, and less a key
/// id the arguments do not change (<method>MergeUpdate</method>). A new Unattended key file is named by
/// <code>root</code> and <code>path</code>, resolved through <class>OcuPilot.Port.PathPort</class> at the
/// write, and its administrator's password is the declared secret the person types at the confirm.</p>
/// <p><b>The version gate and the rules come first</b>: the mint
/// (<class>OcuPilot.Screen.Tool.EncryptionStartupMint</class>) asks
/// <method>OcuPilot.Port.EncryptionPort.SettingsGate</method> and
/// <method>OcuPilot.Port.EncryptionPort.StartupProblems</method>, and the port asks both again at the
/// write. A change to <code>AuditEncrypt</code> is minted destructive with
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.EFFECTAUDITENCRYPTION</parameter>, and Interactive key
/// activation while the audit log, IRISSECURITY or IRISTEMP is encrypted is refused with
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.STARTUPINTERACTIVE</parameter> (AD-10).</p>
/// <p><b>Its pairs</b> are Security's, and the path port's <code>%Admin_FileSystemAccess:USE</code> when a
/// root is sent, each refused by name before any port call (AD-8, measured at Task 0). The descriptor's
/// own classic page performs the write, so it names no other (AD-44).</p>
Class OcuPilot.Screen.Tool.EncryptionStartupUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.encryptionstartup.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EncryptionStartup";

Parameter DESCRIPTION = "Propose a change to this instance's encryption startup settings: how database encryption keys are activated at each start (None, Interactive, Unattended or KMIP), whether journal files, IRISSECURITY, IRISTEMP and the audit log are encrypted, the KMIP server, and which active key is the default and the journal key. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'SYSTEM' as the name and only the settings to change. Unattended with a new key file names it by root and path and an administrator the file lists as AdminName; the person types that administrator's password when confirming. A change to the audit log's encryption takes effect at the next start. Interactive is refused while the audit log, IRISSECURITY or IRISTEMP is encrypted.";

/// <p>The port that composes the settings read and write (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.EncryptionPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names them).</p>
Parameter PERMITTEDFIELDS = "DBEncStartMode,DBEncJournal,DBEncIRISSecurity,DBEncIRISTemp,AuditEncrypt,DBEncStartKMIPServer,DBEncDefaultKeyID,DBEncJournalKeyID,AdminName";

/// <p>The template field this tool never admits: the startup key file, which only a root and a relative
/// name set (AD-21).</p>
Parameter EXCLUDEDFIELDS = "DBEncStartKeyFile";

/// <p>The arguments naming a new Unattended key file, carried to the port in its query
/// (<method>PortQuery</method>).</p>
Parameter LOCATIONARGUMENTS = "root,path";

/// <p>The four encryption settings, each a boolean.</p>
Parameter FLAGFIELDS = "DBEncJournal,DBEncIRISSecurity,DBEncIRISTemp,AuditEncrypt";

/// <p>The setting the port reads at the write unless the arguments change it.</p>
Parameter AUDITFIELD = "AuditEncrypt";

/// <p>The payload key carrying the <code>AuditEncrypt</code> a proposal that changes it reviewed, so its
/// fingerprint covers that value: the port never sends it, and the card never shows it as a changed
/// row.</p>
Parameter REVIEWEDAUDITFIELD = "AuditEncryptReviewed";

/// <p>The administrator and the declared secret a new Unattended key file carries.</p>
Parameter ADMINFIELD = "AdminName";

Parameter PASSWORDFIELD = "AdminPassword";

/// <p>The consequence codes the card renders, each pinned equal to the error class's code by
/// <class>OcuPilot.Test.EncryptionStartupDescriptor</class>: the chosen start mode's, comma-separated in the
/// port's <code>STARTMODES</code> order, then an IRISSECURITY or IRISTEMP change's and a journal encryption
/// change's.</p>
Parameter MODECONSEQUENCES = "ENCRYPTION.STARTUP.NONE,ENCRYPTION.STARTUP.INTERACTIVE,ENCRYPTION.STARTUP.UNATTENDED,ENCRYPTION.STARTUP.KMIP";

Parameter RESTARTCONSEQUENCE = "ENCRYPTION.STARTUP.RESTART";

Parameter JOURNALCONSEQUENCE = "ENCRYPTION.STARTUP.JOURNAL";

/// <p>The path port's pair, required when a root is sent (AD-21's sixth case).</p>
Parameter FILESYSTEMRESOURCE = "%Admin_FileSystemAccess";

Parameter USEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.Encryption.Settings"
}

/// <p>The <code>ordinary</code> derived fields this tool admits (AD-3), the location arguments, and the
/// declared secret <parameter>PASSWORDFIELD</parameter>, which the mint refuses from the model and the
/// confirm supplies (AD-6).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListFromString(..#LOCATIONARGUMENTS) _ $ListBuild(..#PASSWORDFIELD)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p><parameter>EXCLUDEDFIELDS</parameter>.</p>
ClassMethod ExcludedFields() As %List
{
    Quit $ListFromString(..#EXCLUDEDFIELDS)
}

/// <p><class>OcuPilot.Screen.Tool.EncryptionStartupMint</class>, which asks the version gate and the
/// rules first.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.EncryptionStartupMint"
}

/// <p>The derived schema with each setting typed and described, the target named as the singleton's
/// literal id, and the location arguments.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "Send the literal '" _ ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID _ "': the instance has one set of encryption startup settings.", "string")
    If tProperties.%GetTypeOf("DBEncStartMode") = "object" {
        Set tMode = tProperties.%Get("DBEncStartMode")
        Do tMode.%Set("description", "How database encryption keys are activated at each start: None, Interactive (each start asks for a key file on the console), Unattended (each start activates from a key file with no one present; not recommended) or KMIP (each start activates from a configured KMIP server). Interactive is refused while the audit log, IRISSECURITY or IRISTEMP is encrypted.", "string")
        Set tEnum = []
        For tI = 1:1:$Length(##class(OcuPilot.Port.EncryptionPort).#STARTMODES, ",") Do tEnum.%Push($Piece(##class(OcuPilot.Port.EncryptionPort).#STARTMODES, ",", tI))
        Do tMode.%Set("enum", tEnum)
    }
    Set tDescriptions("DBEncJournal") = "Whether new journal files are encrypted, from the next journal switch or restart."
    Set tDescriptions("DBEncIRISSecurity") = "Whether IRISSECURITY is encrypted, from the next restart."
    Set tDescriptions("DBEncIRISTemp") = "Whether IRISTEMP, IRISLOCALDATA and IRISMETRICS are encrypted, from the next restart."
    Set tDescriptions("AuditEncrypt") = "Whether the audit log is encrypted. It takes effect at the next start, when the audit database is encrypted or decrypted in place, keeping every record; this change is confirmed as a destructive one."
    For tField = "DBEncJournal", "DBEncIRISSecurity", "DBEncIRISTemp", "AuditEncrypt" {
        If tProperties.%GetTypeOf(tField) '= "object" Continue
        Do tProperties.%Get(tField).%Set("type", "boolean", "string")
        Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    If tProperties.%GetTypeOf("DBEncStartKMIPServer") = "object" Do tProperties.%Get("DBEncStartKMIPServer").%Set("description", "For KMIP: the name of a KMIP server this instance has configured.", "string")
    If tProperties.%GetTypeOf("DBEncDefaultKeyID") = "object" Do tProperties.%Get("DBEncDefaultKeyID").%Set("description", "The active database encryption key new encrypted databases use, exactly as Database encryption lists it.", "string")
    If tProperties.%GetTypeOf("DBEncJournalKeyID") = "object" Do tProperties.%Get("DBEncJournalKeyID").%Set("description", "The active database encryption key new encrypted journal files use, exactly as Database encryption lists it.", "string")
    If tProperties.%GetTypeOf(..#ADMINFIELD) = "object" Do tProperties.%Get(..#ADMINFIELD).%Set("description", "For Unattended with a new key file: an administrator the key file lists, up to 50 characters; the person types its password when confirming.", "string")
    Do tProperties.%Set("root", {"type": "string", "description": "For Unattended with a new key file: the allowed directory the key file is in, exactly as this instance's Allowed directories screen lists it."})
    Do tProperties.%Set("path", {"type": "string", "description": "For Unattended with a new key file: the key file's name relative to root, up to eight names separated by '/'. Never a full path."})
    Quit tSchema
}

/// <p>The kernel's merge over the fresh read <var>pFresh</var>, shaped for this write: the startup key file
/// is left out; <parameter>AUDITFIELD</parameter> is left out unless <var>pArgs</var> changes it, and when
/// it does, <parameter>REVIEWEDAUDITFIELD</parameter> carries the value it reviewed; a key id the arguments
/// do not change is left out; the location arguments and <parameter>ADMINFIELD</parameter> stay only for a
/// new Unattended key file (<method>NewKeyFile</method>), which also carries the
/// <parameter>PASSWORDFIELD</parameter> placeholder the card asks for. <var>pUnchanged</var> counts the
/// payload's properties no diff row names.</p>
/// <p><b>Caller contract:</b> called by the mint, by the confirm's fingerprint re-merge and by the Save,
/// so the three take one payload and one digest.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || 'pFresh.%IsA("%Library.DynamicObject") {
            Set tSC = $$$ERROR($$$GeneralError, "the encryption startup settings read answered no object")
            Quit
        }
        Set tPort = ..#PORTCLASS
        Set tFresh = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
        Do tFresh.%Remove($Parameter(tPort, "STARTKEYFILEFIELD"))
        Set tArgs = {}
        If $IsObject(pArgs) && pArgs.%IsA("%Library.DynamicObject") Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Set tChangesAudit = 0
        If tArgs.%GetTypeOf(..#AUDITFIELD) '= "unassigned" {
            Set tChangesAudit = (..Flag(tArgs, ..#AUDITFIELD) '= ..Flag(tFresh, ..#AUDITFIELD))
        }
        If 'tChangesAudit {
            Do tFresh.%Remove(..#AUDITFIELD)
            Do tArgs.%Remove(..#AUDITFIELD)
        }
        For tName = "root", "path", ..#ADMINFIELD {
            If tArgs.%GetTypeOf(tName) '= "unassigned" Do tFresh.%Set(tName, "", "string")
        }
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(tFresh, tArgs, pIdArgument, pSettable, .tPayload, .tDiff, .tUnchanged, .pProblem)
        If $$$ISERR(tSC) || (pProblem '= "") Quit
        Kill tDropped
        For tI = 1:1:$Length($Parameter(tPort, "KEYIDFIELDS"), ",") {
            Set tField = $Piece($Parameter(tPort, "KEYIDFIELDS"), ",", tI)
            If '..Names(tDiff, tField) Set tDropped(tField) = ""
        }
        Set tNew = ..NewKeyFile(pFresh, tPayload)
        If 'tNew {
            For tName = "root", "path", ..#ADMINFIELD Set tDropped(tName) = ""
        }
        Set tPayloadOut = {}
        Set tIterator = tPayload.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If $Data(tDropped(tKey)) Continue
            Do ..Copy(tPayload, tKey, tPayloadOut)
        }
        Set tDiffOut = []
        Set tIterator = tDiff.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If $IsObject(tRow) && $Data(tDropped(tRow.%Get("field"))) Continue
            Do tDiffOut.%Push(tRow)
        }
        If tNew Do tPayloadOut.%Set(..#PASSWORDFIELD, "", "string")
        If tChangesAudit Do tPayloadOut.%Set(..#REVIEWEDAUDITFIELD, (..Flag(tFresh, ..#AUDITFIELD) = "true"), "boolean")
        Set tCount = 0
        Set tIterator = tPayloadOut.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If '..Names(tDiffOut, tKey) Set tCount = tCount + 1
        }
        Set pPayload = tPayloadOut
        Set pDiff = tDiffOut
        Set pUnchanged = tCount
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) || (pProblem '= "") {
        Set pPayload = ""
        Set pDiff = []
        Set pUnchanged = 0
    }
    Quit tSC
}

/// <p>Whether payload <var>pPayload</var>, merged over the fresh read <var>pFresh</var>, names a new
/// Unattended key file: its start mode is Unattended, it carries a location, and that location resolves to
/// a file other than the one the instance stores, or does not resolve at all, which the rules then
/// refuse.</p>
ClassMethod NewKeyFile(pFresh As %DynamicObject, pPayload As %DynamicObject) As %Boolean
{
    Set tPort = ..#PORTCLASS
    If $ClassMethod(tPort, "StartupText", pPayload, $Parameter(tPort, "MODEFIELD")) '= "Unattended" Quit 0
    Set tRoot = ##class(OcuPilot.Area.Security.EncryptionRules).Value(pPayload, "root")
    Set tPath = ##class(OcuPilot.Area.Security.EncryptionRules).Value(pPayload, "path")
    If (tRoot = "") && (tPath = "") Quit 0
    Set tSC = $ClassMethod(tPort, "Resolve", tRoot, tPath, "source", .tFile, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit 1
    Quit '$ClassMethod(tPort, "SameFile", tFile, $ClassMethod(tPort, "StartupText", pFresh, $Parameter(tPort, "STARTKEYFILEFIELD")))
}

/// <p><var>pObject</var>'s <var>pName</var> as <code>true</code> or <code>false</code>: a boolean as it
/// is, a number by whether it is 0, and anything else as the text it holds.</p>
ClassMethod Flag(pObject As %DynamicObject, pName As %String) As %String [ Private ]
{
    Set tType = pObject.%GetTypeOf(pName)
    If tType = "boolean" Quit $Select(pObject.%Get(pName): "true", 1: "false")
    If tType = "number" Quit $Select(+pObject.%Get(pName): "true", 1: "false")
    If tType = "string" Quit pObject.%Get(pName)
    Quit ""
}

/// <p>Whether a row of diff <var>pDiff</var> names <var>pField</var>.</p>
ClassMethod Names(pDiff As %DynamicArray, pField As %String) As %Boolean [ Private ]
{
    Set tNamed = 0
    Set tIterator = pDiff.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && (tRow.%Get("field") = pField) Set tNamed = 1 Quit
    }
    Quit tNamed
}

/// <p>Copy <var>pFrom</var>'s <var>pName</var> to <var>pTo</var> under its own type.</p>
ClassMethod Copy(pFrom As %DynamicObject, pName As %String, pTo As %DynamicObject) [ Private ]
{
    Set tType = pFrom.%GetTypeOf(pName)
    If (tType = "string") || (tType = "number") || (tType = "boolean") {
        Do pTo.%Set(pName, pFrom.%Get(pName), tType)
        Quit
    }
    If tType = "null" {
        Do pTo.%Set(pName, "", "null")
        Quit
    }
    Do pTo.%Set(pName, pFrom.%Get(pName))
}

/// <p>The stored payload's location arguments and administrator under the port's own query keys
/// (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    For tName = "root", "path", ..#ADMINFIELD {
        If pPayload.%GetTypeOf(tName) '= "string" Continue
        If pPayload.%Get(tName) = "" Continue
        Set pQuery(tName) = pPayload.%Get(tName)
    }
}

/// <p>The consequence the card and the Save state, first match:
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.EFFECTAUDITENCRYPTION</parameter> when the write changes
/// the audit log's encryption; then the chosen start mode's <parameter>MODECONSEQUENCES</parameter> code
/// when the mode changes; then <parameter>RESTARTCONSEQUENCE</parameter> when IRISSECURITY or IRISTEMP
/// changes; then <parameter>JOURNALCONSEQUENCE</parameter> when journal encryption changes. Each is judged against the
/// settings the instance holds now, read as the caller through this tool's port.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Set tAudit = ##class(OcuPilot.Kernel.Proposal.Prohibited).#EFFECTAUDITENCRYPTION
    If pEffect = tAudit Quit tAudit
    If '$IsObject(pPayload) Quit ""
    Kill tQuery
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tHeld, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tHeld)) Set tHeld = {}
    Quit ..ConsequenceOver(pPayload, tHeld)
}

/// <p><method>Consequence</method>'s answer for payload <var>pPayload</var> against the settings
/// <var>pHeld</var>, which a caller holding a fresh read hands over.</p>
ClassMethod ConsequenceOver(pPayload As %DynamicObject, pHeld As %DynamicObject) As %String
{
    Set tAudit = ##class(OcuPilot.Kernel.Proposal.Prohibited).#EFFECTAUDITENCRYPTION
    If '$IsObject(pPayload) Quit ""
    Set tHeld = $Select($IsObject(pHeld): pHeld, 1: {})
    Set tEffectSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).WeakensByEffect(##class(OcuPilot.Kernel.Proposal.Prohibited).#TYPEENCRYPTIONSTARTUP, pPayload, tHeld, .tEffect)
    If $$$ISOK(tEffectSC) && (tEffect = tAudit) Quit tAudit
    Set tPort = ..#PORTCLASS
    Set tMode = $ClassMethod(tPort, "StartupText", pPayload, $Parameter(tPort, "MODEFIELD"))
    If (tMode '= "") && (tMode '= $ClassMethod(tPort, "StartupText", tHeld, $Parameter(tPort, "MODEFIELD"))) {
        Set tAt = $ListFind($ListFromString($Parameter(tPort, "STARTMODES")), tMode)
        Quit $Select(tAt: $Piece(..#MODECONSEQUENCES, ",", tAt), 1: "")
    }
    Set tRestart = 0
    For tField = "DBEncIRISSecurity", "DBEncIRISTemp" {
        If pPayload.%GetTypeOf(tField) = "unassigned" Continue
        If ..Flag(pPayload, tField) '= ..Flag(tHeld, tField) Set tRestart = 1
    }
    If tRestart Quit ..#RESTARTCONSEQUENCE
    If (pPayload.%GetTypeOf("DBEncJournal") '= "unassigned") && (..Flag(pPayload, "DBEncJournal") '= ..Flag(tHeld, "DBEncJournal")) Quit ..#JOURNALCONSEQUENCE
    Quit ""
}

/// <p>What the caller must hold: the screen's own pairs, then the custom resource of each
/// <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44). The write declares no pair beyond
/// Security's set (measured at Task 0).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p><parameter>FILESYSTEMRESOURCE</parameter> when <var>pArgs</var> sends a root.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    If '$IsObject(pArgs) Quit ""
    If (pArgs.%GetTypeOf("root") = "string") && (pArgs.%Get("root") '= "") Quit $ListBuild($ListBuild(..#FILESYSTEMRESOURCE, ..#USEPERMISSION))
    Quit ""
}

}
