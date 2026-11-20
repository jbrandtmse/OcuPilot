/// <p>Analytics' user-defined icon add (AD-3, AD-6, AD-54, AD-55, AD-65, Story 24.13, Batch 3): add one icon, a name and a path, to the request's namespace. Two callers reach it: the User-defined icons tab's
/// Add icon dialog through <class>OcuPilot.Area.Analytics.UserIconSave</class>, and the agent's proposal and confirmation. A path is text and is never loaded or drawn.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no icon of that exact name, and a name taken since the mint closes the proposal target-changed (<code>ANALYTICS.ICON.TAKEN</code>). Its fields are declared
/// here (<method>FieldRows</method>, AD-3), and its read-back compares the path (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.AnalyticsUserIconAdd Extends OcuPilot.Screen.Tool.AnalyticsUserIconAction
{

Parameter TOOLNAME = "analytics.usericons.add";

Parameter DESCRIPTION = "Propose adding one user-defined icon to the namespace the user is working in: a name and the path of the image dashboards show for it. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give the new icon's name and its path as text; the path is stored as text and never loaded. A name the namespace already holds (compared exactly, case included), a name over 255 characters or with a control character, a path over 2000 characters and a settings database that is read-only are refused.";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ENTRYADD";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter READBACKFIELDS = "Path";

/// <p>The read-back re-reads the created icon through the change's read, because the add's own read is composed for an add.</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.AnalyticsUserIconSet";

Parameter PRECONDITIONCODES = "ANALYTICS.ICON.TAKEN,ANALYTICS.SETTING.READONLY,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Name,Path";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Quit ..EntryFieldRows(1, .pRows)
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Get("Name").%Set("description", "The new icon's name: 1 to 255 characters with no control character. A name the namespace already holds is refused, compared exactly and so case included, so check the User-defined icons list first.", "string")
    Do tProperties.%Get("Path").%Set("description", "The icon's path as text, at most 2000 characters. It is stored as text and never loaded.", "string")
    Quit tSchema
}

/// <p>The composed payload and diff of the create (AD-54), and the namespace the request is scoped to. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The name of the icon the confirmed add <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit pWritten.%Get("Name")
}

/// <p>The add always asks its read for the add: held is <code>ICONTAKEN</code> and absent is the 404 a create expects (AD-54).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#ACTIONKEY) = ..#WRITETYPE
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

}
