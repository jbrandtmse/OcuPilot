/// <p>Pins Story 8.6's wallet secret create (AD-3, AD-6, AD-35, AD-39, AD-54, AD-55): what
/// <class>OcuPilot.Screen.Tool.WalletSecretCreate</class> advertises, the one rule set both callers
/// apply, the one body the screen and the confirm send, the card's required value row, the absence of
/// the value from the stored proposal, the ledger, the answers and every read, and a name taken before
/// the mint or since it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and an account
/// holding <code>%Admin_Wallet</code>. Every write reaches the instance through
/// <class>OcuPilot.Test.WalletRecordPort</class>, into the probe collection of
/// <class>OcuPilot.Test.WalletProbe</class>, whose secrets are removed by exact name.</p>
Class OcuPilot.Test.WalletSecretCreate Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.WalletSecretCreate";

Parameter LIST = "OcuPilot.Screen.Descriptor.WalletSecretList";

Parameter FORM = "OcuPilot.Screen.Descriptor.WalletSecretForm";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter RULES = "OcuPilot.Area.Security.WalletRules";

/// <p>The shipped screen route, mint and confirm, with the port recording what is sent.</p>
Parameter SCREEN = "OcuPilot.Test.WalletSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.WalletConfirm";

Parameter RECORD = "OcuPilot.Test.WalletRecordPort";

Parameter PROBE = "OcuPilot.Test.WalletProbe";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The secrets this class stores, by the part after the probe collection.</p>
Parameter PARTS = "CreateScreen,CreateAgent,CreateTaken,createtaken,CreateSince,CreateLeak";

