/// <p>What Story 24.12's element and documentation write tests share (Batch 3): <class>OcuPilot.Test.AnalyticsQualityMeasureBase</class>'s probe, fixtures and helpers under the catalog
/// <parameter>MARKER</parameter>, with the screens, tools and endpoints of the two part screens, the composite ids, and the rows a screen and the agent's read tool answer set beside the rows the
/// vendor's model holds. <class>OcuPilot.Test.AnalyticsQualityMeasurePartWrite</class> and <class>OcuPilot.Test.AnalyticsQualityMeasurePartWriteEdge</class> extend it.</p>
/// <p><b>What it needs from the environment:</b> the base class's. Every measure and class it makes is named under <parameter>MARKER</parameter> and removed after each test.</p>
Class OcuPilot.Test.AnalyticsQualityMeasurePartBase Extends OcuPilot.Test.AnalyticsQualityMeasureBase [ Abstract ]
{

Parameter MARKER = "OcuProbeQMP";

Parameter CLASSMARKER = "OcuProbeQMP.Analytics.QMP";

Parameter OWNCLASSMARKER = "OcuPilotQMP.Analytics.QMP";

Parameter ELEMENTSCREEN = "/screens/analytics.qualitymeasureelements/action";

Parameter METASCREEN = "/screens/analytics.qualitymeasuremetas/action";

Parameter ELEMENTENDPOINT = "QualityMeasureElements";

Parameter METAENDPOINT = "QualityMeasureMetas";

Parameter ELEMENTADDTOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementAdd";

Parameter ELEMENTSETTOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementSet";

Parameter ELEMENTREMOVETOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementRemove";

Parameter METAADDTOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaAdd";

Parameter METASETTOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaSet";

Parameter METAREMOVETOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaRemove";

/// <p>The composite id of the element <var>pName</var> of the group <var>pGroup</var> of the measure <var>pMeasure</var>; an empty <var>pName</var> names the group.</p>
ClassMethod ElementId(pMeasure As %String, pGroup As %String, pName As %String = "") As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pMeasure, pGroup, pName))
}

/// <p>The composite id of the documentation item <var>pName</var> of the measure <var>pMeasure</var>.</p>
ClassMethod MetaId(pMeasure As %String, pName As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pMeasure, pName))
}

/// <p>The rows the model <var>pModel</var> (a <method>QModel</method> answer) holds as the part screens answer them, sorted and joined by <code>;</code>: with <var>pElements</var> one row per element
/// as <code>Group|GroupCaption|GroupDescription|GroupDisabled|Name|Caption|MDX|Disabled</code>, a group with no element one row with empty element fields; otherwise one per documentation item as
/// <code>Name|Caption|Section|Content|Disabled</code>. The fixtures' text holds none of the characters that delimit the model string.</p>
ClassMethod RowsOfModel(pModel As %String, pElements As %Boolean) As %String
{
    Kill tRows
    For tAt = 2:1:$Length(pModel, "~") {
        Set tPart = $Piece(pModel, "~", tAt)
        If pElements && ($Extract(tPart, 1, 2) = "G:") {
            Set tHead = $Piece($Extract(tPart, 3, *), ";", 1)
            If $Length(tPart, ";") = 1 Set tRows(tHead _ "||||0") = ""
            For tElementAt = 2:1:$Length(tPart, ";") {
                Set tElement = $Extract($Piece(tPart, ";", tElementAt), 3, *)
                Set tRows(tHead _ "|" _ tElement) = ""
            }
        } ElseIf 'pElements && ($Extract(tPart, 1, 2) = "M:") {
            Set tItem = $Extract(tPart, 3, *)
            Set tRows($Piece(tItem, "|", 1) _ "|" _ $Piece(tItem, "|", 2) _ "|" _ $Piece(tItem, "|", 3) _ "|" _ $Piece(tItem, "|", 5, *) _ "|" _ $Piece(tItem, "|", 4)) = ""
        }
    }
    Quit ..Joined(.tRows)
}

