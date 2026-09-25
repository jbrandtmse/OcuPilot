/// <p>Pins Story 12.6's service mappings and delete (AD-10, AD-51, AD-53, AD-55, AD-56 (ii)): the
/// editor's Save removes and adds mappings through the two mapping tools' writes, a mapping another
/// server holds is moved; the agent's add of such a mapping is minted destructive naming the move and
/// the previous holder, and applied at confirm; a mapping moved by someone else after the mint refuses
/// the confirm; a bad service, an unknown key and a removal this server does not hold are refused
/// before anything is sent; a mapping write refused after the save is answered; and a delete, from the
/// row action or the agent, takes the server's mappings with it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture,
/// an account holding <code>%All</code>, the web applications <code>/csp/sys</code> and
/// <code>/api/atelier</code>, the namespace <code>USER</code>, and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because it creates and deletes OAuth 2.0 resource servers, service mappings
/// and server descriptions. Every object is an <class>OcuPilot.Test.OAuthResourceServerProbe</class>
/// one.</p>
Class OcuPilot.Test.OAuthResourceServerMappings Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter ADDTOOL = "OcuPilot.Screen.Tool.OAuthResourceServerAddMapping";

Parameter REMOVETOOL = "OcuPilot.Screen.Tool.OAuthResourceServerRemoveMapping";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.OAuthResourceServerDelete";

Parameter SCREEN = "OcuPilot.Test.OAuthResourceServerSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthResourceServerConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthResourceServerRecordPort";

Parameter FAILPORT = "OcuPilot.Test.OAuthResourceServerFailPort";

Parameter FAILSAVE = "OcuPilot.Test.OAuthResourceServerFailSave";

Parameter PROBE = "OcuPilot.Test.OAuthResourceServerProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter GATEWAY = "%Service_WebGateway";

Parameter BINDINGS = "%Service_Bindings";

