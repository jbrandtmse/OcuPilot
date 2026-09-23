/// <p>AD-10's prohibited set, and its one home. What Release 1 refuses is declared here, as
/// predicates evaluated against the <b>resolved target as the instance holds it now</b>, and is
/// reached only through <method>OcuPilot.Kernel.Proposal.Write.ProhibitedClass</method>.</p>
/// <p><b>Effect, not verb.</b> A predicate answers "what would this write do", never "what did the
/// caller ask for". Two things decide that together: the stored diff, which is the only record of
/// what the proposal changes relative to the target it was minted against, and a fresh read of the
/// target, which is what makes the answer an effect. A field one of them names and the other does
/// not changes nothing the agent proposed, so the set is silent and the gates behind it answer.</p>
/// <p><b>A create is a second set of lists over the same types</b> (AD-54). "What may a change to a
/// live target touch" and "what may a create set" are different questions, so a create tool's
/// fields are <method>PermittedCreateFields</method>'s and
/// <method>AlwaysProhibitedCreateFields</method>'s, and the absent-target early-out below does not
/// apply to a tool whose target is correctly absent (<method>Created</method>).</p>
/// <p><b>It permits, rather than forbids, by name.</b> AD-4 makes the payload the complete property
/// set, and a vendor web application carries 45 settable properties of which a great many decide
/// which compiled code answers at the URL or how a caller gets in. Enumerating those would leave
/// the next vendor property unrefused, so the set names the few whose change it has reviewed
/// (<method>PermittedChangeFields</method>) and refuses every other changed field
/// (<parameter>UNCOVEREDFIELD</parameter>) whatever it is called. The reviewed few carry their own
/// asymmetric predicates, which is where the one reviewed change to a field stays available and
/// every other one does not: the only authentication change it permits is clearing the
/// unauthenticated option, and clearing a resource is refused while setting one is not.</p>
/// <p><b>Refused whatever the caller.</b> This class reads no governance state, no policy and no
/// switch, so governance can disable a permitted tool and can never enable a prohibited one. It is
/// asked inside the confirm transition, before the port call (AD-34, AD-40).</p>
/// <p><b>It fails closed.</b> A target reference it cannot parse, an entity type it holds no
/// predicates for, and a covered type whose dispatch is missing are all
/// <parameter>UNCOVERED</parameter>. A target the port cannot read is an error status, which the
/// confirm renders 500 and no write follows. Only a target the instance no longer holds is "not
/// prohibited": that is the fingerprint gate's refusal a few lines later, not this one's.</p>
/// <p><b>The fields whose every change is prohibited are absent from the tool set as well</b>
/// (<method>AlwaysProhibitedFields</method>), and so is every field outside the reviewed few: a
/// write tool advertises the reviewed names and nothing else, so the model cannot author the rest,
/// and this class refuses them at the write so no other route can either.</p>
/// <p><b>Six types are covered</b> (<parameter>COVEREDTYPES</parameter>): a web application
/// (<method>WebApplication</method>), a user account (<method>User</method>), the instance's
/// auditing configuration (<method>Auditing</method>), a task (<method>Task</method>) and an
/// application error (<method>ApplicationError</method>) -- the last three the reviewed-few sweep
/// alone, because AD-10 forbids no change to any of them -- and a process
/// (<method>Process</method>), which adds two target predicates -- a process OcuPilot is itself
/// running in (AD-7, and AD-10's serving path) and an IRIS system process (AD-10). Each later
/// write-tool story adds its own type here, and a type listed with no branch is refused
/// <parameter>UNCOVERED</parameter> at every write.</p>
/// <p>Seams a subclass overrides: <method>PortClass</method>, <method>RegistryClass</method>,
/// <method>LastAllHolder</method> and <method>HoldsAll</method>. Production overrides none of them.
/// The last two are the census, and the difference between them matters to a reader auditing it:
/// replacing <method>LastAllHolder</method> replaces the census, while replacing
/// <method>HoldsAll</method> only makes its input deterministic and leaves the census body
/// running.</p>
Class OcuPilot.Kernel.Proposal.Prohibited Extends %RegisteredObject
{

/// <p>The target is a web application OcuPilot itself is served by, and the write would change it.
/// AD-38 makes an OcuPilot nobody can reach an instance nobody can repair through OcuPilot, so its
/// own applications are the installer's to change and not the agent's.</p>
Parameter SERVINGPATH = "PROHIBITED.SERVINGPATH";

/// <p>The write would change how the target is authenticated by anything other than clearing its
/// unauthenticated option: it adds a bit, clears another bit, clears the mask, or carries a value
/// that is not a non-negative whole number.</p>
Parameter UNAUTHENTICATED = "PROHIBITED.UNAUTHENTICATED";

/// <p>The write would drop the target's authorization resource: the target names one and the
/// payload names none.</p>
Parameter AUTHORIZATION = "PROHIBITED.AUTHORIZATION";

/// <p>The write would change which compiled code answers at the target's URL.</p>
Parameter DISPATCH = "PROHIBITED.DISPATCH";

/// <p>The write would change the roles the target grants or holds, which is a privilege grant
/// through a path (AD-10).</p>
Parameter PRIVILEGEGRANT = "PROHIBITED.PRIVILEGEGRANT";

/// <p>The write would disable the account the caller is signed in as.</p>
Parameter CURRENTUSER = "PROHIBITED.CURRENTUSER";

/// <p>The write would leave the instance with no account a person can sign in as holding
/// <code>%All</code> -- by disabling the only such account, or by taking <code>%All</code> off it
/// through a role change. Both are the same effect and reach the same predicate
/// (<method>DePrivilegesLastAllHolder</method>), because AD-10's set is defined by effect and not
/// by verb.</p>
Parameter LASTALLHOLDER = "PROHIBITED.LASTALLHOLDER";

/// <p>The write would disable <code>_SYSTEM</code>, the instance's own predefined account.</p>
Parameter SYSTEMACCOUNT = "PROHIBITED.SYSTEMACCOUNT";

/// <p>The write would disable one of the accounts the instance's own services run as
/// (<parameter>SERVICEACCOUNTS</parameter>). It is the account-side analogue of
/// <parameter>SERVINGPATH</parameter>: disabling the account the CSP service runs as ends every
/// CSP request on the instance, OcuPilot's own among them, so AD-38 makes it the same harm as
/// disabling the application that serves OcuPilot.</p>
Parameter SERVICEACCOUNT = "PROHIBITED.SERVICEACCOUNT";

/// <p>The write would suspend or resume a process OcuPilot is itself running in: the job serving
/// this confirmation, or any job running an agent turn (AD-7). Both harms are irrecoverable from
/// inside the product -- suspending the serving job kills the write inside AD-34's transition, and
/// suspending a turn job strands a turn whose owner may be another user.</p>
/// <p><b>Ownership is not the predicate</b> [narrowed 2026-09-22, Story 5.13, orchestrator-decided].
/// AD-10's self-protection items are accounts, the serving path and IRIS system processes, and it
/// nowhere names process ownership, so refusing every process the confirming user owns was a rule
/// of its own borrowing AD-10's authority -- and it prohibited the feature's most likely legitimate
/// use, an administrator suspending their own runaway job, which signing in again recovers.</p>
Parameter OCUPILOTPROCESS = "PROHIBITED.OCUPILOTPROCESS";

/// <p>The write would suspend or resume an IRIS system process: one whose <code>JobType</code> is
/// outside <method>ProcessJobTypes</method>'s allow-list, an unnamed value included.</p>
Parameter SYSTEMPROCESS = "PROHIBITED.SYSTEMPROCESS";

/// <p>The write would change a setting of a covered type that this release has not reviewed. It is
/// the shape that covers a vendor property nobody has classified yet, rather than the names that
/// happen to exist on this build.</p>
Parameter UNCOVEREDFIELD = "PROHIBITED.UNCOVEREDFIELD";

/// <p>The target's entity type is one this release evaluates no predicates for, or its reference
/// could not be read at all. Refusing wholesale is strictly stronger than the enumerated effects,
/// and it is what keeps a later story's write tool from shipping without its predicates.</p>
Parameter UNCOVERED = "PROHIBITED.UNCOVERED";

/// <p>The class a write tool's port declaration lives on, whose own value is the default every
/// shipped tool carries (AD-52).</p>
Parameter WRITETOOLBASE = "OcuPilot.Screen.Tool.Write";

/// <p>The entity types this release evaluates predicates for, comma-separated
/// (<class>OcuPilot.Kernel.EntityType</class>'s spelling). A type outside this list is
/// <parameter>UNCOVERED</parameter>.</p>
Parameter COVEREDTYPES = "web-application,user,auditing-configuration,task,process,application-error";

/// <p>The covered types, each named once so the dispatch and the list cannot drift apart.</p>
Parameter TYPEWEBAPPLICATION = "web-application";

Parameter TYPEUSER = "user";

Parameter TYPEAUDITING = "auditing-configuration";

Parameter TYPETASK = "task";

Parameter TYPEPROCESS = "process";

Parameter TYPEAPPLICATIONERROR = "application-error";

/// <p>The instance's own predefined account, whose disablement AD-10 forbids. Compared through
/// <method>NormalizedUser</method>, so every spelling the instance resolves to it is refused.</p>
Parameter SYSTEMACCOUNTNAME = "_SYSTEM";

/// <p>The accounts the instance's own services run as, comma-separated. Nobody signs in as one,
/// and each is here because something the instance does stops if it is disabled:
/// <code>CSPSystem</code> is what the CSP service runs every web request as,
/// <code>_Ensemble</code> is what interoperability's own jobs run as, and
/// <code>irisowner</code> owns the installed instance and is what the container's start path runs
/// as.</p>
/// <p><b>One list, read twice, because the two harms are one question.</b>
/// <method>IsServiceAccount</method> answers a disable with
/// <parameter>SERVICEACCOUNT</parameter>, and <method>CountsAsHolder</method> answers 0 for a
/// member so the <code>%All</code> census counts only accounts a person can sign in as -- measured
/// on this build, <code>_Ensemble</code> and <code>irisowner</code> both hold <code>%All</code>,
/// so counting them hid every real last-holder case behind two rows nobody can log in with. A
/// second list kept in step with this one is the DW-1206 defect; there is one.</p>
/// <p>Compared through <method>NormalizedUser</method>, so a re-cased spelling earns one verdict
/// (AD-13).</p>
Parameter SERVICEACCOUNTS = "CSPSystem,_Ensemble,irisowner";

/// <p>The role that holds every privilege, and the prefix of every role that holds an
/// administrative one. Adding either to an account is a privilege grant (AD-10).</p>
Parameter ALLROLE = "%All";

Parameter ADMINROLEPREFIX = "%Admin_";

/// <p>The two <code>Process</code> <code>GET</code> properties the process predicates read, named
/// once.</p>
Parameter FIELDJOBTYPE = "JobType";

Parameter FIELDPID = "Pid";

/// <p>The three <code>Security.User</code> payload fields the user predicates read, named once.</p>
Parameter FIELDENABLED = "Enabled";

Parameter FIELDROLES = "Roles";

Parameter FIELDESCALATIONROLES = "EscalationRoles";

/// <p>The <code>AutheEnabled</code> bit that lets an application be reached without signing in, and
/// the only bit <method>ClearsUnauthenticatedOnly</method> permits a payload to change
/// (<file>irissys/%sySecurityMacros.inc</file>:19-20 gives AuthePassword 32 and
/// AutheUnauthenticated 64).</p>
Parameter UNAUTHENTICATEDBIT As %Integer = 64;

/// <p>The admin request type the target is re-read with when the proposal's tool declares none
/// (AD-36's single-object <code>GET</code>).</p>
/// <p><b>The tool's own <method>OcuPilot.Screen.Tool.Write.ReadType</method> is what
/// <method>Target</method> uses</b> (AD-51), which keeps this read and the fingerprint re-read
/// the same read. They have to be: <method>Changed</method> compares the stored payload against
/// this answer field by field, and a payload taken from one request type against a target taken
/// from another would report every field the two types spell differently as changed.</p>
Parameter READTYPE = "GET";

/// <p>Every <code>PROHIBITED.*</code> code this class declares, as a <class>%List</class>: the
/// four web-application predicates in the order <method>WebApplication</method> evaluates them,
/// then the four <method>User</method> adds, then <parameter>PRIVILEGEGRANT</parameter>, which
/// both those types reach, then the two <method>Process</method> adds, then the one every covered
/// type shares, with the wholesale refusal last -- thirteen in all.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#SERVINGPATH, ..#UNAUTHENTICATED, ..#AUTHORIZATION, ..#DISPATCH, ..#SYSTEMACCOUNT, ..#SERVICEACCOUNT, ..#CURRENTUSER, ..#LASTALLHOLDER, ..#PRIVILEGEGRANT, ..#OCUPILOTPROCESS, ..#SYSTEMPROCESS, ..#UNCOVEREDFIELD, ..#UNCOVERED)
}

