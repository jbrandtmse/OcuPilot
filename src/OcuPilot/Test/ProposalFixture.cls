/// <p>Shared instance-state helper for the proposal suite: answer a fresh read with a known object,
/// seed and remove the turns and proposals a test wrote, and force a stored row into the state a
/// refusal is about.</p>
/// <p><b>Every user name a proposal test uses starts with <parameter>PROBEPREFIX</parameter></b>, so
/// teardown finds every turn and every proposal a class left without remembering keys. The suite
/// runs as an account holding <code>%All</code>, so the seeding and ageing writes here go straight
/// to SQL rather than through the stores they are checking.</p>
/// <p><b>It stands in for the admin port.</b> <method>Invoke</method> has
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s signature and answers whatever
/// <method>Arm</method> last stored, or a 404 refusal, so a mint's merge can be driven against a
/// property set no live endpoint happens to carry. <class>OcuPilot.Test.ProposalMint</class> is
/// what points a mint at it.</p>
/// <p><b>It creates no web application and changes nothing on the instance.</b> The one test that
/// needs a real target reads an application the instance already serves; nothing in this suite
/// writes to the instance at all, because minting is the whole of Story 5.1.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ProposalFixture Extends %RegisteredObject
{

/// <p>The prefix every probe user name starts with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeProposal";

/// <p>Answer the next <method>Invoke</method> with the object <var>pJson</var>.</p>
ClassMethod Arm(pJson As %String)
{
    Set ^||OcuPilotProposalFixture("answer") = pJson
    Kill ^||OcuPilotProposalFixture("missing")
    Kill ^||OcuPilotProposalFixture("empty")
    Kill ^||OcuPilotProposalFixture("readfault")
}

/// <p>Answer the next <method>Invoke</method> the way the port answers a target the instance no
/// longer holds: an error status at HTTP 404.</p>
ClassMethod ArmMissing()
{
    Kill ^||OcuPilotProposalFixture("answer")
    Kill ^||OcuPilotProposalFixture("empty")
    Kill ^||OcuPilotProposalFixture("readfault")
    Set ^||OcuPilotProposalFixture("missing") = 1
}

/// <p>Answer the next <method>Invoke</method> with a 200 and no object at all -- the "zero rows"
/// shape a caller must not read as an empty success.</p>
ClassMethod ArmEmpty()
{
    Kill ^||OcuPilotProposalFixture("answer")
    Kill ^||OcuPilotProposalFixture("missing")
    Kill ^||OcuPilotProposalFixture("readfault")
    Set ^||OcuPilotProposalFixture("empty") = 1
}

/// <p>Answer the next reading <method>Invoke</method> the way the port answers a read that failed
/// for a reason other than absence: an error status at <var>pHttpStatus</var>, which is not 404,
/// with a wire-safe fault. <method>ArmMissing</method>'s counterpart on the read path, and
/// <method>ArmWriteFault</method>'s on the reading side.</p>
ClassMethod ArmReadFault(pHttpStatus As %Integer = 500)
{
    Kill ^||OcuPilotProposalFixture("answer")
    Kill ^||OcuPilotProposalFixture("missing")
    Kill ^||OcuPilotProposalFixture("empty")
    Set ^||OcuPilotProposalFixture("readfault") = pHttpStatus
}

/// <p>Answer the next mutating <method>Invoke</method> with the object <var>pJson</var>. A type the
/// fixture holds no armed answer for falls back to the one <method>Arm</method> stored, so a read
/// and a write can be armed together or separately.</p>
ClassMethod ArmWrite(pJson As %String)
{
    Set ^||OcuPilotProposalFixture("write") = pJson
    Kill ^||OcuPilotProposalFixture("writefault")
    Kill ^||OcuPilotProposalFixture("writeexception")
}

/// <p>Answer the next mutating <method>Invoke</method> the way the port answers an endpoint that
/// refused: an error status at <var>pHttpStatus</var> with a wire-safe fault.</p>
ClassMethod ArmWriteFault(pHttpStatus As %Integer = 500)
{
    Set ^||OcuPilotProposalFixture("writefault") = pHttpStatus
    Kill ^||OcuPilotProposalFixture("writeexception")
}

/// <p>Answer the next mutating <method>Invoke</method> by raising an actual ObjectScript
/// exception rather than returning an error status -- the shape a process dying mid-call takes.
/// <method>ArmWriteFault</method> cannot reach this: it <i>returns</i> an error, which
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> handles in its normal
/// <code>$$$ISERR(tWriteSC)</code> branch and finalizes; an exception instead escapes to
/// <method>Transition</method>'s own <code>Catch</code>, which never calls
/// <method>FinalizeConfirmedWrite</method> at all -- the DW-1380 <code>pending</code> trace.</p>
ClassMethod ArmWriteException()
{
    Set ^||OcuPilotProposalFixture("writeexception") = 1
    Kill ^||OcuPilotProposalFixture("writefault")
}

/// <p>The body of the last mutating call, as compact JSON; <code>""</code> when none was made.</p>
ClassMethod LastWriteBody() As %String
{
    Quit $Get(^||OcuPilotProposalFixture("writebody"))
}

/// <p>How many mutating calls were made since the last <method>Clear</method>.</p>
ClassMethod WriteCount() As %Integer
{
    Quit +$Get(^||OcuPilotProposalFixture("writes"))
}

/// <p>Refuse the pair <var>pPair</var> (<code>resource:permission</code>) to
/// <class>OcuPilot.Test.ConfirmFixture</class>'s privilege check, so AD-8's re-check at the write
/// can be driven without changing a single grant on the instance. <code>""</code> refuses
/// none.</p>
ClassMethod DenyPair(pPair As %String = "")
{
    If pPair = "" {
        Kill ^||OcuPilotProposalFixture("deniedpair")
        Quit
    }
    Set ^||OcuPilotProposalFixture("deniedpair") = pPair
}

/// <p>The pair <method>DenyPair</method> last refused, or <code>""</code>.</p>
ClassMethod DeniedPair() As %String
{
    Quit $Get(^||OcuPilotProposalFixture("deniedpair"))
}

/// <p>Answer AD-10's seam with <var>pClass</var> for
/// <class>OcuPilot.Test.ConfirmFixture</class>, so the prohibited-set refusal branch is driven
/// against an armed target. <code>""</code> restores the shipped answer.</p>
ClassMethod ArmProhibited(pClass As %String = "")
{
    If pClass = "" {
        Kill ^||OcuPilotProposalFixture("prohibited")
        Quit
    }
    Set ^||OcuPilotProposalFixture("prohibited") = pClass
}

/// <p>The class <method>ArmProhibited</method> last armed, or <code>""</code>.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit $Get(^||OcuPilotProposalFixture("prohibited"))
}

