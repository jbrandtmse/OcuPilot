/// <p>Test-only <class>OcuPilot.Kernel.Secret.Ladder</class> subclass that answers a value the test
/// set, instead of reading an environment variable.</p>
/// <p>It exists so the credential-bearing paths can be driven without setting an environment
/// variable on the instance -- which a running IRIS cannot be made to do per process anyway -- and
/// so that AC6's canary is a value this suite chose rather than anything real.</p>
/// <p>Only <method>Environment</method> is replaced. The credential type test, the XOR selection
/// and the <code>$Char(0)</code> normalization above it are the shipped ones, so a value this
/// subclass answers travels the path a real one would.</p>
Class OcuPilot.Test.SecretProbe Extends OcuPilot.Kernel.Secret.Ladder
{

/// <p>Answer <var>pValue</var> for every environment variable name from now on.</p>
ClassMethod SetValue(pValue As %String)
{
    Set ^||OcuPilotSecretProbe("value") = pValue
}

/// <p>Answer <code>""</code> for every name -- an unresolved reference.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotSecretProbe
}

/// <p>The value the test set, whatever name is asked for.</p>
ClassMethod Environment(pName As %String) As %String
{
    Quit $Get(^||OcuPilotSecretProbe("value"))
}

}
