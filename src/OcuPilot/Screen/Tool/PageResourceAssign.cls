/// <p>Page resources' Assign and Change (AD-51, AD-53, AD-64, Story 21.37): set the custom resource of one classic page, which the classic portal and
/// every OcuPilot screen that declares the page then require (<class>OcuPilot.Screen.Gate</class>). <class>OcuPilot.Port.PortalResourcePort</class>
/// refuses a page the classic portal does not have, an empty resource and a resource this instance does not define, before anything is stored, and records
/// <code>SecurityChange</code> for an accepted write. The list's Assign and Change dialogs send the resource as <parameter>ARGUMENT</parameter>.</p>
/// <p><b>A page a Home or Agent co-pilot screen declares is refused</b> as <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTSCREEN</parameter> before a proposal is stored
/// (<method>RefusedBeforeState</method>) and again at the write by the prohibited set, so neither caller can reach it.</p>
Class OcuPilot.Screen.Tool.PageResourceAssign Extends OcuPilot.Screen.Tool.PageResourceAction
{

Parameter TOOLNAME = "permissions.pageresources.assign";

Parameter DESCRIPTION = "Propose assigning a custom resource to a classic portal page, or changing the one it has: the classic portal and the OcuPilot screens that follow the page then require that resource. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the page by its class, as the Page resources list reports it, and the resource by the name this instance defines it under. A page that is not a page of the classic portal, a resource this instance does not define and a page one of OcuPilot's Home or Agent screens follows are refused.";

/// <p>The list's row action Change, whose one value is the resource. The route carries row actions alone, so the primary Assign, which the client
/// registers, sends this action with the page it was typed.</p>
Parameter SCREENACTIONS = "change";

Parameter SCREENVALUES = "change=Resource";

/// <p>An empty resource reaches the port, which refuses it with its own sentence on the field.</p>
Parameter SCREENEMPTY = "change=Resource";

/// <p>The port query carries the resource, so the read-back compares it with the page's resource read again.</p>
Parameter READBACKPAYLOAD As BOOLEAN = 1;

/// <p>The one argument: the resource to assign.</p>
Parameter ARGUMENT = "Resource";

ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#ARGUMENT)
}

/// <p>The identifying property described, and <parameter>ARGUMENT</parameter> added, required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Do tSchema.%Get("properties").%Set(..#ARGUMENT, {"type": "string", "description": "The resource to assign, a resource this instance defines, such as %Admin_Secure. A name this instance does not define is refused."})
    Do tSchema.%Get("required").%Push(..#ARGUMENT)
    Quit tSchema
}

/// <p>The resource under the port's resource key, from the call's arguments or the stored payload.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#ARGUMENT) '= "string" Quit
    Set pQuery(##class(OcuPilot.Port.PortalResourcePort).#RESOURCEPARAM) = pPayload.%Get(..#ARGUMENT)
}

/// <p>A page a screen that cannot be adjusted declares is refused as <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTSCREEN</parameter> before the page is read (AD-10), so the
/// screen's action and the agent's mint answer 403.</p>
ClassMethod RefusedBeforeState(pIdValue As %String, Output pCode As %String) As %Boolean
{
    Quit ##class(OcuPilot.Kernel.Proposal.Prohibited).RefusesPageAssignment(pIdValue, $ClassName(), .pCode)
}

/// <p>The row naming the screens that follow the page; the resource row comes from the call's own argument.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set pRows = ..ScreenRows(pFresh)
    Quit $$$OK
}

/// <p>The card's title: a change of the resource the page holds, or an assignment to a page that holds none.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If '$IsObject(pArgs) || (pArgs.%GetTypeOf(..#ARGUMENT) '= "string") Quit ""
    Set tHolds = ($IsObject(pFresh) && (pFresh.%GetTypeOf("Current") = "string") && (pFresh.%Get("Current") '= ""))
    Quit ..Summary($Select(tHolds: ..#SUMMARYCHANGE, 1: ..#SUMMARYASSIGN), ..PageOf(pFresh, pId), pArgs.%Get(..#ARGUMENT))
}

/// <p>The dialog's resource as this tool's argument; the port judges it.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..#ARGUMENT) = "string") Do pArgs.%Set(..#ARGUMENT, pValues.%Get(..#ARGUMENT), "string")
    Quit $$$OK
}

}
