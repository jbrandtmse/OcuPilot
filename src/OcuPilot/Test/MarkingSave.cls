/// <p>Subclass of <class>OcuPilot.Area.Security.AuditEventSave</class> whose port seam is
/// <class>OcuPilot.Test.MarkingPort</class>, so the editor's post-write marking observation reads
/// armed answers while its write reaches the real port.</p>
Class OcuPilot.Test.MarkingSave Extends OcuPilot.Area.Security.AuditEventSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.MarkingPort"
}

/// <p>Issue <var>pToolClass</var>'s write of <var>pPayload</var> to <var>pEventName</var> through
/// the Save's own send, which observes the marking after it.</p>
ClassMethod SaveWrite(pToolClass As %String, pEventName As %String, pPayload As %DynamicObject, Output pHttpStatus As %Integer) As %Status
{
    Quit ..Send(pToolClass, pEventName, pPayload, .pHttpStatus, .tFault)
}

}
