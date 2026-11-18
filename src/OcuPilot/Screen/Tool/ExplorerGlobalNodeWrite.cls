/// <p>What the node tools share (Story 21.5, AD-53): the node page's <code>save</code> and <code>delete</code>, each a person's alone and
/// so unadvertised. The target is the node's canonical reference (entity type <code>global-node</code>), the port's
/// <parameter>OcuPilot.Port.GlobalPort.REFERENCEKEY</parameter>; the fresh read is the port's node <code>GET</code>.</p>
/// <p><b>Its pairs</b> are the node page's, then the custom resource of the classic edit page, <code>%cspapp.exp.utilexpglobaldrill</code>.</p>
Class OcuPilot.Screen.Tool.ExplorerGlobalNodeWrite Extends OcuPilot.Screen.Tool.ExplorerGlobalWrite [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerGlobalView";

/// <p>Reached by a person's confirmed action alone (AD-53).</p>
Parameter ADVERTISED As BOOLEAN = 0;

Parameter READTYPE = "GET";

Parameter READANSWERS = "Reference,Value,Defined,Editable,Location,Namespace";

/// <p>The classic page whose operation the node tools perform beyond the node page's own (AD-44).</p>
Parameter CLASSICPAGES = "%cspapp.exp.utilexpglobaldrill";

/// <p>The endpoint the node is read and written through.</p>
ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.GlobalPort).#ENDPOINTNODE
}

/// <p>The node's canonical reference.</p>
ClassMethod IdArgument() As %String
{
    Quit "Reference"
}

/// <p>The query key the port reads the reference from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.GlobalPort).#REFERENCEKEY
}

/// <p>A reference that is not canonical, refused as the port refuses it (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = $Select(##class(OcuPilot.Port.GlobalPort).ParseReference(pIdValue, .tName, .tRebuilt): "", 1: ##class(OcuPilot.Port.GlobalPort).#REASONREFERENCE)
    Quit $$$OK
}

}
