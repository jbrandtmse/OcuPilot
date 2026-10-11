/// <p>The spec-based REST services' create (AD-53, AD-54, AD-55, Story 18.32): propose building a service in the
/// request's namespace from a whole OpenAPI 2.0 document, which compiles <code>&lt;Name&gt;.spec</code>,
/// <code>.disp</code> and <code>.impl</code>. The agent reaches it by proposal and confirmation; the person's caller is
/// <class>OcuPilot.Area.WebApp.RestServiceSave</class> (<code>POST /rest-service</code>), which meets the port's rules and
/// not <method>AgentProblems</method>.</p>
/// <p><b>It is the agent's second code path</b> (AD-53): the classes are compiled from the document, so the mint and
/// the confirm hold it to the code saves' rules (<method>AgentProblems</method>: only the namespace's own routines
/// database, never <code>%SYS</code> or a <code>%</code> name, for each of the three classes), and a package beginning
/// with <code>OcuPilot</code> is refused by the kernel on either caller
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTCODE</parameter>). The mint is
/// <class>OcuPilot.Screen.Tool.RestServiceCreateMint</class>.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no service of that name, and no class of its specification's or
/// dispatch class's name, in any letter case, and a name taken since the mint reads present at the confirm's re-read and
/// closes the proposal target-changed. An implementation
/// class that already exists keeps its code (measured).</p>
/// <p><b>Its payload is <code>{Name, Document, Namespace}</code></b> (<method>ComposeCreate</method>); the card shows the
/// whole document as added lines, at most <parameter>OcuPilot.Screen.Tool.ExplorerSave.CHANGEMAXLENGTH</parameter>
/// characters, and the port is handed the parsed document, never text (AD-21). Its read-back compares
/// <code>Name</code> (<parameter>READBACKFIELDS</parameter>, AD-58). No vendor event records the create, and no classic
/// page creates a REST service, so it declares no classic page (AD-44).</p>
Class OcuPilot.Screen.Tool.RestServiceCreate Extends OcuPilot.Screen.Tool.RestServiceWrite
{

Parameter TOOLNAME = "webapp.restapis.create";

Parameter DESCRIPTION = "Propose creating a spec-based REST service in this namespace from a whole OpenAPI 2.0 document. It creates nothing by itself: it answers a proposal the user reviews and confirms, and confirming compiles the classes <Name>.spec, <Name>.disp and <Name>.impl. Name is the package: letters and digits in dot-separated parts, each starting with a letter, with no percent sign, at most 215 characters. Document is the OpenAPI 2.0 document as a JSON object, never text or a URL, whose swagger member is 2.0; it must fit one card: formatted and escaped as the card carries it, it is at most 30,000 characters. A name this namespace already lists, or whose <Name>.spec or <Name>.disp class it already holds, in any letter case, a name whose class begins with OcuPilot, a package whose classes would be stored outside this namespace's own routines database, and %SYS are refused. An implementation class that already exists keeps its code.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

/// <p>The fresh read: whether the namespace lists a service of the name, in any letter case.</p>
Parameter READTYPE = "STATE";

Parameter WRITETYPE = "POST";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Name,Namespace";

/// <p>What the read-back compares, the one value the instance reports back (AD-58).</p>
Parameter READBACKFIELDS = "Name";

/// <p>The consequence code the proposal carries: confirming compiles the classes.</p>
Parameter CONSEQUENCE = "RESTSERVICE.CREATE.COMPILES";

/// <p>The argument and payload member carrying the OpenAPI document.</p>
Parameter DOCUMENTFIELD = "Document";

/// <p>The suffixes of the three classes a create builds from its package, comma-separated: the specification, the
/// dispatch and the implementation class. <method>AgentProblems</method> holds each to the code saves' rules.</p>
Parameter CLASSPARTS = "spec,disp,impl";

/// <p><parameter>CONSEQUENCE</parameter>, the code every create's proposal carries: confirming compiles the classes.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

/// <p>The package and the document, the two values a create sends.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..IdArgument(), ..#DOCUMENTFIELD)
}

/// <p>The package as a string and the document as an object: the rows the generated field lists would carry.</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 2
    Set pRows(1) = $ListBuild(..IdArgument(), "string", 0)
    Set pRows(2) = $ListBuild(..#DOCUMENTFIELD, "object", 0)
    Quit $$$OK
}

