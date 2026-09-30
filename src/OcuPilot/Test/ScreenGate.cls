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
/// writing a custom resource to the instance. The one test that writes the store is
/// <class>OcuPilot.Test.ClassicPageGate</class>, on a throwaway only, and it restores each page it
/// assigns.</li>
/// <li><method>ListedScreens</method> answers an armed roster for an area instead of the registry's,
/// or an armed failure, so an area's verdict can be driven over a roster the shipped descriptors do
/// not form. <method>TabMembers</method> answers an armed failure for a tab group's head the same
/// way.</li>
/// </ul>
/// <p>Every answer lives in process-private globals, cleared by <method>Reset</method>, so
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
    Kill ^||OcuPilotGateListed
    Kill ^||OcuPilotGateListedFails
    Kill ^||OcuPilotGateTabsFail
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

/// <p>Declare the descriptor classes <var>pAreaKey</var>'s side bar lists, comma-separated, in
/// side-bar order; <code>""</code> declares an area that lists none.</p>
ClassMethod ArmListed(pAreaKey As %String, pClasses As %String)
{
    Set ^||OcuPilotGateListed(pAreaKey) = $Select(pClasses = "": "", 1: $ListFromString(pClasses))
}

/// <p>Declare that reading <var>pAreaKey</var>'s side-bar roster fails.</p>
ClassMethod ArmListedFailure(pAreaKey As %String)
{
    Set ^||OcuPilotGateListedFails(pAreaKey) = 1
}

/// <p>Declare that reading the tabs of the group <var>pDescriptor</var> heads fails.</p>
ClassMethod ArmTabMembersFailure(pDescriptor As %String)
{
    Set ^||OcuPilotGateTabsFail(pDescriptor) = 1
}

ClassMethod TabMembers(pDescriptor As %String, Output pList As %List) As %Status
{
    Set pList = ""
    If $Get(^||OcuPilotGateTabsFail(pDescriptor)) Quit $$$ERROR($$$GeneralError, "armed tab roster failure for " _ pDescriptor)
    Quit ##class(OcuPilot.Screen.Registry).TabMembersFor(pDescriptor, .pList)
}

ClassMethod ListedScreens(pAreaKey As %String, Output pList As %List) As %Status
{
    Set pList = ""
    If $Get(^||OcuPilotGateListedFails(pAreaKey)) Quit $$$ERROR($$$GeneralError, "armed roster failure for " _ pAreaKey)
    If $Data(^||OcuPilotGateListed(pAreaKey)) {
        Set pList = ^||OcuPilotGateListed(pAreaKey)
        Quit $$$OK
    }
    Quit ##class(OcuPilot.Screen.Registry).ListedScreensForArea(pAreaKey, .pList)
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
