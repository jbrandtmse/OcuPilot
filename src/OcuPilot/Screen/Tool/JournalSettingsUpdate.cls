/// <p>Journal settings' edit (Story 18.18, AD-4, AD-6, AD-52, AD-55): propose a change to this
/// instance's journal settings. It reads them fresh through <class>OcuPilot.Port.JournalPort</class>,
/// merges the arguments over that object and mints a proposal the user confirms; the screen's Save
/// (<class>OcuPilot.Area.OsMgmt.JournalSave</class>) is its second caller. It writes nothing.</p>
/// <p><b>A merge write over the singleton</b> (AD-13): the body is the fresh read's ten settable keys
/// with the change applied, never <code>ArchiveName</code>, <code>wijdir</code> or
/// <code>targwijsz</code>, which the screen shows and the vendor keeps when omitted (AD-4's named
/// exception). The classic page's purge rule shapes the merge (<method>MergeUpdate</method>).</p>
/// <p><b>A directory is a root and a relative name</b> (<code>primaryRoot</code>,
/// <code>primaryPath</code>, <code>alternateRoot</code>, <code>alternatePath</code>), resolved through
/// <class>OcuPilot.Port.PathPort</class> as a vendor-writes directory that must already exist, at the
/// mint and again at the write, and sent only under the vendor's own key (AD-21's sixth case).</p>
/// <p><b>Its pairs</b> are Journal settings' own, <code>%DB_IRISSYS:WRITE</code> and
/// <code>%Admin_Operate:USE</code> (AD-8 as amended 2026-10-02: without the first the vendor's save
/// fails <code>&lt;PROTECT&gt;</code>, and without the second it stores the change and then fails its
/// file switch), and the path port's <code>%Admin_FileSystemAccess:USE</code> when a root is sent, each
/// refused by name before any port call. The descriptor's own classic page performs the save, so it
/// names no other (AD-44).</p>
Class OcuPilot.Screen.Tool.JournalSettingsUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.journalsettings.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.JournalSettings";

Parameter DESCRIPTION = "Propose a change to this instance's journal settings: its primary and alternate journal directories, the size at which it starts a new journal file, the file prefix, when old journal files are purged, and whether a journal write error freezes the instance, web sessions are journaled and files are compressed. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'SYSTEM' as the name and only the settings to change. A directory is named by one of the instance's allowed directories and a relative name, and must already exist. The archive target and the write image journal are never changed here.";

/// <p>The port that composes the settings read and write (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.JournalPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names them).</p>
Parameter PERMITTEDFIELDS = "BackupsBeforePurge,DaysBeforePurge,FileSizeLimit,FreezeOnError,JournalFilePrefix,JournalcspSession,PurgeArchived,CompressFiles";

/// <p>The template fields this tool never admits: the two directories, which only a root and a
/// relative name set, and the three the screen shows and the write never sends.</p>
Parameter EXCLUDEDFIELDS = "CurrentDirectory,AlternateDirectory,ArchiveName,wijdir,targwijsz";

/// <p>The pair the write itself names: the vendor's <code>ResourcesOR()</code> for the settings
/// <code>PUT</code> takes <code>%Admin_Manage</code> or <code>%Admin_Journal</code>, and the screen
/// declares both (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Manage";

Parameter WRITEPERMISSION = "USE";

/// <p>The pairs this tool requires beyond Journal settings' own, as comma-separated
/// <code>resource:permission</code> entries (AD-8).</p>
Parameter EXTRAPAIRS = "%DB_IRISSYS:WRITE,%Admin_Operate:USE";

/// <p>The path port's pair, required when a root is sent (AD-21's sixth case).</p>
Parameter FILESYSTEMRESOURCE = "%Admin_FileSystemAccess";

Parameter USEPERMISSION = "USE";

/// <p>The consequence a payload that leaves <code>FreezeOnError</code> on carries; the client maps it
/// to its published sentence.</p>
Parameter FREEZECONSEQUENCE = "JOURNAL.SETTINGS.FREEZE";

Parameter FREEZEFIELD = "FreezeOnError";

ClassMethod Endpoint() As %String
{
    Quit "Journal.Settings"
}

/// <p>The <code>ordinary</code> derived fields this tool admits (AD-3) and the four directory
/// arguments.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListFromString(##class(OcuPilot.Port.JournalPort).#DIRECTORYARGUMENTS)
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

/// <p>The derived schema with each field and the four directory arguments described, and the target
/// named as the singleton's literal id.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tDescriptions(..IdArgument()) = "Send the literal 'SYSTEM': the instance has one set of journal settings."
    Set tDescriptions("FileSizeLimit") = "The size, in megabytes, at which the instance starts a new journal file: a whole number from 0 to 4079."
    Set tDescriptions("JournalFilePrefix") = "A prefix for new journal files' names: up to 64 letters, digits, hyphens or underscores, or empty for none."
    Set tDescriptions("DaysBeforePurge") = "Purge journal files after this many days: a whole number from 0 to 100."
    Set tDescriptions("BackupsBeforePurge") = "Purge journal files after this many successful backups: a whole number from 0 to 10."
    Set tDescriptions("PurgeArchived") = "Whether journal files are purged as soon as they are copied to the archive target. With no archive target it is sent false, and while it is true both purge counts are sent 0."
    Set tDescriptions("FreezeOnError") = "Whether a journal write error blocks every process that journals until it is fixed."
    Set tDescriptions("JournalcspSession") = "Whether web sessions are journaled."
    Set tDescriptions("CompressFiles") = "Whether journal files are compressed."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    For tWhich = "primary", "alternate" {
        Set tRoot = {"type": "string"}
        Do tRoot.%Set("description", "For a new " _ tWhich _ " journal directory: one of this instance's allowed directories, exactly as its Allowed directories list reports it. The directory must already exist.", "string")
        Do tProperties.%Set(tWhich _ "Root", tRoot)
        Set tPath = {"type": "string"}
        Do tPath.%Set("description", "For a new " _ tWhich _ " journal directory: the directory under " _ tWhich _ "Root, up to eight names separated by /.", "string")
        Do tProperties.%Set(tWhich _ "Path", tPath)
    }
    Quit tSchema
}

