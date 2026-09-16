/// <p>Test-only <class>OcuPilot.Screen.Gate</class> subclass whose single privilege consultation
/// answers from a switch instead of from the instance.</p>
/// <p>It exists because <code>%UnitTest</code> runs as an account holding <code>%All</code>, for
/// which the real <code>$System.Security.Check</code> answers yes to every resource name --
/// including one the instance does not define. A denial cannot be driven in process any other way,
/// and <class>OcuPilot.Port.ProviderPort</class>'s draft gate has a denial that has to be
/// observable. The real check is exercised over the wire by the suite's own wire classes.</p>
/// <p>Only <method>HoldsPrivilege</method> is replaced, so the set semantics the port depends on
/// -- every pair required, the first failure named -- are the shipped ones.</p>
Class OcuPilot.Test.ProviderGate Extends OcuPilot.Screen.Gate
{

/// <p>Answer every privilege question with no, so the next gate evaluation refuses and names its
/// first pair.</p>
ClassMethod Deny()
{
    Set ^||OcuPilotProviderGate("deny") = 1
}

/// <p>Answer every privilege question with yes, which is what an unset switch already does.</p>
ClassMethod Allow()
{
    Kill ^||OcuPilotProviderGate
}

/// <p>The switch, in place of the instance's own answer.</p>
ClassMethod HoldsPrivilege(pResource As %String, pPermission As %String) As %Boolean
{
    Quit '+$Get(^||OcuPilotProviderGate("deny"))
}

}
