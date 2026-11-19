/// <p>What the Run-time variables and User-defined icons tabs' Add dialogs share (AD-55, AD-54, Story 24.13, Batch 3): a person's Save that adds one run-time variable or icon of the request's namespace through
/// the add tool the agent's mint and confirm read. It is <class>OcuPilot.Area.Interop.ItemSave</class>'s Save for a member with no parent, as <class>OcuPilot.Area.Analytics.TermListSave</class> is built: the order
/// of the Save, its hold on the name, its absence read, the prohibited set, the port's add and the read-back are the superclass's. The body's members are <code>Name</code> and the tool's own members; the rules
/// over them are <method>OcuPilot.Port.AnalyticsPort.SettingEntryViolation</method>'s, and a violation is answered 400, as the port answers it, with its code and sentence.</p>
Class OcuPilot.Area.Analytics.SettingEntrySave Extends OcuPilot.Area.Interop.ItemSave [ Abstract ]
{

/// <p>No parent: the name is exact within the namespace.</p>
Parameter PRODUCTIONMEMBER;

Parameter NAMEMEMBER = "Name";

Parameter NAMEEMPTYCODE = "ANALYTICS.SETTING.NAME";

/// <p>The port's rules over the new name <var>pName</var> and the members <var>pFields</var> carry: at most one violation, the first the port finds.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tCode = $ClassMethod(..PortClass(), "SettingEntryViolation", $ClassMethod(..#CREATETOOL, "Endpoint"), $ClassMethod(..#CREATETOOL, "WriteType"), pName, pFields, "", .tField)
    If tCode '= "" Set pViolations($Increment(pViolations)) = $ListBuild(tField, tCode)
    Quit $$$OK
}

/// <p>Render <var>pViolations</var> as one 400 envelope carrying the first violation's code and sentence and every violation in <code>detail.violations</code>, as the port refuses the same write.</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Set tCode = $List(pViolations(1), 2)
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tCode, tDetail)
}

}