/// <p>A prohibited set that refuses every write, for
/// <method>OcuPilot.Test.ConfirmFixture.ProhibitedClassName</method> to answer with. The signature
/// is the one <class>OcuPilot.Kernel.Proposal.Confirm</class> calls;
/// <class>OcuPilot.Kernel.Proposal.Prohibited</class> implements the same one.</p>
ClassMethod Prohibits(pToolName As %String, pTargetRef As %String, pPayload As %String, pDiff As %String, Output pProhibits As %Boolean, Output pCode As %String) As %Status
{
    Set pProhibits = 1
    Set pCode = "AGENT.PROHIBITED"
    Quit $$$OK
}

/// <p>Forget every armed answer and every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotProposalFixture
}

/// <p>Set one stored column of proposal <var>pKey</var>, for a test that needs a row in a state no
/// shipped path writes -- a stale definition version among them.</p>
ClassMethod SetDefinition(pKey As %String, pDefinitionId As %String, pDefinitionVersion As %String) As %Status
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Proposal SET DefinitionId = ?, DefinitionVersion = ? WHERE %EXACT(ProposalKey) = ?", pDefinitionId, pDefinitionVersion, pKey)
    If tRS.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "the probe definition could not be set: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
    Quit $$$OK
}

/// <p>How many times <method>Invoke</method> was called since the last <method>Clear</method>.</p>
ClassMethod CallCount() As %Integer
{
    Quit +$Get(^||OcuPilotProposalFixture("calls"))
}

/// <p>The value the last call carried for query parameter <var>pName</var>.</p>
ClassMethod LastQuery(pName As %String) As %String
{
    Quit $Get(^||OcuPilotProposalFixture("query", pName))
}

/// <p>The request type the last call named.</p>
ClassMethod LastType() As %String
{
    Quit $Get(^||OcuPilotProposalFixture("type"))
}

