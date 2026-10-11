/// <p>The tool listing's per-process cache (AD-5, DW-2286): one cache serves every caller of
/// <method>OcuPilot.Screen.Tool.Registry.ListTools</method>, a class compiled or deleted in this
/// process or in another is seen on the next call, and only the listing is cached, only as copies.
/// Every claim is read off <method>OcuPilot.Screen.Tool.Registry.BuildCount</method> deltas, never
/// its absolute value, because the cache lives as long as the test process.</p>
/// <p>Needs a development or throwaway instance: it compiles and deletes
/// <code>OcuPilot.Test.RegistryCacheProbe.Late</code>, starts one child process to compile it, and
/// writes agent-ledger rows for its dispatches, which it removes after each test. Like <class>OcuPilot.Test.ToolDispatch</class>, it clears the stored governance policy
/// before each test and puts it back after, so it is not live-safe.</p>
Class OcuPilot.Test.RegistryCache Extends %UnitTest.TestCase
{

Parameter PRODUCTION = "OcuPilot.Screen.Tool.Registry";

Parameter FIXTURE = "OcuPilot.Test.RegistryCacheProbe.Registry";

Parameter BADREGISTRY = "OcuPilot.Test.BadFulfilment.Registry";

Parameter UNREADABLE = "OcuPilot.Test.RegistryCacheProbe.UnreadableRegistry";

Parameter PROBE = "OcuPilot.Test.ToolDispatchProbe";

Parameter COUNTER = "OcuPilot.Test.DispatchTool.Counter";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The turn key every dispatch of this class is answered under.</p>
Parameter TURNKEY = "registry-cache";

Parameter LATECLASS = "OcuPilot.Test.RegistryCacheProbe.Late";

Parameter LATENAME = "probe.cachelate.read";

Parameter LATEWIRE = "probe_cachelate_read";

/// <p>The keys of a listing entry, in order, and no others.</p>
Parameter ENTRYKEYS = "name,kind,class,descriptor,fulfilment,advertised";

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Do ..DropProbe()
    Do $ClassMethod(..#PROBE, "Reset")
    Do $ClassMethod(..#COUNTER, "Clear")
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ..DropProbe()
    Do $ClassMethod(..#PROBE, "Reset")
    Do $ClassMethod(..#COUNTER, "Clear")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(..#TURNKEY), "the ledger rows the test's production dispatch wrote are removed")
    Kill tRows
    Merge tRows = ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Do $$$AssertStatusOK(tSC, "the policy found before the test is put back")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).Matches(.tRows), "and reads back as it was")
    Quit $$$OK
}

/// <p>Create <code>OcuPilot.Test.RegistryCacheProbe.Late</code>, a read tool over the counting
/// fixture whose <parameter>ADVERTISED</parameter> is <var>pAdvertised</var>, and compile it,
/// replacing any earlier copy.</p>
ClassMethod CompileProbe(pAdvertised As %Boolean = 1) As %Status
{
    Set tSC = $$$OK
    Try {
        Do ..DropProbe()
        Set tClass = ##class(%Dictionary.ClassDefinition).%New(..#LATECLASS)
        Set tClass.Super = ..#COUNTER
        Set tClass.Description = "Test tool compiled by OcuPilot.Test.RegistryCache and deleted by its DropProbe."
        For tPair = $ListBuild("TOOLNAME", ..#LATENAME), $ListBuild("KIND", "read"), $ListBuild("DESCRIPTION", "A fixture read tool compiled while the listing is cached."), $ListBuild("ADVERTISED", +pAdvertised) {
            Set tParameter = ##class(%Dictionary.ParameterDefinition).%New()
            Set tParameter.Name = $List(tPair, 1)
            Set tParameter.Default = $List(tPair, 2)
            Do tClass.Parameters.Insert(tParameter)
        }
        Set tSC = tClass.%Save()
        If $$$ISERR(tSC) Quit
        Set tSC = $System.OBJ.Compile(..#LATECLASS, "ck-d")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the probe class if it exists.</p>
ClassMethod DropProbe()
{
    If ##class(%Dictionary.ClassDefinition).%ExistsId(..#LATECLASS) {
        Do $System.OBJ.Delete(..#LATECLASS, "-d")
    }
}

/// <p>The child process entry: compile the probe, then signal <code>ok</code>, or the error text,
/// to process <var>pParent</var>.</p>
ClassMethod CompileProbeJob(pParent As %Integer)
{
    Try {
        Set tSC = ..CompileProbe()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Do $System.Event.Signal(pParent, $Select($$$ISOK(tSC): "ok", 1: $System.Status.GetErrorText(tSC)))
}

/// <p>Answer one call to wire name <var>pWire</var> with <var>pInput</var> through
/// <class>OcuPilot.Test.ToolDispatchProbe</class>. <var>pResult</var> is the
/// <code>tool_result</code> block and <var>pName</var> the name recorded for it.</p>
Method DispatchOne(pWire As %String, pInput As %DynamicObject, Output pResult As %DynamicObject, Output pName As %String)
{
    Set tUse = {"type": "tool_use", "id": "toolu_1"}
    Do tUse.%Set("name", pWire, "string")
    Do tUse.%Set("input", pInput)
    Set tUses = []
    Do tUses.%Push(tUse)
    Set tSC = $ClassMethod(..#PROBE, "Answer", ..#TURNKEY, $Username, "", tUses, ..#LIMITS, .tResults, .tNames)
    Do $$$AssertStatusOK(tSC, "the dispatcher answers")
    Set pResult = $Select($IsObject($Get(tResults)): tResults.%Get(0), 1: {})
    Set pName = $Select($IsObject($Get(tNames)): tNames.%Get(0), 1: "")
}

/// <p>The keys of <var>pEntry</var>, comma-separated, in order.</p>
ClassMethod KeysOf(pEntry As %DynamicObject) As %String
{
    Set tKeys = ""
    Set tIterator = pEntry.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Quit tKeys
}

/// <p>Assert that the wire name of the probe is unknown to the fixture registry's dispatch.</p>
Method AssertProbeUnknown(pMessage As %String)
{
    Do ..DispatchOne(..#LATEWIRE, {}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""TOOL.UNKNOWN""}", pMessage)
}

/// <p>Assert that the probe is listed, advertised and answers through the fixture registry's dispatch,
/// and that its tool ran once more.</p>
Method AssertProbeAnswers(pMessage As %String)
{
    Set tCalls = $ClassMethod(..#COUNTER, "Calls", ..#LATENAME)
    Do ..DispatchOne(..#LATEWIRE, {"marker": "late"}, .tResult, .tName)
    Do $$$AssertEquals(tName _ "|" _ tResult."is_error", ..#LATENAME _ "|0", pMessage)
    Do $$$AssertEquals($ClassMethod(..#COUNTER, "Calls", ..#LATENAME) - tCalls, 1, "and the probe tool ran")
}

/// <p>AC1 -- after <method>OcuPilot.Screen.Tool.Registry.ForgetListing</method> one listing is built,
/// and then <code>Resolve</code>, <code>ResolveWire</code>, <code>ProviderTools</code>, the governance
/// gate and a production dispatch of the first advertised write tool build nothing more. The cached
/// answer equals a fresh build.</p>
/// <p>Mutation: <code>ListTools</code> skips the cache read and always builds -> this goes red.</p>
Method TestOneListingServesEveryCaller()
{
    Set tRegistry = ..#PRODUCTION
    Set tHeld = $ClassMethod(tRegistry, "BuildCount")
    Do $ClassMethod(tRegistry, "ForgetListing")
    Do $$$AssertEquals($ClassMethod(tRegistry, "BuildCount"), tHeld, "forgetting the listing leaves the build count alone")
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ListTools", .tList), "the registry lists its tools")
    Do $$$AssertEquals($ClassMethod(tRegistry, "BuildCount") - tHeld, 1, "one listing after ForgetListing builds exactly once, so the counter counts")

    Set tName = ""
    Set tIterator = tList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If (tEntry.kind = "write") && tEntry.advertised {
            Set tName = tEntry.name
            Quit
        }
    }
    Do $$$AssertTrue(tName '= "", "the listing holds an advertised write tool")
    If tName = "" Quit
    Set tWire = $ClassMethod(tRegistry, "WireName", tName)
    Set tBuilds = $ClassMethod(tRegistry, "BuildCount")

    Do $$$AssertStatusOK($ClassMethod(tRegistry, "Resolve", tName, .tResolved, 1), "Resolve answers as the governance gate asks it")
    Do $$$AssertEquals($Select($IsObject(tResolved): tResolved.name, 1: ""), tName, "and finds the write tool")
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ResolveWire", tWire, .tWired), "ResolveWire answers")
    Do $$$AssertEquals($Select($IsObject(tWired): tWired.name, 1: ""), tName, "and finds it by its wire name")
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ProviderTools", .tProvider), "ProviderTools answers")
    Do $$$AssertTrue(+$Get(tProvider) > 0, "and advertises tools")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide(tName, "write", $Username, {}, .tDecision), "the governance gate decides")

    ; The schema refuses the undeclared argument before the tool is invoked, so the call mints nothing.
    Set tUse = {"type": "tool_use", "id": "toolu_1", "input": {"registryCacheUndeclared": 1}}
    Do tUse.%Set("name", tWire, "string")
    Set tUses = []
    Do tUses.%Push(tUse)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Agent.Dispatch).Answer(..#TURNKEY, $Username, "", tUses, ..#LIMITS, .tResults, .tNames), "a production dispatch answers")
    Do $$$AssertEquals(tNames.%Get(0), tName, "recorded under the tool's canonical dotted name")
    Do $$$AssertEquals(tResults.%Get(0)."is_error", 1, "and refused")

    Do $$$AssertEquals($ClassMethod(tRegistry, "BuildCount") - tBuilds, 0, "none of the five callers built the listing again")
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ListTools", .tCached), "the cached listing is read")
    Do $ClassMethod(tRegistry, "ForgetListing")
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ListTools", .tFresh), "and a fresh one built")
    Do $$$AssertEquals(tCached.%ToJSON(), tFresh.%ToJSON(), "the cached answer equals a fresh build")
}

/// <p>AC3 -- a tool class compiled in this process is listed by the next call, a recompile with
/// <parameter>ADVERTISED</parameter> 0 takes it off the wire while <code>Resolve</code> still finds
/// it, and a deleted class is gone. Both registries' listings are cached before the compile.</p>
/// <p>Mutation: <code>CompileSignature</code> answers a constant -> this goes red, the probe is
/// never listed.</p>
Method TestCompiledToolAppearsOnNextCall()
{
    Do $ClassMethod(..#PROBE, "SetRegistryClass", ..#FIXTURE)
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ListTools", .tFixtureList), "the fixture registry lists, and caches")
    Do $$$AssertStatusOK($ClassMethod(..#PRODUCTION, "ListTools", .tProductionList), "so does the production registry")
    Do ..AssertProbeUnknown("before the compile the probe is unknown")
    Set tFixtureBuilds = $ClassMethod(..#FIXTURE, "BuildCount")
    Set tProductionBuilds = $ClassMethod(..#PRODUCTION, "BuildCount")

    Do $$$AssertStatusOK(..CompileProbe(), "the probe is compiled")
    Do $$$AssertStatusOK($ClassMethod(..#PRODUCTION, "ListTools", .tProductionList), "the production registry lists again")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTION, "BuildCount") - tProductionBuilds, 1, "and rebuilt once, because its signature covers the OcuPilot. package")
    Do ..AssertProbeAnswers("the next dispatched call resolves the probe and answers it")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "BuildCount") - tFixtureBuilds, 1, "the fixture registry rebuilt once, and kept its own count")

    Do $$$AssertStatusOK(..CompileProbe(0), "the probe is recompiled unadvertised")
    Do ..AssertProbeUnknown("the wire name is unknown")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Resolve", ..#LATENAME, .tHidden, 1), "Resolve with unadvertised allowed answers")
    Do $$$AssertEquals($Select($IsObject(tHidden): tHidden.name _ "|" _ tHidden.advertised, 1: ""), ..#LATENAME _ "|0", "and still finds the tool")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Resolve", ..#LATENAME, .tAgent), "Resolve as the agent's path calls it answers")
    Do $$$AssertTrue('$IsObject(tAgent), "and does not find it")

    Do ..DropProbe()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Resolve", ..#LATENAME, .tGone, 1), "after the class is deleted Resolve answers")
    Do $$$AssertTrue('$IsObject(tGone), "and finds nothing")
}

/// <p>AC3 -- the same compile made by another process is seen by the next call in this one, with no
/// restart. The child is a <code>JOB</code> in the same namespace that signals its compile status.</p>
/// <p>Mutation: <code>CompileSignature</code> answers a constant -> this goes red, the probe is
/// never listed.</p>
Method TestCompileInAnotherProcessIsSeen()
{
    Do $ClassMethod(..#PROBE, "SetRegistryClass", ..#FIXTURE)
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ListTools", .tFixtureList), "the fixture registry lists, and caches")
    Do $$$AssertStatusOK($ClassMethod(..#PRODUCTION, "ListTools", .tProductionList), "so does the production registry")
    Do ..AssertProbeUnknown("before the compile the probe is unknown")
    Set tFixtureBuilds = $ClassMethod(..#FIXTURE, "BuildCount")
    Set tProductionBuilds = $ClassMethod(..#PRODUCTION, "BuildCount")

    Do $System.Event.Clear($Job)
    Job ##class(OcuPilot.Test.RegistryCache).CompileProbeJob($Job)::10
    Set tStarted = $Test
    Do $$$AssertTrue(tStarted, "the child process started")
    If 'tStarted Quit
    Set tMessage = $System.Event.WaitMsg("", 60)
    Do $$$AssertEquals($ListGet(tMessage, 1), 1, "the child signalled within 60 seconds")
    Do $$$AssertEquals($ListGet(tMessage, 2), "ok", "and compiled the probe")

    Do $$$AssertStatusOK($ClassMethod(..#PRODUCTION, "ListTools", .tProductionList), "the production registry lists again")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTION, "BuildCount") - tProductionBuilds, 1, "and rebuilt once for a compile it did not make")
    Do ..AssertProbeAnswers("the next dispatched call resolves the probe and answers it")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "BuildCount") - tFixtureBuilds, 1, "the fixture registry rebuilt once")
}

/// <p>AC4 -- a caller that changes its answer, an entry or the array, changes nothing the next
/// call reads. Every answer is read from the cache.</p>
/// <p>Mutation: the cache stores and answers the built <class>%DynamicArray</class> itself -> this
/// goes red.</p>
Method TestCachedListingIsACopy()
{
    Set tRegistry = ..#PRODUCTION
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ListTools", .tWarm), "the registry lists, and caches")
    Set tOriginal = tWarm.%ToJSON()
    Set tBuilds = $ClassMethod(tRegistry, "BuildCount")

    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ListTools", .tAnswer), "a cached answer is read")
    Do $$$AssertTrue(tAnswer '= tWarm, "it is an array of its own")
    Do tAnswer.%Get(0).%Set("name", "tampered", "string")
    Do tAnswer.%Push({"name": "extra"})
    Do tAnswer.%Remove(1)
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ListTools", .tNext), "the next answer is read")
    Do $$$AssertEquals(tNext.%ToJSON(), tOriginal, "it is unchanged by what the caller did to the last")
    Do $$$AssertEquals($ClassMethod(tRegistry, "BuildCount") - tBuilds, 0, "and both came from the cache")
}

/// <p>AC4 -- every entry of a listing, built or cached, carries the six keys of the listing in
/// order and nothing that depends on the caller. Read from the production registry and from the
/// fixture registry holding the probe.</p>
/// <p>Mutation: <code>Claim</code> adds a seventh key -> this goes red.</p>
Method TestEntriesCarryOnlyTheListing()
{
    Do $$$AssertStatusOK(..CompileProbe(), "the probe is compiled")
    For tRegistry = ..#PRODUCTION, ..#FIXTURE {
        Do $ClassMethod(tRegistry, "ForgetListing")
        For tPass = "built", "cached" {
            Do $$$AssertStatusOK($ClassMethod(tRegistry, "ListTools", .tList), tRegistry _ " lists (" _ tPass _ ")")
            Set tEntries = 0
            Set tOdd = ""
            Set tIterator = tList.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tEntry) {
                Set tEntries = tEntries + 1
                If (..KeysOf(tEntry) '= ..#ENTRYKEYS) || (tEntry.%GetTypeOf("advertised") '= "boolean") {
                    Set tOdd = $Select(tOdd = "": tEntry.name _ " has " _ ..KeysOf(tEntry), 1: tOdd)
                }
            }
            Do $$$AssertTrue(tEntries > 0, tRegistry _ " lists tools (" _ tPass _ ")")
            Do $$$AssertEquals(tOdd, "", "every entry carries exactly " _ ..#ENTRYKEYS _ " (" _ tPass _ ")")
        }
    }
}

/// <p>AC4 -- a registry whose build fails builds again on every call: the failure is returned each
/// time and nothing is cached.</p>
/// <p>Mutation: a failed build is cached -> this goes red.</p>
Method TestFailedBuildIsNotCached()
{
    Set tRegistry = ..#BADREGISTRY
    Do $ClassMethod(tRegistry, "ForgetListing")
    Set tBuilds = $ClassMethod(tRegistry, "BuildCount")
    For tCall = 1:1:3 {
        Set tSC = $ClassMethod(tRegistry, "ListTools", .tList)
        Do $$$AssertStatusNotOK(tSC, "call " _ tCall _ " is refused")
        Do $$$AssertEquals(tList, "", "with no list")
        Do $$$AssertEquals($ClassMethod(tRegistry, "BuildCount") - tBuilds, tCall, "and it built again")
    }
}

/// <p>Row "signature unreadable" -- when the compile signature cannot be read, every call builds and
/// answers its build, and nothing is cached. <class>OcuPilot.Test.RegistryCacheProbe.UnreadableRegistry</class>
/// overrides the signature read to fail.</p>
/// <p>Mutation: <code>ListTools</code> reads the cache without checking the signature read's status ->
/// this goes red, the first call raises.</p>
Method TestUnreadableSignatureBuildsWithoutCaching()
{
    Set tRegistry = ..#UNREADABLE
    Do $$$AssertStatusOK(..CompileProbe(), "the probe is compiled")
    Do $ClassMethod(tRegistry, "ForgetListing")
    Set tBuilds = $ClassMethod(tRegistry, "BuildCount")
    For tCall = 1:1:2 {
        Set tSC = $ClassMethod(tRegistry, "ListTools", .tList)
        Do $$$AssertStatusOK(tSC, "call " _ tCall _ " answers although the signature cannot be read")
        Set tFound = 0
        If $IsObject($Get(tList)) {
            Set tIterator = tList.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tEntry) {
                If tEntry.name = ..#LATENAME Set tFound = 1
            }
        }
        Do $$$AssertTrue(tFound, "with the probe tool listed")
        Do $$$AssertEquals($ClassMethod(tRegistry, "BuildCount") - tBuilds, tCall, "and it built again, so nothing was cached")
    }
}

}
