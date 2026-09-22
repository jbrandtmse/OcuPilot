/// <p>The two stores behind the Switches screen: the instance's one switch row
/// (<class>OcuPilot.Kernel.State.Switch</class>) and the per-user holds
/// (<class>OcuPilot.Kernel.State.Hold</class>).</p>
/// <p>What is pinned here is the singleton contract -- defaults with no row, a merge that leaves
/// unnamed fields alone, one row however often it is written -- and the hold's weak reference to a
/// user (AD-37): a name the instance does not hold is a legitimate row that reads back verbatim.</p>
/// <p>Every row this class writes is removed in <method>OnAfterOneTest</method>, which then asserts
/// none survives.</p>
Class OcuPilot.Test.SwitchState Extends %UnitTest.TestCase
{

/// <p>The prefix every probe hold's user name starts with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeHold";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the switch row and the holds this class wrote are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no hold survives this class")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 0, "and no switch row survives it either")
    Quit $$$OK
}

/// <p>DW-435: the instance's one switch row is one row because the store <b>refuses</b> a second,
/// not because every writer happens to check first. Two callers that both read "no row" would
/// otherwise both create one, and <code>SELECT TOP 1 ... ORDER BY ID</code> would answer the older
/// of the two for ever after.</p>
/// <p>Mutation: delete <code>Index SwitchSingletonIdx</code> from
/// <class>OcuPilot.Kernel.State.Switch</class> and recompile the package -- this goes red.
/// Dropping <code>Set tRow.Singleton = 1</code> from <method>SetGuarded</method> is not a second
/// mutation: the property's own <code>InitialExpression</code> writes 1, so the row is unchanged.</p>
Method TestASecondSwitchRowIsRefused()
{
    Kill tValues
    Set tValues("enforcedReadOnly") = 0
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues), "the instance's one row is written")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 1, "and there is exactly one")

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "INSERT INTO OcuPilot_Kernel_State.SwitchState (Singleton, RowVersion) VALUES (1, 1)")
    Do $$$AssertTrue(tRS.%SQLCODE < 0, "a second row is refused by the store itself: SQLCODE=" _ tRS.%SQLCODE)
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 1, "and the instance still holds exactly one")
}

/// <p><b>A row written before <property>OcuPilot.Kernel.State.Switch.WritesMarked</property>
/// existed answers that property's default, not 0.</b> The property was added with no
/// <code>SCHEMAVERSION</code> move (Consistency Conventions), which is only sound because
/// <method>Resolve</method> reads the slot's <b>presence</b> rather than its truth: an untouched
/// slot reads <code>""</code>, <code>''""</code> is 0, and every instance upgraded from an earlier
/// OcuPilot that had ever written this row -- a kill switch set, enforced read-only set, one
/// <code>PUT /agent/switches</code> -- would draw the not-marked banner for every user over an
/// instance that is marking perfectly well.</p>
/// <p>No writer can produce such a row: <method>SetGuarded</method> builds the object with
/// <code>%New()</code> and the property's <code>InitialExpression</code> fills the slot. The
/// stored slot is therefore cleared through SQL, which is exactly the shape an older row has.</p>
/// <p>Mutation (Rule 19): drop the <code>'= ""</code> guard from <method>Resolve</method> -- make
/// the assignment unconditional -- and this goes red on the resolved value.</p>
Method TestARowPredatingTheMarkingSlotAnswersItsDefault()
{
    Kill tValues
    Set tValues("enforcedReadOnly") = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues), "an instance with a switch row, as every upgraded one has")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 1, "exactly one row")

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.SwitchState SET WritesMarked = NULL")
    Do $$$AssertTrue(tRS.%SQLCODE = 0, "the stored slot is cleared, which is what an older row holds: SQLCODE=" _ tRS.%SQLCODE)

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).Resolve(.tRead), "the switches still resolve")
    Do $$$AssertEquals($Get(tRead("writesMarked")), ##class(OcuPilot.Kernel.State.Switch).#DEFAULTWRITESMARKED, "and the empty slot answers the declared default")
    Do $$$AssertEquals($Get(tRead("writesMarked")), 1, "which is 'marking', so no banner is drawn over an upgraded instance")
    Do $$$AssertEquals($Get(tRead("enforcedReadOnly")), 1, "while the fields the older row did carry are unchanged")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 1, "and the reader the restraint route uses answers the same")
}

