/// <p>Fixture: the shipped dispatcher reading <class>OcuPilot.Test.LedgerTool.Registry</class>, so a
/// refusal inside <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> resolves a tool that
/// declares a secret argument. No shipped tool declares one, so without this the layer-1 redaction
/// on a refusal row has nothing to redact and could be removed unnoticed.</p>
Class OcuPilot.Test.LedgerDispatchProbe Extends OcuPilot.Kernel.Agent.Dispatch
{

ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Test.LedgerTool.Registry"
}

}
