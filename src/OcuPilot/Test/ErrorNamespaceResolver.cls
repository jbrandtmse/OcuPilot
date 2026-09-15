/// <p>Test-only <class>OcuPilot.Api.Namespaces</class> subclass whose
/// <method>GlobalDatabase</method> answers 0 for every namespace -- the shape the instance reports
/// when it holds no guarding resource for a namespace's globals database.</p>
/// <p>That answer is the one that must not be read as "no privilege required"
/// (<class>OcuPilot.Api.Namespaces</class> `:80-83`). The port turns it into an empty pair set and
/// refuses; without this fixture the branch is unreachable, because every namespace on this
/// instance resolves to a <code>%DB_*</code> resource. It is a subclass rather than a stand-alone
/// class so every other method the port might reach through
/// <method>OcuPilot.Port.LogSourcePort.NamespaceResolver</method> still answers for real.</p>
/// <p>Nothing here writes to the instance, and the fixture is reached only through the port's
/// resolver seam.</p>
Class OcuPilot.Test.ErrorNamespaceResolver Extends OcuPilot.Api.Namespaces
{

ClassMethod GlobalDatabase(pNamespace As %String, Output pResource As %String, Output pReadOnly As %Boolean) As %Boolean
{
    Set pResource = ""
    Set pReadOnly = 0
    Quit 0
}

}
