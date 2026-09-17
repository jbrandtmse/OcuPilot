/// <p>Story 4.4's kernel-level cutter and its supporting pieces, driven in process: the bounds
/// <class>OcuPilot.Kernel.Agent.Bound</class> applies (row cap, per-field cut, total-size cut and
/// the refusal when nothing fits), the descriptor grammar's <code>context.maxLength</code> refusal
/// in <class>OcuPilot.Screen.Registry</class>, <code>OcuPilot.Kernel.Egress.IsPrivate</code> and
/// <code>LeavesInstance</code>, and <class>OcuPilot.Kernel.State.Switch</class>'s default and
/// out-of-range resolution for <code>contextRowCap</code>.</p>
/// <p>Spawns nothing and opens no socket beyond one DNS lookup of an <code>.invalid</code> name. It
/// writes the switch row and deletes every <class>OcuPilot.Kernel.State.Sharing</class> row, so it
/// runs on a throwaway instance.</p>
Class OcuPilot.Test.ContextBound Extends %UnitTest.TestCase
{

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the switch row this class wrote is removed")
    Quit $$$OK
}

/// <p>Row cap -- more rows than the cap are cut to it and marked truncated; at the cap, nothing is
/// cut and <code>rowsAvailable</code> is the pre-cut count.</p>
/// <p>Mutation: drop the row-cap step from <method>OcuPilot.Kernel.Agent.Bound.Apply</method> --
/// this goes red.</p>
Method TestTheRowCapCutsAndReportsRowsAvailable()
{
    Set tPayload = {"rows": []}
    For tI = 1:1:250 {
        Do tPayload.rows.%Push({"n": (tI)})
    }
    Kill tFieldMax
    Set tOk = ##class(OcuPilot.Kernel.Agent.Bound).Apply(tPayload, 5, .tFieldMax, 1000, 65536, .tJson)
    Do $$$AssertTrue(tOk, "the payload fits")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tJson)
    Do $$$AssertEquals(tParsed.rows.%Size(), 5, "cut to the cap")
    Do $$$AssertEquals(tParsed.rowsSent, 5, "rowsSent matches")
    Do $$$AssertEquals(tParsed.rowsAvailable, 250, "rowsAvailable is the pre-cut count")
    Do $$$AssertEquals(tParsed.truncated, 1, "and marked truncated")

    Set tPayload2 = {"rows": []}
    For tI = 1:1:5 {
        Do tPayload2.rows.%Push({"n": (tI)})
    }
    Kill tFieldMax
    Set tOk2 = ##class(OcuPilot.Kernel.Agent.Bound).Apply(tPayload2, 5, .tFieldMax, 1000, 65536, .tJson2)
    Do $$$AssertTrue(tOk2, "the payload fits")
    Set tParsed2 = ##class(%DynamicObject).%FromJSON(tJson2)
    Do $$$AssertEquals(tParsed2.rows.%Size() _ "|" _ tParsed2.truncated, "5|0", "at the cap, nothing is cut")
}

/// <p>Per-field cut -- a string longer than its declared maximum is cut to maximum-1 characters
/// plus U+2026, and its field name is reported in <code>truncatedFields</code>, sorted and
/// unique.</p>
/// <p>Mutation: drop the ellipsis append or the field-set bookkeeping in
/// <method>OcuPilot.Kernel.Agent.Bound.Apply</method> -- this goes red.</p>
Method TestThePerFieldCutMarksTruncatedFields()
{
    Set tLong = $TR($J("", 1200), " ", "x")
    Set tPayload = {"rows": [{"Description": (tLong), "Name": "ok"}, {"Description": (tLong), "Name": "ok2"}]}
    Kill tFieldMax
    Set tFieldMax("Description") = 1000
    Set tOk = ##class(OcuPilot.Kernel.Agent.Bound).Apply(tPayload, 200, .tFieldMax, 1000, 65536, .tJson)
    Do $$$AssertTrue(tOk, "the payload fits")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tJson)
    Set tCut = tParsed.rows.%Get(0)."Description"
    Do $$$AssertEquals($Length(tCut), 1000, "cut to the declared maximum")
    Do $$$AssertEquals($Extract(tCut, 1000), $Char(8230), "ending U+2026")
    Do $$$AssertEquals($Extract(tCut, 1, 999), $Extract(tLong, 1, 999), "keeping the leading text")
    Do $$$AssertEquals(tParsed.rows.%Get(0).Name, "ok", "an untouched field is untouched")
    Do $$$AssertEquals(tParsed.truncatedFields.%ToJSON(), "[""Description""]", "one entry, not one per row")
    Do $$$AssertEquals(tParsed.truncated, 1, "and marked truncated")
}

