/// <p>Locale properties' Add table (AD-55, AD-54, Story 21.16): <code>POST /locale-properties</code> adds one table to a list of a custom locale through
/// <class>OcuPilot.Screen.Tool.LocaleTableAdd</class>, the tool the agent's mint and confirm read. It is
/// <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with the locale as the parent and the row, <code>&lt;list&gt;:&lt;table&gt;</code>, as the member:
/// the order of the Save, its hold on the row's composite id, its absence read, the prohibited set, the port's add and the read-back are the
/// superclass's. The body's members are <code>Locale</code>, <code>Name</code> and, for an input/output table, <code>InputFrom</code> and
/// <code>OutputTo</code>; a locale the instance does not list is 404 <code>LOCALE.NOTFOUND</code>.</p>
/// <p>The rules over the row and its sides are <class>OcuPilot.Port.LocalePort</class>'s, asked under its per-locale lock before any vendor call, so
/// <method>Violations</method> finds none of its own.</p>
/// <p><code>DependsOn</code> is required: <parameter>TAKENREASON</parameter> is a compile-time expression over <class>OcuPilot.Api.LocaleError</class>.</p>
Class OcuPilot.Area.OsMgmt.LocaleTableSave Extends OcuPilot.Area.Interop.ItemSave [ DependsOn = OcuPilot.Api.LocaleError ]
{

/// <p>The tool class both callers resolve the add through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.LocaleTableAdd";

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocalePropertyList";

/// <p>The members that identify the row: its locale and its name.</p>
Parameter PRODUCTIONMEMBER = "Locale";

Parameter NAMEMEMBER = "Name";

/// <p>The refusal a missing locale or row earns (422), and the refusal a listed table earns (409) with its sentence from
/// <class>OcuPilot.Api.LocaleError</class>.</p>
Parameter PARENTEMPTYCODE = "PORT.FIELD.SHAPE";

Parameter NAMEEMPTYCODE = "PORT.FIELD.SHAPE";

Parameter TAKENCODE = "LOCALE.TABLE.TAKEN";

Parameter TAKENREASON = {##class(OcuPilot.Api.LocaleError).#REASONTABLETAKEN};

/// <p>Whether the instance lists the locale <var>pParent</var>, read through the port's own locale read.</p>
ClassMethod ParentHeld(pNamespace As %String, pParent As %String) As %Boolean
{
    Quit $$$ISOK(..ParentRefusal(pNamespace, pParent, .tHttp, .tFault))
}

/// <p>The port's read of the locale <var>pParent</var>: <code>$$$OK</code> when it is listed, and the port's own refusal, 404
/// <code>LOCALE.NOTFOUND</code>, when it is not.</p>
ClassMethod ParentRefusal(pNamespace As %String, pParent As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill tQuery
    Set tQuery(##class(OcuPilot.Port.LocalePort).#NAMEKEY) = pParent
    Quit $ClassMethod(..PortClass(), "Invoke", ##class(OcuPilot.Port.LocalePort).#LOCALESENDPOINT, ##class(OcuPilot.Port.LocalePort).#TYPEGET, .tQuery, "", .tRow, .pHttpStatus, .pFault)
}

/// <p>No rule of its own: the port judges the list, the table and the sides at the write.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Quit $$$OK
}

}
