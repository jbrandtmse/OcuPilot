/// <p>Shared instance-state helper for the agent-definition suite: create a probe definition,
/// count what is left, and remove every one of them.</p>
/// <p><b>A definition is a row in the <code>OCUPILOT</code> protected database and nothing else
/// removes it</b> -- no install step, no uninstall, no purge task. So each test class owns its own
/// cleanup, and the residue check is an assertion rather than a hope. Every name this class
/// creates starts with <parameter>PROBEPREFIX</parameter>, so teardown can find them all without
/// remembering ids.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests, so
/// that the suite's own classes are the only things the runner enumerates.</p>
Class OcuPilot.Test.AgentFixture Extends %RegisteredObject
{

/// <p>The prefix every probe definition's name starts with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>Create one probe definition through the same guarded path the handler uses, so the default
/// marker settles exactly as it would in production.</p>
/// <p><var>pEnabled</var> and <var>pVerified</var> are written directly, which the API would
/// refuse: only Story 3.4 sets the verification flag, and the enable rule refuses an unverified
/// definition. The state class is the layer under test in
/// <class>OcuPilot.Test.AgentState</class>, so the fixture reaches it directly rather than
/// arranging a flag the API cannot produce yet.</p>
ClassMethod CreateDefinition(pName As %String, pEnabled As %Boolean = 0, pVerified As %Boolean = 0, Output pRow) As %Status
{
    Set pRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set pRow.Name = pName
    Set pRow.Provider = "anthropic"
    Set pRow.Model = "claude-opus-5"
    Set pRow.EndpointUrl = "https://api.anthropic.com/v1/messages"
    Set pRow.CredType = "env"
    Set pRow.EnvVarName = "ANTHROPIC_API_KEY"
    Set pRow.CredentialName = ""
    Set pRow.Enabled = pEnabled
    Set pRow.ConnectionVerified = pVerified
    Quit ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(pRow)
}

/// <p>Set definition <var>pId</var>'s enabled and verified flags directly, through the production
/// update path with the security snapshot taken first so no field appears changed.</p>
/// <p>Written directly for the same reason <method>CreateDefinition</method> writes them: the API
/// refuses an enable while the definition is unverified, and only Story 3.4 sets the verification
/// flag, so a test that needs an enabled, verified definition to edit cannot arrange one over the
/// wire.</p>
ClassMethod SetFlags(pId As %String, pEnabled As %Boolean, pVerified As %Boolean) As %Status
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tRow) Quit $$$ERROR($$$GeneralError, "No agent definition with id " _ pId)
    Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tRow, .tSnapshot)
    Set tRow.Enabled = pEnabled
    Set tRow.ConnectionVerified = pVerified
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tRow, .tSnapshot)
    Set tRow = ""
    Quit tSC
}

/// <p>How many probe definitions the instance still holds, or <code>-1</code> when the count
/// could not be read.</p>
/// <p>Read by SQL rather than through the guarded list, deliberately: the suite runs as an account
/// holding <code>%All</code>, so this reads the stored rows without going through the code it is
/// checking up on.</p>
ClassMethod ProbeCount() As %Integer
{
    Set tResult = -1
    Try {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Agent WHERE Name %STARTSWITH ?", ..#PROBEPREFIX)
        If tRS.%SQLCODE < 0 Quit
        If 'tRS.%Next() Quit
        Set tResult = tRS.%GetData(1)
    } Catch ex {
        Set tResult = -1
    }
    Quit tResult
}

/// <p>Remove every probe definition, and report how many survive in <var>pRemaining</var>.
/// <var>pRemaining</var> is <code>-1</code> when the count could not be read, which is a failure
/// and not a clean instance.</p>
ClassMethod RemoveProbeDefinitions(Output pRemaining As %Integer) As %Status
{
    Set pRemaining = -1
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedList(.tIds)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:+$Get(tIds) {
        Set tOpenSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tIds(tI), .tRow)
        If $$$ISERR(tOpenSC) || '$IsObject(tRow) Continue
        Set tName = tRow.Name
        Set tRow = ""
        ; Folded, because ProbeCount's %STARTSWITH is case-insensitive: a probe row named in
        ; another case would be counted and never removed, so teardown could never pass.
        If $ZConvert($Extract(tName, 1, $Length(..#PROBEPREFIX)), "L") '= $ZConvert(..#PROBEPREFIX, "L") Continue
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(tIds(tI))
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Set pRemaining = ..ProbeCount()
    Quit $$$OK
}

}
