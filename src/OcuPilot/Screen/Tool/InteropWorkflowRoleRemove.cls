/// <p>Interoperability's workflow role remove (AD-6, AD-51, AD-53, AD-62, Story 24.17 Batch 3b): remove one workflow role of the request's namespace. Each of its members is removed from it; the tasks
/// already sent through it are left as they are (<code>INTEROP.WORKFLOW.ROLEREMOVE</code>).</p>
/// <p><b>It is destructive</b>: a removed workflow role cannot be restored from OcuPilot, so its card draws the destructive treatment, its row action types the role's name, and its governance key
/// ships disabled (AD-22). Its read-back reads the role gone on the port's 404.</p>
/// <p>Two callers reach it: the list's row action Remove through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropWorkflowRoleAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropWorkflowRoleRemove Extends OcuPilot.Screen.Tool.InteropWorkflowRoleAction
{

Parameter TOOLNAME = "interop.workflowroles.remove";

Parameter DESCRIPTION = "Propose removing one workflow role from the namespace the user is working in, which cannot be restored. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the workflow role exactly as the Workflow roles list reports it. Each of the role's members is removed from it; tasks already sent through the role are left as they are. A workflow role the namespace does not hold and a namespace under source control are refused.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "REMOVEWORKFLOWROLE";

/// <p>Declared: a removed workflow role cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>One static sentence.</p>
Parameter CONSEQUENCECODE = "INTEROP.WORKFLOW.ROLEREMOVE";

/// <p>The workflow role's name, description, capacity and member count: what the removal reviewed, so a role edited or given a member since the review closes the proposal target-changed; and its
/// namespace, which the stored payload keeps so the confirm and the script form act where the proposal read.</p>
Parameter FINGERPRINTSUBJECT = "Name,Description,Capacity,Members,Namespace";

Parameter PRECONDITIONFIELD = "Members";

/// <p>The removal rows the card shows: what the removed workflow role held.</p>
Parameter REMOVALROWS = "Name,Description,Capacity,Members";

Parameter PRECONDITIONCODES = "INTEROP.WORKFLOW.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no
/// after-state. A read that answered no <code>Members</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Members") '= "number") {
            Set pProblem = "this instance did not report the workflow role, and a workflow role whose state is unknown is not one to remove"
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
