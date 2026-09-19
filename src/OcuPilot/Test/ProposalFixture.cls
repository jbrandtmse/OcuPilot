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
}

/// <p>Answer the next <method>Invoke</method> the way the port answers a target the instance no
/// longer holds: an error status at HTTP 404.</p>
ClassMethod ArmMissing()
{
    Kill ^||OcuPilotProposalFixture("answer")
    Set ^||OcuPilotProposalFixture("missing") = 1
}

/// <p>Answer the next <method>Invoke</method> with a 200 and no object at all -- the "zero rows"
/// shape a caller must not read as an empty success.</p>
ClassMethod ArmEmpty()
{
    Kill ^||OcuPilotProposalFixture("answer")
    Kill ^||OcuPilotProposalFixture("missing")
    Set ^||OcuPilotProposalFixture("empty") = 1
}

/// <p>Forget every armed answer and every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotProposalFixture
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

/// <p>Insert a turn row for <var>pUser</var> in <var>pState</var>, as a job that has already
/// finished would have left it, and answer its key in <var>pKey</var>.</p>
ClassMethod SeedTurn(pUser As %String, pState As %String, Output pKey As %String) As %Status
{
    Set pKey = $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.GenCryptRand(16)), "L")
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
