/// <p>Story 14.4's stores: what a conversation entry keeps (its screen context, definition and
/// time), the fallbacks an older entry reads, the Transcripts list's rows and their scoping, the
/// owner lookup, and the two descriptors that declare the list and the transcript page.</p>
/// <p><b>Live-safe.</b> It creates no principal and spawns nothing; every conversation it writes
/// names <parameter>PROBEUSER</parameter> or <code>$USERNAME</code> and is deleted by key in
/// <method>OnAfterOneTest</method>.</p>
Class OcuPilot.Test.TranscriptStore Extends %UnitTest.TestCase
{

Parameter PROBEUSER = "OcuPilotProbeTranscriptStore";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The conversation keys this method created, for its teardown.</p>
Property CreatedKeys As %String [ MultiDimensional ];

Method OnAfterOneTest() As %Status
{
    Set tKey = ""
    For {
        Set tKey = $Order(..CreatedKeys(tKey))
        If tKey = "" Quit
        Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tKey)
    }
    Kill ..CreatedKeys
    Quit $$$OK
}

/// <p>A new conversation for <var>pUser</var>, its lock released at once.</p>
Method NewConversation(pUser As %String) As %String
{
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", pUser, 5, .tStatus, .tConflict)
    If '$IsObject(tConvo) Quit ""
    Set tKey = tConvo.ConvKey
    Set tConvo = ""
    Set ..CreatedKeys(tKey) = ""
    Quit tKey
}

/// <p>Append one completed entry to conversation <var>pKey</var>.</p>
ClassMethod Append(pKey As %String, pMessage As %String, pContext As %String = "", pDefinitionId As %String = "") As %Status
{
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate(pKey, "", 5, .tStatus, .tConflict)
    If '$IsObject(tConvo) Quit tStatus
    Set tSC = ##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, pMessage, "completed", "a reply", "", 0, [], 0, ..#LIMITS, "", "", pContext, pDefinitionId)
    Set tConvo = ""
    Quit tSC
}

/// <p>AC1: an entry keeps the screen context its turn was started with, the definition it ran
/// under and the time it was appended; the opt-in read answers <code>appendedAt</code> and the
/// parsed <code>context</code>, and the default read keeps the panel's shape.</p>
/// <p>Mutation (Rule 19): drop the <code>ContextJson</code> write from
/// <method>OcuPilot.Kernel.State.Entry.GuardedAppend</method> -- the context reads null and this
/// goes red.</p>
Method TestAnEntryKeepsItsContextDefinitionAndTime()
{
    Set tKey = ..NewConversation(..#PROBEUSER)
    Do $$$AssertNotEquals(tKey, "", "a conversation is created")
    Set tContext = {"route": "tasks/schedule", "view": {"rows": [{"Name": "nightly"}]}, "rowsSent": 1}
    Do $$$AssertStatusOK(..Append(tKey, "What runs tonight?", tContext.%ToJSON(), "4242"), "an entry is appended")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Entry).GuardedRows(tKey, .tRows, 1), "the opt-in read runs")
    Do $$$AssertEquals(tRows.%Size(), 1, "one entry")
    Set tRow = tRows.%Get(0)
    Do $$$AssertTrue($IsObject(tRow.context), "the entry carries its screen context")
    If $IsObject(tRow.context) {
        Do $$$AssertEquals(tRow.context.route, "tasks/schedule", "with its route")
        Do $$$AssertEquals(tRow.context.view.rows.%Get(0).Name, "nightly", "and its rows, as stored")
    }
    Do $$$AssertTrue($Match(tRow.appendedAt, "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$"), "and the ISO time it was appended: " _ tRow.appendedAt)
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT DefinitionId FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ?", tKey)
    Do $$$AssertTrue(tRS.%Next() && (tRS.%GetData(1) = "4242"), "and the definition it ran under")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Entry).GuardedRows(tKey, .tPlain), "the default read runs")
    Set tPlainRow = tPlain.%Get(0)
    Do $$$AssertEquals(tPlainRow.%IsDefined("context"), 0, "and the panel's read carries no context")
    Do $$$AssertEquals(tPlainRow.%IsDefined("appendedAt"), 0, "and no time")

    Do $$$AssertStatusOK(..Append(tKey, "And after that?"), "a turn with no context is appended")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Entry).GuardedRows(tKey, .tRows, 1), "the opt-in read runs again")
    Do $$$AssertEquals(tRows.%Get(1).%GetTypeOf("context"), "null", "and a turn that carried none reads null")
}

