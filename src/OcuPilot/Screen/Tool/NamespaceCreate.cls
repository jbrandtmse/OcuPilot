/// <p>The Namespaces list's create tool (AD-54, AD-55): propose a new namespace on this instance. It
/// reads the intended name fresh through the vendor's own <code>Namespace.Namespace</code>
/// <code>GET</code>, requires that read to answer <b>nothing</b>, composes the payload from its
/// arguments and mints a proposal the user confirms. It writes nothing.</p>
/// <p>It admits the three template fields (<parameter>PERMITTEDFIELDS</parameter>) and requires the
/// globals and routines databases. The namespace editor's own rules
/// (<method>OcuPilot.Area.OsMgmt.NamespaceRules.Validate</method>) refuse the arguments at the mint,
/// the same rules the screen's Save applies.</p>
/// <p>The vendor's <code>PUT</code> is an upsert, so the absence fingerprint is what stops a confirmed
/// create rewriting a namespace somebody else created since the mint (AD-54). The name travels only
/// as the vendor's <code>name</code> query parameter.</p>
Class OcuPilot.Screen.Tool.NamespaceCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.namespaces.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.NamespaceList";

Parameter DESCRIPTION = "Propose a new namespace on this instance. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace and the databases it reads its globals and routines from; it creates no database, web application or mapping.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The vendor request type a create is issued with: <code>Namespace.Namespace</code>'s
/// <code>PUT</code>, an upsert.</p>
Parameter WRITETYPE = "PUT";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same three).</p>
Parameter PERMITTEDFIELDS = "Globals,Routines,TempGlobals";

/// <p>The fields the vendor's create refuses a body without.</p>
Parameter REQUIREDFIELDS = "Globals,Routines";

/// <p>The pair every namespace write needs beyond the Namespaces list's own:
/// <code>%DB_IRISSYS:WRITE</code>. <code>Config.Namespaces</code> writes the system database, and a
/// principal holding only the list's pairs was refused there (AD-8, measured on
/// <code>ocupilot-b-ci</code>).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

ClassMethod Endpoint() As %String
{
    Quit "Namespace.Namespace"
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

/// <p>The derived schema with every field described and <parameter>REQUIREDFIELDS</parameter>
/// required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Set tSchema = ..Described(tSchema, 1)
    If $IsObject(tSchema) && (tSchema.%GetTypeOf("required") = "array") && (tSchema.%GetTypeOf("properties") = "object") {
        For tI = 1:1:$Length(..#REQUIREDFIELDS, ",") {
            Set tField = $Piece(..#REQUIREDFIELDS, ",", tI)
            If tSchema.%Get("properties").%GetTypeOf(tField) = "object" Do tSchema.%Get("required").%Push(tField)
        }
    }
    Quit tSchema
}

/// <p><var>pSchema</var> with the name and the three fields described, for a create when
/// <var>pCreates</var> is 1 and for an edit otherwise.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) Quit pSchema
    If pSchema.%GetTypeOf("properties") '= "object" Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Set tDescriptions("Globals") = "The database the namespace reads and writes its globals in, named as this instance's databases list names it."
    Set tDescriptions("Routines") = "The database the namespace reads its routines and classes from, named as this instance's databases list names it."
    Set tDescriptions("TempGlobals") = "The database the namespace keeps its temporary globals in, named as this instance's databases list names it. Omit it on a create to take the instance's default."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    If tProperties.%GetTypeOf("Name") = "object" {
        If pCreates {
            Do tProperties.%Get("Name").%Set("description", "The name the new namespace will take: a letter or %, then letters, digits, _ or -, at most 64 characters. The instance stores it upper case, and a name it already holds in any case is refused, so check the namespaces list first.", "string")
        } Else {
            Do tProperties.%Get("Name").%Set("description", "The namespace to change, as this instance's own namespaces list reports it.", "string")
        }
    }
    Quit pSchema
}

/// <p>The namespace editor's own rules over the agent's arguments, create mode, each broken rule as
/// its field and published sentence (AD-55). The name look-up is skipped: the mint's absence read has
/// answered it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..RuleProblem(pIdValue, pArgs, "create", "", .pProblem)
}

/// <p><method>OcuPilot.Area.OsMgmt.NamespaceRules.Validate</method> over <var>pArgs</var> for
/// <var>pIdValue</var> in mode <var>pMode</var>, against the fresh read <var>pFresh</var> where an
/// edit has one, the look-up never, as one <var>pProblem</var> naming each field and its published
/// sentence.</p>
ClassMethod RuleProblem(pIdValue As %String, pArgs As %DynamicObject, pMode As %String, pFresh As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.OsMgmt.NamespaceRules).Validate(pIdValue, pArgs, .tViolations, pMode, 0, pFresh)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tField = $List(tViolations(tI), 1)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ tField _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>Send each database field in the spelling this instance's databases list gives it, just before
/// the port is invoked (<method>OcuPilot.Area.OsMgmt.NamespaceRules.Spell</method>), so the read-back
/// never reads a case difference as a change. The value the user reviewed names the same
/// database.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.OsMgmt.NamespaceRules).Spell(pPayload)
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
