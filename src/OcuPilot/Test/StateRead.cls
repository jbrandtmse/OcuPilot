/// <p>AD-36's <b>second</b> read source kind: a descriptor-declared read whose rows come from
/// OcuPilot's own protected state (AD-9) rather than from an instance endpoint through the port.</p>
/// <p>What the story claims is that the second kind changes <b>where the rows come from and
/// nothing else</b>, so every assertion here is about a property the first kind already has --
/// the declared field set, the secret strip, the filter and sort view rule, the row cap and the
/// truncation signal -- observed over the state source.</p>
/// <p>Every definition this class creates is named with <parameter>PROBEPREFIX</parameter> and
/// removed in <method>OnAfterOneTest</method>, which then asserts none survives.</p>
Class OcuPilot.Test.StateRead Extends %UnitTest.TestCase
{

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The descriptor whose read names the state source.</p>
Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.AgentDefinitionList";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Quit $$$OK
}

/// <p>Create <var>pCount</var> probe definitions and answer how many were made.</p>
ClassMethod Seed(pCount As %Integer) As %Integer
{
    Set tMade = 0
    For tI = 1:1:pCount {
        Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "State" _ tI)
        If $$$ISOK(tSC) Set tMade = tMade + 1
    }
    Quit tMade
}

/// <p>The declaration names the state source, and the registry accepts it -- the two halves of
/// "a screen over OcuPilot's own configuration is a declared read like any other".</p>
/// <p>Mutation: change <code>read.source.port</code> to a third word -- the registry refuses the
/// descriptor naming both declared kinds, and this goes red.</p>
Method TestTheDefinitionsListDeclaresAStateSourceTheRegistryAccepts()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tDeclaration.read.source.port, ##class(OcuPilot.Screen.Read).#SOURCESTATE, "the read names the state source kind")
    Do $$$AssertEquals(tDeclaration.read.source.endpoint, "Agent", "naming the kernel store by its own name, with no package")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Read).StateClass(tDeclaration.read.source.endpoint), "OcuPilot.Kernel.State.Agent", "which resolves inside the kernel's state package and nowhere else")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "and the registry accepts the whole declaration")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).SideBarPositionProblem(tDeclaration), "", "including its side-bar position")
}

/// <p>A state read whose source declares a <code>rowGet</code> or <code>criteria</code> is refused
/// where it is declared: neither has anything to act on when the rows are read whole from a kernel
/// store.</p>
Method TestAStateSourceDeclaringADetailCallOrCriteriaIsRefused()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Set tWithRowGet = ##class(%DynamicObject).%FromJSON(tDeclaration.%ToJSON())
    Do tWithRowGet.read.source.%Set("rowGet", {"key": "id", "param": "id", "fields": [], "derived": []})
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tWithRowGet) [ "rowGet is declared on a state source", "a per-row detail call is refused: " _ ##class(OcuPilot.Screen.Registry).ReadProblem(tWithRowGet))

    Set tWithCriteria = ##class(%DynamicObject).%FromJSON(tDeclaration.%ToJSON())
    Do tWithCriteria.read.%Set("criteria", {"fields": []})
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tWithCriteria) [ "read.criteria is declared on a state source", "and so are server-search criteria: " _ ##class(OcuPilot.Screen.Registry).ReadProblem(tWithCriteria))

    Set tPackaged = ##class(%DynamicObject).%FromJSON(tDeclaration.%ToJSON())
    Do tPackaged.read.source.%Set("endpoint", "OcuPilot.Kernel.State.Agent")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tPackaged) [ "names a package", "and an endpoint naming a package is refused, so no descriptor points a read outside the kernel's stores")
}

/// <p>The state read answers the declared fields, one row per definition, in the store's own
/// order -- and the rows are <method>OcuPilot.Kernel.State.Agent.ScreenRow</method>'s, which is
/// also what the selection list answers, so a screen and the switcher cannot disagree.</p>
/// <p>Mutation: drop a key from
/// <method>OcuPilot.Kernel.State.Agent.ScreenRow</method> -- this goes red on the projected
/// row.</p>
Method TestTheStateReadProjectsTheDeclaredFields()
{
    Do $$$AssertEquals(..Seed(3), 3, "three probe definitions exist")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the state read completes")
    Do $$$AssertEquals(tHttp, 200, "answering 200")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.fields.%ToJSON(), "[""id"",""name"",""provider"",""model"",""enabled"",""default""]", "the declared field set, with no secret stripped because the read carries none")
    Do $$$AssertEquals(tResult.rows.%Size(), 3, "one row per definition")
    Do $$$AssertEquals(tResult.truncated, 0, "and nothing was cut")
    Set tRow = tResult.rows.%Get(0)
    Do $$$AssertTrue($IsObject(tRow), "the first row is an object")
    If '$IsObject(tRow) Quit
    Set tKeys = ""
    Set tIterator = tRow.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tKeys, "id,name,provider,model,enabled,default", "carrying exactly the declared keys")
    Do $$$AssertEquals(tRow.%GetTypeOf("enabled"), "boolean", "with the flags typed as JSON booleans")
    Do $$$AssertEquals(tRow.%GetTypeOf("name"), "string", "and the name as a JSON string")
}

