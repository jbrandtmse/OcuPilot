/// <p>Analytics' quality measure element add (AD-3, AD-6, AD-54, AD-55, AD-61, AD-65, Story 24.12): add one element to a group of a quality measure of the request's namespace, creating the
/// group when the measure lacks it. Two callers reach it: the Groups and elements screen's Add element dialog through <class>OcuPilot.Area.Analytics.QualityMeasureElementSave</class>, and
/// the agent's proposal and confirmation.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no element of that name in the group, and a name added since the mint closes the proposal target-changed. A measure that is not there is
/// <code>ANALYTICS.QUALITYMEASURE.ABSENT</code>. The group fields sent with the element (<code>GroupCaption</code>, <code>GroupDescription</code>, <code>GroupDisabled</code>) set the group
/// it names, a new one or an existing one. The measure's class is saved and compiled. Its fields are declared here (<method>FieldRows</method>, AD-3), and its read-back compares each
/// (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementAdd Extends OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementAction
{

Parameter TOOLNAME = "analytics.qualitymeasureelements.add";

Parameter DESCRIPTION = "Propose adding one element (an MDX expression) to a group of a quality measure of the namespace the user is working in. A group the measure does not hold is created with the element. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the measure as the Quality measures list reports it, the group, the new element's name, and optionally its caption, MDX and disabled flag, and the group's caption, description and disabled flag. The measure's class is saved and compiled, and a failed compile puts the class back. A name the group already holds (without regard to case), a measure that does not exist, that two classes define or that is linked to another measure, and a class of OcuPilot's own are refused.";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ENTRYADD";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter READBACKFIELDS = "GroupCaption,GroupDescription,GroupDisabled,Caption,MDX,Disabled";

/// <p>The read-back re-reads the created element through the change's read, because the add's own read is composed for an add.</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementSet";

Parameter PRECONDITIONCODES = "ANALYTICS.QUALITYMEASURE.ELEMENTTAKEN,ANALYTICS.QUALITYMEASURE.ABSENT,ANALYTICS.QUALITYMEASURE.AMBIGUOUS,ANALYTICS.QUALITYMEASURE.READONLY,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Name,Caption,MDX,Disabled,GroupCaption,GroupDescription,GroupDisabled";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 7
    Set pRows(1) = $ListBuild("Name", "string", 0)
    Set pRows(2) = $ListBuild("Caption", "string", 0)
    Set pRows(3) = $ListBuild("MDX", "string", 0)
    Set pRows(4) = $ListBuild("Disabled", "boolean", 0)
    Set pRows(5) = $ListBuild("GroupCaption", "string", 0)
    Set pRows(6) = $ListBuild("GroupDescription", "string", 0)
    Set pRows(7) = $ListBuild("GroupDisabled", "boolean", 0)
    Quit $$$OK
}

ClassMethod NameDescription() As %String
{
    Quit "The new element's name: 1 to 250 characters with no control character. A name the group already holds is refused, compared without regard to case, so check the Groups and elements list first."
}

/// <p>The composed payload and diff of the create (AD-54), and the namespace the request is scoped to. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The composite id of the element the confirmed add <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If (pWritten.%GetTypeOf("QualityMeasure") '= "string") || (pWritten.%GetTypeOf("Group") '= "string") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pWritten.%Get("QualityMeasure"), pWritten.%Get("Group"), pWritten.%Get("Name")))
}

}
