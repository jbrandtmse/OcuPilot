/// <p>The privilege gate (AD-8). A requirement is a <b>set</b> of
/// <code>(resource, permission)</code> pairs, <b>all</b> of which are required; each is checked
/// with <code>$System.Security.Check</code> in the calling process at the moment of the call
/// (the <method>OcuPilot.Api.Router.HoldsAdminResource</method> idiom); nothing is cached,
/// there is no service account and no <code>$ROLES</code> is inspected. A denial names the
/// pair that failed, as <code>resource:permission</code>, so the UX can say which privilege is
/// missing.</p>
/// <p><b>The classic page's custom resource is unioned on</b> (AD-44). An operator who has
/// assigned a resource to the classic page a screen replaces has an expectation OcuPilot
/// honours, so a descriptor's declared set plus that resource at <code>USE</code> is what the
/// screen requires. <code>USE</code> is the permission the portal itself checks
/// (<file>irissys/%ZEN/Controller.cls</file>, read directly: it gates the page's own
/// <code>RESOURCE</code> first and then <code>$System.Security.Check(tCustom, "USE")</code>),
/// and the store is keyed by the <b>normalized class name</b>, not by a URL --
/// <class>%SYS.Portal.Resources</class>' IdKey is <code>Page</code> and
/// <code>NormalizePage</code> exists to turn a link into one. That normalization strips a query
/// and a fragment, percent-decodes once, drops <code>.cls</code>/<code>.zen</code> and turns a
/// leading <code>_</code> into <code>%</code>, but does <b>not</b> case-fold a class -- so a
/// descriptor that mis-cases its classic page silently resolves to no custom resource.</p>
/// <p><b>No namespace switch.</b> <class>%CSP.Portal.Utils</class> is <code>%</code>-mapped and
/// the read carries no privilege guard of its own; verified live from <code>HSCUSTOM</code>
/// 2026-09-12, where the store holds no rows and the lookup answers <code>""</code>. The write
/// path is guarded and is not something OcuPilot ever takes.</p>
Class OcuPilot.Screen.Gate Extends %RegisteredObject
{

/// <p>The permission a classic page's custom resource is required at.</p>
Parameter CLASSICPERMISSION = "USE";

/// <p>The closed list of IRIS administrative resources, comma-separated. Holding <b>any one</b>
/// of them at <parameter>ADMINPERMISSION</parameter> is the instance-level floor: what
/// <method>OcuPilot.Api.Router.HoldsAdminResource</method> requires of a caller before any route
/// runs, and what <method>OcuPilot.Port.ProviderPort.Invoke</method> requires before an outbound
/// provider request leaves (AD-8, AD-29).</p>
/// <p>Read from the instance on 2026-09-11 (<code>Security.Resources:List</code> over
/// <code>%Admin*</code>) -- all thirteen it defines. A closed list, not a wildcard scan: what
/// OcuPilot admits must not silently widen because a later IRIS release adds a resource, and a
/// list is what a reviewer can check.</p>
/// <p><b>This is the list's one home.</b> The router and the provider port derive their own
/// parameters from it at compile time rather than restating it, so the floor a request meets and
/// the floor a provider call meets cannot come apart.</p>
Parameter ADMINRESOURCES = "%Admin_ExternalLanguageServerEdit,%Admin_FileSystemAccess,%Admin_Journal,%Admin_Manage,%Admin_OAuth2_Client,%Admin_OAuth2_Registration,%Admin_OAuth2_Server,%Admin_Operate,%Admin_RoleEdit,%Admin_Secure,%Admin_Task,%Admin_UserEdit,%Admin_Wallet";

/// <p>The permission each <parameter>ADMINRESOURCES</parameter> member is required at.</p>
Parameter ADMINPERMISSION = "USE";

/// <p>The user names that are not an authenticated principal, comma-separated: IRIS's
/// unauthenticated placeholder and its public one.</p>
Parameter ANONYMOUSPRINCIPALS = "UnknownUser,_PUBLIC";

/// <p>Whether <var>pUser</var> is an authenticated principal (AD-21: <i>anonymous does not mean
/// unprivileged</i>).</p>
/// <p>On a Minimal-security instance <code>%Service_CSP</code>'s default user
/// <code>UnknownUser</code> holds <code>%All</code>, so a check that asked only what roles the
/// caller has would let an anonymous browser through with every privilege there is. The
/// placeholders are therefore rejected by name, before any privilege question is asked.</p>
/// <p><b>One home for the list.</b> The router's identity gate and
/// <class>OcuPilot.Port.ProviderPort</class>'s both call this, so the two cannot come to disagree
/// about what counts as anonymous -- which is what would happen with the literals spelled at each
/// gate, as they were at the router's until this method existed.</p>
ClassMethod IsAuthenticatedPrincipal(pUser As %String) As %Boolean
{
    If pUser = "" Quit 0
    Quit '$ListFind($ListFromString(..#ANONYMOUSPRINCIPALS), pUser)
}

/// <p>Whether the calling process may reach <var>pTarget</var> -- either an area key
/// <class>OcuPilot.Screen.Area</class> declares, or the class name of a screen descriptor.
/// <var>pFailedPair</var> is the first pair that failed, spelled
/// <code>resource:permission</code>, and <code>""</code> when the answer is yes.</p>
/// <p>The two kinds are told apart by asking the area vocabulary first: an area key is a
/// declared value and a descriptor is a class name, so nothing that is not a declared area is
/// ever treated as one. A target that resolves to neither is refused with no pair named --
/// there is no requirement to report, and admitting it would be a gate that opens on a typo.</p>
ClassMethod Evaluate(pTarget As %String, Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    Set tAllowed = 0
    Try {
        If ##class(OcuPilot.Screen.Area).Exists(pTarget) {
            Set tAllowed = ..EvaluatePairs(##class(OcuPilot.Screen.Area).PrivilegePairs(pTarget), .pFailedPair)
            Quit
        }
        If '##class(%Dictionary.CompiledClass).%ExistsId(pTarget) Quit
        Set tPairs = ..RequiredPairs(pTarget, .tResolved)
        ; A requirement that could not be read is not an empty requirement. Without this the
        ; Catch below would hand back "", which EvaluatePairs holds to be satisfied by everyone.
        If 'tResolved Quit
        Set tAllowed = ..EvaluatePairs(tPairs, .pFailedPair)
    } Catch {
        Set tAllowed = 0
        Set pFailedPair = ""
    }
    Quit tAllowed
}

/// <p>What descriptor class <var>pDescriptor</var> requires: its declared pair set unioned with
/// the custom resource assigned to the classic page it replaces, at
/// <parameter>CLASSICPERMISSION</parameter>. An unassigned page reads <code>""</code> and adds
/// nothing.</p>
/// <p><var>pResolved</var> is 1 only when the requirement was actually read. An empty list means
/// "requires nothing", which every caller holds, so a caller cannot tell that apart from a
/// failure unless the failure says so: a target that is not a descriptor, or one whose
/// declaration will not parse, answers an empty list with <var>pResolved</var> 0 and must be
/// refused rather than admitted.</p>
ClassMethod RequiredPairs(pDescriptor As %String, Output pResolved As %Boolean) As %List
{
    Set tPairs = ""
    Set pResolved = 0
    Try {
        Set tDeclSC = $ClassMethod(pDescriptor, "DeclarationJson", .tDeclaration)
        If $$$ISERR(tDeclSC) Quit
        Set tPairs = $ClassMethod(pDescriptor, "PrivilegePairs")
        Set tCustom = ..ClassicResource($ClassMethod(pDescriptor, "ClassicPage"))
        If tCustom '= "" Set tPairs = tPairs _ $ListBuild($ListBuild(tCustom, ..#CLASSICPERMISSION))
        Set pResolved = 1
    } Catch {
        Set tPairs = ""
        Set pResolved = 0
    }
    Quit tPairs
}

/// <p>Whether the <b>declared</b> requirement <var>pPairs</var> is met. An empty set is held by
/// everyone, because a declared-empty set is how a screen that never gates is expressed --
/// <class>OcuPilot.Screen.Descriptor.Home</class> declares <code>"privileges": []</code>
/// deliberately, and refusing it would lock every account out of Home.</p>
/// <p><b>This is not the question "has a requirement been named at all".</b> A caller holding a
/// set it did not declare -- a stored row's recorded requirement, a port's
/// <code>Parameter</code> -- must never read an empty set as satisfied, and asks
/// <method>EvaluateRequired</method> instead (DW-1120).</p>
ClassMethod EvaluatePairs(pPairs As %List, Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    Set tAllowed = 1
    Try {
        For tI = 1:1:$ListLength(pPairs) {
            Set tPair = $List(pPairs, tI)
            Set tResource = $List(tPair, 1)
            Set tPermission = $List(tPair, 2)
            If '..HoldsPrivilege(tResource, tPermission) {
                Set tAllowed = 0
                Set pFailedPair = tResource _ ":" _ tPermission
                Quit
            }
        }
    } Catch {
        Set tAllowed = 0
        Set pFailedPair = ""
    }
    Quit tAllowed
}

