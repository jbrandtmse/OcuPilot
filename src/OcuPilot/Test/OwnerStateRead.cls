/// <p>AD-9's read gate for the proposal and ledger stores and for <code>Base</code>'s three public reads, as real
/// principals meet it. A principal holding <code>%Development:USE</code> and no <code>OcuPilotAdmin</code> is
/// refused <code>ERROR #822</code>, with no value of the row reaching it, by every key, token, id and user read of
/// another user's proposal and ledger rows and by <code>Base</code>'s opens of another user's rows; it reads its own
/// rows, an administrator without <code>%All</code> reads anyone's, a row that does not exist answers as it did, and
/// the confirm, cancel, draft, claim and transcript-gate paths answer a non-owner the status and code they did.</p>
/// <p>The calls run in a child process logged in as each principal
/// (<class>OcuPilot.Test.OwnerStateReadProbe</class>); the rows are seeded and read back here by SQL, as the suite's
/// own <code>%All</code> identity.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes two users and
/// two roles and writes turns, conversations, proposals and ledger rows. <method>OnBeforeAllTests</method> refuses
/// anywhere it does not. Every row it seeds names a user or key starting with <code>OcuPilotOwnerRead</code>, removed
/// after each test.</p>
Class OcuPilot.Test.OwnerStateRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.OwnerStateReadProbe";

Parameter STOREPACKAGE = "OcuPilot.Kernel.State.";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>Holds <code>%Development:USE</code> and the install namespace's code read, and nothing else.</p>
Parameter DEVUSER = "OcuPilotOwnerReadDev";

Parameter DEVROLE = "OcuPilotOwnerReadDevRole";

/// <p>Holds <code>OcuPilotAdmin:USE</code> and the install namespace's code read, and no <code>%All</code>.</p>
Parameter ADMINUSER = "OcuPilotOwnerReadAdmin";

Parameter ADMINROLE = "OcuPilotOwnerReadAdminRole";

/// <p>The user name whose rows the developer reads. No account has it.</p>
Parameter VICTIM = "OcuPilotOwnerReadVictim";

/// <p>The window, in hours, a windowed ledger read names.</p>
Parameter WINDOW = 24;

/// <p>The rows seeded for one test, by what they are: <code>victim*</code> and <code>own*</code> carry the keys and
/// the stored ids of the victim's and the developer's rows.</p>
Property PreparedIds As %DynamicObject;

Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedIds = {}
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OwnerStateRead creates and deletes users and roles and writes OcuPilot's stores on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotOwnerRead" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ##class(OcuPilot.Test.AdminStateWrite).EnsurePrincipals(..PreparedPassword, ..Cases())
}

Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.AdminStateWrite).RemovePrincipals(..Cases(), "OcuPilot.Test.OwnerStateRead")
}

/// <p>Remove what an earlier test left and seed the rows the legs read.</p>
Method OnBeforeOneTest() As %Status
{
    Do ..Clean()
    Quit ..Seed()
}

Method OnAfterOneTest() As %Status
{
    Do ..Clean()
    Do $$$AssertEquals(..LeftOver(), 0, "no row of this class survives the test")
    Quit $$$OK
}

/// <p>The principals, as <method>OcuPilot.Test.AdminStateWrite.EnsurePrincipals</method> takes them.</p>
ClassMethod Cases() As %List
{
    Quit $ListBuild($ListBuild(..#DEVUSER, ..#DEVROLE, "%Development:U", 0), $ListBuild(..#ADMINUSER, ..#ADMINROLE, "OcuPilotAdmin:U", 1))
}

/// <p>Delete every row of the stores this class reads that names the victim or the developer.</p>
ClassMethod Clean()
{
    Set tPackage = "OcuPilot_Kernel_State."
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM " _ tPackage _ "Step WHERE TurnKey IN (SELECT TurnKey FROM " _ tPackage _ "Turn WHERE UserName IN (?, ?))", ..#VICTIM, ..#DEVUSER)
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM " _ tPackage _ "Entry WHERE ConvoKey IN (SELECT ConvKey FROM " _ tPackage _ "Convo WHERE UserName IN (?, ?))", ..#VICTIM, ..#DEVUSER)
    For tTable = "Proposal", "Ledger", "Turn", "Convo" {
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM " _ tPackage _ tTable _ " WHERE UserName IN (?, ?)", ..#VICTIM, ..#DEVUSER)
    }
}

/// <p>How many rows of the stores this class seeds survive <method>Clean</method>: the rows that name either user,
/// and the steps and entries of the turns and conversations this test seeded.</p>
Method LeftOver() As %Integer
{
    Set tCount = 0
    For tTable = "Proposal", "Ledger", "Turn", "Convo" {
        Set tCount = tCount + ..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State." _ tTable _ " WHERE UserName IN ('" _ ..#VICTIM _ "', '" _ ..#DEVUSER _ "')")
    }
    For tWho = "victim", "own" {
        If ..PreparedIds.%Get(tWho _ "Turn") '= "" Set tCount = tCount + ..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ?", ..PreparedIds.%Get(tWho _ "Turn"))
        If ..PreparedIds.%Get(tWho _ "Conv") '= "" Set tCount = tCount + ..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ?", ..PreparedIds.%Get(tWho _ "Conv"))
    }
    Quit tCount
}

/// <p>Seed, as the suite's own identity, one turn with a step, one conversation with an entry, one proposal and two
/// ledger rows (one an overflow row) for the victim and the same for the developer, and remember the keys and the
/// stored ids.</p>
Method Seed() As %Status
{
    Set tSC = $$$OK
    For tWho = "victim", "own" {
        Set tUser = $Select(tWho = "victim": ..#VICTIM, 1: ..#DEVUSER)
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .tTurn))
        Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", tUser, 5, .tConvoSC, .tConflict)
        Set tSC = $$$ADDSC(tSC, tConvoSC)
        If '$IsObject(tConvo) Continue
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, "hello", "completed", "a reply", "", 0, [], 0, ..#LIMITS, tTurn))
        Set tConv = tConvo.ConvKey
        Set tConvo = ""
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Step).GuardedAppend(tTurn, "announce", "shell.screen.open", "running", "", "", "", ..#LIMITS, .tSeq, .tStored, "tasks/schedule"))
        Kill tValues
        Set tValues("user") = tUser
        Set tValues("convKey") = tConv
        Set tValues("turnKey") = tTurn
        Set tValues("toolName") = "webapp.list.update"
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", "/csp/ocupilotownerread" _ tWho, .tTarget))
        Set tValues("targetRef") = tTarget
        Set tValues("fingerprint") = "0"
        Set tValues("arguments") = "{""secret"":""" _ tWho _ "-arguments""}"
        Set tValues("payload") = "{}"
        Set tValues("diff") = "[]"
        Set tValues("unchangedCount") = 0
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Propose).GuardedMint(.tValues, ..#LIMITS, .tProposal, .tToken, .tExpiresAt))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Ledger).GuardedAppend(tTurn, tUser, "probe", "tool", "probe." _ tWho, "", "", "{""secret"":""" _ tWho _ "-ledger""}", 0, "ok", "", 0, 0, "", ..#LIMITS, .tSeq, .tStored, 0, "", .tLedger))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Ledger).GuardedCountOverflow(tTurn, tUser, "", .tDropped))
        Do ..PreparedIds.%Set(tWho _ "Turn", tTurn, "string")
        Do ..PreparedIds.%Set(tWho _ "Conv", tConv, "string")
        Do ..PreparedIds.%Set(tWho _ "Proposal", tProposal, "string")
        Do ..PreparedIds.%Set(tWho _ "Token", tToken, "string")
        Do ..PreparedIds.%Set(tWho _ "LedgerKey", tLedger, "string")
        Do ..PreparedIds.%Set(tWho _ "TurnId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = ?", tTurn), "string")
        Do ..PreparedIds.%Set(tWho _ "ConvoId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(ConvKey) = ?", tConv), "string")
        Do ..PreparedIds.%Set(tWho _ "StepId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ?", tTurn), "string")
        Do ..PreparedIds.%Set(tWho _ "EntryId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ?", tConv), "string")
        Do ..PreparedIds.%Set(tWho _ "ProposalId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", tProposal), "string")
        Do ..PreparedIds.%Set(tWho _ "LedgerId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(LedgerKey) = ?", tLedger), "string")
    }
    Quit tSC
}

