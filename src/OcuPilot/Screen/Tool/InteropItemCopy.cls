/// <p>Interoperability's item copy (AD-3, AD-6, AD-54, AD-55, AD-62, Story 20.40): add a new item to a production of the
/// request's namespace as a copy of one of its items. It is <class>OcuPilot.Screen.Tool.InteropItemAdd</class>'s create with one
/// argument beyond the name, <code>CopyFrom</code>, the source item's name in the same production. Two callers reach it: the
/// Production items list's Copy dialog through <class>OcuPilot.Area.Interop.ItemCopy</class>, and the agent's proposal and
/// confirmation.</p>
/// <p><b>The payload</b> is <code>CopyFrom</code>, <code>Enabled</code> false and the namespace the proposal was composed in; the
/// port reads the source under the write's own lock and copies it as it stands then. The copy takes the source's class, settings,
/// category and comment, is stored disabled, and a business process whose pool size was 0 reads a pool size of 1
/// (<method>OcuPilot.Port.InteropPort.PerformItem</method>). A caller supplies no class, pool size, category, comment or enabled
/// flag.</p>
/// <p><b>It is not destructive</b>: the copy is created disabled and Remove undoes it.</p>
Class OcuPilot.Screen.Tool.InteropItemCopy Extends OcuPilot.Screen.Tool.InteropItemAdd
{

Parameter TOOLNAME = "interop.items.copy";

Parameter DESCRIPTION = "Propose adding one item to a production of the namespace the user is working in as a copy of another item of the same production. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production as the Productions list reports it, the new item's name, and the existing item to copy (CopyFrom) as that production's Production items list reports it. The copy takes the source's class, settings, category and comment, and is added disabled; a business process that runs in the shared actor pool is copied with a pool size of 1. The change is stored in the production's configuration; a running production starts an enabled item only when it is next updated or started. A name the production already holds in any letter case, an illegal name, a source the production does not hold or holds more than once, and a namespace under source control are refused.";

Parameter WRITETYPE = "COPY";

/// <p>What the read-back compares: the new item's name and that it was left disabled (AD-58).</p>
Parameter READBACKFIELDS = "Name,Enabled";

/// <p>The classic page's Actions tab copies an item, and the sibling item tools declare no classic page for their operations
/// (AD-44).</p>
Parameter CLASSICPAGES = "";

Parameter CONSEQUENCECODE = "INTEROP.ITEM.COPY";

Parameter PRECONDITIONCODES = "INTEROP.ITEM.TAKEN,INTEROP.ITEM.COPYSOURCE,INTEROP.ITEM.AMBIGUOUS,INTEROP.ITEM.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The one argument beyond the name: the item to copy.</p>
Parameter FIELDS = "CopyFrom";

/// <p>The one field a copy sets.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p><code>CopyFrom</code> as the field row the input schema is derived from: a string (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 1
    Set pRows(1) = $ListBuild("CopyFrom", "string", 0)
    Quit $$$OK
}

/// <p>The add's schema with <code>CopyFrom</code> described and required; no class is asked for.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf("CopyFrom") = "object" Do tProperties.%Get("CopyFrom").%Set("description", "The existing item of this production to copy, named exactly as its Production items list reports it. An item the production does not hold, or holds more than once, is refused. Required.", "string")
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push("CopyFrom")
    Quit tSchema
}

/// <p>The port's <method>OcuPilot.Port.InteropPort.CopyViolations</method> over the new name, the source and the production.</p>
ClassMethod FieldViolations(pNamespace As %String, pProduction As %String, pName As %String, pArgs As %DynamicObject, Output pViolations) As %Status
{
    Quit $ClassMethod(..#PORTCLASS, "CopyViolations", pNamespace, pProduction, pName, pArgs, .pViolations)
}

}
