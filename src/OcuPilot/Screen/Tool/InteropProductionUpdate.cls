/// <p>Interoperability's production update (AD-6, AD-51, AD-53, AD-62): Update a running production that needs it. The vendor records no audit event for an update (Story 20.2 measured two runs on the throwaway), a named gap in AD-15 and AD-53.</p>
/// <p>Two callers reach it: the Productions row action Update through <class>OcuPilot.Api.ScreenAction</class>
/// and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropProductionAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropProductionUpdate Extends OcuPilot.Screen.Tool.InteropProductionAction
{

Parameter TOOLNAME = "interop.productions.update";

Parameter DESCRIPTION = "Propose updating one running production of the namespace the user is working in, so it applies the settings and enabled items changed since it started. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production exactly as the Productions list reports it. The update waits up to 15 seconds for an item to finish its work; if it takes longer the update is refused and the production keeps running. A production that is not running, or has nothing to update, is refused.";

Parameter SCREENACTIONS = "update";

Parameter WRITETYPE = "UPDATE";

Parameter FINGERPRINTSUBJECT = "State,NeedsUpdate,Namespace";

Parameter AFTERWORD = "Running";

Parameter CONSEQUENCECODE = "INTEROP.UPDATE";

}
