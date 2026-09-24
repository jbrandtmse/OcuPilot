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
/// <method>TabProblem</method>), whose <code>rowTarget</code> is not the declared grammar (AD-5,
/// <method>RowTargetProblem</method>), or whose route or tool identifier collides with
/// another's; and, over the whole roster, whose tab groups do not fit together
/// (<method>TabGroupProblem</method>) and whose <code>rowTarget</code> does not resolve
/// (<method>RowTargetResolutionProblem</method>). For both the
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
            ; AD-3, AD-6: the confirm channel is closed to all but the fields the descriptor
            ; declares secret, and the fingerprint's exclusions are the descriptor's too. Refused
            ; where they are declared, after the read and its criteria are known sound, because
            ; both lists are read against them.
            Set tConfirmProblem = ..ConfirmChannelProblem(tObject)
            If tConfirmProblem '= "" {
                Set pProblem = tClass _ ": " _ tConfirmProblem
                Quit
            }
            ; AD-5, AD-14: the entity-type vocabulary is the kernel's closed enum and the singular
            ; noun over it is a descriptor declaration, so a noun declared for no entity type is
            ; refused where it is declared rather than resolving to nothing in a card title.
            Set tEntityLabelProblem = ..EntityLabelProblem(tObject)
            If tEntityLabelProblem '= "" {
                Set pProblem = tClass _ ": " _ tEntityLabelProblem
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
            ; Story 11.3's contract: a screen's suggested prompts are declared beside its command
            ; box aliases, validated here as the mirror validates them.
            Set tPromptsProblem = ..SuggestedPromptsProblem(tObject)
            If tPromptsProblem '= "" {
                Set pProblem = tClass _ ": " _ tPromptsProblem
                Quit
            }
            ; AD-5, Story 6.10: a list's one declared cross-screen row target. The roster-wide
            ; half (whether the named route resolves) runs later, once every entry's own shape is
            ; known sound.
            Set tRowTargetProblem = ..RowTargetProblem(tObject)
            If tRowTargetProblem '= "" {
                Set pProblem = tClass _ ": " _ tRowTargetProblem
                Quit
            }
            ; AD-5, AD-53: a declared action's self-protection rule is drawn by the client from a
            ; closed vocabulary both sides read, so a rule neither understands is refused where it
            ; is declared rather than rendered as a word in a row menu.
            Set tActionProblem = ..ActionProblem(tObject)
            If tActionProblem '= "" {
                Set pProblem = tClass _ ": " _ tActionProblem
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
        ; DW-1020: a sub-resource screen's route id names an entity of its parent's primary entity
        ; type (AD-5), resolved through parentScope -- so the parent it names has to exist, be
        ; built and carry an id for that resolution to answer anything. Checked last, over the
        ; whole roster, because a stale parentScope would otherwise be caught piecemeal by whatever
        ; rule happened to read it first.
        If (pProblem = "") && $$$ISOK(tSC) Set pProblem = ..ParentScopeResolutionProblem(tRoster)
        ; AD-5, Story 6.10: a declared rowTarget's route has to resolve to a built, id-keyed
        ; screen that does not already pair its own surface, which only the whole roster can say.
        If (pProblem = "") && $$$ISOK(tSC) Set pProblem = ..RowTargetResolutionProblem(tRoster)
    } Catch ex {
        Set pProblem = "the descriptor roster could not be validated: " _ ex.DisplayString()
        Set tSC = ex.AsStatus()
    }
    ; A problem is a refusal, not a report: the status carries it too, so a caller that checks
    ; only $$$ISERR cannot read an invalid roster as a valid one.
    If $$$ISOK(tSC) && (pProblem '= "") Set tSC = $$$ERROR($$$GeneralError, pProblem)
    Quit tSC
}