Parameter ACTIONPATH = "/screens/security.oauthresourceservers/action";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthResourceServerMappings creates and deletes OAuth 2.0 resource servers and service mappings on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "AddServer", ..Issuer())
    If $$$ISERR(tSC) Quit tSC
    For tSuffix = "A", "B" {
        Set tSC = $ClassMethod(..#PROBE, "AddResource", ..Server(tSuffix), ..Issuer(), $ListBuild("aud.mappings"))
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do $ClassMethod(..#FAILPORT, "Disarm")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

ClassMethod Issuer() As %String
{
    Quit $ClassMethod(..#PROBE, "Issuer", "mappings")
}

/// <p>Probe server A or B.</p>
ClassMethod Server(pSuffix As %String) As %String
{
    Quit $ClassMethod(..#PROBE, "Name", "Map" _ pSuffix)
}

/// <p>One mapping row, as the Save's body carries it.</p>
ClassMethod Row(pService As %String, pKey As %String) As %DynamicObject
{
    Set tRow = {}
    Do tRow.%Set("Service", pService, "string")
    Do tRow.%Set("Key", pKey, "string")
    Quit tRow
}

/// <p>A mapping tool's arguments for server <var>pName</var>.</p>
ClassMethod Args(pName As %String, pService As %String, pKey As %String) As %DynamicObject
{
    Set tArgs = ..Row(pService, pKey)
    Do tArgs.%Set("Name", pName, "string")
    Quit tArgs
}

/// <p>AC5 on the screen's caller: one Save removes the Web Gateway mapping server A holds and adds a
/// Web Gateway application and a namespace, the removal first; A then holds exactly the two added.</p>
Method TestTheSaveRemovesAndAddsMappings()
{
    Set tA = ..Server("A")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Map", ..#GATEWAY, "/csp/sys", tA), "A holds /csp/sys")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tA, {}, [(..Row(..#GATEWAY, "/api/atelier")), (..Row(..#BINDINGS, "USER"))], [(..Row(..#GATEWAY, "/csp/sys"))], .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the Save's rules pass: " _ $System.Status.GetErrorText(tSC))
    Do $ClassMethod(..#SCREEN, "StoreMappings", tA, [(..Row(..#GATEWAY, "/api/atelier")), (..Row(..#BINDINGS, "USER"))], [(..Row(..#GATEWAY, "/csp/sys"))], .tCount, .tReason)
    Do $$$AssertEquals(+tCount _ "|" _ tReason, "0|", "and every mapping write lands")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes"), "REMOVEMAPPING,ADDMAPPING,ADDMAPPING", "the removal first, then each addition")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "MappingsOf", tA), "%Service_Bindings/user,%Service_WebGateway//api/atelier", "and A holds exactly the two added, the namespace lower-cased")
}

/// <p>AC5's move on the screen's caller: B's Save adds the mapping A holds, and B then holds it.</p>
Method TestASaveMovesAMappingAnotherServerHolds()
{
    Set tA = ..Server("A")
    Set tB = ..Server("B")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Map", ..#GATEWAY, "/csp/sys", tA), "A holds /csp/sys")
    Set tSC = $ClassMethod(..#FAILSAVE, "Handle", tB, {"mappingsAdded": [(..Row(..#GATEWAY, "/csp/sys"))]}, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "B's Save answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holder", ..#GATEWAY, "/csp/sys"), tB, "and B holds the mapping")
}

/// <p>AC5's agent half: the agent's add of a mapping A holds, proposed for B, is minted destructive with
/// the move as its consequence and the previous holder as a row, and its confirm moves the mapping.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method> stops
/// naming <parameter>OcuPilot.Kernel.Proposal.Prohibited.EFFECTMAPPINGMOVE</parameter> -- the
/// destructive and consequence assertion goes red.</p>
Method TestAMoveIsMintedDestructiveAndAppliedAtConfirm()
{
    Set tA = ..Server("A")
    Set tB = ..Server("B")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Map", ..#GATEWAY, "/csp/sys", tA), "A holds /csp/sys")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#ADDTOOL, tB, ..Args(tB, ..#GATEWAY, "/csp/sys"), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the add is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Do ##class(OcuPilot.Test.ServiceUpdate).Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 OAUTH.MAPPINGMOVE", "destructive, naming the move")
    Set tRows = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tRows = tRows _ $ListBuild(tRow.%Get("field") _ ":" _ tRow.%Get("before") _ ">" _ tRow.%Get("after")) }
    Do $$$AssertEquals($ListToString(tRows, "|"), "Mappings:>%Service_WebGateway//csp/sys|Held:" _ tA _ ">" _ tB, "its rows are B's mappings and the previous holder")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the move is confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "RecordedMappings", "ADDMAPPING"), ..#GATEWAY _ "//csp/sys", "one mapping write, for the mapping reviewed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holder", ..#GATEWAY, "/csp/sys"), tB, "and B holds it")
}

/// <p>A mapping another server takes between the mint and the confirm refuses the confirm: the
/// fingerprint covers every holder.</p>
Method TestAMoveByAnotherAfterTheMintIsRefusedAtConfirm()
{
    Set tA = ..Server("A")
    Set tB = ..Server("B")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#ADDTOOL, tB, ..Args(tB, ..#GATEWAY, "/api/atelier"), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the add is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Do ##class(OcuPilot.Test.ServiceUpdate).Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "0 ", "a mapping nobody holds is an ordinary add")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Map", ..#GATEWAY, "/api/atelier", tA), "then A takes the mapping")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount") _ " " _ $ClassMethod(..#PROBE, "Holder", ..#GATEWAY, "/api/atelier"), "0 " _ tA, "nothing is sent, and A keeps it")
}

/// <p>The agent's removal of a mapping A holds is minted as an ordinary change and confirmed; a
/// removal A does not hold is refused at the mint.</p>
Method TestTheAgentsRemovalIsConfirmed()
{
    Set tA = ..Server("A")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Map", ..#BINDINGS, "USER", tA), "A holds USER")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#REMOVETOOL, tA, ..Args(tA, ..#GATEWAY, "/csp/sys"), .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ##class(OcuPilot.Api.Error).#REASONOAUTHMAPPINGABSENT), "a removal A does not hold is refused at the mint")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#REMOVETOOL, tA, ..Args(tA, ..#BINDINGS, "user"), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the removal is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Do ##class(OcuPilot.Test.ServiceUpdate).Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "0 ", "as an ordinary change")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the removal is confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "MappingsOf", tA), "", "and A holds no mapping")
}

/// <p>A mapping with a bad service, a key naming nothing, and a removal the server does not hold are
/// each refused on their field before anything is sent, on the Save and on the agent's mint.</p>
Method TestBadMappingsAreRefusedBeforeAnythingIsSent()
{
    Set tA = ..Server("A")
    Set tCase($Increment(tCase)) = $ListBuild("add", "%Service_Bogus", "*", "Mappings.Service", "OAUTH.MAPPINGSERVICE.VALUE")
    Set tCase($Increment(tCase)) = $ListBuild("add", ..#GATEWAY, "/ocupilot/no/such/app", "Mappings.Key", "OAUTH.MAPPINGKEY.ABSENT")
    Set tCase($Increment(tCase)) = $ListBuild("add", ..#BINDINGS, "OCUPILOTNOSUCHNS", "Mappings.Key", "OAUTH.MAPPINGKEY.ABSENT")
    Set tCase($Increment(tCase)) = $ListBuild("remove", ..#GATEWAY, "/csp/sys", "Mappings.Key", "OAUTH.MAPPINGABSENT")
    For tI = 1:1:tCase {
        Set tRow = ..Row($List(tCase(tI), 2), $List(tCase(tI), 3))
        Set tAdded = $Select($List(tCase(tI), 1) = "add": [(tRow)], 1: [])
        Set tRemoved = $Select($List(tCase(tI), 1) = "remove": [(tRow)], 1: [])
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Update", tA, {"Description": "must not be saved"}, tAdded, tRemoved, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, $List(tCase(tI), 4)), $List(tCase(tI), 5), "case " _ tI _ ": the Save refuses " _ $List(tCase(tI), 4))
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "case " _ tI _ ": and sends nothing, the server's own edit included")
        Set tTool = $Select($List(tCase(tI), 1) = "add": ..#ADDTOOL, 1: ..#REMOVETOOL)
        Set tSC = $ClassMethod(..#HELPER, "Mint", tTool, tA, ..Args(tA, $List(tCase(tI), 2), $List(tCase(tI), 3)), .tProposal, .tHttp, .tFault)
        Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400), "case " _ tI _ ": and the agent's mint refuses it: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tA).%Get("Description"), "", "the server is unchanged")
}

/// <p>A mapping write refused after the server saved: the edit's route answers 200 carrying
/// <code>mappingsRefused</code>, the count and the refusal's sentence, and the instance holds the edit.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthResourceServerPort.AddMapping</method> returns a
/// vendor 500 unmapped -- the reason assertion goes red.</p>
Method TestAMappingRefusedAfterTheSaveIsAnswered()
{
    Set tA = ..Server("A")
    Do $ClassMethod(..#FAILPORT, "Arm", "Security.OAuth2.ResourceServerMapping", "PUT", 500)
    Set tSC = $ClassMethod(..#FAILSAVE, "Handle", tA, {"Description": "saved before the refusal", "mappingsAdded": [(..Row(..#GATEWAY, "/csp/sys"))]}, .tRaw, .tStatus)
    Do $$$AssertStatusOK(tSC, "the edit's route runs")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ $Extract(tRaw, 1, 300))
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tAnswer = "" }
    Set tRefused = $Select($IsObject(tAnswer) && (tAnswer.%GetTypeOf("mappingsRefused") = "object"): tAnswer.%Get("mappingsRefused"), 1: {})
    Do $$$AssertEquals(tRefused.%Get("count") _ " " _ tRefused.%Get("reason"), "1 " _ ##class(OcuPilot.Api.Error).#REASONOAUTHRESOURCESERVERVALIDATION, "carrying mappingsRefused, one mapping and the port's named refusal, not the vendor's 500")
    Do $$$AssertEquals($ClassMethod(..#FAILPORT, "Reached", "Security.OAuth2.ResourceServerMapping", "PUT") _ " " _ $ClassMethod(..#PROBE, "Stored", tA).%Get("Description"), "1 saved before the refusal", "the mapping write reached the armed port, and the edit is stored")
}

/// <p>AC3 on the instance: the row action deletes server A with its two mappings, answering the
/// <code>deleted</code> action and the AD-13 triple; the agent's delete of B is minted destructive,
/// listing the mappings removed with it, and confirmed.</p>
Method TestADeleteTakesTheMappingsWithIt()
{
    Set tA = ..Server("A")
    Set tB = ..Server("B")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Map", ..#GATEWAY, "/csp/sys", tA), "A holds /csp/sys")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Map", ..#BINDINGS, "USER", tA), "and USER")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Map", ..#GATEWAY, "/api/atelier", tB), "B holds /api/atelier")
    Set tRequest = {"action": "delete"}
    Do tRequest.%Set("id", tA, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#ACTIONPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 200, "the row action answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue((tRaw [ """action"":""deleted""") && (tRaw [ """type"":""oauth2-resource-server"""), "with the deleted action on the resource server's triple")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tA) _ "|" _ $ClassMethod(..#PROBE, "Holder", ..#GATEWAY, "/csp/sys") _ "|" _ $ClassMethod(..#PROBE, "Holder", ..#BINDINGS, "USER"), "0||", "A and both its mappings are gone")
    Set tArgs = {}
    Do tArgs.%Set("Name", tB, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#DELETETOOL, tB, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Do ##class(OcuPilot.Test.ServiceUpdate).Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive, 1, "destructive")
    Set tMappingsRow = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { If tRow.%Get("field") = "Mappings" Set tMappingsRow = tRow.%Get("before") _ ">" _ tRow.%Get("after") }
    Do $$$AssertEquals(tMappingsRow, ..#GATEWAY _ "//api/atelier>", "listing the mapping removed with it")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the delete is confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tB) _ "|" _ $ClassMethod(..#PROBE, "Holder", ..#GATEWAY, "/api/atelier"), "0|", "B and its mapping are gone")
}

/// <p>A mapping added to the server between an agent delete's mint and its confirm refuses the confirm:
/// the delete's fingerprint covers the mappings its card lists as removed with the server.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthResourceServerPort.MappingTable</method> lists none
/// of the server's own mappings, so the reviewed state carries none -- the confirm deletes B with the
/// unreviewed mapping and both assertions go red.</p>
Method TestAMappingAddedAfterADeletesMintRefusesItsConfirm()
{
    Set tB = ..Server("B")
    Set tArgs = {}
    Do tArgs.%Set("Name", tB, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#DELETETOOL, tB, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Map", ..#GATEWAY, "/api/atelier", tB), "then B takes a mapping its card never listed")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISERR(tSC) _ " " _ tHttp _ " " _ $Get(tCode), "1 409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tB) _ "|" _ $ClassMethod(..#PROBE, "Holder", ..#GATEWAY, "/api/atelier"), "1|" _ tB, "and B and its mapping are still there")
}

}
