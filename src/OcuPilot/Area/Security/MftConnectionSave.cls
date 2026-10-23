/// <p>The managed file transfer connection editor's Save (AD-55, Story 18.26): <code>POST /mft-connection</code>
/// creates one connection through <class>OcuPilot.Screen.Tool.MftConnectionCreate</class>, and <code>PUT
/// /mft-connection/:id</code> changes one through <class>OcuPilot.Screen.Tool.MftConnectionUpdate</class>, the tools
/// the agent's mint and confirm read. It is <class>OcuPilot.Kernel.Proposal.ScreenSave</class> over the rules of
/// <class>OcuPilot.Area.Security.MftConnectionRules</class>. The delete and the token revoke are row actions
/// (<class>OcuPilot.Screen.Tool.MftConnectionDelete</class>, <class>OcuPilot.Screen.Tool.MftConnectionRevoke</class>)
/// and have no route here.</p>
/// <p>A connection is addressed by its name, as written, and the answer is <code>{id, readBack}</code>. <b>No edit
/// carries <code>Service</code></b>: it is not a field the update tool admits, and a body that names it is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>.</p>
Class OcuPilot.Area.Security.MftConnectionSave Extends OcuPilot.Kernel.Proposal.ScreenSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.MftConnectionCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.MftConnectionUpdate";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.MftConnectionForm";

Parameter RULES = "OcuPilot.Area.Security.MftConnectionRules";

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
    Quit "connection"
}

}
