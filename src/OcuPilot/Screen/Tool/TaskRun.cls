/// <p>The On-demand tasks list's run tool (AD-51, AD-53, FR-52): run one task now. Two callers
/// reach it: the list's Run row action through <class>OcuPilot.Api.ScreenAction</class>, and the
/// agent's proposal and confirmation. Both read the task fresh through <code>Task.CRUD</code>'s
/// <code>INFO</code> and issue the vendor's <code>RUN</code>.</p>
/// <p><b>It is an action-style write whose vendor type needs a fixed body.</b> <code>RUN</code>
/// requires <code>{"RunNow":true}</code>, which no caller supplies: the port sends it
/// (<parameter>OcuPilot.Port.AdminPort.CONSTANTBODIES</parameter>), so this tool sends no body and
/// the ledger records none.</p>
/// <p><b>Its diff comes from the read.</b> The vendor's <code>RunNow</code> sets
/// <code>NextScheduled</code> to the request time at once and clears <code>Suspended</code>
/// (measured on <code>ocupilot-ci</code>), so <method>StateDiff</method> answers a
/// <code>NextScheduled</code> row and, for a suspended task, a <code>Suspended</code> row. Both
/// names are the fingerprint's subject, so a confirm after either moved is refused.</p>
/// <p><b>The lock trap.</b> <code>%SYS.Task.RunNow</code> leaves an exclusive lock on the task for
/// as long as the caller holds that task's OREF, and the Task Manager skips a locked task. The
/// vendor's <code>RunRun</code> holds its OREF only as a local, and this path runs at
/// <code>$TLEVEL</code> 0 with no OcuPilot lock, so nothing here may open the task or wrap the
/// write in a transaction.</p>
/// <p><b>Story 7.6's schedule Run is a subclass</b> that overrides only
/// <parameter>TOOLNAME</parameter> and <parameter>DESCRIPTORCLASS</parameter>.</p>
Class OcuPilot.Screen.Tool.TaskRun Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "tasks.ondemand.run";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.TaskOnDemandList";

Parameter DESCRIPTION = "Propose running one task now, once, whatever its schedule. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the task by the numeric id the task list reports for it, not by its name. Running a suspended task also resumes it.";

/// <p>The screen's own Run row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "run";

/// <p>The state read: <code>Task.CRUD</code>'s <code>INFO</code>, which answers
/// <code>NextScheduled</code> and a truthful <code>Suspended</code> (AD-36, AD-51).</p>
Parameter READTYPE = "INFO";

/// <p>The vendor's own run request type: <code>TYPERUN</code> 12, whose <code>RunRun</code> calls
/// <code>%SYS.Task.RunNow(id)</code> (measured on this build).</p>
Parameter WRITETYPE = "RUN";

/// <p>No body from the tool: the vendor's constant body is the port's wire fact.</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p><code>%Admin_Task:USE</code>, the vendor's <code>ResourcesOR()</code> resource for
/// <code>RUN</code> and one of the two pairs the screen already declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Task";

Parameter WRITEPERMISSION = "USE";

/// <p>The <code>INFO</code> field the run's own precondition reads: whether the task is
/// suspended, which decides whether the run also resumes it.</p>
Parameter PRECONDITIONFIELD = "Suspended";

/// <p>The two <code>INFO</code> fields the diff is about. Either moving between the mint and the
/// confirm means somebody else ran or resumed the task (AD-51).</p>
Parameter FINGERPRINTSUBJECT = "NextScheduled,Suspended";

/// <p>What this tool's own <code>INFO</code> read answers of its subject. The screen's list does
/// not carry <code>Suspended</code>, because its LIST coerces it (AD-36).</p>
Parameter READANSWERS = "NextScheduled,Suspended";

/// <p>The state row's label: the field the run moves at once.</p>
Parameter STATEFIELD = "NextScheduled";

/// <p>The value the state row reads after the write.</p>
Parameter STATEAFTER = "now";

ClassMethod Endpoint() As %String
{
    Quit "Task.CRUD"
}

/// <p>The vendor's numeric task id, which the list's rows carry as <code>Id</code>.</p>
ClassMethod IdArgument() As %String
{
    Quit "Id"
}

/// <p>The query parameter <code>Task.CRUD</code> identifies a task by, for both the
/// <code>INFO</code> read and the <code>RUN</code> write.</p>
ClassMethod IdParam() As %String
{
    Quit "id"
}

/// <p>None: the tool sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The task to run, named by the numeric id this instance's own task list reports for it. A task the list does not report is refused.", "string")
    Quit tSchema
}

/// <p>The screen's own pairs together with
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

/// <p>The rows this proposal's card shows, from the fresh <code>INFO</code> read
/// <var>pFresh</var>: <code>NextScheduled</code> moving from the value read to
/// <code>now</code>, and, for a suspended task, <code>Suspended</code> moving from
/// <code>true</code> to <code>false</code>.</p>
/// <p>A read that does not answer <code>Suspended</code> as a boolean is <var>pProblem</var>: the
/// mint refuses rather than proposing a run whose effect on the task's state nobody
/// established.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tSuspended = ""
        Set tNext = ""
        If $IsObject(pFresh) {
            Set tSuspended = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#PRECONDITIONFIELD), pFresh.%GetTypeOf(..#PRECONDITIONFIELD))
            Set tNext = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#STATEFIELD), pFresh.%GetTypeOf(..#STATEFIELD))
        }
        If (tSuspended '= "true") && (tSuspended '= "false") {
            Set pProblem = "this instance did not report whether that task is suspended, so its run cannot be proposed"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", tNext, "string")
        Do tRow.%Set("after", ..#STATEAFTER, "string")
        Do pRows.%Push(tRow)
        If tSuspended = "true" {
            Set tRow = {}
            Do tRow.%Set("field", ..#PRECONDITIONFIELD, "string")
            Do tRow.%Set("before", "true", "string")
            Do tRow.%Set("after", "false", "string")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
