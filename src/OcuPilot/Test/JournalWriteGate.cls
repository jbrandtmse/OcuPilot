/// <p>Pins Story 18.5's journal tools' pairs with least-privileged principals (AD-8, AD-29): a
/// principal lacking one of Journals' two pairs, or one of the directory switch's two further pairs,
/// is refused 403 <code>AUTH.NOPRIVILEGE</code> naming the first pair it lacks, on the screen's action
/// and at the agent's confirm of each tool, with zero port calls; and a principal holding exactly the
/// declared pairs reaches the port on both callers.</p>
/// <p>The legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.JournalWriteGateProbe</class>), which reports what
/// <class>OcuPilot.Test.JournalIntegrityPort</class> was asked; the integrity check is answered by that
/// seam and never sent to the vendor.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, journaling on in a stock
/// configuration (one journal directory), a caller holding <code>%All</code>, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>JOURNALVARIABLE</parameter> reading
/// <code>1</code>: it creates and removes probe principals, switches the journal file first where the
/// list names no closed file (<method>OcuPilot.Test.JournalProbe.EnsureClosedFile</method>), and the
/// floor's file switch switches the instance's journal file.</p>
Class OcuPilot.Test.JournalWriteGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the floor's journal switch.</p>
Parameter JOURNALVARIABLE = "OCUPILOT_ALLOW_JOURNAL";

Parameter PROBE = "OcuPilot.Test.JournalProbe";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.JournalList";

/// <p>The principals, each <code>user:role:resources</code> beyond the install namespace's code read:
/// without <code>%Admin_Operate</code>; without <code>%DB_IRISSYS</code>; with Journals' pairs and
/// <code>%Admin_Manage:USE</code>, lacking the system database's write; with Journals' pairs and that
/// write, lacking <code>%Admin_Manage:USE</code>; and with exactly every declared pair.</p>
Parameter PRINCIPALS = "OCUPROBE185GOP:OCUPROBE185GOPR:%DB_IRISSYS:R,OCUPROBE185GDB:OCUPROBE185GDBR:%Admin_Operate:U,OCUPROBE185GWR:OCUPROBE185GWRR:%Admin_Operate:U;%DB_IRISSYS:R;%Admin_Manage:U,OCUPROBE185GMG:OCUPROBE185GMGR:%Admin_Operate:U;%DB_IRISSYS:RW,OCUPROBE185GFL:OCUPROBE185GFLR:%Admin_Operate:U;%DB_IRISSYS:RW;%Admin_Manage:U";

/// <p>The three tools, each <code>action:class</code>.</p>
Parameter TOOLS = "switchfile:OcuPilot.Screen.Tool.JournalSwitchFile,switchdirectory:OcuPilot.Screen.Tool.JournalSwitchDirectory,integrity:OcuPilot.Screen.Tool.JournalIntegrityCheck";

