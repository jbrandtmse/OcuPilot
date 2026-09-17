/// <p>The one enumeration of screen descriptors (AD-5). The route table, the navigation entry
/// and the privilege gate all read this class; nothing else enumerates descriptors, and adding
/// a screen is adding a subclass of <class>OcuPilot.Screen.Descriptor.Base</class>.</p>
/// <p>Descriptors are found by a parameterized <class>%Dictionary.CompiledClass</class> query
/// over the descriptor package, keeping the discipline
/// <class>OcuPilot.Test.AdminInventory</class> states for the vendor's endpoint classes: a
/// query that did not open, or a fetch that stopped early, is an error rather than a package
/// with fewer classes in it. It differs from that fixture in one way, for a measured reason --
/// see <method>Descriptors</method>.</p>
/// <p><method>Validate</method> is the server half of "the build fails on an unknown value"
/// (AD-14): it refuses a descriptor whose declaration will not parse, whose area is not one
/// <class>OcuPilot.Screen.Area</class> declares, whose entity types are not
/// <method>OcuPilot.Kernel.EntityType.IsKnown</method>, whose declared <code>scope</code> is
/// neither of <class>OcuPilot.Kernel.Scope</class>'s two values, whose tool identifier is empty,
/// whose refresh declaration is not a permitted pair (AD-43, <method>RefreshProblem</method>),
/// whose read is not the declared grammar (AD-36, <method>ReadProblem</method>),
/// whose declared server-search criteria are not the declared grammar (AD-21,
/// <method>CriteriaProblem</method>),
/// whose privilege set names a pair its area does not (AD-8,
/// <method>AreaCoverageProblem</method>),
/// whose banner is not the declared grammar (<method>BannerProblem</method>),
/// whose archetype or classic link-out is not a permitted shape (AD-44,
/// <method>ClassicLinkProblem</method>), whose <code>tab</code> is not the declared grammar (AD-5,
/// <method>TabProblem</method>), or whose route or tool identifier collides with
/// another's; and, over the whole roster, whose tab groups do not fit together
/// (<method>TabGroupProblem</method>). For both the
/// <b>entity type</b> and the
/// <b>scope</b>, <file>scripts/check-objectscript.py</file> and
/// <file>ui/tools/screen-mirror.mjs</file> refuse the same value before it ever compiles, each
/// reading its vocabulary from the same source this method reads
/// (<class>OcuPilot.Kernel.EntityType</class>'s <code>TYPES</code> parameter,
/// <class>OcuPilot.Kernel.Scope</class>'s two), so this method is the refusal expressed against
/// a compiled roster rather than a third copy of either vocabulary, and
/// <method>OcuPilot.Test.Descriptor.TestTheProductionRosterValidates</method> is where a shipped
/// descriptor meets it.</p>
/// <p><b>Nothing on the serving path calls it.</b> It is run by
/// <class>OcuPilot.Test.Descriptor</class>, and it is here for the story that adds a descriptor
/// at install or upgrade time to call. <method>Roster</method> deliberately does not: it answers
/// every request, and a roster walk per request is a cost the two build-time refusals already
/// buy at zero.</p>
Class OcuPilot.Screen.Registry Extends %RegisteredObject
{

/// <p>The package descriptors live in, trailing dot included.</p>
Parameter DESCRIPTORPACKAGE = "OcuPilot.Screen.Descriptor.";

/// <p>The abstract base, which lives in the package and is not a descriptor.</p>
Parameter BASECLASS = "OcuPilot.Screen.Descriptor.Base";

/// <p>The package this registry enumerates. Overridable so a test can point a registry at
/// fixture descriptors -- the three awkward declaration forms, and one naming an entity type
/// the enum does not hold -- without adding them to the production roster. Production never
/// overrides it.</p>
ClassMethod DescriptorPackage() As %String
{
    Quit ..#DESCRIPTORPACKAGE
}

/// <p>The one class in <method>DescriptorPackage</method> that is not a descriptor. A fixture
/// package holds no base of its own, so this simply never matches there.</p>
ClassMethod BaseClass() As %String
{
    Quit ..#BASECLASS
}

/// <p>Every descriptor class in the package, by name, in class-name order. Membership is the
/// package prefix <b>and</b> the superclass: a class that merely sits in the package is not a
/// descriptor, and admitting one would make every accessor call below it throw.</p>
/// <p><b>Embedded SQL, not <class>%SQL.Statement</class>, and the difference is load-bearing.</b>
/// Dynamic SQL is privilege-checked against the calling user, and no ordinary administrator
/// holds a SQL grant on <class>%Dictionary.CompiledClass</class>: measured over the wire
/// 2026-09-12, a throwaway principal holding <code>%Admin_Operate:USE</code> plus read on the
/// install namespace's code database got <code>SQLCODE -99 ... is not privileged for the
/// operation</code>, and the navigation map answered one internal-error envelope instead of a
/// map. Embedded SQL is not privilege-checked, so this reads the dictionary for exactly the
/// callers the shell exists for. The package still travels as a host variable, never as
/// concatenated text (AD-21).</p>
/// <p>The caller's own privileges are unaffected by this: nothing about which screens they may
/// <i>reach</i> is decided here -- that is <class>OcuPilot.Screen.Gate</class>'s, evaluated per
/// entry in the calling process. This method answers "which screens exist", which is the same
/// answer for everyone.</p>
ClassMethod Descriptors(Output pList As %List) As %Status
{
    Set tSC = $$$OK
    Set pList = ""
    Try {
        Set tPackage = ..DescriptorPackage()
        Set tBase = ..BaseClass()
        Set tName = ""
        &sql(DECLARE OcuDescriptorCur CURSOR FOR SELECT Name INTO :tName FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH :tPackage ORDER BY Name)
        &sql(OPEN OcuDescriptorCur)
        If SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the descriptor query did not open: SQLCODE " _ SQLCODE)
            Quit
        }
        For {
            &sql(FETCH OcuDescriptorCur)
            Quit:SQLCODE'=0
            If tName = tBase Continue
            ; The package prefix says where a class sits, not what it is. A class placed under
            ; the descriptor package that is not a descriptor answers no accessor, so the
            ; $ClassMethod calls every caller of this list makes would throw -- and that throw
            ; takes down Roster, which takes down GET /api/ocupilot/navigation, which leaves the
            ; client holding no map at all and every area reading as ungated. The superclass is
            ; what makes a class a descriptor, so that is what is asked; a class that cannot
            ; answer %Extends is not one either.
            Set tIsDescriptor = 0
            Try {
                Set tIsDescriptor = $ClassMethod(tName, "%Extends", tBase)
            } Catch {
                Set tIsDescriptor = 0
            }
            If 'tIsDescriptor Continue
            Set pList = pList _ $ListBuild(tName)
        }
        ; The fetch loop ends at SQLCODE 100 normally and at a negative value on a failure, so
        ; the code is kept before CLOSE resets it: a fetch that stopped early would otherwise
        ; read as a package with fewer classes in it.
        Set tFetchCode = SQLCODE
        &sql(CLOSE OcuDescriptorCur)
        If tFetchCode < 0 {
            Set pList = ""
            Set tSC = $$$ERROR($$$GeneralError, "the descriptor fetch stopped early: SQLCODE " _ tFetchCode)
        }
    } Catch ex {
        Set pList = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Refuse every descriptor the declaration contract does not admit. <var>pProblem</var>
/// names the first offending class and what is wrong with it, and is <code>""</code> exactly
/// when the roster is sound.</p>
ClassMethod Validate(Output pProblem As %String) As %Status
{
    Set tSC = $$$OK
    Set pProblem = ""
    Try {
        Set tSC = ..Descriptors(.tList)
        If $$$ISERR(tSC) Quit
        Set tRoutes = ""
        Set tRoster = []
        For tI = 1:1:$ListLength(tList) {
            Set tClass = $List(tList, tI)
            Set tDeclSC = $ClassMethod(tClass, "DeclarationJson", .tObject)
            If $$$ISERR(tDeclSC) {
                Set pProblem = tClass _ ": " _ $System.Status.GetErrorText(tDeclSC)
                Quit
            }
            ; DW-271. The top-level key set is closed, and this is the only check that reads it.
            ; Every rule below asks the declaration for a key it names, so a misspelling is not an
            ; error anywhere else: `banners` installs a screen whose strip never raises, because
            ; BannerProblem reads `banner`, finds nothing, and correctly calls a screen with no
            ; banner sound. Checked before the first accessor runs, so the refusal names the
            ; misspelling rather than whatever the accessor's default then failed on.
            Set tDeclProblem = ..DeclarationProblem(tObject)
            If tDeclProblem '= "" {
                Set pProblem = tClass _ ": " _ tDeclProblem
                Quit
            }
            Set tArea = $ClassMethod(tClass, "AreaKey")
            If '##class(OcuPilot.Screen.Area).Exists(tArea) {
                Set pProblem = tClass _ ": area '" _ tArea _ "' is not one OcuPilot.Screen.Area declares"
                Quit
            }
            ; Story 3.5: sideBarPosition 0 is the sentinel for routable-but-unlisted, and
            ; Base.cls's `+..Field(...)` already answers 0 for an absent key -- so without this
            ; rule a forgotten key unlists a screen with nothing red anywhere. Declared, not
            ; defaulted.
            Set tPositionProblem = ..SideBarPositionProblem(tObject)
            If tPositionProblem '= "" {
                Set pProblem = tClass _ ": " _ tPositionProblem
                Quit
            }
            Set tTypes = $ClassMethod(tClass, "EntityTypes")
            Set tBadType = ""
            For tJ = 1:1:$ListLength(tTypes) {
                If '##class(OcuPilot.Kernel.EntityType).IsKnown($List(tTypes, tJ)) {
                    Set tBadType = $List(tTypes, tJ)
                    Quit
                }
            }
            If tBadType '= "" {
                Set pProblem = tClass _ ": entity type '" _ tBadType _ "' is not in OcuPilot.Kernel.EntityType"
                Quit
            }
            ; The scope half of every reference to one of this screen's entities (AD-13) is
            ; resolved from this value by OcuPilot.Kernel.EntityRef.ScopeFor, which answers ""
            ; for anything else -- so a third spelling would produce references with no scope
            ; rather than a refusal anyone could see.
            Set tScope = $ClassMethod(tClass, "Scope")
            If (tScope '= ##class(OcuPilot.Kernel.Scope).#SCOPENAMESPACE) && (tScope '= ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE) {
                Set pProblem = tClass _ ": scope '" _ tScope _ "' is neither '" _ ##class(OcuPilot.Kernel.Scope).#SCOPENAMESPACE _ "' nor '" _ ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE _ "'"
                Quit
            }
            Set tIdentifier = $ClassMethod(tClass, "ToolIdentifier")
            If tIdentifier = "" {
                Set pProblem = tClass _ ": toolIdentifier is empty, and a tool name is never derived from a route or a display name"
                Quit
            }
            If $Data(tIdentifierOwner(tIdentifier)) {
                Set pProblem = tClass _ ": toolIdentifier '" _ tIdentifier _ "' is already declared by " _ tIdentifierOwner(tIdentifier) _ ", and a screen and its tools are resolved by it"
                Quit
            }
            Set tIdentifierOwner(tIdentifier) = tClass
            Set tReadProblem = ..ReadProblem(tObject)
            If tReadProblem '= "" {
                Set pProblem = tClass _ ": " _ tReadProblem
                Quit
            }
            ; AD-21: the declared criteria roster is the allow-list a route and a read tool are
            ; both filtered through, so a misdeclared one would either drop a parameter the screen
            ; sends or admit a caller key the port never validated. Refused where it is declared,
            ; after the read's own shape is known to be sound.
            Set tCriteriaProblem = ..CriteriaProblem(tObject)
            If tCriteriaProblem '= "" {
                Set pProblem = tClass _ ": " _ tCriteriaProblem
                Quit
            }
            ; A pair missing either half is dropped by Area.PairsFrom rather than carried, so a
            ; descriptor that misspells "permission" would otherwise declare a gate and ship
            ; ungated. The refusal is here because the drop is silent by design everywhere else.
            Set tBadPair = ..MalformedPair(tObject.%Get("privileges"))
            If tBadPair '= "" {
                Set pProblem = tClass _ ": declared privilege pair " _ tBadPair _ " is missing its resource or its permission"
                Quit
            }
            ; AD-8: OcuPilot.Screen.Gate evaluates an area's set and a screen's set separately and
            ; never unions them, so an area declaring less than one of its screens requires shows
            ; the rail item allowed and refuses everything inside it.
            Set tCoverageProblem = ..AreaCoverageProblem(tArea, $ClassMethod(tClass, "PrivilegePairs"))
            If tCoverageProblem '= "" {
                Set pProblem = tClass _ ": " _ tCoverageProblem
                Quit
            }
            ; AD-43: the descriptor is the only place a screen says whether it refreshes and at
            ; what rates, so a malformed pair has to fail where it is declared. Refusing it here
            ; means install stops; the alternative is a screen that binds the shared framework at
            ; render time and arms a timer at a rate nobody declared.
            Set tRefreshProblem = ..RefreshProblem($ClassMethod(tClass, "Refreshes"), $ClassMethod(tClass, "RefreshRates"))
            If tRefreshProblem '= "" {
                Set pProblem = tClass _ ": " _ tRefreshProblem
                Quit
            }
            ; A banner is a second declared port read whose value raises a strip above the table,
            ; so its shape is refused where it is declared rather than swallowed at render time:
            ; OcuPilot.Screen.Read suppresses the strip on any fault, which is exactly what would
            ; make a misdeclared banner invisible instead of loud.
            Set tBannerProblem = ..BannerProblem(tObject)
            If tBannerProblem '= "" {
                Set pProblem = tClass _ ": " _ tBannerProblem
                Quit
            }
            ; AD-44: a list archetype never links out and only a detail view may, so a
            ; malformed or forbidden exemption is refused where it is declared. Nothing on the
            ; serving path calls this method yet (see the class comment), so the refusal that
            ; actually stops a bad declaration today is ui/tools/classic-links.mjs at the build
            ; and the commit; this is the same rule waiting for the story that runs Validate at
            ; install, and it is what OcuPilot.Test.Descriptor drives.
            Set tClassicProblem = ..ClassicLinkProblem(tObject)
            If tClassicProblem '= "" {
                Set pProblem = tClass _ ": " _ tClassicProblem
                Quit
            }
            ; AD-5: a tabbed screen is one descriptor per tab, grouped by a declared tab.
            Set tTabProblem = ..TabProblem(tObject)
            If tTabProblem '= "" {
                Set pProblem = tClass _ ": " _ tTabProblem
                Quit
            }
            Set tRoute = $ClassMethod(tClass, "Route")
            If $ListFind(tRoutes, tRoute) > 0 {
                Set pProblem = tClass _ ": route '" _ tRoute _ "' is already declared by another descriptor"
                Quit
            }
            Set tRoutes = tRoutes _ $ListBuild(tRoute)
            Do tRoster.%Push({"descriptor": (tClass), "declaration": (tObject)})
        }
        If (pProblem = "") && $$$ISOK(tSC) Set pProblem = ..TabGroupProblem(tRoster)
    } Catch ex {
        Set pProblem = "the descriptor roster could not be validated: " _ ex.DisplayString()
        Set tSC = ex.AsStatus()
    }
    ; A problem is a refusal, not a report: the status carries it too, so a caller that checks
    ; only $$$ISERR cannot read an invalid roster as a valid one.
    If $$$ISOK(tSC) && (pProblem '= "") Set tSC = $$$ERROR($$$GeneralError, pProblem)
    Quit tSC
}

