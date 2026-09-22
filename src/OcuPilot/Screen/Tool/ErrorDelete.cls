/// <p>The application error log's delete tool (AD-48, AD-51, AD-52, FR-63): propose clearing the
/// application errors one namespace holds. It enumerates, at proposal time, the specific
/// <code>(date, errorNumber)</code> pairs it will remove, and mints a proposal whose card lists
/// them. It writes nothing.</p>
/// <p><b>Its port is not the admin port</b> (AD-52). The administration API backs no application
/// error route at all, so this tool declares <class>OcuPilot.Port.LogSourcePort</class> and the
/// mint's fresh read, the confirm's re-read, the prohibited set's live read and the write itself
/// all resolve through it. Nothing else about the write path moves: the proposal, the
/// server-computed diff, the fingerprint, the single atomic transition, the caller's own privileges
/// through that port's own per-namespace gate and the agent marker are what they are for every
/// other write.</p>
/// <p><b>It is action-style</b> (AD-51): no settable field, no body, and a card whose rows come
/// from the fresh read. <b>Its fingerprint subject is the enumerated id set itself</b> -- the
/// namespace and the <code>entries</code> array -- so a confirm after another party removed one of
/// the listed errors is refused <code>PROPOSAL.TARGETCHANGED</code>, while an error logged after
/// the proposal leaves the subject alone and survives the confirm. That residue is correct, and the
/// card says so.</p>
/// <p><b>It is destructive</b>: a deleted application error cannot be proposed back.</p>
/// <p><b>The namespace has exactly one source</b>, the level the user drilled to, which the agent
/// sends as this tool's own argument. The route's <code>?ns=</code> (AD-44) reaches no layer of
/// this path.</p>
Class OcuPilot.Screen.Tool.ErrorDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "logs.applicationerrors.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LogErrorList";

Parameter DESCRIPTION = "Propose deleting the application errors one namespace holds. It changes nothing by itself: it answers a proposal listing every error it would remove, which the user reviews and confirms. Name the namespace exactly as this instance's own application error log reports it. A namespace the log does not report, and one that records no errors, are both refused. Errors logged after the proposal are not removed.";

/// <p>The port this tool's target lives behind (AD-48, AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.LogSourcePort";

/// <p>The fresh read: the port's enumeration of every <code>(date, errorNumber)</code> the drilled
/// namespace holds. It is reached only through the write path and never over HTTP -- the four
/// drill routes are unchanged (AD-36, AD-48).</p>
Parameter READTYPE = "ENUMERATE";

/// <p>The write: remove the ids the proposal enumerated, and nothing else.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body. Nothing is sent, so nothing is disclosed as unchanged and the ledger names no
/// field (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The AD-14 action this write performs: its targets are removed, so a screen showing them
/// drops the rows that left rather than re-reading a row that moved. It is the first shipped
/// producer of this action.</p>
Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted application error is gone, and no proposal puts it back. The card draws
/// the destructive treatment and its Confirm is <code>button-destructive</code>.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The names <parameter>READTYPE</parameter> answers, for the registration guard over
/// <parameter>FINGERPRINTSUBJECT</parameter>. This screen declares no <code>read</code> -- three
/// drill levels are three column sets -- so its declaration knows no name a subject could carry,
/// and the tool's own read is what the guard validates against (DW-1475).</p>
Parameter READANSWERS = "namespace,entries,count,truncated";

/// <p>The read field this tool's precondition reads: a namespace whose enumeration is empty, or was
/// cut by the row cap, is refused at the mint.</p>
Parameter PRECONDITIONFIELD = "entries";

/// <p>The subject the fingerprint covers: the scoped target identity and the enumerated id set
/// (AD-48's "the fingerprint is the enumerated id set, never a count and never a live re-query").
/// <code>count</code> and <code>truncated</code> are outside it deliberately -- both are functions
/// of <code>entries</code>, and a subject naming a count is the livelock AD-48 refuses.</p>
Parameter FINGERPRINTSUBJECT = "namespace,entries";

/// <p>The port endpoint this tool reads and writes through
/// (<parameter>OcuPilot.Port.LogSourcePort.ENDPOINTERRORS</parameter>).</p>
ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.LogSourcePort).#ENDPOINTERRORS
}

/// <p>The namespace the user drilled to, which is the only source this write's namespace has.</p>
ClassMethod IdArgument() As %String
{
    Quit ##class(OcuPilot.Port.LogSourcePort).#NAMESPACEPARAM
}

