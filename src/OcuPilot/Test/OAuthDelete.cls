/// <p>Story 7.3's two OAuth 2.0 delete tools as declarations: each is an action-style write over its
/// tab's own two pairs, with a subject naming no secret; the prohibited set covers both entity types,
/// letting a subject-only delete through and refusing any changed field; and every write tool over a
/// <code>Security.OAuth2.*</code> endpoint is either bodyless or a merge (AC5).</p>
/// <p>Needs OcuPilot compiled and nothing else. It writes nothing to the instance: the set is asked
/// through <class>OcuPilot.Test.ProhibitedFixture</class>, whose live read is
/// <class>OcuPilot.Test.ProposalFixture</class>'s armed object.</p>
Class OcuPilot.Test.OAuthDelete Extends %UnitTest.TestCase
{

Parameter CLIENTTOOL = "security.oauthclients.delete";

Parameter CLIENTTOOLCLASS = "OcuPilot.Screen.Tool.OAuthClientDelete";

Parameter SERVERCLIENTTOOL = "security.oauthserverclients.delete";

Parameter SERVERCLIENTTOOLCLASS = "OcuPilot.Screen.Tool.OAuthServerClientDelete";

/// <p>The endpoint prefix AC5's family rule covers.</p>
Parameter FAMILYPREFIX = "Security.OAuth2.";

/// <p>The keys the <code>GET</code>s answer that no subject may name: the member object carrying
/// <code>client_secret</code> and <code>registration_access_token</code>, and the credentials
/// name (AD-35).</p>
Parameter NEVERSUBJECT = "Metadata,ClientCredentials";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Quit $$$OK
}

