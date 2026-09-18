/// <p>AC3 -- registration is the contract (AD-15). Every triple
/// <class>OcuPilot.Kernel.Audit.Event</class> can name is one the installer registers, an emission
/// through each is read back from the audit database as exactly one row, and the same emission
/// with that registration deleted returns an error status and produces no row.</p>
/// <p><b>The negative leg is what makes the positive one non-vacuous.</b> An unregistered triple
/// makes <code>$System.Security.Audit</code> return a bare failure and drop the event with no
/// error and no log line, so a round trip that only ever succeeds cannot tell a working
/// registration from a test that would pass without one.</p>
/// <p><b>It deletes an audit event registration, so <method>OnBeforeAllTests</method> refuses to
/// run unless <parameter>ARMINGVARIABLE</parameter> arms it.</b> Only
/// <file>scripts/ci-throwaway.sh</file> sets it: while the registration is gone, every row
/// OcuPilot would write under that triple is dropped silently, which on an instance someone cares
/// about is auditing quietly stopping.</p>
/// <p><b>Why the audit read looks like this (DW-85).</b> <class>%SYS.Audit</class>'s
/// <code>Event</code>, <code>EventSource</code> and <code>EventType</code> indexes are brought up
/// to date by a background pass about every 60 seconds, so a row younger than the last pass is
/// invisible to a query whose plan reads them, from any process. Every read here carries
/// <code>%NOINDEX</code> on the three event predicates and is bounded by
/// <code>UTCTimeStamp</code>, the first subscript of the table's IDKEY, so the plan reads the
/// master map over that range and sees the row at once.</p>
Class OcuPilot.Test.AuditEvent Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Anything else -- absent, empty, or a value that reads like a refusal such as
/// <code>0</code> -- refuses.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_AUDIT_EVENTS";

/// <p>The entity type the emitter legs below record against -- a value of
/// <class>OcuPilot.Kernel.EntityType</class>'s closed vocabulary.</p>
Parameter PROBETYPE = "agent-definition";

/// <p>A type no vocabulary holds, for the refusal leg.</p>
Parameter UNKNOWNTYPE = "probe-not-an-entity-type";

/// <p>The REST application's path from the origin root, for the leg that drives a real write while
/// a registration is missing.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The prefix the definition that leg edits is named with, so
/// <class>OcuPilot.Test.AgentFixture</class>'s teardown finds it.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>Whether <method>OnBeforeAllTests</method> installed and read the roster back.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

/// <p>The audit database's own clock, read just before each method's emissions so a read can be
/// bounded to the rows this run wrote. The prefix must not begin with "Test"
/// (<file>.claude/rules/objectscript-testing.md</file>).</p>
Property PreparedSince As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSetupOk = 0
    Set ..PreparedSince = ""
    Quit $$$OK
}

/// <p>Refuse to run at all unless <parameter>ARMINGVARIABLE</parameter> arms this class, then
/// install production so the roster is registered before anything reads it.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditEvent deletes an OcuPilot audit event registration on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was deleted. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSetupOk = ($ListLength(##class(OcuPilot.Kernel.Audit.Event).Names()) > 0)
    If '..PreparedSetupOk Quit $$$ERROR($$$GeneralError, "Setup read an empty audit-event roster, so every assertion here would be vacuous")
    Quit $$$OK
}

/// <p>Put back whatever a method deleted, and <b>return a failing status</b> if any roster triple
/// is still missing -- a class that left auditing off is a failure, not a passing run.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Set tMissing = ..MissingTriples()
    If tMissing '= "" {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditEvent left an audit event unregistered on this instance: " _ tMissing)
    }
    Quit $$$OK
}