/// <p>An array- or object-valued row field (a real read tool's <code>Roles</code> column, for
/// instance) survives the per-field cut untouched -- it is neither a string to trim nor a field
/// the row-cap or size-cap steps drop.</p>
/// <p>Mutation: pass <var>tValueType</var> as an explicit <code>%Set</code> type hint for an
/// object or array value in <method>OcuPilot.Kernel.Agent.Bound.Apply</method> -- this raises
/// <code>&lt;ILLEGAL VALUE&gt;</code> instead of returning, so this test goes red.</p>
Method TestAnArrayOrObjectFieldSurvivesThePerFieldCutUntouched()
{
    Set tPayload = {"rows": [{"Name": "Admin", "Roles": ["a", "b", "c"], "Detail": {"nested": "object"}}]}
    Kill tFieldMax
    Set tOk = ##class(OcuPilot.Kernel.Agent.Bound).Apply(tPayload, 200, .tFieldMax, 1000, 65536, .tJson)
    Do $$$AssertTrue(tOk, "the payload fits, rather than raising <ILLEGAL VALUE>")
    Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(tJson)
    Set tRow = tParsed.rows.%Get(0)
    Do $$$AssertEquals(tRow.Roles.%ToJSON(), "[""a"",""b"",""c""]", "the array survives untouched")
    Do $$$AssertEquals(tRow.Detail.%ToJSON(), "{""nested"":""object""}", "and the object survives untouched")
    Do $$$AssertEquals(tParsed.truncated, 0, "neither is treated as a truncation")
}

/// <p>Total size -- a payload whose rows fit the row cap but not the size cap has trailing rows
/// dropped until it fits, and a rowless payload that still cannot fit is refused.</p>
/// <p>Mutation: remove the size check in <method>OcuPilot.Kernel.Agent.Bound.Apply</method> --
/// this goes red.</p>
Method TestTheTotalSizeCutDropsTrailingRowsAndRefusesWhenNothingFits()
{
    Set tPayload = {"rows": []}
    For tI = 1:1:200 {
        Do tPayload.rows.%Push({"n": (tI), "text": ($TR($J("", 900), " ", "x"))})
    }
    Kill tFieldMax
    Set tOk = ##class(OcuPilot.Kernel.Agent.Bound).Apply(tPayload, 200, .tFieldMax, 1000, 65536, .tJson)
    Do $$$AssertTrue(tOk, "the payload is answered, not refused")
    Do $$$AssertTrue($Length(tJson) <= 65536, "within the cap: " _ $Length(tJson))
    Set tParsed = ##class(%DynamicObject).%FromJSON(tJson)
    Do $$$AssertTrue((tParsed.rows.%Size() > 0) && (tParsed.rows.%Size() < 200), "with trailing rows dropped: " _ tParsed.rows.%Size())
    Do $$$AssertEquals(tParsed.rowsSent, tParsed.rows.%Size(), "rowsSent matches what survived")
    Do $$$AssertEquals(tParsed.truncated, 1, "and marked truncated")

    Set tRowless = {"rows": [], "big": ($TR($J("", 70000), " ", "x"))}
    Kill tFieldMax
    Set tRefused = ##class(OcuPilot.Kernel.Agent.Bound).Apply(tRowless, 200, .tFieldMax, 1000, 65536, .tRefusedJson)
    Do $$$AssertEquals(tRefused, 0, "a rowless payload that cannot fit is refused")
    Do $$$AssertEquals(tRefusedJson, "", "with no payload")
}

