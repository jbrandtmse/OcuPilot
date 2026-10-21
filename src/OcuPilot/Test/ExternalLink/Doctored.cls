/// <p>Fixture descriptor whose declaration is whatever the running test armed in <parameter>GLOBALNAME</parameter>, so
/// <method>OcuPilot.Screen.Registry.Validate</method>'s refusal of an <code>external</code> screen (AD-44, Story 20.32) can be
/// demonstrated over a real roster for each doctored shape rather than only over values. It lives in a package of its own with
/// <class>OcuPilot.Test.ExternalLinkRegistry</class>, for the reason <class>OcuPilot.Test.ClassicLink.Bad</class> does: Validate reports the
/// first problem it meets, so the roster carries exactly this one descriptor.</p>
/// <p>Nothing armed is a failing status, never an empty declaration. The armed text is process-private, so it never reaches another
/// process, and the declaration cache is dropped by <method>OcuPilot.Screen.Descriptor.Base.ForgetDeclaration</method> between shapes.</p>
Class OcuPilot.Test.ExternalLink.Doctored Extends OcuPilot.Screen.Descriptor.Base
{

/// <p>The process-private global, without its <code>^||</code>, holding the declaration's JSON text.</p>
Parameter GLOBALNAME = "OcuPilotExternalLinkDeclaration";

ClassMethod DeclarationJson(Output pObject As %DynamicObject) As %Status
{
    Set pObject = ""
    Set tName = "^||" _ ..#GLOBALNAME
    Set tText = $Get(@tName)
    If tText = "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ExternalLink.Doctored: no declaration is armed in " _ tName)
    Set pObject = ##class(%DynamicAbstractObject).%FromJSON(tText)
    Quit $$$OK
}

/// <p>Arm <var>pDeclaration</var>, a <class>%DynamicObject</class>, as this fixture's declaration, and forget the cached parse.</p>
ClassMethod Arm(pDeclaration As %DynamicObject)
{
    Set tName = "^||" _ ..#GLOBALNAME
    Set @tName = pDeclaration.%ToJSON()
    Do ..ForgetDeclaration()
}

/// <p>Disarm the fixture and forget the cached parse.</p>
ClassMethod Disarm()
{
    Set tName = "^||" _ ..#GLOBALNAME
    Kill @tName
    Do ..ForgetDeclaration()
}

}
