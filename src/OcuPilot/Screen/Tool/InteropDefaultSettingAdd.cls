/// <p>Interoperability's system default setting add (AD-3, AD-6, AD-54, AD-55, AD-62, Story 24.15): add one system default setting to the
/// request's namespace, giving a setting its value in every production, item and host class its key matches. Two callers reach it: the
/// list's New default setting dialog through <class>OcuPilot.Area.Interop.DefaultSettingSave</class>, and the agent's proposal and
/// confirmation. The setting is stored at once; a running production uses it once it is updated.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no setting under that key, and a key added since the mint reads present at the
/// confirm's re-read and closes the proposal target-changed. A key part may be <code>*</code>; a setting whose name holds a credential is
/// refused <code>SECRET</code>, and a value the vendor refuses for the setting is <code>VALUE</code>.</p>
/// <p><b>Its payload</b> is the setting's name and the fields the caller supplies and the namespace the add was composed in
/// (<method>ComposeCreate</method>); the production, the item and the host class are the id's first three parts. The port has no body
/// template to derive a field list from, so the fields are declared here (<method>FieldRows</method>, AD-3) and its read-back compares them
/// (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.InteropDefaultSettingAdd Extends OcuPilot.Screen.Tool.InteropDefaultSettingAction
{

Parameter TOOLNAME = "interop.defaultsettings.add";

Parameter DESCRIPTION = "Propose adding one system default setting to the namespace the user is working in. A system default setting gives a setting its value in every production, item and host class it matches, unless the production sets its own value; use * for any. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production, the item, the host class and the setting, and give the value, and optionally a description and whether the setting is deployable. A running production uses the new value once it is updated. A key the namespace already holds, a setting whose name holds a credential, a part that is empty or over 255 characters or holds two vertical bars, a value the setting does not accept, a value or description over 2,000 characters and a namespace under source control are refused.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADDDEFAULT";

/// <p>The add sends a body: the composed payload (AD-4 has no subject for a create).</p>
Parameter SENDSBODY As BOOLEAN = 1;

/// <p>What the read-back compares, the fields a create sends (AD-58).</p>
Parameter READBACKFIELDS = "Value,Description,Deployable";

/// <p>The read-back re-reads the created setting through the update's single-object read, because the add's own read asks for the add and
/// answers a held key as <code>TAKEN</code> (AD-58).</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.InteropDefaultSettingUpdate";

Parameter PRECONDITIONCODES = "INTEROP.DEFAULTSETTING.TAKEN,INTEROP.DEFAULTSETTING.SECRET,INTEROP.DEFAULTSETTING.SOURCECONTROL,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.DEFAULTSETTING.PENDING";

/// <p>The fields an add may set, in the order the card lists them.</p>
Parameter FIELDS = "Setting,Value,Description,Deployable";

/// <p>An add judges the key it is given.</p>
Parameter JUDGESKEY As BOOLEAN = 1;

/// <p>The setting's name and the three fields an add sets.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The four fields as the field rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 4
    Set pRows(1) = $ListBuild("Setting", "string", 0)
    Set pRows(2) = $ListBuild("Value", "string", 0)
    Set pRows(3) = $ListBuild("Description", "string", 0)
    Set pRows(4) = $ListBuild("Deployable", "boolean", 0)
    Quit $$$OK
}

/// <p>The derived schema with the value, the description and the flag described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf("Value") = "object" Do tProperties.%Get("Value").%Set("description", "The value, as text, at most 2,000 characters, exactly as the setting stores it: a boolean setting takes 1 or 0. A value the setting does not accept is refused.", "string")
    If tProperties.%GetTypeOf("Description") = "object" Do tProperties.%Get("Description").%Set("description", "What this default is for, as text, at most 2,000 characters.", "string")
    If tProperties.%GetTypeOf("Deployable") = "object" Do tProperties.%Get("Deployable").%Set("description", "Whether the setting is exported with a production's deployment package. Omit it for false.", "string")
    Quit tSchema
}

/// <p>The composed payload and diff of the create (AD-54): the setting's name and the fields the caller supplied, as the kernel's
/// <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> composes them, and the namespace the request is scoped to, which the port query and
/// the prohibited set read. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The composite id of the setting the confirmed add <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    Set tParts = ""
    For tName = "Production", "Item", "HostClass", "Setting" {
        If pWritten.%GetTypeOf(tName) '= "string" Quit
        Set tParts = tParts _ $ListBuild(pWritten.%Get(tName))
    }
    If $ListLength(tParts) '= 4 Quit ""
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite(tParts)
}

/// <p>The add always asks its read for the add (<parameter>OcuPilot.Port.InteropPort.ACTIONKEY</parameter>): present is
/// <code>TAKEN</code> and absent is the 404 a create expects (AD-54), at the mint and at the confirm alike. The namespace is the payload's,
/// else the request's scope.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ..#WRITETYPE
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

}
