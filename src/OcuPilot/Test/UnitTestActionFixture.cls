/// <p>Test-only <class>OcuPilot.Test.NamespaceActionFixture</class> subclass whose tool registry is
/// <class>OcuPilot.Test.UnitTestTool.Registry</class>: the screen action route resolves <code>explorer.unittests.run</code> to
/// <class>OcuPilot.Test.UnitTestTool.Run</class>, which reaches <class>OcuPilot.Test.DevToolPortFixture</class>. The pairs, the
/// governance key, the hold and the prohibited set are the shipped route's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.UnitTestActionFixture Extends OcuPilot.Test.NamespaceActionFixture
{

ClassMethod ToolRegistryClass() As %String
{
    Quit "OcuPilot.Test.UnitTestTool.Registry"
}

}
