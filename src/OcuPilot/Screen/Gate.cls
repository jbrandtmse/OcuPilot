/// <p>The privilege gate (AD-8). A screen's requirement is a <b>set</b> of
/// <code>(resource, permission)</code> pairs, <b>all</b> of which are required, and an area opens on
/// its listed entries' answers (<method>EvaluateArea</method>); each pair is checked
/// with <code>$System.Security.Check</code> in the calling process at the moment of the call
/// (the <method>OcuPilot.Api.Router.HoldsAdminResource</method> idiom); nothing is cached,
/// there is no service account and no <code>$ROLES</code> is inspected. A denial names the
/// pair that failed, as <code>resource:permission</code>, so the UX can say which privilege is
/// missing.</p>
/// <p><b>The classic page's custom resource is unioned on</b> (AD-44). An operator who has
/// assigned a resource to the classic page a screen replaces has an expectation OcuPilot
/// honours, so a descriptor's base set plus that resource at <code>USE</code> is what the
/// screen requires. The base set is the descriptor's declared set, or the set an operator adjusted the
/// screen to (AD-64, <method>RequiredPairs</method>). <code>USE</code> is the permission the portal itself checks
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

/// <p>The separator of an either-of pair's resources (AD-64): a pair whose resource is
/// <code>a|b</code> is held when the caller holds the permission on <b>any one</b> of them. Only
/// <method>AdjusterPairs</method> builds one; every other pair is a single resource.</p>
Parameter ALTERNATIVESEPARATOR = "|";

/// <p>The resources whose holder may view and adjust screen permissions (AD-64 item 4): either one,
/// at <parameter>CLASSICPERMISSION</parameter>.</p>
Parameter ADJUSTERRESOURCES = "%Development,%Admin_Secure";

/// <p>The closed list of IRIS administrative resources, comma-separated. Holding <b>any one</b>
/// of them, <parameter>DEVELOPMENTRESOURCE</parameter> or <parameter>INTEROPRESOURCE</parameter>, at
/// <parameter>ADMINPERMISSION</parameter> is the instance-level floor (<method>FloorResources</method>): what
/// <method>OcuPilot.Api.Router.HoldsAdminResource</method> requires of a caller before any route
/// runs, what <method>OcuPilot.Port.ProviderPort.Invoke</method> requires before an outbound
/// provider request leaves, and what a turn's step boundary requires of its owner (AD-8, AD-29,
/// AD-31).</p>
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

/// <p>The floor member that admits a developer account: the classic portal admits a
/// <code>%Developer</code> account to System Explorer, whose Classes, Routines, Globals and SQL
/// pages declare it as their <code>RESOURCE</code> (AD-8). It never joins
/// <parameter>ADMINRESOURCES</parameter>, whose members are <code>%Admin_*</code> alone.</p>
Parameter DEVELOPMENTRESOURCE = "%Development";

/// <p>The floor member that admits an Interoperability account: the classic Interoperability
/// pages check <code>%Ens_Portal</code> (<code>EnsPortal.Application.CheckPrivileges</code>), and
/// the stock <code>%EnsRole_Operator</code>, <code>_Monitor</code> and <code>_Administrator</code>
/// hold it. It never joins <parameter>ADMINRESOURCES</parameter>. Clearing the floor opens only
/// the surfaces whose own pairs the caller holds and those that declare none, which are
/// owner-scoped or have no classic resource (<class>OcuPilot.Test.InteropFloorOwnPairs</class>).</p>
Parameter INTEROPRESOURCE = "%Ens_Portal";

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
/// <class>OcuPilot.Screen.Area</class> declares, answered by <method>EvaluateArea</method>, or the
/// class name of a screen descriptor. <var>pFailedPair</var> is the first pair that failed, spelled
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
            Set tAllowed = ..EvaluateArea(pTarget, .pFailedPair)
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

