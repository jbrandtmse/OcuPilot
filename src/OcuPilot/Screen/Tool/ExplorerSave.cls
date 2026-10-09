/// <p>System Explorer's save of one document's text (AD-6, AD-10, AD-51, AD-53, Stories 19.3 and 20.21):
/// what the Classes and Routines lists' save tools share. A person's Save sends the text, the version
/// the editor read and the compile choice as the list's <code>save</code> action's declared values, and
/// <class>OcuPilot.Port.AtelierPort</class> puts the text against that version, refusing a document
/// another writer changed since, and compiles it when asked.</p>
/// <p><b>The agent's save</b> sends exact replacements instead (<code>Edits</code>), which
/// <class>OcuPilot.Screen.Tool.ExplorerSaveMint</class> applies to the stored text, so the card reviews
/// what will be saved. The agent's rules (<method>AgentProblem</method>, <method>ConfirmProblem</method>)
/// apply to that path only; a person's Save never asks them.</p>
/// <p><b>The text is a screen value alone</b> for a person's Save: the input schema names the document and
/// the agent's replacements, and the text is never stored, logged or put on a card or the ledger. The
/// target is exactly one document (<method>SetProblem</method>).</p>
/// <p><b>It is destructive</b>: a save replaces the document's text, which cannot be undone from
/// OcuPilot. Its WRITE pair on the routines database is an argument pair (<method>ArgumentPairs</method>):
/// it resolves from the namespace the proposal stored, else the request's, so a confirm writes where the
/// proposal read (DW-2242, AD-8). The kernel refuses a document whose name begins with <code>OcuPilot</code>
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTCODE</parameter>). The compile's console
/// lines reach the screen and the proposal card only (AD-39's fifth exception). No classic page has an
/// editor, so it declares none (AD-44).</p>
Class OcuPilot.Screen.Tool.ExplorerSave Extends OcuPilot.Screen.Tool.ExplorerWrite [ Abstract ]
{

/// <p>Offered to the agent as well as reached by a person's Save (AD-53, Story 20.21).</p>
Parameter ADVERTISED As BOOLEAN = 1;

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

/// <p>The consequence code the proposal carries: the save compiles the text on Confirm.</p>
Parameter CONSEQUENCE = "EXPLORER.SAVE.COMPILES";

/// <p>The most characters one change's hunk may serialize to, so the card shows it whole.</p>
Parameter CHANGEMAXLENGTH As INTEGER = 30000;

/// <p>The rule a match refusal states, shared by every refusal of an <code>Old</code> text (DW-2228).</p>
Parameter MATCHRULE = "Each Old is matched exactly, character for character, against the text this instance stores. The copy explorer.class.source and explorer.routine.source send can differ from it: control and invisible characters are removed, a key-shaped value reads [redacted], and the data delimiter's name is changed. Choose an Old that avoids those places.";

/// <p>The endpoint that reads one document of the tool's kind, as the agent's mint reads its stored text.
/// Abstract: each list names its own.</p>
ClassMethod DocumentEndpoint() As %String [ Abstract ]
{
    Quit ""
}

/// <p>The three declared values the port reads beyond the document.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.AtelierPort).#CONTENTKEY, ##class(OcuPilot.Port.AtelierPort).#VERSIONKEY, ##class(OcuPilot.Port.AtelierPort).#COMPILEKEY)
}

/// <p>The screen's declared pairs, then the custom resource of each <parameter>CLASSICPAGES</parameter>
/// page. WRITE is not among them: <method>ArgumentPairs</method> carries it (DW-2242).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The WRITE pair a save or a create of <var>pArgs</var> requires (DW-2242, AD-8): WRITE on the
/// routines database of the namespace the proposal stored in its <code>Namespace</code> argument, else
/// of the request's scope. <var>pResolved</var> is 0 when that database names no resource, which the
/// caller refuses.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Quit ..CodeWritePairs(pArgs, .pResolved)
}

/// <p>The WRITE pair on the routines database of <var>pArgs</var>' <code>Namespace</code>, or of the
/// request's scope when that is absent or empty (<method>ArgumentPairs</method>). Shared by a save and a
/// create (<class>OcuPilot.Screen.Tool.ExplorerCreate</class>).</p>
ClassMethod CodeWritePairs(pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set tNamespace = ""
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Namespace") = "string") Set tNamespace = pArgs.%Get("Namespace")
    If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(tNamespace, .tRoutine, .tGlobal, .tMapped, .tResolved)
    Set pResolved = tResolved && (tRoutine '= "")
    If 'pResolved Quit ""
    Quit $ListBuild($ListBuild(tRoutine, "WRITE"))
}

/// <p>What is wrong with <var>pValue</var> as the document a save names, or <code>""</code>: exactly
/// one name of this list's kind.</p>
ClassMethod SetProblem(pValue As %String) As %String
{
    If '$IsObject(pValue) && ($ListLength(##class(OcuPilot.Port.AtelierPort).SetNames(..Endpoint(), pValue)) = 1) Quit ""
    Quit "'" _ ..#IDARGUMENT _ "' names exactly one document of this list, as this instance's list reports it"
}

/// <p>The schema: the document, the agent's replacements and its own words. The text, the version and
/// the compile choice are never advertised, so the closed schema refuses them.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#IDARGUMENT, {"type": "string", "description": "The one document, named exactly as this instance's own list reports it."})
    Do tSchema.%Get("required").%Push(..#IDARGUMENT)
    Set tEdits = {"type": "array", "minItems": 1, "maxItems": 20, "description": "One to 20 exact replacements, applied in order to the document's stored text. Each is an object with exactly Old and New. Read the document first with explorer.class.source or explorer.routine.source, and copy each Old from that read."}
    Do tEdits.%Set("items", {"type": "object", "description": "One replacement: Old, the text to replace, which must occur exactly once in the stored text at the point its edit applies, and New, the text that replaces it. Send exactly these two members."})
    Do tProperties.%Set("Edits", tEdits)
    Do tSchema.%Get("required").%Push("Edits")
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

/// <p>The body the mint and the confirm's re-merge take for a save: the fresh read merged with the
/// stored text, version and compile choice by the kernel's merge, and the diff replaced by the one row
/// the agent's mint computed, <code>[pArgs.Hunk]</code>, or <code>[]</code> when no hunk is present (a
/// person's Save carries none, so its diff is empty, as before).</p>
/// <p><b>Caller contract:</b> the same signature as <method>OcuPilot.Screen.Tool.Write.MergeUpdate</method>.
/// A person's Save calls the kernel merge itself, so its payload and diff are unchanged.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) Quit tSC
    Set pDiff = []
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Hunk") = "object") Do pDiff.%Push(pArgs.%Get("Hunk"))
    Quit $$$OK
}

/// <p>The mint's class for an agent's save: <class>OcuPilot.Screen.Tool.ExplorerSaveMint</class>, which
/// applies the agent's replacements and computes the hunk (Story 20.21).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.ExplorerSaveMint"
}

