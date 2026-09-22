/// <p>Fixture: an action-style write whose declared fingerprint subject names a field its
/// descriptor's <code>fingerprintExcludes</code> also names (DW-1474, AD-51).</p>
/// <p><b>Its descriptor is <class>OcuPilot.Test.ProposalScreen</class>, because no shipped one
/// declares <code>fingerprintExcludes</code> at all</b> -- which is why this direction of the guard
/// had never been exercised. That screen excludes <code>LastModified</code> and declares it in its
/// read, so the overlap is the only thing wrong with this declaration.</p>
/// <p><method>OcuPilot.Screen.Registry.FingerprintSubjectProblem</method> is asked about it
/// directly; the class is in
/// <parameter>OcuPilot.Screen.Tool.Registry.EXCLUDEDPACKAGE</parameter>, so it never registers.</p>
Class OcuPilot.Test.SubjectProbe.ExcludedName Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "probe.subject.excludedname";

Parameter DESCRIPTORCLASS = "OcuPilot.Test.ProposalScreen";

Parameter DESCRIPTION = "Fixture: an action-style write whose fingerprint subject names an excluded field.";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter WRITETYPE = "SUSPEND";

Parameter FINGERPRINTSUBJECT = "Name,LastModified";

Parameter PRECONDITIONFIELD = "LastModified";

ClassMethod Endpoint() As %String
{
    Quit "WebApp.App"
}

ClassMethod IdArgument() As %String
{
    Quit "Name"
}

ClassMethod IdParam() As %String
{
    Quit "name"
}

ClassMethod SettableFields() As %List
{
    Quit ""
}

}
