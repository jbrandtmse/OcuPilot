/// <p>Interoperability's delete of suspended messages (AD-6, AD-13, AD-22, AD-51, AD-53, AD-62, Story 24.16): remove each message of one set, its body when no other
/// message uses it and its search table entries, as the Delete button of the classic Suspended Messages page does, each only if it is still suspended. Two callers reach
/// it: the Suspended messages list's row action Delete over the checked rows, after the dry run a person reviews, and the agent's proposal and confirmation
/// (<class>OcuPilot.Screen.Tool.InteropSuspendedAction</class>).</p>
/// <p><b>Destructive, key <code>false</code></b> (AD-22). The classic page's journaling suspension and bitmap clean-up are not part of it. The vendor audits nothing for
/// it, so OcuPilot records its own <code>ConfigChange</code> from either caller (<method>OcuPilot.Port.InteropPort.PerformResend</method>).</p>
Class OcuPilot.Screen.Tool.InteropSuspendedDelete Extends OcuPilot.Screen.Tool.InteropSuspendedAction
{

Parameter TOOLNAME = "interop.suspendedmessages.delete";

Parameter DESCRIPTION = "Propose deleting suspended messages of the interoperability message store: each message header is removed, with its body when no other message uses it and its search table entries. It deletes nothing by itself: it answers a proposal the user reviews and confirms, and the proposal shows what each message would do. Name the messages by the ids interop.suspendedmessages.read reports in its ID column, up to 100, separated by commas; a set over 100 or with a malformed id is refused, never cut. A message is deleted only if it is still suspended; the others are listed with the reason and not deleted, and a set none of which can be deleted is refused. A delete cannot be undone.";

Parameter SETDESCRIPTION = "The suspended messages to delete.";

/// <p>The classic Suspended Messages page's resource for its discard and delete (AD-8, AD-44).</p>
Parameter WRITERESOURCE = "%Ens_MessageDiscard";

/// <p>The fresh read: the set's verdicts, composed for the action.</p>
Parameter READTYPE = "DELETE";

Parameter WRITETYPE = "DELETEMESSAGES";

Parameter SCREENACTIONS = "delete";

/// <p>A person's action carries the digest it was reviewed at; the dry run carries none.</p>
Parameter SCREENVALUES = "delete=Reviewed";

Parameter SCREENOPTIONAL = "delete=Reviewed";

Parameter PRECONDITIONCODES = "INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.SUSPENDED.DELETE";

/// <p>A delete removes each message, which the Suspended messages list reads again.</p>
Parameter CHANGEACTION = "deleted";

Parameter OUTCOMEKIND = "delete";

}