/// <p>What is wrong with <var>pDeclaration</var>'s <code>entityLabelKey</code>, or <code>""</code>
/// when nothing is (AD-5, AD-14).</p>
/// <p>The key is optional and names the client string key holding the <b>singular</b> noun for this
/// screen's primary entity type -- what a proposal card's title reads where the wire carries only
/// the type's slug and <code>labelKey</code> is the plural screen label. Declared empty, or absent,
/// means this screen publishes no noun yet.</p>
/// <p>A noun declared where no <code>entityType</code> is declared is refused: it names a label for
/// nothing, and the card would resolve a title with an empty noun in it rather than fail.</p>
/// <p><file>ui/tools/screen-mirror.mjs</file>'s <code>entityLabelProblem</code> returns the same
/// sentences.</p>
/// <p><b>Public and value-driven</b> for the reason <method>RefreshProblem</method> is.</p>
ClassMethod EntityLabelProblem(pDeclaration As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        If '$IsObject(pDeclaration) Quit
        If pDeclaration.%GetTypeOf("entityLabelKey") = "unassigned" Quit
        If pDeclaration.%GetTypeOf("entityLabelKey") '= "string" {
            Set tProblem = "entityLabelKey is not a string key"
            Quit
        }
        If pDeclaration.%Get("entityLabelKey") = "" Quit
        If $Select(pDeclaration.%GetTypeOf("entityType") = "string": pDeclaration.%Get("entityType"), 1: "") = "" {
            Set tProblem = "entityLabelKey names the singular noun for this screen's entity type, and none is declared"
            Quit
        }
    } Catch ex {
        Set tProblem = "the entity-label declaration could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>The keys a screen declaration may carry at its top level -- the whole vocabulary, in the
/// order <class>OcuPilot.Screen.Descriptor.Base</class> reads them (AD-5).</p>
/// <p>Ten are optional and the rest are not, but this parameter says nothing about which:
/// <method>DeclarationProblem</method> is an <b>unknown-key</b> check, never a presence check. A
/// declaration missing an optional key -- <code>refreshes</code>, <code>refreshRates</code>,
/// <code>read</code>, <code>table</code>, <code>banner</code>, <code>tab</code>,
/// <code>rowTarget</code>, <code>secretArguments</code>, <code>fingerprintExcludes</code>,
/// <code>entityLabelKey</code> -- is sound, and a declaration missing a required one is already
/// refused by the rule that reads it, with a sentence naming what it was for.</p>
Parameter DECLARATIONKEYS = "route,area,labelKey,sideBarPosition,archetype,built,refreshes,refreshRates,privileges,entityType,entityLabelKey,secondaryEntityTypes,scope,parentScope,id,context,secretArguments,fingerprintExcludes,primaryAction,rowActions,emptyStateKey,commandAliases,suggestedPrompts,classicPage,classicLinkExemption,read,table,banner,tab,toolIdentifier,rowTarget";

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

/// <p>What is wrong with <var>pDeclaration</var>'s <code>suggestedPrompts</code>, or
/// <code>""</code> (Story 11.3). Absent or <code>null</code> declares none. Otherwise it is an array
/// of at least <parameter>SUGGESTEDPROMPTSMIN</parameter> objects, each carrying only
/// <code>groupKey</code> and <code>textKey</code>, both non-empty string keys. That each key
/// resolves is the build's check, over the string source this class cannot read.
/// <file>ui/tools/screen-mirror.mjs</file>'s <code>suggestedPromptsProblem</code> returns the same
/// sentence for every case.</p>
ClassMethod SuggestedPromptsProblem(pDeclaration As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        If '$IsObject(pDeclaration) {
            Set tProblem = "the declaration is not an object"
            Quit
        }
        Set tType = pDeclaration.%GetTypeOf("suggestedPrompts")
        If (tType = "unassigned") || (tType = "null") Quit
        If tType '= "array" {
            Set tProblem = "suggestedPrompts is not an array of prompts"
            Quit
        }
        Set tPrompts = pDeclaration.%Get("suggestedPrompts")
        If tPrompts.%Size() < ..#SUGGESTEDPROMPTSMIN {
            Set tProblem = "suggestedPrompts declares " _ tPrompts.%Size() _ ", and a screen that declares prompts declares at least " _ ..#SUGGESTEDPROMPTSMIN
            Quit
        }
        Set tIterator = tPrompts.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tPrompt) {
            Set tWhere = "suggestedPrompts[" _ tIndex _ "]"
            If '$IsObject(tPrompt) || 'tPrompt.%IsA("%Library.DynamicObject") {
                Set tProblem = tWhere _ " is not an object declaring its groupKey and textKey"
                Quit
            }
            Set tProblem = ..UnknownKeyProblem(tPrompt, tWhere, $ListBuild("groupKey", "textKey"))
            If tProblem '= "" Quit
            For tKey = "groupKey", "textKey" {
                If (tPrompt.%GetTypeOf(tKey) '= "string") || (tPrompt.%Get(tKey) = "") {
                    Set tProblem = tWhere _ "." _ tKey _ " is empty, and a prompt names the string key it reads"
                    Quit
                }
            }
            If tProblem '= "" Quit
        }
    } Catch ex {
        Set tProblem = "the suggested prompts could not be read: " _ ex.DisplayString()
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
/// <parameter>READSOURCETYPES</parameter>. A <code>GET</code> source reads one object of an
/// <code>admin</code> endpoint and declares no <code>forEach</code>; it declares
/// <code>criteria</code> -- exactly one field, whose value the route id fills -- and a paired
/// <code>rowGet</code> keyed by that field's own <code>param</code> only when <code>parentScope</code>
/// names the route it is fetched under (Story 6.7), and refuses both otherwise. An
/// <code>UPCOMING</code> or <code>HISTORY</code> source lists an admin
/// endpoint's rows -- scheduled occurrences and task-run history respectively -- and declares no
/// <code>rowGet</code> or <code>forEach</code> either. A source's optional
/// <code>forEach</code> lists a parent endpoint first (<method>ForEachProblem</method>), and its
/// optional <code>query</code> fixes parameters no caller can change
/// (<method>SourceQueryProblem</method>). The source is one of three kinds:
/// <code>admin</code>, an instance endpoint reached through the port, with a
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
/// shape <method>TableProblem</method> checks, unless it is a <code>form-page</code> that declares none
/// (<method>RendersNoTable</method>); a <code>table</code> with no read is refused here.
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
        Set tProblem = ..UnknownKeyProblem(tSource, "read.source", $ListBuild("port", "endpoint", "type", "rowGet", "forEach", "query", "parts"))
        If tProblem '= "" Quit
        Set tPort = tSource.%Get("port")
        If (tSource.%GetTypeOf("port") '= "string") || '$ListFind($ListBuild(##class(OcuPilot.Screen.Read).#SOURCEADMIN, ##class(OcuPilot.Screen.Read).#SOURCESTATE, ##class(OcuPilot.Screen.Read).#SOURCEMGMNT, ##class(OcuPilot.Screen.Read).#SOURCELOGSOURCE), tPort) {
            Set tProblem = "read.source.port '" _ tPort _ "' is not one of '" _ ##class(OcuPilot.Screen.Read).#SOURCEADMIN _ "', '" _ ##class(OcuPilot.Screen.Read).#SOURCESTATE _ "', '" _ ##class(OcuPilot.Screen.Read).#SOURCEMGMNT _ "' or '" _ ##class(OcuPilot.Screen.Read).#SOURCELOGSOURCE _ "', the four sources a declared read names (AD-36)"
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
            Set tProblem = "read.source.type '" _ tSource.%Get("type") _ "' is not 'LIST', 'GET', 'UPCOMING', 'HISTORY' or 'VOLUMELIST'"
            Quit
        }
        ; A GET source reads one named object of an admin endpoint as the read's one row (AD-36), so
        ; it has no row list to issue a detail call for, no parents to list and no server search.
        If tSource.%Get("type") = "GET" {
            If tPort '= ##class(OcuPilot.Screen.Read).#SOURCEADMIN {
                Set tProblem = "read.source.type 'GET' is declared on a '" _ tPort _ "' source, and a single-object read issues an admin endpoint's GET (AD-36)"
                Quit
            }
            If tSource.%GetTypeOf("forEach") = "object" {
                Set tProblem = "read.source.forEach is declared on a GET source, which reads one object and lists no parents (AD-36)"
                Quit
            }
            ; Story 6.7: a single-object GET may take its one criterion from the route id, but only
            ; when parentScope names that route -- without one there is no id to fill it from, so
            ; the refusal below still stands for every other GET source.
            Set tGetParented = (pDeclaration.%GetTypeOf("parentScope") = "string") && (pDeclaration.%Get("parentScope") '= "")
            If (tRead.%GetTypeOf("criteria") = "object") && 'tGetParented {
                Set tProblem = "read.criteria is declared on a GET source with no parentScope, and a single-object read takes its one criterion from the route id only when parent-scoped (AD-36, Story 6.7)"
                Quit
            }
            ; A parent-scoped GET may pair its route-id criterion with one rowGet, keyed by that
            ; criterion's own param rather than by a list row's field (RowGetProblem, below). Every
            ; other GET keeps refusing rowGet outright, because it reads one object and has no
            ; per-row detail call to issue at all.
            If (tRead.%GetTypeOf("criteria") '= "object") && (tSource.%GetTypeOf("rowGet") = "object") {
                Set tProblem = "read.source.rowGet is declared on a GET source with no read.criteria, and a single-object read issues a detail call only alongside its one parent-scoped route-id criterion (AD-36, Story 6.7)"
                Quit
            }
        }
        ; An UPCOMING source lists an admin endpoint's scheduled occurrences (AD-36): a row is an
        ; occurrence rather than an object, so there is no detail call to issue and no parent to list.
        If tSource.%Get("type") = "UPCOMING" {
            If tPort '= ##class(OcuPilot.Screen.Read).#SOURCEADMIN {
                Set tProblem = "read.source.type 'UPCOMING' is declared on a '" _ tPort _ "' source, and a list-shaped request type other than LIST issues an admin endpoint (AD-36)"
                Quit
            }
            If tSource.%GetTypeOf("rowGet") = "object" {
                Set tProblem = "read.source.rowGet is declared on an UPCOMING source, whose rows are occurrences with no detail call to issue (AD-36)"
                Quit
            }
            If tSource.%GetTypeOf("forEach") = "object" {
                Set tProblem = "read.source.forEach is declared on an UPCOMING source, which lists no parents (AD-36)"
                Quit
            }
        }
        ; A HISTORY source lists an admin endpoint's task-run history (AD-36), Task.CRUD's own
        ; request type: a row is a run rather than an object, so there is no detail call to issue
        ; and no parent to list -- the same rules UPCOMING takes, for the same reason.
        If tSource.%Get("type") = "HISTORY" {
            If tPort '= ##class(OcuPilot.Screen.Read).#SOURCEADMIN {
                Set tProblem = "read.source.type 'HISTORY' is declared on a '" _ tPort _ "' source, and a list-shaped request type other than LIST issues an admin endpoint (AD-36)"
                Quit
            }
            If tSource.%GetTypeOf("rowGet") = "object" {
                Set tProblem = "read.source.rowGet is declared on a HISTORY source, whose rows are task runs with no detail call to issue (AD-36)"
                Quit
            }
            If tSource.%GetTypeOf("forEach") = "object" {
                Set tProblem = "read.source.forEach is declared on a HISTORY source, which lists no parents (AD-36)"
                Quit
            }
        }
        ; A VOLUMELIST source lists an admin endpoint's volume files (AD-36, Story 6.11):
        ; Database.SysCRUD's own request type, worded like the HISTORY arm above for the same
        ; reason -- a row is a volume file rather than an object, so there is no detail call to
        ; issue and no parent to list.
        If tSource.%Get("type") = "VOLUMELIST" {
            If tPort '= ##class(OcuPilot.Screen.Read).#SOURCEADMIN {
                Set tProblem = "read.source.type 'VOLUMELIST' is declared on a '" _ tPort _ "' source, and a list-shaped request type other than LIST issues an admin endpoint (AD-36)"
                Quit
            }
            If tSource.%GetTypeOf("rowGet") = "object" {
                Set tProblem = "read.source.rowGet is declared on a VOLUMELIST source, whose rows are volume files with no detail call to issue (AD-36)"
                Quit
            }
            If tSource.%GetTypeOf("forEach") = "object" {
                Set tProblem = "read.source.forEach is declared on a VOLUMELIST source, which lists no parents (AD-36)"
                Quit
            }
        }
        Set tProblem = ..SourceQueryProblem(tRead, tSource)
        If tProblem '= "" Quit
        ; A state source's rows are OcuPilot's own, read whole: there is no detail endpoint to
        ; issue per row and no vendor query to search on the server, so declaring either is
        ; refused where it is declared rather than ignored at read time (AD-36).
        ; A mgmnt source answers whole rows from the management API, which offers no per-row
        ; detail call to issue.
        If (tPort = ##class(OcuPilot.Screen.Read).#SOURCEMGMNT) && (tSource.%GetTypeOf("rowGet") = "object") {
            Set tProblem = "read.source.rowGet is declared on a mgmnt source, which reads whole rows from the management API and has no per-row detail call (AD-36)"
            Quit
        }
        ; A logsource source answers whole rows parsed from one log file's tail, which has no
        ; per-row detail call to issue: a log line is not an entity the instance can be asked for.
        If (tPort = ##class(OcuPilot.Screen.Read).#SOURCELOGSOURCE) && (tSource.%GetTypeOf("rowGet") = "object") {
            Set tProblem = "read.source.rowGet is declared on a logsource source, which reads whole rows from a log file's bounded tail and has no per-row detail call (AD-36)"
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
        ; Story 6.7: a parent-scoped GET's rowGet.key names the read's one route-id criterion
        ; rather than a read.fields entry -- the GET's own answer carries no such property -- so
        ; the allowed set is that one param exactly when the criteria block is sound enough to name
        ; it. A malformed criteria block still leaves this "", which falls back to checking key
        ; against read.fields and refuses there instead; either way the declaration is refused, and
        ; CriteriaProblem is what names the malformed block itself.
        Set tRowGetKeyAllowed = ""
        If (tSource.%Get("type") = "GET") && (tRead.%GetTypeOf("criteria") = "object") {
            Set tCritFields = tRead.%Get("criteria").%Get("fields")
            If $IsObject(tCritFields) && tCritFields.%IsA("%Library.DynamicArray") && (tCritFields.%Size() = 1) {
                Set tCritFirst = tCritFields.%Get(0)
                If $IsObject(tCritFirst) && (tCritFirst.%GetTypeOf("param") = "string") Set tRowGetKeyAllowed = $ListBuild(tCritFirst.%Get("param"))
            }
        }
        Set tProblem = ..RowGetProblem(tSource, tFields, tRowGetKeyAllowed)
        If tProblem '= "" Quit
        Set tProblem = ..ForEachProblem(tRead, tSource, tFields)
        If tProblem '= "" Quit
        ; AD-36 (Story 6.9): a single-object GET may also declare up to three parts, each
        ; answering one object merged into the read's one row as <as>.<member> fields.
        Set tProblem = ..PartsProblem(tRead, tSource, tFields)
        If tProblem '= "" Quit

        If pDeclaration.%GetTypeOf("context") '= "object" {
            Set tProblem = "context is not an object, and a screen that declares a read declares its secret fields (AD-24)"
            Quit
        }
        Set tContext = pDeclaration.%Get("context")
        Set tProblem = ..UnknownKeyProblem(tContext, "context", $ListBuild("fields", "secretFields", "maxLength"))
        If tProblem '= "" Quit
        Set tSecretProblem = ..NameArrayProblem(tContext, "secretFields", tFields, .tSecrets)
        If tSecretProblem '= "" {
            Set tProblem = "context." _ tSecretProblem
            Quit
        }
        Do ..NameArrayProblem(tContext, "fields", "", .tContextFields)
        Set tProblem = ..ContextMaxLengthProblem(tContext, tContextFields)
        If tProblem '= "" Quit

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

        If '..RendersNoTable(pDeclaration) {
            Set tProblem = ..TableProblem(pDeclaration, tFields, tSecrets)
            If tProblem '= "" Quit
        }

        ; The last arm, so no earlier refusal changes which sentence a declaration gets.
        ; OcuPilot.Port.AdminPort.RunSequence sets $NAMESPACE to %SYS for every request type with
        ; no predicate on the endpoint, and IRIS requires READ on a namespace's default globals
        ; database -- IRISSYS, resource %DB_IRISSYS -- to make it current. Without the pair the
        ; vendor endpoint fails inside %SYS and the port answers 500 where the gate would have
        ; named the missing privilege (AD-2, AD-8). A logsource read is outside the rule: it reads
        ; a file off disk and never enters %SYS.
        If tPort = ##class(OcuPilot.Screen.Read).#SOURCEADMIN {
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
/// kind -- <method>CriteriaMaxLengthProblem</method>), an optional <code>vendorParam</code> (a
/// query parameter name the value is sent to the vendor under instead of <code>param</code>, never
/// <code>maxRows</code> or <code>ns</code> and never another field's <code>param</code> or
/// <code>vendorParam</code> -- <method>CriteriaVendorParamProblem</method>, Story 6.6: this is how
/// Task history sends the vendor's own <code>filter</code>, a name
/// <parameter>CRITERIARESERVEDPARAMS</parameter> reserves for the tool), plus
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
/// <p><b>A server-search screen never auto-refreshes</b> (AD-43): it renders nothing until Search
/// is pressed, so a timer would have no rows to re-read and <file>EXPERIENCE.md</file> exempts it
/// by name.</p>
/// <p><b>A parent-scoped read declares exactly one criterion</b> (AD-5). A declaration with a
/// non-empty <code>parentScope</code> and a <code>read</code> is a sub-resource screen whose one
/// criterion the client fills from the route id, so a read declaring none, or more than one, is
/// refused with <method>ParentCriteriaProblem</method>'s sentence. Such a read runs when its page
/// opens, with no Search to press, and may still auto-refresh in place -- it takes its one value
/// from the route rather than from a search the user ran, so a timer has rows to re-read (Story
/// 6.7); a screen with a server-search criterion of its own still never does.</p>
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
        Set tProblem = ..CriteriaVendorParamProblem(tCriteria)
        If tProblem '= "" Quit
        Set tProblem = ..CriteriaMarkerProblem(tCriteria, tParams)
        If tProblem '= "" Quit
        If tParented && ($ListLength(tParams) '= 1) {
            Set tProblem = ..ParentCriteriaProblem(pDeclaration)
            Quit
        }

        ; The last arm, so no earlier refusal changes which sentence a declaration gets. A
        ; parent-scoped screen's only criterion is the route id rather than a server search --
        ; already confirmed above, since tParented reaching here means exactly one criterion -- so
        ; it may refresh in place (Story 6.7).
        If ''pDeclaration.%Get("refreshes") && 'tParented {
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
        Set tAllowed = $ListBuild("param", "labelKey", "kind", "maxLength", "vendorParam")
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

        ; Story 6.6: a criterion may send its value to the vendor under a declared name of its own,
        ; because the vendor's own name is reserved for the read's two callers (Task history sends
        ; `filter`, which CRITERIARESERVEDPARAMS reserves for the tool's own view argument). Only
        ; shape and the two names every read's own machinery sends are checked here; a collision
        ; with another field's param or vendorParam is checked once every field is known
        ; (CriteriaVendorParamProblem).
        If (tField.%GetTypeOf("vendorParam") '= "unassigned") {
            Set tVendorParam = tField.%Get("vendorParam")
            If (tField.%GetTypeOf("vendorParam") '= "string") || '$Match(tVendorParam, "^[A-Za-z][A-Za-z0-9]*$") {
                Set tProblem = tWhere _ " vendorParam '" _ tVendorParam _ "' is not a query parameter name"
                Quit
            }
            Set tVendorFolded = $ZConvert(tVendorParam, "L")
            If (tVendorFolded = "maxrows") || (tVendorFolded = "ns") {
                Set tProblem = tWhere _ " vendorParam '" _ tVendorParam _ "' collides with a name the read's own callers already send"
                Quit
            }
        }

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

/// <p>What is wrong with <var>pCriteria</var>'s declared <code>vendorParam</code>s taken together,
/// or <code>""</code> (Story 6.6). Each field's own shape is already sound
/// (<method>CriteriaFieldsProblem</method>); this is the one check that needs every field's name
/// known first -- a <code>vendorParam</code> may not equal, case-folded, another field's
/// <code>param</code> or <code>vendorParam</code>, because both values reach the same vendor query
/// and a collision would let one field's value silently overwrite another's.</p>
ClassMethod CriteriaVendorParamProblem(pCriteria As %DynamicObject) As %String [ Private ]
{
    Set tProblem = ""
    Try {
        Set tFields = pCriteria.%Get("fields")
        If '$IsObject(tFields) || 'tFields.%IsA("%Library.DynamicArray") Quit
        Set tOuter = tFields.%GetIterator()
        While tOuter.%GetNext(.tOuterIndex, .tOuterField) {
            If '$IsObject(tOuterField) Continue
            If tOuterField.%GetTypeOf("vendorParam") '= "string" Continue
            Set tVendorParam = tOuterField.%Get("vendorParam")
            If tVendorParam = "" Continue
            Set tVendorFolded = $ZConvert(tVendorParam, "L")
            Set tInner = tFields.%GetIterator()
            While tInner.%GetNext(.tInnerIndex, .tInnerField) {
                If tInnerIndex = tOuterIndex Continue
                If '$IsObject(tInnerField) Continue
                Set tOtherParam = tInnerField.%Get("param")
                If (tInnerField.%GetTypeOf("param") = "string") && (tOtherParam '= "") && ($ZConvert(tOtherParam, "L") = tVendorFolded) {
                    Set tProblem = "read.criteria.fields entry #" _ (tOuterIndex + 1) _ " vendorParam '" _ tVendorParam _ "' collides with another field's param or vendorParam"
                    Quit
                }
                If (tInnerField.%GetTypeOf("vendorParam") = "string") && (tInnerField.%Get("vendorParam") '= "") && ($ZConvert(tInnerField.%Get("vendorParam"), "L") = tVendorFolded) {
                    Set tProblem = "read.criteria.fields entry #" _ (tOuterIndex + 1) _ " vendorParam '" _ tVendorParam _ "' collides with another field's param or vendorParam"
                    Quit
                }
            }
            If tProblem '= "" Quit
        }
    } Catch ex {
        Set tProblem = "the vendorParam declarations could not be validated: " _ ex.DisplayString()
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
/// rows; <code>GET</code>, one object read as the read's one row; <code>UPCOMING</code>, an admin
/// endpoint's list of scheduled occurrences, issued as a list is; <code>HISTORY</code>,
/// <code>Task.CRUD</code>'s task-run history, issued the same way (Story 6.6); and
/// <code>VOLUMELIST</code>, <code>Database.SysCRUD</code>'s volume-file list, issued the same way
/// again (Story 6.11).</p>
Parameter READSOURCETYPES = "LIST,GET,UPCOMING,HISTORY,VOLUMELIST";

/// <p>The longest value a <code>read.source.query</code> entry may fix.</p>
Parameter SOURCEQUERYMAXLENGTH As INTEGER = 50;

/// <p>What is wrong with <var>pSource</var>'s <code>query</code>, or <code>""</code> (AD-36).
/// <var>pRead</var> is the declared read, whose <code>criteria</code> the keys are compared to.</p>
/// <p>An absent or <code>null</code> <code>query</code> fixes no parameter. Otherwise it is a
/// non-empty object on an <code>admin</code> source; each key is a query parameter name that equals,
/// case-folded, neither a <parameter>CRITERIARESERVEDPARAMS</parameter> name nor a declared
/// <code>read.criteria</code> field's <code>param</code> or <code>vendorParam</code>; and each value
/// is a non-empty string of at most
/// <parameter>SOURCEQUERYMAXLENGTH</parameter> characters.
/// <method>OcuPilot.Screen.Read.Execute</method> sends every entry on the read's <code>LIST</code>,
/// <code>UPCOMING</code> or <code>HISTORY</code> call, on a single-object <code>GET</code> and on each per-parent child list,
/// never on a per-parent read's parent list or a <code>rowGet</code> detail call, so no caller can
/// change or remove one. <file>ui/tools/screen-mirror.mjs</file>'s
/// <code>sourceQueryProblem</code> returns the same sentence for every case in
/// <class>OcuPilot.Test.ReadSourceCorpus</class>.</p>
ClassMethod SourceQueryProblem(pRead As %DynamicObject, pSource As %DynamicObject) As %String
{
    Set tWhere = "read.source.query"
    Set tType = pSource.%GetTypeOf("query")
    If (tType = "unassigned") || (tType = "null") Quit ""
    If tType '= "object" Quit tWhere _ " is not an object of fixed query parameters (AD-36)"
    Set tPort = pSource.%Get("port")
    If tPort '= ##class(OcuPilot.Screen.Read).#SOURCEADMIN Quit tWhere _ " is declared on a '" _ tPort _ "' source, and fixed query parameters travel on admin endpoints (AD-36)"
    Set tQuery = pSource.%Get("query")
    If tQuery.%Size() = 0 Quit tWhere _ " is empty, and a declared query fixes at least one parameter (AD-36)"

    Set tCriteriaParams = ""
    Set tCriteria = pRead.%Get("criteria")
    If $IsObject(tCriteria) && tCriteria.%IsA("%Library.DynamicObject") && (tCriteria.%GetTypeOf("fields") = "array") {
        Set tFieldIterator = tCriteria.%Get("fields").%GetIterator()
        While tFieldIterator.%GetNext(.tFieldIndex, .tField, .tFieldType) {
            If tFieldType '= "object" Continue
            If tField.%GetTypeOf("param") = "string" {
                Set tCriteriaParams = tCriteriaParams _ $ListBuild($ZConvert(tField.%Get("param"), "L"))
            }
            If tField.%GetTypeOf("vendorParam") = "string" {
                Set tCriteriaParams = tCriteriaParams _ $ListBuild($ZConvert(tField.%Get("vendorParam"), "L"))
            }
        }
    }
    Set tReserved = $ListFromString($ZConvert(..#CRITERIARESERVEDPARAMS, "L"))

    Set tProblem = ""
    Set tIterator = tQuery.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue, .tValueType) {
        If '$Match(tKey, "^[A-Za-z][A-Za-z0-9]*$") {
            Set tProblem = tWhere _ " key '" _ tKey _ "' is not a query parameter name"
            Quit
        }
        Set tFolded = $ZConvert(tKey, "L")
        If $ListFind(tReserved, tFolded) {
            Set tProblem = tWhere _ " key '" _ tKey _ "' collides with a name the read's own callers already send"
            Quit
        }
        If $ListFind(tCriteriaParams, tFolded) {
            Set tProblem = tWhere _ " key '" _ tKey _ "' is also a read.criteria param, and no caller can change a fixed parameter (AD-36)"
            Quit
        }
        If (tValueType '= "string") || (tValue = "") || ($Length(tValue) > ..#SOURCEQUERYMAXLENGTH) {
            Set tProblem = tWhere _ " '" _ tKey _ "' is not a non-empty string of at most " _ ..#SOURCEQUERYMAXLENGTH _ " characters"
            Quit
        }
    }
    Quit tProblem
}

/// <p>What is wrong with <var>pSource</var>'s <code>forEach</code>, or <code>""</code> (AD-36).
/// <var>pRead</var> is the declared read and <var>pFields</var> its declared fields.</p>
/// <p>An absent or <code>null</code> <code>forEach</code> lists no parents. Otherwise it is an object
/// carrying only <code>endpoint</code> (the parent endpoint, a package-relative name),
/// <code>key</code> (the parent row field whose text each child list is read for), <code>param</code>
/// (the query parameter that text is sent as, equal, case-folded, to no <code>read.source.query</code>
/// key, which it would overwrite) and <code>fields</code>, an array of objects carrying
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
    If pSource.%GetTypeOf("query") = "object" {
        Set tQueryIterator = pSource.%Get("query").%GetIterator()
        While tQueryIterator.%GetNext(.tQueryKey) {
            If $ZConvert(tQueryKey, "L") = $ZConvert(tForEach.%Get("param"), "L") Set tProblem = tWhere _ ".param '" _ tForEach.%Get("param") _ "' is also a read.source.query key, which each child list would overwrite (AD-36)"
        }
        If tProblem '= "" Quit tProblem
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

/// <p>The shape a declared part's <code>type</code> takes (AD-36): the vendor's own upper-case
/// request-type name, resolved through <class>OcuPilot.Port.AdminPort</class>'s
/// <code>BARETYPES</code> map when it carries no <code>TYPE</code> prefix of its own (System
/// usage, Story 6.9).</p>
Parameter PARTTYPEPATTERN = "^[A-Z]+$";

/// <p>The shape a declared part's <code>as</code> takes (AD-36): the object key its answer is
/// merged under, and the prefix every <code>&lt;as&gt;.&lt;member&gt;</code> field starts with.</p>
Parameter PARTASPATTERN = "^[A-Z][A-Za-z0-9]*$";

/// <p>The most parts a single-object <code>GET</code> may declare (AD-36).</p>
Parameter MAXPARTS As INTEGER = 3;

/// <p>What is wrong with <var>pSource</var>'s <code>parts</code>, or <code>""</code> (AD-36,
/// Story 6.9). <var>pRead</var> is the declared read and <var>pFields</var> its declared fields.</p>
/// <p>An absent or <code>null</code> <code>parts</code> declares none. Otherwise it is a
/// non-empty array of 1 to <parameter>MAXPARTS</parameter> objects carrying only <code>type</code>
/// (<parameter>PARTTYPEPATTERN</parameter>) and <code>as</code>
/// (<parameter>PARTASPATTERN</parameter>, unique across the block), declared on a single-object
/// <code>GET</code> source with no <code>criteria</code> or <code>query</code> -- either would
/// name the read's one criterion or a fixed parameter, and a parts read's row is assembled from
/// the parts alone. A <code>GET</code> source already guarantees an <code>admin</code> port and
/// already refuses <code>rowGet</code> and <code>forEach</code> outright unless a parent-scoped
/// route-id <code>criteria</code> is also declared, in which case this method's own criteria
/// check fires first, so neither needs its own arm here. Every
/// declared field then starts with one of the block's <code>as</code> values, followed by one or
/// two further dot-separated segments, since <method>OcuPilot.Screen.Read.CopyAs</method>
/// composes a part field's <code>&lt;as&gt;.&lt;member&gt;</code> with the existing
/// <code>&lt;object&gt;.&lt;member&gt;</code> projection to at most two members deep.
/// <file>ui/tools/screen-mirror.mjs</file>'s <code>partsProblem</code> returns the same sentence
/// for every case in <class>OcuPilot.Test.ReadSourceCorpus</class>.</p>
ClassMethod PartsProblem(pRead As %DynamicObject, pSource As %DynamicObject, pFields As %List) As %String
{
    Set tProblem = ""
    Try {
        Set tWhere = "read.source.parts"
        Set tType = pSource.%GetTypeOf("parts")
        If (tType = "unassigned") || (tType = "null") Quit
        If tType '= "array" {
            Set tProblem = tWhere _ " is not an array of {type, as} parts (AD-36)"
            Quit
        }
        If pSource.%Get("type") '= "GET" {
            Set tProblem = tWhere _ " is declared on a '" _ pSource.%Get("type") _ "' source, and parts merge into a single-object GET's one row (AD-36)"
            Quit
        }
        ; A GET source's own rules already guarantee the port is admin by this point, and already
        ; refuse rowGet and forEach outright on a GET source unless a parent-scoped route-id
        ; criterion is also declared -- in which case the criteria check just below fires first.
        ; So parts and rowGet or forEach cannot reach here together; only criteria and query can.
        If pRead.%GetTypeOf("criteria") = "object" {
            Set tProblem = tWhere _ " is declared with read.criteria, and a parts read takes no criterion (AD-36)"
            Quit
        }
        If pSource.%GetTypeOf("query") = "object" {
            Set tProblem = tWhere _ " is declared with read.source.query, and a parts read fixes no query parameter (AD-36)"
            Quit
        }
        Set tParts = pSource.%Get("parts")
        Set tCount = tParts.%Size()
        If (tCount < 1) || (tCount > ..#MAXPARTS) {
            Set tProblem = tWhere _ " declares " _ tCount _ " part(s), and a parts read names 1 to " _ ..#MAXPARTS
            Quit
        }
        Set tSeenAs = ""
        Set tAsList = ""
        Set tIterator = tParts.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tPart, .tPartType) {
            Set tAt = tWhere _ " entry #" _ (tIndex + 1)
            If tPartType '= "object" {
                Set tProblem = tAt _ " is not an object declaring its type and as"
                Quit
            }
            Set tProblem = ..UnknownKeyProblem(tPart, tAt, $ListBuild("type", "as"))
            If tProblem '= "" Quit
            Set tPartType2 = tPart.%Get("type")
            If (tPart.%GetTypeOf("type") '= "string") || '$Match(tPartType2, ..#PARTTYPEPATTERN) {
                Set tProblem = tAt _ " type '" _ tPartType2 _ "' is not upper-case letters"
                Quit
            }
            Set tAs = tPart.%Get("as")
            If (tPart.%GetTypeOf("as") '= "string") || '$Match(tAs, ..#PARTASPATTERN) {
                Set tProblem = tAt _ " as '" _ tAs _ "' is not an upper camel-case identifier"
                Quit
            }
            If $ListFind(tSeenAs, tAs) {
                Set tProblem = tAt _ " names the as '" _ tAs _ "' twice, and every part's as is unique"
                Quit
            }
            Set tSeenAs = tSeenAs _ $ListBuild(tAs)
            Set tAsList = tAsList _ $ListBuild(tAs)
        }
        If tProblem '= "" Quit

        For tI = 1:1:$ListLength(pFields) {
            Set tField = $List(pFields, tI)
            Set tMatched = 0
            For tJ = 1:1:$ListLength(tAsList) {
                Set tAs = $List(tAsList, tJ)
                If $Match(tField, "^" _ tAs _ "\.[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)?$") Set tMatched = 1
            }
            If 'tMatched {
                Set tProblem = "read.fields '" _ tField _ "' does not start with a declared parts.as followed by one or two segments (AD-36)"
                Quit
            }
        }
    } Catch ex {
        Set tProblem = "the parts declaration could not be read: " _ ex.DisplayString()
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
/// <var>pFields</var> is the read's declared fields. <var>pKeyAllowed</var> is non-empty only for a
/// parent-scoped GET's route-id criterion (Story 6.7): when it is, <code>key</code> must equal that
/// one param instead of naming one of <var>pFields</var>, because the GET's own answer carries no
/// such property for a per-row detail call to key off.</p>
/// <p>An absent or <code>null</code> <code>rowGet</code> declares no detail call. Otherwise it is an
/// object carrying only <code>key</code> (one of <var>pFields</var>, or <var>pKeyAllowed</var> where
/// that is non-empty), <code>param</code> (a query
/// parameter name), an optional <code>type</code> (one of <parameter>ROWGETTYPES</parameter>, spelled
/// exactly; absent means <code>GET</code>), <code>fields</code> (a non-empty array of unique names
/// from <var>pFields</var>, without <code>key</code>) and <code>derived</code>, an array of objects
/// carrying only <code>field</code> (one of <var>pFields</var>, neither <code>key</code> nor a detail
/// field, and not repeated), <code>rule</code> (one of <parameter>ROWGETRULES</parameter>) and
/// <code>from</code> (one of the detail fields). <file>ui/tools/screen-mirror.mjs</file>'s
/// <code>rowGetProblem</code> returns the same sentence for every case in
/// <class>OcuPilot.Test.RowGetCorpus</class>.</p>
ClassMethod RowGetProblem(pSource As %DynamicObject, pFields As %List, pKeyAllowed As %List = "") As %String
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
    If pKeyAllowed '= "" {
        If '$ListFind(pKeyAllowed, tKey) Quit tWhere _ ".key '" _ tKey _ "' must equal the read's one route-id criterion param (AD-36, Story 6.7)"
    } ElseIf '$ListFind(pFields, tKey) {
        Quit tWhere _ ".key '" _ tKey _ "' is not one of read.fields"
    }
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

/// <p>Whether <var>pDeclaration</var> is a <code>form-page</code> over a single-object
/// <code>GET</code> read that declares no <code>table</code> and no <code>composite</code> id. A
/// form renders that one object as fields and actions, never as a grid, so it names no column
/// header and no empty-state sentence a user could never see. Such a declaration is exempt from
/// <method>TableProblem</method>; a form over a list-shaped read, one with a composite id, and one
/// that declares a table are still held to it. <file>ui/tools/screen-mirror.mjs</file>'s
/// <code>rendersNoTable</code> is the twin.</p>
ClassMethod RendersNoTable(pDeclaration As %DynamicObject) As %Boolean [ Private ]
{
    If pDeclaration.%Get("archetype") '= "form-page" Quit 0
    Set tTableType = pDeclaration.%GetTypeOf("table")
    If (tTableType '= "unassigned") && (tTableType '= "null") Quit 0
    If (pDeclaration.%GetTypeOf("id") = "object") && (pDeclaration.%Get("id").%Get("kind") = "composite") Quit 0
    Set tRead = pDeclaration.%Get("read")
    If '$IsObject(tRead) || (tRead.%GetTypeOf("source") '= "object") Quit 0
    Quit tRead.%Get("source").%Get("type") = "GET"
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

/// <p>What is wrong with <var>pDeclaration</var>'s <code>secretArguments</code> and
/// <code>fingerprintExcludes</code>, or <code>""</code> (AD-3, AD-6).</p>
/// <p>Both are optional arrays of non-empty, unique strings. Every
/// <code>fingerprintExcludes</code> path names a field this screen already knows: a row of the
/// <class>OcuPilot.Screen.Tool.ToolFields</class> entry whose tool name this screen's
/// <code>toolIdentifier</code> owns, <b>or</b> a field the screen's own read declares -- its
/// <code>read.fields</code>, its <code>rowGet</code> detail fields and its derived field names. So
/// an exclusion cannot quietly cover nothing, which is the failure mode that would leave a
/// side-effect field inside the fingerprint and every confirm refusing on a target nobody touched,
/// and a screen whose side-effect field the write tool does not settle can still declare it while a
/// typo is still refused.</p>
/// <p><b>A credential-named field the list does not hold is refused</b> (DW-1121). A declared
/// criterion, and a settable string field of this screen's write tool, whose name matches the
/// credential pattern (Conventions, Secrets) and is absent from <code>secretArguments</code> is a
/// secret the confirm channel would carry in clear. The pattern is
/// <method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>'s, so the refusal and the log
/// redactor read one list; the string-placeholder qualification is the generator's own
/// (<file>ui/tools/field-lists.mjs</file>), so a boolean named <code>CSRFToken</code> is not a
/// credential here either.</p>
/// <p><b>A <code>secretArguments</code> entry the screen knows no name for is refused too</b>
/// (DW-1206). <code>secretArguments</code> reached only the shape rules and was then read as a
/// <i>whitelist</i> by <method>OcuPilot.Kernel.Proposal.Confirm.ChannelProblem</method> and by
/// <method>OcuPilot.Screen.Tool.Write.FieldRows</method>, both matching by exact name -- so a
/// misspelt entry left the real field advertised to the model and the channel closed to the
/// spelling nobody sends. Both entries are now checked against one set,
/// <method>DeclaredNames</method>'s, so the two sibling declarations cannot be validated against
/// different sets, which is the cause rather than the symptom.</p>
/// <p><b>A <code>secretArguments</code> entry also qualifies when it is a top-level
/// <code>secret</code> literal row of the screen's write tools</b> (<method>SecretRowNames</method>):
/// a derived credential, or a wrapper field the tool authors (AD-3). The source is additive --
/// every name the two sources above admit is still admitted -- and
/// <file>ui/tools/screen-mirror.mjs</file>'s <code>secretRowNames</code> applies the same rule.</p>
/// <p><b>Both directions moved, and both are pinned.</b> Folding the declared criteria into the
/// set <b>loosens</b> <code>fingerprintExcludes</code> -- a criterion name was refused before and
/// is a name the read declares. Scoping the tool half to the rows a write tool may actually set
/// <b>tightens</b> it -- any row of the entry was accepted before, a <code>secret</code> or
/// <code>opaque</code> one included. A row the write tool cannot set -- a nested or
/// array-element path -- is no longer nameable as an exclusion at all, which is the tightening
/// this key trades for the typo the union catches.</p>
ClassMethod ConfirmChannelProblem(pDeclaration As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        If '$IsObject(pDeclaration) {
            Set tProblem = "the declaration is not an object"
            Quit
        }
        Set tProblem = ..StringListProblem(pDeclaration, "secretArguments", .tSecrets)
        If tProblem '= "" Quit
        Set tProblem = ..StringListProblem(pDeclaration, "fingerprintExcludes", .tExcludes)
        If tProblem '= "" Quit

        Set tIdentifier = ""
        If pDeclaration.%GetTypeOf("toolIdentifier") = "string" Set tIdentifier = pDeclaration.%Get("toolIdentifier")
        Set tProblem = ..ToolFieldRows(tIdentifier, .tRows)
        If tProblem '= "" Quit
        Do ..DeclaredNames(pDeclaration, .tRows, .tNames)

        For tI = 1:1:$ListLength(tExcludes) {
            Set tPath = $List(tExcludes, tI)
            If '$ListFind(tNames("path"), tPath) && '$ListFind(tNames("read"), tPath) {
                Set tProblem = "fingerprintExcludes names '" _ tPath _ "', which is neither a field of this screen's write tool nor one its read declares (AD-6)"
                Quit
            }
        }
        If tProblem '= "" Quit

        Set tSecretRows = ..SecretRowNames(.tRows)
        For tI = 1:1:$ListLength(tSecrets) {
            Set tName = $List(tSecrets, tI)
            If '$ListFind(tNames("settable"), tName) && '$ListFind(tNames("read"), tName) && '$ListFind(tSecretRows, tName) {
                Set tProblem = "secretArguments names '" _ tName _ "', which is neither a settable field of this screen's write tool nor one its read declares (AD-6)"
                Quit
            }
        }
        If tProblem '= "" Quit

        Set tProblem = ..CredentialNameProblem(tNames("criteria"), tSecrets, "read.criteria")
        If tProblem '= "" Quit
        Set tProblem = ..CredentialNameProblem(tNames("credential"), tSecrets, "the write tool's settable fields")
    } Catch ex {
        Set tProblem = "the confirm channel could not be validated: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>The class an action-style write's declarations live on, which is what makes
/// <method>FingerprintSubjectProblem</method> a question about a tool at all.</p>
Parameter WRITETOOLBASE = "OcuPilot.Screen.Tool.Write";

/// <p>What is wrong with write tool <var>pToolClass</var>'s declared fingerprint subject, or
/// <code>""</code> (AD-51 as amended 2026-09-22). A <b>merge</b> write declares none and has
/// nothing wrong with it: its fingerprint is the descriptor's exclusions over the payload it
/// sends, which is AD-6's own rule. An action-style write sends none, so it must declare one.</p>
/// <p><b>Caller contract:</b> <method>OcuPilot.Screen.Tool.Registry.ListTools</method> calls it for
/// every write tool it lists, so a tool whose subject this refuses cannot be registered, reached by
/// the model, or minted from.</p>
/// <p>Three things are held. An action-style write <b>declares</b> one, and a body-sending write
/// does not, because the inversion is that kind's and a merge write declaring one would send a
/// body narrowed to it. The other two are the structural half of adequacy: the subject carries
/// the field the tool's own precondition reads
/// (<parameter>OcuPilot.Screen.Tool.Write.PRECONDITIONFIELD</parameter>), and every name in it is
/// one the screen or the tool's own read already knows. An empty subject fingerprints nothing at
/// all, and one without the precondition field would let a confirm succeed against a target
/// somebody else had already moved.</p>
/// <p><b>Identity is not required</b> (AD-51 as amended 2026-09-22): the fingerprint asks whether
/// the reviewed state moved, while which object this is is already answered by the proposal's
/// <code>TargetRef</code> (AD-13). Naming the id is permitted where the read answers one, since
/// it cannot move for a fixed target.</p>
/// <p><b>The name check runs through <method>DeclaredNames</method></b>, the same extraction
/// <method>ConfirmChannelProblem</method> validates <code>fingerprintExcludes</code> against, given
/// this tool's class so its <code>toolRead</code> projection carries the names the tool's own read
/// answers. Validating two sibling declarations against two sets is DW-1206's defect, and one set
/// is its fix.</p>
/// <p>One further condition: a subject name the descriptor's <code>fingerprintExcludes</code> also
/// names is refused, because <method>OcuPilot.Kernel.Proposal.Fingerprint.Of</method> projects
/// before it excludes, so the digest would cover nothing.</p>
/// <p>And one last: an action-style write that declares no subject at all is refused (DW-1476).
/// Such a tool sends no payload, so leaving the subject undeclared would fall back to AD-6's
/// exclusion model over a body it never sends -- a fingerprint over nothing.</p>
ClassMethod FingerprintSubjectProblem(pToolClass As %String) As %String
{
    Set tProblem = ""
    Try {
        If pToolClass = "" Quit
        ; The declaration lives on OcuPilot.Screen.Tool.Write, so a tool that classifies itself
        ; `write` without extending it has no subject to hold -- a fixture registry that widens
        ; the excluded package lists such classes, and asking them would raise rather than refuse.
        If '$ClassMethod(pToolClass, "%Extends", ..#WRITETOOLBASE) Quit
        Set tSubject = $ClassMethod(pToolClass, "FingerprintSubject")
        If (tSubject '= "") && $ClassMethod(pToolClass, "SendsBody") {
            Set tProblem = "FINGERPRINTSUBJECT is declared on a write that sends a body, and the inversion is the action-style kind's alone -- a merge write's fingerprint is the descriptor's exclusions over the whole payload (AD-6, AD-51)"
            Quit
        }
        If tSubject = "" {
            If $Parameter(pToolClass, "FINGERPRINTSUBJECT") '= "" {
                Set tProblem = "FINGERPRINTSUBJECT is declared and names no field, and a subject that covers nothing is no fingerprint at all (AD-51)"
                Quit
            }
            If '$ClassMethod(pToolClass, "SendsBody") {
                Set tProblem = "an action-style write declares the subject its fingerprint covers, and this one declares no FINGERPRINTSUBJECT -- it sends no payload, so there is nothing for AD-6's exclusion model to cover (AD-51)"
            }
            Quit
        }
        Set tPrecondition = $ClassMethod(pToolClass, "PreconditionField")
        If tPrecondition = "" {
            Set tProblem = "a declared fingerprint subject names the field its action's precondition reads, and PRECONDITIONFIELD is empty (AD-51)"
            Quit
        }
        If '$ListFind(tSubject, tPrecondition) {
            Set tProblem = "the declared fingerprint subject omits '" _ tPrecondition _ "', which is the field this tool's own precondition reads (AD-51)"
            Quit
        }
        Set tDescriptor = $Parameter(pToolClass, "DESCRIPTORCLASS")
        If tDescriptor = "" {
            Set tProblem = "a declared fingerprint subject is checked against the screen's own declared names, and this tool names no descriptor class (AD-5)"
            Quit
        }
        Set tSC = $ClassMethod(tDescriptor, "DeclarationJson", .tDeclaration)
        If $$$ISERR(tSC) || '$IsObject(tDeclaration) {
            Set tProblem = "the declaration of " _ tDescriptor _ " could not be read, so the declared fingerprint subject could not be checked against it"
            Quit
        }
        Set tIdentifier = ""
        If tDeclaration.%GetTypeOf("toolIdentifier") = "string" Set tIdentifier = tDeclaration.%Get("toolIdentifier")
        Set tProblem = ..ToolFieldRows(tIdentifier, .tRows)
        If tProblem '= "" Quit
        Do ..DeclaredNames(tDeclaration, .tRows, .tNames, pToolClass)
        ; DW-1474. Fingerprint.Of projects the subject and then applies the exclusions, so a name
        ; both keys carry is hashed out of the very set it is the whole of -- collapsing the digest
        ; to the empty object and making every confirm match. The two keys relate in no other
        ; condition, which is why the overlap is refused here by name.
        Set tExcludes = ""
        Do ..StringListProblem(tDeclaration, "fingerprintExcludes", .tExcludes)
        For tI = 1:1:$ListLength(tSubject) {
            Set tName = $List(tSubject, tI)
            If $ListFind(tExcludes, tName) {
                Set tProblem = "the declared fingerprint subject names '" _ tName _ "', which this screen's fingerprintExcludes also names -- the projection runs before the exclusion, so the digest would cover nothing (AD-6, AD-51)"
                Quit
            }
            If '$ListFind(tNames("path"), tName) && '$ListFind(tNames("read"), tName) && '$ListFind(tNames("toolRead"), tName) {
                Set tProblem = "the declared fingerprint subject names '" _ tName _ "', which is neither a field of this screen's write tool, nor one its read declares, nor one this tool's own READANSWERS declares (AD-51)"
                Quit
            }
        }
    } Catch ex {
        Set tProblem = "the declared fingerprint subject could not be validated: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>The self-protection rules a declared action may name, comma-separated (AD-5, AD-53).
/// Declared as data because a generator reads it: <file>ui/tools/screen-mirror.mjs</file> parses
/// this parameter and refuses the same values this class does, so a rule neither side understands
/// is refused at the build rather than rendered as a word -- the discipline
/// <parameter>DECLAREDNAMEKINDS</parameter> already follows.</p>
/// <p><code>serves-ocupilot</code> is one rule Release 1 declares: the target is a web
/// application OcuPilot is itself served through. It <b>explains</b> a refusal and never enforces
/// one -- the refusal is <class>OcuPilot.Kernel.Proposal.Prohibited</class>'s, evaluated at the
/// write whatever the caller (AD-10), and its sentence is that class's
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.SERVINGPATHREASON</parameter>.
/// <code>protected-account</code> is the account one: the target is <code>_SYSTEM</code>, the
/// signed-in account or a service account, and its sentences are that class's
/// <code>SYSTEMACCOUNTREASON</code>, <code>CURRENTUSERREASON</code> and
/// <code>SERVICEACCOUNTREASON</code>. The last <code>%All</code> holder is a census no client can
/// read, so it is refused at the write alone. <code>service-account-sign-in</code> is the sign-in
/// one (AD-10 as amended 2026-09-23): the target is a service account other than the signed-in one,
/// and its sentence is <code>SERVICEACCOUNTSIGNINREASON</code>.</p>
Parameter SELFPROTECTIONRULES = "serves-ocupilot,protected-account,service-account-sign-in";

/// <p>The fewest suggested prompts a declaration that declares any may carry (Story 11.3).</p>
Parameter SUGGESTEDPROMPTSMIN As INTEGER = 3;

/// <p>The projections <method>DeclaredNames</method> fills, comma-separated. Declared as data
/// because a generator reads it: <file>ui/tools/screen-mirror.mjs</file> parses this parameter and
/// fails <code>npm run build</code> when its own builder answers a different set, so the mirror
/// cannot consume a projection this class does not fill, or miss one it does -- the discipline
/// <parameter>OcuPilot.Kernel.EntityRef.IDRULENAMES</parameter> already follows for its own closed
/// vocabulary. What each projection means is <method>DeclaredNames</method>'s doc comment.</p>
Parameter DECLAREDNAMEKINDS = "settable,path,criteria,read,credential,toolRead";

/// <p>What is wrong with <var>pDeclaration</var>'s declared actions, or <code>""</code> (AD-5,
/// AD-53): the primary action and every row action carry only <code>id</code> and
/// <code>selfProtection</code>, an id is unique across the row actions, and a non-empty
/// <code>selfProtection</code> names a rule <parameter>SELFPROTECTIONRULES</parameter> declares.</p>
/// <p><b>The vocabulary is closed because both sides read it.</b> The rule is mirrored to the
/// client, which draws the action refused before a click; a value neither side understands would
/// render as a word in a menu rather than as a reason. An action with no rule declares
/// <code>""</code>, which is every shipped action but this story's three.</p>
/// <p><b>It validates the declaration, not the refusal.</b> Whether a given target is protected is
/// AD-10's question, asked at the write; this refuses a declaration that names a rule nothing can
/// evaluate.</p>
ClassMethod ActionProblem(pDeclaration As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        If '$IsObject(pDeclaration) {
            Set tProblem = "the declaration is not an object"
            Quit
        }
        Set tRules = $ListFromString(..#SELFPROTECTIONRULES)
        ; An absent key is left alone, the leniency ui/tools/screen-mirror.mjs keeps for a
        ; partially declared fixture; DeclarationProblem has already refused a misspelt one.
        If pDeclaration.%GetTypeOf("primaryAction") '= "unassigned" {
            Set tProblem = ..OneActionProblem(pDeclaration.%Get("primaryAction"), "primaryAction", tRules)
            If tProblem '= "" Quit
        }
        If pDeclaration.%GetTypeOf("rowActions") = "unassigned" Quit
        If pDeclaration.%GetTypeOf("rowActions") '= "array" {
            Set tProblem = "rowActions is not an array of declared actions"
            Quit
        }
        Set tSeen = ""
        Set tIterator = pDeclaration.%Get("rowActions").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tAction) {
            Set tWhere = "rowActions entry #" _ (tIndex + 1)
            Set tProblem = ..OneActionProblem(tAction, tWhere, tRules)
            If tProblem '= "" Quit
            Set tId = tAction.%Get("id")
            If tId = "" {
                Set tProblem = tWhere _ " declares an empty id, and an action with no id is a control nothing can run"
                Quit
            }
            If $ListFind(tSeen, tId) {
                Set tProblem = "rowActions names the action '" _ tId _ "' twice"
                Quit
            }
            Set tSeen = tSeen _ $ListBuild(tId)
        }
    } Catch ex {
        Set tProblem = "the declared actions could not be validated: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>What is wrong with one declared action <var>pAction</var> at <var>pWhere</var>, or
/// <code>""</code>. Read for <method>ActionProblem</method> alone.</p>
ClassMethod OneActionProblem(pAction As %DynamicObject, pWhere As %String, pRules As %List) As %String [ Private ]
{
    If '$IsObject(pAction) || 'pAction.%IsA("%Library.DynamicObject") {
        Quit pWhere _ " is not an object declaring its id and self-protection rule"
    }
    Set tKeysProblem = ..UnknownKeyProblem(pAction, pWhere, $ListBuild("id", "selfProtection"))
    If tKeysProblem '= "" Quit tKeysProblem
    If pAction.%GetTypeOf("id") '= "string" Quit pWhere _ " id is not a string"
    If pAction.%GetTypeOf("selfProtection") '= "string" Quit pWhere _ " selfProtection is not a string"
    Set tRule = pAction.%Get("selfProtection")
    If tRule = "" Quit ""
    If '$ListFind(pRules, tRule) {
        Quit pWhere _ " selfProtection '" _ tRule _ "' is not one of " _ ..#SELFPROTECTIONRULES _ ", and a rule neither the instance nor the client understands explains nothing (AD-5, AD-53)"
    }
    Quit ""
}

