/// <p>The <code>(entity type, scope, id)</code> triple (AD-13): that a key round-trips every id
/// in <method>OcuPilot.Test.EntityId.Corpus</method>, that one name in two namespaces is two
/// entities, that the type is validated against the kernel vocabulary, and that the scope half
/// resolves from a descriptor's declared <code>scope</code>.</p>
/// <p>The id half is the same fixed corpus <class>OcuPilot.Test.EntityId</class> runs through the
/// URL codec, so the two grammars cannot drift on what an id may contain.</p>
Class OcuPilot.Test.EntityRef Extends %UnitTest.TestCase
{

/// <p>The entity type the round-trip rows use. A declared value, so the refusal rows are the
/// only ones testing an undeclared one.</p>
Parameter KNOWNTYPE = "task";

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
/// <p>Mutation: set <parameter>OcuPilot.Kernel.EntityRef.REFSEPARATOR</parameter> equal to
/// <parameter>OcuPilot.Kernel.EntityId.COMPOSITESEPARATOR</parameter> -> the composite id's first
/// part is read as the key's id and the rest is lost, so the part assertions go red.</p>
Method TestACompositeIdPassesThroughAKeyUnharmed()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).#REFSEPARATOR, ##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR + 1, "the reference separator is one code point above the composite one")

    Set tJoined = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("HSCUSTOM", "/csp/myapp"))
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", tJoined, .tKey), "a composite id builds a key")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Parse(tKey, .tType, .tScope, .tId), "and it parses back")
    Do $$$AssertEquals(tId, tJoined, "with the composite id whole")

    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(tId)
    Do $$$AssertEquals($ListLength(tParts), 2, "which still splits into its own parts")
    Do $$$AssertEquals($List(tParts, 1), "HSCUSTOM", "in order")
    Do $$$AssertEquals($List(tParts, 2), "/csp/myapp", "including the part that holds a slash")
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