/// <p>Whether the calling process holds every pair in <var>pPairs</var>, where an <b>empty
/// requirement is never held</b> (DW-1120). <var>pFailedPair</var> is the first pair that failed,
/// and <code>""</code> both when the answer is yes and when there was no pair to name.</p>
/// <p><b>The two entry points answer two different questions</b> and that is why there are two.
/// <method>EvaluatePairs</method> asks whether a screen's declared requirement is met, and a
/// screen may declare none. This one asks whether a requirement was named and is held, which is
/// what a ledger row's recorded pair set and a port's declared <code>Parameter</code> need: a set
/// that resolved to nothing records a check nobody made, so releasing on it would release on a
/// requirement nobody named.</p>
ClassMethod EvaluateRequired(pPairs As %List, Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    If '$ListValid(pPairs) || ($ListLength(pPairs) = 0) Quit 0
    Quit ..EvaluatePairs(pPairs, .pFailedPair)
}

/// <p>Whether the calling process holds <b>any one</b> pair in <var>pPairs</var> -- an OR-set,
/// where <method>EvaluateRequired</method> is an AND-set. An empty or unreadable set is never
/// held, for the same reason.</p>
/// <p><var>pFailedPair</var> is <code>""</code> when the answer is yes; when it is no, it is the
/// <b>first</b> pair of the set, which is the one the caller would have to be granted. No single
/// pair failed the caller here -- all of them did -- so naming the last one tried would name an
/// arbitrary member of the list.</p>
ClassMethod EvaluateAnyOf(pPairs As %List, Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    If '$ListValid(pPairs) || ($ListLength(pPairs) = 0) Quit 0
    Set tAllowed = 0
    Try {
        For tI = 1:1:$ListLength(pPairs) {
            Set tPair = $List(pPairs, tI)
            If '$ListValid(tPair) || ($ListLength(tPair) '= 2) Continue
            If ..HoldsPrivilege($List(tPair, 1), $List(tPair, 2)) {
                Set tAllowed = 1
                Quit
            }
        }
        If 'tAllowed {
            Set tFirst = $List(pPairs, 1)
            If $ListValid(tFirst) && ($ListLength(tFirst) = 2) Set pFailedPair = $List(tFirst, 1) _ ":" _ $List(tFirst, 2)
        }
    } Catch {
        Set tAllowed = 0
        Set pFailedPair = ""
    }
    Quit tAllowed
}

