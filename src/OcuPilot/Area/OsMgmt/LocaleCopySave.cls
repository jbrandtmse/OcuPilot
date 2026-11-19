/// <p>Locale definitions' Copy (AD-55, AD-54, Story 21.16): <code>POST /locales</code> copies one locale the instance lists to a new custom locale through
/// <class>OcuPilot.Screen.Tool.LocaleCopy</class>, the tool the agent's mint and confirm read. It is
/// <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with no parent: a locale belongs to the instance, so the member is the new name alone
/// (<parameter>PRODUCTIONMEMBER</parameter> is empty), and the order of the Save, its hold on the new name, its absence read, the prohibited set, the
/// port's copy and the read-back are the superclass's. The body's members are <code>Name</code> (the new locale), <code>Source</code> and,
/// optionally, <code>Description</code>; any other member is 400 <code>PORT.FIELD.UNEXPECTED</code>.</p>
/// <p>The rules over the new name and the source are <class>OcuPilot.Port.LocalePort</class>'s, asked under its per-locale lock before any vendor call
/// (<code>LOCALE.COPY.NAME</code>, <code>LOCALE.NOTFOUND</code>, <code>LOCALE.COPY.TAKEN</code>), so <method>Violations</method> finds none of its own.</p>
/// <p><code>DependsOn</code> is required: <parameter>TAKENREASON</parameter> is a compile-time expression over <class>OcuPilot.Api.LocaleError</class>.</p>
Class OcuPilot.Area.OsMgmt.LocaleCopySave Extends OcuPilot.Area.Interop.ItemSave [ DependsOn = OcuPilot.Api.LocaleError ]
{

/// <p>The tool class both callers resolve the copy through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.LocaleCopy";

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocaleList";

/// <p>Empty: a locale has no parent (<class>OcuPilot.Area.Interop.ItemSave</class>).</p>
Parameter PRODUCTIONMEMBER = "";

Parameter NAMEMEMBER = "Name";

/// <p>The code an empty name earns and the refusal a taken one earns, with the sentence of each from <class>OcuPilot.Api.LocaleError</class>.</p>
Parameter NAMEEMPTYCODE = "LOCALE.COPY.NAME";

Parameter TAKENCODE = "LOCALE.COPY.TAKEN";

Parameter TAKENREASON = {##class(OcuPilot.Api.LocaleError).#REASONCOPYTAKEN};

/// <p>No rule of its own: the port judges the name, the source and the description at the write.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Quit $$$OK
}

}
