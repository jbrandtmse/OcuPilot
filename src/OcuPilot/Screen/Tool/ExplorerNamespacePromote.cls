/// <p>System Explorer's Compare namespaces promote (AD-5, AD-6, AD-10, AD-22, AD-51, AD-52, AD-53, Story 24.9): write the
/// classes and routines the route's namespace holds, and the other namespace of this instance lacks or holds differently,
/// into that other namespace, and compile them there. Two callers reach it: the screen's <code>promote</code> action over
/// the checked rows, reviewed first (<parameter>DRYRUN</parameter>) and confirmed by typing the other namespace's name,
/// and the agent's proposal and confirmation.</p>
/// <p><b>The target is the document set</b> (AD-13): <parameter>IDARGUMENT</parameter>'s names, comma-joined into one
/// <code>class</code> id whose canonical spelling is unique and sorted. <b>The fresh read is composed from the other
/// namespace, the pattern and the generated choice</b> (<parameter>READSVALUES</parameter>, <method>PortQuery</method>):
/// the port's <code>PLAN</code> answers the chosen steps, how many documents only the other namespace holds, and
/// <code>PlanHash</code>, which the fingerprint covers. A person's action carries the hash its review was read at as
/// <code>Reviewed</code>; the agent's confirm carries the hash its proposal was read at. The port derives the plan again
/// inside the write and refuses a hash that moved, <parameter>OcuPilot.Port.DevToolPort.CODESTALE</parameter>.</p>
/// <p><b>It is destructive</b>: a document written replaces the other namespace's copy and the replaced text is not kept,
/// so its card and its dialog state that there is no rollback (<parameter>CONSEQUENCE</parameter>), the dialog types the
/// other namespace's name, and its governance key ships disabled (AD-22). Nothing is deleted. The kernel refuses a set
/// naming a document of OcuPilot's own on both callers
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTCODE</parameter>), and the agent's own fence
/// (<method>OcuPilot.Screen.Tool.ExplorerSave.AgentProblem</method>) applies to its mint and its confirm alone. Its result
/// and per-document outcomes reach the screen and the proposal card only (AD-39).</p>
Class OcuPilot.Screen.Tool.ExplorerNamespacePromote Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "explorer.namespacediff.promote";

Parameter DESCRIPTION = "Propose promoting classes and routines from the route's namespace into `target`, another namespace of this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Read `explorer.namespacediff.read` first with the same `target`, `spec` and `generated`. Name in `Documents` only rows whose Change is 'Only in this namespace' or 'Content differs', at most 100. Each is written into the target, replacing its copy, then compiled. Nothing is deleted. There is no rollback, so say so in the rationale. A document whose name begins with OcuPilot or %, and %SYS, are refused. If either namespace changes before the user confirms, the proposal is refused.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerNamespaceDiff";

/// <p>The port that composes the plan and writes the set (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.DevToolPort";

/// <p>The fresh read: the plan for the chosen documents.</p>
Parameter READTYPE = "PLAN";

Parameter WRITETYPE = "PROMOTE";

/// <p>No body: the port composes the writes.</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The read is composed from the other namespace, the pattern and the generated choice the call carries.</p>
Parameter READSVALUES As BOOLEAN = 1;

/// <p>A person's action is reviewed through <code>POST /screens/:screen/dryrun</code> before it is sent, which lists the
/// steps and the documents left alone.</p>
Parameter DRYRUN As BOOLEAN = 1;

/// <p>Declared: a document written replaces the other namespace's copy and the replaced text is not kept.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>A promote changes documents of the other namespace, so a list showing them re-reads (AD-14).</p>
Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "promote";

/// <p>The other namespace, the pattern and the generated choice the screen was read with, and the plan hash the review was
/// read at, which the dry run carries none of.</p>
Parameter SCREENVALUES = "promote=target:spec:generated:Reviewed";

Parameter SCREENOPTIONAL = "promote=Reviewed";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,Target,Spec,Generated,Steps,Warnings,PlanHash,Reviewed";