/// <p>The journal settings found before the class ran.</p>
Property SavedSettings As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedSettings = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#JOURNALVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.JournalWriteGate creates users and roles and switches the journal file on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#JOURNALVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..SavedSettings = $ClassMethod(..#PROBE, "JournalSettings").%ToJSON()
    Set tSC = $ClassMethod(..#PROBE, "EnsureClosedFile", 1)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Length(..#PRINCIPALS, ",") {
        Set tEntry = $Piece(..#PRINCIPALS, ",", tI)
        Set tSC = $ClassMethod(..#PROBE, "SeedPrincipal", $Piece(tEntry, ":", 1), $Piece(tEntry, ":", 2), $Translate($Piece(tEntry, ":", 3, *), ";", ","))
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $ClassMethod(..#PROBE, "RestoreJournal", ##class(%DynamicObject).%FromJSON(..SavedSettings))
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RestoreJournal", ##class(%DynamicObject).%FromJSON(..SavedSettings))
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>AC9: each principal short of a declared pair is refused, on the screen's action and at the
/// agent's confirm of each tool it lacks a pair for, 403 <code>AUTH.NOPRIVILEGE</code> naming the first
/// pair it lacks, with zero port calls; nothing is switched.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Manage:USE</code> from
/// <parameter>OcuPilot.Screen.Tool.JournalSwitchDirectory.EXTRAPAIRS</parameter> -&gt; that principal's
/// directory switch reaches the port and this goes red.</p>
Method TestEachMissingPairIsRefusedByNameBeforeAnyPortCall()
{
    Set tFile = ..ClosedFile()
    Do $$$AssertTrue(tFile '= "", "a closed journal file is listed")
    If tFile = "" Quit
    ; The directory switch is minted only where a second directory is configured.
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedAlternate"), "the probe alternate is configured")
    Set tBefore = $ClassMethod(..#PROBE, "Newest")
    For tCase = $ListBuild(1, "%Admin_Operate:USE", "switchfile,switchdirectory,integrity"), $ListBuild(2, "%DB_IRISSYS:READ", "switchfile,switchdirectory,integrity"), $ListBuild(3, "%DB_IRISSYS:WRITE", "switchdirectory"), $ListBuild(4, "%Admin_Manage:USE", "switchdirectory") {
        Set tUser = ..User($List(tCase, 1))
        Set tActions = $List(tCase, 3)
        Set tPlan = []
        For tI = 1:1:$Length(tActions, ",") {
            Set tAction = $Piece(tActions, ",", tI)
            Do tPlan.%Push(..ActionStep(tAction, tFile))
        }
        For tI = 1:1:$Length(tActions, ",") {
            Set tAction = $Piece(tActions, ",", tI)
            Set tSC = ..Mint(..ToolOf(tAction), tUser, ..TargetOf(tAction, tFile), .tProposal, .tHttp, .tFault)
            Do $$$AssertStatusOK(tSC, tAction _ " is minted for " _ tUser _ ": " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
            Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""))})
        }
        Set tRun = ..RunChild(tUser, tPlan)
        Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
        For tI = 1:1:tPlan.%Size() {
            Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE " _ $List(tCase, 2) _ " calls=0", tUser _ " leg " _ tI _ " (" _ tPlan.%Get(tI - 1).%ToJSON() _ ") is refused naming " _ $List(tCase, 2) _ " before any port call")
        }
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Newest"), tBefore, "and nothing was switched")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreJournal", ##class(%DynamicObject).%FromJSON(..SavedSettings)), "the journal settings found are restored")
}

/// <p>The floor under the refusals' zero: a principal holding exactly every declared pair reaches the
/// port with each tool on the screen's action -- the file switch applied, the directory switch read
/// and refused for the one directory before any switch is sent, the check answered by the seam -- and
/// at the confirm of the file switch.</p>
/// <p>Mutation (Rule 19): drop the one-directory test from
/// <class>OcuPilot.Port.JournalPort</class>'s other-directory read -&gt; the screen sends the switch,
/// the vendor's 409 maps to the same code, and the before-any-switch leg goes red.</p>
Method TestExactlyTheDeclaredPairsReachThePort()
{
    Set tFile = ..ClosedFile()
    If tFile = "" {
        Do $$$AssertTrue(0, "a closed journal file is listed")
        Quit
    }
    Set tUser = ..User(5)
    Set tSC = ..Mint(..ToolOf("switchfile"), tUser, "current", .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the file switch is minted for the principal")
    ; The confirm goes first: the screen's own switch would move the file it was minted against.
    Set tPlan = [{"kind": "confirm", "proposalId": ($Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""))}]
    Do tPlan.%Push(..ActionStep("switchfile", tFile))
    Do tPlan.%Push(..ActionStep("switchdirectory", tFile))
    Do tPlan.%Push(..ActionStep("integrity", tFile))
    Set tRun = ..RunChild(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as the principal")
    Set tLeg = ..Leg(tRun, 1)
    Do $$$AssertTrue($IsObject(tLeg) && (tLeg.%Get("http") = 200) && (tLeg.%Get("types") [ "Journal.Settings/SWITCHFILE"), "the agent's confirmed file switch reaches the port: " _ ..LegText(tRun, 1))
    Set tLeg = ..Leg(tRun, 2)
    Do $$$AssertTrue($IsObject(tLeg) && (tLeg.%Get("http") = 200) && (tLeg.%Get("types") [ "Journal.Settings/SWITCHFILE"), "the screen's file switch reaches the port and is applied: " _ ..LegText(tRun, 2))
    Set tLeg = ..Leg(tRun, 3)
    Do $$$AssertTrue($IsObject(tLeg) && (tLeg.%Get("http") = 409) && (tLeg.%Get("code") = "JOURNAL.SWITCHDIR.NOOTHER") && (tLeg.%Get("calls") > 0), "the screen's directory switch reaches the port's read: " _ ..LegText(tRun, 3))
    Do $$$AssertTrue($IsObject(tLeg) && '(tLeg.%Get("types") [ "Journal.Settings/SWITCHDIR"), "and is refused at that read, before any switch is sent: " _ $Select($IsObject(tLeg): tLeg.%Get("types"), 1: ""))
    Set tLeg = ..Leg(tRun, 4)
    Do $$$AssertTrue($IsObject(tLeg) && (tLeg.%Get("http") = 200) && (tLeg.%Get("types") [ "Journal.File/INTEGRITYCHECK"), "the screen's check reaches the port: " _ ..LegText(tRun, 4))
}

/// <p>A closed journal file the instance lists, or <code>""</code>.</p>
ClassMethod ClosedFile() As %String
{
    Set tRows = ##class(OcuPilot.Test.JournalProbe).Listed()
    If '$IsObject(tRows) || (tRows.%Size() < 2) Quit ""
    Quit tRows.%Get(1).%Get("Name")
}

/// <p>The screen step for <var>pAction</var>: the switches name <code>current</code>, the check
/// <var>pFile</var> with its flag off.</p>
ClassMethod ActionStep(pAction As %String, pFile As %String) As %DynamicObject
{
    Set tStep = {"kind": "action"}
    Do tStep.%Set("action", pAction, "string")
    Do tStep.%Set("id", ..TargetOf(pAction, pFile), "string")
    If pAction = "integrity" Do tStep.%Set("values", {"CheckDetails": "false"})
    Quit tStep
}

/// <p>The target <var>pAction</var> names.</p>
ClassMethod TargetOf(pAction As %String, pFile As %String) As %String
{
    Quit $Select(pAction = "integrity": pFile, 1: "current")
}

/// <p>The tool class of <var>pAction</var>.</p>
ClassMethod ToolOf(pAction As %String) As %String
{
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tEntry = $Piece(..#TOOLS, ",", tI)
        If $Piece(tEntry, ":", 1) = pAction Quit
    }
    Quit $Piece(tEntry, ":", 2)
}

/// <p>Mint <var>pToolClass</var>'s proposal against <var>pId</var> for <var>pUser</var>, read as the
/// caller: the mint itself holds no pair check, which the dispatch gate and the confirm make.</p>
ClassMethod Mint(pToolClass As %String, pUser As %String, pId As %String, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Set tArgs = {}
    Do tArgs.%Set("Name", pId, "string")
    Quit $ClassMethod($ClassMethod(pToolClass, "MintClass"), "Mint", ..#SCREEN, $Parameter(pToolClass, "TOOLNAME"), pUser, "", tTurn, tArgs, "OcuPilot.Kernel.Agent.Limits", .pProposal, .pHttp, .pFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pId, "Name", $ClassMethod(pToolClass, "SettableFields"), pToolClass)
}

/// <p>The principal of entry <var>pIndex</var> of <parameter>PRINCIPALS</parameter>.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $Piece($Piece(..#PRINCIPALS, ",", pIndex), ":", 1)
}

/// <p>Run <class>OcuPilot.Test.JournalWriteGateProbe</class> as <var>pUser</var> over <var>pPlan</var>
/// in a child process and answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod RunChild(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.JournalWriteGateProbe).Run($Job, pUser, tPlan)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 180)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 180 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Who the child ran as, <code>username loggedIn</code>, or its error.</p>
ClassMethod Ran(pRun As %DynamicObject) As %String
{
    If '$IsObject(pRun) Quit "no answer"
    If pRun.%IsDefined("error") Quit pRun.%Get("error")
    Quit pRun.%Get("username") _ " " _ pRun.%Get("loggedIn")
}

/// <p>Step <var>pIndex</var> (from 1) of the child's answer <var>pRun</var>, or <code>""</code>.</p>
ClassMethod Leg(pRun As %DynamicObject, pIndex As %Integer) As %DynamicObject
{
    If '$IsObject(pRun) || (pRun.%GetTypeOf("steps") '= "array") Quit ""
    Quit pRun.%Get("steps").%Get(pIndex - 1)
}

/// <p>Step <var>pIndex</var> as <code>http code failedPair calls=n</code>.</p>
ClassMethod LegText(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    Set tLeg = ..Leg(pRun, pIndex)
    If '$IsObject(tLeg) Quit "absent"
    Quit tLeg.%Get("http") _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair") _ " calls=" _ tLeg.%Get("calls")
}

/// <p><var>pBody</var> as text for an assertion message.</p>
ClassMethod Shown(pBody) As %String
{
    Quit $Select($IsObject(pBody): pBody.%ToJSON(), 1: $Get(pBody))
}

}