/// <p>The keys a screen declaration may carry at its top level -- the whole vocabulary, in the
/// order <class>OcuPilot.Screen.Descriptor.Base</class> reads them (AD-5).</p>
/// <p>Six are optional and the rest are not, but this parameter says nothing about which:
/// <method>DeclarationProblem</method> is an <b>unknown-key</b> check, never a presence check. A
/// declaration missing an optional key -- <code>refreshes</code>, <code>refreshRates</code>,
/// <code>read</code>, <code>table</code>, <code>banner</code>, <code>tab</code> -- is sound, and a
/// declaration missing a required one is already refused by the rule that reads it, with a sentence
/// naming what it was for.</p>
Parameter DECLARATIONKEYS = "route,area,labelKey,sideBarPosition,archetype,built,refreshes,refreshRates,privileges,entityType,secondaryEntityTypes,scope,parentScope,id,context,primaryAction,rowActions,emptyStateKey,commandAliases,classicPage,classicLinkExemption,read,table,banner,tab,toolIdentifier";

/// <p>What is wrong with <var>pDeclaration</var>'s own top-level keys, or <code>""</code> when
/// nothing is (DW-271). Every key must be one of <parameter>DECLARATIONKEYS</parameter>.</p>
/// <p><b>This is the only rule a misspelt top-level key can trip.</b> Every other rule here asks
/// the declaration for a key by name, so an unknown one is invisible to all of them: a descriptor
/// declaring <code>banners</code> installs, validates, mirrors verbatim, and renders a screen
/// whose strip never raises. Refused by name rather than by presence, because a presence check
/// would refuse the five optional keys' absence and the twenty-key declarations
/// <class>OcuPilot.Test.Bad.Unknown</class> and <class>OcuPilot.Test.Pair.Bad</class> build in
/// ObjectScript to drive other refusals.</p>
/// <p><file>ui/tools/screen-mirror.mjs</file>'s <code>declarationProblem</code> returns the same
/// sentence for every case in <class>OcuPilot.Test.DeclarationCorpus</class>, the corpus both
/// engines run.</p>
/// <p><b>Public and value-driven</b> for the reason <method>RefreshProblem</method> is.</p>
ClassMethod DeclarationProblem(pDeclaration As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        ; $IsObject answers 1 for a %DynamicArray too, and iterating one yields integer keys -- so
        ; without the second half an array-shaped declaration would be refused here as "the unknown
        ; key '0'" and by the mirror as "not an object", and the two engines' sentences would
        ; differ on the same input.
        If '$IsObject(pDeclaration) || pDeclaration.%IsA("%Library.DynamicArray") {
            Set tProblem = "the declaration is not an object"
            Quit
        }
        Set tProblem = ..UnknownKeyProblem(pDeclaration, "the declaration", $ListFromString(..#DECLARATIONKEYS))
    } Catch ex {
        Set tProblem = "the declaration could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>What is wrong with a declared refresh pair, or <code>""</code> when nothing is (AD-43).</p>
/// <p>A screen that does not refresh permits no rate; one that does declares at least one, and
/// every rate is a whole number of seconds above zero, strictly ascending. Nothing else is a
/// rate the chip could advance through: a duplicate would make one step of the cycle a no-op, a
/// fraction would arm a timer at a delay no copy names, and zero is spelled by turning the chip
/// off rather than by declaring it.</p>
/// <p><b>Public, unlike <method>MalformedPair</method></b>, so the shapes above can be exercised
/// as values rather than as a fixture descriptor per shape -- six malformed declarations would
/// otherwise be six fixture classes and six registries, because <method>Validate</method> reports
/// only the first problem in a roster.</p>
ClassMethod RefreshProblem(pRefreshes As %Boolean, pRates As %List) As %String
{
    Set tProblem = ""
    Try {
        Set tCount = $ListLength(pRates)
        If 'pRefreshes {
            If tCount > 0 Set tProblem = "refreshRates declares " _ tCount _ " rate(s) while refreshes is false; a screen that does not refresh permits none"
            Quit
        }
        If tCount = 0 {
            Set tProblem = "refreshes is true but refreshRates is empty; a refreshing screen declares the rates its chip may set"
            Quit
        }
        Set tPrevious = 0
        For tI = 1:1:tCount {
            Set tRate = $List(pRates, tI)
            If (tRate = "") || '$IsValidNum(tRate) || (tRate '= (tRate \ 1)) || (tRate '> 0) {
                Set tProblem = "refreshRates entry #" _ tI _ " ('" _ tRate _ "') is not a whole number of seconds above zero"
                Quit
            }
            If tRate '> tPrevious {
                Set tProblem = "refreshRates entry #" _ tI _ " (" _ tRate _ ") does not ascend from " _ tPrevious
                Quit
            }
            Set tPrevious = tRate
        }
    } Catch ex {
        Set tProblem = "the refresh declaration could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>What is wrong with a <b>built</b> <var>pDeclaration</var>'s <code>sideBarPosition</code>, or
/// <code>""</code> when nothing is. It must be declared, a JSON number, a whole number, and at
/// least 0.</p>
/// <p><b>0 means routable but not listed.</b> A screen declaring it is built, routed and reached
/// from its own list -- the name cell, or that list's Create -- and appears in no side bar, no
/// command box and no Home tile caption. Every other position is that screen's place in its
/// area's side bar, ascending.</p>
/// <p><b>Why the key needs a rule it never had.</b>
/// <method>OcuPilot.Screen.Descriptor.Base.SideBarPosition</method> is <code>+..Field(...)</code>,
/// so an absent key already reads as 0 -- which, once 0 is a sentinel, silently unlists any
/// descriptor that forgets to declare it. Refusing an undeclared key is what makes the sentinel a
/// decision rather than an accident. An unbuilt screen is exempt: it is listed by nothing and
/// routed by nothing, so its position says nothing yet.</p>
/// <p><b>Public and value-driven</b> for the reason <method>RefreshProblem</method> is.</p>
ClassMethod SideBarPositionProblem(pDeclaration As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        If '$IsObject(pDeclaration) {
            Set tProblem = "the declaration is not an object"
            Quit
        }
        If pDeclaration.%Get("built") '= 1 Quit
        Set tType = pDeclaration.%GetTypeOf("sideBarPosition")
        If tType '= "number" {
            Set tProblem = "sideBarPosition is not declared as a number, and an absent key would silently unlist a built screen (AD-5)"
            Quit
        }
        Set tValue = pDeclaration.%Get("sideBarPosition")
        If ('$Match(tValue, "^(0|[1-9][0-9]*)$")) || (+tValue < 0) {
            Set tProblem = "sideBarPosition '" _ tValue _ "' is not a whole number of at least 0, where 0 means routable but not listed"
            Quit
        }
    } Catch ex {
        Set tProblem = "the sideBarPosition declaration could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>The shape a <code>tab.group</code> route takes: lower-case segments of letters, digits and
/// hyphens, joined by <code>/</code>.</p>
Parameter TABGROUPPATTERN = "^[a-z0-9-]+(/[a-z0-9-]+)*$";

/// <p>What is wrong with <var>pDeclaration</var>'s <code>tab</code>, or <code>""</code> when nothing
/// is (AD-5). A tabbed screen is one descriptor per tab, grouped by this declaration.</p>
/// <p>A <code>tab</code> that is absent or <code>null</code> is a screen that is no tab. Otherwise it
/// is an object carrying only <code>group</code> (a route, <parameter>TABGROUPPATTERN</parameter>),
/// <code>position</code> (a whole number of at least 1) and <code>labelKey</code> (a non-empty string
/// key). Position 1 is declared exactly by the member whose <code>route</code> is the group, and a
/// member at position 2 or higher declares <code>sideBarPosition</code> 0, so the group's side-bar
/// entry is its first tab and no other.</p>
/// <p>How the members of one group fit together is <method>TabGroupProblem</method>'s, over the
/// roster. <file>ui/tools/screen-mirror.mjs</file>'s <code>tabProblem</code> returns the same sentence
/// for every case in <class>OcuPilot.Test.TabCorpus</class>.</p>
/// <p><b>Public and value-driven</b> for the reason <method>RefreshProblem</method> is.</p>
ClassMethod TabProblem(pDeclaration As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        If '$IsObject(pDeclaration) {
            Set tProblem = "the declaration is not an object"
            Quit
        }
        Set tType = pDeclaration.%GetTypeOf("tab")
        If (tType = "unassigned") || (tType = "null") Quit
        If tType '= "object" {
            Set tProblem = "tab is not an object declaring its group, position and labelKey (AD-5)"
            Quit
        }
        Set tTab = pDeclaration.%Get("tab")
        Set tProblem = ..UnknownKeyProblem(tTab, "tab", $ListBuild("group", "position", "labelKey"))
        If tProblem '= "" Quit
        Set tGroup = tTab.%Get("group")
        If (tTab.%GetTypeOf("group") '= "string") || '$Match(tGroup, ..#TABGROUPPATTERN) {
            Set tProblem = "tab.group '" _ tGroup _ "' is not a route"
            Quit
        }
        Set tPosition = tTab.%Get("position")
        If (tTab.%GetTypeOf("position") '= "number") || '$Match(tPosition, "^[1-9][0-9]*$") {
            Set tProblem = "tab.position '" _ tPosition _ "' is not a whole number of at least 1"
            Quit
        }
        If (tTab.%GetTypeOf("labelKey") '= "string") || (tTab.%Get("labelKey") = "") {
            Set tProblem = "tab.labelKey is empty, and a tab names the string key its label reads"
            Quit
        }
        Set tRoute = pDeclaration.%Get("route")
        If (tPosition = 1) && (tRoute '= tGroup) {
            Set tProblem = "tab.position 1 is the group's own route, and route '" _ tRoute _ "' is not tab.group '" _ tGroup _ "' (AD-5)"
            Quit
        }
        If (tPosition '= 1) && (tRoute = tGroup) {
            Set tProblem = "tab.group '" _ tGroup _ "' is this screen's own route, which only tab.position 1 may declare (AD-5)"
            Quit
        }
        If (tPosition > 1) && ((pDeclaration.%GetTypeOf("sideBarPosition") '= "number") || (pDeclaration.%Get("sideBarPosition") '= 0)) {
            Set tProblem = "tab.position " _ tPosition _ " is a tab under its group's first, and such a tab declares sideBarPosition 0 (AD-5)"
            Quit
        }
    } Catch ex {
        Set tProblem = "the tab declaration could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>What is wrong with how a roster's tab groups fit together, or <code>""</code> (AD-5).
/// <var>pScreens</var> is a <class>%DynamicArray</class> of <code>{descriptor, declaration}</code>
/// in roster order, and the answer names the offending descriptor.</p>
/// <p>A member is any declaration whose <code>tab</code> is an object with a string
/// <code>group</code>. Groups are checked in the order their first member appears. For each: the
/// group names a built member (the declaration at the group's route, built, declaring that group);
/// every member shares that member's <code>area</code> and <code>archetype</code>; and the members'
/// positions, sorted, run 1 to their count with no gap or repeat. A shape one member cannot hold on
/// its own is <method>TabProblem</method>'s.</p>
/// <p><file>ui/tools/screen-mirror.mjs</file>'s <code>tabGroupProblem</code> returns the same sentence
/// for every roster case in <class>OcuPilot.Test.TabCorpus</class>.</p>
ClassMethod TabGroupProblem(pScreens As %DynamicArray) As %String
{
    Set tProblem = ""
    Try {
        Kill tMembers, tOrder
        Set tGroups = ""
        Set tIterator = pScreens.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tScreen) {
            If '$IsObject(tScreen) Continue
            Set tDeclaration = tScreen.%Get("declaration")
            If '$IsObject(tDeclaration) || (tDeclaration.%GetTypeOf("tab") '= "object") Continue
            Set tTab = tDeclaration.%Get("tab")
            If tTab.%GetTypeOf("group") '= "string" Continue
            Set tGroup = tTab.%Get("group")
            If '$ListFind(tGroups, tGroup) Set tGroups = tGroups _ $ListBuild(tGroup)
            Set tMembers(tGroup) = $Get(tMembers(tGroup)) + 1
            Set tMembers(tGroup, tMembers(tGroup)) = tScreen
        }
        For tG = 1:1:$ListLength(tGroups) {
            Set tGroup = $List(tGroups, tG)
            Set tHead = ""
            For tM = 1:1:tMembers(tGroup) {
                Set tDeclaration = tMembers(tGroup, tM).%Get("declaration")
                If (tDeclaration.%Get("route") = tGroup) && (tDeclaration.%GetTypeOf("built") = "boolean") && tDeclaration.%Get("built") Set tHead = tMembers(tGroup, tM)
            }
            If tHead = "" {
                Set tProblem = tMembers(tGroup, 1).%Get("descriptor") _ ": tab.group '" _ tGroup _ "' names no built member at that route, and a tab group opens at its first tab (AD-5)"
                Quit
            }
            Set tArea = tHead.%Get("declaration").%Get("area")
            Set tArchetype = tHead.%Get("declaration").%Get("archetype")
            For tM = 1:1:tMembers(tGroup) {
                Set tDeclaration = tMembers(tGroup, tM).%Get("declaration")
                If (tDeclaration.%Get("area") = tArea) && (tDeclaration.%Get("archetype") = tArchetype) Continue
                Set tProblem = tMembers(tGroup, tM).%Get("descriptor") _ ": tab.group '" _ tGroup _ "' is declared in area '" _ tDeclaration.%Get("area") _ "' with archetype '" _ tDeclaration.%Get("archetype") _ "', and a tab group's members share the area and archetype of '" _ tGroup _ "' (AD-5)"
                Quit
            }
            If tProblem '= "" Quit
            Kill tSorted
            For tM = 1:1:tMembers(tGroup) {
                Set tPosition = tMembers(tGroup, tM).%Get("declaration").%Get("tab").%Get("position")
                Set tSorted(+tPosition) = $Get(tSorted(+tPosition)) + 1
            }
            Set tText = ""
            Set tExpected = 1
            Set tSound = 1
            Set tPosition = ""
            For {
                Set tPosition = $Order(tSorted(tPosition))
                If tPosition = "" Quit
                For tC = 1:1:tSorted(tPosition) {
                    Set tText = tText _ $Select(tText = "": "", 1: ",") _ tPosition
                    If tPosition '= tExpected Set tSound = 0
                    Set tExpected = tExpected + 1
                }
            }
            If 'tSound {
                Set tProblem = tHead.%Get("descriptor") _ ": tab.group '" _ tGroup _ "' declares positions " _ tText _ ", and a tab group's positions run 1 to " _ tMembers(tGroup) _ " with no gap or repeat (AD-5)"
                Quit
            }
        }
    } Catch ex {
        Set tProblem = "the tab groups could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>The first of <var>pPairs</var> that the area declared under <var>pAreaKey</var> does not
/// itself declare, as the sentence <method>Validate</method> prefixes with the declaring class, or
/// <code>""</code> when the area covers all of them (AD-8).</p>
/// <p><var>pPairs</var> is one screen's pair set in the form
/// <method>OcuPilot.Screen.Descriptor.Base.PrivilegePairs</method> answers. An area that declares
/// more than a screen requires is sound; one that declares less is not, because
/// <class>OcuPilot.Screen.Gate</class> evaluates the area's set and the screen's set separately and
/// never unions them -- so the rail item reads allowed while every screen inside it is refused.
/// Checked per descriptor, which is the same statement as "the area covers the union of its
/// screens' sets" and additionally reports which class the missing pair belongs to.</p>
/// <p><b>The declared set is all this can check.</b>
/// <method>OcuPilot.Screen.Gate.RequiredPairs</method> also unions the classic page's
/// operator-assigned custom resource, which is runtime state no roster check reads, so a screen
/// gated by such a resource can still be refused inside an area that reads allowed.</p>
/// <p><b>An area that declares <i>no</i> pairs is a never-gating area, and its screens gate
/// independently.</b> An empty set is not "a set that covers nothing": it is EXPERIENCE.md's
/// "the rail-item itself never gates" ("Agent co-pilot &#8250; Definitions and Switches"), the
/// shape <class>OcuPilot.Screen.Area</class> records for Home and Agent co-pilot. The false
/// admission this rule exists to prevent -- an area that reads allowed while every screen inside
/// it refuses -- is the intended behaviour there: the rail item carries an attention dot rather
/// than a gate, and the side-bar entries name the resource. So an empty area set is sound
/// whatever its screens require; a non-empty one that does not cover a screen's is still
/// refused, because that is an area that meant to gate and gated too little.</p>
/// <p><b>Public and value-driven</b> for the reason <method>RefreshProblem</method> is: a covered
/// and an uncovered set are exercised as values rather than as one fixture descriptor per case.</p>
ClassMethod AreaCoverageProblem(pAreaKey As %String, pPairs As %List) As %String
{
    Set tProblem = ""
    Try {
        Set tAreaPairs = ##class(OcuPilot.Screen.Area).PrivilegePairs(pAreaKey)
        If tAreaPairs = "" Quit
        For tI = 1:1:$ListLength(pPairs) {
            Set tPair = $List(pPairs, tI)
            Set tCovered = 0
            For tJ = 1:1:$ListLength(tAreaPairs) {
                Set tAreaPair = $List(tAreaPairs, tJ)
                If ($List(tAreaPair, 1) = $List(tPair, 1)) && ($List(tAreaPair, 2) = $List(tPair, 2)) Set tCovered = 1
            }
            If tCovered Continue
            Set tProblem = "area '" _ pAreaKey _ "' does not declare " _ $List(tPair, 1) _ ":" _ $List(tPair, 2) _ ", which this screen requires, so the area would read allowed while the screen is refused (AD-8)"
            Quit
        }
    } Catch ex {
        Set tProblem = "the area's privilege coverage could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>The severities a declared banner may take: the three <file>ui/src/styles/_components.scss</file>
/// gives a <code>.ocu-banner-*</code> variant (DESIGN.md `:1203`). A severity outside them would
/// render an unstyled strip, so the set is what the client can actually draw rather than the
/// document's whole variant list.</p>
Parameter BANNERSEVERITIES = "info,warning,restrained";

/// <p>What is wrong with <var>pDeclaration</var>'s <code>banner</code>, or <code>""</code> when
/// nothing is. <var>pDeclaration</var> is the whole parsed declaration, because the last rule
/// reaches <code>read</code>.</p>
/// <p>A <code>banner</code> that is absent or <code>null</code> is a screen with no banner.
/// Otherwise it is an object carrying only <code>source</code>, <code>field</code> and
/// <code>cases</code>; <code>source</code>
/// carries only <code>port</code> (<code>admin</code>), <code>endpoint</code> (a package-relative
/// name) and <code>type</code> (<code>GET</code>, the one request type a banner's value comes from);
/// <code>field</code> is a non-empty string; and <code>cases</code> is a non-empty array of objects
/// carrying only <code>equals</code>, <code>messageKey</code> and <code>severity</code>, each
/// <code>equals</code> and <code>messageKey</code> a non-empty string, each <code>equals</code>
/// declared once, and each <code>severity</code> one of
/// <parameter>BANNERSEVERITIES</parameter>. Last of all, a banner
/// declared while <code>read</code> is not is refused: a banner is chrome on a declared read's
/// screen, it rides in that read's own response, and the read's own
/// <code>%DB_IRISSYS:READ</code> arm is what covers the banner's admin-port call too, so the pair
/// is not checked twice.</p>
/// <p><b>One read, many cases</b> (DW-270). A field with a closed set of values usually has more
/// than one state worth a strip -- <code>%SYS.Task.TASKMGRStatus()</code> answers
/// <code>Running</code>, <code>Suspended</code> and <code>Not running</code>, and a single-case
/// banner left a stopped scheduler silent. The cases share the one port call the banner already
/// makes, so a second state costs no second read.</p>
/// <p><file>ui/tools/screen-mirror.mjs</file>'s <code>bannerProblem</code> returns the same sentence
/// for every case in <class>OcuPilot.Test.BannerCorpus</class>, the corpus both engines run.</p>
/// <p><b>Public and value-driven</b> for the reason <method>RefreshProblem</method> is.</p>
ClassMethod BannerProblem(pDeclaration As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        If '$IsObject(pDeclaration) {
            Set tProblem = "the declaration is not an object"
            Quit
        }
        Set tType = pDeclaration.%GetTypeOf("banner")
        If (tType = "unassigned") || (tType = "null") Quit
        If tType '= "object" {
            Set tProblem = "banner is not an object naming its source, field and cases"
            Quit
        }
        Set tBanner = pDeclaration.%Get("banner")
        Set tProblem = ..UnknownKeyProblem(tBanner, "banner", $ListBuild("source", "field", "cases"))
        If tProblem '= "" Quit

        If tBanner.%GetTypeOf("source") '= "object" {
            Set tProblem = "banner.source is not an object naming its port, endpoint and type"
            Quit
        }
        Set tSource = tBanner.%Get("source")
        Set tProblem = ..UnknownKeyProblem(tSource, "banner.source", $ListBuild("port", "endpoint", "type"))
        If tProblem '= "" Quit
        If (tSource.%GetTypeOf("port") '= "string") || (tSource.%Get("port") '= "admin") {
            Set tProblem = "banner.source.port '" _ tSource.%Get("port") _ "' is not 'admin', the one port a Release 1 read names (AD-2)"
            Quit
        }
        If (tSource.%GetTypeOf("endpoint") '= "string") || '$Match(tSource.%Get("endpoint"), "^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") {
            Set tProblem = "banner.source.endpoint '" _ tSource.%Get("endpoint") _ "' is not a package-relative endpoint name"
            Quit
        }
        If (tSource.%GetTypeOf("type") '= "string") || (tSource.%Get("type") '= "GET") {
            Set tProblem = "banner.source.type '" _ tSource.%Get("type") _ "' is not 'GET'"
            Quit
        }

        If (tBanner.%GetTypeOf("field") '= "string") || (tBanner.%Get("field") = "") {
            Set tProblem = "banner.field is empty, and a banner compares one named field to the values its cases name"
            Quit
        }

        Set tProblem = ..BannerCasesProblem(tBanner)
        If tProblem '= "" Quit

        Set tReadType = pDeclaration.%GetTypeOf("read")
        If (tReadType = "unassigned") || (tReadType = "null") {
            Set tProblem = "a banner is chrome on a declared read's screen (AD-36)"
        }
    } Catch ex {
        Set tProblem = "the banner declaration could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>What is wrong with <var>pBanner</var>'s <code>cases</code>, or <code>""</code> (DW-270): a
/// non-empty array of objects carrying only <code>equals</code>, <code>messageKey</code> and
/// <code>severity</code>, each <code>equals</code> and <code>messageKey</code> a non-empty string,
/// each <code>equals</code> declared once -- a repeated value would make the second case
/// unreachable, since <method>OcuPilot.Screen.Read.BannerKey</method> raises the first that matches
/// -- and each <code>severity</code> one of <parameter>BANNERSEVERITIES</parameter>.</p>
ClassMethod BannerCasesProblem(pBanner As %DynamicObject) As %String [ Private ]
{
    If pBanner.%GetTypeOf("cases") '= "array" Quit "banner.cases is not an array of banner cases"
    Set tCases = pBanner.%Get("cases")
    If tCases.%Size() = 0 Quit "banner.cases is empty, and a declared banner raises at least one sentence"

    Set tProblem = ""
    Set tSeen = ""
    Set tSeverities = $ListFromString(..#BANNERSEVERITIES)
    Set tIterator = tCases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase, .tCaseType) {
        Set tWhere = "banner.cases entry #" _ (tIndex + 1)
        If tCaseType '= "object" {
            Set tProblem = tWhere _ " is not an object declaring its equals, messageKey and severity"
            Quit
        }
        Set tProblem = ..UnknownKeyProblem(tCase, tWhere, $ListBuild("equals", "messageKey", "severity"))
        If tProblem '= "" Quit
        For tKey = "equals", "messageKey" {
            If (tCase.%GetTypeOf(tKey) '= "string") || (tCase.%Get(tKey) = "") {
                Set tProblem = tWhere _ " " _ tKey _ " is empty, and a case names the one value it raises on and the string key it raises"
                Quit
            }
        }
        If tProblem '= "" Quit
        Set tEquals = tCase.%Get("equals")
        If $ListFind(tSeen, tEquals) {
            Set tProblem = tWhere _ " names the value '" _ tEquals _ "' twice"
            Quit
        }
        Set tSeen = tSeen _ $ListBuild(tEquals)
        If (tCase.%GetTypeOf("severity") '= "string") || '$ListFind(tSeverities, tCase.%Get("severity")) {
            Set tProblem = tWhere _ " severity '" _ tCase.%Get("severity") _ "' is not one of " _ ..#BANNERSEVERITIES
            Quit
        }
    }
    Quit tProblem
}

/// <p>The tool-identifier shape a read-declaring descriptor carries: one lower-case area segment
/// and one lower-case screen segment, so its read tool is <code>&lt;toolIdentifier&gt;.read</code>
/// (Conventions, Tool naming).</p>
Parameter READTOOLIDENTIFIERPATTERN = "^[a-z][a-z0-9]*\.[a-z][a-z0-9]*$";

/// <p>What is wrong with <var>pDeclaration</var>'s <code>read</code>, or <code>""</code> when
/// nothing is (AD-36). <var>pDeclaration</var> is the whole parsed declaration, because the rules
/// reach <code>context.secretFields</code> and <code>toolIdentifier</code> as well.</p>
/// <p>A <code>read</code> that is absent or <code>null</code> is a screen with no read. Otherwise:
/// <code>source</code> is <code>{port, endpoint, type}</code>, whose <code>type</code> is one of
/// <parameter>READSOURCETYPES</parameter> -- <code>GET</code> reads one object of an
/// <code>admin</code> endpoint and declares no <code>rowGet</code>, <code>forEach</code> or
/// <code>criteria</code> -- and whose optional <code>forEach</code> lists a parent endpoint first
/// (<method>ForEachProblem</method>). It names one of three sources
/// -- <code>admin</code>, an instance endpoint reached through the port, with a
/// dotted endpoint name and an optional <code>rowGet</code> (<method>RowGetProblem</method>);
/// <code>mgmnt</code>, the management API reached through its own port, which declares no
/// <code>rowGet</code>; or
/// <code>state</code>, one of OcuPilot's own kernel stores (AD-9) named without a package, which
/// declares neither a <code>rowGet</code> nor <code>criteria</code>;
/// <code>fields</code> is a non-empty array of unique names; <code>filter</code>,
/// <code>sort.fields</code> and <code>context.secretFields</code> name only declared fields, and no
/// secret field is filterable or sortable (a filter over one would let a tool probe its value);
/// <code>sort.default</code> is one of <code>sort.fields</code>; <code>sort.direction</code> is
/// <code>asc</code> or <code>desc</code>; <code>paging</code> is <code>cap</code>, since no admin
/// LIST accepts a cursor; and <code>toolIdentifier</code> matches
/// <parameter>READTOOLIDENTIFIERPATTERN</parameter>. <code>read</code>, <code>read.source</code>,
/// <code>read.sort</code> and <code>context</code> carry only their declared keys, and
/// <code>context.secretFields</code> is declared, so a misspelt key is refused rather than read as
/// no secret field. A read-declaring declaration also declares its <code>table</code>, whose
/// shape <method>TableProblem</method> checks; a <code>table</code> with no read is refused here.
/// Last of all, a read on the <code>admin</code> port whose <code>privileges</code> omit
/// <code>%DB_IRISSYS:READ</code> is refused, because the port runs every endpoint in
/// <code>%SYS</code> -- a <code>state</code> read runs in the install namespace and needs no such
/// pair, so the rule is on the source kind rather than on every read. <file>ui/tools/screen-mirror.mjs</file>'s <code>readProblem</code> refuses the
/// same shapes before the mirror is emitted, and
/// <class>OcuPilot.Test.AdminPairCorpus</class> is the corpus both engines run.</p>
/// <p><b>Public and value-driven</b> for the reason <method>RefreshProblem</method> is.</p>
ClassMethod ReadProblem(pDeclaration As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        If '$IsObject(pDeclaration) {
            Set tProblem = "the declaration is not an object"
            Quit
        }
        Set tType = pDeclaration.%GetTypeOf("read")
        If (tType = "unassigned") || (tType = "null") {
            Set tTableType = pDeclaration.%GetTypeOf("table")
            If (tTableType '= "unassigned") && (tTableType '= "null") Set tProblem = "table is declared while read is not, and a table renders a declared read's rows (AD-36)"
            Quit
        }
        If tType '= "object" {
            Set tProblem = "read is a " _ tType _ ", and a declared read is an object (AD-36)"
            Quit
        }
        Set tRead = pDeclaration.%Get("read")
        Set tProblem = ..UnknownKeyProblem(tRead, "read", $ListBuild("source", "fields", "filter", "sort", "paging", "criteria"))
        If tProblem '= "" Quit

        If tRead.%GetTypeOf("source") '= "object" {
            Set tProblem = "read.source is not an object naming its port, endpoint and type (AD-36)"
            Quit
        }
        Set tSource = tRead.%Get("source")
        Set tProblem = ..UnknownKeyProblem(tSource, "read.source", $ListBuild("port", "endpoint", "type", "rowGet", "forEach"))
        If tProblem '= "" Quit
        Set tPort = tSource.%Get("port")
        If (tSource.%GetTypeOf("port") '= "string") || '$ListFind($ListBuild(##class(OcuPilot.Screen.Read).#SOURCEADMIN, ##class(OcuPilot.Screen.Read).#SOURCESTATE, ##class(OcuPilot.Screen.Read).#SOURCEMGMNT), tPort) {
            Set tProblem = "read.source.port '" _ tPort _ "' is not one of '" _ ##class(OcuPilot.Screen.Read).#SOURCEADMIN _ "', '" _ ##class(OcuPilot.Screen.Read).#SOURCESTATE _ "' or '" _ ##class(OcuPilot.Screen.Read).#SOURCEMGMNT _ "', the three sources a declared read names (AD-36)"
            Quit
        }
        If (tSource.%GetTypeOf("endpoint") '= "string") || '$Match(tSource.%Get("endpoint"), "^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") {
            Set tProblem = "read.source.endpoint '" _ tSource.%Get("endpoint") _ "' is not a package-relative endpoint name"
            Quit
        }
        If (tPort = ##class(OcuPilot.Screen.Read).#SOURCESTATE) && (tSource.%Get("endpoint") [ ".") {
            Set tProblem = "read.source.endpoint '" _ tSource.%Get("endpoint") _ "' names a package, and a state source names a store inside " _ ##class(OcuPilot.Screen.Read).#STATEPACKAGE _ " by its own name alone (AD-9)"
            Quit
        }
        If (tSource.%GetTypeOf("type") '= "string") || '$ListFind($ListFromString(..#READSOURCETYPES), tSource.%Get("type")) {
            Set tProblem = "read.source.type '" _ tSource.%Get("type") _ "' is not 'LIST' or 'GET'"
            Quit
        }
        ; A GET source reads one named object of an admin endpoint as the read's one row (AD-36), so
        ; it has no row list to issue a detail call for, no parents to list and no server search.
        If tSource.%Get("type") = "GET" {
            If tPort '= ##class(OcuPilot.Screen.Read).#SOURCEADMIN {
                Set tProblem = "read.source.type 'GET' is declared on a '" _ tPort _ "' source, and a single-object read issues an admin endpoint's GET (AD-36)"
                Quit
            }
            If tSource.%GetTypeOf("rowGet") = "object" {
                Set tProblem = "read.source.rowGet is declared on a GET source, which reads one object and has no rows to issue a detail call for (AD-36)"
                Quit
            }
            If tSource.%GetTypeOf("forEach") = "object" {
                Set tProblem = "read.source.forEach is declared on a GET source, which reads one object and lists no parents (AD-36)"
                Quit
            }
            If tRead.%GetTypeOf("criteria") = "object" {
                Set tProblem = "read.criteria is declared on a GET source, whose one object takes no server search (AD-36)"
                Quit
            }
        }
        ; A state source's rows are OcuPilot's own, read whole: there is no detail endpoint to
        ; issue per row and no vendor query to search on the server, so declaring either is
        ; refused where it is declared rather than ignored at read time (AD-36).
        ; A mgmnt source answers whole rows from the management API, which offers no per-row
        ; detail call to issue.
        If (tPort = ##class(OcuPilot.Screen.Read).#SOURCEMGMNT) && (tSource.%GetTypeOf("rowGet") = "object") {
            Set tProblem = "read.source.rowGet is declared on a mgmnt source, which reads whole rows from the management API and has no per-row detail call (AD-36)"
            Quit
        }
        If tPort = ##class(OcuPilot.Screen.Read).#SOURCESTATE {
            If tSource.%GetTypeOf("rowGet") = "object" {
                Set tProblem = "read.source.rowGet is declared on a state source, which reads whole rows from a kernel store and has no per-row detail call (AD-36)"
                Quit
            }
            If tRead.%GetTypeOf("criteria") = "object" {
                Set tProblem = "read.criteria is declared on a state source, whose rows are filtered and sorted in one view rule rather than searched on a vendor query (AD-21, AD-36)"
                Quit
            }
        }

        Set tFieldsProblem = ..NameArrayProblem(tRead, "fields", "", .tFields)
        If tFieldsProblem '= "" {
            Set tProblem = "read." _ tFieldsProblem
            Quit
        }
        If $ListLength(tFields) = 0 {
            Set tProblem = "read.fields is empty, and a read projects at least one field"
            Quit
        }
        Set tProblem = ..RowGetProblem(tSource, tFields)
        If tProblem '= "" Quit
        Set tProblem = ..ForEachProblem(tRead, tSource, tFields)
        If tProblem '= "" Quit

        If pDeclaration.%GetTypeOf("context") '= "object" {
            Set tProblem = "context is not an object, and a screen that declares a read declares its secret fields (AD-24)"
            Quit
        }
        Set tContext = pDeclaration.%Get("context")
        Set tProblem = ..UnknownKeyProblem(tContext, "context", $ListBuild("fields", "secretFields"))
        If tProblem '= "" Quit
        Set tSecretProblem = ..NameArrayProblem(tContext, "secretFields", tFields, .tSecrets)
        If tSecretProblem '= "" {
            Set tProblem = "context." _ tSecretProblem
            Quit
        }

        Set tFilterProblem = ..NameArrayProblem(tRead, "filter", tFields, .tFilter)
        If tFilterProblem '= "" {
            Set tProblem = "read." _ tFilterProblem
            Quit
        }
        Set tProblem = ..SecretOverlap("read.filter", tFilter, tSecrets)
        If tProblem '= "" Quit

        If tRead.%GetTypeOf("sort") '= "object" {
            Set tProblem = "read.sort is not an object declaring its fields, default and direction"
            Quit
        }
        Set tSort = tRead.%Get("sort")
        Set tProblem = ..UnknownKeyProblem(tSort, "read.sort", $ListBuild("fields", "default", "direction"))
        If tProblem '= "" Quit
        Set tSortProblem = ..NameArrayProblem(tSort, "fields", tFields, .tSortFields)
        If tSortProblem '= "" {
            Set tProblem = "read.sort." _ tSortProblem
            Quit
        }
        Set tProblem = ..SecretOverlap("read.sort.fields", tSortFields, tSecrets)
        If tProblem '= "" Quit
        If (tSort.%GetTypeOf("default") '= "string") || '$ListFind(tSortFields, tSort.%Get("default")) {
            Set tProblem = "read.sort.default '" _ tSort.%Get("default") _ "' is not one of read.sort.fields"
            Quit
        }
        If (tSort.%GetTypeOf("direction") '= "string") || '$ListFind($ListBuild("asc", "desc"), tSort.%Get("direction")) {
            Set tProblem = "read.sort.direction '" _ tSort.%Get("direction") _ "' is neither 'asc' nor 'desc'"
            Quit
        }

        If (tRead.%GetTypeOf("paging") = "string") && (tRead.%Get("paging") = "cursor") {
            Set tProblem = "read.paging 'cursor' is refused: neither declared source kind accepts a cursor; declare 'cap' (AD-36)"
            Quit
        }
        If (tRead.%GetTypeOf("paging") '= "string") || (tRead.%Get("paging") '= "cap") {
            Set tProblem = "read.paging '" _ tRead.%Get("paging") _ "' is not 'cap'"
            Quit
        }

        Set tIdentifier = pDeclaration.%Get("toolIdentifier")
        If '$Match(tIdentifier, ..#READTOOLIDENTIFIERPATTERN) {
            Set tProblem = "toolIdentifier '" _ tIdentifier _ "' declares a read and is not <area>.<screen> in lower case, so its read tool could not be named <area>.<screen>.read"
            Quit
        }

        Set tProblem = ..TableProblem(pDeclaration, tFields, tSecrets)
        If tProblem '= "" Quit

        ; The last arm, so no earlier refusal changes which sentence a declaration gets.
        ; OcuPilot.Port.AdminPort.RunSequence sets $NAMESPACE to %SYS for every request type with
        ; no predicate on the endpoint, and IRIS requires READ on a namespace's default globals
        ; database -- IRISSYS, resource %DB_IRISSYS -- to make it current. Without the pair the
        ; vendor endpoint fails inside %SYS and the port answers 500 where the gate would have
        ; named the missing privilege (AD-2, AD-8).
        If tSource.%Get("port") = ##class(OcuPilot.Screen.Read).#SOURCEADMIN {
            Set tHasSystemRead = 0
            Set tDeclaredPairs = pDeclaration.%Get("privileges")
            If $IsObject(tDeclaredPairs) {
                Set tPairIterator = tDeclaredPairs.%GetIterator()
                While tPairIterator.%GetNext(.tPairIndex, .tDeclaredPair) {
                    If '$IsObject(tDeclaredPair) Continue
                    If (tDeclaredPair.%Get("resource") = "%DB_IRISSYS") && (tDeclaredPair.%Get("permission") = "READ") Set tHasSystemRead = 1
                }
            }
            If 'tHasSystemRead Set tProblem = "read.source.port 'admin' requires the declared privileges to include %DB_IRISSYS:READ, because the port runs every endpoint in %SYS (AD-2, AD-8)"
        }
    } Catch ex {
        Set tProblem = "the read declaration could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>The kinds a declared server-search criterion may take (AD-21).</p>
Parameter CRITERIONKINDS = "text,datetime,choice";

/// <p>The names a read's own two callers already send, which no criterion may claim.</p>
/// <p><code>maxRows</code> is the row cap <method>OcuPilot.Screen.Read.Execute</method> sends
/// itself; <code>filter</code>, <code>sort</code> and <code>direction</code> are the read tool's
/// own arguments, and a criterion taking one of those names would replace that property in
/// <method>OcuPilot.Screen.Tool.Read.InputSchema</method> -- losing <code>sort</code>'s declared
/// enum, for instance -- because the criteria are added after it; <code>ns</code> is the scope key
/// <file>ui/src/app/core/api.ts</file> appends to every request, which a criterion of that name
/// would read off the request and forward into the vendor query. Compared case-folded, because the
/// vendor upper-cases query keys.</p>
Parameter CRITERIARESERVEDPARAMS = "maxRows,filter,sort,direction,ns";

/// <p>What is wrong with <var>pDeclaration</var>'s <code>read.criteria</code>, or <code>""</code>
/// when nothing is (AD-21). <var>pDeclaration</var> is the whole parsed declaration, because the
/// last rule reaches <code>refreshes</code>.</p>
/// <p>A <code>read</code> that is absent, <code>null</code> or not an object declares no criteria,
/// and so does a <code>read</code> whose <code>criteria</code> is absent or <code>null</code>:
/// every list before Story 2.10 filters and sorts on the client within the cap, and only a read
/// whose API searches on the server declares one.</p>
/// <p>Otherwise <code>criteria</code> is an object carrying only <code>fields</code> and
/// <code>marker</code>, on an <code>admin</code> or <code>mgmnt</code> source. <code>fields</code> is a non-empty array
/// of objects carrying only <code>param</code> (a query parameter name, unique across the block
/// and never one of <parameter>CRITERIARESERVEDPARAMS</parameter>), a non-empty
/// <code>labelKey</code>, a <code>kind</code> from <parameter>CRITERIONKINDS</parameter> and a
/// <code>maxLength</code> (a whole number above zero, required on every criterion whatever its
/// kind -- <method>CriteriaMaxLengthProblem</method>), plus
/// <code>options</code> -- a non-empty array of unique non-empty strings -- exactly when
/// <code>kind</code> is <code>choice</code>. <code>marker</code>, when declared, carries only
/// <code>param</code> (one of the declared criteria), a non-empty <code>value</code> and a
/// non-empty <code>labelKey</code>.</p>
/// <p><b>The roster is the allow-list, which is why a misdeclaration is refused at install.</b>
/// <method>OcuPilot.Api.ScreenRead.Handle</method> reads a query parameter only where this block
/// names it and <method>OcuPilot.Screen.Tool.Read.InputSchema</method> publishes one property per
/// criterion, so a dropped or misspelt entry is a parameter the screen silently stops sending and a
/// tool silently stops accepting -- not an error anyone sees at render time. The <code>choice</code>
/// kind exists for the same reason: <method>OcuPilot.Screen.Read.Execute</method> refuses a value
/// outside <code>options</code> before the port is called, because the vendor's own
/// <code>$$AuthenticationDisplayToLogical^%SYS.SECURITY</code> answers <code>-1</code> for a name it
/// does not know and <code>-1</code> matches nearly every row.</p>
/// <p><b>A criteria-bearing screen never auto-refreshes</b> (AD-43): it renders nothing until
/// Search is pressed, so a timer would have no rows to re-read and
/// <file>EXPERIENCE.md</file> exempts it by name.</p>
/// <p><b>A parent-scoped read declares exactly one criterion</b> (AD-5). A declaration with a
/// non-empty <code>parentScope</code> and a <code>read</code> is a sub-resource list whose one
/// criterion the client fills from the route id, so a read declaring none, or more than one, is
/// refused with <method>ParentCriteriaProblem</method>'s sentence. Such a read runs when its page
/// opens, with no Search to press, and never auto-refreshes either.</p>
/// <p><file>ui/tools/screen-mirror.mjs</file>'s <code>criteriaProblem</code> returns the same
/// sentence for every case in <class>OcuPilot.Test.CriteriaCorpus</class>, the corpus both engines
/// run.</p>
/// <p><b>Public and value-driven</b> for the reason <method>RefreshProblem</method> is.</p>
ClassMethod CriteriaProblem(pDeclaration As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        If '$IsObject(pDeclaration) {
            Set tProblem = "the declaration is not an object"
            Quit
        }
        If pDeclaration.%GetTypeOf("read") '= "object" Quit
        Set tRead = pDeclaration.%Get("read")
        Set tParented = (pDeclaration.%GetTypeOf("parentScope") = "string") && (pDeclaration.%Get("parentScope") '= "")
        Set tType = tRead.%GetTypeOf("criteria")
        If (tType = "unassigned") || (tType = "null") {
            If tParented Set tProblem = ..ParentCriteriaProblem(pDeclaration)
            Quit
        }
        If tType '= "object" {
            Set tProblem = "read.criteria is not an object declaring its fields and marker (AD-21)"
            Quit
        }
        Set tCriteria = tRead.%Get("criteria")
        Set tProblem = ..UnknownKeyProblem(tCriteria, "read.criteria", $ListBuild("fields", "marker"))
        If tProblem '= "" Quit

        Set tPort = ""
        If tRead.%GetTypeOf("source") = "object" Set tPort = tRead.%Get("source").%Get("port")
        If (tPort '= "admin") && (tPort '= "mgmnt") {
            Set tProblem = "read.criteria is declared on a '" _ tPort _ "' source, and server criteria travel on the admin and mgmnt ports alone (AD-21)"
            Quit
        }

        Set tProblem = ..CriteriaFieldsProblem(tCriteria, .tParams)
        If tProblem '= "" Quit
        Set tProblem = ..CriteriaMarkerProblem(tCriteria, tParams)
        If tProblem '= "" Quit
        If tParented && ($ListLength(tParams) '= 1) {
            Set tProblem = ..ParentCriteriaProblem(pDeclaration)
            Quit
        }

        ; The last arm, so no earlier refusal changes which sentence a declaration gets.
        If ''pDeclaration.%Get("refreshes") {
            Set tProblem = "refreshes is declared with read.criteria, and a screen that searches on the server renders nothing until Search and does not auto-refresh (AD-43)"
        }
    } Catch ex {
        Set tProblem = "the criteria declaration could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>The one sentence a parent-scoped read that does not declare exactly one criterion is refused
/// with (AD-5).</p>
ClassMethod ParentCriteriaProblem(pDeclaration As %DynamicObject) As %String [ Private ]
{
    Quit "parentScope '" _ pDeclaration.%Get("parentScope") _ "' is declared with a read, and a parent-scoped read declares exactly one read.criteria field, which its route id fills (AD-5)"
}

/// <p>What is wrong with <var>pCriteria</var>'s <code>fields</code>, or <code>""</code>.
/// <var>pParams</var> is the declared parameter names, as a <class>%List</class>.</p>
ClassMethod CriteriaFieldsProblem(pCriteria As %DynamicObject, Output pParams As %List) As %String [ Private ]
{
    Set pParams = ""
    If pCriteria.%GetTypeOf("fields") '= "array" Quit "read.criteria.fields is not an array of criterion declarations"
    Set tFields = pCriteria.%Get("fields")
    If tFields.%Size() = 0 Quit "read.criteria.fields is empty, and a declared criteria block carries at least one criterion (AD-21)"

    Set tProblem = ""
    Set tKinds = $ListFromString(..#CRITERIONKINDS)
    Set tSeen = ""
    Set tIterator = tFields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField, .tFieldType) {
        Set tWhere = "read.criteria.fields entry #" _ (tIndex + 1)
        If tFieldType '= "object" {
            Set tProblem = tWhere _ " is not an object declaring its param, labelKey and kind"
            Quit
        }
        Set tKind = tField.%Get("kind")
        Set tAllowed = $ListBuild("param", "labelKey", "kind", "maxLength")
        If tKind = "choice" Set tAllowed = tAllowed _ $ListBuild("options")
        Set tProblem = ..UnknownKeyProblem(tField, tWhere, tAllowed)
        If tProblem '= "" Quit

        Set tParam = tField.%Get("param")
        If (tField.%GetTypeOf("param") '= "string") || '$Match(tParam, "^[A-Za-z][A-Za-z0-9]*$") {
            Set tProblem = tWhere _ " param '" _ tParam _ "' is not a query parameter name"
            Quit
        }
        Set tFolded = $ZConvert(tParam, "L")
        If $ListFind($ListFromString($ZConvert(..#CRITERIARESERVEDPARAMS, "L")), tFolded) {
            Set tProblem = tWhere _ " param '" _ tParam _ "' collides with a name the read's own callers already send"
            Quit
        }
        If $ListFind(tSeen, tFolded) {
            Set tProblem = tWhere _ " names the param '" _ tParam _ "' twice"
            Quit
        }
        Set tSeen = tSeen _ $ListBuild(tFolded)
        Set pParams = pParams _ $ListBuild(tParam)

        If (tField.%GetTypeOf("labelKey") '= "string") || (tField.%Get("labelKey") = "") {
            Set tProblem = tWhere _ " labelKey is empty, and a criterion's control names a string key"
            Quit
        }
        If (tField.%GetTypeOf("kind") '= "string") || '$ListFind(tKinds, tKind) {
            Set tProblem = tWhere _ " kind '" _ tKind _ "' is not one of " _ ..#CRITERIONKINDS
            Quit
        }
        Set tProblem = ..CriteriaMaxLengthProblem(tField, tWhere)
        If tProblem '= "" Quit
        If tKind '= "choice" Continue
        Set tProblem = ..CriteriaOptionsProblem(tField, tWhere)
        If tProblem '= "" Quit
    }
    If tProblem '= "" Set pParams = ""
    Quit tProblem
}

/// <p>What is wrong with a criterion's <code>maxLength</code>, or <code>""</code>: a whole number
/// above zero, declared on <b>every</b> criterion whatever its kind (DW-279).</p>
/// <p><b>Required, not optional.</b> The vendor's own property is what bounds the value in the end
/// -- <code>Pids</code> is <code>MAXLEN</code> 50 on
/// <code>%Api.Admin.Endpoints.Security.Audit.RecordListTask</code> -- and a value longer than that
/// faults inside the port, where <method>OcuPilot.Screen.Read.SeedCriteria</method> can no longer
/// name the parameter that was too long. A criterion that declared no bound would be one no
/// refusal could be written for, so the grammar refuses it at install rather than at the first
/// over-long value. That is why this is a <b>presence</b> check where
/// <method>DeclarationProblem</method> is deliberately not one: here there is a rule that needs
/// the key, and nothing else would report its absence.</p>
ClassMethod CriteriaMaxLengthProblem(pField As %DynamicObject, pWhere As %String) As %String [ Private ]
{
    Set tType = pField.%GetTypeOf("maxLength")
    If tType = "unassigned" Quit pWhere _ " declares no maxLength, and every criterion declares the length its vendor property accepts (AD-21)"
    Set tValue = pField.%Get("maxLength")
    If (tType '= "number") || (tValue = "") || '$IsValidNum(tValue) || (tValue '= (tValue \ 1)) || (tValue '> 0) {
        Quit pWhere _ " maxLength '" _ tValue _ "' is not a whole number above zero"
    }
    Quit ""
}

/// <p>What is wrong with a <code>choice</code> criterion's <code>options</code>, or
/// <code>""</code>: a non-empty array of unique non-empty strings, which is the enum the executor
/// and the read tool both validate a supplied value against (AD-21).</p>
ClassMethod CriteriaOptionsProblem(pField As %DynamicObject, pWhere As %String) As %String [ Private ]
{
    If pField.%GetTypeOf("options") '= "array" Quit pWhere _ " kind 'choice' declares no options, and a choice criterion is validated against a declared enum (AD-21)"
    Set tOptions = pField.%Get("options")
    If tOptions.%Size() = 0 Quit pWhere _ " options is empty, and a choice criterion is validated against a declared enum (AD-21)"
    Set tProblem = ""
    Set tSeen = ""
    Set tIterator = tOptions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tOption, .tOptionType) {
        If (tOptionType '= "string") || (tOption = "") {
            Set tProblem = pWhere _ " options entry #" _ (tIndex + 1) _ " is not a non-empty value"
            Quit
        }
        If $ListFind(tSeen, tOption) {
            Set tProblem = pWhere _ " options names '" _ tOption _ "' twice"
            Quit
        }
        Set tSeen = tSeen _ $ListBuild(tOption)
    }
    Quit tProblem
}

/// <p>What is wrong with <var>pCriteria</var>'s <code>marker</code>, or <code>""</code>.
/// <var>pParams</var> is the declared parameter names.</p>
/// <p>An absent or <code>null</code> marker is a criteria block with no agent-marker affordance.
/// Otherwise its <code>param</code> is one of the declared criteria -- the marker <b>overrides</b>
/// that criterion rather than merging with it, so it has to be one the form already carries.</p>
ClassMethod CriteriaMarkerProblem(pCriteria As %DynamicObject, pParams As %List) As %String [ Private ]
{
    Set tType = pCriteria.%GetTypeOf("marker")
    If (tType = "unassigned") || (tType = "null") Quit ""
    If tType '= "object" Quit "read.criteria.marker is not an object declaring its param, value and labelKey"
    Set tMarker = pCriteria.%Get("marker")
    Set tProblem = ..UnknownKeyProblem(tMarker, "read.criteria.marker", $ListBuild("param", "value", "labelKey"))
    If tProblem '= "" Quit tProblem
    Set tParam = tMarker.%Get("param")
    If (tMarker.%GetTypeOf("param") '= "string") || '$ListFind(pParams, tParam) {
        Quit "read.criteria.marker.param '" _ tParam _ "' is not one of read.criteria.fields, and the marker overrides a declared criterion rather than adding one"
    }
    If (tMarker.%GetTypeOf("value") '= "string") || (tMarker.%Get("value") = "") {
        Quit "read.criteria.marker.value is empty, and the marker filter sends one declared value"
    }
    If (tMarker.%GetTypeOf("labelKey") '= "string") || (tMarker.%Get("labelKey") = "") {
        Quit "read.criteria.marker.labelKey is empty, and the marker filter names a string key"
    }
    Quit ""
}

/// <p>The request types a <code>read.source</code> may issue (AD-36): <code>LIST</code>, a list of
/// rows, and <code>GET</code>, one object read as the read's one row.</p>
Parameter READSOURCETYPES = "LIST,GET";

/// <p>What is wrong with <var>pSource</var>'s <code>forEach</code>, or <code>""</code> (AD-36).
/// <var>pRead</var> is the declared read and <var>pFields</var> its declared fields.</p>
/// <p>An absent or <code>null</code> <code>forEach</code> lists no parents. Otherwise it is an object
/// carrying only <code>endpoint</code> (the parent endpoint, a package-relative name),
/// <code>key</code> (the parent row field whose text each child list is read for), <code>param</code>
/// (the query parameter that text is sent as) and <code>fields</code>, an array of objects carrying
/// only <code>field</code> (one of <var>pFields</var>, not repeated) and <code>from</code> (the
/// parent row field copied into it). It is declared on an <code>admin</code> <code>LIST</code> source
/// only, with no <code>rowGet</code> and no <code>criteria</code>.
/// <file>ui/tools/screen-mirror.mjs</file>'s <code>forEachProblem</code> returns the same sentence
/// for every case in <class>OcuPilot.Test.ReadSourceCorpus</class>.</p>
ClassMethod ForEachProblem(pRead As %DynamicObject, pSource As %DynamicObject, pFields As %List) As %String
{
    Set tWhere = "read.source.forEach"
    Set tType = pSource.%GetTypeOf("forEach")
    If (tType = "unassigned") || (tType = "null") Quit ""
    If tType '= "object" Quit tWhere _ " is not an object declaring its endpoint, key, param and fields (AD-36)"
    Set tForEach = pSource.%Get("forEach")
    Set tProblem = ..UnknownKeyProblem(tForEach, tWhere, $ListBuild("endpoint", "key", "param", "fields"))
    If tProblem '= "" Quit tProblem
    Set tPort = pSource.%Get("port")
    If tPort '= ##class(OcuPilot.Screen.Read).#SOURCEADMIN Quit tWhere _ " is declared on a '" _ tPort _ "' source, and a per-parent list issues admin endpoints (AD-36)"
    If pSource.%GetTypeOf("rowGet") = "object" Quit tWhere _ " is declared with read.source.rowGet, and a per-parent list copies its parent's fields rather than a detail call's (AD-36)"
    If pRead.%GetTypeOf("criteria") = "object" Quit tWhere _ " is declared with read.criteria, and a per-parent list sets its one parameter from each parent (AD-36)"
    If (tForEach.%GetTypeOf("endpoint") '= "string") || '$Match(tForEach.%Get("endpoint"), "^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") {
        Quit tWhere _ ".endpoint '" _ tForEach.%Get("endpoint") _ "' is not a package-relative endpoint name"
    }
    If (tForEach.%GetTypeOf("key") '= "string") || (tForEach.%Get("key") = "") Quit tWhere _ ".key is empty, and a per-parent list reads each parent's key by name"
    If (tForEach.%GetTypeOf("param") '= "string") || '$Match(tForEach.%Get("param"), "^[A-Za-z][A-Za-z0-9]*$") {
        Quit tWhere _ ".param '" _ tForEach.%Get("param") _ "' is not a query parameter name"
    }
    If tForEach.%GetTypeOf("fields") '= "array" Quit tWhere _ ".fields is not an array of parent fields"
    Set tSeen = ""
    Set tIterator = tForEach.%Get("fields").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry, .tEntryType) {
        Set tAt = tWhere _ ".fields entry #" _ (tIndex + 1)
        If tEntryType '= "object" {
            Set tProblem = tAt _ " is not an object declaring its field and from"
            Quit
        }
        Set tProblem = ..UnknownKeyProblem(tEntry, tAt, $ListBuild("field", "from"))
        If tProblem '= "" Quit
        Set tField = tEntry.%Get("field")
        If (tEntry.%GetTypeOf("field") '= "string") || '$ListFind(pFields, tField) {
            Set tProblem = tAt _ " field '" _ tField _ "' is not one of read.fields"
            Quit
        }
        If $ListFind(tSeen, tField) {
            Set tProblem = tAt _ " names the field '" _ tField _ "' twice"
            Quit
        }
        Set tSeen = tSeen _ $ListBuild(tField)
        If (tEntry.%GetTypeOf("from") '= "string") || (tEntry.%Get("from") = "") {
            Set tProblem = tAt _ " from is empty, and a parent field is copied from a named key of the parent"
            Quit
        }
    }
    Quit tProblem
}

/// <p>The rules a <code>read.source.rowGet</code> derived field may name (AD-36).</p>
Parameter ROWGETRULES = "beforeToday";

/// <p>The request types a <code>read.source.rowGet</code> may issue (AD-36): <code>GET</code>, the
/// default; <code>INFO</code>, where the list's own row is wrong; and <code>CERTINFO</code>, where only
/// that type carries the fields.</p>
Parameter ROWGETTYPES = "GET,INFO,CERTINFO";

/// <p>What is wrong with <var>pSource</var>'s <code>rowGet</code>, or <code>""</code> (AD-36).
/// <var>pFields</var> is the read's declared fields.</p>
/// <p>An absent or <code>null</code> <code>rowGet</code> declares no detail call. Otherwise it is an
/// object carrying only <code>key</code> (one of <var>pFields</var>), <code>param</code> (a query
/// parameter name), an optional <code>type</code> (one of <parameter>ROWGETTYPES</parameter>, spelled
/// exactly; absent means <code>GET</code>), <code>fields</code> (a non-empty array of unique names
/// from <var>pFields</var>, without <code>key</code>) and <code>derived</code>, an array of objects
/// carrying only <code>field</code> (one of <var>pFields</var>, neither <code>key</code> nor a detail
/// field, and not repeated), <code>rule</code> (one of <parameter>ROWGETRULES</parameter>) and
/// <code>from</code> (one of the detail fields). <file>ui/tools/screen-mirror.mjs</file>'s
/// <code>rowGetProblem</code> returns the same sentence for every case in
/// <class>OcuPilot.Test.RowGetCorpus</class>.</p>
ClassMethod RowGetProblem(pSource As %DynamicObject, pFields As %List) As %String
{
    Set tWhere = "read.source.rowGet"
    Set tType = pSource.%GetTypeOf("rowGet")
    If (tType = "unassigned") || (tType = "null") Quit ""
    If tType '= "object" Quit tWhere _ " is not an object declaring its key, param, fields and derived (AD-36)"
    Set tRowGet = pSource.%Get("rowGet")
    Set tProblem = ..UnknownKeyProblem(tRowGet, tWhere, $ListBuild("key", "param", "type", "fields", "derived"))
    If tProblem '= "" Quit tProblem

    If tRowGet.%GetTypeOf("key") '= "string" Quit tWhere _ ".key is not a string"
    Set tKey = tRowGet.%Get("key")
    If '$ListFind(pFields, tKey) Quit tWhere _ ".key '" _ tKey _ "' is not one of read.fields"
    If tRowGet.%GetTypeOf("param") '= "string" Quit tWhere _ ".param is not a string"
    If '$Match(tRowGet.%Get("param"), "^[A-Za-z][A-Za-z0-9]*$") Quit tWhere _ ".param '" _ tRowGet.%Get("param") _ "' is not a query parameter name"
    If tRowGet.%GetTypeOf("type") '= "unassigned" {
        If (tRowGet.%GetTypeOf("type") '= "string") || '$ListFind($ListFromString(..#ROWGETTYPES), tRowGet.%Get("type")) {
            Quit tWhere _ ".type '" _ tRowGet.%Get("type") _ "' is not one of " _ ..#ROWGETTYPES _ ", the detail types a per-row call issues (AD-36)"
        }
    }

    Set tProblem = ..NameArrayProblem(tRowGet, "fields", pFields, .tDetail)
    If tProblem '= "" Quit tWhere _ "." _ tProblem
    If $ListLength(tDetail) = 0 Quit tWhere _ ".fields is empty, and a detail call merges at least one field (AD-36)"
    If $ListFind(tDetail, tKey) Quit tWhere _ ".fields names the key field '" _ tKey _ "', which the list row already carries"

    If tRowGet.%GetTypeOf("derived") '= "array" Quit tWhere _ ".derived is not an array of derived fields"
    Set tSeen = ""
    Set tIterator = tRowGet.%Get("derived").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry, .tEntryType) {
        Set tAt = tWhere _ ".derived entry #" _ (tIndex + 1)
        If tEntryType '= "object" {
            Set tProblem = tAt _ " is not an object declaring its field, rule and from"
            Quit
        }
        Set tProblem = ..UnknownKeyProblem(tEntry, tAt, $ListBuild("field", "rule", "from"))
        If tProblem '= "" Quit
        If tEntry.%GetTypeOf("field") '= "string" {
            Set tProblem = tAt _ " field is not a string"
            Quit
        }
        Set tField = tEntry.%Get("field")
        If '$ListFind(pFields, tField) {
            Set tProblem = tAt _ " field '" _ tField _ "' is not one of read.fields"
            Quit
        }
        If tField = tKey {
            Set tProblem = tAt _ " field '" _ tField _ "' is the key field"
            Quit
        }
        If $ListFind(tDetail, tField) {
            Set tProblem = tAt _ " field '" _ tField _ "' is also a detail field, whose value the detail call supplies"
            Quit
        }
        If $ListFind(tSeen, tField) {
            Set tProblem = tAt _ " names the field '" _ tField _ "' twice"
            Quit
        }
        Set tSeen = tSeen _ $ListBuild(tField)
        If tEntry.%GetTypeOf("rule") '= "string" {
            Set tProblem = tAt _ " rule is not a string"
            Quit
        }
        If '$ListFind($ListFromString(..#ROWGETRULES), tEntry.%Get("rule")) {
            Set tProblem = tAt _ " rule '" _ tEntry.%Get("rule") _ "' is not one of " _ ..#ROWGETRULES
            Quit
        }
        If tEntry.%GetTypeOf("from") '= "string" {
            Set tProblem = tAt _ " from is not a string"
            Quit
        }
        If '$ListFind(tDetail, tEntry.%Get("from")) {
            Set tProblem = tAt _ " from '" _ tEntry.%Get("from") _ "' is not one of read.source.rowGet.fields"
            Quit
        }
    }
    Quit tProblem
}

