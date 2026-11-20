/// <p>Pins AD-10's journal judgement for KMIP key activation at startup (Story 21.10; AD-4, AD-10, AD-53, AD-55): KMIP is
/// refused <code>PROHIBITED.STARTUPKMIP</code> with the journal sentence while journal encryption is on in the stored settings,
/// when the same write sets it, while the journal forbids a start without its key, and while that answer cannot be read, on
/// the form's Save (<class>OcuPilot.Test.EncryptionStartupSaveFixture</class>) and at the agent's confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>), each with no <code>PUT</code>, and for the script
/// (<class>OcuPilot.Kernel.Proposal.Draft</class>); a write that hits the databases case too is
/// refused with the databases sentence; and with journal encryption off and the journal free, KMIP is written by both callers.</p>
/// <p><b>No test changes a real startup setting.</b> Every change runs through <class>OcuPilot.Test.EncryptionSeamPort</class>
/// armed <code>kmip</code> or <code>journalstartupfails</code>, which never sends a settings <code>PUT</code>, and AD-10's set
/// reads the seam's settings (<class>OcuPilot.Test.EncryptionStartupProhibited</class>).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because the class creates probe key files and sets the governance policy. Every probe object is
/// removed after each test, and after each test the instance's encryption state reads as that test found it.</p>
Class OcuPilot.Test.EncryptionStartupKmipWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ENCRYPTION_CONFIG";

Parameter PROBE = "OcuPilot.Test.EncryptionStartupProbe";

Parameter SEAM = "OcuPilot.Test.EncryptionSeamPort";

Parameter WRITE = "OcuPilot.Test.EncryptionStartupWrite";

Parameter CONFIRM = "OcuPilot.Test.DatabaseConfirm";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter GOVERNANCEKEY = "security.encryptionstartup.update";

Parameter SERVER = "OCUPROBESTARTKMS";

/// <p>The seam-active key.</p>
Parameter KEYONE = "0CC1C7E0-C0D0-11F1-8A00-0242AC110001";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>Whether <method>OnBeforeAllTests</method> took the policy snapshot; the teardown restores only then.</p>
Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

