/// <p>Interoperability's production restart (AD-6, AD-51, AD-53, AD-62): Restart a running production, waiting at most the port's cap for work in progress. A restart whose start fails leaves the production stopped.</p>
/// <p>Two callers reach it: the Productions row action Restart through <class>OcuPilot.Api.ScreenAction</class>
/// and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropProductionAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropProductionRestart Extends OcuPilot.Screen.Tool.InteropProductionAction
{

Parameter TOOLNAME = "interop.productions.restart";

Parameter DESCRIPTION = "Propose restarting one running production of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production exactly as the Productions list reports it. The restart waits up to 15 seconds for work in progress to finish before stopping; if it takes longer nothing is stopped. A production that is not running is refused.";

Parameter SCREENACTIONS = "restart";

Parameter WRITETYPE = "RESTART";

Parameter FINGERPRINTSUBJECT = "State,Namespace";

Parameter AFTERWORD = "Running";

Parameter CONSEQUENCECODE = "INTEROP.RESTART";

}
