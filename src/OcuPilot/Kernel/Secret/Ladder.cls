/// <p>The credential ladder (AD-42): a definition's stored credential <i>reference</i> resolved to
/// the secret itself.</p>
/// <p><b>It returns a <class>%String</class>, never a <class>%Status</class>, and that is the
/// point.</b> A status carries text, and text written from a failed resolution is text that names
/// what it was resolving -- which on this path is a credential. So there is one answer,
/// <code>""</code> for unresolved, and the caller turns that into
/// <code>PROVIDER.CREDENTIAL</code> naming the reference. Nothing here builds a message, and
/// nothing here writes to a log (AD-35).</p>
/// <p><b>This story implements the environment-variable rung only.</b> <code>creds</code> answers
/// <code>""</code>, so a definition configured for the credentials rung refuses before any call is
/// made rather than sending an empty key. Story 3.3 replaces this body with the full ladder, adds
/// the interoperability-namespace condition the credentials rung needs, and owns DW-22's flagging
/// of a definition whose reference no longer resolves. <b>Nothing in the port changes when it
/// does</b>: the port asks this class through an overridable seam and reads one string.</p>
Class OcuPilot.Kernel.Secret.Ladder Extends %RegisteredObject
{

/// <p>The secret <var>pCredType</var> and its reference name resolve to, or <code>""</code>.</p>
/// <p><var>pEnvVarName</var> is read for <code>env</code> and <var>pCredentialName</var> for
/// <code>creds</code>; the XOR invariant
/// (<method>OcuPilot.Kernel.AgentRules.Normalize</method>) has already cleared whichever the type
/// did not select, so only one of them is ever populated.</p>
/// <p><b>Caller contract:</b> assign the result straight onto the holder that will use it --
/// <property>OcuPilot.Kernel.Provider.Base.ApiKey</property> -- and never into a local. An
/// <code>^%ETN</code> entry captures every local at every stack level (AD-48), and OcuPilot
/// renders that log (AD-35, AD-46).</p>
/// <p><code>$Char(0)</code> is normalized to <code>""</code>: an environment variable set to the
/// empty string reads back as the one-character sentinel on some paths, which every ordinary
/// emptiness guard passes.</p>
ClassMethod Resolve(pCredType As %String, pEnvVarName As %String = "", pCredentialName As %String = "") As %String
{
    If pCredType '= ##class(OcuPilot.Kernel.AgentRules).#CREDTYPEENV Quit ""
    If pEnvVarName = "" Quit ""
    Quit ..Environment(pEnvVarName)
}

/// <p>One environment variable's value, or <code>""</code>. The single seam a test overrides to
/// put a canary in play without setting a variable on the instance; production never overrides
/// it.</p>
/// <p>Read twice rather than held in a local: the value is the secret, and a frame that holds it
/// in a local is a frame whose symbol table an <code>^%ETN</code> entry would capture (AD-48).</p>
ClassMethod Environment(pName As %String) As %String
{
    If $System.Util.GetEnviron(pName) = $Char(0) Quit ""
    Quit $System.Util.GetEnviron(pName)
}

}
