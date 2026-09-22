/// <p>Fixture: an action-style write whose declared fingerprint subject is inadequate because
/// the declaration names no field at all (AD-51).
/// <method>OcuPilot.Test.ToolWrite.TestAnInadequateFingerprintSubjectIsRefusedAtRegistration</method>
/// asks <method>OcuPilot.Screen.Registry.FingerprintSubjectProblem</method> about it directly; the
/// class is in <parameter>OcuPilot.Screen.Tool.Registry.EXCLUDEDPACKAGE</parameter>, so it never
/// registers.</p>
Class OcuPilot.Test.SubjectProbe.EmptySubject Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "probe.subject.emptysubject";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ProcessList";

Parameter DESCRIPTION = "Fixture: an action-style write with an inadequate fingerprint subject.";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter WRITETYPE = "SUSPEND";

Parameter FINGERPRINTSUBJECT = " , ";

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
