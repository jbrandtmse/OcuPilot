/// <p>Pins Story 12.6's resource server edit (AD-4, AD-39, AD-55): the Save and the agent's edit send
/// the complete set -- every template field, <code>Audiences</code> whole, and every authenticator
/// setting the edit leaves out filled from the fresh read while the namespace and class stay -- so a
/// partial edit leaves every other field and setting as stored; an edit that names another
/// authenticator class sends only its own settings; and the edit's form rules refuse on both callers.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed with the demo fixture, an account
/// holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it
/// creates and deletes OAuth 2.0 resource servers and server descriptions. Every object is an
/// <class>OcuPilot.Test.OAuthResourceServerProbe</class> one, removed by exact name.</p>
Class OcuPilot.Test.OAuthResourceServerUpdate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthResourceServerUpdate";

Parameter SCREEN = "OcuPilot.Test.OAuthResourceServerSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthResourceServerConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthResourceServerRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthResourceServerProbe";

Parameter FAILPORT = "OcuPilot.Test.OAuthResourceServerFailPort";

Parameter FAILSAVE = "OcuPilot.Test.OAuthResourceServerFailSave";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter SIMPLE = "%OAuth2.ResourceServer.SimpleAuthenticator";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthResourceServerUpdate creates and deletes OAuth 2.0 resource servers on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "AddServer", ..Issuer())
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#FAILPORT, "Disarm")
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

