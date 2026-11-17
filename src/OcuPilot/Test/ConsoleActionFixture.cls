/// <p>Test-only <class>OcuPilot.Test.NamespaceActionFixture</class> subclass whose tool registry is
/// <class>OcuPilot.Test.ConsoleTool.Registry</class>: the screen action route resolves <code>explorer.command.run</code> and
/// <code>explorer.classmethod.run</code> to <class>OcuPilot.Test.ConsoleTool.RunCommand</class> and
/// <class>OcuPilot.Test.ConsoleTool.RunClassMethod</class>, which reach <class>OcuPilot.Test.DevToolPortFixture</class>. The
/// pairs, the governance key, the hold and the prohibited set are the shipped route's (Story 24.6).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ConsoleActionFixture Extends OcuPilot.Test.NamespaceActionFixture
{

ClassMethod ToolRegistryClass() As %String
{
    Quit "OcuPilot.Test.ConsoleTool.Registry"
}

}
