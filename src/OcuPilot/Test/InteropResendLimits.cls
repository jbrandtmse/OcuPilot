/// <p>Pins the limits Story 20.31 puts on a message resend (AD-6, AD-13, AD-22, AD-53, AD-62): the cap of 100 messages an action takes,
/// met by 100 real messages sent by the person's route and carried by the agent's card, and exceeded by 101 real ones that every caller
/// refuses whole with nothing sent; the review digest a person's action carries, which a forged, truncated or foreign digest does not
/// satisfy while the reviewed one does; each write's governance key, which the agent's call needs and a person's action does not, shown
/// off, on and put back; an edit that clears a field, through both callers; and what the outcome of a resend reads when the vendor
/// refused one message.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe production in
/// <code>USER</code></b> and sends messages to it (<class>OcuPilot.Test.InteropResendCase</class>). One class per run.</p>
Class OcuPilot.Test.InteropResendLimits Extends OcuPilot.Test.InteropResendCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter RESENDTOOL = "OcuPilot.Screen.Tool.InteropMessageResend";

Parameter EDITTOOL = "OcuPilot.Screen.Tool.InteropMessageEditResend";

Parameter RESENDKEY = "interop.messages.resend";

Parameter EDITKEY = "interop.messageheader.editresend";

/// <p>The suite whose route calls this one reuses: the Messages screen's dry run and action.</p>
Parameter RESEND = "OcuPilot.Test.InteropResend";

/// <p>The Header screen's dry run and action.</p>
Parameter EDIT = "OcuPilot.Test.InteropEditResend";

/// <p>Store <var>pCount</var> string requests to the probe's enabled operation: their header ids, ascending, in <var>pIds</var> as a
/// <class>%List</class>, and how many were stored.</p>
Method Store(pCount As %Integer, Output pIds As %List) As %Integer
{
    Set pIds = ""
    For tI = 1:1:pCount {
        Set tSC = $ClassMethod(..#FIXTURE, "Request", "bulk " _ tI, ..#OPNAME, .tId)
        If $$$ISERR(tSC) Quit
        Set pIds = pIds _ $ListBuild(tId)
    }
    Quit $ListLength(pIds)
}

/// <p>The agent's call of the tool <var>pKey</var> with the arguments <var>pInput</var>, dispatched as the running account on a seeded
/// turn: <code>&lt;is_error&gt;|&lt;content&gt;</code> of its one result, <code>""</code> when none came. The turn's ledger rows are
/// removed.</p>
Method Ask(pKey As %String, pInput As %DynamicObject) As %String
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit "seed: " _ $System.Status.GetErrorText(tSC)
    Do pInput.%Set("rationale", "probe", "string")
    Do pInput.%Set("expectedImpact", "probe", "string")
    Set tUse = {"type": "tool_use", "id": "toolu_limits", "input": (pInput)}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pKey), "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tAnswer = ""
    If $$$ISOK(tSC) && $IsObject($Get(tResults)) && (tResults.%Size() = 1) Set tAnswer = $Select(tResults.%Get(0).%Get("is_error"): 1, 1: 0) _ "|" _ tResults.%Get(0).%Get("content")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    Quit tAnswer
}

/// <p>Put the governance policy found before <method>EnableKey</method> back, as <method>OnAfterOneTest</method> does, and say whether
/// the stored policy reads as it did.</p>
Method PutPolicyBack(ByRef pBefore) As %Boolean
{
    Kill tPolicy
    Merge tPolicy = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the key was turned on is put back")
    Set ..PreparedPolicyTaken = 0
    Quit ##class(OcuPilot.Test.GovernanceFixture).Matches(.pBefore)
}