/// <p>What is wrong with saving document <var>pName</var> in namespace <var>pNamespace</var> on the
/// agent's behalf, or <code>""</code>. The mint asks it, and Confirm asks it again before anything is
/// written; a person's Save never asks it. With <var>pCreate</var> the same rules apply to a new name
/// (Story 20.20): the sentences say create, and a name holding <code>%</code> anywhere is refused.</p>
/// <p>Refused: an empty namespace, <code>%SYS</code>, a name beginning with <code>%</code>, and a document
/// whose database is not its namespace's own routines database. A mapped document's answer names the
/// database it is stored in and says the person can save it from the editor. An answer that cannot be
/// read refuses.</p>
ClassMethod AgentProblem(pNamespace As %String, pName As %String, pCreate As %Boolean = 0) As %String
{
    Set tProblem = ""
    Set tVerb = $Select(pCreate: "create", 1: "save")
    Try {
        If pNamespace = "" {
            Set tProblem = $Select(pCreate: "the namespace is not known, so the agent does not create the document", 1: "the namespace of the document is not known, so the agent does not save it")
            Quit
        }
        If $ZConvert(pNamespace, "U") = "%SYS" {
            Set tProblem = "the agent does not " _ tVerb _ " a document in %SYS"
            Quit
        }
        If pCreate && (pName [ "%") {
            Set tProblem = "the agent does not create a document whose name holds %"
            Quit
        }
        If $Extract(pName) = "%" {
            Set tProblem = "the agent does not " _ tVerb _ " a document whose name begins with %"
            Quit
        }
        Set tPieces = $Length(pName, ".")
        Set tBase = $Piece(pName, ".", 1, tPieces - 1)
        Set tExtension = $ZConvert($Piece(pName, ".", tPieces), "L")
        Set tRoutineDest = ##class(%SYS.Namespace).GetRoutineDest(pNamespace)
        If tExtension = "cls" {
            Set tPackage = $Piece(tBase, ".", 1, $Length(tBase, ".") - 1)
            Set tDest = ##class(%SYS.Namespace).GetPackageDest(pNamespace, tPackage)
        } Else {
            Set tType = $Select(tExtension = "inc": "INC", tExtension = "int": "INT", 1: "MAC")
            Set tDest = ##class(%SYS.Namespace).GetRoutineDest(pNamespace, tBase, tType)
        }
        If (tDest = "") || (tRoutineDest = "") {
            Set tProblem = $Select(pCreate: "the database that would hold '" _ pName _ "' could not be read, so the agent does not create it", 1: "the database that holds '" _ pName _ "' could not be read, so the agent does not save it")
            Quit
        }
        If tDest = tRoutineDest Quit
        Set tPath = "^" _ tDest
        Kill tInfo
        Do ##class(%SYS.Namespace).GetAllNSInfo(tPath, .tInfo, 1)
        Set tResource = $Get(tInfo("RoutineDB", "Resource"))
        Set tWhere = "another database"
        If $Extract(tResource, 1, 4) = "%DB_" Set tWhere = "database " _ $Extract(tResource, 5, *)
        If pCreate {
            Set tProblem = "'" _ pName _ "' would be stored in " _ tWhere _ ", not in this namespace's own routines database, so the agent does not create it"
        } Else {
            Set tProblem = "'" _ pName _ "' is stored in " _ tWhere _ ", not in this namespace's own routines database, so the agent does not save it. The person can save it from the class or routine editor."
        }
    } Catch {
        Set tProblem = $Select(pCreate: "the database that would hold '" _ pName _ "' could not be read, so the agent does not create it", 1: "the database that holds '" _ pName _ "' could not be read, so the agent does not save it")
    }
    Quit tProblem
}

/// <p>The refusal of the agent's confirmed save, asked again at the write with the stored arguments
/// <var>pArgs</var> (the namespace the mint read), in <var>pProblem</var>, or <code>""</code>. A name
/// the mint refused, or a document moved to another database since, refuses here (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) Quit $$$OK
    Set pProblem = ..AgentProblem(pArgs.%Get("Namespace"), pIdValue)
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

/// <p>The consequence code every save carries: the text compiles on Confirm, as the user.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

}
