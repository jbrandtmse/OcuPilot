/// <p>What the Classes and Routines lists' creates share (AD-53, AD-54, Story 20.20): an agent's
/// proposal of one new class or routine in the turn's namespace, which the person confirms. Confirm saves
/// the text and then compiles it, as the person.</p>
/// <p><b>The mint</b> (<class>OcuPilot.Screen.Tool.ExplorerCreateMint</class>) applies the saves' rules to
/// the new name (<method>OcuPilot.Screen.Tool.ExplorerSave.AgentProblem</method> with <code>pCreate</code>)
/// and refuses a name the namespace already holds. The fresh read is <code>NEWDOC</code>, which must find
/// the name absent; the absence fingerprint covers it, so a name taken after the mint refuses at Confirm.
/// The write is <code>CREATE</code>: the port sends no version and refuses a held name before the PUT
/// (<class>OcuPilot.Port.AtelierPort</class>), and the vendor refuses a PUT over the exact name with 409.</p>
/// <p><b>The payload</b> is <code>{content, Compile, Namespace}</code> and the diff one row, the whole new
/// text as added lines (<method>ComposeCreate</method>). The card needs no client change: a row with an
/// empty <code>before</code> draws every line as added.</p>
/// <p><b>WRITE</b> is an argument pair read from the namespace the proposal stored (DW-2242,
/// <class>OcuPilot.Screen.Tool.ExplorerSave</class>.<method>CodeWritePairs</method>). The consequence, the
/// card's size limit, the port query and the write's output are the save's.</p>
Class OcuPilot.Screen.Tool.ExplorerCreate Extends OcuPilot.Screen.Tool.ExplorerWrite [ Abstract ]
{

/// <p>Offered to the agent only: no screen action carries a create (AD-55).</p>
Parameter ADVERTISED As BOOLEAN = 1;

/// <p>No screen action: an agent-only write.</p>
Parameter SCREENACTIONS = "";

/// <p>The fresh read: whether the namespace holds a document the name takes.</p>
Parameter READTYPE = "NEWDOC";

Parameter WRITETYPE = "CREATE";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

/// <p>Declared: a create is not destructive, since nothing existing is replaced; a delete undoes it.</p>
Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>The field the write's precondition reads: the name's presence, which a create requires absent.</p>
Parameter PRECONDITIONFIELD = "Present";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Present,Namespace";

/// <p>The absence fingerprint's subject, for a create (AD-54).</p>
Parameter FINGERPRINTSUBJECT = "Present,Namespace";

/// <p>The pattern a new name must match for this list's kind (<method>SetProblem</method>).</p>
Parameter KINDPATTERN = "";

/// <p>What the refusal of a name of the wrong kind says.</p>
Parameter REASONKIND = "";

/// <p>What the schema says <code>Names</code> takes, for this list's kind.</p>
Parameter NAMESDESCRIPTION = "";

/// <p>How the schema says <code>Text</code> starts, for this list's kind.</p>
Parameter TEXTDESCRIPTION = "";

/// <p>The one value a create sends: the whole text.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.AtelierPort).#CONTENTKEY)
}

/// <p>What is wrong with <var>pValue</var> as the one new document a create names, or <code>""</code>:
/// one name of this list's kind (<parameter>KINDPATTERN</parameter>) with a package for a class, as
/// <method>OcuPilot.Port.AtelierPort.SetNames</method> reads it.</p>
ClassMethod SetProblem(pValue As %String) As %String
{
    If '$IsObject(pValue) && ($ListLength(##class(OcuPilot.Port.AtelierPort).SetNames(..Endpoint(), pValue)) = 1) && $Match(pValue, ..#KINDPATTERN) Quit ""
    Quit ..#REASONKIND
}

