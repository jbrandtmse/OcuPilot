/// <p>Interoperability's workflow member remove (AD-6, AD-51, AD-53, AD-62, Story 24.17 Batch 3b): remove one member from one workflow role of the request's namespace. Their worklist for the role is
/// deleted and each task they hold through it is left unassigned (<code>INTEROP.WORKFLOW.MEMBERREMOVE</code>); the workflow user and the role stay, and adding the member again restores the
/// membership.</p>
/// <p><b>It is not destructive</b>: the card shows the member's rank and title and the consequence sentence, and a removal is undone by adding the member again. Its read-back reads the
/// membership gone on the port's 404. The vendor answers the removal of a user who is not a member as a success, so the port refuses it by name.</p>
/// <p>Two callers reach it: the members list's row action Remove through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropWorkflowMemberAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropWorkflowMemberRemove Extends OcuPilot.Screen.Tool.InteropWorkflowMemberAction
{

Parameter TOOLNAME = "interop.workflowmembers.remove";

Parameter DESCRIPTION = "Propose removing one member from a workflow role of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the role and the user exactly as the role's members list reports them. The member's worklist for the role is deleted and each task they hold through it is left unassigned; the workflow user and the role stay. A user who is not a member of the role, a role the namespace does not hold and a namespace under source control are refused.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "REMOVEWORKFLOWMEMBER";

Parameter CHANGEACTION = "deleted";

/// <p>One static sentence.</p>
Parameter CONSEQUENCECODE = "INTEROP.WORKFLOW.MEMBERREMOVE";

/// <p>The membership's role, user, full name, rank, title and active state: what the removal reviewed, so a member edited, deactivated or renamed since the review closes the proposal
/// target-changed; and its namespace, which the stored payload keeps so the confirm and the script form act where the proposal read.</p>
Parameter FINGERPRINTSUBJECT = "Role,User,Ranking,Title,Namespace";

Parameter PRECONDITIONFIELD = "Ranking";

/// <p>The removal rows the card shows: what the removed membership held.</p>
Parameter REMOVALROWS = "Role,User,Ranking,Title";

Parameter PRECONDITIONCODES = "INTEROP.WORKFLOW.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>A remove has no fields to judge.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no
/// after-state. A read that answered no <code>Ranking</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Ranking") '= "number") {
            Set pProblem = "this instance did not report the member, and a member whose state is unknown is not one to remove"
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