/// <p>An entry stored before the new columns existed reads its conversation's
/// <code>CreatedAt</code> for its time and no context, and a gap left by a removed entry does not
/// stop the conversation appending.</p>
Method TestAnOlderEntryFallsBackAndTheSequenceContinuesPastAGap()
{
    Set tKey = ..NewConversation(..#PROBEUSER)
    Do $$$AssertStatusOK(..Append(tKey, "first"), "an entry is appended")
    Do $$$AssertStatusOK(..Append(tKey, "second"), "and another")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Entry SET AppendedAt = NULL, DefinitionId = NULL WHERE %EXACT(ConvoKey) = ? AND Seq = 2", tKey)
    Do $$$AssertTrue(tRS.%SQLCODE >= 0, "the second entry is made to look older than the columns")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT CreatedAt FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(ConvKey) = ?", tKey)
    Do tRS.%Next()
    Set tCreated = tRS.%GetData(1)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Entry).GuardedRows(tKey, .tRows, 1), "the read runs")
    Do $$$AssertEquals(tRows.%Get(1).appendedAt, tCreated, "and the older entry reads its conversation's CreatedAt")

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ? AND Seq = 1", tKey)
    Do $$$AssertStatusOK(..Append(tKey, "third"), "an entry appends after the first was removed")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(Seq) FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ?", tKey)
    Do tRS.%Next()
    Do $$$AssertEquals(tRS.%GetData(1), 3, "one past the highest sequence the conversation holds")
}

