/// <p>The base of the three namespace mapping delete tools (AD-6, AD-8, AD-51, Story 18.14): propose
/// deleting one mapping. It reads the mapping fresh through the vendor's own <code>GET</code> and
/// mints a proposal whose card lists the fields the mapping holds. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor reads no body for <code>DELETE</code>, the tool
/// admits no settable field, and the port splits its composite id into the vendor's query. Its
/// fingerprint covers the template fields the read answers. A global's base mapping deleted while a
/// subscript-level mapping of the same global exists is refused by the vendor with nothing changed,
/// and that refusal reaches the caller as <code>MAPPING.NAME.SUBSCRIPTS</code>
/// (<parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter>).</p>
/// <p>It declares no replaced classic page: the classic delete is performed on
/// <code>%CSP.UI.Portal.Mappings</code>, which the list's descriptor already unions (AD-44).</p>
/// <p>A concrete subclass declares <parameter>TOOLNAME</parameter>,
/// <parameter>DESCRIPTORCLASS</parameter>, <parameter>DESCRIPTION</parameter>,
/// <parameter>ENDPOINT</parameter>, <parameter>MAPPINGKIND</parameter>, <parameter>READANSWERS</parameter>
/// and <parameter>FINGERPRINTSUBJECT</parameter>.</p>
Class OcuPilot.Screen.Tool.MappingDelete Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

Parameter READTYPE = "GET";

/// <p>The vendor's own delete request type, which answers 404 for an absent mapping.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted mapping is gone, and the namespace reads what it named from its default
/// database again.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the mapping list's Delete carries out (AD-53).</p>
Parameter SCREENACTIONS = "delete";

/// <p>The port that splits the composite id (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.NamespacePort";

Parameter PRECONDITIONFIELD = "Database";

/// <p>The kind's admin endpoint, declared by the subclass.</p>
Parameter ENDPOINT;

/// <p>The kind, declared by the subclass.</p>
Parameter MAPPINGKIND;

/// <p>The pair every mapping write needs beyond the list's own
/// (<parameter>OcuPilot.Screen.Tool.MappingCreate.WRITERESOURCE</parameter>).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

ClassMethod Endpoint() As %String
{
    Quit ..#ENDPOINT
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><class>OcuPilot.Screen.Tool.MappingMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.MappingMint"
}

/// <p>The derived schema with the namespace and the name described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Set tSchema = $ClassMethod(##class(OcuPilot.Area.OsMgmt.MappingRules).ToolClass(..#MAPPINGKIND, "Create"), "Described", tSchema, 0)
    If $IsObject(tSchema) && (tSchema.%GetTypeOf("properties") = "object") && (tSchema.%Get("properties").%GetTypeOf("Name") = "object") {
        Do tSchema.%Get("properties").%Get("Name").%Set("description", "The mapping to delete, exactly as this namespace's mapping list reports it. A mapping this namespace does not hold is refused.", "string")
    }
    Quit tSchema
}

/// <p>What the caller must hold: the list's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit tPairs
}

/// <p>The removal rows this proposal's card shows, from the fresh <code>GET</code>
/// <var>pFresh</var>: one per <parameter>READANSWERS</parameter> name, carrying the value the
/// instance holds and no after-state. A read that answered no <parameter>PRECONDITIONFIELD</parameter>
/// is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report that mapping's database, and a mapping whose database is unknown is not one to delete"
            Quit
        }
        Set tNames = ..ReadAnswers()
        For tI = 1:1:$ListLength(tNames) {
            Set tField = $List(tNames, tI)
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField)), "string")
            Do tRow.%Set("after", "", "string")
            Do tRow.%Set("removed", 1, "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
