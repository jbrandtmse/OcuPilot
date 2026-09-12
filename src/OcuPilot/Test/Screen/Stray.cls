/// <p>Test-only fixture: a class that sits in the fixture descriptor package and is <b>not</b> a
/// descriptor. It declares no <code>XData Declaration</code> and answers none of the accessors
/// <class>OcuPilot.Screen.Registry</class>'s callers invoke.</p>
/// <p>It exists to give the registry's superclass filter a subject. Membership in the roster is
/// the package prefix <b>and</b> the superclass: without the second half a misplaced class is
/// enumerated, <code>$ClassMethod(class, "AreaKey")</code> raises
/// <code>&lt;METHOD DOES NOT EXIST&gt;</code>, and that exception fails
/// <method>OcuPilot.Screen.Registry.Roster</method>, fails
/// <class>OcuPilot.Api.Navigation</class>, and leaves the client holding no navigation map at
/// all -- which reads at the client as every area ungated.</p>
Class OcuPilot.Test.Screen.Stray Extends %RegisteredObject
{

/// <p>Present only so the class has a member; nothing calls it.</p>
ClassMethod Marker() As %String
{
    Quit "not a descriptor"
}

}
