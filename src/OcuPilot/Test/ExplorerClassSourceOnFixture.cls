/// <p>The class source read answered through <class>OcuPilot.Test.AtelierPortFixture</class>, so a test
/// can arm the document read's answers (<class>OcuPilot.Test.ExplorerSource</class>). It is not a tool:
/// the registry excludes this package.</p>
Class OcuPilot.Test.ExplorerClassSourceOnFixture Extends OcuPilot.Screen.Tool.ExplorerClassSource
{

/// <p>The fixture port, which answers the armed document reads.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.AtelierPortFixture"
}

}
