/// <p>What Interoperability's three system default setting writes share (AD-6, AD-35, AD-51, AD-52, AD-53, AD-62, Story 24.15): a write of
/// one system default setting of the request's namespace through <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the
/// list's New default setting and its row actions Edit and Remove, and the agent's proposal and confirmation. The target is the composite
/// <code>[Production, Item, HostClass, Setting]</code> (<class>OcuPilot.Screen.Tool.InteropDefaultSettingMint</class>), each part kept
/// exactly; a part may be <code>*</code> for any. A write is stored at once, and a running production uses it once it is updated.</p>
/// <p><b>A setting whose name matches the credential pattern is never shown and never written</b>: the port answers its value empty and
/// <code>Secret</code> true, and refuses every write of it <code>INTEROP.DEFAULTSETTING.SECRET</code> before any vendor call, from either
/// caller. A value the agent sent for such a setting is redacted from its ledger row and its step by <method>CallSecretNames</method>.</p>
/// <p><b>A rename cannot be expressed</b>: the key is the target, and the update's settable fields are <code>Value</code>,
/// <code>Description</code> and <code>Deployable</code>; a different key is a remove and an add.</p>
/// <p><b>It declares</b> <code>%Ens_SystemDefaultConfig:WRITE</code> and WRITE on the namespace's globals database beyond the screen's pairs
/// (AD-8, AD-62), each refused by name before any port call. The classic page's per-setting rules (the setting <code>Enabled</code>, a
/// restricted caller) depend on the setting the call names, so the port asks them at each call. The vendor checks no privilege of its own
/// (measured), and records its own audit row for each insert, update and delete.</p>
Class OcuPilot.Screen.Tool.InteropDefaultSettingAction Extends OcuPilot.Screen.Tool.InteropAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropDefaultSettingList";

/// <p>The fresh read: one default setting, composed for the action.</p>
Parameter READTYPE = "DEFAULTSETTING";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Production,Item,HostClass,Setting,Value,Description,Deployable,Secret,Namespace";

Parameter WRITERESOURCE = "%Ens_SystemDefaultConfig";

/// <p>The default setting read the confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Secret";

/// <p>The arguments naming the production, the item and the host class the setting applies to.</p>
Parameter PRODUCTIONARGUMENT = "Production";

Parameter ITEMARGUMENT = "Item";

Parameter HOSTCLASSARGUMENT = "HostClass";

/// <p>The refusal code of a write of a setting whose name holds a credential.</p>
Parameter SECRETCODE = "INTEROP.DEFAULTSETTING.SECRET";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTDEFAULTSETTINGS
}

/// <p><class>OcuPilot.Screen.Tool.InteropDefaultSettingMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropDefaultSettingMint"
}

/// <p>The setting's name, which the screen's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Setting"
}

/// <p>The setting's name, which the card titles it by: the fresh read's <code>Setting</code>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Setting") = "string") Quit pFresh.%Get("Setting")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Setting") = "string") Quit pArgs.%Get("Setting")
    Quit ""
}

/// <p>What the schema says of the setting's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The setting's name, exactly as the System default settings list reports it in its Setting column, or * for any. A setting whose name holds a credential is refused."
}

/// <p>The derived schema with the production, the item and the host class added and required, and the setting described: the target is one
/// default setting.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#PRODUCTIONARGUMENT, {"type": "string", "description": "The production the setting applies to, exactly as the System default settings list reports it in its Production column, or * for any."})
    Do tProperties.%Set(..#ITEMARGUMENT, {"type": "string", "description": "The item the setting applies to, exactly as the list reports it in its Item column, or * for any."})
    Do tProperties.%Set(..#HOSTCLASSARGUMENT, {"type": "string", "description": "The host class the setting applies to, exactly as the list reports it in its Host class column, or * for any."})
    If tSchema.%GetTypeOf("required") = "array" {
        Do tSchema.%Get("required").%Push(..#PRODUCTIONARGUMENT)
        Do tSchema.%Get("required").%Push(..#ITEMARGUMENT)
        Do tSchema.%Get("required").%Push(..#HOSTCLASSARGUMENT)
    }
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    }
    Quit tSchema
}

/// <p><code>Value</code> when the call <var>pInput</var> names a setting whose name the credential pattern matches
/// (<method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>), else none: its ledger row and step show the redaction mark in place of
/// whatever the agent sent for it (AD-3 layer 1, AD-41).</p>
ClassMethod CallSecretNames(pInput As %DynamicAbstractObject) As %List
{
    If '$IsObject(pInput) || 'pInput.%IsA("%Library.DynamicObject") Quit ""
    If pInput.%GetTypeOf("Setting") '= "string" Quit ""
    If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(pInput.%Get("Setting")) Quit $ListBuild("Value")
    Quit ""
}

/// <p>The refusal of a setting whose name the credential pattern matches, as its published sentence, else <code>""</code>: the rule the
/// port applies, asked again here so the mint and the confirm refuse by it too.</p>
ClassMethod SecretProblem(pIdValue As %String) As %String
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    If $ListLength(tParts) '= 4 Quit ""
    If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName($List(tParts, 4)) Quit $ClassMethod(..#PORTCLASS, "ReasonFor", ..#SECRETCODE)
    Quit ""
}

/// <p>Whether the rules over the call judge the key's parts: an add, whose key is new. A setting already held keeps the key it has.</p>
Parameter JUDGESKEY As BOOLEAN = 0;

/// <p>The rules over the call: <code>SECRET</code> on the setting's name, then <method>OcuPilot.Port.InteropPort.DefaultSettingViolations</method>
/// over the key (for an add, <parameter>JUDGESKEY</parameter>) and the arguments' <code>Value</code>, <code>Description</code> and
/// <code>Deployable</code>, in the namespace the arguments carry, else the request's (<method>ArgumentNamespace</method>), as one sentence
/// naming each field and its published sentence, or <code>""</code>.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..SecretProblem(pIdValue)
    If pProblem '= "" Quit $$$OK
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    If $ListLength(tParts) '= 4 Quit $$$OK
    Set tSC = $ClassMethod(..#PORTCLASS, "DefaultSettingViolations", ..ArgumentNamespace(pArgs), $List(tParts, 1), $List(tParts, 2), $List(tParts, 3), $List(tParts, 4), pArgs, .tViolations, ..#JUDGESKEY)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
    }
    Quit $$$OK
}

/// <p>The same rules again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the proposal live
/// (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

}
