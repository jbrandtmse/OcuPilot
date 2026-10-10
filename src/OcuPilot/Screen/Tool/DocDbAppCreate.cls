/// <p>The Doc DB applications' create tool (AD-54, AD-55, Story 18.30): propose a new Doc DB application record. It
/// reads the intended record fresh through the vendor's own <code>DocDB</code> <code>GET</code>, requires that read to
/// answer <b>nothing</b>, composes the body from the settings the arguments supply and mints a proposal the user
/// confirms. It writes nothing.</p>
/// <p>The agent names the record with <code>Namespace</code> and <code>Name</code>;
/// <class>OcuPilot.Screen.Tool.MappingMint</class> joins them into the composite id the list's rows carry, and
/// <class>OcuPilot.Port.DocDbAppPort</class> splits it for the vendor. The vendor's <code>PUT</code> is an upsert that
/// resolves a name in any case, so the absence fingerprint is what stops a confirmed create rewriting a record
/// somebody else created since the mint (AD-54). The vendor stores the name exactly as sent, so
/// <method>TypedId</method> hands the confirm and the draft the name as typed. The rules of
/// <method>OcuPilot.Area.WebApp.DocDbAppRules.Check</method> refuse the arguments at the mint, the same rules the
/// screen's Save applies. <b>It never creates or drops a document database</b>: a record only registers a name.</p>
Class OcuPilot.Screen.Tool.DocDbAppCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "webapp.docdbapps.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DocDbAppList";

Parameter DESCRIPTION = "Propose a new Doc DB application record. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace the document database lives in and the record's name, a class name kept exactly as written, and optionally its description, whether it is enabled and the service or application resource that controls it. A record that already exists under that name in any case is refused. The record only registers a name: it does not create or drop a document database.";

/// <p>The port that splits the composite id (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.DocDbAppPort";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The vendor's one write that takes a body, an upsert.</p>
Parameter WRITETYPE = "PUT";

/// <p>The three settings this tool admits
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same).</p>
Parameter PERMITTEDFIELDS = "Description,Enabled,Resource";

/// <p>The pair this tool requires beyond the list's own: none, and the declaration keeps the idiom of every tool of
/// the area (AD-8). The area's set is what the write needs, measured at Story 18.30's plan.</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>The classic editor whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Applications.DocDB";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.WebApp.DocDbAppRules";

/// <p>The argument naming the record's namespace.</p>
Parameter NAMESPACEARGUMENT = "Namespace";

ClassMethod Endpoint() As %String
{
    Quit "DocDB"
}

/// <p><class>OcuPilot.Screen.Tool.MappingMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.MappingMint"
}

/// <p>The vendor's <code>name</code> query parameter, which carries the composite id the port splits.</p>
ClassMethod IdParam() As %String
{
    Quit "name"
}

/// <p>The composite id of <var>pArgs</var>' <code>Namespace</code> and <code>Name</code> as the caller typed them, or
/// <code>""</code> when either is not text: what the confirm and the draft send, so the vendor stores the name as
/// written.</p>
ClassMethod TypedId(pArgs As %DynamicObject) As %String
{
    If '$IsObject(pArgs) Quit ""
    If (pArgs.%GetTypeOf(..#NAMESPACEARGUMENT) '= "string") || (pArgs.%GetTypeOf(..IdArgument()) '= "string") Quit ""
    Set tNamespace = pArgs.%Get(..#NAMESPACEARGUMENT)
    Set tName = pArgs.%Get(..IdArgument())
    If (tNamespace = "") || (tName = "") Quit ""
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tNamespace, tName))
}

/// <p>The <code>ordinary</code> derived fields this tool admits (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with <parameter>NAMESPACEARGUMENT</parameter> required and every field described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ..Described(##super(pDescriptor), 1)
}

/// <p><var>pSchema</var> with <parameter>NAMESPACEARGUMENT</parameter> added, required, and the name and each setting
/// described, for a create when <var>pCreates</var> is 1 and for an edit or a delete otherwise. <code>Enabled</code> is
/// typed boolean, the type the instance reads it as, and its description names every value the rules admit. Every
/// Doc DB application tool's schema is described here.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Do tProperties.%Set(..#NAMESPACEARGUMENT, {"type": "string", "description": "The namespace the record belongs to, as the Namespaces list shows it. It must be a namespace this instance defines."})
    If pSchema.%GetTypeOf("required") = "array" Do pSchema.%Get("required").%Push(..#NAMESPACEARGUMENT)
    If pCreates {
        Set tDescriptions("Name") = "The name the new record takes, a class name such as My.Docs, kept exactly as written. A record that already exists under the name in any case is refused."
    } Else {
        Set tDescriptions("Name") = "The record, exactly as the Doc DB applications list reports its name."
    }
    Set tDescriptions("Description") = "A description of the record, at most 256 characters."
    Set tDescriptions("Enabled") = "Whether the record is enabled. One of true, false, 1, 0, ""1"" or ""0""; any other value is refused. Send true or false."
    Set tDescriptions("Resource") = "The service or application resource that controls the document database, as the Resources list names it. Empty for none. A resource the instance does not list as a service or application resource is refused."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    If tProperties.%GetTypeOf("Enabled") = "object" Do tProperties.%Get("Enabled").%Set("type", "boolean", "string")
    Quit pSchema
}

/// <p>The create's body: <var>pArgs</var> as <method>OcuPilot.Area.WebApp.DocDbAppRules.CreateBody</method> completes
/// it -- <code>Enabled</code> a boolean and the omitted settings at the instance's defaults -- so the diff the user
/// reviews and the body sent read the same, then the kernel's composition.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Quit ##super($ClassMethod(..#RULES, "CreateBody", pArgs), pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p>The rules over the agent's arguments, create mode, each broken one as its field and published sentence
/// (AD-55). <var>pIdValue</var> is the composite id; the name look-up is skipped, the mint's absence read having
/// answered it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    Quit $ClassMethod(..#RULES, "Problem", $ListGet(tParts, 1), $ListGet(tParts, 2), pArgs, "", "create", ..PortClass(), .pProblem, 1)
}

/// <p>What the caller must hold: the list's own pairs, then <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>
/// and the custom resource of the <parameter>CLASSICPAGES</parameter> editor, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
