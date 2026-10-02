/// <p>Pins Story 18.5's journal integrity check over a seam (AD-26, AD-39's fifth exception): a check
/// whose console answers lines reaches the screen and the proposal card with those lines and its
/// errors verdict, while the stored proposal and the turn's ledger rows carry none of them; a check
/// still running at the port's bound answers started on both callers, its read-back unchecked; and
/// the port sends the flag each caller chose, unchecked as false and checked as true.</p>
/// <p>The check itself is answered by <class>OcuPilot.Test.JournalIntegrityPort</class>, never sent to
/// the vendor, so it needs no corrupt file. It needs OcuPilot installed, journaling on, and a caller
/// holding <code>%All</code>. Where the journal file list names no closed file,
/// <method>OnBeforeAllTests</method> first switches the journal file to close one
/// (<method>OcuPilot.Test.JournalProbe.EnsureClosedFile</method>), only when
/// <parameter>JOURNALVARIABLE</parameter> reads <code>1</code>; the file it closes is kept. Otherwise it
/// writes only proposals, ledger rows and agent markers, and removes the proposals it minted.</p>
Class OcuPilot.Test.JournalIntegrity Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the journal switch a list without a closed file needs.</p>
Parameter JOURNALVARIABLE = "OCUPILOT_ALLOW_JOURNAL";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.JournalList";

Parameter TOOL = "OcuPilot.Screen.Tool.JournalIntegrityCheck";

Parameter SEAM = "OcuPilot.Test.JournalIntegrityPort";

Parameter ACTION = "OcuPilot.Test.JournalIntegrityAction";

Parameter CONFIRM = "OcuPilot.Test.JournalIntegrityConfirm";

/// <p>The two console lines the seam answers, as the vendor's check would write them.</p>
Parameter LINEONE = "OcuProbe185 bad record at offset 131088";

Parameter LINETWO = "OcuProbe185 checksum mismatch in block 7";

