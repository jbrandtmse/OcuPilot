/// <p>Interoperability's workflow task assign (AD-6, AD-10, AD-22, AD-51, AD-53, AD-56, AD-58, AD-59, AD-62, Story 24.17 Batch 4): assign one open workflow task of the request's namespace to an
/// active workflow user, to Unassigned, or change only its priority, as the classic Assign or Reassign Task dialog does. Two callers reach it: the Workflow tasks screen's row action Assign, after the
/// dry run a person reviews, and the agent's proposal and confirmation.</p>
/// <p><b>It is not destructive and its key ships on</b> (AD-22): an assignment can be changed back. Assigning to a user takes the task off every other user's worklist
/// (<code>INTEROP.WORKFLOW.TASKASSIGN</code>); Unassigned sends it to every active member of its workflow role (<code>INTEROP.WORKFLOW.TASKUNASSIGN</code>). The vendor records nothing, so OcuPilot
/// records its own <code>ConfigChange</code> from either caller (<method>OcuPilot.Port.InteropPort.PerformWorkflowTask</method>), never a subject.</p>
/// <p><b>Its values travel in the port's query</b> (<method>PortQuery</method>), each optional: an absent one means unchanged. The fresh read answers the assignee under <code>User</code> and the
/// priority under <code>Priority</code>, so a merge that sets one to what the task holds leaves it unchanged. An empty <code>User</code> is the request to unassign. The port judges each value again
/// at the write, in the proposal's namespace.</p>
Class OcuPilot.Screen.Tool.InteropWorkflowTaskAssign Extends OcuPilot.Screen.Tool.InteropWorkflowTaskAction
{

Parameter TOOLNAME = "interop.workflowtasks.assign";

Parameter DESCRIPTION = "Propose assigning one open workflow task of the namespace the user is working in to a workflow user, to Unassigned, or changing only its priority. Name the task by the Task ID interop.workflowtasks.read reports. User is the name of an active workflow user of this namespace, spelled exactly as the Workflow users list reports it, or empty for Unassigned; leave it out to keep the task's assignment. Priority is a whole number from 1 to 5; leave it out to keep it. Assigning to a user takes the task off every other user's worklist, and unassigning it sends it to every active member of its workflow role. A task that is already complete, a user who is not an active workflow user, and an assignment that would change nothing are refused. It changes nothing by itself: it answers a proposal the user reviews and confirms, and the task can be assigned again.";

Parameter SCREENACTIONS = "assign";

/// <p>The dialog sends the user and the priority it changes. Both are optional on the route: the dry run that opens the dialog carries none, and the write judges that something changes.</p>
Parameter SCREENVALUES = "assign=User:Priority";

Parameter SCREENOPTIONAL = "assign=User:Priority";

/// <p>An empty user is the request: the task is unassigned.</p>
Parameter SCREENEMPTY = "assign=User";

Parameter WRITETYPE = "ASSIGNWORKFLOWTASK";

Parameter DESTRUCTIVE As BOOLEAN = 0;

Parameter CONSEQUENCECODE = "INTEROP.WORKFLOW.TASKASSIGN";

Parameter CONSEQUENCEUNASSIGNCODE = "INTEROP.WORKFLOW.TASKUNASSIGN";

Parameter PRECONDITIONCODES = "INTEROP.WORKFLOW.TASKCOMPLETE,INTEROP.WORKFLOW.TASKUNCHANGED,INTEROP.NAMESPACE";

/// <p>The state the review fixes, and the user: the assign's merge row for <code>User</code> is then part of the fingerprint's subject rather than a changed field the prohibited set has no
/// permission for.</p>
Parameter FINGERPRINTSUBJECT = "TaskId,Status,AssignedTo,Priority,IsComplete,Namespace,User";

/// <p>The read-back compares what the assign set with what the task holds afterward: the assignee and the priority.</p>
Parameter READBACKFIELDS = "User,Priority";

Parameter READBACKPAYLOAD As BOOLEAN = 1;

/// <p>The person's Assign is reviewed first (<method>DryRunReview</method>): the dialog shows the task's assignee and priority.</p>
Parameter DRYRUN As BOOLEAN = 1;

/// <p>The read at the read-back and the confirm asks no action: it must read the state the write left, which an assign that has changed everything would otherwise refuse as unchanged. The
/// write judges its values itself.</p>
Parameter READASKSACTION As BOOLEAN = 0;

/// <p>The review: the task's role, assignee and priority from the fresh read <var>pFresh</var>.</p>
ClassMethod DryRunReview(pFresh As %DynamicObject) As %DynamicObject
{
    Set tReview = {}
    If '$IsObject(pFresh) Quit tReview
    Do tReview.%Set("RoleName", pFresh.%Get("RoleName"), "string")
    Do tReview.%Set("AssignedTo", pFresh.%Get("AssignedTo"), "string")
    Do tReview.%Set("Priority", +pFresh.%Get("Priority"), "number")
    Quit tReview
}

/// <p>The user and the priority an assign may carry.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild("User", "Priority")
}