/// <p>The one set of names <var>pDeclaration</var>'s two confirm-channel keys are validated
/// against (DW-1206), built once from its write tool's classified rows <var>pRows</var> and from
/// its own declared read. <var>pNames</var> carries five <class>%List</class> projections of that
/// one traversal:</p>
/// <ul>
/// <li><code>settable</code> -- the write tool's settable field names in the
/// <code>[]</code>-stripped spelling <method>OcuPilot.Screen.Tool.Write.FieldRows</method> matches
/// a declared secret by, which is the spelling <code>secretArguments</code> is checked in;</li>
/// <li><code>path</code> -- the same rows in the spelling they are written in,
/// <code>[]</code> included, which is the spelling
/// <method>OcuPilot.Kernel.Proposal.Fingerprint.Canonical</method> matches an exclusion by and so
/// the spelling <code>fingerprintExcludes</code> is checked in;</li>
/// <li><code>criteria</code> -- the declared criterion parameter names and the
/// <code>FlagCriteria</code> names, de-duplicated;</li>
/// <li><code>read</code> -- <code>read.fields</code>, the <code>rowGet</code> detail fields, the
/// derived field names and <code>criteria</code>, de-duplicated;</li>
/// <li><code>credential</code> -- the rows the credential-name rule qualifies, which is
/// <code>path</code> narrowed to a string placeholder (<file>ui/tools/field-lists.mjs</file>'s own
/// qualification, so a boolean named <code>CSRFToken</code> is not a credential).</li>
/// <li><code>toolRead</code> -- the names <var>pToolClass</var>'s own
/// <parameter>OcuPilot.Screen.Tool.Write.READANSWERS</parameter> declares its
/// <code>READTYPE</code> read answers, or empty where the caller names no tool class (DW-1475). A
/// screen's declared read and its write tool's own read are not the same set, and a screen that
/// declares no <code>read</code> at all knows no name a subject could carry.</li>
/// </ul>
/// <p><b>The two keys are checked in two spellings and that is not two sets.</b> One traversal
/// answers both, because their consumers honour different spellings:
/// <method>OcuPilot.Screen.Tool.Write.FieldRows</method> drops a declared secret by its stripped
/// name, while an exclusion of an array reaches the fingerprint as <code>&lt;path&gt;[]</code>. A
/// single spelling would admit the entry one consumer ignores -- which is the defect this method
/// exists to close, in a new place.</p>
/// <p>Read leniently: a malformed read contributes no names rather than a second refusal, because
/// <method>ReadProblem</method> has already refused it by the time this runs.</p>
ClassMethod DeclaredNames(pDeclaration As %DynamicObject, ByRef pRows, Output pNames, pToolClass As %String = "") [ Private ]
{
    Kill pNames
    Set pNames("settable") = ""
    Set pNames("path") = ""
    Set pNames("credential") = ""
    Set pNames("criteria") = ..DeclaredCriterionParams(pDeclaration)
    Set pNames("read") = ..DeclaredReadFields(pDeclaration)
    Set pNames("toolRead") = ..ToolReadAnswers(pToolClass)
    Try {
        Set tPath = ""
        For {
            Set tPath = $Order(pRows(tPath))
            If tPath = "" Quit
            Set tRow = pRows(tPath)
            If '$ListValid(tRow) Continue
            If $List(tRow, 3) Set pNames("credential") = pNames("credential") _ $ListBuild(tPath)
            If '$List(tRow, 1) Continue
            If '$ListFind(pNames("path"), tPath) Set pNames("path") = pNames("path") _ $ListBuild(tPath)
            Set tName = $List(tRow, 2)
            If tName = "" Continue
            If $ListFind(pNames("settable"), tName) Continue
            Set pNames("settable") = pNames("settable") _ $ListBuild(tName)
        }
        For tI = 1:1:$ListLength(pNames("criteria")) {
            Set tName = $List(pNames("criteria"), tI)
            If $ListFind(pNames("read"), tName) Continue
            Set pNames("read") = pNames("read") _ $ListBuild(tName)
        }
    } Catch {
        ; Deliberately empty: the projections filled before the raise are kept. This runs after
        ; ReadProblem has already refused a malformed declaration, so a partial set can only make
        ; this validator more permissive, never wrongly refusing a sound name.
    }
}

