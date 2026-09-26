/// <p>Pins Story 12.7's affected clients (AC3, AC6, AD-6, AD-10): the port's read names the clients
/// registered with the server; a proposal of each of the four change tools is minted destructive with
/// the client effect and a card row naming every client; a client registered or removed after the mint
/// refuses each tool's confirm; a caller who cannot list the clients gets the hidden effect and no row; and a delete
/// takes every registered client with it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture,
/// an account holding <code>%All</code>, no authorization server configuration, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes the
/// instance's configuration and registers clients with it
/// (<class>OcuPilot.Test.OAuthAuthorizationServerProbe</class>).</p>
Class OcuPilot.Test.OAuthAuthorizationServerClients Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CONFIRM = "OcuPilot.Test.OAuthAuthorizationServerConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthAuthorizationServerRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthAuthorizationServerProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter ACTIONPATH = "/screens/security.oauthserver/action";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthAuthorizationServerClients creates and deletes this instance's OAuth 2.0 authorization server configuration and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Seed")
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "the configuration, its clients and every probe object are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

ClassMethod Id() As %String
{
    Quit ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
}

/// <p>The port's read names each registered client as <code>{ClientId, Name}</code>, ordered by name,
/// and says the list is not hidden; the form read answers the same list.</p>
Method TestTheReadNamesTheRegisteredClients()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "B"), .tIdB), "a client is registered")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "A"), .tIdA), "and another")
    Set tRead = $ClassMethod(..#PROBE, "Read")
    Set tExpected = "[{""ClientId"":""" _ tIdA _ """,""Name"":""" _ $ClassMethod(..#PROBE, "Name", "A") _ """},{""ClientId"":""" _ tIdB _ """,""Name"":""" _ $ClassMethod(..#PROBE, "Name", "B") _ """}]"
    Do $$$AssertEquals($Select($IsObject(tRead): tRead.%Get("Clients").%ToJSON() _ " " _ tRead.%Get("ClientsHidden"), 1: ""), tExpected _ " 0", "the port's read names both, by name")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/oauth/authorization-server/form", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the form read answers")
    Do $$$AssertTrue((tRaw [ tExpected) && (tRaw [ """clientsHidden"":false"), "with the same clients")
}

/// <p>AC6: with a client registered, a proposal of the edit, the password, the rotation and the delete
/// is each minted destructive with the client effect (the delete's naming the clients it deletes) and
/// a card row naming the client -- unchanged for three, removed for the delete.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthAuthorizationServerPort.Read</method> stops
/// adding <code>Clients</code> -- no effect and no row, and this goes red.</p>
Method TestEachToolNamesTheEffectAndTheClients()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Card")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", tName, .tId), "a client is registered")
    Set tNamed = tName _ " (" _ tId _ ")"
    ; tool suffix|arguments|consequence|the clients row's after
    Set tCases = $ListBuild($ListBuild("Update", "{""Description"":""card""}", "OAUTH.SERVERCLIENTS", tNamed), $ListBuild("SetPassword", "{}", "OAUTH.SERVERCLIENTS", tNamed), $ListBuild("RotateKeys", "{}", "OAUTH.SERVERCLIENTS", tNamed), $ListBuild("Delete", "{}", "OAUTH.SERVERCLIENTSDELETED", ""))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tTool = "OcuPilot.Screen.Tool.OAuthAuthorizationServer" _ $List(tCase, 1)
        Set tArgs = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Do tArgs.%Set("Name", ..Id(), "string")
        Set tSC = $ClassMethod(..#HELPER, "Mint", tTool, ..Id(), tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tTool _ ": is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
        If '$IsObject($Get(tProposal)) Continue
        Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
        Do $$$AssertEquals($Get(tValues("destructive")) _ " " _ $Get(tValues("consequence")), "1 " _ $List(tCase, 3), tTool _ ": destructive, naming the effect")
        Set tRow = ""
        Set tIterator = tProposal.%Get("changed").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) { If tEntry.%Get("field") = "Clients" Set tRow = tEntry.%Get("before") _ "|" _ tEntry.%Get("after") }
        Do $$$AssertEquals(tRow, tNamed _ "|" _ $List(tCase, 4), tTool _ ": and a row naming the client")
    }
}

/// <p>AC6, AD-6: a client registered between the mint and the confirm changes the reviewed state, so
/// the confirm of each of the four change tools is refused and nothing is sent; the delete's leaves the
/// configuration and every client in place.</p>
/// <p>Mutation (Rule 19): drop <code>Clients</code> from
/// <parameter>OcuPilot.Screen.Tool.OAuthAuthorizationServerDelete.FINGERPRINTSUBJECT</parameter> -- the
/// delete's confirm is no longer refused as the target having changed and this goes red.</p>
Method TestAClientRegisteredAfterTheMintRefusesTheConfirm()
{
    Set tPassword = $ClassMethod(..#PROBE, "Secret", "late")
    For tSuffix = "Update", "SetPassword", "RotateKeys", "Delete" {
        Set tTool = "OcuPilot.Screen.Tool.OAuthAuthorizationServer" _ tSuffix
        Set tArgs = $Select(tSuffix = "Update": {"Description": "late"}, 1: {})
        Do tArgs.%Set("Name", ..Id(), "string")
        Set tSC = $ClassMethod(..#HELPER, "Mint", tTool, ..Id(), tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tTool _ ": is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
        If '$IsObject($Get(tProposal)) Continue
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "Late" _ tSuffix), .tId), tTool _ ": then a client is registered")
        Set tClients = $ClassMethod(..#PROBE, "ClientCount")
        Set tKeys = $ClassMethod(..#PROBE, "Stored").%Get("KeyCount")
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSupplied = $Select(tSuffix = "SetPassword": {"ServerPassword": (tPassword)}, 1: "")
        Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), tSupplied, $Username, .tResult, .tHttp, .tCode, .tDetail)
        Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, tTool _ ": the confirm is refused as the target having changed")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, tTool _ ": and nothing is sent")
        Set tStored = $ClassMethod(..#PROBE, "Stored")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds") _ " " _ $ClassMethod(..#PROBE, "ClientCount") _ " " _ $Select($IsObject(tStored): tStored.%Get("Description") _ " " _ tStored.%Get("PasswordLength") _ " " _ tStored.%Get("KeyCount"), 1: ""), "1 " _ tClients _ " seeded 0 " _ tKeys, tTool _ ": the configuration and every client are as they were")
    }
}

/// <p>AC6, AD-6: a client removed between the mint and the confirm refuses the delete's confirm too,
/// and the configuration survives.</p>
/// <p>Mutation (Rule 19): as <method>TestAClientRegisteredAfterTheMintRefusesTheConfirm</method>'s.</p>
Method TestAClientRemovedAfterTheMintRefusesTheConfirm()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "Kept"), .tKept), "a client is registered")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "Removed"), .tRemoved), "and another")
    Set tArgs = {}
    Do tArgs.%Set("Name", ..Id(), "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", "OcuPilot.Screen.Tool.OAuthAuthorizationServerDelete", ..Id(), tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is minted naming both: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveClient", tRemoved), "then one client is removed")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount") _ " " _ $ClassMethod(..#PROBE, "Holds") _ " " _ $ClassMethod(..#PROBE, "ClientCount"), "0 1 1", "and nothing is sent: the configuration and the other client survive")
}

/// <p>A read whose clients are hidden from the caller is the hidden effect, and its
/// card carries no clients row; the four codes combine with a privileged customization role as
/// declared.</p>
Method TestHiddenClientsAreNamedAsHidden()
{
    Do $ClassMethod(..#RECORD, "Arm", "Security.OAuth2.ServerClients", "LIST", 403)
    Kill tQuery
    Set tSC = $ClassMethod(..#RECORD, "Invoke", "Security.OAuth2.Server", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read answers when the client list refuses the caller")
    Do $$$AssertEquals($Select($IsObject($Get(tRead)): tRead.%Get("Clients").%ToJSON() _ " " _ tRead.%Get("ClientsHidden"), 1: ""), "[] 1", "with no client and the list hidden")
    Set tSC = $ClassMethod(..#SET, "WeakensByEffect", "oauth2-server", tRead, tRead, .tEffect, ..Id())
    Do $$$AssertEquals(tEffect, "OAUTH.SERVERCLIENTSHIDDEN", "the effect is the hidden one")
    Do $$$AssertEquals(##class(OcuPilot.Area.Security.OAuthAuthorizationServerRules).ClientsRow(tRead, 0), "", "and the card carries no clients row")
    Do $$$AssertEquals($ClassMethod(..#SET, "ServerConsequence", "delete", 0, tEffect) _ " " _ $ClassMethod(..#SET, "ServerConsequence", "", 1, tEffect) _ " " _ $ClassMethod(..#SET, "ServerConsequence", "", 1, "OAUTH.SERVERCLIENTS") _ " " _ $ClassMethod(..#SET, "ServerConsequence", "", 1, ""), "OAUTH.SERVERCLIENTSDELETEDHIDDEN OAUTH.SERVERCLIENTSHIDDENPRIVILEGED OAUTH.SERVERCLIENTSPRIVILEGED OAUTH.CUSTOMIZATIONPRIVILEGED", "and each code combines as declared")
    Set tSC = $ClassMethod(..#SET, "WeakensByEffect", "oauth2-server", {"Clients": [], "ClientsHidden": false}, {"Clients": [], "ClientsHidden": false}, .tEffect, ..Id())
    Do $$$AssertEquals(tEffect, "", "a server with no client and nothing hidden has no effect")
}

/// <p>AC3: the tab's row action deletes the configuration and the vendor deletes every client
/// registered with it.</p>
/// <p>Mutation (Rule 19): the row action's tool <parameter>OcuPilot.Screen.Tool.OAuthAuthorizationServerDelete.SCREENACTIONS</parameter>
/// emptied -- the action is not the tab's and this goes red.</p>
Method TestADeleteCascadesTheClients()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "Gone"), .tId), "a client is registered")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ClientCount"), 1, "the instance holds it")
    Set tRequest = {"action": "delete"}
    Do tRequest.%Set("id", $ClassMethod(..#PROBE, "Issuer"), "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#ACTIONPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 200, "the row action answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds") _ " " _ $ClassMethod(..#PROBE, "ClientCount"), "0 0", "and the configuration and its client are gone")
}

}
