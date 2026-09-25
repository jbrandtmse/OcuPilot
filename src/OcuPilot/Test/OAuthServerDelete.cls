/// <p>Pins Story 12.4's server description delete (AD-6, AD-51, AD-53): a description a client
/// configuration uses is refused by name on the tab's row action, at the port and at the agent's mint,
/// and nothing is deleted; one a resource server uses is deleted over the row action and the resource
/// server is left naming nothing; the agent's delete is minted destructive with its removal rows and
/// confirmed; and a client configured against it after the mint refuses the confirm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo
/// fixture, an account holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because it creates and deletes OAuth 2.0 server descriptions, a client
/// configuration and a resource server.</p>
Class OcuPilot.Test.OAuthServerDelete Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthServerDescriptionDelete";

Parameter PROBE = "OcuPilot.Test.OAuthServerProbe";

Parameter ENDPOINT = "Security.OAuth2.Client.ServerDefinition";

/// <p>The tab's row-action route, under the test helper's base path.</p>
Parameter ACTIONPATH = "/screens/security.oauthserverdescriptions/action";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthServerDelete creates and deletes OAuth 2.0 server descriptions, a client configuration and a resource server on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and no probe description survives")
    Quit $$$OK
}

/// <p>One row action on the tab over a real HTTP request as the test account, answering the status
/// and the parsed envelope.</p>
Method Act(pAction As %String, pId As %String, Output pStatus As %Integer, Output pBody) As %Status
{
    Set pBody = ""
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#ACTIONPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Try { Set pBody = ##class(%DynamicObject).%FromJSON($ZConvert(tRaw, "I", "UTF8")) } Catch { Set pBody = "" }
    Do $$$AssertEquals(($Get(tRaw) [ "}{"), 0, pAction _ ": one envelope")
    Quit tSC
}

/// <p>AC3's refusal: a description a client configuration uses is refused 409
/// <code>OAUTH.SERVERINUSE</code>, by name, on the tab's row action and at the port before the vendor
/// is called, and the agent's mint refuses it with the same sentence; the description remains.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthServerPort.Invoke</method> drops its client-count
/// refusal -- the vendor's own 500 reaches the row action and this goes red.</p>
Method TestADescriptionAClientUsesIsRefusedByName()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "InUse")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer), "a description is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tIssuer), "and a client configuration uses it")
    Set tSC = ..Act("delete", tIssuer, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "the row action is answered")
    Do $$$AssertEquals(tStatus, 409, "at 409")
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("code") _ "|" _ tBody.%Get("reason"), 1: ""), "OAUTH.SERVERINUSE|" _ ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERINUSE, "refused by name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tIssuer), 1, "and the description remains")
    Kill tQuery
    Set tQuery("issuer") = tIssuer
    Set tSC = ##class(OcuPilot.Port.OAuthServerPort).Invoke(..#ENDPOINT, "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 OAUTH.SERVERINUSE", "the port refuses it the same way")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#TOOL, tIssuer, {"IssuerEndpoint": (tIssuer)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#PROBE, "Problem", $Get(tFault)) = ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERINUSE), "and the agent's mint refuses it with the same sentence")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tIssuer), 1, "the description still remains")
}

/// <p>AC3's delete: a description a resource server uses is deleted over the row action, answering the
/// <code>deleted</code> action and the AD-13 triple; the instance no longer holds it, and the resource
/// server names a description that no longer exists, as the delete's consequence line says.</p>
Method TestADescriptionAResourceServerUsesIsDeletedAndLeftDangling()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "Resource")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer), "a description is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddResource", tIssuer), "and a resource server uses it")
    Set tSC = ..Act("delete", tIssuer, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the row action deletes it")
    If $IsObject(tBody) && (tStatus = 200) {
        Do $$$AssertEquals(tBody.%Get("action"), "deleted", "answering the deleted action")
        Do $$$AssertEquals(tBody.%Get("target").%ToJSON(), "{""type"":""oauth2-server-definition"",""scope"":""instance"",""id"":""" _ tIssuer _ """}", "and the triple the write was made against")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tIssuer), 0, "the instance no longer holds it")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ResourceDangles"), 1, "and the resource server is left naming nothing")
}

/// <p>The agent's delete is minted destructive, its card listing the issuer and both counts removed,
/// and nothing is deleted at the mint; its confirm deletes the description.</p>
Method TestTheAgentsDeleteIsMintedDestructiveAndConfirmed()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "AgentDelete")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer), "a description is created")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#TOOL, tIssuer, {"IssuerEndpoint": (tIssuer)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is minted: " _ $ClassMethod(..#PROBE, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRows = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tRows = tRows _ $ListBuild(tRow.%Get("field") _ "=" _ tRow.%Get("before") _ $Select(tRow.%Get("removed"): "!", 1: ""))
    }
    Do $$$AssertEquals($ListToString(tRows, "|"), "IssuerEndpoint=" _ tIssuer _ "!|ClientCount=0!|ResourceCount=0!", "its card lists the issuer and both counts removed")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals(+$Get(tValues("destructive")), 1, "it is destructive")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tIssuer), 1, "and nothing is deleted at the mint")
    Set tSC = ##class(OcuPilot.Test.ConfirmFixture).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the delete is confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "deleted", "publishing deleted")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tIssuer), 0, "and the description is gone")
}

/// <p>A client configured against the description after the mint changes the fingerprinted client
/// count, so the confirm is refused as the target having changed, and nothing is deleted.</p>
Method TestAClientAddedAfterTheMintRefusesTheConfirm()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "LateClient")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer), "a description is created")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#TOOL, tIssuer, {"IssuerEndpoint": (tIssuer)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is minted")
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tIssuer), "then a client configuration is configured against it")
    Set tSC = ##class(OcuPilot.Test.ConfirmFixture).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tIssuer), 1, "and nothing is deleted")
}

}