/// <p>Every roster triple that is <b>not</b> registered on this instance, comma-separated, or
/// <code>""</code>. Reads the roster before the <code>%SYS</code> switch, because an
/// <code>OcuPilot</code> class reference evaluated there raises
/// <code>&lt;CLASS DOES NOT EXIST&gt;</code>.</p>
ClassMethod MissingTriples() As %String
{
    Set tSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
    Set tType = ##class(OcuPilot.Kernel.Audit.Event).Type()
    Set tNames = ##class(OcuPilot.Kernel.Audit.Event).Names()
    Set tMissing = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tNames) {
            Set tName = $List(tNames, tI)
            If '##class(Security.Events).Exists(tSource, tType, tName, .tObj, .tSC) {
                Set tMissing = tMissing _ $Select(tMissing = "": "", 1: ", ") _ tName
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tMissing = "the registrations could not be read: " _ ex.DisplayString()
    }
    Quit tMissing
}

/// <p>How many rows the audit database's master map holds for <var>pEvent</var> since
/// <var>pSince</var> whose <code>EventData</code> carries <var>pMarker</var> -- and
/// <var>pAlso</var>, when one is given -- with the last such row's data in <var>pData</var>.
/// <code>-1</code> when the read itself failed.</p>
/// <p><b><var>pSince</var> bounds the read; it does not identify a row.</b>
/// <code>$ZTimeStamp</code>'s fractional resolution is coarser than the interval between two
/// consecutive writes on this build -- measured here, two rows 14 ms apart both fell on or after
/// a bound taken between them -- so a caller that needs "the row this write produced" passes a
/// marker that only that row carries, and the time bound keeps the scan short.</p>
ClassMethod RowsCarrying(pSince As %String, pEvent As %String, pMarker As %String, Output pData As %String, pAlso As %String = "") As %Integer
{
    Set pData = ""
    Set tSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
    Set tType = ##class(OcuPilot.Kernel.Audit.Event).Type()
    Set tRows = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = ? AND %NOINDEX EventType = ? AND %NOINDEX Event = ?", pSince, tSource, tType, pEvent)
        If tRS.%SQLCODE < 0 {
            Set $NAMESPACE = tOrigNS
            Quit
        }
        Set tRows = 0
        While tRS.%Next() {
            Set tData = tRS.%Get("EventData")
            If tData '[ pMarker Continue
            If (pAlso '= "") && (tData '[ pAlso) Continue
            Set tRows = tRows + 1
            Set pData = tData
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tRows = -1
    }
    Quit tRows
}

/// <p>A marker unique to this call, so a read bounded by time cannot be satisfied by a row an
/// earlier run wrote in the same second.</p>
ClassMethod Marker() As %String
{
    Quit "OcuPilotProbeAudit" _ $Translate($System.Util.CreateGUID(), "-", "")
}

/// <p>The audit database's own clock, in the form <code>%SYS.Audit.UTCTimeStamp</code> carries.</p>
ClassMethod Now() As %String
{
    Quit $ZDateTime($ZTimeStamp, 3, , 3)
}

/// <p>AC3 -- every triple the emitter can name is registered, and the two names it selects
/// between are both in the roster it declares. This is the assertion that keeps the emitter from
/// naming a triple registration does not carry, which would be dropped with no error at all.</p>
/// <p>Mutation (Rule 19): drop one entry from
/// <method>OcuPilot.Kernel.Audit.Event.Roster</method>'s list without removing it from
/// <method>EventNameFor</method> -- the membership assertion goes red.</p>
Method TestEveryTripleTheEmitterCanNameIsRegistered()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup installed and read a non-empty roster")
    Set tNames = ##class(OcuPilot.Kernel.Audit.Event).Names()
    Do $$$AssertTrue($ListLength(tNames) >= 3, "the roster carries the grant marker and the two change events: " _ $ListLength(tNames))
    Do $$$AssertEquals(..MissingTriples(), "", "every triple the roster declares is registered on this instance")

    ; The other direction: the emitter must not be able to name something the roster does not.
    For tSecurity = 0, 1 {
        Set tName = ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(tSecurity)
        Do $$$AssertTrue($ListFind(tNames, tName) > 0, "the event name the emitter selects for securityChange " _ tSecurity _ " (" _ tName _ ") is in the roster registration carries")
    }
}

