/// <p>Interoperability's production stop (AD-6, AD-51, AD-53, AD-62): Stop a running production, waiting at most the port's cap for work in progress. The vendor answers a stop of a production that is not running as a success that changes nothing, which the port refuses before any vendor call.</p>
/// <p>Two callers reach it: the Productions row action Stop through <class>OcuPilot.Api.ScreenAction</class>
/// and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropProductionAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropProductionStop Extends OcuPilot.Screen.Tool.InteropProductionAction
{

Parameter TOOLNAME = "interop.productions.stop";

Parameter DESCRIPTION = "Propose stopping one running production of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production exactly as the Productions list reports it. The stop waits up to 15 seconds for work in progress to finish; if it takes longer nothing is stopped. A production that is not running is refused.";

Parameter SCREENACTIONS = "stop";

Parameter WRITETYPE = "STOP";

Parameter FINGERPRINTSUBJECT = "State,Namespace";

Parameter AFTERWORD = "Stopped";

Parameter CONSEQUENCECODE = "INTEROP.STOP";

}
