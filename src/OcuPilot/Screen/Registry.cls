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
/// whose archetype or classic link-out is not a permitted shape (AD-44,
/// <method>ClassicLinkProblem</method>), or whose route or tool identifier collides with
/// another's. For both the
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

/// <p>The tool-identifier shape a read-declaring descriptor carries: one lower-case area segment
/// and one lower-case screen segment, so its read tool is <code>&lt;toolIdentifier&gt;.read</code>
/// (Conventions, Tool naming).</p>
Parameter READTOOLIDENTIFIERPATTERN = "^[a-z][a-z0-9]*\.[a-z][a-z0-9]*$";

/// <p>What is wrong with <var>pDeclaration</var>'s <code>read</code>, or <code>""</code> when
/// nothing is (AD-36). <var>pDeclaration</var> is the whole parsed declaration, because the rules
/// reach <code>context.secretFields</code> and <code>toolIdentifier</code> as well.</p>
/// <p>A <code>read</code> that is absent or <code>null</code> is a screen with no read. Otherwise:
/// <code>source</code> is <code>{port: "admin", endpoint, type: "LIST"}</code> with a dotted
/// endpoint name and an optional <code>rowGet</code> (<method>RowGetProblem</method>);
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
/// <file>ui/tools/screen-mirror.mjs</file>'s <code>readProblem</code> refuses the same shapes before
/// the mirror is emitted.</p>
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
        Set tProblem = ..UnknownKeyProblem(tRead, "read", $ListBuild("source", "fields", "filter", "sort", "paging"))
        If tProblem '= "" Quit

        If tRead.%GetTypeOf("source") '= "object" {
            Set tProblem = "read.source is not an object naming its port, endpoint and type (AD-36)"
            Quit
        }
        Set tSource = tRead.%Get("source")
        Set tProblem = ..UnknownKeyProblem(tSource, "read.source", $ListBuild("port", "endpoint", "type", "rowGet"))
        If tProblem '= "" Quit
        If (tSource.%GetTypeOf("port") '= "string") || (tSource.%Get("port") '= "admin") {
            Set tProblem = "read.source.port '" _ tSource.%Get("port") _ "' is not 'admin', the one port a Release 1 read names (AD-2)"
            Quit
        }
        If (tSource.%GetTypeOf("endpoint") '= "string") || '$Match(tSource.%Get("endpoint"), "^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") {
            Set tProblem = "read.source.endpoint '" _ tSource.%Get("endpoint") _ "' is not a package-relative endpoint name"
            Quit
        }
        If (tSource.%GetTypeOf("type") '= "string") || (tSource.%Get("type") '= "LIST") {
            Set tProblem = "read.source.type '" _ tSource.%Get("type") _ "' is not 'LIST'"
            Quit
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
            Set tProblem = "read.paging 'cursor' is refused on an admin source, which accepts no cursor; declare 'cap' (AD-36)"
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
    } Catch ex {
        Set tProblem = "the read declaration could not be read: " _ ex.DisplayString()
    }
    Quit tProblem
}

/// <p>The rules a <code>read.source.rowGet</code> derived field may name (AD-36).</p>
Parameter ROWGETRULES = "beforeToday";

/// <p>What is wrong with <var>pSource</var>'s <code>rowGet</code>, or <code>""</code> (AD-36).
/// <var>pFields</var> is the read's declared fields.</p>
/// <p>An absent or <code>null</code> <code>rowGet</code> declares no detail call. Otherwise it is an
/// object carrying only <code>key</code> (one of <var>pFields</var>), <code>param</code> (a query
/// parameter name), <code>fields</code> (a non-empty array of unique names from <var>pFields</var>,
/// without <code>key</code>) and <code>derived</code>, an array of objects carrying only
/// <code>field</code> (one of <var>pFields</var>, neither <code>key</code> nor a detail field, and
/// not repeated), <code>rule</code> (one of <parameter>ROWGETRULES</parameter>) and
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
    Set tProblem = ..UnknownKeyProblem(tRowGet, tWhere, $ListBuild("key", "param", "fields", "derived"))
    If tProblem '= "" Quit tProblem

    If tRowGet.%GetTypeOf("key") '= "string" Quit tWhere _ ".key is not a string"
    Set tKey = tRowGet.%Get("key")
    If '$ListFind(pFields, tKey) Quit tWhere _ ".key '" _ tKey _ "' is not one of read.fields"
    If tRowGet.%GetTypeOf("param") '= "string" Quit tWhere _ ".param is not a string"
    If '$Match(tRowGet.%Get("param"), "^[A-Za-z][A-Za-z0-9]*$") Quit tWhere _ ".param '" _ tRowGet.%Get("param") _ "' is not a query parameter name"

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
/// <code>labelKey</code> and a <code>kind</code> from <parameter>TABLECOLUMNKINDS</parameter>, and
/// exactly one column is <code>name</code>. The declaration names a non-empty
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
        Set tProblem = ..UnknownKeyProblem(tColumn, tWhere, $ListBuild("field", "labelKey", "kind"))
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
        If 'tExempt {
            If tHref '= "" {
                Set tProblem = "classicLinkExemption declares an href while exempt is false; link parts without an exemption are a half-made declaration"
                Quit
            }
            If tLabel '= "" {
                Set tProblem = "classicLinkExemption declares a label while exempt is false; link parts without an exemption are a half-made declaration"
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
    } Catch ex {
        Set tProblem = "the classic link declaration could not be read: " _ ex.DisplayString()
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