/// <p>The kinds a table column may declare (AD-5).</p>
Parameter TABLECOLUMNKINDS = "name,identifier,text,number,status";

/// <p>What is wrong with a read-declaring <var>pDeclaration</var>'s <code>table</code>, or
/// <code>""</code>. <var>pFields</var> is the read's declared fields and <var>pSecrets</var> its
/// <code>context.secretFields</code>.</p>
/// <p><code>table</code> is an object carrying only <code>columns</code>, <code>emptyNextKey</code>
/// and <code>emptyAgentKey</code>. <code>columns</code> is non-empty; each column carries only
/// <code>field</code> (one of <var>pFields</var>, none of <var>pSecrets</var>, unique across
/// columns), a non-empty
/// <code>labelKey</code>, a <code>kind</code> from <parameter>TABLECOLUMNKINDS</parameter> and an
/// optional <code>emptyKey</code> (a non-empty string key an empty cell in that column reads
/// instead of "(none)"), and exactly one column is <code>name</code>. The declaration names a non-empty
/// <code>emptyStateKey</code>, and a <code>composite</code> id names only parts in <var>pFields</var>.
/// A write-capable declaration (<method>IsWriteCapable</method>) names <code>emptyAgentKey</code>
/// and leaves <code>emptyNextKey</code> empty; any other names <code>emptyNextKey</code> and leaves
/// <code>emptyAgentKey</code> empty.</p>
ClassMethod TableProblem(pDeclaration As %DynamicObject, pFields As %List, pSecrets As %List) As %String [ Private ]
{
    If pDeclaration.%GetTypeOf("table") '= "object" Quit "table is not an object, and a declaration with a read declares its table's columns and empty-state keys (AD-5)"
    Set tTable = pDeclaration.%Get("table")
    Set tProblem = ..UnknownKeyProblem(tTable, "table", $ListBuild("columns", "emptyNextKey", "emptyAgentKey"))
    If tProblem '= "" Quit tProblem
    If tTable.%GetTypeOf("columns") '= "array" Quit "table.columns is not an array of columns"
    If tTable.%Get("columns").%Size() = 0 Quit "table.columns is empty, and a table shows at least one column"

    Set tKinds = $ListFromString(..#TABLECOLUMNKINDS)
    Set tSeen = ""
    Set tNames = 0
    Set tIterator = tTable.%Get("columns").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn, .tColumnType) {
        Set tWhere = "table.columns entry #" _ (tIndex + 1)
        If tColumnType '= "object" {
            Set tProblem = tWhere _ " is not an object declaring its field, labelKey and kind"
            Quit
        }
        Set tProblem = ..UnknownKeyProblem(tColumn, tWhere, $ListBuild("field", "labelKey", "kind", "emptyKey"))
        If tProblem '= "" Quit
        Set tField = tColumn.%Get("field")
        If (tColumn.%GetTypeOf("field") '= "string") || '$ListFind(pFields, tField) {
            Set tProblem = tWhere _ " field '" _ tField _ "' is not one of read.fields"
            Quit
        }
        If $ListFind(pSecrets, tField) {
            Set tProblem = tWhere _ " field '" _ tField _ "' is a secret field, and a secret is never returned to a screen (Conventions, Secrets)"
            Quit
        }
        If $ListFind(tSeen, tField) {
            Set tProblem = tWhere _ " names the field '" _ tField _ "' twice"
            Quit
        }
        Set tSeen = tSeen _ $ListBuild(tField)
        If (tColumn.%GetTypeOf("labelKey") '= "string") || (tColumn.%Get("labelKey") = "") {
            Set tProblem = tWhere _ " labelKey is empty, and a column header names a string key"
            Quit
        }
        Set tKind = tColumn.%Get("kind")
        If (tColumn.%GetTypeOf("kind") '= "string") || '$ListFind(tKinds, tKind) {
            Set tProblem = tWhere _ " kind '" _ tKind _ "' is not one of " _ ..#TABLECOLUMNKINDS
            Quit
        }
        If (tColumn.%GetTypeOf("emptyKey") '= "unassigned") && ((tColumn.%GetTypeOf("emptyKey") '= "string") || (tColumn.%Get("emptyKey") = "")) {
            Set tProblem = tWhere _ " emptyKey is not a non-empty string key, and an empty cell in that column reads the string it names"
            Quit
        }
        If tKind = "name" Set tNames = tNames + 1
    }
    If tProblem '= "" Quit tProblem
    If tNames '= 1 Quit "table.columns declares " _ tNames _ " name column(s), and exactly one column is the row's name"

    If (pDeclaration.%GetTypeOf("emptyStateKey") '= "string") || (pDeclaration.%Get("emptyStateKey") = "") Quit "emptyStateKey is empty, and a declaration with a read names its empty-state sentence"

    If (pDeclaration.%GetTypeOf("id") = "object") && (pDeclaration.%Get("id").%Get("kind") = "composite") && (pDeclaration.%Get("id").%GetTypeOf("parts") = "array") {
        Set tParts = pDeclaration.%Get("id").%Get("parts").%GetIterator()
        While tParts.%GetNext(.tIndex, .tPart) {
            If '$ListFind(pFields, tPart) {
                Set tProblem = "id.parts names '" _ tPart _ "', which is not one of read.fields, so a row's key could not be read from it"
                Quit
            }
        }
        If tProblem '= "" Quit tProblem
    }

    For tKey = "emptyNextKey", "emptyAgentKey" {
        If tTable.%GetTypeOf(tKey) '= "string" {
            Set tProblem = "table." _ tKey _ " is not a string key"
            Quit
        }
    }
    If tProblem '= "" Quit tProblem
    Set tNext = tTable.%Get("emptyNextKey")
    Set tAgent = tTable.%Get("emptyAgentKey")
    If ..IsWriteCapable(pDeclaration) {
        If tNext '= "" Quit "table.emptyNextKey is declared on a write-capable descriptor, whose empty state invites the agent instead"
        If tAgent = "" Quit "table.emptyAgentKey is empty on a write-capable descriptor, whose empty state invites the agent"
    } Else {
        If tAgent '= "" Quit "table.emptyAgentKey is declared on a descriptor with no primary or row action, which has no write to invite"
        If tNext = "" Quit "table.emptyNextKey is empty, and a read-only empty state says what to do next"
    }
    Quit ""
}

