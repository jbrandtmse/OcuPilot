/// <p>Pins Story 18.33's changes to a privileged routine application's two lists on both callers (C2, C3, C4): the
/// screen's six row actions over <code>POST /screens/webapp.routineapps/action</code>, each a delta over the fresh read;
/// the agent's mint and confirm of a complete <code>MatchRoles</code> and <code>Routines</code>; every row of the lists'
/// rules refused before any <code>PUT</code>; the editor's General Save refusing a list; and OcuPilot's own three
/// applications refused by every action and by the mint.</p>
/// <p>Every write is real for an application named <code>OcuProbe1831...</code> and a role named
/// <code>OcuProbe1833Role...</code> and the class touches no other. <b>It never writes <code>OcuPilotState</code>,
/// <code>OcuPilotIdentity</code> or <code>OcuPilotSslRead</code>:</b> every leg that names them is refused before the port,
/// and the class compares the three applications' stored state before and after each test, read-only.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates, changes and deletes probe
/// applications and roles and sets the governance policy. After each test the application list reads as that test
/// found it.</p>
Class OcuPilot.Test.RoutineAppMembers Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.RoutineAppProbe";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RoutineAppUpdate";

Parameter RULES = "OcuPilot.Area.WebApp.RoutineAppRules";

Parameter PORT = "OcuPilot.Port.AdminPort";

Parameter ACTIONPATH = "/screens/webapp.routineapps/action";

Parameter OWNCODE = "PROHIBITED.OCUPILOTROUTINEAPP";

/// <p>The probe application every leg edits.</p>
Parameter APP = "OcuProbe1831A";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

/// <p>OcuPilot's own three applications as the vendor reads them before the test.</p>
Property PreparedOwn As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RoutineAppMembers changes probe privileged routine applications on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts")
    Set ..PreparedOwn = ##class(OcuPilot.Test.RoutineAppWrite).OwnApplications()
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Kill tSettings
    Set tSettings("webapp.routineapps.update") = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe application, role and resource is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the application list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedFacts, "the application list reads as before the test")
    Do $$$AssertNotEquals(..PreparedOwn, "", "OcuPilot's own three applications were read before the test")
    Do $$$AssertEquals(##class(OcuPilot.Test.RoutineAppWrite).OwnApplications(), ..PreparedOwn, "and read the same after it")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
}

