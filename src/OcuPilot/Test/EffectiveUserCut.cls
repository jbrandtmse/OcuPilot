/// <p>The Effective privileges view with its composition read cut at the cap (Story 16.3):
/// <method>EffectiveRead</method> answers <code>truncated</code> and nothing else, so
/// <class>OcuPilot.Test.EffectiveUser</class> can pin that every section then reads unchecked.</p>
Class OcuPilot.Test.EffectiveUserCut Extends OcuPilot.Kernel.Shell.EffectiveUser
{

ClassMethod EffectiveRead(pRoots As %DynamicArray, Output pRoleRows As %DynamicObject, Output pPublic As %DynamicObject, Output pUnchecked As %String) As %Status
{
    Set pRoleRows = {}
    Set pPublic = {}
    Set pUnchecked = ##class(OcuPilot.Kernel.Shell.Effective).#TRUNCATED
    Quit $$$OK
}

}