/// <p><b>A clean instance answers the defaults and holds no row</b>, which is what "a fresh install
/// leaves the kill switch off and writes no switch row" means.</p>
Method TestACleanInstanceAnswersTheDefaultsWithNoRow()
{
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 0, "the instance holds no switch row")
    Set tSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tValues)
    Do $$$AssertStatusOK(tSC, "and the switches resolve anyway")
    Do $$$AssertEquals(tValues("killSwitch"), ##class(OcuPilot.Kernel.State.Switch).#DEFAULTKILLSWITCH, "the kill switch takes its declared default")
    Do $$$AssertEquals(tValues("killSwitch"), 0, "which is off")
    Do $$$AssertEquals(tValues("killSwitchReason"), "", "with no reason")
    Do $$$AssertEquals(tValues("enforcedReadOnly"), 0, "read-only is not enforced")
    Do $$$AssertEquals(tValues("shareContextByDefault"), 1, "and screen context is shared by default")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 0, "and reading wrote nothing")
}

/// <p><b>A write round-trips and creates exactly one row</b>, however often it is written -- the
/// singleton contract <class>OcuPilot.Kernel.State.Egress</class> established.</p>
Method TestAWriteRoundTripsIntoOneRow()
{
    Set tValues("killSwitch") = 1
    Set tValues("killSwitchReason") = "Paused during the change freeze"
    Set tValues("enforcedReadOnly") = 1
    Set tValues("shareContextByDefault") = 0
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues), "the switches are written")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 1, "as one row")

    Set tSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tRead)
    Do $$$AssertStatusOK(tSC, "and read back")
    Do $$$AssertEquals(tRead("killSwitch"), 1, "the kill switch is on")
    Do $$$AssertEquals(tRead("killSwitchReason"), "Paused during the change freeze", "with the reason verbatim")
    Do $$$AssertEquals(tRead("enforcedReadOnly"), 1, "read-only is enforced")
    Do $$$AssertEquals(tRead("shareContextByDefault"), 0, "and screen context is not shared by default")
    Do $$$AssertNotEquals(tRead("updatedAt"), "", "the write stamped a timestamp")
    Do $$$AssertTrue($Extract(tRead("updatedAt"), $Length(tRead("updatedAt"))) = "Z", "in ISO-8601 UTC: " _ tRead("updatedAt"))
    Do $$$AssertTrue(tRead("updatedAt") [ "T", "with the T separator rather than a raw $ZDateTime space")

    Kill tSecond
    Set tSecond("killSwitch") = 0
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tSecond), "a second write succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 1, "and still leaves one row")
}

/// <p><b>A write merges</b>: a subscript the caller omits keeps its stored value, so turning the
/// kill switch off does not clear enforced read-only.</p>
/// <p>Mutation: write every field unconditionally in
/// <method>OcuPilot.Kernel.State.Switch.SetGuarded</method> -- this goes red on the enforced flag.</p>
Method TestAWriteLeavesTheFieldsItDoesNotName()
{
    Set tValues("killSwitch") = 1
    Set tValues("killSwitchReason") = "off"
    Set tValues("enforcedReadOnly") = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues), "both switches are on")

    Kill tOnly
    Set tOnly("killSwitch") = 0
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tOnly), "the kill switch alone is turned off")
    Set tSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tRead)
    Do $$$AssertStatusOK(tSC, "and the switches read back")
    Do $$$AssertEquals(tRead("killSwitch"), 0, "the kill switch is off")
    Do $$$AssertEquals(tRead("enforcedReadOnly"), 1, "and enforced read-only is untouched")
    Do $$$AssertEquals(tRead("killSwitchReason"), "off", "as is the reason, which is history rather than a claim once the switch is off")
}

/// <p><b>A hold round-trips, and its user is a weak reference</b> (AD-37): the name is recorded as
/// data, so one the instance does not hold reads back verbatim and fails no read.</p>
Method TestAHoldRoundTripsAndItsUserIsAWeakReference()
{
    Set tGhost = ##class(OcuPilot.Test.SwitchFixture).#GHOSTUSER
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Hold(tGhost, "no longer with us", .tId), "a hold naming a user the instance does not hold is written")
    Do $$$AssertNotEquals(tId, "", "and answers an id")

    Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedForUser(tGhost, .tHeld, .tReason)
    Do $$$AssertStatusOK(tSC, "the hold reads back")
    Do $$$AssertEquals(tHeld, 1, "as held")
    Do $$$AssertEquals(tReason, "no longer with us", "with its reason")

    Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedScreenRows(.tRows)
    Do $$$AssertStatusOK(tSC, "and the screen rows read")
    Do $$$AssertEquals(tRows.%Size(), 1, "carrying one row")
    Set tRow = tRows.%Get(0)
    Do $$$AssertEquals(tRow.userName, tGhost, "whose user name is the stored one, verbatim")
    Do $$$AssertEquals(tRow.reason, "no longer with us", "with the reason")
    Do $$$AssertEquals(tRow.id, tId, "and the row's id")
    Do $$$AssertTrue(tRow.%IsDefined("present") = 0, "and nothing about whether the user still resolves, which is the API's answer rather than the store's")
}

