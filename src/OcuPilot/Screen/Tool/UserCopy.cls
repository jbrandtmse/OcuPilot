/// <p>The Users list's copy tool (AD-54, AD-55, Story 18.29): propose a new user account that takes an
/// existing local account's roles, escalation roles, settings and SQL privileges. It reads the new name
/// fresh and requires that read to answer <b>nothing</b>, reads the source through the copy's own port,
/// composes the payload from its arguments and the source, and mints a proposal the user confirms. It
/// writes nothing.</p>
/// <p><b>Its arguments</b> are <code>Name</code>, <code>CopyFrom</code> (required) and <code>FullName</code>
/// (empty takes the source's). The password is a secret, supplied at confirm, and a copy always takes that
/// new password, never the source's (AD-35).</p>
/// <p><b>Its payload</b> is <code>CopyFrom</code>, <code>FullName</code>, <code>Roles</code> and
/// <code>EscalationRoles</code>, the last two as the source's <code>GET</code> lists them, so the confirm
/// compares the source against what the user reviewed (<class>OcuPilot.Port.UserCopyPort</class>).
/// <class>OcuPilot.Kernel.Proposal.Prohibited</class> admits those four fields alone for this write type,
/// and a copy that confers <code>%All</code> or an administrative privilege is destructive and names it
/// (AD-10).</p>
/// <p>It inherits <class>OcuPilot.Screen.Tool.UserCreate</class>'s pairs and its name rules. Its input
/// schema drops the create's <code>Roles</code> argument, because a copy takes its roles from the source.</p>
Class OcuPilot.Screen.Tool.UserCopy Extends OcuPilot.Screen.Tool.UserCreate
{

Parameter TOOLNAME = "permissions.users.copy";

Parameter DESCRIPTION = "Propose a new user account that copies an existing local user: its roles, escalation roles, settings and SQL privileges. Name the new account and the account to copy from (CopyFrom); optionally give its full name, or leave it empty to take the source's. The new account is given a new password at confirm, and the user types it on the card -- never send a password. It creates nothing by itself: it answers a proposal the user reviews and confirms.";

/// <p>The vendor request type a copy is issued with. The port carries it out itself
/// (<class>OcuPilot.Port.UserCopyPort</class>), so no vendor request type of this name exists.</p>
Parameter WRITETYPE = "COPY";

/// <p>The port the copy goes through: <class>OcuPilot.Port.UserCopyPort</class>, which extends the admin port
/// and calls <code>Security.Users.Copy</code> (AD-27).</p>
Parameter PORTCLASS = "OcuPilot.Port.UserCopyPort";

/// <p>The derived top-level fields the agent may set: the copy's full name only. The roles come from the source.</p>
Parameter PERMITTEDFIELDS = "FullName";

/// <p>The classic user page where the copy lives (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.User";

/// <p>The one authored argument beyond the name: the account to copy from.</p>
Parameter SOURCEARGUMENT = "CopyFrom";

/// <p>The roles and escalation roles a copy takes from the source, never from the caller (the copy's payload
/// names them; neither is an argument).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The copy's input schema: the create's schema without its <code>Roles</code> argument, with the source
/// added as a required string.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If $IsObject(tProperties) Do tProperties.%Remove("Roles")
    Set tSource = {"type": "string", "description": "The existing local user whose roles, escalation roles, settings and SQL privileges the new account takes. A directory-service or delegated account is refused."}
    Do tProperties.%Set(..#SOURCEARGUMENT, tSource)
    Do tSchema.%Get("required").%Push(..#SOURCEARGUMENT)
    Quit tSchema
}

/// <p>The create's pairs with the classic user page's custom resource added (AD-44): the copy's page is
/// <parameter>CLASSICPAGES</parameter>, so an assigned page gates the copy as it gates the classic page.</p>
/// <p>Mutation (Rule 19): drop the <method>WithClassicPages</method> call -- the assigned-page leg of
/// <class>OcuPilot.Test.ClassicPageGate</class> goes red.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##super(pDescriptor, .pResolved)
    If 'pResolved Quit ""
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The create rules' problems (<method>OcuPilot.Screen.Tool.UserCreate.ArgumentProblem</method>) and a
/// missing or empty source, which the copy requires.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pIdValue, pArgs, .pProblem)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(pArgs) || (pArgs.%GetTypeOf(..#SOURCEARGUMENT) '= "string") || (pArgs.%Get(..#SOURCEARGUMENT) = "") {
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ ..#SOURCEARGUMENT _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation("USERCOPY.SOURCE")
    }
    Quit $$$OK
}

/// <p>The composed payload and diff of the copy (AD-54): the source read through
/// <class>OcuPilot.Port.UserCopyPort</class>, then the four fields <method>PermittedFields</method> and the
/// payload name, composed by the kernel's create composition. An absent or unsupported source answers
/// <var>pProblem</var>, and nothing is composed.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tFrom = ""
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#SOURCEARGUMENT) = "string") Set tFrom = pArgs.%Get(..#SOURCEARGUMENT)
    Set tHttp = 0
    Set tSource = ##class(OcuPilot.Port.UserCopyPort).SourceOf(tFrom, .tHttp)
    If '$IsObject(tSource) {
        Set pProblem = "'" _ ..#SOURCEARGUMENT _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation("USERCOPY.SOURCE")
        Quit $$$OK
    }
    Set tFull = ""
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("FullName") = "string") Set tFull = pArgs.%Get("FullName")
    If tFull = "" Set tFull = tSource.%Get("FullName")
    Set tComposed = {}
    Do tComposed.%Set(pIdArgument, pArgs.%Get(pIdArgument), "string")
    Do tComposed.%Set(..#SOURCEARGUMENT, tFrom, "string")
    Do tComposed.%Set("FullName", tFull, "string")
    Do tComposed.%Set("Roles", tSource.%Get("Roles"))
    Do tComposed.%Set("EscalationRoles", tSource.%Get("EscalationRoles"))
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Compose(tComposed, pIdArgument, $ListBuild(..#SOURCEARGUMENT, "FullName", "Roles", "EscalationRoles"), .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p>What the write's read-back compares (AD-58): the full name and both role lists.</p>
ClassMethod ReadBackFields() As %List
{
    Quit $ListBuild("FullName", "Roles", "EscalationRoles")
}

}