/// <p><parameter>ADMINRESOURCES</parameter> spelled as the comma-separated
/// <code>resource:permission</code> specification every declared pair set in this tree uses, each
/// member at <parameter>ADMINPERMISSION</parameter>.</p>
/// <p>Read at <b>compile</b> time by the two classes that declare the administrative floor as a
/// parameter of their own, so neither holds a copy of the list.</p>
ClassMethod AdminPairSpec() As %String
{
    Set tSpec = ""
    For tI = 1:1:$Length(..#ADMINRESOURCES, ",") {
        Set tResource = $Piece(..#ADMINRESOURCES, ",", tI)
        If tResource = "" Continue
        Set tSpec = tSpec _ $Select(tSpec = "": "", 1: ",") _ tResource _ ":" _ ..#ADMINPERMISSION
    }
    Quit tSpec
}

/// <p><var>pSpec</var>, a comma-separated list of <code>resource:permission</code>, as the
/// <code>%List</code> of two-element <code>%List</code>s this gate's evaluators take.</p>
/// <p><b>A member without both halves voids the whole specification</b>, which
/// <method>EvaluateRequired</method> then refuses. Dropping only the unreadable member would
/// leave an <code>AND</code> gate evaluating fewer pairs than its <code>Parameter</code>
/// declares -- a port measurably weaker than the declaration a reader checks it against -- and
/// a shorter list is exactly what such a gate cannot notice. An empty member, from a trailing
/// separator, is skipped rather than treated as malformed; an empty specification parses to an
/// empty list, which the evaluator already refuses.</p>
ClassMethod ParsePairSpec(pSpec As %String) As %List
{
    Set tPairs = ""
    For tI = 1:1:$Length(pSpec, ",") {
        Set tMember = $Piece(pSpec, ",", tI)
        If tMember = "" Continue
        Set tResource = $Piece(tMember, ":", 1)
        Set tPermission = $Piece(tMember, ":", 2)
        If (tResource = "") || (tPermission = "") Quit
        Set tPairs = tPairs _ $ListBuild($ListBuild(tResource, tPermission))
    }
    If $Length(pSpec, ",") > 0, tPairs '= "" {
        ; The loop stops on the first malformed member; a short answer therefore means "the rest
        ; was never read", which must not be handed to an evaluator as a requirement.
        Set tDeclared = 0
        For tI = 1:1:$Length(pSpec, ",") {
            If $Piece(pSpec, ",", tI) '= "" Set tDeclared = tDeclared + 1
        }
        If $ListLength(tPairs) '= tDeclared Set tPairs = ""
    }
    Quit tPairs
}

