/// <p>Pins Story 24.17 Batch 1's refusals (AD-8, AD-29, AD-39, AD-56, AD-62): every value outside its rule, an update that would change nothing, an alert that is gone, an alert another user owns
/// and the gate, each answered by its own code before any vendor call, with the alert unchanged; a vendor error that is never a 200 and whose audit row reads <code>completed</code> false; and
/// that no log line carries a reason or a vendor's text, and none is written while the namespace is switched. The gate is tried as real principals in a child process.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropAlertCase</class> needs; it creates and removes five principals.</p>
Class OcuPilot.Test.InteropAlertRefusals Extends OcuPilot.Test.InteropAlertCase
{

Parameter GENERATOR = "OcuPilot.Test.InteropArchiveFixture";

/// <p>The principals: the pairs a full update needs, the same with the administration pair, with the Alerts resource at READ only, with no Alerts resource, and with READ on <code>USER</code>'s
/// database only.</p>
Parameter PRINCIPALS = "OcuP2417aExact:%Development:U,%Ens_Portal:U,%Ens_Alerts:RW,%DB_HSCUSTOM:RW,%DB_USER:RW;OcuP2417aAdmin:%Development:U,%Ens_Portal:U,%Ens_Alerts:RW,%Ens_AlertAdministration:U,%DB_HSCUSTOM:RW,%DB_USER:RW;OcuP2417aNoWrite:%Development:U,%Ens_Portal:U,%Ens_Alerts:R,%DB_HSCUSTOM:RW,%DB_USER:RW;OcuP2417aNoRead:%Development:U,%Ens_Portal:U,%DB_HSCUSTOM:RW,%DB_USER:RW;OcuP2417aDbRead:%Development:U,%Ens_Portal:U,%Ens_Alerts:RW,%DB_HSCUSTOM:RW,%DB_USER:R";

/// <p>The legs a probe runs, in order, <code>&lt;name&gt;|&lt;endpoint&gt;|&lt;type&gt;</code>.</p>
Parameter LEGS = "list|ManagedAlerts|LIST,history|ManagedAlertActions|LIST,owners|ManagedAlerts|ALERTOWNERS,mine|ManagedAlerts|UPDATEALERT,other|ManagedAlerts|UPDATEALERT,review|ManagedAlerts|ALERT";

Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    Set tSC = ##super()
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = "OcuP2417a" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ##super()
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit tSC
    Quit $$$ADDSC(tSC, $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS))
}