/// <p>The first column of the first row <var>pSql</var> answers when bound to <var>pValue</var>, or
/// <code>""</code>.</p>
ClassMethod Stored(pSql As %String, pValue As %String = "") As %String
{
    If pValue = "" {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql)
    } Else {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pValue)
    }
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit ""
    Quit tRS.%GetData(1)
}

/// <p>The rows this class seeds as one string: each row is its columns joined by <code>~</code>. A refused or
/// answered read changes none of them.</p>
ClassMethod Fingerprint() As %String
{
    Set tText = ""
    Set tPackage = "OcuPilot_Kernel_State."
    Set tUsers = "('" _ ..#VICTIM _ "', '" _ ..#DEVUSER _ "')"
    Set tQueries = $ListBuild("SELECT ID, ProposalKey, UserName, State, Burned, ClosedReason, RowVersion FROM " _ tPackage _ "Proposal WHERE UserName IN " _ tUsers _ " ORDER BY ID", "SELECT ID, LedgerKey, UserName, Status, Seq, Dropped, RowVersion FROM " _ tPackage _ "Ledger WHERE UserName IN " _ tUsers _ " ORDER BY ID", "SELECT ID, TurnKey, UserName, State, RowVersion FROM " _ tPackage _ "Turn WHERE UserName IN " _ tUsers _ " ORDER BY ID", "SELECT ID, ConvKey, UserName, RowVersion FROM " _ tPackage _ "Convo WHERE UserName IN " _ tUsers _ " ORDER BY ID")
    For tI = 1:1:$ListLength(tQueries) {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, $List(tQueries, tI))
        If tRS.%SQLCODE < 0 {
            Set tText = tText _ "[query " _ tI _ " failed " _ tRS.%SQLCODE _ "]"
            Continue
        }
        Set tText = tText _ "[" _ tI
        While tRS.%Next() {
            Set tText = tText _ "{"
            For tC = 1:1:tRS.%ResultColumnCount {
                Set tText = tText _ $Select(tC = 1: "", 1: "~") _ tRS.%GetData(tC)
            }
            Set tText = tText _ "}"
        }
        Set tText = tText _ "]"
    }
    Quit tText
}

