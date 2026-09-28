/// <p>The permission check with its composition read cut at the cap (Story 16.3):
/// <method>EffectiveRead</method> answers <code>truncated</code> and nothing else, so
/// <class>OcuPilot.Test.PermissionCheck</class> can pin that a cut read is refused rather than
/// answered no. Outside the tool registry's package, so it is never advertised.</p>
Class OcuPilot.Test.PermissionCheckCut Extends OcuPilot.Kernel.Shell.PermissionCheck
{

ClassMethod EffectiveRead(pRoots As %DynamicArray, Output pRoleRows As %DynamicObject, Output pPublic As %DynamicObject, Output pUnchecked As %String) As %Status
{
    Set pRoleRows = {}
    Set pPublic = {}
    Set pUnchecked = ##class(OcuPilot.Kernel.Shell.Effective).#TRUNCATED
    Quit $$$OK
}

}
