/// <p>Test-only <class>OcuPilot.Kernel.Secret.Ladder</class> subclass that answers a value the test
/// set, instead of reading an environment variable.</p>
/// <p>It exists so the credential-bearing paths can be driven without setting an environment
/// variable on the instance -- which a running IRIS cannot be made to do per process anyway -- and
/// so that AC6's canary is a value this suite chose rather than anything real.</p>
/// <p>Two seams are replaced -- <method>Environment</method> and
/// <method>CredentialsRungAvailable</method> -- and nothing else. <method>Resolve</method>, the
/// credential type test, the XOR name selection above it, <method>Credential</method> and
/// <method>Store</method> are the shipped ones, so a value this subclass answers travels the path a
/// real one would and the credentials rung reads and writes the real store. The
/// <code>$Char(0)</code> normalization is <b>inside</b> the replaced environment method and is
/// therefore not exercised from here: a running IRIS cannot be made to hand one process a different
/// environment, which is the reason that seam exists at all.</p>
Class OcuPilot.Test.SecretProbe Extends OcuPilot.Kernel.Secret.Ladder
{

/// <p>Answer <var>pValue</var> for every environment variable name from now on.</p>
ClassMethod SetValue(pValue As %String)
{
    Set ^||OcuPilotSecretProbe("value") = pValue
}

/// <p>Answer the credentials-rung availability predicate with <var>pState</var> from now on:
/// <code>1</code>, <code>0</code>, or <code>raise</code> to make it throw. Anything else, including
/// the unset state <method>Clear</method> leaves, falls through to the shipped predicate.</p>
/// <p><b><code>raise</code> is what makes "the <code>env</code> arm consults no rung predicate"
/// falsifiable from one namespace.</b> An arm that merely ignored a <code>0</code> answer and an arm
/// that never asked are the same observation; an arm that would have thrown is not.</p>
ClassMethod SetRungAvailable(pState As %String)
{
    Set ^||OcuPilotSecretProbe("rung") = pState
}

/// <p>Answer <code>""</code> for every name -- an unresolved reference -- and forget every
/// switch.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotSecretProbe
}

/// <p>The value the test set, whatever name is asked for.</p>
ClassMethod Environment(pName As %String) As %String
{
    Quit $Get(^||OcuPilotSecretProbe("value"))
}

/// <p>Capture the message and the composed line
/// <method>OcuPilot.Kernel.Secret.Ladder.Store</method> would have logged, instead of writing it.
/// The line is built by the <b>shipped</b>
/// <method>OcuPilot.Kernel.Secret.Ladder.LogReason</method>, so what a test reads back is
/// production's composition and not a copy of it.</p>
ClassMethod LogCodes(pMessage As %String, pStatus As %Status)
{
    Set ^||OcuPilotSecretProbe("logMessage") = pMessage
    Set ^||OcuPilotSecretProbe("logReason") = ..LogReason(pStatus)
}

/// <p>One captured field of the last <method>LogCodes</method> call, or <code>""</code> when the
/// run made none -- which is itself a failure signal for a test that expected one.</p>
/// @param pField One of "logMessage", "logReason"
ClassMethod CapturedLog(pField As %String) As %String
{
    Quit $Get(^||OcuPilotSecretProbe(pField), "")
}

/// <p>The switched availability answer, or the shipped predicate when no test set one.</p>
ClassMethod CredentialsRungAvailable() As %Boolean
{
    Set tState = $Get(^||OcuPilotSecretProbe("rung"))
    If tState = "raise" {
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "OcuPilot.Test.SecretProbe: the credentials-rung predicate was asked and this probe is armed to raise"))
    }
    If (tState '= 0) && (tState '= 1) Quit ##super()
    Quit ''+tState
}

}