/// <p>Whether the calling process holds one pair. The single point at which this gate consults
/// the instance: <code>$System.Security.Check</code>, evaluated in the calling process at the
/// moment of the call and never cached, with no service account and no
/// <code>$ROLES</code> inspection (AD-8). It is a <code>%SYSTEM</code> call and needs no
/// namespace switch.</p>
/// <p><b>Overridable</b> so the set semantics -- every pair required, the first failure named,
/// the classic union -- can be driven in process against a declared answer. They cannot be
/// driven against the real check, because <code>%UnitTest</code> runs as an account holding
/// <code>%All</code>, for which the real check answers yes to every resource name including
/// one the instance does not define. The real check is exercised over the wire by
/// <class>OcuPilot.Test.Wire</class>, as a throwaway principal holding exactly one
/// administrative resource. Production never overrides it.</p>
ClassMethod HoldsPrivilege(pResource As %String, pPermission As %String) As %Boolean
{
    Quit $System.Security.Check(pResource, pPermission)
}

/// <p>The custom resource an operator has assigned to the classic page <var>pPageClass</var>,
/// or <code>""</code>. The class name is URL-encoded on the way in, which is the form
/// <class>%SYS.Portal.Resources</class> documents and the portal itself passes.</p>
/// <p><b>Overridable</b> so the union can be exercised against a fixture value: no custom
/// resource is ever written to <class>%SYS.Portal.Resources</class> by this project's tests,
/// whose store is empty on the development instance and stays so. Production never overrides
/// it.</p>
ClassMethod ClassicResource(pPageClass As %String) As %String
{
    If pPageClass = "" Quit ""
    Quit ##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(pPageClass, "O", "URL"))
}

}
