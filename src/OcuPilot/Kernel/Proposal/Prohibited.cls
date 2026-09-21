/// <p>AD-10's prohibited set, and its one home. What Release 1 refuses is declared here, as
/// predicates evaluated against the <b>resolved target as the instance holds it now</b>, and is
/// reached only through <method>OcuPilot.Kernel.Proposal.Write.ProhibitedClass</method>.</p>
/// <p><b>Effect, not verb.</b> A predicate answers "what would this write do", never "what did the
/// caller ask for". Two things decide that together: the stored diff, which is the only record of
/// what the proposal changes relative to the target it was minted against, and a fresh read of the
/// target, which is what makes the answer an effect. A field one of them names and the other does
/// not changes nothing the agent proposed, so the set is silent and the gates behind it answer.</p>
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
/// <p><b>Three types are covered</b> (<parameter>COVEREDTYPES</parameter>): a web application,
/// whose predicates are <method>WebApplication</method>'s, a user account, whose predicates are
/// <method>User</method>'s, and the instance's auditing configuration, whose predicate is
/// <method>Auditing</method>'s -- the reviewed-few sweep alone, because AD-10 forbids no change to
/// it. Each later write-tool story adds its own type here, and a type listed with no branch is
/// refused <parameter>UNCOVERED</parameter> at every write.</p>
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

/// <p>The write would disable the only account on this instance that holds <code>%All</code>.</p>
Parameter LASTALLHOLDER = "PROHIBITED.LASTALLHOLDER";

/// <p>The write would disable <code>_SYSTEM</code>, the instance's own predefined account.</p>
Parameter SYSTEMACCOUNT = "PROHIBITED.SYSTEMACCOUNT";

/// <p>The write would change a setting of a covered type that this release has not reviewed. It is
/// the shape that covers a vendor property nobody has classified yet, rather than the names that
/// happen to exist on this build.</p>
Parameter UNCOVEREDFIELD = "PROHIBITED.UNCOVEREDFIELD";

/// <p>The target's entity type is one this release evaluates no predicates for, or its reference
/// could not be read at all. Refusing wholesale is strictly stronger than the enumerated effects,
/// and it is what keeps a later story's write tool from shipping without its predicates.</p>
Parameter UNCOVERED = "PROHIBITED.UNCOVERED";

/// <p>The entity types this release evaluates predicates for, comma-separated
/// (<class>OcuPilot.Kernel.EntityType</class>'s spelling). A type outside this list is
/// <parameter>UNCOVERED</parameter>.</p>
Parameter COVEREDTYPES = "web-application,user,auditing-configuration";

/// <p>The covered types, each named once so the dispatch and the list cannot drift apart.</p>
Parameter TYPEWEBAPPLICATION = "web-application";

Parameter TYPEUSER = "user";

Parameter TYPEAUDITING = "auditing-configuration";

/// <p>The instance's own predefined account, whose disablement AD-10 forbids. Compared through
/// <method>NormalizedUser</method>, so every spelling the instance resolves to it is refused.</p>
Parameter SYSTEMACCOUNTNAME = "_SYSTEM";

/// <p>The role that holds every privilege, and the prefix of every role that holds an
/// administrative one. Adding either to an account is a privilege grant (AD-10).</p>
Parameter ALLROLE = "%All";

Parameter ADMINROLEPREFIX = "%Admin_";

/// <p>The three <code>Security.User</code> payload fields the user predicates read, named once.</p>
Parameter FIELDENABLED = "Enabled";

Parameter FIELDROLES = "Roles";

Parameter FIELDESCALATIONROLES = "EscalationRoles";

/// <p>The <code>AutheEnabled</code> bit that lets an application be reached without signing in, and
/// the only bit <method>ClearsUnauthenticatedOnly</method> permits a payload to change
/// (<file>irissys/%sySecurityMacros.inc</file>:19-20 gives AuthePassword 32 and
/// AutheUnauthenticated 64).</p>
Parameter UNAUTHENTICATEDBIT As %Integer = 64;

/// <p>The admin request type the target is re-read with (AD-36's single-object <code>GET</code>),
/// the same one the fingerprint re-read uses.</p>
Parameter READTYPE = "GET";

/// <p>Every <code>PROHIBITED.*</code> code this class declares, as a <class>%List</class>: the
/// web-application predicates in the order <method>WebApplication</method> evaluates them, then the
/// three <method>User</method> adds, then the two both types share, with the wholesale refusal
/// last.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#SERVINGPATH, ..#UNAUTHENTICATED, ..#AUTHORIZATION, ..#DISPATCH, ..#SYSTEMACCOUNT, ..#CURRENTUSER, ..#LASTALLHOLDER, ..#PRIVILEGEGRANT, ..#UNCOVEREDFIELD, ..#UNCOVERED)
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
    If pCode = ..#CURRENTUSER Quit "Disabling the account you are signed in as is not something the agent can propose."
    If pCode = ..#LASTALLHOLDER Quit "Disabling the only account on this instance that holds %All is not something the agent can propose."
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