/// <p><method>OcuPilot.Port.AdminPort.Invoke</method>'s signature, answering what was armed.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Do $Increment(^||OcuPilotProposalFixture("calls"))
    Set ^||OcuPilotProposalFixture("endpoint") = pEndpoint
    Set ^||OcuPilotProposalFixture("type") = pType
    Kill ^||OcuPilotProposalFixture("query")
    Set tName = ""
    For {
        Set tName = $Order(pQuery(tName))
        If tName = "" Quit
        Set ^||OcuPilotProposalFixture("query", tName) = pQuery(tName)
    }
    If $ListFind($ListFromString($Parameter("OcuPilot.Port.AdminPort", "MUTATINGTYPES")), pType) {
        ; A mutating call, classified by the port's own list rather than by "not GET" -- LIST, INFO
        ; and the other read suffixes are reads here as they are there. Recorded in full, because
        ; what the port receives is what the story is about (AD-6 -- the stored payload, with only
        ; declared secret values merged in).
        Do $Increment(^||OcuPilotProposalFixture("writes"))
        Set ^||OcuPilotProposalFixture("writebody") = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
        If $Get(^||OcuPilotProposalFixture("writeexception")) {
            ; The call really reached the port -- the increment above already counted it -- and
            ; then raised instead of returning, which is what leaves a caller's ledger row
            ; unfinalized rather than finalized error.
            Throw ##class(%Exception.General).%New("OcuPilot.Test.ProposalFixture: forced write exception")
        }
        If $Data(^||OcuPilotProposalFixture("writefault")) {
            Set pHttpStatus = +^||OcuPilotProposalFixture("writefault")
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "The instance refused that operation")
            Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED)
        }
        Set pHttpStatus = 200
        Set pResult = ##class(%DynamicAbstractObject).%FromJSON($Get(^||OcuPilotProposalFixture("write"), $Get(^||OcuPilotProposalFixture("answer"), "{}")))
        Quit $$$OK
    }
    If $Data(^||OcuPilotProposalFixture("readfault")) {
        Set pHttpStatus = +^||OcuPilotProposalFixture("readfault")
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "The instance refused that read")
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED)
    }
    If $Get(^||OcuPilotProposalFixture("missing")) {
        Set pHttpStatus = 404
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "That item is no longer present on this instance")
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
    }
    Set pHttpStatus = 200
    If $Get(^||OcuPilotProposalFixture("empty")) Quit $$$OK
    Set pResult = ##class(%DynamicAbstractObject).%FromJSON($Get(^||OcuPilotProposalFixture("answer"), "{}"))
    Quit $$$OK
}

/// <p>Seed one proposal row directly, for a test that needs a stored proposal without driving a
/// mint: <var>pValues</var> is <method>OcuPilot.Kernel.State.Propose.GuardedMint</method>'s own
/// argument array, and the new row's id and token come back.</p>
ClassMethod SeedProposal(ByRef pValues, Output pKey As %String, Output pToken As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Propose).GuardedMint(.pValues, "OcuPilot.Kernel.Agent.Limits", .pKey, .pToken, .tExpiresAt)
}

/// <p>Insert a turn row for <var>pUser</var> in <var>pState</var>, as a job that has already
/// finished would have left it, and answer its key in <var>pKey</var>.</p>
ClassMethod SeedTurn(pUser As %String, pState As %String, Output pKey As %String) As %Status
{
    Set pKey = $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.GenCryptRand(16)), "L")
    ; Recorded so a class whose rows name the running account rather than PROBEPREFIX -- every
    ; confirm test, since the claim's privilege re-check is against a real principal -- can still
    ; remove exactly what it wrote (RemoveSeeded).
    Set ^||OcuPilotProposalFixtureTurns(pKey) = ""
    Set tNow = ##class(OcuPilot.Kernel.State.Turn).Timestamp()
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "INSERT INTO OcuPilot_Kernel_State.Turn (TurnKey, UserName, State, QueuedAt, StartedAt, EndedAt, RowVersion) VALUES (?, ?, ?, ?, ?, ?, 1)", pKey, pUser, pState, tNow, tNow, tNow)
    If tRS.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "the probe turn could not be seeded: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
    Quit $$$OK
}

/// <p>Force proposal <var>pKey</var>'s stored <code>Burned</code> flag.</p>
ClassMethod SetBurned(pKey As %String, pBurned As %Boolean) As %Status
{
    Quit ..Update("UPDATE OcuPilot_Kernel_State.Proposal SET Burned = ? WHERE %EXACT(ProposalKey) = ?", ''pBurned, pKey)
}

/// <p>Force proposal <var>pKey</var>'s stored <code>State</code>.</p>
ClassMethod SetState(pKey As %String, pState As %String) As %Status
{
    Quit ..Update("UPDATE OcuPilot_Kernel_State.Proposal SET State = ? WHERE %EXACT(ProposalKey) = ?", pState, pKey)
}