/// <p>AC2: 101 messages that could all go are refused whole by the person's review, the person's action and the agent's mint, naming
/// <code>Messages</code> and the cap, and none is sent -- not even the first 100; 100 of them are then reviewed to 100 lines and sent by
/// the person's action as 100 new headers with a line for each.</p>
/// <p>Mutation (Rule 19): lower <parameter>OcuPilot.Port.InteropPort.RESENDMAX</parameter> to 99 -- the 100 legs go red; raise it to 101 --
/// the 101 legs go red.</p>
Method TestAHundredMessagesGoAndAHundredAndOneAreRefusedWholeWithNothingSent()
{
    Do $$$AssertEquals(..Store(101, .tIds), 101, "101 messages that could all go are stored")
    If $ListLength(tIds) '= 101 Quit
    Set tAll = $ListToString(tIds, ",")
    Set tHundred = $ListToString($List(tIds, 1, 100), ",")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Do ..EnableKey(..#RESENDKEY)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tCap = "Messages must name 1 to 100 message header IDs"
    Do $$$AssertEquals($ClassMethod(..#RESEND, "Dry", tAll, .tDry), "400 PORT.VALIDATION", "the review of 101 is refused whole")
    Do $$$AssertTrue($IsObject(tDry) && (tDry.%ToJSON() [ tCap), "naming Messages and the cap")
    Do $$$AssertEquals($ClassMethod(..#RESEND, "Send", tAll, $Translate($Justify("", 64), " ", "a"), .tSent), "400 PORT.VALIDATION", "so is the action")
    Do $$$AssertTrue($IsObject(tSent) && (tSent.%ToJSON() [ tCap), "naming Messages and the cap")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#RESENDTOOL, {"Messages": (tAll)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertTrue($$$ISERR(tSC) && ($Get(tHttp) = 400) && '$IsObject($Get(tProposal)), "and so is the agent's mint: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: $Get(tHttp)))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "nothing was sent, though every one of the 101 could go")

    Do $$$AssertEquals($ClassMethod(..#RESEND, "Dry", tHundred, .tDry), "200 ", "the review of 100 answers: " _ $Select($IsObject(tDry): $Extract(tDry.%ToJSON(), 1, 200), 1: tDry))
    Do $$$AssertEquals($Length($ClassMethod(..#RESEND, "Lines", tDry), $Char(10)), 100, "with a line for each")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "and sends nothing")
    Do $$$AssertEquals($ClassMethod(..#RESEND, "Send", tHundred, tDry.review.Digest, .tSent), "200 ", "the action of 100 is admitted: " _ $Select($IsObject(tSent): $Extract(tSent.%ToJSON(), 1, 200), 1: tSent))
    If $IsObject(tSent) {
        Do $$$AssertEquals(tSent.output.lines.%Size() _ "|" _ $Piece(tSent.output.lines.%Get(0), ": resent as ", 1) _ "|" _ $Piece(tSent.output.lines.%Get(99), ": resent as ", 1), "100|" _ $List(tIds, 1) _ "|" _ $List(tIds, 100), "it answers a line for each, in id order")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId") - tTop, 100, "and exactly 100 headers were made")
    Do $$$AssertEquals(..Gained($ClassMethod(..#FIXTURE, "Property", $List(tIds, 100), "SessionId"), tTop), 1, "the last of them in its original's session")
}

/// <p>AC2, AC3: the agent's mint of the whole cap, 100 messages, answers a card of one row of 100 lines and sends nothing: the message
/// store's ids are as long as the store is old, and a set of them is one proposal target that must fit the proposal store's index.</p>
/// <p>Mutation (Rule 19): lower <parameter>OcuPilot.Port.InteropPort.RESENDMAX</parameter> to 99 -- the mint is refused and this goes red.</p>
Method TestTheAgentsCardCarriesTheWholeCapOfAHundredMessages()
{
    Do $$$AssertEquals(..Store(100, .tIds), 100, "100 messages that could all go are stored")
    If $ListLength(tIds) '= 100 Quit
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Do ..EnableKey(..#RESENDKEY)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#RESENDTOOL, {"Messages": ($ListToString(tIds, ","))}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the agent's mint of 100 succeeds: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $IsObject($Get(tProposal)) {
        Do $$$AssertEquals(tProposal.changed.%Size() _ "|" _ $Length(tProposal.changed.%Get(0).after, $Char(10)), "1|100", "its card is one row of 100 lines")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "and the mint sent nothing")
}

/// <p>AC4: a person's action is held to the digest of its review. A digest of the wrong length, of zeros, in the wrong letter case, with a
/// blank after it, the review of another set, or one that is not hex at all is refused 409 <code>INTEROP.RESEND.CHANGED</code> and
/// nothing is sent; the reviewed digest then sends both messages.</p>
/// <p>Mutation (Rule 19): compare only the first 8 characters of the digest in <method>OcuPilot.Port.InteropPort.ReadResend</method> --
/// the truncated and foreign rows go red.</p>
Method TestAForgedTruncatedOrForeignDigestIsRefusedAndOnlyTheReviewedOneSends()
{
    Set tA = ..Make("alpha")
    Set tC = ..Make("gamma", ..#TWONAME)
    Set tSet = tA _ "," _ tC
    Do $$$AssertEquals($ClassMethod(..#RESEND, "Dry", tSet, .tDry), "200 ", "the set is reviewed")
    Do $$$AssertEquals($ClassMethod(..#RESEND, "Dry", tA, .tOther), "200 ", "so is one of its messages")
    If '$IsObject(tDry) || '$IsObject(tOther) Quit
    Set tDigest = tDry.review.Digest
    Do $$$AssertNotEquals(tOther.review.Digest, tDigest, "the two reviews read two digests")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    For tCase = $ListBuild("64 letters a", $Translate($Justify("", 64), " ", "a")), $ListBuild("64 zeros", $Translate($Justify("", 64), " ", "0")), $ListBuild("the digest less its last digit", $Extract(tDigest, 1, 63)), $ListBuild("the digest in capitals", $ZConvert(tDigest, "U")), $ListBuild("the digest and a blank", tDigest _ " "), $ListBuild("the digest of another set", tOther.review.Digest), $ListBuild("a word", "reviewed") {
        Set tCode = $ClassMethod(..#RESEND, "Send", tSet, $List(tCase, 2), .tRefused)
        Do $$$AssertEquals(tCode, "409 INTEROP.RESEND.CHANGED", $List(tCase, 1) _ " is refused as a review the verdicts no longer give")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "and nothing was sent")
    Do $$$AssertEquals($ClassMethod(..#RESEND, "Send", tSet, tDigest, .tSent), "200 ", "the reviewed digest sends: " _ $Select($IsObject(tSent): $Extract(tSent.%ToJSON(), 1, 200), 1: tSent))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId") - tTop, 2, "both messages")
}

/// <p>AC3, AD-22: the agent's resend is refused at the shipped value of its key and minted once the key is on, with the person's own
/// action admitted either way; the stored policy then reads as it did, and the agent is refused again.</p>
/// <p>Mutation (Rule 19): have <class>OcuPilot.Kernel.Governance.Baseline</class> ship <code>interop.messages.resend</code> <code>true</code>
/// -- the refused rows go red.</p>
Method TestTheResendKeyAloneDecidesWhetherTheAgentMintsAndAPersonIsNeverAsked()
{
    Set tA = ..Make("alpha")
    Set tB = ..Make("beta")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tBefore), "the stored policy reads")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).IsDefault(.tBefore), "and leaves the key to the baseline")
    Set tDenied = "1|{""code"":""GOVERNANCE.DISABLED""}"
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Do $$$AssertEquals(..Ask(..#RESENDKEY, {"Messages": (tA)}), tDenied, "the agent's resend is refused while the key is off")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "and nothing was minted or sent")
    Do $$$AssertEquals($ClassMethod(..#RESEND, "Dry", tB, .tDry), "200 ", "a person's review is not asked of the key")
    If $IsObject(tDry) Do $$$AssertEquals($ClassMethod(..#RESEND, "Send", tB, tDry.review.Digest, .tSent), "200 ", "and neither is the person's action")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId") - tTop, 1, "which sent")
    Do ..EnableKey(..#RESENDKEY)
    Set tAnswer = ..Ask(..#RESENDKEY, {"Messages": (tA)})
    Do $$$AssertTrue(($Piece(tAnswer, "|", 1) = 0) && (tAnswer [ "proposalId"), "the agent's resend is minted once the key is on: " _ $Extract(tAnswer, 1, 300))
    Do $$$AssertTrue(..PutPolicyBack(.tBefore), "the policy reads as it did")
    Do $$$AssertEquals(..Ask(..#RESENDKEY, {"Messages": (tA)}), tDenied, "and the agent is refused again")
}

/// <p>AC5, AD-22: the same for the edit and resend: refused at the shipped value, minted with the key on, a person's action admitted
/// either way, the policy put back and the agent refused again.</p>
/// <p>Mutation (Rule 19): have <class>OcuPilot.Kernel.Governance.Baseline</class> ship <code>interop.messageheader.editresend</code>
/// <code>true</code> -- the refused rows go red.</p>
Method TestTheEditKeyAloneDecidesWhetherTheAgentMintsAndAPersonIsNeverAsked()
{
    Set tA = ..Make("alpha")
    Set tB = ..Make("beta")
    Set tFields = {"StringValue": "edited"}
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tBefore), "the stored policy reads")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).IsDefault(.tBefore), "and leaves the key to the baseline")
    Set tDenied = "1|{""code"":""GOVERNANCE.DISABLED""}"
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Do $$$AssertEquals(..Ask(..#EDITKEY, {"Message": (tA), "Fields": (tFields)}), tDenied, "the agent's edit is refused while the key is off")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "and nothing was minted or sent")
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Dry", tB, "", .tForm), "200 ", "a person's review is not asked of the key")
    If $IsObject(tForm) Do $$$AssertEquals($ClassMethod(..#EDIT, "Send", tB, tFields.%ToJSON(), tForm.review.Digest, .tSent), "200 ", "and neither is the person's action")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId") - tTop, 1, "which sent")
    Do ..EnableKey(..#EDITKEY)
    Set tAnswer = ..Ask(..#EDITKEY, {"Message": (tA), "Fields": (tFields)})
    Do $$$AssertTrue(($Piece(tAnswer, "|", 1) = 0) && (tAnswer [ "proposalId"), "the agent's edit is minted once the key is on: " _ $Extract(tAnswer, 1, 300))
    Do $$$AssertTrue(..PutPolicyBack(.tBefore), "the policy reads as it did")
    Do $$$AssertEquals(..Ask(..#EDITKEY, {"Message": (tA), "Fields": (tFields)}), tDenied, "and the agent is refused again")
}

/// <p>AC5: an edit may clear a field. The agent's edit of <code>StringValue</code> to empty text is carried by the card, the stored
/// payload and the confirm, and the person's review and send of the same: each copy reads the field empty, and each original keeps
/// its own value.</p>
/// <p>Mutation (Rule 19): drop an empty member from the echoed <code>Fields</code> in
/// <method>OcuPilot.Port.InteropPort.CanonicalFields</method> (ignore its keep-empty flag) -- the copies keep their value and this goes
/// red.</p>
Method TestAnEditThatClearsAFieldSendsACopyWithTheFieldEmpty()
{
    Set tA = ..Make("alpha")
    Set tB = ..Make("beta")
    Do ..EnableKey(..#EDITKEY)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#EDITTOOL, {"Message": (tA), "Fields": {"StringValue": ""}}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the agent's edit that clears the field mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $IsObject($Get(tProposal)) {
        Do $$$AssertEquals(tProposal.changed.%Size() _ "|" _ tProposal.changed.%Get(0).before, "1|StringValue: alpha", "its card shows the field's value before")
        Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
        Do $$$AssertEquals(tStatus, 200, "it confirms: " _ $Extract($Get(tRaw), 1, 300))
        Set tNew = $ClassMethod(..#EDIT, "NewHeader", $Get(tAnswer), tA)
        Do $$$AssertEquals($ClassMethod(..#EDIT, "FieldsOf", tNew, "StringValue") _ "|" _ $ClassMethod(..#EDIT, "FieldsOf", tA, "StringValue"), "StringValue=|StringValue=alpha", "the agent's copy reads the field empty and the original keeps its own")
    }
    Set tFields = {"StringValue": ""}.%ToJSON()
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Dry", tB, tFields, .tDry), "200 ", "the person's review of the clear answers: " _ $Select($IsObject($Get(tDry)): tDry.%ToJSON(), 1: $Get(tDry)))
    If '$IsObject($Get(tDry)) Quit
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Send", tB, tFields, tDry.review.Digest, .tSent), "200 ", "and the send: " _ $Select($IsObject($Get(tSent)): tSent.%ToJSON(), 1: $Get(tSent)))
    Set tNew = $ClassMethod(..#EDIT, "NewHeader", $Get(tSent), tB)
    Do $$$AssertEquals($ClassMethod(..#EDIT, "FieldsOf", tNew, "StringValue") _ "|" _ $ClassMethod(..#EDIT, "FieldsOf", tB, "StringValue"), "StringValue=|StringValue=beta", "the person's copy reads the field empty and the original keeps its own")
}

/// <p>A message the vendor refuses reads <code>&lt;id&gt;: not resent: &lt;the vendor's text&gt;</code> on the outcome a person is shown,
/// between the lines of the two that were sent, in id order.</p>
/// <p>Mutation (Rule 19): have <method>OcuPilot.Screen.Tool.InteropMessageAction.WriteOutput</method> read every entry as sent -- the
/// middle line goes red.</p>
Method TestAVendorRefusalReadsNotResentWithTheVendorsTextOnTheOutcome()
{
    Set tA = ..Make("alpha")
    Set tB = ..Make("beta")
    Set tC = ..Make("gamma")
    Do ..HoldPairs()
    Do $ClassMethod(..#SEAM, "Arm")
    Do $ClassMethod(..#SEAM, "FailResendOf", tB)
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tA _ "," _ tB _ "," _ tC
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Messages", "RESENDMESSAGES", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 200, "the write is admitted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tResult)) Quit
    Set tOutput = $ClassMethod(..#RESENDTOOL, "WriteOutput", tResult)
    Do $$$AssertTrue($IsObject(tOutput) && (tOutput.lines.%Size() = 3), "the outcome has a line for each message sent")
    If '$IsObject(tOutput) Quit
    Do $$$AssertEquals($Piece(tOutput.lines.%Get(0), ": resent as ", 1) _ "|" _ $Piece(tOutput.lines.%Get(2), ": resent as ", 1), tA _ "|" _ tC, "the first and the third read resent as the new header")
    Do $$$AssertEquals($Piece(tOutput.lines.%Get(1), ": not resent: ", 1), tB, "the second reads not resent")
    Do $$$AssertTrue(tOutput.lines.%Get(1) [ (": not resent: "), "with the words not resent: " _ tOutput.lines.%Get(1))
    Do $$$AssertTrue(tOutput.lines.%Get(1) [ ("resend refused for the test: " _ tB), "and the vendor's text: " _ tOutput.lines.%Get(1))
}

}
