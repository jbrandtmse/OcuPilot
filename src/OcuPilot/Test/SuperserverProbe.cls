/// <p>Test-only helper for Story 18.25's suites: the probe superservers, the instance's superserver list as
/// one JSON text (<method>Facts</method>), the agent's mint through the tool's own mint class
/// (<method>Mint</method>) and a job whose serving port is read (<method>JobServingPort</method>). It holds no
/// assertions.</p>
/// <p><b>Only 21825 to 21829 is ever written.</b> <method>Seed</method> and <method>RemoveAll</method> refuse any
/// other port, 1972 the system default's and the gateway's among them, so no helper here can cut the throwaway
/// off. They write through the real admin port, never the seam.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SuperserverProbe Extends %RegisteredObject
{

/// <p>The ports a probe superserver may take.</p>
Parameter PORTS = "21825,21826,21827,21828,21829";

/// <p>The composite id of the superserver on <var>pPort</var> bound to <var>pBind</var>.</p>
ClassMethod Id(pPort As %String, pBind As %String = "0.0.0.0") As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pPort, pBind))
}

/// <p><var>pId</var> as one query-string value, percent-encoded once: a query value is decoded once by the web
/// server, where a path segment (<method>OcuPilot.Kernel.EntityId.Encode</method>) is decoded twice.</p>
ClassMethod QueryId(pId As %String) As %String
{
    Quit $ZConvert(pId, "O", "URL")
}

/// <p>Create the probe superserver on <var>pPort</var> through the real admin port with the settings
/// <var>pBody</var> carries, which may be empty. A port outside <parameter>PORTS</parameter> is refused.</p>
ClassMethod Seed(pPort As %String, pBody As %DynamicObject = "") As %Status
{
    If '$IsObject(pBody) Set pBody = {}
    If '$ListFind($ListFromString(..#PORTS), pPort) Quit $$$ERROR($$$GeneralError, "only a port " _ ..#PORTS _ " lists is written")
    Kill tQuery
    Set tQuery("port") = pPort
    Quit ##class(OcuPilot.Port.AdminPort).Invoke("Security.Superserver", "PUT", .tQuery, pBody, .tResult, .tHttp, .tFault)
}

/// <p>The superserver on <var>pPort</var> as the vendor's <code>GET</code> reads it, or <code>""</code>.</p>
ClassMethod Stored(pPort As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("port") = pPort
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Superserver", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRead)) Quit ""
    Quit tRead
}

/// <p>Delete every probe superserver by exact port; a port outside <parameter>PORTS</parameter> is never
/// touched.</p>
ClassMethod RemoveAll() As %Status
{
    Set tSC = $$$OK
    For tI = 1:1:$Length(..#PORTS, ",") {
        Set tPort = $Piece(..#PORTS, ",", tI)
        If '$IsObject(..Stored(tPort)) Continue
        Kill tQuery
        Set tQuery("port") = tPort
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Port.AdminPort).Invoke("Security.Superserver", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault))
    }
    Quit tSC
}

/// <p>How many probe superservers the instance holds.</p>
ClassMethod Remaining() As %Integer
{
    Set tCount = 0
    For tI = 1:1:$Length(..#PORTS, ",") {
        If $IsObject(..Stored($Piece(..#PORTS, ",", tI))) Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The instance's superserver list, as the vendor's <code>LIST</code> answers it, as JSON text: the state a
/// test must leave as it found it.</p>
ClassMethod Facts() As %String
{
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Superserver", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit "unreadable"
    Quit tRows.%ToJSON()
}

/// <p>Mint the proposal for the tool <var>pToolClass</var> over <var>pArgs</var> through the tool's own mint
/// class, which builds the composite id from <code>Port</code> and <code>BindAddress</code>, as the agent's
/// call does. <var>pProblem</var> is the refusal's problem or code.</p>
ClassMethod Mint(pToolClass As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pProblem As %String, pUser As %String = {$Username}) As %Status
{
    Set pProposal = ""
    Set pHttp = 0
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod($ClassMethod(pToolClass, "MintClass"), "Mint", $Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), pUser, "", tTurnKey, pArgs, "OcuPilot.Kernel.Agent.Limits", .tResult, .pHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pArgs.%Get("Port"), $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
    If $IsObject($Get(tResult)) Set pProposal = tResult
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set pProblem = tFault.%Get("detail").%Get("problem")
    If $IsObject($Get(tFault)) && (pProblem = "") Set pProblem = tFault.%Get("code")
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal: " _ pHttp _ " " _ pProblem)
    Quit $$$OK
}

/// <p>The serving port a job reads for itself, as <code>port|</code>: a background process has no TCP principal,
/// so the answer is empty.</p>
ClassMethod JobServingPort() As %String
{
    Kill ^OcuPilotSuperserverProbe
    Job ##class(OcuPilot.Test.SuperserverProbe).StoreServingPort()
    Set tWaited = 0
    While '$Data(^OcuPilotSuperserverProbe) && (tWaited < 100) {
        Hang 0.1
        Set tWaited = tWaited + 1
    }
    Set tAnswer = $Get(^OcuPilotSuperserverProbe, "no answer")
    Kill ^OcuPilotSuperserverProbe
    Quit tAnswer _ "|"
}

/// <p>The job's body: store the serving port this process reads.</p>
ClassMethod StoreServingPort()
{
    Set ^OcuPilotSuperserverProbe = ##class(OcuPilot.Kernel.Proposal.Prohibited).ServingSuperserverPort()
}

}
