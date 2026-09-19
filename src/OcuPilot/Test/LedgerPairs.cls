/// <p>The ledger's pair string and the bounds around it (AD-24, AD-41, AD-46): the canonical
/// spelling and its round trip, the union the dispatcher itself reads, a pair the grammar cannot
/// represent, a set that overruns its column, a list that raises mid-walk, every declared bound
/// against the column it is cut into, and the error vocabulary's own completeness.</p>
/// <p><b>Split out of <class>OcuPilot.Test.Ledger</class>, whose helpers it calls by full class
/// name</b> -- the shape <class>OcuPilot.Test.LedgerStep</class> established.</p>
/// <p><b>Live-safe.</b> It spawns nothing, creates no principal and touches no registration. Every
/// row it writes names <parameter>PROBEUSER</parameter> or <code>$USERNAME</code>, and
/// <method>OnAfterOneTest</method> asserts none of its own survives.</p>
Class OcuPilot.Test.LedgerPairs Extends %UnitTest.TestCase
{

/// <p>The store under test.</p>
Parameter STORE = "OcuPilot.Kernel.State.Ledger";

/// <p>The ledger's public face.</p>
Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

/// <p>The shipped bounds, and the narrowed ones a cap test runs under.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter NARROW = "OcuPilot.Test.LedgerLimits";

/// <p>The shipped bounds with only the reply budget narrowed.</p>
Parameter BUDGET = "OcuPilot.Test.LedgerBudgetLimits";

/// <p>The user every probe row records -- its own, so the teardown's row sweep cannot reach a
/// sibling's rows. It keeps <parameter>OcuPilot.Test.TurnFixture.PROBEPREFIX</parameter> because
/// every probe user in this suite does; this class reserves no turn, so the prefix buys it
/// nothing of its own and the property its teardown has to preserve is the row sweep.</p>
Parameter PROBEUSER = "OcuPilotProbeTurnLedgerPairs";

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Clear()
    Do $$$AssertEquals(..RowCount(), 0, "no probe ledger row survives the method")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).RemoveTurns(.tRemaining), "the probe turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>Remove every probe row this class could have written, and every grant its pair tests made.</p>
Method Clear()
{
    Do ##class(OcuPilot.Test.LedgerGate).Clear()
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..#PROBEUSER)
}

/// <p>How many rows name this class's own probe user.</p>
ClassMethod RowCount() As %Integer
{
    Quit ##class(OcuPilot.Test.Ledger).RowCountFor(..#PROBEUSER)
}

/// <p>Record one tool call as <b>this</b> class's probe user, through the sibling's own recorder, so
/// a moved method keeps the call it had and the rows it writes are swept by this class's teardown.</p>
ClassMethod Record(pTurnKey As %String, pName As %String, pInput As %DynamicObject, pSecretNames As %List = "", pDeclaredPairs As %List = "", pArgumentPairs As %List = "", pLimits As %String = {..#LIMITS}, pClassified As %Boolean = 1) As %Status
{
    Quit ##class(OcuPilot.Test.Ledger).Record(pTurnKey, pName, pInput, pSecretNames, pDeclaredPairs, pArgumentPairs, pLimits, ..#PROBEUSER, pClassified)
}

/// <p>Every <code>LEDGER*</code> code the error vocabulary declares is in
/// <method>OcuPilot.Api.Error.LedgerCodes</method> and has a written sentence. Its own copy of the
/// turn family's test, because that one filters on <code>TURN</code>.</p>
/// <p>Mutation (Rule 19): remove the <code>LEDGER.UNAVAILABLE</code> branch from
/// <method>OcuPilot.Api.Error.ReasonForLedger</method> -- this goes red.</p>
Method TestEveryLedgerCodeHasASentence()
{
    Set tDeclared = ##class(OcuPilot.Api.Error).LedgerCodes()
    Set tFound = 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledParameter WHERE parent = ?", "OcuPilot.Api.Error")
    While tRS.%Next() {
        Set tName = tRS.%GetData(1)
        If $Extract(tName, 1, 6) '= "LEDGER" Continue
        Set tFound = tFound + 1
        Set tCode = $Parameter("OcuPilot.Api.Error", tName)
        Do $$$AssertTrue($ListFind(tDeclared, tCode) > 0, tName _ " is in LedgerCodes()")
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForLedger(tCode), "", tName _ " has a written sentence")
    }
    Do $$$AssertTrue(tFound > 0, "the vocabulary declares ledger codes")
    Do $$$AssertEquals($ListLength(tDeclared), tFound, "and LedgerCodes() holds no code the class does not declare")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForLedger("TURN.BUSY"), "", "and no code from another family")
}

