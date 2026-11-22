/// <p>Pins Story 24.16's purge refusals end to end against back-dated probe records in <code>USER</code> (AD-6, AD-8, AD-39, AD-62): days that are not a whole number from
/// 0 to 99999 are 422 <code>INTEROP.PURGE.DAYS</code> from the person's Purge, the agent's mint and the port, before any vendor call and with nothing deleted; a purge
/// already running in the namespace, the classic page's lock held by a child job this class starts and ends, is 409 <code>INTEROP.PURGE.RUNNING</code> and deletes
/// nothing. The gate runs as real principals in a child process: a caller without <code>%Ens_Purge:USE</code>, one without <code>%Ens_PurgeSettings:WRITE</code>, one who
/// cannot write the database and one who cannot read it, each refused by name before any vendor call and before any value is judged. A purge with the bitmap cleanup on gives the
/// process's roles back, on the way out of the vendor call and on a raised error, and no log line carries a description or a vendor status text.</p>
/// <p><b>What it needs from the environment:</b> interoperability-enabled <code>USER</code> and <code>HSCUSTOM</code> namespaces, the HTTP test account and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes users and roles named <code>OcuP2416*</code>. It removes every probe record,
/// principal and role it creates, ends the lock-holding job it starts, and puts both namespaces' setting nodes back exactly as it found them.</p>
Class OcuPilot.Test.InteropPurgeRefusals Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropPurgeFixture";

Parameter CONTROL = "OcuPilot.Test.InteropPurgeControl";

Parameter ITEMCONTROL = "OcuPilot.Test.InteropItemControl";

Parameter GENERATOR = "OcuPilot.Test.InteropLookupGate";

Parameter SEAM = "OcuPilot.Test.InteropPurgeSeam";

Parameter PORT = "OcuPilot.Port.InteropPort";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by <code>;</code>.</p>
Parameter PRINCIPALS = "OcuP2416Exact:%Development:U,%Ens_Portal:U,%Ens_Purge:U,%Ens_PurgeSettings:W,%DB_USER:RW;OcuP2416NoPurge:%Development:U,%Ens_Portal:U,%Ens_PurgeSettings:W,%DB_USER:RW;OcuP2416NoSettings:%Development:U,%Ens_Portal:U,%Ens_Purge:U,%DB_USER:RW;OcuP2416DbRead:%Development:U,%Ens_Portal:U,%Ens_Purge:U,%Ens_PurgeSettings:W,%DB_USER:R;OcuP2416NoDb:%Development:U,%Ens_Portal:U,%Ens_Purge:U,%Ens_PurgeSettings:W";

/// <p>The one principal the roles legs run as: it holds no administrative role.</p>
Parameter ROLESPRINCIPAL = "OcuP2416Roles:%Development:U,%Ens_Portal:U,%Ens_Purge:U,%DB_USER:RW";

/// <p>The legs a probe runs, in order, <code>&lt;name&gt;|&lt;type&gt;|&lt;endpoint&gt;</code>.</p>
Parameter LEGS = "counts|LIST|Purge,state|PURGESTATE|Purge,purge|PURGE|Purge,settings|LIST|PurgeSettings,set|SETTINGSET|PurgeSettings";

Property PreparedPassword As %String;