/// <p>The row cap bounds a state read exactly as it bounds a port read, and
/// <code>truncated</code> says so.</p>
/// <p>A kernel store's guarded list takes no <code>maxRows</code> ahead of it, so the cap is
/// applied to the answer -- the same guarantee one step later, not a weaker one, and this is the
/// assertion that says which.</p>
/// <p>Mutation: return the whole array from
/// <method>OcuPilot.Screen.Read.Execute</method>'s state branch without the cap -- this goes red
/// at three rows where two are expected.</p>
Method TestTheRowCapAndTheTruncationSignalApplyToAStateRead()
{
    Do $$$AssertEquals(..Seed(3), 3, "three probe definitions exist")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 2, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the capped read completes")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%Size(), 2, "at most the cap's rows")
    Do $$$AssertEquals(tResult.truncated, 1, "and the answer says it was cut")

    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, "0", .tBadResult, .tBadHttp, .tBadFault)
    Do $$$AssertStatusNotOK(tSC, "a cap of zero is refused")
    Do $$$AssertEquals(tBadHttp, 400, "with 400")
    Do $$$AssertEquals($Select($IsObject(tBadFault): tBadFault.code, 1: ""), "READ.MAXROWS", "and the same code a port read's bad cap earns")
}

/// <p>The one view rule filters and sorts a state read's rows -- the same
/// <method>OcuPilot.Screen.Read.ApplyView</method> the screen and the read tool both narrow a port
/// read through (AD-36).</p>
Method TestTheViewRuleNarrowsAStateReadTheSameWay()
{
    Do $$$AssertEquals(..Seed(3), 3, "three probe definitions exist")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the state read completes")
    If '$IsObject(tResult) Quit
    Set tRead = $ClassMethod(..#DESCRIPTOR, "Read")
    Set tNarrowed = ##class(OcuPilot.Screen.Read).ApplyView(tResult.rows, tRead, ..#PROBEPREFIX _ "State2", "name", "asc")
    Do $$$AssertEquals(tNarrowed.%Size(), 1, "a filter over a declared filter field keeps the one matching row")
    Do $$$AssertEquals(tNarrowed.%Get(0).name, ..#PROBEPREFIX _ "State2", "and it is the one named")

    Set tDescending = ##class(OcuPilot.Screen.Read).ApplyView(tResult.rows, tRead, "", "name", "desc")
    Do $$$AssertEquals(tDescending.%Size(), 3, "an empty filter keeps every row")
    Do $$$AssertEquals(tDescending.%Get(0).name, ..#PROBEPREFIX _ "State3", "sorted by the declared field in the direction asked for")
}

/// <p><b>Integration (Rule 1)</b> -- the generic screen-read route serves the state source, so the
/// client reaches it through the one route every other list uses and no route was added for it.</p>
Method TestTheScreenReadRouteServesTheStateSource()
{
    Do $$$AssertEquals(..Seed(2), 2, "two probe definitions exist")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#APIBASE _ "/screens/agent.definitions/read", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the read request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), "[""id"",""name"",""provider"",""model"",""enabled"",""default""]", "carrying the declared fields")
    Do $$$AssertEquals(tAnswer.rows.%Size(), 2, "and one row per definition")
    Do $$$AssertEquals(tAnswer.truncated, 0, "with the truncation signal every read carries")
}

/// <p>A state source naming a store this instance does not hold is a 500 with the generic fault,
/// and the detail stays in the status (AD-12).</p>
/// <p>Driven through <class>OcuPilot.Test.ReadState.NoStore</class>'s fixture descriptor rather than by
/// editing a shipped one: the refusal is the executor's, and the shipped declaration is the thing
/// that must not change.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Read.StateRows</method>'s missing-class arm answer
/// <code>$$$OK</code> with no rows -- the read falls through to the "answered something other than
/// a list" arm and this goes red on the reason, which then names no store.</p>
Method TestAStateSourceNamingNoStoreIsAnInternalFault()
{
    Do $$$AssertEquals(##class(OcuPilot.Screen.Read).StateClass("NoSuchStore"), "OcuPilot.Kernel.State.NoSuchStore", "the endpoint resolves inside the state package")
    Do $$$AssertTrue('##class(%Dictionary.CompiledClass).%ExistsId("OcuPilot.Kernel.State.NoSuchStore"), "and this instance holds no such class, which is the precondition this leg needs")

    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Test.ReadState.NoStore", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "executing the read is an error")
    Do $$$AssertEquals(tHttp, 500, "answering 500")
    Do $$$AssertTrue($IsObject(tFault), "with a fault object")
    If '$IsObject(tFault) Quit
    Do $$$AssertEquals(tFault.code, "INTERNAL", "carrying the generic internal code")
    Do $$$AssertTrue(tFault.reason '[ "NoSuchStore", "and a reason that names no class of ours: '" _ tFault.reason _ "'")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ "NoSuchStore", "while the detail stays in the status (AD-12)")
    Do $$$AssertTrue('$IsObject(tResult), "and no rows are answered")
}

}
