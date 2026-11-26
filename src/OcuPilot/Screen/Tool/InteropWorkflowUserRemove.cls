/// <p>Interoperability's workflow user remove (AD-6, AD-51, AD-53, AD-62, Story 24.17 Batch 3a): remove one workflow user of the request's namespace. The user leaves every workflow role, their
/// worklist is deleted and each task they hold is left unassigned (<code>INTEROP.WORKFLOW.USERREMOVE</code>); the roles stay.</p>
/// <p><b>It is destructive</b>: a removed workflow user cannot be restored from OcuPilot, so its card draws the destructive treatment, its row action types the user's name, and its governance key
/// ships disabled (AD-22). Its read-back reads the user gone on the port's 404.</p>
/// <p>Two callers reach it: the list's row action Remove through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropWorkflowUserAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropWorkflowUserRemove Extends OcuPilot.Screen.Tool.InteropWorkflowUserAction
{

Parameter TOOLNAME = "interop.workflowusers.remove";

Parameter DESCRIPTION = "Propose removing one workflow user from the namespace the user is working in, which cannot be restored. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the workflow user exactly as the Workflow users list reports it. The user is taken out of every workflow role, their worklist is deleted and each task they hold is left unassigned; the workflow roles stay. A workflow user the namespace does not hold and a namespace under source control are refused.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "REMOVEWORKFLOWUSER";

/// <p>Declared: a removed workflow user cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>One static sentence.</p>
Parameter CONSEQUENCECODE = "INTEROP.WORKFLOW.USERREMOVE";

/// <p>The workflow user's name, full name, active state and role count: what the removal reviewed, so a user edited or given a role since the review closes the proposal target-changed; and its
/// namespace, which the stored payload keeps so the confirm and the script form act where the proposal read.</p>
Parameter FINGERPRINTSUBJECT = "Name,FullName,IsActive,Roles,Namespace";

Parameter PRECONDITIONFIELD = "Roles";

/// <p>The removal rows the card shows: what the removed workflow user held.</p>
Parameter REMOVALROWS = "Name,FullName,IsActive,Roles";

Parameter PRECONDITIONCODES = "INTEROP.WORKFLOW.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no
/// after-state. A read that answered no <code>Roles</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Roles") '= "number") {
            Set pProblem = "this instance did not report the workflow user, and a workflow user whose state is unknown is not one to remove"
            Quit
        }
        Set pRows = ..RemovalRows(pFresh)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
