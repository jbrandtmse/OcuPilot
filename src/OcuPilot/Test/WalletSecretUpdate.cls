/// <p>Pins Story 8.6's wallet secret edit (AD-4, AD-6, AD-27, AD-35, AD-55): what
/// <class>OcuPilot.Screen.Tool.WalletSecretUpdate</class> advertises, the merge both callers send
/// over a fresh read, the stored value kept when no new value is entered and replaced when one is,
/// the card's optional value row, a key outside the edit refused, a secret deleted since the read
/// refused rather than re-created (AC4), and a secret of another type left alone.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and an account
/// holding <code>%Admin_Wallet</code>. Every write reaches the instance through
/// <class>OcuPilot.Test.WalletRecordPort</class>, into the probe collection of
/// <class>OcuPilot.Test.WalletProbe</class>, whose secrets are removed by exact name.</p>
Class OcuPilot.Test.WalletSecretUpdate Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.WalletSecretUpdate";

Parameter LIST = "OcuPilot.Screen.Descriptor.WalletSecretList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter SCREEN = "OcuPilot.Test.WalletSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.WalletConfirm";

Parameter RECORD = "OcuPilot.Test.WalletRecordPort";

Parameter PROBE = "OcuPilot.Test.WalletProbe";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The secrets this class stores, by the part after the probe collection.</p>
Parameter PARTS = "EditKv,EditGone,EditSym";

/// <p>The value the edited secret is stored with.</p>
Parameter STORED = "OcuPilotProbe86Stored";

Method OnBeforeAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "EnsureCollection", .tCreated)
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove", .tRemaining)
    If $$$ISOK(tSC) && (tRemaining > 0) Set tSC = $$$ERROR($$$GeneralError, tRemaining _ " probe secret(s) survived OcuPilot.Test.WalletSecretUpdate")
    Quit tSC
}

