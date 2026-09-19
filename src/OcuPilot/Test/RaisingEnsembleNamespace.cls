/// <p>Test-only stand-in for <class>%Library.EnsembleMgr</class> whose
/// <method>IsEnsembleNamespace</method> raises.</p>
/// <p>It exists so <class>OcuPilot.Test.SecretRaisingRung</class> can make the rung predicate raise
/// <b>inside its own <code>Try</code></b>, which is where a real failure of that check lands: the
/// predicate's <code>Catch</code> answers 0, and the ladder must read that 0 as a store it could
/// not read rather than as an absent entry.</p>
Class OcuPilot.Test.RaisingEnsembleNamespace Extends %RegisteredObject
{

/// <p>Always raises.</p>
ClassMethod IsEnsembleNamespace(pNamespace As %String = "") As %Boolean
{
    Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "OcuPilot.Test.RaisingEnsembleNamespace: the interoperability check raised"))
    Quit 0
}

}
