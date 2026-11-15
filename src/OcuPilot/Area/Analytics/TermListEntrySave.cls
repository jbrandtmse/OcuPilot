/// <p>Entries' Add entry (AD-55, AD-54, Story 24.2): <code>POST /analytics/term-list-entries</code> adds one entry to a term list of the
/// request's namespace through <class>OcuPilot.Screen.Tool.AnalyticsTermListEntryAdd</class>, the tool the agent's mint and confirm read. It
/// is <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with the term list as the parent and the key as the member. The body's members are
/// <code>TermList</code>, <code>Key</code> and, optionally, <code>Value</code> and <code>FieldValues</code>; a list the namespace does not
/// hold is 404 <code>ANALYTICS.TERMLIST.ABSENT</code>, any other refusal of the list's read is the port's own, and the rules over the
/// fields are <method>OcuPilot.Port.AnalyticsPort.TermListViolations</method>'s.</p>
Class OcuPilot.Area.Analytics.TermListEntrySave Extends OcuPilot.Area.Interop.ItemSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.AnalyticsTermListEntryAdd";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsTermListEntryList";

Parameter PRODUCTIONMEMBER = "TermList";

Parameter NAMEMEMBER = "Key";

Parameter PARENTEMPTYCODE = "ANALYTICS.TERMLIST.NAME";

Parameter NAMEEMPTYCODE = "ANALYTICS.TERMLIST.KEY";

Parameter TAKENCODE = "ANALYTICS.TERMLIST.ENTRYTAKEN";

Parameter TAKENREASON = "This term list already holds an entry with that key.";

/// <p>Whether <var>pNamespace</var> holds the term list <var>pParent</var>, read through the port's own list read.</p>
ClassMethod ParentHeld(pNamespace As %String, pParent As %String) As %Boolean
{
    Quit $$$ISOK(..ParentRefusal(pNamespace, pParent, .tHttp, .tFault))
}

/// <p>The port's list read of <var>pParent</var> in <var>pNamespace</var>: <code>$$$OK</code> when it is held, 404
/// <code>ANALYTICS.TERMLIST.ABSENT</code> when it is not, and any other refusal of the read as the port answered it.</p>
ClassMethod ParentRefusal(pNamespace As %String, pParent As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill tQuery
    Set tQuery(##class(OcuPilot.Port.AnalyticsPort).#IDKEY) = pParent
    Set tQuery(##class(OcuPilot.Port.AnalyticsPort).#NAMESPACEKEY) = pNamespace
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTTERMLISTS, ##class(OcuPilot.Port.AnalyticsPort).#TYPETERMLIST, .tQuery, "", .tRow, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) || (+$Get(pHttpStatus) '= 404) Quit tSC
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.AnalyticsError).#TERMLISTABSENT, ##class(OcuPilot.Api.AnalyticsError).#REASONTERMLISTABSENT)
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.AnalyticsError).#TERMLISTABSENT)
}

ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Quit $ClassMethod(..PortClass(), "TermListViolations", $ClassMethod(..#CREATETOOL, "WriteType"), pParent, pName, pFields, .pViolations)
}

}
