/// <p>Fixture: <class>OcuPilot.Test.RegistryCacheProbe.Registry</class> whose compile signature can
/// never be read, so <class>OcuPilot.Test.RegistryCache</class> can pin what the tool listing does
/// when the class dictionary query fails.</p>
Class OcuPilot.Test.RegistryCacheProbe.UnreadableRegistry Extends OcuPilot.Test.RegistryCacheProbe.Registry
{

ClassMethod CompileSignature(Output pSignature As %String) As %Status [ Private ]
{
    Set pSignature = ""
    Quit $$$ERROR($$$GeneralError, "the compile signature cannot be read")
}

}