/// <p>The names <var>pToolClass</var> declares its own <code>READTYPE</code> read answers, as a
/// <class>%List</class>, or <code>""</code> for no class and for one that cannot be asked.</p>
/// <p>Read for <method>DeclaredNames</method> alone. A class that cannot be asked contributes no
/// name, which refuses a subject rather than admitting one -- the fail-closed direction for a
/// guard whose job is to refuse a name nothing answers.</p>
ClassMethod ToolReadAnswers(pToolClass As %String) As %List [ Private ]
{
    Set tNames = ""
    Try {
        If pToolClass = "" Quit
        Set tNames = $ClassMethod(pToolClass, "ReadAnswers")
    } Catch {
        Set tNames = ""
    }
    Quit tNames
}

/// <p>The field names <var>pDeclaration</var>'s read declares, as a <class>%List</class>: its
/// <code>read.fields</code>, its <code>read.source.rowGet.fields</code> and the
/// <code>field</code> of each <code>read.source.rowGet.derived</code> entry.</p>
/// <p>Read for <method>DeclaredNames</method> alone, and read leniently: a malformed read
/// contributes no names here rather than a second refusal, because
/// <method>ReadProblem</method> has already refused it by the time this runs.</p>
ClassMethod DeclaredReadFields(pDeclaration As %DynamicObject) As %List [ Private ]
{
    Set tFields = ""
    Try {
        If pDeclaration.%GetTypeOf("read") '= "object" Quit
        Set tRead = pDeclaration.%Get("read")
        Do ..AppendNames(tRead, "fields", .tFields)
        If tRead.%GetTypeOf("source") '= "object" Quit
        Set tSource = tRead.%Get("source")
        If tSource.%GetTypeOf("rowGet") '= "object" Quit
        Set tRowGet = tSource.%Get("rowGet")
        Do ..AppendNames(tRowGet, "fields", .tFields)
        If tRowGet.%GetTypeOf("derived") '= "array" Quit
        Set tIterator = tRowGet.%Get("derived").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If '$IsObject(tEntry) Continue
            If tEntry.%GetTypeOf("field") '= "string" Continue
            If tEntry.%Get("field") = "" Continue
            If $ListFind(tFields, tEntry.%Get("field")) Continue
            Set tFields = tFields _ $ListBuild(tEntry.%Get("field"))
        }
    } Catch {
        ; Deliberately empty: the names collected before the raise are kept, for the reason
        ; <method>DeclaredNames</method>'s own catch gives.
    }
    Quit tFields
}