/// <p>Whether <var>pDeclaration</var> declares a primary action or at least one row action.</p>
ClassMethod IsWriteCapable(pDeclaration As %DynamicObject) As %Boolean [ Private ]
{
    If (pDeclaration.%GetTypeOf("primaryAction") = "object") && (pDeclaration.%Get("primaryAction").%Get("id") '= "") Quit 1
    If pDeclaration.%GetTypeOf("rowActions") '= "array" Quit 0
    Set tFound = 0
    Set tIterator = pDeclaration.%Get("rowActions").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAction) {
        If $IsObject(tAction) && (tAction.%Get("id") '= "") {
            Set tFound = 1
            Quit
        }
    }
    Quit tFound
}

/// <p>What is wrong with <var>pParent</var>'s array <var>pKey</var>, or <code>""</code>. It must
/// be an array of unique non-empty strings; when <var>pAllowed</var> is non-empty every name must
/// be in it. <var>pNames</var> is the names read, as a <class>%List</class>.</p>
ClassMethod NameArrayProblem(pParent As %DynamicObject, pKey As %String, pAllowed As %List, Output pNames As %List) As %String [ Private ]
{
    Set pNames = ""
    If pParent.%GetTypeOf(pKey) '= "array" Quit pKey _ " is not an array of field names"
    Set tProblem = ""
    Set tIterator = pParent.%Get(pKey).%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName, .tType) {
        If (tType '= "string") || (tName = "") {
            Set tProblem = pKey _ " entry #" _ (tIndex + 1) _ " is not a field name"
            Quit
        }
        If $ListFind(pNames, tName) {
            Set tProblem = pKey _ " names '" _ tName _ "' twice"
            Quit
        }
        If (pAllowed '= "") && '$ListFind(pAllowed, tName) {
            Set tProblem = pKey _ " names '" _ tName _ "', which is not one of read.fields"
            Quit
        }
        Set pNames = pNames _ $ListBuild(tName)
    }
    If tProblem '= "" Set pNames = ""
    Quit tProblem
}

