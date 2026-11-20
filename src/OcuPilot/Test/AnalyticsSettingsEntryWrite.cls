/// <p>Pins Story 24.13 Batch 3's six writes against <code>USER</code> (AD-6, AD-13, AD-15, AD-22, AD-53, AD-54, AD-58, AD-59, AD-65): a run-time variable and a user-defined icon are each added, changed and removed by the
/// person's action (the Add dialog's save, the tab's row actions) and by the agent's confirmed proposal. Each write leaves what was sent in the vendor's global and every other variable and icon as it was, reads back
/// <code>matches</code> (a removal <code>notFound</code>), is read by the screen and by the agent's read tool, and leaves one OcuPilot <code>ConfigChange</code> row naming the namespace and the name and never the text.
/// A variable's expression, which is code, is stored as text and run by nothing here: <code>^OcuProbe2413Ran</code>, which the probe expression would set, stays undefined through every write, read and script. The six
/// script forms make the same change as the writes and write nothing while another process holds the namespace's settings lock; the agent's cards carry the consequences the spec names.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, an analytics-enabled <code>USER</code> namespace the
/// fixture turns on, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it rewrites <code>USER</code>'s analytics settings (restored from a snapshot). One class per run.</p>
Class OcuPilot.Test.AnalyticsSettingsEntryWrite Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter WRITE = "OcuPilot.Test.AnalyticsSettingsWrite";

Parameter SEAM = "OcuPilot.Test.AnalyticsSettingsLockSeam";

Parameter NAMESPACE = "USER";

Parameter VARIABLETOOLS = "OcuPilot.Screen.Tool.AnalyticsRuntimeVariableAdd,OcuPilot.Screen.Tool.AnalyticsRuntimeVariableSet,OcuPilot.Screen.Tool.AnalyticsRuntimeVariableRemove";

Parameter ICONTOOLS = "OcuPilot.Screen.Tool.AnalyticsUserIconAdd,OcuPilot.Screen.Tool.AnalyticsUserIconSet,OcuPilot.Screen.Tool.AnalyticsUserIconRemove";

/// <p>The probe's names and the expression that would set <code>^OcuProbe2413Ran</code> if anything ever ran it.</p>
Parameter VARIABLE = "OcuProbe2413Var";

Parameter ICON = "OcuProbe2413Icon";

Parameter EXPRESSION = "$Increment(^OcuProbe2413Ran)";

Property StartDigest As %String;

Property StartTaken As %Boolean [ InitialExpression = 0 ];