/// <p>AC3 -- an emission through each registered triple lands as exactly one row carrying the
/// data it was given, read back from the master map rather than from the emitter's own state.</p>
/// <p>Mutation (Rule 19): drop one triple from
/// <method>OcuPilot.Install.Installer.EnsureAuditEvents</method>'s roster loop -- that triple's
/// emission returns an error status and no row is found, red.</p>
Method TestAnEmissionThroughEachTripleIsOneRow()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup installed and read a non-empty roster")
    Set tSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
    Set tType = ##class(OcuPilot.Kernel.Audit.Event).Type()
    Set tNames = ##class(OcuPilot.Kernel.Audit.Event).Names()
    Set ..PreparedSince = ..Now()

    Kill tMarker
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tNames) {
            Set tMarker(tI) = ..Marker()
            Set tAuditSC = $System.Security.Audit(tSource, tType, $List(tNames, tI), tMarker(tI), "OcuPilot round-trip probe")
            Set tStatus(tI) = tAuditSC
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }

    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Do $$$AssertStatusOK(tStatus(tI), tName _ ": the emission through a registered triple succeeds")
        Set tRows = ..RowsCarrying(..PreparedSince, tName, tMarker(tI), .tData)
        Do $$$AssertEquals(tRows, 1, tName _ ": exactly one row carrying this run's own marker is in the audit master map")
        Do $$$AssertEquals(tData, tMarker(tI), tName _ ": and it carries the data it was written with")
    }
}

