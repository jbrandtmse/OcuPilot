/// <p>Interoperability's system default setting update (AD-4, AD-6, AD-51, AD-53, AD-56, AD-62, Story 24.15): change the value, the
/// description or the deployable flag of one system default setting of the request's namespace. The change is stored at once; a running
/// production uses it once it is updated. <b>The key cannot be changed</b>: a different key is a remove and an add. A call carrying any
/// argument beyond the setting's key parts and those three fields is refused before any port call.</p>
/// <p>Two callers reach it: the list's row action Edit through <class>OcuPilot.Api.ScreenAction</class>, whose dialog sends the fields it
/// changed and may send an empty value or description, and the agent's proposal and confirmation. It is a merge over the setting's fresh
/// read, so its card shows one row for each field it moves and its read-back compares the three fields
/// (<parameter>READBACKFIELDS</parameter>). Its state, pairs and refusals are
/// <class>OcuPilot.Screen.Tool.InteropDefaultSettingAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropDefaultSettingUpdate Extends OcuPilot.Screen.Tool.InteropDefaultSettingAction
{

Parameter TOOLNAME = "interop.defaultsettings.update";

Parameter DESCRIPTION = "Propose changing the value, the description or the deployable flag of one system default setting of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production, the item, the host class and the setting exactly as the System default settings list reports them, and give only the fields to change; a value or description sent as an empty string is cleared and a field left out is kept. The key cannot be changed: to move a default, add one under the new key and remove the old one. A running production uses the new value once it is updated. A setting whose name holds a credential, a value the setting does not accept, a value or description over 2,000 characters, a setting the namespace does not hold and a namespace under source control are refused.";

Parameter WRITETYPE = "SETDEFAULT";

/// <p>The update sends a body: the setting's row with the new values (AD-4).</p>
Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "edit";

/// <p>The dialog's values are the three fields (AD-56 (ii)); the key is the target. A flag is sent as <code>true</code> or <code>false</code>.</p>
Parameter SCREENVALUES = "edit=Value:Description:Deployable";

/// <p>The value and the description may be empty: clearing one is the request.</p>
Parameter SCREENEMPTY = "edit=Value:Description";

/// <p>The dialog sends the fields it changed and no other: a value left out keeps what the setting holds, so a change made elsewhere to
/// another field since the list was read is kept (AD-4, AD-56).</p>
Parameter SCREENOPTIONAL = "edit=Value:Description:Deployable";

/// <p>What the read-back compares (AD-58).</p>
Parameter READBACKFIELDS = "Value,Description,Deployable";

Parameter PRECONDITIONCODES = "INTEROP.DEFAULTSETTING.SECRET,INTEROP.DEFAULTSETTING.SOURCECONTROL,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.DEFAULTSETTING.PENDING";

/// <p>The three fields an update may set.</p>
Parameter FIELDS = "Value,Description,Deployable";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The three fields as the field rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 3
    Set pRows(1) = $ListBuild("Value", "string", 0)
    Set pRows(2) = $ListBuild("Description", "string", 0)
    Set pRows(3) = $ListBuild("Deployable", "boolean", 0)
    Quit $$$OK
}

/// <p>The derived schema with each field described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf("Value") = "object" Do tProperties.%Get("Value").%Set("description", "The new value, as text, at most 2,000 characters, exactly as the setting stores it: a boolean setting takes 1 or 0. An empty string clears it. Check the setting's current value on the System default settings list first.", "string")
    If tProperties.%GetTypeOf("Description") = "object" Do tProperties.%Get("Description").%Set("description", "The new description, as text, at most 2,000 characters. An empty string clears it.", "string")
    If tProperties.%GetTypeOf("Deployable") = "object" Do tProperties.%Get("Deployable").%Set("description", "Whether the setting is exported with a production's deployment package.", "string")
    Quit tSchema
}

/// <p>No state rows: a merge's card shows the values it moves (<method>OcuPilot.Kernel.Proposal.Mint.Merge</method>), and a setting nobody
/// established is refused by the fresh read.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The dialog's values as this tool's arguments: the value and the description as sent, an empty one included, and the flag as the
/// boolean its <code>true</code> or <code>false</code> text names; any other flag text is <var>pProblem</var>. The port judges the rest.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    For tName = "Value", "Description" {
        If pValues.%GetTypeOf(tName) = "string" Do pArgs.%Set(tName, pValues.%Get(tName), "string")
    }
    If pValues.%GetTypeOf("Deployable") = "string" {
        If '$ListFind($ListBuild("true", "false"), pValues.%Get("Deployable")) {
            Set pProblem = "'Deployable' is true or false"
        } Else {
            Do pArgs.%Set("Deployable", (pValues.%Get("Deployable") = "true"), "boolean")
        }
    }
    Quit $$$OK
}

}