/// <p>The written sentence a <code>PROHIBITED.*</code> code carries, or <code>""</code> for any
/// other code (AD-39). <method>OcuPilot.Kernel.Proposal.Write.ReasonFor</method> delegates the
/// family here, so the set still has one home.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#UNAUTHENTICATED Quit "The only change to how a web application is authenticated that the agent can propose is removing the option of reaching it without signing in."
    If pCode = ..#AUTHORIZATION Quit "Removing the resource that guards a web application is not something the agent can propose."
    If pCode = ..#DISPATCH Quit "Changing which code answers at a web application's address is not something the agent can propose."
    If pCode = ..#PRIVILEGEGRANT Quit "Granting an administrative privilege is not something the agent can propose, whether it is granted by a web application or held by an account."
    If pCode = ..#SERVINGPATH Quit "Changing a web application that serves OcuPilot itself is not something the agent can propose."
    If pCode = ..#SYSTEMACCOUNT Quit "Disabling the instance's own _SYSTEM account is not something the agent can propose."
    If pCode = ..#SERVICEACCOUNT Quit "Disabling an account the instance's own services run as is not something the agent can propose."
    If pCode = ..#CURRENTUSER Quit "Disabling the account you are signed in as is not something the agent can propose."
    If pCode = ..#LASTALLHOLDER Quit "Leaving this instance with no account that holds %All is not something the agent can propose, whether by disabling the last one or by taking the role off it."
    If pCode = ..#OCUPILOTPROCESS Quit "Suspending or resuming a process OcuPilot is itself running in -- this confirmation, or an agent turn -- is not something the agent can propose."
    If pCode = ..#SYSTEMPROCESS Quit "Suspending or resuming an IRIS system process is not something the agent can propose."
    If pCode = ..#UNCOVEREDFIELD Quit "Only a few of this kind of object's settings are ones the agent may propose changing, and that is not one of them."
    If pCode = ..#UNCOVERED Quit "This release does not check writes to that kind of object against its prohibited set, so none is proposable yet."
    Quit ""
}