/// <p>The schema: the new document's name and whole text, and the agent's own words. The version and the
/// compile choice are never advertised: a create sends no version, and the compile always runs.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#IDARGUMENT, {"type": "string", "description": (..#NAMESDESCRIPTION)})
    Do tSchema.%Get("required").%Push(..#IDARGUMENT)
    Set tLimit = $FNumber(##class(OcuPilot.Screen.Tool.ExplorerSave).#CHANGEMAXLENGTH, ",")
    Do tProperties.%Set("Text", {"type": "string", "description": ("The document's whole text in UDL form, one string with line feeds. " _ ..#TEXTDESCRIPTION _ " At most " _ tLimit _ " characters. The header must name the document in Names.")})
    Do tSchema.%Get("required").%Push("Text")
    Do tProperties.%Set("rationale", {"type": "string", "description": "Why this new document is being proposed, in one sentence, shown to the user above the diff."})
    Do tProperties.%Set("expectedImpact", {"type": "string", "description": "What the user should expect to happen once this is confirmed, in one sentence."})
    Do tProperties.%Set("reverse", {"type": "string", "description": "How to undo this create, in one sentence. Omit it where no reversal exists."})
    Quit tSchema
}

/// <p>The screen's declared pairs, then the custom resource of each <parameter>CLASSICPAGES</parameter>
/// page. WRITE is not among them: <method>ArgumentPairs</method> carries it (DW-2242).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The WRITE pair on the routines database of the namespace the proposal stored, as a save's
/// (<class>OcuPilot.Screen.Tool.ExplorerSave</class>.<method>CodeWritePairs</method>, DW-2242).</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Tool.ExplorerSave).CodeWritePairs(pArgs, .pResolved)
}

/// <p>The composed payload and diff of the create (AD-54): <code>{content, Compile, Namespace}</code>,
/// the text the mint stored, the compile on (a create always compiles) and the namespace the mint read.
/// The diff is the one row the mint computed, the whole text as added lines, and the unchanged count is
/// zero.</p>
/// <p><b>Caller contract:</b> the same signature as <method>OcuPilot.Screen.Tool.Write.ComposeCreate</method>.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = {}
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tText = ""
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(##class(OcuPilot.Port.AtelierPort).#CONTENTKEY) = "string") Set tText = pArgs.%Get(##class(OcuPilot.Port.AtelierPort).#CONTENTKEY)
    Do pPayload.%Set(##class(OcuPilot.Port.AtelierPort).#CONTENTKEY, tText, "string")
    Do pPayload.%Set(##class(OcuPilot.Port.AtelierPort).#COMPILEKEY, 1, "boolean")
    Do pPayload.%Set(..#NAMESPACEFIELD, $Select($IsObject(pArgs) && (pArgs.%GetTypeOf("Namespace") = "string"): pArgs.%Get("Namespace"), 1: ""), "string")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Hunk") = "object") Do pDiff.%Push(pArgs.%Get("Hunk"))
    Quit $$$OK
}

/// <p>The save's port query (<class>OcuPilot.Screen.Tool.ExplorerSave</class>): the namespace the stored
/// payload was minted in, then the text and <code>Compile</code> under the port's query keys, so the
/// confirm's re-read and its write reach the namespace the proposal read (AD-52). A create's payload holds
/// no version.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##class(OcuPilot.Screen.Tool.ExplorerSave).PortQuery(pPayload, .pQuery)
}

/// <p>The mint's class for an agent's create: <class>OcuPilot.Screen.Tool.ExplorerCreateMint</class>.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.ExplorerCreateMint"
}

/// <p>The refusal of the agent's confirmed create, asked again at Confirm with the stored namespace:
/// <code>ExplorerSave.AgentProblem</code> with <code>pCreate</code>, so a name the mint refused, or one now
/// stored in another database, refuses here before anything is written.</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) Quit $$$OK
    Set pProblem = ##class(OcuPilot.Screen.Tool.ExplorerSave).AgentProblem(pArgs.%Get("Namespace"), pIdValue, 1)
    Quit $$$OK
}

/// <p>What the screen shows of the create the port answered <var>pWritten</var> for: the save's
/// (<class>OcuPilot.Screen.Tool.ExplorerSave</class>), its compile's <code>{lines, errors}</code>, or
/// <code>""</code>. Never stored, logged or sent to the model (AD-39).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.ExplorerSave).WriteOutput(.pWritten)
}

/// <p>The save's consequence code: the text compiles on Confirm, as the person.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ##class(OcuPilot.Screen.Tool.ExplorerSave).Consequence(pPayload, pPrivileged, pEffect)
}

}
