/// <p>What System Explorer's compile and delete share (AD-6, AD-13, AD-51, AD-52, AD-53, Story
/// 19.2): a write over a <b>set of documents</b> of one list, reached by two callers -- the list's
/// own action over its checked rows, through <class>OcuPilot.Api.ScreenAction</class>, and the
/// agent's proposal and confirmation.</p>
/// <p><b>The target is the set</b>: <parameter>IDARGUMENT</parameter>'s names, comma-joined into one
/// <code>class</code> or <code>routine</code> id whose canonical spelling is unique and sorted
/// (AD-13's <code>documentset</code> rule), at most
/// <parameter>OcuPilot.Port.AtelierPort.MAXDOCUMENTS</parameter> of them
/// (<method>SetProblem</method>).</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body, and
/// <class>OcuPilot.Port.AtelierPort</class> composes the vendor's call from the set and the declared
/// values the port query carries (<method>PortQuery</method>). The fresh read is the port's
/// <code>DOCS</code>, which answers the namespace it read; that namespace is in every subject and
/// travels in the port query, so a confirm writes where the proposal read.</p>
/// <p><b>It declares WRITE on the namespace's routines database</b> beyond the list's
/// <code>%Development:USE</code> (AD-8 as amended 2026-10-02, measured), resolved for the request's
/// scope at each gate call; the port checks the same pair for the namespace it writes, before any
/// vendor call. A document whose name begins with <code>OcuPilot</code> is refused by the kernel
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTCODE</parameter>) on both callers.</p>
/// <p>A write's console lines and per-document results reach the screen and the proposal card only,
/// through <method>WriteOutput</method> (AD-39's fifth exception).</p>
Class OcuPilot.Screen.Tool.ExplorerWrite Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

/// <p>The port that reads the set and composes the vendor's call (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.AtelierPort";

/// <p>The fresh read: which documents of the set the namespace holds.</p>
Parameter READTYPE = "DOCS";

/// <p>No body: the port composes the call.</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Present,Modified,Absent,Namespace,KeepSource,CompileDependents,SkipUpToDate";

/// <p>The card's state row's label.</p>
Parameter STATEFIELD = "Documents";

/// <p>The argument naming the set.</p>
Parameter IDARGUMENT = "Names";

/// <p>The read field naming the namespace the set was read in.</p>
Parameter NAMESPACEFIELD = "Namespace";

/// <p>The permission a write requires on the resource guarding its namespace's routines
/// database.</p>
Parameter WRITEPERMISSION = "WRITE";

/// <p>The comma-joined names of the set.</p>
ClassMethod IdArgument() As %String
{
    Quit ..#IDARGUMENT
}

/// <p>The query key the port reads the set from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#NAMESKEY
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the set is checked
/// and found present (<class>OcuPilot.Screen.Tool.ExplorerMint</class>).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.ExplorerMint"
}

/// <p>What is wrong with <var>pValue</var> as the set a write names, or <code>""</code>: a string of
/// 1 to <parameter>OcuPilot.Port.AtelierPort.MAXDOCUMENTS</parameter> names of this list's kind,
/// separated by commas, as <method>OcuPilot.Port.AtelierPort.SetNames</method> reads it.</p>
ClassMethod SetProblem(pValue As %String) As %String
{
    If '$IsObject(pValue) && ($ListLength(##class(OcuPilot.Port.AtelierPort).SetNames(..Endpoint(), pValue)) > 0) Quit ""
    Quit "'" _ ..#IDARGUMENT _ "' names 1 to " _ ##class(OcuPilot.Port.AtelierPort).#MAXDOCUMENTS _ " documents of this list, as this instance's list reports them, separated by commas"
}

/// <p>The set refused by <method>SetProblem</method> after the fresh read, as it is before the mint
/// (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..SetProblem(pIdValue)
    Quit $$$OK
}

/// <p>The derived schema with the set described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The documents, named exactly as this instance's own list reports them and separated by commas, at most " _ ##class(OcuPilot.Port.AtelierPort).#MAXDOCUMENTS _ ". A document the list does not report is refused, and so is one whose name begins with OcuPilot.", "string")
    }
    Quit tSchema
}

/// <p>The screen's own pairs, then WRITE on the routines database of the namespace the request is
/// scoped to (<method>OcuPilot.Kernel.Scope.Current</method>), then the custom resource of each
/// <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44). <var>pResolved</var> is 0
/// when the namespace's routines database names no resource.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(##class(OcuPilot.Kernel.Scope).Current(), .tRoutine, .tGlobal, .tMapped, .tResolved)
    If tRoutine = "" {
        Set pResolved = 0
        Quit ""
    }
    Set tOwn = $ListBuild(tRoutine, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The namespace the stored payload <var>pPayload</var> was read in, under the port's own query
/// key, so the confirm's re-read and write, the screen's write and every read-back reach the
/// namespace the proposal read (AD-52). A fresh read, whose payload is empty, is scoped by the
/// port.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.AtelierPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

/// <p>The names the fresh read <var>pFresh</var> holds under <var>pField</var>, joined by
/// <code>", "</code> for a card row.</p>
ClassMethod NamesShown(pFresh As %DynamicObject, pField As %String) As %String
{
    If '$IsObject(pFresh) Quit ""
    Quit $Replace(pFresh.%Get(pField), ",", ", ")
}

/// <p>What the screen and the proposal card show of the write the port answered <var>pWritten</var>
/// for: its <code>output</code> -- a compile's <code>{lines, errors}</code> and a delete's
/// <code>{documents}</code> -- or <code>""</code>. Never stored, logged or put on the ledger, and
/// never sent to the model (AD-39).</p>
ClassMethod WriteOutput(pWritten) As %DynamicObject
{
    If '$IsObject($Get(pWritten)) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    Quit pWritten
}

}
