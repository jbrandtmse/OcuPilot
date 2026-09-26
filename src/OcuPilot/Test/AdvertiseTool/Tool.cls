/// <p>Fixture: one read tool whose declarations a test switches (<method>SetMode</method>), so
/// <class>OcuPilot.Test.AdvertiseTool.Registry</class>'s advertised list can be refused one way at a
/// time: <code>subset</code> declares an input schema the validator admits and the emitted subset does
/// not (a top-level <code>description</code>), <code>nodescription</code> declares no description,
/// <code>noresult</code> declares no result schema, and <code>""</code> declares all of them well.</p>
/// <p>State lives in <code>^||OcuPilotAdvertiseTool</code>; <code>SetMode("")</code> forgets it.</p>
Class OcuPilot.Test.AdvertiseTool.Tool Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "probe.advertise.read";

Parameter KIND = "read";

Parameter DESCRIPTION = "A fixture read tool whose declarations a test switches.";

ClassMethod SetMode(pMode As %String)
{
    Kill ^||OcuPilotAdvertiseTool
    If pMode '= "" Set ^||OcuPilotAdvertiseTool("mode") = pMode
}

ClassMethod Mode() As %String
{
    Quit $Get(^||OcuPilotAdvertiseTool("mode"))
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {"marker": {"type": "string", "maxLength": 8}}, "required": [], "additionalProperties": false}
    If ..Mode() = "subset" Do tSchema.%Set("description", "a top-level description the emitted subset refuses", "string")
    Quit tSchema
}

/// <p>Declared: none (AD-3). Fixture.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    If ..Mode() = "noresult" Quit ""
    Quit {"type": "object", "properties": {"marker": {"type": "string"}}, "required": ["marker"], "additionalProperties": false}
}

ClassMethod Description(pDescriptor As %String = "") As %String
{
    If ..Mode() = "nodescription" Quit ""
    Quit ..#DESCRIPTION
}

ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = {"marker": ""}
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

}