/// <p>The governance policy found before a test turned a key on, restored after it.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsEntryWrite turns analytics on in USER and rewrites its analytics settings, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "SnapshotSettings")
    If $$$ISOK(tSC) Set ..StartDigest = $ClassMethod(..#PROBE, "SettingsDigest"), ..StartTaken = 1
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsEntryWrite left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && ..StartTaken && ($ClassMethod(..#PROBE, "SettingsDigest") '= ..StartDigest) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsEntryWrite left USER's analytics settings changed")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set ..PreparedPolicyTaken = 0
    Do ..KillRan()
    Quit $ClassMethod(..#PROBE, "ClearSettings")
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Release", ..#NAMESPACE)
    Lock -^CacheTemp.OcuPilotAnalyticsSettings(..#NAMESPACE)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    If ..PreparedPolicyTaken {
        Kill tPolicy
        Merge tPolicy = ..PreparedPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
        Set ..PreparedPolicyTaken = 0
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Do ..KillRan()
    Quit $ClassMethod(..#PROBE, "ClearSettings")
}

/// <p>Kill <code>^OcuProbe2413Ran</code>, which the probe expression would set if anything ran it, in <code>USER</code>, where the settings are, and in the namespace this test runs in, where the port runs.</p>
ClassMethod KillRan()
{
    Set tOrigNS = $NAMESPACE
    Kill ^OcuProbe2413Ran
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Kill ^OcuProbe2413Ran
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>Turn the governance key <var>pKey</var> on for this test; the policy found is restored by <method>OnAfterOneTest</method>.</p>
Method EnableKey(pKey As %String)
{
    If '..PreparedPolicyTaken {
        Kill tPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy), "the governance policy is read")
        Merge ..PreparedPolicy = tPolicy
        Set ..PreparedPolicyTaken = 1
    }
    Kill tSettings
    Set tSettings(pKey) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), pKey _ " is turned on")
}

/// <p>The run-time variable <var>pName</var> in <code>USER</code> as <code>stored|expression|comment|context</code>.</p>
ClassMethod Variable(pName As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "unread"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tText = ''$Data(^DeepSee.User.Settings(pName)) _ "|" _ $Get(^DeepSee.User.Settings(pName, "value")) _ "|" _ $Get(^DeepSee.User.Settings(pName, "comment")) _ "|" _ $Get(^DeepSee.User.Settings(pName, "context"))
    } Catch ex {
        Set tText = "unread " _ ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p>The user-defined icon <var>pName</var> in <code>USER</code> as <code>stored|path</code>.</p>
ClassMethod Icon(pName As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "unread"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tText = ''$Data(^DeepSee.User.Icons(pName)) _ "|" _ $Get(^DeepSee.User.Icons(pName))
    } Catch ex {
        Set tText = "unread " _ ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p>Store a variable (<var>pIcon</var> 0) or an icon (1) in <code>USER</code> through the vendor's own setters, as the classic page does, for a test that changes or removes one.</p>
ClassMethod Seed(pIcon As %Boolean, pName As %String, pA As %String = "", pComment As %String = "", pContext As %String = "")
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If pIcon {
            Do ##class(%DeepSee.UserPortal.Utils).%SetUserIcon(pName, pA)
        } Else {
            Do ##class(%DeepSee.UserPortal.Utils).%SetUserSetting(pName, pA, pComment, pContext)
        }
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>Whether <code>^OcuProbe2413Ran</code>, which the probe expression would set if it ran, is defined in <code>USER</code>, where the settings are, or in the namespace this test runs in, where the port
/// runs: <code>0</code> when neither holds it.</p>
ClassMethod Ran() As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tData = $Data(^OcuProbe2413Ran)
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tData = tData + $Data(^OcuProbe2413Ran)
    } Catch {
        Set tData = -1
    }
    Set $NAMESPACE = tOrigNS
    Quit tData
}

/// <p>The person's row action <var>pAction</var> of the screen <var>pScreen</var> on <var>pId</var> with <var>pValues</var>, as <class>OcuPilot.Test.AnalyticsSettingsWrite</class> sends it: the status, the answer in <var>pAnswer</var>.</p>
ClassMethod Act(pScreen As %String, pAction As %String, pId As %String, pValues As %DynamicObject, Output pAnswer) As %Integer
{
    Quit $ClassMethod(..#WRITE, "Act", pScreen, pAction, pId, pValues, .pAnswer)
}

/// <p>The person's Add dialog's save <var>pPath</var> with <var>pBody</var>: the status, the answer in <var>pAnswer</var>.</p>
ClassMethod Post(pPath As %String, pBody As %DynamicObject, Output pAnswer) As %Integer
{
    Do $ClassMethod(..#CONTROL, "Call", "POST", pPath, pBody, .tStatus, .pAnswer)
    Quit tStatus
}

/// <p>The agent's mint of <var>pTool</var> with <var>pArgs</var> as the HTTP account, then its confirm over HTTP: the single envelope the confirm answers in <var>pAnswer</var>, the proposal in
/// <var>pProposal</var> and the turn in <var>pTurn</var>. The caller removes the turn's ledger rows.</p>
Method Through(pTool As %String, pArgs As %DynamicObject, Output pAnswer, Output pProposal, Output pTurn As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .tFault, .pTurn)
    Do $$$AssertStatusOK(tSC, $Parameter(pTool, "TOOLNAME") _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(pProposal)) Quit
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", pProposal.proposalId, .tStatus, .tRaw, .pAnswer)
    Do $$$AssertEquals(tStatus, 200, $Parameter(pTool, "TOOLNAME") _ " confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(pAnswer) && ($Length(tRaw, "}{") = 1), "exactly one envelope")
}

/// <p>The audit rows added by a write of <var>pEntity</var> <var>pName</var> with the verb <var>pVerb</var> since <var>pSince</var>, over the baseline taken before it.</p>
ClassMethod Rows(pSince As %String, pEntity As %String, pName As %String, pVerb As %String, pBase As %Integer, Output pData As %String) As %Integer
{
    Quit $ClassMethod(..#WRITE, "Added", pSince, pEntity, pName, pVerb, pBase, .pData)
}

/// <p>AC1, AC2, AC5: a run-time variable is added, changed and removed by the person and by the agent. The vendor holds what was sent and keeps the other variables, the answers' read-backs match (a removal
/// finds it gone), the screen's read and the agent's read tool answer the new state, and one <code>ConfigChange</code> row per write names the namespace and the variable, never the expression. The agent's remove
/// applies once the test turns its key on.</p>
/// <p>Mutation (Rule 19): drop <code>AuditWrite</code> from <method>OcuPilot.Port.AnalyticsPort.SendSetting</method> for the run-time variables -- the audit legs go red; set the comment from the stored row in
/// place of the body in the same method -- the change legs go red.</p>
Method TestAVariableIsAddedChangedAndRemovedByBothCallers()
{
    Set tName = ..#VARIABLE
    Do ..Seed(0, "OcuProbe2413Other", "1", "other", "")
    Set tOther = ..Variable("OcuProbe2413Other")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Rows(tSince, "analytics-runtime-variable", tName, "analytics.runtimevariables.add", 0)
    Set tStatus = ..Post("/analytics/runtime-variables", {"Name": (tName), "Value": (..#EXPRESSION), "Comment": "OcuProbe2413 comment", "Context": "OcuProbe2413Context"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "the person's Add run-time variable answers 201: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.readBack.verdict, ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "and the read-back matches")
    Do $$$AssertEquals(..Variable(tName), "1|" _ ..#EXPRESSION _ "|OcuProbe2413 comment|OcuProbe2413Context", "the vendor holds what was sent, the expression as text")
    Do $$$AssertEquals(..Variable("OcuProbe2413Other"), tOther, "and another variable is unchanged")
    Do $$$AssertEquals(..Rows(tSince, "analytics-runtime-variable", tName, "analytics.runtimevariables.add", tBase, .tData), 1, "one ConfigChange row names the add")
    Do $$$AssertTrue((tData [ """variable"":""" _ tName _ """") && (tData [ """namespace"":""USER""") && (tData '[ "Increment") && (tData '[ "OcuProbe2413 comment"), "naming the namespace and the variable, never the text: " _ tData)
    Set tRow = $ClassMethod(..#WRITE, "RowWhere", $ClassMethod(..#WRITE, "ScreenRows", "analytics.runtimevariables"), "Name", tName)
    Do $$$AssertTrue($IsObject(tRow) && (tRow.Value = ..#EXPRESSION) && (tRow.Comment = "OcuProbe2413 comment"), "the screen reads the new row")
    Set tToolRow = $ClassMethod(..#WRITE, "ToolRow", "analytics.runtimevariables.read", "Name", tName)
    Do $$$AssertTrue($IsObject(tToolRow) && (tToolRow.Context = "OcuProbe2413Context"), "and the agent's read tool answers it")

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Rows(tSince, "analytics-runtime-variable", tName, "analytics.runtimevariables.set", 0)
    Set tStatus = $ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "set", tName, {"Comment": "OcuProbe2413 changed"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's Change run-time variable answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching")
    Do $$$AssertEquals(..Variable(tName), "1|" _ ..#EXPRESSION _ "|OcuProbe2413 changed|OcuProbe2413Context", "only the comment changed")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "set", tName, {"Value": "1+1"}, .tValue), 200, "a new expression is stored")
    Do $$$AssertEquals(..Variable(tName), "1|1+1|OcuProbe2413 changed|OcuProbe2413Context", "and the comment and the context are kept")
    Do $$$AssertEquals(..Rows(tSince, "analytics-runtime-variable", tName, "analytics.runtimevariables.set", tBase), 2, "one ConfigChange row per change")

    Set tAgent = tName _ "Agent"
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Rows(tSince, "analytics-runtime-variable", tAgent, "analytics.runtimevariables.add", 0)
    Do ..Through($Piece(..#VARIABLETOOLS, ",", 1), {"Name": (tAgent), "Value": (..#EXPRESSION), "Comment": "agent"}, .tConfirmed, .tProposal, .tTurn)
    If $IsObject($Get(tConfirmed)) Do $$$AssertEquals(tConfirmed.action _ "|" _ tConfirmed.createdId _ "|" _ tConfirmed.readBack.verdict, "created|" _ tAgent _ "|matches", "the agent's add is created, naming the variable, the read-back matching")
    Do $$$AssertEquals(..Variable(tAgent), "1|" _ ..#EXPRESSION _ "|agent|", "the vendor holds what the agent sent")
    Do $$$AssertEquals(..Rows(tSince, "analytics-runtime-variable", tAgent, "analytics.runtimevariables.add", tBase), 1, "one ConfigChange row names the agent's add")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, "analytics.runtimevariables.add"), 1, "and the ledger holds it once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Rows(tSince, "analytics-runtime-variable", tAgent, "analytics.runtimevariables.set", 0)
    Do ..Through($Piece(..#VARIABLETOOLS, ",", 2), {"Name": (tAgent), "Context": "agentctx"}, .tConfirmed, .tProposal, .tTurn)
    If $IsObject($Get(tConfirmed)) Do $$$AssertEquals(tConfirmed.action _ "|" _ tConfirmed.readBack.verdict, "updated|matches", "the agent's change is updated, the read-back matching")
    Do $$$AssertEquals(..Variable(tAgent), "1|" _ ..#EXPRESSION _ "|agent|agentctx", "the agent's change keeps what it left out")
    Do $$$AssertEquals(..Rows(tSince, "analytics-runtime-variable", tAgent, "analytics.runtimevariables.set", tBase), 1, "and one ConfigChange row names the agent's change")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Set tToolRow = $ClassMethod(..#WRITE, "ToolRow", "analytics.runtimevariables.read", "Name", tAgent)
    Do $$$AssertTrue($IsObject(tToolRow) && (tToolRow.Context = "agentctx"), "and the read tool answers it")

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Rows(tSince, "analytics-runtime-variable", tName, "analytics.runtimevariables.remove", 0)
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "remove", tName, "", .tRemoved), 200, "the person's Remove run-time variable runs: " _ $Select($IsObject(tRemoved): $Extract(tRemoved.%ToJSON(), 1, 300), 1: tRemoved))
    If $IsObject(tRemoved) Do $$$AssertEquals(tRemoved.action _ "|" _ tRemoved.readBack.verdict, "deleted|notFound", "deleted, the read-back finding it gone")
    Do $$$AssertEquals(..Variable(tName), "0|||", "the vendor holds none")
    Do $$$AssertEquals(..Rows(tSince, "analytics-runtime-variable", tName, "analytics.runtimevariables.remove", tBase), 1, "and one ConfigChange row names the person's removal")
    Do $$$AssertEquals(..Variable(tAgent) _ "|" _ ..Variable("OcuProbe2413Other"), "1|" _ ..#EXPRESSION _ "|agent|agentctx|" _ tOther, "and the other variables are as they were")
    Do ..EnableKey("analytics.runtimevariables.remove")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Rows(tSince, "analytics-runtime-variable", tAgent, "analytics.runtimevariables.remove", 0)
    Do ..Through($Piece(..#VARIABLETOOLS, ",", 3), {"Name": (tAgent)}, .tConfirmed, .tProposal, .tTurn)
    If $IsObject($Get(tConfirmed)) Do $$$AssertEquals(tConfirmed.action _ "|" _ tConfirmed.readBack.verdict, "deleted|notFound", "with its key on the agent's remove applies, the read-back finding it gone")
    Do $$$AssertEquals(..Variable(tAgent), "0|||", "the vendor holds none")
    Do $$$AssertEquals(..Rows(tSince, "analytics-runtime-variable", tAgent, "analytics.runtimevariables.remove", tBase), 1, "and one ConfigChange row names the agent's removal")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC1, AC2, AC5: a user-defined icon is added, changed and removed by the person and by the agent as a variable is; the path is text, kept exactly, and the answers carry it as text.</p>
/// <p>Mutation (Rule 19): remove the icon's verb branch of <method>OcuPilot.Port.AnalyticsPort.SendSetting</method>'s audit -- the audit legs go red.</p>
Method TestAnIconIsAddedChangedAndRemovedByBothCallers()
{
    Set tName = ..#ICON
    Do ..Seed(1, "OcuProbe2413OtherIcon", "/other.png")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Rows(tSince, "analytics-user-icon", tName, "analytics.usericons.add", 0)
    Set tStatus = ..Post("/analytics/user-icons", {"Name": (tName), "Path": "http://OcuProbe2413.invalid/a.png"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "the person's Add icon answers 201: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.readBack.verdict, "matches", "and the read-back matches")
    Do $$$AssertEquals(..Icon(tName), "1|http://OcuProbe2413.invalid/a.png", "the vendor holds the path as sent")
    Do $$$AssertEquals(..Rows(tSince, "analytics-user-icon", tName, "analytics.usericons.add", tBase, .tData), 1, "one ConfigChange row names the add")
    Do $$$AssertTrue((tData [ """icon"":""" _ tName _ """") && (tData '[ "invalid"), "naming the icon, never the path: " _ tData)
    Set tRow = $ClassMethod(..#WRITE, "RowWhere", $ClassMethod(..#WRITE, "ScreenRows", "analytics.usericons"), "Name", tName)
    Do $$$AssertTrue($IsObject(tRow) && (tRow.Path = "http://OcuProbe2413.invalid/a.png"), "the screen reads the new row, its path as text")
    Set tToolRow = $ClassMethod(..#WRITE, "ToolRow", "analytics.usericons.read", "Name", tName)
    Do $$$AssertTrue($IsObject(tToolRow) && (tToolRow.Path = "http://OcuProbe2413.invalid/a.png"), "and the agent's read tool answers it")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Rows(tSince, "analytics-user-icon", tName, "analytics.usericons.set", 0)
    Set tStatus = $ClassMethod(..#WRITE, "Act", "analytics.usericons", "set", tName, {"Path": "/OcuProbe2413/b.png"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's Change icon answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching")
    Do $$$AssertEquals(..Icon(tName) _ "|" _ ..Icon("OcuProbe2413OtherIcon"), "1|/OcuProbe2413/b.png|1|/other.png", "the path changed and the other icon did not")
    Do $$$AssertEquals(..Rows(tSince, "analytics-user-icon", tName, "analytics.usericons.set", tBase), 1, "one ConfigChange row names the person's change")

    Set tAgent = tName _ "Agent"
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Rows(tSince, "analytics-user-icon", tAgent, "analytics.usericons.add", 0)
    Do ..Through($Piece(..#ICONTOOLS, ",", 1), {"Name": (tAgent), "Path": "/agent.png"}, .tConfirmed, .tProposal, .tTurn)
    If $IsObject($Get(tConfirmed)) Do $$$AssertEquals(tConfirmed.action _ "|" _ tConfirmed.createdId _ "|" _ tConfirmed.readBack.verdict, "created|" _ tAgent _ "|matches", "the agent's add is created, the read-back matching")
    Do $$$AssertEquals(..Icon(tAgent), "1|/agent.png", "the vendor holds the agent's path")
    Do $$$AssertEquals(..Rows(tSince, "analytics-user-icon", tAgent, "analytics.usericons.add", tBase), 1, "one ConfigChange row names the agent's add")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Rows(tSince, "analytics-user-icon", tAgent, "analytics.usericons.set", 0)
    Do ..Through($Piece(..#ICONTOOLS, ",", 2), {"Name": (tAgent), "Path": "/agent2.png"}, .tConfirmed, .tProposal, .tTurn)
    If $IsObject($Get(tConfirmed)) Do $$$AssertEquals(tConfirmed.action _ "|" _ tConfirmed.readBack.verdict, "updated|matches", "the agent's change is updated, the read-back matching")
    Do $$$AssertEquals(..Icon(tAgent), "1|/agent2.png", "the agent's change stores the new path")
    Do $$$AssertEquals(..Rows(tSince, "analytics-user-icon", tAgent, "analytics.usericons.set", tBase), 1, "one ConfigChange row names the agent's change")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Rows(tSince, "analytics-user-icon", tName, "analytics.usericons.remove", 0)
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.usericons", "remove", tName, "", .tRemoved), 200, "the person's Remove icon runs")
    If $IsObject(tRemoved) Do $$$AssertEquals(tRemoved.action _ "|" _ tRemoved.readBack.verdict, "deleted|notFound", "deleted, the read-back finding it gone")
    Do $$$AssertEquals(..Icon(tName), "0|", "the vendor holds none")
    Do $$$AssertEquals(..Rows(tSince, "analytics-user-icon", tName, "analytics.usericons.remove", tBase), 1, "one ConfigChange row names the removal")
    Do ..EnableKey("analytics.usericons.remove")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBase = ..Rows(tSince, "analytics-user-icon", tAgent, "analytics.usericons.remove", 0)
    Do ..Through($Piece(..#ICONTOOLS, ",", 3), {"Name": (tAgent)}, .tConfirmed, .tProposal, .tTurn)
    If $IsObject($Get(tConfirmed)) Do $$$AssertEquals(tConfirmed.action _ "|" _ tConfirmed.readBack.verdict, "deleted|notFound", "with its key on the agent's remove applies, the read-back finding it gone")
    Do $$$AssertEquals(..Rows(tSince, "analytics-user-icon", tAgent, "analytics.usericons.remove", tBase), 1, "one ConfigChange row names the agent's removal")
    Do $$$AssertEquals(..Icon(tAgent) _ "|" _ ..Icon("OcuProbe2413OtherIcon"), "0||1|/other.png", "and the other icon is as it was")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC3: the probe expression, which would set <code>^OcuProbe2413Ran</code> if anything ran it, is stored and read back as text by the person's add and change, by the agent's add and change, by the add and
/// change script forms and by every read (the screen's, the agent's tool and the port's single-row read), and the global stays undefined throughout. A variable that holds an expression that is not valid is still changed in
/// another member, and the check never runs the text it refuses.</p>
/// <p>The journal is scanned for the whole window, every process included because the person's and the agent's writes are served by other processes: no set or kill record names
/// <code>^OcuProbe2413Ran</code>, so a write followed by a kill of it is caught as well as a run that leaves it defined. The scan is shown able to see: a control write in the namespace this test runs in and one in
/// <code>USER</code> are both found, which they are only while the database that holds each is journaled, as both are on the throwaway; and the person's add, which another process served, is found by
/// the every-process scan and not by this process's own.</p>
/// <p>Mutation (Rule 19): run the expression in <method>OcuPilot.Port.AnalyticsPort.VariableExpressionHolds</method> (an <code>Xecute</code> of the line) -- the global leg goes red; set and then kill
/// <code>^OcuProbe2413Ran</code> there before the check -- only the journal leg goes red.</p>
Method TestAnExpressionIsNeverRun()
{
    Set tMark = $ClassMethod(..#PROBE, "JournalMark")
    Set tName = ..#VARIABLE
    Do $$$AssertEquals(..Post("/analytics/runtime-variables", {"Name": (tName), "Value": (..#EXPRESSION)}, .tAnswer), 201, "the person adds the probe expression")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "set", tName, {"Comment": "after"}, .tSet), 200, "and changes its comment")
    Do ..Through($Piece(..#VARIABLETOOLS, ",", 1), {"Name": (tName _ "Agent"), "Value": (..#EXPRESSION)}, .tConfirmed, .tProposal, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Do ..Through($Piece(..#VARIABLETOOLS, ",", 2), {"Name": (tName _ "Agent"), "Value": (..#EXPRESSION _ "+1")}, .tConfirmed, .tProposal, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Do ..RunScript("RuntimeVariables", "ENTRYADD", tName _ "Script", {"Value": (..#EXPRESSION)})
    Do ..RunScript("RuntimeVariables", "ENTRYSET", tName _ "Script", {"Value": (..#EXPRESSION _ "+2")})
    Do $$$AssertTrue($ClassMethod(..#WRITE, "ScreenRows", "analytics.runtimevariables").%Size() > 0, "the screen reads the variables")
    Do $$$AssertTrue($IsObject($ClassMethod(..#WRITE, "ToolRow", "analytics.runtimevariables.read", "Name", tName)), "and the agent's tool reads them")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tName
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Port.AnalyticsPort", "Invoke", "RuntimeVariables", "RUNTIMEVARIABLE", .tQuery, "", .tRow, .tHttp, .tFault), "and the port's single-row read answers")
    Do $$$AssertEquals(..Variable(tName), "1|" _ ..#EXPRESSION _ "|after|", "the expression is held as the text it was sent")
    Do $$$AssertEquals(..Variable(tName _ "Script"), "1|" _ ..#EXPRESSION _ "+2||", "and the script's change as well")
    Do $$$AssertEquals(..Ran(), 0, "^OcuProbe2413Ran, which the expression would set, is still undefined")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "set", tName, {"Value": "1+"}, .tBad), 400, "an expression that is not valid is refused")
    Do $$$AssertEquals(..Variable(tName), "1|" _ ..#EXPRESSION _ "|after|", "and nothing was written")
    Do $$$AssertEquals(..Ran(), 0, "and the check ran nothing")
    Do ..Seed(0, tName _ "Held", "1+", "", "")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Act", "analytics.runtimevariables", "set", tName _ "Held", {"Value": "1+", "Comment": "kept"}, .tHeld), 200, "a variable that holds an expression that is not valid is still changed in another member")
    Do $$$AssertEquals(..Variable(tName _ "Held"), "1|1+|kept|", "its expression kept as it was")
    Set tTotal = $ClassMethod(..#PROBE, "JournalWrites", tMark, .tWrites, 1)
    Set tOwn = $ClassMethod(..#PROBE, "JournalWrites", tMark, .tMine, 0)
    Set tServed = 0
    For tI = 1:1:tTotal {
        If tWrites(tI) [ ("(""" _ tName _ """") Set tServed = tServed + 1
    }
    Set tHere = 0
    For tI = 1:1:tOwn {
        If tMine(tI) [ ("(""" _ tName _ """") Set tHere = tHere + 1
    }
    Do $$$AssertTrue((tServed > 0) && (tHere = 0), "the every-process scan finds the person's add, which another process served (" _ tServed _ " records), and this process's own scan does not (" _ tHere _ ")")
    Set tNamed = 0
    Set tFirst = ""
    For tI = 1:1:tTotal {
        If tWrites(tI) [ "OcuProbe2413Ran" Set tNamed = tNamed + 1, tFirst = tFirst _ $Select(tFirst = "": "", 1: "; ") _ tWrites(tI)
    }
    Set ^OcuProbe2413Scan = 1
    Set ^|"USER"|OcuProbe2413Scan = 1
    Set tScanned = $ClassMethod(..#PROBE, "JournalWrites", tMark, .tAll, 1)
    Kill ^OcuProbe2413Scan
    Kill ^|"USER"|OcuProbe2413Scan
    Set tSeen = 0
    For tI = 1:1:tScanned {
        If $Get(tAll(tI)) [ "OcuProbe2413Scan" Set tSeen = tSeen + 1
    }
    Do $$$AssertTrue(tTotal > 0, "the journal scan spans the writes (" _ tTotal _ " records)")
    Do $$$AssertEquals(tNamed, 0, "no journaled write of ^OcuProbe2413Ran by any write, read or script" _ $Select(tNamed > 0: ": " _ $Extract(tFirst, 1, 240), 1: ""))
    Do $$$AssertEquals(tSeen, 2, "while the scan finds the control writes made after them, in this namespace and in USER" _ $Select(tScanned < 0: " (the journal rolled to another file)", 1: ""))
}

/// <p>Run the script form of <var>pType</var> on <var>pEndpoint</var> for <var>pId</var> with <var>pBody</var>, one line at a time, in the namespace it names, rendered by the port whose lock line gives up at once;
/// assert that its final status is OK, or not when <var>pExpectOK</var> is 0; when <var>pBusy</var> is 1 that its error text is the busy sentence.</p>
Method RunScript(pEndpoint As %String, pType As %String, pId As %String, pBody, pExpectOK As %Boolean = 1, pBusy As %Boolean = 0)
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    Set tSteps = $ClassMethod(..#SEAM, "Snippet", pEndpoint, pType, .tQuery, pBody)
    Do $$$AssertTrue($IsObject(tSteps) && (tSteps.%Size() = 1), pType _ " renders one script step")
    If '$IsObject(tSteps) || (tSteps.%Size() '= 1) Quit
    Set tOrigNS = $NAMESPACE
    XECUTE "Kill tSC,tOptions,tOption,tData,tMessage,tPage,tPanel,tNumber,tClass,tAt,tLocked"
    Try {
        For tI = 1:1:$Length(tSteps.%Get(0).text, $Char(10)) {
            Set tLine = $Piece(tSteps.%Get(0).text, $Char(10), tI)
            If tLine '= "" XECUTE tLine
        }
    } Catch ex {
        Do $$$AssertTrue(0, pType _ " script ran: " _ ex.DisplayString())
    }
    Set $NAMESPACE = tOrigNS
    Set tScriptStatus = $Get(@"tSC")
    Do $$$AssertEquals(''$System.Status.IsOK(tScriptStatus), ''pExpectOK, pEndpoint _ " " _ pType _ " script ends with its status " _ $Select(pExpectOK: "OK", 1: "refused") _ ": " _ $System.Status.GetErrorText(tScriptStatus))
    If pBusy Do $$$AssertTrue($System.Status.GetErrorText(tScriptStatus) [ ##class(OcuPilot.Api.Error).#REASONWRITETARGETBUSY, pEndpoint _ " " _ pType _ " script's refusal is the busy sentence: " _ $System.Status.GetErrorText(tScriptStatus))
}

/// <p>AC6: each of the six script forms, run in <code>USER</code>, makes the change the write makes (an add, a change that keeps what the body leaves out, a removal) and takes the same refusals (a name held, a name not
/// held, an expression that is not valid, a name that is too long). While another process holds the namespace's settings lock each writes nothing and ends with the busy sentence; once it is released the same
/// script applies.</p>
/// <p>Mutation (Rule 19): drop the lock line from the opening <method>OcuPilot.Port.AnalyticsPort.SettingSnippet</method> builds -- the held-lock leg goes red.</p>
Method TestEachWritesScriptFormMakesTheSameChange()
{
    Set tVar = ..#VARIABLE
    Set tIcon = ..#ICON
    Do ..RunScript("RuntimeVariables", "ENTRYADD", tVar, {"Value": "1+1", "Comment": "c", "Context": "x"})
    Do $$$AssertEquals(..Variable(tVar), "1|1+1|c|x", "the add script stores the variable")
    Do ..RunScript("RuntimeVariables", "ENTRYADD", tVar, {"Value": "2"}, 0)
    Do $$$AssertEquals(..Variable(tVar), "1|1+1|c|x", "an add of a held name is refused and changes nothing")
    Do ..RunScript("RuntimeVariables", "ENTRYSET", tVar, {"Comment": "changed"})
    Do $$$AssertEquals(..Variable(tVar), "1|1+1|changed|x", "the change script keeps the members the body leaves out")
    Do ..RunScript("RuntimeVariables", "ENTRYSET", tVar, {"Value": "1+"}, 0)
    Do ..RunScript("RuntimeVariables", "ENTRYSET", tVar _ "Missing", {"Comment": "x"}, 0)
    Do ..RunScript("RuntimeVariables", "ENTRYADD", $Translate($Justify("", 256), " ", "n"), {"Value": "1"}, 0)
    Do $$$AssertEquals(..Variable(tVar) _ "|" _ ..Variable(tVar _ "Missing"), "1|1+1|changed|x|0|||", "an expression that is not valid, a name that is not held and a name that is too long change nothing")
    Do ..RunScript("Worklists", "WORKLISTSHOW", ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Home", 1, "%DeepSee.UserPortal.RecentList")), {}, 0)
    Do ..RunScript("UserIcons", "ENTRYADD", tIcon, {"Path": "/a.png"})
    Do $$$AssertEquals(..Icon(tIcon), "1|/a.png", "the icon add script stores the icon")
    Do ..RunScript("UserIcons", "ENTRYADD", tIcon, {"Path": "/z.png"}, 0)
    Do ..RunScript("UserIcons", "ENTRYSET", tIcon, {"Path": "/b.png"})
    Do $$$AssertEquals(..Icon(tIcon), "1|/b.png", "the icon change script stores the new path")
    Do ..RunScript("UserIcons", "ENTRYREMOVE", tIcon _ "Missing", {}, 0)
    Do $$$AssertTrue($ClassMethod(..#SEAM, "Hold", ..#NAMESPACE), "another process took the namespace's settings lock")
    Do ..RunScript("RuntimeVariables", "ENTRYADD", tVar _ "Busy", {"Value": "1"}, 0, 1)
    Do ..RunScript("RuntimeVariables", "ENTRYSET", tVar, {"Comment": "busy"}, 0, 1)
    Do ..RunScript("RuntimeVariables", "ENTRYREMOVE", tVar, {}, 0, 1)
    Do ..RunScript("UserIcons", "ENTRYADD", tIcon _ "Busy", {"Path": "/busy.png"}, 0, 1)
    Do ..RunScript("UserIcons", "ENTRYSET", tIcon, {"Path": "/busy.png"}, 0, 1)
    Do ..RunScript("UserIcons", "ENTRYREMOVE", tIcon, {}, 0, 1)
    Set tHeld = ..Variable(tVar) _ "|" _ ..Variable(tVar _ "Busy") _ "|" _ ..Icon(tIcon) _ "|" _ ..Icon(tIcon _ "Busy")
    Do $$$AssertEquals(tHeld, "1|1+1|changed|x|0||||1|/b.png|0|", "with the lock held no script wrote anything: " _ tHeld)
    Do $ClassMethod(..#SEAM, "Release", ..#NAMESPACE)
    Do ..RunScript("RuntimeVariables", "ENTRYREMOVE", tVar, {})
    Do ..RunScript("UserIcons", "ENTRYREMOVE", tIcon, {})
    Set tReleased = ..Variable(tVar) _ "|" _ ..Icon(tIcon)
    Do $$$AssertEquals(tReleased, "0||||0|","once released the removal scripts apply: " _ tReleased)
    Do $$$AssertEquals(..Ran(), 0, "and no script ran an expression")
}

/// <p>The two routes the tabs' Add dialogs post to answer JSON envelopes of the declared type and shape as the HTTP account: <code>POST /analytics/runtime-variables</code> and <code>/analytics/user-icons</code> create
/// a row (201 <code>{id, target, readBack}</code>); a name that is held is a 409 envelope and a name or an expression outside the rules a 400 one, each carrying its code and its published sentence.</p>
/// <p>Mutation (Rule 19): answer 422 from <method>OcuPilot.Area.Analytics.SettingEntrySave.RenderViolations</method> -- the two 400 legs go red.</p>
Method TestTheRoutesAnswerJsonEnvelopesOfTheDeclaredShape()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tVariable = {"Name": "OcuProbe2413Wire", "Value": "1"}.%ToJSON()
    Set tIcon = {"Name": "OcuProbe2413WireIcon", "Path": "/w.png"}.%ToJSON()
    For tCase = $ListBuild("POST", "/analytics/runtime-variables?ns=USER", tVariable, 201), $ListBuild("POST", "/analytics/user-icons?ns=USER", tIcon, 201), $ListBuild("POST", "/analytics/runtime-variables?ns=USER", tVariable, 409, "ANALYTICS.VARIABLE.TAKEN"), $ListBuild("POST", "/analytics/user-icons?ns=USER", tIcon, 409, "ANALYTICS.ICON.TAKEN"), $ListBuild("POST", "/analytics/runtime-variables?ns=USER", {"Name": "OcuProbe2413WireBad", "Value": "1+"}.%ToJSON(), 400, "ANALYTICS.VARIABLE.EXPRESSION"), $ListBuild("POST", "/analytics/user-icons?ns=USER", {"Name": ""}.%ToJSON(), 400, "ANALYTICS.SETTING.NAME") {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest($List(tCase, 1), tBase _ $List(tCase, 2), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, $List(tCase, 3), "application/json")
        Do $$$AssertEquals(tStatus, $List(tCase, 4), $List(tCase, 2) _ " answers " _ $List(tCase, 4) _ ": " _ $Extract(tRaw, 1, 200))
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", $List(tCase, 2) _ ": its content type is JSON (" _ $Get(tHeaders("CONTENT-TYPE")) _ ")")
        Set tBody = ""
        Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
        If '$IsObject(tBody) {
            Do $$$AssertTrue(0, $List(tCase, 2) _ ": its body is one JSON document")
            Continue
        }
        If $List(tCase, 4) = 201 Do $$$AssertTrue(tBody.id '= "", "the create names its target")
        If $List(tCase, 4) > 299 Do $$$AssertTrue(tBody.code '= "", "a refusal carries its code")
        If $ListGet(tCase, 5) '= "" Do $$$AssertEquals(tBody.%Get("code") _ "|" _ tBody.%Get("reason"), $List(tCase, 5) _ "|" _ ##class(OcuPilot.Api.AnalyticsError).ReasonFor($List(tCase, 5)), $List(tCase, 2) _ ": the refusal carries its published sentence")
    }
}

/// <p>AC5: the agent's cards say what each write is: an add or a change of a variable carries <code>ANALYTICS.VARIABLE.CODE</code> (the expression is code), the removal of a variable
/// <code>ANALYTICS.VARIABLE.REMOVE</code> and of an icon <code>ANALYTICS.ICON.REMOVE</code>; an icon's add and change carry none.</p>
/// <p>Mutation (Rule 19): answer <code>""</code> from <method>OcuPilot.Screen.Tool.AnalyticsSettingEntryAction.Consequence</method>'s parameter, <parameter>CONSEQUENCECODE</parameter> of
/// <class>OcuPilot.Screen.Tool.AnalyticsRuntimeVariableAction</class> -- the variable legs go red.</p>
Method TestTheCardsSayWhatTheWriteStores()
{
    Do ..Seed(0, ..#VARIABLE, "1", "", "")
    Do ..Seed(1, ..#ICON, "/a.png")
    Do ..EnableKey("analytics.runtimevariables.remove")
    Do ..EnableKey("analytics.usericons.remove")
    For tCase = $ListBuild($Piece(..#VARIABLETOOLS, ",", 1), {"Name": (..#VARIABLE _ "New"), "Value": "1"}.%ToJSON(), "ANALYTICS.VARIABLE.CODE"), $ListBuild($Piece(..#VARIABLETOOLS, ",", 2), {"Name": (..#VARIABLE), "Comment": "x"}.%ToJSON(), "ANALYTICS.VARIABLE.CODE"), $ListBuild($Piece(..#VARIABLETOOLS, ",", 3), {"Name": (..#VARIABLE)}.%ToJSON(), "ANALYTICS.VARIABLE.REMOVE"), $ListBuild($Piece(..#ICONTOOLS, ",", 1), {"Name": (..#ICON _ "New"), "Path": "/n.png"}.%ToJSON(), ""), $ListBuild($Piece(..#ICONTOOLS, ",", 2), {"Name": (..#ICON), "Path": "/m.png"}.%ToJSON(), ""), $ListBuild($Piece(..#ICONTOOLS, ",", 3), {"Name": (..#ICON)}.%ToJSON(), "ANALYTICS.ICON.REMOVE") {
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", $List(tCase, 1), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 2)), ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, $Parameter($List(tCase, 1), "TOOLNAME") _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If $IsObject($Get(tProposal)) Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence"), $List(tCase, 3), $Parameter($List(tCase, 1), "TOOLNAME") _ ": the card's consequence")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    }
}

}