/// <p>The chosen steps, both namespaces, the pattern and the generated choice, and the plan. <code>Reviewed</code> is
/// named because the stored payload is narrowed to the subject and <method>PortQuery</method> reads the hash from that
/// payload.</p>
Parameter FINGERPRINTSUBJECT = "Steps,Namespace,Target,Spec,Generated,PlanHash,Reviewed";

/// <p>A promote acts on the steps the plan showed.</p>
Parameter PRECONDITIONFIELD = "Steps";

/// <p>The card's state row's label.</p>
Parameter STATEFIELD = "Documents";

/// <p>The consequence code the proposal carries: each document is written over the other namespace's copy and nothing is
/// undone.</p>
Parameter CONSEQUENCE = "EXPLORER.PROMOTE.NOROLLBACK";

/// <p>The card's lines for the documents only the other namespace holds, which a promote leaves alone.</p>
Parameter REVIEWWARNING = "<n> documents only in the other namespace stay as they are.";

Parameter REVIEWWARNINGONE = "1 document only in the other namespace stays as it is.";

/// <p>The argument naming the set.</p>
Parameter IDARGUMENT = "Documents";

/// <p>The most documents one promote writes.</p>
Parameter MAXDOCUMENTS As INTEGER = 100;

/// <p>The write's endpoint: the namespace diff's.</p>
ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.DevToolPort).#ENDPOINTNAMESPACEDIFF
}

/// <p>The comma-joined names of the set.</p>
ClassMethod IdArgument() As %String
{
    Quit ..#IDARGUMENT
}

/// <p>The query key the port reads the set from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.DevToolPort).#DOCUMENTSKEY
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the plan is read and each step checked
/// (<class>OcuPilot.Screen.Tool.ExplorerNamespacePromoteMint</class>).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.ExplorerNamespacePromoteMint"
}

/// <p>The other namespace, the pattern, the generated choice and the reviewed plan hash, the names the payload carries
/// them under.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild("Target", "Spec", "Generated", "Reviewed")
}

/// <p>The screen's own pairs, then the custom resource of each <parameter>CLASSICPAGES</parameter> page, each pair once
/// (AD-8, AD-44). WRITE is not among them: <method>ArgumentPairs</method> carries it.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The WRITE pair on the routines database of the other namespace <var>pArgs</var> names, as <code>Target</code> or,
/// before the agent's mint has spelled it so, <code>target</code> (AD-8, AD-29): the namespace the documents are written
/// into, which the port checks again before any vendor call. <var>pResolved</var> is 0 when no namespace is named or its
/// database names no resource, which the caller refuses.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set tTarget = ""
    If $IsObject(pArgs) {
        If pArgs.%GetTypeOf("Target") = "string" Set tTarget = pArgs.%Get("Target")
        If (tTarget = "") && (pArgs.%GetTypeOf("target") = "string") Set tTarget = pArgs.%Get("target")
    }
    If tTarget = "" {
        Set pResolved = 0
        Quit ""
    }
    Quit ##class(OcuPilot.Screen.Tool.ExplorerSave).CodeWritePairs({"Namespace": (tTarget)}, .pResolved)
}

/// <p>What is wrong with <var>pValue</var> as the set a promote names, or <code>""</code>: a string of 1 to
/// <parameter>MAXDOCUMENTS</parameter> names, each a class or a routine, separated by commas.</p>
ClassMethod SetProblem(pValue As %String) As %String
{
    Set tSentence = "'" _ ..#IDARGUMENT _ "' names 1 to " _ ..#MAXDOCUMENTS _ " classes or routines, as the Compare namespaces list reports them, separated by commas"
    If $IsObject(pValue) Quit tSentence
    Kill tSeen
    Set tCount = 0
    Set tValid = 1
    For tI = 1:1:$Length(pValue, ",") {
        Set tName = $Piece(pValue, ",", tI)
        If tName = "" Continue
        If ($Length(tName) > 256) || ('$Match(tName, ##class(OcuPilot.Port.AtelierPort).#CLASSNAMEPATTERN) && '$Match(tName, ##class(OcuPilot.Port.AtelierPort).#ROUTINENAMEPATTERN)) {
            Set tValid = 0
            Quit
        }
        If '$Data(tSeen("n" _ tName)) {
            Set tSeen("n" _ tName) = ""
            Set tCount = tCount + 1
        }
    }
    If 'tValid || (tCount < 1) || (tCount > ..#MAXDOCUMENTS) Quit tSentence
    Quit ""
}

