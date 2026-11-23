/// <p>Pins that an export keeps the namespace it was proposed in (AD-52, Story 24.16 Batch 3): the agent's export minted in <code>USER</code> and confirmed from a request scoped to
/// <code>HSCUSTOM</code> exports and records the views of <code>USER</code>'s messages, in <code>USER</code>, and reads nothing of <code>HSCUSTOM</code>'s, which also holds a probe of its own. A person's
/// export of <code>HSCUSTOM</code>'s message, reviewed and sent in that scope, exports that one. After the last test no probe header, body or file is left in either namespace.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropMessageExportCase</class> needs, and <code>HSCUSTOM</code> as the second interoperability-enabled namespace.
/// No production is started. One class per run.</p>
Class OcuPilot.Test.InteropMessageExportElsewhere Extends OcuPilot.Test.InteropMessageExportCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>AC5 (Integration, Rule 1): the proposal's namespace is the one the kernel's confirm consumes. An export minted in <code>USER</code> and confirmed with <code>?ns=HSCUSTOM</code> answers
/// <code>USER</code>'s bytes alone, records the view in <code>USER</code> alone, and carries none of the text of the probe <code>HSCUSTOM</code> holds.</p>
/// <p>Mutation (Rule 19): leave <code>Namespace</code> out of <parameter>OcuPilot.Screen.Tool.InteropMessageExport.FINGERPRINTSUBJECT</parameter> -- the confirm judges in <code>HSCUSTOM</code> and this goes red.</p>
Method TestAnExportMintedInOneNamespaceIsConfirmedInThatNamespace()
{
    Set tUser1 = $ClassMethod(..#EXPORTFIXTURE, "Store", "USER", "hl7", "u")
    Set tUser2 = $ClassMethod(..#EXPORTFIXTURE, "Store", "USER", "xml", "v")
    Set tOther = $ClassMethod(..#EXPORTFIXTURE, "Store", "HSCUSTOM", "chars", "h", "elsewhere text " _ $Parameter(..#EXPORTFIXTURE, "SENTINEL"))
    Do $$$AssertTrue((tUser1 > 0) && (tUser2 > 0) && (tOther > 0), "the probes are stored in both namespaces")
    Do $$$AssertTrue((tOther '= tUser1) && (tOther '= tUser2), "and HSCUSTOM's id is none of USER's, so a view row names one message")
    Set tSet = tUser1 _ "," _ tUser2
    Set tOtherHeaders = $ClassMethod(..#EXPORTFIXTURE, "Headers", "HSCUSTOM")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#EXPORTTOOL, {"Messages": (tSet), "Separator": "LF", "Charset": "UTF8"}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the export mints in USER: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer, "HSCUSTOM")
    Do $$$AssertEquals(tStatus, 200, "it confirms from a request scoped to HSCUSTOM: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..OutcomeText($Get(tAnswer)), ..OutcomeLine("export", tUser1) _ $Char(10) _ ..OutcomeLine("export", tUser2), "USER's two messages are exported")
    Set tBytes = ..BytesOf($Get(tAnswer))
    Do $$$AssertTrue((tBytes [ "MSH|") && (tBytes '[ "elsewhere text"), "the file holds USER's bodies and none of HSCUSTOM's")
    Do $$$AssertEquals(..Views(tSince, tUser1) _ "|" _ ..Views(tSince, tUser2) _ "|" _ ..Views(tSince, tOther), "1|1|0", "the views were recorded for USER's messages, and none for HSCUSTOM's")
    Do $$$AssertEquals($ClassMethod(..#EXPORTFIXTURE, "Headers", "HSCUSTOM"), tOtherHeaders, "HSCUSTOM holds the rows it held")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC5: the same export of <code>HSCUSTOM</code>'s message, proposed and confirmed in that scope, exports that message and not <code>USER</code>'s, so the namespace the proposal keeps is the one it was
/// read in and not a fixed one.</p>
/// <p>Mutation (Rule 19): the confirm exports in <code>USER</code> whatever the proposal holds -- this goes red.</p>
Method TestAnExportProposedInAnotherNamespaceExportsThatNamespacesMessage()
{
    Set tUser1 = $ClassMethod(..#EXPORTFIXTURE, "Store", "USER", "hl7", "u")
    Set tOther = $ClassMethod(..#EXPORTFIXTURE, "Store", "HSCUSTOM", "chars", "h", "elsewhere text " _ $Parameter(..#EXPORTFIXTURE, "SENTINEL"))
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    Set tArgs = {"Messages": (tOther), "Separator": "LF", "Charset": "UTF8", "rationale": "probe", "expectedImpact": "probe"}
    Set tTool = ..#EXPORTTOOL
    Set tSC = $ClassMethod($ClassMethod(tTool, "MintClass"), "Mint", $Parameter(tTool, "DESCRIPTORCLASS"), $Parameter(tTool, "TOOLNAME"), tUser, "", tTurn, tArgs, $ClassMethod(tTool, "LimitsClass"), .tProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), tOther, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), $ClassMethod(tTool, "ToolClass"))
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tSC, "the export mints in HSCUSTOM: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer, "USER")
    Do $$$AssertEquals(tStatus, 200, "it confirms from a request scoped to USER: " _ $Extract($Get(tRaw), 1, 300))
    Set tBytes = ..BytesOf($Get(tAnswer))
    Do $$$AssertEquals(tBytes, $ZConvert("elsewhere text " _ $Parameter(..#EXPORTFIXTURE, "SENTINEL") _ $Char(10), "O", "UTF8"), "the file is HSCUSTOM's message and nothing of USER's")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC8: the probes of this class, both namespaces' and every body, are gone when a test ends: the fixture reads none left.</p>
Method TestNoProbeIsLeftInEitherNamespaceAfterAnExport()
{
    Set tUser1 = $ClassMethod(..#EXPORTFIXTURE, "Store", "USER", "hl7", "u")
    Set tOther = $ClassMethod(..#EXPORTFIXTURE, "Store", "HSCUSTOM", "binary", "h")
    Do $$$AssertEquals($ClassMethod(..#EXPORTFIXTURE, "Left"), "headers=1/1 bodies=2", "two probes are stored, one in each namespace")
    Do $$$AssertTrue($ClassMethod(..#EXPORTFIXTURE, "DropProbes"), "and dropping them leaves none")
    Do $$$AssertEquals($ClassMethod(..#EXPORTFIXTURE, "Left"), "headers=0/0 bodies=0", "no header and no body is left in either namespace")
}

}
