/// <p>Pins Story 16.12 against live locks (AD-2, AD-8, AD-10, AD-51, AD-52, AD-53, AD-58): each scope
/// removes exactly the locks it names and no others; the vendor's 409 refuses a removal while the
/// owner is in a transaction, and the override removes it with the owner still in its transaction; the
/// agent's mint and Confirm carry the diff, the consequence, the published sentence, the read-back,
/// the marker and the change event; an owner that took a lock since the mint refuses the confirm; a
/// principal holding the screen's pairs alone is refused naming <code>%DB_IRISSYS:WRITE</code> on
/// both callers, and removes with it; a crafted id is answered 404; a lock on one of OcuPilot's own
/// globals is refused on both callers; and the vendor audits each removal under the caller.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and
/// serving over HTTP as <class>OcuPilot.Test.Http</class>'s test account, auditing on, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes
/// two users and two roles and starts processes that hold locks. Every lock it takes is on
/// <parameter>PROBEGLOBAL</parameter> or <parameter>OWNGLOBAL</parameter>, held by a process it
/// started (<method>StartHolder</method>, bounded by <parameter>HOLDSECONDS</parameter>); it removes
/// no other lock, and every holder is ended and the residue checked after each test.</p>
Class OcuPilot.Test.LockRemoveLive Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.LockList";

Parameter REMOVE = "OcuPilot.Screen.Tool.LockRemove";

Parameter REMOVEPROCESS = "OcuPilot.Screen.Tool.LockRemoveProcess";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The global every probe lock is taken on. It does not begin with <code>OcuPilot</code>.</p>
Parameter PROBEGLOBAL = "OcuProbeLock";

/// <p>The global the prohibited leg's probe locks, which the lock arm reads as OcuPilot's own.</p>
Parameter OWNGLOBAL = "OcuPilotTestLock16x12";

/// <p>The longest a holder waits before it ends on its own, in seconds.</p>
Parameter HOLDSECONDS = 300;

/// <p>The purpose-built principal holding the install namespace's code read and the Locks screen's
/// two pairs, and not <code>%DB_IRISSYS:WRITE</code>.</p>
Parameter READERUSER = "OcuPilotLockGateReader";

Parameter READERROLE = "OcuPilotLockGateReaderRole";

/// <p>The same, with <code>%DB_IRISSYS:WRITE</code> added.</p>
Parameter WRITERUSER = "OcuPilotLockGateWriter";

Parameter WRITERROLE = "OcuPilotLockGateWriterRole";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The holder processes this test started, which its teardown ends.</p>
Property PreparedHolders As %List;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedHolders = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LockRemoveLive creates and deletes users and roles and holds locks on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotLock" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ..EnsurePrincipals()
}

