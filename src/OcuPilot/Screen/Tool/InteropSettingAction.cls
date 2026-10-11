/// <p>What Interoperability's two item setting writes share (AD-6, AD-35, AD-41, AD-51, AD-52, AD-53, AD-62, Story
/// 20.22): a write of one setting of one item of one production of the request's namespace through
/// <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the Item settings row actions Set value and
/// Reset to default, and the agent's proposal and confirmation. A setting write changes the stored production
/// configuration and the production class and nothing else: it never updates, starts or stops a production, so a
/// running production reads update pending until Productions' confirmed Update applies the change. It is an item
/// write (<class>OcuPilot.Screen.Tool.InteropItemAction</class>) with the same pairs, gate and fresh read, whose
/// target is the composite <code>[Production, Item, Target, Name]</code>
/// (<class>OcuPilot.Screen.Tool.InteropSettingMint</class>).</p>
/// <p><b>A setting whose name the credential pattern matches is never shown and never set</b>: the port answers its
/// value and default empty, and refuses a set or a reset <code>INTEROP.SETTING.SECRET</code> before any vendor call,
/// from either caller. A value the agent sent for such a setting is redacted from its ledger row and its step by
/// <method>CallSecretNames</method>, because the refusal alone would leave it in a row the dispatcher records.</p>
/// <p>The card names a server path a location on the server (<method>Consequence</method>).</p>
Class OcuPilot.Screen.Tool.InteropSettingAction Extends OcuPilot.Screen.Tool.InteropItemAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropItemSettingList";

/// <p>The fresh read: one setting, composed for the action.</p>
Parameter READTYPE = "SETTING";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Production,Item,Target,Name,Value,Source,Default,DefaultSource,Type,Category,Location,Secret,Namespace,Count";

/// <p>The setting read the confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Source";

/// <p>The arguments naming the item and the group the setting belongs to.</p>
Parameter ITEMARGUMENT = "Item";

Parameter TARGETARGUMENT = "Target";

/// <p>The consequence code of a change to a server path.</p>
Parameter LOCATIONCODE = "INTEROP.SETTING.LOCATION";

/// <p>The refusal code of a set or a reset of a setting whose name holds a credential.</p>
Parameter SECRETCODE = "INTEROP.SETTING.SECRET";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTSETTINGS
}

/// <p><class>OcuPilot.Screen.Tool.InteropSettingMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropSettingMint"
}

/// <p>What the schema says of the setting's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The setting, named exactly as this item's Item settings list reports it. A setting the list does not report is refused."
}

/// <p>The derived schema with the item and the group added and required: the target is one setting of one item.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#ITEMARGUMENT, {"type": "string", "description": "The item the setting belongs to, named exactly as the production's Production items list reports it. An item the list does not report is refused."})
    Do tProperties.%Set(..#TARGETARGUMENT, {"type": "string", "enum": ["Core", "Host", "Adapter"], "description": "The group the setting belongs to, as the Item settings list reports it: Core for one of the item's own properties, Host for a setting of its class, Adapter for a setting of its adapter."})
    If tSchema.%GetTypeOf("required") = "array" {
        Do tSchema.%Get("required").%Push(..#ITEMARGUMENT)
        Do tSchema.%Get("required").%Push(..#TARGETARGUMENT)
    }
    Quit tSchema
}

/// <p><parameter>LOCATIONCODE</parameter> when the payload's setting is a server path (<code>Location</code> true),
/// else <parameter>CONSEQUENCECODE</parameter>.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If $IsObject(pPayload) && (pPayload.%GetTypeOf("Location") = "boolean") && pPayload.%Get("Location") Quit ..#LOCATIONCODE
    Quit ..#CONSEQUENCECODE
}

/// <p><code>Value</code> when the call <var>pInput</var> names a setting whose name the credential pattern matches
/// (<method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>), else none: its ledger row and step show the
/// redaction mark in place of whatever the agent sent for it (AD-3 layer 1, AD-41).</p>
ClassMethod CallSecretNames(pInput As %DynamicAbstractObject) As %List
{
    If '$IsObject(pInput) || 'pInput.%IsA("%Library.DynamicObject") Quit ""
    If pInput.%GetTypeOf("Name") '= "string" Quit ""
    If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(pInput.%Get("Name")) Quit $ListBuild("Value")
    Quit ""
}

/// <p>The setting's name inside the composite id <var>pIdValue</var>, <code>""</code> for any other spelling.</p>
ClassMethod SettingNameOf(pIdValue As %String) As %String [ Private ]
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    If $ListLength(tParts) '= 4 Quit ""
    Quit $List(tParts, 4)
}

/// <p>The refusal of a setting whose name the credential pattern matches, as its published sentence, else
/// <code>""</code>: the same rule the port applies, asked again here so the mint and the confirm refuse by it too.</p>
ClassMethod SecretProblem(pIdValue As %String) As %String
{
    Set tName = ..SettingNameOf(pIdValue)
    If (tName '= "") && ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tName) Quit $ClassMethod(..#PORTCLASS, "ReasonFor", ..#SECRETCODE)
    Quit ""
}

/// <p>The rule over the call: <code>SECRET</code> on the name.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..SecretProblem(pIdValue)
    Quit $$$OK
}

/// <p>The same rule again at the write, so a confirm is refused what the mint would now refuse before the claim,
/// leaving the proposal live (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

}