/// <p>The set refused by <method>SetProblem</method> after the fresh read, as it is before the mint (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..SetProblem(pIdValue)
    Quit $$$OK
}

/// <p>The schema: the other namespace, the pattern, the generated choice, the set and the agent's own words. The reviewed
/// plan hash is never advertised, so the closed schema refuses it, and no <code>reverse</code> is offered, since a promote
/// has none.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set("target", {"type": "string", "maxLength": 64, "description": "The other namespace of this instance the documents are written into, spelled as osmgmt.namespaces.read answers its Name. It must differ from the namespace the user is working in and must not be %SYS."})
    Do tProperties.%Set("spec", {"type": "string", "maxLength": 256, "description": "The pattern the comparison was read with, such as MyApp.*.cls,*.mac, as explorer.namespacediff.read took it."})
    Do tProperties.%Set("generated", {"type": "string", "enum": ["yes", "no"], "description": "yes when the comparison included generated routines. Omit it for no."})
    Do tProperties.%Set(..#IDARGUMENT, {"type": "string", "description": "The documents to promote, named exactly as the Document column of explorer.namespacediff.read reports them, separated by commas, at most 100. Each one's Change must be 'Only in this namespace' or 'Content differs'; any other name refuses the whole proposal."})
    For tField = "target", "spec", ..#IDARGUMENT {
        Do tSchema.%Get("required").%Push(tField)
    }
    Do tProperties.%Set("rationale", {"type": "string", "description": "Why this change is being proposed, in one sentence, shown to the user above the list of documents."})
    Do tProperties.%Set("expectedImpact", {"type": "string", "description": "What the user should expect to happen once this is confirmed, in one sentence."})
    Quit tSchema
}

/// <p>The screen's values as this tool's arguments (AD-56 (ii)): <code>Target</code>, <code>Spec</code> and
/// <code>Generated</code> as sent, from <code>target</code>, <code>spec</code> and <code>generated</code>, and
/// <code>Reviewed</code>, the plan hash a person's dry run answered, when the action carries one. The port judges each.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    For tPair = $ListBuild("target", "Target"), $ListBuild("spec", "Spec"), $ListBuild("generated", "Generated"), $ListBuild("Reviewed", "Reviewed") {
        If pValues.%GetTypeOf($List(tPair, 1)) = "string" Do pArgs.%Set($List(tPair, 2), pValues.%Get($List(tPair, 1)), "string")
    }
    Quit $$$OK
}

/// <p>The query the port's plan and promote read from the payload <var>pPayload</var>: the namespace it was read in, the
/// other namespace, the pattern, the generated choice, the plan hash a person reviewed and the plan hash the payload was
/// read at, each when it is a non-empty string, under the port's own keys, so the confirm's write and the screen's write
/// promote what the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    For tPair = $ListBuild("Namespace", ##class(OcuPilot.Port.DevToolPort).#NAMESPACEKEY), $ListBuild("Target", ##class(OcuPilot.Port.DevToolPort).#TARGETKEY), $ListBuild("Spec", ##class(OcuPilot.Port.DevToolPort).#SPECKEY), $ListBuild("Generated", ##class(OcuPilot.Port.DevToolPort).#GENERATEDKEY), $ListBuild("Reviewed", ##class(OcuPilot.Port.DevToolPort).#REVIEWEDKEY), $ListBuild("PlanHash", ##class(OcuPilot.Port.DevToolPort).#PLANHASHKEY) {
        If (pPayload.%GetTypeOf($List(tPair, 1)) = "string") && (pPayload.%Get($List(tPair, 1)) '= "") Set pQuery($List(tPair, 2)) = pPayload.%Get($List(tPair, 1))
    }
}

/// <p>The fresh read as the payload and nothing to merge: the card's row is <method>StateDiff</method>'s, and the arguments
/// are carried to the port by <method>PortQuery</method>.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Quit $$$OK
}

