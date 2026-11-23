/// <p>Interoperability's message export (AD-6, AD-13, AD-22, AD-51, AD-53, AD-62, Story 24.16 Batch 3): save the bodies of the checked messages of the
/// Messages list as one file, as the classic Messages page's Export dialog does, each only if its body can be written as text. Two callers reach it: the list's row action
/// Export over the checked rows, after the dry run a person reviews, and the agent's proposal and confirmation. It extends the Suspended messages set writes
/// (<class>OcuPilot.Screen.Tool.InteropSuspendedAction</class>) -- the same reviewed digest, card lines and outcome lines, with the export's own verdicts and words -- and adds the
/// separator and the character set the file is made with.</p>
/// <p><b>Not destructive, key <code>true</code></b> (AD-22): an export changes nothing. The vendor's own view row is recorded for each body exported
/// (<method>OcuPilot.Port.InteropPort.AuditViewHere</method>), so OcuPilot records no row of its own. <b>The file reaches the confirming browser alone</b>
/// (<method>WriteOutput</method>, AD-39's fifth exception): its bytes, base64-encoded, are the answer's <code>output.file</code>, never stored, logged, put on the ledger or sent to the model.</p>
Class OcuPilot.Screen.Tool.InteropMessageExport Extends OcuPilot.Screen.Tool.InteropSuspendedAction
{

Parameter TOOLNAME = "interop.messages.export";

Parameter DESCRIPTION = "Propose exporting the bodies of messages of the interoperability message store to one file, which the user saves in the browser. It changes nothing by itself: it answers a proposal the user reviews and confirms, and the proposal shows what each message would do. Name the messages by the ids interop.messages.read reports in its ID column, up to 100, separated by commas; a set over 100 or with a malformed id is refused, never cut. Choose the separator between messages (CRLF, CR, LF, MLLP, Tab or None; CRLF unless asked) and the character set (UTF8 unless asked). A message is exported only if it still exists with a body that can be written as text; the others are listed with the reason and not exported, and a set none of which can be exported is refused. Each body exported is recorded in the audit log as viewed. The messages' text is never sent to you.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropMessageList";

Parameter SETDESCRIPTION = "The messages to export.";

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>The classic Export dialog's resource (<code>EnsPortal.Dialog.ExportMessages</code>, AD-8, AD-44), and READ alone on the globals database: an export writes no database.</p>
Parameter WRITERESOURCE = "%Ens_MessageExport";

Parameter DATABASEPERMISSION = "READ";

Parameter CLASSICPAGES = "EnsPortal.Dialog.ExportMessages";

/// <p>The fresh read: the set's verdicts, composed for the export.</p>
Parameter READTYPE = "EXPORT";

Parameter WRITETYPE = "EXPORTMESSAGES";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,Production,Messages,Verdicts,Eligible,Reviewed,Digest,Separator,Charset,Separators,Charsets";

Parameter SCREENACTIONS = "export";

/// <p>A person's action carries the separator, the character set and the digest it was reviewed at; the dry run may carry the first two and not the digest.</p>
Parameter SCREENVALUES = "export=Separator:Charset:Reviewed";

Parameter SCREENOPTIONAL = "export=Separator:Charset:Reviewed";

Parameter FINGERPRINTSUBJECT = "Verdicts,Separator,Charset,Namespace,Reviewed";

Parameter PRECONDITIONCODES = "INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.MESSAGE.EXPORT";

Parameter NONECODE = "INTEROP.EXPORT.NONE";

/// <p>An export changes nothing, which the list reads again all the same.</p>
Parameter CHANGEACTION = "updated";

Parameter OUTCOMEKIND = "export";

/// <p>The argument names the file is made with.</p>
Parameter SEPARATORARGUMENT = "Separator";

Parameter CHARSETARGUMENT = "Charset";

/// <p>The Messages endpoint, which serves the export beside the resends.</p>
ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTMESSAGES
}

/// <p>The reviewed digest and the two choices a person's action carries, which reach the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#SEPARATORARGUMENT, ..#CHARSETARGUMENT, ..#REVIEWEDARGUMENT)
}

/// <p>The screen's pairs, then the export dialog's resource and the Contents pane's (an export is never a way round it), then READ on the globals database
/// (<method>OcuPilot.Screen.Tool.InteropAction.PrivilegePairs</method>), each once, in the port's order.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##super(pDescriptor, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    Set tContent = $ListBuild("%Ens_MessageContent", "USE")
    Set tAt = $ListFind(tPairs, tOwn)
    If 'tAt Quit tPairs
    Set tOut = ""
    For tI = 1:1:$ListLength(tPairs) {
        If $List(tPairs, tI) = tContent Continue
        Set tOut = tOut _ $ListBuild($List(tPairs, tI))
        If tI = tAt Set tOut = tOut _ $ListBuild(tContent)
    }
    Quit tOut
}

/// <p>Compose the port's read (<method>OcuPilot.Screen.Tool.InteropMessageAction.PortQuery</method>), then name the separator and the character set the payload holds.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#SEPARATORARGUMENT) = "string" Set pQuery(##class(OcuPilot.Port.InteropPort).#SEPARATORKEY) = pPayload.%Get(..#SEPARATORARGUMENT)
    If pPayload.%GetTypeOf(..#CHARSETARGUMENT) = "string" Set pQuery(##class(OcuPilot.Port.InteropPort).#CHARSETKEY) = pPayload.%Get(..#CHARSETARGUMENT)
}

