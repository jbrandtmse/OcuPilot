/// <p>Interoperability's business partner update (AD-4, AD-6, AD-51, AD-53, AD-56, AD-62, Story 20.26): change the description or a
/// contact's field of one business partner of the request's namespace. The change is in effect at once. <b>The name cannot be
/// changed</b>: the vendor renames by deleting and creating, so every item that names the partner would point at nothing. To rename
/// a partner, add one under the new name, change the Business partner setting of each item that names the old one, then remove it.
/// A call carrying any argument beyond the thirteen fields is refused before any port call.</p>
/// <p>Two callers reach it: the partners list's row action Edit through <class>OcuPilot.Api.ScreenAction</class>, whose dialog sends
/// every field and may send an empty one, and the agent's proposal and confirmation. It is a merge over the partner's fresh read, so
/// its card shows one row for each field it moves and its read-back compares the thirteen fields
/// (<parameter>READBACKFIELDS</parameter>). <code>NamedBy</code> is part of the read and no part of the merge, the fingerprint or
/// the read-back: items that start or stop naming the partner do not close the proposal.</p>
Class OcuPilot.Screen.Tool.InteropPartnerUpdate Extends OcuPilot.Screen.Tool.InteropPartnerAction
{

Parameter TOOLNAME = "interop.businesspartners.update";

Parameter DESCRIPTION = "Propose changing the description or a contact's details of one business partner of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the partner exactly as the Business partners list reports it, and give only the fields to change; a field sent as an empty string is cleared and a field left out is kept. The partner's name cannot be changed. To rename one, add a partner under the new name, change the Business partner setting of each item that names the old one, then remove the old one. A field over its length and a namespace under source control are refused.";

Parameter WRITETYPE = "SETPARTNER";

/// <p>The read field a call's arguments do not carry and the merged payload does: the namespace. <code>NamedBy</code> is no
/// part of the payload (<method>MergeUpdate</method>), so it cannot mark one.</p>
Parameter STATEMARKER = "Namespace";

/// <p>The update sends a body: the partner's row with the new values (AD-4).</p>
Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "edit";

/// <p>The dialog sends the thirteen fields as this tool's values, each of which may be empty (AD-56 (ii)); the name is the target.</p>
Parameter SCREENVALUES = "edit=Description:PrimaryContact:PrimaryTitle:PrimaryEmail:PrimaryPhone:PrimaryMobile:PrimaryNotes:AlternativeContact:AlternativeTitle:AlternativeEmail:AlternativePhone:AlternativeMobile:AlternativeNotes";

Parameter SCREENEMPTY = "edit=Description:PrimaryContact:PrimaryTitle:PrimaryEmail:PrimaryPhone:PrimaryMobile:PrimaryNotes:AlternativeContact:AlternativeTitle:AlternativeEmail:AlternativePhone:AlternativeMobile:AlternativeNotes";

/// <p>What the read-back compares (AD-58).</p>
Parameter READBACKFIELDS = "Description,PrimaryContact,PrimaryTitle,PrimaryEmail,PrimaryPhone,PrimaryMobile,PrimaryNotes,AlternativeContact,AlternativeTitle,AlternativeEmail,AlternativePhone,AlternativeMobile,AlternativeNotes";

Parameter PRECONDITIONCODES = "INTEROP.PARTNER.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The thirteen fields an update may set.</p>
Parameter FIELDS = "Description,PrimaryContact,PrimaryTitle,PrimaryEmail,PrimaryPhone,PrimaryMobile,PrimaryNotes,AlternativeContact,AlternativeTitle,AlternativeEmail,AlternativePhone,AlternativeMobile,AlternativeNotes";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The thirteen fields as the field rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Quit ..PartnerFieldRows(0, .pRows)
}

/// <p>The derived schema with each field described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ..DescribeFields(##super(pDescriptor))
}

/// <p>No state rows: a merge's card shows the values it moves (<method>OcuPilot.Kernel.Proposal.Mint.Merge</method>), and a
/// partner nobody established is refused by the fresh read.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The kernel's merge with <code>NamedBy</code> left out of the payload, which is what the fingerprint covers and the confirmed
/// write sends, and out of the count of fields it sends unchanged.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    If pPayload.%GetTypeOf("NamedBy") '= "unassigned" {
        Do pPayload.%Remove("NamedBy")
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