/// <p>Whether the calling process may open the area <var>pAreaKey</var>: its rail item, Home tile
/// and side bar (AD-8). A key the area vocabulary does not declare is refused, naming nothing. An
/// area that declares no pair never gates (Home, Agent co-pilot). Any other area opens when at
/// least one entry its side bar lists (<method>ListedScreens</method>) opens
/// (<method>EvaluateEntry</method>): the screen passes its own gate, the classic page's custom
/// resource included, or it heads a tab group one of whose tabs passes its own. Each screen keeps
/// its own gate, so the answer admits no read that screen's gate refuses.</p>
/// <p>When none of them does, <var>pFailedPair</var> is the first pair of the area's declared set the
/// caller lacks, or, when the caller holds that whole set, the first failed pair a listed screen
/// names. <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method> holds that set to every pair
/// the area's screens declare but their own, so holding it opens every screen that declares no own
/// pair and whose classic page carries no custom resource. An area that lists no screen is answered by its declared set alone, as its tile expects;
/// a roster that cannot be read refuses, naming nothing.</p>
ClassMethod EvaluateArea(pAreaKey As %String, Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    Set tAllowed = 0
    Try {
        If '##class(OcuPilot.Screen.Area).Exists(pAreaKey) Quit
        Set tAreaPairs = ##class(OcuPilot.Screen.Area).PrivilegePairs(pAreaKey)
        If tAreaPairs = "" {
            Set tAllowed = 1
            Quit
        }
        Set tSC = ..ListedScreens(pAreaKey, .tScreens)
        If $$$ISERR(tSC) Quit
        If $ListLength(tScreens) = 0 {
            Set tAllowed = ..EvaluatePairs(tAreaPairs, .pFailedPair)
            Quit
        }
        Set tScreenPair = ""
        For tI = 1:1:$ListLength(tScreens) {
            Set tFailed = ""
            If ..EvaluateEntry($List(tScreens, tI), .tFailed) {
                Set tAllowed = 1
                Quit
            }
            If tScreenPair = "" Set tScreenPair = tFailed
        }
        If tAllowed Quit
        Set tAreaPair = ""
        If ..EvaluatePairs(tAreaPairs, .tAreaPair) Set tAreaPair = tScreenPair
        Set pFailedPair = tAreaPair
    } Catch {
        Set tAllowed = 0
        Set pFailedPair = ""
    }
    Quit tAllowed
}

/// <p>Whether the calling process may open the side-bar entry <var>pDescriptor</var>: the screen
/// passes its own gate (<method>Evaluate</method>), or it heads a tab group (AD-5) and another tab
/// of that group (<method>TabMembers</method>) passes its own. <var>pFailedPair</var> is the listed
/// screen's own failed pair, and <code>""</code> when the answer is yes. The entry opens on a tab
/// only through that tab's gate, so the answer admits no read a tab's gate refuses; a group whose
/// tabs cannot be read refuses.</p>
ClassMethod EvaluateEntry(pDescriptor As %String, Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    If ..Evaluate(pDescriptor, .pFailedPair) Quit 1
    Set tAllowed = 0
    Try {
        Set tSC = ..TabMembers(pDescriptor, .tMembers)
        If $$$ISERR(tSC) Quit
        For tI = 1:1:$ListLength(tMembers) {
            Set tMemberFailed = ""
            If ..Evaluate($List(tMembers, tI), .tMemberFailed) {
                Set tAllowed = 1
                Quit
            }
        }
    } Catch {
        Set tAllowed = 0
    }
    If tAllowed Set pFailedPair = ""
    Quit tAllowed
}

/// <p>The other tabs of the tab group <var>pDescriptor</var> heads, in strip order
/// (<method>OcuPilot.Screen.Registry.TabMembersFor</method>), which <method>EvaluateEntry</method>
/// reads.</p>
/// <p><b>Overridable</b> for the reason <method>ListedScreens</method> is. Production never
/// overrides it.</p>
ClassMethod TabMembers(pDescriptor As %String, Output pList As %List) As %Status
{
    Quit ##class(OcuPilot.Screen.Registry).TabMembersFor(pDescriptor, .pList)
}

/// <p>The descriptor classes <var>pAreaKey</var>'s side bar lists, in side-bar order
/// (<method>OcuPilot.Screen.Registry.ListedScreensForArea</method>), which
/// <method>EvaluateArea</method> reads.</p>
/// <p><b>Overridable</b> so a test can arrange a roster the shipped descriptors do not form -- one
/// whose first screen needs a pair its area does not name, or none at all. Production never
/// overrides it.</p>
ClassMethod ListedScreens(pAreaKey As %String, Output pList As %List) As %Status
{
    Quit ##class(OcuPilot.Screen.Registry).ListedScreensForArea(pAreaKey, .pList)
}