/// <p>What is wrong with the separator or the character set <var>pArgs</var> carries, as one sentence built from the argument's name, or <code>""</code>: a separator outside
/// <parameter>OcuPilot.Port.InteropPort.EXPORTSEPARATORS</parameter> and a character set the instance does not list. An argument left out reads its default. The classic dialog offers no other.</p>
ClassMethod ChoiceProblem(pArgs As %DynamicObject) As %String
{
    If '$IsObject(pArgs) Quit ""
    Set tSeparator = pArgs.%Get(..#SEPARATORARGUMENT)
    If (pArgs.%GetTypeOf(..#SEPARATORARGUMENT) '= "unassigned") && '$ListFind($ListFromString(##class(OcuPilot.Port.InteropPort).#EXPORTSEPARATORS), tSeparator) {
        Quit "'" _ ..#SEPARATORARGUMENT _ "' must be one of " _ $Replace(##class(OcuPilot.Port.InteropPort).#EXPORTSEPARATORS, ",", ", ")
    }
    Set tCharset = pArgs.%Get(..#CHARSETARGUMENT)
    If (pArgs.%GetTypeOf(..#CHARSETARGUMENT) '= "unassigned") && '$ListFind(##class(OcuPilot.Port.InteropPort).ExportCharsets(), tCharset) {
        Quit "'" _ ..#CHARSETARGUMENT _ "' must be one of the character sets this instance lists: " _ $ListToString(##class(OcuPilot.Port.InteropPort).ExportCharsets(), ", ")
    }
    Quit ""
}

/// <p><method>OcuPilot.Screen.Tool.InteropSuspendedAction.SetProblem</method>, then <method>ChoiceProblem</method>.</p>
ClassMethod SetProblem(pValue As %String, pArgs As %DynamicObject) As %String
{
    Set tProblem = ##super(pValue, pArgs)
    If tProblem '= "" Quit tProblem
    Quit ..ChoiceProblem(pArgs)
}

/// <p>The same rules again at the confirm, so a character set the instance no longer lists is refused before the claim, leaving the proposal live (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..ChoiceProblem(pArgs)
    Quit $$$OK
}

/// <p>The derived schema with the set described and the two choices added, neither required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tSeparators = []
    For tI = 1:1:$Length(##class(OcuPilot.Port.InteropPort).#EXPORTSEPARATORS, ",") Do tSeparators.%Push($Piece(##class(OcuPilot.Port.InteropPort).#EXPORTSEPARATORS, ",", tI), "string")
    Set tProperty = {"type": "string", "description": "What goes between two messages in the file: CRLF, CR, LF, MLLP (the HL7 framing), Tab or None. CRLF when left out."}
    Do tProperty.%Set("enum", tSeparators)
    Do tProperties.%Set(..#SEPARATORARGUMENT, tProperty)
    Do tProperties.%Set(..#CHARSETARGUMENT, {"type": "string", "description": "The character set the file is written in, one this instance lists, such as UTF8 or CP1252. UTF8 when left out."})
    Quit tSchema
}

/// <p>The screen's values as this tool's arguments (AD-56 (ii)): the digest a person's dry run answered and the separator and character set chosen, each a string as sent; a
/// value that is not one of its list is <var>pProblem</var>, so the screen refuses it as the mint does.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject(pValues) {
        If pValues.%GetTypeOf(..#SEPARATORARGUMENT) = "string" Do pArgs.%Set(..#SEPARATORARGUMENT, pValues.%Get(..#SEPARATORARGUMENT), "string")
        If pValues.%GetTypeOf(..#CHARSETARGUMENT) = "string" Do pArgs.%Set(..#CHARSETARGUMENT, pValues.%Get(..#CHARSETARGUMENT), "string")
    }
    Set pProblem = ..ChoiceProblem(pArgs)
    Quit $$$OK
}

/// <p>What a review answers beside its digest: the lists the dialog offers and the choices made, so the dialog asks nothing else of the instance.</p>
ClassMethod DryRunReview(pFresh As %DynamicObject) As %DynamicObject
{
    Set tReview = ##super(pFresh)
    If '$IsObject(pFresh) Quit tReview
    Do tReview.%Set(..#SEPARATORARGUMENT, pFresh.%Get("Separator"), "string")
    Do tReview.%Set(..#CHARSETARGUMENT, pFresh.%Get("Charset"), "string")
    If pFresh.%GetTypeOf("Separators") = "array" Do tReview.%Set("Separators", pFresh.%Get("Separators"))
    If pFresh.%GetTypeOf("Charsets") = "array" Do tReview.%Set("Charsets", pFresh.%Get("Charsets"))
    Quit tReview
}

/// <p>The outcome a confirmed export shows (<method>OcuPilot.Screen.Tool.InteropMessageAction.WriteOutput</method>'s lines, one for each message), and <code>file</code>, the bytes of
/// the export base64-encoded, when any message was exported. It reaches the confirming browser alone (AD-39's fifth exception).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    Set tOutput = ##super(pWritten)
    If '$IsObject(tOutput) Quit tOutput
    If (pWritten.%GetTypeOf("File") = "string") && (pWritten.%Get("File") '= "") Do tOutput.%Set("file", pWritten.%Get("File"), "string")
    Quit tOutput
}

}