/// <p><parameter>COVEREDTYPES</parameter> as a <class>%List</class>.</p>
ClassMethod CoveredTypes() As %List
{
    Set tList = ""
    For tI = 1:1:$Length(..#COVEREDTYPES, ",") {
        Set tValue = $Piece(..#COVEREDTYPES, ",", tI)
        If tValue '= "" Set tList = tList _ $ListBuild(tValue)
    }
    Quit tList
}

/// <p>The payload field names of entity type <var>pType</var> whose change this release has
/// reviewed and may permit, as a <class>%List</class>; <code>""</code> for a type it permits no
/// change to at all.</p>
/// <p>This is the list AD-10's "by effect, not by verb" rests on. Every changed field outside it is
/// refused without the set knowing what the field does, so a vendor property added by a later IRIS
/// build is refused until somebody reviews it -- which is the opposite failure mode from a
/// forbidden-name list, where the new property is settable until somebody notices. It grows one
/// reviewed field at a time. Two of the four carry an asymmetric predicate of their own
/// (<method>WebApplication</method>); the other two carry a reviewed argument that no change to
/// them is an effect this AD forbids -- <code>Enabled</code> because it turns an application's
/// already-declared configuration on and off rather than changing any of it, and the applications
/// AD-38 protects are refused every change by the serving-path predicate; <code>Description</code>
/// because it is display text no request is routed or authorized by.</p>
/// <p>An account's two are <code>Enabled</code> and <code>Roles</code>. <code>Enabled</code> carries
/// the asymmetric predicate: enabling an account is a change AD-10 does not forbid, while disabling
/// one is refused for the current user, the last <code>%All</code> holder and
/// <parameter>SYSTEMACCOUNTNAME</parameter>. <code>Roles</code> is permitted except where the delta
/// grants privilege, which is the same asymmetry read over a list.</p>
/// <p>A process's is <b>none</b>, for the reason a task's is: both of its writes are bodyless
/// (AD-51), so every changed field a <code>process</code> proposal could carry is one nobody has
/// reviewed.</p>
/// <p>A task's is <b>none</b>. Its one write is the bodyless resume (AD-51), which sets no field
/// at all, so every changed field a <code>task</code> proposal could carry is one nobody has
/// reviewed. AD-10's Release 1 set names no task effect, and this story invents none.</p>
/// <p>An application error's is <b>none</b>, for the same reason: its one write is the bodyless
/// by-namespace delete (AD-48), whose card rows are removals rather than field changes.</p>
/// <p>The auditing configuration's one is <code>Enabled</code>, and it carries <b>no</b> asymmetric
/// predicate: AD-10 does not forbid turning auditing off, and the product's answer to it is the
/// card's warning, the recorded drop and the banner rather than a refusal (AD-15 as amended
/// 2026-09-21). Every other property of that object -- the audit-database location, encryption --
/// is refused by the reviewed-few rule.</p>
/// <p>A write tool advertises no field outside this list, which is the other half of AD-10; the
/// tool states its own admitted names and a test asserts the two agree, so the tool layer never
/// reads the kernel.</p>
ClassMethod PermittedChangeFields(pType As %String) As %List
{
    If pType = ..#TYPEWEBAPPLICATION Quit $ListBuild("AutheEnabled", "Description", "Enabled", "Resource")
    If pType = ..#TYPEUSER Quit $ListBuild(..#FIELDENABLED, ..#FIELDROLES)
    If pType = ..#TYPEAUDITING Quit $ListBuild(..#FIELDENABLED)
    Quit ""
}

/// <p>The payload field names of entity type <var>pType</var> whose <b>every</b> change is
/// prohibited by a named predicate, as a <class>%List</class>; <code>""</code> for a type with
/// none.</p>
/// <p>They are a subset of the fields outside <method>PermittedChangeFields</method> -- the names
/// whose refusal carries a sentence of its own rather than the reviewed-few one, so the user is
/// told which effect was refused. A web application's roles and dispatch class are two; an
/// account's escalation roles are the third, and that one is a privilege grant through a path
/// however it changes.</p>
ClassMethod AlwaysProhibitedFields(pType As %String) As %List
{
    If pType = ..#TYPEWEBAPPLICATION Quit $ListBuild("MatchRoles", "DispatchClass")
    If pType = ..#TYPEUSER Quit $ListBuild(..#FIELDESCALATIONROLES)
    Quit ""
}

/// <p>The payload field names of entity type <var>pType</var> a <b>create</b> may set, as a
/// <class>%List</class>; <code>""</code> for a type this release reviews no create for, which is
/// refused <parameter>UNCOVERED</parameter> wholesale (AD-54).</p>
/// <p><b>"What may a change to a live target touch" and "what may a create set" are different
/// questions</b>, so a create carries its own reviewed list rather than reusing
/// <method>PermittedChangeFields</method>. The difference is not a relaxation: a field prohibited
/// because it repoints a <b>serving</b> object is prohibited on a change and permitted on a create,
/// which repoints nothing, while a field prohibited by effect under AD-10 stays prohibited on both.
/// <code>DispatchClass</code> is the first kind -- DW-1207's owner decision is about pointing a
/// running application at arbitrary compiled code, and it is also what makes a REST application a
/// REST application. <code>MatchRoles</code> is the second kind and appears in neither list
/// (<method>AlwaysProhibitedCreateFields</method>).</p>
/// <p>A web application's eleven are the settings the create form captures: the namespace it runs
/// in, its description, whether it is enabled, its authentication methods, its guarding resource,
/// whether it recurses into subdirectories, the dispatch class that makes it a REST application,
/// and the four WSGI properties that make it a WSGI or ASGI one. <code>Path</code> is not among
/// them and is never settable by a caller: the server derives it from
/// <code>WSGIAppLocation</code> (<method>OcuPilot.Screen.Tool.Write.DerivedFields</method>), and
/// <method>Security.Applications.Create</method> creates the directory a CSP application names.</p>
ClassMethod PermittedCreateFields(pType As %String) As %List
{
    If pType = ..#TYPEWEBAPPLICATION Quit $ListBuild("AutheEnabled", "Description", "DispatchClass", "Enabled", "NameSpace", "Recurse", "Resource", "WSGIAppLocation", "WSGIAppName", "WSGICallable", "WSGIType")
    Quit ""
}

/// <p>The payload field names of entity type <var>pType</var> whose presence in a <b>create</b> is
/// prohibited by a named predicate, as a <class>%List</class>; <code>""</code> for a type with
/// none (AD-54).</p>
/// <p>They are the fields AD-10 forbids <b>unconditionally</b> -- the ones whose refusal carries a
/// sentence of its own rather than the reviewed-few one. Setting application roles on any web
/// application is a privilege grant through a path, and creating the application is no exception:
/// <code>MatchRoles</code> is refused here exactly as
/// <method>AlwaysProhibitedFields</method> refuses it on a change.</p>
ClassMethod AlwaysProhibitedCreateFields(pType As %String) As %List
{
    If pType = ..#TYPEWEBAPPLICATION Quit $ListBuild("MatchRoles")
    Quit ""
}

/// <p>The port the target is read through when the proposal's tool declares the base's own default
/// (AD-52). Overridable so a fixture can answer a known object; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>The port <var>pToolClass</var> declares its target lives behind (AD-52), or
/// <method>PortClass</method> where it declares the base's own default, names no class, or cannot
/// be asked.</p>
/// <p>The set reads the target through the same port the write will reach it through, so its
/// verdict is about the object the write is about.</p>
ClassMethod PortClassOf(pToolClass As %String) As %String [ Private ]
{
    Set tPort = ""
    Try {
        If pToolClass '= "" Set tPort = $ClassMethod(pToolClass, "PortClass")
    } Catch {
        Set tPort = ""
    }
    If (tPort = "") || (tPort = $Parameter(..#WRITETOOLBASE, "PORTCLASS")) Quit ..PortClass()
    Quit tPort
}

/// <p>The tool registry the target's endpoint and identifying parameter are resolved through, and
/// the only name this class holds outside the kernel. The kernel may read the registry; the
/// registry never reads the kernel. Overridable for the reason <method>PortClass</method> is.</p>
ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Screen.Tool.Registry"
}

/// <p>Whether the write that <var>pToolName</var> proposed against <var>pTargetRef</var>, carrying
/// the stored payload <var>pPayload</var> and the stored diff <var>pDiff</var>, is prohibited -- in
/// <var>pProhibits</var>, with the refusing code in <var>pCode</var>.</p>
/// <p><b>Caller contract:</b> the four arguments are the stored row's, never the request's, and
/// this is called inside the confirm transition before the port call. <var>pDiff</var> is the
/// mint's own <code>[{field, before, after}]</code>, which is what scopes the verdict to fields the
/// proposal actually changes; a diff naming nothing leaves nothing prohibited, and the fingerprint
/// gate behind the set refuses a row whose payload its own fingerprint does not cover. An error
/// status means the question could not be answered and the caller must not write:
/// <var>pProhibits</var> is 0 and <var>pCode</var> is <code>""</code> on that path, so a caller
/// that reads them without checking the status is refused by its own <code>$$$ISERR</code> rather
/// than by a false negative.</p>
ClassMethod Prohibits(pToolName As %String, pTargetRef As %String, pPayload As %String, pDiff As %String, Output pProhibits As %Boolean, Output pCode As %String) As %Status
{
    Set pProhibits = 0
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        Set tParseSC = ##class(OcuPilot.Kernel.EntityRef).Parse(pTargetRef, .tType, .tScope, .tId)
        If $$$ISERR(tParseSC) || '$ListFind(..CoveredTypes(), tType) {
            Do ..Refuse(..#UNCOVERED, .pProhibits, .pCode)
            Quit
        }
        If (tType '= ..#TYPEWEBAPPLICATION) && (tType '= ..#TYPEUSER) && (tType '= ..#TYPEAUDITING) && (tType '= ..#TYPETASK) && (tType '= ..#TYPEPROCESS) && (tType '= ..#TYPEAPPLICATIONERROR) {
            ; A type COVEREDTYPES lists and no branch evaluates. Fail closed rather than write.
            Do ..Refuse(..#UNCOVERED, .pProhibits, .pCode)
            Quit
        }

        Set tServes = 0
        If tType = ..#TYPEWEBAPPLICATION {
            ; AD-9: the escalated state read runs to completion before the port is entered. Its
            ; frame has unwound by the time Target() calls the port, so the two are never nested.
            Set tSC = ..ServesOcuPilot(tId, .tServes)
            If $$$ISERR(tSC) Quit
        }

        Set tSC = ..Target(pToolName, tId, .tTarget, .tPresent, .tToolClass)
        If $$$ISERR(tSC) Quit
        ; AD-54. A create's target is CORRECTLY absent, so the early-out below -- which reasons that
        ; the fingerprint re-read refuses an absent target moments later -- does not apply to one:
        ; for a create that re-read compares the target's absence and finds it matching, so nothing
        ; behind this set would refuse the write. The create predicates are evaluated instead, over
        ; the fields the caller actually supplied.
        If ..CreatesOf($Get(tToolClass)) {
            If 'tServes && (tType = ..#TYPEWEBAPPLICATION) {
                Set tSC = ..UnderOcuPilot(tId, .tServes)
                If $$$ISERR(tSC) Quit
            }
            Set tSC = ..Created(tType, tServes, ..ParsedObject(pPayload), .pProhibits, .pCode)
            Quit
        }
        ; A target the instance no longer holds is not prohibited: the fingerprint re-read refuses
        ; it TARGETCHANGED a few lines later and closes the row, which is the answer the user sees.
        If 'tPresent Quit

        Set tPayloadObject = ..ParsedObject(pPayload)
        Set tSC = ..Changed(pDiff, tPayloadObject, tTarget, ..SkippedFields($Get(tToolClass)), .tChanged)
        If $$$ISERR(tSC) Quit

        If tType = ..#TYPEUSER {
            Set tSC = ..User(tId, tPayloadObject, tTarget, .tChanged, .pProhibits, .pCode)
            Quit
        }
        If tType = ..#TYPEAUDITING {
            Set tSC = ..Auditing(.tChanged, .pProhibits, .pCode)
            Quit
        }
        If tType = ..#TYPETASK {
            Set tSC = ..Task(.tChanged, .pProhibits, .pCode)
            Quit
        }
        If tType = ..#TYPEPROCESS {
            Set tSC = ..Process(tTarget, .tChanged, .pProhibits, .pCode)
            Quit
        }
        If tType = ..#TYPEAPPLICATIONERROR {
            Set tSC = ..ApplicationError(.tChanged, .pProhibits, .pCode)
            Quit
        }
        Set tSC = ..WebApplication(tPayloadObject, tTarget, tServes, .tChanged, .pProhibits, .pCode)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Set pProhibits = 0
        Set pCode = ""
    }
    Quit tSC
}

