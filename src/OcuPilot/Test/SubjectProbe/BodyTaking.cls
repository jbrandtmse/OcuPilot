/// <p>Fixture: a merge write -- one that sends a body -- declaring a fingerprint subject, which
/// AD-51's inversion is not for: its payload would be narrowed to the subject and the body sent
/// with it.
/// <method>OcuPilot.Test.ToolWrite.TestAnInadequateFingerprintSubjectIsRefusedAtRegistration</method>
/// asks <method>OcuPilot.Screen.Registry.FingerprintSubjectProblem</method> about it directly; the
/// class is in <parameter>OcuPilot.Screen.Tool.Registry.EXCLUDEDPACKAGE</parameter>, so it never
/// registers.</p>
Class OcuPilot.Test.SubjectProbe.BodyTaking Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "probe.subject.bodytaking";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ProcessList";

Parameter DESCRIPTION = "Fixture: a merge write declaring a fingerprint subject.";

Parameter FINGERPRINTSUBJECT = "Pid,State";

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
