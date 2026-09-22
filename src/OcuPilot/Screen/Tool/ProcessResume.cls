/// <p>The processes list's resume tool (AD-6, AD-51, AD-10): propose resuming one suspended
/// process. It reads the process fresh through the vendor's own <code>Process</code>
/// <code>GET</code>, refuses a process the instance does not report suspended, and mints a
/// proposal carrying one state row. It writes nothing.</p>
/// <p><b>The not-suspended refusal is OcuPilot's alone.</b> Measured on the instance 2026-09-21:
/// the vendor's <code>RunResume</code> carries no guard of its own -- it opens the process and
/// calls <code>Resume()</code> -- where <code>RunSuspend</code> answers
/// <code>HTTP409CONFLICT</code> on <code>'CanBeSuspended</code>. So the mint is the only place a
/// resume of a running process is refused.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor exposes resume only as the bodyless
/// <code>RESUME</code> request type, and the endpoint publishes no body template, so the tool
/// admits no settable field and its field list is empty by derivation (AD-3). Its fingerprint
/// covers the declared subject <code>Pid</code> and <code>State</code> -- the scoped target
/// identity plus the field its own precondition reads.</p>
Class OcuPilot.Screen.Tool.ProcessResume Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.processes.resume";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ProcessList";

Parameter DESCRIPTION = "Propose resuming one process this instance has suspended. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the process by the numeric process id the processes list reports for it. A process that is not suspended, a process OcuPilot is itself running in -- this request, or an agent turn -- and an IRIS system process are all refused.";

/// <p>The state read: <code>Process</code>'s <code>GET</code>, the endpoint's one single-object
/// read (AD-36, AD-51).</p>
Parameter READTYPE = "GET";

/// <p>The vendor's own resume request type. Measured on the instance 2026-09-21:
/// <code>Process</code>'s <code>TYPERESUME</code> is 11, its <code>Run</code> dispatches it, and
/// its <code>ValidateQueryParams</code> requires the <code>id</code> query parameter.</p>
Parameter WRITETYPE = "RESUME";

/// <p>No body: the vendor's <code>NeedsRequestBody()</code> admits only a patch and a broadcast,
/// so <code>RESUME</code> reads none and the port admits the type without one
/// (<parameter>OcuPilot.Port.AdminPort.BODYLESSTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The pair a resume requires: <code>%Admin_Operate:USE</code>, the vendor's own
/// <code>ResourcesOR()</code> resource and one of the three
/// <class>OcuPilot.Screen.Descriptor.ProcessList</class> already declares (AD-8 as amended
/// 2026-09-21).</p>
Parameter WRITERESOURCE = "%Admin_Operate";

Parameter WRITEPERMISSION = "USE";

/// <p>The <code>GET</code> property this tool's precondition reads, a JSON string:
/// <code>%SYS.ProcessQuery.State</code> spells a suspended process <code>SUSP</code>.</p>
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

Parameter STATEBEFORE = "Suspended";

Parameter STATEAFTER = "Running";

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
/// <code>GET</code> read and the <code>RESUME</code> write.</p>
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
    Do tProperties.%Get(..IdArgument()).%Set("description", "The process to resume, named by the numeric process id this instance's own processes list reports for it. A process the list does not report, and a process that is not suspended, are both refused.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs
/// (<method>OcuPilot.Screen.Gate.RequiredPairs</method>) together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, appended only when
/// the screen does not already declare it.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The one row this proposal's card shows, from the fresh <code>GET</code> read
/// <var>pFresh</var>: <code>State</code> moving from <code>Suspended</code> to
/// <code>Running</code>. A process the read does not report suspended is <var>pProblem</var>, and
/// so is a read that answered no state at all -- a value this method cannot read as suspended
/// must not become a proposal to resume something.</p>
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
        If '(tRendered [ ..#SUSPENDEDMARK) {
            Set pProblem = "this instance reports that process as not suspended, and only a suspended process can be resumed"
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