/// <p>AC2 on the instance-fulfilled path -- a row's <code>requiredPairs</code> is written from the
/// pairs the dispatcher itself read, both halves of them.
/// <class>OcuPilot.Test.LedgerTool.Probe</class> declares <code>%Admin_Operate:USE</code> and adds
/// <code>%DB_IRISSYS:READ</code> only when the call names <code>Name</code>, so the two legs below
/// tell a row carrying the union from a row carrying the declared half alone. No shipped tool this
/// exit is reached with requires a pair, so an empty requirement would otherwise be truthful.</p>
/// <p>Mutation (Rule 19): replace <code>$Get(tPairs), $Get(tArgumentPairs)</code> with
/// <code>"", ""</code> at <method>OcuPilot.Kernel.Agent.Dispatch.AnswerOne</method>'s common exit --
/// both rows record no requirement and this goes red.</p>
Method TestARowsRequiredPairsComeFromTheDispatchersOwnReads()
{
    Set tBoth = ##class(OcuPilot.Test.Ledger).NewTurnKey()
    Do $$$AssertEquals(..DispatchedPairs(tBoth, {"Name": "probe"}), "%Admin_Operate:USE,%DB_IRISSYS:READ", "a call naming Name records the declared pair unioned with the one its argument adds")

    Set tDeclaredOnly = ##class(OcuPilot.Test.Ledger).NewTurnKey()
    Do $$$AssertEquals(..DispatchedPairs(tDeclaredOnly, {}), "%Admin_Operate:USE", "and a call naming none records the declared half alone")
}

