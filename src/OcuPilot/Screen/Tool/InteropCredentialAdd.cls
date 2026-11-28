/// <p>Interoperability's credential add (AD-3, AD-6, AD-54, AD-55, AD-62, Story 24.15): add one credential to the request's namespace, with its user
/// name, its business partner and, optionally, its password. Two callers reach it: the Credentials list's New credential dialog through
/// <class>OcuPilot.Area.Interop.CredentialSave</class>, and the agent's proposal and confirmation. The credential is in effect at once.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no credential of that name in any letter case, because the vendor's adapters resolve a name
/// ignoring case, and a name added since the mint reads present at the confirm's re-read and closes the proposal target-changed.</p>
/// <p><b>The password is a composed secret</b> (<method>ComposedSecrets</method>): it is declared in the screen's <code>secretArguments</code>, so it
/// is absent from this schema, refused from the model at the mint, never stored, and supplied at the confirm on the card beside the masked row, where
/// it may be left empty and then no password is stored (<method>OptionalSecrets</method>).</p>
/// <p><b>Its payload</b> is the name and the fields the caller supplies and the namespace the add was composed in (<method>ComposeCreate</method>);
/// its read-back compares the user name and the business partner (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.InteropCredentialAdd Extends OcuPilot.Screen.Tool.InteropCredentialAction
{

Parameter TOOLNAME = "interop.credentials.add";

Parameter DESCRIPTION = "Propose adding one credential to the namespace the user is working in. A credential holds a user name and a password that a production setting names to sign in to another system. It changes nothing by itself: it answers a proposal the user reviews and confirms, and the user types the password on the card at that point -- never send a password. Give the credential's name, which cannot be changed afterwards, and optionally its user name and the business partner it belongs to; a field left out stays empty. A name the namespace already holds, in any letter case, a name over 50 characters, a business partner the namespace does not hold and a user name the instance does not accept are refused.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADDCREDENTIAL";

/// <p>The add sends a body: the composed payload, and the password the confirm supplies (AD-4 has no subject for a create).</p>
Parameter SENDSBODY As BOOLEAN = 1;

/// <p>What the read-back compares, the fields a create sends that a read answers (AD-58). The password is never read.</p>
Parameter READBACKFIELDS = "Username,BusinessPartner";

/// <p>The read-back re-reads the created credential through the update's single-object read, because the add's own read asks for the add and
/// answers a held name as <code>TAKEN</code> (AD-58).</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.InteropCredentialUpdate";

Parameter PRECONDITIONCODES = "INTEROP.CREDENTIAL.TAKEN,INTEROP.NAMESPACE";

/// <p>The fields an add may set, in the order the card lists them.</p>
Parameter FIELDS = "Name,Username,BusinessPartner";

/// <p>The secret the confirm supplies and the payload never carries.</p>
Parameter COMPOSEDSECRETS = "Password";

/// <p>An add judges the name it is given.</p>
Parameter JUDGESNAME As BOOLEAN = 1;

/// <p>The name, the two fields an add sets and the password the confirm composes.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS) _ ..ComposedSecrets()
}

/// <p>The three fields as the field rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Quit ..CredentialFieldRows(1, .pRows)
}

/// <p>What the schema says of the new credential's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The new credential's name: 1 to 50 characters with no control character. It cannot be changed afterwards. A name the namespace already holds, in any letter case, is refused, so check the Credentials list first."
}

/// <p>The derived schema with each field described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ..DescribeFields(##super(pDescriptor))
}

/// <p>The declared secret the body carries and the payload does not, for the mint's masked diff row (AD-6): <parameter>COMPOSEDSECRETS</parameter>.</p>
ClassMethod ComposedSecrets() As %List
{
    Quit $ListFromString(..#COMPOSEDSECRETS)
}

/// <p>The password may be left empty at the confirm: no password is then stored.</p>
ClassMethod OptionalSecrets() As %List
{
    Quit $ListFromString(..#COMPOSEDSECRETS)
}

/// <p>The names a confirm may carry (AD-6): the declared secrets this tool composes, which is the password alone.</p>
ClassMethod ChannelSecretNames(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set tDeclared = ..SecretArguments(pDescriptor, .pDeclared)
    Set tOwn = ..ComposedSecrets()
    Set tNames = ""
    For tI = 1:1:$ListLength(tOwn) {
        If $ListFind(tDeclared, $List(tOwn, tI)) Set tNames = tNames _ $ListBuild($List(tOwn, tI))
    }
    Quit tNames
}

/// <p>The card's masked rows: one <code>{field, before, after}</code> per <parameter>COMPOSEDSECRETS</parameter> name, both sides empty, carrying
/// <code>optional: true</code> where <method>OptionalSecrets</method> names it. They carry no value; the confirm supplies one or none.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tNames = ..ComposedSecrets()
    Set tOptional = ..OptionalSecrets()
    For tI = 1:1:$ListLength(tNames) {
        Set tRow = {}
        Do tRow.%Set("field", $List(tNames, tI), "string")
        Do tRow.%Set("before", "", "string")
        Do tRow.%Set("after", "", "string")
        If $ListFind(tOptional, $List(tNames, tI)) Do tRow.%Set("optional", 1, "boolean")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

/// <p>Drop an empty password from <var>pPayload</var>: the card sends every masked field, an optional one left empty as <code>""</code>, and an add
/// stores a password only when one was entered, as the screen's Save does, so the two callers' bodies are one body.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    For tI = 1:1:$ListLength(..ComposedSecrets()) {
        Set tName = $List(..ComposedSecrets(), tI)
        If (pPayload.%GetTypeOf(tName) = "string") && (pPayload.%Get(tName) = "") Do pPayload.%Remove(tName)
    }
}

/// <p>The composed payload and diff of the create (AD-54): the name and the fields the caller supplied, as the kernel's
/// <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> composes them, and the namespace the request is scoped to, which the port query and the
/// prohibited set read. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The name of the credential the confirmed add <var>pWritten</var> created, or <code>""</code>: the id its read-back re-reads it by.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("Name") '= "string" Quit ""
    Quit pWritten.%Get("Name")
}

/// <p>The add always asks its read for the add (<parameter>OcuPilot.Port.InteropPort.ACTIONKEY</parameter>): present, in any letter case, is
/// <code>TAKEN</code> and absent is the 404 a create expects (AD-54), at the mint and at the confirm alike. The namespace is the payload's, else the
/// request's scope.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ..#WRITETYPE
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

}
