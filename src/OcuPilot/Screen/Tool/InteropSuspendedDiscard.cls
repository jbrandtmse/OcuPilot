/// <p>Interoperability's discard of suspended messages (AD-6, AD-13, AD-22, AD-51, AD-53, AD-62, Story 24.16): mark each message of one set Discarded, as the Discard
/// button of the classic Suspended Messages page does, each only if it is still suspended. Two callers reach it: the Suspended messages list's row action Discard over
/// the checked rows, after the dry run a person reviews, and the agent's proposal and confirmation (<class>OcuPilot.Screen.Tool.InteropSuspendedAction</class>).</p>
/// <p><b>Not destructive, key <code>true</code></b> (AD-22): the header and its body are kept and the message can still be resent from Messages. The vendor audits
/// nothing for it, so OcuPilot records its own <code>ConfigChange</code> from either caller (<method>OcuPilot.Port.InteropPort.PerformResend</method>).</p>
Class OcuPilot.Screen.Tool.InteropSuspendedDiscard Extends OcuPilot.Screen.Tool.InteropSuspendedAction
{

Parameter TOOLNAME = "interop.suspendedmessages.discard";

Parameter DESCRIPTION = "Propose discarding suspended messages of the interoperability message store: each is marked Discarded, so it is no longer suspended and is not processed. The message and its body are kept. It changes nothing by itself: it answers a proposal the user reviews and confirms, and the proposal shows what each message would do. Name the messages by the ids interop.suspendedmessages.read reports in its ID column, up to 100, separated by commas; a set over 100 or with a malformed id is refused, never cut. A message is discarded only if it is still suspended; the others are listed with the reason and not discarded, and a set none of which can be discarded is refused. A discarded message can still be resent from Messages.";

Parameter SETDESCRIPTION = "The suspended messages to discard.";

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>The classic Suspended Messages page's resource for its discard and delete (AD-8, AD-44).</p>
Parameter WRITERESOURCE = "%Ens_MessageDiscard";

/// <p>The fresh read: the set's verdicts, composed for the action.</p>
Parameter READTYPE = "DISCARD";

Parameter WRITETYPE = "DISCARDMESSAGES";

Parameter SCREENACTIONS = "discard";

/// <p>A person's action carries the digest it was reviewed at; the dry run carries none.</p>
Parameter SCREENVALUES = "discard=Reviewed";

Parameter SCREENOPTIONAL = "discard=Reviewed";

Parameter PRECONDITIONCODES = "INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.SUSPENDED.DISCARD";

/// <p>A discard keeps each header, which the Suspended messages list reads again.</p>
Parameter CHANGEACTION = "updated";

Parameter OUTCOMEKIND = "discard";

}