/// <p><b>A user with no hold reads as not held</b>, which is an ordinary answer rather than an
/// error.</p>
Method TestAUserWithNoHoldIsNotHeld()
{
    Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedForUser(..#PROBEPREFIX _ "Nobody", .tHeld, .tReason)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHeld, 0, "and reports no hold")
    Do $$$AssertEquals(tReason, "", "with no reason")
    Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedForUser("", .tHeld, .tReason)
    Do $$$AssertStatusOK(tSC, "and an empty user name is an ordinary answer too")
    Do $$$AssertEquals(tHeld, 0, "reporting no hold")
}

/// <p><b>One user carries at most one hold</b>, and the id lookup finds an existing one so a caller
/// can refuse the repeat on its own field rather than leaving the unique index to answer
/// <code>#5808</code>.</p>
Method TestOneUserCarriesAtMostOneHold()
{
    Set tUser = ..#PROBEPREFIX _ "Twice"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Hold(tUser, "first", .tFirstId), "the first hold is written")
    Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedIdForUser(tUser, .tFound)
    Do $$$AssertStatusOK(tSC, "and is found by name")
    Do $$$AssertEquals(tFound, tFirstId, "as the row just written")

    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Hold(tUser, "second", .tSecondId)
    Do $$$AssertStatusNotOK(tSC, "a second hold on the same user is refused by the unique index")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).ProbeHoldCount(), 1, "and only one row exists")
}

/// <p><b>A hold is removed by id</b>, and an id no row holds removes nothing without failing.</p>
Method TestAHoldIsRemovedByIdAndAnAbsentIdIsNotAnError()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Hold(..#PROBEPREFIX _ "Gone", "released soon", .tId), "a hold is written")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).ProbeHoldCount(), 1, "as one row")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Hold).GuardedDeleteId(tId), "and is removed")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).ProbeHoldCount(), 0, "leaving none")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Hold).GuardedDeleteId("999999999"), "removing an id no row holds is not an error")
}