/// <p>What both tools declare, given the tool name <var>pName</var>, its class <var>pClass</var>,
/// its endpoint, identifying argument and parameter, its subject and its precondition field.</p>
Method AssertActionDeleteOverTheTabsOwnPairs(pName As %String, pClass As %String, pEndpoint As %String, pIdArgument As %String, pIdParam As %String, pSubject As %String, pPrecondition As %String)
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(pName, .tTool)
    Do $$$AssertStatusOK(tSC, pName _ ": the registry resolves it by name")
    Do $$$AssertTrue($IsObject(tTool), pName _ ": and finds it")
    If '$IsObject(tTool) Quit
    Do $$$AssertEquals(tTool.%Get("kind"), "write", pName _ ": a write tool")
    Do $$$AssertEquals(tTool.%Get("class"), pClass, pName _ ": answered by its own class")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Registry).FulfilmentOf(tTool), "instance", pName _ ": fulfilled on the instance")

    Do $$$AssertEquals($ClassMethod(pClass, "PortClass"), $Select(pClass = ..#CLIENTTOOLCLASS: "OcuPilot.Port.OAuthClientPort", 1: "OcuPilot.Port.AdminPort"), pName _ ": behind its port")
    Do $$$AssertEquals($ClassMethod(pClass, "Endpoint"), pEndpoint, pName _ ": over " _ pEndpoint)
    Do $$$AssertEquals($ClassMethod(pClass, "IdArgument"), pIdArgument, pName _ ": named by " _ pIdArgument)
    Do $$$AssertEquals($ClassMethod(pClass, "IdParam"), pIdParam, pName _ ": sent as the vendor's " _ pIdParam)
    Do $$$AssertEquals($ClassMethod(pClass, "ReadType"), "GET", pName _ ": its fresh read is the single-object GET")
    Do $$$AssertEquals($ClassMethod(pClass, "WriteType"), "DELETE", pName _ ": its write is the vendor's delete")
    Do $$$AssertEquals($ClassMethod(pClass, "SendsBody"), 0, pName _ ": it sends no body")
    Do $$$AssertEquals($ClassMethod(pClass, "ChangeAction"), "deleted", pName _ ": it publishes deleted")
    Do $$$AssertEquals($ClassMethod(pClass, "Destructive"), 1, pName _ ": it is destructive")
    Do $$$AssertEquals($ListLength($ClassMethod(pClass, "SettableFields")), 0, pName _ ": it admits no settable field")
    Do $$$AssertEquals($ListToString($ClassMethod(pClass, "FingerprintSubject")), pSubject, pName _ ": its subject is the one this class pins")
    Do $$$AssertEquals($ClassMethod(pClass, "PreconditionField"), pPrecondition, pName _ ": carrying its precondition field")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(pClass), "", pName _ ": and the registration guard holds the subject adequate")
    Do $$$AssertEquals($ListToString($ClassMethod(pClass, "ScreenActionIds")), "delete", pName _ ": it carries its tab's delete row action")

    ; AD-35: nothing the subject names is Metadata, the credentials name or a credential-shaped key,
    ; so the stored payload, the diff and the ledger carry no secret.
    Set tSubject = $ClassMethod(pClass, "FingerprintSubject")
    Set tNever = $ListFromString(..#NEVERSUBJECT)
    For tI = 1:1:$ListLength(tSubject) {
        Set tField = $List(tSubject, tI)
        Do $$$AssertEquals($ListFind(tNever, tField), 0, pName _ ": the subject does not name " _ tField)
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tField), 0, pName _ ": and " _ tField _ " is no credential-shaped name")
    }
    Do $$$AssertEquals($ListFind($ClassMethod(pClass, "ReadAnswers"), "Metadata"), 0, pName _ ": READANSWERS does not name Metadata")

    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating(pEndpoint, "DELETE"), pName _ ": the port admits " _ pEndpoint _ "/DELETE")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsBodyless(pEndpoint, "DELETE"), pName _ ": as a type the vendor reads no body for")

    Set tPairs = $ClassMethod(pClass, "PrivilegePairs", "", .tResolved)
    Do $$$AssertEquals(tResolved, 1, pName _ ": its pairs resolve")
    Set tDeclared = ##class(OcuPilot.Screen.Gate).RequiredPairs($Parameter(pClass, "DESCRIPTORCLASS"), .tDeclaredResolved)
    Do $$$AssertEquals(tDeclaredResolved, 1, pName _ ": the tab's own set resolves")
    Do $$$AssertEquals(tPairs, tDeclared, pName _ ": and the write's set is exactly the tab's")
    For tI = 1:1:$ListLength(tPairs) {
        Do $$$AssertNotEquals($List($List(tPairs, tI), 2), "WRITE", pName _ ": no pair at WRITE (AD-8)")
    }
}