/// <p>What descriptor class <var>pDescriptor</var> requires: its base set (<method>BaseSet</method>) --
/// the pairs an operator adjusted it to when its screen is adjustable and has a stored row
/// (AD-64), else its declared set -- unioned with the custom resource assigned to the classic page it
/// replaces, at <parameter>CLASSICPERMISSION</parameter>. An unassigned page reads <code>""</code> and
/// adds nothing.</p>
/// <p><b>This is the one reader of a screen's adjustment</b> (AD-64). It reads the store on every call
/// in the calling process and caches nothing, so every screen, area, read, tool, dispatch and confirm
/// gate follows a change at once. A store that cannot be read refuses the screen.</p>
/// <p><var>pResolved</var> is 1 only when the requirement was actually read. An empty list means
/// "requires nothing", which every caller holds, so a caller cannot tell that apart from a
/// failure unless the failure says so: a target that is not a descriptor, one whose
/// declaration will not parse, or one whose adjustment cannot be read answers an empty list with
/// <var>pResolved</var> 0 and must be refused rather than admitted.</p>
ClassMethod RequiredPairs(pDescriptor As %String, Output pResolved As %Boolean) As %List
{
    Set tPairs = ""
    Set pResolved = 0
    Try {
        Set tDeclSC = $ClassMethod(pDescriptor, "DeclarationJson", .tDeclaration)
        If $$$ISERR(tDeclSC) Quit
        Set tPairs = ..BaseSet(pDescriptor, .tAdjusted, .tBaseResolved)
        If 'tBaseResolved {
            Set tPairs = ""
            Quit
        }
        Set tCustom = ..ClassicResource($ClassMethod(pDescriptor, "ClassicPage"))
        If tCustom '= "" Set tPairs = tPairs _ $ListBuild($ListBuild(tCustom, ..#CLASSICPERMISSION))
        Set pResolved = 1
    } Catch {
        Set tPairs = ""
        Set pResolved = 0
    }
    Quit tPairs
}