/// <p>AC3 -- the emitter's own row: one row per accepted change, under the event name its
/// classification selects, carrying the actor, the scoped target triple, the verb and the
/// changed-field set.</p>
/// <p>The refusal leg is here too: an entity type the kernel vocabulary does not hold is refused
/// by <class>OcuPilot.Kernel.EntityRef</class> before anything is written, so a slice cannot
/// invent a target type by spelling one (AD-14).</p>
/// <p>Mutation (Rule 19): make
/// <method>OcuPilot.Kernel.Audit.Event.EventNameFor</method> answer the same name for both
/// classifications -- the security row is found under the configuration event and the per-event
/// counts go red.</p>
Method TestTheEmitterWritesOneRowCarryingTheTargetAndTheChanges()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup installed and read a non-empty roster")
    Set ..PreparedSince = ..Now()
    Set tConfigName = ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(0)
    Set tSecurityName = ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(1)
    Set tConfigMarker = ..Marker()
    Set tSecurityMarker = ..Marker()

    Set tConfigChanges = {}
    Do tConfigChanges.%Set("maxTokens", {"old": "32000", "new": "4000"})
    Set tConfigSC = ##class(OcuPilot.Kernel.Audit.Event).Record("update", ..#PROBETYPE, tConfigMarker, tConfigChanges, 0)
    Do $$$AssertStatusOK(tConfigSC, "the configuration-change emission succeeds")

    Set tSecurityChanges = {}
    Do tSecurityChanges.%Set("endpointUrl", {"old": "https://192.0.2.1/v1/messages", "new": "https://198.51.100.7/v1/messages"})
    Set tSecuritySC = ##class(OcuPilot.Kernel.Audit.Event).Record("update", ..#PROBETYPE, tSecurityMarker, tSecurityChanges, 1)
    Do $$$AssertStatusOK(tSecuritySC, "the security-change emission succeeds")

    Set tConfigRows = ..RowsCarrying(..PreparedSince, tConfigName, tConfigMarker, .tConfigData)
    Do $$$AssertEquals(tConfigRows, 1, "exactly one " _ tConfigName _ " row was written")
    Do $$$AssertTrue(tConfigData [ ("""actor"":""" _ $Username _ """"), "naming the actor: " _ tConfigData)
    Do $$$AssertTrue(tConfigData [ ("""type"":""" _ ..#PROBETYPE _ """"), "and the target's entity type")
    Do $$$AssertTrue(tConfigData [ ("""scope"":""" _ ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE _ """"), "and the instance scope (AD-13)")
    Do $$$AssertTrue(tConfigData [ ("""id"":""" _ tConfigMarker _ """"), "and the target id")
    Do $$$AssertTrue(tConfigData [ """verb"":""update""", "and the verb")
    Do $$$AssertTrue(tConfigData [ """securityChange"":false", "classified as an ordinary configuration change")
    Do $$$AssertTrue(tConfigData [ """maxTokens"":{""old"":""32000"",""new"":""4000""}", "carrying the changed field in clear, old and new: " _ tConfigData)
    Do $$$AssertEquals(..RowsCarrying(..PreparedSince, tSecurityName, tConfigMarker, .tStray), 0, "and nothing under the security event name")

    Set tSecurityRows = ..RowsCarrying(..PreparedSince, tSecurityName, tSecurityMarker, .tSecurityData)
    Do $$$AssertEquals(tSecurityRows, 1, "exactly one " _ tSecurityName _ " row was written")
    Do $$$AssertTrue(tSecurityData [ """securityChange"":true", "classified as a security change: " _ tSecurityData)
    Do $$$AssertTrue(tSecurityData [ "198.51.100.7", "carrying the new endpoint (AD-42)")
    Do $$$AssertEquals(..RowsCarrying(..PreparedSince, tConfigName, tSecurityMarker, .tStray2), 0, "and nothing under the configuration event name")

    ; AD-14: the vocabulary is closed, and a target type outside it is refused before any row.
    Set tRefusedMarker = ..Marker()
    Set tRefusedSC = ##class(OcuPilot.Kernel.Audit.Event).Record("update", ..#UNKNOWNTYPE, tRefusedMarker, {}, 0)
    Do $$$AssertStatusNotOK(tRefusedSC, "an entity type the kernel vocabulary does not hold is refused")
    Do $$$AssertEquals(..RowsCarrying(..PreparedSince, tConfigName, tRefusedMarker, .tNone), 0, "and writes no row")
}

/// <p>AC3's negative leg -- with the registration deleted the same emission returns an error
/// status and produces no row, and a re-install puts it back. Without this the round trip above
/// could pass on an instance where registration did nothing at all.</p>
/// <p>Mutation (Rule 19): make
/// <method>OcuPilot.Kernel.Audit.Event.Record</method> return <code>$$$OK</code> whatever
/// <code>$System.Security.Audit</code> answered -- the dropped-emission assertion goes red while
/// the row count stays 0, which is the pair that distinguishes "reported the drop" from "wrote the
/// row".</p>
Method TestADeletedRegistrationDropsTheRowAndReportsIt()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup installed and read a non-empty roster")
    Set tSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
    Set tType = ##class(OcuPilot.Kernel.Audit.Event).Type()
    Set tConfigName = ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(0)
    Set ..PreparedSince = ..Now()

    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Events).Exists(tSource, tType, tConfigName, .tE, .tS) {
            Set tDeleteSC = ##class(Security.Events).Delete(tSource, tType, tConfigName)
            Do $$$AssertStatusOK(tDeleteSC, "the configuration-change registration is deleted, so absence is a current fact")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }

    Set tDroppedMarker = ..Marker()
    Set tDroppedSC = ##class(OcuPilot.Kernel.Audit.Event).Record("update", ..#PROBETYPE, tDroppedMarker, {}, 0)
    Do $$$AssertStatusNotOK(tDroppedSC, "an emission through a deleted registration returns an error status")
    Do $$$AssertEquals(..RowsCarrying(..PreparedSince, tConfigName, tDroppedMarker, .tNone), 0, "and produces no row")

    Set tRestoreSC = ##class(OcuPilot.Install.Installer).Install("")
    Do $$$AssertStatusOK(tRestoreSC, "re-install re-registers the deleted triple")
    Do $$$AssertEquals(..MissingTriples(), "", "and every roster triple is registered again")

    Set tRestoredMarker = ..Marker()
    Set tRestoredSC = ##class(OcuPilot.Kernel.Audit.Event).Record("update", ..#PROBETYPE, tRestoredMarker, {}, 0)
    Do $$$AssertStatusOK(tRestoredSC, "the same emission now succeeds")
    Do $$$AssertEquals(..RowsCarrying(..PreparedSince, tConfigName, tRestoredMarker, .tRestoredData), 1, "and lands as exactly one row")
}


/// <p>Put back any registration a method deleted, remove any definition it created, and report a
/// survivor of either as a failure. The restore is here as well as inside each method: a method
/// that aborted between its <code>Security.Events.Delete</code> and its re-install would otherwise
/// leave this instance's auditing silently off for every later class.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.EventProbe).Clear()
    Set tRestoreSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tRestoreSC) Quit tRestoreSC
    Set tMissing = ..MissingTriples()
    If tMissing '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditEvent left an audit event unregistered on this instance: " _ tMissing)
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    If $$$ISERR(tSC) Quit tSC
    If tRemaining '= 0 Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditEvent left " _ tRemaining _ " probe definition(s) on this instance")
    Quit $$$OK
}

/// <p>AC3, and the rest of the unregistered-triple row -- <b>a dropped emission neither fails the
/// write it records nor passes silently</b> (AD-15). The negative leg above establishes the status
/// and the absent row; these are the two halves it does not reach.</p>
/// <p>The write is driven over HTTP through the shipped
/// <method>OcuPilot.Api.Definitions.HandleUpdate</method>, so "the write still succeeds" is
/// observed where a caller sees it rather than from inside the emitter, and the stored value is
/// read back so a 200 over an unchanged row cannot pass. The report is captured through
/// <class>OcuPilot.Test.EventProbe</class>, which overrides the one reporting seam and leaves the
/// payload, the redaction and the <code>$System.Security.Audit</code> call real.</p>
/// <p>A <code>maxTokens</code> edit is the write chosen because it touches no security field, so
/// it is classified an ordinary configuration change and lands on the triple this method deleted.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Api.Definitions.LogChange</method> render a
/// failure when <method>RecordAudit</method>'s status is an error -- the 200 assertion goes red
/// while the no-row assertion stays green. Second mutation: delete the
/// <code>If $$$ISERR(tSC) Do ..LogFailure(...)</code> line from
/// <method>OcuPilot.Kernel.Audit.Event.Record</method> -- the three report assertions go red.</p>
Method TestADroppedEmissionNeitherFailsTheWriteNorPassesSilently()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup installed and read a non-empty roster")
    Set tSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
    Set tType = ##class(OcuPilot.Kernel.Audit.Event).Type()
    Set tConfigName = ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(0)
    Set ..PreparedSince = ..Now()

    Set tCreateSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "Dropped", 0, 0, .tRow)
    Do $$$AssertStatusOK(tCreateSC, "a definition exists for the write to be made against")
    If $$$ISERR(tCreateSC) Quit
    Set tId = tRow.%Id()
    Set tRow = ""

    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Events).Exists(tSource, tType, tConfigName, .tE, .tS) {
            Set tDeleteSC = ##class(Security.Events).Delete(tSource, tType, tConfigName)
            Do $$$AssertStatusOK(tDeleteSC, "the configuration-change registration is deleted, so the drop below is a current fact")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }

    ; The report, captured at the seam: the real payload and the real audit call run, and only the
    ; reporting is intercepted.
    Do ##class(OcuPilot.Test.EventProbe).Clear()
    Set tReportedSC = ##class(OcuPilot.Test.EventProbe).Record("update", ..#PROBETYPE, tId, {}, 0)
    Do $$$AssertStatusNotOK(tReportedSC, "the dropped emission returns an error status")
    Do $$$AssertEquals(##class(OcuPilot.Test.EventProbe).Captured("calls"), 1, "and reports the drop exactly once")
    Do $$$AssertEquals(##class(OcuPilot.Test.EventProbe).Captured("verb"), "update", "naming the verb")
    Do $$$AssertEquals(##class(OcuPilot.Test.EventProbe).Captured("id"), tId, "and the target it could not record")
    Do $$$AssertTrue(##class(OcuPilot.Test.EventProbe).Captured("reason") '= "", "with the reason the audit call gave: " _ ##class(OcuPilot.Test.EventProbe).Captured("reason"))
    Do $$$AssertEquals(##class(OcuPilot.Test.EventProbe).Captured("message"), ##class(OcuPilot.Kernel.Audit.Event).#DROPPEDCONFIG, "and the configuration-change sentence, this being a configuration change")

    ; The write itself, over the wire, while the triple its record needs is unregistered.
    Set tCallSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", ..#APIBASE _ "/agent/definitions/" _ tId, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders, "{""maxTokens"":4000}", "application/json")
    Do $$$AssertStatusOK(tCallSC, "the update request completes")
    Do $$$AssertEquals(tStatus, 200, "and the write still succeeds while its audit row is being dropped (" _ tBody _ ")")
    Set tOpenSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tAfterRow)
    Do $$$AssertStatusOK(tOpenSC, "the definition opens after the write")
    If $$$ISOK(tOpenSC) {
        Do $$$AssertEquals(tAfterRow.MaxTokens, 4000, "and carries the edited bound, so the 200 is a write that happened")
        Set tAfterRow = ""
    }
    Do $$$AssertEquals(..RowsCarrying(..PreparedSince, tConfigName, """id"":""" _ tId _ """", .tNone, """verb"":""update"""), 0, "and no audit row records it, which is the cost the caller is not told about")
    ; Read under the OTHER registered name as well. Only the configuration triple was deleted, so a
    ; regression that reclassified a maxTokens-only edit as a security change would write a real row
    ; under the still-registered SecurityChange triple and the assertion above would still read 0.
    Do $$$AssertEquals(..RowsCarrying(..PreparedSince, ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(1), """id"":""" _ tId _ """", .tNoneSecurity, """verb"":""update"""), 0, "and none under the still-registered security event name either, so the drop is a drop and not a reclassification")

    Set tRestoreSC = ##class(OcuPilot.Install.Installer).Install("")
    Do $$$AssertStatusOK(tRestoreSC, "re-install re-registers the deleted triple")
    Do $$$AssertEquals(..MissingTriples(), "", "and every roster triple is registered again")
}


/// <p>AC3 -- <b>the smoke check's two answers</b>. <method>OcuPilot.Install.Smoke.CheckAuditEvent</method>
/// is what keeps every later audit assertion from being vacuous, so its own discrimination is
/// asserted here rather than taken on trust: the baseline triple missing is <code>fail</code>, a
/// later roster entry missing is <code>skipped</code> naming it, and nothing missing is
/// <code>pass</code>.</p>
/// <p><code>skipped</code> is deliberately not counted as executed, so it can never fail a smoke
/// run -- which is why the baseline arm has to be a real <code>fail</code> and why an arm that
/// collapsed the two would be invisible on every green run.</p>
/// <p>It lives in this class rather than in <class>OcuPilot.Test.Smoke</class> because it deletes
/// registrations, which is what <parameter>ARMINGVARIABLE</parameter> arms.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Install.Smoke.CheckAuditEvent</method> note
/// <code>skipped</code> for the baseline as well -- the first leg goes red while the other two
/// stay green.</p>
Method TestTheSmokeCheckFailsOnTheBaselineAndSkipsOnALaterEntry()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup installed and read a non-empty roster")
    Set tBaseline = ##class(OcuPilot.Kernel.State.Base).#AUDITNAME
    Set tConfigName = ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(0)

    Set tOk = ##class(OcuPilot.Install.Smoke).Run("", "", "0", .tReport, .tCounts)
    Do $$$AssertTrue(##class(OcuPilot.Test.Smoke).Line(tReport, "auditevent") [ "pass", "with every triple registered the check passes: " _ ##class(OcuPilot.Test.Smoke).Line(tReport, "auditevent"))
    ; The verdict of this same run, so the failing verdict asserted below discriminates rather than
    ; repeating a run that was already red for a reason unrelated to the registrations.
    Do $$$AssertEquals(tOk, 1, "and the run as a whole passes: " _ tCounts)

    ; The status is checked, not discarded: a delete that silently failed would leave the check
    ; answering "pass", and the red below would be read as a classification defect rather than as
    ; a teardown that never happened.
    Do $$$AssertStatusOK(..DeleteRegistration(tConfigName), "the later roster entry's registration is deleted")
    Set tOk = ##class(OcuPilot.Install.Smoke).Run("", "", "0", .tReport2, .tCounts2)
    Set tLine2 = ##class(OcuPilot.Test.Smoke).Line(tReport2, "auditevent")
    Do $$$AssertTrue(tLine2 [ "skipped", "a missing later roster entry is skipped, not failed: " _ tLine2)
    Do $$$AssertTrue(tLine2 [ tConfigName, "and the check names which one is missing")

    Do $$$AssertStatusOK(..DeleteRegistration(tBaseline), "the baseline triple's registration is deleted too")
    Set tOk = ##class(OcuPilot.Install.Smoke).Run("", "", "0", .tReport3, .tCounts3)
    Set tLine3 = ##class(OcuPilot.Test.Smoke).Line(tReport3, "auditevent")
    Do $$$AssertTrue(tLine3 [ "fail", "the baseline triple missing is a real failure: " _ tLine3)
    Do $$$AssertEquals(tOk, 0, "and it fails the run, which skipped never does: " _ tCounts3)

    Set tRestoreSC = ##class(OcuPilot.Install.Installer).Install("")
    Do $$$AssertStatusOK(tRestoreSC, "re-install re-registers both deleted triples")
    Do $$$AssertEquals(..MissingTriples(), "", "and every roster triple is registered again")
    Set tOk = ##class(OcuPilot.Install.Smoke).Run("", "", "0", .tReport4, .tCounts4)
    Do $$$AssertTrue(##class(OcuPilot.Test.Smoke).Line(tReport4, "auditevent") [ "pass", "and the check passes again")
}

/// <p>AC5 (Story 4.9) -- the <code>LedgerRead</code> roster entry: a cross-user ledger read lands
/// exactly one row under it, naming the subject as the read's target; a self read lands none; and
/// with that registration deleted the same read still succeeds and lands none -- which is what
/// proves the registration, not the emission, is what makes a row land (AD-15).</p>
/// <p>This account holds <code>%All</code>, so the cross-user gate passes and what is under test
/// here is the emission rather than the gate; the gate is
/// <class>OcuPilot.Test.LedgerWire</class>'s, as a real least-privileged principal.</p>
/// <p>Mutation (Rule 19): remove <parameter>OcuPilot.Kernel.Audit.Event.EVENTLEDGERREAD</parameter>
/// from <method>OcuPilot.Kernel.Audit.Event.Roster</method> -- the roster assertion goes red.</p>
Method TestACrossUserLedgerReadLandsOneRowAndVanishesUnregistered()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup installed and read a non-empty roster")
    Set tName = $Parameter("OcuPilot.Kernel.Audit.Event", "EVENTLEDGERREAD")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Audit.Event).Names(), tName) > 0, tName _ " is on the roster registration carries")
    Do $$$AssertEquals(..MissingTriples(), "", "and every roster triple is registered on this instance")
    Set ..PreparedSince = ..Now()

    Set tSubject = ..Marker()
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Audit.Ledger).ViewForUser($Username, tSubject, 0, "", 10, .tView, .tFault), "a cross-user ledger read runs")
    Do $$$AssertEquals($IsObject(tFault), 0, "with no fault, this account holding the administrative resource")
    Do $$$AssertEquals(..RowsCarrying(..PreparedSince, tName, tSubject, .tData), 1, "exactly one " _ tName _ " row was written")
    Do $$$AssertTrue(tData [ """verb"":""read""", "naming the verb: " _ tData)
    Do $$$AssertTrue(tData [ """type"":""user""", "and the subject's entity type (AD-13)")
    Do $$$AssertTrue(tData [ ("""scope"":""" _ ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE _ """"), "and the instance scope")
    Do $$$AssertTrue(tData [ ("""actor"":""" _ $Username _ """"), "and the reader as the actor")

    ; A self read is not a cross-user read and emits nothing.
    Do ##class(OcuPilot.Kernel.Audit.Ledger).ViewForUser($Username, "", 0, "", 10, .tSelf, .tSelfFault)
    Do $$$AssertEquals(..RowsCarrying(..PreparedSince, tName, """id"":""" _ $Username _ """", .tSelfData), 0, "a read of the caller's own rows emits none")

    ; The negative leg: with the registration gone the same read still succeeds and lands no row.
    Do $$$AssertStatusOK(..DeleteRegistration(tName), "the " _ tName _ " registration is deleted")
    Set tSecond = ..Marker()
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Audit.Ledger).ViewForUser($Username, tSecond, 0, "", 10, .tAfter, .tAfterFault), "the same read still succeeds")
    Do $$$AssertEquals($IsObject(tAfterFault), 0, "with no fault -- emission never fails the read (AD-15)")
    Do $$$AssertTrue($IsObject(tAfter), "and still answers a view")
    Do $$$AssertEquals(..RowsCarrying(..PreparedSince, tName, tSecond, .tNone), 0, "and lands no row at all")

    Set tRestoreSC = ##class(OcuPilot.Install.Installer).Install("")
    Do $$$AssertStatusOK(tRestoreSC, "re-install re-registers the deleted triple")
    Do $$$AssertEquals(..MissingTriples(), "", "and every roster triple is registered again")
}

/// <p>A dropped <parameter>OcuPilot.Kernel.Audit.Event.EVENTLEDGERREAD</parameter> emission reports
/// that a <b>read</b> was answered and no row was written -- not that a configuration change was
/// made (DW-1127). The log line is the only trace of the drop (AD-15), so a line naming the wrong
/// operation sends an operator looking for an edit that never happened.</p>
/// <p>Captured through <class>OcuPilot.Test.EventProbe</class>, so the real payload, the real
/// redaction and the real <code>$System.Security.Audit</code> call all run.</p>
/// <p>Mutation (Rule 19): drop the message argument from
/// <method>OcuPilot.Kernel.Audit.Event.Record</method>'s <method>LogFailure</method> call -- the
/// report falls back to the configuration-change sentence and this goes red.</p>
Method TestADroppedLedgerReadReportsAReadRatherThanAChange()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup installed and read a non-empty roster")
    Set tName = $Parameter("OcuPilot.Kernel.Audit.Event", "EVENTLEDGERREAD")
    Do $$$AssertStatusOK(..DeleteRegistration(tName), "the " _ tName _ " registration is deleted, so the emission below drops")

    Set tSubject = ..Marker()
    Do ##class(OcuPilot.Test.EventProbe).Clear()
    Set tReportedSC = ##class(OcuPilot.Test.EventProbe).Record($Parameter("OcuPilot.Kernel.Audit.Ledger", "READVERB"), $Parameter("OcuPilot.Kernel.Audit.Ledger", "READENTITYTYPE"), tSubject, {}, 0, {}, tName)
    Do $$$AssertStatusNotOK(tReportedSC, "the dropped emission returns an error status")
    Do $$$AssertEquals(##class(OcuPilot.Test.EventProbe).Captured("calls"), 1, "and reports the drop exactly once")
    Do $$$AssertEquals(##class(OcuPilot.Test.EventProbe).Captured("message"), ##class(OcuPilot.Kernel.Audit.Event).#DROPPEDLEDGERREAD, "with the read-shaped sentence: " _ ##class(OcuPilot.Test.EventProbe).Captured("message"))
    Do $$$AssertTrue(##class(OcuPilot.Test.EventProbe).Captured("message") '[ "configuration change", "which does not call a read a configuration change")
    Do ##class(OcuPilot.Test.EventProbe).Clear()

    Set tRestoreSC = ##class(OcuPilot.Install.Installer).Install("")
    Do $$$AssertStatusOK(tRestoreSC, "re-install re-registers the deleted triple")
    Do $$$AssertEquals(..MissingTriples(), "", "and every roster triple is registered again")
}

/// <p>Delete one of OcuPilot's own audit event registrations by its full event name, switching to
/// <code>%SYS</code> and restoring (AD-16). A name that is not registered is left alone.</p>
ClassMethod DeleteRegistration(pEventName As %String) As %Status
{
    Set tSC = $$$OK
    Set tSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
    Set tType = ##class(OcuPilot.Kernel.Audit.Event).Type()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Events).Exists(tSource, tType, pEventName, .tE, .tS) {
            Set tSC = ##class(Security.Events).Delete(tSource, tType, pEventName)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