/// <p>AC2 -- a row's <code>requiredPairs</code> is the declared set unioned with the
/// argument-derived one, canonically spelled, sorted and de-duplicated, and it round-trips back to
/// the pair list the gate evaluates.</p>
/// <p>Mutation (Rule 19): drop <var>pArgumentPairs</var> from
/// <method>OcuPilot.Kernel.Audit.Ledger.RecordToolCall</method>'s union -- the argument-derived pair
/// is absent and this goes red.</p>
Method TestARowsPairsAreTheUnionSortedAndDeduplicated()
{
    Set tDeclared = $ListBuild($ListBuild("%Admin_Operate", "USE"), $ListBuild("%Admin_Secure", "USE"))
    Set tArgument = $ListBuild($ListBuild("%DB_IRISSYS", "READ"), $ListBuild("%Admin_Operate", "USE"))
    Set tText = $ClassMethod(..#LEDGER, "PairsToString", tDeclared _ tArgument)
    Do $$$AssertEquals(tText, "%Admin_Operate:USE,%Admin_Secure:USE,%DB_IRISSYS:READ", "the union is sorted and de-duplicated")

    Set tBack = $ClassMethod(..#LEDGER, "StringToPairs", tText)
    Do $$$AssertEquals($ListLength(tBack), 3, "and round-trips to three pairs")
    Do $$$AssertEquals($List($List(tBack, 3), 1) _ ":" _ $List($List(tBack, 3), 2), "%DB_IRISSYS:READ", "each carrying its resource and permission")
    Do $$$AssertEquals($ClassMethod(..#LEDGER, "PairsToString", tBack), tText, "and back again unchanged")
    Do $$$AssertEquals($ClassMethod(..#LEDGER, "StringToPairs", ""), "", "an empty string is no pair at all")

    Set tKey = ##class(OcuPilot.Test.Ledger).NewTurnKey()
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}, "", tDeclared, tArgument), "a call carrying both halves is recorded")
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tView, .tFault), "the view reads")
    Do $$$AssertEquals(tView.rows.%Size(), 1, "one row")
    If tView.rows.%Size() = 1 Do $$$AssertEquals(tView.rows.%Get(0).requiredPairs, tText, "carrying the union it was written with")
}

/// <p>Every bound a writer cuts at is at most, and where it is the whole column exactly, the
/// declared <code>MAXLEN</code> of the column it is cut into -- read from
/// <class>%Dictionary.CompiledProperty</class> rather than recalled (DW-1124).</p>
/// <p>A declared bound and its column cannot be one literal in ObjectScript: a property's
/// <code>MAXLEN</code> keyword cannot read a class parameter. So the invariant is asserted here
/// instead of eliminated, over the shipped bound <b>and every</b> class that inherits it, since a
/// limits class that overran the column would fail the row's whole write.</p>
/// <p>The population is <b>derived</b> from the class hierarchy rather than listed: a hand-written
/// roster is a second place to keep correct, and the first version of this method already omitted
/// <class>OcuPilot.Test.TurnLimits</class>. A found-count floor is what stops a sweep that read
/// nothing from passing every row having tested nothing.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Test.LedgerLimits.LEDGERROWMAXLENGTH</parameter>
/// -- or any other subclass's -- to 8192; this goes red naming the class, the bound and the
/// column.</p>
Method TestEveryDeclaredBoundFitsTheColumnItIsCutInto()
{
    Set tArgumentsMax = ..MaxLenOf(..#STORE, "Arguments")
    Do $$$AssertTrue(tArgumentsMax > 0, "the Arguments column declares a MAXLEN: " _ tArgumentsMax)
    Set tFound = 0
    Set tSeen = ""
    ; PrimarySuper, not Super: Super holds a class's *direct* superclasses only, so a sweep over it
    ; reads the three classes that extend the shipped bound and none of the ones that extend those
    ; -- OcuPilot.Test.TurnLimitsNav and OcuPilot.Test.TurnLimitsNavCapped, which OcuPilot.Test.
    ; TurnNavigate installs. PrimarySuper is the whole primary chain, self included, and is
    ; ~-delimited, so the pattern must carry the delimiters or it matches a class merely named alike.
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %Dictionary.CompiledClass WHERE ID = ? OR PrimarySuper LIKE ?", ..#LIMITS, "%~" _ ..#LIMITS _ "~%")
    While tRS.%Next() {
        Set tClass = tRS.%Get("ID")
        Set tBound = +$Parameter(tClass, "LEDGERROWMAXLENGTH")
        Set tFound = tFound + 1
        Set tSeen = tSeen _ $ListBuild(tClass)
        Do $$$AssertTrue(tBound > 0, tClass _ ": declares LEDGERROWMAXLENGTH " _ tBound)
        Do $$$AssertTrue(tBound <= tArgumentsMax, tClass _ ": LEDGERROWMAXLENGTH " _ tBound _ " fits the Arguments column's MAXLEN " _ tArgumentsMax)
    }
    ; A sweep that found nothing, or that missed the subclasses this suite drives, would pass every
    ; row above having tested nothing -- which is how the hand-written roster this replaced hid
    ; OcuPilot.Test.TurnLimits.
    Do $$$AssertTrue(tFound >= 6, "the sweep read the compiled limits hierarchy rather than an empty roster (found " _ tFound _ ")")
    For tKnown = ..#LIMITS, ..#NARROW, ..#BUDGET, "OcuPilot.Test.TurnLimits", "OcuPilot.Test.TurnLimitsNav", "OcuPilot.Test.TurnLimitsNavCapped" {
        Do $$$AssertTrue($ListFind(tSeen, tKnown) > 0, tKnown _ " is in the derived population: " _ $ListToString(tSeen, ", "))
    }

    Set tRouteBound = +$Parameter("OcuPilot.Kernel.State.Base", "ROUTEMAXLENGTH")
    Do $$$AssertEquals(tRouteBound, ..MaxLenOf(..#STORE, "Route"), "ROUTEMAXLENGTH is the ledger Route column's own length")
    Do $$$AssertEquals(tRouteBound, ..MaxLenOf("OcuPilot.Kernel.State.Turn", "ContextRoute"), "and the turn ContextRoute column's")

    Do $$$AssertEquals(+$Parameter(..#STORE, "PAIRSMAXLENGTH"), ..MaxLenOf(..#STORE, "RequiredPairs"), "PAIRSMAXLENGTH is the RequiredPairs column's own length")
}

/// <p>A pair list that <b>raises</b> mid-walk discards every pair, so it answers
/// <code>pTruncated</code> 1 like any other short set. The empty answer is the dangerous one: an
/// empty <code>RequiredPairs</code> reads back through <method>StringToPairs</method> as a call
/// that required nothing, and <method>OcuPilot.Screen.Gate.EvaluatePairs</method> allows an empty
/// list -- so a row that reported an uncut empty set would be released to a cross-user reader
/// (AD-46).</p>
/// <p>Mutation (Rule 19): set <code>pTruncated</code> back to 0 in
/// <method>OcuPilot.Kernel.Audit.Ledger.PairsToString</method>'s <code>Catch</code> -- this goes
/// red on the flag, and the withhold assertion with it.</p>
Method TestAPairListThatRaisesIsReportedShortRatherThanEmpty()
{
    ; A %List whose second member is not itself a valid list: $List raises inside the walk.
    Set tBroken = $ListBuild($ListBuild("OcuPilotProbePairResource01", "USE")) _ "notalist"
    Set tText = $ClassMethod(..#LEDGER, "PairsToString", tBroken, .tCut)
    Do $$$AssertEquals(tText, "", "a pair list that raises yields no pairs at all")
    Do $$$AssertEquals(tCut, 1, "and is reported short, so a cross-user read cannot gate on it")

    ; End to end: the row is stored, and withheld from a cross-user read that holds the admin pair.
    Set tKey = ##class(OcuPilot.Test.Ledger).NewTurnKey()
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}, "", tBroken, ""), "the call is still recorded (AD-15)")
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", "OcuPilotProbeLedgerReader", ..#PROBEUSER, 0, tKey, 10, .tCross, .tCrossFault), "the cross-user read runs")
    Do $$$AssertEquals($IsObject(tCrossFault), 0, "with no fault, the administrative pair being held")
    Do $$$AssertEquals(tCross.rowsSent _ "|" _ tCross.rowsWithheld, "0|1", "and the row is absent and counted")
}

/// <p>A pair set longer than <parameter>OcuPilot.Kernel.State.Ledger.PAIRSMAXLENGTH</parameter> is
/// stored cut at a <b>whole-pair</b> boundary with
/// <code>requiredPairsTruncated</code> 1, and a cross-user read withholds that row and counts it --
/// even from a reader holding every pair the cut set still names (AD-24, AD-41, AD-46).</p>
/// <p>Mutation (Rule 19): drop the <code>$Length(tCandidate) > tMax</code> guard from
/// <method>OcuPilot.Kernel.Audit.Ledger.PairsToString</method> -- the whole set is returned uncut,
/// <code>GuardedAppend</code> stores <property>RequiredPairs</property> as it is given it, the row
/// overruns its column, the save fails and the row vanishes. (Mutating
/// <code>GuardedAppend</code> to store the value uncut is a no-op: that is what it already does,
/// by design -- only <method>PairsToString</method> knows where a pair boundary is.) Separately:
/// drop the
/// <code>requiredPairsTruncated</code> branch from
/// <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> -- the row is sent and the withheld
/// assertions go red.</p>
Method TestAnOverLongPairSetIsCutAtAPairBoundaryAndWithheldCrossUser()
{
    Set tMax = +$Parameter(..#STORE, "PAIRSMAXLENGTH")
    Set tPairs = ""
    For tI = 1:1:40 {
        Set tResource = "OcuPilotProbePairResource" _ $Extract("0" _ tI, *-1, *)
        Set tPairs = tPairs _ $ListBuild($ListBuild(tResource, "USE"))
        Do ##class(OcuPilot.Test.LedgerGate).Grant(tResource, "USE")
    }
    Set tWhole = $ClassMethod(..#LEDGER, "PairsToString", tPairs, .tCut)
    Do $$$AssertEquals(tCut, 1, "forty pairs overrun the bound and PairsToString says so")
    Do $$$AssertTrue($Length(tWhole) <= tMax, "the answer fits the column: " _ $Length(tWhole) _ " of " _ tMax)

    Set tKey = ##class(OcuPilot.Test.Ledger).NewTurnKey()
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}, "", tPairs, ""), "the call is recorded")
    Do $$$AssertEquals(..RowCount(), 1, "and the row is stored rather than failing the write")

    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tSelf, .tSelfFault), "the owner's own read runs")
    Do $$$AssertEquals(tSelf.rowsSent, 1, "and keeps the row (AD-46)")
    If tSelf.rowsSent '= 1 Quit
    Set tRow = tSelf.rows.%Get(0)
    Do $$$AssertEquals(tRow.requiredPairsTruncated, 1, "the row says its pair set was cut")
    Do $$$AssertTrue($Length(tRow.requiredPairs) <= tMax, "the stored set fits the column: " _ $Length(tRow.requiredPairs))
    Do $$$AssertTrue($Length(tRow.requiredPairs) > 0, "and is not empty")
    ; Cut on a pair boundary: every comma-separated piece still parses as a whole pair, so no half
    ; pair reads back as a requirement nobody named.
    Do $$$AssertEquals($ListLength($ClassMethod(..#LEDGER, "StringToPairs", tRow.requiredPairs)), $Length(tRow.requiredPairs, ","), "every piece of the cut set is a whole pair: " _ tRow.requiredPairs)

    ; The reader holds every pair the cut set names, so the row is withheld for being short and not
    ; for a privilege it lacks.
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", "OcuPilotProbeLedgerReader", ..#PROBEUSER, 0, tKey, 10, .tCross, .tCrossFault), "the cross-user read runs")
    Do $$$AssertEquals($IsObject(tCrossFault), 0, "with no fault, the administrative pair being held")
    Do $$$AssertEquals(tCross.rowsSent _ "|" _ tCross.rowsWithheld, "0|1", "and the row is absent and counted")
    Do $$$AssertEquals(tCross.rows.%ToJSON(), "[]", "with nothing of it on the wire")
}

/// <p>The <code>requiredPairs</code> of the one row a call with arguments <var>pInput</var> writes
/// through the shipped <method>OcuPilot.Kernel.Agent.Dispatch.AnswerOne</method> reading
/// <class>OcuPilot.Test.LedgerTool.Registry</class>. Answers a sentence naming what went wrong
/// instead, so a failure reads as itself rather than as a pair mismatch. Removes the turn's rows
/// before returning: they name <code>$Username</code> rather than
/// <parameter>PROBEUSER</parameter>.</p>
ClassMethod DispatchedPairs(pTurnKey As %String, pInput As %DynamicObject) As %String
{
    Set tOut = ""
    Try {
        Set tUse = {"id": "toolu_pairs"}
        Do tUse.%Set("name", "probe_ledger_read", "string")
        Do tUse.%Set("input", pInput)
        Set tUses = []
        Do tUses.%Push(tUse)
        Set tSC = $ClassMethod("OcuPilot.Test.LedgerDispatchProbe", "Answer", pTurnKey, $Username, "1", tUses, ..#LIMITS, .tResults, .tNames, , , .tDetails, "probe/route")
        If $$$ISERR(tSC) {
            Set tOut = "the dispatcher failed: " _ $System.Status.GetErrorText(tSC)
            Quit
        }
        Set tViewSC = $ClassMethod(..#LEDGER, "ViewForUser", $Username, "", 0, pTurnKey, 10, .tView, .tFault)
        If $$$ISERR(tViewSC) || $IsObject(tFault) || '$IsObject(tView) {
            Set tOut = "the view did not read"
            Quit
        }
        If tView.rowsSent '= 1 {
            Set tOut = "the call wrote " _ tView.rowsSent _ " rows: " _ tView.%ToJSON()
            Quit
        }
        Set tOut = tView.rows.%Get(0).requiredPairs
    } Catch ex {
        Set tOut = "the read raised: " _ ex.DisplayString()
    }
    Do $ClassMethod(..#STORE, "GuardedDeleteForTurn", pTurnKey)
    Quit tOut
}

/// <p>The declared <code>MAXLEN</code> of <var>pClass</var>'s <var>pProperty</var>, falling back to
/// <class>%Library.String</class>'s default when the property declares none, or <code>-1</code>
/// when the property does not exist -- which reddens the caller rather than reading as 0.</p>
ClassMethod MaxLenOf(pClass As %String, pProperty As %String) As %Integer
{
    Set tProperty = ##class(%Dictionary.CompiledProperty).%OpenId(pClass _ "||" _ pProperty)
    If '$IsObject(tProperty) Quit -1
    Set tMaxLen = ""
    If $IsObject(tProperty.Parameters) Set tMaxLen = tProperty.Parameters.GetAt("MAXLEN")
    If tMaxLen = "" Set tMaxLen = $Parameter("%Library.String", "MAXLEN")
    Quit +tMaxLen
}

/// <p>A pair holding <code>,</code> or <code>:</code> in either half cannot be spelled in this
/// column's grammar, so it is left out and the set is reported short. Written, it would read back
/// through <method>OcuPilot.Kernel.Audit.Ledger.StringToPairs</method> as a resource nobody named at
/// a permission nobody named, and a cross-user read gating on that would release the row. End to
/// end the row is still stored (AD-15) and withheld by the landed truncation signal -- from a reader
/// that holds every pair the recorded set does name, so the withhold is the shortness and not a
/// privilege.</p>
/// <p>Mutation (Rule 19): drop the separator check from
/// <method>OcuPilot.Kernel.Audit.Ledger.PairsToString</method> -- the bogus pair round-trips, the
/// set is not reported short and the row is released.</p>
Method TestAPairHoldingASeparatorIsOmittedAndTheSetReportedShort()
{
    Set tPlain = $ListBuild("OcuPilotProbePairPlain", "USE")
    Set tBad = $ListBuild($ListBuild("OcuPilotProbePair,Comma", "USE"), $ListBuild("OcuPilotProbePair:Colon", "USE"), $ListBuild("OcuPilotProbePairPermA", "US,E"), $ListBuild("OcuPilotProbePairPermB", "US:E"))
    For tI = 1:1:$ListLength(tBad) {
        Set tText = $ClassMethod(..#LEDGER, "PairsToString", $ListBuild(tPlain, $List(tBad, tI)), .tCut)
        Do $$$AssertEquals(tText, "OcuPilotProbePairPlain:USE", "pair " _ tI _ " is left out, the representable one kept: " _ tText)
        Do $$$AssertEquals(tCut, 1, "and pair " _ tI _ "'s set is reported short")
    }

    Set tKey = ##class(OcuPilot.Test.Ledger).NewTurnKey()
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}, "", $ListBuild(tPlain, $List(tBad, 1)), ""), "the call is still recorded (AD-15)")
    Do ##class(OcuPilot.Test.LedgerGate).Grant("OcuPilotProbePairPlain", "USE")

    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tSelf, .tSelfFault), "the owner's own read runs")
    Do $$$AssertEquals(tSelf.rowsSent, 1, "and keeps the row (AD-46)")
    If tSelf.rowsSent = 1 {
        Do $$$AssertEquals(tSelf.rows.%Get(0).requiredPairs, "OcuPilotProbePairPlain:USE", "which records only the representable pair")
        Do $$$AssertEquals(tSelf.rows.%Get(0).requiredPairsTruncated, 1, "and says its pair set is incomplete")
    }

    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", "OcuPilotProbeLedgerReader", ..#PROBEUSER, 0, tKey, 10, .tCross, .tCrossFault), "the cross-user read runs")
    Do $$$AssertEquals($IsObject(tCrossFault), 0, "with no fault, the administrative pair being held")
    Do $$$AssertEquals(tCross.rowsSent _ "|" _ tCross.rowsWithheld, "0|1", "and the row is absent and counted")
}


