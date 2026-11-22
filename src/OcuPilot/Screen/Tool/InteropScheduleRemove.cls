/// <p>Interoperability's schedule spec remove (AD-6, AD-51, AD-53, AD-62, Story 24.15): remove one schedule spec of the request's namespace. Items that
/// name it keep running until the production is next updated, and are then disabled and stopped until the schedule spec is added again
/// (<code>INTEROP.SCHEDULE.REMOVE</code>). There is no refusal for a schedule spec in use: a person confirms the consequence the card states.</p>
/// <p><b>It is destructive</b>: a removed schedule spec cannot be restored from OcuPilot, so its card draws the destructive treatment, its row action
/// types the schedule spec's name, and its governance key ships disabled (AD-22). Its read-back reads the schedule spec gone on the port's 404.</p>
/// <p>Two callers reach it: the list's row action Remove through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation.
/// Its state, fingerprint and refusals are <class>OcuPilot.Screen.Tool.InteropScheduleAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropScheduleRemove Extends OcuPilot.Screen.Tool.InteropScheduleAction
{

Parameter TOOLNAME = "interop.schedules.remove";

Parameter DESCRIPTION = "Propose removing one schedule spec from the namespace the user is working in, which cannot be restored. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the schedule spec exactly as the Schedule specs list reports it. Items that name the schedule spec keep running until the production is next updated, and are then disabled and stopped until the schedule spec is added again. A schedule spec the namespace does not hold and a namespace under source control are refused.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "REMOVESCHEDULE";

/// <p>Declared: a removed schedule spec cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>One static sentence.</p>
Parameter CONSEQUENCECODE = "INTEROP.SCHEDULE.REMOVE";

/// <p>The schedule spec's name, description, spec and flag: what the removal reviewed, so a schedule spec edited since the review closes the proposal
/// target-changed; and its namespace, which the stored payload keeps so the confirm and the script form act where the proposal read.</p>
Parameter FINGERPRINTSUBJECT = "Name,Description,ScheduleSpec,Deployable,Namespace";

Parameter PRECONDITIONFIELD = "ScheduleSpec";

/// <p>The removal rows the card shows: what the removed schedule spec held.</p>
Parameter REMOVALROWS = "Name,Description,ScheduleSpec";

Parameter PRECONDITIONCODES = "INTEROP.SCHEDULE.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per <parameter>REMOVALROWS</parameter> name, carrying
/// the value the instance holds and no after-state. A read that answered no <code>ScheduleSpec</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("ScheduleSpec") '= "string") {
            Set pProblem = "this instance did not report the schedule spec, and a schedule spec whose state is unknown is not one to remove"
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
