/// <p>The processes list's suspend tool (AD-6, AD-51, AD-10): propose suspending one running
/// process. It reads the process fresh through the vendor's own <code>Process</code>
/// <code>GET</code>, refuses a process the instance already reports suspended, and mints a
/// proposal carrying one state row. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51). The vendor exposes suspend only as the bodyless
/// <code>SUSPEND</code> request type -- <code>NeedsRequestBody()</code> is
/// <code>IsTypePatch() || (Type = TYPEBROADCAST)</code>, so no body is read -- and the endpoint
/// publishes no body template at all, so the tool admits no settable field and its field list is
/// empty by derivation rather than by hand (AD-3).</p>
/// <p><b>Its fingerprint covers a declared subject</b>, <code>Pid</code> and <code>State</code>: a
/// running process moves nine of its fifty read keys within seconds, so a digest over the whole
/// read would refuse every confirm against exactly the processes this tool exists to act on. The
/// subject is the scoped target identity plus the field this tool's own precondition reads.</p>
/// <p><b>It is not destructive</b>: proposing the opposite puts the process back, which is what
/// <class>OcuPilot.Screen.Tool.ProcessResume</class> is for. EXPERIENCE.md's
/// <code>confirm-dialog</code> row names a suspend among the non-destructive warnings and reserves
/// the destructive treatment for a terminate, which OcuPilot ships no tool for.</p>
Class OcuPilot.Screen.Tool.ProcessSuspend Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.processes.suspend";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ProcessList";

Parameter DESCRIPTION = "Propose suspending one process this instance is running. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the process by the numeric process id the processes list reports for it. A process that is already suspended, a process OcuPilot is itself running in -- this request, or an agent turn -- and an IRIS system process are all refused.";

/// <p>The state read: <code>Process</code>'s <code>GET</code>, the endpoint's one single-object
/// read. Its <code>LIST</code> answers an array and there is no <code>TYPEINFO</code> on the
/// class, so this is the only type the diff, the fingerprint and the state refusal can rest on
/// (AD-36, AD-51).</p>
Parameter READTYPE = "GET";

/// <p>The vendor's own suspend request type. Measured on the instance 2026-09-21:
/// <code>Process</code>'s <code>TYPESUSPEND</code> is 12, its <code>Run</code> dispatches it, its
/// <code>ValidateQueryParams</code> requires the <code>id</code> query parameter, and its
/// <code>ResourcesOR()</code> answers <code>%Admin_Operate</code> for every type.</p>
Parameter WRITETYPE = "SUSPEND";

/// <p>No body: the vendor's <code>NeedsRequestBody()</code> admits only a patch and a broadcast,
/// so <code>SUSPEND</code> reads none and the port admits the type without one
/// (<parameter>OcuPilot.Port.AdminPort.BODYLESSTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>Declared rather than inherited because a reader expects the opposite: suspending a running
/// process stops work, but the user undoes it by proposing the resume, so the card draws the
/// ordinary Confirm treatment (EXPERIENCE.md's <code>confirm-dialog</code> row).</p>
Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>The pair a suspend requires: <code>%Admin_Operate:USE</code>, the vendor's own
/// <code>ResourcesOR()</code> resource and one of the three
/// <class>OcuPilot.Screen.Descriptor.ProcessList</class> already declares -- so the resolved set
/// is the screen's own (AD-8 as amended 2026-09-21).</p>
Parameter WRITERESOURCE = "%Admin_Operate";

Parameter WRITEPERMISSION = "USE";

/// <p>The <code>GET</code> property this tool's precondition reads. It is a JSON string, not a
/// boolean: <code>%SYS.ProcessQuery.State</code> spells a suspended process <code>SUSP</code> and
/// a suspension requested <code>S</code>. <code>CanBeSuspended</code> is not the discriminator --
/// its retrieval code ends <code>i State'["SUSP"</code>, so it conflates "already suspended" with
/// "cannot be suspended".</p>
Parameter PRECONDITIONFIELD = "State";

/// <p>The subject the fingerprint covers: the scoped target identity and the precondition
/// field.</p>
Parameter FINGERPRINTSUBJECT = "Pid,State";

/// <p>The substring a suspended process's <code>State</code> carries.
/// <code>%SYS.ProcessQuery.State</code> also spells a suspension merely <i>requested</i>
/// <code>S</code>, which does not carry it and so does not read as suspended here; the vendor's
/// own <code>CanBeSuspended</code> guard answers that case with its 409.</p>
Parameter SUSPENDEDMARK = "SUSP";

/// <p>The state row's label and its two values, the product's words for the state the action
/// moves.</p>
Parameter STATEFIELD = "State";

Parameter STATEBEFORE = "Running";

Parameter STATEAFTER = "Suspended";

ClassMethod Endpoint() As %String
{
    Quit "Process"
}

/// <p>The numeric process id, which is the property the processes list's rows carry it under and
/// the one its route names.</p>
ClassMethod IdArgument() As %String
{
    Quit "Pid"
}

/// <p>The query parameter <code>Process</code> identifies a process by, for both the
/// <code>GET</code> read and the <code>SUSPEND</code> write.</p>
ClassMethod IdParam() As %String
{
    Quit "id"
}

/// <p>None: the write sends no body, so <method>OcuPilot.Screen.Tool.Write.FieldRows</method>
/// answers no rows and the merge may set nothing (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced: the target is one
/// process, named by the numeric process id the list reports.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The process to suspend, named by the numeric process id this instance's own processes list reports for it. A process the list does not report, and a process that is already suspended, are both refused.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs
/// (<method>OcuPilot.Screen.Gate.RequiredPairs</method>) together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, appended only when
/// the screen does not already declare it so the ledger row's pair column records one check
/// once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The one row this proposal's card shows, from the fresh <code>GET</code> read
/// <var>pFresh</var>: <code>State</code> moving from <code>Running</code> to
/// <code>Suspended</code>. A process the read already reports suspended is <var>pProblem</var>, so
/// the mint refuses rather than proposing a change that would not happen.</p>
/// <p><b>An unreadable state refuses too.</b> The rendering is
/// <method>OcuPilot.Kernel.Proposal.Mint.Display</method>'s, the one the diff and the fingerprint
/// read a value through; a read that answered no <code>State</code> at all refuses, because a
/// process whose state nobody established is not one to propose stopping.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tRendered = ""
        If $IsObject(pFresh) {
            Set tRendered = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#PRECONDITIONFIELD), pFresh.%GetTypeOf(..#PRECONDITIONFIELD))
        }
        If tRendered = "" {
            Set pProblem = "this instance did not report that process's state, and a process whose state is unknown is not one to suspend"
            Quit
        }
        If tRendered [ ..#SUSPENDEDMARK {
            Set pProblem = "this instance reports that process as already suspended"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", ..#STATEBEFORE, "string")
        Do tRow.%Set("after", ..#STATEAFTER, "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
