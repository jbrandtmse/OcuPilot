/// <p>Test-only stand-in for <class>%Library.EnsembleMgr</class> that answers
/// <method>IsEnsembleNamespace</method> 0.</p>
/// <p>It exists so <class>OcuPilot.Test.SecretNotInterop</class> can put the rung predicate's
/// second condition in the state no namespace this suite runs on produces: the credential class
/// compiled and reachable, and the namespace not interoperability-enabled. The predicate reaches
/// this class by the same <code>$ClassMethod</code> dispatch it reaches the real one by, so the
/// shipped code path is unchanged.</p>
Class OcuPilot.Test.NotEnsembleNamespace Extends %RegisteredObject
{

/// <p>Always 0 -- this class is the "not interoperability-enabled" answer.</p>
ClassMethod IsEnsembleNamespace(pNamespace As %String = "") As %Boolean
{
    Quit 0
}

}
