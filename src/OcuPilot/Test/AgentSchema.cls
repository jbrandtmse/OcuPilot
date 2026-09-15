/// <p>AC1 -- the agent definition's schema, and <b>the absences that define it</b>, read off the
/// compiled class rather than off the source: no property that could hold a credential value, no
/// property typed as a persistent class, no collection property, a class name inside the storage
/// cap, and a storage section the compiler owns.</p>
/// <p><b>Why the absence needs a test at all.</b> Nothing about a schema makes a reviewer notice
/// a property that <i>is not</i> there, and the harvested original's own suite locked this same
/// absence for the same reason: the way an API key stops being logged is that there is nowhere to
/// put it. A property added later would compile, pass every other test in the suite, and be found
/// by nobody.</p>
/// <p>Introspection only -- this class creates no definition and no instance state, so it has no
/// teardown.</p>
Class OcuPilot.Test.AgentSchema Extends %UnitTest.TestCase
{

/// <p>The class under inspection.</p>
Parameter DEFINITIONCLASS = "OcuPilot.Kernel.State.Agent";

/// <p>The storage-global cap <file>scripts/check-objectscript.py</file> enforces on any class
/// reaching <class>%Persistent</class>, asserted here as well so the reason for the cap is
/// visible from the instance and not only from the checker.</p>
Parameter MAXCLASSNAMELENGTH As %Integer = 29;

/// <p>AC1 -- there is no <code>ApiKey</code> property, and no property whose name denotes a secret
/// value.</p>
/// <p><b>The pattern is not the log redactor's list, and the difference is the point.</b>
/// <parameter>OcuPilot.Kernel.Audit.Log.CREDENTIALNAMES</parameter> matches <i>log keys</i> and
/// deliberately over-matches, because over-masking a log line costs a reader one look at the code
/// while under-masking costs a credential. A schema check with the same list would refuse two
/// properties the design requires: <property>MaxTokens</property>, whose name contains
/// <code>token</code> and which is a count, and <property>CredentialName</property>, which holds a
/// credential's <b>name</b> -- scoped identity data OcuPilot stores on purpose (AD-35, AD-37),
/// never its value. So the names below denote a secret value rather than anything that might sit
/// near one, and the check that the two lists have not diverged where it matters is made
/// separately.</p>
/// <p><b>What is narrowed is the <i>substring</i> form of <code>token</code> and
/// <code>credential</code>, not the names themselves.</b> A property called exactly
/// <code>Key</code> or <code>Token</code> holds a secret whatever its neighbours are called, so
/// both are checked below as whole names -- which costs nothing, because no property on the
/// definition is exactly either.</p>
/// <p>Mutation: add <code>Property ApiKey As %String;</code> to
/// <class>OcuPilot.Kernel.State.Agent</class> -- this goes red naming ApiKey.</p>
Method TestNoPropertyCanHoldACredentialValue()
{
    Set tOffenders = ""
    Set tPatterns = $ListBuild("apikey", "secret", "password", "passwd", "pwd", "privatekey", "accesstoken", "refreshtoken", "bearertoken")
    Set tExact = $ListBuild("key", "token")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledProperty WHERE parent = ?", ..#DEFINITIONCLASS)
    Set tChecked = 0
    While tRS.%Next() {
        Set tProperty = tRS.%Get("Name")
        If $Extract(tProperty) = "%" Continue
        Set tChecked = tChecked + 1
        Set tFolded = $ZConvert(tProperty, "L")
        For tJ = 1:1:$ListLength(tPatterns) {
            If tFolded [ $List(tPatterns, tJ) Set tOffenders = tOffenders _ $Select(tOffenders = "": "", 1: ", ") _ tProperty
        }
        If $ListFind(tExact, tFolded) Set tOffenders = tOffenders _ $Select(tOffenders = "": "", 1: ", ") _ tProperty
    }
    Do $$$AssertTrue(tChecked > 0, "the compiled class was read: " _ tChecked _ " declared properties")
    Do $$$AssertEquals(tOffenders, "", "no property on the agent definition denotes a secret value")
    Do $$$AssertTrue('##class(%Dictionary.CompiledProperty).%ExistsId(..#DEFINITIONCLASS _ "||ApiKey"), "and there is no ApiKey property, which is the absence the harvested original locked too")
}

/// <p>The log redactor still masks the two names this schema check is narrower than it for, so the
/// narrowing above cannot quietly become a hole: a credential value logged under a key called
/// <code>apiKey</code> or <code>password</code> is still redacted whatever this class stores.</p>
Method TestTheLogRedactorStillCoversTheNamesThisCheckNarrows()
{
    For tName = "apikey", "password", "secret", "privatekey" {
        Do $$$AssertTrue(##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tName), "the log redactor still masks a key named " _ tName)
    }
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Audit.Log).IsCredentialName("credentialName"), "and a key named credentialName, which is why the change record's credential reference arrives redacted")
}

/// <p>AC1 -- every property is a <class>%Library</class> datatype: none is typed as a persistent
/// class, so the credential reference is a weak reference and not a foreign key (AD-37), and none
/// is a collection, so the persistent-storage rule's subtable question does not arise.</p>
/// <p>Mutation: retype <code>CredentialName</code> to a persistent class -- this goes red naming
/// it.</p>
Method TestEveryPropertyIsADatatypeAndNoneIsACollection()
{
    Set tForeign = ""
    Set tCollections = ""
    Set tChecked = 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name, Type, Collection FROM %Dictionary.CompiledProperty WHERE parent = ?", ..#DEFINITIONCLASS)
    While tRS.%Next() {
        Set tProperty = tRS.%Get("Name")
        If $Extract(tProperty) = "%" Continue
        Set tChecked = tChecked + 1
        If $Extract(tRS.%Get("Type"), 1, 9) '= "%Library." {
            Set tForeign = tForeign _ $Select(tForeign = "": "", 1: ", ") _ tProperty _ " is " _ tRS.%Get("Type")
        }
        If tRS.%Get("Collection") '= "" {
            Set tCollections = tCollections _ $Select(tCollections = "": "", 1: ", ") _ tProperty _ " is a " _ tRS.%Get("Collection")
        }
    }
    Do $$$AssertTrue(tChecked > 0, "the compiled class was read: " _ tChecked _ " declared properties")
    Do $$$AssertEquals(tForeign, "", "every property is a %Library datatype, so none is a reference to a persistent class")
    Do $$$AssertEquals(tCollections, "", "no property is a collection")
}

