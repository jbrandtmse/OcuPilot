/// <p>Interoperability's resubmit of suspended messages (AD-6, AD-13, AD-22, AD-51, AD-53, AD-62, Story 24.16): put each message of one set back on its target's queue
/// under its own message id, as the Resubmit button of the classic Suspended Messages page does, each only if its verdict says it can go. Two callers reach it: the
/// Suspended messages list's row action Resubmit over the checked rows, through <class>OcuPilot.Api.ScreenAction</class> after the dry run a person reviews
/// (<class>OcuPilot.Api.ScreenDryRun</class>), and the agent's proposal and confirmation (<class>OcuPilot.Screen.Tool.InteropSuspendedAction</class>).</p>
/// <p><b>Destructive, key <code>false</code></b> (AD-22): a delivered message cannot be recalled by proposing the opposite. The vendor audits each resubmit itself, so
/// OcuPilot records no row of its own.</p>
Class OcuPilot.Screen.Tool.InteropSuspendedResubmit Extends OcuPilot.Screen.Tool.InteropSuspendedAction
{

Parameter TOOLNAME = "interop.suspendedmessages.resubmit";

Parameter DESCRIPTION = "Propose resubmitting suspended messages of the interoperability message store: each is put back on its target's queue under its own message id, and the running production processes it. It sends nothing by itself: it answers a proposal the user reviews and confirms, and the proposal shows what each message would do. Name the messages by the ids interop.suspendedmessages.read reports in its ID column, up to 100, separated by commas; a set over 100 or with a malformed id is refused, never cut. The production must be running. A message is resubmitted only if it is still suspended, still exists with its body, and a request's target is an enabled item of the running production; the others are listed with the reason and not resubmitted, and a set none of which can be resubmitted is refused. A resubmitted message can fail and be suspended again, and a resubmit cannot be undone.";

Parameter SETDESCRIPTION = "The suspended messages to resubmit.";

/// <p>The fresh read: the set's verdicts, composed for the action.</p>
Parameter READTYPE = "RESUBMIT";

Parameter WRITETYPE = "RESUBMITMESSAGES";

Parameter SCREENACTIONS = "resubmit";

/// <p>A person's action carries the digest it was reviewed at; the dry run carries none.</p>
Parameter SCREENVALUES = "resubmit=Reviewed";

Parameter SCREENOPTIONAL = "resubmit=Reviewed";

Parameter PRECONDITIONCODES = "INTEROP.PRODUCTION.NOTRUNNING,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.SUSPENDED.RESUBMIT";

/// <p>A resubmit keeps each header, which the Suspended messages list reads again.</p>
Parameter CHANGEACTION = "updated";

Parameter OUTCOMEKIND = "resubmit";

}
