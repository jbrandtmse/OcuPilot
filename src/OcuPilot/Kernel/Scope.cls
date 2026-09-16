/// <p>The request's resolved namespace, carried as a value (AD-44). <method>OcuPilot.Api.Router.OnPreDispatch</method>
/// resolves <code>?ns=</code> once, checks that the caller may enter it, and stashes it here;
/// every handler that needs the scope a request was made in reads <method>Current</method>
/// rather than <code>$Namespace</code>, which reports where the code is executing and not what
/// the route asked for.</p>
/// <p><b>This is the route's scope, and only the route's.</b> A port whose namespace is the
/// level the user has drilled to takes it as an explicit call parameter from the screen's
/// descriptor state and must not read this stash (AD-48): two sources would let a compliant
/// delete purge a namespace other than the one on screen.</p>
/// <p>Backed by a process-private global holding a string. What keeps one request's scope out of
/// the next on a reused process is <method>OcuPilot.Api.Router.OnPreDispatch</method> clearing it
/// before it resolves anything -- which also means a request refused before the namespace gate
/// leaves nothing behind. The node is a scalar, so <method>Set</method> simply replaces it.</p>
Class OcuPilot.Kernel.Scope Extends %RegisteredObject
{

/// <p>The literal scope of a configuration object that has no namespace (AD-13). A descriptor
/// declares it, <method>OcuPilot.Kernel.EntityRef.ScopeFor</method> resolves to it, and
/// <method>OcuPilot.Screen.Registry.Validate</method> refuses anything that is neither this nor
/// <parameter>SCOPENAMESPACE</parameter>.</p>
Parameter SCOPEINSTANCE = "instance";

/// <p>The declared scope of a namespace-scoped screen (AD-5, AD-13). Spelled here so the two
/// values the declaration admits have one home rather than a literal per reader.</p>
Parameter SCOPENAMESPACE = "namespace";

/// <p>Stash <var>pNamespace</var> as this request's resolved scope.</p>
ClassMethod Set(pNamespace As %String)
{
    Set ^||OcuPilotScope = pNamespace
}

/// <p>This request's resolved scope, falling back to <code>$Namespace</code> when nothing has
/// been stashed -- a code path reached outside a request (an install step, a test) still gets
/// the namespace it is executing in rather than an empty string.</p>
ClassMethod Current() As %String
{
    Set tValue = $Get(^||OcuPilotScope)
    If tValue = "" Quit $Namespace
    Quit tValue
}

/// <p>Forget the stash, so <method>Current</method> falls back again.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotScope
}

}