/// <p>AC1 -- the thirteen fields the acceptance criterion names are all present, so the absences
/// above are absences within a schema that actually holds the definition. Fourteen properties
/// answer the thirteen: AC1's "credential reference" is <property>EnvVarName</property> and
/// <property>CredentialName</property>, which the XOR invariant keeps to one at a time.</p>
Method TestEveryNamedFieldIsPresent()
{
    Set tMissing = ""
    For tProperty = "Name", "Provider", "Model", "EndpointUrl", "CredType", "EnvVarName", "CredentialName", "MaxTokens", "Temperature", "MaxIterationsPerTurn", "SystemPromptOverride", "ReadOnly", "RetentionDays", "Enabled" {
        If '##class(%Dictionary.CompiledProperty).%ExistsId(..#DEFINITIONCLASS _ "||" _ tProperty) {
            Set tMissing = tMissing _ $Select(tMissing = "": "", 1: ", ") _ tProperty
        }
    }
    Do $$$AssertEquals(tMissing, "", "the definition holds every field AC1 names")
}

/// <p>AC1 -- the class name is inside the storage-global cap.</p>
/// <p><b>The cap is not cosmetic.</b> The compiler hashes the storage global of a longer name, and
/// the harvest map records that happening to two of the sibling projects' own classes. The obvious
/// <code>...State.AgentDef</code> is 30 characters and would have been the next one.</p>
/// <p><b>The cap is read off the instance, not off this class's own parameters.</b> Comparing
/// <parameter>DEFINITIONCLASS</parameter> against <parameter>MAXCLASSNAMELENGTH</parameter> alone
/// cannot fail: renaming the production class moves <parameter>DEFINITIONCLASS</parameter> with
/// it and the comparison stays true. So the assertion sweeps every compiled class that reaches
/// <class>OcuPilot.Kernel.State.Base</class> and measures each name -- which a state class added
/// over the cap turns red, whatever it is called.
/// <file>scripts/check-objectscript.py</file>'s <code>check_naming</code> is still the gate that
/// fails the commit; this is the same cap asserted where the rest of the schema is.</p>
/// <p>Mutation: narrow the sweep's <code>Name %STARTSWITH 'OcuPilot.'</code> to a prefix no class
/// holds -- the coverage assertion goes red, which the parameter comparison it replaced could not
/// do, because nothing about the instance entered that comparison.</p>
Method TestTheClassNameIsInsideTheStorageGlobalCap()
{
    Set tOver = ""
    Set tSawDefinition = 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'OcuPilot.' AND PrimarySuper LIKE '%OcuPilot.Kernel.State.Base%'")
    Do $$$AssertTrue(tRS.%SQLCODE >= 0, "the state classes are readable from the class dictionary: SQLCODE " _ tRS.%SQLCODE)
    While tRS.%Next() {
        Set tName = tRS.%GetData(1)
        If tName = ..#DEFINITIONCLASS Set tSawDefinition = 1
        If $Length(tName) <= ..#MAXCLASSNAMELENGTH Continue
        Set tOver = tOver _ $Select(tOver = "": "", 1: ", ") _ tName _ " (" _ $Length(tName) _ ")"
    }
    Do $$$AssertEquals(tSawDefinition, 1, "the sweep covers " _ ..#DEFINITIONCLASS _ " itself")
    Do $$$AssertEquals(tOver, "", "every class reaching the state root is inside the " _ ..#MAXCLASSNAMELENGTH _ "-character storage-global cap")
}

/// <p>AC1 -- the storage section is the compiler's. The definition adds no storage globals of its
/// own: it shares <class>OcuPilot.Kernel.State.Base</class>'s extent, which is what the compiler
/// produces for a subclass whose source carries no <code>Storage</code> block, and the four
/// locations are read off <b>Base</b> rather than written down here so the assertion cannot drift
/// from the root it is about.</p>
/// <p><b>What this does and does not prove.</b> The compiler writes a <code>Storage</code>
/// definition into every persistent class on the server, so no instance-side reading can tell a
/// hand-written section from a generated one by its presence. What it can tell is whether the
/// section is still the default the compiler derives: a hand-written one that redirected this
/// class's data, index, id or stream global would go red here.</p>
Method TestTheStorageSectionIsTheCompilersOwn()
{
    Set tMine = ##class(%Dictionary.CompiledStorage).%OpenId(..#DEFINITIONCLASS _ "||Default")
    Set tRoot = ##class(%Dictionary.CompiledStorage).%OpenId("OcuPilot.Kernel.State.Base||Default")
    Do $$$AssertTrue($IsObject(tMine), "the definition's compiled storage is readable")
    Do $$$AssertTrue($IsObject(tRoot), "the state root's compiled storage is readable")
    If '$IsObject(tMine) || '$IsObject(tRoot) Quit
    Do $$$AssertEquals(tMine.DataLocation, tRoot.DataLocation, "the definition stores its data in the state root's extent, not a global of its own")
    Do $$$AssertEquals(tMine.IndexLocation, tRoot.IndexLocation, "and its indices there too")
    Do $$$AssertEquals(tMine.IdLocation, tRoot.IdLocation, "and its id counter")
    Do $$$AssertEquals(tMine.StreamLocation, tRoot.StreamLocation, "and its stream location")
    Set tClass = ##class(%Dictionary.CompiledClass).%OpenId(..#DEFINITIONCLASS)
    Do $$$AssertTrue($IsObject(tClass), "the definition's compiled class is readable")
    If $IsObject(tClass) Do $$$AssertEquals(tClass.StorageStrategy, "Default", "and the class names no storage strategy of its own")
    Do $$$AssertTrue(tRoot.DataLocation [ "OcuPilot", "the extent's data global is unhashed and matches OcuPilot's protected-global mapping pattern: " _ tRoot.DataLocation)
}

/// <p>AC4's structural half -- both indexes are declared, and both are unique. The behaviour they
/// buy is <class>OcuPilot.Test.AgentState</class>'s; what is pinned here is that "exactly one
/// default" rests on the storage layer rather than on every future caller remembering.</p>
Method TestBothIndexesAreDeclaredUnique()
{
    For tCase = "NameIdx|Name", "DefaultIdx|DefaultMark" {
        Set tIndex = $Piece(tCase, "|", 1)
        Set tObject = ##class(%Dictionary.CompiledIndex).%OpenId(..#DEFINITIONCLASS _ "||" _ tIndex)
        Do $$$AssertTrue($IsObject(tObject), tIndex _ " is declared on the definition")
        If '$IsObject(tObject) Continue
        Do $$$AssertEquals(tObject.Unique, 1, tIndex _ " is unique")
        Do $$$AssertEquals(tObject.Properties, $Piece(tCase, "|", 2), tIndex _ " is on " _ $Piece(tCase, "|", 2))
    }
}

}