/// <p>AC3, AC4: the client configuration delete is an action-style write over the Client
/// configurations tab's own two pairs, keyed by <code>ApplicationName</code>.</p>
Method TestTheClientConfigurationDeleteIsAnActionWriteOverTheTabsOwnPairs()
{
    Do ..AssertActionDeleteOverTheTabsOwnPairs(..#CLIENTTOOL, ..#CLIENTTOOLCLASS, "Security.OAuth2.Client.ClientConfiguration", "ApplicationName", "applicationName", "ServerDefinition,ClientType,DefaultScope,Enabled", "ClientType")
}

/// <p>AC2, AC3, AC4: the server client delete is an action-style write over the Server client
/// descriptions tab's own two pairs, keyed by <code>ClientId</code>, the vendor's IdKey.</p>
Method TestTheServerClientDeleteIsAnActionWriteOverTheTabsOwnPairs()
{
    Do ..AssertActionDeleteOverTheTabsOwnPairs(..#SERVERCLIENTTOOL, ..#SERVERCLIENTTOOLCLASS, "Security.OAuth2.ServerClients", "ClientId", "clientId", "Name,ClientType,RedirectURL,Description", "ClientType")
}

/// <p>One target of each type as its <code>GET</code> shapes it, with <var>pDescription</var> as its
/// <code>Description</code>.</p>
ClassMethod Fresh(pTool As %String, pDescription As %String = "before") As %DynamicObject
{
    If pTool = ..#CLIENTTOOL {
        Set tFresh = {"ServerDefinition": "7", "Enabled": true, "ClientType": "confidential", "SSLConfiguration": "OcuPilotDemoTLS", "ClientId": "probe", "ClientCredentials": "", "Metadata": {"client_secret": "probe-secret"}, "DefaultScope": ""}
    } Else {
        Set tFresh = {"Name": "probe", "RedirectURL": [], "LaunchURL": "", "ClientType": "resource", "ClientCredentials": "", "Metadata": {"client_secret": "probe-secret"}, "DefaultScope": ""}
    }
    Do tFresh.%Set("Description", pDescription, "string")
    Quit tFresh
}

/// <p>AC4, AD-10: each type is covered. A subject-only delete, with the tool's own removal rows as
/// its diff, is not prohibited; a diff naming a field outside the subject that the payload changes
/// -- <code>PublicJWKS</code> for a configuration, outside its reviewed list, <code>DefaultScope</code>
/// and <code>Enabled</code> for a server client, whose subject carries its description and whose
/// reviewed list is empty -- is refused <code>PROHIBITED.UNCOVEREDFIELD</code>. A subject field is the
/// fingerprint's to adjudicate, not this sweep's.</p>
/// <p>Mutation (Rule 19): drop either type from
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.COVEREDTYPES</parameter> -- its subject-only leg
/// is refused <code>PROHIBITED.UNCOVERED</code> and goes red. Send the server client past the
/// <method>OcuPilot.Kernel.Proposal.Prohibited.OAuthEntry</method> branch -- it falls through to the
/// web application predicates, which permit <code>Enabled</code>, and its <code>Enabled</code> leg
/// goes red.</p>
Method TestEachOAuthTypeIsCoveredAndRefusesAChangedField()
{
    Set tUncoveredField = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "UNCOVEREDFIELD")
    For tCase = $ListBuild(..#CLIENTTOOL, ..#CLIENTTOOLCLASS, "oauth2-client-configuration", "OcuPilotTestDelete", "PublicJWKS"), $ListBuild(..#SERVERCLIENTTOOL, ..#SERVERCLIENTTOOLCLASS, "oauth2-server-client", "probe-client-id", "DefaultScope"), $ListBuild(..#SERVERCLIENTTOOL, ..#SERVERCLIENTTOOLCLASS, "oauth2-server-client", "probe-client-id", "Enabled") {
        Set tTool = $List(tCase, 1)
        Set tClass = $List(tCase, 2)
        Set tType = $List(tCase, 3)
        Set tId = $List(tCase, 4)
        Set tChangedField = $List(tCase, 5)
        Do $$$AssertEquals($ListFind($ClassMethod(tClass, "FingerprintSubject"), tChangedField), 0, tTool _ ": " _ tChangedField _ " is outside the subject")
        Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Proposal.Prohibited).CoveredTypes(), tType) > 0, tType _ " is a covered type")
        Set tFresh = ..Fresh(tTool)
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Projection(tFresh, $ClassMethod(tClass, "FingerprintSubject"), .tPayload)
        Do $$$AssertStatusOK(tSC, tTool _ ": the fresh read projects to the subject")
        Set tSC = $ClassMethod(tClass, "StateDiff", tFresh, .tRows, .tProblem)
        Do $$$AssertStatusOK(tSC, tTool _ ": its removal rows are computed")
        Do $$$AssertEquals(tProblem, "", tTool _ ": for a target that reports its type")
        Do $$$AssertEquals(tPayload.%GetTypeOf("Metadata"), "unassigned", tTool _ ": the stored payload carries no Metadata")
        Do $$$AssertEquals((tRows.%ToJSON() [ "client_secret") || (tRows.%ToJSON() [ "Metadata"), 0, tTool _ ": and neither does the diff")

        Set tSC = ##class(OcuPilot.Test.ProhibitedFixture).Ask(tFresh.%ToJSON(), tPayload.%ToJSON(), tRows.%ToJSON(), tId, tType, .tProhibits, .tCode, tTool)
        Do $$$AssertStatusOK(tSC, tTool _ ": the set answers the subject-only delete")
        Do $$$AssertEquals(tProhibits, 0, tTool _ ": and does not prohibit it: " _ tCode)

        Do tPayload.%Set(tChangedField, "after", "string")
        Set tSC = ##class(OcuPilot.Test.ProhibitedFixture).Ask(tFresh.%ToJSON(), tPayload.%ToJSON(), ##class(OcuPilot.Test.ProhibitedFixture).Diff(tChangedField), tId, tType, .tProhibits, .tCode, tTool)
        Do $$$AssertStatusOK(tSC, tTool _ ": the set answers a changed " _ tChangedField)
        Do $$$AssertEquals(tProhibits, 1, tTool _ ": and prohibits it")
        Do $$$AssertEquals(tCode, tUncoveredField, tTool _ ": as a field nobody has reviewed")
    }
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields("oauth2-client-configuration")), "ServerDefinition,Enabled,Description,ClientType,SSLConfiguration,RedirectionEndpoint,JWTAudience,JWTInterval,ClientId,ClientCredentials,Metadata,DefaultScope", "the client configuration's reviewed fields are exactly the template's twelve")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields("oauth2-server-client"), "", "and no server client field")
}

