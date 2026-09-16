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

/// <p>Whether every pair in <var>pPairs</var> is held. An empty set is held by everyone, which
/// is how an area or a screen that never gates is expressed.</p>
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