/// <p>The state of the probe <var>pId</var> that every refusal leaves: unassigned, open, level 1 (so a step down is possible) and no history.</p>
Method Arrange() As %Integer
{
    Quit $ClassMethod(..#FIXTURE, "Probe", ..#SOURCE, "", 1, 1, "to be refused")
}

/// <p>AC3: each value outside its rule is refused by its own code, in the port's answer, and leaves the alert as it was: an owner nobody lists, a level two above or below the current one or below
/// 0, minutes of 0, 20161 or not a number, and a reason that is empty, 501 characters or holds a tab. The limits themselves, 1 and 20160 minutes and a reason of 1 and 500 characters, are
/// accepted, each as an update of its own.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.AlertMinutesOK</method> compare with <code>&lt;</code> in place of <code>'&gt;</code> -- the 20160 leg goes red; let
/// <method>OcuPilot.Port.InteropPort.AlertLevelShapeOK</method> take a minus sign -- the leg one step below level 0 goes red.</p>
Method TestEachValueOutsideItsRuleIsRefusedByNameAndNothingIsSaved()
{
    Set tId = ..Arrange()
    Set tBefore = $ClassMethod(..#FIXTURE, "State", ..#SOURCE, tId)
    Set tLong = $Translate($Justify("", 501), " ", "x")
    Set tCases = $ListBuild($ListBuild("alertowner", "nobody", "INTEROP.ALERT.OWNER"), $ListBuild("alertlevel", 3, "INTEROP.ALERT.LEVEL"), $ListBuild("alertlevel", -1, "INTEROP.ALERT.LEVEL"), $ListBuild("alertlevel", "x", "INTEROP.ALERT.LEVEL"), $ListBuild("alertminutes", 0, "INTEROP.ALERT.NEXTACTION"), $ListBuild("alertminutes", 20161, "INTEROP.ALERT.NEXTACTION"), $ListBuild("alertminutes", "x", "INTEROP.ALERT.NEXTACTION"), $ListBuild("alertreason", "", "INTEROP.ALERT.REASON"), $ListBuild("alertreason", tLong, "INTEROP.ALERT.REASON"), $ListBuild("alertreason", "a" _ $Char(9) _ "b", "INTEROP.ALERT.REASON"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Kill tValues
        Set tValues("alertopen") = 0
        Set tValues("alertreason") = "a reason"
        Set tValues($List(tCase, 1)) = $List(tCase, 2)
        Set tVerdict = ..Update(tId, .tValues, .tRow, .tFault)
        Do $$$AssertEquals(tVerdict, "422 " _ $List(tCase, 3), $List(tCase, 1) _ "=" _ $Extract($List(tCase, 2), 1, 12) _ " is refused by its own code")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#SOURCE, tId), tBefore, "and the alert is as it was")
    }
    Kill tValues
    Set tValues("alertminutes") = 1
    Set tValues("alertreason") = "x"
    Do $$$AssertEquals(..Update(tId, .tValues, .tRow, .tFault), "200 ", "1 minute and a reason of 1 character are accepted")
    Kill tValues
    Set tValues("alertminutes") = 20160
    Set tValues("alertlevel") = 0
    Set tValues("alertreason") = $Translate($Justify("", 500), " ", "y")
    Do $$$AssertEquals(..Update(tId, .tValues, .tRow, .tFault), "200 ", "20160 minutes, the level one down and a reason of 500 characters are accepted")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#SOURCE, tId), "|1|0|2", "each was saved as an update of its own")
    Set tZero = $ClassMethod(..#FIXTURE, "Probe", ..#SOURCE, "", 1, 0, "at level 0")
    Kill tValues
    Set tValues("alertlevel") = -1
    Set tValues("alertreason") = "below 0"
    Do $$$AssertEquals(..Update(tZero, .tValues, .tRow, .tFault), "422 INTEROP.ALERT.LEVEL", "one step below level 0 is refused by its own code")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#SOURCE, tZero), "|1|0|0", "and that alert is as it was")
    Set tId2 = $ClassMethod(..#FIXTURE, "Probe", ..#SOURCE, "irisowner")
    Kill tValues
    Set tValues("alertowner") = ""
    Set tValues("alertreason") = "unassign"
    Do $$$AssertEquals(..Update(tId2, .tValues, .tRow, .tFault), "200 ", "an empty owner unassigns an alert")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#SOURCE, tId2), "|1|0|1", "which reads unassigned")
}

/// <p>AC3: the person's Update and the agent's mint refuse the same values by the same sentences before anything is stored: a minutes value of 0 answers 400 <code>TOOL.ARGUMENTS</code> to the screen
/// and the minted proposal is refused for the agent.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropManagedAlertUpdate.ScreenActionDelta</method> accept any minutes -- the screen leg goes red.</p>
Method TestTheScreenAndTheMintRefuseTheSameValues()
{
    Set tId = ..Arrange()
    Set tBefore = $ClassMethod(..#FIXTURE, "State", ..#SOURCE, tId)
    Set tText = ..Act(tId, {"NextActionMinutes": "0", "Reason": "soon"}, .tAnswer)
    Do $$$AssertEquals($Piece(tText, " ", 1), 400, "the screen refuses minutes of 0: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..Mint(tId, {"NextActionMinutes": 0, "Reason": "soon"}, .tReason, .tProposal, .tTurn), "INTEROP.ALERT.NEXTACTION", "the agent's mint is refused by the same code")
    Do $$$AssertEquals(..Mint(tId, {"Open": false}, .tReason2, .tProposal2, .tTurn2), "INTEROP.ALERT.REASON", "a mint with no reason is refused by its code")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#SOURCE, tId), tBefore, "and nothing was saved")
    Set tText = ..Act(tId, {"Owner": "nobody", "Reason": "give it away"}, .tOwner)
    Do $$$AssertEquals($Piece(tText, " ", 1) _ "|" _ $Select($IsObject(tOwner): tOwner.%Get("code"), 1: ""), "422|INTEROP.ALERT.OWNER", "an owner nobody lists is refused by its code from the screen")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn2))
}

/// <p>AC3: an update whose every value is what the alert already holds is refused <code>INTEROP.ALERT.UNCHANGED</code>, from the port, the screen and the agent's mint, and nothing is saved:
/// the vendor would record an empty or a repeated action.</p>
/// <p>Mutation (Rule 19): remove the unchanged refusal from <method>OcuPilot.Port.InteropPort.AlertJudge</method> -- this goes red.</p>
Method TestAnUpdateThatChangesNothingIsRefusedBeforeTheVendor()
{
    Set tId = $ClassMethod(..#FIXTURE, "Probe", ..#SOURCE, "", 1, 1, "unchanged")
    Kill tValues
    Set tValues("alertowner") = ""
    Set tValues("alertopen") = 1
    Set tValues("alertlevel") = 1
    Set tValues("alertreason") = "same again"
    Do $$$AssertEquals(..Update(tId, .tValues, .tRow, .tFault), "409 INTEROP.ALERT.UNCHANGED", "the port refuses it")
    Do $$$AssertEquals(..Act(tId, {"Open": "1", "Reason": "same again"}, .tAnswer), "409 INTEROP.ALERT.UNCHANGED", "and so does the screen")
    Do $$$AssertEquals(..Mint(tId, {"Open": true, "EscalationLevel": 1, "Reason": "same again"}, .tReason, .tProposal, .tTurn), "INTEROP.ALERT.UNCHANGED", "and the agent's mint")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#SOURCE, tId), "|1|1|0", "no history row was added")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC3: an alert that is gone, or an id of no shape, is 404 <code>INTEROP.ALERT.NOTFOUND</code> before any value is judged, for the update and for the state read.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.AlertGone</method> answer 400 -- this goes red.</p>
Method TestAnAlertThatIsGoneIsRefusedNotFound()
{
    Set tId = $ClassMethod(..#FIXTURE, "Probe", ..#SOURCE)
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "Delete", ..#SOURCE, tId), "the probe is deleted")
    Kill tValues
    Set tValues("alertopen") = 0
    Set tValues("alertreason") = "gone"
    Do $$$AssertEquals(..Update(tId, .tValues, .tRow, .tFault), "404 INTEROP.ALERT.NOTFOUND", "an update of a deleted alert is refused")
    Do $$$AssertEquals(..Update("12x", .tValues, .tRow2, .tFault2), "404 INTEROP.ALERT.NOTFOUND", "and so is an id of the wrong shape")
    Kill tQuery
    Set tQuery("id") = tId
    Do $$$AssertEquals(..Verdict(..#ENDPOINT, "ALERT", .tState, .tFault3, .tQuery), "404 INTEROP.ALERT.NOTFOUND", "as is the state read")
}

/// <p>AC4: a vendor error is never a 200: the vendor's status answers 500 <code>INTERNAL</code>, a raised error does too, the alert is unchanged and OcuPilot's audit row reads
/// <code>completed</code> false. Neither the reason nor the vendor's text reaches the log.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformAlertUpdate</method> ignore the vendor's status -- this goes red.</p>
Method TestAVendorErrorIsNeverA200AndIsAuditedAsNotCompleted()
{
    Set tSeam = ..#SEAM
    Set tId = ..Arrange()
    Kill tValues
    Set tValues("alertopen") = 0
    Set tValues("alertreason") = "reason " _ $Parameter(tSeam, "MARKER")
    ; One window for both modes: the probe's id is new, so its rows are counted cumulatively, one per update, whenever the audit stamps them.
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tExpect = 0
    For tMode = "status", "fault" {
        Set ^IRIS.Temp.OcuProbe2417Mode = tMode
        Do $ClassMethod(tSeam, "ClearLog")
        Set tExpect = tExpect + 1
        Do $$$AssertEquals(..Update(tId, .tValues, .tRow, .tFault, ..#SOURCE, tSeam), "500 INTERNAL", tMode _ ": the answer is 500, never 200")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#SOURCE, tId), "|1|1|0", tMode _ ": the alert is unchanged")
        Set tRows = ..OwnRows(tSince, tId, .tData, tExpect)
        Do $$$AssertEquals(tRows, tExpect, tMode _ ": OcuPilot records one ConfigChange for each update (since " _ tSince _ "; -1 is a failed audit read)")
        Do $$$AssertTrue((tData [ """completed"":false") && (tData '[ $Parameter(tSeam, "MARKER")), tMode _ ": it reads completed false and carries neither the reason nor the vendor's text: " _ tData)
        Set tLog = $ClassMethod(tSeam, "LoggedText")
        Do $$$AssertTrue((tLog '= "") && (tLog '[ $Parameter(tSeam, "MARKER")), tMode _ ": the log line names no reason and no vendor text: " _ tLog)
    }
    Kill ^IRIS.Temp.OcuProbe2417Mode
    Do $$$AssertEquals(..Update(tId, .tValues, .tOk, .tFault, ..#SOURCE, tSeam), "200 ", "and with the vendor's own call the same update saves")
}

/// <p>AC6: no OcuPilot call and no log line runs while the namespace is switched: a fault raised inside the switched block of the update and of the owner list is logged after the namespace is
/// restored, in the namespace the call was made from, and the alert's namespace never holds a log line.</p>
/// <p>Mutation (Rule 19): log a line inside the switched <code>Catch</code> of <method>OcuPilot.Port.InteropPort.PerformAlertUpdate</method> -- this goes red.</p>
Method TestNothingIsLoggedWhileTheNamespaceIsSwitched()
{
    Set tSeam = ..#SEAM
    Set tId = ..Arrange()
    Set ^IRIS.Temp.OcuProbe2417Mode = "here"
    Kill tValues
    Set tValues("alertopen") = 0
    Set tValues("alertreason") = "switched"
    Do $$$AssertEquals(..Update(tId, .tValues, .tRow, .tFault, ..#SOURCE, tSeam), "500 INTERNAL", "a fault inside the update's switched block is a 500")
    Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417Mode("hereIn")), ..#SOURCE, "the hook ran in the alert's namespace")
    Do $$$AssertEquals($ClassMethod(tSeam, "LoggedIn"), $NAMESPACE, "and the one line it caused was written in the namespace the call came from")
    Do $ClassMethod(tSeam, "ClearLog")
    Kill tOwnerValues
    Set tOwnerValues("alertowner") = "somebodyelse"
    Set tOwnerValues("alertreason") = "to someone"
    Do $$$AssertEquals(..Update(tId, .tOwnerValues, .tRow2, .tFault2, ..#SOURCE, tSeam), "500 INTERNAL", "a fault inside the owner list's switched block is a 500")
    Do $$$AssertEquals($ClassMethod(tSeam, "LoggedIn"), $NAMESPACE, "and its line, too, was written after the namespace was restored")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#SOURCE, tId), "|1|1|0", "the alert is unchanged")
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var> and run each of <parameter>LEGS</parameter> through <class>OcuPilot.Port.InteropPort</class> in
/// <code>USER</code>, then signal <code>{loggedIn, "&lt;leg&gt;": {http, code, failedPair}}</code> to process <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tSpec = $Piece(..#LEGS, ",", tI)
            Set tName = $Piece(tSpec, "|", 1)
            Kill tQuery
            Set tQuery("namespace") = ..#SOURCE
            Set tQuery("id") = $Get(^IRIS.Temp.OcuProbe2417Ids($Select((tName = "other") || (tName = "review"): "other", 1: "mine")))
            If $Piece(tSpec, "|", 2) = "ManagedAlertActions" Set tQuery("alert") = $Get(^IRIS.Temp.OcuProbe2417Ids("mine"))
            ; The review of an update of another user's alert, as the dialog's dry run and the agent's mint read it.
            If $Piece(tSpec, "|", 3) = "ALERT" Set tQuery("action") = "UPDATEALERT"
            If $Piece(tSpec, "|", 3) = "UPDATEALERT" {
                Set tQuery("alertopen") = 0
                Set tQuery("alertreason") = "probe"
            }
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = $ClassMethod(..#PORT, "Invoke", $Piece(tSpec, "|", 2), $Piece(tSpec, "|", 3), .tQuery, "", .tResult, .tHttp, .tFault)
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            If $IsObject(tFault) {
                Do tLeg.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
            Do tOut.%Set(tName, tLeg)
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying <code>error</code>.</p>
Method ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropAlertRefusals).Probe($Job, pUser)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 180)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 180 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>AC3: the gate, as real principals in a child process, refuses before any vendor call and before any value is judged: a reader reads the list and the history and is refused the owners and the
/// update naming <code>%Ens_Alerts:WRITE</code>; one without the resource is refused every read naming <code>%Ens_Alerts:READ</code>; one who cannot write <code>USER</code>'s database reads and
/// is refused the owners and the update naming that pair; a writer updates an unassigned alert, and is refused another user's alert naming <code>%Ens_AlertAdministration:USE</code> until it holds
/// that pair. The review of an update of another user's alert, as the dialog's dry run and the agent's mint read it, is refused naming that pair too. A refused update changed nothing.</p>
/// <p>Mutation (Rule 19): drop the administration pair check from <method>OcuPilot.Port.InteropPort.PerformAlertUpdate</method> -- the <code>OcuP2417aExact</code> leg of another's alert goes red;
/// drop it from <method>OcuPilot.Port.InteropPort.ReadAlert</method> -- the review leg goes red.</p>
Method TestTheGateRefusesEachPrincipalBeforeAnyVendorCall()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    Do $$$AssertStatusOK(tSC, "the principals are created")
    If $$$ISERR(tSC) Quit
    Set tDeny = ##class(OcuPilot.Kernel.Denial).Code()
    Set tOk = "200||"
    Set tAdmin = "403|" _ tDeny _ "|%Ens_AlertAdministration:USE"
    Set tWrite = "403|" _ tDeny _ "|%Ens_Alerts:WRITE"
    Set tRead = "403|" _ tDeny _ "|%Ens_Alerts:READ"
    Set tDb = "403|" _ tDeny _ "|%DB_USER:WRITE"
    Set tExpected("OcuP2417aExact") = $ListBuild(tOk, tOk, tOk, tOk, tAdmin, tAdmin)
    Set tExpected("OcuP2417aAdmin") = $ListBuild(tOk, tOk, tOk, tOk, tOk, tOk)
    Set tExpected("OcuP2417aNoWrite") = $ListBuild(tOk, tOk, tWrite, tWrite, tWrite, tAdmin)
    Set tExpected("OcuP2417aNoRead") = $ListBuild(tRead, tRead, tRead, tRead, tRead, tRead)
    Set tExpected("OcuP2417aDbRead") = $ListBuild(tOk, tOk, tDb, tDb, tDb, tAdmin)
    Set tUser = ""
    For {
        Set tUser = $Order(tExpected(tUser))
        If tUser = "" Quit
        Do $ClassMethod(..#FIXTURE, "DropProbes")
        Set tMine = $ClassMethod(..#FIXTURE, "Probe", ..#SOURCE, "", 1, 0, "mine")
        Set tOther = $ClassMethod(..#FIXTURE, "Probe", ..#SOURCE, "OcuProbeOther", 1, 0, "another's")
        Set ^IRIS.Temp.OcuProbe2417Ids("mine") = tMine
        Set ^IRIS.Temp.OcuProbe2417Ids("other") = tOther
        Set tOut = ..ProbeAs(tUser)
        Kill ^IRIS.Temp.OcuProbe2417Ids
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tUser _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tUser _ ": the principal logged in")
        Set tMineDone = 0
        Set tOtherDone = 0
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tLegName = $Piece($Piece(..#LEGS, ",", tI), "|", 1)
            Set tLeg = tOut.%Get(tLegName)
            Set tGot = $Select($IsObject(tLeg): tLeg.http _ "|" _ tLeg.%Get("code") _ "|" _ tLeg.%Get("failedPair"), 1: "no answer")
            Do $$$AssertEquals(tGot, $List(tExpected(tUser), tI), tUser _ ": the " _ tLegName _ " leg is answered as declared")
            If (tLegName = "mine") && (tGot = tOk) Set tMineDone = 1
            If (tLegName = "other") && (tGot = tOk) Set tOtherDone = 1
        }
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#SOURCE, tMine), $Select(tMineDone: "|0|0|1", 1: "|1|0|0"), tUser _ ": an admitted update was saved and a refused one changed nothing")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#SOURCE, tOther), $Select(tOtherDone: "OcuProbeOther|0|0|1", 1: "OcuProbeOther|1|0|0"), tUser _ ": and so for another user's alert")
    }
    Do $$$AssertStatusOK($ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS), "the principals are removed")
}

}
