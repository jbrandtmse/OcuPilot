/// <p>The Web applications list's create tool (AD-54, AD-55): propose a new web application on
/// this instance. It reads the intended name fresh through the vendor's own
/// <code>WebApp.App</code> <code>GET</code>, requires that read to answer <b>nothing</b>, composes
/// the payload from its arguments and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>It is the product's first create</b>, so two things about the write path are inverted for
/// it and nothing else is (<parameter>CREATES</parameter>): the fresh read's acceptance, and what
/// the fingerprint covers. The port, the endpoint, the read type, the atomic transition, the
/// per-target lock, the sibling cancel, the audit marker, the ledger row and the change event are
/// every other write's.</p>
/// <p><b>The absence fingerprint is load-bearing rather than ceremony.</b>
/// <code>%Api.Admin.Endpoints.WebApp.App:RunPut</code> calls
/// <method>Security.Applications.Exists</method> and falls through to
/// <method>Security.Applications.Modify</method> when the name is taken, answering 200 with no
/// refusal path of its own. Without the confirm's re-read a create would silently rewrite whichever
/// fields it sends onto somebody else's application.</p>
/// <p><b>It admits eleven of the forty-five ordinary top-level fields its classified field list
/// carries</b> (<parameter>PERMITTEDFIELDS</parameter>), which are exactly the ones
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> has reviewed for a
/// web-application create. <code>DispatchClass</code> is among them and is <b>not</b> among the
/// ones a change may touch: DW-1207's refusal is about repointing a serving application at
/// arbitrary compiled code, and a create repoints nothing -- it is also what makes a REST
/// application a REST application.</p>
/// <p><b>Application roles are the one authored argument</b> (<parameter>MATCHROLESARGUMENT</parameter>):
/// <code>MatchRoles</code>, an array of <code>{MatchRole, TargetRoles}</code> entries, the vendor's
/// own shape. Granting <code>%All</code> or an administrative role there is permitted and confirmed
/// as a delete is -- the mint marks the proposal destructive and names the privilege
/// (<method>Consequence</method>) -- and it is refused on one of OcuPilot's own paths (AD-10).</p>
/// <p><b>Two names are absent from every path.</b> <code>Name</code>
/// is the vendor's <code>name</code> query parameter and a 400 in the body
/// (<code>UnexpectedRequestBodyField</code>). And <code>Path</code> is never settable by a caller:
/// <method>DerivedFields</method> sets it, and <code>WSGIAppLocation</code>, to the directory the
/// caller's one directory name resolves to under the instance's fixed WSGI root (AD-21), and
/// <method>Security.Applications.Create</method> creates the directory a CSP application names.</p>
/// <p><b>Choosing Unauthenticated is permitted and named</b> (DW-1489): <method>Consequence</method>
/// carries <parameter>CONSEQUENCEUNAUTHENTICATED</parameter> onto the proposal, and the card states
/// it -- or <parameter>CONSEQUENCEUNAUTHENTICATEDPRIVILEGED</parameter>, one line for both, when
/// the create also grants a privileged application role.</p>
/// <p><b><code>Type</code> is never sent.</b> <code>MergeJsonAndProperties</code> hard-codes it to
/// <code>$$$AppTypeCSP</code> and <method>RequestBodySchema</method> does not carry it, so sending
/// it is a 400. The CSP, REST, WSGI and ASGI choice a caller makes is a combination of
/// <code>DispatchClass</code>, <code>WSGIType</code> and the WSGI fields, which is how
/// <class>%CSP.UI.Portal.Applications.Web</class> expresses it too.</p>
Class OcuPilot.Screen.Tool.WebAppCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "webapp.list.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter DESCRIPTION = "Propose a new web application on this instance. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the application by the URL path it will answer at, such as /csp/myapp, give it a namespace, and choose at least one authentication method -- a create that names none would be reachable without signing in. It may also grant application roles.";

/// <p>This tool creates its target, which is what inverts the mint's fresh read and moves the
/// fingerprint onto the target's absence (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

