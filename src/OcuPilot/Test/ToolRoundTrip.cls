/// <p>Every real tool round-trips through <method>OcuPilot.Screen.Tool.Registry.InvokeTool</method>
/// (Conventions, Tests; AD-36, AD-39): each answers a result conforming to its result schema, or
/// refuses <code>{}</code> with the code it is named for; and a state read asked for one row fetches two ids from its store, answers
/// one row and says it was cut (AD-21, AD-24).</p>
/// <p><b>Throwaway only.</b> The tools run against the instance -- the audit read queues a vendor
/// task -- and the store leg creates probe agent definitions, all removed after each method.</p>
Class OcuPilot.Test.ToolRoundTrip Extends %UnitTest.TestCase
{

Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The live tools that refuse <code>{}</code>, as comma-separated <code>tool:code</code>: the
/// application error tool requires a namespace and a date, and the navigation tool
/// (Story 4.7, <parameter>FULFILMENT</parameter> = <code>client</code>) refuses any call to its
/// own <code>View</code> with <code>NAV.NOTINSTANCE</code> -- <code>InvokeTool</code> reaching it
/// at all is exactly the mis-wiring that code guards against, since
/// <class>OcuPilot.Kernel.Agent.Dispatch</class> never calls it in production.</p>
/// <p>Epic 6's six detail reads join the list at the merge: each names the one row it is about,
/// so an empty argument object has nothing to read. Three refuse at the descriptor's own criterion
/// check (<code>READ.CRITERION</code>) and three at the port's (<code>PORT.VALIDATION</code>).</p>
/// <p>Every write tool refuses <code>{}</code> too, and before any port is touched: a proposal is
/// about one target, so <code>Name</code> is required by its input schema and an empty argument
/// object has nothing to read fresh. That holds for the auditing write as well, whose target is a
/// singleton: the id names nothing the vendor reads, but it is what keys the lock, so the schema
/// still requires it (AD-13, AD-34). It holds for the task resume as well, which admits no field
/// at all and whose schema is therefore the identifying property and the agent's own words
/// (AD-51), and for the two process writes, whose schemas are the pid and those same words. The
/// web-application delete (Story 7.1) is the same shape: it admits no field either, so its schema
/// is the application's name and those words, and so are the two OAuth 2.0 deletes (Story 7.3) and
/// the users delete and password change (Story 7.2), the Task schedule's run, suspend and delete
/// (Story 7.6), the two process terminates (Story 7.8), and the five audit event writes (Story 7.11), whose
/// schemas are the event's name, <code>Enabled</code> for the two updates, and those words.</p>
Parameter REFUSEEMPTY = "logs.applicationerrors.read:TOOL.ARGUMENTS,logs.applicationerrors.delete:TOOL.ARGUMENTS,shell.screen.open:NAV.NOTINSTANCE,osmgmt.databasedetails.read:READ.CRITERION,osmgmt.processdetails.read:READ.CRITERION,tasks.taskdetails.read:READ.CRITERION,osmgmt.databasevolumes.read:PORT.VALIDATION,security.secrets.read:PORT.VALIDATION,webapp.openapi.read:PORT.VALIDATION,webapp.list.update:TOOL.ARGUMENTS,permissions.users.update:TOOL.ARGUMENTS,security.auditing.update:TOOL.ARGUMENTS,tasks.schedule.resume:TOOL.ARGUMENTS,osmgmt.processes.suspend:TOOL.ARGUMENTS,osmgmt.processes.resume:TOOL.ARGUMENTS,webapp.list.create:TOOL.ARGUMENTS,permissions.users.create:TOOL.ARGUMENTS,permissions.roles.create:TOOL.ARGUMENTS,permissions.roles.delete:TOOL.ARGUMENTS,permissions.resources.create:TOOL.ARGUMENTS,permissions.resources.update:TOOL.ARGUMENTS,permissions.resources.delete:TOOL.ARGUMENTS,security.x509.import:TOOL.ARGUMENTS,security.x509.update:TOOL.ARGUMENTS,security.x509.delete:TOOL.ARGUMENTS,security.secrets.create:TOOL.ARGUMENTS,security.secrets.update:TOOL.ARGUMENTS,osmgmt.devices.create:TOOL.ARGUMENTS,osmgmt.devices.update:TOOL.ARGUMENTS,osmgmt.devices.delete:TOOL.ARGUMENTS,webapp.list.delete:TOOL.ARGUMENTS,permissions.users.delete:TOOL.ARGUMENTS,permissions.users.password:TOOL.ARGUMENTS,security.auditsystemevents.update:TOOL.ARGUMENTS,security.audituserevents.update:TOOL.ARGUMENTS,security.auditsystemevents.reset:TOOL.ARGUMENTS,security.audituserevents.reset:TOOL.ARGUMENTS,security.audituserevents.delete:TOOL.ARGUMENTS,security.audituserevents.create:TOOL.ARGUMENTS,security.oauthclients.delete:TOOL.ARGUMENTS,security.oauthserverclients.delete:TOOL.ARGUMENTS,tasks.ondemand.run:TOOL.ARGUMENTS,tasks.schedule.run:TOOL.ARGUMENTS,tasks.schedule.suspend:TOOL.ARGUMENTS,tasks.schedule.delete:TOOL.ARGUMENTS,osmgmt.processes.terminate:TOOL.ARGUMENTS,osmgmt.processes.terminatewitherror:TOOL.ARGUMENTS,permissions.roles.update:TOOL.ARGUMENTS,security.ssl.create:TOOL.ARGUMENTS,security.ssl.update:TOOL.ARGUMENTS,security.ssl.delete:TOOL.ARGUMENTS,security.secrets.delete:TOOL.ARGUMENTS,tasks.schedule.create:TOOL.ARGUMENTS,tasks.schedule.update:TOOL.ARGUMENTS,permissions.services.update:TOOL.ARGUMENTS,security.ldap.update:TOOL.ARGUMENTS";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.StateReadProbe).Clear()
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.StateReadProbe).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining), "the probe definitions are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>Every live tool, called with <code>{}</code> under the row cap, answers a result its result
/// schema admits, except the tools <parameter>REFUSEEMPTY</parameter> names, which refuse
/// <code>{}</code> with the code it gives them.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.Read.View</method> answers every call as an internal
/// failure -> this goes red.</p>
Method TestEveryToolConformsToItsResultSchemaOrAnswersACode()
{
    Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ListTools", .tTools), "the live tools list")
    If '$IsObject(tTools) Quit
    Set tCap = $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS")
    Kill tRefusals
    For tI = 1:1:$Length(..#REFUSEEMPTY, ",") {
        Set tEntry = $Piece(..#REFUSEEMPTY, ",", tI)
        Set tRefusals($Piece(tEntry, ":", 1)) = $Piece(tEntry, ":", 2)
    }
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tSC = $ClassMethod(..#REGISTRY, "InvokeTool", tTool, {}, tCap, .tResult, .tHttp, .tFault)
        If $Data(tRefusals(tTool.name)) {
            Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "1|" _ tRefusals(tTool.name), tTool.name _ ": refuses {} with its named code")
            Continue
        }
        Do $$$AssertStatusOK(tSC, tTool.name _ ": answers a result")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(tHttp _ "|" _ $IsObject(tFault), "200|0", tTool.name _ ": answers 200 and no fault")
        Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ValidateArguments", $ClassMethod(..#REGISTRY, "ResultSchemaOf", tTool), tResult, .tProblem), tTool.name _ ": conforms to its result schema " _ tProblem)
        If tResult.%IsDefined("rows") Do $$$AssertTrue(tResult.rows.%Size() <= tCap, tTool.name _ ": within the row cap")
    }
}

