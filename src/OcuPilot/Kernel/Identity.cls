/// <p>Whether an authenticating account may still be served (AD-8 as amended 2026-09-19, DW-444).
/// The instance keeps honouring a disabled account's access token and keeps minting pairs for its
/// refresh token, so an account an administrator disabled otherwise keeps full OcuPilot access
/// until its pair lapses. This is the policy face of the one identity read that closes that.</p>
/// <p><b>It does not escalate.</b> The escalation is
/// <method>OcuPilot.Kernel.State.Base.GuardedUserEnabled</method>'s, behind its own privileged
/// routine application, because <file>scripts/check-objectscript.py</file> confines every
/// <code>New $ROLES</code> in the tree to that file. What lives here is the decision an
/// unreadable flag forces, which is a policy question and not a storage one.</p>
Class OcuPilot.Kernel.Identity Extends %RegisteredObject
{

/// <p>Machine code (AD-12, AD-39) for a caller whose IRIS account is disabled. Declared here
/// rather than on <class>OcuPilot.Api.Error</class>, which validates a code by shape and so needs
/// no edit to render one.</p>
Parameter AUTHDISABLED = "AUTH.DISABLED";

/// <p>The written sentence the refusal carries.</p>
Parameter REASONDISABLED = "This account is disabled on this instance.";

/// <p>The sentence carried when the identity escalation itself could not be entered. It names
/// the repair, because waiting never helps: the privileged routine application
/// <parameter>OcuPilot.Kernel.State.Base.IDENTITYAPPLICATION</parameter> and its role are
/// install-created objects, and running install again recreates or repairs them.</p>
Parameter REASONUNAVAILABLE = "OcuPilot cannot read this instance's account state; waiting will not help, and an administrator needs to run install again";

/// <p>The store the enabled flag is read through. Overridable so a fixture can drive the
/// unreadable-flag branch, which no instance produces on demand; production never overrides
/// it.</p>
ClassMethod StateClass() As %String
{
    Quit "OcuPilot.Kernel.State.Base"
}

/// <p>Whether <var>pUserName</var> may be served: 1 only when the instance reported the account
/// enabled.</p>
/// <p><b>An unreadable flag is a refusal, not an admission.</b> A read that answered nothing says
/// nothing about whether the account is enabled, and admitting on it would make every failure of
/// the identity escalation a silent reopening of the hole this closes.</p>
/// <p><b>Refusing and blaming the caller are two decisions, and only the first is this class's.</b>
/// <var>pUnavailable</var> is 1 when the escalation could not be entered at all, which refuses
/// every account on the instance and is a fault in OcuPilot's own install rather than in any
/// account. A caller that renders it as <code>AUTH.DISABLED</code> tells every user their account
/// was disabled and names no repair; <class>OcuPilot.Api.Router</class> renders it as AD-38's
/// <code>unreadable</code> answer instead.</p>
ClassMethod IsEnabled(pUserName As %String, Output pUnavailable As %Boolean) As %Boolean
{
    Set pUnavailable = 0
    Set tEnabled = 0
    Try {
        Set tEnabled = $ClassMethod(..StateClass(), "GuardedUserEnabled", pUserName, .tKnown, .tUnavailable)
        Set pUnavailable = ''+$Get(tUnavailable)
        If '+$Get(tKnown) Set tEnabled = 0
    } Catch ex {
        Set tEnabled = 0
        Set pUnavailable = 1
    }
    Quit tEnabled
}

}
