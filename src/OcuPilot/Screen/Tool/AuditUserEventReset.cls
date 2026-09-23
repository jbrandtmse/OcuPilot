/// <p>The User events list's reset tool: <class>OcuPilot.Screen.Tool.AuditEventReset</class> over
/// the events applications register.</p>
Class OcuPilot.Screen.Tool.AuditUserEventReset Extends OcuPilot.Screen.Tool.AuditEventReset
{

Parameter TOOLNAME = "security.audituserevents.reset";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuditUserEventList";

Parameter DESCRIPTION = "Propose resetting one user audit event's Total, Written and Lost counters to zero. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the event exactly as the user events list reports it, as Source/Type/Name. The audit records already written are not touched.";

}