/// <p>Append <var>pParent</var>'s string array <var>pKey</var> to <var>pNames</var>, skipping
/// anything that is not a non-empty string and anything already there.</p>
ClassMethod AppendNames(pParent As %DynamicObject, pKey As %String, ByRef pNames As %List) [ Private ]
{
    If pParent.%GetTypeOf(pKey) '= "array" Quit
    Set tIterator = pParent.%Get(pKey).%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue, .tType) {
        If (tType '= "string") || (tValue = "") Continue
        If $ListFind(pNames, tValue) Continue
        Set pNames = pNames _ $ListBuild(tValue)
    }
}

/// <p>What is wrong with <var>pDeclaration</var>'s optional array-of-strings key <var>pKey</var>,
/// or <code>""</code>, with its values in <var>pValues</var> as a <class>%List</class>. An absent
/// or null key is an empty list.</p>
ClassMethod StringListProblem(pDeclaration As %DynamicObject, pKey As %String, Output pValues As %List) As %String [ Private ]
{
    Set pValues = ""
    Set tType = pDeclaration.%GetTypeOf(pKey)
    If (tType = "unassigned") || (tType = "null") Quit ""
    If tType '= "array" Quit pKey _ " is not an array of strings"
    Set tProblem = ""
    Set tIterator = pDeclaration.%Get(pKey).%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue, .tValueType) {
        If (tValueType '= "string") || (tValue = "") {
            Set tProblem = pKey _ " holds an entry that is not a non-empty string"
            Quit
        }
        If $ListFind(pValues, tValue) {
            Set tProblem = pKey _ " names '" _ tValue _ "' twice"
            Quit
        }
        Set pValues = pValues _ $ListBuild(tValue)
    }
    If tProblem '= "" Set pValues = ""
    Quit tProblem
}

