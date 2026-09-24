/// <p>Pins Story 9.5's three SSL/TLS write tools as the agent reaches them (AD-3, AD-6, AD-10, AD-51,
/// AD-54): what <class>OcuPilot.Screen.Tool.SslCreate</class>,
/// <class>OcuPilot.Screen.Tool.SslUpdate</class> and <class>OcuPilot.Screen.Tool.SslDelete</class>
/// advertise and declare; a create fingerprinted over the name's absence; a change turning peer
/// verification off minted destructive with its effect named; a no-op refused at the mint; and a
/// change to OcuPilot's own provider configuration's installer-owned fields refused at the mint with
/// the published sentence.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state readable.
/// Every mint's fresh read and every confirmed write go to <class>OcuPilot.Test.ProposalFixture</class>;
/// the tools' own rules read the instance, and only read it. No arming variable is required.</p>
Class OcuPilot.Test.SslUpdate Extends %UnitTest.TestCase
{

Parameter CREATE = "OcuPilot.Screen.Tool.SslCreate";

Parameter UPDATE = "OcuPilot.Screen.Tool.SslUpdate";

Parameter DELETE = "OcuPilot.Screen.Tool.SslDelete";

Parameter LIST = "OcuPilot.Screen.Descriptor.SslConfigList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>A name the instance does not hold, which every proposal here is about but OcuPilot's own.</p>
Parameter PROBE = "OcuPilotProbeSslUpdate";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>AD-3, AD-54: the create requires what the vendor requires and admits the thirteen settings;
/// the change admits the same thirteen and carries the private key password as a declared secret no
/// schema offers; neither advertises a file location. Each tool's positive list is the prohibited
/// set's. The delete is an action write over the vendor's bodyless <code>DELETE</code>, fingerprinted
/// over the four settings anything connecting through the configuration relies on.</p>
Method TestTheToolsDeclareTheirFieldsAndShapes()
{
    Set tCreate = $ClassMethod(..#CREATE, "InputSchema")
    Do $$$AssertEquals(tCreate.%Get("required").%ToJSON(), "[""Name"",""Type"",""VerifyPeer"",""Enabled""]", "the create requires the name and what the vendor requires")
    Set tUpdate = $ClassMethod(..#UPDATE, "InputSchema")
    Do $$$AssertEquals(tUpdate.%Get("required").%ToJSON(), "[""Name""]", "the change requires only the name")
    Set tThirteen = ..Sorted($ListFromString($Parameter(..#CREATE, "PERMITTEDFIELDS")))
    For tSchema = tCreate, tUpdate {
        Set tNames = ""
        Set tIterator = tSchema.%Get("properties").%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If $ListFind($ListBuild("Name", "rationale", "expectedImpact", "reverse"), tKey) Continue
            Set tNames = tNames _ $ListBuild(tKey)
        }
        Do $$$AssertEquals(..Sorted(tNames), tThirteen, "a schema advertises the thirteen settings and nothing else")
        Do $$$AssertEquals(tSchema.%Get("properties").%Get("VerifyPeer").%Get("type"), "integer", "typed as the vendor's read answers them")
    }
    Do $$$AssertEquals(..Sorted($ClassMethod(..#CREATE, "SettableFields")), tThirteen, "the create sets the thirteen")
    Do $$$AssertEquals(..Sorted($ClassMethod(..#SET, "PermittedCreateFields", "ssl-configuration")), tThirteen, "which the prohibited set permits a create")
    Do $$$AssertEquals(..Sorted($ClassMethod(..#UPDATE, "SettableFields")), ..Sorted($ClassMethod(..#SET, "PermittedChangeFields", "ssl-configuration")), "the change sets what the set permits a change, the password among them")
    Do $$$AssertTrue($ListFind($ClassMethod(..#UPDATE, "SecretArguments"), "PrivateKeyPassword") > 0, "which is a declared secret")
    Do $$$AssertEquals($ClassMethod(..#CREATE, "SecretArguments") _ $ClassMethod(..#DELETE, "SecretArguments"), "", "while the create and the delete admit none")

    Do $$$AssertEquals($ClassMethod(..#DELETE, "ReadType") _ " " _ $ClassMethod(..#DELETE, "WriteType") _ " " _ $ClassMethod(..#DELETE, "SendsBody"), "GET DELETE 0", "the delete is bodyless over the vendor's GET")
    Do $$$AssertEquals($ListToString($ClassMethod(..#DELETE, "FingerprintSubject")), "Type,VerifyPeer,CAFile,Enabled", "fingerprinted over what a connection relies on")
    Do $$$AssertEquals($ClassMethod(..#DELETE, "Destructive") _ " " _ $ClassMethod(..#DELETE, "ChangeAction"), "1 deleted", "destructive, publishing deleted")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(..#DELETE), "", "and the registry accepts its subject")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).IsBodyless("Security.SSLConfig", "DELETE"), 1, "the port admits the delete bodyless")
}

/// <p>AD-54: a create is minted over the name's absence, every supplied setting a row; a
/// configuration of that name made since the mint refuses the confirm with nothing written.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Screen.Tool.SslCreate.CREATES</parameter> to 0 --
/// the absent target refuses the mint and this goes red.</p>
Method TestTheCreateFingerprintsTheNamesAbsence()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#CREATE, {"Name": (..#PROBE), "Type": 0, "VerifyPeer": 1, "Enabled": true, "CAFile": "%OSCertificateStore"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is minted: " _ ..Problem(.tFault))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 4, "one row per supplied setting")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "and nothing sent unchanged")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm({"Type": 0, "VerifyPeer": 0, "Enabled": true}.%ToJSON())
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "a name taken since the mint refuses the confirm")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is written")

    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#CREATE, {"Name": (..#PROBE), "Type": 1, "VerifyPeer": 0, "Enabled": true}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "a server create is refused at the mint")
}

/// <p>AD-10 (the DW-1207 pattern): turning peer verification off on a configuration that is not
/// OcuPilot's own is minted destructive with <code>SSL.NOPEERCHECK</code> as its consequence, while a
/// change that leaves it on is neither.</p>
/// <p>Mutation (Rule 19): drop the SSL branch from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method> -- the destructive and
/// consequence assertions go red.</p>
Method TestTurningPeerVerificationOffIsMintedDestructive()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh())
    Set tKey = ..MintedKey(..#UPDATE, {"Name": (..#PROBE), "VerifyPeer": 0})
    Do $$$AssertNotEquals(tKey, "", "the change is minted")
    Do ..Stored(tKey, .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 " _ $Parameter(..#SET, "EFFECTNOPEERCHECK"), "destructive, naming its effect")
    Set tKey = ..MintedKey(..#UPDATE, {"Name": (..#PROBE), "Description": "probe"})
    Do ..Stored(tKey, .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "0 ", "while a change leaving it on is neither")
}

/// <p>Epic 9's editor contract: a change that restates what the configuration holds is 400
/// <code>TOOL.ARGUMENTS</code> at the mint, never an empty proposal. Read from OcuPilot's own
/// configuration, which the mint only reads.</p>
/// <p>Mutation (Rule 19): drop the no-op refusal from
/// <method>OcuPilot.Screen.Tool.SslUpdate.ArgumentProblem</method> -- a proposal carrying only the
/// optional password row is minted and this goes red.</p>
Method TestANoOpIsRefusedAtTheMint()
{
    Set tOwn = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG
    Kill tQuery
    Set tQuery("name") = tOwn
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.SSLConfig", "GET", .tQuery, "", .tHeld, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "OcuPilot's own configuration reads")
    If '$IsObject($Get(tHeld)) Quit
    ; The mint's own read answers a key file, so the card would carry the optional password row: the
    ; refusal has to come from the tool, not from an empty card.
    Do tHeld.%Set("PrivateKeyFile", "/probe/key.pem", "string")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tHeld.%ToJSON())
    For tArgs = {"Name": (tOwn), "Description": (tHeld.%Get("Description"))}, {"Name": (tOwn)} {
        Set tSC = ..Mint(..#UPDATE, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, tArgs.%ToJSON() _ " is refused as changing nothing")
        Do $$$AssertTrue(..Problem(.tFault) [ "nothing would change", tArgs.%ToJSON() _ ": by the tool's own no-op rule: " _ ..Problem(.tFault))
    }
}

/// <p>AD-10, AD-53: a change to the type, peer verification, trusted certificates or enablement of
/// OcuPilot's own provider configuration is refused at the mint with the sentence the kernel refuses
/// its write with, while its description is proposed.</p>
/// <p>Mutation (Rule 19): drop the own-configuration check from
/// <method>OcuPilot.Screen.Tool.SslUpdate.ArgumentProblem</method> -- the four fields are minted and
/// this goes red.</p>
Method TestOcuPilotsOwnConfigurationIsRefusedAtTheMint()
{
    Set tOwn = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG
    Kill tQuery
    Set tQuery("name") = tOwn
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.SSLConfig", "GET", .tQuery, "", .tHeld, .tHttp, .tFault)
    If '$IsObject($Get(tHeld)) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tHeld.%ToJSON())
    For tArgs = {"VerifyPeer": 0}, {"Enabled": false}, {"CAFile": ""}, {"Type": 1} {
        Do tArgs.%Set("Name", tOwn, "string")
        Set tSC = ..Mint(..#UPDATE, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, tArgs.%ToJSON() _ " is refused at the mint")
        Do $$$AssertTrue(..Problem(.tFault) [ $Parameter(..#SET, "OCUPILOTSSLREASON"), tArgs.%ToJSON() _ ": with the published sentence")
    }
    Set tSC = ..Mint(..#UPDATE, {"Name": (tOwn), "Description": "probe"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "its description is proposed: " _ ..Problem(.tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is written")
}

/// <p>AD-5, AD-39: the form is built, unlisted and at the list's own route with the editor suffix,
/// over the list's own pairs, and its context never carries a password being typed; every
/// <code>SSL.*</code> field code carries a sentence; the list declares Create and Delete and invites
/// the agent.</p>
Method TestTheFormDescriptorIsBuiltUnlistedAndCarriesTheListsOwnPairs()
{
    Set tForm = "OcuPilot.Screen.Descriptor.SslForm"
    Do $$$AssertEquals($ClassMethod(tForm, "Route"), $ClassMethod(..#LIST, "Route") _ "/edit", "the form's route is the list's own with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(tForm, "IsBuilt") _ " " _ (+$ClassMethod(tForm, "SideBarPosition")), "1 0", "it is built and unlisted")
    Do $$$AssertEquals($ClassMethod(tForm, "Archetype") _ " " _ $ClassMethod(tForm, "PrimaryEntityType"), "form-page ssl-configuration", "a form page over the SSL/TLS configuration type")
    Do $$$AssertEquals($ClassMethod(tForm, "ToolIdentifier"), "security.sslform", "with its own tool identifier")
    Do $$$AssertEquals($IsObject($ClassMethod(tForm, "Read")), 0, "and no declared read")
    Do $$$AssertEquals($ListToString($ClassMethod(tForm, "PrivilegePairs")), $ListToString($ClassMethod(..#LIST, "PrivilegePairs")), "the form requires exactly what the list requires")
    Do $$$AssertEquals($Parameter("OcuPilot.Area.Security.SslSave", "DESCRIPTORCLASS") _ " " _ $Parameter("OcuPilot.Area.Security.SslRules", "DESCRIPTORCLASS"), tForm _ " " _ tForm, "and the routes gate on the form's declaration")
    Set tSC = $ClassMethod(tForm, "DeclarationJson", .tFormDeclaration)
    Do $$$AssertStatusOK(tSC, "the form's declaration parses")
    If $$$ISOK(tSC) Do $$$AssertEquals(tFormDeclaration.%Get("context").%Get("secretFields").%ToJSON(), "[""PrivateKeyPassword""]", "its context never carries a password being typed")

    Set tCodes = ##class(OcuPilot.Api.Error).SslViolationCodes()
    Do $$$AssertTrue($ListLength(tCodes) > 0, "the story publishes SSL field codes")
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a written sentence")
    }
    Set tSC = $ClassMethod(..#LIST, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the list's declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tDeclaration.%Get("primaryAction").%Get("id"), "create", "the list declares Create as its primary action")
    Do $$$AssertEquals(tDeclaration.%Get("rowActions").%ToJSON(), "[{""id"":""delete"",""selfProtection"":""ocupilot-ssl""}]", "and Delete, drawn refused on OcuPilot's own configuration")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyNextKey"), "", "so its empty state names no next step")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyAgentKey"), "sslListEmptyAgent", "and invites the agent instead")
}

/// <p>A probe client as the vendor's read answers one, verifying its peer.</p>
ClassMethod Fresh() As %String
{
    Quit {"AuthorizeCN": false, "CAFile": "%OSCertificateStore", "CAPath": "", "CertificateFile": "", "CipherList": ["ALL"], "Ciphersuites": ["TLS_AES_256_GCM_SHA384"], "Description": "", "DiffieHellmanBits": 0, "Enabled": true, "OCSP": 0, "OCSPIssuerCert": "", "OCSPResponseFile": "", "OCSPTimeout": 2, "OCSPURL": "", "PrivateKeyFile": "", "PrivateKeyType": 2, "TLSMaxVersion": 32, "TLSMinVersion": 16, "Type": 0, "VerifyDepth": 9, "VerifyPeer": 1}.%ToJSON()
}

/// <p>Mint one proposal of tool <var>pTool</var> with <var>pArgs</var> through the fixture mint.</p>
Method Mint(pTool As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tId = pArgs.%Get("Name")
    Quit $ClassMethod(..#MINT, "Mint", ..#LIST, $Parameter(pTool, "TOOLNAME"), $Username, "", tTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), tId, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p>The key of the proposal <method>Mint</method> answers, or <code>""</code>.</p>
Method MintedKey(pTool As %String, pArgs As %DynamicObject) As %String
{
    Set tSC = ..Mint(pTool, pArgs, .tProposal, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tProposal)) Quit ""
    Quit tProposal.%Get("proposalId")
}

/// <p>Confirm <var>pKey</var> through the shipped transition over the fixture port.</p>
Method Confirm(pKey As %String, Output pHttp As %Integer, Output pCode As %String) As %Status
{
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, "", $Username, .tResult, .pHttp, .pCode, .tDetail)
}

/// <p>Proposal <var>pKey</var>'s stored destructive flag and consequence.</p>
ClassMethod Stored(pKey As %String, Output pDestructive As %Boolean, Output pConsequence As %String)
{
    Set pDestructive = ""
    Set pConsequence = "<absent>"
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pKey, .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit
    Set pDestructive = +$Get(tValues("destructive"))
    Set pConsequence = $Get(tValues("consequence"))
}

/// <p>The problem a refusal's fault carries, or <code>""</code>.</p>
ClassMethod Problem(ByRef pFault) As %String
{
    If '$IsObject($Get(pFault)) Quit ""
    If pFault.%GetTypeOf("detail") '= "object" Quit pFault.%Get("reason")
    Quit pFault.%Get("detail").%Get("problem")
}

/// <p><var>pList</var> sorted and comma-separated.</p>
ClassMethod Sorted(pList As %List) As %String
{
    Kill tNames
    For tI = 1:1:$ListLength(pList) Set tNames($List(pList, tI)) = ""
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tNames(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

}
