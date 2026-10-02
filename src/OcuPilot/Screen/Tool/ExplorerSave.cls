/// <p>System Explorer's save of one document's text (AD-6, AD-10, AD-51, AD-53, Story 19.3): what the
/// Classes and Routines lists' save tools share. The class and routine editors' Save sends the text,
/// the version the editor read and the compile choice as the list's <code>save</code> action's
/// declared values, and <class>OcuPilot.Port.AtelierPort</class> puts the text against that version,
/// refusing a document another writer changed since, and compiles it when asked.</p>
/// <p><b>It is unadvertised</b> (<parameter>ADVERTISED</parameter> 0, AD-53's named case): only a
/// person's Save writes code. The provider's tool list, the dispatch lookup and the screen context's
/// <code>tools</code> never carry it, and its baseline key ships disabled; a person's own Save is
/// never asked governance (AD-22).</p>
/// <p><b>The text is a screen value alone</b>: the input schema names only the document
/// (<method>InputSchema</method>), and the text is never stored, logged or put on a proposal, a card
/// or the ledger. The target is exactly one document (<method>SetProblem</method>).</p>
/// <p><b>It is destructive</b>: a save replaces the document's text, which cannot be undone from
/// OcuPilot. It declares WRITE on the namespace's routines database (AD-8), and the kernel refuses a
/// document whose name begins with <code>OcuPilot</code>
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTCODE</parameter>). The compile's console
/// lines reach the screen only (AD-39's fifth exception). No classic page has an editor, so it
/// declares none (AD-44).</p>
Class OcuPilot.Screen.Tool.ExplorerSave Extends OcuPilot.Screen.Tool.ExplorerWrite [ Abstract ]
{

/// <p>Reached by a person's Save alone (AD-53).</p>
Parameter ADVERTISED As BOOLEAN = 0;

/// <p>The list's save, which the editors send.</p>
Parameter SCREENACTIONS = "save";

Parameter SCREENVALUES = "save=content:version:Compile";

/// <p>The fresh read: the one document, with the three declared values empty beside it.</p>
Parameter READTYPE = "SAVEDOCS";

Parameter WRITETYPE = "SAVE";

/// <p>Declared: a save replaces the document's text.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>A save acts on the document at the version the editor read.</p>
Parameter PRECONDITIONFIELD = "Modified";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Present,Modified,Absent,Namespace,content,version,Compile";

/// <p>The document's version, the namespace, and the text, version and compile choice saved.</p>
Parameter FINGERPRINTSUBJECT = "Modified,Absent,Namespace,content,version,Compile";

/// <p>The three declared values the port reads beyond the document.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.AtelierPort).#CONTENTKEY, ##class(OcuPilot.Port.AtelierPort).#VERSIONKEY, ##class(OcuPilot.Port.AtelierPort).#COMPILEKEY)
}

/// <p>What is wrong with <var>pValue</var> as the document a save names, or <code>""</code>: exactly
/// one name of this list's kind.</p>
ClassMethod SetProblem(pValue As %String) As %String
{
    If '$IsObject(pValue) && ($ListLength(##class(OcuPilot.Port.AtelierPort).SetNames(..Endpoint(), pValue)) = 1) Quit ""
    Quit "'" _ ..#IDARGUMENT _ "' names exactly one document of this list, as this instance's list reports it"
}

/// <p>The schema: the document alone, required, and the agent's own words. The text, the version and
/// the compile choice are never advertised, so the closed schema refuses them.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#IDARGUMENT, {"type": "string", "description": "The one document, named exactly as this instance's own list reports it."})
    Do tSchema.%Get("required").%Push(..#IDARGUMENT)
    Do tProperties.%Set("rationale", {"type": "string", "description": "Why this change is being proposed, in one sentence, shown to the user above the diff."})
    Do tProperties.%Set("expectedImpact", {"type": "string", "description": "What the user should expect to happen once this is confirmed, in one sentence."})
    Do tProperties.%Set("reverse", {"type": "string", "description": "How to undo this change, in one sentence. Omit it where no reversal exists."})
    Quit tSchema
}

/// <p>The screen's three values as this tool's arguments: the text and the version as sent, and
/// <code>Compile</code> from <code>true</code> or <code>false</code>, any other spelling refused (AD-56
/// (ii)).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tField = ##class(OcuPilot.Port.AtelierPort).#CONTENTKEY, ##class(OcuPilot.Port.AtelierPort).#VERSIONKEY {
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    Set tCompile = ""
    If $IsObject(pValues) Set tCompile = pValues.%Get(##class(OcuPilot.Port.AtelierPort).#COMPILEKEY)
    If (tCompile '= "true") && (tCompile '= "false") {
        Set pArgs = {}
        Set pProblem = "'" _ ##class(OcuPilot.Port.AtelierPort).#COMPILEKEY _ "' is true or false"
        Quit $$$OK
    }
    Do pArgs.%Set(##class(OcuPilot.Port.AtelierPort).#COMPILEKEY, (tCompile = "true"), "boolean")
    Quit $$$OK
}

/// <p>The namespace, then the text, the version and <code>Compile</code> (as <code>1</code> or
/// <code>0</code>) of the payload <var>pPayload</var> under the port's own query keys, so the write
/// saves what the person sent against the version the editor read (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.AtelierPort).#CONTENTKEY, ##class(OcuPilot.Port.AtelierPort).#VERSIONKEY {
        If (pPayload.%GetTypeOf(tField) = "string") && (pPayload.%Get(tField) '= "") Set pQuery(tField) = pPayload.%Get(tField)
    }
    Set tCompile = ##class(OcuPilot.Port.AtelierPort).#COMPILEKEY
    If pPayload.%GetTypeOf(tCompile) = "boolean" Set pQuery(tCompile) = $Select(pPayload.%Get(tCompile): 1, 1: 0)
}

/// <p>No state row: a save's card, were one minted, would show nothing of the text.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>What the screen shows of the save the port answered <var>pWritten</var> for: its compile's
/// <code>{lines, errors}</code> when it compiled, or <code>""</code>. Never stored, logged or put on
/// the ledger, and never sent to the model (AD-39).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("lines") '= "array" Quit ""
    Quit pWritten
}

}
