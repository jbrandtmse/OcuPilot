/// <p>The privileged routine applications' create tool (AD-54, AD-55, Story 18.31): propose a new privileged routine
/// application. It is <class>OcuPilot.Screen.Tool.DocDbAppCreate</class> over the vendor's own
/// <code>Security.PrivilegedRoutine</code> endpoint, reached through <class>OcuPilot.Port.AdminPort</class>, with the
/// application's name as its whole id. It reads the intended application fresh, requires that read to answer
/// <b>nothing</b>, composes the body from the settings the arguments supply and mints a proposal the user confirms. It
/// writes nothing.</p>
/// <p>The vendor's <code>PUT</code> is an upsert that stores the name exactly as sent, so <method>TypedId</method> hands
/// the confirm and the draft the name as typed, and the absence fingerprint stops a confirmed create rewriting an
/// application somebody created since the mint (AD-54). The create sends the three settings alone: the vendor stores
/// the application with no roles and no routines, which the Application roles, Matching roles and Routines tabs of
/// the classic editor add. A name any application holds, of any kind, is refused
/// (<method>ArgumentProblem</method>). The rules of <method>OcuPilot.Area.WebApp.RoutineAppRules.Check</method> refuse the
/// arguments at the mint, the same rules the screen's Save applies.</p>
Class OcuPilot.Screen.Tool.RoutineAppCreate Extends OcuPilot.Screen.Tool.DocDbAppCreate
{

Parameter TOOLNAME = "webapp.routineapps.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoutineAppList";

Parameter DESCRIPTION = "Propose a new privileged routine application. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the application, kept exactly as written and at most 64 characters, and optionally its description, whether it is enabled and the service, system or application resource that controls it. A name that any application already holds, in any case, is refused. The application is created with no roles and no routines.";

/// <p>The admin API's port, which holds the endpoint's type check (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.AdminPort";

/// <p>The classic editor whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Applications.PrivRoutine";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.WebApp.RoutineAppRules";

ClassMethod Endpoint() As %String
{
    Quit "Security.PrivilegedRoutine"
}

/// <p>The kernel's mint: the application's id is its name, so no composite is built.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Mint"
}

/// <p>The name as the caller typed it, or <code>""</code> when it is not text: what the confirm and the draft send, so
/// the vendor stores the name as written.</p>
ClassMethod TypedId(pArgs As %DynamicObject) As %String
{
    If '$IsObject(pArgs) || (pArgs.%GetTypeOf(..IdArgument()) '= "string") Quit ""
    Quit pArgs.%Get(..IdArgument())
}

/// <p>The derived schema with the name and each setting described, and no namespace
/// (<method>Described</method>).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ..Described(##super(pDescriptor), 1)
}

/// <p><var>pSchema</var> without a namespace, and with the name and each setting described, for a create when
/// <var>pCreates</var> is 1 and for an edit or a delete otherwise. <code>Enabled</code> is typed boolean, the type the
/// instance reads it as, and its description names every value the rules admit. Every privileged routine application
/// tool's schema is described here.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Do:(tProperties.%GetTypeOf("Namespace") '= "unassigned") tProperties.%Remove("Namespace")
    If pSchema.%GetTypeOf("required") = "array" {
        Set tRequired = []
        Set tIterator = pSchema.%Get("required").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) {
            If tName '= "Namespace" Do tRequired.%Push(tName)
        }
        Do pSchema.%Set("required", tRequired)
    }
    If pCreates {
        Set tDescriptions("Name") = "The name the new application takes, at most 64 characters, kept exactly as written. A name that any application already holds, in any case, is refused."
    } Else {
        Set tDescriptions("Name") = "The privileged routine application, exactly as the privileged routine applications list reports its name."
    }
    Set tDescriptions("Description") = "A description of the application, at most 256 characters."
    Set tDescriptions("Enabled") = "Whether the application is enabled. One of true, false, 1, 0, ""1"" or ""0""; any other value is refused. Send true or false."
    Set tDescriptions("Resource") = "The service, system or application resource that controls the application, as the Resources list names it. Empty for none. A resource the instance does not list as a service, system or application resource is refused."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    If tProperties.%GetTypeOf("Enabled") = "object" Do tProperties.%Get("Enabled").%Set("type", "boolean", "string")
    Quit pSchema
}

/// <p>The rules over the agent's arguments, create mode, each broken one as its field and published sentence
/// (AD-55), then the look-up that refuses a name any application holds. <var>pIdValue</var> is the name. The mint's
/// absence read answers only for a routine application: a name a web application holds reads as absent there.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = $ClassMethod(..#RULES, "Problem", "", pIdValue, pArgs, "", "create", ..PortClass(), .pProblem, 1)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tSC = $ClassMethod(..#RULES, "Taken", ..PortClass(), "", pIdValue, .tTaken)
    If $$$ISERR(tSC) Quit tSC
    If tTaken Set pProblem = "'Name': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($Parameter($Parameter(..#RULES, "ERRORCLASS"), "TAKEN"))
    Quit $$$OK
}

}
