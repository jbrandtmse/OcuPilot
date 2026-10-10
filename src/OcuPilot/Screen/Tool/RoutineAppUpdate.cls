/// <p>The privileged routine applications' edit tool (AD-4, AD-6, AD-55, Story 18.31): propose a change to one
/// application's description, enabled flag or resource. It is <class>OcuPilot.Screen.Tool.DocDbAppUpdate</class> over
/// the vendor's own <code>Security.PrivilegedRoutine</code> endpoint, reached through
/// <class>OcuPilot.Port.AdminPort</class>. It reads the application fresh, merges the arguments over that object and
/// mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's complete set, with the changed settings applied (AD-4). The
/// vendor empties the routines a <code>PUT</code> does not send, so the roles and routines the read answered go back
/// unchanged, and a change to a setting keeps them. The name is the id and never changes.</p>
/// <p>OcuPilot's own two routine applications are refused every change before a proposal is stored
/// (<method>RefusedBeforeState</method>).</p>
Class OcuPilot.Screen.Tool.RoutineAppUpdate Extends OcuPilot.Screen.Tool.DocDbAppUpdate
{

Parameter TOOLNAME = "webapp.routineapps.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoutineAppList";

Parameter DESCRIPTION = "Propose a change to one privileged routine application. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the application exactly as the privileged routine applications list reports it and send only the settings to change: the description, whether it is enabled, or the service, system or application resource that controls it. The application's roles and routines are kept as they are, and its name cannot be changed.";

Parameter PORTCLASS = "OcuPilot.Port.AdminPort";

/// <p>The classic editor whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Applications.PrivRoutine";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.WebApp.RoutineAppRules";

ClassMethod Endpoint() As %String
{
    Quit "Security.PrivilegedRoutine"
}

/// <p>The kernel's mint: the application's id is its name, so no composite is built.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Mint"
}

/// <p>The derived schema with the name and the settings described, and no namespace
/// (<method>OcuPilot.Screen.Tool.RoutineAppCreate.Described</method>).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.RoutineAppCreate).Described(##super(pDescriptor), 0)
}

/// <p>OcuPilot's own privileged routine applications are refused every change as
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTROUTINEAPP</parameter> before a proposal is stored or a write
/// is sent (AD-10, Story 18.10), so the screen's action and the agent's mint answer 403.</p>
ClassMethod RefusedBeforeState(pIdValue As %String, Output pCode As %String) As %Boolean
{
    Quit ##class(OcuPilot.Kernel.Proposal.Prohibited).RefusesBeforeState(pIdValue, .pCode)
}

}