/// <p>The AD-14 action a confirmed create performs, which is what puts the caret on the new row
/// rather than re-reading an existing one.</p>
Parameter CHANGEACTION = "created";

/// <p>The one authored argument: the application's roles, each entry
/// <code>{MatchRole, TargetRoles}</code>, the vendor's own shape. An entry whose
/// <code>MatchRole</code> is empty grants its <code>TargetRoles</code> to every request the
/// application serves.</p>
Parameter MATCHROLESARGUMENT = "MatchRoles";

/// <p>The only top-level fields this tool admits, comma-separated: the web-application settings
/// whose creation AD-10's prohibited set has reviewed
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method>). A test asserts the
/// two agree; the kernel is never read from here.</p>
Parameter PERMITTEDFIELDS = "AutheEnabled,Description,DispatchClass,Enabled,NameSpace,Recurse,Resource,WSGIAppLocation,WSGIAppName,WSGICallable,WSGIType";

/// <p>The vendor property the server derives, and the property it derives it from. Not settable by
/// a caller and absent from <parameter>PERMITTEDFIELDS</parameter>: no OcuPilot endpoint accepts a
/// filesystem path from a caller (AD-21), so both are set to the directory
/// <class>OcuPilot.Area.WebApp.Location</class> resolves the caller's one directory name to.</p>
Parameter DERIVEDPATH = "Path";

Parameter WSGILOCATION = "WSGIAppLocation";

/// <p>The authentication mask field, and the bit that makes an application reachable without
/// signing in (<file>irissys/%sySecurityMacros.inc</file>).</p>
Parameter AUTHEFIELD = "AutheEnabled";

Parameter UNAUTHENTICATEDBIT As INTEGER = 64;

/// <p>The consequence code a create choosing Unauthenticated carries onto its proposal (DW-1489).</p>
Parameter CONSEQUENCEUNAUTHENTICATED = "WEBAPP.UNAUTHENTICATED";

/// <p>The one consequence code a create carries when it is both unauthenticated and grants a
/// privileged application role (AD-10): anyone who reaches the application, without signing in,
/// runs with that privilege. The card renders one line for it, never two.</p>
Parameter CONSEQUENCEUNAUTHENTICATEDPRIVILEGED = "WEBAPP.UNAUTHENTICATEDPRIVILEGED";

/// <p>The pair a create requires: <code>%Admin_Secure:USE</code>, which is exactly what
/// <method>%CSP.Portal.Application.CheckSecurity</method> checks before the classic editor saves,
/// and exactly the pair <class>OcuPilot.Screen.Descriptor.WebAppList</class> already declares for
/// its own read (DW-1208).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "WebApp.App"
}