/// <p>AC1 in the store: the Transcripts list names only conversations holding an entry, reports
/// each one's turns, start and last activity, and gives a title only on the caller's own row, cut
/// at 120 characters. This process holds <code>%All</code>, so it is the administrator's view and
/// the probe user's row is listed without its title; the non-administrator's own-only view is
/// <class>OcuPilot.Test.TranscriptsWire</class>'s.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.State.Convo.GuardedScreenRows</method> answer
/// the start as the last activity -- this goes red.</p>
Method TestTheListNamesConversationsWithEntriesAndTitlesOnlyTheCallersOwn()
{
    Set tOther = ..NewConversation(..#PROBEUSER)
    Do $$$AssertStatusOK(..Append(tOther, "another user's private question"), "another user's conversation holds an entry")
    Set tEmpty = ..NewConversation(..#PROBEUSER)
    Set tOwn = ..NewConversation($Username)
    Set tLong = $Translate($Justify("", 150), " ", "x")
    Do $$$AssertStatusOK(..Append(tOwn, tLong), "the caller's own holds one")
    Do $$$AssertStatusOK(..Append(tOwn, "again"), "and a second")
    For tPair = $ListBuild("Convo", "CreatedAt", "2026-01-01T00:00:00Z", ""), $ListBuild("Entry", "AppendedAt", "2026-01-01T12:00:00Z", 1), $ListBuild("Entry", "AppendedAt", "2026-01-02T00:00:00Z", 2) {
        If $List(tPair, 1) = "Convo" {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Convo SET CreatedAt = ? WHERE %EXACT(ConvKey) = ?", $List(tPair, 3), tOwn)
        } Else {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Entry SET AppendedAt = ? WHERE %EXACT(ConvoKey) = ? AND Seq = ?", $List(tPair, 3), tOwn, $List(tPair, 4))
        }
        Do $$$AssertEquals(tRS.%SQLCODE, 0, "the caller's conversation is dated: " _ $List(tPair, 1) _ " " _ $List(tPair, 3))
    }

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).GuardedScreenRows(.tRows), "the list reads")
    Kill tById
    For tI = 0:1:tRows.%Size() - 1 {
        Set tById(tRows.%Get(tI).id) = tRows.%Get(tI)
    }
    Do $$$AssertEquals($Data(tById(tEmpty)), 0, "a conversation with no entry is not listed")
    Do $$$AssertEquals($Data(tById(tOther)), 1, "an administrator sees another user's conversation")
    If $Data(tById(tOther)) {
        Do $$$AssertEquals(tById(tOther).user, ..#PROBEUSER, "naming its user")
        Do $$$AssertEquals(tById(tOther).title, "", "and never its first message")
        Do $$$AssertEquals(tById(tOther).turns, 1, "with its turn count")
    }
    Do $$$AssertEquals($Data(tById(tOwn)), 1, "and their own")
    If $Data(tById(tOwn)) {
        Do $$$AssertEquals(tById(tOwn).title, $Extract(tLong, 1, 120), "whose title is the first message cut at 120 characters")
        Do $$$AssertEquals(tById(tOwn).turns, 2, "with both turns counted")
        Do $$$AssertEquals(tById(tOwn).started, "2026-01-01T00:00:00Z", "started is the conversation's start")
        Do $$$AssertEquals(tById(tOwn).lastActivity, "2026-01-02T00:00:00Z", "and last activity its newest entry's time")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).GuardedScreenRows(.tOne, 1), "a capped read runs")
    Do $$$AssertEquals(tOne.%Size(), 1, "and answers no more than its cap")
    Do $$$AssertStatusNotOK(##class(OcuPilot.Kernel.State.Convo).GuardedScreenRows(.tBad, "1; DROP"), "a cap that is not a whole number is refused")
}

/// <p>The owner lookup answers the stored user for a key and nothing for an unknown one.</p>
Method TestTheOwnerLookupAnswersTheStoredUser()
{
    Set tKey = ..NewConversation(..#PROBEUSER)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).GuardedOwnerOf(tKey, .tUser), "the lookup runs")
    Do $$$AssertEquals(tUser, ..#PROBEUSER, "and names the user who created it")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).GuardedOwnerOf("no-such-conversation", .tNone), "an unknown key reads")
    Do $$$AssertEquals(tNone, "", "as no owner")
}

/// <p>The Transcripts list and the transcript page are declared as Story 14.4 fixes them: a list
/// at side-bar position 4 with no pair and no entity type over the <code>Convo</code> state read,
/// and an unlisted detail beneath it with no read. The registry admits both.</p>
Method TestTheListAndTheTranscriptPageAreDeclared()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Registry).Validate(.tProblem), "the registry validates: " _ $Get(tProblem))
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Descriptor.AgentTranscripts).DeclarationJson(.tList), "the list's declaration reads")
    Do $$$AssertEquals(tList.route, "agent/transcripts", "the list's route")
    Do $$$AssertEquals(tList.archetype, "list", "is a list")
    Do $$$AssertEquals(tList.sideBarPosition, 4, "at the agent area's fourth position")
    Do $$$AssertEquals(tList.privileges.%Size(), 0, "declaring no pair")
    Do $$$AssertEquals(tList.entityType, "", "and no entity type")
    Do $$$AssertEquals(tList.read.source.port, "state", "reading OcuPilot's own state")
    Do $$$AssertEquals(tList.read.source.endpoint, "Convo", "through the conversation store")
    Do $$$AssertEquals(tList.toolIdentifier, "agent.transcripts", "under its own tool identifier")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Descriptor.AgentTranscript).DeclarationJson(.tDetail), "the page's declaration reads")
    Do $$$AssertEquals(tDetail.route, "agent/transcripts/details", "the page's route")
    Do $$$AssertEquals(tDetail.archetype, "detail", "is a detail")
    Do $$$AssertEquals(tDetail.sideBarPosition, 0, "taking no side-bar position")
    Do $$$AssertEquals(tDetail.parentScope, "agent/transcripts", "beneath the list")
    Do $$$AssertEquals(tDetail.%IsDefined("read"), 0, "with no read")
    Do $$$AssertEquals(tDetail.suggestedPrompts.%ToJSON(), tList.suggestedPrompts.%ToJSON(), "and the list's three prompts")
}

}
