/// <p>The privileged routine applications' delete tool (AD-6, AD-8, AD-51, Story 18.31): propose removing one
/// privileged routine application from this instance. It is <class>OcuPilot.Screen.Tool.DocDbAppDelete</class> over the
/// vendor's own <code>Security.PrivilegedRoutine</code> endpoint, reached through <class>OcuPilot.Port.AdminPort</class>.
/// It reads the application fresh and mints a proposal whose card lists what it removes: the three settings and the
/// roles and routines it holds. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>DELETE</code> reads no body, so the tool admits no settable
/// field. Its fingerprint covers all five fields, so a change to the roles or routines since the mint refuses the
/// confirm. It runs on the classic list page itself, so it declares no replaced page.</p>
/// <p>OcuPilot's own two routine applications are refused before the precondition is read
/// (<method>RefusedBeforeState</method>).</p>
Class OcuPilot.Screen.Tool.RoutineAppDelete Extends OcuPilot.Screen.Tool.DocDbAppDelete
{

Parameter TOOLNAME = "webapp.routineapps.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoutineAppList";

Parameter DESCRIPTION = "Propose deleting one privileged routine application. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the application exactly as the privileged routine applications list reports it. The application and the roles and routines it holds are removed.";

Parameter PORTCLASS = "OcuPilot.Port.AdminPort";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Description,Enabled,Resource,MatchRoles,Routines";

Parameter FINGERPRINTSUBJECT = "Description,Enabled,Resource,MatchRoles,Routines";

ClassMethod Endpoint() As %String
{
    Quit "Security.PrivilegedRoutine"
}

/// <p>The kernel's mint: the application's id is its name, so no composite is built.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Mint"
}

/// <p>The derived schema with the name described, and no namespace
/// (<method>OcuPilot.Screen.Tool.RoutineAppCreate.Described</method>).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.RoutineAppCreate).Described(##super(pDescriptor), 0)
}

/// <p>OcuPilot's own privileged routine applications are refused the delete as
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTROUTINEAPP</parameter> before the precondition below reads them
/// (AD-10, Story 18.10).</p>
ClassMethod RefusedBeforeState(pIdValue As %String, Output pCode As %String) As %Boolean
{
    Quit ##class(OcuPilot.Kernel.Proposal.Prohibited).RefusesBeforeState(pIdValue, .pCode)
}

}
