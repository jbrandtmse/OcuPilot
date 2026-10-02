/// <p>The <code>(entity type, scope, id)</code> triple (AD-13): that a key round-trips every id
/// in <method>OcuPilot.Test.EntityId.Corpus</method>, that one name in two namespaces is two
/// entities, that the type is validated against the kernel vocabulary, and that the scope half
/// resolves from a descriptor's declared <code>scope</code>.</p>
/// <p>The id half is the same fixed corpus <class>OcuPilot.Test.EntityId</class> runs through the
/// URL codec, so the two grammars cannot drift on what an id may contain.</p>
Class OcuPilot.Test.EntityRef Extends %UnitTest.TestCase
{

/// <p>The entity type the round-trip rows use: a declared value, so the refusal rows are the only
/// ones testing an undeclared one, and one <parameter>OcuPilot.Kernel.EntityRef.IDRULES</parameter>
/// declares no rule for, so the corpus round-trips verbatim. <code>task</code> held this place
/// until Story 5.11 gave it the <code>integer</code> rule, <code>role</code> until Story 8.3 gave it
/// <code>foldcase</code>, <code>resource</code> until Story 8.4 did, <code>service</code> until
/// Story 9.9 did, and <code>database</code> until Story 18.4 gave it <code>directoryset</code>.</p>
Parameter KNOWNTYPE = "device";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>AC5 -- every corpus id survives a reference key unchanged, and the id reaches the key
/// verbatim rather than through <method>OcuPilot.Kernel.EntityId.Encode</method>, whose output
/// has no inverse on its own (encode-twice, decode-once).</p>
/// <p>Mutation: build the key from <method>OcuPilot.Kernel.EntityId.Encode</method> -> the
/// verbatim assertion goes red for the rows carrying a space, a slash, a percent sign or a
/// non-ASCII character, and the round trip goes red with it.</p>
Method TestEveryCorpusIdRoundTripsThroughAReferenceKey()
{
    Set tCorpus = ##class(OcuPilot.Test.EntityId).Corpus()
    For tI = 1:1:$ListLength(tCorpus) {
        Set tId = $List(tCorpus, tI)
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key(..#KNOWNTYPE, "USER", tId, .tKey)
        Do $$$AssertStatusOK(tSC, "corpus row " _ tI _ " builds a key")
        Do $$$AssertTrue((tKey [ tId), "corpus row " _ tI _ " reaches the key verbatim, not through the URL codec")

        Set tParseSC = ##class(OcuPilot.Kernel.EntityRef).Parse(tKey, .tType, .tScope, .tParsed)
        Do $$$AssertStatusOK(tParseSC, "corpus row " _ tI _ " parses back")
        Do $$$AssertEquals(tType, ..#KNOWNTYPE, "corpus row " _ tI _ " keeps its entity type")
        Do $$$AssertEquals(tScope, "USER", "corpus row " _ tI _ " keeps its scope")
        Do $$$AssertEquals(tParsed, tId, "corpus row " _ tI _ " keeps its id byte for byte")
    }
}

/// <p>AC4 -- one name in two namespaces is two entities: the same type and id under two scopes
/// produce two different keys, each parsing back to its own triple. Without the scope half a
/// confirm could re-read the wrong object and find a matching fingerprint (AD-6).</p>
/// <p>Mutation: drop the scope from the key in
/// <method>OcuPilot.Kernel.EntityRef.Key</method> -> the two keys become equal and this goes
/// red.</p>
Method TestOneNameInTwoNamespacesIsTwoEntities()
{
    Set tName = "Nightly purge"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key(..#KNOWNTYPE, "USER", tName, .tUser), "the USER key builds")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key(..#KNOWNTYPE, "HSCUSTOM", tName, .tCustom), "the HSCUSTOM key builds")
    Do $$$AssertNotEquals(tUser, tCustom, "the same task name in two namespaces is two keys")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Parse(tUser, .tTypeA, .tScopeA, .tIdA), "the USER key parses")
    Do $$$AssertEquals(tScopeA, "USER", "back to its own namespace")
    Do $$$AssertEquals(tIdA, tName, "and its own id")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Parse(tCustom, .tTypeB, .tScopeB, .tIdB), "the HSCUSTOM key parses")
    Do $$$AssertEquals(tScopeB, "HSCUSTOM", "back to its own namespace")
    Do $$$AssertEquals(tIdB, tName, "and the same id")
}

/// <p>A composite id passes through a key unharmed: the two separators are different code
/// points, so the key splits into three parts and the id then splits into its own on the
/// codec's separator.</p>
/// <p>The type is one whose ids are the instance's own strings, so the id reaches the key
/// verbatim and the round trip is over every byte of it. A web application's id is canonicalized
/// instead, which <method>TestAWebApplicationIdReachesAKeyInOneSpelling</method> pins.</p>
/// <p>Mutation: set <parameter>OcuPilot.Kernel.EntityRef.REFSEPARATOR</parameter> equal to
/// <parameter>OcuPilot.Kernel.EntityId.COMPOSITESEPARATOR</parameter> -> the composite id's first
/// part is read as the key's id and the rest is lost, so the part assertions go red.</p>
Method TestACompositeIdPassesThroughAKeyUnharmed()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).#REFSEPARATOR, ##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR + 1, "the reference separator is one code point above the composite one")

    Set tJoined = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("HSCUSTOM", "/csp/myapp"))
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key(..#KNOWNTYPE, "instance", tJoined, .tKey), "a composite id builds a key")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Parse(tKey, .tType, .tScope, .tId), "and it parses back")
    Do $$$AssertEquals(tId, tJoined, "with the composite id whole")

    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(tId)
    Do $$$AssertEquals($ListLength(tParts), 2, "which still splits into its own parts")
    Do $$$AssertEquals($List(tParts, 1), "HSCUSTOM", "in order")
    Do $$$AssertEquals($List(tParts, 2), "/csp/myapp", "including the part that holds a slash")
}

/// <p>AD-34, DW-1359 -- a web application's id reaches a key in one spelling, so two spellings the
/// instance resolves to one application are one scoped target. Normalization is keyed by entity
/// type: a task's name and a user's name are the instance's own strings and reach a key
/// untouched.</p>
/// <p>This is the necessary condition only. That the second confirm of one target is refused and
/// its write never reaches the port is
/// <class>OcuPilot.Test.ProposalSpelling</class>'s, against a real application.</p>
/// <p>Mutation: answer <var>pId</var> verbatim from
/// <method>OcuPilot.Kernel.EntityRef.NormalizedId</method>'s web-application arm -> every
/// one-key assertion below goes red and the type-keyed ones stay green.</p>
Method TestAWebApplicationIdReachesAKeyInOneSpelling()
{
    Set tForms = $ListBuild("/CSP/OcuPilotProbeSpelling", "/csp/ocupilotprobespelling/", "/CSP/OCUPILOTPROBESPELLING///")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", "/csp/ocupilotprobespelling", .tCanonical)
    Do $$$AssertStatusOK(tSC, "the canonical spelling builds a key")
    For tI = 1:1:$ListLength(tForms) {
        Set tForm = $List(tForms, tI)
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", tForm, .tKey), "'" _ tForm _ "' builds a key")
        Do $$$AssertEquals(tKey, tCanonical, "and it is the same key the canonical spelling built, so the two are one scoped target")
    }

    ; A stored reference is canonicalized at the point of use as well, which is what serializes a
    ; row written into the store directly (OcuPilot.Kernel.State.Propose.GuardedClaimAndClose).
    Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityRef).#REFSEPARATOR)
    Set tStored = "web-application" _ tSeparator _ "instance" _ tSeparator _ "/CSP/OcuPilotProbeSpelling/"
    Do $$$AssertNotEquals(tStored, tCanonical, "a ref stored in a second spelling is not the canonical one")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).Canonical(tStored), tCanonical, "and Canonical reads it as the target it names")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).Canonical("not a reference key"), "not a reference key", "while a key it cannot read comes back as it came")

    ; Type-keyed: a name the instance holds case-sensitively is not folded.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key(..#KNOWNTYPE, "USER", "Nightly Purge", .tTask), "a task name builds a key")
    Do $$$AssertTrue((tTask [ "Nightly Purge"), "and reaches it in the case it was given")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("role", "instance", "%All", .tRole), "a role name builds a key")
    Do $$$AssertTrue((tRole [ "%all"), "folded, because the instance resolves a role name without regard to case")

    ; An id that normalizes to nothing is an id no reference carries, rather than a key with none.
    Do $$$AssertStatusNotOK(##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", "/", .tSlash), "an id that normalizes to nothing is refused")
    Do $$$AssertEquals(tSlash, "", "with no key handed back")
}

/// <p>The type is the kernel's closed vocabulary, on every entry point: a key, a parse and a wire
/// object all refuse a value <method>OcuPilot.Kernel.EntityType.IsKnown</method> does not
/// hold.</p>
/// <p>Mutation: drop the <method>Validate</method> call from
/// <method>OcuPilot.Kernel.EntityRef.Parse</method> -> the parse assertion goes red while the
/// other two stay green, which is what shows all three are checked and not only the builder.</p>
Method TestAnUnknownEntityTypeIsRefusedEverywhere()
{
    Set tBad = "not-an-entity-type"
    Do $$$AssertTrue('##class(OcuPilot.Kernel.EntityType).IsKnown(tBad), "the probe value is not in the vocabulary")

    Do $$$AssertStatusNotOK(##class(OcuPilot.Kernel.EntityRef).Key(tBad, "USER", "x", .tKey), "a key over an unknown type is refused")
    Do $$$AssertEquals(tKey, "", "and no key is handed back")

    Set tHandBuilt = tBad _ $Char(##class(OcuPilot.Kernel.EntityRef).#REFSEPARATOR) _ "USER" _ $Char(##class(OcuPilot.Kernel.EntityRef).#REFSEPARATOR) _ "x"
    Do $$$AssertStatusNotOK(##class(OcuPilot.Kernel.EntityRef).Parse(tHandBuilt, .tType, .tScope, .tId), "a key that names an unknown type is refused on the way back too")
    Do $$$AssertEquals(tType, "", "and nothing is handed back")

    Do $$$AssertStatusNotOK(##class(OcuPilot.Kernel.EntityRef).Wire(tBad, "USER", "x", .tObject), "and a wire object over one is refused")
    Do $$$AssertTrue('$IsObject(tObject), "with no object handed back")
}

/// <p>A reference names something: an empty scope and an empty id are both refused, and a
/// malformed key -- one carrying fewer than three parts -- is refused rather than read as a
/// triple with empty halves.</p>
Method TestAReferenceWithoutAScopeOrAnIdIsRefused()
{
    Do $$$AssertStatusNotOK(##class(OcuPilot.Kernel.EntityRef).Key(..#KNOWNTYPE, "", "x", .tNoScope), "an empty scope is refused -- 'instance' is the literal for an object that has none")
    Do $$$AssertStatusNotOK(##class(OcuPilot.Kernel.EntityRef).Key(..#KNOWNTYPE, "USER", "", .tNoId), "and an empty id is refused")
    Do $$$AssertStatusNotOK(##class(OcuPilot.Kernel.EntityRef).Parse(..#KNOWNTYPE _ $Char(##class(OcuPilot.Kernel.EntityRef).#REFSEPARATOR) _ "USER", .tType, .tScope, .tId), "a key with only two parts is refused")
    Do $$$AssertStatusNotOK(##class(OcuPilot.Kernel.EntityRef).Parse("", .tType2, .tScope2, .tId2), "and so is an empty key")
}

/// <p>AC4's scope half -- a descriptor declaring <code>namespace</code> resolves to the request's
/// stashed scope and one declaring <code>instance</code> to the literal. Any third spelling
/// resolves to nothing, which is why
/// <method>OcuPilot.Screen.Registry.Validate</method> refuses it before a descriptor carrying one
/// can reach a roster.</p>
/// <p>Mutation: return <code>$Namespace</code> instead of
/// <method>OcuPilot.Kernel.Scope.Current</method> for <code>namespace</code> -> the stashed
/// assertion goes red while the fallback one stays green.</p>
Method TestTheScopeHalfResolvesFromTheDeclaredScope()
{
    Set tExecuting = $Namespace
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).ScopeFor("instance"), "instance", "a configuration object's scope is the literal")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).ScopeFor("namespace"), tExecuting, "and a namespace-scoped one falls back to the namespace in effect")

    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).ScopeFor("namespace"), "USER", "a namespace-scoped entity takes the request's resolved scope")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).ScopeFor("instance"), "instance", "while a configuration object does not move with it")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).ScopeFor(##class(OcuPilot.Test.Scope.Bad).#BADSCOPE), "", "and a third spelling resolves to nothing at all")

    ; The two declared values are the descriptors' own, read from the roster rather than
    ; re-spelled here.
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Descriptor.Home", "Scope"), "instance", "Home declares the instance scope")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.Screen.Sub", "Scope"), "namespace", "and a namespace-scoped fixture declares the other")
}

/// <p>DW-1364 -- the id rule is a declared table, not a branch, because
/// <file>ui/tools/screen-mirror.mjs</file> reads it and the client applies the same rule. This
/// pins the declaration itself: every pair names a type the kernel vocabulary holds and a rule
/// <parameter>OcuPilot.Kernel.EntityRef.IDRULENAMES</parameter> declares, the declared rule is
/// what <method>OcuPilot.Kernel.EntityRef.NormalizedId</method> applies, and a type with no pair
/// is verbatim.</p>
/// <p>That the client ends up with the same key is <file>ui/tools/entity-ref.test.mjs</file>'s;
/// that the generator refuses an undeclared rule is
/// <file>ui/tools/screen-mirror.test.mjs</file>'s. This is the instance half.</p>
/// <p>Mutation: add <code>task:foldcase-striptrailingslash</code> to
/// <parameter>OcuPilot.Kernel.EntityRef.IDRULES</parameter> -> the verbatim-for-an-unruled-type
/// assertion goes red; remove the <code>web-application</code> pair -> the folded assertions go
/// red while the roster assertions stay green.</p>
Method TestTheIdRuleTableIsDeclaredAndIsWhatNormalizationApplies()
{
    Set tRaw = ##class(OcuPilot.Kernel.EntityRef).#IDRULES
    Set tNames = ##class(OcuPilot.Kernel.EntityRef).#IDRULENAMES
    Do $$$AssertTrue(tRaw '= "", "the table declares at least one pair, so the generator has something to mirror")

    Set tRuled = ""
    For tI = 1:1:$Length(tRaw, ",") {
        Set tPair = $Piece(tRaw, ",", tI)
        If tPair = "" Continue
        Set tType = $Piece(tPair, ":", 1)
        Set tRule = $Piece(tPair, ":", 2)
        Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown(tType), "pair " _ tI _ " names a declared entity type: " _ tType)
        Do $$$AssertTrue($ListFind($ListFromString(tNames, ","), tRule) > 0, "pair " _ tI _ " names a rule IDRULENAMES declares: " _ tRule)
        Set tRuled = tRuled _ $ListBuild(tType)
    }

    ; The one rule Release 1 declares, applied by the type the table names it for and by no other.
    Do $$$AssertTrue($ListFind(tRuled, "web-application") > 0, "the web-application pair is the one DW-1359 added")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("web-application", "/API/OcuPilot/"), "/api/ocupilot", "the declared rule folds case and strips every trailing slash")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("web-application", "/API/OCUPILOT///"), "/api/ocupilot", "including several")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("web-application", "api/ocupilot"), "api/ocupilot", "and it goes exactly as far as the instance's own resolution does")

    ; A type the table holds no pair for canonicalizes to itself, which is what makes adding one a
    ; decision about that type rather than a default applied to it.
    Do $$$AssertTrue($ListFind(tRuled, ..#KNOWNTYPE) = 0, "the corpus type declares no rule, which is what makes its round trip verbatim")

    ; Story 5.11's rule: a task is addressed by the vendor's integer id, which the model supplies as
    ; a string, so every spelling of one number is one key. A value the rule cannot read as an
    ; integer is folded to lower case: a task create's target is the name (Story 9.7).
    Do $$$AssertTrue($ListFind(tRuled, "task") > 0, "the task pair is the one Story 5.11 added")
    For tSpelling = "7", "007", "+7", " 7 ", "0000007" {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("task", tSpelling), "7", "'" _ tSpelling _ "' folds to its plain decimal spelling")
    }
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("task", "-0"), "0", "a negative zero is zero")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("task", "-007"), "-7", "and a negative id keeps its sign")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("task", $Char(9) _ "7"), "7", "a tab folds like the space does")
    ; The same corpus the client twin folds and refuses (ui/tools/entity-ref.test.mjs): a rule whose
    ; point is that two languages agree is only pinned where both sides answer the same inputs.
    For tVerbatim = "7.0", "abc", "7a", "0x7", "1 2" {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("task", tVerbatim), tVerbatim, "'" _ tVerbatim _ "' is not an integer and keeps its spelling")
    }
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("task", "OcuP97Nightly"), "ocup97nightly", "a task name folds to lower case, so two spellings of one name are one target (AD-13, AD-54)")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("task", ""), "", "and an empty id is answered verbatim rather than folded to a number")
    ; Story 16.6's rule: a process id may name a set of pids, each once, ascending, in the integer
    ; rule's spelling -- so two spellings of one set are one key -- and a single pid reads as the
    ; integer rule reads it. The order is on the string (sign, length, digits), as the client twin
    ; (ui/tools/entity-ref.test.mjs) answers the same corpus.
    Do $$$AssertEquals($Piece(##class(OcuPilot.Kernel.EntityRef).#IDRULES, "process:", 2) [ "integerset", 1, "the process pair names the integerset rule")
    For tCase = $ListBuild(" 907,812, 812", "812,907"), $ListBuild("812", "812"), $ListBuild(" 007 ", "7"), $ListBuild("10,9,100", "9,10,100"), $ListBuild("+0,-0,0", "0"), $ListBuild("-3,2,-12", "-12,-3,2"), $ListBuild($Char(9) _ "5,4", "4,5") {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("process", $List(tCase, 1)), $List(tCase, 2), "'" _ $List(tCase, 1) _ "' is the set " _ $List(tCase, 2))
    }
    For tVerbatim = "abc", "812,", ",812", "812,abc", "8 12", "7.0" {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("process", tVerbatim), tVerbatim, "'" _ tVerbatim _ "' is not a set of integers and keeps its spelling")
    }
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("process", "ABC,1"), "abc,1", "and is folded to lower case as the integer rule folds one")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("process", "instance", "907, 812,812", .tSetKey), "a spelled set builds a key")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("process", "instance", "812,907", .tCanonicalKey), "and so does the canonical one")
    Do $$$AssertEquals(tSetKey, tCanonicalKey, "and the two are one key")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId(..#KNOWNTYPE, "/API/OcuPilot/"), "/API/OcuPilot/", "so its ids are the instance's own strings")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("role", "%All"), "%all", "while a role's fold, by Story 8.3's rule")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("resource", "%DB_OcuPilot"), "%db_ocupilot", "and a resource's, by Story 8.4's")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("database-configuration", "OcuProbe183X"), "ocuprobe183x", "and a database configuration's, by Story 18.3's: the instance resolves a configuration name without regard to case")
    ; Story 18.4's rule: a database is addressed by its directory, kept exactly, or by a JSON array
    ; of directories -- the integrity check's set -- deduplicated and sorted, one member reading as
    ; itself. The same corpus runs through the client twin (ui/tools/entity-ref.test.mjs).
    Do $$$AssertTrue($ListFind(tRuled, "database") > 0, "the database pair is the one Story 18.4 added")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("database", "/Durable/IRIS/mgr/User/"), "/Durable/IRIS/mgr/User/", "a directory keeps its spelling")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("database", "[""/b/"",""/a/"",""/b""]"), "[""/a/"",""/b/""]", "a set drops a later spelling of one directory and sorts the rest")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("database", "[""/a/"",""/a""]"), "/a/", "and a set of one reads as that directory")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("database", "[1]"), "[1]", "while an array that is not of directories is kept exactly")
    ; Story 18.14's rule: a mapping is addressed by [namespace, Name], and only the namespace part
    ; folds -- a routine mapping's type suffix and a global mapping's subscript are the instance's
    ; own spelling. The same corpus runs through the client twin (ui/tools/entity-ref.test.mjs).
    Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR)
    For tType = "global-mapping", "routine-mapping", "package-mapping" {
        Do $$$AssertTrue($ListFind(tRuled, tType) > 0, "the " _ tType _ " pair is one Story 18.14 added")
    }
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("routine-mapping", "OcuProbe" _ tSeparator _ "Probe*_MAC"), "ocuprobe" _ tSeparator _ "Probe*_MAC", "a mapping folds its namespace part and keeps its name's spelling")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("global-mapping", "USER" _ tSeparator _ "Probe(""A"")"), "user" _ tSeparator _ "Probe(""A"")", "a global mapping's subscript keeps its case")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("package-mapping", "OcuProbe"), "ocuprobe", "and a value with no separator folds whole")
    ; Story 19.2's rule: a class or routine id may name a set of documents, split on commas, empty
    ; pieces dropped, each once, sorted by character code; a value with no comma, the literal import
    ; among them, is kept exactly. The same corpus runs through the client twin
    ; (ui/tools/entity-ref.test.mjs).
    For tType = "class", "routine" {
        Do $$$AssertTrue($ListFind(tRuled, tType) > 0, "the " _ tType _ " pair is one Story 19.2 added")
    }
    For tCase = $ListBuild("B.cls,A.cls,,B.cls", "A.cls,B.cls"), $ListBuild("a.cls,B.cls,%Z.cls", "%Z.cls,B.cls,a.cls"), $ListBuild("Z.mac,", "Z.mac"), $ListBuild(",,", ""), $ListBuild("12.mac,9.mac", "12.mac,9.mac"), $ListBuild("A.cls", "A.cls"), $ListBuild(" A.cls ", " A.cls "), $ListBuild("import", "import"), $ListBuild("Caf" _ $Char(233) _ ".cls,Cafe.cls", "Cafe.cls,Caf" _ $Char(233) _ ".cls") {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("class", $List(tCase, 1)), $List(tCase, 2), "'" _ $List(tCase, 1) _ "' is the set '" _ $List(tCase, 2) _ "'")
    }
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("routine", "B.mac,A.inc"), "A.inc,B.mac", "a routine set sorts the same way")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("class", "USER", "B.cls,A.cls", .tDocKey), "a spelled document set builds a key")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("class", "USER", "A.cls,B.cls", .tDocCanonical), "and so does the canonical one")
    Do $$$AssertEquals(tDocKey, tDocCanonical, "and the two are one key")

    ; A key built from a non-canonical spelling is the key built from the canonical one, which is
    ; the necessary condition behind AD-34's per-target lock.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", "/API/OcuPilot/", .tFromForm), "a non-canonical spelling builds a key")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", "/api/ocupilot", .tFromCanonical), "and so does the canonical one")
    Do $$$AssertEquals(tFromForm, tFromCanonical, "and the two are one key")
}

/// <p>The wire form a change event, a proposal target and an audit marker carry: exactly
/// <code>{type, scope, id}</code>, with the scope resolved by the caller.</p>
Method TestTheWireFormCarriesTheTripleAndNothingElse()
{
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Set tScope = ##class(OcuPilot.Kernel.EntityRef).ScopeFor("namespace")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Wire(..#KNOWNTYPE, tScope, "Nightly purge", .tObject), "the wire object builds")
    Do $$$AssertEquals(tObject.type, ..#KNOWNTYPE, "it carries the entity type")
    Do $$$AssertEquals(tObject.scope, "USER", "the resolved scope")
    Do $$$AssertEquals(tObject.id, "Nightly purge", "and the id")

    Set tKeys = 0
    Set tIterator = tObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys + 1
    }
    Do $$$AssertEquals(tKeys, 3, "and nothing else -- a reference is the triple, not a payload")
}

}