ClassMethod Issuer() As %String
{
    Quit $ClassMethod(..#PROBE, "Issuer", "update")
}

/// <p>Make server <var>pName</var> with a description, two audiences, a client ID and the simple
/// authenticator's three settings each set.</p>
ClassMethod MakeServer(pName As %String) As %Status
{
    Set tSettings = {"Description": "before", "ClientId": "probe-client", "ScopeRequiredToConnect": "kept.scope"}
    Do tSettings.%Set("Authenticator", {"Namespace": "%SYS", "Implementation": (..#SIMPLE), "UserClaim": "user.before", "RoleClaim": "roles.kept", "Prefix": "kept:"})
    Quit $ClassMethod(..#PROBE, "AddResource", pName, ..Issuer(), $ListBuild("aud.one", "aud.two"), tSettings)
}

/// <p>AC2 on the screen's caller: an edit changing the description, removing one audience and changing
/// one authenticator setting sends the complete set -- every template field, the audiences whole and
/// all three settings -- and the instance then holds exactly that, every other field and setting as
/// before.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthResourceServerRules.Expand</method> stops
/// filling the settings the edit leaves out -- the kept-settings assertion goes red, as the vendor
/// resets them to the class's defaults.</p>
Method TestAnEditSendsTheCompleteSet()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Edit")
    Do $$$AssertStatusOK(..MakeServer(tName), "a server is created")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tName)
    Set tBody = {"Description": "after", "Audiences": ["aud.one"]}
    Do tBody.%Set("Authenticator", {"Namespace": "%SYS", "Implementation": (..#SIMPLE), "UserClaim": "user.after"})
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, tBody, [], [], .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the edit completes: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes"), "PUT", "one vendor PUT")
    Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#RECORD, "LastBody", "PUT"))
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Keys", tSent), "AccessTokenIsJWT,AlwaysCallIntrospection,Audiences,Authenticator,ClientId,Description,Enabled,IntrospectionAuthMethod,IssuerEndpoint,ScopeRequiredToConnect,UseOIDC", "carrying every template field")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Keys", tSent.%Get("Authenticator")), "Implementation,Namespace,Prefix,RoleClaim,UserClaim", "and every authenticator setting")
    Set tAfter = $ClassMethod(..#PROBE, "Stored", tName)
    Do $$$AssertEquals(tAfter.%Get("Description") _ "|" _ tAfter.%Get("Audiences").%ToJSON() _ "|" _ tAfter.%Get("Authenticator").%Get("UserClaim"), "after|[""aud.one""]|user.after", "the instance holds exactly the edit")
    Do $$$AssertEquals(tAfter.%Get("Authenticator").%Get("RoleClaim") _ "|" _ tAfter.%Get("Authenticator").%Get("Prefix"), "roles.kept|kept:", "and keeps the two settings the edit left out")
    For tField = "ClientId", "ScopeRequiredToConnect", "IssuerEndpoint", "IntrospectionAuthMethod", "Enabled", "AccessTokenIsJWT", "AlwaysCallIntrospection", "UseOIDC" {
        Do $$$AssertEquals(tAfter.%Get(tField), tBefore.%Get(tField), tField _ " is as before")
    }
}

/// <p>An edit naming another authenticator class replaces the authenticator with that class and sends
/// only the settings it names: the probe authenticator's <code>Claim</code> is stored and the simple
/// authenticator's settings are gone; switching back leaves the settings it omits at the class's
/// defaults.</p>
Method TestAnImplementationChangeTakesTheNewClassDefaults()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Switch")
    Do $$$AssertStatusOK(..MakeServer(tName), "a server is created")
    Set tBody = {}
    Do tBody.%Set("Authenticator", {"Namespace": ($ClassMethod(..#PROBE, "Namespace")), "Implementation": ($Parameter(..#PROBE, "AUTHENTICATOR")), "Claim": "email"})
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, tBody, [], [], .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the switch completes: " _ $System.Status.GetErrorText(tSC))
    Set tStored = $ClassMethod(..#PROBE, "Stored", tName).%Get("Authenticator")
    Do $$$AssertEquals(tStored.%Get("Implementation") _ "|" _ tStored.%Get("Claim") _ "|" _ tStored.%GetTypeOf("UserClaim"), $Parameter(..#PROBE, "AUTHENTICATOR") _ "|email|unassigned", "the new class holds its one setting")
    Set tBody = {}
    Do tBody.%Set("Authenticator", {"Namespace": "%SYS", "Implementation": (..#SIMPLE), "UserClaim": "user.back"})
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, tBody, [], [], .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the switch back completes")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tName).%Get("Authenticator")
    Do $$$AssertEquals(tStored.%Get("UserClaim") _ "|" _ tStored.%Get("RoleClaim") _ "|" _ tStored.%Get("Prefix"), "user.back|scope|", "and the class's defaults fill the rest")
}

/// <p>AC7's edit half: the agent's edit naming one authenticator setting is minted with the complete
/// authenticator in its diff and confirmed, and the instance keeps the settings the agent left out.</p>
Method TestTheAgentsEditKeepsTheUnsentSettings()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Agent")
    Do $$$AssertStatusOK(..MakeServer(tName), "a server is created")
    Set tArgs = {"Description": "agent"}
    Do tArgs.%Set("Name", tName, "string")
    Do tArgs.%Set("Authenticator", {"Namespace": "%SYS", "Implementation": (..#SIMPLE), "Prefix": "agent:"})
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the edit is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tAfterText = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { If tRow.%Get("field") = "Authenticator" Set tAfterText = tRow.%Get("after") }
    Do $$$AssertTrue((tAfterText [ "roles.kept") && (tAfterText [ "agent:"), "its Authenticator row shows the complete result: " _ tAfterText)
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the edit is confirmed: " _ $Get(tCode))
    Set tStored = $ClassMethod(..#PROBE, "Stored", tName)
    Do $$$AssertEquals(tStored.%Get("Description") _ "|" _ tStored.%Get("Authenticator").%Get("Prefix") _ "|" _ tStored.%Get("Authenticator").%Get("UserClaim") _ "|" _ tStored.%Get("Authenticator").%Get("RoleClaim"), "agent|agent:|user.before|roles.kept", "the instance holds the edit and keeps the settings left out")
}

/// <p>The card states the reset (AD-4): the agent's edit naming another authenticator class is minted
/// destructive with <code>OAUTH.AUTHENTICATORRESET</code> as its consequence, and one leaving the
/// authenticator's namespace and class as stored is an ordinary edit.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method> stops
/// naming <parameter>OcuPilot.Kernel.Proposal.Prohibited.EFFECTAUTHENTICATORRESET</parameter> -- the
/// first assertion goes red.</p>
Method TestAnAgentsAuthenticatorChangeIsMintedDestructive()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Reset")
    Do $$$AssertStatusOK(..MakeServer(tName), "a server is created")
    Set tArgs = {}
    Do tArgs.%Set("Name", tName, "string")
    Do tArgs.%Set("Authenticator", {"Namespace": ($ClassMethod(..#PROBE, "Namespace")), "Implementation": ($Parameter(..#PROBE, "AUTHENTICATOR")), "Claim": "email"})
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the switch is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Do ##class(OcuPilot.Test.ServiceUpdate).Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 OAUTH.AUTHENTICATORRESET", "destructive, naming the reset")
    Set tArgs = {"Description": "kept class"}
    Do tArgs.%Set("Name", tName, "string")
    Do tArgs.%Set("Authenticator", {"Namespace": "%sys", "Implementation": (..#SIMPLE), "Prefix": "same:"})
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the edit is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Do ##class(OcuPilot.Test.ServiceUpdate).Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "0 ", "the same namespace, in another case, and class is an ordinary edit")
}

/// <p>A vendor 500 on the <code>PUT</code> is answered 422
/// <code>OAUTH.RESOURCESERVERVALIDATION</code>, and the vendor's text stays in the log.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthResourceServerPort.Put</method> returns a vendor
/// 500 unmapped -- the status and code assertion goes red.</p>
Method TestAVendorRefusalOfThePutIsNamed()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Vendor")
    Do $$$AssertStatusOK(..MakeServer(tName), "a server is created")
    Do $ClassMethod(..#FAILPORT, "Arm", "Security.OAuth2.ResourceServer", "PUT", 500)
    Set tSC = $ClassMethod(..#FAILSAVE, "Handle", tName, {"Description": "refused"}, .tRaw, .tStatus)
    Do $$$AssertStatusOK(tSC, "the edit's route runs")
    Do $$$AssertEquals(tStatus _ " " _ (tRaw [ """OAUTH.RESOURCESERVERVALIDATION"""), "422 1", "answered 422 with the named code: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue('(tRaw [ "canned vendor refusal"), "without the vendor's text")
    Do $$$AssertEquals($ClassMethod(..#FAILPORT, "Reached", "Security.OAuth2.ResourceServer", "PUT"), 1, "after the PUT reached the armed vendor")
}

/// <p>The edit's form rules refuse on both callers against the stored server: an emptied audience list,
/// an unknown issuer, an unknown introspection method and a 300-character description each refuse on
/// their field with nothing sent; a valid edit leaving the required fields out is accepted.</p>
Method TestTheEditsFormRulesRefuseOnBothCallers()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Rules")
    Do $$$AssertStatusOK(..MakeServer(tName), "a server is created")
    Set tLong = $Translate($Justify("", 300), " ", "x")
    Set tCase($Increment(tCase)) = $ListBuild("Audiences", "OAUTH.AUDIENCES.REQUIRED")
    Set tPatch(tCase) = {"Audiences": []}
    Set tCase($Increment(tCase)) = $ListBuild("IssuerEndpoint", "OAUTH.ISSUERENDPOINT.ABSENT")
    Set tPatch(tCase) = {"IssuerEndpoint": "https://ocupilotprobe126.invalid/nosuchissuer"}
    Set tCase($Increment(tCase)) = $ListBuild("IntrospectionAuthMethod", "OAUTH.INTROSPECTIONAUTHMETHOD.VALUE")
    Set tPatch(tCase) = {"IntrospectionAuthMethod": "bogus"}
    Set tCase($Increment(tCase)) = $ListBuild("Description", "OAUTH.DESCRIPTION.LENGTH")
    Set tPatch(tCase) = {}
    Do tPatch(tCase).%Set("Description", tLong, "string")
    For tI = 1:1:tCase {
        Set tField = $List(tCase(tI), 1)
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Update", tName, tPatch(tI), [], [], .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, tField), $List(tCase(tI), 2), "case " _ tI _ ": the Save refuses " _ tField)
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "case " _ tI _ ": and sends nothing")
        Set tArgs = ##class(%DynamicObject).%FromJSON(tPatch(tI).%ToJSON())
        Do tArgs.%Set("Name", tName, "string")
        Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ("'" _ tField _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase(tI), 2)))), "case " _ tI _ ": and the agent's mint refuses it with the field's sentence: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    }
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, {"Enabled": false}, [], [], .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(+$Get(tViolations) _ " " _ $ClassMethod(..#RECORD, "WriteTypes"), "0 PUT", "an edit leaving the required fields out is accepted and sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Enabled"), 0, "and stored")
}

/// <p>An edit whose fields repeat what the instance stores sends no server write.</p>
Method TestAnEditRepeatingStoredValuesSendsNoPut()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Repeat")
    Do $$$AssertStatusOK(..MakeServer(tName), "a server is created")
    Set tRead = $ClassMethod(..#PROBE, "Read", tName)
    Do $$$AssertTrue($IsObject(tRead), "the server reads")
    If '$IsObject(tRead) Quit
    Set tBody = {}
    For tField = "Description", "Audiences", "Authenticator" {
        If $IsObject(tRead.%Get(tField)) { Do tBody.%Set(tField, tRead.%Get(tField)) } Else { Do tBody.%Set(tField, tRead.%Get(tField), "string") }
    }
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, tBody, [], [], .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "an edit re-sending " _ tBody.%ToJSON() _ " completes")
    Do $$$AssertEquals(+$Get(tViolations) _ " " _ $ClassMethod(..#RECORD, "WriteCount"), "0 0", "with no violation, and sends no server write")
}

}
