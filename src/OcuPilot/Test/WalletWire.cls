/// <p>The wallet secret routes and tools against the instance itself, through the real port (AD-4,
/// AD-8, AD-12, AD-27, AD-35, AD-39, AD-54, AD-55): the routes' envelopes, a create over the route
/// that the list's own read then shows and an edit that keeps the stored value, the vendor's upsert
/// that would re-create a deleted secret and the two callers that refuse first (AC4), every wallet
/// route refused to a real principal without the wallet resource (AC5), and no value in the
/// instance's message log after a refused save (AC2).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// the wallet screens' own pairs, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because the legs create and delete a user, a role, a second probe collection and secrets.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not; every probe is removed by exact
/// name.</p>
Class OcuPilot.Test.WalletWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FORMPATH = "/wallet/secret/form";

Parameter NAMEPATH = "/wallet/secret/name";

Parameter CREATEPATH = "/wallet/secret";

/// <p>The edit route; <method>EditPath</method> fills its one segment.</p>
Parameter EDITPATH = "/wallet/secret/:id";

Parameter LIST = "OcuPilot.Screen.Descriptor.WalletSecretList";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.WalletSecretCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.WalletSecretUpdate";

Parameter PROBE = "OcuPilot.Test.WalletProbe";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The secrets this class stores in the probe collection, by the part after it.</p>
Parameter PARTS = "WireRoute,WireGone,WireSym";

/// <p>A second collection the refused-save leg deletes between its mint and its confirm.</p>
Parameter GONECOLLECTION = "OcuPilotProbe86Gone";

/// <p>The purpose-built principal that holds everything the wallet screens need but the wallet
/// resource.</p>
Parameter NOWALLETUSER = "OcuPilotWireNoWallet";

Parameter NOWALLETROLE = "OcuPilotWireNoWalletRole";

/// <p>Where the instance's message log was when this class began, which the log scan reads
/// from.</p>
Property StartedAt As %Integer [ InitialExpression = 0 ];

/// <p>The throwaway principal's password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The values the legs stored or sent, which the log scan looks for.</p>
Property SentValues As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..SentValues = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WalletWire creates and deletes a user, a role, wallet collections and wallet secrets on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..StartedAt = ##class(%File).GetFileSize(..LogPath())
    Set tSC = $ClassMethod(..#PROBE, "EnsureCollection", .tCreated)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = "OcuPilotWal" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ..EnsurePrincipal()
}

