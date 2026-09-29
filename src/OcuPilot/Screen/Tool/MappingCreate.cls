/// <p>The base of the three namespace mapping create tools (AD-54, AD-55, Story 18.14): propose a
/// new global, routine or package mapping in one namespace. It reads the intended mapping fresh
/// through the vendor's own <code>GET</code>, requires that read to answer <b>nothing</b>, composes
/// the payload from its arguments and mints a proposal the user confirms. It writes nothing.</p>
/// <p>The agent names the mapping with <code>Namespace</code> and <code>Name</code>;
/// <class>OcuPilot.Screen.Tool.MappingMint</class> joins them into the composite id the mapping lists'
/// rows carry, and <class>OcuPilot.Port.NamespacePort</class> splits it for the vendor. The kind's
/// template fields are the settable ones, with <code>Database</code> required, and the editor's own
/// rules (<method>OcuPilot.Area.OsMgmt.MappingRules.Validate</method>) refuse the arguments at the
/// mint, the same rules the screen's Save applies.</p>
/// <p>The vendor's <code>PUT</code> is an upsert, so the absence fingerprint is what stops a confirmed
/// create rewriting a mapping somebody else created since the mint (AD-54).</p>
/// <p>A concrete subclass declares <parameter>TOOLNAME</parameter>,
/// <parameter>DESCRIPTORCLASS</parameter>, <parameter>DESCRIPTION</parameter>,
/// <parameter>ENDPOINT</parameter>, <parameter>MAPPINGKIND</parameter>,
/// <parameter>PERMITTEDFIELDS</parameter> and <parameter>CLASSICPAGES</parameter>.</p>
Class OcuPilot.Screen.Tool.MappingCreate Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The vendor request type a create is issued with: the mapping endpoint's <code>PUT</code>, an
/// upsert.</p>
Parameter WRITETYPE = "PUT";

/// <p>The port that splits the composite id (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.NamespacePort";

/// <p>The kind's admin endpoint, declared by the subclass.</p>
Parameter ENDPOINT;

/// <p>The kind, <code>global</code>, <code>routine</code> or <code>package</code>, declared by the
/// subclass.</p>
Parameter MAPPINGKIND;

/// <p>The derived top-level fields this tool admits, comma-separated, declared by the subclass
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same).</p>
Parameter PERMITTEDFIELDS;

/// <p>The pair every mapping write needs beyond the mapping list's own: <code>%DB_IRISSYS:WRITE</code>.
/// The mapping classes write the system database, and a principal holding only the list's pairs was
/// refused there with nothing changed (AD-8, measured on <code>ocupilot-b-ci</code>).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The argument naming the mapping's namespace.</p>
Parameter NAMESPACEARGUMENT = "Namespace";

ClassMethod Endpoint() As %String
{
    Quit ..#ENDPOINT
}

/// <p>The <code>ordinary</code> top-level fields this tool admits, derived rather than transcribed
/// (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p><class>OcuPilot.Screen.Tool.MappingMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.MappingMint"
}

/// <p>The derived schema with <parameter>NAMESPACEARGUMENT</parameter> and <code>Database</code>
/// required and every field described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Set tSchema = ..Described(tSchema, 1)
    If $IsObject(tSchema) && (tSchema.%GetTypeOf("required") = "array") && (tSchema.%GetTypeOf("properties") = "object") {
        If tSchema.%Get("properties").%GetTypeOf("Database") = "object" Do tSchema.%Get("required").%Push("Database")
    }
    Quit tSchema
}

/// <p><var>pSchema</var> with <parameter>NAMESPACEARGUMENT</parameter> added, required, and the name
/// and the template fields described, for a create when <var>pCreates</var> is 1 and for an edit or
/// a delete otherwise. Every mapping tool's schema is described here.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) Quit pSchema
    If pSchema.%GetTypeOf("properties") '= "object" Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Do tProperties.%Set(..#NAMESPACEARGUMENT, {"type": "string", "description": "The namespace the mapping belongs to, as the Namespaces list shows it. %ALL applies the mapping to every namespace."})
    If pSchema.%GetTypeOf("required") = "array" Do pSchema.%Get("required").%Push(..#NAMESPACEARGUMENT)
    Set tDescriptions("Database") = "The database the namespace reads what this mapping names from, named as this instance's databases list names it."
    Set tDescriptions("LockDatabase") = "The database the mapped global's locks are taken in, named as this instance's databases list names it. Empty for the mapped database itself."
    Set tDescriptions("Collation") = "The collation of a new global created through this mapping, a whole number; 5 is IRIS standard."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    If tProperties.%GetTypeOf("Name") = "object" {
        If pCreates {
            Set tName = "The name to map, as the classic mapping dialog takes it."
            If ..#MAPPINGKIND = "global" Set tName = "The global to map, without its caret, optionally with a subscript range such as Name(""a""):(""m""). A name beginning with % maps a system global. A name this namespace already maps is refused, so check its global mappings list first."
            If ..#MAPPINGKIND = "routine" Set tName = "The routine name or pattern to map, such as Name or Name*, optionally limited to one type with a suffix in capitals such as Name_MAC. A name this namespace already maps is refused, so check its routine mappings list first."
            If ..#MAPPINGKIND = "package" Set tName = "The package to map, such as My.Package. A name this namespace already maps is refused, so check its package mappings list first."
            Do tProperties.%Get("Name").%Set("description", tName, "string")
        } Else {
            Do tProperties.%Get("Name").%Set("description", "The mapping's name, exactly as this namespace's mapping list reports it.", "string")
        }
    }
    Quit pSchema
}

/// <p>The editor's own rules over the agent's arguments, create mode, each broken rule as its field
/// and published sentence (AD-55). <var>pIdValue</var> is the composite id; the name look-up is
/// skipped, because the mint's absence read has answered it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..RuleProblem(pIdValue, pArgs, "create", .pProblem)
}

/// <p><method>OcuPilot.Area.OsMgmt.MappingRules.Validate</method> over <var>pArgs</var> for the
/// mapping whose composite id is <var>pIdValue</var>, in mode <var>pMode</var>, the look-up never, as
/// one <var>pProblem</var> naming each field and its published sentence.</p>
ClassMethod RuleProblem(pIdValue As %String, pArgs As %DynamicObject, pMode As %String, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    Set tSC = ##class(OcuPilot.Area.OsMgmt.MappingRules).Validate(..#MAPPINGKIND, $ListGet(tParts, 1), $ListGet(tParts, 2), pArgs, .tViolations, pMode, 0)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tField = $List(tViolations(tI), 1)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ tField _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>Each database field in the spelling this instance's databases list gives it, just before the
/// port is invoked (<method>OcuPilot.Area.OsMgmt.MappingRules.Spell</method>).</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.OsMgmt.MappingRules).Spell(pPayload)
}

/// <p>What the caller must hold: the list's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, then the custom
/// resource of the <parameter>CLASSICPAGES</parameter> dialog, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