/// <p>The registered write tools whose entity type this class evaluates no predicates for, as a
/// <class>%List</class> of tool names.</p>
/// <p>It is empty in Release 1 and a test asserts so, which is what stops a write tool registering
/// over a type <parameter>COVEREDTYPES</parameter> does not list. It reads that list alone: a type
/// added to the list with no predicate branch passes this gate and is refused
/// <parameter>UNCOVERED</parameter> at every write instead. A registry that cannot be read is an
/// error, never an empty list: an empty list is the passing answer.</p>
ClassMethod UncoveredWriteTools(Output pTools As %List) As %Status
{
    Set pTools = ""
    Set tSC = $$$OK
    Try {
        Set tSC = $ClassMethod(..RegistryClass(), "ListTools", .tAll)
        If $$$ISERR(tSC) Quit
        Set tCovered = ..CoveredTypes()
        Set tIterator = tAll.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If '$IsObject(tEntry) Continue
            If tEntry.%Get("kind") '= "write" Continue
            Set tType = ""
            Set tDescriptor = $Parameter(tEntry.%Get("class"), "DESCRIPTORCLASS")
            If tDescriptor '= "" Set tType = $ClassMethod(tDescriptor, "PrimaryEntityType")
            If '$ListFind(tCovered, tType) Set pTools = pTools _ $ListBuild(tEntry.%Get("name"))
        }
    } Catch ex {
        Set pTools = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The <b>create</b> predicates, in declared order, first hit wins: a create at a path that
/// serves OcuPilot, a field AD-10 forbids unconditionally, and any field the release has not
/// reviewed for a create of this type (AD-54).</p>
/// <p><b>The set here is the payload's own keys, not a diff against a live target</b>, and that is
/// the whole difference. A create has no prior state to compare against, so
/// <method>Changed</method> has no subject: every property the composed body carries is a property
/// the caller asked this write to set, and the sweep is over exactly those.
/// <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> puts nothing else there.</p>
/// <p><var>pServes</var> is whether the intended path is one of OcuPilot's own applications,
/// already resolved by <method>ServesOcuPilot</method> so no escalated read happens here. It is
/// answered from the id the proposal carries -- which for a create is the name the write will take,
/// canonical under AD-13 -- so creating a second application at OcuPilot's own address is refused
/// on the same predicate that refuses changing the first.</p>
/// <p>A type <method>PermittedCreateFields</method> reviews nothing for is refused
/// <parameter>UNCOVERED</parameter> wholesale rather than permitted an empty body: a create tool
/// registering before its type's list exists is the shape this fails closed against.</p>
ClassMethod Created(pType As %String, pServes As %Boolean, pPayload As %DynamicObject, Output pProhibits As %Boolean, Output pCode As %String) As %Status [ Private ]
{
    Set pProhibits = 0
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        If pServes {
            Do ..Refuse(..#SERVINGPATH, .pProhibits, .pCode)
            Quit
        }
        Set tPermitted = ..PermittedCreateFields(pType)
        If tPermitted = "" {
            Do ..Refuse(..#UNCOVERED, .pProhibits, .pCode)
            Quit
        }
        Set tAlways = ..AlwaysProhibitedCreateFields(pType)
        For tI = 1:1:$ListLength(tAlways) {
            If pPayload.%GetTypeOf($List(tAlways, tI)) '= "unassigned" {
                Do ..Refuse(..#PRIVILEGEGRANT, .pProhibits, .pCode)
                Quit
            }
        }
        If pProhibits Quit
        Set tIterator = pPayload.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If '$ListFind(tPermitted, tKey) {
                Do ..Refuse(..#UNCOVEREDFIELD, .pProhibits, .pCode)
                Quit
            }
        }
    } Catch ex {
        Set pProhibits = 0
        Set pCode = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pPath</var> lies beneath one of OcuPilot's own application paths, in
/// <var>pUnder</var>. The web server routes a request to the longest matching application name, so
/// a new application at <code>/api/ocupilot/x</code> would answer requests OcuPilot's own API
/// serves today; a create there is refused on the serving-path predicate.</p>
ClassMethod UnderOcuPilot(pPath As %String, Output pUnder As %Boolean) As %Status [ Private ]
{
    Set pUnder = 0
    Set tSC = $$$OK
    Try {
        Set tPath = ..NormalizedPath(pPath)
        Set tKeys = ##class(OcuPilot.Install.Roster).Keys()
        If tKeys = "" {
            Set tSC = $$$ERROR($$$GeneralError, "the install roster's application keys could not be read, so which paths serve OcuPilot is unknown")
            Quit
        }
        For tI = 1:1:$Length(tKeys, ",") {
            Set tSC = ##class(OcuPilot.Install.Roster).Application($Piece(tKeys, ",", tI), .tApp)
            If $$$ISERR(tSC) Quit
            If '$IsObject(tApp) Continue
            Set tOwn = ..NormalizedPath(tApp.path) _ "/"
            If $Extract(tPath, 1, $Length(tOwn)) = tOwn Set pUnder = 1
        }
    } Catch ex {
        Set pUnder = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pToolClass</var> declares that its write creates its target
/// (<method>OcuPilot.Screen.Tool.Write.Creates</method>, AD-54), or <code>0</code> for a class that
/// names none or cannot be asked -- which is every write that shipped before Epic 8, and is the
/// answer that keeps the absent-target early-out in place for them.</p>
ClassMethod CreatesOf(pToolClass As %String) As %Boolean [ Private ]
{
    Set tCreates = 0
    Try {
        If pToolClass '= "" Set tCreates = ''$ClassMethod(pToolClass, "Creates")
    } Catch {
        Set tCreates = 0
    }
    Quit tCreates
}

/// <p>The web-application predicates, in declared order, first hit wins: OcuPilot's own serving
/// path, an authentication change other than clearing the unauthenticated option, a dropped
/// resource, a repointed dispatch, changed roles, and any other changed field the release has not
/// reviewed.</p>
/// <p><var>pChanged</var> is <method>Changed</method>'s answer -- the fields this proposal changes,
/// and the only fields any predicate here looks at. <var>pServes</var> is whether the target is one
/// of OcuPilot's own applications, already resolved by <method>ServesOcuPilot</method> so no
/// escalated read happens here.</p>
ClassMethod WebApplication(pPayload As %DynamicObject, pTarget As %DynamicObject, pServes As %Boolean, ByRef pChanged, Output pProhibits As %Boolean, Output pCode As %String) As %Status [ Private ]
{
    Set pProhibits = 0
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        ; OcuPilot's own applications are the installer's. Every property of one decides whether
        ; OcuPilot answers at that address -- the namespace and the path as completely as the
        ; enabled flag -- so the predicate is over the application, not over a list of properties.
        If pServes && +$Get(pChanged) {
            Do ..Refuse(..#SERVINGPATH, .pProhibits, .pCode)
            Quit
        }
        If $Data(pChanged("AutheEnabled")) && '..ClearsUnauthenticatedOnly(..Rendered(pPayload, "AutheEnabled"), ..Rendered(pTarget, "AutheEnabled")) {
            Do ..Refuse(..#UNAUTHENTICATED, .pProhibits, .pCode)
            Quit
        }
        If $Data(pChanged("Resource")) && (..Rendered(pPayload, "Resource") = "") {
            Do ..Refuse(..#AUTHORIZATION, .pProhibits, .pCode)
            Quit
        }
        If $Data(pChanged("DispatchClass")) {
            Do ..Refuse(..#DISPATCH, .pProhibits, .pCode)
            Quit
        }
        If $Data(pChanged("MatchRoles")) {
            Do ..Refuse(..#PRIVILEGEGRANT, .pProhibits, .pCode)
            Quit
        }
        Set tPermitted = ..PermittedChangeFields(..#TYPEWEBAPPLICATION)
        Set tField = ""
        For {
            Set tField = $Order(pChanged(tField))
            If tField = "" Quit
            If '$ListFind(tPermitted, tField) {
                Do ..Refuse(..#UNCOVEREDFIELD, .pProhibits, .pCode)
                Quit
            }
        }
    } Catch ex {
        Set pProhibits = 0
        Set pCode = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The user predicates, in declared order, first hit wins: a disable of
/// <parameter>SYSTEMACCOUNTNAME</parameter>, of the signed-in account, or of the last
/// <code>%All</code> holder; an escalation-role change; a role delta that grants privilege; and any
/// other changed field the release has not reviewed.</p>
/// <p><var>pId</var> is the target's id as the reference carries it -- already canonical, and
/// compared through <method>NormalizedUser</method> anyway so an account addressed in another case
/// earns the same verdict. <var>pChanged</var> is <method>Changed</method>'s answer: the fields this
/// proposal changes, and the only fields any predicate here looks at.</p>
/// <p><b><code>$Username</code> is the one thing read from process state rather than from the stored
/// row</b>, and it is the right source: a confirm is a user-originated foreground request executing
/// as the caller (AD-40), confirmable only by the user who minted the proposal (AD-6), so the
/// process's user is the row's owner and is the person the refusal protects from signing themselves
/// out.</p>
/// <p><b>The name-matched disable refusals are scoped to a disable, by effect.</b> AD-10 forbids
/// deleting or disabling those accounts, so enabling one, or renaming its full name, is not this
/// predicate's business -- and <method>PermittedChangeFields</method> is what refuses every field
/// beyond the reviewed two in the first place.</p>
/// <p><b>Losing the last <code>%All</code> holder is not scoped to a disable</b>, because the
/// effect AD-10 names is reachable two ways: disabling that account, and taking the role off it.
/// <method>DePrivilegesLastAllHolder</method> is the one predicate both reach, which is why this
/// method asks it once rather than once per verb.</p>
ClassMethod User(pId As %String, pPayload As %DynamicObject, pTarget As %DynamicObject, ByRef pChanged, Output pProhibits As %Boolean, Output pCode As %String) As %Status [ Private ]
{
    Set pProhibits = 0
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        If ..Disables(pPayload, .pChanged) {
            Set tCanonical = ..NormalizedUser(pId)
            If tCanonical = ..NormalizedUser(..#SYSTEMACCOUNTNAME) {
                Do ..Refuse(..#SYSTEMACCOUNT, .pProhibits, .pCode)
                Quit
            }
            If tCanonical = ..NormalizedUser($Username) {
                Do ..Refuse(..#CURRENTUSER, .pProhibits, .pCode)
                Quit
            }
            If ..IsServiceAccount(pId) {
                Do ..Refuse(..#SERVICEACCOUNT, .pProhibits, .pCode)
                Quit
            }
        }
        Set tSC = ..DePrivilegesLastAllHolder(pId, pPayload, pTarget, .pChanged, .tLast)
        If $$$ISERR(tSC) Quit
        If tLast {
            Do ..Refuse(..#LASTALLHOLDER, .pProhibits, .pCode)
            Quit
        }
        If $Data(pChanged(..#FIELDESCALATIONROLES)) {
            Do ..Refuse(..#PRIVILEGEGRANT, .pProhibits, .pCode)
            Quit
        }
        If $Data(pChanged(..#FIELDROLES)) {
            Set tSC = ..GrantsPrivilege(pPayload, pTarget, .tGrants)
            If $$$ISERR(tSC) Quit
            If tGrants {
                Do ..Refuse(..#PRIVILEGEGRANT, .pProhibits, .pCode)
                Quit
            }
        }
        Set tPermitted = ..PermittedChangeFields(..#TYPEUSER)
        Set tField = ""
        For {
            Set tField = $Order(pChanged(tField))
            If tField = "" Quit
            If '$ListFind(tPermitted, tField) {
                Do ..Refuse(..#UNCOVEREDFIELD, .pProhibits, .pCode)
                Quit
            }
        }
    } Catch ex {
        Set pProhibits = 0
        Set pCode = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The auditing-configuration predicate: the reviewed-few sweep and nothing else.</p>
/// <p><var>pChanged</var> is <method>Changed</method>'s answer -- the fields this proposal changes.
/// A change to <code>Enabled</code> is permitted in <b>both</b> directions, because AD-10's set is
/// by effect and neither turning auditing on nor turning it off is an effect it forbids; every
/// other property of the object is refused <parameter>UNCOVEREDFIELD</parameter>, which is what
/// keeps a vendor property a later IRIS build adds to this endpoint's template out of the
/// <b>changed</b> set until somebody reviews it. The payload still carries it, unchanged, as the
/// complete body over the fresh read (AD-4); what this refuses is a proposal that moves it.</p>
/// <p><b>Turning auditing off is not prohibited, and that is the decision rather than an
/// omission</b>: the product answers it with the card's warning, the recorded drop of the marker
/// and the panel banner (AD-15 as amended 2026-09-21). Refusing it would mean an operator could
/// not do through OcuPilot what the classic portal lets them do in two clicks, while leaving the
/// window unrecorded either way.</p>
ClassMethod Auditing(ByRef pChanged, Output pProhibits As %Boolean, Output pCode As %String) As %Status [ Private ]
{
    Quit ..ReviewedFewOnly(..#TYPEAUDITING, .pChanged, .pProhibits, .pCode)
}

/// <p>The task predicate: the reviewed-few sweep and nothing else, over an empty permitted list.</p>
/// <p><var>pChanged</var> is <method>Changed</method>'s answer. A task's one write sends no body
/// (AD-51), so a proposal against a task changes no field and this refuses nothing; a proposal
/// that does carry one is refused <parameter>UNCOVEREDFIELD</parameter>, because
/// <method>PermittedChangeFields</method> names no task field anybody has reviewed.</p>
/// <p><b>The state row the card shows is not a changed field.</b> An action-style write's diff
/// names the state its action moves -- a resume's is labelled <code>Status</code> -- and
/// <method>Changed</method> skips the row naming the tool's declared
/// <method>OcuPilot.Screen.Tool.Write.StateField</method>, so the verdict is over effects rather
/// than over a row's label (AD-10). Skipping it is what the label needs, not the empty body: the
/// payload a bodyless write stores is its fresh read, and <code>Task.CRUD</code> answers a
/// <code>Status</code> property of its own -- the last run's result -- which moves whenever the
/// task runs.</p>
ClassMethod Task(ByRef pChanged, Output pProhibits As %Boolean, Output pCode As %String) As %Status [ Private ]
{
    Quit ..ReviewedFewOnly(..#TYPETASK, .pChanged, .pProhibits, .pCode)
}

/// <p>The application-error predicates: the reviewed-few sweep over an empty permitted list, and
/// nothing else.</p>
/// <p>AD-10's Release 1 set names no application-error effect. The one write over this type is the
/// bodyless by-namespace delete (AD-48, AD-51), which sets no field at all, so every changed field
/// a proposal against it could carry is one nobody has reviewed and is refused
/// <parameter>UNCOVEREDFIELD</parameter>. Its card's removal rows are not changed fields either:
/// each is labelled by the error's <b>date</b>, a name neither the stored payload nor the live
/// target answers, so both sides render <code>""</code> and the row is dropped as unchanged. What
/// <method>Changed</method> skips for this tool is the declared fingerprint subject --
/// <code>namespace</code> and <code>entries</code> -- which is the set whose movement the
/// fingerprint adjudicates, so it is not adjudicated a second time here (AD-51).</p>
/// <p><b>The delete is not prohibited by a predicate here, and that is the design.</b> What bounds
/// it is the per-namespace gate the port resolves at call time (AD-29, AD-48), the enumerated id
/// set the confirm removes exactly, and the confirmation itself -- none of which is an effect this
/// AD forbids.</p>
ClassMethod ApplicationError(ByRef pChanged, Output pProhibits As %Boolean, Output pCode As %String) As %Status [ Private ]
{
    Quit ..ReviewedFewOnly(..#TYPEAPPLICATIONERROR, .pChanged, .pProhibits, .pCode)
}

/// <p>The process predicates, in declared order, first hit wins: a process OcuPilot is itself
/// running in, an IRIS system process, then the reviewed-few sweep over an empty permitted list.</p>
/// <p><var>pTarget</var> is the <b>fresh</b> read <method>Target</method> took inside the confirm
/// transition, so both predicates read the instance rather than the stored payload -- a pid is
/// reusable once its process has ended, and the fingerprint's declared subject does not cover
/// <code>JobType</code>.</p>
/// <p><b>The first predicate is one rule for two harms</b> (<method>IsOcuPilotProcess</method>):
/// the job serving this confirmation and any job running a turn, whoever owns either. A process
/// the confirming user owns which is neither is <b>permitted</b> -- that is the narrowing of
/// 2026-09-22, and the reason is at <parameter>OCUPILOTPROCESS</parameter>.</p>
/// <p><b>System processes are an allow-list</b> (<method>ProcessJobTypes</method>) and fail closed
/// on a <code>JobType</code> the table does not name. Measured over the whole 31-process population
/// on this build, <code>CanBeSuspended</code> and <code>CanBeTerminated</code> are both 1 for the
/// Task Manager and for every Work Queue worker, so a refusal resting on the vendor's own booleans
/// would let the agent suspend the Task Manager; <code>NameSpace</code> separates nothing, being
/// empty for the core daemons and <code>%SYS</code> for an operator's own session.</p>
ClassMethod Process(pTarget As %DynamicObject, ByRef pChanged, Output pProhibits As %Boolean, Output pCode As %String) As %Status [ Private ]
{
    Set pProhibits = 0
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        If ..IsOcuPilotProcess(pTarget) {
            Do ..Refuse(..#OCUPILOTPROCESS, .pProhibits, .pCode)
            Quit
        }
        If '..IsActionableJobType(pTarget) {
            Do ..Refuse(..#SYSTEMPROCESS, .pProhibits, .pCode)
            Quit
        }
        Set tSC = ..ReviewedFewOnly(..#TYPEPROCESS, .pChanged, .pProhibits, .pCode)
    } Catch ex {
        Set pProhibits = 0
        Set pCode = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The <code>JobType</code> values a process this release lets the agent act on carries, as a
/// <class>%List</class> of integers: <code>FOREJOB</code> 1, <code>APPMODE</code> 2,
/// <code>FORAPPJOB</code> 3, <code>IDIRECTSRV</code> 26, <code>CSPSRV</code> 27,
/// <code>ODBCSRV</code> 28 and <code>CALLINTYPE</code> 47.</p>
/// <p><b>Only 1 and 3 are interactive.</b> <file>%syPidtab.inc</file>:128 defines
/// <code>INTERACTIVEJOB</code> as <code>FOREJOB</code> or <code>FORAPPJOB</code>; the other five
/// here it groups under <code>BACKGROUNDJOB</code> at :132, alongside the Work Queue workers this
/// list refuses. So the set is a user's own session plus the client servers that answer for one,
/// and it admits a <code>JOB</code>ed background process -- OcuPilot's own turn job among them.</p>
/// <p><b>An allow-list rather than a deny-list</b>, so a value a later IRIS build adds to that
/// include file is refused until somebody reviews it. The daemons, the Task Manager
/// (<code>TASKTYPE</code> 36) and the Work Queue workers (<code>WORKQUEUESRV</code> 59) are all
/// outside it.</p>
ClassMethod ProcessJobTypes() As %List
{
    Quit $ListBuild(1, 2, 3, 26, 27, 28, 47)
}

/// <p>Whether <var>pTarget</var>'s <code>JobType</code> is one <method>ProcessJobTypes</method>
/// admits. A read that answered no <code>JobType</code>, or one this method cannot read as a whole
/// number, is <b>not</b> actionable: a process whose kind nobody established is a system process
/// as far as this predicate is concerned.</p>
ClassMethod IsActionableJobType(pTarget As %DynamicObject) As %Boolean
{
    If '$IsObject(pTarget) Quit 0
    Set tType = ..Rendered(pTarget, ..#FIELDJOBTYPE)
    If tType = "" Quit 0
    If '$Match(tType, "^[0-9]+$") Quit 0
    Quit ''$ListFind(..ProcessJobTypes(), +tType)
}

/// <p>Whether <var>pTarget</var> is a process OcuPilot is itself running in: its <code>Pid</code>
/// is this job's own -- the job serving the confirmation, which suspending would kill the write
/// inside AD-34's transition -- or it is the job of a turn this instance is running (AD-7),
/// whoever started it.</p>
/// <p>A turn job is identified from OcuPilot's own record rather than from the process: a running
/// turn's row carries the pid of the job that began it
/// (<method>OcuPilot.Kernel.State.Turn.GuardedIsTurnJob</method>). Only a <b>running</b> turn
/// counts, so a finished turn's pid, once the instance reuses it, does not refuse an unrelated
/// process.</p>
/// <p><b>It fails closed</b> on a read that carries no <code>Pid</code> and on a state read that
/// errors: a process whose identity nobody established, and a question OcuPilot could not answer
/// about itself, are both refused rather than proposed.</p>
ClassMethod IsOcuPilotProcess(pTarget As %DynamicObject) As %Boolean
{
    If '$IsObject(pTarget) Quit 1
    Set tPid = ..Rendered(pTarget, ..#FIELDPID)
    If tPid = "" Quit 1
    If ##class(OcuPilot.Kernel.EntityRef).NormalizedId(..#TYPEPROCESS, tPid) = ##class(OcuPilot.Kernel.EntityRef).NormalizedId(..#TYPEPROCESS, $Job) Quit 1
    Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedIsTurnJob(tPid, .tTurnJob)
    If $$$ISERR(tSC) Quit 1
    Quit ''tTurnJob
}

/// <p>The reviewed-few sweep for entity type <var>pType</var>: every field <var>pChanged</var>
/// names that <method>PermittedChangeFields</method> does not is refused
/// <parameter>UNCOVEREDFIELD</parameter>.</p>
/// <p>The whole of the two shortest branches, so a type whose predicates are exactly "the reviewed
/// few and nothing else" adds a permitted list rather than a second copy of this loop.</p>
ClassMethod ReviewedFewOnly(pType As %String, ByRef pChanged, Output pProhibits As %Boolean, Output pCode As %String) As %Status [ Private ]
{
    Set pProhibits = 0
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        Set tPermitted = ..PermittedChangeFields(pType)
        Set tField = ""
        For {
            Set tField = $Order(pChanged(tField))
            If tField = "" Quit
            If '$ListFind(tPermitted, tField) {
                Do ..Refuse(..#UNCOVEREDFIELD, .pProhibits, .pCode)
                Quit
            }
        }
    } Catch ex {
        Set pProhibits = 0
        Set pCode = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the rendered value <var>pValue</var> reads as off. The instance answers
/// <code>Enabled</code> as a boolean on its <code>GET</code> and the template types it boolean, so
/// <method>OcuPilot.Kernel.Proposal.Mint.Display</method> renders it <code>true</code> or
/// <code>false</code>.</p>
/// <p><b>Only <code>true</code> reads as on.</b> A numeric spelling is read for its value, and
/// every other rendering -- an absent member, and any spelling this method does not know -- is read
/// as off, because a value the predicate cannot read as on must not be treated as leaving the
/// account enabled: the three disable refusals behind this guard would then be skipped. An
/// unreadable payload renders every member <code>""</code>
/// (<method>ParsedObject</method>), which is the reachable case.</p>
ClassMethod IsOff(pValue As %String) As %Boolean [ Private ]
{
    If pValue = "true" Quit 0
    If pValue = "false" Quit 1
    If pValue = "" Quit 1
    If $IsValidNum(pValue) Quit (+pValue = 0)
    Quit 1
}

/// <p><var>pName</var> in the one spelling a reference to an account carries. The rule is the
/// identity layer's, not this class's -- <method>NormalizedPath</method>'s counterpart for
/// accounts, and for the same reason: the same rule decides which reference key a proposal's target
/// gets and so which lock and which siblings a confirm of it takes (AD-34).</p>
ClassMethod NormalizedUser(pName As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityRef).NormalizedId(..#TYPEUSER, pName)
}

/// <p>Whether the role delta between <var>pTarget</var>'s live roles and <var>pPayload</var>'s
/// would grant privilege, in <var>pGrants</var> (AD-10): an added role that is
/// <parameter>ALLROLE</parameter>, carries the <parameter>ADMINROLEPREFIX</parameter> prefix, holds
/// a role that does, or carries such a name as a <b>resource</b>
/// (<method>RoleEscalates</method>).</p>
/// <p><b>It is a delta, not a match on the payload.</b> AD-4 makes the payload the complete
/// property set, so an account that already holds <code>%All</code> sends it back on every write;
/// reading the payload alone would refuse every change to such an account. A role the write
/// <i>removes</i> grants nothing and is not this predicate's business.</p>
/// <p><b>Asking the instance is what makes it "through any path".</b> A custom role that grants
/// <code>%All</code>, and a stock role that carries <code>%Admin_Secure</code> as a resource under
/// a name saying nothing, are both grants of that privilege, so the question is asked of the
/// instance rather than of the role's name. A name the instance holds no role for grants nothing
/// here; the vendor's own validation is what refuses it.</p>
ClassMethod GrantsPrivilege(pPayload As %DynamicObject, pTarget As %DynamicObject, Output pGrants As %Boolean) As %Status [ Private ]
{
    Set pGrants = 0
    Set tSC = $$$OK
    Try {
        Kill tHeld
        Kill tWanted
        Do ..RoleNames(pTarget, .tHeld)
        Do ..RoleNames(pPayload, .tWanted)
        Set tKey = ""
        For {
            Set tKey = $Order(tWanted(tKey))
            If tKey = "" Quit
            If $Data(tHeld(tKey)) Continue
            Set tSC = ..RoleEscalates(tWanted(tKey), .tEscalates)
            If $$$ISERR(tSC) Quit
            If tEscalates {
                Set pGrants = 1
                Quit
            }
        }
    } Catch ex {
        Set pGrants = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The role names <var>pObject</var>'s <code>Roles</code> member carries, as
/// <var>pNames(&lt;upper-cased name&gt;) = &lt;name as written&gt;</var>. An IRIS role name is
/// case-insensitive, so the key is folded and the value keeps the spelling a recursed lookup is
/// made with.</p>
/// <p>The member is an array on the vendor's own <code>GET</code> and in a payload the merge built
/// from one; a comma-separated string is read too, because that is how the same property reaches
/// <class>Security.Users</class>, and a member carrying neither names no role.</p>
ClassMethod RoleNames(pObject As %DynamicObject, Output pNames) [ Private ]
{
    Kill pNames
    If '$IsObject(pObject) Quit
    If pObject.%GetTypeOf(..#FIELDROLES) = "array" {
        Set tValue = pObject.%Get(..#FIELDROLES)
        If '$IsObject(tValue) Quit
        Set tIterator = tValue.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tItem) {
            If $IsObject(tItem) Continue
            Set tOne = $ZStrip(tItem, "<>W")
            If tOne = "" Continue
            Set pNames($ZConvert(tOne, "U")) = tOne
        }
        Quit
    }
    Set tRaw = ..Rendered(pObject, ..#FIELDROLES)
    For tI = 1:1:$Length(tRaw, ",") {
        Set tOne = $ZStrip($Piece(tRaw, ",", tI), "<>W")
        If tOne = "" Continue
        Set pNames($ZConvert(tOne, "U")) = tOne
    }
}

/// <p>Whether granting <var>pRole</var> grants <code>%All</code> or an administrative privilege, in
/// <var>pEscalates</var>: the name itself, or any name in the set the instance says it recurses to,
/// or any <b>resource</b> one of those roles carries.</p>
/// <p><b>A role's name says almost nothing about what it grants, so the resources are what the
/// question is really about.</b> IRIS ships no role whose name begins
/// <parameter>ADMINROLEPREFIX</parameter> -- the prefix names <i>resources</i> -- and a role grants
/// a resource directly rather than through another role, so the recursed role set alone answers
/// nothing about administrative privilege. Measured on this build: <code>%Manager</code>,
/// <code>%Operator</code> and <code>%SecurityAdministrator</code> each recurse to themselves alone
/// and each carries <code>%Admin_Secure:U</code> or <code>%Admin_Operate:U</code> as a resource, so
/// granting one is a grant of exactly the privilege this write tool itself gates on. Each role in
/// the recursed set is therefore read for its resource list as well as its name.</p>
ClassMethod RoleEscalates(pRole As %String, Output pEscalates As %Boolean) As %Status [ Private ]
{
    Set pEscalates = 0
    Set tSC = $$$OK
    Try {
        If ..IsPrivilegedRole(pRole) {
            Set pEscalates = 1
            Quit
        }
        Set tRecursed = ""
        Set tSC = $SYSTEM.Security.GetRecursedRoleSet(pRole, .tRecursed)
        If $$$ISERR(tSC) Quit
        For tI = 1:1:$Length(tRecursed, ",") {
            Set tOne = $Piece(tRecursed, ",", tI)
            If ..IsPrivilegedRole(tOne) {
                Set pEscalates = 1
                Quit
            }
            Set tSC = ..RoleGrantsPrivilege(tOne, .tGrants)
            If $$$ISERR(tSC) Quit
            If tGrants {
                Set pEscalates = 1
                Quit
            }
        }
        If $$$ISERR(tSC) Quit
        ; A name the instance holds no role for recurses to nothing, so the loop above saw no
        ; member: ask for the name's own resources before answering that it grants nothing.
        If 'pEscalates && (tRecursed = "") {
            Set tSC = ..RoleGrantsPrivilege(pRole, .tGrants)
            If $$$ISERR(tSC) Quit
            Set pEscalates = ''tGrants
        }
    } Catch ex {
        Set pEscalates = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether role <var>pRole</var> carries a privileged <b>resource</b>, in <var>pGrants</var>:
/// one named <parameter>ALLROLE</parameter> or carrying <parameter>ADMINROLEPREFIX</parameter>, at
/// any permission.</p>
/// <p>The resource list is the instance's own (<class>Security.Roles</class>, read in
/// <code>%SYS</code> and restored, AD-16). A name the instance holds no role for carries nothing,
/// which is the same answer <method>RoleEscalates</method> gives it: the vendor's own validation is
/// what refuses an unknown role.</p>
/// <p><b>The prefix, not a list.</b> Matching the resource-name prefix rather than a roster of
/// today's administrative resources is a rule a later build's new <code>%Admin_*</code> resource
/// cannot outgrow. It admits every resource outside that prefix, which is what keeps an ordinary
/// role add permitted -- measured on this build, <code>%Developer</code>, <code>%SQL</code> and
/// <code>%EnsRole_Operator</code> carry none.</p>
ClassMethod RoleGrantsPrivilege(pRole As %String, Output pGrants As %Boolean) As %Status [ Private ]
{
    Set pGrants = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        If $ZStrip(pRole, "<>W") = "" Quit
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tGetSC = ##class(Security.Roles).Get(pRole, .tProps)
        Set tResources = ""
        If $$$ISOK(tGetSC) Set tResources = $Get(tProps("Resources"))
        Set $NAMESPACE = tOrigNS
        For tI = 1:1:$Length(tResources, ",") {
            If ..IsPrivilegedRole($Piece($Piece(tResources, ",", tI), ":", 1)) Set pGrants = 1
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pGrants = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pRole</var> is <parameter>ALLROLE</parameter> or carries
/// <parameter>ADMINROLEPREFIX</parameter>, compared case-insensitively because IRIS resolves a role
/// name that way.</p>
/// <p>It serves a role name and a <b>resource</b> name alike (<method>RoleGrantsPrivilege</method>):
/// the two patterns AD-10 names are the same strings in either vocabulary, and one test for both is
/// what keeps them from drifting apart.</p>
ClassMethod IsPrivilegedRole(pRole As %String) As %Boolean [ Private ]
{
    Set tName = $ZConvert($ZStrip(pRole, "<>W"), "U")
    If tName = "" Quit 0
    If tName = $ZConvert(..#ALLROLE, "U") Quit 1
    Quit $Extract(tName, 1, $Length(..#ADMINROLEPREFIX)) = $ZConvert(..#ADMINROLEPREFIX, "U")
}

/// <p>Whether this proposal turns the target's <code>Enabled</code> off, in the sense the disable
/// refusals are scoped to: the diff names that field and the payload's value reads as off
/// (<method>IsOff</method>).</p>
ClassMethod Disables(pPayload As %DynamicObject, ByRef pChanged) As %Boolean [ Private ]
{
    If '$Data(pChanged(..#FIELDENABLED)) Quit 0
    Quit ..IsOff(..Rendered(pPayload, ..#FIELDENABLED))
}

/// <p>Whether this proposal would leave the instance with no account a person can sign in as
/// holding <code>%All</code>, in <var>pLast</var> (AD-10).</p>
/// <p><b>One predicate, two paths to the same effect.</b> Disabling the last counting holder and
/// taking <code>%All</code> off it through a role change end in the same place -- an instance
/// nobody can administer -- so AD-10's by-effect set answers them with one rule rather than two
/// kept in step. Either path asks <method>LastAllHolder</method>, whose census
/// (<method>CountsAsHolder</method>) is what decides which rows are a fallback at all.</p>
/// <p>The role path's own half is <method>RolesGrantAll</method> over the <b>payload's</b> role
/// list, which AD-4 makes the complete set the write will send: a payload that still grants
/// <code>%All</code> removes nothing, and the census is not consulted. Where it does not, the
/// census decides, and <method>LastAllHolder</method> answers 0 for a target that does not hold
/// <code>%All</code> today -- so an ordinary account's role change costs one live read and is
/// permitted.</p>
ClassMethod DePrivilegesLastAllHolder(pId As %String, pPayload As %DynamicObject, pTarget As %DynamicObject, ByRef pChanged, Output pLast As %Boolean) As %Status [ Private ]
{
    Set pLast = 0
    Set tSC = $$$OK
    Try {
        Set tReaches = ..Disables(pPayload, .pChanged)
        If 'tReaches && $Data(pChanged(..#FIELDROLES)) {
            Kill tWanted
            Do ..RoleNames(pPayload, .tWanted)
            Set tSC = ..RolesGrantAll(.tWanted, .tGrants)
            If $$$ISERR(tSC) Quit
            Set tReaches = 'tGrants
        }
        If 'tReaches Quit
        Set tSC = ..LastAllHolder(pId, .pLast)
    } Catch ex {
        Set pLast = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the role names in <var>pNames</var> grant <parameter>ALLROLE</parameter> between
/// them, in <var>pGrants</var>: a name that is <code>%All</code> itself, or any role the instance
/// says that name recurses to.</p>
/// <p>It asks the instance rather than matching the written name, for the reason
/// <method>HoldsAll</method> does -- a custom role can grant <code>%All</code> under a name saying
/// nothing -- and it is the narrower question than <method>RoleEscalates</method>'s, which also
/// answers yes for an administrative resource. Only <code>%All</code> is the privilege this
/// predicate's caller is counting.</p>
/// <p><b>A name the instance cannot resolve grants nothing here</b>, which leaves the caller
/// reading the payload as no longer granting <code>%All</code> -- so an unresolvable role makes
/// the write look more like the one that strips the last holder, and the caller refuses rather
/// than writes.</p>
ClassMethod RolesGrantAll(ByRef pNames, Output pGrants As %Boolean) As %Status [ Private ]
{
    Set pGrants = 0
    Set tSC = $$$OK
    Try {
        Set tKey = ""
        For {
            Set tKey = $Order(pNames(tKey))
            If tKey = "" Quit
            Set tName = pNames(tKey)
            If $ZConvert($ZStrip(tName, "<>W"), "U") = $ZConvert(..#ALLROLE, "U") {
                Set pGrants = 1
                Quit
            }
            Set tRecursed = ""
            Set tRecurseSC = $SYSTEM.Security.GetRecursedRoleSet(tName, .tRecursed)
            If $$$ISERR(tRecurseSC) Continue
            For tI = 1:1:$Length(tRecursed, ",") {
                If $ZConvert($ZStrip($Piece(tRecursed, ",", tI), "<>W"), "U") = $ZConvert(..#ALLROLE, "U") Set pGrants = 1
            }
            If pGrants Quit
        }
    } Catch ex {
        Set pGrants = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pId</var> is the only account on this instance that holds <code>%All</code>, in
/// <var>pLast</var> (AD-10).</p>
/// <p><b>It is a query over the whole population, and it asks the instance.</b> Every account the
/// instance holds is listed and each is asked for its <i>recursed</i> role set, so an account that
/// holds <code>%All</code> only through a custom role is counted -- a substring match on a declared
/// <code>Roles</code> list would miss it and the predicate would then permit the write that locks
/// the instance out.</p>
/// <p><b>Which rows count is <method>CountsAsHolder</method>'s question</b>, asked of each row
/// before <method>HoldsAll</method> is asked about it: only an account a person can sign in as
/// counts, because counting one that cannot would let the last usable holder be disabled.</p>
/// <p><b>Overridable seam.</b> A test drives the refusal by answering here, so no suite has to
/// strip <code>%All</code> from a real account to make an instance have one holder. Production
/// never overrides it; <method>HoldsAll</method> is the half a test exercises directly.</p>
ClassMethod LastAllHolder(pId As %String, Output pLast As %Boolean) As %Status
{
    Set pLast = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ..HoldsAll(pId, .tTargetHolds)
        If $$$ISERR(tSC) Quit
        If 'tTargetHolds Quit
        Set tCanonical = ..NormalizedUser(pId)
        ; The population is read inside %SYS and nothing else happens there: both judging a row
        ; and normalizing a name reach OcuPilot's own classes, which are not visible in %SYS, so
        ; the rows are carried out verbatim and filtered after the restore (AD-16). Columns 1 and 2
        ; are Name and Enabled (irissys/Security/Users.cls:663's ROWSPEC
        ; "Name,Enabled,Roles,LastLoginTime,Flags").
        Set tRows = ""
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Security.Users:List")
        Set tSC = tRS.Execute("*", "*")
        If $$$ISOK(tSC) {
            While tRS.Next() {
                Set tRows = tRows _ $ListBuild($ListBuild(tRS.GetData(1), tRS.GetData(2)))
            }
            Do tRS.Close()
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        Set tNames = ""
        For tI = 1:1:$ListLength(tRows) {
            Set tRow = $List(tRows, tI)
            If '..CountsAsHolder($List(tRow, 1), $List(tRow, 2)) Continue
            Set tNames = tNames _ $ListBuild($List(tRow, 1))
        }
        Set pLast = 1
        For tI = 1:1:$ListLength(tNames) {
            Set tName = $List(tNames, tI)
            If ..NormalizedUser(tName) = tCanonical Continue
            Set tSC = ..HoldsAll(tName, .tHolds)
            If $$$ISERR(tSC) Quit
            If tHolds {
                Set pLast = 0
                Quit
            }
        }
        If $$$ISERR(tSC) Set pLast = 0
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pLast = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the population row <var>pName</var> / <var>pEnabled</var> can count as another
/// <code>%All</code> holder at all, before <method>HoldsAll</method> is asked about it. The two
/// arguments are columns 1 and 2 of <code>Security.Users:List</code>
/// (<file>irissys/Security/Users.cls</file>:663).</p>
/// <p><b>Only an account a person can sign in as counts.</b> Two reasons a row cannot be one: its
/// enabled column does not read positively, and it is one of the unauthenticated placeholders
/// <parameter>OcuPilot.Screen.Gate.ANONYMOUSPRINCIPALS</parameter> names -- which the list answers
/// enabled, and which AD-21 records as holding <code>%All</code> on a Minimal-security instance.
/// Counting either would let the last account an operator can actually use be disabled. The list of
/// placeholders has one home and this is not it (AD-21); a value this method cannot read as enabled
/// leaves the target looking more like the last holder, which refuses rather than writes.</p>
/// <p><b>A third reason: the row is an account one of the instance's own services runs as</b>
/// (<parameter>SERVICEACCOUNTS</parameter>). Nobody signs in as one, so it can never be the holder
/// an operator falls back on -- and on a stock instance two of them hold <code>%All</code>, which
/// made this census answer "there is another holder" for an instance whose only usable holder was
/// the account being disabled.</p>
ClassMethod CountsAsHolder(pName As %String, pEnabled As %String) As %Boolean
{
    If $ZStrip(pName, "<>W") = "" Quit 0
    If '##class(OcuPilot.Screen.Gate).IsAuthenticatedPrincipal(pName) Quit 0
    If ..IsServiceAccount(pName) Quit 0
    If $ZConvert(pEnabled, "U") = "YES" Quit 1
    Quit (pEnabled = 1)
}

/// <p>Whether <var>pName</var> is one of the accounts <parameter>SERVICEACCOUNTS</parameter> names,
/// compared through <method>NormalizedUser</method> so a re-cased spelling earns the same verdict
/// (AD-13).</p>
ClassMethod IsServiceAccount(pName As %String) As %Boolean
{
    Set tIs = 0
    Set tCanonical = ..NormalizedUser(pName)
    If tCanonical = "" Quit 0
    For tI = 1:1:$Length(..#SERVICEACCOUNTS, ",") {
        Set tOne = $ZStrip($Piece(..#SERVICEACCOUNTS, ",", tI), "<>W")
        If tOne = "" Continue
        If ..NormalizedUser(tOne) = tCanonical Set tIs = 1
    }
    Quit tIs
}

/// <p><parameter>SERVICEACCOUNTS</parameter> as a <class>%List</class>, in the order it declares
/// them.</p>
ClassMethod ServiceAccounts() As %List
{
    Set tList = ""
    For tI = 1:1:$Length(..#SERVICEACCOUNTS, ",") {
        Set tOne = $ZStrip($Piece(..#SERVICEACCOUNTS, ",", tI), "<>W")
        If tOne '= "" Set tList = tList _ $ListBuild(tOne)
    }
    Quit tList
}

/// <p>Whether account <var>pUser</var> would hold <code>%All</code> if it signed in, in
/// <var>pHolds</var>.</p>
/// <p>It asks <method>%SYSTEM.Security.GetUserRecursedRoleSet</method>, which answers the whole set
/// a login would grant -- roles a role grants included -- so a custom role that grants
/// <code>%All</code> counts. That method needs <code>%Admin_Secure:USE</code> for an account other
/// than the caller's own, which is a pair every write reaching this class already holds (AD-8).</p>
ClassMethod HoldsAll(pUser As %String, Output pHolds As %Boolean) As %Status
{
    Set pHolds = 0
    Set tSC = $$$OK
    Try {
        If pUser = "" Quit
        Set tRoles = ""
        Set tSC = $SYSTEM.Security.GetUserRecursedRoleSet(pUser, .tRoles)
        If $$$ISERR(tSC) Quit
        For tI = 1:1:$Length(tRoles, ",") {
            If $ZConvert($ZStrip($Piece(tRoles, ",", tI), "<>W"), "U") = $ZConvert(..#ALLROLE, "U") Set pHolds = 1
        }
    } Catch ex {
        Set pHolds = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The fields this proposal changes, as <var>pChanged(&lt;field&gt;)</var> with their number at
/// the root: every field the stored diff <var>pDiff</var> names whose payload value differs from
/// <var>pTarget</var>'s as the instance holds it now.</p>
/// <p>Both halves are load-bearing. The diff is the mint's own record of what the proposal changes
/// relative to the target it was minted against, so a field a third party moved after the mint is
/// never attributed to the agent -- that target is answered 409 by the fingerprint gate behind the
/// set, which also closes the row, rather than 403 for a change nobody proposed. The live
/// comparison is what makes a verdict an effect rather than a match on a stored field (AD-10): a
/// field the diff names whose value the instance already holds changes nothing.</p>
/// <p><var>pSkipped</var> is what this tool's own declarations put outside the sweep
/// (<method>SkippedFields</method>), and a row naming any of it is skipped.</p>
/// <p>It holds two things, for one reason. The <b>state-row label</b> names the state an
/// action-style write moves rather than a payload field (AD-51), and a label may spell a property
/// the endpoint also answers for its own reasons -- a resume's row is labelled <code>Status</code>
/// while <code>Task.CRUD</code>'s <code>Status</code> is the last run's result. The <b>declared
/// fingerprint subject</b> is by construction the set whose movement the fingerprint adjudicates,
/// so re-adjudicating it here would answer a moved target 403
/// <parameter>UNCOVEREDFIELD</parameter> with the proposal row left live, where AD-6 requires 409
/// <code>PROPOSAL.TARGETCHANGED</code> with it closed. Both are the same defect: a row this sweep
/// must not read as a payload field.</p>
ClassMethod Changed(pDiff As %String, pPayload As %DynamicObject, pTarget As %DynamicObject, pSkipped As %List, Output pChanged) As %Status [ Private ]
{
    Kill pChanged
    Set pChanged = 0
    Set tSC = $$$OK
    Try {
        Set tRows = ..ParsedArray(pDiff)
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            Set tField = tRow.%Get("field")
            If tField = "" Continue
            If $ListFind(pSkipped, tField) Continue
            If $Data(pChanged(tField)) Continue
            If ..Rendered(pPayload, tField) = ..Rendered(pTarget, tField) Continue
            Set pChanged(tField) = ""
            Set pChanged = pChanged + 1
        }
    } Catch ex {
        Kill pChanged
        Set pChanged = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The target at <var>pId</var> as <var>pToolName</var>'s own endpoint answers it now, in
/// <var>pTarget</var>, with <var>pPresent</var> 0 for a target the instance no longer holds and
/// the resolved tool class in <var>pToolClass</var>.</p>
/// <p>The endpoint and the identifying parameter come from the tool the proposal names, through
/// the registry, so this class names no endpoint of its own. A 404 is absence; any other refusal,
/// and a success that carried no object, are error statuses, because a target that could not be
/// read is not a target that was checked. <var>pToolClass</var> is answered from the same single
/// resolve, so the caller reads the tool's declarations without a second registry lookup.</p>
ClassMethod Target(pToolName As %String, pId As %String, Output pTarget As %DynamicObject, Output pPresent As %Boolean, Output pToolClass As %String) As %Status [ Private ]
{
    Set pTarget = ""
    Set pPresent = 0
    Set pToolClass = ""
    Set tSC = $$$OK
    Try {
        Set tSC = $ClassMethod(..RegistryClass(), "Resolve", pToolName, .tTool)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tTool) {
            Set tSC = $$$ERROR($$$GeneralError, "the prohibited set was asked about a tool this instance does not carry: '" _ pToolName _ "'")
            Quit
        }
        Set tClass = tTool.%Get("class")
        Set pToolClass = tClass
        Set tEndpoint = $ClassMethod(tClass, "Endpoint")
        Set tIdParam = $ClassMethod(tClass, "IdParam")
        If (tEndpoint = "") || (tIdParam = "") || (pId = "") {
            Set tSC = $$$ERROR($$$GeneralError, "the prohibited set could not address the target of '" _ pToolName _ "'")
            Quit
        }
        Kill tQuery
        Set tQuery(tIdParam) = pId
        Set tReadSC = $ClassMethod(..PortClassOf(tClass), "Invoke", tEndpoint, ..ReadTypeOf(tClass), .tQuery, "", .tFresh, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If +$Get(tHttp) = 404 Quit
            Set tSC = tReadSC
            Quit
        }
        If '$IsObject(tFresh) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set tSC = $$$ERROR($$$GeneralError, "the prohibited set read the target of '" _ pToolName _ "' and was answered no object")
            Quit
        }
        Set pTarget = tFresh
        Set pPresent = 1
    } Catch ex {
        Set pTarget = ""
        Set pPresent = 0
        Set pToolClass = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The admin request type <var>pToolClass</var>'s target is read with (AD-51), or
/// <parameter>READTYPE</parameter> when the class declares none or cannot be asked.</p>
ClassMethod ReadTypeOf(pToolClass As %String) As %String [ Private ]
{
    Set tType = ""
    Try {
        If pToolClass '= "" Set tType = $ClassMethod(pToolClass, "ReadType")
    } Catch {
        Set tType = ""
    }
    If tType = "" Quit ..#READTYPE
    Quit tType
}

/// <p>The state-row label <var>pToolClass</var> declares (AD-51), or <code>""</code> for a merge
/// write and for a class that cannot be asked -- which is the answer that leaves
/// <method>Changed</method> reading every diff row, so an unaskable class never narrows the
/// set.</p>
ClassMethod StateFieldOf(pToolClass As %String) As %String [ Private ]
{
    Set tField = ""
    Try {
        If pToolClass '= "" Set tField = $ClassMethod(pToolClass, "StateField")
    } Catch {
        Set tField = ""
    }
    Quit tField
}

/// <p>The diff-row names <method>Changed</method> leaves outside its sweep for
/// <var>pToolClass</var>: its declared state-row label and every name its declared fingerprint
/// subject covers (AD-51). Empty for a merge write and for a class that cannot be asked, which is
/// the answer that leaves every diff row read.</p>
ClassMethod SkippedFields(pToolClass As %String) As %List
{
    Set tSkipped = ""
    Set tField = ..StateFieldOf(pToolClass)
    If tField '= "" Set tSkipped = $ListBuild(tField)
    Try {
        If pToolClass = "" Quit
        Set tSubject = $ClassMethod(pToolClass, "FingerprintSubject")
        For tI = 1:1:$ListLength(tSubject) {
            Set tName = $List(tSubject, tI)
            If (tName = "") || $ListFind(tSkipped, tName) Continue
            Set tSkipped = tSkipped _ $ListBuild(tName)
        }
    } Catch {
        ; Deliberately empty: the state field collected above is kept, and a class that cannot be
        ; asked narrows nothing further.
    }
    Quit tSkipped
}

/// <p>Whether the web application at <var>pPath</var> is one OcuPilot is served by, in
/// <var>pServes</var>: a path <class>OcuPilot.Install.Roster</class> declares, or one
/// <class>OcuPilot.Kernel.State.WebApp</class> recorded at install -- the production applications
/// and a probe profile's alike.</p>
/// <p><var>pPath</var> is the id the proposal carries, so both sides are compared through
/// <method>NormalizedPath</method>: the instance resolves a re-cased or slash-suffixed id to the
/// same application, and a predicate that did not would read OcuPilot's own API as somebody
/// else's while the write reached it (DW-1352). Install's record is looked up by that normalized
/// path alone -- every path install records is a roster or probe literal already in that
/// form.</p>
/// <p>A roster that cannot be read is an error, never an empty declaration: an empty one would
/// make every OcuPilot path writable.</p>
ClassMethod ServesOcuPilot(pPath As %String, Output pServes As %Boolean) As %Status [ Private ]
{
    Set pServes = 0
    Set tSC = $$$OK
    Try {
        Set tPath = ..NormalizedPath(pPath)
        Set tKeys = ##class(OcuPilot.Install.Roster).Keys()
        If tKeys = "" {
            Set tSC = $$$ERROR($$$GeneralError, "the install roster's application keys could not be read, so which paths serve OcuPilot is unknown")
            Quit
        }
        For tI = 1:1:$Length(tKeys, ",") {
            Set tSC = ##class(OcuPilot.Install.Roster).Application($Piece(tKeys, ",", tI), .tApp)
            If $$$ISERR(tSC) Quit
            If $IsObject(tApp) && (..NormalizedPath(tApp.path) = tPath) Set pServes = 1
        }
        If $$$ISERR(tSC) Quit
        If pServes Quit
        Set tSC = ..Recorded(tPath, .pServes)
    } Catch ex {
        Set pServes = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether install recorded an application at exactly <var>pPath</var>, in <var>pServes</var>.
/// The record's own lookup is an exact compare, so the caller passes the normalized path: every
/// path install writes is a roster or probe literal already in that form.</p>
ClassMethod Recorded(pPath As %String, Output pServes As %Boolean) As %Status [ Private ]
{
    Set pServes = 0
    Set tSC = ##class(OcuPilot.Kernel.State.WebApp).GuardedForPath(pPath, .tRow)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject(tRow) Set pServes = 1
    Set tRow = ""
    Quit tSC
}

/// <p><var>pPath</var> in the form this instance resolves a web application name in. Two spellings
/// that normalize alike name one application to the instance, so they must earn one verdict from
/// the set.</p>
/// <p><b>The rule is the identity layer's, not this class's</b>: a web application's canonical
/// spelling is what <method>OcuPilot.Kernel.EntityRef.NormalizedId</method> answers, because the
/// same rule decides which reference key a proposal's target gets and so which lock and which
/// siblings a confirm of it takes (AD-34). The set delegates to it; making AD-10's one home the
/// project's path normalizer would point the identity layer at the safety gate. This method stays
/// because a caller of the set reads its verdict here, and because the roster paths and install's
/// records it compares are not references.</p>
/// <p><class>OcuPilot.Test.ProhibitedRoute</class> pins the rule against the instance's own
/// answers, which is the only way that agreement can fail for the right reason.</p>
ClassMethod NormalizedPath(pPath As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityRef).NormalizedId(##class(OcuPilot.Kernel.EntityRef).#TYPEWEBAPPLICATION, pPath)
}

/// <p><var>pObject</var>'s member <var>pName</var> in the rendered form the diff and the
/// fingerprint compare values in (<method>OcuPilot.Kernel.Proposal.Mint.Display</method>), or
/// <code>""</code> when it carries none. One comparison, so a predicate and the diff the user read
/// cannot disagree about whether a value changed.</p>
ClassMethod Rendered(pObject As %DynamicObject, pName As %String) As %String [ Private ]
{
    If '$IsObject(pObject) Quit ""
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Display(pObject.%Get(pName), pObject.%GetTypeOf(pName))
}

/// <p>Whether a payload's rendered <code>AutheEnabled</code> is the target's own mask with the
/// unauthenticated bit cleared and nothing else changed, which is the one authentication change
/// this release permits.</p>
/// <p>The property is not a set of ways in: the same mask carries strength modifiers
/// (<file>irissys/%sySecurityMacros.inc</file>:15-40 -- AutheTwoFactorPW 2097152, AutheTwoFactorSMS
/// 1048576, AutheLDAPCache 4096, AutheKBEncryption 256, AutheKBIntegrity 512,
/// AutheAlwaysTryDelegated 16777216, AutheMutualTLS 33554432), so a subset test reads clearing
/// two-factor as a narrowing and requiring it as a widening -- both backwards. Permitting exactly
/// one transition instead is a rule a later build's new bit cannot outgrow, whether that bit is a
/// mechanism or a modifier: adding any bit, clearing any other bit and clearing the mask entirely
/// are all refused, and so is a value either side cannot read as a non-negative whole number,
/// because the set does not clear a payload it cannot judge. A target mask of 0 therefore permits
/// no change at all -- <code>0 -&gt; 32</code> is refused with the rest.</p>
ClassMethod ClearsUnauthenticatedOnly(pPayload As %String, pTarget As %String) As %Boolean [ Private ]
{
    If '$IsValidNum(pPayload) || '$IsValidNum(pTarget) Quit 0
    If (+pPayload '= (pPayload \ 1)) || (+pTarget '= (pTarget \ 1)) Quit 0
    If (+pPayload < 0) || (+pTarget < 0) Quit 0
    Set tTarget = pTarget \ 1
    Set tPermitted = tTarget - (((tTarget \ ..#UNAUTHENTICATEDBIT) # 2) * ..#UNAUTHENTICATEDBIT)
    Quit (pPayload \ 1) = tPermitted
}

/// <p><var>pText</var> parsed as a JSON object, or <code>{}</code> when it is empty or
/// unreadable. Every member of such a payload renders <code>""</code>, so a field the diff names
/// whose live value is not empty compares as changed and is refused.</p>
ClassMethod ParsedObject(pText As %String) As %DynamicObject [ Private ]
{
    Set tObject = {}
    Try {
        If pText = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pText)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicObject") Set tObject = tParsed
    } Catch {
        Set tObject = {}
    }
    Quit tObject
}

/// <p><var>pText</var> parsed as a JSON array, or <code>[]</code> when it is empty or unreadable.
/// An empty one names no changed field, which leaves the verdict to the fingerprint gate behind the
/// set: it refuses any row whose stored payload does not digest to the row's own fingerprint.</p>
ClassMethod ParsedArray(pText As %String) As %DynamicArray [ Private ]
{
    Set tArray = []
    Try {
        If pText = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pText)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicArray") Set tArray = tParsed
    } Catch {
        Set tArray = []
    }
    Quit tArray
}

/// <p>Record the refusal <var>pCode</var> for the caller. A refusal is a successful answer to the
/// question, never an error status: the confirm renders it 403.</p>
ClassMethod Refuse(pCode As %String, Output pProhibits As %Boolean, Output pOutCode As %String) [ Private ]
{
    Set pProhibits = 1
    Set pOutCode = pCode
}

}