/// <p>Whether the screen <var>pDescriptor</var> may have its required pairs adjusted (AD-64): its area
/// declares a pair set. A screen of an area that declares none (Home, Agent co-pilot) never gates
/// by the area and is never adjustable, so the kill switch, the definitions, governance and Screen
/// permissions itself stay out of reach of an adjustment. <b>This is that predicate's one home.</b></p>
ClassMethod Adjustable(pDescriptor As %String) As %Boolean
{
    Set tAdjustable = 0
    Try {
        Set tKey = $ClassMethod(pDescriptor, "AreaKey")
        ; The area vocabulary is static XData that costs a JSON parse per read, and this runs once per
        ; requirement the navigation map evaluates. The answer is kept per process, valid for the
        ; compiled Area class it was read from and dropped when that class is recompiled; it is not the
        ; adjustment, which is read on every call.
        Set tHash = $$$comClassKeyGet("OcuPilot.Screen.Area", $$$cCLASShash)
        If (tHash '= "") && ($Get(%OcuPilotGateAreas("hash")) = tHash) && $Data(%OcuPilotGateAreas(tKey)) {
            Set tAdjustable = %OcuPilotGateAreas(tKey)
            Quit
        }
        Set tAdjustable = ($ListLength(##class(OcuPilot.Screen.Area).PrivilegePairs(tKey)) > 0)
        If tHash '= "" {
            If $Get(%OcuPilotGateAreas("hash")) '= tHash Kill %OcuPilotGateAreas
            Set %OcuPilotGateAreas("hash") = tHash
            Set %OcuPilotGateAreas(tKey) = tAdjustable
        }
    } Catch {
        Set tAdjustable = 0
    }
    Quit tAdjustable
}

/// <p>The stored adjustment of descriptor <var>pDescriptor</var>, as a pair list, in <var>pFound</var>
/// whether the store holds a row for its <code>toolIdentifier</code>, and in <var>pResolved</var> 1 only
/// when the store was read and a stored row parsed. A row that will not parse is not an empty set: it
/// is unresolved.</p>
/// <p><b>Overridable</b> so a test can drive the seam in process; production never overrides it.</p>
ClassMethod AdjustedPairs(pDescriptor As %String, Output pFound As %Boolean, Output pResolved As %Boolean) As %List
{
    Set tPairs = ""
    Set pFound = 0
    Set pResolved = 0
    Try {
        Set tScreen = $ClassMethod(pDescriptor, "ToolIdentifier")
        If tScreen = "" {
            Set pResolved = 1
            Quit
        }
        Set tSC = ##class(OcuPilot.Kernel.State.Access).GuardedPairsFor(tScreen, .tText, .pFound)
        If $$$ISERR(tSC) {
            Set pFound = 0
            Quit
        }
        If pFound {
            Set tPairs = ..ParsePairSpec(tText)
            If tPairs = "" Quit
        }
        Set pResolved = 1
    } Catch {
        Set tPairs = ""
        Set pFound = 0
        Set pResolved = 0
    }
    Quit tPairs
}

/// <p>The pairs descriptor <var>pDescriptor</var> requires before the classic page's custom resource is
/// added: the adjusted set when the screen is adjustable (<method>Adjustable</method>) and has a stored
/// row, else the declared set. <var>pAdjusted</var> is 1 when the adjusted set answered, and
/// <var>pResolved</var> 0 when the adjustment could not be read.</p>
ClassMethod BaseSet(pDescriptor As %String, Output pAdjusted As %Boolean, Output pResolved As %Boolean) As %List
{
    Set pAdjusted = 0
    Set pResolved = 0
    Set tPairs = ""
    Try {
        If ..Adjustable(pDescriptor) {
            Set tStored = ..AdjustedPairs(pDescriptor, .tFound, .tReadable)
            If 'tReadable Quit
            If tFound {
                Set pAdjusted = 1
                Set pResolved = 1
                Set tPairs = tStored
                Quit
            }
        }
        Set tPairs = $ClassMethod(pDescriptor, "PrivilegePairs")
        Set pResolved = 1
    } Catch {
        Set tPairs = ""
        Set pAdjusted = 0
        Set pResolved = 0
    }
    Quit tPairs
}

/// <p>The base set (<method>BaseSet</method>) of the built screen whose <code>toolIdentifier</code> is
/// <var>pScreen</var>, with no classic union, and its descriptor class in <var>pDescriptor</var>.
/// <var>pResolved</var> is 0 for an identifier no built screen carries and for an adjustment that cannot
/// be read; <var>pDescriptor</var> tells the two apart (<code>""</code> for the first).</p>
ClassMethod BasePairs(pScreen As %String, Output pDescriptor As %String, Output pResolved As %Boolean) As %List
{
    Set pDescriptor = ""
    Set pResolved = 0
    Set tPairs = ""
    Try {
        Set tDescriptor = ##class(OcuPilot.Screen.Registry).DescriptorForTool(pScreen)
        If (tDescriptor = "") || '$ClassMethod(tDescriptor, "IsBuilt") Quit
        Set pDescriptor = tDescriptor
        Set tPairs = ..BaseSet(tDescriptor, .tAdjusted, .pResolved)
    } Catch {
        Set tPairs = ""
        Set pResolved = 0
    }
    Quit tPairs
}

/// <p><var>pPairs</var> with the custom resource assigned to each classic page <var>pPages</var>
/// names appended at <parameter>CLASSICPERMISSION</parameter>, once each (AD-44 as amended
/// 2026-09-28, DW-1784). <var>pPages</var> is a comma-separated list of normalized class names,
/// a write tool's <parameter>OcuPilot.Screen.Tool.Write.CLASSICPAGES</parameter>. An unassigned
/// page adds nothing.</p>
/// <p><b>It reads the store on every call and caches nothing</b>, so an assignment made after a
/// proposal was minted gates its confirm (AD-8).</p>
ClassMethod WithClassicPages(pPairs As %List, pPages As %String) As %List
{
    Set tPairs = pPairs
    For tI = 1:1:$Length(pPages, ",") {
        Set tPage = $ZStrip($Piece(pPages, ",", tI), "<>W")
        If tPage = "" Continue
        Set tCustom = ..ClassicResource(tPage)
        If tCustom = "" Continue
        Set tPair = $ListBuild(tCustom, ..#CLASSICPERMISSION)
        If '$ListFind(tPairs, tPair) Set tPairs = tPairs _ $ListBuild(tPair)
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
            If '..HoldsAny(tResource, tPermission) {
                Set tAllowed = 0
                Set pFailedPair = ..SpellPair(tResource, tPermission)
                Quit
            }
        }
    } Catch {
        Set tAllowed = 0
        Set pFailedPair = ""
    }
    Quit tAllowed
}