/// <p>Move proposal <var>pKey</var>'s expiry <var>pSeconds</var> into the past, so an expiry test
/// does not wait the window out.</p>
ClassMethod AgeExpiry(pKey As %String, pSeconds As %Integer) As %Status
{
    Set tSeconds = ##class(OcuPilot.Kernel.State.Propose).NowSeconds() - pSeconds
    Set tAged = ##class(OcuPilot.Kernel.State.Turn).Timestamp((tSeconds \ 86400) _ "," _ (tSeconds # 86400))
    Quit ..Update("UPDATE OcuPilot_Kernel_State.Proposal SET ExpiresAt = ? WHERE %EXACT(ProposalKey) = ?", tAged, pKey)
}

/// <p>Move every <b>live</b> proposal of <var>pUser</var> so that it expires <var>pSeconds</var>
/// from now, and answer in <var>pMoved</var> how many rows moved.</p>
/// <p>It exists for the browser leg, which has no other route to the countdown's 1:00 boundary:
/// the window is the instance's own ten minutes (AD-6) and a spec cannot wait nine of them out.
/// Unlike <method>AgeExpiry</method> it takes the user rather than the key, because the browser
/// never learns the id of a proposal a real turn minted.</p>
ClassMethod SetExpiryForUser(pUser As %String, pSeconds As %Integer, Output pMoved As %Integer) As %Status
{
    Set pMoved = 0
    Set tSeconds = ##class(OcuPilot.Kernel.State.Propose).NowSeconds() + pSeconds
    Set tStamp = ##class(OcuPilot.Kernel.State.Turn).Timestamp((tSeconds \ 86400) _ "," _ (tSeconds # 86400))
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Proposal SET ExpiresAt = ? WHERE %EXACT(UserName) = ? AND %EXACT(State) = ?", tStamp, pUser, ##class(OcuPilot.Kernel.State.Propose).#STATELIVE)
    If tRS.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "the probe expiry could not be moved: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
    Set pMoved = +tRS.%ROWCOUNT
    Quit $$$OK
}

/// <p>A stored column of proposal <var>pKey</var>, read by SQL; <code>""</code> for a key no row
/// holds.</p>
ClassMethod Field(pKey As %String, pField As %String) As %String
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT * FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", pKey)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit ""
    Set tValue = tRS.%Get(pField)
    Quit $Select(tValue = $Char(0): "", 1: tValue)
}

