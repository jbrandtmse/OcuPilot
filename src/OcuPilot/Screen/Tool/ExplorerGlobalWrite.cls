/// <p>What the globals' writes share (AD-6, AD-13, AD-52, AD-53, AD-55, Story 21.5): a write of one global or one node of the request's
/// namespace through <class>OcuPilot.Port.GlobalPort</class>, reached by the screen's own action and, for a whole global's delete, by the
/// agent's proposal and confirmation. A write sends no body: the port builds the vendor call from its query.</p>
/// <p><b>The namespace travels in the payload</b> (<parameter>NAMESPACEFIELD</parameter>, <method>PortQuery</method>), so a confirm writes
/// where the proposal read.</p>
/// <p><b>Its pairs</b> are its screen's, then the custom resource of each <parameter>CLASSICPAGES</parameter> page (AD-8, AD-44). WRITE on
/// the database a global resolves to is the instance's to check: a vendor <code>&lt;PROTECT&gt;</code> is the port's 403
/// <code>PORT.ACCESSDENIED</code>. OcuPilot's own and protected globals are refused by the kernel on both callers
/// (<class>OcuPilot.Kernel.Proposal.Prohibited</class>).</p>
Class OcuPilot.Screen.Tool.ExplorerGlobalWrite Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

/// <p>The port that reads and writes a global or a node (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.GlobalPort";

/// <p>No body: the port builds the vendor call from its query (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The payload field naming the namespace the write runs in.</p>
Parameter NAMESPACEFIELD = "Namespace";

/// <p>The description the input schema gives the identifying property.</p>
Parameter IDDESCRIPTION;

/// <p>The consequence code the card and the dialog state (<method>Consequence</method>).</p>
Parameter CONSEQUENCECODE;

/// <p>The screen's own pairs, then the custom resource of each <parameter>CLASSICPAGES</parameter> page, each pair once.
/// <var>pResolved</var> is 0 when the screen's pairs cannot be read.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The identifying property described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", ..#IDDESCRIPTION, "string")
    Quit tSchema
}

/// <p>The namespace the stored payload <var>pPayload</var> was read or composed in, under the port's own query key, so the confirm's
/// re-read and write and every read-back reach the namespace the proposal named (AD-52). A fresh read, whose payload is empty, is scoped
/// by the port.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.GlobalPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

/// <p><parameter>CONSEQUENCECODE</parameter>, the note the card states.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

}
