/// <p>The mobile phone provider editor's Save (AD-55, Story 21.10): <code>POST /phone-provider</code> creates one
/// provider through <class>OcuPilot.Screen.Tool.PhoneProviderCreate</class>, and <code>PUT /phone-provider/:id</code>
/// changes one through <class>OcuPilot.Screen.Tool.PhoneProviderUpdate</class>, the tools the agent's mint and confirm
/// read. It is <class>OcuPilot.Kernel.Proposal.ScreenSave</class> over the rules of
/// <class>OcuPilot.Area.Security.PhoneProviderRules</class>. The delete is a row action
/// (<class>OcuPilot.Screen.Tool.PhoneProviderDelete</class>) and has no route here.</p>
/// <p>A provider is addressed by its name, exactly as written, and the answer is <code>{id, readBack}</code>. <b>No edit
/// carries <code>Name</code></b>: it is not a field the update tool admits, and a body that names it is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>.</p>
Class OcuPilot.Area.Security.PhoneProviderSave Extends OcuPilot.Kernel.Proposal.ScreenSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.PhoneProviderCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.PhoneProviderUpdate";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.PhoneProviderForm";

Parameter RULES = "OcuPilot.Area.Security.PhoneProviderRules";

/// <p>The create body's identifying member, which is not a setting.</p>
Parameter NAMEMEMBER = "Name";

ClassMethod IdentityMembers() As %List
{
    Quit $ListBuild(..#NAMEMEMBER)
}

/// <p>The identity is <code>$ListBuild(name)</code>, and the name is the id. A name that is not text is a
/// <parameter>OcuPilot.Api.Error.PORTFIELDSHAPE</parameter> violation.</p>
ClassMethod CreateIdentity(pBody As %DynamicObject, Output pId As %String, Output pParts As %List, ByRef pShape)
{
    Set tName = ""
    Set tType = pBody.%GetTypeOf(..#NAMEMEMBER)
    If tType = "string" Set tName = pBody.%Get(..#NAMEMEMBER)
    If (tType '= "string") && (tType '= "unassigned") Do ..Add(.pShape, ..#NAMEMEMBER, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
    Set pParts = $ListBuild(tName)
    Set pId = tName
}

ClassMethod Subject() As %String
{
    Quit "provider"
}

}
