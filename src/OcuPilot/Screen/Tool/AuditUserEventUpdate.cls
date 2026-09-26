/// <p>The User events list's enable and disable tool, and the user audit event editor's Description
/// edit: <class>OcuPilot.Screen.Tool.AuditEventUpdate</class> over the events applications register,
/// OcuPilot's own marker event among them. It admits <code>Description</code> beside
/// <code>Enabled</code>, and refuses a system event from both callers.</p>
Class OcuPilot.Screen.Tool.AuditUserEventUpdate Extends OcuPilot.Screen.Tool.AuditEventUpdate
{

Parameter TOOLNAME = "security.audituserevents.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuditUserEventList";

Parameter DESCRIPTION = "Propose a change to one user audit event: turning it on or off, so the instance does or does not record it in the audit database, or changing its description. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the event exactly as the user events list reports it, as Source/Type/Name, and send only the fields to change. Turning off OcuPilot/Security/AgentWrite stops the agent's own writes being marked, so say so plainly in the rationale.";

/// <p>The two derived top-level fields this tool admits, which are the two
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> permits a change to for
/// a user event. A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "Description,Enabled";

Parameter EVENTOWNER = "user";

/// <p>The ownership refusal, then the editor's Description rule
/// (<method>OcuPilot.Area.Security.AuditEventRules.ArgumentViolations</method>).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ##class(OcuPilot.Area.Security.AuditEventRules).OwnerRefusal($ClassName(), pIdValue)
    If pProblem '= "" Quit $$$OK
    Set tSC = ##class(OcuPilot.Area.Security.AuditEventRules).ArgumentViolations(pIdValue, pArgs, 0, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = ##class(OcuPilot.Area.Security.AuditEventRules).ProblemText(.tViolations)
    Quit $$$OK
}

}
