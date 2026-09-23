/// <p>The User events list's enable and disable tool:
/// <class>OcuPilot.Screen.Tool.AuditEventUpdate</class> over the events applications register,
/// OcuPilot's own marker event among them.</p>
Class OcuPilot.Screen.Tool.AuditUserEventUpdate Extends OcuPilot.Screen.Tool.AuditEventUpdate
{

Parameter TOOLNAME = "security.audituserevents.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuditUserEventList";

Parameter DESCRIPTION = "Propose turning one user audit event on or off, so the instance does or does not record it in the audit database. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the event exactly as the user events list reports it, as Source/Type/Name, and send Enabled. Turning off OcuPilot/Security/AgentWrite stops the agent's own writes being marked, so say so plainly in the rationale.";

}