Method OnBeforeAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.JournalProbe).EnsureClosedFile($System.Util.GetEnviron(..#JOURNALVARIABLE) = 1)
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(..#SEAM, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(..#SEAM, "Clear")
    Quit ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
}

/// <p>A closed journal file the instance lists.</p>
ClassMethod ClosedFile() As %String
{
    Set tRows = ##class(OcuPilot.Test.JournalProbe).Listed()
    If '$IsObject(tRows) || (tRows.%Size() < 2) Quit ""
    Quit tRows.%Get(1).%Get("Name")
}

/// <p>AC5: the seam's two lines reach the screen's answer and the confirm's, each with
/// <code>errors</code> true, each check sent with the flag its caller chose; the stored proposal and
/// the turn's ledger rows hold neither line.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.JournalIntegrityCheck.WriteOutput</method>
/// answer <code>""</code> -&gt; neither caller carries the lines and this goes red.</p>
Method TestErrorsReachThePageAndTheCardOnly()
{
    Set tFile = ..ClosedFile()
    Do $$$AssertTrue(tFile '= "", "a closed journal file is listed")
    If tFile = "" Quit
    Do $ClassMethod(..#SEAM, "AnswerLines", [(..#LINEONE), (..#LINETWO)])
    Set tSC = ..Act(tFile, "true", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the screen's check answers 200: " _ ..Shown(tBody))
    Do $$$AssertEquals(..Output(tBody), "{""lines"":[""" _ ..#LINEONE _ """,""" _ ..#LINETWO _ """],""errors"":true}", "with both lines and the errors verdict")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Bodies"), "{""CheckDetails"":true}", "the flag it was given was sent")

    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(tTurn, tFile, .tProposal)
    Do $$$AssertStatusOK(tSC, "the agent's check mints")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm checks: " _ $Get(tCode))
    Do $$$AssertEquals(..Output($Get(tResult)), "{""lines"":[""" _ ..#LINEONE _ """,""" _ ..#LINETWO _ """],""errors"":true}", "and answers the card both lines")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Bodies"), "{""CheckDetails"":true}|{""CheckDetails"":true}", "the confirm sent the flag the proposal carries")
    Set tStored = ##class(OcuPilot.Test.ExplorerWrite).StoredText(tProposal.%Get("proposalId"), .tLedgerRows)
    Do $$$AssertTrue(tLedgerRows > 0, "the turn's ledger rows are read: " _ tLedgerRows)
    Do $$$AssertTrue((tStored [ tFile) && (tStored '[ "OcuProbe185 "), "and the stored proposal and its ledger rows hold no line")
}

/// <p>AC5, AD-26: a check the seam leaves running at the port's bound answers the screen 200 with
/// <code>continues</code> and the confirm the same, each read back <code>unchecked</code>
/// <code>running</code> and carrying no output; the screen's unchecked flag is sent as false, and the
/// proposal's as true.</p>
/// <p>Mutation (Rule 19): drop <class>OcuPilot.Port.JournalPort</class>'s started conversion -&gt;
/// both callers answer <code>PORT.TIMEOUT</code> and this goes red.</p>
Method TestACheckPastTheBoundHasStarted()
{
    Set tFile = ..ClosedFile()
    If tFile = "" {
        Do $$$AssertTrue(0, "a closed journal file is listed")
        Quit
    }
    Do $ClassMethod(..#SEAM, "AnswerTimeout")
    Set tSC = ..Act(tFile, "false", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Member(tBody, "continues") _ " " _ ..ReadBack(tBody), "200 1 unchecked|running", "the screen's check has started: " _ ..Shown(tBody))
    Do $$$AssertEquals(..Output(tBody), "", "and carries no output")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Bodies"), "{""CheckDetails"":false}", "the unchecked flag was sent as false")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(tTurn, tFile, .tProposal)
    Do $$$AssertStatusOK(tSC, "the agent's check mints")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm answers")
    Do $$$AssertEquals(..Member($Get(tResult), "continues") _ " " _ ..ReadBack($Get(tResult)), "1 unchecked|running", "the confirmed check has started")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Bodies"), "{""CheckDetails"":false}|{""CheckDetails"":true}", "with the flag the proposal carries")
}

/// <p>Send the screen's integrity check of <var>pFile</var> with the flag <var>pFlag</var> through
/// <parameter>ACTION</parameter>, answering the status and the parsed envelope.</p>
ClassMethod Act(pFile As %String, pFlag As %String, Output pStatus As %Integer, Output pBody) As %Status
{
    Set tRequest = {"action": "integrity"}
    Do tRequest.%Set("id", pFile, "string")
    Do tRequest.%Set("values", {"CheckDetails": (pFlag)})
    Set tSC = $ClassMethod(..#ACTION, "Act", "osmgmt.journals", tRequest, .tRaw, .pStatus)
    Set pBody = ""
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
    Quit tSC
}

/// <p>Mint the integrity check of <var>pFile</var>, every record, in turn <var>pTurn</var>.</p>
ClassMethod Mint(pTurn As %String, pFile As %String, Output pProposal As %DynamicObject) As %Status
{
    Set tArgs = {"CheckDetails": true}
    Do tArgs.%Set("Name", pFile, "string")
    Quit ##class(OcuPilot.Screen.Tool.JournalMint).Mint(..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurn, tArgs, "OcuPilot.Kernel.Agent.Limits", .pProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pFile, "Name", $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p><var>pBody</var>'s <code>output</code> as JSON, or <code>""</code>.</p>
ClassMethod Output(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("output")) Quit ""
    Quit pBody.%Get("output").%ToJSON()
}

/// <p><var>pBody</var>'s read-back as <code>verdict|reason</code>, or <code>""</code>.</p>
ClassMethod ReadBack(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("readBack")) Quit ""
    Quit pBody.%Get("readBack").%Get("verdict") _ "|" _ pBody.%Get("readBack").%Get("reason")
}

/// <p><var>pBody</var>'s member <var>pName</var>, or <code>""</code>.</p>
ClassMethod Member(pBody, pName As %String) As %String
{
    If '$IsObject(pBody) Quit ""
    Quit pBody.%Get(pName)
}

/// <p><var>pBody</var> as text for an assertion message.</p>
ClassMethod Shown(pBody) As %String
{
    Quit $Select($IsObject(pBody): pBody.%ToJSON(), 1: $Get(pBody))
}

}