/// <p>SQL bound -- over three probe definitions, the definitions read tool asked for one row answers
/// one row, truncated, from a store that fetched two ids: the executor passed its cap plus one and the
/// store bound it into <code>SELECT TOP ?</code>.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.State.Agent.GuardedScreenRows</method> drops
/// <code>TOP ?</code> -> the fetch count goes red.</p>
Method TestAStateReadFetchesOneRowMoreThanItAnswers()
{
    For tI = 1:1:3 {
        Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "RoundTrip" _ tI), "probe definition " _ tI _ " is created")
    }
    Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "Resolve", "agent.definitions.read", .tTool), "the definitions read tool resolves")
    Do $$$AssertTrue($IsObject(tTool), "to a registered tool")
    If '$IsObject(tTool) Quit
    Set tProbe = {"kind": "read", "class": "OcuPilot.Test.StateReadToolProbe"}
    Do tProbe.%Set("name", tTool.name)
    Do tProbe.%Set("descriptor", tTool.descriptor)
    Set tSC = $ClassMethod(..#REGISTRY, "InvokeTool", tProbe, {"maxRows": 1}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read answers")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%Size() _ "|" _ tResult.truncated, "1|1", "one row, truncated")
    Do $$$AssertEquals(##class(OcuPilot.Test.StateReadProbe).Recorded("maxRows") _ "|" _ ##class(OcuPilot.Test.StateReadProbe).Recorded("fetched"), "2|2", "from a store asked for and fetching two ids")

    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedScreenRows(.tRows, 2)
    Do $$$AssertStatusOK(tSC, "the store reads directly")
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%Size(), 1: -1), 2, "and a bound of two reads two of the three or more")
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedScreenRows(.tAll)
    Do $$$AssertTrue($IsObject(tAll) && (tAll.%Size() >= 3), "while no bound reads every definition")
    Do $$$AssertStatusNotOK(##class(OcuPilot.Kernel.State.Agent).GuardedScreenRows(.tBad, 0), "and a bound of zero is refused")
}

}