/// <p>The reads of <var>pWho</var>'s (<code>victim</code> or <code>own</code>) proposal through every public path
/// that takes its key, its token, its id or its owner: the proposal store's own reads and <code>Base</code>'s three
/// public reads.</p>
Method ProposalReads(pWho As %String) As %DynamicArray
{
    Set tUser = $Select(pWho = "victim": ..#VICTIM, 1: ..#DEVUSER)
    Set tIds = ..PreparedIds
    Set tSteps = []
    Do tSteps.%Push({"kind": "OwnerRead.Propose.GuardedByKey", "key": (tIds.%Get(pWho _ "Proposal"))})
    Do tSteps.%Push({"kind": "OwnerRead.Propose.GuardedByToken", "token": (tIds.%Get(pWho _ "Token"))})
    Do tSteps.%Push({"kind": "OwnerRead.Propose.GuardedRowVersion", "key": (tIds.%Get(pWho _ "Proposal"))})
    Do tSteps.%Push({"kind": "OwnerRead.Propose.GuardedRowsForTurn", "turnKey": (tIds.%Get(pWho _ "Turn")), "user": (tUser)})
    Do tSteps.%Push({"kind": "OwnerRead.Propose.GuardedRowsForConvo", "convKey": (tIds.%Get(pWho _ "Conv")), "user": (tUser)})
    Do tSteps.%Push({"kind": "OwnerRead.Propose.GuardedCountForTurn", "turnKey": (tIds.%Get(pWho _ "Turn"))})
    Do tSteps.%Push({"kind": "OwnerRead.Open", "store": "Propose", "id": (tIds.%Get(pWho _ "ProposalId"))})
    Do tSteps.%Push({"kind": "OwnerRead.Exists", "store": "Propose", "id": (tIds.%Get(pWho _ "ProposalId"))})
    Do tSteps.%Push({"kind": "OwnerRead.Open", "store": "Base", "id": (tIds.%Get(pWho _ "ProposalId"))})
    Do tSteps.%Push({"kind": "OwnerRead.Exists", "store": "Base", "id": (tIds.%Get(pWho _ "ProposalId"))})
    Do tSteps.%Push({"kind": "OwnerRead.StoredValue", "store": "Propose", "method": "ProposalKeyIdxExists", "key": (tIds.%Get(pWho _ "Proposal")), "property": "TargetRef"})
    Do tSteps.%Push({"kind": "OwnerRead.StoredValue", "store": "Propose", "method": "ProposalKeyIdxExists", "key": (tIds.%Get(pWho _ "Proposal")), "property": "UserName"})
    Quit tSteps
}

/// <p>The reads of <var>pWho</var>'s ledger rows through every public path that takes a key, an id or a user:
/// the ledger store's own reads (the windowed reads once by the keyed form and once by the window) and
/// <code>Base</code>'s three public reads.</p>
Method LedgerReads(pWho As %String) As %DynamicArray
{
    Set tUser = $Select(pWho = "victim": ..#VICTIM, 1: ..#DEVUSER)
    Set tIds = ..PreparedIds
    Set tSteps = []
    Do tSteps.%Push({"kind": "OwnerRead.Ledger.GuardedRow", "id": (tIds.%Get(pWho _ "LedgerId"))})
    Do tSteps.%Push({"kind": "OwnerRead.Ledger.GuardedIdsForWindow", "user": (tUser), "window": 0, "turnKey": (tIds.%Get(pWho _ "Turn")), "all": 0})
    Do tSteps.%Push({"kind": "OwnerRead.Ledger.GuardedIdsForWindow", "user": (tUser), "window": (..#WINDOW), "turnKey": "", "all": 0})
    Do tSteps.%Push({"kind": "OwnerRead.Ledger.GuardedDroppedFor", "user": (tUser), "window": 0, "turnKey": (tIds.%Get(pWho _ "Turn")), "all": 0})
    Do tSteps.%Push({"kind": "OwnerRead.Ledger.GuardedDroppedFor", "user": (tUser), "window": (..#WINDOW), "turnKey": "", "all": 0})
    Do tSteps.%Push({"kind": "OwnerRead.Ledger.GuardedCountForTurn", "turnKey": (tIds.%Get(pWho _ "Turn"))})
    Do tSteps.%Push({"kind": "OwnerRead.Open", "store": "Ledger", "id": (tIds.%Get(pWho _ "LedgerId"))})
    Do tSteps.%Push({"kind": "OwnerRead.Exists", "store": "Ledger", "id": (tIds.%Get(pWho _ "LedgerId"))})
    Do tSteps.%Push({"kind": "OwnerRead.Open", "store": "Base", "id": (tIds.%Get(pWho _ "LedgerId"))})
    Do tSteps.%Push({"kind": "OwnerRead.StoredValue", "store": "Ledger", "method": "LedgerKeyIdxExists", "key": (tIds.%Get(pWho _ "LedgerKey")), "property": "Name"})
    Quit tSteps
}

/// <p>The reads that name another store's row owned by <var>pWho</var>: a turn, a step (whose owner is its turn's),
/// a conversation and an entry (whose owner is its conversation's), through <code>Base</code>'s three public reads,
/// and the turn and the entry opened through <code>Base</code> itself, whose extent holds every store's rows.</p>
Method BaseReads(pWho As %String) As %DynamicArray
{
    Set tIds = ..PreparedIds
    Set tSteps = []
    For tStore = "Turn", "Step", "Convo", "Entry" {
        Do tSteps.%Push({"kind": "OwnerRead.Open", "store": (tStore), "id": (tIds.%Get(pWho _ tStore _ "Id"))})
        Do tSteps.%Push({"kind": "OwnerRead.Exists", "store": (tStore), "id": (tIds.%Get(pWho _ tStore _ "Id"))})
    }
    Do tSteps.%Push({"kind": "OwnerRead.Open", "store": "Base", "id": (tIds.%Get(pWho _ "TurnId"))})
    Do tSteps.%Push({"kind": "OwnerRead.Open", "store": "Base", "id": (tIds.%Get(pWho _ "EntryId"))})
    Do tSteps.%Push({"kind": "OwnerRead.StoredValue", "store": "Turn", "method": "TurnKeyIdxExists", "key": (tIds.%Get(pWho _ "Turn")), "property": "State"})
    Do tSteps.%Push({"kind": "OwnerRead.StoredValue", "store": "Convo", "method": "ConvKeyIdxExists", "key": (tIds.%Get(pWho _ "Conv")), "property": "UserName"})
    Quit tSteps
}

/// <p>Append <var>pMore</var>'s steps to <var>pSteps</var>.</p>
ClassMethod Concat(pSteps As %DynamicArray, pMore As %DynamicArray)
{
    For tI = 0:1:pMore.%Size() - 1 Do pSteps.%Push(pMore.%Get(tI))
}

/// <p>Assert that <var>pRun</var> logged in as <var>pUser</var>.</p>
Method AssertPrincipal(pRun As %DynamicObject, pUser As %String, pHoldsAdmin As %Boolean)
{
    Do $$$AssertEquals(pRun.%Get("username") _ "|" _ pRun.%Get("holdsAdmin") _ "|" _ (pRun.%Get("roles") [ "%All"), pUser _ "|" _ pHoldsAdmin _ "|0", "the child runs as " _ pUser _ " with" _ $Select(pHoldsAdmin: "", 1: "out") _ " OcuPilotAdmin and without %All")
}

/// <p>Assert that every leg of <var>pPlan</var> was answered by <var>pRun</var>, refused <code>822</code>, and handed back nothing.</p>
Method AssertAllRefused(pRun As %DynamicObject, pWhat As %String, pPlan As %DynamicArray)
{
    Set tLegs = $Select(pRun.%GetTypeOf("steps") = "array": pRun.%Get("steps"), 1: [])
    Do $$$AssertEquals(tLegs.%Size(), pPlan.%Size(), pWhat _ ": the child answered every leg of its plan" _ $Select(pRun.%IsDefined("error"): ": " _ pRun.%Get("error"), 1: ""))
    For tI = 1:1:tLegs.%Size() {
        Set tLeg = tLegs.%Get(tI - 1)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(pRun, tI), tLeg.%Get("kind") _ " ok=0 code=822", pWhat _ " leg " _ tI _ " is refused 822: " _ tLeg.%Get("text"))
        Do $$$AssertEquals(tLeg.%Get("seen"), "", pWhat _ " leg " _ tI _ " (" _ tLeg.%Get("kind") _ ") hands back no value of the row")
    }
}

/// <p>Assert that every leg of <var>pPlan</var> was answered by <var>pRun</var> and handed back a value of the row.</p>
Method AssertAllAnswered(pRun As %DynamicObject, pWhat As %String, pPlan As %DynamicArray)
{
    Set tLegs = $Select(pRun.%GetTypeOf("steps") = "array": pRun.%Get("steps"), 1: [])
    Do $$$AssertEquals(tLegs.%Size(), pPlan.%Size(), pWhat _ ": the child answered every leg of its plan" _ $Select(pRun.%IsDefined("error"): ": " _ pRun.%Get("error"), 1: ""))
    For tI = 1:1:tLegs.%Size() {
        Set tLeg = tLegs.%Get(tI - 1)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(pRun, tI), tLeg.%Get("kind") _ " ok=1 code=", pWhat _ " leg " _ tI _ " is answered: " _ tLeg.%Get("text"))
        Do $$$AssertTrue(tLeg.%Get("seen") '= "", pWhat _ " leg " _ tI _ " (" _ tLeg.%Get("kind") _ ") hands back a value of the row")
    }
}

/// <p>A developer -- <code>%Development:USE</code>, no <code>OcuPilotAdmin</code> -- reads another user's proposal
/// through the store's key, token, version, turn, conversation and count reads and through <code>Base</code>'s
/// opens, the opens through <code>Base</code> itself included. Each is refused <code>822</code>, hands back no value, and
/// the rows read as they did.</p>
/// <p>Mutation (Rule 19): <code>RowReadRefused</code> removed from <code>Propose.GuardedByKey</code> -> its leg goes
/// red; the owner check removed from <code>Base.GuardedOpenId</code> -> the open legs go red; it read from the class
/// called rather than the row's -> the <code>Base</code> open leg goes red.</p>
Method TestADeveloperIsRefusedEveryReadOfAnotherUsersProposal()
{
    Set tBefore = ..Fingerprint()
    Set tPlan = ..ProposalReads("victim")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllRefused(tRun, "the victim's proposal", tPlan)
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>A developer who names another user in a per-turn or per-conversation proposal read, or names its own user and
/// another user's turn or conversation (a ledger count also takes a conversation key), is refused <code>822</code> and
/// hands back nothing.</p>
/// <p>Mutation (Rule 19): the user check removed from <code>Propose.GuardedRowsForTurn</code> or
/// <code>GuardedRowsForConvo</code> -> the legs that name the victim go red; the turn or conversation owner check
/// removed -> the legs that name the developer go red.</p>
Method TestADeveloperIsRefusedAReadNamingAnotherUsersKey()
{
    Set tBefore = ..Fingerprint()
    Set tPlan = []
    Do tPlan.%Push({"kind": "OwnerRead.Propose.GuardedRowsForTurn", "turnKey": "OcuPilotOwnerReadNone", "user": (..#VICTIM)})
    Do tPlan.%Push({"kind": "OwnerRead.Propose.GuardedRowsForConvo", "convKey": "OcuPilotOwnerReadNone", "user": (..#VICTIM)})
    Do tPlan.%Push({"kind": "OwnerRead.Propose.GuardedRowsForTurn", "turnKey": (..PreparedIds.%Get("ownTurn")), "user": (..#VICTIM)})
    Do tPlan.%Push({"kind": "OwnerRead.Propose.GuardedRowsForConvo", "convKey": (..PreparedIds.%Get("ownConv")), "user": (..#VICTIM)})
    Do tPlan.%Push({"kind": "OwnerRead.Propose.GuardedRowsForTurn", "turnKey": (..PreparedIds.%Get("victimTurn")), "user": (..#DEVUSER)})
    Do tPlan.%Push({"kind": "OwnerRead.Propose.GuardedRowsForConvo", "convKey": (..PreparedIds.%Get("victimConv")), "user": (..#DEVUSER)})
    Do tPlan.%Push({"kind": "OwnerRead.Ledger.GuardedCountForTurn", "turnKey": (..PreparedIds.%Get("victimConv"))})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllRefused(tRun, "a read naming the victim", tPlan)
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>A developer reads another user's ledger rows through the store's row, window, dropped-count and count reads and
/// through <code>Base</code>'s opens. Each is refused <code>822</code> with no value.</p>
/// <p>Mutation (Rule 19): the user check removed from <code>Ledger.GuardedIdsForWindow</code> or
/// <code>GuardedDroppedFor</code> -> that leg goes red; the turn check removed from
/// <code>Ledger.GuardedCountForTurn</code> -> the count leg goes red.</p>
Method TestADeveloperIsRefusedEveryReadOfAnotherUsersLedgerRows()
{
    Set tBefore = ..Fingerprint()
    Set tPlan = ..LedgerReads("victim")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllRefused(tRun, "the victim's ledger rows", tPlan)
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>A developer reads another user's turn, step (owned through its turn), conversation and entry (owned through
/// its conversation) through
/// <code>Base</code>'s three public reads. Each is refused <code>822</code> with no value.</p>
/// <p>Mutation (Rule 19): the owner check removed from <code>Base.GuardedOpenId</code> or
/// <code>GuardedExistsId</code> -> the open or existence legs go red.</p>
Method TestADeveloperIsRefusedBaseReadsOfAnotherUsersOtherRows()
{
    Set tBefore = ..Fingerprint()
    Set tPlan = ..BaseReads("victim")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllRefused(tRun, "the victim's turn, step, conversation and entry", tPlan)
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>A developer asking the ledger for every user's rows, or for a window of another user's, is refused
/// <code>822</code> with no value.</p>
/// <p>Mutation (Rule 19): <code>Ledger.GuardedIdsForWindow</code> serves <code>pAllUsers</code> to any caller ->
/// its all-users legs go red.</p>
Method TestADeveloperIsRefusedTheLedgerAcrossEveryUser()
{
    Set tBefore = ..Fingerprint()
    Set tPlan = []
    Do tPlan.%Push({"kind": "OwnerRead.Ledger.GuardedIdsForWindow", "user": (..#DEVUSER), "window": (..#WINDOW), "turnKey": "", "all": 1})
    Do tPlan.%Push({"kind": "OwnerRead.Ledger.GuardedIdsForWindow", "user": (..#VICTIM), "window": (..#WINDOW), "turnKey": "", "all": 1})
    Do tPlan.%Push({"kind": "OwnerRead.Ledger.GuardedIdsForWindow", "user": (..#DEVUSER), "window": 0, "turnKey": (..PreparedIds.%Get("victimTurn")), "all": 1})
    Do tPlan.%Push({"kind": "OwnerRead.Ledger.GuardedDroppedFor", "user": (..#DEVUSER), "window": (..#WINDOW), "turnKey": "", "all": 1})
    Do tPlan.%Push({"kind": "OwnerRead.Ledger.GuardedDroppedFor", "user": (..#VICTIM), "window": (..#WINDOW), "turnKey": "", "all": 1})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllRefused(tRun, "the ledger across users", tPlan)
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>The developer reads its own proposal, ledger rows, turn, step and conversation through every read the
/// refusal tests call, and each answers a value of the row.</p>
/// <p>Mutation (Rule 19): the owner check refuses an owner -> every leg goes red.</p>
Method TestAnOwnerReadsItsOwnRows()
{
    Set tPlan = ..ProposalReads("own")
    Do ..Concat(tPlan, ..LedgerReads("own"))
    Do ..Concat(tPlan, ..BaseReads("own"))
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllAnswered(tRun, "the developer's own rows", tPlan)
}

/// <p>An administrator -- <code>OcuPilotAdmin:USE</code>, no <code>%All</code> -- reads the victim's proposal,
/// ledger rows, turn, step and conversation, and the ledger across every user.</p>
/// <p>Mutation (Rule 19): <code>Ledger.WindowReadRefused</code> refuses an administrator's read across every user ->
/// the two all-users legs go red.</p>
Method TestAnAdministratorReadsAnotherUsersRows()
{
    Set tPlan = ..ProposalReads("victim")
    Do ..Concat(tPlan, ..LedgerReads("victim"))
    Do ..Concat(tPlan, ..BaseReads("victim"))
    Do tPlan.%Push({"kind": "OwnerRead.Ledger.GuardedIdsForWindow", "user": (..#ADMINUSER), "window": (..#WINDOW), "turnKey": "", "all": 1})
    Do tPlan.%Push({"kind": "OwnerRead.Ledger.GuardedDroppedFor", "user": (..#ADMINUSER), "window": (..#WINDOW), "turnKey": "", "all": 1})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    Do ..AssertAllAnswered(tRun, "the victim's rows read by an administrator", tPlan)
}

/// <p>A row that does not exist answers a non-owner as it answers anyone: an open fails without the refusal, an
/// existence check answers no, a stored value and a key or token read answer not found.</p>
/// <p>Mutation (Rule 19): a missing row refused 822 by the gate -> the open, existence and stored-value legs go
/// red.</p>
Method TestARowThatDoesNotExistAnswersAsItDid()
{
    Set tPlan = []
    Do tPlan.%Push({"kind": "OwnerRead.Open", "store": "Propose", "id": 999999999})
    Do tPlan.%Push({"kind": "OwnerRead.Exists", "store": "Propose", "id": 999999999})
    Do tPlan.%Push({"kind": "OwnerRead.StoredValue", "store": "Propose", "method": "ProposalKeyIdxExists", "key": "OcuPilotOwnerReadNone", "property": "TargetRef"})
    Do tPlan.%Push({"kind": "OwnerRead.Propose.GuardedByKey", "key": "OcuPilotOwnerReadNone"})
    Do tPlan.%Push({"kind": "OwnerRead.Propose.GuardedByToken", "token": "OcuPilotOwnerReadNone"})
    Do tPlan.%Push({"kind": "OwnerRead.Propose.GuardedRowVersion", "key": "OcuPilotOwnerReadNone"})
    Do tPlan.%Push({"kind": "OwnerRead.Ledger.GuardedRow", "id": 999999999})
    Do tPlan.%Push({"kind": "OwnerRead.Open", "store": "Ledger", "id": 999999999})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Set tLegs = $Select(tRun.%GetTypeOf("steps") = "array": tRun.%Get("steps"), 1: [])
    Do $$$AssertEquals(tLegs.%Size(), tPlan.%Size(), "the child answered every leg" _ $Select(tRun.%IsDefined("error"): ": " _ tRun.%Get("error"), 1: ""))
    Set tOpen = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1)
    Do $$$AssertTrue($IsObject(tOpen) && ('tOpen.%Get("ok")) && (tOpen.%Get("code") '= "822"), "an open of a missing proposal fails as not found, not as a refusal: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 2), "OwnerRead.Exists ok=1 code=", "an existence check of a missing proposal answers")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 2).%Get("exists"), 0, "it says the row is not there")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 3), "OwnerRead.StoredValue ok=1 code=", "a stored value of a missing key answers")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 3).%Get("found"), 0, "and says nothing was found")
    For tI = 4:1:7 {
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tI).%Get("ok"), 1, "the key, token, version and ledger-row reads of a missing row answer: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tI).%Get("seen"), "", "and hand back nothing")
    }
    Set tOpen = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 8)
    Do $$$AssertTrue($IsObject(tOpen) && ('tOpen.%Get("ok")) && (tOpen.%Get("code") '= "822"), "an open of a missing ledger row fails as not found: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 8))
}

/// <p>The paths a database does not open to the developer stay closed whatever the store checks: a direct open of
/// another user's row and a direct query of the protected table fail, and a stream of the developer's own
/// opened row cannot be read outside the store's frame.</p>
/// <p>Mutation (Rule 19): none of its own; it is the control the read gate is measured against.</p>
Method TestTheDatabaseRefusesTheDirectPaths()
{
    Do $$$AssertTrue((..PreparedIds.%Get("victimProposalId") '= "") && (..PreparedIds.%Get("victimLedgerId") '= "") && (..PreparedIds.%Get("ownProposalId") '= ""), "the rows the control names were seeded")
    Set tPlan = []
    Do tPlan.%Push({"kind": "Direct.OpenId", "store": "Propose", "id": (..PreparedIds.%Get("victimProposalId"))})
    Do tPlan.%Push({"kind": "Direct.OpenId", "store": "Ledger", "id": (..PreparedIds.%Get("victimLedgerId"))})
    Do tPlan.%Push({"kind": "Direct.Sql", "table": "Proposal"})
    Do tPlan.%Push({"kind": "Direct.Sql", "table": "Ledger"})
    Do tPlan.%Push({"kind": "Held.Stream", "id": (..PreparedIds.%Get("ownProposalId"))})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Set tLegs = $Select(tRun.%GetTypeOf("steps") = "array": tRun.%Get("steps"), 1: [])
    Do $$$AssertEquals(tLegs.%Size(), tPlan.%Size(), "the child answered every leg" _ $Select(tRun.%IsDefined("error"): ": " _ tRun.%Get("error"), 1: ""))
    For tI = 1:1:tLegs.%Size() {
        Set tLeg = tLegs.%Get(tI - 1)
        Do $$$AssertTrue('tLeg.%Get("ok") && (tLeg.%Get("seen") = ""), tLeg.%Get("kind") _ " leg " _ tI _ " is refused and hands back nothing: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI) _ " seen=" _ tLeg.%Get("seen"))
    }
    Set tHeld = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 5)
    Do $$$AssertTrue($IsObject(tHeld) && tHeld.%Get("opened"), "the developer opened its own proposal, so the stream read is what was refused")
}

/// <p>A developer holds its own proposal with the arguments pointed at another user's stored arguments and reads its
/// own proposal: the read is refused <code>822</code> and hands back nothing, and the rows read as they did. An open
/// returns the object the caller holds, so the store reads only the stream the row stores.</p>
/// <p>Mutation (Rule 19): the stored-stream comparison removed from <code>Base.GuardedStreamText</code> -> this goes
/// red with the victim's arguments.</p>
Method TestAHeldRowCannotReadAnotherRowsStream()
{
    Set tVictim = ##class(OcuPilot.Kernel.State.Propose).%OpenId(..PreparedIds.%Get("victimProposalId"))
    Do $$$AssertTrue($IsObject(tVictim), "the victim's proposal was seeded")
    Set tStream = $Select($IsObject(tVictim): tVictim.ArgumentsGetObjectId(), 1: "")
    Set tVictim = ""
    Do $$$AssertTrue(tStream '= "", "and stores its arguments as a stream")
    Set tBefore = ..Fingerprint()
    Set tPlan = [].%Push({"kind": "Held.StreamSwap", "id": (..PreparedIds.%Get("ownProposalId")), "key": (..PreparedIds.%Get("ownProposal")), "stream": (tStream)})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do $$$AssertTrue(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1).%Get("opened"), "the developer holds its own proposal: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do ..AssertAllRefused(tRun, "a held proposal pointed at the victim's arguments", tPlan)
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>A developer opens its own proposal, marks it confirmed in memory and saves it through <code>Base</code>'s two
/// public saves: each is refused <code>822</code> and the row reads as it did. An owner store's rows are written
/// through its own writers; <code>Base</code>'s public saves serve an administrator only.</p>
/// <p>Mutation (Rule 19): <code>Base.PublicSaveRefused</code> answers <code>$$$OK</code> for an owner store -> this goes
/// red.</p>
Method TestADeveloperCannotSaveItsOwnProposalThroughBase()
{
    Set tBefore = ..Fingerprint()
    Set tPlan = []
    Do tPlan.%Push({"kind": "Held.BaseSave", "id": (..PreparedIds.%Get("ownProposalId")), "via": "save"})
    Do tPlan.%Push({"kind": "Held.BaseSave", "id": (..PreparedIds.%Get("ownProposalId")), "via": "saveIfCurrent"})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    For tI = 1:1:2 {
        Do $$$AssertTrue(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tI).%Get("opened"), "the developer opens its own proposal: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, tI), "Held.BaseSave ok=0 code=822", "and the public save of it is refused: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
    }
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>A developer counts an overflow on another user's turn key after the turn is gone and its ledger rows and proposal
/// are kept (a ledger row outlives its turn): the count is refused <code>822</code> and answers no count, the counts of
/// the ledger rows and proposals kept under that key answer 0, and the rows read as they did.</p>
/// <p>Mutation (Rule 19): <code>Ledger.GuardedCountOverflow</code> keeps its count on a refusal, or the unnamed-key
/// answer is removed from <code>Ledger.GuardedCountForTurn</code> or <code>Propose.GuardedCountForTurn</code> -> that
/// leg goes red.</p>
Method TestACountOnAnotherUsersOrphanedLedgerAnswersNothing()
{
    Set tTurn = ..PreparedIds.%Get("victimTurn")
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ?", tTurn)
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = ?", tTurn)
    Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = ?", tTurn), 0, "the victim's turn is gone")
    Do $$$AssertEquals(..Stored("SELECT Dropped FROM OcuPilot_Kernel_State.Ledger WHERE Seq = 0 AND %EXACT(TurnKey) = ?", tTurn), 1, "and its overflow row is kept")
    Set tBefore = ..Fingerprint()
    Do $$$AssertTrue(..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(TurnKey) = ?", tTurn) > 0, "and so is its proposal")
    Set tPlan = [].%Push({"kind": "Ledger.GuardedCountOverflow", "turnKey": (tTurn), "user": (..#DEVUSER)})
    Do tPlan.%Push({"kind": "OwnerRead.Ledger.GuardedCountForTurn", "turnKey": (tTurn)})
    Do tPlan.%Push({"kind": "OwnerRead.Propose.GuardedCountForTurn", "turnKey": (tTurn)})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Ledger.GuardedCountOverflow ok=0 code=822", "the count on the victim's overflow row is refused: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1).%Get("dropped"), 0, "and answers no count")
    For tI = 2:1:3 {
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, tI) _ " count=" _ ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tI).%Get("count"), tPlan.%Get(tI - 1).%Get("kind") _ " ok=1 code= count=0", "leg " _ tI _ " counts nothing kept under the gone turn's key: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
    }
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>The callers that map a refused read to today's answer map only <code>822</code>: any other failure of the store's
/// read, and an OK status, are not a refused read.</p>
/// <p>Mutation (Rule 19): <code>Write.IsRefusedRead</code> answers 1 for any error status -> this goes red.</p>
Method TestOnlyAnAccessDeniedIsARefusedRead()
{
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Write).IsRefusedRead($$$ERROR($$$AccessDenied)), "an access-denied status is a refused read")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.Proposal.Write).IsRefusedRead($$$ERROR($$$GeneralError, "the read failed")), "a general failure is not")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.Proposal.Write).IsRefusedRead($$$OK), "and an OK status is not")
}

/// <p>A developer who is not the owner confirms, cancels, drafts and claims the victim's proposal, and asks the
/// transcript gate for the victim's conversation: each gets the status and code it got when the stores answered
/// the read, and the rows read as they did.</p>
/// <p>Mutation (Rule 19): the confirm peek maps a refused read to an error -> the confirm leg goes red; the
/// claim by token maps it to a read failure -> the claim legs go red; the draft maps it to an error -> the draft
/// leg goes red.</p>
Method TestTheRouteAnswersAreUnchangedForANonOwner()
{
    Set tIds = ..PreparedIds
    Set tBefore = ..Fingerprint()
    Set tPlan = []
    Do tPlan.%Push({"kind": "Route.Confirm", "id": (tIds.%Get("victimProposal"))})
    Do tPlan.%Push({"kind": "Route.Cancel", "id": (tIds.%Get("victimProposal"))})
    Do tPlan.%Push({"kind": "Route.Draft", "id": (tIds.%Get("victimProposal"))})
    Do tPlan.%Push({"kind": "Route.Claim", "id": (tIds.%Get("victimProposal")), "token": (tIds.%Get("victimToken"))})
    Do tPlan.%Push({"kind": "Route.ClaimById", "id": (tIds.%Get("victimProposal"))})
    Do tPlan.%Push({"kind": "Route.Confirm", "id": "OcuPilotOwnerReadNone"})
    Do tPlan.%Push({"kind": "Route.Cancel", "id": "OcuPilotOwnerReadNone"})
    Do tPlan.%Push({"kind": "Route.Draft", "id": "OcuPilotOwnerReadNone"})
    Do tPlan.%Push({"kind": "Route.Claim", "id": "OcuPilotOwnerReadNone", "token": "OcuPilotOwnerReadNone"})
    Do tPlan.%Push({"kind": "Route.ClaimById", "id": "OcuPilotOwnerReadNone"})
    Do tPlan.%Push({"kind": "Route.TranscriptGate", "subject": (..#VICTIM), "convKey": (tIds.%Get("victimConv")), "turnKey": (tIds.%Get("victimTurn"))})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Set tLegs = $Select(tRun.%GetTypeOf("steps") = "array": tRun.%Get("steps"), 1: [])
    Do $$$AssertEquals(tLegs.%Size(), tPlan.%Size(), "the child answered every leg" _ $Select(tRun.%IsDefined("error"): ": " _ tRun.%Get("error"), 1: ""))
    Set tExpected = $ListBuild("ok=0 http=403 code=PROPOSAL.NOTYOURS", "ok=0 http=404 code=PROPOSAL.UNKNOWN", "ok=0 http=404 code=PROPOSAL.UNKNOWN", "ok=0 http=0 code=PROPOSAL.NOTYOURS", "ok=0 http=0 code=PROPOSAL.NOTYOURS", "ok=0 http=404 code=PROPOSAL.UNKNOWN", "ok=0 http=404 code=PROPOSAL.UNKNOWN", "ok=0 http=404 code=PROPOSAL.UNKNOWN", "ok=0 http=0 code=PROPOSAL.UNKNOWN", "ok=0 http=0 code=PROPOSAL.UNKNOWN")
    For tI = 1:1:$ListLength(tExpected) {
        Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tI)
        Set tText = $Select($IsObject(tLeg): "ok=" _ +tLeg.%Get("ok") _ " http=" _ tLeg.%Get("http") _ " code=" _ tLeg.%Get("routeCode"), 1: "absent")
        Do $$$AssertEquals(tText, $List(tExpected, tI), "leg " _ tI _ " (" _ $Select($IsObject(tLeg): tLeg.%Get("kind"), 1: "") _ ") answers as it did: " _ $Select($IsObject(tLeg): tLeg.%Get("text"), 1: ""))
        If $IsObject(tLeg) Do $$$AssertEquals(tLeg.%Get("seen"), "", "leg " _ tI _ " hands back no proposal")
    }
    Set tGate = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 11)
    Do $$$AssertTrue($IsObject(tGate) && (tGate.%Get("released") = 0) && (tGate.%Get("faultCode") = ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE), "the transcript gate withholds the victim's conversation from a non-administrator, as it did")
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>The public reads of the proposal and ledger stores and of <code>Base</code> are split into owner reads (which an
/// administrator also makes for any user) and open reads, the split equals the stores' public class methods less their
/// writes, every owner read is a step the probe runs, and neither store defines a public instance method or a
/// query.</p>
/// <p>Mutation (Rule 19): a public read added to <code>Propose</code> or <code>Ledger</code> that no list names ->
/// this test goes red.</p>
Method TestTheReadsAreSplitIntoOwnerAdministratorAndOpen()
{
    For tStore = "Propose", "Ledger" {
        Set tClass = ..#STOREPACKAGE _ tStore
        Set tPublic = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.MethodDefinition WHERE parent = ? AND ClassMethod = 1 AND Private = 0", tClass)
        While tRS.%Next() {
            Set tPublic = tPublic _ $ListBuild(tRS.%GetData(1))
        }
        Set tWrites = ##class(OcuPilot.Test.StoreOwnerWrite).OwnerWrites(tStore) _ ##class(OcuPilot.Test.StoreOwnerWrite).AdministratorWrites(tStore) _ ##class(OcuPilot.Test.StoreOwnerWrite).OpenWrites(tStore)
        Set tReads = ..OwnerReads(tStore) _ ..OpenReads(tStore)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tPublic), ##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tReads _ tWrites), tStore _ "'s public class methods are its owner reads, open reads and declared writes")
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tReads), ##class(OcuPilot.Test.AdminStateWrite).SortedJoin(##class(OcuPilot.Test.StoreOwnerWrite).Reads(tStore)), tStore _ "'s declared reads equal the suite's roster of its reads")
        For tI = 1:1:$ListLength(..OwnerReads(tStore)) {
            Set tKind = "OwnerRead." _ tStore _ "." _ $List(..OwnerReads(tStore), tI)
            Do $$$AssertTrue($ClassMethod(..#PROBE, "Handles", tKind), tKind _ " is a read the probe runs")
        }
        Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM %Dictionary.MethodDefinition WHERE parent = ? AND ClassMethod = 0 AND Private = 0", tClass), 0, tStore _ " defines no public instance method")
        Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM %Dictionary.QueryDefinition WHERE parent = ?", tClass), 0, tStore _ " defines no class query")
    }
    Set tPublic = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.MethodDefinition WHERE parent = 'OcuPilot.Kernel.State.Base' AND ClassMethod = 1 AND Private = 0")
    While tRS.%Next() {
        Set tPublic = tPublic _ $ListBuild(tRS.%GetData(1))
    }
    Set tSplit = ..OwnerReads("Base") _ ..OpenReads("Base") _ ..BaseHelpers() _ ##class(OcuPilot.Test.AdminStateWrite).BaseSurface(1)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tPublic), ##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tSplit), "Base's public class methods are its owner reads, open reads, helpers and refused saves")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).SortedJoin(##class(OcuPilot.Test.AdminStateWrite).BaseSurface(0)), ##class(OcuPilot.Test.AdminStateWrite).SortedJoin(..OwnerReads("Base") _ ..OpenReads("Base") _ ..BaseHelpers()), "and the suite's roster of Base's non-saving methods is those three")
    For tI = 1:1:$ListLength(..OwnerReads("Base")) {
        Set tMethod = $List(..OwnerReads("Base"), tI)
        Set tKind = "OwnerRead." _ $Case(tMethod, "GuardedOpenId": "Open", "GuardedExistsId": "Exists", :"StoredValue")
        Do $$$AssertTrue($ClassMethod(..#PROBE, "Handles", tKind), "Base." _ tMethod _ " is a read the probe runs as " _ tKind)
    }
}

/// <p>The owner reads of <var>pStore</var> (<code>Propose</code>, <code>Ledger</code> or <code>Base</code>): the
/// public methods that answer a row's content or a fact about it to the row's owner or an administrator.</p>
ClassMethod OwnerReads(pStore As %String) As %List
{
    If pStore = "Propose" Quit $ListBuild("GuardedByToken", "GuardedByKey", "GuardedRowVersion", "GuardedRowsForTurn", "GuardedRowsForConvo", "GuardedCountForTurn")
    If pStore = "Ledger" Quit $ListBuild("GuardedIdsForWindow", "GuardedDroppedFor", "GuardedRow", "GuardedCountForTurn")
    Quit $ListBuild("GuardedExistsId", "GuardedOpenId", "GuardedStoredValue")
}

/// <p>The public methods of <var>pStore</var> that read nothing of a user's rows: lock keys, a state projection,
/// the clock, a target hold and the reads of identity and configuration.</p>
ClassMethod OpenReads(pStore As %String) As %List
{
    If pStore = "Propose" Quit $ListBuild("TargetLockKey", "TargetHoldKey", "GuardedTargetHold", "GuardedTargetRelease", "ProjectedState", "NowSeconds", "SecondsOf")
    If pStore = "Base" Quit $ListBuild("GuardedProbeGet", "GuardedRolesSnapshot", "GuardedSslConfigRead", "GuardedUserAbsent", "GuardedUserEnabled")
    Quit ""
}

/// <p>The public methods of <code>Base</code> that are neither a read of a user's rows nor a save: the predicates
/// the stores' gates are built from, status tests, the bounded-window builder and the writer of the probe
/// global.</p>
ClassMethod BaseHelpers() As %List
{
    Quit $ListBuild("AdminWriteRefused", "BoundedWhere", "CallerIsAdministrator", "CallerOwns", "GuardedProbeSet", "GuardedRolesSnapshotThenThrow", "IsCapBusy", "IsDuplicateKey", "IsLockConflict", "IsStaleSave", "OwnerWriteRefused")
}

}
