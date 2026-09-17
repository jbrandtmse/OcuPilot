/// <p>Story 4.4's kernel-level cutter and its supporting pieces, driven in process: the bounds
/// <class>OcuPilot.Kernel.Agent.Bound</class> applies (row cap, per-field cut, total-size cut and
/// the refusal when nothing fits), the descriptor grammar's <code>context.maxLength</code> refusal
/// in <class>OcuPilot.Screen.Registry</class>, <code>OcuPilot.Kernel.Egress.IsPrivate</code> and
/// <code>LeavesInstance</code>, and <class>OcuPilot.Kernel.State.Switch</class>'s default and
/// out-of-range resolution for <code>contextRowCap</code>.</p>
/// <p><b>Live-safe</b>: spawns nothing, opens no socket, and writes only the switch row this class
/// itself sets up and tears down.</p>
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
    For tAddress = "192.0.2.10", "172.15.255.255", "172.32.0.1", "8.8.8.8", "127.0.0.1", "169.254.1.1" {
        Do $$$AssertTrue('##class(OcuPilot.Kernel.Egress).IsPrivate(tAddress), tAddress _ " is not private")
    }
}

/// <p>Leaves instance (Story 4.4's context status read) -- false when marked local, or when every
/// resolved address is loopback, link-local or private; true when unresolvable or any resolved
/// address is a plain public one.</p>
/// <p>Mutation: treat <code>172.16/12</code> as public in
/// <method>OcuPilot.Kernel.Egress.LeavesInstance</method> -- the private-host leg goes red.</p>
Method TestLeavesInstanceClassification()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("192.0.2.10", 0), 1, "a public host leaves the instance")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("192.0.2.10", 1), 0, "a definition marked local never leaves it, whatever it resolves to")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("10.1.2.3", 0), 0, "a private host does not leave it")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Egress).LeavesInstance("no-such-host-ocupilot.invalid", 0), 1, "an unresolvable host is judged as leaving it")
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
}

}
