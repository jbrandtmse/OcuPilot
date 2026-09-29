/// <p>External language servers' stop tool (AD-6, AD-51, AD-53): stop one running external language
/// server. It is <class>OcuPilot.Screen.Tool.LanguageServerStart</class> with the <code>STOP</code>
/// request type, refusing a stopped server with <parameter>STOPPEDREASON</parameter>. The screen opens
/// its warning dialog first, and sends nothing until Proceed.</p>
/// <p>The vendor's stop is <code>StopGateway</code>'s hard <code>%Shutdown(0)</code>, which ends every
/// connection to the server at once, and answers 200 on a stopped server too. It records no audit
/// event (AD-15 and AD-53's fifth named case), so the agent's marker is that write's only record.</p>
Class OcuPilot.Screen.Tool.LanguageServerStop Extends OcuPilot.Screen.Tool.LanguageServerStart
{

Parameter TOOLNAME = "osmgmt.languageservers.stop";

Parameter DESCRIPTION = "Propose stopping one running external language server this instance defines. It changes nothing by itself: it answers a proposal the user reviews and confirms. Stopping it ends every connection to it at once. Name the server exactly as the external language servers list reports it; names are compared with their case. A server that is not running is refused.";

/// <p>The screen's own row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "stop";

Parameter WRITETYPE = "STOP";

/// <p>The classic page whose Stop this tool performs, and the Stop dialog that opens it (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.ExternalLanguageServerStop,%CSP.UI.Portal.Dialog.ExternalLanguageServerStopDialog";

Parameter STARTS As BOOLEAN = 0;

}
