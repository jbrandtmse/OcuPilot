/// <p>AD-9's read gate for the turn, step, navigation, conversation, entry, preference, sharing and background-run
/// stores, as real principals meet it. A principal holding <code>%Development:USE</code> and no
/// <code>OcuPilotAdmin</code> is refused <code>ERROR #822</code>, with no value of the row reaching it, by every key,
/// id and user read of another user's rows, by the reads across every user, by <code>Base</code>'s and a sibling
/// store's opens of them, and by a read through a row it holds that names another row's stream or conversation. It
/// reads its own rows; an administrator without <code>%All</code> reads anyone's; a row that does not exist answers as
/// it did; two reads stay open; and the transcript route answers a non-owner its 404.</p>
/// <p>The calls run in a child process logged in as each principal
/// (<class>OcuPilot.Test.UserStateReadProbe</class>); the rows are seeded and read back here by SQL, as the suite's own
/// <code>%All</code> identity. The three assertion helpers are this class's own because an assertion macro binds to the
/// test case that runs it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes two users and
/// two roles and writes the stores it reads. <method>OnBeforeAllTests</method> refuses anywhere it does not. Every row
/// it seeds names a user starting with <code>OcuPilotUserRead</code>, removed after each test.</p>
Class OcuPilot.Test.UserStateRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.UserStateReadProbe";

Parameter PACKAGE = "OcuPilot.Kernel.State.";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>Holds <code>%Development:USE</code> and the install namespace's code read, and nothing else.</p>
Parameter DEVUSER = "OcuPilotUserReadDev";

Parameter DEVROLE = "OcuPilotUserReadDevRole";

/// <p>Holds <code>OcuPilotAdmin:USE</code> and the install namespace's code read, and no <code>%All</code>.</p>
Parameter ADMINUSER = "OcuPilotUserReadAdmin";

Parameter ADMINROLE = "OcuPilotUserReadAdminRole";

/// <p>The user name whose rows the developer reads. No account has it.</p>
Parameter VICTIM = "OcuPilotUserReadVictim";

/// <p>The process id the victim's running turn records.</p>
Parameter VICTIMJOB = 991122;

/// <p>The keys and stored ids of the rows seeded for one test, as <code>victim*</code> and <code>own*</code>.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UserStateRead creates and deletes users and roles and writes OcuPilot's stores on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotUserRead" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ##class(OcuPilot.Test.AdminStateWrite).EnsurePrincipals(..PreparedPassword, ..Cases())
}

Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.AdminStateWrite).RemovePrincipals(..Cases(), "OcuPilot.Test.UserStateRead")
}

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

/// <p>Delete every row of the stores this class reads that names the victim or the developer, with the turns'
/// signals.</p>
ClassMethod Clean()
{
    Set tPackage = "OcuPilot_Kernel_State."
    Set tTurns = "SELECT TurnKey FROM " _ tPackage _ "Turn WHERE UserName IN (?, ?)"
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, tTurns, ..#VICTIM, ..#DEVUSER)
    Set tKeys = ""
    While tRS.%Next() {
        Set tKeys = tKeys _ $ListBuild(tRS.%GetData(1))
    }
    For tI = 1:1:$ListLength(tKeys) Do ##class(OcuPilot.Kernel.State.Turn).GuardedDelete($List(tKeys, tI))
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM " _ tPackage _ "Entry WHERE ConvoKey IN (SELECT ConvKey FROM " _ tPackage _ "Convo WHERE UserName IN (?, ?))", ..#VICTIM, ..#DEVUSER)
    For tTable = "Convo", "Pref", "Sharing", "SqlRun", "Turn" {
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM " _ tPackage _ tTable _ " WHERE UserName IN (?, ?)", ..#VICTIM, ..#DEVUSER)
    }
}

/// <p>How many rows of the stores this class seeds survive <method>Clean</method>.</p>
Method LeftOver() As %Integer
{
    Set tCount = 0
    For tTable = "Convo", "Pref", "Sharing", "SqlRun", "Turn" {
        Set tCount = tCount + ..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State." _ tTable _ " WHERE UserName IN ('" _ ..#VICTIM _ "', '" _ ..#DEVUSER _ "')")
    }
    For tWho = "victim", "own" {
        If ..PreparedIds.%Get(tWho _ "Turn") '= "" {
            Set tCount = tCount + ..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ?", ..PreparedIds.%Get(tWho _ "Turn"))
            Set tCount = tCount + ..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Nav WHERE %EXACT(TurnKey) = ?", ..PreparedIds.%Get(tWho _ "Turn"))
        }
        If ..PreparedIds.%Get(tWho _ "Conv") '= "" Set tCount = tCount + ..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ?", ..PreparedIds.%Get(tWho _ "Conv"))
    }
    Quit tCount
}