/// <p>The one either-of pair set (AD-64 item 4): <code>%Development</code> or <code>%Admin_Secure</code>
/// at <parameter>CLASSICPERMISSION</parameter>, as a single pair whose resource joins them with
/// <parameter>ALTERNATIVESEPARATOR</parameter>. Screen permissions, its read and its three write tools
/// require it, and nothing else does.</p>
ClassMethod AdjusterPairs() As %List
{
    Quit $ListBuild($ListBuild($Translate(..#ADJUSTERRESOURCES, ",", ..#ALTERNATIVESEPARATOR), ..#CLASSICPERMISSION))
}

/// <p><method>AdjusterPairs</method> spelled as <code>resource|resource:permission</code>, the form
/// <method>ParsePairSpec</method> reads back. Read at <b>compile</b> time by
/// <class>OcuPilot.Port.ScreenAccessPort</class>.</p>
ClassMethod AdjusterSpec() As %String
{
    Set tPair = $List(..AdjusterPairs(), 1)
    Quit $List(tPair, 1) _ ":" _ $List(tPair, 2)
}

/// <p>The resources a pair's resource <var>pResource</var> offers: one, or the members of an either-of pair.</p>
ClassMethod Alternatives(pResource As %String) As %List
{
    Quit $ListFromString(pResource, ..#ALTERNATIVESEPARATOR)
}

/// <p>The pair spelled for a refusal or a list: <code>resource:permission</code>, or every alternative
/// spelled so and joined with <code> or </code>, so a refusal names each pair that would have admitted
/// the caller.</p>
ClassMethod SpellPair(pResource As %String, pPermission As %String) As %String
{
    Set tText = ""
    Set tAlts = ..Alternatives(pResource)
    For tI = 1:1:$ListLength(tAlts) {
        Set tText = tText _ $Select(tText = "": "", 1: " or ") _ $List(tAlts, tI) _ ":" _ pPermission
    }
    Quit tText
}

/// <p>Whether the calling process holds <var>pPermission</var> on <var>pResource</var>, or, for an either-of
/// pair, on any one of its resources (<method>HoldsPrivilege</method> answers each).</p>
ClassMethod HoldsAny(pResource As %String, pPermission As %String) As %Boolean
{
    Set tHolds = 0
    Set tAlts = ..Alternatives(pResource)
    For tI = 1:1:$ListLength(tAlts) {
        If ..HoldsPrivilege($List(tAlts, tI), pPermission) {
            Set tHolds = 1
            Quit
        }
    }
    Quit tHolds
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

/// <p>The floor's members, comma-separated: <parameter>ADMINRESOURCES</parameter>, then
/// <parameter>DEVELOPMENTRESOURCE</parameter>, then <parameter>INTEROPRESOURCE</parameter>. Holding any one at
/// <parameter>ADMINPERMISSION</parameter> clears the floor.</p>
/// <p>Read at <b>compile</b> time by <class>OcuPilot.Api.Router</class>, whose
/// <parameter>OcuPilot.Api.Router.FLOORRESOURCES</parameter> the request gate and a turn's step
/// boundary read, so neither holds a copy of the list.</p>
ClassMethod FloorResources() As %String
{
    Quit ..#ADMINRESOURCES _ "," _ ..#DEVELOPMENTRESOURCE _ "," _ ..#INTEROPRESOURCE
}

/// <p><method>FloorResources</method> spelled as the comma-separated
/// <code>resource:permission</code> specification, each member at
/// <parameter>ADMINPERMISSION</parameter>. Read at <b>compile</b> time by
/// <class>OcuPilot.Port.ProviderPort</class>, whose any-of gate it is.</p>
ClassMethod FloorPairSpec() As %String
{
    Set tSpec = ""
    Set tFloor = ..FloorResources()
    For tI = 1:1:$Length(tFloor, ",") {
        Set tResource = $Piece(tFloor, ",", tI)
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
/// <p><b>Overridable</b> so the union can be exercised against a fixture value. The one test that
/// writes the store is <class>OcuPilot.Test.ClassicPageGate</class>, on a throwaway only, and it
/// restores each page it assigns. Production never overrides it.</p>
ClassMethod ClassicResource(pPageClass As %String) As %String
{
    If pPageClass = "" Quit ""
    Quit ##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(pPageClass, "O", "URL"))
}

}
