/// <p>Test-only <class>OcuPilot.Screen.Gate</class> subclass. It overrides the gate's two seams
/// so the set semantics can be driven in process:</p>
/// <ul>
/// <li><method>HoldsPrivilege</method> answers from a declared set instead of the instance.
/// <code>%UnitTest</code> runs as an account holding <code>%All</code>, for which the real
/// <code>$System.Security.Check</code> answers yes to every resource name -- including one the
/// instance does not define -- so no in-process denial can be observed against it. The real
/// check is exercised over the wire by <class>OcuPilot.Test.Wire</class>, as a throwaway
/// principal holding exactly one administrative resource.</li>
/// <li><method>ClassicResource</method> answers from a declared map instead of
/// <class>%SYS.Portal.Resources</class>, so the classic-page union is exercised without ever
/// writing a custom resource to the instance. That store is empty here and stays so; its write
/// path is an operator's, not a test's.</li>
/// </ul>
/// <p>Both answers live in process-private globals, cleared by <method>Reset</method>, so
/// nothing survives the process that armed it. Their subscripts follow identifier rules -- no
/// hyphens -- because a process-private subscript that is not an identifier parses as an
/// expression.</p>
Class OcuPilot.Test.ScreenGate Extends OcuPilot.Screen.Gate
{

/// <p>Forget every armed answer. Called before each test that arms one.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotGateHeld
    Kill ^||OcuPilotGateClassic
}

/// <p>Declare that the caller holds <var>pResource</var> at <var>pPermission</var>. Anything
/// not armed is not held, so a test states what the principal has rather than what it
/// lacks.</p>
ClassMethod Hold(pResource As %String, pPermission As %String)
{
    Set ^||OcuPilotGateHeld(pResource, pPermission) = 1
}

/// <p>Declare that an operator has assigned <var>pResource</var> to the classic page
/// <var>pPageClass</var>.</p>
ClassMethod AssignClassic(pPageClass As %String, pResource As %String)
{
    Set ^||OcuPilotGateClassic(pPageClass) = pResource
}

ClassMethod HoldsPrivilege(pResource As %String, pPermission As %String) As %Boolean
{
    Quit ''$Get(^||OcuPilotGateHeld(pResource, pPermission), 0)
}

ClassMethod ClassicResource(pPageClass As %String) As %String
{
    If pPageClass = "" Quit ""
    Quit $Get(^||OcuPilotGateClassic(pPageClass), "")
}

}