/// <p>Descriptor bound (AD-24, Story 4.4) -- <code>context.maxLength</code> above 1,000, naming a
/// field not in <code>context.fields</code>, or a non-integer value, is refused by
/// <method>OcuPilot.Screen.Registry.ReadProblem</method>, naming <code>context.maxLength</code>; a
/// value in range is accepted, and <code>read.criteria.fields[].maxLength</code> is untouched by
/// this rule.</p>
/// <p>Mutation: accept 1,001 in <method>OcuPilot.Screen.Registry.ContextMaxLengthProblem</method>
/// -- this goes red.</p>
Method TestTheDescriptorMaxLengthIsBoundedByTheRegistry()
{
    Set tBase = {
        "route": "probe/context-bound",
        "area": "instance",
        "labelKey": "probe",
        "sideBarPosition": 0,
        "archetype": "list",
        "built": false,
        "privileges": [],
        "entityType": "",
        "secondaryEntityTypes": [],
        "scope": "namespace",
        "id": {"kind": "none", "parts": []},
        "primaryAction": {"id": "", "selfProtection": ""},
        "rowActions": [],
        "emptyStateKey": "probe.empty",
        "commandAliases": [],
        "classicPage": "",
        "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
        "toolIdentifier": "probe.contextbound",
        "read": {
            "source": {"port": "state", "endpoint": "Demo", "type": "LIST"},
            "fields": ["Name", "Description"],
            "filter": [],
            "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
            "paging": "cap"
        },
        "context": {"fields": ["Name", "Description"], "secretFields": []},
        "table": {"columns": [{"field": "Name", "labelKey": "probe.name", "kind": "name"}], "emptyNextKey": "probe.empty", "emptyAgentKey": ""}
    }

    Set tGood = ##class(%DynamicAbstractObject).%FromJSON(tBase.%ToJSON())
    Do tGood.context.%Set("maxLength", {"Description": 500})
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tGood), "", "a value in range is accepted")

    Set tTooHigh = ##class(%DynamicAbstractObject).%FromJSON(tBase.%ToJSON())
    Do tTooHigh.context.%Set("maxLength", {"Description": 1001})
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tTooHigh) [ "context.maxLength", "1,001 is refused: " _ ##class(OcuPilot.Screen.Registry).ReadProblem(tTooHigh))

    Set tUnknownField = ##class(%DynamicAbstractObject).%FromJSON(tBase.%ToJSON())
    Do tUnknownField.context.%Set("maxLength", {"Nope": 5})
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tUnknownField) [ "context.maxLength", "a field outside context.fields is refused")

    Set tReadOnlyField = ##class(%DynamicAbstractObject).%FromJSON(tBase.%ToJSON())
    Do tReadOnlyField.context.%Set("fields", ["Name"])
    Do tReadOnlyField.context.%Set("maxLength", {"Description": 5})
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tReadOnlyField) [ "context.maxLength", "a field in read.fields but not context.fields is refused")

    Set tNotNumber = ##class(%DynamicAbstractObject).%FromJSON(tBase.%ToJSON())
    Do tNotNumber.context.%Set("maxLength", {"Description": "5"})
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tNotNumber) [ "context.maxLength", "a string value is refused")
}

/// <p><code>IsPrivate</code> -- the three RFC 1918 blocks and <code>fc00::/7</code> classify
/// private; a public address and a loopback or link-local address do not.</p>
Method TestIsPrivateClassifiesRfc1918AndUniqueLocal()
{
    For tAddress = "10.0.0.1", "10.255.255.255", "172.16.0.1", "172.31.255.255", "192.168.0.1", "192.168.255.255", "fd00::1" {
        Do $$$AssertTrue(##class(OcuPilot.Kernel.Egress).IsPrivate(tAddress), tAddress _ " is private")
    }
    For tAddress = "192.0.2.10", "172.15.255.255", "172.32.0.1", "8.8.8.8", "127.0.0.1", "169.254.1.1", "fe00::1" {
        Do $$$AssertTrue('##class(OcuPilot.Kernel.Egress).IsPrivate(tAddress), tAddress _ " is not private")
    }
}

/// <p>Leaves instance (Story 4.4's context status read) -- false when marked local, or when every
/// resolved address is loopback, link-local or private; true when unresolvable or any resolved
/// address is a plain public one.</p>
/// <p>Mutation (QA): answer 0 for an unresolvable host in
/// <method>OcuPilot.Kernel.Egress.HostLeaves</method> -- the unresolvable-host leg goes red.</p>
Method TestLeavesInstanceClassification()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("192.0.2.10", 0), 1, "a public host leaves the instance")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("192.0.2.10", 1), 0, "a definition marked local never leaves it, whatever it resolves to")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("10.1.2.3", 0), 0, "a private host does not leave it")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("no-such-host-ocupilot.invalid", 0), 1, "an unresolvable host is judged as leaving it")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("127.0.0.1", 0), 0, "a loopback host does not leave it")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("169.254.1.1", 0), 0, "a link-local host does not leave it")
}