/// <p>The port the target is read through. Overridable so a fixture can answer a known object;
/// production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
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
        If (tType '= ..#TYPEWEBAPPLICATION) && (tType '= ..#TYPEUSER) && (tType '= ..#TYPEAUDITING) {
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

        Set tSC = ..Target(pToolName, tId, .tTarget, .tPresent)
        If $$$ISERR(tSC) Quit
        ; A target the instance no longer holds is not prohibited: the fingerprint re-read refuses
        ; it TARGETCHANGED a few lines later and closes the row, which is the answer the user sees.
        If 'tPresent Quit

        Set tPayloadObject = ..ParsedObject(pPayload)
        Set tSC = ..Changed(pDiff, tPayloadObject, tTarget, .tChanged)
        If $$$ISERR(tSC) Quit

        If tType = ..#TYPEUSER {
            Set tSC = ..User(tId, tPayloadObject, tTarget, .tChanged, .pProhibits, .pCode)
            Quit
        }
        If tType = ..#TYPEAUDITING {
            Set tSC = ..Auditing(.tChanged, .pProhibits, .pCode)
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
/// <p><b>The three disable refusals are scoped to a disable, by effect.</b> AD-10 forbids deleting
/// or disabling those three accounts, so enabling one, or renaming its full name, is not this
/// predicate's business -- and <method>PermittedChangeFields</method> is what refuses every field
/// beyond the reviewed two in the first place.</p>
ClassMethod User(pId As %String, pPayload As %DynamicObject, pTarget As %DynamicObject, ByRef pChanged, Output pProhibits As %Boolean, Output pCode As %String) As %Status [ Private ]
{
    Set pProhibits = 0
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        If $Data(pChanged(..#FIELDENABLED)) && ..IsOff(..Rendered(pPayload, ..#FIELDENABLED)) {
            Set tCanonical = ..NormalizedUser(pId)
            If tCanonical = ..NormalizedUser(..#SYSTEMACCOUNTNAME) {
                Do ..Refuse(..#SYSTEMACCOUNT, .pProhibits, .pCode)
                Quit
            }
            If tCanonical = ..NormalizedUser($Username) {
                Do ..Refuse(..#CURRENTUSER, .pProhibits, .pCode)
                Quit
            }
            Set tSC = ..LastAllHolder(pId, .tLast)
            If $$$ISERR(tSC) Quit
            If tLast {
                Do ..Refuse(..#LASTALLHOLDER, .pProhibits, .pCode)
                Quit
            }
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
/// keeps a vendor property a later IRIS build adds to this endpoint's template out of a payload
/// until somebody reviews it.</p>
/// <p><b>Turning auditing off is not prohibited, and that is the decision rather than an
/// omission</b>: the product answers it with the card's warning, the recorded drop of the marker
/// and the panel banner (AD-15 as amended 2026-09-21). Refusing it would mean an operator could
/// not do through OcuPilot what the classic portal lets them do in two clicks, while leaving the
/// window unrecorded either way.</p>
ClassMethod Auditing(ByRef pChanged, Output pProhibits As %Boolean, Output pCode As %String) As %Status [ Private ]
{
    Set pProhibits = 0
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        Set tPermitted = ..PermittedChangeFields(..#TYPEAUDITING)
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
ClassMethod CountsAsHolder(pName As %String, pEnabled As %String) As %Boolean
{
    If $ZStrip(pName, "<>W") = "" Quit 0
    If '##class(OcuPilot.Screen.Gate).IsAuthenticatedPrincipal(pName) Quit 0
    If $ZConvert(pEnabled, "U") = "YES" Quit 1
    Quit (pEnabled = 1)
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
ClassMethod Changed(pDiff As %String, pPayload As %DynamicObject, pTarget As %DynamicObject, Output pChanged) As %Status [ Private ]
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
/// <var>pTarget</var>, with <var>pPresent</var> 0 for a target the instance no longer holds.</p>
/// <p>The endpoint and the identifying parameter come from the tool the proposal names, through
/// the registry, so this class names no endpoint of its own. A 404 is absence; any other refusal,
/// and a success that carried no object, are error statuses, because a target that could not be
/// read is not a target that was checked.</p>
ClassMethod Target(pToolName As %String, pId As %String, Output pTarget As %DynamicObject, Output pPresent As %Boolean) As %Status [ Private ]
{
    Set pTarget = ""
    Set pPresent = 0
    Set tSC = $$$OK
    Try {
        Set tSC = $ClassMethod(..RegistryClass(), "Resolve", pToolName, .tTool)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tTool) {
            Set tSC = $$$ERROR($$$GeneralError, "the prohibited set was asked about a tool this instance does not carry: '" _ pToolName _ "'")
            Quit
        }
        Set tClass = tTool.%Get("class")
        Set tEndpoint = $ClassMethod(tClass, "Endpoint")
        Set tIdParam = $ClassMethod(tClass, "IdParam")
        If (tEndpoint = "") || (tIdParam = "") || (pId = "") {
            Set tSC = $$$ERROR($$$GeneralError, "the prohibited set could not address the target of '" _ pToolName _ "'")
            Quit
        }
        Kill tQuery
        Set tQuery(tIdParam) = pId
        Set tReadSC = $ClassMethod(..PortClass(), "Invoke", tEndpoint, ..#READTYPE, .tQuery, "", .tFresh, .tHttp, .tFault)
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
        Set tSC = ex.AsStatus()
    }
    Quit tSC
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
