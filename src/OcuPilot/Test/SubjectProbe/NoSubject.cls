/// <p>Fixture: an action-style write that declares no fingerprint subject at all, which AD-51
/// refuses because such a write sends no payload for AD-6's exclusion model to cover (DW-1476).
/// <method>OcuPilot.Test.ToolWrite.TestAnInadequateFingerprintSubjectIsRefusedAtRegistration</method>
/// asks <method>OcuPilot.Screen.Registry.FingerprintSubjectProblem</method> about it directly; the
/// class is in <parameter>OcuPilot.Screen.Tool.Registry.EXCLUDEDPACKAGE</parameter>, so it never
/// registers.</p>
Class OcuPilot.Test.SubjectProbe.NoSubject Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "probe.subject.nosubject";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ProcessList";

Parameter DESCRIPTION = "Fixture: an action-style write that declares no fingerprint subject.";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter WRITETYPE = "SUSPEND";

Parameter PRECONDITIONFIELD = "State";

ClassMethod Endpoint() As %String
{
    Quit "Process"
}

ClassMethod IdArgument() As %String
{
    Quit "Pid"
}

ClassMethod IdParam() As %String
{
    Quit "id"
}

ClassMethod SettableFields() As %List
{
    Quit ""
}

}