/// <p>Leaves instance through a proxy (AD-42: a configured proxy is a destination too) -- a public
/// proxy makes a private or marked-local endpoint leave the instance; a private proxy leaves the
/// endpoint's own answer standing.</p>
/// <p>Mutation: ignore <var>pProxyHost</var> in <method>OcuPilot.Kernel.Egress.LeavesInstance</method>
/// -- the public-proxy legs go red.</p>
Method TestAPublicProxyLeavesTheInstance()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("10.1.2.3", 0, "192.0.2.10"), 1, "a private endpoint behind a public proxy leaves")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("192.0.2.10", 1, "192.0.2.10"), 1, "a marked-local definition behind a public proxy leaves")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("10.1.2.3", 0, "10.0.0.5"), 0, "a private endpoint behind a private proxy does not")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("192.0.2.10", 0, "10.0.0.5"), 1, "a public endpoint behind a private proxy still leaves")
}

/// <p>The per-field cut never ends the kept text on the high half of a surrogate pair: a character
/// outside the Basic Multilingual Plane straddling the cut is dropped whole.</p>
/// <p>Mutation: remove the surrogate check in <method>OcuPilot.Kernel.Agent.Bound.Apply</method> --
/// this goes red.</p>
Method TestThePerFieldCutNeverSplitsASurrogatePair()
{
    ; 998 plain characters, then U+1F600 as its surrogate pair at positions 999 and 1000.
    Set tValue = $TR($J("", 998), " ", "x") _ $Char(55357, 56832) _ $TR($J("", 50), " ", "y")
    Set tPayload = {"rows": [{"Description": (tValue)}]}
    Kill tFieldMax
    Set tOk = ##class(OcuPilot.Kernel.Agent.Bound).Apply(tPayload, 200, .tFieldMax, 1000, 65536, .tJson)
    Do $$$AssertTrue(tOk, "the payload fits")
    Set tCut = ##class(%DynamicObject).%FromJSON(tJson).rows.%Get(0)."Description"
    Do $$$AssertEquals($Length(tCut), 999, "the straddling pair is dropped whole")
    Do $$$AssertEquals($Extract(tCut, 998), "x", "the kept text ends before the pair")
    Do $$$AssertEquals($Extract(tCut, 999), $Char(8230), "and the cut is marked")
}