/// <p>Compose the port's read as <class>OcuPilot.Screen.Tool.InteropWorkflowAction</class> does, then name each value the payload or the arguments carry under the port's own query keys, so the
/// read, the write and the draft judge and use one set of values. A value that is left out is left out of the query, which the port reads as unchanged.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    Set tPort = "OcuPilot.Port.InteropPort"
    If pPayload.%GetTypeOf("User") = "string" Set pQuery($Parameter(tPort, "WORKFLOWTASKUSERKEY")) = pPayload.%Get("User")
    Set tType = pPayload.%GetTypeOf("Priority")
    If (tType = "number") || ((tType = "string") && (pPayload.%Get("Priority") '= "")) Set pQuery($Parameter(tPort, "WORKFLOWTASKPRIORITYKEY")) = pPayload.%Get("Priority")
}

/// <p>The derived schema with the task described as the Task ID and the two values added.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set("User", {"type": "string", "maxLength": 128, "description": "The active workflow user to assign the task to, spelled exactly as the Workflow users list reports it, or empty for Unassigned. Leave it out to keep the task's assignment."})
    Do tProperties.%Set("Priority", {"type": "integer", "minimum": 1, "maximum": 5, "description": "The task's priority, a whole number from 1 to 5. Leave it out to keep it."})
    Quit tSchema
}

/// <p>No state row: the merge's rows, one for each value changed, are the card's.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p><parameter>CONSEQUENCEUNASSIGNCODE</parameter> when the payload's user is empty (the task is sent to every active member of its role), else <parameter>CONSEQUENCECODE</parameter> (the task is taken
/// off every other user's worklist).</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If $IsObject(pPayload) && (pPayload.%GetTypeOf("User") = "string") && (pPayload.%Get("User") = "") Quit ..#CONSEQUENCEUNASSIGNCODE
    Quit ..#CONSEQUENCECODE
}

/// <p>The screen's values as this tool's arguments (AD-56 (ii)): the user as sent (empty for Unassigned) and the priority as a number, each only when the person sent it. A value that fails the
/// port's shape rule is <var>pProblem</var>, the sentence of its code, so the screen refuses it as the mint does. The dry run that opens the dialog carries none.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    Set tPort = "OcuPilot.Port.InteropPort"
    If pValues.%GetTypeOf("User") = "string" {
        If '$ClassMethod(tPort, "WorkflowTaskUserShapeOK", pValues.%Get("User")) {
            Set pProblem = $ClassMethod(tPort, "WorkflowTaskProblem", "user")
            Quit $$$OK
        }
        Do pArgs.%Set("User", pValues.%Get("User"), "string")
    }
    If pValues.%GetTypeOf("Priority") = "string" {
        If '$ClassMethod(tPort, "WorkflowTaskPriorityOK", pValues.%Get("Priority")) {
            Set pProblem = $ClassMethod(tPort, "WorkflowTaskProblem", "priority")
            Quit $$$OK
        }
        Do pArgs.%Set("Priority", +pValues.%Get("Priority"), "number")
    }
    Quit $$$OK
}

}
