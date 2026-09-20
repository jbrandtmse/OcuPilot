/// <p>AD-15, FR-21, FR-22: <b>every confirmed agent write is marked</b>, the marker and the
/// vendor's own change row locate each other, a write made any other way is marked by nothing, and
/// a marker the instance drops neither fails the write nor passes silently.</p>
/// <p>The ledger's half is here too (AD-41): the confirmed write's own row is opened before the
/// port call and finalized after it with what was actually executed -- the resolved target, the
/// field names the body carried, the pairs the confirm evaluated and the marker's outcome.</p>
/// <p><b>What it needs from the environment:</b> an account holding <code>%All</code>, the
/// instance's own administration API through the shipped port, and <b>both</b> arming variables.
/// It deletes an audit event registration (<parameter>ARMINGVARIABLE</parameter>) and creates a
/// web application to write to (<parameter>PRINCIPALVARIABLE</parameter>), so it runs on a
/// throwaway container and nowhere else; only <file>scripts/ci-throwaway.sh</file> sets either.</p>
/// <p><b>Why the audit read looks like this</b> (DW-85): <class>%SYS.Audit</class>'s event indexes
/// are brought up to date by a background pass, so every read here carries <code>%NOINDEX</code>
/// on the event predicates and is bounded by <code>UTCTimeStamp</code>, the first subscript of the
/// table's IDKEY. <class>OcuPilot.Test.AuditEvent</class> owns that reader and this class calls
/// it.</p>
Class OcuPilot.Test.AuditMarker Extends %UnitTest.TestCase
{

/// <p>Deleting an audit event registration. While it is gone every row OcuPilot would write under
/// that triple is dropped with no error and no log line.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_AUDIT_EVENTS";

/// <p>Creating the web application a confirmed write is aimed at
/// (<method>OcuPilot.Test.ProposalFixture.EnsureWriteTarget</method>).</p>
Parameter PRINCIPALVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "webapp.list.update";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.WebAppList";

/// <p>The probe application's path, <class>OcuPilot.Test.ProposalFixture</class>'s own.</p>
Parameter TARGET = "/csp/ocupilotprobeconfirm";

/// <p>The change every confirm here carries: setting a resource where none was set, the one
/// authorization change AD-10 permits, and observable on the instance afterwards.</p>
Parameter HARDENRESOURCE = "%Development";

/// <p>The shipped confirm with the audit emitter's reporting seam captured, and the real port.</p>
Parameter CONFIRM = "OcuPilot.Test.MarkerConfirm";

/// <p>The confirm whose port is the fixture, for the one leg that needs a write to fail.</p>
Parameter FIXTURECONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

Parameter STORE = "OcuPilot.Kernel.State.Ledger";

Parameter EVENT = "OcuPilot.Kernel.Audit.Event";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditMarker deletes an OcuPilot audit event registration on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was deleted. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#PRINCIPALVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditMarker creates a web application on this instance and runs on a throwaway container only. " _ ..#PRINCIPALVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget($Namespace, .tCreated)
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveWriteTarget()
    If $$$ISERR(tSC) Quit tSC
    ; Put back whatever a method deleted, and refuse to pass while a triple is still missing: a
    ; class that left auditing off is a failure, not a passing run.
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Set tMissing = ##class(OcuPilot.Test.AuditEvent).MissingTriples()
    If tMissing '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditMarker left an audit event unregistered on this instance: " _ tMissing)
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.EventProbe).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.EventProbe).Clear()
    ; A method that deletes a registration re-installs it at its own tail, and an assertion that
    ; fails before that tail is reached would leave the triple deleted for every later method in
    ; the class -- which surfaces as four unrelated failures rather than the one real one. The
    ; restore belongs where it runs whatever the method did; Install is idempotent (AD-17) and is
    ; called only when something is actually missing.
    If ##class(OcuPilot.Test.AuditEvent).MissingTriples() '= "" {
        Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(""), "the audit registrations this method deleted are put back")
    }
    Do $$$AssertStatusOK(..Unharden(), "the probe application's resource is cleared again")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>The roster name a confirmed write is marked under, on this profile.</p>
