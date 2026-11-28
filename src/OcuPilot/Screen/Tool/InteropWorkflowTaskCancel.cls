/// <p>Interoperability's workflow task cancel (AD-6, AD-10, AD-22, AD-51, AD-53, AD-62, Story 24.17 Batch 4): cancel one open workflow task of the request's namespace, as the classic Assign or
/// Reassign Task dialog's cancel does. The task reads <code>Cancelled</code> and complete, it is taken off every worklist, and its response is returned, canceled, to the business process that sent
/// it (<code>INTEROP.WORKFLOW.TASKCANCEL</code>).</p>
/// <p><b>It is destructive</b>: a canceled task cannot be undone and the waiting business process acts on the response, so its card draws the destructive treatment, its row action types the task's
/// ID, and its governance key ships disabled (AD-22). The port refuses a cancel by name before any vendor call when no production runs in the namespace
/// (<code>INTEROP.PRODUCTION.NOTRUNNING</code>) or the task's sender is not waiting for it in the running one (<code>INTEROP.WORKFLOW.TASKSENDER</code>), where the vendor would delete the task's
/// worklist and then fail to return the response.</p>
/// <p>Two callers reach it: the list's row action Cancel task through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropWorkflowTaskAction</class>'s. Its read-back finds the task complete, which its own read refuses, so it reads <code>nothingSent</code> (AD-58).</p>
Class OcuPilot.Screen.Tool.InteropWorkflowTaskCancel Extends OcuPilot.Screen.Tool.InteropWorkflowTaskAction
{

Parameter TOOLNAME = "interop.workflowtasks.cancel";

Parameter DESCRIPTION = "Propose canceling one open workflow task of the namespace the user is working in, which cannot be undone. Name the task by the Task ID interop.workflowtasks.read reports. The task reads Cancelled and complete, is taken off every worklist, and its response is returned, canceled, to the business process that sent it. It changes nothing by itself: it answers a proposal the user reviews and confirms. A task that is already complete, a namespace in which no production is running, and a task whose business process is not waiting for it in the running production are refused.";

Parameter SCREENACTIONS = "cancel";

Parameter WRITETYPE = "CANCELWORKFLOWTASK";

/// <p>Declared: a canceled task cannot be undone, and the waiting business process acts on the response.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>One static sentence.</p>
Parameter CONSEQUENCECODE = "INTEROP.WORKFLOW.TASKCANCEL";

Parameter PRECONDITIONCODES = "INTEROP.PRODUCTION.NOTRUNNING,INTEROP.WORKFLOW.TASKSENDER,INTEROP.WORKFLOW.TASKCOMPLETE,INTEROP.NAMESPACE";

/// <p>No state row: the card shows the task and the consequence sentence.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

}
