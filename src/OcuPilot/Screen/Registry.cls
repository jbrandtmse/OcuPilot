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
/// or whose route collides with another's. For both the <b>entity type</b> and the
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
        For tI = 1:1:$ListLength(tList) {
            Set tClass = $List(tList, tI)
            Set tDeclSC = $ClassMethod(tClass, "DeclarationJson", .tObject)
            If $$$ISERR(tDeclSC) {
                Set pProblem = tClass _ ": " _ $System.Status.GetErrorText(tDeclSC)
                Quit
            }
            Set tArea = $ClassMethod(tClass, "AreaKey")
            If '##class(OcuPilot.Screen.Area).Exists(tArea) {
                Set pProblem = tClass _ ": area '" _ tArea _ "' is not one OcuPilot.Screen.Area declares"
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
            If $ClassMethod(tClass, "ToolIdentifier") = "" {
                Set pProblem = tClass _ ": toolIdentifier is empty, and a tool name is never derived from a route or a display name"
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
            ; AD-43: the descriptor is the only place a screen says whether it refreshes and at
            ; what rates, so a malformed pair has to fail where it is declared. Refusing it here
            ; means install stops; the alternative is a screen that binds the shared framework at
            ; render time and arms a timer at a rate nobody declared.
            Set tRefreshProblem = ..RefreshProblem($ClassMethod(tClass, "Refreshes"), $ClassMethod(tClass, "RefreshRates"))
            If tRefreshProblem '= "" {
                Set pProblem = tClass _ ": " _ tRefreshProblem
                Quit
            }
            Set tRoute = $ClassMethod(tClass, "Route")
            If $ListFind(tRoutes, tRoute) > 0 {
                Set pProblem = tClass _ ": route '" _ tRoute _ "' is already declared by another descriptor"
                Quit
            }
            Set tRoutes = tRoutes _ $ListBuild(tRoute)
        }
    } Catch ex {
        Set pProblem = "the descriptor roster could not be validated: " _ ex.DisplayString()
        Set tSC = ex.AsStatus()
    }
    ; A problem is a refusal, not a report: the status carries it too, so a caller that checks
    ; only $$$ISERR cannot read an invalid roster as a valid one.
    If $$$ISOK(tSC) && (pProblem '= "") Set tSC = $$$ERROR($$$GeneralError, pProblem)
    Quit tSC
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