/// <p>Store the edited secret afresh: the stored value, uses 5, no TLS and one allowed host.</p>
Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(..#PROBE, "RemoveSecret", ..Name("EditKv"))
    Quit $ClassMethod(..#PROBE, "AddKeyValue", ..Name("EditKv"), {"Secret": (..#STORED), "Usage": 5, "RequireTLS": false, "AllowedHosts": ["h"]})
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    For tI = 1:1:$Length(..#PARTS, ",") Do $ClassMethod(..#PROBE, "RemoveSecret", ..Name($Piece(..#PARTS, ",", tI)))
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>AD-4: the edit is a merge write through the wallet port whose settable set is the prohibited
/// set's reviewed change list; its schema carries no value; and its one composed secret, the value,
/// is optional.</p>
Method TestTheEditIsAMergeWriteOverTheThreeSettings()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals(..Keys(tSchema.%Get("properties")), "AllowedHosts,Name,RequireTLS,Usage,expectedImpact,rationale,reverse", "the schema is the name, the three settings and the agent's own words")
    Do $$$AssertEquals(..Sorted($ClassMethod(..#TOOL, "SettableFields")), ..Sorted($ClassMethod(..#SET, "PermittedChangeFields", "wallet-secret")), "the settable set is the prohibited set's reviewed change list")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ReadType") _ " " _ $ClassMethod(..#TOOL, "WriteType") _ " " _ $ClassMethod(..#TOOL, "SendsBody") _ " " _ $ClassMethod(..#TOOL, "PortClass"), "GET PUT 1 OcuPilot.Port.WalletPort", "a merge write through the wallet port")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Creates") _ " " _ $ClassMethod(..#TOOL, "ChangeAction"), "0 updated", "publishing updated")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "ComposedSecrets")) _ "|" _ $ListToString($ClassMethod(..#TOOL, "OptionalSecrets")), "Secret|Secret", "whose value is composed and optional")
}

/// <p>AC1 on the card: an edit's proposal carries a masked value row, both sides empty and marked
/// optional, beside the one setting it changes.</p>
Method TestTheCardOffersAnOptionalValue()
{
    Set tSC = ..Mint(..Name("EditKv"), {"Usage": 2}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the edit is minted")
    If $$$ISERR(tSC) Quit
    Kill tRows
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tRows(tRow.%Get("field")) = tRow.%Get("before") _ "|" _ tRow.%Get("after") _ "|" _ tRow.%GetTypeOf("optional") _ "|" _ tRow.%Get("optional")
    }
    Do $$$AssertEquals($Get(tRows("Usage")), "5|2|unassigned|", "the uses move from 5 to 2")
    Do $$$AssertEquals($Get(tRows("Secret")), "||boolean|1", "and the value's row is empty and optional")
    Do $$$AssertEquals($Data(tRows("RequireTLS")) + $Data(tRows("AllowedHosts")), 0, "the settings it does not change are not rows")
}

/// <p>The Always rules' complete set, AD-4: an edit of the uses alone, on either caller, sends the fresh
/// read's other two settings and its type unchanged and no value, and the instance keeps the stored
/// value.</p>
Method TestAnEditKeepsWhatTheCallerDidNotChangeOnBothCallers()
{
    Set tSC = $ClassMethod(..#SCREEN, "Update", ..Name("EditKv"), {"Usage": 1}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen's edit is saved")
    Do $$$AssertEquals(..Normal($ClassMethod(..#RECORD, "LastWriteBody")), "AllowedHosts=[""h""]|RequireTLS=false|Type=%Wallet.KeyValue|Usage=1", "the screen sends the fresh read with the uses changed and no value")
    Do $$$AssertEquals(..Read(..Name("EditKv")), "{""Type"":""%Wallet.KeyValue"",""Usage"":1,""RequireTLS"":false,""AllowedHosts"":[""h""]}", "and the instance holds it")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredValue", ..Name("EditKv")), ..#STORED, "with the stored value kept")

    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = ..Mint(..Name("EditKv"), {"Usage": 3}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's edit is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), {"Secret": ""}, .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and confirmed with the value left empty: " _ $Get(tCode))
    Do $$$AssertEquals(..Normal($ClassMethod(..#RECORD, "LastWriteBody")), "AllowedHosts=[""h""]|RequireTLS=false|Type=%Wallet.KeyValue|Usage=3", "the confirm sends the same shape, with no value")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredValue", ..Name("EditKv")), ..#STORED, "and the stored value is kept")
}

/// <p>A new value, entered on either caller, travels in the edit's body and replaces the stored
/// one.</p>
Method TestANewValueReplacesTheStoredOne()
{
    Set tSC = $ClassMethod(..#SCREEN, "Update", ..Name("EditKv"), {"Secret": "OcuPilotProbe86New1"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen's edit with a new value is saved")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredValue", ..Name("EditKv")), "OcuPilotProbe86New1", "and the value is replaced")
    Set tSC = ..Mint(..Name("EditKv"), {"RequireTLS": true}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's edit is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), {"Secret": "OcuPilotProbe86New2"}, .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and confirmed with a new value: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredValue", ..Name("EditKv")), "OcuPilotProbe86New2", "which replaces it")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "") [ "OcuPilotProbe86New2", 0, "and the confirm's answer does not carry it")
}

/// <p>The Edit, screen row: a key outside the three settings and the value is refused at 400 with
/// nothing sent, and the agent's schema refuses the same key.</p>
Method TestAnyOtherKeyIsRefusedOnBothCallers()
{
    For tBody = {"Type": "%Wallet.RSA"}, {"Secret64": "eA=="}, {"Name": "OcuPilotProbe86.Other"} {
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Update", ..Name("EditKv"), tBody, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(tHttp, 400, tBody.%ToJSON() _ ": refused at 400")
        Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, tBody.%ToJSON() _ ": as a field this edit does not take")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, tBody.%ToJSON() _ ": and nothing is sent")
    }
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments($ClassMethod(..#TOOL, "InputSchema"), {"Name": (..Name("EditKv")), "Type": "%Wallet.RSA"}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "the agent's schema refuses a type")
}

/// <p>AC4: the vendor's <code>PUT</code> is an upsert. An edit whose secret was deleted since the
/// read is refused on both callers and the secret is not re-created: the screen's fresh read answers
/// 404 before anything is sent, and the agent's confirm finds the target changed.</p>
/// <p>Mutation (Rule 19): answer an absent name's read with a key-value object at 200 in
/// <method>OcuPilot.Port.WalletPort.Completed</method> -> the screen's edit is sent, the vendor's upsert
/// re-creates the secret, and this goes red.</p>
Method TestADeletedSecretIsRefusedAndNotRecreated()
{
    Set tGone = ..Name("EditGone")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tGone, {"Usage": 1, "Secret": "OcuPilotProbe86Recreated"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusNotOK(tSC, "the screen's edit of an absent secret is refused")
    Do $$$AssertEquals(tHttp, 404, "at 404")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tGone), 0, "and nothing is created")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddKeyValue", tGone, {"Secret": "v"}), "a secret is stored")
    Set tSC = ..Mint(tGone, {"Usage": 2}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and the agent's edit of it is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveSecret", tGone), "then it is deleted")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), {"Secret": "OcuPilotProbe86Recreated"}, .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tGone), 0, "and the secret is not re-created")
}

/// <p>The Another type row: a symmetric key is not changed by either caller -- the screen answers 422
/// on its own code with nothing sent, and the agent's mint is refused at 400.</p>
Method TestAnotherTypeIsLeftAlone()
{
    Set tSym = ..Name("EditSym")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddSymmetricKey", tSym), "a symmetric key is stored")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tSym, {"Usage": 1}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp, 422, "the screen refuses its edit at 422")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#WALLETTYPEUNSUPPORTED, "on the unsupported-type code")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends nothing")
    Set tSC = ..Mint(tSym, {}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "the agent's mint of a settings-free edit is refused at 400")
    Set tSC = ..Mint(tSym, {"Usage": 1}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "and so is one that changes the uses")
}

/// <p>The field rules on an edit, on both callers: a use out of range is refused with its code on the
/// screen and at 400 on the mint, and nothing is sent.</p>
Method TestTheRulesRefuseAnEditOnBothCallers()
{
    Set tSC = $ClassMethod(..#SCREEN, "Update", ..Name("EditKv"), {"Usage": 99}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(..CodeFor(.tViolations, "Usage"), "WALLET.USAGE.RANGE", "the screen refuses a use out of range")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends nothing")
    Set tSC = ..Mint(..Name("EditKv"), {"Usage": 99}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "the agent's mint refuses it at 400")
}

/// <p>The probe collection's full name for the secret <var>pPart</var>.</p>
ClassMethod Name(pPart As %String) As %String
{
    Quit $Parameter(..#PROBE, "COLLECTION") _ "." _ pPart
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

/// <p>The JSON body <var>pText</var> as <code>key=value</code> pairs in key order, each value as
/// JSON, joined with <code>|</code>, so two bodies compare whatever their key order.</p>
ClassMethod Normal(pText As %String) As %String
{
    If pText = "" Quit ""
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pText)
    Set tOut = ""
    For tI = 1:1:$Length(..Keys(tBody), ",") {
        Set tKey = $Piece(..Keys(tBody), ",", tI)
        Set tValue = $Case(tBody.%GetTypeOf(tKey), "array": tBody.%Get(tKey).%ToJSON(), "object": tBody.%Get(tKey).%ToJSON(), "boolean": $Select(tBody.%Get(tKey): "true", 1: "false"), : tBody.%Get(tKey))
        Set tOut = tOut _ $Select(tOut = "": "", 1: "|") _ tKey _ "=" _ tValue
    }
    Quit tOut
}

/// <p>Mint one edit of <var>pName</var> through the shipped mint, as
/// <method>OcuPilot.Screen.Tool.Write.View</method> would.</p>
Method Mint(pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pProposal = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pName, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
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
    Quit ##class(OcuPilot.Test.WalletSecretCreate).CodeFor(.pViolations, pField)
}

ClassMethod Keys(pObject As %DynamicObject) As %String
{
    Quit ##class(OcuPilot.Test.WalletSecretCreate).Keys(pObject)
}

ClassMethod Sorted(pList As %List) As %String
{
    Quit ##class(OcuPilot.Test.WalletSecretCreate).Sorted(pList)
}

}