ClassMethod MarkerName() As %String
{
    Quit $Parameter(..#EVENT, "EVENTAGENTWRITE")
}

/// <p>Clear the probe application's guarding resource, so the next method starts where this one
/// did. Only ever called for <parameter>TARGET</parameter>, which this suite created.</p>
Method Unharden() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("Resource") = ""
        Set tSC = ##class(Security.Applications).Modify(..#TARGET, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The probe application as the shipped port reads it, in <var>pFresh</var>.</p>
Method Fresh(Output pFresh As %DynamicObject) As %Boolean
{
    Kill tQuery
    Set tQuery("name") = ..#TARGET
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .pFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the probe application reads back through the port")
    Quit $$$ISOK(tSC) && $IsObject(pFresh)
}

/// <p>The scoped reference key for <parameter>TARGET</parameter> (AD-13), as the mint would store
/// it.</p>
ClassMethod Reference() As %String
{
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("web-application", ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, ..#TARGET, .tKey)
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>Seed one completed turn and one live proposal against <parameter>TARGET</parameter> whose
/// payload is <var>pFresh</var> with <parameter>HARDENRESOURCE</parameter> set, the way
/// <class>OcuPilot.Test.ProposalSpelling</class> does: one shipped
/// <method>OcuPilot.Kernel.Proposal.Mint.Merge</method> over one real argument supplies the
/// payload, the diff and the unchanged count, and the fingerprint is that payload's own digest --
/// the relationship a mint stores, so both digests the confirm compares match.</p>
/// <p>The proposal id comes back in <var>pKey</var> and the turn key in <var>pTurnKey</var>, which
/// is the key the confirmed write's ledger row is written under.</p>
Method Seed(pFresh As %DynamicObject, Output pTurnKey As %String) As %String
{
    Set pTurnKey = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOL, .tTool)
    Do $$$AssertStatusOK(tSC, "the write tool resolves")
    If $$$ISERR(tSC) || '$IsObject(tTool) Quit ""
    Set tClass = tTool.%Get("class")
    Set tArgs = {}
    Do tArgs.%Set("Resource", ..#HARDENRESOURCE, "string")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, tArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "the shipped merge runs over the fresh read")
    Do $$$AssertEquals(tProblem, "", "with no argument problem")
    If $$$ISERR(tSC) Quit ""
    Set tExcludes = ""
    Set tDescriptor = $Parameter(tClass, "DESCRIPTORCLASS")
    If tDescriptor '= "" Set tExcludes = $ClassMethod(tDescriptor, "FingerprintExcludes")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tPayload, tExcludes, .tFingerprint)
    Do $$$AssertStatusOK(tSC, "and the digest is taken")
    If $$$ISERR(tSC) Quit ""

    Kill tValues
    Set tValues("user") = $Username
    Set tValues("convKey") = ""
    Set tValues("turnKey") = pTurnKey
    Set tValues("toolName") = ..#TOOL
    Set tValues("targetRef") = ..Reference()
    Set tValues("fingerprint") = tFingerprint
    Set tValues("arguments") = tArgs.%ToJSON()
    Set tValues("payload") = tPayload.%ToJSON()
    Set tValues("diff") = tDiff.%ToJSON()
    Set tValues("unchangedCount") = tUnchanged
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>The one <code>write</code>-kind row turn <var>pTurnKey</var> holds, subscripted by column
/// name, with how many such rows there are as the answer. Read by SQL because the view's row
/// object deliberately does not carry <code>Fields</code>.</p>
ClassMethod WriteRow(pTurnKey As %String, Output pValues) As %Integer
{
    Kill pValues
    Set tCount = 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Status, Code, Target, Fields, FieldsTruncated, RequiredPairs, PairsSense, AuditMarked FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ? AND %EXACT(Kind) = ?", pTurnKey, $Parameter("OcuPilot.Kernel.State.Ledger", "KINDWRITE"))
    If tRS.%SQLCODE < 0 Quit -1
    While tRS.%Next() {
        Set tCount = tCount + 1
        For tField = "Status", "Code", "Target", "Fields", "FieldsTruncated", "RequiredPairs", "PairsSense", "AuditMarked" {
            Set tValue = tRS.%Get(tField)
            Set pValues(tField) = $Select(tValue = $Char(0): "", 1: tValue)
        }
    }
    Quit tCount
}

/// <p>How many rows the audit database holds under <method>MarkerName</method> since
/// <var>pSince</var> carrying <var>pMarker</var>, with the last one's data in <var>pData</var>.
/// <class>OcuPilot.Test.AuditEvent</class>'s reader, called rather than copied.</p>
ClassMethod MarkerRows(pSince As %String, pMarker As %String, Output pData As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, ..MarkerName(), pMarker, .pData)
}

/// <p>The vendor's own change rows for <var>pMarker</var> since <var>pSince</var>: how many, with
/// the last one's event name in <var>pEvent</var>, its user in <var>pUser</var> and its UTC
/// timestamp in <var>pStamp</var>. <code>-1</code> when the read itself failed.</p>
/// <p>Bounded and <code>%NOINDEX</code>-ed for the reason
/// <method>OcuPilot.Test.AuditEvent.RowsCarrying</method> is (DW-85). The event name is read back
/// rather than named, because which <code>*Change</code> name a vendor endpoint emits is the
/// vendor's to choose and this suite asserts the join, not the spelling.</p>
ClassMethod VendorRows(pSince As %String, pMarker As %String, Output pEvent As %String, Output pUser As %String, Output pStamp As %String) As %Integer
{
    Set pEvent = ""
    Set pUser = ""
    Set pStamp = ""
    Set tRows = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Event, Username, UTCTimeStamp, EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = ? AND %NOINDEX EventType = ?", pSince, "%System", "%Security")
        If tRS.%SQLCODE < 0 {
            Set $NAMESPACE = tOrigNS
            Quit
        }
        Set tRows = 0
        While tRS.%Next() {
            If tRS.%Get("EventData") '[ pMarker Continue
            Set tRows = tRows + 1
            Set pEvent = tRS.%Get("Event")
            Set pUser = tRS.%Get("Username")
            Set pStamp = tRS.%Get("UTCTimeStamp")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tRows = -1
    }
    Quit tRows
}

/// <p>The probe application's stored <code>Resource</code>, read from the instance's own record.</p>
ClassMethod StoredResource() As %String
{
    Quit ##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Resource")
}

/// <p><b>AC1</b> -- a confirmed write is marked: exactly one
/// <code>OcuPilot</code>/<code>Security</code>/<code>AgentWrite</code> row carrying the proposal
/// id, the tool, the canonical target triple, the actor and the moment; and the ledger's
/// <code>write</code> row finalized <code>ok</code> with the same target, the fields the port was
/// sent, <code>checked</code> and <code>marked</code>.</p>
/// <p>Mutation (Rule 19): drop the <code>$System.Security.Audit</code> call from
/// <method>OcuPilot.Kernel.Audit.Event.RecordAgentWrite</method> (return <code>$$$OK</code>
/// without it) -- the row assertions go red.</p>
Method TestAConfirmedWriteIsMarked()
{
    If '..Fresh(.tFresh) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tKey = ..Seed(tFresh, .tTurnKey)
    If tKey = "" Quit

    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm runs: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tHttp, 200, "and is applied: " _ tCode)
    Do $$$AssertEquals(..StoredResource(), ..#HARDENRESOURCE, "the target really changed on the instance")

    Do $$$AssertEquals($Select($IsObject(tResult): tResult.%Get("auditMarked"), 1: "no answer"), 1, "and the answer says the marker landed")

    Set tRows = ..MarkerRows(tSince, """proposalId"":""" _ tKey _ """", .tData)
    Do $$$AssertEquals(tRows, 1, "exactly one agent-write marker names this proposal")
    If tRows = 1 {
        Set tPayload = ##class(%DynamicAbstractObject).%FromJSON(tData)
        Do $$$AssertEquals(tPayload.%Get("tool"), ..#TOOL, "the marker names the tool")
        Do $$$AssertEquals(tPayload.%Get("actor"), $Username, "and the user the write ran as")
        Do $$$AssertEquals(tPayload.target.type, "web-application", "the AD-13 triple's entity type")
        Do $$$AssertEquals(tPayload.target.scope, ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, "its scope")
        Do $$$AssertEquals(tPayload.target.id, ..#TARGET, "and the canonical id the proposal stored")
        Do $$$AssertNotEquals(tPayload.%Get("writtenAt"), "", "with the moment the write was made")
        Do $$$AssertEquals($Extract(tPayload.%Get("writtenAt"), $Length(tPayload.%Get("writtenAt"))), "Z", "as an ISO-8601 UTC stamp")
        Do $$$AssertTrue(tPayload.fields.%Size() > 0, "and the field names the write sent")
    }

    Do $$$AssertEquals(..WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row on the proposal's turn key")
    Do $$$AssertEquals($Get(tRow("Status")), "ok", "finalized ok")
    Do $$$AssertEquals($Get(tRow("Target")), ..Reference(), "against the canonical reference")
    Do $$$AssertEquals($Get(tRow("PairsSense")), $ClassMethod(..#LEDGER, "SenseChecked"), "recording a requirement the confirm checked")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter(..#STORE, "MARKEDYES"), "and that the marker landed")
    Do ..AssertFields(.tRow, tFresh)
}

/// <p>Every name the row's <code>Fields</code> column carries is a name the write's own body
/// carried, the changed field is among them, and no name the descriptor declared secret is
/// (AD-3, AD-41). The set is cut at a whole-name boundary when the column cannot hold it all, in
/// which case it says so.</p>
Method AssertFields(ByRef pRow, pFresh As %DynamicObject)
{
    Set tStored = $Get(pRow("Fields"))
    Do $$$AssertNotEquals(tStored, "", "the row names the fields the write sent")
    Set tSecrets = $ClassMethod(..#SCREEN, "SecretArguments")
    Set tSent = 0
    Set tIterator = pFresh.%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
        Set tSent = tSent + 1
    }
    Set tHeld = 0
    For tI = 1:1:$Length(tStored, ",") {
        Set tName = $Piece(tStored, ",", tI)
        If tName = "" Continue
        Set tHeld = tHeld + 1
        Do $$$AssertNotEquals(pFresh.%GetTypeOf(tName), "unassigned", "the stored name " _ tName _ " is one the body carried")
        Do $$$AssertEquals($ListFind(tSecrets, tName), 0, "and is not a name the descriptor declared secret")
    }
    Do $$$AssertTrue(tStored [ "Resource", "the field the write changed is among them: " _ tStored)
    ; The column is a bound, not a caller contract: a set that does not fit is cut at a whole-name
    ; boundary and says so, rather than being stored short in silence.
    Do $$$AssertEquals(''$Get(pRow("FieldsTruncated")), $Select(tHeld < tSent: 1, 1: 0), "the truncation flag matches what the column actually holds (" _ tHeld _ " of " _ tSent _ ")")
}

/// <p><b>AC1</b> -- either record locates the other. From the marker: the vendor's own
/// <code>%System</code>/<code>%Security</code> change row for the same target and the same user,
/// at or after the moment the marker recorded. From that row: the marker for the same target in
/// the same window, naming the proposal id.</p>
/// <p>Nothing reads the vendor's row back to stamp an id into the marker (AD-29): the join is the
/// pair <i>(scoped target, user)</i> inside the window <code>writtenAt</code> opens.</p>
/// <p>Mutation (Rule 19): drop <code>writtenAt</code> from
/// <method>OcuPilot.Kernel.Audit.Event.RecordAgentWrite</method>'s payload -- the window has no
/// opening and the ordering assertion goes red.</p>
Method TestEitherRecordLocatesTheOther()
{
    If '..Fresh(.tFresh) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tKey = ..Seed(tFresh, .tTurnKey)
    If tKey = "" Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm runs")
    Do $$$AssertEquals(tHttp, 200, "and is applied: " _ tCode)

    Set tMarkerRows = ..MarkerRows(tSince, """proposalId"":""" _ tKey _ """", .tData)
    Do $$$AssertEquals(tMarkerRows, 1, "the marker is there")
    If tMarkerRows '= 1 Quit
    Set tPayload = ##class(%DynamicAbstractObject).%FromJSON(tData)
    Set tWrittenAt = tPayload.%Get("writtenAt")
    ; Asserted here, not only in the marked leg: `]]` reads every non-empty string as following the
    ; empty one, so without this the ordering assertion below passes on a payload carrying no moment
    ; at all -- which is exactly the mutation this method names.
    Do $$$AssertNotEquals(tWrittenAt, "", "the marker carries the moment the window opens at")
    If tWrittenAt = "" Quit

    ; From the marker to the vendor's own record of the same change.
    Set tVendor = ..VendorRows(tSince, ..#TARGET, .tEvent, .tUser, .tStamp)
    Do $$$AssertTrue(tVendor > 0, "the vendor's own change row for this target is in the window: " _ tVendor)
    If tVendor > 0 {
        Do $$$AssertTrue(tEvent [ "Change", "and is a change event: " _ tEvent)
        Do $$$AssertEquals(tUser, $Username, "recording the same user the marker names")
        ; The vendor writes its row inside the call the marker's own stamp was taken just before.
        Do $$$AssertTrue(..Iso(tStamp) ]] tWrittenAt || (..Iso(tStamp) = tWrittenAt), "at or after the moment the marker recorded: vendor " _ ..Iso(tStamp) _ ", marker " _ tWrittenAt)
    }

    ; And back: the OcuPilot-source row for the same target in the same window names the proposal.
    Do $$$AssertEquals(..MarkerRows(tSince, """id"":""" _ ..#TARGET _ """", .tBack), 1, "the marker is findable from the target alone")
    Do $$$AssertTrue(tBack [ tKey, "and it names the proposal id, which is the link back to the ledger row")
}

/// <p><var>pStamp</var> as <code>%SYS.Audit.UTCTimeStamp</code> carries it, in the ISO-8601 UTC
/// spelling OcuPilot emits, so the two can be compared at all.</p>
ClassMethod Iso(pStamp As %String) As %String
{
    Quit $Translate($Piece(pStamp, ".", 1), " ", "T") _ "Z"
}

/// <p><b>AC1</b> -- the same write made any other way is marked by nothing. The identical vendor
/// <code>PUT</code> issued straight through <class>OcuPilot.Port.AdminPort</class> changes the
/// target and leaves the vendor's own change row, and no agent-write marker at all.</p>
/// <p>This is what makes the positive leg a statement about the <b>agent's</b> writes rather than
/// about writes: the marker is emitted from exactly one place.</p>
/// <p>Mutation (Rule 19): emit the marker from
/// <method>OcuPilot.Port.AdminPort.Invoke</method> as well -- this goes red on the zero.</p>
Method TestAWriteNotMadeByTheAgentEmitsNoMarker()
{
    If '..Fresh(.tFresh) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do tFresh.%Set("Resource", ..#HARDENRESOURCE, "string")
    Kill tQuery
    Set tQuery("name") = ..#TARGET
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "PUT", .tQuery, tFresh, .tWritten, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the direct write runs: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(..StoredResource(), ..#HARDENRESOURCE, "and the target really changed")

    Do $$$AssertEquals(..MarkerRows(tSince, """id"":""" _ ..#TARGET _ """", .tData), 0, "no agent-write marker records it")
    Do $$$AssertTrue(..VendorRows(tSince, ..#TARGET, .tEvent, .tUser, .tStamp) > 0, "while the vendor's own change row is still there: " _ tEvent)
}

/// <p><b>AC3</b> -- a dropped marker neither fails the write nor passes silently (AD-15). With the
/// registration deleted the write still answers 200 and really happens; the only traces of the
/// drop are the ledger row, one <method>LogFailure</method> report and
/// <code>auditMarked: false</code> on the answer.</p>
/// <p>The report is captured through <class>OcuPilot.Test.EventProbe</class>, which replaces the
/// one reporting seam and leaves the payload, the redaction and the
/// <code>$System.Security.Audit</code> call real -- an unregistered triple produces no row and no
/// console line of its own, so without it the drop's report is unobservable.</p>
/// <p>Mutation (Rule 19): refuse with <code>..Internal</code> when <code>tMarkSC</code> is an error,
/// before <code>Answer</code> runs, in
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -- the 200 and the stored-value
/// assertions go red while the no-row assertion stays green. (Assigning <code>tSC</code> after the
/// emission is inert: the next statement assigns <code>tSC</code> from <code>Answer</code>.) Second
/// mutation: delete the <code>If $$$ISERR(tSC) Do ..LogFailure(...)</code> line from
/// <method>OcuPilot.Kernel.Audit.Event.RecordAgentWrite</method> -- the report assertions go
/// red.</p>
Method TestADroppedMarkerNeitherFailsTheWriteNorPassesSilently()
{
    If '..Fresh(.tFresh) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tKey = ..Seed(tFresh, .tTurnKey)
    If tKey = "" Quit

    Do $$$AssertStatusOK(##class(OcuPilot.Test.AuditEvent).DeleteRegistration(..MarkerName()), "the agent-write registration is deleted, so the drop below is a current fact")
    Do ##class(OcuPilot.Test.EventProbe).Clear()

    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm still succeeds: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tHttp, 200, "the status the caller receives is unchanged from the marked case: " _ tCode)
    Do $$$AssertEquals(..StoredResource(), ..#HARDENRESOURCE, "and the target really changed on the instance")
    ; Read defensively so an answer this method did not get cannot raise before the re-install
    ; below: a method that aborted here would leave the registration deleted for the next one.
    Do $$$AssertEquals($Select($IsObject(tResult): tResult.%Get("auditMarked"), 1: "no answer"), 0, "the answer says the marker was not written")

    Do $$$AssertEquals(..MarkerRows(tSince, """proposalId"":""" _ tKey _ """", .tNone), 0, "and no audit row records it, which is the cost the caller is not told about")
    Do $$$AssertEquals(##class(OcuPilot.Test.EventProbe).Captured("calls"), 1, "the drop is reported exactly once")
    Do $$$AssertEquals(##class(OcuPilot.Test.EventProbe).Captured("message"), $Parameter(..#EVENT, "DROPPEDAGENTWRITE"), "with the confirmed-write sentence")
    ; Not "is non-empty": $System.Status.GetErrorText of the raw 0 the audit call answers renders
    ; "ERROR #00: (no error description)", which is non-empty and says nothing, so that assertion
    ; could not fail. The reason has to carry the answer the call actually gave.
    Do $$$AssertTrue(##class(OcuPilot.Test.EventProbe).Captured("reason") [ $Parameter(..#EVENT, "DROPPEDANSWER"), "and the reason names the answer the audit call gave, not an empty status text")

    Do $$$AssertEquals(..WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tRow("Status")), "ok", "finalized ok, because the write happened")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter(..#STORE, "MARKEDNO"), "and recording that the marker did not")

    ; The executor records what it observed, so the panel's banner is showing on the next read.
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 0, "the executor recorded that this instance is not marking writes")

    Set tRestoreSC = ##class(OcuPilot.Install.Installer).Install("")
    Do $$$AssertStatusOK(tRestoreSC, "re-install re-registers the deleted triple")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).MissingTriples(), "", "and every roster triple is registered again")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 1, "and install's own observation put the recorded fact back")
}

/// <p><b>AC2</b> -- the row is finalized <b>after</b> the write, with what was actually executed
/// (AD-41). A port call that raises after the claim committed leaves the row finalized
/// <code>error</code>, no marker at all, and the proposal confirmed and burned.</p>
/// <p>The port is <class>OcuPilot.Test.ProposalFixture</class> here, because a real endpoint
/// cannot be made to raise; everything else -- the gates, the claim, the open, the finalize -- is
/// the shipped code.</p>
/// <p>Mutation (Rule 19): finalize before the port call in
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -- move the
/// <code>FinalizeConfirmedWrite</code> call above <code>Invoke</code> -- and the status and
/// marker assertions go red, because the row would then record an outcome nobody had yet.</p>
Method TestTheRowRecordsWhatWasExecuted()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    If '..Fresh(.tFresh) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tKey = ..Seed(tFresh, .tTurnKey)
    If tKey = "" Quit

    ; The read the confirm re-takes is the fixture's, so it must answer the same object the mint
    ; merged over, or the fingerprint refuses before the claim.
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tFresh.%ToJSON())
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWriteFault(500)

    Set tSC = $ClassMethod(..#FIXTURECONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm answers the port's own failure")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "the port was called exactly once")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "confirmed", "the proposal is still confirmed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 1, "and burned")

    Do $$$AssertEquals(..WriteRow(tTurnKey, .tRow), 1, "the row opened before the call is there, which is the trace a write nobody can account for leaves")
    Do $$$AssertEquals($Get(tRow("Status")), "error", "finalized error")
    Do $$$AssertNotEquals($Get(tRow("Code")), "", "carrying the machine code the port answered")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter(..#STORE, "MARKEDNONE"), "and claiming nothing about marking, because no marker was emitted")
    Do $$$AssertEquals(..MarkerRows(tSince, """proposalId"":""" _ tKey _ """", .tNone), 0, "no agent-write marker was written")
}

/// <p><b>DW-1380.</b> The row <method>OpenConfirmedWrite</method> opens is the trace a write
/// nobody can account for leaves -- but only if an exception escaping mid-flight actually leaves
/// it <code>pending</code>, rather than every failure eventually finalizing it. This drives a real
/// exception out of the port call, not a returned error status: <method>ArmWriteFault</method>
/// (<method>TestTheRowRecordsWhatWasExecuted</method> above) exercises the
/// <code>$$$ISERR(tWriteSC)</code> branch, which finalizes <code>error</code>; a process that dies
/// between the open and that branch never reaches it at all, and
/// <method>OcuPilot.Test.ProposalFixture.ArmWriteException</method> is what a real crash looks
/// like from the caller's side.</p>
/// <p>Mutation (Rule 19): in <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method>'s outer
/// <code>Catch</code>, finalize the ledger row <code>error</code> the same way the write-failure
/// branch does, using the caught exception's status as <var>pCode</var> -- the row reads
/// <code>error</code> instead of <code>pending</code> and this goes red.</p>
Method TestARowIsLeftPendingWhenTheWriteRaises()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    If '..Fresh(.tFresh) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tKey = ..Seed(tFresh, .tTurnKey)
    If tKey = "" Quit

    ; Same fingerprint setup as the finalized-error leg above: the fixture must answer the object
    ; the mint merged over, or the fingerprint refuses before the claim is even made.
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tFresh.%ToJSON())
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWriteException()

    Set tSC = $ClassMethod(..#FIXTURECONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm answers the raised exception as an internal failure")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "the port really was called before it raised")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "confirmed", "the claim already committed, so the proposal is still confirmed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 1, "and burned")

    Do $$$AssertEquals(..WriteRow(tTurnKey, .tRow), 1, "the row opened before the call is still there")
    Do $$$AssertEquals($Get(tRow("Status")), $Parameter(..#STORE, "STATUSPENDING"), "left pending -- nobody finalized it, which is the trace itself")
    Do $$$AssertEquals($Get(tRow("Code")), "", "carrying no code, because nothing set one")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), "", "and no claim about marking either, exactly as when the row was opened")
    ; The trace has to be reachable by whoever investigates it, not only by its own author: the
    ; open records the requirement the confirm had already evaluated, so the cross-user gate has
    ; the row's own pairs to answer on (AD-46) instead of withholding it under an empty sense.
    Do $$$AssertNotEquals($Get(tRow("RequiredPairs")), "", "recording the requirement the confirm evaluated before it called the port")
    Do $$$AssertEquals($Get(tRow("PairsSense")), $Parameter(..#STORE, "SENSECHECKED"), "under the sense that says somebody read it")
    Do $$$AssertEquals(..MarkerRows(tSince, """proposalId"":""" _ tKey _ """", .tNone), 0, "no agent-write marker was written")
}

/// <p><b>DW-1379.</b> The instance-wide "writes are not being marked" fact is an observation about
/// the instance, so only an answer the instance gave may set it. A marker that fails <b>before</b>
/// <code>$System.Security.Audit</code> -- a stored reference that will not parse -- asked the
/// instance nothing, and <method>OcuPilot.Kernel.Audit.Event.RecordAgentWrite</method> says so
/// through <var>pEmitted</var> rather than through its status, which is an error either way.</p>
/// <p>Driven at the emitter because the confirm cannot reach the branch: <code>FingerprintMatches</code>
/// parses the same stored <code>TargetRef</code> first and refuses outright, so no fixture seam
/// reaches the marker's parse. The consequence this pins is the executor's rule -- refresh the
/// instance-wide fact only when <var>pEmitted</var> is 1 -- and the branch that makes it matter.</p>
/// <p>Mutation (Rule 19): set <var>pEmitted</var> to 1 at the top of <code>RecordAgentWrite</code>
/// instead of immediately before the audit call, and this goes red on the unparseable arm -- a
/// per-write failure would again be recorded as the instance's own answer.</p>
Method TestAMarkerThatNeverAskedTheInstanceSaysSo()
{
    Set tSC = $ClassMethod(..#EVENT, "RecordAgentWrite", "probe-proposal", ..#TOOL, "not-a-reference", $Username, "2026-09-20T00:00:00Z", "", .tEmitted)
    Do $$$AssertStatusNotOK(tSC, "an unparseable stored reference fails the marker")
    Do $$$AssertEquals($Get(tEmitted, -1), 0, "and reports that the audit call was never made, so it is no evidence about the instance")

    Set tRef = ..Reference()
    Do $$$AssertTrue(tRef '= "", "the suite's own canonical reference is built for the control arm")
    Set tOkSC = $ClassMethod(..#EVENT, "RecordAgentWrite", "probe-proposal", ..#TOOL, tRef, $Username, "2026-09-20T00:00:00Z", "", .tOkEmitted)
    Do $$$AssertStatusOK(tOkSC, "a reference that parses reaches the audit call")
    Do $$$AssertEquals($Get(tOkEmitted, -1), 1, "and reports that the instance was asked, which is what may refresh the recorded fact")
}

/// <p><b>AC1</b>, the half no shipped descriptor can drive: a name the descriptor declared secret
/// is excluded from the row's field list <b>at write time</b> (AD-3), never redacted afterwards.
/// No shipped screen declares a secret argument yet, so the declaration is supplied as data.</p>
/// <p>Mutation (Rule 19): drop the <code>$ListFind(pSecretNames, tKey)</code> guard from
/// <method>OcuPilot.Kernel.Proposal.Confirm.FieldNames</method> -- the declared name reaches the
/// list and this goes red.</p>
Method TestASecretDeclaredNameNeverReachesTheFieldList()
{
    Set tBody = {}
    Do tBody.%Set("Name", ..#TARGET, "string")
    Do tBody.%Set("Resource", ..#HARDENRESOURCE, "string")
    Do tBody.%Set("Password", "probe-not-a-real-secret", "string")

    Set tWith = $ClassMethod(..#CONFIRM, "FieldNamesFor", tBody, $ListBuild("Password"))
    Do $$$AssertEquals($ListLength(tWith), 2, "a declared secret name is not among the fields the row records")
    Do $$$AssertEquals($ListFind(tWith, "Password"), 0, "by name")
    Do $$$AssertTrue($ListFind(tWith, "Resource") > 0, "while every other name the body carried is")

    ; The same body with nothing declared: the name is a field like any other, which is what says
    ; the exclusion above is the declaration's doing and not the name's.
    Set tWithout = $ClassMethod(..#CONFIRM, "FieldNamesFor", tBody, "")
    Do $$$AssertEquals($ListLength(tWithout), 3, "with no declaration the same body names three fields")
    Do $$$AssertTrue($ListFind(tWithout, "Password") > 0, "the undeclared name among them")
}

}