/// <p>The criterion names <var>pDeclaration</var>'s read declares, as a <class>%List</class>;
/// empty for a read that declares none.</p>
/// <p>Both halves of <code>criteria</code>: the <code>param</code> of each
/// <code>criteria.fields</code> entry, whose value a person types, and each <b>flag</b> criterion
/// -- a member of <code>criteria</code> other than <code>fields</code> declaring both a
/// <code>param</code> and a <code>value</code>, which is the descriptor's own value and is what
/// <method>OcuPilot.Screen.Descriptor.Base.FlagCriteria</method> enumerates. A half-declared flag
/// is not a criterion and is not named here.</p>
/// <p>De-duplicated: a flag may send its value under the same vendor parameter a typed criterion
/// uses (the audit viewer's <code>marker</code> and its <code>eventSources</code> field are one
/// such pair), and a name twice in this list would make one refusal read as two.</p>
ClassMethod DeclaredCriterionParams(pDeclaration As %DynamicObject) As %List [ Private ]
{
    Set tParams = ""
    Try {
        If pDeclaration.%GetTypeOf("read") '= "object" Quit
        Set tRead = pDeclaration.%Get("read")
        If tRead.%GetTypeOf("criteria") '= "object" Quit
        Set tCriteria = tRead.%Get("criteria")
        If tCriteria.%GetTypeOf("fields") = "array" {
            Set tIterator = tCriteria.%Get("fields").%GetIterator()
            While tIterator.%GetNext(.tIndex, .tField) {
                If '$IsObject(tField) Continue
                If tField.%GetTypeOf("param") '= "string" Continue
                If tField.%Get("param") = "" Continue
                If $ListFind(tParams, tField.%Get("param")) Continue
                Set tParams = tParams _ $ListBuild(tField.%Get("param"))
            }
        }
        Set tFlags = tCriteria.%GetIterator()
        While tFlags.%GetNext(.tName, .tFlag) {
            If tName = "fields" Continue
            If '$IsObject(tFlag) || 'tFlag.%IsA("%Library.DynamicObject") Continue
            If tFlag.%GetTypeOf("param") '= "string" Continue
            If tFlag.%Get("param") = "" Continue
            If tFlag.%GetTypeOf("value") = "unassigned" Continue
            If $ListFind(tParams, tFlag.%Get("param")) Continue
            Set tParams = tParams _ $ListBuild(tFlag.%Get("param"))
        }
    } Catch {
        ; Deliberately empty, and a change from the reset this replaced: the names collected before
        ; the raise are kept, for the reason <method>DeclaredNames</method>'s own catch gives.
    }
    Quit tParams
}