/// <p>Seed, as the suite's own identity, for the victim and for the developer: a completed turn with a step, a
/// navigation directive, a renewed lease and the columns a read hands back; a conversation with an entry carrying
/// both streams; a favorite, a stored view and a sharing choice; and an ended background run with an answer. Remember
/// the keys and the stored ids.</p>
Method Seed() As %Status
{
    Set tSC = $$$OK
    Set ..PreparedIds = {}
    For tWho = "victim", "own" {
        Set tUser = $Select(tWho = "victim": ..#VICTIM, 1: ..#DEVUSER)
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .tTurn))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Turn).GuardedRenew(tTurn))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Step).GuardedAppend(tTurn, "announce", "shell.screen.open", "running", "", "", "", ..#LIMITS, .tSeq, .tStored, "tasks/schedule"))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Nav).GuardedRequest(tTurn, 1, "tasks/" _ tWho, ""))
        Do ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Turn SET DefinitionId = ?, Workflow = ?, StepsDropped = 3, Reply = ?, ContextRoute = ? WHERE %EXACT(TurnKey) = ?", tWho _ "-definition", tWho _ "-workflow", tWho _ "-turn-reply", "route-" _ tWho, tTurn)
        Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", tUser, 5, .tConvoSC, .tConflict)
        Set tSC = $$$ADDSC(tSC, tConvoSC)
        If '$IsObject(tConvo) Continue
        Set tSteps = [].%Push({"kind": "model", "name": (tWho _ "-step")})
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, tWho _ "-message", "completed", tWho _ "-reply", "", 0, tSteps, 0, ..#LIMITS, tTurn, "", "{""route"":""" _ tWho _ "-context""}"))
        Set tConv = tConvo.ConvKey
        Set tConvo = ""
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Pref).GuardedAdd(tUser, "favorite", "tasks/" _ tWho, 20, .tAtLimit))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(tUser, "view", "tasks/schedule", tWho _ "-view"))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Sharing).GuardedSetForUser(tUser, 0))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.SqlRun).GuardedReserve(tUser, $NAMESPACE, 10, ..#LIMITS, .tRun, .tBusyKey, .tFull, .tSweep))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.SqlRun).GuardedBegin(tRun, tUser, .tBegun, .tCancel))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.SqlRun).GuardedFinish(tRun, "ended", "{""answer"":""" _ tWho _ "-answer""}"))
        Do ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.SqlRun SET CancelRequested = 1 WHERE %EXACT(RunKey) = ?", tRun)
        Do ..PreparedIds.%Set(tWho _ "Turn", tTurn, "string")
        Do ..PreparedIds.%Set(tWho _ "Conv", tConv, "string")
        Do ..PreparedIds.%Set(tWho _ "Run", tRun, "string")
        Do ..PreparedIds.%Set(tWho _ "TurnId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = ?", tTurn), "string")
        Do ..PreparedIds.%Set(tWho _ "StepId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ?", tTurn), "string")
        Do ..PreparedIds.%Set(tWho _ "NavId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Nav WHERE %EXACT(TurnKey) = ?", tTurn), "string")
        Do ..PreparedIds.%Set(tWho _ "ConvoId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(ConvKey) = ?", tConv), "string")
        Do ..PreparedIds.%Set(tWho _ "EntryId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ?", tConv), "string")
        Do ..PreparedIds.%Set(tWho _ "PrefId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Pref WHERE %EXACT(UserName) = ? AND Kind = 'view'", tUser), "string")
        Do ..PreparedIds.%Set(tWho _ "SharingId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Sharing WHERE %EXACT(UserName) = ?", tUser), "string")
        Do ..PreparedIds.%Set(tWho _ "SqlRunId", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = ?", tRun), "string")
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
    Set tTurns = "(SELECT TurnKey FROM " _ tPackage _ "Turn WHERE UserName IN " _ tUsers _ ")"
    Set tConvs = "(SELECT ConvKey FROM " _ tPackage _ "Convo WHERE UserName IN " _ tUsers _ ")"
    Set tQueries = $ListBuild("SELECT ID, TurnKey, UserName, State, StepsDropped, Reply, RowVersion FROM " _ tPackage _ "Turn WHERE UserName IN " _ tUsers _ " ORDER BY ID", "SELECT ID, TurnKey, Seq, Status, RowVersion FROM " _ tPackage _ "Step WHERE TurnKey IN " _ tTurns _ " ORDER BY ID", "SELECT ID, TurnKey, Seq, Route, Outcome, RowVersion FROM " _ tPackage _ "Nav WHERE TurnKey IN " _ tTurns _ " ORDER BY ID", "SELECT ID, ConvKey, UserName, RowVersion FROM " _ tPackage _ "Convo WHERE UserName IN " _ tUsers _ " ORDER BY ID", "SELECT ID, ConvoKey, Seq, Message, RowVersion FROM " _ tPackage _ "Entry WHERE ConvoKey IN " _ tConvs _ " ORDER BY ID", "SELECT ID, UserName, Kind, Name, Value, RowVersion FROM " _ tPackage _ "Pref WHERE UserName IN " _ tUsers _ " ORDER BY ID", "SELECT ID, UserName, Share, RowVersion FROM " _ tPackage _ "Sharing WHERE UserName IN " _ tUsers _ " ORDER BY ID", "SELECT ID, RunKey, UserName, State, CancelRequested, RowVersion FROM " _ tPackage _ "SqlRun WHERE UserName IN " _ tUsers _ " ORDER BY ID")
    For tI = 1:1:$ListLength(tQueries) {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, $List(tQueries, tI))
        If tRS.%SQLCODE < 0 {
            Set tText = tText _ "[query " _ tI _ " failed " _ tRS.%SQLCODE _ "]"
            Continue
        }
        Set tText = tText _ "[" _ tI
        While tRS.%Next() {
            Set tText = tText _ "{"
            For tC = 1:1:tRS.%ResultColumnCount Set tText = tText _ $Select(tC = 1: "", 1: "~") _ tRS.%GetData(tC)
            Set tText = tText _ "}"
        }
        Set tText = tText _ "]"
    }
    Quit tText
}

