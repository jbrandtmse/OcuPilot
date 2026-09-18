/// <p>Fixture: the shipped dispatcher reading <class>OcuPilot.Test.LedgerClientTool.Registry</class>,
/// so <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> resolves a client-fulfilled
/// tool that declares a secret argument. No shipped client-fulfilled tool declares one
/// (<class>OcuPilot.Screen.Tool.Navigate</class> declares none), so without this the
/// client-fulfilled half of the mandatory-declaration wiring has nothing to exercise.</p>
Class OcuPilot.Test.LedgerClientDispatchProbe Extends OcuPilot.Kernel.Agent.Dispatch
{

ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Test.LedgerClientTool.Registry"
}

}
