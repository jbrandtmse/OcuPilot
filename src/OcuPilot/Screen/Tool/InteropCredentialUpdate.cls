/// <p>Interoperability's credential update (AD-4, AD-6, AD-51, AD-53, AD-56, AD-62, Story 24.15): change the user name or the business partner of one
/// credential of the request's namespace. The change is in effect at once, and whatever signs in with the credential uses it from its next
/// connection (<code>INTEROP.CREDENTIAL.CHANGE</code>). <b>The name cannot be changed</b>: to rename a credential, add one under the new name, change
/// what names the old one, then remove it. <b>The password is not a field of this tool</b>: it is set by
/// <class>OcuPilot.Screen.Tool.InteropCredentialPassword</class>.</p>
/// <p>Two callers reach it: the Credentials list's row action Edit through <class>OcuPilot.Api.ScreenAction</class>, whose dialog sends the fields it
/// changed and may send an empty one, and the agent's proposal and confirmation. It is a merge over the credential's fresh read, so its card shows
/// one row for each field it moves and its read-back compares the two fields (<parameter>READBACKFIELDS</parameter>). <code>Password</code> is part
/// of the read and no part of the merge, the fingerprint or the read-back.</p>
Class OcuPilot.Screen.Tool.InteropCredentialUpdate Extends OcuPilot.Screen.Tool.InteropCredentialAction
{

Parameter TOOLNAME = "interop.credentials.update";

Parameter DESCRIPTION = "Propose changing the user name or the business partner of one credential of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the credential exactly as the Credentials list reports it, and give only the fields to change; a field sent as an empty string is cleared and a field left out is kept. The credential's name and its password cannot be changed by this tool; to set a password use the set-password tool. A business partner the namespace does not hold and a user name the instance does not accept are refused.";

Parameter WRITETYPE = "SETCREDENTIAL";

/// <p>The update sends a body: the credential's row with the new values (AD-4).</p>
Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter CONSEQUENCECODE = "INTEROP.CREDENTIAL.CHANGE";

Parameter SCREENACTIONS = "edit";

/// <p>The dialog's values are the two fields, each of which may be empty (AD-56 (ii)); the name is the target.</p>
Parameter SCREENVALUES = "edit=Username:BusinessPartner";

Parameter SCREENEMPTY = "edit=Username:BusinessPartner";

/// <p>The dialog sends the fields it changed and no other: a value left out keeps what the credential holds, so a change made elsewhere to the other
/// field since the list was read is kept (AD-4, AD-56).</p>
Parameter SCREENOPTIONAL = "edit=Username:BusinessPartner";

/// <p>What the read-back compares (AD-58).</p>
Parameter READBACKFIELDS = "Username,BusinessPartner";

Parameter PRECONDITIONCODES = "INTEROP.NAMESPACE";

/// <p>The two fields an update may set.</p>
Parameter FIELDS = "Username,BusinessPartner";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The two fields as the field rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Quit ..CredentialFieldRows(0, .pRows)
}

/// <p>The derived schema with each field described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ..DescribeFields(##super(pDescriptor))
}

/// <p>No state rows: a merge's card shows the values it moves (<method>OcuPilot.Kernel.Proposal.Mint.Merge</method>), and a credential nobody
/// established is refused by the fresh read.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The kernel's merge with <code>Password</code> left out of the payload, which is what the fingerprint covers and the confirmed write sends, and
/// out of the count of fields it sends unchanged.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    If pPayload.%GetTypeOf("Password") '= "unassigned" {
        Do pPayload.%Remove("Password")
        Set pUnchanged = pUnchanged - 1
    }
    Quit tSC
}

/// <p>The dialog's values as this tool's arguments, each declared one a string, an empty one included; the port judges them.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tNames = ..SettableFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tField = $List(tNames, tI)
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    Quit $$$OK
}

}
