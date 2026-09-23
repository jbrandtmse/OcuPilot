/// <p>The Task schedule's suspend tool (AD-51, AD-53, FR-52): <class>OcuPilot.Screen.Tool.TaskResume</class>
/// in the other direction. Two callers reach it: the list's Suspend row action through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. Both read
/// the task fresh through <code>Task.CRUD</code>'s <code>INFO</code> and issue the vendor's
/// <code>SUSPEND</code>.</p>
/// <p><b>Its body is the port's.</b> <code>SUSPEND</code> reads a body the tool does not supply;
/// the port sends the vendor's own default, <code>{"LeaveInQueue":true}</code>
/// (<parameter>OcuPilot.Port.AdminPort.CONSTANTBODIES</parameter>), so the tool sends none and
/// the ledger records none (AD-51).</p>
/// <p><b>A no-op is refused at the read.</b> The vendor answers 200 for a suspend of a task that is
/// already suspended and logs a history row for it; <method>StateDiff</method> refuses that task,
/// and one whose state the read did not establish, so nothing is sent.</p>
/// <p><b>Every check reads <code>INFO</code></b>: <code>Task.CRUD</code>'s <code>LIST</code>
/// reports <code>Suspended</code> false for every task, and after a suspend it stays false while
/// <code>INFO</code> answers true (AD-36).</p>
Class OcuPilot.Screen.Tool.TaskSuspend Extends OcuPilot.Screen.Tool.TaskResume
{

Parameter TOOLNAME = "tasks.schedule.suspend";

Parameter DESCRIPTION = "Propose suspending one task so the Task Manager stops running it until it is resumed. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the task by the numeric id the task schedule reports for it, not by its name. A task that is already suspended is refused.";

/// <p>The screen's own Suspend row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "suspend";

/// <p>The vendor's own suspend request type, <code>TYPESUSPEND</code> 15, keyed by the
/// <code>id</code> query parameter; <code>ResourcesOR()</code> answers <code>%Admin_Task</code>
/// for it (measured on this build).</p>
Parameter WRITETYPE = "SUSPEND";

Parameter STATEBEFORE = "Scheduled";

Parameter STATEAFTER = "Suspended";

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The task to suspend, named by the numeric id this instance's own task schedule reports for it. A task the schedule does not report, and a task that is already suspended, are both refused.", "string")
    Quit tSchema
}

/// <p>The one row this proposal's card shows, from the fresh <code>INFO</code> read
/// <var>pFresh</var>: <code>Status</code> moving from <code>Scheduled</code> to
/// <code>Suspended</code>.</p>
/// <p>A task the read says is suspended is <var>pProblem</var>, and so is one whose
/// <code>Suspended</code> the read did not answer in a spelling this tool reads: only a value that
/// reads as not suspended passes, so no suspend is proposed against a task whose state nobody
/// established.</p>
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
        If ..ReadsSuspended(tRendered) {
            Set pProblem = "this instance reports that task as already suspended, and only a task that is not suspended can be suspended"
            Quit
        }
        If '..ReadsNotSuspended(tRendered) {
            Set pProblem = "this instance did not report whether that task is suspended, so its suspend cannot be proposed"
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

/// <p>Whether the rendered value <var>pRendered</var> reads as not suspended: <code>false</code>,
/// the JSON boolean <code>INFO</code> answers, or the vendor's integer <code>0</code>. Every other
/// rendering, an absent value among them, does not.</p>
ClassMethod ReadsNotSuspended(pRendered As %String) As %Boolean [ Private ]
{
    If pRendered = "false" Quit 1
    If '$IsValidNum(pRendered) Quit 0
    Quit (+pRendered = 0)
}

}
