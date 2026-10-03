/// <p>Journals' Check integrity (Story 18.5, AD-51, AD-53): check one journal file, its headers or
/// every record, through the vendor's <code>Journal.File</code> <code>INTEGRITYCHECK</code>, which the
/// vendor queues (AD-26) and which changes nothing. <class>OcuPilot.Port.JournalPort</class> builds
/// <code>{CheckDetails}</code> from the tool's one argument, <parameter>ARGUMENT</parameter>, carried
/// in the port query (<method>PortQuery</method>); the screen's warning dialog sends it as its flag
/// (<parameter>SCREENVALUES</parameter>).</p>
/// <p><b>The target is a file the instance's journal file list names</b> (AD-21's eighth case): any
/// other name is refused <code>JOURNAL.FILE.UNLISTED</code> before the vendor is called for it, at the
/// mint (<class>OcuPilot.Screen.Tool.JournalMint</class>) as at the write. The fresh read is the
/// file's <code>GET</code>, whose <code>FileGUID</code> is the precondition: a file replaced under the
/// same name refuses the confirm.</p>
/// <p><b>Its findings are the check's console lines</b>, which reach the screen and the proposal card
/// only, through <method>WriteOutput</method> (AD-39's fifth exception); no line reaches a tool
/// result, the ledger, a log line or screen context. A check still running past the port's bound has
/// started (AD-26). Journals' own two pairs suffice (measured); the classic integrity page is its
/// replaced page (AD-44). No vendor event records it with auditing on (AD-15, AD-53).</p>
Class OcuPilot.Screen.Tool.JournalIntegrityCheck Extends OcuPilot.Screen.Tool.JournalAction
{

Parameter TOOLNAME = "osmgmt.journals.integrity";

Parameter DESCRIPTION = "Propose an integrity check of one journal file: the instance reads the file and changes nothing in it; it answers a proposal the user reviews and confirms. Name the file exactly as this instance's journal file list reports it. Set CheckDetails to check every record, which takes longer.";

Parameter SCREENACTIONS = "integrity";

/// <p>The screen's warning dialog sends its flag as this tool's one argument (AD-56 (ii)).</p>
Parameter SCREENVALUES = "integrity=CheckDetails";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "INTEGRITYCHECK";

/// <p>The one argument: whether every record is checked.</p>
Parameter ARGUMENT = "CheckDetails";

Parameter PRECONDITIONFIELD = "FileGUID";

/// <p>The file's identity, and the argument, which the stored payload keeps so the confirm sends what
/// the card showed.</p>
Parameter FINGERPRINTSUBJECT = "FileGUID,CheckDetails";

Parameter READANSWERS = "FileGUID,CheckDetails,CreationTime,FileCount,MaxSize,FirstRecordAddress,LastRecordAddress,End,EncryptionKeyID,MinTransFileCount,MinTransFileIndex,ClusterStartTime";

Parameter CLASSICPAGES = "%cspapp.op.utilsysjournalintegrity";

/// <p>The client maps it to <code>journalIntegrityConsequence</code>.</p>
Parameter CONSEQUENCECODE = "JOURNAL.INTEGRITY";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.JournalPort).#FILEENDPOINT
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.AdminPort).#JOURNALFILEPARAM
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the file is read and
/// found listed (<class>OcuPilot.Screen.Tool.JournalMint</class>).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.JournalMint"
}

/// <p><parameter>ARGUMENT</parameter> alone: the tool sends no body, so its field list is empty by
/// derivation (AD-3), and its one argument reaches the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#ARGUMENT)
}

/// <p>The identifying property described, and <parameter>ARGUMENT</parameter> added as an optional
/// boolean.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The journal file to check, named exactly as this instance's journal file list reports it. Any other name is refused.", "string")
    Do tProperties.%Set(..#ARGUMENT, {"type": "boolean", "description": "Check every record rather than the file's headers alone. It takes longer. Omit it for false."})
    Quit tSchema
}

/// <p>The stored payload's <parameter>ARGUMENT</parameter> under the port's own query key, as
/// <code>true</code> or <code>false</code> (AD-52). <var>pPayload</var> may also be the caller's
/// arguments, which carry the same name.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#ARGUMENT) '= "boolean" Quit
    Set pQuery(##class(OcuPilot.Port.JournalPort).#CHECKDETAILSQUERY) = $Select(pPayload.%Get(..#ARGUMENT): "true", 1: "false")
}

/// <p>The screen's flag as this tool's argument (AD-56 (ii)): <code>true</code> or <code>false</code>
/// as a boolean; any other value is not sent, and the port checks the headers alone.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) || (pValues.%GetTypeOf(..#ARGUMENT) = "unassigned") Quit $$$OK
    Set tValue = pValues.%Get(..#ARGUMENT)
    If (tValue = "true") || (tValue = "false") Do pArgs.%Set(..#ARGUMENT, (tValue = "true"), "boolean")
    Quit $$$OK
}

/// <p>No state row: an argument's own merge row is the card's.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>What the screen and the proposal card show of the check the port answered <var>pWritten</var>
/// for: <code>{lines, errors}</code>, the check's console lines and whether it found errors, which it
/// did when it wrote a line or failed. <code>""</code> for any other answer, a started check's
/// among them. Never stored, logged or put on the ledger, and never sent to the model (AD-39).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("console") '= "array" Quit ""
    Set tLines = pWritten.%Get("console")
    Set tOut = {}
    Do tOut.%Set("lines", tLines)
    Do tOut.%Set("errors", (tLines.%Size() > 0) || ''pWritten.%Get("failed"), "boolean")
    Quit tOut
}

}