Method OnBeforeAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "EnsureCollection", .tCreated)
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove", .tRemaining)
    If $$$ISOK(tSC) && (tRemaining > 0) Set tSC = $$$ERROR($$$GeneralError, tRemaining _ " probe secret(s) survived OcuPilot.Test.WalletSecretCreate")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    For tI = 1:1:$Length(..#PARTS, ",") Do $ClassMethod(..#PROBE, "RemoveSecret", ..Name($Piece(..#PARTS, ",", tI)))
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>AD-3, AD-6: the schema carries the name, the two derived settings and the tool's own hosts
/// array, and no value, no <code>Secret64</code> and no <code>Type</code>; the settable set is the
/// prohibited set's reviewed create list; the create is the vendor's <code>PUT</code> through the
/// wallet port, guarded as a create; and <code>Type</code> is the tool's derived field.</p>
Method TestTheSchemaAdvertisesNoValue()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals(..Keys(tSchema.%Get("properties")), "AllowedHosts,Name,RequireTLS,Usage,expectedImpact,rationale,reverse", "the schema is the name, the three settings and the agent's own words")
    Do $$$AssertEquals(tSchema.%Get("properties").%Get("AllowedHosts").%Get("items").%Get("type"), "string", "the hosts are an array of strings")
    Do $$$AssertEquals(tSchema.%Get("properties").%Get("Usage").%Get("type") _ " " _ tSchema.%Get("properties").%Get("RequireTLS").%Get("type"), "number boolean", "the uses are a number and the TLS flag a boolean, as derived")
    Do $$$AssertEquals(..Sorted($ClassMethod(..#TOOL, "SettableFields")), ..Sorted($ClassMethod(..#SET, "PermittedCreateFields", "wallet-secret")), "the settable set is the prohibited set's reviewed create list")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ReadType") _ " " _ $ClassMethod(..#TOOL, "WriteType") _ " " _ $ClassMethod(..#TOOL, "PortClass"), "GET PUT OcuPilot.Port.WalletPort", "read and written through the wallet port")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Creates") _ " " _ $ClassMethod(..#TOOL, "ChangeAction"), "1 created", "guarded as a create and publishing created (AD-54)")
    Do $$$AssertEquals($ListToString($ClassMethod(..#LIST, "SecretArguments")), "Secret", "the list declares the value secret")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "ComposedSecrets")), "Secret", "and the create composes it")
    Set tPayload = {}
    Do $ClassMethod(..#TOOL, "DerivedFields", tPayload)
    Do $$$AssertEquals(tPayload.%ToJSON(), "{""Type"":""%Wallet.KeyValue""}", "Type is derived, always the key-value type")
}

/// <p>The field-rules row of the matrix on both callers: each rule refuses the screen's Save with its
/// own code and sends nothing, and the agent's mint refuses the same arguments at 400.</p>
Method TestEveryFieldRuleRefuses()
{
    Set tCollection = $Parameter(..#PROBE, "COLLECTION")
    Set tFree = ..Name("CreateScreen")
    Set tLong = $Translate($Justify("", 32769), " ", "v")
    Set tHost = $Translate($Justify("", 256), " ", "h")
    Set tCases = []
    Do tCases.%Push({"name": "", "args": {}, "field": "Name", "code": "WALLET.NAME.REQUIRED"})
    Do tCases.%Push({"name": "NoDotAtAll", "args": {}, "field": "Name", "code": "WALLET.NAME.SHAPE"})
    Do tCases.%Push({"name": (tCollection _ ".has space"), "args": {}, "field": "Name", "code": "WALLET.NAME.SHAPE"})
    Do tCases.%Push({"name": (tCollection _ "." _ $Translate($Justify("", 128), " ", "x")), "args": {}, "field": "Name", "code": "WALLET.NAME.LENGTH"})
    Do tCases.%Push({"name": "OcuPilotProbe86Missing.Any", "args": {}, "field": "Name", "code": "WALLET.COLLECTION.ABSENT"})
    Do tCases.%Push({"name": (tFree), "args": {"Secret": ""}, "field": "Secret", "code": "WALLET.SECRET.REQUIRED"})
    Do tCases.%Push({"name": (tFree), "args": {"Secret": (tLong)}, "field": "Secret", "code": "WALLET.SECRET.LENGTH"})
    Do tCases.%Push({"name": (tFree), "args": {"Usage": 16}, "field": "Usage", "code": "WALLET.USAGE.RANGE"})
    Do tCases.%Push({"name": (tFree), "args": {"Usage": 1.5}, "field": "Usage", "code": "WALLET.USAGE.RANGE"})
    Do tCases.%Push({"name": (tFree), "args": {"Usage": "5"}, "field": "Usage", "code": "WALLET.USAGE.RANGE"})
    Do tCases.%Push({"name": (tFree), "args": {"AllowedHosts": ["a b"]}, "field": "AllowedHosts", "code": "WALLET.ALLOWEDHOSTS.SHAPE"})
    Do tCases.%Push({"name": (tFree), "args": {"AllowedHosts": [""]}, "field": "AllowedHosts", "code": "WALLET.ALLOWEDHOSTS.SHAPE"})
    Do tCases.%Push({"name": (tFree), "args": {"AllowedHosts": ["a,b"]}, "field": "AllowedHosts", "code": "WALLET.ALLOWEDHOSTS.SHAPE"})
    Do tCases.%Push({"name": (tFree), "args": {"AllowedHosts": [(tHost)]}, "field": "AllowedHosts", "code": "WALLET.ALLOWEDHOSTS.SHAPE"})
    Do tCases.%Push({"name": (tFree), "args": {"AllowedHosts": [("h" _ $Char(10, 10) _ "i")]}, "field": "AllowedHosts", "code": "WALLET.ALLOWEDHOSTS.SHAPE"})
    Do tCases.%Push({"name": (tFree), "args": {"AllowedHosts": "h"}, "field": "AllowedHosts", "code": "WALLET.ALLOWEDHOSTS.SHAPE"})
    Do tCases.%Push({"name": (tFree), "args": {"RequireTLS": "yes"}, "field": "RequireTLS", "code": "PORT.FIELD.SHAPE"})
    Set tCaseIterator = tCases.%GetIterator()
    While tCaseIterator.%GetNext(.tI, .tCase) {
        Set tArgs = ..Args("value-" _ tI)
        Set tOverride = tCase.%Get("args")
        Set tIterator = tOverride.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tType = tOverride.%GetTypeOf(tKey)
            If (tType = "object") || (tType = "array") {
                Do tArgs.%Set(tKey, tValue)
            } Else {
                Do tArgs.%Set(tKey, tValue, tType)
            }
        }
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Create", tCase.%Get("name"), tArgs, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(..CodeFor(.tViolations, tCase.%Get("field")), tCase.%Get("code"), "case " _ tI _ ": the screen refuses " _ tCase.%Get("field") _ " with " _ tCase.%Get("code"))
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "case " _ tI _ ": and nothing is sent")
    }
    Set tAgent = []
    Do tAgent.%Push({"name": "NoDotAtAll", "args": {}})
    Do tAgent.%Push({"name": "OcuPilotProbe86Missing.Any", "args": {}})
    Do tAgent.%Push({"name": (..Name("CreateAgent")), "args": {"Usage": 16}})
    Do tAgent.%Push({"name": (..Name("CreateAgent")), "args": {"AllowedHosts": ["a b"]}})
    Set tCaseIterator = tAgent.%GetIterator()
    While tCaseIterator.%GetNext(.tI, .tCase) {
        Set tSC = ..Mint(tCase.%Get("name"), tCase.%Get("args"), .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, "the agent's mint refuses " _ tCase.%ToJSON() _ " at 400")
    }
}

/// <p>AD-55: the screen's Save and the agent's confirmed create send the same flat body --
/// <code>Type</code>, the three settings and the value -- at the tool's own <code>PUT</code>, naming
/// the secret only in the query parameter, and the instance holds the two secrets alike.</p>
Method TestTheScreenAndTheConfirmSendOneBody()
{
    Set tValue = ..Value()
    Set tArgs = ..Args(tValue)
    Set tSC = $ClassMethod(..#SCREEN, "Create", ..Name("CreateScreen"), tArgs, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen stores the secret")
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastName"), "PUT " _ ..Name("CreateScreen"), "at the tool's own PUT, naming the secret in the query")
    Set tScreenBody = $ClassMethod(..#RECORD, "LastWriteBody")

    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = ..Mint(..Name("CreateAgent"), ..Settings(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent mints the same create")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), {"Secret": (tValue)}, .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and its confirm stores it: " _ $Get(tCode))
    Set tAgentBody = $ClassMethod(..#RECORD, "LastWriteBody")

    Do $$$AssertNotEquals(tScreenBody, "", "a body reached the port from the screen")
    Set tScreen = ##class(%DynamicAbstractObject).%FromJSON(tScreenBody)
    Set tAgent = ##class(%DynamicAbstractObject).%FromJSON(tAgentBody)
    Do $$$AssertEquals(..Keys(tScreen), "AllowedHosts,RequireTLS,Secret,Type,Usage", "the screen sends the type, the three settings and the value")
    Do $$$AssertEquals(..Keys(tAgent), ..Keys(tScreen), "the confirm sends the same keys")
    For tField = "Type", "Usage", "RequireTLS", "AllowedHosts", "Secret" {
        Do $$$AssertEquals(tAgent.%Get(tField, "", "json"), tScreen.%Get(tField, "", "json"), tField _ " is the same on both")
    }
    Do $$$AssertEquals(..Read(..Name("CreateAgent")), ..Read(..Name("CreateScreen")), "the instance holds the two secrets alike")
    Do $$$AssertEquals(..Read(..Name("CreateScreen")), "{""Type"":""%Wallet.KeyValue"",""Usage"":5,""RequireTLS"":true,""AllowedHosts"":[""h.example""]}", "as the settings sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredValue", ..Name("CreateAgent")), tValue, "with the value the card supplied")
}

/// <p>AC1, AD-6: the create's card shows one row per supplied setting and one masked value row, both
/// sides empty, which is required.</p>
Method TestTheCardRequiresTheValue()
{
    Set tSC = ..Mint(..Name("CreateAgent"), ..Settings(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is minted")
    If $$$ISERR(tSC) Quit
    Kill tRows
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tRows(tRow.%Get("field")) = tRow.%Get("before") _ "|" _ tRow.%Get("after") _ "|" _ tRow.%GetTypeOf("optional")
    }
    Do $$$AssertEquals($Get(tRows("Secret")), "||unassigned", "the value's row is empty and required")
    Do $$$AssertEquals($Get(tRows("Usage")), "|5|unassigned", "beside a row for the uses")
    Do $$$AssertEquals($Data(tRows("RequireTLS")) + $Data(tRows("AllowedHosts")), 2, "and for the other two settings")
}

/// <p>AC2, AD-35: the model cannot send the value, and after a create confirmed with one, the value
/// is in no stored argument, payload or diff, no minted or confirm answer, no ledger row -- whose
/// fields name the type and the three settings -- and no read: the port's own, the form's, the
/// list's and its read tool's.</p>
Method TestNoValueReachesTheProposalTheLedgerOrAnyRead()
{
    Set tValue = ..Value()
    Set tArgs = ..Settings()
    Do tArgs.%Set("Secret", tValue, "string")
    Set tSC = ..Mint(..Name("CreateLeak"), tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "a value among the model's arguments is refused at the mint")
    If $IsObject($Get(tProposal)) {
        Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
        Do $$$AssertEquals(($Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))) [ tValue, 0, "and a proposal minted from them anyway stores no value")
    }

    Set tSC = ..Mint(..Name("CreateLeak"), ..Settings(), .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the create is minted")
    If $$$ISERR(tSC) Quit
    Set tKey = tProposal.%Get("proposalId")
    Set tSC = ..Confirm(tKey, {"Secret": (tValue)}, .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and confirmed with its value")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredValue", ..Name("CreateLeak")), tValue, "which the instance holds")

    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tValues)
    Do $$$AssertTrue($Get(tFound), "the stored proposal is read back")
    Do $$$AssertEquals(($Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))) [ tValue, 0, "the stored proposal carries no value")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "") [ tValue, 0, "nor the confirm's answer")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row")
    Set tLedger = ""
    Set tName = ""
    For {
        Set tName = $Order(tRow(tName))
        If tName = "" Quit
        Set tLedger = tLedger _ tRow(tName) _ "|"
    }
    Do $$$AssertEquals(tLedger [ tValue, 0, "nor the ledger row")
    Do $$$AssertEquals(..Sorted($ListFromString($Get(tRow("Fields")))), "AllowedHosts,RequireTLS,Type,Usage", "whose fields name the type and the three settings")

    Set tReads = ..Read(..Name("CreateLeak"))
    Set tSC = $ClassMethod(..#RULES, "Present", ..Name("CreateLeak"), .tFresh, .tHttp, .tFault)
    Set tReads = tReads _ $Select($IsObject($Get(tFresh)): tFresh.%ToJSON(), 1: "")
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#LIST, {"collection": ($Parameter(..#PROBE, "COLLECTION"))}, 1000, .tView)
    Do $$$AssertStatusOK(tSC, "the list's read tool answers")
    Set tReads = tReads _ $Select($IsObject($Get(tView)): tView.%ToJSON(), 1: "")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/screens/security.secrets/read?maxRows=1000&collection=" _ $Parameter(..#PROBE, "COLLECTION"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the list's own read answers")
    Set tReads = tReads _ $Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: "")
    Do $$$AssertTrue(tReads [ ..Name("CreateLeak"), "the reads name the secret")
    Do $$$AssertEquals(tReads [ tValue, 0, "and none carries its value")
}

/// <p>AD-54, the Name taken row: a name the collection already holds, compared exactly, refuses the
/// screen's Save and the agent's mint, while a name differing only in case is free; and a name
/// stored between the mint and the confirm refuses the confirm at 409, with nothing sent and the
/// stored value untouched.</p>
Method TestATakenNameRefusesBothCallersAndAConfirmTakenSince()
{
    Set tTaken = ..Name("CreateTaken")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddKeyValue", tTaken, {"Secret": "original"}), "a secret holds the name")
    Set tSC = $ClassMethod(..#SCREEN, "Create", tTaken, ..Args(..Value()), .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(..CodeFor(.tViolations, "Name"), "WALLET.NAME.TAKEN", "the screen refuses the taken name")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends nothing")
    Set tSC = ..Mint(tTaken, ..Settings(), .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "the agent's mint refuses it too")
    Set tSC = $ClassMethod(..#SCREEN, "Create", ..Name("createtaken"), ..Args(..Value()), .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "a name differing only in case is stored")
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredValue", tTaken), "original", "and the first secret is untouched")

    Do $ClassMethod(..#RECORD, "Clear")
    Set tSince = ..Name("CreateSince")
    Set tSC = ..Mint(tSince, ..Settings(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a free name is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddKeyValue", tSince, {"Secret": "original"}), "and then taken")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), {"Secret": (..Value())}, .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredValue", tSince), "original", "and the stored value is untouched")
}

/// <p>AD-10: a screen create carrying a field nobody reviewed -- the vendor's <code>Secret64</code>
/// or a <code>Type</code> -- is refused by the prohibited set at 403, and nothing is sent.</p>
/// <p>Mutation (Rule 19): answer the <code>wallet-secret</code> branch of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> without asking
/// <code>ReviewedFewOnly</code> -> the create is sent and this goes red.</p>
Method TestAnUnreviewedFieldIsRefusedOnTheScreen()
{
    For tField = "Secret64", "Type" {
        Set tArgs = ..Args(..Value())
        Do tArgs.%Set(tField, $Select(tField = "Type": "%Wallet.RSA", 1: "eA=="), "string")
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Create", ..Name("CreateScreen"), tArgs, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "403 " _ $Parameter(..#SET, "UNCOVEREDFIELD"), tField _ ": the screen refuses it as an unreviewed field")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, tField _ ": and nothing is sent")
    }
}

/// <p>AD-5, AD-8, AD-39: the form is built, unlisted, at the list's route with the editor suffix,
/// over the list's own pairs, with its value secret-typed in context and no classic page; every
/// <code>WALLET.*</code> code carries a sentence and the form read publishes exactly those; the list
/// declares Create and invites the agent.</p>
Method TestTheFormDescriptorIsBuiltUnlistedAndCarriesTheListsOwnPairs()
{
    Set tForm = ..#FORM
    Do $$$AssertEquals($ClassMethod(tForm, "Route"), $ClassMethod(..#LIST, "Route") _ "/edit", "the form's route is the list's own with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(tForm, "IsBuilt") _ " " _ (+$ClassMethod(tForm, "SideBarPosition")), "1 0", "it is built and unlisted")
    Do $$$AssertEquals($ClassMethod(tForm, "Archetype") _ " " _ $ClassMethod(tForm, "PrimaryEntityType"), "form-page wallet-secret", "a form page over the wallet secret type")
    Do $$$AssertEquals($ClassMethod(tForm, "ToolIdentifier"), "security.secretform", "with its own tool identifier")
    Do $$$AssertEquals($IsObject($ClassMethod(tForm, "Read")), 0, "and no declared read")
    Do $$$AssertEquals($ListToString($ClassMethod(tForm, "PrivilegePairs")), $ListToString($ClassMethod(..#LIST, "PrivilegePairs")), "the form requires exactly what the list requires")
    Do $$$AssertTrue($ListFind($ClassMethod(tForm, "PrivilegePairs"), $ListBuild("%Admin_Wallet", "USE")), "the wallet resource among it")
    Set tSC = $ClassMethod(tForm, "DeclarationJson", .tFormDeclaration)
    Do $$$AssertStatusOK(tSC, "the form's declaration reads")
    If $IsObject($Get(tFormDeclaration)) {
        Do $$$AssertEquals(tFormDeclaration.%Get("context").%Get("secretFields").%ToJSON(), "[""Secret""]", "its context never carries a value being typed")
        Do $$$AssertEquals(tFormDeclaration.%Get("classicPage"), "", "and it names no classic page")
    }
    Set tCodes = ##class(OcuPilot.Api.Error).WalletViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a sentence")
    }
    Do $$$AssertEquals($ClassMethod(..#RULES, "Rules").%Size(), $ListLength(tCodes), "the form read publishes one rule per code")
    Set tSC = $ClassMethod(..#LIST, "DeclarationJson", .tDeclaration)
    Do $$$AssertEquals(tDeclaration.%Get("primaryAction").%Get("id"), "create", "the list declares Create as its primary action")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyNextKey"), "", "so its empty state names no next step")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyAgentKey"), "walletSecretListEmptyAgent", "and invites the agent instead")
}

/// <p>The probe collection's full name for the secret <var>pPart</var>.</p>
ClassMethod Name(pPart As %String) As %String
{
    Quit $Parameter(..#PROBE, "COLLECTION") _ "." _ pPart
}

/// <p>A value no other test uses, generated at run time.</p>
ClassMethod Value() As %String
{
    Quit "OcuPilotProbe86Value" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(12), 1), "+/=", "")
}

/// <p>The three settings every create here proposes.</p>
ClassMethod Settings() As %DynamicObject
{
    Quit {"Usage": 5, "RequireTLS": true, "AllowedHosts": ["h.example"]}
}

/// <p><method>Settings</method> with <var>pValue</var> added: what the screen's Save carries.</p>
ClassMethod Args(pValue As %String) As %DynamicObject
{
    Set tArgs = ..Settings()
    Do tArgs.%Set("Secret", pValue, "string")
    Quit tArgs
}

/// <p>The secret <var>pName</var> as the wallet port reads it, as JSON, or <code>""</code>.</p>
ClassMethod Read(pName As %String) As %String
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = ##class(OcuPilot.Port.WalletPort).Invoke("Wallet.Secret", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Quit ""
    Quit tResult.%ToJSON()
}

/// <p>Mint one create of <var>pName</var> through the shipped mint, as
/// <method>OcuPilot.Screen.Tool.Write.View</method> would.</p>
Method Mint(pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTurnKey As %String) As %Status
{
    Set pProposal = ""
    Set pTurnKey = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pName, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>Confirm <var>pKey</var> through the shipped transition with <var>pSecrets</var> as the body.</p>
Method Confirm(pKey As %String, pSecrets As %DynamicObject, Output pHttp As %Integer, Output pCode As %String, Output pResult As %DynamicObject) As %Status
{
    Set pResult = ""
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, pSecrets, $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p>The code <var>pViolations</var> carries for <var>pField</var>, or <code>""</code>.</p>
ClassMethod CodeFor(ByRef pViolations, pField As %String) As %String
{
    Set tCode = ""
    For tI = 1:1:+$Get(pViolations) {
        If $List(pViolations(tI), 1) = pField Set tCode = $List(pViolations(tI), 2) Quit
    }
    Quit tCode
}

/// <p><var>pObject</var>'s keys, sorted, comma-separated.</p>
ClassMethod Keys(pObject As %DynamicObject) As %String
{
    Set tKeys = ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $ListBuild(tKey)
    }
    Quit ..Sorted(tKeys)
}

/// <p><var>pList</var> sorted, as a comma-separated string.</p>
ClassMethod Sorted(pList As %List) As %String
{
    Kill tSeen
    For tI = 1:1:$ListLength(pList) Set tSeen($List(pList, tI)) = ""
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSeen(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

}
