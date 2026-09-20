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
/// <p><b>The two fields whose every change is prohibited are absent from the tool set as well</b>
/// (<method>AlwaysProhibitedFields</method>), and so is every field outside the reviewed few: a
/// write tool advertises the reviewed names and nothing else, so the model cannot author the rest,
/// and this class refuses them at the write so no other route can either.</p>
/// <p>Seams a subclass overrides: <method>PortClass</method> and <method>RegistryClass</method>.
/// Production overrides neither.</p>
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

/// <p>The write would change the roles the target grants, which is a privilege grant through a
/// path (AD-10).</p>
Parameter PRIVILEGEGRANT = "PROHIBITED.PRIVILEGEGRANT";

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
Parameter COVEREDTYPES = "web-application";

/// <p>The one covered type, named once so the dispatch and the list cannot drift apart.</p>
Parameter TYPEWEBAPPLICATION = "web-application";

/// <p>The <code>AutheEnabled</code> bit that lets an application be reached without signing in, and
/// the only bit <method>ClearsUnauthenticatedOnly</method> permits a payload to change
/// (<file>irissys/%sySecurityMacros.inc</file>:19-20 gives AuthePassword 32 and
/// AutheUnauthenticated 64).</p>
Parameter UNAUTHENTICATEDBIT As %Integer = 64;

/// <p>The admin request type the target is re-read with (AD-36's single-object <code>GET</code>),
/// the same one the fingerprint re-read uses.</p>
Parameter READTYPE = "GET";

/// <p>Every <code>PROHIBITED.*</code> code this class declares, as a <class>%List</class>, in the
/// order the predicates are evaluated (<method>WebApplication</method>), with the wholesale refusal
/// last.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#SERVINGPATH, ..#UNAUTHENTICATED, ..#AUTHORIZATION, ..#DISPATCH, ..#PRIVILEGEGRANT, ..#UNCOVEREDFIELD, ..#UNCOVERED)
}

/// <p>The written sentence a <code>PROHIBITED.*</code> code carries, or <code>""</code> for any
/// other code (AD-39). <method>OcuPilot.Kernel.Proposal.Write.ReasonFor</method> delegates the
/// family here, so the set still has one home.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#UNAUTHENTICATED Quit "The only change to how a web application is authenticated that the agent can propose is removing the option of reaching it without signing in."
    If pCode = ..#AUTHORIZATION Quit "Removing the resource that guards a web application is not something the agent can propose."
    If pCode = ..#DISPATCH Quit "Changing which code answers at a web application's address is not something the agent can propose."
    If pCode = ..#PRIVILEGEGRANT Quit "Changing the roles a web application grants is not something the agent can propose."
    If pCode = ..#SERVINGPATH Quit "Changing a web application that serves OcuPilot itself is not something the agent can propose."
    If pCode = ..#UNCOVEREDFIELD Quit "Only a few of a web application's settings are ones the agent may propose changing, and that is not one of them."
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
/// <p>A write tool advertises no field outside this list, which is the other half of AD-10; the
/// tool states its own admitted names and a test asserts the two agree, so the tool layer never
/// reads the kernel.</p>
ClassMethod PermittedChangeFields(pType As %String) As %List
{
    If pType = ..#TYPEWEBAPPLICATION Quit $ListBuild("AutheEnabled", "Description", "Enabled", "Resource")
    Quit ""
}

/// <p>The payload field names of entity type <var>pType</var> whose <b>every</b> change is
/// prohibited by a named predicate, as a <class>%List</class>; <code>""</code> for a type with
/// none.</p>
/// <p>They are a subset of the fields outside <method>PermittedChangeFields</method> -- the two
/// DW-1207 names whose refusal carries a sentence of its own rather than the reviewed-few one, so
/// the user is told which effect was refused.</p>
ClassMethod AlwaysProhibitedFields(pType As %String) As %List
{
    If pType = ..#TYPEWEBAPPLICATION Quit $ListBuild("MatchRoles", "DispatchClass")
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
        If tType '= ..#TYPEWEBAPPLICATION {
            ; A type COVEREDTYPES lists and no branch evaluates. Fail closed rather than write.
            Do ..Refuse(..#UNCOVERED, .pProhibits, .pCode)
            Quit
        }

        ; AD-9: the escalated state read runs to completion before the port is entered. Its frame
        ; has unwound by the time Target() calls the port, so the two are never nested.
        Set tSC = ..ServesOcuPilot(tId, .tServes)
        If $$$ISERR(tSC) Quit

        Set tSC = ..Target(pToolName, tId, .tTarget, .tPresent)
        If $$$ISERR(tSC) Quit
        ; A target the instance no longer holds is not prohibited: the fingerprint re-read refuses
        ; it TARGETCHANGED a few lines later and closes the row, which is the answer the user sees.
        If 'tPresent Quit

        Set tPayloadObject = ..ParsedObject(pPayload)
        Set tSC = ..Changed(pDiff, tPayloadObject, tTarget, .tChanged)
        If $$$ISERR(tSC) Quit

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