/// <p>The field names the composed payload may set: every <code>ordinary</code> top-level literal
/// of this tool's own field-list entry, derived rather than transcribed (AD-3), plus
/// <parameter>MATCHROLESARGUMENT</parameter>.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#MATCHROLESARGUMENT)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a field the prohibited set has not reviewed for a
/// create is absent from the schema and from <method>SettableFields</method> whether or not anyone
/// has thought to exclude it by name.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>Set <code>WSGIAppLocation</code> and <code>Path</code> to the directory the caller's
/// location name resolves to under the fixed WSGI root, or remove both where it does not resolve
/// (AD-21, AD-55). A body that names no location is left alone.</p>
/// <p><b>Caller contract:</b> <class>OcuPilot.Kernel.Proposal.Confirm</class> and
/// <class>OcuPilot.Area.WebApp.Create</class> each call it once, on the body about to be sent,
/// after the prohibited set has reached its verdict. The root is computed at this call by
/// <method>OcuPilot.Area.WebApp.Location.Resolve</method>, so the directory sent is the one the
/// instance answers now; the caller's own text never reaches the vendor. A name that no longer
/// resolves at confirm drops both keys rather than passing the text through.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#WSGILOCATION) = "unassigned" Quit
    Set tLocation = ""
    If pPayload.%GetTypeOf(..#WSGILOCATION) = "string" Set tLocation = pPayload.%Get(..#WSGILOCATION)
    If (tLocation '= "") && ##class(OcuPilot.Area.WebApp.Location).Resolve(tLocation, .tPath) {
        Do pPayload.%Set(..#WSGILOCATION, tPath, "string")
        Do pPayload.%Set(..#DERIVEDPATH, tPath, "string")
        Quit
    }
    Do pPayload.%Remove(..#WSGILOCATION)
    Do pPayload.%Remove(..#DERIVEDPATH)
}

/// <p>The kernel-owned consequence code this create's payload <var>pPayload</var> carries, or
/// <code>""</code> (DW-1489): <parameter>CONSEQUENCEUNAUTHENTICATED</parameter> when
/// <code>AutheEnabled</code> includes the unauthenticated bit, and
/// <parameter>CONSEQUENCEUNAUTHENTICATEDPRIVILEGED</parameter> instead when the mint also found the
/// create granting privilege (<var>pPrivileged</var>,
/// <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method>). A privileged
/// grant alone answers <code>""</code>, and the mint names it with its own code. The mint stores the
/// code on the proposal and the card states its sentence; the create is not refused.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0) As %String
{
    If '$IsObject(pPayload) Quit ""
    Set tType = pPayload.%GetTypeOf(..#AUTHEFIELD)
    If (tType '= "number") && (tType '= "string") Quit ""
    Set tMask = pPayload.%Get(..#AUTHEFIELD)
    If '$IsValidNum(tMask) Quit ""
    If '(((tMask \ 1) \ ..#UNAUTHENTICATEDBIT) # 2) Quit ""
    Quit $Select(pPrivileged: ..#CONSEQUENCEUNAUTHENTICATEDPRIVILEGED, 1: ..#CONSEQUENCEUNAUTHENTICATED)
}

/// <p>The derived schema with <code>WSGIAppLocation</code> described as the one directory name it
/// is (AD-21): a name, not a path, placed under the instance's own WSGI directory; and
/// <parameter>MATCHROLESARGUMENT</parameter> added as an array of <code>{MatchRole, TargetRoles}</code>
/// entries, whose shape <method>ArgumentProblem</method> refuses, because the schema subset a
/// provider is sent describes no member below a property.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tEntry = {"type": "object", "description": "One entry, an object with exactly two members: MatchRole, empty to grant the target roles to every request the application serves or a role a caller must hold to receive them, and TargetRoles, an array of role names as this instance's own roles list reports them."}
    Set tRoles = {"type": "array", "description": "The application's roles. Granting %All, or a role that carries an administrative privilege, is proposable and is confirmed as a delete is. Application roles are refused on OcuPilot's own web applications."}
    Do tRoles.%Set("items", tEntry)
    Do tProperties.%Set(..#MATCHROLESARGUMENT, tRoles)
    If tProperties.%GetTypeOf(..#WSGILOCATION) '= "object" Quit tSchema
    Do tProperties.%Get(..#WSGILOCATION).%Set("description", "For a WSGI or ASGI application only: the name of one directory, such as myapp -- letters, digits, dots, dashes and underscores, at most 64 characters. It is placed in this instance's own WSGI directory. A path, or a name containing .., is refused.")
    Quit tSchema
}

/// <p>The screen's own field rules (<method>OcuPilot.Area.WebApp.Create.Validate</method>) over the
/// agent's arguments, each broken rule as its field and published sentence (AD-55). A create that
/// names no authentication method is refused here rather than created with the vendor's
/// Unauthenticated default. The name look-up is skipped: the mint's absence read has answered
/// it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.WebApp.Create).Validate(pIdValue, pArgs, .tViolations, 0)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tField = $List(tViolations(tI), 1)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ tField _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>What the caller must hold: the screen's own pairs
/// (<method>OcuPilot.Screen.Gate.RequiredPairs</method>, which unions the declared set with the
/// classic page's custom resource) together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>.</p>
/// <p><b>Each pair once.</b> The write's own pair is one the screen already declares, so appending
/// it unconditionally would put <code>%Admin_Secure:USE</code> in the resolved set twice and the
/// ledger row's pair column would record one check as two (DW-1208).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
