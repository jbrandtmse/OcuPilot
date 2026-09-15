/// <p>Test-only <class>OcuPilot.Screen.Tool.ErrorRead</class> subclass whose
/// <method>PortClass</method> answers <class>OcuPilot.Test.ErrorLogFixture</class>, so the tool's
/// reads are counted per query name.</p>
/// <p>That is what makes "the read tool never reaches <code>ErrorDetail</code>" an observation
/// rather than an inference from the payload's shape: a tool that fetched the captured detail and
/// then dropped it would answer exactly the same five fields (AD-48).</p>
/// <p>It overrides one seam and nothing else, so the projection, the schema and the cap under test
/// are the shipped tool's.</p>
Class OcuPilot.Test.ErrorReadProbe Extends OcuPilot.Screen.Tool.ErrorRead
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ErrorLogFixture"
}

}