/// <p>Each tool's precondition: a fresh read that answers no <code>ClientType</code> did not answer
/// the target's own record, so <method>StateDiff</method> answers a problem and no removal rows,
/// which the mint and the row-action route both refuse.</p>
/// <p>Mutation (Rule 19): delete the <code>If tReported = ""</code> block from either tool's
/// <method>StateDiff</method> -- its problem and row-count assertions go red.</p>
Method TestAReadWithoutTheClientTypeIsAPreconditionProblem()
{
    For tCase = $ListBuild(..#CLIENTTOOL, ..#CLIENTTOOLCLASS), $ListBuild(..#SERVERCLIENTTOOL, ..#SERVERCLIENTTOOLCLASS) {
        Set tTool = $List(tCase, 1)
        Set tClass = $List(tCase, 2)
        Set tFresh = ..Fresh(tTool)
        Do tFresh.%Remove("ClientType")
        Set tSC = $ClassMethod(tClass, "StateDiff", tFresh, .tRows, .tProblem)
        Do $$$AssertStatusOK(tSC, tTool _ ": a read without its type is answered, not raised")
        Do $$$AssertNotEquals(tProblem, "", tTool _ ": and is a precondition problem")
        Do $$$AssertEquals(tRows.%Size(), 0, tTool _ ": with no removal rows")
    }
}

