/// <p>What Interoperability's four credential writes share (AD-6, AD-35, AD-51, AD-52, AD-53, AD-62, Story 24.15): a write of one credential of the
/// request's namespace through <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the Credentials list's New credential and its row
/// actions Edit, Set password and Remove, and the agent's proposal and confirmation. A write takes effect at once: what signs in with the credential
/// uses the change from its next connection. The target is the credential's name, kept exactly (AD-13).</p>
/// <p><b>A password is never a field of a payload, a row, a diff, a read-back, an audit payload or an error</b> (AD-35): it is a declared secret of
/// the screen (<code>secretArguments</code>), refused from the model at the mint, supplied at the confirm on the card or typed in the dialog, and passed
/// to the vendor alone. The port's row says only whether one is stored.</p>
/// <p><b>A rename cannot be expressed</b>: the name is the target, and the update's settable fields are the user name and the business partner; a
/// different name is a remove and an add.</p>
/// <p><b>It declares</b> <code>%Ens_Credentials:WRITE</code> and WRITE on the namespace's globals database beyond the screen's pairs (AD-8, AD-62),
/// each refused by name before any port call. The vendor checks <code>%Ens_Credentials:WRITE</code> itself for a password and records no audit row
/// of its own (measured).</p>
Class OcuPilot.Screen.Tool.InteropCredentialAction Extends OcuPilot.Screen.Tool.InteropAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropCredentialList";

/// <p>The fresh read: one credential, composed for the action.</p>
Parameter READTYPE = "CREDENTIAL";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Name,Username,BusinessPartner,Password,Namespace";

Parameter WRITERESOURCE = "%Ens_Credentials";

/// <p>The read field a call's arguments do not carry and the stored payload does: the namespace.</p>
Parameter STATEMARKER = "Namespace";

/// <p>Whether the rules over the call judge the credential's name: an add, whose name is new. A credential already held keeps the name it has.</p>
Parameter JUDGESNAME As BOOLEAN = 0;

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTCREDENTIALS
}

/// <p>The credential's name, which the card titles it by: the fresh read's <code>Name</code>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

/// <p>What the schema says of the credential's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The credential's name, exactly as the Credentials list reports it in its Name column. A credential the list does not report is refused."
}

/// <p>The derived schema with the name described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    }
    Quit tSchema
}

/// <p>The user name and business partner as field rows the input schema is derived from: strings (AD-3), with the name first when
/// <var>pWithName</var>. The port has no body template to derive them from.</p>
ClassMethod CredentialFieldRows(pWithName As %Boolean, Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    If pWithName Set pRows($Increment(pRows)) = $ListBuild("Name", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("Username", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("BusinessPartner", "string", 0)
    Quit $$$OK
}

/// <p>The derived schema with the user name and the business partner described.</p>
ClassMethod DescribeFields(pSchema As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If tProperties.%GetTypeOf("Username") = "object" Do tProperties.%Get("Username").%Set("description", "The user name the credential signs in with. An empty string clears it.", "string")
    If tProperties.%GetTypeOf("BusinessPartner") = "object" Do tProperties.%Get("BusinessPartner").%Set("description", "The business partner this credential belongs to: the name of a partner the Business partners list reports, or an empty string for none.", "string")
    Quit pSchema
}

/// <p>The rules over the caller's fields, as one sentence naming each field and its published sentence, or <code>""</code> (AD-55):
/// <method>OcuPilot.Port.InteropPort.CredentialViolations</method> over the arguments' fields and, for an add (<parameter>JUDGESNAME</parameter>),
/// the id's name, in the namespace the arguments carry, else the request's (<method>ArgumentNamespace</method>). The screen's Save and the mint
/// apply them alike.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $ClassMethod(..#PORTCLASS, "CredentialViolations", ..ArgumentNamespace(pArgs), pIdValue, pArgs, .tViolations, ..#JUDGESNAME, 1)
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

/// <p>Whether the agent's write of the credential <var>pIdValue</var> is refused because an enabled agent definition reads its provider key from it
/// (AD-10, Story 24.15), and the <code>PROHIBITED.*</code> code that refuses it. It asks only while a turn is acting for the model
/// (<method>OcuPilot.Kernel.Proposal.Caller.IsTurn</method>) and only in OcuPilot's own namespace, where the <code>creds</code> rung opens the entry
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.IsOwnNamespace</method>): a person's call on the screen runs in no turn and is not refused, and a
/// credential of that name in another namespace is not the provider's. The definitions are read at each call
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.ProviderCredential</method>); a read that fails refuses.</p>
ClassMethod RefusedForProvider(pIdValue As %String, Output pCode As %String) As %Boolean
{
    Set pCode = ""
    If '##class(OcuPilot.Kernel.Proposal.Caller).IsTurn() Quit 0
    If '##class(OcuPilot.Kernel.Proposal.Prohibited).IsOwnNamespace(##class(OcuPilot.Kernel.Scope).Current()) Quit 0
    If '##class(OcuPilot.Kernel.Proposal.Prohibited).ProviderCredential(pIdValue) Quit 0
    Set pCode = ##class(OcuPilot.Kernel.Proposal.Prohibited).#PROVIDERCREDENTIAL
    Quit 1
}

}