/// <p>The reads of <var>pWho</var>'s (<code>victim</code> or <code>own</code>) turn, steps and directive.</p>
Method TurnReads(pWho As %String) As %DynamicArray
{
    Set tUser = $Select(pWho = "victim": ..#VICTIM, 1: ..#DEVUSER)
    Set tKey = ..PreparedIds.%Get(pWho _ "Turn")
    Set tSteps = []
    For tMethod = "GuardedDropped", "GuardedSignals", "GuardedDefinitionOf", "GuardedWorkflowOf" {
        Do tSteps.%Push({"kind": ("UserRead.Turn." _ tMethod), "key": (tKey)})
    }
    Do tSteps.%Push({"kind": "UserRead.Turn.GuardedForOwner", "key": (tKey), "user": (tUser)})
    Do tSteps.%Push({"kind": "UserRead.Turn.GuardedView", "key": (tKey), "user": (tUser)})
    Do tSteps.%Push({"kind": "UserRead.Step.GuardedRows", "key": (tKey)})
    Do tSteps.%Push({"kind": "UserRead.Nav.GuardedPending", "key": (tKey)})
    Quit tSteps
}

/// <p>The reads of <var>pWho</var>'s conversation and entries, the load branch of <code>LoadOrCreate</code> and the
/// history of a conversation object that names its key included.</p>
Method ConvoReads(pWho As %String) As %DynamicArray
{
    Set tUser = $Select(pWho = "victim": ..#VICTIM, 1: ..#DEVUSER)
    Set tKey = ..PreparedIds.%Get(pWho _ "Conv")
    Set tSteps = []
    Do tSteps.%Push({"kind": "UserRead.Convo.GuardedOwner", "key": (tKey), "user": (tUser)})
    Do tSteps.%Push({"kind": "UserRead.Convo.GuardedOwnerOf", "key": (tKey)})
    Do tSteps.%Push({"kind": "UserRead.Convo.GuardedView", "key": (tKey), "user": (tUser)})
    Do tSteps.%Push({"kind": "UserRead.Convo.LoadOrCreate", "key": (tKey)})
    Do tSteps.%Push({"kind": "UserRead.Convo.HistoryMessages", "key": (tKey)})
    Do tSteps.%Push({"kind": "UserRead.Entry.GuardedRows", "key": (tKey), "context": 0})
    Do tSteps.%Push({"kind": "UserRead.Entry.GuardedRows", "key": (tKey), "context": 1})
    Do tSteps.%Push({"kind": "UserRead.Entry.GuardedTurnKeys", "key": (tKey)})
    Quit tSteps
}

/// <p>The reads of <var>pWho</var>'s preferences, sharing choice and background run.</p>
Method SettingsReads(pWho As %String) As %DynamicArray
{
    Set tUser = $Select(pWho = "victim": ..#VICTIM, 1: ..#DEVUSER)
    Set tRun = ..PreparedIds.%Get(pWho _ "Run")
    Set tSteps = []
    Do tSteps.%Push({"kind": "UserRead.Pref.GuardedListForUser", "user": (tUser), "kindOf": "favorite"})
    Do tSteps.%Push({"kind": "UserRead.Pref.GuardedListForUser", "user": (tUser), "kindOf": "view"})
    Do tSteps.%Push({"kind": "UserRead.Pref.GuardedValue", "user": (tUser), "kindOf": "view", "name": "tasks/schedule"})
    Do tSteps.%Push({"kind": "UserRead.Pref.GuardedCountForUser", "user": (tUser), "kindOf": "view"})
    Do tSteps.%Push({"kind": "UserRead.Sharing.GuardedForUser", "user": (tUser)})
    Do tSteps.%Push({"kind": "UserRead.SqlRun.GuardedViewForOwner", "key": (tRun), "user": (tUser)})
    Do tSteps.%Push({"kind": "UserRead.SqlRun.GuardedCancelRequested", "key": (tRun)})
    Quit tSteps
}

/// <p>The reads of <var>pWho</var>'s row of each of the eight stores through <code>Base</code>, and the stored values
/// of the rows that have a unique key of their own.</p>
Method BaseReads(pWho As %String) As %DynamicArray
{
    Set tIds = ..PreparedIds
    Set tSteps = []
    For tStore = "Turn", "Step", "Nav", "Convo", "Entry", "Pref", "Sharing", "SqlRun" {
        Do tSteps.%Push({"kind": "OwnerRead.Open", "store": "Base", "id": (tIds.%Get(pWho _ tStore _ "Id"))})
        Do tSteps.%Push({"kind": "OwnerRead.Exists", "store": "Base", "id": (tIds.%Get(pWho _ tStore _ "Id"))})
    }
    Do tSteps.%Push({"kind": "OwnerRead.StoredValue", "store": "Turn", "method": "TurnKeyIdxExists", "key": (tIds.%Get(pWho _ "Turn")), "property": "Reply"})
    Do tSteps.%Push({"kind": "OwnerRead.StoredValue", "store": "Nav", "method": "NavTurnKeyIdxExists", "key": (tIds.%Get(pWho _ "Turn")), "property": "Route"})
    Do tSteps.%Push({"kind": "OwnerRead.StoredValue", "store": "Convo", "method": "ConvKeyIdxExists", "key": (tIds.%Get(pWho _ "Conv")), "property": "UserName"})
    Do tSteps.%Push({"kind": "OwnerRead.StoredValue", "store": "SqlRun", "method": "RunKeyIdxExists", "key": (tIds.%Get(pWho _ "Run")), "property": "Namespace"})
    Quit tSteps
}

/// <p>The opens and existence checks of <var>pWho</var>'s row of each of the eight stores through the class name of
/// the next store.</p>
Method SiblingReads(pWho As %String) As %DynamicArray
{
    Set tIds = ..PreparedIds
    Set tStores = $ListBuild("Turn", "Step", "Nav", "Convo", "Entry", "Pref", "Sharing", "SqlRun")
    Set tSteps = []
    For tI = 1:1:$ListLength(tStores) {
        Set tId = tIds.%Get(pWho _ $List(tStores, tI) _ "Id")
        Set tSibling = $List(tStores, tI # $ListLength(tStores) + 1)
        Do tSteps.%Push({"kind": "OwnerRead.Open", "store": (tSibling), "id": (tId)})
        Do tSteps.%Push({"kind": "OwnerRead.Exists", "store": (tSibling), "id": (tId)})
    }
    Quit tSteps
}

/// <p>Append <var>pMore</var>'s steps to <var>pSteps</var>.</p>
ClassMethod Concat(pSteps As %DynamicArray, pMore As %DynamicArray)
{
    For tI = 0:1:pMore.%Size() - 1 Do pSteps.%Push(pMore.%Get(tI))
}

/// <p>Assert that <var>pRun</var> logged in as <var>pUser</var>, with or without <code>OcuPilotAdmin</code> and
/// without <code>%All</code>.</p>
Method AssertPrincipal(pRun As %DynamicObject, pUser As %String, pHoldsAdmin As %Boolean)
{
    Do $$$AssertEquals(pRun.%Get("username") _ "|" _ pRun.%Get("holdsAdmin") _ "|" _ (pRun.%Get("roles") [ "%All"), pUser _ "|" _ pHoldsAdmin _ "|0", "the child runs as " _ pUser _ " with" _ $Select(pHoldsAdmin: "", 1: "out") _ " OcuPilotAdmin and without %All")
}

/// <p>The legs of <var>pRun</var>, asserting it answered every leg of <var>pPlan</var>.</p>
Method LegsOf(pRun As %DynamicObject, pWhat As %String, pPlan As %DynamicArray) As %DynamicArray
{
    Set tLegs = $Select(pRun.%GetTypeOf("steps") = "array": pRun.%Get("steps"), 1: [])
    Do $$$AssertEquals(tLegs.%Size(), pPlan.%Size(), pWhat _ ": the child answered every leg of its plan" _ $Select(pRun.%IsDefined("error"): ": " _ pRun.%Get("error"), 1: ""))
    Quit tLegs
}

/// <p>Assert that every leg of <var>pPlan</var> was answered by <var>pRun</var>, refused <code>822</code>, and handed
/// back nothing.</p>
Method AssertAllRefused(pRun As %DynamicObject, pWhat As %String, pPlan As %DynamicArray)
{
    Set tLegs = ..LegsOf(pRun, pWhat, pPlan)
    For tI = 1:1:tLegs.%Size() {
        Set tLeg = tLegs.%Get(tI - 1)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(pRun, tI), tLeg.%Get("kind") _ " ok=0 code=822", pWhat _ " leg " _ tI _ " is refused 822: " _ tLeg.%Get("text"))
        Do $$$AssertEquals(tLeg.%Get("seen"), "", pWhat _ " leg " _ tI _ " (" _ tLeg.%Get("kind") _ ") hands back no value")
    }
}

/// <p>Assert that every leg of <var>pPlan</var> was answered by <var>pRun</var> and handed back a value.</p>
Method AssertAllAnswered(pRun As %DynamicObject, pWhat As %String, pPlan As %DynamicArray)
{
    Set tLegs = ..LegsOf(pRun, pWhat, pPlan)
    For tI = 1:1:tLegs.%Size() {
        Set tLeg = tLegs.%Get(tI - 1)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(pRun, tI), tLeg.%Get("kind") _ " ok=1 code=", pWhat _ " leg " _ tI _ " is answered: " _ tLeg.%Get("text"))
        Do $$$AssertTrue(tLeg.%Get("seen") '= "", pWhat _ " leg " _ tI _ " (" _ tLeg.%Get("kind") _ ") hands back a value")
    }
}

/// <p>A developer -- <code>%Development:USE</code>, no <code>OcuPilotAdmin</code> -- reads another user's turn through
/// its key, its signals, its definition and workflow, its owner and its progress view, its steps and its navigation
/// directive. Each is refused <code>822</code>, hands back no value through any output argument, and the rows read as
/// they did.</p>
/// <p>Mutation (Rule 19): the key check removed from <code>Turn.GuardedDropped</code>, <code>GuardedSignals</code>,
/// <code>Step.GuardedRows</code> or <code>Nav.GuardedPending</code>, or the open in <code>Turn.GuardedDefinitionOf</code>
/// or <code>GuardedWorkflowOf</code> made without the caller check -> that leg goes red.</p>
Method TestADeveloperIsRefusedEveryReadOfAnotherUsersTurn()
{
    Set tBefore = ..Fingerprint()
    Set tPlan = ..TurnReads("victim")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllRefused(tRun, "the victim's turn", tPlan)
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>A developer reads another user's conversation through its owner, its view, <code>LoadOrCreate</code>'s load
/// branch, the history of a conversation object that names its key, its entries with and without the stored context
/// and its turn keys. Each is refused <code>822</code> and hands back nothing.</p>
/// <p>Mutation (Rule 19): the key check removed from <code>Convo.GuardedOwnerOf</code>, <code>Entry.GuardedRows</code>
/// or <code>GuardedTurnKeys</code>, the user check from <code>Convo.GuardedOwner</code>, or the stored-owner check from
/// <code>LoadOrCreate</code>'s load branch -> that leg goes red.</p>
Method TestADeveloperIsRefusedEveryReadOfAnotherUsersConversation()
{
    Set tBefore = ..Fingerprint()
    Set tPlan = ..ConvoReads("victim")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllRefused(tRun, "the victim's conversation", tPlan)
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>A developer reads another user's preferences, sharing choice and background run through the user and key reads,
/// and every user's through the two all-users reads. Each is refused <code>822</code> and hands back nothing.</p>
/// <p>Mutation (Rule 19): the user check removed from <code>Pref.GuardedListForUser</code>, <code>GuardedValue</code>,
/// <code>GuardedCountForUser</code>, <code>Sharing.GuardedForUser</code> or <code>SqlRun.GuardedViewForOwner</code>,
/// the key check from <code>SqlRun.GuardedCancelRequested</code>, or the administrator check from either
/// <code>GuardedUsers</code> -> that leg goes red.</p>
Method TestADeveloperIsRefusedEveryReadOfAnotherUsersSettings()
{
    Set tBefore = ..Fingerprint()
    Set tPlan = ..SettingsReads("victim")
    Do tPlan.%Push({"kind": "UserRead.Pref.GuardedUsers"})
    Do tPlan.%Push({"kind": "UserRead.Sharing.GuardedUsers"})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllRefused(tRun, "the victim's settings", tPlan)
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>A developer who names another user in a read that finds no row -- the user's turn, conversation, background run,
/// preferences or sharing choice is not there -- is refused <code>822</code> all the same: whether another user has a
/// row is not the developer's to ask.</p>
/// <p>Mutation (Rule 19): the user check removed from <code>Turn.GuardedForOwner</code>, <code>Convo.GuardedOwner</code>,
/// <code>Pref.GuardedListForUser</code>, <code>GuardedValue</code>, <code>GuardedCountForUser</code>,
/// <code>Sharing.GuardedForUser</code> or <code>SqlRun.GuardedViewForOwner</code> -> that leg goes red.</p>
Method TestADeveloperIsRefusedAReadNamingAnotherUserWhoHoldsNoRow()
{
    Set tBefore = ..Fingerprint()
    Set tNone = "OcuPilotUserReadNone"
    Set tNoone = "OcuPilotUserReadNoone"
    Set tPlan = []
    Do tPlan.%Push({"kind": "UserRead.Turn.GuardedForOwner", "key": (tNone), "user": (tNoone)})
    Do tPlan.%Push({"kind": "UserRead.Turn.GuardedView", "key": (tNone), "user": (tNoone)})
    Do tPlan.%Push({"kind": "UserRead.Convo.GuardedOwner", "key": (tNone), "user": (tNoone)})
    Do tPlan.%Push({"kind": "UserRead.Convo.GuardedView", "key": (tNone), "user": (tNoone)})
    Do tPlan.%Push({"kind": "UserRead.Pref.GuardedListForUser", "user": (tNoone), "kindOf": "favorite"})
    Do tPlan.%Push({"kind": "UserRead.Pref.GuardedValue", "user": (tNoone), "kindOf": "view", "name": "tasks/schedule"})
    Do tPlan.%Push({"kind": "UserRead.Pref.GuardedCountForUser", "user": (tNoone), "kindOf": "favorite"})
    Do tPlan.%Push({"kind": "UserRead.Sharing.GuardedForUser", "user": (tNoone)})
    Do tPlan.%Push({"kind": "UserRead.SqlRun.GuardedViewForOwner", "key": (tNone), "user": (tNoone)})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllRefused(tRun, "a read naming a user with no row", tPlan)
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>A developer opens, and asks the existence of, the victim's row of each of the eight stores through
/// <code>Base</code>, and reads the stored values the unique keys name, also through a store that has no such key.
/// Each is refused <code>822</code> and hands back nothing.</p>
/// <p>Mutation (Rule 19): <code>Base.GuardedOpenId</code> or <code>GuardedExistsId</code> reads the gate from the class
/// called rather than the stored row's -> the <code>Base</code> legs go red.</p>
Method TestADeveloperIsRefusedEveryOpenOfAnotherUsersRowThroughBase()
{
    Set tBefore = ..Fingerprint()
    Set tPlan = ..BaseReads("victim")
    Do tPlan.%Push({"kind": "OwnerRead.StoredValue", "store": "Pref", "method": "RunKeyIdxExists", "key": (..PreparedIds.%Get("victimRun")), "property": "Namespace"})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllRefused(tRun, "the victim's rows through Base", tPlan)
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>A developer who names a row of one store through the class name of another store is handed nothing: the open
/// fails, because the stored row is not an instance of the class called, and the existence check answers no. The
/// control is the database's own refusal of a foreign class, whatever the stores check.</p>
/// <p>Mutation (Rule 19): none of its own; it is the control the read gate is measured against.</p>
Method TestARowNamedThroughAnotherStoresClassIsNotHandedBack()
{
    Set tBefore = ..Fingerprint()
    Set tPlan = ..SiblingReads("victim")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Set tLegs = ..LegsOf(tRun, "the victim's rows through a sibling class", tPlan)
    For tI = 1:1:tLegs.%Size() {
        Set tLeg = tLegs.%Get(tI - 1)
        Do $$$AssertEquals(tLeg.%Get("seen"), "", "leg " _ tI _ " (" _ tLeg.%Get("kind") _ ") hands back nothing")
        If tLeg.%Get("kind") = "OwnerRead.Open" Do $$$AssertEquals(tLeg.%Get("ok"), 0, "leg " _ tI _ " fails to open: " _ tLeg.%Get("text"))
    }
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>The paths the database does not open to the developer stay closed whatever the stores check: for each of the
/// eight stores a direct open, existence check and read of one stored property of the victim's row, a direct query
/// of the table, and the extent query.</p>
/// <p>Mutation (Rule 19): none of its own; it is the control the read gate is measured against.</p>
Method TestTheDatabaseRefusesTheDirectPaths()
{
    Set tStores = $ListBuild("Turn", "Step", "Nav", "Convo", "Entry", "Pref", "Sharing", "SqlRun")
    Set tProperties = $ListBuild("State", "Name", "Route", "UserName", "Message", "Value", "UserName", "Namespace")
    Set tPlan = []
    For tI = 1:1:$ListLength(tStores) {
        Set tStore = $List(tStores, tI)
        Set tId = ..PreparedIds.%Get("victim" _ tStore _ "Id")
        Do $$$AssertTrue(tId '= "", "the victim's " _ tStore _ " row was seeded")
        Do tPlan.%Push({"kind": "Direct.OpenId", "store": (tStore), "id": (tId)})
        Do tPlan.%Push({"kind": "Direct.ExistsId", "store": (tStore), "id": (tId)})
        Do tPlan.%Push({"kind": "Direct.GetStored", "store": (tStore), "id": (tId), "property": ($List(tProperties, tI))})
        Do tPlan.%Push({"kind": "Direct.Sql", "table": (tStore)})
        Do tPlan.%Push({"kind": "Direct.Extent", "store": (tStore)})
    }
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Set tLegs = ..LegsOf(tRun, "the direct paths", tPlan)
    For tI = 1:1:tLegs.%Size() {
        Set tLeg = tLegs.%Get(tI - 1)
        Do $$$AssertEquals(tLeg.%Get("seen"), "", tLeg.%Get("kind") _ " leg " _ tI _ " hands back nothing: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
        If tLeg.%Get("kind") '= "Direct.Extent" Do $$$AssertEquals(tLeg.%Get("ok"), 0, tLeg.%Get("kind") _ " leg " _ tI _ " is refused: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
    }
}

/// <p>A developer holds its own entry with a stream pointed at another user's entry stream and reads its own
/// conversation, holds its own background run with the answer pointed at the victim's and reads its own run, and
/// holds its own conversation with the key edited to the victim's and asks for its history. No value of the victim
/// reaches it, and the rows read as they did. An open returns the object the caller holds, so the stores read only the
/// stream a row stores and the key a conversation stores.</p>
/// <p>Mutation (Rule 19): the stored-stream comparison removed from <code>Base.GuardedStreamText</code> -> the entry
/// and run legs go red; the key check removed from <code>Entry.GuardedRows</code> -> the history leg goes red.</p>
Method TestAHeldRowCannotReadAnotherRowsStreamOrConversation()
{
    Set tVictimEntry = ##class(OcuPilot.Kernel.State.Entry).%OpenId(..PreparedIds.%Get("victimEntryId"))
    Set tVictimRun = ##class(OcuPilot.Kernel.State.SqlRun).%OpenId(..PreparedIds.%Get("victimSqlRunId"))
    Do $$$AssertTrue($IsObject(tVictimEntry) && $IsObject(tVictimRun), "the victim's entry and run were seeded")
    Set tSteps = tVictimEntry.StepsJsonGetObjectId()
    Set tContext = tVictimEntry.ContextJsonGetObjectId()
    Set tAnswer = tVictimRun.AnswerGetObjectId()
    Set tVictimEntry = ""
    Set tVictimRun = ""
    Do $$$AssertTrue((tSteps '= "") && (tContext '= "") && (tAnswer '= ""), "and each stores its stream")
    Set tIds = ..PreparedIds
    Set tBefore = ..Fingerprint()
    Set tPlan = []
    Do tPlan.%Push({"kind": "Held.EntryStreamSwap", "id": (tIds.%Get("ownEntryId")), "key": (tIds.%Get("ownConv")), "property": "StepsJson", "stream": (tSteps)})
    Do tPlan.%Push({"kind": "Held.EntryStreamSwap", "id": (tIds.%Get("ownEntryId")), "key": (tIds.%Get("ownConv")), "property": "ContextJson", "stream": (tContext)})
    Do tPlan.%Push({"kind": "Held.RunStreamSwap", "id": (tIds.%Get("ownSqlRunId")), "key": (tIds.%Get("ownRun")), "stream": (tAnswer)})
    Do tPlan.%Push({"kind": "Held.HistoryKeyEdit", "own": (tIds.%Get("ownConv")), "key": (tIds.%Get("victimConv"))})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Set tLegs = ..LegsOf(tRun, "the held rows", tPlan)
    For tI = 1:1:tLegs.%Size() {
        Set tLeg = tLegs.%Get(tI - 1)
        Do $$$AssertTrue(tLeg.%Get("opened"), "leg " _ tI _ ": the developer holds its own row: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
        Do $$$AssertTrue(tLeg.%Get("seen") '[ "victim", "leg " _ tI _ " hands back no value of the victim: " _ tLeg.%Get("seen"))
    }
    For tI = 3:1:4 {
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tI).%Get("code"), "822", "leg " _ tI _ " is refused 822")
    }
    Do $$$AssertTrue(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1).%Get("seen") [ "own-message", "the swapped steps stream still reads the row's own message")
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>The developer reads its own turn, steps, directive, conversation, entries, preferences, sharing choice and run
/// through every read the refusal tests call, and each answers a value of the row.</p>
/// <p>Mutation (Rule 19): the owner check refuses an owner -> every leg goes red.</p>
Method TestAnOwnerReadsItsOwnRows()
{
    Set tPlan = ..TurnReads("own")
    Do ..Concat(tPlan, ..ConvoReads("own"))
    Do ..Concat(tPlan, ..SettingsReads("own"))
    Do ..Concat(tPlan, ..BaseReads("own"))
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllAnswered(tRun, "the developer's own rows", tPlan)
}

/// <p>An administrator -- <code>OcuPilotAdmin:USE</code>, no <code>%All</code> -- reads the victim's turn,
/// conversation, settings and run through every read, and every user's preferences and sharing choices.</p>
/// <p>Mutation (Rule 19): the administrator exemption removed from <code>Base.OwnerWriteRefused</code> -> every leg
/// goes red.</p>
Method TestAnAdministratorReadsAnotherUsersRows()
{
    Set tPlan = ..TurnReads("victim")
    Do ..Concat(tPlan, ..ConvoReads("victim"))
    Do ..Concat(tPlan, ..SettingsReads("victim"))
    Do tPlan.%Push({"kind": "UserRead.Pref.GuardedUsers"})
    Do tPlan.%Push({"kind": "UserRead.Sharing.GuardedUsers"})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    Do ..AssertAllAnswered(tRun, "the victim's rows read by an administrator", tPlan)
    Set tUsers = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tPlan.%Size()).%Get("seen")
    Do $$$AssertTrue((tUsers [ ..#VICTIM) && (tUsers [ ..#DEVUSER), "the all-users read names both users: " _ tUsers)
}

/// <p>The two reads a product path makes for another user stay open to the developer: the names of users with live
/// turns, and whether a process is a turn job.</p>
/// <p>Mutation (Rule 19): <code>Turn.GuardedLiveUsers</code> or <code>GuardedIsTurnJob</code> refuses a non-administrator
/// -> its leg goes red.</p>
Method TestTheOpenReadsStayOpen()
{
    Do ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Turn SET State = 'running', JobId = ? WHERE %EXACT(TurnKey) = ?", ..#VICTIMJOB, ..PreparedIds.%Get("victimTurn"))
    Set tPlan = []
    Do tPlan.%Push({"kind": "UserRead.Turn.GuardedLiveUsers"})
    Do tPlan.%Push({"kind": "UserRead.Turn.GuardedIsTurnJob", "pid": (..#VICTIMJOB)})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllAnswered(tRun, "the open reads", tPlan)
    Do $$$AssertTrue(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1).%Get("seen") [ ..#VICTIM, "the live users include the victim")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 2).%Get("isJob"), 1, "and the process id is a turn job")
}

/// <p>The Transcripts list is scoped to its caller: the developer sees its own conversation and not the victim's, an
/// administrator sees both.</p>
/// <p>Mutation (Rule 19): <code>Convo.GuardedScreenRows</code> selects every user's rows and opens them without the
/// caller check -> the developer's leg goes red. Either change alone leaves it green, because each hides the other's
/// rows.</p>
Method TestTheTranscriptListIsScopedToTheCaller()
{
    Set tPlan = [].%Push({"kind": "UserRead.Convo.GuardedScreenRows"})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Set tSeen = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1).%Get("seen")
    Do $$$AssertTrue((tSeen [ ..PreparedIds.%Get("ownConv")) && (tSeen '[ ..PreparedIds.%Get("victimConv")), "the developer's list holds its own conversation alone: " _ tSeen)
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    Set tSeen = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1).%Get("seen")
    Do $$$AssertTrue((tSeen [ ..PreparedIds.%Get("ownConv")) && (tSeen [ ..PreparedIds.%Get("victimConv")), "the administrator's list holds both: " _ tSeen)
    Do $$$AssertTrue(tSeen '[ "victim-message", "and carries no title of the victim's: " _ tSeen)
}

/// <p>A row that does not exist, and another user's row asked for under the developer's own name, answer a
/// non-owner as they answer anyone: the call succeeds, nothing is found and nothing is handed back; a load of a
/// conversation that does not exist fails as not found, not as a refusal.</p>
/// <p>Mutation (Rule 19): <code>Convo.GuardedOwnerOf</code> refusing a key that names no conversation -> its leg goes
/// red; <code>Turn.GuardedForOwner</code> refusing the developer's own name -> the own-name legs go red.</p>
Method TestARowThatDoesNotExistAnswersAsItDid()
{
    Set tIds = ..PreparedIds
    Set tNone = "OcuPilotUserReadNone"
    Set tPlan = []
    For tMethod = "GuardedDropped", "GuardedSignals", "GuardedDefinitionOf", "GuardedWorkflowOf" {
        Do tPlan.%Push({"kind": ("UserRead.Turn." _ tMethod), "key": (tNone)})
    }
    Do tPlan.%Push({"kind": "UserRead.Step.GuardedRows", "key": (tNone)})
    Do tPlan.%Push({"kind": "UserRead.Nav.GuardedPending", "key": (tNone)})
    Do tPlan.%Push({"kind": "UserRead.Convo.GuardedOwnerOf", "key": (tNone)})
    Do tPlan.%Push({"kind": "UserRead.Entry.GuardedRows", "key": (tNone), "context": 0})
    Do tPlan.%Push({"kind": "UserRead.Entry.GuardedTurnKeys", "key": (tNone)})
    Do tPlan.%Push({"kind": "UserRead.SqlRun.GuardedCancelRequested", "key": (tNone)})
    Do tPlan.%Push({"kind": "UserRead.Turn.GuardedForOwner", "key": (tNone), "user": (..#DEVUSER)})
    Do tPlan.%Push({"kind": "UserRead.Turn.GuardedForOwner", "key": (tIds.%Get("victimTurn")), "user": (..#DEVUSER)})
    Do tPlan.%Push({"kind": "UserRead.Turn.GuardedView", "key": (tIds.%Get("victimTurn")), "user": (..#DEVUSER)})
    Do tPlan.%Push({"kind": "UserRead.Convo.GuardedOwner", "key": (tIds.%Get("victimConv")), "user": (..#DEVUSER)})
    Do tPlan.%Push({"kind": "UserRead.Convo.GuardedView", "key": (tIds.%Get("victimConv")), "user": (..#DEVUSER)})
    Do tPlan.%Push({"kind": "UserRead.SqlRun.GuardedViewForOwner", "key": (tIds.%Get("victimRun")), "user": (..#DEVUSER)})
    Do tPlan.%Push({"kind": "UserRead.Convo.LoadOrCreate", "key": (tNone)})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Set tLegs = ..LegsOf(tRun, "the missing and own-named reads", tPlan)
    For tI = 1:1:tLegs.%Size() - 1 {
        Set tLeg = tLegs.%Get(tI - 1)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, tI), tLeg.%Get("kind") _ " ok=1 code=", "leg " _ tI _ " answers: " _ tLeg.%Get("text"))
        Do $$$AssertEquals(tLeg.%Get("seen"), "", "leg " _ tI _ " (" _ tLeg.%Get("kind") _ ") hands back nothing")
    }
    Set tLoad = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tPlan.%Size())
    Do $$$AssertTrue($IsObject(tLoad) && 'tLoad.%Get("ok") && (tLoad.%Get("code") '= "822"), "a load of a conversation that does not exist fails as not found: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tPlan.%Size()))
}

/// <p>A step, a directive or an entry whose turn or conversation row is gone is still another user's row: a developer
/// who reads by that key is handed none of it, because each row's own open refuses a caller who is not the owner. The
/// control is that the child rows exist while their parents do not.</p>
/// <p>Mutation (Rule 19): the per-row open in <code>Step.GuardedRows</code>, <code>Nav.GuardedPending</code> or
/// <code>Entry.GuardedRows</code> made through <code>GuardedOpenIdAnyCaller</code> -> that leg goes red.</p>
Method TestAnOrphanedChildRowOfAnotherUserIsNotHandedBack()
{
    Set tIds = ..PreparedIds
    Set tTurn = tIds.%Get("victimTurn")
    Set tConv = tIds.%Get("victimConv")
    Set tPackage = "OcuPilot_Kernel_State."
    Do $$$AssertTrue((..Stored("SELECT COUNT(*) FROM " _ tPackage _ "Step WHERE %EXACT(TurnKey) = ?", tTurn) > 0) && (..Stored("SELECT COUNT(*) FROM " _ tPackage _ "Nav WHERE %EXACT(TurnKey) = ?", tTurn) > 0) && (..Stored("SELECT COUNT(*) FROM " _ tPackage _ "Entry WHERE %EXACT(ConvoKey) = ?", tConv) > 0), "the victim's step, directive and entry exist")
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM " _ tPackage _ "Turn WHERE %EXACT(TurnKey) = ?", tTurn)
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM " _ tPackage _ "Convo WHERE %EXACT(ConvKey) = ?", tConv)
    Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM " _ tPackage _ "Turn WHERE %EXACT(TurnKey) = ?", tTurn) _ "|" _ ..Stored("SELECT COUNT(*) FROM " _ tPackage _ "Convo WHERE %EXACT(ConvKey) = ?", tConv), "0|0", "and their turn and conversation do not")
    Set tPlan = []
    Do tPlan.%Push({"kind": "UserRead.Step.GuardedRows", "key": (tTurn)})
    Do tPlan.%Push({"kind": "UserRead.Nav.GuardedPending", "key": (tTurn)})
    Do tPlan.%Push({"kind": "UserRead.Entry.GuardedRows", "key": (tConv), "context": 0})
    Do tPlan.%Push({"kind": "UserRead.Entry.GuardedRows", "key": (tConv), "context": 1})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM " _ tPackage _ "Step WHERE %EXACT(TurnKey) = ?", tTurn)
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM " _ tPackage _ "Nav WHERE %EXACT(TurnKey) = ?", tTurn)
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM " _ tPackage _ "Entry WHERE %EXACT(ConvoKey) = ?", tConv)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Set tLegs = ..LegsOf(tRun, "the orphaned child rows", tPlan)
    For tI = 1:1:tLegs.%Size() {
        Set tLeg = tLegs.%Get(tI - 1)
        Do $$$AssertEquals(tLeg.%Get("seen"), "", "leg " _ tI _ " (" _ tLeg.%Get("kind") _ ") hands back nothing")
    }
}

/// <p>The transcript route answers a non-owner without the administrative resource the 404 it answers an unknown id,
/// and answers the owner its conversation.</p>
/// <p>Mutation (Rule 19): <code>Transcripts.HandleRead</code> renders a refused <code>GuardedOwnerOf</code> as an
/// internal error -> the first leg goes red.</p>
Method TestTheTranscriptRouteAnswersANonOwnerItsNotFound()
{
    Set tIds = ..PreparedIds
    Set tBefore = ..Fingerprint()
    Set tPlan = []
    Do tPlan.%Push({"kind": "Route.Transcript", "id": (tIds.%Get("victimConv"))})
    Do tPlan.%Push({"kind": "Route.Transcript", "id": "OcuPilotUserReadNone"})
    Do tPlan.%Push({"kind": "Route.Transcript", "id": (tIds.%Get("ownConv"))})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Set tLegs = ..LegsOf(tRun, "the transcript route", tPlan)
    For tI = 1:1:tLegs.%Size() {
        Set tLeg = tLegs.%Get(tI - 1)
        Do $$$AssertEquals(tLeg.%Get("ok"), 1, "leg " _ tI _ " is handled: " _ tLeg.%Get("text"))
        Do $$$AssertEquals(tLeg.%Get("http") = 404, (tI < 3), "leg " _ tI _ " answers " _ $Select(tI < 3: "404", 1: "its conversation") _ ": " _ tLeg.%Get("http"))
        If tI = 3 Do $$$AssertTrue(((tLeg.%Get("http") '= 403) && (tLeg.%Get("http") '= 500)), "the owner's leg is neither refused nor an internal error: " _ tLeg.%Get("http"))
    }
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the rows read as they did")
}

/// <p>The public reads of the eight stores are split into owner reads (which an administrator also makes for any
/// user), administrator reads and open reads; with the declared writes and helpers the split equals each store's public
/// class methods; every read is a step the probe runs; and no store defines a public instance method or a query.</p>
/// <p>Mutation (Rule 19): a public read added to one of the eight stores that no list names -> this test goes
/// red.</p>
Method TestTheReadsAreSplitIntoOwnerAdministratorAndOpen()
{
    For tStore = "Turn", "Step", "Nav", "Convo", "Entry", "Pref", "Sharing", "SqlRun" {
        Set tClass = ..#PACKAGE _ tStore
        Set tPublic = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.MethodDefinition WHERE parent = ? AND ClassMethod = 1 AND Private = 0", tClass)
        While tRS.%Next() {
            Set tPublic = tPublic _ $ListBuild(tRS.%GetData(1))
        }
        Set tSplit = ..OwnerReads(tStore) _ ..AdministratorReads(tStore) _ ..OpenReads(tStore) _ ..Writes(tStore)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tPublic), ##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tSplit), tStore _ "'s public class methods are its owner, administrator and open reads and its declared writes")
        For tI = 1:1:$ListLength(..OwnerReads(tStore) _ ..AdministratorReads(tStore)) {
            Set tKind = "UserRead." _ tStore _ "." _ $List(..OwnerReads(tStore) _ ..AdministratorReads(tStore), tI)
            Do $$$AssertTrue($ClassMethod(..#PROBE, "Handles", tKind), tKind _ " is a read the probe runs")
        }
        Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM %Dictionary.MethodDefinition WHERE parent = ? AND ClassMethod = 0 AND Private = 0", tClass), 0, tStore _ " defines no public instance method")
        Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM %Dictionary.QueryDefinition WHERE parent = ?", tClass), 0, tStore _ " defines no class query")
    }
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Handles", "UserRead.Turn.GuardedLiveUsers") && $ClassMethod(..#PROBE, "Handles", "UserRead.Turn.GuardedIsTurnJob"), "the two open reads are steps the probe runs")
}

/// <p>The public reads of <var>pStore</var> that answer a row's content or a fact about it to the row's owner and to
/// an administrator.</p>
ClassMethod OwnerReads(pStore As %String) As %List
{
    If pStore = "Turn" Quit $ListBuild("GuardedDropped", "GuardedSignals", "GuardedDefinitionOf", "GuardedWorkflowOf", "GuardedForOwner", "GuardedView")
    If pStore = "Step" Quit $ListBuild("GuardedRows")
    If pStore = "Nav" Quit $ListBuild("GuardedPending")
    If pStore = "Convo" Quit $ListBuild("GuardedOwner", "GuardedOwnerOf", "GuardedView", "GuardedScreenRows", "HistoryMessages", "LoadOrCreate")
    If pStore = "Entry" Quit $ListBuild("GuardedRows", "GuardedTurnKeys")
    If pStore = "Pref" Quit $ListBuild("GuardedListForUser", "GuardedValue", "GuardedCountForUser")
    If pStore = "Sharing" Quit $ListBuild("GuardedForUser")
    If pStore = "SqlRun" Quit $ListBuild("GuardedViewForOwner", "GuardedCancelRequested")
    Quit ""
}

/// <p>The public reads of <var>pStore</var> across every user, which an administrator alone makes.</p>
ClassMethod AdministratorReads(pStore As %String) As %List
{
    If pStore = "Pref" Quit $ListBuild("GuardedUsers")
    If pStore = "Sharing" Quit $ListBuild("GuardedUsers")
    Quit ""
}

/// <p>The public methods of <var>pStore</var> that read nothing of a user's rows: the two reads a product path makes
/// for another user, and the clock, the vocabulary and the formatting helpers.</p>
ClassMethod OpenReads(pStore As %String) As %List
{
    If pStore = "Turn" Quit $ListBuild("GuardedLiveUsers", "GuardedIsTurnJob", "Cap", "CitationsArray", "EgressObject", "IsTerminal", "IsoOfSeconds", "MinuteCeiling", "NowSeconds", "SecondsOf", "Timestamp")
    If pStore = "Pref" Quit $ListBuild("IsShellMember", "IsThemeValue")
    If pStore = "SqlRun" Quit $ListBuild("IsTerminal")
    Quit ""
}

/// <p>The public writers of <var>pStore</var>, each gated by its own owner or administrator check
/// (<class>OcuPilot.Test.TranscriptOwnerWrite</class>, <class>OcuPilot.Test.PrefOwnerWrite</class>,
/// <class>OcuPilot.Test.ReserveSweepWrite</class>).</p>
ClassMethod Writes(pStore As %String) As %List
{
    If pStore = "Turn" Quit $ListBuild("GuardedAbandonForUser", "GuardedAddDropped", "GuardedBegin", "GuardedDelete", "GuardedFinish", "GuardedForgetStarts", "GuardedProgress", "GuardedReconcile", "GuardedRenew", "GuardedRequestStop", "GuardedReserve", "GuardedSweep", "GuardedSweepStarts")
    If pStore = "Step" Quit $ListBuild("GuardedAppend", "GuardedDeleteForTurn", "GuardedFinishTool", "GuardedSnapshotText", "GuardedUpdate")
    If pStore = "Nav" Quit $ListBuild("GuardedDeleteForTurn", "GuardedRequest", "GuardedSettle")
    If pStore = "Convo" Quit $ListBuild("AppendEntry", "GuardedDelete", "GuardedPurgeEmpty")
    If pStore = "Entry" Quit $ListBuild("GuardedAppend", "GuardedDeleteForConvo", "GuardedPurge")
    If pStore = "Pref" Quit $ListBuild("DeleteAllGuarded", "GuardedAdd", "GuardedClear", "GuardedDeleteForUser", "GuardedRemove", "GuardedSetValue", "GuardedTouch", "GuardedTrim")
    If pStore = "Sharing" Quit $ListBuild("DeleteAllGuarded", "GuardedDeleteForUser", "GuardedSetForUser")
    If pStore = "SqlRun" Quit $ListBuild("GuardedBegin", "GuardedCancel", "GuardedFinish", "GuardedForgetUser", "GuardedReserve", "GuardedSweep")
    Quit ""
}

}