/// <p>The schema: the package, the document and the agent's own words. The namespace is never advertised: a create
/// runs in the request's namespace.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..IdArgument(), {"type": "string", "description": "The package the new service takes: letters and digits in dot-separated parts, each starting with a letter, with no percent sign, at most 215 characters. The classes <Name>.spec, <Name>.disp and <Name>.impl are created. A name this namespace already lists, or whose <Name>.spec or <Name>.disp class it already holds, in any letter case, is refused, so check the REST API explorer first."})
    Do tSchema.%Get("required").%Push(..IdArgument())
    Set tLimit = $FNumber(##class(OcuPilot.Screen.Tool.ExplorerSave).#CHANGEMAXLENGTH, ",")
    Do tProperties.%Set(..#DOCUMENTFIELD, {"type": "object", "description": ("The whole OpenAPI 2.0 document, as a JSON object (never a string or a URL), whose swagger member is the string 2.0. The user reviews it as sent, formatted, and it must fit one card: formatted and escaped as the card carries it, at most " _ tLimit _ " characters.")})
    Do tSchema.%Get("required").%Push(..#DOCUMENTFIELD)
    Do tProperties.%Set("rationale", {"type": "string", "description": "Why this service is being proposed, in one sentence, shown to the user above the document."})
    Do tProperties.%Set("expectedImpact", {"type": "string", "description": "What the user should expect to happen once this is confirmed, in one sentence."})
    Do tProperties.%Set("reverse", {"type": "string", "description": "How to undo this create, in one sentence. Omit it where no reversal exists."})
    Quit tSchema
}

/// <p>The port's rules for a create, as the port refuses them (AD-55): the package
/// (<method>OcuPilot.Port.MgmntPort.NameProblem</method>), then the document
/// (<method>OcuPilot.Port.MgmntPort.DocumentProblem</method>).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ##class(OcuPilot.Port.MgmntPort).NameProblem(pIdValue)
    If pProblem = "" Set pProblem = ##class(OcuPilot.Port.MgmntPort).DocumentProblem(pArgs)
    Quit $$$OK
}

/// <p>What is wrong with building the three classes of package <var>pName</var> in <var>pNamespace</var> on the agent's
/// behalf, or <code>""</code>: the first refusal of
/// <method>OcuPilot.Screen.Tool.ExplorerSave.AgentProblem</method>, as a class create, for the specification, the
/// dispatch and the implementation class in turn.</p>
ClassMethod AgentProblems(pNamespace As %String, pName As %String) As %String
{
    Set tProblem = ""
    Set tParts = $ListFromString(..#CLASSPARTS)
    For tI = 1:1:$ListLength(tParts) {
        Set tProblem = ##class(OcuPilot.Screen.Tool.ExplorerSave).AgentProblem(pNamespace, pName _ "." _ $List(tParts, tI) _ ".cls", 1)
        If tProblem '= "" Quit
    }
    Quit tProblem
}

/// <p>The mint's class for an agent's create: <class>OcuPilot.Screen.Tool.RestServiceCreateMint</class>.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.RestServiceCreateMint"
}

/// <p>The refusal of the agent's confirmed create, asked again at Confirm with the stored namespace:
/// <method>AgentProblems</method>, so a package the mint refused, or one whose classes would now be stored in another
/// database, refuses here before anything is sent. Stored arguments that are not an object refuse too.</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) {
        Set pProblem = "the proposal's stored arguments could not be read, so the agent does not create it"
        Quit $$$OK
    }
    Set pProblem = ..AgentProblems(pArgs.%Get(..#NAMESPACEFIELD), pIdValue)
    Quit $$$OK
}

/// <p>The composed payload and diff of the create (AD-54): <code>{Name, Document, Namespace}</code>, the package as the
/// caller typed it, the document it sent and the namespace the mint read. The diff is the one row the mint computed,
/// the whole formatted document as added lines, and the unchanged count is zero.</p>
/// <p><b>Caller contract:</b> the same signature as <method>OcuPilot.Screen.Tool.Write.ComposeCreate</method>.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = {}
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tName = ""
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(pIdArgument) = "string") Set tName = pArgs.%Get(pIdArgument)
    Do pPayload.%Set(pIdArgument, tName, "string")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#DOCUMENTFIELD) = "object") Do pPayload.%Set(..#DOCUMENTFIELD, pArgs.%Get(..#DOCUMENTFIELD))
    Do pPayload.%Set(..#NAMESPACEFIELD, $Select($IsObject(pArgs) && (pArgs.%GetTypeOf(..#NAMESPACEFIELD) = "string"): pArgs.%Get(..#NAMESPACEFIELD), 1: ""), "string")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Hunk") = "object") Do pDiff.%Push(pArgs.%Get("Hunk"))
    Quit $$$OK
}

}