/// <p>The kernel's merge over the fresh read without the keys the write never sends, and without a
/// directory's two arguments when the call names neither, with the classic page's purge rule applied
/// to the arguments first (<method>OcuPilot.Area.OsMgmt.JournalRules.PurgeRule</method>), so the
/// payload, the diff and the body agree for the mint, the confirm and the Save alike.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tPort = "OcuPilot.Port.JournalPort"
    Set tFresh = $ClassMethod(tPort, "Without", pFresh, $ListFromString($Parameter(tPort, "SHOWNONLYKEYS")))
    For tWhich = "primary", "alternate" {
        If $IsObject(pArgs) && ((pArgs.%GetTypeOf(tWhich _ "Root") '= "unassigned") || (pArgs.%GetTypeOf(tWhich _ "Path") '= "unassigned")) Continue
        Set tFresh = $ClassMethod(tPort, "Without", tFresh, $ListBuild(tWhich _ "Root", tWhich _ "Path"))
    }
    Set tArgs = ##class(OcuPilot.Area.OsMgmt.JournalRules).PurgeRule(pArgs, pFresh)
    Quit ##super(tFresh, tArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p>The rules of <method>OcuPilot.Area.OsMgmt.JournalRules.Problem</method> over the agent's
/// arguments, each directory resolved (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Area.OsMgmt.JournalRules).Problem(pArgs, .pProblem)
}

/// <p>The same rules asked again at the confirm (AD-6, AD-40), so a directory removed or a root
/// dropped since the mint refuses the confirm with the row left live, before the port's own
/// resolution at the write would.</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Area.OsMgmt.JournalRules).Problem(pArgs, .pProblem)
}

/// <p>Each directory whose root the payload carries, resolved, under its vendor key, just before the
/// port is invoked, so the read-back compares it. Arguments that no longer resolve leave the payload
/// as it is, and the port's own resolution refuses the write.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    Set tPort = "OcuPilot.Port.JournalPort"
    For tWhich = "primary", "alternate" {
        If pPayload.%GetTypeOf(tWhich _ "Root") '= "string" Continue
        If pPayload.%Get(tWhich _ "Root") = "" Continue
        Set tPath = $Select(pPayload.%GetTypeOf(tWhich _ "Path") = "string": pPayload.%Get(tWhich _ "Path"), 1: "")
        Set tSC = $ClassMethod(tPort, "ResolveDirectory", pPayload.%Get(tWhich _ "Root"), tPath, tWhich _ "Root", tWhich _ "Path", .tDirectory, .tHttp, .tFault)
        If $$$ISERR(tSC) || (tDirectory = "") Continue
        Do pPayload.%Set($Parameter(tPort, $Select(tWhich = "primary": "PRIMARYKEY", 1: "ALTERNATEKEY")), tDirectory, "string")
    }
}

/// <p>The stored payload's directory arguments under the port's own query keys (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    Set tNames = $ListFromString(##class(OcuPilot.Port.JournalPort).#DIRECTORYARGUMENTS)
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        If pPayload.%GetTypeOf(tName) '= "string" Continue
        If pPayload.%Get(tName) = "" Continue
        Set pQuery(tName) = pPayload.%Get(tName)
    }
}

/// <p><parameter>FREEZECONSEQUENCE</parameter> for a payload that sends
/// <parameter>FREEZEFIELD</parameter> true, and <code>""</code> otherwise.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If '$IsObject(pPayload) Quit ""
    If pPayload.%GetTypeOf(..#FREEZEFIELD) '= "boolean" Quit ""
    If 'pPayload.%Get(..#FREEZEFIELD) Quit ""
    Quit ..#FREEZECONSEQUENCE
}

/// <p>What the caller must hold: Journal settings' own pairs, then
/// <parameter>WRITERESOURCE</parameter> and each <parameter>EXTRAPAIRS</parameter> pair the set lacks,
/// then the custom resource of each <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8,
/// AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    For tI = 1:1:$Length(..#EXTRAPAIRS, ",") {
        Set tEntry = $ZStrip($Piece(..#EXTRAPAIRS, ",", tI), "<>W")
        If tEntry = "" Continue
        Set tPair = $ListBuild($Piece(tEntry, ":", 1), $Piece(tEntry, ":", 2))
        If '$ListFind(tPairs, tPair) Set tPairs = tPairs _ $ListBuild(tPair)
    }
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p><parameter>FILESYSTEMRESOURCE</parameter> when <var>pArgs</var> sends a root.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    Set tPairs = ""
    If '$IsObject(pArgs) Quit tPairs
    For tRoot = "primaryRoot", "alternateRoot" {
        If (pArgs.%GetTypeOf(tRoot) = "string") && (pArgs.%Get(tRoot) '= "") {
            Set tPairs = $ListBuild($ListBuild(..#FILESYSTEMRESOURCE, ..#USEPERMISSION))
            Quit
        }
    }
    Quit tPairs
}

}