/// <p>End any holder still running, remove both principals and their roles, and fail when a probe
/// lock or a principal survives.</p>
Method OnAfterAllTests() As %Status
{
    Do ..StopProbeHolders()
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#READERUSER, ..#WRITERUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
        }
        For tRole = ..#READERROLE, ..#WRITERROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
        }
        Set tLeft = ##class(Security.Users).Exists(..#READERUSER) || ##class(Security.Users).Exists(..#WRITERUSER) || ##class(Security.Roles).Exists(..#READERROLE) || ##class(Security.Roles).Exists(..#WRITERROLE)
        Set $NAMESPACE = tOrigNS
        If tLeft Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.LockRemoveLive left a throwaway principal on the instance")
        If $$$ISOK(tSC) && (..ProbeLockCount() '= 0) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.LockRemoveLive left a probe lock on the instance")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedHolders = ""
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

/// <p>End every holder this test started and assert no probe lock remains listed (AC9).</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    For tI = 1:1:$ListLength(..PreparedHolders) Do ..StopHolder($List(..PreparedHolders, tI))
    Set ..PreparedHolders = ""
    Do $$$AssertEquals(..ProbeLockCount(), 0, "no probe lock survives the test (AC9)")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>AC4, AD-53: each scope over the route, as the test account. <code>remove</code> takes one of
/// P1's three locks and leaves the others; <code>removeprocess</code> takes both of the rest of P1's and leaves
/// P2's, one of which is a decoy whose reference carries P1's owner key and so matches the vendor's
/// substring filter for it; <code>removeclient</code> on a local owner is refused with the published
/// sentence and sends nothing; each removal answers the deleted event with a read-back that finds the
/// lock gone.</p>
/// <p>Mutation (Rule 19): keep every row of <method>OcuPilot.Port.LockPort.Listing</method>'s owner
/// filter without the exact owner compare -- P2's decoy is removed with P1's locks and this goes
/// red.</p>
Method TestEachScopeRemovesExactlyItsLocks()
{
    Set tP1 = ..Holder("aa", 3, 0)
    If tP1 = "" Quit
    Set tP2 = ..Holder("ab", 1, 0, , ",P" _ tP1 _ ",")
    If tP2 = "" Quit
    Set tA = ..IdOf(tP1, 1)
    Set tB = ..IdOf(tP1, 2)
    Set tC = ..IdOf(tP2, 1)
    Set tDecoy = ..IdOf(tP2, 2)

    Do ..Act("remove", tA, "false", "", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Field(tBody, "action") _ " " _ ..ReadBack(tBody), "200 deleted notFound", "remove answers the deleted event and finds the lock gone: " _ ..Shown(tBody))
    Do $$$AssertEquals(..Listed(tA) _ ..Listed(tB) _ ..Listed(tC), "011", "it removed a alone")
    Do $$$AssertEquals(..CountOf(tP1), 2, "and P1 still holds its other two")

    Do ..Act("removeclient", tB, "false", "", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..Problem(tBody), "400 TOOL.ARGUMENTS " _ $Parameter(..#REMOVE, "LOCALREASON"), "removeclient on a local owner is refused with the published sentence")
    Do $$$AssertEquals(..Listed(tB), 1, "and removes nothing")

    Do ..Act("removeprocess", tB, "false", "", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Field(tBody, "action") _ " " _ ..ReadBack(tBody), "200 deleted notFound", "removeprocess answers the deleted event: " _ ..Shown(tBody))
    Do $$$AssertEquals(..Listed(tB) _ ..Listed(tC) _ ..Listed(tDecoy), "011", "it removed P1's locks and left both of P2's, the decoy included")
    Do $$$AssertEquals(..CountOf(tP1), 0, "P1 holds no lock")
}

/// <p>AC2 (DW-1073), AD-2: a holder in an open transaction. The vendor's own <code>DELETE</code> with
/// its check answers 409 and the admin port logs nothing for it; the first removal is answered 409
/// <code>LOCK.INTRANSACTION</code> with the published sentence and the lock stays; the override
/// removes it, and the holder is still in its transaction.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.LockPort.Invoke</method> send
/// <code>checkTxn</code> 0 always -- the first removal succeeds and this goes red.</p>
Method TestAnOwnerInATransactionIsRefusedThenOverridden()
{
    Set tHolder = ..Holder("ta", 1, 1)
    If tHolder = "" Quit
    Set tId = ..IdOf(tHolder, 1)
    ; Through the shipped port with its log recorded rather than written, on an id this listing holds.
    Kill tQuery
    Set tQuery("id") = tId
    Set tQuery("checkTxn") = 1
    Do ##class(OcuPilot.Test.X509LogPort).Taken()
    Set tSC = ##class(OcuPilot.Test.X509LogPort).Invoke("Lock", "DELETE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ " " _ +$Get(tHttp), "1 409", "the vendor's own DELETE answers 409 while the owner is in a transaction")
    Do $$$AssertEquals(##class(OcuPilot.Test.X509LogPort).Taken(), "", "and the port logs nothing for it (AD-2)")
    Do ..Act("remove", tId, "false", "", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..Field(tBody, "reason"), "409 " _ ##class(OcuPilot.Api.LockError).#INTRANSACTION _ " " _ ##class(OcuPilot.Api.LockError).#REASONINTRANSACTION, "the vendor's in-transaction check refuses it with the published sentence: " _ ..Shown(tBody))
    Do $$$AssertEquals(..Listed(tId), 1, "and the lock stays")
    Do ..Act("remove", tId, "true", "", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..ReadBack(tBody), "200 notFound", "the override removes it: " _ ..Shown(tBody))
    Do $$$AssertEquals(..Listed(tId), 0, "and it is gone")
    Do $$$AssertEquals(..TLevelAfterBeat(tHolder), 1, "while the holder is still in its transaction")
}

/// <p>AC2, AC6, AD-15, AD-58: the agent's un-overridden proposal mints with the lock as a removed row,
/// and its Confirm is answered 409 with the published sentence and removes nothing; an overriding
/// proposal is destructive with the <code>LOCK.INTRANSACTION</code> consequence, and its Confirm
/// removes the lock, reads back <code>notFound</code>, lands the marker and names the lock's
/// deleted triple.</p>
Method TestTheAgentsConfirmWarnsThenOverrides()
{
    Set tHolder = ..Holder("tb", 1, 1)
    If tHolder = "" Quit
    Set tId = ..IdOf(tHolder, 1)
    Set tSC = ..Mint(..#REMOVE, $Username, tId, 0, .tProposal, .tTurn)
    Do $$$AssertStatusOK(tSC, "the un-overridden removal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tRemoved = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("removed") Set tRemoved = tRemoved _ $ListBuild(tRow.%Get("field"))
    }
    Do $$$AssertEquals($ListToString(tRemoved), "^" _ ..#PROBEGLOBAL _ "(""tb"",1)", "the card lists the lock as removed")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Api.LockError).#INTRANSACTION, "its Confirm is answered 409 LOCK.INTRANSACTION")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode($Get(tCode)), ##class(OcuPilot.Api.LockError).#REASONINTRANSACTION, "whose sentence is the published one")
    Do $$$AssertEquals(..Listed(tId), 1, "and removes nothing")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Set tSC = ..Mint(..#REMOVE, $Username, tId, 1, .tProposal, .tTurn)
    Do $$$AssertStatusOK(tSC, "the overriding removal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals(+$Get(tValues("destructive")) _ "|" _ $Get(tValues("consequence")), "1|" _ ##class(OcuPilot.Api.LockError).#INTRANSACTION, "destructive, carrying the in-transaction consequence")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Parse($Get(tValues("targetRef")), .tType, .tScope, .tRefId)
    Do $$$AssertEquals(tType _ "/" _ tScope _ "/" _ tRefId, "lock/instance/" _ tId, "naming the lock's own triple")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "its Confirm removes the lock: " _ $Get(tCode))
    Do $$$AssertEquals(..Field($Get(tResult), "action") _ " " _ ..ReadBack($Get(tResult)), "deleted notFound", "publishing deleted, with a read-back that finds it gone")
    Do $$$AssertEquals(..Listed(tId), 0, "and it is gone")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurn, .tLedger), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tLedger("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed on it")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC6, AD-6, AD-48: an owner-scope proposal fingerprints the enumerated set, so a lock the owner
/// takes after the mint refuses the Confirm with <code>PROPOSAL.TARGETCHANGED</code> and nothing is
/// removed. The new lock is under another first subscript, so the target keeps its own
/// <code>DeleteID</code> and only the set moves.</p>
/// <p>Mutation (Rule 19): drop <code>DeleteIDs</code> from
/// <parameter>OcuPilot.Screen.Tool.LockRemoveProcess.FINGERPRINTSUBJECT</parameter> -- the Confirm
/// removes the set and this goes red.</p>
Method TestAnOwnerThatTookALockSinceTheMintRefusesTheConfirm()
{
    Set tHolder = ..Holder("tc", 1, 0)
    If tHolder = "" Quit
    Set tId = ..IdOf(tHolder, 1)
    Set tSC = ..Mint(..#REMOVEPROCESS, $Username, tId, 0, .tProposal, .tTurn)
    Do $$$AssertStatusOK(tSC, "the owner-scope removal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set ^IRIS.Temp.OcuProbeLock1612(tHolder, "take") = 1
    Set tDeadline = $ZHorolog + 10
    While (..CountOf(tHolder) < 2) && ($ZHorolog < tDeadline) {
        Hang 0.1
    }
    Do $$$AssertEquals(..CountOf(tHolder), 2, "the owner took a second lock")
    Do $$$AssertEquals(..Listed(tId), 1, "and the target kept its own DeleteID, so only the enumerated set moved")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($Get(tCode), $Parameter("OcuPilot.Kernel.Proposal.Write", "TARGETCHANGED"), "the Confirm is refused as a moved target")
    Do $$$AssertEquals(..CountOf(tHolder), 2, "and nothing is removed")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC5, AD-8: a principal holding the Locks screen's two pairs reads the list, and is refused
/// naming <code>%DB_IRISSYS:WRITE</code> on the route, at the agent's dispatch and at Confirm, with
/// the lock still listed; a principal holding that pair too removes it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.LockRemove.PrivilegePairs</method> answer
/// the screen's pairs alone -- the refusals no longer name the pair and this goes red.</p>
Method TestAPrincipalWithoutTheWritePairIsRefusedByName()
{
    Set tHolder = ..Holder("pa", 1, 0)
    If tHolder = "" Quit
    Set tId = ..IdOf(tHolder, 1)
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/osmgmt.locks/read?maxRows=5", ..#READERUSER, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the principal reads the list")
    Do ..Act("remove", tId, "false", ..#READERUSER, ..PreparedPassword, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..FailedPair(tBody), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:WRITE", "its route removal is refused naming the pair")

    ; The agent's dispatch asks the registry's pairs of the tool against the caller's grants before
    ; the tool runs; the principal lacks the one the tool adds.
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(..#REMOVE, "TOOLNAME"), .tTool)
    Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)
    Do $$$AssertEquals(tResolved _ " " _ ##class(OcuPilot.Kernel.Proposal.Operation).MissingPair(..#READERUSER, tPairs, ""), "1 %DB_IRISSYS:WRITE", "its agent's call is refused at dispatch naming the pair")

    Set tSC = ..Mint(..#REMOVE, ..#READERUSER, tId, 0, .tProposal, .tMintTurn)
    Do $$$AssertStatusOK(tSC, "a proposal is minted for the principal: " _ $System.Status.GetErrorText(tSC))
    If $$$ISOK(tSC) {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", ..#READERUSER, .tResult, .tHttp, .tCode, .tDetail)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tCode) _ " " _ ..FailedPair({"detail": ($Get(tDetail))}), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:WRITE", "and its Confirm is refused naming the pair")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tMintTurn)
    }
    Do $$$AssertEquals(..Listed(tId), 1, "the lock is still listed")

    Do ..Act("remove", tId, "false", ..#WRITERUSER, ..PreparedPassword, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..ReadBack(tBody), "200 notFound", "a principal holding the pair removes it: " _ ..Shown(tBody))
    Do $$$AssertEquals(..Listed(tId), 0, "and it is gone")
}

/// <p>The crafted-id row: a <code>DeleteID</code> naming a live holder's pid with slot pieces no lock
/// carries is answered 404 on the route and refused at the mint as not present, and the holder's own
/// lock stays. The port never sends it (<class>OcuPilot.Port.LockPort</class> sends only an id its
/// fresh listing holds).</p>
Method TestACraftedIdIsAnsweredNotFound()
{
    Set tHolder = ..Holder("ca", 1, 0)
    If tHolder = "" Quit
    Set tId = ..IdOf(tHolder, 1)
    Set tCrafted = "1,1,P" _ tHolder _ ","
    Do $$$AssertEquals(..Listed(tCrafted), 0, "no lock carries the crafted id")
    Do ..Act("remove", tCrafted, "false", "", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "the route answers 404")
    Set tSC = ..Mint(..#REMOVE, $Username, tCrafted, 0, .tProposal, .tTurn, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the mint refuses it")
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ ..Code($Get(tFault)) _ " " _ ..Problem($Get(tFault)), "400 TOOL.ARGUMENTS '" _ tCrafted _ "' is not present on this instance", "as not present")
    Do $$$AssertEquals(..Listed(tId), 1, "and the holder's own lock stays")
}

/// <p>AC7, AD-10: a lock on one of OcuPilot's own globals is refused
/// <code>PROHIBITED.OCUPILOTLOCK</code> alone on the route, among its owner's set on the route, and at
/// the agent's Confirm, and nothing is removed.</p>
/// <p>Mutation (Rule 19): skip the <code>lock</code> branch in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -- the removals go through and this
/// goes red.</p>
Method TestOcuPilotsOwnLockIsRefusedOnBothCallers()
{
    Set tCode = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "OCUPILOTLOCK")
    Set tOwn = ..Holder("oa", 1, 0, ..#OWNGLOBAL)
    If tOwn = "" Quit
    Set tId = ..IdOf(tOwn, 1)
    Do ..Act("remove", tId, "false", "", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody), "403 " _ tCode, "the lock alone is refused on the route")
    Do ..Act("removeprocess", tId, "false", "", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody), "403 " _ tCode, "and in its owner's set")
    Set tSC = ..Mint(..#REMOVE, $Username, tId, 0, .tProposal, .tTurn)
    Do $$$AssertStatusOK(tSC, "the agent's removal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISOK(tSC) {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tConfirmCode, .tDetail)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tConfirmCode), "403 " _ tCode, "and its Confirm is refused")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Do $$$AssertEquals(..Listed(tId), 1, "and the lock stays")
}

/// <p>AC6, AD-15, AD-53: the vendor records each removal as <code>%System/%System/ConfigurationChange</code>
/// "Delete lock &lt;full reference&gt;" under the caller, the reference carrying its database's
/// extended prefix.</p>
Method TestTheVendorAuditsARemovalUnderTheCaller()
{
    Set tHolder = ..Holder("au", 1, 0)
    If tHolder = "" Quit
    Set tId = ..IdOf(tHolder, 1)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do ..Act("remove", tId, "false", ..#WRITERUSER, ..PreparedPassword, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the removal is made: " _ ..Shown(tBody))
    Set tWanted = ..#PROBEGLOBAL _ "(""au"",1)"
    Set tFound = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Description, Username FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = ? AND %NOINDEX EventType = ? AND %NOINDEX Event = ?", tSince, "%System", "%System", "ConfigurationChange")
        While (tRS.%SQLCODE >= 0) && tRS.%Next() {
            Set tDescription = tRS.%Get("Description")
            If ($Extract(tDescription, 1, 13) = "Delete lock ^") && ($Extract(tDescription, *-$Length(tWanted) + 1, *) = tWanted) Set tFound = tRS.%Get("Username")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Do $$$AssertEquals(tFound, ..#WRITERUSER, "the vendor recorded 'Delete lock' of the full reference ending " _ tWanted _ " under the caller")
}

/// <p>Start a holder of <var>pCount</var> locks on <var>pGlobal</var> under tag <var>pTag</var>, and
/// of <var>pDecoy</var>'s one more where given, inside a transaction when <var>pInTxn</var> is true,
/// record it for teardown, and answer its pid, or <code>""</code> with a failed assertion.</p>
Method Holder(pTag As %String, pCount As %Integer, pInTxn As %Boolean, pGlobal As %String = {..#PROBEGLOBAL}, pDecoy As %String = "") As %String
{
    Set tPid = ..StartHolder(pTag, pCount, pInTxn, pGlobal, pDecoy)
    If tPid '= "" Set ..PreparedHolders = ..PreparedHolders _ $ListBuild(tPid)
    Do $$$AssertTrue(tPid '= "", "a holder of " _ pCount _ " lock(s) on ^" _ pGlobal _ "(""" _ pTag _ """) started")
    Quit tPid
}

/// <p><code>JOB</code> a holder (<method>Hold</method>) of <var>pCount</var> locks
/// <code>^&lt;pGlobal&gt;(pTag, 1..pCount)</code>, and of <code>^&lt;pGlobal&gt;(pTag, pDecoy)</code>
/// where <var>pDecoy</var> is given, in an open transaction when <var>pInTxn</var> is true, and answer
/// its pid once the lock table lists every one, or <code>""</code>. The browser spec calls it too.
/// <var>pTag</var> is letters and digits, and <var>pDecoy</var> an owner key between commas.</p>
ClassMethod StartHolder(pTag As %String, pCount As %Integer = 1, pInTxn As %Boolean = 0, pGlobal As %String = {..#PROBEGLOBAL}, pDecoy As %String = "") As %String
{
    If '$Match(pTag, "^[A-Za-z0-9]{1,20}$") || '$Match(pGlobal, "^[A-Za-z][A-Za-z0-9]{0,30}$") || (pCount < 1) || (pCount > 20) Quit ""
    If (pDecoy '= "") && '$Match(pDecoy, "^,[PC][0-9]{1,10},$") Quit ""
    Set tWanted = pCount + (pDecoy '= "")
    Set tPid = ""
    Try {
        Job ##class(OcuPilot.Test.LockRemoveLive).Hold(pTag, pCount, ''pInTxn, pGlobal, ..#HOLDSECONDS, pDecoy)
        Set tPid = $ZChild
        If 'tPid Set tPid = ""
        If tPid = "" Quit
        Set tDeadline = $ZHorolog + 20
        While (..CountOf(tPid) < tWanted) && ($ZHorolog < tDeadline) {
            Hang 0.1
        }
        If ..CountOf(tPid) < tWanted {
            Do ..StopHolder(tPid)
            Set tPid = ""
        }
    } Catch ex {
        Set tPid = ""
    }
    Quit tPid
}

/// <p>The holder's own body: take the locks, then beat every quarter second -- recording its
/// <code>$TLevel</code> under <code>^IRIS.Temp.OcuProbeLock1612($Job)</code> and taking one more lock,
/// <code>^&lt;pGlobal&gt;(pTag_"t", 99)</code>, when asked -- until <var>pSeconds</var>, at most
/// <parameter>HOLDSECONDS</parameter>, have passed.</p>
/// <p><b>Caller contract:</b> <code>JOB</code>ed by <method>StartHolder</method> alone. It ends on its
/// own, so a run that aborted cannot leave it holding for ever; <method>StopHolder</method> is the
/// ordinary end, and a transaction it holds is rolled back with it.</p>
ClassMethod Hold(pTag As %String, pCount As %Integer, pInTxn As %Boolean, pGlobal As %String, pSeconds As %Integer, pDecoy As %String = "")
{
    Try {
        Set tSeconds = $Select(pSeconds > ..#HOLDSECONDS: ..#HOLDSECONDS, pSeconds < 1: 1, 1: pSeconds)
        If pInTxn TStart
        For tI = 1:1:pCount {
            Set tName = "^" _ pGlobal _ "(""" _ pTag _ """," _ tI _ ")"
            Lock +@tName:5
        }
        If pDecoy '= "" {
            Set tName = "^" _ pGlobal _ "(""" _ pTag _ """,""" _ pDecoy _ """)"
            Lock +@tName:5
        }
        Set tEnd = $ZHorolog + tSeconds
        Set tBeat = 0
        While $ZHorolog < tEnd {
            Set tBeat = tBeat + 1
            Set ^IRIS.Temp.OcuProbeLock1612($Job) = $TLevel _ "," _ tBeat
            If $Get(^IRIS.Temp.OcuProbeLock1612($Job, "take")) '= "" {
                Kill ^IRIS.Temp.OcuProbeLock1612($Job, "take")
                ; Under another first subscript: a lock the owner takes beside another under the same
                ; one gives that other lock a new DeleteID (measured on this build).
                Set tName = "^" _ pGlobal _ "(""" _ pTag _ "t"",99)"
                Lock +@tName:5
            }
            Hang 0.25
        }
    } Catch ex {
    }
    Try {
        Kill ^IRIS.Temp.OcuProbeLock1612($Job)
        If $TLevel TRollback
    } Catch ex {
    }
    Quit
}

/// <p>End holder <var>pPid</var> and wait for the instance to stop reporting it, then forget its beat.
/// Nothing here touches a process this class did not start.</p>
ClassMethod StopHolder(pPid As %String)
{
    If '$Match(pPid, "^[1-9][0-9]*$") Quit
    Set tOrigNS = $NAMESPACE
    Try {
        If $Data(^$JOB(pPid)) {
            Set $NAMESPACE = "%SYS"
            Set tProcess = ##class(SYS.Process).%OpenId(pPid)
            If $IsObject(tProcess) Do tProcess.Terminate()
            Set tProcess = ""
            Set $NAMESPACE = tOrigNS
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Set tDeadline = $ZHorolog + 10
    While $Data(^$JOB(pPid)) && ($ZHorolog < tDeadline) {
        Hang 0.1
    }
    Kill ^IRIS.Temp.OcuProbeLock1612(pPid)
}

/// <p>End every process the lock table lists holding a probe lock: only this class's holders take
/// locks on <parameter>PROBEGLOBAL</parameter> and <parameter>OWNGLOBAL</parameter>.</p>
ClassMethod StopProbeHolders()
{
    Set tRows = ..ProbeRows()
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOwner = $Piece(tRow.%Get("DeleteID"), ",", 3)
        If $Extract(tOwner) = "P" Do ..StopHolder($Extract(tOwner, 2, *))
    }
}

/// <p>The lock rows on either probe global, from the vendor's own list; <var>pReadable</var> is 0 when
/// either list could not be read.</p>
ClassMethod ProbeRows(Output pReadable As %Boolean) As %DynamicArray
{
    Set pReadable = 1
    Set tFound = []
    For tGlobal = ..#PROBEGLOBAL, ..#OWNGLOBAL {
        Kill tQuery
        Set tQuery("filter") = tGlobal
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Lock", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        If $$$ISERR(tSC) || '$IsObject($Get(tRows)) {
            Set pReadable = 0
            Continue
        }
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get("Reference") [ ("^" _ tGlobal _ "(") Do tFound.%Push(tRow)
        }
    }
    Quit tFound
}

/// <p>How many probe locks the lock table lists, or <code>-1</code> when it cannot be read.</p>
ClassMethod ProbeLockCount() As %Integer
{
    Set tRows = ..ProbeRows(.tReadable)
    Quit $Select(tReadable: tRows.%Size(), 1: -1)
}

/// <p>The probe lock rows process <var>pPid</var> holds, in reference order; <var>pReadable</var> is 0
/// when the list could not be read.</p>
ClassMethod RowsOf(pPid As %String, Output pReadable As %Boolean) As %DynamicArray
{
    Set tRows = ..ProbeRows(.pReadable)
    Kill tByReference
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Piece(tRow.%Get("DeleteID"), ",", 3) = ("P" _ pPid) Set tByReference(tRow.%Get("Reference")) = tRow
    }
    Set tOwn = []
    Set tReference = ""
    For {
        Set tReference = $Order(tByReference(tReference), 1, tRow)
        If tReference = "" Quit
        Do tOwn.%Push(tRow)
    }
    Quit tOwn
}

/// <p>How many probe locks process <var>pPid</var> holds, or <code>-1</code> when the list cannot be
/// read.</p>
ClassMethod CountOf(pPid As %String) As %Integer
{
    Set tRows = ..RowsOf(pPid, .tReadable)
    Quit $Select(tReadable: tRows.%Size(), 1: -1)
}

/// <p>The <code>DeleteID</code> of process <var>pPid</var>'s <var>pIndex</var>th probe lock, in
/// reference order, or <code>""</code>.</p>
ClassMethod IdOf(pPid As %String, pIndex As %Integer) As %String
{
    Set tRow = ..RowsOf(pPid).%Get(pIndex - 1)
    Quit $Select($IsObject(tRow): tRow.%Get("DeleteID"), 1: "")
}

/// <p>Whether the lock table lists <var>pId</var> exactly: 1 or 0, or <code>-1</code> when the list
/// cannot be read.</p>
ClassMethod Listed(pId As %String) As %Integer
{
    Set tRows = ..ProbeRows(.tReadable)
    If 'tReadable Quit -1
    Set tIterator = tRows.%GetIterator()
    Set tListed = 0
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("DeleteID") = pId Set tListed = 1
    }
    Quit tListed
}

/// <p>Holder <var>pPid</var>'s <code>$TLevel</code> from a beat recorded after this call started, or
/// <code>-1</code> when none lands within five seconds.</p>
ClassMethod TLevelAfterBeat(pPid As %String) As %Integer
{
    Set tStart = +$Piece($Get(^IRIS.Temp.OcuProbeLock1612(pPid)), ",", 2)
    Set tDeadline = $ZHorolog + 5
    While ($ZHorolog < tDeadline) {
        Set tNow = $Get(^IRIS.Temp.OcuProbeLock1612(pPid))
        If +$Piece(tNow, ",", 2) > tStart Quit
        Hang 0.1
    }
    If +$Piece($Get(^IRIS.Temp.OcuProbeLock1612(pPid)), ",", 2) <= tStart Quit -1
    Quit +$Piece(^IRIS.Temp.OcuProbeLock1612(pPid), ",", 1)
}

/// <p>Mint <var>pToolClass</var>'s proposal for <var>pUser</var> over lock <var>pId</var>, with
/// <code>RemoveInTransaction</code> <var>pOverride</var>, on a seeded completed turn.</p>
Method Mint(pToolClass As %String, pUser As %String, pId As %String, pOverride As %Boolean, Output pProposal As %DynamicObject, Output pTurn As %String, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pProposal = ""
    Set pTurn = ""
    Set pHttp = ""
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .pTurn)
    If $$$ISERR(tSC) Quit tSC
    Set tArgs = {}
    Do tArgs.%Set("DeleteID", pId, "string")
    Do tArgs.%Set("RemoveInTransaction", ''pOverride, "boolean")
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#SCREEN, $Parameter(pToolClass, "TOOLNAME"), pUser, "", pTurn, tArgs, ..#LIMITS, .pProposal, .pHttp, .pFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pId, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
}

/// <p>One Locks action over the route as <var>pUser</var>, or as the test account when
/// <var>pUser</var> is empty, with <code>RemoveInTransaction</code> <var>pOverride</var>, answering the
/// HTTP status and the parsed envelope.</p>
Method Act(pAction As %String, pId As %String, pOverride As %String, pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pBody) As %Status
{
    Set pBody = ""
    If pUser = "" {
        Set pUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        Set pPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    }
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    Do tRequest.%Set("values", {"RemoveInTransaction": (pOverride)})
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/osmgmt.locks/action", pUser, pPassword, .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
    Quit tSC
}

/// <p>An envelope's or an answer's member <var>pName</var>, or <code>""</code>.</p>
ClassMethod Field(pBody, pName As %String) As %String
{
    If '$IsObject(pBody) Quit ""
    Quit pBody.%Get(pName)
}

/// <p>The code an envelope <var>pBody</var> carries, or <code>""</code>.</p>
ClassMethod Code(pBody) As %String
{
    Quit ..Field(pBody, "code")
}

/// <p>An answer's read-back verdict, or <code>""</code>.</p>
ClassMethod ReadBack(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("readBack")) Quit ""
    Quit pBody.%Get("readBack").%Get("verdict")
}

/// <p>The failed pair an envelope <var>pBody</var>'s detail names, or <code>""</code>.</p>
ClassMethod FailedPair(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) Quit ""
    Quit pBody.%Get("detail").%Get("failedPair")
}

/// <p>The problem an envelope <var>pBody</var>'s detail names, or <code>""</code>.</p>
ClassMethod Problem(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) Quit ""
    Quit pBody.%Get("detail").%Get("problem")
}

/// <p><var>pBody</var> as text, for an assertion's message.</p>
ClassMethod Shown(pBody) As %String
{
    Quit $Select($IsObject(pBody): pBody.%ToJSON(), 1: $Get(pBody))
}

/// <p>Create the two throwaway roles and the accounts that hold them, then read the grants back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        For tCase = $ListBuild(..#READERUSER, ..#READERROLE, tCode _ ",%DB_IRISSYS:R,%Admin_Operate:U", 0), $ListBuild(..#WRITERUSER, ..#WRITERROLE, tCode _ ",%DB_IRISSYS:RW,%Admin_Operate:U", 1) {
            Set tUser = $List(tCase, 1)
            Set tRole = $List(tCase, 2)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the lock removal gate (throwaway)", $List(tCase, 3), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot lock removal test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.LockRemoveLive; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
            If ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Operate", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "READ") '= 1) || (($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "WRITE") = 1) '= $List(tCase, 4)) {
                Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal " _ tUser _ "'s grants did not read back as declared")
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
