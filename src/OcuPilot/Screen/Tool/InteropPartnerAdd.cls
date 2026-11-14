/// <p>Interoperability's business partner add (AD-3, AD-6, AD-54, AD-55, AD-62, Story 20.26): add one business partner to the
/// request's namespace, with its description and both contacts. Two callers reach it: the partners list's New business partner
/// dialog through <class>OcuPilot.Area.Interop.PartnerSave</class>, and the agent's proposal and confirmation. The partner is in
/// effect at once.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no partner of that name, and a name added since the mint reads present at
/// the confirm's re-read and closes the proposal target-changed. The vendor stores a name that differs from another only in letter
/// case as a second partner, so the port refuses it by name (<code>INTEROP.PARTNER.NAMECASE</code>).</p>
/// <p><b>Its payload</b> is the name and the thirteen fields the caller supplies and the namespace the add was composed in
/// (<method>ComposeCreate</method>). The port has no body template to derive a field list from, so the fields are declared here
/// (<method>FieldRows</method>, AD-3) and its read-back compares them (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.InteropPartnerAdd Extends OcuPilot.Screen.Tool.InteropPartnerAction
{

Parameter TOOLNAME = "interop.businesspartners.add";

Parameter DESCRIPTION = "Propose adding one business partner to the namespace the user is working in. A business partner is information about an organization or application a production connects to; saving one changes nothing in how a production runs. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give the partner's name, which cannot be changed afterwards, and any of its description and its primary and alternative contacts; a field left out stays empty. A name the namespace already holds, in any letter case, a field over its length and a namespace under source control are refused.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADDPARTNER";

/// <p>The add sends a body: the composed payload (AD-4 has no subject for a create).</p>
Parameter SENDSBODY As BOOLEAN = 1;

/// <p>What the read-back compares, the fields a create sends (AD-58).</p>
Parameter READBACKFIELDS = "Description,PrimaryContact,PrimaryTitle,PrimaryEmail,PrimaryPhone,PrimaryMobile,PrimaryNotes,AlternativeContact,AlternativeTitle,AlternativeEmail,AlternativePhone,AlternativeMobile,AlternativeNotes";

/// <p>The read-back re-reads the created partner through the update's single-object read, because the add's own read asks for the add
/// and answers a held name as <code>TAKEN</code> (AD-58).</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.InteropPartnerUpdate";

Parameter PRECONDITIONCODES = "INTEROP.PARTNER.TAKEN,INTEROP.PARTNER.NAMECASE,INTEROP.PARTNER.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The fields an add may set, in the order the card lists them.</p>
Parameter FIELDS = "Name,Description,PrimaryContact,PrimaryTitle,PrimaryEmail,PrimaryPhone,PrimaryMobile,PrimaryNotes,AlternativeContact,AlternativeTitle,AlternativeEmail,AlternativePhone,AlternativeMobile,AlternativeNotes";

/// <p>An add judges the name it is given.</p>
Parameter JUDGESNAME As BOOLEAN = 1;

/// <p>The name and the thirteen fields an add sets.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The fourteen fields as the field rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Quit ..PartnerFieldRows(1, .pRows)
}

/// <p>What the schema says of the new partner's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The new business partner's name: 1 to 255 characters with no control character. It cannot be changed afterwards. A name the namespace already holds, in any letter case, is refused, so check the Business partners list first."
}

/// <p>The derived schema with each field described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ..DescribeFields(##super(pDescriptor))
}

/// <p>The composed payload and diff of the create (AD-54): the name and the fields the caller supplied, as the kernel's
/// <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> composes them, and the namespace the request is scoped to, which the port
/// query and the prohibited set read. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The name of the partner the confirmed add <var>pWritten</var> created, or <code>""</code>: the id its read-back re-reads it by.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("Name") '= "string" Quit ""
    Quit pWritten.%Get("Name")
}

/// <p>The add always asks its read for the add (<parameter>OcuPilot.Port.InteropPort.ACTIONKEY</parameter>): present is
/// <code>TAKEN</code> and absent is the 404 a create expects (AD-54), at the mint and at the confirm alike. The namespace is the
/// payload's, else the request's scope.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ..#WRITETYPE
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

}
