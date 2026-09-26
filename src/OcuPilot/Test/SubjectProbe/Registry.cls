/// <p>Fixture: a tool registry whose discovery package is this one, so the probes
/// <parameter>OcuPilot.Screen.Tool.Registry.EXCLUDEDPACKAGE</parameter> keeps out of the shipped
/// list are admitted and <method>OcuPilot.Screen.Tool.Registry.ListTools</method> reaches AD-51's
/// registration-time fingerprint-subject guard.</p>
/// <p>The screen registry is the shipped one, so the guard reads each probe's declared subject
/// against the real screen's field list. Discovery is <code>ORDER BY Name</code>, so the class the
/// list refuses is <class>OcuPilot.Test.SubjectProbe.BodyTaking</class>.</p>
Class OcuPilot.Test.SubjectProbe.Registry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.SubjectProbe."
}

ClassMethod ExcludedPackage() As %String
{
    Quit ""
}

}