/// <p>How many proposal rows name a user starting with <var>pPrefix</var>.</p>
ClassMethod ProposalCount(pPrefix As %String = {..#PROBEPREFIX}) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Proposal WHERE UserName %STARTSWITH ?", pPrefix)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>How many turn rows name a user starting with <var>pPrefix</var>.</p>
ClassMethod TurnCount(pPrefix As %String = {..#PROBEPREFIX}) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Turn WHERE UserName %STARTSWITH ?", pPrefix)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>Remove every probe proposal and every probe turn, and report in <var>pRemaining</var> how
/// many of either survive; <code>-1</code> when that could not be read.</p>
ClassMethod Remove(Output pRemaining As %Integer, pPrefix As %String = {..#PROBEPREFIX}) As %Status
{
    Set pRemaining = -1
    Do ..Clear()
    Set tSC = ..Update("DELETE FROM OcuPilot_Kernel_State.Proposal WHERE UserName %STARTSWITH ?", pPrefix)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Update("DELETE FROM OcuPilot_Kernel_State.Turn WHERE UserName %STARTSWITH ?", pPrefix)
    If $$$ISERR(tSC) Quit tSC
    Set tProposals = ..ProposalCount(pPrefix)
    Set tTurns = ..TurnCount(pPrefix)
    If (tProposals < 0) || (tTurns < 0) Quit $$$ERROR($$$GeneralError, "the probe rows could not be counted")
    Set pRemaining = tProposals + tTurns
    Quit $$$OK
}

/// <p>Remove every proposal minted on a turn <method>SeedTurn</method> seeded in this process, and
/// those turns, and report in <var>pRemaining</var> how many of either survive.</p>
/// <p><method>Remove</method>'s counterpart for rows that name the running account: the probe
/// prefix cannot find them, but the seeded turn key can.</p>
ClassMethod RemoveSeeded(Output pRemaining As %Integer) As %Status
{
    Set pRemaining = 0
    Do ..Clear()
    Set tKey = ""
    For {
        Set tKey = $Order(^||OcuPilotProposalFixtureTurns(tKey))
        If tKey = "" Quit
        Set tSC = ..Update("DELETE FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(TurnKey) = ?", tKey)
        If $$$ISERR(tSC) Quit
        Set tSC = ..Update("DELETE FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = ?", tKey)
        If $$$ISERR(tSC) Quit
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(TurnKey) = ?", tKey)
        If tRS.%Next() Set pRemaining = pRemaining + +tRS.%GetData(1)
    }
    Kill ^||OcuPilotProposalFixtureTurns
    If $Get(tSC, $$$OK) '= $$$OK Quit tSC
    Quit $$$OK
}

/// <p>The web application <method>EnsureWriteTarget</method> creates and
/// <method>RemoveWriteTarget</method> deletes: this suite's own, on the probe prefix, and never
/// one the instance already had.</p>
Parameter WRITETARGET = "/csp/ocupilotprobeconfirm";

/// <p>The Description <method>EnsureWriteTarget</method> stamps its own application with, and the
/// only one <method>RemoveWriteTarget</method> will delete.</p>
Parameter WRITEMARKER = "OcuPilot confirm probe";

/// <p>The environment variable that arms <method>EnsureWriteTarget</method>. Only
/// <file>scripts/ci-throwaway.sh</file> sets it, so the application this fixture creates exists on
/// the container that script builds and nowhere else; absent, empty, or <code>0</code> refuses.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>Create <parameter>WRITETARGET</parameter> as a minimal CSP application in <var>pNamespace</var>,
/// so a confirmed write has something of its own to write to.</p>
/// <p><b>Its own application, never one the instance had.</b> The path carries the probe prefix, and
/// an application that already exists under it is a <b>refusal</b>, not a silent adoption: this
/// fixture must never hand a caller an application it did not make, because
/// <method>RemoveWriteTarget</method> would then delete it. That pairing is why the refusal is an
/// error rather than a no-op.</p>
/// <p><b>Throwaway only, enforced.</b> This changes the instance's web-application table, so it
/// refuses unless <parameter>ARMINGVARIABLE</parameter> reads <code>1</code> -- the same gate
/// <class>OcuPilot.Test.State</class> keeps over the principals it creates, and set only by
/// <file>scripts/ci-throwaway.sh</file>. A doc comment is a barrier only a reader can enforce, and
/// this method is reachable from any session on any instance.</p>
ClassMethod EnsureWriteTarget(pNamespace As %String = {$Namespace}, Output pCreated As %Boolean) As %Status
{
    Set pCreated = 0
    Set tSC = $$$OK
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "EnsureWriteTarget creates a web application on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(..#WRITETARGET) {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ERROR($$$GeneralError, "the probe application " _ ..#WRITETARGET _ " already exists on this instance; this fixture creates its own and will not adopt one it did not make")
            Quit
        }
        Kill tProps
        Set tProps("NameSpace") = pNamespace
        Set tProps("Description") = ..#WRITEMARKER
        Set tProps("Enabled") = 1
        Set tProps("AutheEnabled") = 32
        Set tSC = ##class(Security.Applications).Create(..#WRITETARGET, .tProps)
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        Set pCreated = 1
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><parameter>WRITETARGET</parameter>'s stored property <var>pField</var>, or <code>""</code>
/// when the instance carries no such application. What a confirmed write is read back through --
/// the instance's own record, beside the screen the user would look at.</p>
ClassMethod WriteTargetField(pField As %String = "Enabled") As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(..#WRITETARGET, .tRow) {
            Set tValue = $Property(tRow, pField)
            Set tRow = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tValue = ""
    }
    Quit tValue
}

/// <p>Remove <parameter>WRITETARGET</parameter> again. An application that is not there is not an
/// error.</p>
ClassMethod RemoveWriteTarget() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        ; Only what this fixture made. The marker is the Description EnsureWriteTarget wrote,
        ; because the two calls run in different sessions and no process-private state survives
        ; between them -- and deleting a web application the instance already had is the one
        ; mistake this fixture must not be able to make.
        If ##class(Security.Applications).Exists(..#WRITETARGET, .tRow) {
            If $IsObject(tRow) && (tRow.Description = ..#WRITEMARKER) {
                Set tRow = ""
                Set tSC = ##class(Security.Applications).Delete(..#WRITETARGET)
            } Else {
                Set tRow = ""
                Set tSC = $$$ERROR($$$GeneralError, "the application at " _ ..#WRITETARGET _ " is not this fixture's own, so it was left alone")
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Run <var>pSql</var> with one or two bound values.</p>
ClassMethod Update(pSql As %String, pFirst As %String, pSecond As %String = "") As %Status [ Private ]
{
    If pSecond = "" {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pFirst)
    } Else {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pFirst, pSecond)
    }
    If tRS.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "the probe write failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
    Quit $$$OK
}

}