/// <p>The other two ways a pair is dropped report short as well: a member that is not a
/// two-element list, and a member with an empty resource or permission. Each leaves the column
/// stating a smaller requirement than the call had, which a cross-user read would release, so
/// each answers <var>pTruncated</var> 1 exactly as a separator-bearing pair does.</p>
/// <p>Mutation (Rule 19): drop either <code>Set pTruncated = 1</code> from
/// <method>OcuPilot.Kernel.Audit.Ledger.PairsToString</method>'s corresponding branch -- that
/// leg's flag assertion goes red while the representable pair still spells.</p>
Method TestEveryUnspellablePairIsReportedShort()
{
    Set tPlain = $ListBuild("OcuPilotProbePairPlain", "USE")
    Set tDropped = $ListBuild($ListBuild("OcuPilotProbePairShort"), $ListBuild("OcuPilotProbePairLong", "USE", "EXTRA"), $ListBuild("", "USE"), $ListBuild("OcuPilotProbePairNoPerm", ""))
    For tI = 1:1:$ListLength(tDropped) {
        Set tText = $ClassMethod(..#LEDGER, "PairsToString", $ListBuild(tPlain, $List(tDropped, tI)), .tCut)
        Do $$$AssertEquals(tText, "OcuPilotProbePairPlain:USE", "member " _ tI _ " is left out, the representable one kept: " _ tText)
        Do $$$AssertEquals(tCut, 1, "and member " _ tI _ "'s set is reported short")
    }

    ; The control: a set of representable pairs alone is not reported short, so the flag above is
    ; the drop and not something every call sets.
    Set tWhole = $ClassMethod(..#LEDGER, "PairsToString", $ListBuild(tPlain, $ListBuild("OcuPilotProbePairOther", "READ")), .tWholeCut)
    Do $$$AssertEquals(tWhole, "OcuPilotProbePairOther:READ,OcuPilotProbePairPlain:USE", "two representable pairs both spell: " _ tWhole)
    Do $$$AssertEquals(tWholeCut, 0, "and the set is not reported short")
}

}
