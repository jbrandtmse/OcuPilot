/// <p>The Security advisor's ignore tool (AD-6, AD-51, AD-52, AD-53): ignore one security recommendation, so the instance's own
/// Security Advisor shows it as ignored. Two callers reach it: the advisor's Ignore row action through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation.
/// <class>OcuPilot.Screen.Tool.SecurityAdvisorUnignore</class> is this tool with the opposite request type and state.</p>
/// <p><b>Its port is <class>OcuPilot.Port.AdvisorPort</class></b> (AD-52), whose <code>ROW</code> read is the fresh read of the
/// recommendation the composite id names. It is not destructive: stopping ignoring undoes it.</p>
/// <p><b>It is action-style</b> (AD-51): no settable field, no body, and a card whose one row is <code>Ignored</code> moving from
/// <code>false</code> to <code>true</code>. Its fingerprint subject is <code>Ignored</code>, the field its precondition reads, so
/// a confirm after the flag moved is refused. Whether the state allows the action is the port's answer: a recommendation already in
/// the state the action leaves is refused 409 <code>ADVISOR.IGNORED</code> (<code>ADVISOR.NOTIGNORED</code> for the opposite) at the write,
/// for both callers.</p>
/// <p><b>The target is composite</b> (AD-13): the agent names <code>type</code>, <code>element</code> and <code>code</code>, which
/// <class>OcuPilot.Screen.Tool.SecurityAdvisorMint</class> joins, and the screen sends the row's own composite id.</p>
Class OcuPilot.Screen.Tool.SecurityAdvisorIgnore Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.advisor.ignore";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SecurityAdvisorList";

Parameter DESCRIPTION = "Propose ignoring one security recommendation, so the instance's own Security Advisor shows it as ignored. It changes nothing by itself: it answers a proposal the user reviews and confirms. Ignoring hides nothing and fixes nothing; stopping ignoring undoes it. Name the recommendation by its type, its element and its code exactly as the security advisor list reports them; an element of one space is a type's general row. A recommendation the list does not report, or one already ignored, is refused.";

/// <p>The screen's own row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "ignore";

/// <p>The port this tool's target lives behind (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.AdvisorPort";

/// <p>The fresh read: the port's one row.</p>
Parameter READTYPE = "ROW";

Parameter WRITETYPE = "IGNORE";

/// <p>No body: the flag is the whole write (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p><code>%DB_IRISSYS:WRITE</code>, the pair the page's ignore flag is stored under and one the screen declares among its own (AD-8).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

Parameter PRECONDITIONFIELD = "Ignored";

Parameter FINGERPRINTSUBJECT = "Ignored";

Parameter STATEFIELD = "Ignored";

/// <p>The port's two state refusals.</p>
Parameter PRECONDITIONCODES = "ADVISOR.IGNORED,ADVISOR.NOTIGNORED";

/// <p>The state the action leaves, as the card spells a boolean.</p>
Parameter AFTER = "true";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AdvisorPort).#ENDPOINT
}

/// <p>The argument naming the recommendation's code, the last part of its id.</p>
ClassMethod IdArgument() As %String
{
    Quit "code"
}

/// <p>The query parameter the port reads the composite id from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.AdvisorPort).#IDPARAM
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the type, the element and the code are joined into
/// the composite id (AD-13).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.SecurityAdvisorMint"
}

/// <p>The derived schema with the identifying property's description replaced and the type and the element added, required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The recommendation's code, copied as a string exactly as the security advisor list's Code reports it, for example RoleHasSecure. A recommendation the list does not report is refused.", "string")
    Set tType = {"type": "string", "description": "The recommendation's type, exactly as the security advisor list's Type reports it."}
    Set tAreas = ##class(OcuPilot.Port.AdvisorPort).#ADVISORAREAS
    Set tTypes = []
    For tI = 1:1:$Length(tAreas, "|") Do tTypes.%Push($Piece($Piece(tAreas, "|", tI), "=", 1))
    Do tType.%Set("enum", tTypes)
    Do tProperties.%Set("type", tType)
    Do tProperties.%Set("element", {"type": "string", "description": "The element the recommendation is about, copied exactly as the security advisor list's Element reports it: a role, a user, a service, a web application or an auditing event. A single space is the general row of a type."})
    Do tSchema.%Get("required").%Push("type")
    Do tSchema.%Get("required").%Push("element")
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs, and nothing more (AD-8).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit tPairs
}

/// <p>The one row this proposal's card shows, from the fresh row <var>pFresh</var>: <code>Ignored</code> moving from the state the row reads to
/// <parameter>AFTER</parameter>. A row that reads no state is <var>pProblem</var>; whether the state allows the action is the port's to judge, which
/// refuses 409 <code>ADVISOR.IGNORED</code> or <code>ADVISOR.NOTIGNORED</code> for both callers.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#STATEFIELD) '= "boolean") {
            Set pProblem = "this instance did not report whether that recommendation is ignored"
            Quit
        }
        Do pRows.%Push({"field": (..#STATEFIELD), "before": ($Select(pFresh.%Get(..#STATEFIELD): "true", 1: "false")), "after": (..#AFTER)})
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