/// <p>Remove the probe collections, their secrets, the principal and its role; a failing status when
/// any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove", .tRemaining)
    If $$$ISOK(tSC) && (tRemaining > 0) Set tSC = $$$ERROR($$$GeneralError, tRemaining _ " probe secret(s) survived OcuPilot.Test.WalletWire")
    Set tSC = $$$ADDSC(tSC, ..RemoveGoneCollection())
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#NOWALLETUSER) Do ##class(Security.Users).Delete(..#NOWALLETUSER)
        If ##class(Security.Roles).Exists(..#NOWALLETROLE) Do ##class(Security.Roles).Delete(..#NOWALLETROLE)
        If ##class(Security.Users).Exists(..#NOWALLETUSER) || ##class(Security.Roles).Exists(..#NOWALLETROLE) {
            Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.WalletWire left its throwaway principal on the instance"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    For tI = 1:1:$Length(..#PARTS, ",") Do $ClassMethod(..#PROBE, "RemoveSecret", ..Name($Piece(..#PARTS, ",", tI)))
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>AD-12, AD-39: the form read, with a collection and without, the name look-up, the create and
/// the edit each answer exactly one JSON envelope over a real HTTP request; a create naming nothing
/// is refused on its own envelope code, and an edit or a form read of a name the instance does not
/// hold is 404 with its own, as is a form read of a collection it does not hold; a form read of a
/// symmetric key answers its name and type alone, not editable.</p>
/// <p>Mutation (Rule 19): answer <code>editable</code> true whatever the type in
/// <method>OcuPilot.Area.Security.WalletRules.HandleForm</method> -> the symmetric-key leg goes red.</p>
Method TestEachRouteAnswersOneJsonEnvelopeOverTheWire()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tPath = tBase _ ..#FORMPATH, tBase _ ..#FORMPATH _ "?collection=" _ ..Collection(), tBase _ ..#NAMEPATH _ "?name=" _ ..Name("WireRoute") {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, tUser, tPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tPath _ ": at 200")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tPath _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tPath _ ": exactly one envelope")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH, .tStatus, .tBody)
    If $IsObject($Get(tBody)) Do $$$AssertEquals(tBody.%Get("rules").%Size(), $ListLength(##class(OcuPilot.Api.Error).WalletViolationCodes()), "the form read carries one rule per wallet code")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?name=" _ ..Name("WireRoute"), .tStatus, .tBody)
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%Get("taken"), 1: ""), 0, "the look-up answers a free name as not taken")
    Set tSym = ..Name("WireSym")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddSymmetricKey", tSym), "a symmetric key is stored")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?name=" _ tSym, .tStatus, .tBody)
    Set tSecret = $Select($IsObject($Get(tBody)): tBody.%Get("secret"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tSecret): tSecret.%ToJSON(), 1: ""), "{""Name"":""" _ tSym _ """,""Collection"":""" _ ..Collection() _ """,""Type"":""%Wallet.SymmetricKey"",""editable"":false}", "the form read of a symmetric key answers its name and type alone, not editable")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, tPassword, .tStatus, .tBody, .tHeaders, "{}", "application/json")
    Do $$$AssertEquals(tStatus, 422, "a create naming nothing is refused at 422")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).code, ##class(OcuPilot.Api.Error).#WALLETVALIDATION, "with the create's own envelope code")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..EditPath(..Name("WireRoute")), tUser, tPassword, .tStatus, .tBody, .tHeaders, "{""Usage"":1}", "application/json")
    Do $$$AssertEquals(tStatus, 404, "an edit of a name the instance does not hold is 404")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).code, ##class(OcuPilot.Api.Error).#WALLETNAMEABSENT, "with the absent code")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?name=" _ ..Name("WireRoute"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 404, "and so is the form read of one")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?collection=OcuPilotProbe86Missing", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""), "404 " _ ##class(OcuPilot.Api.Error).#WALLETCOLLECTIONABSENT, "a form read of a collection the instance does not hold is 404 on its own code")
}

/// <p>AC1, AC7 over the wire: <code>POST /wallet/secret</code> stores a secret; the name look-up
/// answers it taken, with its sentence, and a case variant of it free; the list's own read then shows
/// it; the form read answers its settings, editable, and no value; <code>PUT</code> with
/// one setting changes it and keeps the value; and a second create of the name is refused as
/// taken.</p>
Method TestACreateShowsOnTheListAndAnEditKeepsTheValue()
{
    Set tValue = ..Value()
    Set tName = ..Name("WireRoute")
    Set tRequest = {"Name": (tName), "Secret": (tValue), "Usage": 3, "RequireTLS": true, "AllowedHosts": ["h.example"]}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the create answers 201")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: ""), "{""name"":""" _ tName _ """}", "naming the secret and nothing else")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?name=" _ tName, .tStatus, .tBody)
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%Get("taken") _ "|" _ tBody.%Get("reason"), 1: ""), "1|" _ ##class(OcuPilot.Api.Error).#REASONWALLETNAMETAKEN, "the look-up answers the stored name as taken, with the published sentence")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?name=" _ ..Name("wireroute"), .tStatus, .tBody)
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%Get("taken"), 1: ""), 0, "and a name differing from it only in case as free")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/screens/security.secrets/read?maxRows=1000&collection=" _ ..Collection(), .tStatus, .tBody)
    Set tRow = ""
    If $IsObject($Get(tBody)) && (tBody.%GetTypeOf("rows") = "array") {
        Set tIterator = tBody.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If $IsObject(tEntry) && (tEntry.%Get("Name") = tName) Set tRow = tEntry
        }
    }
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%ToJSON(), 1: ""), "{""Name"":""" _ tName _ """,""Type"":""%Wallet.KeyValue""}", "the list's own read shows the new secret")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..EditPath(tName), .tStatus, .tBody, "{""RequireTLS"":false}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the edit answers 200")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?name=" _ tName, .tStatus, .tBody)
    Set tSecret = $Select($IsObject($Get(tBody)): tBody.%Get("secret"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tSecret): tSecret.%ToJSON(), 1: ""), "{""Name"":""" _ tName _ """,""Collection"":""" _ ..Collection() _ """,""Type"":""%Wallet.KeyValue"",""Usage"":3,""RequireTLS"":false,""AllowedHosts"":[""h.example""],""editable"":true}", "the form read answers the changed setting, the kept ones, and no value")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredValue", tName), tValue, "and the instance kept the value")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "a second create of the name is refused")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: "") [ ##class(OcuPilot.Api.Error).#WALLETNAMETAKEN, 1, "as taken")
    Set ..SentValues = ..SentValues _ $ListBuild(tValue)
}

/// <p>AC4: the vendor's <code>PUT</code> is an upsert -- sent with a value for a name deleted a moment
/// earlier, the raw port answers 201 and the secret is back. Both callers refuse first: the screen's
/// edit of the deleted name answers 404 over the wire and the agent's confirm 409, and neither
/// re-creates it.</p>
Method TestTheUpsertWouldRecreateADeletedSecretAndBothCallersRefuse()
{
    Set tName = ..Name("WireGone")
    Set tValue = ..Value()
    Set ..SentValues = ..SentValues _ $ListBuild(tValue)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddKeyValue", tName, {"Secret": "v1"}), "a secret is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveSecret", tName), "and deleted")
    Kill tQuery
    Set tQuery("name") = tName
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Wallet.Secret", "PUT", .tQuery, {"Type": "%Wallet.KeyValue", "Secret": (tValue)}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 201, "the raw port's PUT with a value answers 201")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 1, "and re-creates the deleted secret")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveSecret", tName), "which is deleted again")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..EditPath(tName), .tStatus, .tBody, {"Usage": 1, "Secret": (tValue)}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 404, "the screen's edit of the deleted name is refused at 404")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and does not re-create it")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddKeyValue", tName, {"Secret": "v2"}), "the secret is stored once more")
    Set tSC = ..Mint(..#UPDATETOOL, tName, {"Name": (tName), "Usage": 2}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's edit is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveSecret", tName), "and the secret deleted after the mint")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), {"Secret": (tValue)}, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and nothing is re-created")
}

/// <p>AC5 with a real principal: a caller holding the install namespace's code, the system database
/// read and the secure resource but not <code>%Admin_Wallet</code> is refused on every wallet route
/// with the screen-privilege code naming <code>%Admin_Wallet:USE</code>, before anything is read or
/// written, and the navigation map lists the form denied on the same pair.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Wallet</code> from
/// <class>OcuPilot.Screen.Descriptor.WalletSecretForm</class>'s privileges -> the routes pass the gate
/// and this goes red.</p>
Method TestACallerWithoutTheWalletResourceIsRefusedOnEveryRoute()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tRoutes = $ListBuild($ListBuild("GET", ..#FORMPATH), $ListBuild("GET", ..#FORMPATH _ "?collection=" _ ..Collection()), $ListBuild("GET", ..#NAMEPATH _ "?name=" _ ..Name("WireRoute")), $ListBuild("POST", ..#CREATEPATH), $ListBuild("PUT", ..EditPath(..Name("WireRoute"))))
    For tI = 1:1:$ListLength(tRoutes) {
        Set tMethod = $List($List(tRoutes, tI), 1)
        Set tPath = tBase _ $List($List(tRoutes, tI), 2)
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(tMethod, tPath, ..#NOWALLETUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders, $Select(tMethod = "GET": "", 1: "{""Name"":""" _ ..Name("WireRoute") _ """,""Secret"":""x""}"), $Select(tMethod = "GET": "", 1: "application/json"))
        Do $$$AssertEquals(tStatus, 403, tMethod _ " " _ tPath _ ": is refused")
        Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", tMethod _ " " _ tPath _ ": on the screen-privilege code")
        Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), "%Admin_Wallet:USE", tMethod _ " " _ tPath _ ": naming %Admin_Wallet:USE")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", ..Name("WireRoute")), 0, "and nothing was created")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/navigation", ..#NOWALLETUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the navigation map answers the principal")
    Do $$$AssertTrue(tBody [ "{""route"":""security/wallet/secrets/edit"",""labelKey"":""walletSecretFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""}", "and lists the form denied on the wallet pair")
}

/// <p>AC2 through the real port: an agent create whose collection was deleted between the mint and
/// the confirm is refused by the vendor at 422, and the confirm's answer carries no value. The port
/// logs the refusal, which <method>TestZNothingReachedTheMessageLog</method> then finds and
/// scans.</p>
Method TestARefusedAgentSaveAnswersNoValue()
{
    Set tValue = ..Value()
    Set ..SentValues = ..SentValues _ $ListBuild(tValue)
    Set tName = ..#GONECOLLECTION _ ".WireRefused"
    Do $$$AssertStatusOK(..CreateGoneCollection(), "a second collection is created")
    Set tSC = ..Mint(..#CREATETOOL, tName, {"Name": (tName), "Usage": 1}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's create in it is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK(..RemoveGoneCollection(), "and the collection deleted after the mint")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), {"Secret": (tValue)}, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp, 422, "at the vendor's 422 for an absent collection")
    Set tAnswer = $Get(tCode) _ $Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "") _ $Select($IsObject($Get(tDetail)): tDetail.%ToJSON(), 1: "") _ $System.Status.GetErrorText(tSC)
    Do $$$AssertEquals(tAnswer [ tValue, 0, "and its answer carries no value")
}

/// <p>AC2, AD-35: nothing this class did wrote a value into the instance's message log. Named to run
/// last, so the log it scans covers every other leg; it first requires the refusal
/// <method>TestARefusedAgentSaveAnswersNoValue</method> logged, so a scan that read nothing, or the
/// wrong part of the file, cannot pass.</p>
/// <p>Mutation (Rule 19): add the sent body's JSON to the vendor status
/// <method>OcuPilot.Port.AdminPort.Invoke</method> hands <method>OcuPilot.Port.AdminPort.Fail</method>
/// -> the refusal's log line carries the value and the scan goes red.</p>
Method TestZNothingReachedTheMessageLog()
{
    Set tLog = ..LogSince(..StartedAt)
    Do $$$AssertTrue(tLog [ "Wallet.Secret failed with HTTP 422", "the log read covers this class's run: it holds the refused create's line")
    For tI = 1:1:$ListLength(..SentValues) {
        Do $$$AssertEquals(tLog [ $List(..SentValues, tI), 0, "the message log carries no value this class sent (" _ tI _ ")")
    }
    Do $$$AssertTrue($ListLength(..SentValues) >= 3, "and the scan looked for every value the legs sent")
}

/// <p>The probe collection.</p>
ClassMethod Collection() As %String
{
    Quit $Parameter(..#PROBE, "COLLECTION")
}

/// <p>The probe collection's full name for the secret <var>pPart</var>.</p>
ClassMethod Name(pPart As %String) As %String
{
    Quit ..Collection() _ "." _ pPart
}

/// <p>A value no other test uses, generated at run time.</p>
ClassMethod Value() As %String
{
    Quit "OcuPilotProbe86Wire" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(12), 1), "+/=", "")
}

/// <p><parameter>EDITPATH</parameter> for <var>pName</var>, its segment encoded by the one shared
/// encoder (AD-13).</p>
ClassMethod EditPath(pName As %String) As %String
{
    Quit $Replace(..#EDITPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pName))
}

/// <p>Mint one write of tool <var>pTool</var> against <var>pName</var> through the shipped mint and
/// the tool's own port.</p>
Method Mint(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pProposal = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#LIST, $Parameter(pTool, "TOOLNAME"), $Username, "", tTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pName, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p>Create <parameter>GONECOLLECTION</parameter> when it is absent.</p>
ClassMethod CreateGoneCollection() As %Status
{
    Set tSC = $$$OK
    Set tResource = $Parameter(..#PROBE, "RESOURCE")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(%Wallet.Collection).Exists(..#GONECOLLECTION) Set tSC = ##class(%Wallet.Collection).Create(..#GONECOLLECTION, {"Resource": (tResource)})
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete <parameter>GONECOLLECTION</parameter> when it is present; an error when it survives.</p>
ClassMethod RemoveGoneCollection() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(%Wallet.Collection).Exists(..#GONECOLLECTION) Set tSC = ##class(%Wallet.Collection).Delete(..#GONECOLLECTION)
        If ##class(%Wallet.Collection).Exists(..#GONECOLLECTION) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the collection " _ ..#GONECOLLECTION _ " is still present after its removal"))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the throwaway role -- the install namespace's code read, the system database read and
/// the secure resource, and no wallet resource -- and the account that holds it, then read the grant
/// back.</p>
Method EnsurePrincipal() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tSysDb = ##class(SYS.Database).%OpenId(tDatabase.Directory)
        Set tResources = tSysDb.ResourceName _ ":R,%DB_IRISSYS:R,%Admin_Secure:U"
        If ##class(Security.Roles).Exists(..#NOWALLETROLE) Do ##class(Security.Roles).Delete(..#NOWALLETROLE)
        Set tSC = ##class(Security.Roles).Create(..#NOWALLETROLE, "OcuPilot test: no wallet resource (throwaway)", tResources, "")
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#NOWALLETUSER) Do ##class(Security.Users).Delete(..#NOWALLETUSER)
        Set tSC = ##class(Security.Users).Create(..#NOWALLETUSER, ..#NOWALLETROLE, ..PreparedPassword, "OcuPilot wallet test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.WalletWire; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#NOWALLETUSER, "%Admin_Wallet", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#NOWALLETUSER, "%DB_IRISSYS", "READ") '= 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal's grants did not read back as the system read without the wallet resource")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The instance's message log.</p>
ClassMethod LogPath() As %String
{
    Quit ##class(%File).NormalizeFilename("messages.log", $System.Util.ManagerDirectory())
}

/// <p>What the message log gained after byte <var>pOffset</var>, at most 4 MB of it.</p>
ClassMethod LogSince(pOffset As %Integer) As %String
{
    Set tText = ""
    Try {
        Set tStream = ##class(%Stream.FileBinary).%New()
        Set tSC = tStream.LinkToFile(..LogPath())
        If $$$ISERR(tSC) Quit
        If pOffset > 0 Do tStream.MoveTo(pOffset + 1)
        While 'tStream.AtEnd && ($Length(tText) < 4000000) {
            Set tText = tText _ tStream.Read(32000)
        }
    } Catch {
        Set tText = ""
    }
    Quit tText
}

}
