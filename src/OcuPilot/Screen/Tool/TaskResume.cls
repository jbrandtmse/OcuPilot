/// <p>The task schedule's resume tool (AD-6, AD-51, AD-53, FR-52): resume a suspended task. Two
/// callers reach it: the list's Resume row action through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. Both read
/// the task fresh through the vendor's own <code>Task.CRUD</code> <code>INFO</code> and refuse a
/// task that is not suspended; the agent's caller mints a proposal carrying one state row.</p>
/// <p><b>It is the first action-style write</b> (AD-51). The vendor exposes resume only as the
/// bodyless <code>RESUME</code> request type: <code>MergeJsonAndObj</code>'s settable list omits
/// <code>Suspended</code>, <code>TaskToJson</code> does not carry it, and
/// <code>NeedsRequestBody()</code> excludes <code>RESUME</code> -- so no <code>PUT</code> can
/// resume a task and there is no body to send. The tool therefore declares its own request types
/// and sends none, while the lock, the fingerprint, the prohibited set, the marker and the ledger
/// row stay exactly where they are.</p>
/// <p><b>Its diff comes from the read, not from a payload.</b> Nothing is sent, so the card's one
/// row is <method>StateDiff</method>'s, computed from the fresh <code>INFO</code> answer; the
/// row's label is the product's word for the state (<file>epics.md</file>, UJ-6), not the vendor's
/// <code>Status</code> field, which reports the last run's result and which no resume changes.
/// A task that is not suspended is refused at the fresh read, by either caller, so the vendor's
/// own "this returns ok even if it is not suspended" is never reached.</p>
/// <p><b>The target is the vendor's numeric task id</b>, which the schedule list's own rows carry
/// as <code>Id</code> and its route names. <class>OcuPilot.Kernel.EntityRef</class>'s
/// <code>integer</code> rule folds every spelling of one id to one key, which is what gives
/// AD-34's per-target lock and its sibling cancel one target to hold.</p>
Class OcuPilot.Screen.Tool.TaskResume Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "tasks.schedule.resume";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Parameter DESCRIPTION = "Propose resuming one task the Task Manager suspended after it failed. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the task by the numeric id the task schedule reports for it, not by its name. A task that is not suspended is refused.";

/// <p>The screen's own Resume row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "resume";

/// <p>The state read: <code>Task.CRUD</code>'s <code>INFO</code>, which is the only request type
/// that answers <code>Suspended</code> truthfully on this build. The endpoint's <code>LIST</code>
/// coerces it to false for every task and its <code>GET</code> does not carry it at all, so the
/// diff, the fingerprint and the not-suspended refusal all rest on this type (AD-36, AD-51).</p>
Parameter READTYPE = "INFO";

/// <p>The vendor's own resume request type. Measured on the instance 2026-09-21:
/// <code>Task.CRUD</code>'s <code>TYPERESUME</code> is 14, its <code>Run</code> dispatches it, its
/// <code>ValidateQueryParams</code> requires the <code>id</code> query parameter, and its
/// <code>ResourcesOR()</code> answers <code>%Admin_Task</code> alone for it.</p>
Parameter WRITETYPE = "RESUME";

/// <p>No body: <code>NeedsRequestBody()</code> excludes <code>TYPERESUME</code>, so the vendor
/// reads none and the port admits the type without one
/// (<parameter>OcuPilot.Port.AdminPort.BODYLESSTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The pair a resume requires: <code>%Admin_Task:USE</code>, which is the vendor's own
/// <code>ResourcesOR()</code> resource for this request type and exactly one of the two pairs
/// <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class> already declares -- so the resolved
/// set is the screen's own and no permission an IRIS-shipped role does not grant appears on the
/// path (AD-8 as amended 2026-09-21).</p>
Parameter WRITERESOURCE = "%Admin_Task";

Parameter WRITEPERMISSION = "USE";

/// <p>The <code>INFO</code> property the not-suspended refusal reads, which is by construction the
/// field this tool's own precondition reads (AD-51).</p>
Parameter PRECONDITIONFIELD = "Suspended";

/// <p>The subject the fingerprint covers: the one <code>INFO</code> field whose movement between
/// the mint and the confirm invalidates the reviewed intent. A task somebody else resumed in that
/// window is refused <code>PROPOSAL.TARGETCHANGED</code>, while the counters and timestamps
/// <code>INFO</code> also answers -- <code>Status</code>, <code>LastStarted</code>,
/// <code>NextScheduled</code> -- move whenever the task runs and are not the diff moving
/// (AD-51).</p>
/// <p><b>The identity is absent deliberately</b>: <code>Task.CRUD</code>'s <code>INFO</code>
/// answers no <code>Id</code>, and the proposal's <code>TargetRef</code> is what says which task
/// this is (AD-13, AD-51 as amended 2026-09-22).</p>
Parameter FINGERPRINTSUBJECT = "Suspended";

/// <p>The state row's label and its two values. The label is the product's word for the state,
/// which <file>epics.md</file> and UJ-6 both write as
/// <code>Status: Suspended -&gt; Scheduled</code>.</p>
Parameter STATEFIELD = "Status";

Parameter STATEBEFORE = "Suspended";

Parameter STATEAFTER = "Scheduled";

ClassMethod Endpoint() As %String
{
    Quit "Task.CRUD"
}

/// <p>The vendor's numeric task id, which is the property the schedule list's rows carry it
/// under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Id"
}

/// <p>The query parameter <code>Task.CRUD</code> identifies a task by, for both the
/// <code>INFO</code> read and the <code>RESUME</code> write.</p>
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
/// task, named by the numeric id the schedule reports, never by its name.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The task to resume, named by the numeric id this instance's own task schedule reports for it. A task the schedule does not report, and a task that is not suspended, are both refused.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs
/// (<method>OcuPilot.Screen.Gate.RequiredPairs</method>, which unions the declared set with the
/// classic page's custom resource) together with
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

/// <p>The one row this proposal's card shows, from the fresh <code>INFO</code> read
/// <var>pFresh</var>: <code>Status</code> moving from <code>Suspended</code> to
/// <code>Scheduled</code>. A task the read says is not suspended is <var>pProblem</var>, so the
/// mint refuses rather than proposing a change that would not happen.</p>
/// <p><b>An unreadable suspended state refuses too.</b> The rendering is
/// <method>OcuPilot.Kernel.Proposal.Mint.Display</method>'s, the one the diff and the fingerprint
/// read a value through, and only a value that reads as suspended passes -- so a read that
/// answered no such property, or a spelling this tool does not know, refuses the mint instead of
/// proposing a resume against a task whose state nobody established.</p>
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
        If '..ReadsSuspended(tRendered) {
            Set pProblem = "this instance reports that task as not suspended, and only a suspended task can be resumed"
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

/// <p>Whether the rendered value <var>pRendered</var> reads as suspended. <code>INFO</code>
/// answers a JSON boolean, so <code>true</code> is the reachable positive; the vendor's own
/// <code>%SYS.TaskSuper.Suspended</code> is an integer whose 1 and 2 both mean suspended, so both
/// spellings read as one too.</p>
/// <p><b>Every other rendering reads as not suspended</b>, which refuses the mint: a value this
/// method cannot read must not become a proposal to resume something.</p>
ClassMethod ReadsSuspended(pRendered As %String) As %Boolean [ Private ]
{
    If pRendered = "true" Quit 1
    If pRendered = "false" Quit 0
    If '$IsValidNum(pRendered) Quit 0
    Quit (+pRendered > 0)
}

}