/// <p>What a reviewed action answers beside its rows: the plan hash the person's action carries back.</p>
ClassMethod DryRunReview(pFresh As %DynamicObject) As %DynamicObject
{
    Set tReview = {}
    Do tReview.%Set("Digest", $Select($IsObject(pFresh): pFresh.%Get("PlanHash"), 1: ""), "string")
    Quit tReview
}

/// <p>The one row this proposal's card and review show, from the fresh read <var>pFresh</var>: <code>Documents</code>,
/// whose after-value is each chosen step as <code>&lt;Document&gt; -- &lt;Change&gt;</code>, one to a line, then, when the
/// other namespace holds documents the plan leaves alone, the line that counts them
/// (<parameter>REVIEWWARNING</parameter>). A read that answers no steps is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Steps") '= "array") || (pFresh.%Get("Steps").%Size() = 0) {
            Set pProblem = "this instance did not report the documents to promote"
            Quit
        }
        Set tLines = ""
        Set tIterator = pFresh.%Get("Steps").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            Set tLines = tLines _ $Select(tLines = "": "", 1: $Char(10)) _ tStep.%Get("Document") _ " -- " _ tStep.%Get("Change")
        }
        Set tWarnings = +pFresh.%Get("Warnings")
        If tWarnings > 0 Set tLines = tLines _ $Char(10) _ $Select(tWarnings = 1: ..#REVIEWWARNINGONE, 1: $Replace(..#REVIEWWARNING, "<n>", tWarnings))
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", "", "string")
        Do tRow.%Set("after", tLines, "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The refusal of the agent's confirmed promote, asked again at the write with the stored arguments <var>pArgs</var>
/// (the namespace the mint read, the other namespace, the pattern and the generated choice), in <var>pProblem</var>, or
/// <code>""</code>: each step of the plan read now is held to <method>OcuPilot.Screen.Tool.ExplorerSave.AgentProblem</method>
/// for the other namespace, a create for a document only the first namespace holds (AD-6, AD-40). A plan that cannot be
/// read refuses.</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) {
        Set pProblem = "the proposal's stored arguments could not be read, so the agent does not promote it"
        Quit $$$OK
    }
    Kill tQuery
    Set tQuery(##class(OcuPilot.Port.DevToolPort).#DOCUMENTSKEY) = pIdValue
    Do ..PortQuery(pArgs, .tQuery)
    Set tReadSC = $ClassMethod(..#PORTCLASS, "Invoke", ..Endpoint(), ..#READTYPE, .tQuery, "", .tPlan, .tHttp, .tFault)
    If $$$ISERR(tReadSC) || '$IsObject($Get(tPlan)) {
        Set pProblem = "the plan could not be read, so the agent does not promote it"
        Quit $$$OK
    }
    Set pProblem = ..StepsProblem(pArgs.%Get("Target"), tPlan)
    Quit $$$OK
}

/// <p>What the agent's fence says of writing the steps of the plan <var>pPlan</var> into <var>pTarget</var>, or
/// <code>""</code>: the first refusal of <method>OcuPilot.Screen.Tool.ExplorerSave.AgentProblem</method>, a create for a
/// document only the first namespace holds.</p>
ClassMethod StepsProblem(pTarget As %String, pPlan As %DynamicObject) As %String
{
    Set tProblem = ""
    Set tIterator = pPlan.%Get("Steps").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        Set tProblem = ##class(OcuPilot.Screen.Tool.ExplorerSave).AgentProblem(pTarget, tStep.%Get("Document"), (tStep.%Get("Change") = ##class(OcuPilot.Port.DevToolPort).#CHANGEONLYHERE))
        If tProblem '= "" Quit
    }
    Quit tProblem
}

/// <p>What the screen and the proposal card show of the promote the port answered <var>pWritten</var> for: its
/// <code>{documents, lines, errors, stopped}</code>, or <code>""</code>. Never stored, logged or put on the ledger, and
/// never sent to the model (AD-39).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("documents") '= "array" Quit ""
    Quit pWritten
}

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload: nothing a promote writes is undone.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

}