/// <p><b>Holds list in creation order</b>, which is what the screen renders them in, and a bounded
/// read stops at its bound.</p>
Method TestHoldsListInCreationOrder()
{
    For tSuffix = "Alpha", "Beta", "Gamma" {
        Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Hold(..#PROBEPREFIX _ tSuffix, "reason " _ tSuffix, .tId), tSuffix _ " is held")
    }
    Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedScreenRows(.tRows)
    Do $$$AssertStatusOK(tSC, "the screen rows read")
    Do $$$AssertEquals(tRows.%Size(), 3, "carrying three rows")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Hold).GuardedScreenRows(.tBounded, 2), "a bounded read answers")
    Do $$$AssertEquals($Select($IsObject(tBounded): tBounded.%Size(), 1: -1), 2, "with the two ids its SELECT TOP ? bound admits")
    Do $$$AssertStatusNotOK(##class(OcuPilot.Kernel.State.Hold).GuardedScreenRows(.tRefused, 0), "and a bound of zero is refused")
    If tRows.%Size() '= 3 Quit
    Do $$$AssertEquals(tRows.%Get(0).userName, ..#PROBEPREFIX _ "Alpha", "the first written is first")
    Do $$$AssertEquals(tRows.%Get(1).userName, ..#PROBEPREFIX _ "Beta", "then the second")
    Do $$$AssertEquals(tRows.%Get(2).userName, ..#PROBEPREFIX _ "Gamma", "then the third")
}

/// <p><b>A hold is matched the way the unique index matches it</b> -- case-insensitively, which is
/// IRIS SQL's default collation. The claim matters because
/// <method>OcuPilot.Kernel.Restraint.Verdict</method> asks
/// <method>OcuPilot.Kernel.State.Hold.GuardedForUser</method> whether the acting user is held: a
/// lookup that folded case differently from the index would let a user held as one spelling act
/// under another, and the per-user kill switch would silently not apply.</p>
/// <p>Mutation: wrap the column in <code>%EXACT()</code> in
/// <method>GuardedForUser</method>'s WHERE clause -- this goes red on the folded lookup while the
/// exact-spelling tests above stay green.</p>
Method TestAHoldIsMatchedTheWayTheUniqueIndexMatchesIt()
{
    Set tStored = ..#PROBEPREFIX _ "CaseFold"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Hold(tStored, "held under one spelling", .tId), "a hold is written under one spelling")

    Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedForUser($ZConvert(tStored, "U"), .tHeld, .tReason)
    Do $$$AssertStatusOK(tSC, "the upper-cased spelling reads back")
    Do $$$AssertEquals(tHeld, 1, "as held, because the lookup folds case the way the index does")
    Do $$$AssertEquals(tReason, "held under one spelling", "carrying the stored reason")

    Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedIdForUser($ZConvert(tStored, "L"), .tFound)
    Do $$$AssertStatusOK(tSC, "and so does the lower-cased one")
    Do $$$AssertEquals(tFound, tId, "finding the same row, which is what lets a repeat be refused on its own field")

    ; The index agrees: a second hold differing only in case is the duplicate the lookup just found.
    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Hold($ZConvert(tStored, "U"), "second", .tSecondId)
    Do $$$AssertStatusNotOK(tSC, "so the unique index refuses a hold differing only in case")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).ProbeHoldCount(), 1, "and only one row exists")
}

/// <p><b>The change record a switch write leaves carries the fields that moved and nothing else</b>
/// -- the seam the audit row is written from (FR-29).</p>
/// <p>Driven through <class>OcuPilot.Test.SwitchesProbe</class>, which overrides the one call
/// <method>OcuPilot.Api.Switches.LogChange</method> writes through, so the real change-set
/// computation and the real subsystem name run and the line is read back rather than written to
/// the console log.</p>
/// <p>Mutation: delete the <code>..LogInfo(...)</code> call from
/// <method>OcuPilot.Api.Switches.LogChange</method> -- this goes red on "the change record reached
/// the log seam", where every wire test stays green because none of them reads the log.</p>
/// <p>Second mutation (Rule 19): restore <method>OcuPilot.Api.Switches.LogChange</method>'s
/// constant <code>securityChange</code> of 1, or set <code>killSwitchReason</code>'s security
/// column in <method>OcuPilot.Api.Switches.Fields</method> to 1 -- the reworded-reason leg below
/// goes red, which is the only leg that observes the classifier's other answer.</p>
Method TestASwitchWriteRecordsTheFieldsThatMoved()
{
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Kill tBefore, tAfter
    Set tBefore("killSwitch") = 0
    Set tBefore("killSwitchReason") = ""
    Set tBefore("enforcedReadOnly") = 0
    Set tBefore("updatedAt") = "2026-09-15T10:00:00Z"
    Set tAfter("killSwitch") = 1
    Set tAfter("killSwitchReason") = "Paused for the change freeze"
    Set tAfter("enforcedReadOnly") = 0
    Set tAfter("updatedAt") = "2026-09-15T10:30:45Z"

    Do ##class(OcuPilot.Test.SwitchesProbe).LogChange("switches", .tBefore, .tAfter)
    Set tLine = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue(tLine '= "", "the change record reached the log seam")
    Do $$$AssertTrue(tLine [ """subsystem"":""agent-switch""", "under the agent-switch subsystem: " _ tLine)
    Do $$$AssertTrue(tLine [ """msg"":""switches""", "naming the verb")
    Do $$$AssertTrue(tLine [ """killSwitch"":{""old"":""0"",""new"":""1""}", "the kill switch's move is carried with its old and new value: " _ tLine)
    Do $$$AssertTrue(tLine [ """securityChange"":true", "and the record classifies itself as a security change")
    Do $$$AssertEquals(tLine [ "enforcedReadOnly", 0, "a field that did not move is not in the record")
    Do $$$AssertEquals(tLine [ "updatedAt", 0, "and neither is the stamp every write re-applies, which would make a no-op write look like a change")

    ; The other direction: a write that moved nothing records nothing but its own empty change set,
    ; so "carries the fields that moved" is not satisfied by a record that carries everything.
    ; Both arrays are whole, as OcuPilot.Api.Switches.HandleUpdate passes them -- two reads of the
    ; same store -- differing only in the stamp every write re-applies.
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Kill tSame
    Merge tSame = tBefore
    Set tSame("updatedAt") = "2026-09-15T11:00:00Z"
    Do ##class(OcuPilot.Test.SwitchesProbe).LogChange("switches", .tBefore, .tSame)
    Set tLine = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue(tLine [ """changes"":{}", "a write that moved nothing records an empty change set: " _ tLine)

    ; And the classification's other answer. killSwitchReason is the one switch field that decides
    ; no restraint -- it is the operator's copy for the banner -- so moving only it is an ordinary
    ; configuration change, which is what selects the ConfigChange event name over SecurityChange.
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Kill tReworded
    Merge tReworded = tBefore
    Set tReworded("killSwitchReason") = "Paused while the freeze is reviewed"
    Set tReworded("updatedAt") = "2026-09-15T12:00:00Z"
    Do ##class(OcuPilot.Test.SwitchesProbe).LogChange("switches", .tBefore, .tReworded)
    Set tLine = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue(tLine [ """killSwitchReason"":{""old"":"""",""new"":""Paused while the freeze is reviewed""}", "a reworded banner reason is carried as a change: " _ tLine)
    Do $$$AssertTrue(tLine [ """securityChange"":false", "and is NOT classified a security change, because no field that restrains anything moved: " _ tLine)

    ; A hold is one by what it does, whatever its change set carries.
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Kill tNoHold, tHold
    Set tHold("userName") = "OcuPilotProbeHoldClassify"
    Set tHold("reason") = "classification probe"
    Do ##class(OcuPilot.Test.SwitchesProbe).LogChange("hold", .tNoHold, .tHold)
    Set tLine = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue(tLine [ """securityChange"":true", "a per-user hold is a security change by what it does: " _ tLine)
}

/// <p><b>The validators refuse what the published copy cannot render</b>: a kill switch with no
/// reason leaves the banner's <code>&lt;reason&gt;</code> slot empty, and a hold needs a user and a
/// reason for the same two reasons.</p>
/// <p>Mutation: delete the <code>killSwitch</code> guard from
/// <method>OcuPilot.Kernel.SwitchRules.ValidateSwitches</method> -- this goes red on the first
/// case.</p>
Method TestTheValidatorsRefuseWhatThePublishedCopyCannotRender()
{
    Kill tValues
    Set tValues("killSwitch") = 1
    Set tValues("killSwitchReason") = ""
    Set tValues("contextRowCap") = 200
    Do $$$AssertEquals(##class(OcuPilot.Kernel.SwitchRules).ValidateSwitches(.tValues, .tViolations), 1, "a kill switch with no reason is refused once")
    Do $$$AssertEquals($List(tViolations(1), 1), "killSwitchReason", "on the reason field")
    Do $$$AssertEquals($List(tViolations(1), 2), ##class(OcuPilot.Api.Error).#AGENTSWITCHREASONREQUIRED, "with its own code")

    Set tValues("killSwitchReason") = "   "
    Do $$$AssertEquals(##class(OcuPilot.Kernel.SwitchRules).ValidateSwitches(.tValues, .tViolations), 1, "and whitespace is not a reason either")

    Set tValues("killSwitchReason") = "Paused during the change freeze"
    Do $$$AssertEquals(##class(OcuPilot.Kernel.SwitchRules).ValidateSwitches(.tValues, .tViolations), 0, "a kill switch with a reason is accepted")

    Kill tOff
    Set tOff("killSwitch") = 0
    Set tOff("killSwitchReason") = ""
    Set tOff("contextRowCap") = 200
    Do $$$AssertEquals(##class(OcuPilot.Kernel.SwitchRules).ValidateSwitches(.tOff, .tViolations), 0, "and turning the switch off needs no reason")

    Kill tHold
    Set tHold("userName") = ""
    Set tHold("reason") = ""
    Do $$$AssertEquals(##class(OcuPilot.Kernel.SwitchRules).ValidateHold(.tHold, 0, .tHoldViolations), 2, "a hold with neither a user nor a reason is refused twice")
    Do $$$AssertEquals($List(tHoldViolations(1), 1), "userName", "on the user field first")
    Do $$$AssertEquals($List(tHoldViolations(2), 1), "reason", "then on the reason field")

    Set tHold("userName") = ..#PROBEPREFIX _ "Dup"
    Set tHold("reason") = "already off"
    Do $$$AssertEquals(##class(OcuPilot.Kernel.SwitchRules).ValidateHold(.tHold, 1, .tHoldViolations), 1, "a repeat on a user already held is refused once")
    Do $$$AssertEquals($List(tHoldViolations(1), 2), ##class(OcuPilot.Api.Error).#AGENTHOLDDUPLICATE, "under the duplicate code")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.SwitchRules).ValidateHold(.tHold, 0, .tHoldViolations), 0, "and is accepted when the user is not held")
}

}