/// <p>Projection (Story 4.4 Boundaries) -- on <code>logs/audit</code>, a row key outside
/// <code>context.fields</code> and a sort over such a field are dropped; a screen declaring
/// <code>context.secretFields</code> answers identity only.</p>
/// <p>Mutation: remove the <code>context.fields</code> filter in
/// <method>OcuPilot.Screen.Context.Build</method> -- this goes red.</p>
Method TestProjectionKeepsOnlyDeclaredContextFields()
{
    Set tContext = {"route": "logs/audit", "namespace": "HSCUSTOM", "view": {"sort": "EventData", "rows": [{"Description": "kept", "EventData": "dropped"}]}}
    Set tSC = ##class(OcuPilot.Screen.Context).Build(tContext, .tBuilt, .tPayload, .tFieldMax, .tDropped)
    Do $$$AssertStatusOK(tSC, "the audit context builds")
    Do $$$AssertTrue(tBuilt, "the route resolves")
    If 'tBuilt Quit
    Set tRow = tPayload.rows.%Get(0)
    Do $$$AssertEquals(tRow.Description, "kept", "a declared field is kept")
    Do $$$AssertTrue('tRow.%IsDefined("EventData"), "a field outside context.fields is dropped")
    Do $$$AssertEquals(tPayload.sort, "", "a sort over an undeclared field is dropped")

    Set tSecret = {"route": "agent/definitions/edit", "namespace": "HSCUSTOM", "entity": "probe", "view": {"sort": "Name", "filter": "x", "rows": [{"Name": "probe"}]}}
    Set tSC = ##class(OcuPilot.Screen.Context).Build(tSecret, .tSecretBuilt, .tSecretPayload, .tSecretMax, .tSecretDropped)
    Do $$$AssertStatusOK(tSC, "the secret screen's context builds")
    Do $$$AssertTrue(tSecretBuilt, "its route resolves")
    If 'tSecretBuilt Quit
    Do $$$AssertEquals(tSecretPayload.%ToJSON(), "{""screen"":""" _ tSecretPayload.screen _ """,""route"":""agent/definitions/edit"",""namespace"":""HSCUSTOM"",""entity"":""probe""}", "identity only: no rows, sort or filter")
}

/// <p>Wire refusals (Story 4.4 Boundaries) -- <method>OcuPilot.Api.Turn.ContextViolation</method>
/// refuses a negative, fractional or too-small <code>rowsAvailable</code>, non-array
/// <code>rows</code>, and a <code>sort</code>, <code>direction</code> or <code>filter</code> over
/// <code>FIELDMAXLENGTH</code>, and accepts a sound context.</p>
/// <p>Mutation: drop the member length check in <method>OcuPilot.Api.Turn.ContextViolation</method>
/// -- the long-filter leg goes red.</p>
Method TestContextViolationRefusesEachBadShape()
{
    Set tLimits = "OcuPilot.Kernel.Agent.Limits"
    Set tCode = ##class(OcuPilot.Api.Error).#TURNCONTEXTINVALID
    Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
    Set tLong = $TR($J("", 1001), " ", "x")
    Set tSound = {"context": {"route": "logs/audit", "namespace": (tNamespace), "view": {"filter": "x", "rows": [{"Description": "a"}], "rowsAvailable": 3}}}
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).ContextViolation(tSound, tLimits), "", "a sound context is accepted")
    For tCase = "rowsAvailable:-1", "rowsAvailable:0", "rowsAvailable:2.5", "rows:{}", "filter:long", "sort:long", "direction:long" {
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tSound.%ToJSON())
        Set tMember = $Piece(tCase, ":", 1)
        Set tValue = $Piece(tCase, ":", 2)
        If tValue = "long" {
            Do tBody.context.view.%Set(tMember, tLong, "string")
        } ElseIf tValue = "{}" {
            Do tBody.context.view.%Set(tMember, {})
        } Else {
            Do tBody.context.view.%Set(tMember, +tValue, "number")
        }
        Do $$$AssertEquals(##class(OcuPilot.Api.Turn).ContextViolation(tBody, tLimits), tCode, tCase _ " is refused")
    }
}


/// <p><code>Switch.Resolve</code> -- <code>contextRowCap</code> answers the default
/// (<parameter>OcuPilot.Kernel.State.Switch.DEFAULTCONTEXTROWCAP</parameter>) on a clean instance,
/// and answers the default again when the stored value is out of range, rather than widening the
/// bound.</p>
Method TestSwitchResolveDefaultsAndClampsOutOfRangeContextRowCap()
{
    Set tSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tValues)
    Do $$$AssertStatusOK(tSC, "a clean instance resolves")
    Do $$$AssertEquals(tValues("contextRowCap"), ##class(OcuPilot.Kernel.State.Switch).#DEFAULTCONTEXTROWCAP, "the default is 200")

    Set tRow("contextRowCap") = 500
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tRow), "a valid value is stored")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).Resolve(.tAfter), "resolve again")
    Do $$$AssertEquals(tAfter("contextRowCap"), 500, "the stored value reads back")

    ; SetGuarded itself applies no range check -- that is Kernel.SwitchRules' job at the API layer
    ; -- so a stored value outside 1-1,000 is reachable, and Resolve is what keeps it from widening
    ; the bound rather than answering it.
    Kill tOutOfRange
    Set tOutOfRange("contextRowCap") = 5000
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tOutOfRange), "an out-of-range value is stored")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).Resolve(.tClamped), "resolve again")
    Do $$$AssertEquals(tClamped("contextRowCap"), ##class(OcuPilot.Kernel.State.Switch).#DEFAULTCONTEXTROWCAP, "an out-of-range stored value answers the default")

    ; A stored 0, which is also what an empty value reads as, answers the default too.
    Kill tZero
    Set tZero("contextRowCap") = 0
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tZero), "a zero value is stored")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).Resolve(.tZeroResolved), "resolve again")
    Do $$$AssertEquals(tZeroResolved("contextRowCap"), ##class(OcuPilot.Kernel.State.Switch).#DEFAULTCONTEXTROWCAP, "a stored zero answers the default")
}

/// <p>Per-user sharing store isolation (AD-9, Story 4.4's AC3 mechanism) --
/// <method>OcuPilot.Kernel.State.Sharing.GuardedForUser</method> answers a stored user's own
/// choice, and a second, never-stored user is answered not-found rather than the first user's row
/// -- the not-found signal <method>OcuPilot.Api.Context.Body</method> reads as "fall back to the
/// instance default".</p>
/// <p>Mutation (QA): drop the <code>WHERE UserName = ?</code> clause from
/// <method>OcuPilot.Kernel.State.Sharing.GuardedForUser</method>'s query -- the second user reads
/// the first user's row instead of not-found, and this goes red.</p>
Method TestSharingIsPerUserAndFallsBackWhenNoRowExists()
{
    Set tUserA = "OcuPilotProbeSharingUserA"
    Set tUserB = "OcuPilotProbeSharingUserB"
    Do ##class(OcuPilot.Kernel.State.Sharing).DeleteAllGuarded()

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Sharing).GuardedSetForUser(tUserA, 0), "user A's choice is stored")

    Set tSCA = ##class(OcuPilot.Kernel.State.Sharing).GuardedForUser(tUserA, .tFoundA, .tShareA)
    Do $$$AssertStatusOK(tSCA, "user A's read completes")
    Do $$$AssertEquals(tFoundA _ "|" _ tShareA, "1|0", "user A reads their own stored choice")

    Set tSCB = ##class(OcuPilot.Kernel.State.Sharing).GuardedForUser(tUserB, .tFoundB, .tShareB)
    Do $$$AssertStatusOK(tSCB, "user B's read completes")
    Do $$$AssertEquals(tFoundB _ "|" _ tShareB, "0|0", "user B, who never stored a row, is answered not-found rather than user A's row")

    Do ##class(OcuPilot.Kernel.State.Sharing).DeleteAllGuarded()
}

/// <p>Descriptor bound, other half (AD-24, Story 4.4's Never list: "widening the maxLength check
/// beyond context") -- <code>read.criteria.fields[].maxLength</code> above 1,000 stays accepted by
/// <method>OcuPilot.Screen.Registry.CriteriaProblem</method>, on the shipped
/// <code>logs/audit</code> descriptor's own live declaration with one criterion's
/// <code>maxLength</code> raised well past the context ceiling.</p>
/// <p>Mutation (QA): add <code>|| (tValue &gt; 1000)</code> to
/// <method>OcuPilot.Screen.Registry.CriteriaMaxLengthProblem</method>'s condition -- this goes
/// red.</p>
Method TestCriteriaMaxLengthAboveOneThousandStaysAcceptedByTheRegistry()
{
    Set tSC = ##class(OcuPilot.Screen.Descriptor.AuditList).DeclarationJson(.tDecl)
    Do $$$AssertStatusOK(tSC, "the shipped audit descriptor's declaration reads")
    Set tFound = 0
    Set tFields = tDecl.read.criteria.fields
    Set tIterator = tFields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        If tField.param = "eventSources" {
            Do tField.%Set("maxLength", 5000, "number")
            Set tFound = 1
        }
    }
    Do $$$AssertTrue(tFound, "the eventSources criterion is present to widen")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDecl), "", "a criteria maxLength above 1,000 stays accepted -- the 1,000 ceiling binds context.maxLength alone")
}

}