/// <p>The first name in <var>pNames</var> that matches the credential pattern and is absent from
/// <var>pSecrets</var>, as a refusal naming <var>pWhere</var>, or <code>""</code> (DW-1121).</p>
ClassMethod CredentialNameProblem(pNames As %List, pSecrets As %List, pWhere As %String) As %String [ Private ]
{
    Set tProblem = ""
    For tI = 1:1:$ListLength(pNames) {
        Set tName = $List(pNames, tI)
        If '##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(..LastSegment(tName)) Continue
        If $ListFind(pSecrets, tName) Continue
        Set tProblem = pWhere _ " names '" _ tName _ "', whose name matches the credential pattern and which secretArguments does not declare (AD-3)"
        Quit
    }
    Quit tProblem
}

/// <p><var>pPath</var>'s last segment with any <code>[]</code> removed, the same reduction
/// <file>ui/tools/field-lists.mjs</file>'s <code>lastSegment</code> makes.</p>
ClassMethod LastSegment(pPath As %String) As %String [ Private ]
{
    Set tSegment = $Piece(pPath, ".", $Length(pPath, "."))
    While $Extract(tSegment, *-1, *) = "[]" {
        Set tSegment = $Extract(tSegment, 1, *-2)
    }
    Quit tSegment
}

/// <p>The classified field rows of the write tool <var>pIdentifier</var> owns, as
/// <code>pRows(path) = $ListBuild(isSettable, strippedName, isSettableStringLiteral, isTopLevelSecret)</code>;
/// empty when the identifier owns no <class>OcuPilot.Screen.Tool.ToolFields</class> entry. A
/// refusal is returned when that generated block cannot be read, because an unreadable field list
/// is not a negative result.</p>
/// <p><b>Settable here means the field-list shape a write tool can send</b>: an
/// <code>ordinary</code> literal at the top level, whose name is the path with any trailing
/// <code>[]</code> removed and which carries no interior <code>[</code>. It is deliberately
/// <i>not</i> <method>OcuPilot.Screen.Tool.Write.FieldRows</method>'s output, which narrows the
/// same rows further by <method>PermittedFields</method> and <method>ExcludedFields</method> and
/// <b>drops every name the descriptor declares secret</b> -- so validating
/// <code>secretArguments</code> against that output would reject every entry for being declared,
/// which is the circularity this shape avoids. The consequence is stated rather than hidden: a
/// derived field the tool does not permit is still a nameable secret here, and closing that is
/// this spec's <code>deferred:</code> item. The third element narrows the rows to a string
/// placeholder, which is the credential-name rule's own qualification and nothing else's; the
/// fourth marks a top-level <code>secret</code> literal (<method>SecretRowNames</method>). One
/// reader of the generated block, four questions asked of its rows.</p>
ClassMethod ToolFieldRows(pIdentifier As %String, Output pRows) As %String [ Private ]
{
    Kill pRows
    If pIdentifier = "" Quit ""
    Set tProblem = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Screen.Tool.ToolFields", "Tools", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tProblem = "the generated tool field lists could not be read"
            Quit
        }
        Do tXData.Data.Rewind()
        Set tTools = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        Set tXData = ""
        If '$IsObject(tTools) {
            Set tProblem = "the generated tool field lists are not a JSON object"
            Quit
        }
        Set tIterator = tTools.%GetIterator()
        While tIterator.%GetNext(.tName, .tEntry) {
            If $Piece(tName, ".", 1, 2) '= pIdentifier Continue
            If '$IsObject(tEntry) || (tEntry.%GetTypeOf("fields") '= "array") Continue
            Set tFields = tEntry.%Get("fields").%GetIterator()
            While tFields.%GetNext(.tIndex, .tField) {
                If '$IsObject(tField) Continue
                Set tPath = tField.%Get("path")
                Set tLiteral = (tField.%Get("class") = "ordinary") && (tField.%Get("shape") = "literal")
                Set tName = $Select($Extract(tPath, *-1, *) = "[]": $Extract(tPath, 1, *-2), 1: tPath)
                If (tPath [ ".") || (tName [ "[") Set tName = ""
                Set tTopSecret = (tField.%Get("class") = "secret") && (tField.%Get("shape") = "literal") && '(tPath [ ".") && '(tPath [ "[")
                Set pRows(tPath) = $ListBuild((tLiteral && (tName '= "")), tName, (tLiteral && (tField.%Get("templateType") = "string")), tTopSecret)
            }
        }
    } Catch ex {
        Kill pRows
        Set tProblem = "the generated tool field lists could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>The names of the top-level <code>secret</code> literal rows in <var>pRows</var>
/// (<method>ToolFieldRows</method>'s answer), as a <class>%List</class>: the third source a
/// <code>secretArguments</code> entry may name. A nested path, an array element and a row of any
/// other class contribute nothing.</p>
ClassMethod SecretRowNames(ByRef pRows) As %List [ Private ]
{
    Set tNames = ""
    Set tPath = ""
    For {
        Set tPath = $Order(pRows(tPath))
        If tPath = "" Quit
        Set tRow = pRows(tPath)
        If '$ListValid(tRow) || ($ListLength(tRow) < 4) Continue
        If '$List(tRow, 4) Continue
        If '$ListFind(tNames, tPath) Set tNames = tNames _ $ListBuild(tPath)
    }
    Quit tNames
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

/// <p>What is wrong with <var>pContext</var>'s <code>maxLength</code> map, or <code>""</code>
/// (AD-24, Story 4.4). Optional; when declared it is an object whose every key is one of
/// <var>pFields</var>, the declaration's <code>context.fields</code>, and whose every value is a whole number from 1 to 1,000 -- the same bound the
/// kernel cutter enforces by default, so a declared value can only lower it, never raise it.</p>
ClassMethod ContextMaxLengthProblem(pContext As %DynamicObject, pFields As %List) As %String [ Private ]
{
    Set tType = pContext.%GetTypeOf("maxLength")
    If (tType = "unassigned") || (tType = "null") Quit ""
    If tType '= "object" Quit "context.maxLength is not an object"
    Set tMap = pContext.%Get("maxLength")
    Set tProblem = ""
    Set tIterator = tMap.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue, .tValueType) {
        If '$ListFind(pFields, tKey) {
            Set tProblem = "context.maxLength names '" _ tKey _ "', which is not in context.fields"
            Quit
        }
        If (tValueType '= "number") || (tValue '= (tValue \ 1)) || (tValue < 1) || (tValue > 1000) {
            Set tProblem = "context.maxLength." _ tKey _ " is not a whole number from 1 to 1,000"
            Quit
        }
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

/// <p>The entity type <var>pDescriptor</var>'s route id identifies (DW-1020, AD-5, AD-13):
/// <var>pDescriptor</var>'s own <method>OcuPilot.Screen.Descriptor.Base.PrimaryEntityType</method>
/// for a screen declaring no <code>parentScope</code>, or the entity type of the descriptor
/// declared at that route otherwise -- resolved through the parent declaration and never declared
/// a second time. A sub-resource screen's <b>rows</b> keep their own primary entity type
/// regardless; this answers what the id in the URL names, not what the rows are (task history is
/// not a task).</p>
/// <p>A <code>parentScope</code> that resolves to no descriptor -- which
/// <method>ParentScopeResolutionProblem</method> refuses in the production roster -- falls back to
/// <var>pDescriptor</var>'s own primary entity type rather than throwing, since this method has no
/// refusal of its own to raise.</p>
ClassMethod RouteEntityType(pDescriptor As %String) As %String
{
    Set tType = ""
    Try {
        Set tParentScope = $ClassMethod(pDescriptor, "ParentScope")
        If tParentScope '= "" {
            Set tParentClass = ..DescriptorForRoute(tParentScope)
            If tParentClass '= "" Set tType = $ClassMethod(tParentClass, "PrimaryEntityType")
        }
        If tType = "" Set tType = $ClassMethod(pDescriptor, "PrimaryEntityType")
    } Catch {
        Set tType = ""
    }
    Quit tType
}

/// <p>What is wrong with <var>pRoster</var>'s <code>parentScope</code> declarations taken
/// together, or <code>""</code> (DW-1020, AD-5). <var>pRoster</var> is
/// <method>Validate</method>'s own array of <code>{descriptor, declaration}</code> entries, one
/// per descriptor in the package.</p>
/// <p>A built descriptor's non-empty <code>parentScope</code> must name the route of some other
/// <b>built</b> descriptor whose own <code>id.kind</code> is not <code>none</code> -- a route with
/// nothing to identify resolves no entity for the child's id to name. The entry being checked is
/// excluded from its own candidate search, so a descriptor cannot resolve its <code>parentScope</code>
/// against itself by declaring one equal to its own <code>route</code>. An unbuilt descriptor's
/// <code>parentScope</code> is not checked: it routes nothing yet, so a stale reference in a
/// declaration still being drafted is not this rule's problem.</p>
ClassMethod ParentScopeResolutionProblem(pRoster As %DynamicArray) As %String [ Private ]
{
    Set tProblem = ""
    Try {
        Set tOuter = pRoster.%GetIterator()
        While tOuter.%GetNext(.tOuterIndex, .tEntry) {
            Set tDeclaration = tEntry.%Get("declaration")
            If ''tDeclaration.%Get("built") = 0 Continue
            Set tParentScope = tDeclaration.%Get("parentScope")
            If (tDeclaration.%GetTypeOf("parentScope") '= "string") || (tParentScope = "") Continue
            Set tFound = 0
            Set tInner = pRoster.%GetIterator()
            While tInner.%GetNext(.tInnerIndex, .tCandidateEntry) {
                If tInnerIndex = tOuterIndex Continue
                Set tCandidate = tCandidateEntry.%Get("declaration")
                If tCandidate.%Get("route") '= tParentScope Continue
                If ''tCandidate.%Get("built") = 0 Continue
                Set tIdKind = ""
                If tCandidate.%GetTypeOf("id") = "object" Set tIdKind = tCandidate.%Get("id").%Get("kind")
                If (tIdKind '= "") && (tIdKind '= "none") Set tFound = 1
            }
            If 'tFound {
                Set tProblem = tEntry.%Get("descriptor") _ ": parentScope '" _ tParentScope _ "' names no built descriptor with that route and an id (DW-1020)"
                Quit
            }
        }
    } Catch ex {
        Set tProblem = "the parentScope roster could not be validated: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>The keys a declared <code>rowTarget</code> may carry (AD-5, Story 6.10).</p>
Parameter ROWTARGETKEYS = "route,field";

/// <p>What is wrong with <var>pDeclaration</var>'s declared <code>rowTarget</code>, or
/// <code>""</code> when nothing is, including when none is declared (AD-5, Story 6.10). A row
/// target is a list's single cross-screen row link: the field its name cell encodes and the
/// route that link opens, resolved ahead of the paired-surface chain in
/// <file>ui/src/app/shell/data-table.ts</file> -- because a list keyed by something other than
/// the linked entity (the Locks list's removal id, say) would otherwise link its own id route,
/// which names the wrong thing.</p>
/// <p>Declarable only on a <code>list</code> archetype that also declares a <code>table</code>,
/// since exactly one column's <code>kind</code> is <code>name</code>
/// (<method>TableProblem</method>) and a row target replaces what that column would otherwise
/// link to. Its <code>route</code> is a non-empty string other than the declaring screen's own
/// route -- a row already reaches its own route through the id chain -- and its <code>field</code>
/// is a non-empty string that is one of <code>read.fields</code>, since
/// <file>data-table.ts</file> reads it off the row.</p>
/// <p>Whether the named route resolves to a built, id-keyed screen that does not already pair
/// its own surface is <method>RowTargetResolutionProblem</method>'s question, checked over the
/// whole roster once every declaration's own shape is sound.
/// <file>ui/tools/screen-mirror.mjs</file>'s <code>rowTargetProblem</code> returns the same
/// sentence for every case in <class>OcuPilot.Test.RowTargetCorpus</class>.</p>
/// <p><b>Public, unlike <method>MalformedPair</method></b>, so the shapes above can be exercised
/// as values rather than as a fixture descriptor per shape.</p>
ClassMethod RowTargetProblem(pDeclaration As %DynamicObject) As %String
{
    Set tProblem = ""
    Try {
        Set tType = pDeclaration.%GetTypeOf("rowTarget")
        If (tType = "unassigned") || (tType = "null") Quit
        If tType '= "object" {
            Set tProblem = "rowTarget is not an object naming its route and field (AD-5)"
            Quit
        }
        Set tTarget = pDeclaration.%Get("rowTarget")
        Set tProblem = ..UnknownKeyProblem(tTarget, "rowTarget", $ListFromString(..#ROWTARGETKEYS))
        If tProblem '= "" Quit
        If pDeclaration.%Get("archetype") '= "list" {
            Set tProblem = "rowTarget is declared on a '" _ pDeclaration.%Get("archetype") _ "' archetype, and a row target is a list's own row link (AD-5)"
            Quit
        }
        If pDeclaration.%GetTypeOf("table") '= "object" {
            Set tProblem = "rowTarget is declared without a table, and a row target replaces the table's name column's own link (AD-5)"
            Quit
        }
        If (tTarget.%GetTypeOf("route") '= "string") || (tTarget.%Get("route") = "") {
            Set tProblem = "rowTarget.route is empty, and a row target names the route it opens"
            Quit
        }
        If tTarget.%Get("route") = pDeclaration.%Get("route") {
            Set tProblem = "rowTarget.route '" _ tTarget.%Get("route") _ "' is this screen's own route, and a row already reaches it through its own id (AD-5)"
            Quit
        }
        If (tTarget.%GetTypeOf("field") '= "string") || (tTarget.%Get("field") = "") {
            Set tProblem = "rowTarget.field is empty, and a row target names the field its link encodes"
            Quit
        }
        Set tFields = ""
        Set tFieldsArray = pDeclaration.%Get("read").%Get("fields")
        If $IsObject(tFieldsArray) && tFieldsArray.%IsA("%Library.DynamicArray") {
            Set tFieldIterator = tFieldsArray.%GetIterator()
            While tFieldIterator.%GetNext(.tFieldIndex, .tFieldValue) {
                If '$IsObject(tFieldValue) Set tFields = tFields _ $ListBuild(tFieldValue)
            }
        }
        If '$ListFind(tFields, tTarget.%Get("field")) {
            Set tProblem = "rowTarget.field '" _ tTarget.%Get("field") _ "' is not one of read.fields"
            Quit
        }
    } Catch ex {
        Set tProblem = "rowTarget could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>Whether some other built entry in <var>pRoster</var> already pairs <var>pRoute</var>'s own
/// surface -- an editor or document viewer at <code>&lt;pRoute&gt;/edit</code> or
/// <code>&lt;pRoute&gt;/document</code> (Story 3.5's and Story 6.2's route conventions), or a
/// detail screen or child list whose <code>parentScope</code> is <var>pRoute</var> -- the four
/// surfaces <file>ui/src/app/core/navigation.ts</file>'s <code>editorScreenFor</code>,
/// <code>documentScreenFor</code>, <code>detailScreenFor</code> and <code>childListFor</code>
/// pair a list with, named by route and <code>parentScope</code> alone. Deliberately broader than
/// those four, which each also require the candidate to be unlisted and id-keyed: this rule counts
/// a built candidate at either route, so it refuses a declaration the client would have left
/// unpaired rather than admitting one it would pair. A row's name cell links to one place, so a
/// screen that already has one of these declares no <code>rowTarget</code> as well
/// (<method>RowTargetResolutionProblem</method>).</p>
ClassMethod RowTargetPairsOwnSurface(pRoute As %String, pRoster As %DynamicArray) As %Boolean [ Private ]
{
    Set tFound = 0
    Try {
        Set tIterator = pRoster.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            Set tCandidate = tEntry.%Get("declaration")
            If ''tCandidate.%Get("built") = 0 Continue
            Set tCandidateRoute = tCandidate.%Get("route")
            If (tCandidateRoute = (pRoute _ "/edit")) || (tCandidateRoute = (pRoute _ "/document")) {
                Set tFound = 1
                Quit
            }
            If (tCandidate.%GetTypeOf("parentScope") = "string") && (tCandidate.%Get("parentScope") = pRoute) && (pRoute '= "") {
                Set tFound = 1
                Quit
            }
        }
    } Catch {
        Set tFound = 0
    }
    Quit tFound
}

/// <p>What is wrong with how <var>pRoster</var>'s declared <code>rowTarget</code>s resolve, or
/// <code>""</code> (AD-5, Story 6.10). <var>pRoster</var> is <method>Validate</method>'s own
/// array of <code>{descriptor, declaration}</code> entries, one per descriptor in the package.</p>
/// <p>A declared <code>rowTarget.route</code> must name some other entry's <code>route</code>,
/// that entry must be <code>built</code>, its <code>id.kind</code> must not be <code>none</code>,
/// and the declaring screen must not already pair its own surface
/// (<method>RowTargetPairsOwnSurface</method>) -- a row's name cell links to one place.
/// <file>ui/tools/screen-mirror.mjs</file>'s <code>rowTargetResolutionProblem</code> returns the
/// same sentence for every roster case in <class>OcuPilot.Test.RowTargetCorpus</class>.</p>
/// <p><b>Public, like <method>TabGroupProblem</method></b>, so a corpus roster can be run through
/// it directly rather than through a fixture registry per roster.</p>
ClassMethod RowTargetResolutionProblem(pRoster As %DynamicArray) As %String
{
    Set tProblem = ""
    Try {
        Set tOuter = pRoster.%GetIterator()
        While tOuter.%GetNext(.tOuterIndex, .tEntry) {
            Set tDeclaration = tEntry.%Get("declaration")
            If tDeclaration.%GetTypeOf("rowTarget") '= "object" Continue
            Set tTarget = tDeclaration.%Get("rowTarget")
            Set tRoute = tTarget.%Get("route")
            Set tOwnRoute = tDeclaration.%Get("route")
            Set tCandidate = ""
            Set tInner = pRoster.%GetIterator()
            While tInner.%GetNext(.tInnerIndex, .tCandidateEntry) {
                If tInnerIndex = tOuterIndex Continue
                Set tCandidateDecl = tCandidateEntry.%Get("declaration")
                If tCandidateDecl.%Get("route") = tRoute Set tCandidate = tCandidateDecl
            }
            If tCandidate = "" {
                Set tProblem = tEntry.%Get("descriptor") _ ": rowTarget.route '" _ tRoute _ "' names no declared screen (AD-5)"
                Quit
            }
            If ''tCandidate.%Get("built") = 0 {
                Set tProblem = tEntry.%Get("descriptor") _ ": rowTarget.route '" _ tRoute _ "' names a screen that is not built (AD-5)"
                Quit
            }
            Set tIdKind = ""
            If tCandidate.%GetTypeOf("id") = "object" Set tIdKind = tCandidate.%Get("id").%Get("kind")
            If (tIdKind = "") || (tIdKind = "none") {
                Set tProblem = tEntry.%Get("descriptor") _ ": rowTarget.route '" _ tRoute _ "' names a screen with no id, and a row target's field decodes into that screen's own id (AD-5)"
                Quit
            }
            If ..RowTargetPairsOwnSurface(tOwnRoute, pRoster) {
                Set tProblem = tEntry.%Get("descriptor") _ ": rowTarget is declared on a screen that already pairs its own surface, and a row's name cell links to one place (AD-5)"
                Quit
            }
        }
    } Catch ex {
        Set tProblem = "the rowTarget roster could not be validated: " _ ex.DisplayString()
    }
    Quit tProblem
}

}
