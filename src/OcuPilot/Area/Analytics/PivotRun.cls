/// <p>A saved pivot's background run (Story 24.14, AD-7, AD-41, AD-42, AD-65): MDX query's run, <class>OcuPilot.Area.Analytics.MdxQuery</class>, whose text is the
/// vendor's own composition of a saved pivot rather than a statement the browser sent. <code>POST /analytics/pivot/background</code> starts one and answers its run id at
/// once; <code>GET .../:id</code> answers it to its owner; <code>POST .../:id/cancel</code> asks it to stop. The routes, the run row, the job, the checks
/// and the answer are MDX query's; this class is its <code>pivot</code> kind.</p>
/// <p><b>The start's body</b> is <code>{item, drill?, confirmed?}</code>: <code>item</code> is the pivot's full name, kept exactly (AD-13), and any other key or shape is 400
/// <code>ANALYTICS.MDX.INPUT</code>. The start and the job each compose the statement in turn
/// (<method>OcuPilot.Port.AnalyticsPort.PivotStatement</method>: a name that fails the folder item shape, a missing item and an item the caller's resources hide are 404
/// <code>ANALYTICS.FOLDERITEM.ABSENT</code>, and an item that is not a pivot on a cube the namespace holds is 409 <code>ANALYTICS.PIVOT.CUBE</code>), and then make
/// MDX query's own checks on it: the gate, the detection of text that runs server-side code or SQL (a stored restriction asks first), the prepare and the run, under the same caps
/// and bound. No pivot variable is handed to the prepare. The answer adds <code>statement</code>, the composed MDX, cut at
/// <parameter>OcuPilot.Port.AnalyticsPort.MDXMAXCELL</parameter> characters.</p>
Class OcuPilot.Area.Analytics.PivotRun Extends OcuPilot.Area.Analytics.MdxQuery
{

/// <p>The screen the three routes and the job answer for: the viewer's Definition tab, whose pairs are Folder items'.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsFolderItemDefinitionTab";

Parameter RUNKIND = "pivot";

Parameter LOGSUBSYSTEM = "pivotbackground";

Parameter TEXTKEY = "item";

/// <p>Any string: a name that cannot be a folder item is the port's 404, not a malformed body.</p>
ClassMethod TextValid(pText As %String) As %Boolean
{
    Quit 1
}

/// <p>The saved pivot <var>pText</var> named, composed into its statement by <method>OcuPilot.Port.AnalyticsPort.PivotStatement</method>.</p>
ClassMethod Resolve(pNamespace As %String, pText As %String, Output pStatement As %String, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttp = 0
    Set pFault = ""
    Quit $ClassMethod(..PortClass(), "PivotStatement", pNamespace, pText, .pStatement, .pHttp, .pFault)
}

/// <p>The composed statement, cut at the port's cell bound, as the answer's <code>statement</code>.</p>
ClassMethod Annotate(pStatement As %String, pAnswer As %DynamicObject)
{
    Do pAnswer.%Set("statement", $ClassMethod(..PortClass(), "Cut", pStatement), "string")
}

}