/// <p>The subscripts of <var>pRows</var> in order, joined by <code>;</code>.</p>
ClassMethod Joined(ByRef pRows) As %String
{
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(pRows(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ";") _ tKey
    }
    Quit tOut
}

/// <p>The row <var>pRow</var> of a part screen as the string <method>RowsOfModel</method> builds for it.</p>
ClassMethod RowText(pRow As %DynamicObject, pElements As %Boolean) As %String
{
    If pElements Quit pRow.%Get("Group") _ "|" _ pRow.%Get("GroupCaption") _ "|" _ pRow.%Get("GroupDescription") _ "|" _ ''pRow.%Get("GroupDisabled") _ "|" _ pRow.%Get("Name") _ "|" _ pRow.%Get("Caption") _ "|" _ pRow.%Get("MDX") _ "|" _ ''pRow.%Get("Disabled")
    Quit pRow.%Get("Name") _ "|" _ pRow.%Get("Caption") _ "|" _ pRow.%Get("Section") _ "|" _ pRow.%Get("Content") _ "|" _ ''pRow.%Get("Disabled")
}

/// <p>The rows of the part screen's read for the measure <var>pName</var> (<code>GET /screens/analytics.qualitymeasureelements/read</code> or <code>.qualitymeasuremetas</code>) as
/// <method>RowsOfModel</method> builds them; <code>"unreadable"</code> and the HTTP status when it is not answered.</p>
ClassMethod ScreenPartRows(pName As %String, pElements As %Boolean) As %String
{
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.qualitymeasure" _ $Select(pElements: "elements", 1: "metas") _ "/read?ns=" _ ..#NAMESPACE _ "&qualitymeasure=" _ $ZConvert(pName, "O", "URL"), "", .tHttp, .tRead)
    If (tHttp '= 200) || '$IsObject(tRead) || '$IsObject(tRead.%Get("rows")) Quit "unreadable " _ tHttp
    Kill tRows
    For tAt = 0:1:tRead.rows.%Size() - 1 {
        Set tRows(..RowText(tRead.rows.%Get(tAt), pElements)) = ""
    }
    Quit ..Joined(.tRows)
}

/// <p>The same rows from the agent's read tool <code>analytics.qualitymeasureelements.read</code> or <code>.qualitymeasuremetas.read</code>.</p>
ClassMethod ToolPartRows(pName As %String, pElements As %Boolean) As %String
{
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.qualitymeasure" _ $Select(pElements: "elements", 1: "metas") _ ".read", {"qualitymeasure": (pName)}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
    If (tLeg.%Get("http") '= 200) || '$IsObject(tLeg.%Get("rows")) Quit "unreadable"
    Kill tRows
    For tAt = 0:1:tLeg.rows.%Size() - 1 {
        Set tRows(..RowText(tLeg.rows.%Get(tAt), pElements)) = ""
    }
    Quit ..Joined(.tRows)
}

/// <p>Both reads of the part screen of the measure <var>pName</var> equal the rows the vendor's model holds (AD-58's integration check): the screen's read, the agent's read tool and the model, as one
/// assertion each.</p>
Method AssertReadsEqualModel(pName As %String, pElements As %Boolean, pWhat As %String)
{
    Set tModel = ..RowsOfModel(..QModel(pName), pElements)
    Do $$$AssertEquals(..ScreenPartRows(pName, pElements), tModel, pWhat _ ": the screen's read answers the model's rows")
    Do $$$AssertEquals(..ToolPartRows(pName, pElements), tModel, pWhat _ ": and so does the agent's read tool")
}

/// <p>A part write's script, <method>OcuPilot.Port.AnalyticsPort.Snippet</method> of <var>pEndpoint</var> for the write <var>pType</var> on the composite id <var>pId</var> with <var>pBody</var>.</p>
ClassMethod PartScript(pEndpoint As %String, pType As %String, pId As %String, pBody As %DynamicObject) As %DynamicArray
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    Quit $ClassMethod(..#PORT, "Snippet", pEndpoint, pType, .tQuery, pBody)
}

}