/// <p>AC5: no <code>Security.OAuth2.*</code> endpoint merges (AD-4), so every registered write tool
/// over one is bodyless -- <code>SENDSBODY</code> 0 and its <code>&lt;endpoint&gt;/&lt;type&gt;</code>
/// in the port's <code>BODYLESSTYPES</code> --, a create (AD-54), a <code>PUT</code> merge write whose
/// body is <method>OcuPilot.Kernel.Proposal.Mint.Merge</method>'s complete property set over a fresh
/// read, a secret-body write (AD-56) or a type its port composes (AD-51).
/// Each half is named exactly.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Screen.Tool.OAuthClientDelete.SENDSBODY</parameter>
/// to 1 and its <parameter>OcuPilot.Screen.Tool.OAuthClientDelete.FINGERPRINTSUBJECT</parameter> to
/// <code>""</code> -- that tool lands in no half, and the bodyless and every-tool assertions go red.
/// <code>SENDSBODY</code> alone is refused at registration, so no assertion here is reached.</p>
Method TestEveryOAuthWriteToolIsBodylessOrAMerge()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the registry lists its tools")
    If $$$ISERR(tSC) Quit
    Set tNeither = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If '$IsObject(tEntry) || (tEntry.%Get("kind") '= "write") Continue
        Set tClass = tEntry.%Get("class")
        Set tEndpoint = $ClassMethod(tClass, "Endpoint")
        If $Extract(tEndpoint, 1, $Length(..#FAMILYPREFIX)) '= ..#FAMILYPREFIX Continue
        Set tType = $ClassMethod(tClass, "WriteType")
        Set tSends = $ClassMethod(tClass, "SendsBody")
        Set tHalf = ""
        If 'tSends && ##class(OcuPilot.Port.AdminPort).IsBodyless(tEndpoint, tType) {
            Set tHalf = "bodyless"
        } ElseIf tSends && $Parameter(tClass, "CREATES") && ((tType = "POST") || (tType = "PUT")) {
            Set tHalf = "create"
        } ElseIf tSends && (tType = "PUT") && ($ClassMethod(tClass, "FingerprintSubject") = "") {
            Set tHalf = "merge"
        } ElseIf 'tSends && ($Parameter(tClass, "SECRETBODY") '= "") {
            Set tHalf = "secret"
        } ElseIf 'tSends && $ListFind($ListFromString($Parameter($ClassMethod(tClass, "PortClass"), "COMPOSEDTYPES")), tEndpoint _ "/" _ tType) {
            Set tHalf = "composed"
        }
        If tHalf = "" {
            Set tNeither = tNeither _ $ListBuild(tEntry.%Get("name"))
        } Else {
            Set tByHalf(tHalf, tEntry.%Get("name")) = ""
        }
    }
    Do $$$AssertEquals($ListToString(tNeither), "", "every OAuth 2.0 write tool is in one half")
    Do $$$AssertEquals(..Half(.tByHalf, "bodyless"), "permissions.users.revoketokens," _ ..#CLIENTTOOL _ ",security.oauthclients.register,security.oauthclients.rotatekeys,security.oauthresourceservers.addmapping,security.oauthresourceservers.delete,security.oauthresourceservers.removemapping," _ ..#SERVERCLIENTTOOL _ ",security.oauthserverdescriptions.delete", "the bodyless half is exactly the four deletes, Story 12.2's token revoke, Story 12.5's registration and key rotation and Story 12.6's two mapping writes")
    Do $$$AssertEquals(..Half(.tByHalf, "merge"), "security.oauthclients.update,security.oauthresourceservers.update,security.oauthserverdescriptions.update", "the merge half is exactly Stories 12.4's, 12.5's and 12.6's edits")
    Do $$$AssertEquals(..Half(.tByHalf, "create"), "security.oauthclients.create,security.oauthresourceservers.create,security.oauthserverdescriptions.create", "the create half is exactly Stories 12.4's, 12.5's and 12.6's creates")
    Do $$$AssertEquals(..Half(.tByHalf, "secret"), "security.oauthclients.setsecrets,security.oauthresourceservers.setsecret,security.oauthserverdescriptions.settoken", "the secret-body half is exactly Story 12.4's token write, Story 12.5's client secrets and Story 12.6's client secret")
    Do $$$AssertEquals(..Half(.tByHalf, "composed"), "security.oauthserverdescriptions.updatejwks", "and the composed half exactly Story 12.4's key-set refresh")
}

/// <p>The tool names <var>pByHalf</var> holds under <var>pHalf</var>, in collation order,
/// comma-separated.</p>
ClassMethod Half(ByRef pByHalf, pHalf As %String) As %String
{
    Set tNames = ""
    Set tName = ""
    For {
        Set tName = $Order(pByHalf(pHalf, tName))
        If tName = "" Quit
        Set tNames = tNames _ $ListBuild(tName)
    }
    Quit $ListToString(tNames)
}

}
