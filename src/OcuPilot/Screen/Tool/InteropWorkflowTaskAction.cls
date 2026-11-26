/// <p>What Interoperability's two workflow task writes share (AD-6, AD-51, AD-52, AD-53, AD-62, Story 24.17 Batch 4): a write of one workflow task of the request's namespace through
/// <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the Workflow tasks list's row actions Assign and Cancel task, and the agent's proposal and confirmation. The port runs
/// the vendor's own <code>EnsLib.Workflow.Engine</code> calls, as the classic Assign or Reassign Task dialog does. The target is the task's ID, a whole number sent as text, kept exactly (AD-13).</p>
/// <p><b>A task has no name</b>: the card and the typed confirmation name the task by its ID (<parameter>TARGETFIELD</parameter>).</p>
/// <p><b>Both writes fingerprint the state they reviewed</b> (<parameter>FINGERPRINTSUBJECT</parameter>): the task's status, assignee, priority and completion, so a task that moved after the review
/// closes the proposal as moved. Its privileges, read and refusals are <class>OcuPilot.Screen.Tool.InteropWorkflowAction</class>'s: <code>%Ens_WorkflowConfig:WRITE</code> and WRITE on the
/// namespace's globals database, each refused by name before any port call.</p>
Class OcuPilot.Screen.Tool.InteropWorkflowTaskAction Extends OcuPilot.Screen.Tool.InteropWorkflowAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropWorkflowTaskList";

/// <p>The fresh read: one workflow task, composed for the action.</p>
Parameter READTYPE = "WORKFLOWTASK";

/// <p>What <parameter>READTYPE</parameter> answers. <code>User</code> is the assignee under the name an assign's argument carries.</p>
Parameter READANSWERS = "TaskId,RoleName,IsComplete,Status,Priority,Source,AssignedTo,Subject,TimeCreated,TimeCompleted,Duration,Namespace,User";

/// <p>The classic dialog whose own resource an operator may have assigned beyond the screen's (AD-8, AD-44).</p>
Parameter CLASSICPAGES = "EnsPortal.Dialog.WorkflowTaskAssign";

/// <p>The task's ID, which the card titles it by.</p>
Parameter TARGETFIELD = "TaskId";

/// <p>The port method that judges the task's ID and an assign's fields.</p>
Parameter VIOLATIONSMETHOD = "WorkflowTaskViolations";

/// <p>The task's ID is always judged: it is the target and is never new.</p>
Parameter JUDGESNAME As BOOLEAN = 1;

/// <p>The read asks for the write at the mint and the confirm, so a complete task, and for a cancel a stopped production or a sender that is not waiting, is refused before anything is claimed.</p>
Parameter READASKSACTION As BOOLEAN = 1;

Parameter FINGERPRINTSUBJECT = "TaskId,Status,AssignedTo,Priority,IsComplete,Namespace";

/// <p>The field the precondition reads: a task that is complete takes neither write.</p>
Parameter PRECONDITIONFIELD = "IsComplete";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTWORKFLOWTASKS
}

/// <p>The target is the task, named by its ID.</p>
ClassMethod IdArgument() As %String
{
    Quit "TaskId"
}

/// <p>What the schema says of the task's ID.</p>
ClassMethod NameDescription() As %String
{
    Quit "The workflow task, by the Task ID the Workflow tasks list reports, a whole number sent as text. A task the list does not report is refused."
}

}