/// <p>C2: the four role actions add and remove an application role and a matching role as a delta over the fresh read,
/// and the routines the application holds are as read after each; a role already granted there, one not granted, an
/// absent role and an empty value are each 400 and write nothing.</p>
/// <p>Mutation (Rule 19): answer <code>##super</code> in place of the forwarded role delta in
/// <method>OcuPilot.Screen.Tool.RoutineAppUpdate.ScreenActionDelta</method> -- the role legs go red.</p>
Method TestTheRoleActionsApplyADeltaAndKeepTheRoutines()
{
    Set tRole = $ClassMethod(..#PROBE, "RoleName", "A")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureRole", "A"), "a probe role")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, $ClassMethod(..#PROBE, "WithLists")), "a probe application holding a role and a routine")
    Set tEntries = $ClassMethod(..#PROBE, "Entries", ..#APP)
    Do $$$AssertEquals(..Act("add-application-role", ..#APP, {"Role": (tRole)}), 200, "an application role is added")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Targets", ..#APP, ""), "%DB_HSCUSTOM," _ tRole, "the instance holds it beside the role it held")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Entries", ..#APP), tEntries, "and the routines are as they were read")
    Do $$$AssertEquals(..Act("add-matching-role", ..#APP, {"MatchRole": (tRole), "Role": "%Developer"}), 200, "a matching role is added")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Targets", ..#APP, tRole), "%Developer", "the instance holds it")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Targets", ..#APP, ""), "%DB_HSCUSTOM," _ tRole, "beside the application roles")
    Set tFacts = $ClassMethod(..#PROBE, "Facts")
    Set tRefused = "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS
    Do $$$AssertEquals($Piece(..Refusal("add-application-role", ..#APP, {"Role": (tRole)}), " ", 1, 2), tRefused, "adding a role already granted there is refused")
    Do $$$AssertEquals($Piece(..Refusal("remove-matching-role", ..#APP, {"MatchRole": (tRole), "Role": "%Operator"}), " ", 1, 2), tRefused, "removing one not granted there is refused")
    Do $$$AssertEquals($Piece(..Refusal("add-application-role", ..#APP, {"Role": "OcuProbe1833RoleNone"}), " ", 1, 2), tRefused, "and an absent role")
    Do $$$AssertEquals($Piece(..Refusal("add-matching-role", ..#APP, {"MatchRole": "", "Role": "%SQL"}), " ", 1, 2), tRefused, "and an empty matching role")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), tFacts, "none of them wrote anything")
    Do $$$AssertEquals(..Act("remove-matching-role", ..#APP, {"MatchRole": (tRole), "Role": "%Developer"}), 200, "the matching role is removed")
    Do $$$AssertEquals(..Act("remove-application-role", ..#APP, {"Role": (tRole)}), 200, "and the application role")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Targets", ..#APP, "") _ "|" _ $ClassMethod(..#PROBE, "Targets", ..#APP, tRole), "%DB_HSCUSTOM|", "leaving the role the application held")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Entries", ..#APP), tEntries, "and the routines as they were read")
}

/// <p>C2: the two routine actions add and remove an entry as a delta over the fresh read, and the roles the application
/// holds are as read after each; an entry already listed (its database in any case), one not listed, an empty value, a
/// name holding a comma or a colon, a database the instance does not define and a type that is not Routine or Class are
/// each 400 and write nothing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.WebApp.RoutineAppRules.EntryValid</method> accept any database -- the
/// unlisted database leg goes red; answer <code>##super</code> in place of the routine delta -- every routine leg goes
/// red.</p>
Method TestTheRoutineActionsApplyADeltaAndKeepTheRoles()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, $ClassMethod(..#PROBE, "WithLists")), "a probe application holding a role and a routine")
    Set tTargets = $ClassMethod(..#PROBE, "Targets", ..#APP, "")
    Do $$$AssertEquals(..Act("add-routine", ..#APP, ..Entry("OcuProbe1833.Added", "HSCUSTOM", "Class")), 200, "a class is added")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Entries", ..#APP), "OcuProbe1831.Routine:HSCUSTOM:Class,OcuProbe1833.Added:HSCUSTOM:Class", "the instance lists it beside the entry it held")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Targets", ..#APP, ""), tTargets, "and the roles are as they were read")
    Do $$$AssertEquals(..Act("add-routine", ..#APP, ..Entry("OcuProbe1833Routine", "HSCUSTOM", "Routine")), 200, "a routine is added")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Entries", ..#APP) [ "OcuProbe1833Routine:HSCUSTOM:Routine", "the instance lists it as a routine")
    Set tFacts = $ClassMethod(..#PROBE, "Facts")
    Set tRefused = "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS _ " "
    Set tListed = tRefused _ "the application already lists that routine or class"
    Set tNotListed = tRefused _ "the application does not list that routine or class"
    Set tBroken = tRefused _ ##class(OcuPilot.Api.Error).ReasonForViolation($Parameter($Parameter(..#RULES, "ERRORCLASS"), "ROUTINES"))
    Do $$$AssertEquals(..Refusal("add-routine", ..#APP, ..Entry("OcuProbe1833.Added", "hscustom", "Class")), tListed, "an entry already listed, its database in other case, is refused with a sentence that names no value")
    Do $$$AssertEquals(..Refusal("remove-routine", ..#APP, ..Entry("OcuProbe1833.Added", "HSCUSTOM", "Routine")), tNotListed, "removing one with another type is refused")
    Do $$$AssertEquals(..Refusal("remove-routine", ..#APP, ..Entry("OcuProbe1833.Nothing", "HSCUSTOM", "Class")), tNotListed, "and one not listed")
    Do $$$AssertEquals(..Refusal("add-routine", ..#APP, ..Entry("OcuProbe1833,Comma", "HSCUSTOM", "Class")), tBroken, "a name holding a comma is refused with the routines rule's sentence")
    Do $$$AssertEquals(..Refusal("add-routine", ..#APP, ..Entry("OcuProbe1833:Colon", "HSCUSTOM", "Class")), tBroken, "and one holding a colon")
    Do $$$AssertEquals(..Refusal("add-routine", ..#APP, ..Entry("OcuProbe1833.Other", "OCUPROBE1833NODB", "Class")), tBroken, "and a database the instance does not define")
    Do $$$AssertEquals(..Act("add-routine", ..#APP, ..Entry("OcuProbe1833.Other", "hscustom", "Class")), 400, "and one named in other case")
    Do $$$AssertEquals(..Act("add-routine", ..#APP, ..Entry("OcuProbe1833.Other", "HSCUSTOM", "Function")), 400, "and a type that is neither Routine nor Class")
    Do $$$AssertEquals(..Act("add-routine", ..#APP, ..Entry("OcuProbe1833.Other", "HSCUSTOM", "class")), 400, "and one spelled in other case")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), tFacts, "none of them wrote anything")
    Do $$$AssertEquals(..Act("remove-routine", ..#APP, ..Entry("OcuProbe1833.Added", "hscustom", "Class")), 200, "an entry is removed, its database named in other case")
    Do $$$AssertEquals(..Act("remove-routine", ..#APP, ..Entry("OcuProbe1833Routine", "HSCUSTOM", "Routine")), 200, "and the routine")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Entries", ..#APP), "OcuProbe1831.Routine:HSCUSTOM:Class", "leaving the entry the application held")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Targets", ..#APP, ""), tTargets, "and the roles are as they were read")
    Do $$$AssertEquals(..Act("remove-routine", ..#APP, ..Entry("OcuProbe1831.Routine", "HSCUSTOM", "Class")), 200, "the last entry is removed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Entries", ..#APP) _ "|" _ $ClassMethod(..#PROBE, "Targets", ..#APP, ""), "|" _ tTargets, "leaving none, and the roles as read")
}

/// <p>C3: a routine action whose name, database or type is empty, or only spaces, is 400 and writes nothing, on both
/// routine actions; the held entry is the base, so the blank member is the only thing wrong. A value of only spaces gets
/// the sentence naming its member, which the rules' refusal does not name.</p>
/// <p>Mutation (Rule 19): drop the <code>$ZStrip</code> from the blank test in
/// <method>OcuPilot.Screen.Tool.RoutineAppUpdate.ScreenActionDelta</method> -- the spaces legs go red.</p>
Method TestABlankRoutineValueIsRefusedByBothRoutineActions()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, $ClassMethod(..#PROBE, "WithLists")), "a probe application holding a role and a routine")
    Set tFacts = $ClassMethod(..#PROBE, "Facts")
    Set tRefused = "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS _ " '"
    Set tMembers = $ListBuild($ListBuild("RoutineOrClass", "the routine or class"), $ListBuild("Db", "its database"), $ListBuild("Type", "its type, Routine or Class"))
    For tAction = "add-routine", "remove-routine" {
        For tI = 1:1:$ListLength(tMembers) {
            Set tMember = $List($List(tMembers, tI), 1)
            Set tEntry = ..Entry("OcuProbe1831.Routine", "HSCUSTOM", "Class")
            Do tEntry.%Set(tMember, "   ")
            Do $$$AssertEquals(..Refusal(tAction, ..#APP, tEntry), tRefused _ tMember _ "' names " _ $List($List(tMembers, tI), 2) _ " and cannot be empty", tAction _ ": a " _ tMember _ " of only spaces is refused naming the member")
            Do tEntry.%Set(tMember, "")
            Do $$$AssertEquals(..Act(tAction, ..#APP, tEntry), 400, tAction _ ": an empty " _ tMember _ " is refused")
        }
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), tFacts, "none of them wrote anything")
}

/// <p>C2: the agent sends each list whole through the update's mint and confirm: a complete <code>MatchRoles</code>
/// stores it and keeps the routines as read, a complete <code>Routines</code> stores it and keeps the roles as read, both
/// at once store both, an empty list removes every entry, and the payload carries both lists whichever it changes
/// (AD-4). A list equal to the stored one changes nothing and is refused at the mint.</p>
/// <p>Mutation (Rule 19): drop <code>Routines</code> from <method>OcuPilot.Screen.Tool.RoutineAppUpdate.SettableFields</method>
/// -- the routines legs go red at the mint.</p>
Method TestTheAgentSendsEachListWhole()
{
    Set tRole = $ClassMethod(..#PROBE, "RoleName", "A")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureRole", "A"), "a probe role")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, $ClassMethod(..#PROBE, "WithLists")), "a probe application holding a role and a routine")
    Set tEntries = $ClassMethod(..#PROBE, "Entries", ..#APP)
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, ..#APP, {"Name": (..#APP), "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM", (tRole)]}]}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a complete MatchRoles is minted (" _ tProblem _ ")")
    Set tPayload = ##class(%DynamicObject).%FromJSON(##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "payload"))
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tPayload), "Description,Enabled,MatchRoles,Resource,Routines", "its payload carries the three settings and both lists")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals(##class(OcuPilot.Test.RoutineAppWrite).Verdict($Get(tResult)), "matches", "its read-back matches")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Targets", ..#APP, "") _ "|" _ $ClassMethod(..#PROBE, "Entries", ..#APP), "%DB_HSCUSTOM," _ tRole _ "|" _ tEntries, "the instance holds the roles and the routines as read")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, ..#APP, {"Name": (..#APP), "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM", (tRole)]}]}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "a list equal to the stored one is refused at the mint: " _ tProblem)
    Do $$$AssertTrue(tProblem [ "nothing would change", "and the refusal says nothing would change: " _ tProblem)
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, ..#APP, {"Name": (..#APP), "Routines": [{"RoutineOrClass": "OcuProbe1833.New", "Db": "HSCUSTOM", "Type": "Class"}, {"RoutineOrClass": "OcuProbe1833Routine", "Db": "HSCUSTOM", "Type": "Routine"}]}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a complete Routines is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Entries", ..#APP) _ "|" _ $ClassMethod(..#PROBE, "Targets", ..#APP, ""), "OcuProbe1833.New:HSCUSTOM:Class,OcuProbe1833Routine:HSCUSTOM:Routine|%DB_HSCUSTOM," _ tRole, "the instance holds the routines it was sent, the entry it held gone, and the roles as read")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, ..#APP, {"Name": (..#APP), "MatchRoles": [{"MatchRole": (tRole), "TargetRoles": ["%Developer"]}], "Routines": [{"RoutineOrClass": "OcuProbe1833.Both", "Db": "HSCUSTOM", "Type": "Class"}]}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "both lists are minted together (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Targets", ..#APP, "") _ "|" _ $ClassMethod(..#PROBE, "Targets", ..#APP, tRole) _ "|" _ $ClassMethod(..#PROBE, "Entries", ..#APP), "|%Developer|OcuProbe1833.Both:HSCUSTOM:Class", "the instance holds both")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, ..#APP, {"Name": (..#APP), "MatchRoles": [], "Routines": []}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "two empty lists are minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Lists", ..#APP), "[]|[]", "which removes every entry")
}

/// <p>C3: every row of the lists' rules is refused before any <code>PUT</code>: the rules answer the field and the code,
/// the agent's mint answers the field and the published sentence, and the application is as it was. A routines list with
/// several broken entries answers its code once.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.WebApp.RoutineAppRules.RoutinesViolation</method> add nothing -- every
/// routines row goes red; make <method>OcuPilot.Area.WebApp.RoutineAppRules.Judged</method> answer 0 -- every row goes
/// red; drop the <code>$ZStrip</code> from <method>OcuPilot.Area.WebApp.RoutineAppRules.EntryValid</method>'s name test
/// -- the only-spaces row goes red.</p>
Method TestEveryListRuleIsRefusedBeforeAnyPut()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, $ClassMethod(..#PROBE, "WithLists")), "a probe application holding a role and a routine")
    Set tFacts = $ClassMethod(..#PROBE, "Facts")
    Set tShape = ##class(OcuPilot.Api.Error).#WEBAPPMATCHROLESSHAPE
    Set tUnknown = ##class(OcuPilot.Api.Error).#WEBAPPMATCHROLESUNKNOWN
    Set tRoutines = $Parameter($Parameter(..#RULES, "ERRORCLASS"), "ROUTINES")
    Set tCases = $ListBuild($ListBuild("roles not a list", "{""MatchRoles"": ""x""}", "MatchRoles", tShape), $ListBuild("role entry not an object", "{""MatchRoles"": [1]}", "MatchRoles", tShape), $ListBuild("role entry without targets", "{""MatchRoles"": [{""MatchRole"": """"}]}", "MatchRoles", tShape), $ListBuild("role entry with a third member", "{""MatchRoles"": [{""MatchRole"": """", ""TargetRoles"": [""%SQL""], ""Extra"": 1}]}", "MatchRoles", tShape), $ListBuild("role absent", "{""MatchRoles"": [{""MatchRole"": """", ""TargetRoles"": [""OcuProbe1833RoleNone""]}]}", "MatchRoles", tUnknown), $ListBuild("matching role absent", "{""MatchRoles"": [{""MatchRole"": ""OcuProbe1833RoleNone"", ""TargetRoles"": [""%SQL""]}]}", "MatchRoles", tUnknown))
    Set tCases = tCases _ $ListBuild($ListBuild("routines not a list", "{""Routines"": ""x""}", "Routines", tRoutines), $ListBuild("entry not an object", "{""Routines"": [1]}", "Routines", tRoutines), $ListBuild("entry of two members", "{""Routines"": [{""RoutineOrClass"": ""a"", ""Db"": ""HSCUSTOM""}]}", "Routines", tRoutines), $ListBuild("entry of four members", "{""Routines"": [{""RoutineOrClass"": ""a"", ""Db"": ""HSCUSTOM"", ""Type"": ""Class"", ""Extra"": ""x""}]}", "Routines", tRoutines), $ListBuild("entry member a number", "{""Routines"": [{""RoutineOrClass"": ""a"", ""Db"": ""HSCUSTOM"", ""Type"": 1}]}", "Routines", tRoutines), $ListBuild("name empty", "{""Routines"": [{""RoutineOrClass"": """", ""Db"": ""HSCUSTOM"", ""Type"": ""Class""}]}", "Routines", tRoutines), $ListBuild("name of only spaces", "{""Routines"": [{""RoutineOrClass"": ""   "", ""Db"": ""HSCUSTOM"", ""Type"": ""Class""}]}", "Routines", tRoutines), $ListBuild("name with a comma", "{""Routines"": [{""RoutineOrClass"": ""a,b"", ""Db"": ""HSCUSTOM"", ""Type"": ""Class""}]}", "Routines", tRoutines), $ListBuild("name with a colon", "{""Routines"": [{""RoutineOrClass"": ""a:b"", ""Db"": ""HSCUSTOM"", ""Type"": ""Class""}]}", "Routines", tRoutines), $ListBuild("database unlisted", "{""Routines"": [{""RoutineOrClass"": ""a"", ""Db"": ""OCUPROBE1833NODB"", ""Type"": ""Class""}]}", "Routines", tRoutines), $ListBuild("database in other case", "{""Routines"": [{""RoutineOrClass"": ""a"", ""Db"": ""hscustom"", ""Type"": ""Class""}]}", "Routines", tRoutines), $ListBuild("type unknown", "{""Routines"": [{""RoutineOrClass"": ""a"", ""Db"": ""HSCUSTOM"", ""Type"": ""Function""}]}", "Routines", tRoutines), $ListBuild("type in other case", "{""Routines"": [{""RoutineOrClass"": ""a"", ""Db"": ""HSCUSTOM"", ""Type"": ""routine""}]}", "Routines", tRoutines))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tChange = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Set tSC = $ClassMethod(..#RULES, "Check", "", "", tChange, "", "update", ..#PORT, .tViolations, 0)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the rules answer")
        Do $$$AssertEquals(+$Get(tViolations) _ " " _ $Select($Get(tViolations) '= 0: $List(tViolations(1), 1) _ " " _ $List(tViolations(1), 2), 1: ""), "1 " _ $List(tCase, 3) _ " " _ $List(tCase, 4), $List(tCase, 1) _ ": one violation on its field with its code")
        Do tChange.%Set("Name", ..#APP)
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, ..#APP, tChange, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 1) _ ": the agent's change is refused (" _ tProblem _ ")")
        Do $$$AssertTrue(tProblem [ ("'" _ $List(tCase, 3) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 4))), $List(tCase, 1) _ ": naming the field and the published sentence: " _ tProblem)
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), tFacts, $List(tCase, 1) _ ": and nothing was written")
    }
    Set tMany = {"Routines": [{"RoutineOrClass": "", "Db": "HSCUSTOM", "Type": "Class"}, {"RoutineOrClass": "a", "Db": "OCUPROBE1833NODB", "Type": "Class"}]}
    Set tSC = $ClassMethod(..#RULES, "Check", "", "", tMany, "", "update", ..#PORT, .tViolations, 0)
    Do $$$AssertEquals(+$Get(tViolations), 1, "several broken entries answer the routines code once")
    Set tSC = $ClassMethod(..#RULES, "Check", "", "", ##class(%DynamicObject).%FromJSON($ClassMethod(..#PROBE, "WithLists").%ToJSON()), $ClassMethod(..#PROBE, "WithLists"), "update", ..#PORT, .tViolations, 1)
    Do $$$AssertEquals(+$Get(tViolations), 0, "a list equal to the fresh read's is not judged again")
    Set tStale = {"MatchRoles": [{"MatchRole": "", "TargetRoles": ["OcuProbe1833RoleNone"]}], "Routines": [{"RoutineOrClass": "a", "Db": "OCUPROBE1833NODB", "Type": "Class"}]}
    Kill tViolations
    Set tSC = $ClassMethod(..#RULES, "Check", "", "", ##class(%DynamicObject).%FromJSON(tStale.%ToJSON()), tStale, "update", ..#PORT, .tViolations, 1)
    Do $$$AssertEquals(+$Get(tViolations), 0, "lists the fresh read holds are not judged on a setting-only update, though the rules would refuse them")
    Set tChanged = ##class(%DynamicObject).%FromJSON(tStale.%ToJSON())
    Do tChanged.%Get("Routines").%Push({"RoutineOrClass": "b", "Db": "HSCUSTOM", "Type": "Class"})
    Kill tViolations
    Set tSC = $ClassMethod(..#RULES, "Check", "", "", tChanged, tStale, "update", ..#PORT, .tViolations, 1)
    Do $$$AssertEquals(+$Get(tViolations) _ " " _ $Select($Get(tViolations) '= 0: $List(tViolations(1), 1), 1: ""), "1 Routines", "a list that differs from it is judged whole, the other still not")
    Kill tViolations
    Set tSC = $ClassMethod(..#RULES, "Check", "", "", ##class(%DynamicObject).%FromJSON(tStale.%ToJSON()), "", "update", ..#PORT, .tViolations, 0)
    Do $$$AssertEquals(+$Get(tViolations), 2, "and the agent's arguments, judged without a read, are refused in both")
}

/// <p>C4: the editor's General Save sends its three settings and refuses a list with 400
/// <code>PORT.FIELDUNEXPECTED</code>, nothing sent; a Save of the settings alone keeps both lists as read (AD-4).</p>
/// <p>Mutation (Rule 19): drop the <code>SaveFields</code> override from <class>OcuPilot.Area.WebApp.RoutineAppSave</class>
/// -- the list legs go red, the Save accepting a list.</p>
Method TestTheGeneralSaveRefusesAListAndKeepsBoth()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "", ..#APP, $ClassMethod(..#PROBE, "WithLists")), "a probe application holding a role and a routine")
    Set tFacts = $ClassMethod(..#PROBE, "Facts")
    For tBody = "{""MatchRoles"": []}", "{""Routines"": []}", "{""Description"": ""x"", ""Routines"": [], ""MatchRoles"": []}" {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/routine-application/" _ $ClassMethod(..#PROBE, "PathId", ..#APP), .tStatus, .tAnswer, tBody, "application/json")
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, tBody _ " is refused as an unexpected field")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), tFacts, "nothing was written")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/routine-application/" _ $ClassMethod(..#PROBE, "PathId", ..#APP), .tStatus, .tAnswer, {"Description": "general"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 200, "a Save of a setting is accepted")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "", ..#APP, "Description"), "general", "and the description changed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Targets", ..#APP, "") _ "|" _ $ClassMethod(..#PROBE, "Entries", ..#APP), "%DB_HSCUSTOM|OcuProbe1831.Routine:HSCUSTOM:Class", "with both lists as they were")
}

/// <p>C4: OcuPilot's own three applications are refused by every one of the six actions as 403
/// <code>PROHIBITED.OCUPILOTROUTINEAPP</code>, whether the value names something they hold or not; by the kernel's early
/// refusal, the set asked about a change of each list, and the port arm; and by the agent's mint of a list change.
/// Nothing is sent, and the three applications read as they did.</p>
/// <p>Mutation (Rule 19), never writing the own applications, one arm at a time: drop the <code>routine-application</code>
/// own-application arm from <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -- the set's legs go red, and
/// the action and mint legs stay green because the early refusal and the port arm refuse too; make
/// <method>OcuPilot.Screen.Tool.RoutineAppUpdate.RefusedBeforeState</method> answer 0 -- the removes, which the delta then
/// refuses for an entry the application does not hold, and the mint legs go red, and the set still refuses every
/// write.</p>
Method TestTheOwnApplicationsAreRefusedByEachActionAndTheMint()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureRole", "A"), "a probe role")
    Set tRole = $ClassMethod(..#PROBE, "RoleName", "A")
    Set tValues = {}
    Do tValues.%Set("add-application-role", {"Role": (tRole)})
    Do tValues.%Set("remove-application-role", {"Role": (tRole)})
    Do tValues.%Set("add-matching-role", {"MatchRole": (tRole), "Role": "%Developer"})
    Do tValues.%Set("remove-matching-role", {"MatchRole": (tRole), "Role": "%Developer"})
    Do tValues.%Set("add-routine", ..Entry("OcuProbe1833.Own", "HSCUSTOM", "Class"))
    Do tValues.%Set("remove-routine", ..Entry("OcuProbe1833.Own", "HSCUSTOM", "Class"))
    For tName = "OcuPilotState", "OcuPilotIdentity", "OcuPilotSslRead", "ocupilotstate" {
        Set tRefused = $ClassMethod("OcuPilot.Kernel.Proposal.Prohibited", "RefusesBeforeState", tName, .tCode)
        Do $$$AssertEquals(tRefused _ " " _ tCode, "1 " _ ..#OWNCODE, tName _ " is refused before its state is read")
        Set tRefused = $ClassMethod(..#UPDATETOOL, "RefusedBeforeState", tName, .tCode)
        Do $$$AssertEquals(tRefused _ " " _ tCode, "1 " _ ..#OWNCODE, "by the update tool")
        Set tRefused = $ClassMethod("OcuPilot.Kernel.Proposal.Prohibited", "RoutineEndpointRefused", "PUT", tName, .tCode)
        Do $$$AssertEquals(tRefused _ " " _ tCode, "1 " _ ..#OWNCODE, "and the port arm refuses a PUT of it")
        For tField = "MatchRoles", "Routines" {
            Set tBody = {}
            Do tBody.%Set(tField, [])
            Set tProhibits = ##class(OcuPilot.Test.RoutineAppWrite).Ask("webapp.routineapps.update", tName, tBody.%ToJSON(), [{"field": (tField), "before": "a", "after": "x"}].%ToJSON(), .tCode, .tSC)
            Do $$$AssertStatusOK(tSC, "the set answers a diff naming " _ tField)
            Do $$$AssertEquals(tProhibits _ " " _ tCode, "1 " _ ..#OWNCODE, tName _ "'s " _ tField _ " is refused")
        }
        Set tIterator = tValues.%GetIterator()
        While tIterator.%GetNext(.tAction, .tActionValues) {
            Set tStatus = ..Act(tAction, tName, tActionValues, .tBody)
            Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""), "403 " _ ..#OWNCODE, tAction _ " on " _ tName _ " is refused")
        }
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, tName, {"Name": (tName), "MatchRoles": []}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tHttp _ " " _ tProblem, "0 403 " _ ..#OWNCODE, "the agent's roles change of " _ tName _ " is refused at the mint")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, tName, {"Name": (tName), "Routines": []}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tHttp _ " " _ tProblem, "0 403 " _ ..#OWNCODE, "and its routines change")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.RoutineAppWrite).OwnApplications(), ..PreparedOwn, "OcuPilot's own three applications read as they did")
}

/// <p>One role-or-routine action <var>pAction</var> on <var>pId</var> with <var>pValues</var>, over the screen's own
/// action route; answers the HTTP status and, in <var>pBody</var>, the envelope.</p>
ClassMethod Act(pAction As %String, pId As %String, pValues As %DynamicObject, Output pBody As %DynamicObject) As %Integer
{
    Set tRequest = {"action": (pAction), "id": (pId), "values": (pValues)}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#ACTIONPATH, .tStatus, .pBody, tRequest.%ToJSON(), "application/json")
    If $$$ISERR(tSC) Quit 0
    Quit tStatus
}

/// <p>One action as <method>Act</method> sends it, answered as the status, the envelope's code and its
/// <code>detail.problem</code>, joined by a space.</p>
ClassMethod Refusal(pAction As %String, pId As %String, pValues As %DynamicObject) As %String
{
    Set tStatus = ..Act(pAction, pId, pValues, .tBody)
    If '$IsObject($Get(tBody)) Quit tStatus
    Set tProblem = ""
    If tBody.%GetTypeOf("detail") = "object" Set tProblem = tBody.detail.%Get("problem")
    Quit tStatus _ " " _ tBody.%Get("code") _ " " _ tProblem
}

/// <p>The values of a routine action.</p>
ClassMethod Entry(pName As %String, pDb As %String, pType As %String) As %DynamicObject
{
    Quit {"RoutineOrClass": (pName), "Db": (pDb), "Type": (pType)}
}

}
