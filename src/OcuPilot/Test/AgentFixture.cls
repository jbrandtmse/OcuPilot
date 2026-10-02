/// <p>Shared instance-state helper for the agent-definition suite: create a probe definition,
/// count what is left, remove every one of them, and set the instance's own definitions aside
/// while a class that needs none runs.</p>
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

/// <p>The first element of an agent definition's data node in the extent every
/// <class>OcuPilot.Kernel.State.Base</class> class shares, which is what tells its rows from the
/// other stores' rows there.</p>
Parameter ROWMARKER = "~OcuPilot.Kernel.State.Agent~";

/// <p>The index subscripts <class>OcuPilot.Kernel.State.Agent</class> declares under the shared
/// index global. No other store declares either.</p>
Parameter AGENTINDEXES = "NameIdx,DefaultIdx";

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

/// <p>Move every agent definition on the instance out of the way, so a class whose methods need an
/// instance holding none can run beside an operator's own, and
/// <method>RestoreDefinitions</method> can put them back exactly.</p>
/// <p>Each Agent row's data node with its subtree, and Agent's two index subtrees, are moved raw,
/// in one transaction, into <code>^OcuPilotTestAgentAside</code>, which
/// <parameter>OcuPilot.Kernel.State.Base.MAPPINGPATTERN</parameter> maps into OcuPilot's
/// protected database. Nothing goes through a guarded delete, so ids and row versions survive and
/// no default marker is rebalanced. A holding global a crashed run left is restored first, and
/// that restore's refusal is this method's.</p>
/// <p><b>Caller contract:</b> once this succeeds, <method>RestoreDefinitions</method> runs on every
/// path out of the class, its setup's own error path included.</p>
ClassMethod SetAsideDefinitions() As %Status
{
    Set tSC = $$$OK
    Set tInTx = 0
    Try {
        If $Data(^OcuPilotTestAgentAside) {
            Set tSC = ..RestoreDefinitions()
            If $$$ISERR(tSC) Quit
        }
        Set tIds = ..AgentRowIds()
        Set tIndexed = 0
        For tI = 1:1:$Length(..#AGENTINDEXES, ",") {
            If $Data(^OcuPilot.Kernel.State.BaseI($Piece(..#AGENTINDEXES, ",", tI))) Set tIndexed = 1
        }
        If (tIds = "") && 'tIndexed Quit
        TSTART
        Set tInTx = 1
        Set tPtr = 0
        While $ListNext(tIds, tPtr, tId) {
            Merge ^OcuPilotTestAgentAside("D", tId) = ^OcuPilot.Kernel.State.BaseD(tId)
            Kill ^OcuPilot.Kernel.State.BaseD(tId)
        }
        For tI = 1:1:$Length(..#AGENTINDEXES, ",") {
            Set tIndex = $Piece(..#AGENTINDEXES, ",", tI)
            Merge ^OcuPilotTestAgentAside("I", tIndex) = ^OcuPilot.Kernel.State.BaseI(tIndex)
            Kill ^OcuPilot.Kernel.State.BaseI(tIndex)
        }
        Set ^OcuPilotTestAgentAside = $ListLength(tIds)
        TCOMMIT
        Set tInTx = 0
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If tInTx {
        TROLLBACK 1
    }
    Quit tSC
}

/// <p>Remove every probe definition, then put back what <method>SetAsideDefinitions</method>
/// moved, byte for byte and under the same ids, and remove the holding global. Nothing set aside
/// is not an error.</p>
/// <p>Refused, with the holding global kept, while any Agent row or Agent index node remains once
/// the probes are gone, or another row holds a held id: merging over either would mix two sets of
/// rows.</p>
ClassMethod RestoreDefinitions() As %Status
{
    Set tSC = $$$OK
    Set tInTx = 0
    Try {
        Set tSC = ..RemoveProbeDefinitions(.tRemaining)
        If $$$ISERR(tSC) Quit
        If '$Data(^OcuPilotTestAgentAside) Quit
        Set tLeft = ""
        Set tIds = ..AgentRowIds()
        If tIds '= "" Set tLeft = tLeft _ " definitions " _ $ListToString(tIds, ",") _ ";"
        For tI = 1:1:$Length(..#AGENTINDEXES, ",") {
            Set tIndex = $Piece(..#AGENTINDEXES, ",", tI)
            If $Data(^OcuPilot.Kernel.State.BaseI(tIndex)) Set tLeft = tLeft _ " index " _ tIndex _ ";"
        }
        Set tId = ""
        For {
            Set tId = $Order(^OcuPilotTestAgentAside("D", tId))
            If tId = "" Quit
            If $Data(^OcuPilot.Kernel.State.BaseD(tId)) Set tLeft = tLeft _ " a row under held id " _ tId _ ";"
        }
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "The agent definitions set aside stay in ^OcuPilotTestAgentAside, because the instance still holds" _ tLeft)
            Quit
        }
        TSTART
        Set tInTx = 1
        Set tId = ""
        For {
            Set tId = $Order(^OcuPilotTestAgentAside("D", tId))
            If tId = "" Quit
            Merge ^OcuPilot.Kernel.State.BaseD(tId) = ^OcuPilotTestAgentAside("D", tId)
        }
        For tI = 1:1:$Length(..#AGENTINDEXES, ",") {
            Set tIndex = $Piece(..#AGENTINDEXES, ",", tI)
            Merge ^OcuPilot.Kernel.State.BaseI(tIndex) = ^OcuPilotTestAgentAside("I", tIndex)
        }
        Kill ^OcuPilotTestAgentAside
        TCOMMIT
        Set tInTx = 0
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If tInTx {
        TROLLBACK 1
    }
    Quit tSC
}

/// <p>The ids of every Agent row in the shared extent, as a list, read from the data nodes
/// themselves.</p>
ClassMethod AgentRowIds() As %List [ Private ]
{
    Set tIds = ""
    Set tId = ""
    For {
        Set tId = $Order(^OcuPilot.Kernel.State.BaseD(tId))
        If tId = "" Quit
        Set tNode = $Get(^OcuPilot.Kernel.State.BaseD(tId))
        If $ListValid(tNode) && ($ListGet(tNode, 1) = ..#ROWMARKER) Set tIds = tIds _ $ListBuild(tId)
    }
    Quit tIds
}

}