Property PreparedSettings As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSettings = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropPurgeRefusals creates and deletes users and roles, deletes probe records and writes the purge settings on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP2416Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set ..PreparedSettings = $ClassMethod(..#FIXTURE, "SaveSettings")
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Kill ^IRIS.Temp.OcuProbe2416Hold, ^IRIS.Temp.OcuProbe2416Mode
    Set tSC = $$$OK
    If ..PreparedSettings '= "" Set tSC = $ClassMethod(..#FIXTURE, "RestoreSettings", ..PreparedSettings)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS))
    Quit $$$ADDSC(tSC, $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#ROLESPRINCIPAL))
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "ClearLog")
    Kill ^IRIS.Temp.OcuProbe2416Hold, ^IRIS.Temp.OcuProbe2416Mode
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    For tNode = "BodiesToo", "KeepIntegrity", "NamespaceBitmapMaint", "Desc" {
        Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", tNode, "<absent>")
    }
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "ClearLog")
    Set ^IRIS.Temp.OcuProbe2416Hold = "stop"
    Hang 0.3
    Kill ^IRIS.Temp.OcuProbe2416Hold, ^IRIS.Temp.OcuProbe2416Mode
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "DropProbes"), "the probe records are removed from both namespaces, and none survives")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "RestoreSettings", ..PreparedSettings), "both namespaces' setting nodes are put back")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SaveSettings"), ..PreparedSettings, "and read as they did before the test")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The code of <var>pFault</var>, or <code>""</code>.</p>
ClassMethod CodeOf(pFault) As %String
{
    Quit $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>The port class <var>pClass</var>'s purge of USER for <var>pDays</var> as <code>status code</code>, the envelope in <var>pFault</var>.</p>
ClassMethod Verdict(pDays As %String, Output pFault, pClass As %String = {..#PORT}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "USER"
    Set tQuery("days") = pDays
    Set tSC = $ClassMethod(pClass, "Invoke", "Purge", "PURGE", .tQuery, "", .tRow, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ ..CodeOf(.pFault)
}

/// <p>Whether any process holds the classic page's purge lock of USER.</p>
ClassMethod LockHeld() As %Boolean
{
    Quit $Data(^$LOCK("^IRIS.Temp.EnsPurgeAll(""USER"",""lock"")")) > 0
}

/// <p>Give the user <var>pUser</var> the existing role <var>pRole</var>.</p>
ClassMethod AddRole(pUser As %String, pRole As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRoles = pRole
        Set tSC = ##class(Security.Users).AddRoles(pUser, .tRoles)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many rows the vendor's bitmap maintenance has recorded for <var>pNamespace</var>; a cleanup adds one per class it visits.</p>
ClassMethod BitmapRuns(pNamespace As %String) As %Integer
{
    Set tCount = 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %SYS_Maint.Bitmap WHERE Namespace = ?", pNamespace)
    If tRS.%Next() Set tCount = tRS.%GetData(1)
    Quit tCount
}

/// <p>Arrange one back-dated header, with a body, one back-dated event log row and the header made now.</p>
ClassMethod Arrange() As %Boolean
{
    Quit $ClassMethod(..#CONTROL, "Arrange")
}

/// <p>The counts a refusal must leave as they were.</p>
Parameter ARRANGED = "header=2 body=2 log=1 io=1 alertClosed=1 alertOpen=1";

/// <p>AC3: days that are not a whole number from 0 to 99999 (negative, fractional, past the top, text and empty) are refused 422 <code>INTEROP.PURGE.DAYS</code> by the
/// port, with the sentence the instance publishes, by the person's Purge and by the agent's mint, before any vendor call, and nothing is deleted; 99999 is accepted and
/// deletes nothing, because no probe is that old.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PurgeDaysOK</method> accept a negative number -- the first leg goes red.</p>
Method TestDaysThatAreNotAWholeNumberFrom0To99999AreRefusedBeforeAnyVendorCall()
{
    Do $$$AssertTrue($ClassMethod(..#CONTROL, "Arrange"), "the probe records are arranged")
    Set tReason = ##class(OcuPilot.Api.InteropError).ReasonFor("INTEROP.PURGE.DAYS")
    Set tVendorCalls = 0
    For tDays = "-1", "1.5", "100000", "x", "", "07", "1e3" {
        Do $$$AssertEquals(..Verdict(tDays, .tFault, ..#SEAM), "422 INTEROP.PURGE.DAYS", "days '" _ tDays _ "': the port refuses them")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("reason"), 1: ""), tReason, "days '" _ tDays _ "': with the published sentence")
        Set tText = $ClassMethod(..#CONTROL, "Act", tDays, .tAnswer)
        Do $$$AssertEquals(tText, "400 TOOL.ARGUMENTS", "days '" _ tDays _ "': the person's Purge is refused as the tool's argument rule, as the mint is")
        ; An empty value never reaches the days rule: the screen action's own argument check refuses it first, with its own sentence.
        If tDays '= "" Do $$$AssertEquals($Select($IsObject($Get(tAnswer)) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("problem"), 1: ""), tReason, "days '" _ tDays _ "': with the published sentence: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
        Do $$$AssertEquals($ClassMethod(..#CONTROL, "Mint", tDays, .tProposal, .tTurn, .tMintReason), "TOOL.ARGUMENTS", "days '" _ tDays _ "': the agent's mint is refused")
        Do $$$AssertEquals(tMintReason, tReason, "days '" _ tDays _ "': with the same sentence")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), ..#ARRANGED, "days '" _ tDays _ "': nothing was deleted")
    }
    Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2416Mode("before")), "", "no refusal reached the vendor call")
    Do $$$AssertEquals(..Verdict("99999", .tFault), "200 ", "99999 days is accepted")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), ..#ARRANGED, "and deletes nothing, because no probe is that old")
}

/// <p>AC3: a purge while the classic page's lock is held by another process is 409 <code>INTEROP.PURGE.RUNNING</code> from the port, the person's Purge and the agent's
/// mint, with the published sentence, and deletes nothing; the purge state read reports it running; once the other process lets go the purge runs. The holder is a child job this
/// test starts and ends.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PurgeRunningHere</method> answer 0 and the write's lock take no lock -- this goes red.</p>
Method TestAPurgeWhileTheLockIsHeldIsRefusedAndDeletesNothing()
{
    Do $$$AssertTrue($ClassMethod(..#CONTROL, "Arrange"), "the probe records are arranged")
    Kill ^IRIS.Temp.OcuProbe2416Hold
    Job ##class(OcuPilot.Test.InteropPurgeFixture).HoldLock("USER")::10
    Do $$$AssertTrue($Test, "the lock-holding job starts")
    If '$Test Quit
    For tI = 1:1:100 {
        If $Get(^IRIS.Temp.OcuProbe2416Hold) = 1 Quit
        Hang 0.1
    }
    Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2416Hold), 1, "it holds the lock")
    Do $$$AssertTrue(..LockHeld(), "and the lock reads as held")
    Set tReason = ##class(OcuPilot.Api.InteropError).ReasonFor("INTEROP.PURGE.RUNNING")
    Do $$$AssertEquals(..Verdict("3650", .tFault), "409 INTEROP.PURGE.RUNNING", "the port refuses the purge")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("reason"), 1: ""), tReason, "with the published sentence")
    Set tText = $ClassMethod(..#CONTROL, "Act", "3650", .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tText), "INTEROP.PURGE.RUNNING", "the person's Purge is refused: " _ tText)
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Mint", "3650", .tProposal, .tTurn, .tMintReason), "INTEROP.PURGE.RUNNING", "the agent's mint is refused")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Purge", "PURGESTATE", .tQuery, "", .tState, .tHttp, .tStateFault)
    Do $$$AssertEquals($Select($IsObject($Get(tState)): tState.Running, 1: ""), 1, "the state read says a purge is running")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), ..#ARRANGED, "nothing was deleted")
    Set ^IRIS.Temp.OcuProbe2416Hold = "stop"
    For tI = 1:1:100 {
        If $Get(^IRIS.Temp.OcuProbe2416Hold) = 2 Quit
        Hang 0.1
    }
    Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2416Hold), 2, "the holder lets go and ends")
    Do $$$AssertEquals(..Verdict("3650", .tFault), "200 ", "and the purge then runs")
    Do $$$AssertTrue('..LockHeld(), "and lets go of the lock when it has run")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), "header=1 body=2 log=0 io=0 alertClosed=0 alertOpen=1", "deleting the old records and keeping the old body, as Include message bodies is off")
}

/// <p>AC3: no log line a failed purge writes carries a vendor status text or the namespace's description: an error status the vendor answers reaches the log as its error
/// codes alone, and a purge that raises is logged without either.</p>
/// <p>It also pins that such a purge lets go of the lock and that an error status is still audited.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PurgeVendorStatus</method> answer the status it was given -- this goes red; remove the lock release from the
/// Catch of <method>OcuPilot.Port.InteropPort.PerformPurge</method> -- the fault leg goes red; move the audit call below the vendor error's quit -- the status leg goes red.</p>
Method TestNoLogLineCarriesADescriptionOrAVendorStatusText()
{
    Set tMarker = $Parameter(..#SEAM, "MARKER")
    Set tDescription = "OcuProbe2416 private description"
    Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", "Desc", tDescription)
    Do $$$AssertTrue($ClassMethod(..#CONTROL, "Arrange"), "the probe records are arranged")
    For tMode = "status", "fault" {
        Set ^IRIS.Temp.OcuProbe2416Mode = tMode
        Do $ClassMethod(..#SEAM, "ClearLog")
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tVerdict = ..Verdict("3650", .tFault, ..#SEAM)
        Do $$$AssertEquals($Extract(tVerdict, 1, 3), "500", tMode _ ": the purge answers 500: " _ tVerdict)
        Do $$$AssertTrue('..LockHeld(), tMode _ ": a purge that failed lets go of the lock")
        If tMode = "status" Do $$$AssertEquals($ClassMethod(..#CONTROL, "OwnRows", tSince), 1, "status: a purge the vendor answered with an error is still recorded, as a partial purge may have deleted")
        Set tLog = $ClassMethod(..#SEAM, "LoggedText")
        Do $$$AssertTrue(tLog '= "", tMode _ ": the failure is logged")
        Do $$$AssertTrue(tLog '[ tMarker, tMode _ ": the log carries no vendor status text: " _ tLog)
        Do $$$AssertTrue(tLog '[ tDescription, tMode _ ": and no description: " _ tLog)
        Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() '[ tMarker) && (tFault.%ToJSON() '[ tDescription), tMode _ ": and neither does the envelope")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), ..#ARRANGED, "a purge the vendor did not run deleted nothing")
}

/// <p>The two legs of the roles test: a purge with the bitmap cleanup on, as a process holding no administrative role, over back-dated probes, and the same
/// with a vendor call that raises after the process has changed its roles. In each the roles the process holds before and after the port's call are equal; in the
/// second the process held other roles inside the call, so the test cannot pass for want of a change.</p>
/// <p>Mutation (Rule 19): remove <code>New $ROLES</code> from <method>OcuPilot.Port.InteropPort.PurgeFrame</method> -- the raised-error leg goes red.</p>
Method TestTheProcessRolesAreGivenBackOnSuccessAndOnAnError()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#ROLESPRINCIPAL, ..PreparedPassword, "the purge roles")
    Do $$$AssertStatusOK(tSC, "the principal is created")
    If $$$ISERR(tSC) Quit
    ; The Ensemble administrator role carries the SQL rights a whole purge needs; without them the vendor answers an error status (measured).
    Do $$$AssertStatusOK(..AddRole("OcuP2416Roles", "%EnsRole_Administrator"), "the principal holds the Ensemble administrator role, and no administrative one")
    Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", "NamespaceBitmapMaint", "1")
    Do $$$AssertTrue($ClassMethod(..#CONTROL, "Arrange"), "the probe records are arranged")
    Set tRuns = ..BitmapRuns("USER")
    Set tOut = ..ProbeAs("OcuP2416Roles", "success")
    Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), "the success probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
    If $IsObject(tOut) && (tOut.%Get("error") = "") {
        Do $$$AssertTrue(tOut.loggedIn, "the principal logged in")
        Do $$$AssertEquals(tOut.http, 200, "the purge with the bitmap cleanup on ran and answered 200: " _ tOut.%ToJSON())
        Do $$$AssertTrue(..BitmapRuns("USER") > tRuns, "and the vendor's bitmap cleanup ran over USER")
        Do $$$AssertEquals(tOut.after, tOut.before, "the process's roles after the call are the roles before it: " _ tOut.before)
    }
    ; The raised-error leg runs in this process, which holds roles it may add to (a principal may not change its roles at all).
    Set ^IRIS.Temp.OcuProbe2416Mode = "roles"
    Set tBefore = $ROLES
    Set tVerdict = ..Verdict("3650", .tFault, ..#SEAM)
    Set tAfter = $ROLES
    Do $$$AssertEquals($Extract(tVerdict, 1, 3), "500", "the purge that raised answered 500: " _ tVerdict)
    Do $$$AssertEquals(tAfter, tBefore, "the process's roles after the call are the roles before it: " _ tBefore)
    Do $$$AssertTrue($Get(^IRIS.Temp.OcuProbe2416Mode("inside")) '= $Get(^IRIS.Temp.OcuProbe2416Mode("before")), "and inside the call the process held other roles: " _ $Get(^IRIS.Temp.OcuProbe2416Mode("inside")))
    Do $$$AssertStatusOK($ClassMethod(..#GENERATOR, "DeletePrincipals", ..#ROLESPRINCIPAL), "the principal is removed")
}

/// <p>AC3: the gate, as real principals in a child process, refuses before any vendor call and before any value is judged: a caller without <code>%Ens_Purge:USE</code> is
/// refused the counts, the state and the purge naming that pair and reads and sets the settings; one without <code>%Ens_PurgeSettings:WRITE</code> is refused both settings
/// legs naming it and reads the counts; one who cannot write the database is refused the purge and the set naming it and reads; one who cannot read it is refused every leg. A
/// refused purge deleted nothing and a refused set stored nothing.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.InteropPort.PURGEPAIRS</parameter> from the Purge endpoint's pairs -- the <code>OcuP2416NoPurge</code> legs go red.</p>
Method TestTheGateRefusesEachPrincipalBeforeAnyVendorCall()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword, "the purge gate")
    Do $$$AssertStatusOK(tSC, "the principals are created")
    If $$$ISERR(tSC) Quit
    Set tDeny = ##class(OcuPilot.Kernel.Denial).Code()
    Set tOk = "200||"
    Set tAny = "*"
    Set tPurge = "403|" _ tDeny _ "|%Ens_Purge:USE"
    Set tSettings = "403|" _ tDeny _ "|%Ens_PurgeSettings:WRITE"
    Set tWrite = "403|" _ tDeny _ "|%DB_USER:WRITE"
    Set tRead = "403|" _ tDeny _ "|%DB_USER:READ"
    Set tExpected("OcuP2416Exact") = $ListBuild(tOk, tOk, tAny, tOk, tOk)
    Set tExpected("OcuP2416NoPurge") = $ListBuild(tPurge, tPurge, tPurge, tOk, tOk)
    Set tExpected("OcuP2416NoSettings") = $ListBuild(tOk, tOk, tAny, tSettings, tSettings)
    Set tExpected("OcuP2416DbRead") = $ListBuild(tOk, tOk, tWrite, tOk, tWrite)
    Set tExpected("OcuP2416NoDb") = $ListBuild(tRead, tRead, tWrite, tRead, tWrite)
    Set tUser = ""
    For {
        Set tUser = $Order(tExpected(tUser))
        If tUser = "" Quit
        Do $ClassMethod(..#FIXTURE, "DropProbes")
        Do $ClassMethod(..#FIXTURE, "PutSetting", "USER", "Desc", "<absent>")
        Do $$$AssertTrue($ClassMethod(..#CONTROL, "Arrange"), tUser _ ": the probe records are arranged")
        Set tOut = ..ProbeAs(tUser, "gate")
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tUser _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tUser _ ": the principal logged in")
        Set tPurged = 1
        Set tSet = 1
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tLegName = $Piece($Piece(..#LEGS, ",", tI), "|", 1)
            Set tLeg = tOut.%Get(tLegName)
            Set tGot = $Select($IsObject(tLeg): tLeg.http _ "|" _ tLeg.%Get("code") _ "|" _ tLeg.%Get("failedPair"), 1: "no answer")
            Set tWant = $List(tExpected(tUser), tI)
            If tWant = tAny {
                Do $$$AssertTrue($IsObject(tLeg) && (tLeg.%Get("failedPair") = ""), tUser _ ": the " _ tLegName _ " leg is admitted past the gate: " _ tGot)
            } Else {
                Do $$$AssertEquals(tGot, tWant, tUser _ ": the " _ tLegName _ " leg is answered as declared")
            }
            If (tLegName = "purge") && (tWant '= tAny) Set tPurged = 0
            If (tLegName = "set") && (tWant '= tOk) Set tSet = 0
        }
        If 'tPurged Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts", "USER"), ..#ARRANGED, tUser _ ": a refused purge deleted nothing")
        If 'tSet Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", "USER"), "<absent>|<absent>|<absent>|<absent>", tUser _ ": a refused set stored nothing")
        If tSet Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", "USER"), "<absent>|<absent>|<absent>|OcuProbe2416 gate", tUser _ ": an admitted set stored what it sent")
    }
    Do $$$AssertStatusOK($ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS), "the principals are removed")
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in <var>pMode</var> in a child process and answer what it signalled, or an object carrying <code>error</code>.</p>
Method ProbeAs(pUser As %String, pMode As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropPurgeRefusals).Probe($Job, pUser, pMode)::10
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

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var> and, in mode <code>gate</code>, run each of <parameter>LEGS</parameter> through
/// <class>OcuPilot.Port.InteropPort</class> and signal <code>{loggedIn, "&lt;leg&gt;": {http, code, failedPair}}</code>; in mode <code>success</code> or <code>fault</code> run the purge through
/// <class>OcuPilot.Test.InteropPurgeSeam</class> and signal <code>{loggedIn, http, before, after}</code>, the roles the process held either side of the call. Signals
/// <code>{error}</code> to process <var>pParent</var> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pMode As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        If pMode '= "gate" {
            Set ^IRIS.Temp.OcuProbe2416Mode = pMode
            Set tBefore = $ROLES
            Kill tQuery
            Set tQuery("namespace") = "USER"
            Set tQuery("id") = "USER"
            Set tQuery("days") = "3650"
            Set tSC = $ClassMethod(..#SEAM, "Invoke", "Purge", "PURGE", .tQuery, "", .tResult, .tHttp, .tFault)
            Do tOut.%Set("http", +$Get(tHttp), "number")
            Do tOut.%Set("before", tBefore)
            Do tOut.%Set("after", $ROLES)
        } Else {
            For tI = 1:1:$Length(..#LEGS, ",") {
                Set tSpec = $Piece(..#LEGS, ",", tI)
                Set tName = $Piece(tSpec, "|", 1)
                Set tType = $Piece(tSpec, "|", 2)
                Kill tQuery
                Set tQuery("namespace") = "USER"
                Set tBody = ""
                If tType = "PURGE" Set tQuery("days") = "3650"
                If tType = "SETTINGSET" {
                    Set tQuery("id") = "Description"
                    Set tBody = {"Value": "OcuProbe2416 gate"}
                }
                Set tHttp = 0
                Set tFault = ""
                Kill tResult
                Set tSC = $ClassMethod(..#PORT, "Invoke", $Piece(tSpec, "|", 3), tType, .tQuery, tBody, .tResult, .tHttp, .tFault)
                Set tLeg = {}
                Do tLeg.%Set("http", +tHttp, "number")
                If $IsObject(tFault) {
                    Do tLeg.%Set("code", tFault.%Get("code"))
                    If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
                }
                Do tOut.%Set(tName, tLeg)
            }
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