/// <p>The query parameter the port identifies the target namespace by, for both the enumeration
/// and the delete.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.LogSourcePort).#NAMESPACEPARAM
}

/// <p>None: the write sends no body, so <method>OcuPilot.Screen.Tool.Write.FieldRows</method>
/// answers no rows and the merge may set nothing (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced: the target is one
/// namespace, named as the instance's own application error log reports it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The namespace whose application errors to delete, exactly as this instance's own application error log reports it. It is the namespace the user has drilled to. A namespace the log does not report, and one that records no errors, are both refused.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: this screen's own two pairs, together with the pairs
/// <method>OcuPilot.Port.LogSourcePort.PairsFor</method> answers for the target namespace --
/// <code>%DB_&lt;ns&gt;:READ</code> and <code>%DB_&lt;ns&gt;:WRITE</code> on the resource guarding
/// that namespace's globals database, resolved at call time (AD-8, AD-29, AD-48). It is
/// <method>OcuPilot.Screen.Tool.ErrorRead.PrivilegePairs</method>'s shape: this method answers the
/// screen's own two pairs and <method>ArgumentPairs</method> the per-namespace half, which both the
/// dispatcher and the confirm check.</p>
/// <p>A namespace whose requirement the instance cannot resolve adds no pair and is not admitted by
/// that: the port refuses it by its own enumeration and gate before anything is read or removed.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit tPairs
}

/// <p>What a call naming <var>pArgs</var>'s namespace requires beyond
/// <method>PrivilegePairs</method>: the per-namespace pairs the port resolves for it, so the
/// dispatcher checks them against the caller's current grants before the mint runs (AD-8, AD-31)
/// and the confirm re-checks them, against the stored arguments, before any live read.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    If '$IsObject(pArgs) Quit ""
    Quit ##class(OcuPilot.Port.LogSourcePort).PairsFor(##class(OcuPilot.Port.LogSourcePort).#ERRORSKEY, pArgs.%Get(..IdArgument()))
}

/// <p>The removal rows this proposal's card shows, from the fresh enumeration <var>pFresh</var>:
/// one per enumerated error, carrying its identifying pair -- the date as the field and the error
/// number as the value -- with no after-state.</p>
/// <p>A namespace the enumeration found no errors in is <var>pProblem</var>, so the mint refuses
/// rather than proposing a delete that would remove nothing. <b>A truncated enumeration is
/// <var>pProblem</var> too</b>: a cut set cannot support "the confirm removes exactly these", and a
/// silent partial delete is what AD-48's enumerated-id-set rule exists to prevent.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) {
            Set pProblem = "this instance did not report that namespace's application errors"
            Quit
        }
        If ''pFresh.%Get("truncated") {
            Set pProblem = "this namespace holds more application errors than one proposal can list, so no proposal can promise to remove exactly the ones shown"
            Quit
        }
        If pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "array" {
            Set pProblem = "this instance did not report that namespace's application errors"
            Quit
        }
        Set tEntries = pFresh.%Get(..#PRECONDITIONFIELD)
        If tEntries.%Size() = 0 {
            Set pProblem = "this instance records no application errors for that namespace"
            Quit
        }
        Set tIterator = tEntries.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If '$IsObject(tEntry) Continue
            Set tRow = {}
            Do tRow.%Set("field", tEntry.%Get("date"), "string")
            Do tRow.%Set("before", tEntry.%Get("errorNumber"), "string")
            Do tRow.%Set("after", "", "string")
            Do tRow.%Set("removed", 1, "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The enumerated id set, as the compact JSON of the stored payload's own
/// <parameter>PRECONDITIONFIELD</parameter> array, under the port's
/// <parameter>OcuPilot.Port.LogSourcePort.ENTRIESPARAM</parameter> (AD-52).</p>
/// <p><b>It is what makes the confirm remove exactly those ids</b>, and what makes the fingerprint
/// re-read a question about exactly those ids. The stored payload is the projection the digest was
/// taken over, so the enumeration the re-read gets back is that set narrowed to what still exists:
/// an id another party removed shortens it and refuses the confirm, while an error logged after
/// the proposal is in no stored set and leaves it alone. That is AD-48's residue clause and its
/// moved-target clause from one declaration.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#PRECONDITIONFIELD) '= "array" Quit
    Set pQuery(##class(OcuPilot.Port.LogSourcePort).#ENTRIESPARAM) = pPayload.%Get(..#PRECONDITIONFIELD).%ToJSON()
}

}