/// <p>A refusal naming the first key of <var>pObject</var> outside <var>pAllowed</var>, or
/// <code>""</code>.</p>
ClassMethod UnknownKeyProblem(pObject As %DynamicObject, pWhere As %String, pAllowed As %List) As %String [ Private ]
{
    Set tProblem = ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind(pAllowed, tKey) Continue
        Set tProblem = pWhere _ " declares the unknown key '" _ tKey _ "'"
        Quit
    }
    Quit tProblem
}

/// <p>A refusal naming the first of <var>pNames</var> that is also secret, or <code>""</code>.</p>
ClassMethod SecretOverlap(pWhere As %String, pNames As %List, pSecrets As %List) As %String [ Private ]
{
    Set tProblem = ""
    For tI = 1:1:$ListLength(pNames) {
        Set tName = $List(pNames, tI)
        If '$ListFind(pSecrets, tName) Continue
        Set tProblem = pWhere _ " names the secret field '" _ tName _ "', and a filter or sort over a secret field would let a tool probe its value (AD-24)"
        Quit
    }
    Quit tProblem
}

/// <p>What is wrong with <var>pDeclaration</var>'s archetype and classic link-out, or
/// <code>""</code> when nothing is (AD-44). <var>pDeclaration</var> is the whole parsed
/// declaration.</p>
/// <p>The archetype must be one <class>OcuPilot.Screen.Archetype</class> declares, and
/// <code>classicLinkExemption.exempt</code>, when declared, is a JSON boolean; an absent one reads
/// as false. An exemption is permitted only on an archetype that class classifies
/// <code>detail</code>, and it must carry a reason, the classic page's own name as its label, a
/// root-relative same-origin href, and a <code>classicPage</code> to be an exemption from. A screen
/// that declares no exemption carries no link parts either -- a label or an href with
/// <code>exempt</code> false is a half-made declaration whose other half a later edit would supply
/// silently.</p>
/// <p><b>The href is refused unless it is root-relative.</b> A descriptor is not an egress
/// primitive (AD-47): an absolute, protocol-relative or traversing target would let the
/// declaration choose a host, which is the one thing the origin boundary exists to stop.</p>
/// <p>A complete exemption may also declare a <code>rowLink</code>, which
/// <method>RowLinkProblem</method> checks; with <code>exempt</code> false it is a half-made
/// declaration like a label or an href.</p>
/// <p><file>ui/tools/classic-links.mjs</file>'s <code>classicLinkProblem</code> returns the same
/// sentence for every case in <class>OcuPilot.Test.ClassicLinkCorpus</class>.</p>
ClassMethod ClassicLinkProblem(pDeclaration As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        Set tArchetype = pDeclaration.%Get("archetype")
        Set tClassicPage = pDeclaration.%Get("classicPage")
        Set tExemption = {}
        If pDeclaration.%GetTypeOf("classicLinkExemption") = "object" Set tExemption = pDeclaration.%Get("classicLinkExemption")
        If '##class(OcuPilot.Screen.Archetype).Exists(tArchetype) {
            Set tProblem = "archetype """ _ tArchetype _ """ is not one OcuPilot.Screen.Archetype declares (AD-44)"
            Quit
        }
        Set tExemptType = tExemption.%GetTypeOf("exempt")
        If (tExemptType '= "unassigned") && (tExemptType '= "boolean") {
            Set tProblem = "classicLinkExemption.exempt is not a JSON boolean; declare true or false (AD-44)"
            Quit
        }
        Set tExempt = (tExemptType = "boolean") && tExemption.%Get("exempt")
        Set tReason = tExemption.%Get("reason")
        Set tLabel = tExemption.%Get("label")
        Set tHref = tExemption.%Get("href")
        Set tRowLinkType = tExemption.%GetTypeOf("rowLink")
        Set tHasRowLink = (tRowLinkType '= "unassigned") && (tRowLinkType '= "null")
        If 'tExempt {
            If tHref '= "" {
                Set tProblem = "classicLinkExemption declares an href while exempt is false; link parts without an exemption are a half-made declaration"
                Quit
            }
            If tLabel '= "" {
                Set tProblem = "classicLinkExemption declares a label while exempt is false; link parts without an exemption are a half-made declaration"
                Quit
            }
            If tHasRowLink {
                Set tProblem = "classicLinkExemption declares a rowLink while exempt is false; link parts without an exemption are a half-made declaration"
                Quit
            }
            Quit
        }
        If '##class(OcuPilot.Screen.Archetype).MayLinkOut(tArchetype) {
            Set tProblem = "archetype """ _ tArchetype _ """ declares a classicLinkExemption, and only a detail archetype may (AD-44)"
            Quit
        }
        If tReason = "" {
            Set tProblem = "classicLinkExemption declares exempt with no reason, and the check reports the reason of every exemption it honors (AD-44)"
            Quit
        }
        If tClassicPage = "" {
            Set tProblem = "classicLinkExemption declares exempt while classicPage is empty; a screen with no classic equivalent has nothing to link out to"
            Quit
        }
        If tLabel = "" {
            Set tProblem = "classicLinkExemption declares exempt with no label, and the card's action names the classic page it opens"
            Quit
        }
        Set tProblem = ..ClassicHrefProblem(tHref)
        If (tProblem '= "") || 'tHasRowLink Quit
        Set tProblem = ..RowLinkProblem(pDeclaration, tExemption)
    } Catch ex {
        Set tProblem = "the classic link declaration could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>What is wrong with a complete exemption's declared <code>rowLink</code>, or <code>""</code>
/// (AD-44, AD-47). <var>pExemption</var> is <var>pDeclaration</var>'s
/// <code>classicLinkExemption</code>.</p>
/// <p>A row link turns each row's name cell into the exemption's <code>href</code> with the declared
/// params appended from that row, so it is declared only on a screen with a read. It is an object
/// carrying only <code>params</code>, an array of objects carrying only <code>name</code> (a query
/// parameter name, declared once) and <code>field</code> (one of <code>read.fields</code>, never one
/// of <code>context.secretFields</code>).</p>
ClassMethod RowLinkProblem(pDeclaration As %DynamicObject, pExemption As %DynamicObject) As %String [ Private ]
{
    Set tWhere = "classicLinkExemption.rowLink"
    If pDeclaration.%GetTypeOf("read") '= "object" Quit tWhere _ " is declared on a screen with no read, and a row link reads its values from the read's rows (AD-44)"
    If pExemption.%GetTypeOf("rowLink") '= "object" Quit tWhere _ " is not an object declaring its params (AD-44)"
    Set tRowLink = pExemption.%Get("rowLink")
    Set tProblem = ..UnknownKeyProblem(tRowLink, tWhere, $ListBuild("params"))
    If tProblem '= "" Quit tProblem
    If tRowLink.%GetTypeOf("params") '= "array" Quit tWhere _ ".params is not an array of row link params"
    Set tFields = ""
    Set tRead = pDeclaration.%Get("read")
    If tRead.%GetTypeOf("fields") = "array" {
        Set tIterator = tRead.%Get("fields").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) { Set tFields = tFields _ $ListBuild(tName) }
    }
    Set tSecrets = ""
    If (pDeclaration.%GetTypeOf("context") = "object") && (pDeclaration.%Get("context").%GetTypeOf("secretFields") = "array") {
        Set tIterator = pDeclaration.%Get("context").%Get("secretFields").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) { Set tSecrets = tSecrets _ $ListBuild(tName) }
    }
    Set tSeen = ""
    Set tIterator = tRowLink.%Get("params").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tParam, .tParamType) {
        Set tAt = tWhere _ ".params entry #" _ (tIndex + 1)
        If tParamType '= "object" {
            Set tProblem = tAt _ " is not an object declaring its name and field"
            Quit
        }
        Set tProblem = ..UnknownKeyProblem(tParam, tAt, $ListBuild("name", "field"))
        If tProblem '= "" Quit
        Set tName = tParam.%Get("name")
        If (tParam.%GetTypeOf("name") '= "string") || '$Match(tName, "^[A-Za-z][A-Za-z0-9]*$") {
            Set tProblem = tAt _ " name '" _ tName _ "' is not a query parameter name"
            Quit
        }
        If $ListFind(tSeen, tName) {
            Set tProblem = tAt _ " names the param '" _ tName _ "' twice"
            Quit
        }
        Set tSeen = tSeen _ $ListBuild(tName)
        Set tField = tParam.%Get("field")
        If (tParam.%GetTypeOf("field") '= "string") || '$ListFind(tFields, tField) {
            Set tProblem = tAt _ " field '" _ tField _ "' is not one of read.fields"
            Quit
        }
        If $ListFind(tSecrets, tField) {
            Set tProblem = tAt _ " field '" _ tField _ "' is a secret field, and a secret never leaves the instance in a link (AD-35)"
            Quit
        }
    }
    Quit tProblem
}

/// <p>What is wrong with an exemption's declared href, or <code>""</code> when nothing is. It
/// must be a root-relative path on this instance: one leading <code>/</code>, no second one
/// (a protocol-relative URL names another host), no <code>..</code> segment, and nothing
/// outside the characters a URL path, query and fragment are spelled with -- which excludes a
/// scheme's colon-slash-slash, a backslash and any whitespace.</p>
ClassMethod ClassicHrefProblem(pHref As %String) As %String
{
    If pHref = "" Quit "classicLinkExemption declares exempt with no href, and no URL is ever derived from classicPage (AD-44)"
    If $Extract(pHref, 1, 2) = "//" Quit "classicLinkExemption href """ _ pHref _ """ is protocol-relative, which names another origin (AD-47)"
    If pHref [ ".." Quit "classicLinkExemption href """ _ pHref _ """ traverses, and a descriptor is not an egress primitive (AD-47)"
    If '$Match(pHref, "^/[A-Za-z0-9._~%!$&'()*+,;=:@/?#-]*$") Quit "classicLinkExemption href """ _ pHref _ """ is not a root-relative same-origin path (AD-47)"
    Quit ""
}

/// <p>The 1-based position of the first declared privilege entry missing a resource or a
/// permission, as <code>#n</code>, or <code>""</code> when every entry carries both.</p>
/// <p>An entry that is not an object counts as malformed too: <class>OcuPilot.Screen.Area</class>'s
/// <method>PairsFrom</method> skips it, so it would otherwise declare a gate and produce
/// none.</p>
ClassMethod MalformedPair(pDeclared As %DynamicArray) As %String [ Private ]
{
    Set tBad = ""
    If '$IsObject(pDeclared) Quit tBad
    Set tIterator = pDeclared.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPair) {
        If '$IsObject(tPair) || (tPair.%Get("resource") = "") || (tPair.%Get("permission") = "") {
            Set tBad = "#" _ (tIndex + 1)
            Quit
        }
    }
    Quit tBad
}

/// <p>The descriptor classes declared for <var>pAreaKey</var>, ordered by side-bar position
/// then class name. <var>pBuiltOnly</var> drops the screens that do not exist yet, which is
/// what a side bar lists.</p>
ClassMethod ScreensForArea(pAreaKey As %String, pBuiltOnly As %Boolean = 1, Output pList As %List) As %Status
{
    Set tSC = $$$OK
    Set pList = ""
    Try {
        Set tSC = ..Descriptors(.tAll)
        If $$$ISERR(tSC) Quit
        Kill tOrdered
        For tI = 1:1:$ListLength(tAll) {
            Set tClass = $List(tAll, tI)
            If $ClassMethod(tClass, "AreaKey") '= pAreaKey Continue
            If pBuiltOnly && '$ClassMethod(tClass, "IsBuilt") Continue
            Set tOrdered(+$ClassMethod(tClass, "SideBarPosition"), tClass) = ""
        }
        Set tPosition = ""
        For {
            Set tPosition = $Order(tOrdered(tPosition))
            If tPosition = "" Quit
            Set tClass = ""
            For {
                Set tClass = $Order(tOrdered(tPosition, tClass))
                If tClass = "" Quit
                Set pList = pList _ $ListBuild(tClass)
            }
        }
    } Catch ex {
        Set pList = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The ordered area-to-screen roster: a <class>%DynamicArray</class> of areas in rail order,
/// each carrying its declared fields and its built screens in side-bar order. This is what
/// <class>OcuPilot.Api.Navigation</class> gates and serves, and what the client mirror is the
/// browser-side copy of.</p>
ClassMethod Roster(Output pRoster As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pRoster = ""
    Try {
        Set tSC = ##class(OcuPilot.Screen.Area).List(.tAreas)
        If $$$ISERR(tSC) Quit
        Set pRoster = []
        Kill tByPosition
        Set tIterator = tAreas.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tArea) {
            Set tByPosition(+tArea.railPosition, tArea.key) = tIndex
        }
        Set tPosition = ""
        For {
            Set tPosition = $Order(tByPosition(tPosition))
            If tPosition = "" Quit
            Set tKey = ""
            For {
                Set tKey = $Order(tByPosition(tPosition, tKey))
                If tKey = "" Quit
                Set tArea = tAreas.%Get(tByPosition(tPosition, tKey))
                Set tEntry = {}
                Do tEntry.%Set("key", tArea.key)
                Do tEntry.%Set("railPosition", +tArea.railPosition, "number")
                Do tEntry.%Set("labelKey", tArea.labelKey)
                Do tEntry.%Set("navigates", ''tArea.navigates, "boolean")
                Do tEntry.%Set("pinBottom", ''tArea.pinBottom, "boolean")
                Set tScreens = []
                Set tSubSC = ..ScreensForArea(tArea.key, 1, .tClasses)
                If $$$ISERR(tSubSC) {
                    Set tSC = tSubSC
                    Quit
                }
                For tI = 1:1:$ListLength(tClasses) {
                    Set tClass = $List(tClasses, tI)
                    Set tScreen = {}
                    Do tScreen.%Set("descriptor", tClass)
                    Do tScreen.%Set("route", $ClassMethod(tClass, "Route"))
                    Do tScreen.%Set("labelKey", $ClassMethod(tClass, "LabelKey"))
                    Do tScreen.%Set("sideBarPosition", +$ClassMethod(tClass, "SideBarPosition"), "number")
                    Do tScreens.%Push(tScreen)
                }
                Do tEntry.%Set("screens", tScreens)
                Do pRoster.%Push(tEntry)
            }
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set pRoster = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The descriptor class whose <code>toolIdentifier</code> is <var>pToolIdentifier</var>, or
/// <code>""</code>. The identifier is compared as declared, never derived from a route.</p>
ClassMethod DescriptorForTool(pToolIdentifier As %String) As %String
{
    Set tFound = ""
    Try {
        If pToolIdentifier = "" Quit
        Set tSC = ..Descriptors(.tList)
        If $$$ISERR(tSC) Quit
        For tI = 1:1:$ListLength(tList) {
            Set tClass = $List(tList, tI)
            If $ClassMethod(tClass, "ToolIdentifier") = pToolIdentifier {
                Set tFound = tClass
                Quit
            }
        }
    } Catch {
        Set tFound = ""
    }
    Quit tFound
}

/// <p>The descriptor class declared at <var>pRoute</var>, or <code>""</code>. The route is the
/// declared value, not a URL: Home's is the empty string.</p>
ClassMethod DescriptorForRoute(pRoute As %String) As %String
{
    Set tFound = ""
    Try {
        Set tSC = ..Descriptors(.tList)
        If $$$ISERR(tSC) Quit
        For tI = 1:1:$ListLength(tList) {
            Set tClass = $List(tList, tI)
            If $ClassMethod(tClass, "Route") = pRoute {
                Set tFound = tClass
                Quit
            }
        }
    } Catch {
        Set tFound = ""
    }
    Quit tFound
}

}