/// <p>The encryption facts and the audit database's identity before each test.</p>
Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EncryptionStartupKmipWrite creates encryption key files on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#WRITE, "Facts")
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.EncryptionStartupProhibited")
    Kill tSettings
    Set tSettings(..#GOVERNANCEKEY) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "SeedDirectory", .tCreated)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Do $ClassMethod(..#SEAM, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "the probe directory and every probe object are removed")
    Set tFacts = $ClassMethod(..#WRITE, "Facts")
    Do $$$AssertEquals(tFacts, ..PreparedFacts, "no encryption setting moved and the audit database is the one the test found")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>AD-10 as amended 2026-11-15 (DW-2431): KMIP is refused <code>PROHIBITED.STARTUPKMIP</code> with the journal sentence while
/// journal encryption is on in the stored settings, when the same write sets it under KMIP, while the journal forbids a start
/// without its key, and while that answer cannot be read, on the Save and at the confirm, with no <code>PUT</code>; and with the
/// audit log, IRISSECURITY or IRISTEMP encrypted too, the databases sentence is the one answered.</p>
/// <p>Mutation (Rule 19): judge the journal only for Interactive in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.EncryptionStartup</method> -- every leg goes red; drop the databases-first order
/// -- the last leg alone; send the code's default sentence in place of the variant -- every journal leg's sentence assertion;
/// leave <var>pReason</var> unset in <method>OcuPilot.Kernel.Proposal.Draft.Take</method> -- the script leg's sentence alone.</p>
Method TestKmipIsRefusedWhileJournalEncryptionNeedsItsKey()
{
    Set tCode = "PROHIBITED.STARTUPKMIP"
    Set tUnattended = {"DBEncStartMode": "Unattended", "DBEncStartKeyFile": "/ocuprobestart/held.key"}
    Set tJournalHeld = ##class(%DynamicObject).%FromJSON(tUnattended.%ToJSON())
    Do tJournalHeld.%Set("DBEncJournal", 1, "boolean")
    Set tBoth = ##class(%DynamicObject).%FromJSON(tJournalHeld.%ToJSON())
    Do tBoth.%Set("DBEncIRISTemp", 1, "boolean")
    Set tKmipHeld = {"DBEncStartMode": "KMIP", "DBEncStartKMIPServer": (..#SERVER)}
    Set tChoose = {"DBEncStartMode": "KMIP", "DBEncStartKMIPServer": (..#SERVER)}
    Set tJournalReason = $Parameter(..#PROHIBITED, "STARTUPKMIPJOURNALREASON")
    Set tDatabasesReason = $Parameter(..#PROHIBITED, "STARTUPKMIPREASON")
    For tCase = $ListBuild(tJournalHeld.%ToJSON(), tChoose.%ToJSON(), "kmip", 0, "KMIP chosen while journal encryption is on", tJournalReason), $ListBuild(tKmipHeld.%ToJSON(), "{""DBEncJournal"":true}", "kmip", 0, "journal encryption set under KMIP", tJournalReason), $ListBuild(tUnattended.%ToJSON(), tChoose.%ToJSON(), "kmip", 1, "KMIP while the journal forbids a start without its key", tJournalReason), $ListBuild(tUnattended.%ToJSON(), tChoose.%ToJSON(), "journalstartupfails", 0, "KMIP while the journal's answer cannot be read", tJournalReason), $ListBuild(tBoth.%ToJSON(), tChoose.%ToJSON(), "kmip", 0, "KMIP while journal encryption and IRISTEMP are both on", tDatabasesReason) {
        Do $ClassMethod(..#SEAM, "Arm", $List(tCase, 3))
        Do $ClassMethod(..#SEAM, "ArmKmip", ..#SERVER)
        Do $ClassMethod(..#SEAM, "ArmJournalRefused", $List(tCase, 4))
        Do $ClassMethod(..#SEAM, "Hold", "database", [{"Id": (..#KEYONE), "KeyLen": 256, "IsDefault": true}])
        Do $ClassMethod(..#WRITE, "Hold", ##class(%DynamicObject).%FromJSON($List(tCase, 1)))
        Do $ClassMethod(..#SEAM, "ClearCalls")
        Set tChange = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Save", tChange, .tAnswer), "403 " _ tCode, $List(tCase, 5) _ " is refused on the Save: " _ $Extract(tAnswer, 1, 200))
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Parsed", tAnswer, "reason"), $List(tCase, 6), "with its sentence")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Puts"), 0, $List(tCase, 5) _ ": no PUT from the Save")
        Do $ClassMethod(..#WRITE, "Hold", ##class(%DynamicObject).%FromJSON($List(tCase, 1)))
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Propose", tChange, .tProposal), "", $List(tCase, 5) _ " is minted")
        Do $$$AssertEquals(..Confirm(tProposal, .tReason), "403 " _ tCode, $List(tCase, 5) _ " is refused at the confirm")
        Do $$$AssertEquals(tReason, $List(tCase, 6), "with its sentence")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Puts"), 0, $List(tCase, 5) _ ": no PUT from the confirm")
        ; The script's judgement reads through the real port, not the seam, so only the cases decided by the settings alone run it.
        If ($List(tCase, 3) '= "kmip") || ($List(tCase, 4) '= 0) Continue
        Do $ClassMethod(..#WRITE, "Hold", ##class(%DynamicObject).%FromJSON($List(tCase, 1)))
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Propose", tChange, .tDraftProposal), "", $List(tCase, 5) _ " is minted for a script")
        Set tDraftSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(tDraftProposal.%Get("proposalId"), $Username, "http://localhost", .tDraftAnswer, .tDraftHttp, .tDraftCode, .tDraftReason)
        Do $$$AssertEquals(+$Get(tDraftHttp) _ " " _ $Get(tDraftCode), "403 " _ tCode, $List(tCase, 5) _ " is refused for the script")
        Do $$$AssertEquals($Get(tDraftReason), $List(tCase, 6), "with its sentence")
    }
}

/// <p>AD-10 as amended 2026-11-15: with journal encryption off and the journal free to start without its key, KMIP with a
/// configured server is written by the Save and by a confirmed proposal, one <code>PUT</code> each.</p>
/// <p>Mutation (Rule 19): refuse every KMIP write in the journal arm of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.EncryptionStartup</method> -- both legs go red.</p>
Method TestKmipIsWrittenWithJournalEncryptionOffOnBothCallers()
{
    Do $ClassMethod(..#SEAM, "Arm", "kmip")
    Do $ClassMethod(..#SEAM, "ArmKmip", ..#SERVER)
    Do $ClassMethod(..#SEAM, "ArmJournalRefused", 0)
    Do $ClassMethod(..#SEAM, "Hold", "database", [{"Id": (..#KEYONE), "KeyLen": 256, "IsDefault": true}])
    For tCaller = "save", "agent" {
        Do $ClassMethod(..#WRITE, "Hold", {"DBEncStartMode": "None"})
        Do $ClassMethod(..#SEAM, "ClearCalls")
        Set tChange = {"DBEncStartMode": "KMIP", "DBEncStartKMIPServer": (..#SERVER)}
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Change", tCaller, tChange, .tConsequence), "200 ", tCaller _ " writes KMIP with journal encryption off")
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Puts"), 1, tCaller _ ": one PUT")
    }
}

/// <p>Confirm <var>pProposal</var> through <class>OcuPilot.Test.DatabaseConfirm</class> as this process's user, answering
/// <code>http code</code>, with the sentence the refusal carries in <var>pReason</var>.</p>
ClassMethod Confirm(pProposal As %DynamicObject, Output pReason As %String) As %String
{
    Set pReason = ""
    If '$IsObject(pProposal) Quit "no proposal"
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", pProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail, .pReason)
    If $$$ISOK(tSC) && ($Get(tCode) = "") Quit "200 "
    Quit +$Get(tHttp) _ " " _ $Get(tCode)
}

}
