/// <p>Interoperability's production recover (AD-6, AD-51, AD-53, AD-62): Recover a troubled production. The vendor records no audit event for a recover (Story 20.2 measured two runs on the throwaway), a named gap in AD-15 and AD-53; it makes no privilege check of its own and raises a protection error without WRITE on the database, which the pairs refuse first.</p>
/// <p>Two callers reach it: the Productions row action Recover through <class>OcuPilot.Api.ScreenAction</class>
/// and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropProductionAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropProductionRecover Extends OcuPilot.Screen.Tool.InteropProductionAction
{

Parameter TOOLNAME = "interop.productions.recover";

Parameter DESCRIPTION = "Propose recovering one troubled production of the namespace the user is working in: recover is the first response to a troubled production and returns it to Suspended so it can be started again, deleting no message. Clean, which deletes queued messages, is a last resort this product does not offer. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production exactly as the Productions list reports it. A production that is not troubled is refused.";

Parameter SCREENACTIONS = "recover";

Parameter WRITETYPE = "RECOVER";

Parameter FINGERPRINTSUBJECT = "State,Namespace";

Parameter AFTERWORD = "Suspended";

Parameter CONSEQUENCECODE = "INTEROP.RECOVER";

}
