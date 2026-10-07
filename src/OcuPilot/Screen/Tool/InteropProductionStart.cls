/// <p>Interoperability's production start (AD-6, AD-51, AD-53, AD-62): Start a stopped or suspended production. The vendor answers a start of a running production with a refusal and of a troubled production with another, and a start while another production is current with a third; the port refuses each by its own code before any vendor call. A start returns once its jobs are launched (measured under a second, also with an item whose initialization waits 25 s), so it is sent at once from the row.</p>
/// <p>Two callers reach it: the Productions row action Start through <class>OcuPilot.Api.ScreenAction</class>
/// and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropProductionAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropProductionStart Extends OcuPilot.Screen.Tool.InteropProductionAction
{

Parameter TOOLNAME = "interop.productions.start";

Parameter DESCRIPTION = "Propose starting one production of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production exactly as the Productions list reports it. A production that is already running or troubled, and one whose namespace runs another production, is refused; a stopped or suspended production starts.";

Parameter SCREENACTIONS = "start";

Parameter WRITETYPE = "START";

Parameter FINGERPRINTSUBJECT = "State,Current,Namespace";

Parameter AFTERWORD = "Running";

}
