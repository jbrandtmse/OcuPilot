/// <p>Test-only helper for Story 18.30's suites: the probe Doc DB application records, the probe resource they name
/// (<parameter>RESOURCE</parameter>, made in <code>%SYS</code>), the instance's record list as one JSON text
/// (<method>Facts</method>), the agent's mint through a tool's own class (<method>Mint</method>) and a confirm run as
/// a real principal in a child process (<method>RunAs</method>). It holds no assertions.</p>
/// <p><b>Only <parameter>PREFIX</parameter> is ever touched.</b> A record or resource is named from it, in any case,
/// and each is removed by exact namespace and name. Records are created and deleted through the real admin port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DocDbAppProbe Extends %RegisteredObject
{

/// <p>What every probe record and resource name begins with, in any case.</p>
Parameter PREFIX = "OcuProbe1830";

/// <p>The user resource the probe records name when a test needs a listed one. <method>EnsureResource</method> creates
/// it and <method>RemoveAll</method> removes it.</p>
Parameter RESOURCE = "OcuProbe1830Res";

Parameter ENDPOINT = "DocDB";

Parameter PORT = "OcuPilot.Port.DocDbAppPort";

/// <p>A probe name: <parameter>PREFIX</parameter> and <var>pSuffix</var>.</p>
ClassMethod Name(pSuffix As %String) As %String
{
    Quit ..#PREFIX _ pSuffix
}

/// <p>Whether <var>pName</var> begins with <parameter>PREFIX</parameter>, in any case.</p>
ClassMethod IsProbe(pName As %String) As %Boolean
{
    Quit $ZConvert($Extract(pName, 1, $Length(..#PREFIX)), "L") = $ZConvert(..#PREFIX, "L")
}

/// <p>The composite id of <var>pNamespace</var> and <var>pName</var>.</p>
ClassMethod Id(pNamespace As %String, pName As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pNamespace, pName))
}

/// <p><var>pId</var> as the path segment a request names it by, percent-encoded once (AD-13).</p>
ClassMethod PathId(pId As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).Encode(pId)
}

/// <p><var>pId</var> as one query-string value, percent-encoded once: a query parameter is decoded once by the
/// request, one decode less than <method>PathId</method> answers for a route segment.</p>
ClassMethod QueryId(pId As %String) As %String
{
    Quit $ZConvert($ZConvert(pId, "O", "UTF8"), "O", "URL")
}

/// <p>The user resource <parameter>RESOURCE</parameter> in <code>%SYS</code>, when the instance holds none of that
/// name; a second call changes nothing.</p>
ClassMethod EnsureResource() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Security.Resources).Exists(..#RESOURCE) Set tSC = ##class(Security.Resources).Create(..#RESOURCE, "OcuPilot Doc DB application probe resource", "")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the user resource <parameter>RESOURCE</parameter> from <code>%SYS</code> when the instance holds
/// it.</p>
ClassMethod RemoveResource() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Resources).Exists(..#RESOURCE) Set tSC = ##class(Security.Resources).Delete(..#RESOURCE)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the instance holds <parameter>RESOURCE</parameter>: <code>1</code> or <code>0</code>, and
/// <code>-1</code> when it cannot be read.</p>
ClassMethod HoldsResource() As %Integer
{
    Set tHolds = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tHolds = ''##class(Security.Resources).Exists(..#RESOURCE)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHolds
}

/// <p>Create the probe record <var>pName</var> in <var>pNamespace</var> through the real admin port with
/// <var>pBody</var>, which defaults to a description, enabled and no resource.</p>
ClassMethod Seed(pNamespace As %String, pName As %String, pBody As %DynamicObject = "") As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "only a name beginning " _ ..#PREFIX _ " is written")
    If '$IsObject(pBody) Set pBody = {"Description": "probe", "Enabled": true, "Resource": ""}
    Kill tQuery
    Set tQuery("name") = ..Id(pNamespace, pName)
    Quit $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "PUT", .tQuery, pBody, .tResult, .tHttp, .tFault)
}

/// <p>The record <var>pName</var> of <var>pNamespace</var> as the vendor's <code>GET</code> reads it, or
/// <code>""</code>.</p>
ClassMethod Stored(pNamespace As %String, pName As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("name") = ..Id(pNamespace, pName)
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRead)) Quit ""
    Quit tRead
}

/// <p>The member <var>pField</var> of the record <var>pName</var> of <var>pNamespace</var> as the vendor's
/// <code>GET</code> reads it, as text, or <code>absent</code> when the instance holds no such record.</p>
ClassMethod StoredField(pNamespace As %String, pName As %String, pField As %String) As %String
{
    Set tRead = ..Stored(pNamespace, pName)
    If '$IsObject(tRead) Quit "absent"
    Set tType = tRead.%GetTypeOf(pField)
    Quit $Select(tType = "unassigned": "absent", 1: tRead.%Get(pField))
}

/// <p>The three settings of the record <var>pName</var> of <var>pNamespace</var> as <code>Description|Enabled|Resource</code>,
/// <code>Enabled</code> as 1 or 0, or <code>absent</code> when the instance holds no such record.</p>
ClassMethod Summary(pNamespace As %String, pName As %String) As %String
{
    Set tRead = ..Stored(pNamespace, pName)
    If '$IsObject(tRead) Quit "absent"
    Quit tRead.%Get("Description") _ "|" _ tRead.%Get("Enabled") _ "|" _ tRead.%Get("Resource")
}

/// <p>The instance's record list, as the vendor's <code>LIST</code> answers it, as JSON text: the state a test must
/// leave as it found it.</p>
ClassMethod Facts() As %String
{
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit "unreadable"
    Quit tRows.%ToJSON()
}

/// <p>The probe records the instance lists, as a <class>%List</class> of <code>Namespace|Name</code> exactly as
/// stored.</p>
ClassMethod Names() As %List
{
    Set tNames = ""
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit tNames
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If ..IsProbe(tRow.%Get("Name")) Set tNames = tNames _ $ListBuild(tRow.%Get("Namespace") _ "|" _ tRow.%Get("Name"))
    }
    Quit tNames
}

/// <p>Delete every probe record by exact namespace and name, then the probe resource, then clear the system monitor:
/// the admin port logs a write answered 404 at severity 2, which raises the instance's alert state, and only a clear
/// resets it.</p>
ClassMethod RemoveAll() As %Status
{
    Set tSC = $$$OK
    Set tNames = ..Names()
    For tI = 1:1:$ListLength(tNames) {
        Kill tQuery
        Set tQuery("name") = ..Id($Piece($List(tNames, tI), "|", 1), $Piece($List(tNames, tI), "|", 2, 99))
        Do $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    }
    Set tSC = $$$ADDSC(tSC, ..RemoveResource())
    Do $SYSTEM.Monitor.Clear()
    Quit tSC
}

/// <p>How many probe records and probe resources the instance holds.</p>
ClassMethod Remaining() As %Integer
{
    Quit $ListLength(..Names()) + (..HoldsResource() > 0)
}

/// <p>Mint the proposal for the tool <var>pToolClass</var> over <var>pArgs</var> through the tool's own mint class, as
/// the agent's call does, naming the target <var>pName</var>. <var>pProblem</var> is the refusal's problem or
/// code.</p>
ClassMethod Mint(pToolClass As %String, pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pProblem As %String, pUser As %String = {$Username}) As %Status
{
    Set pProposal = ""
    Set pHttp = 0
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod($ClassMethod(pToolClass, "MintClass"), "Mint", $Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), pUser, "", tTurnKey, pArgs, "OcuPilot.Kernel.Agent.Limits", .tResult, .pHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pName, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
    If $IsObject($Get(tResult)) Set pProposal = tResult
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set pProblem = tFault.%Get("detail").%Get("problem")
    If $IsObject($Get(tFault)) && (pProblem = "") Set pProblem = tFault.%Get("code")
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal: " _ pHttp _ " " _ pProblem)
    Quit $$$OK
}

/// <p>Run the JSON array <var>pPlan</var> as the probe account <var>pUser</var> in a child process and answer
/// <code>{username, loggedIn, steps}</code>, or an object carrying <code>error</code>. A step is <code>{kind:
/// "confirm", proposalId}</code>, whose answer is <code>{http, code, failedPair}</code> of the shipped confirm
/// reaching the real port, or <code>{kind: "entry", descriptor}</code>, whose answer is the screen's side-bar verdict
/// as <code>{http, failedPair}</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray, pWaitSeconds As %Integer = 120) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.DocDbAppProbe).Child($Job, pUser, tPlan)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", pWaitSeconds)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within " _ pWaitSeconds _ " seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child process <method>RunAs</method> starts: log in as <var>pUser</var>, run each step of <var>pPlan</var>
/// and signal the answers to <var>pParent</var>.</p>
ClassMethod Child(pParent As %Integer, pUser As %String, pPlan As %String)
{
    Set tOut = {}
    Try {
        Set ^||OcuPilotDatabaseWritePort = ..#PORT
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUser), "boolean")
        Do tOut.%Set("username", $Username, "string")
        Set tSteps = []
        Set tIterator = ##class(%DynamicArray).%FromJSON(pPlan).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            Do tSteps.%Push(..Step(tStep))
        }
        Do tOut.%Set("steps", tSteps)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>One step of a plan, answered as <code>{http, code, failedPair}</code>.</p>
ClassMethod Step(pStep As %DynamicObject) As %DynamicObject
{
    Set tLeg = {}
    Set tHttp = 0
    Set tCode = ""
    Set tPair = ""
    If pStep.%Get("kind") = "confirm" {
        Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(pStep.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        If $$$ISOK(tSC) && (tCode = "") Set tHttp = 200
        If $IsObject($Get(tDetail)) Set tPair = tDetail.%Get("failedPair")
    } ElseIf pStep.%Get("kind") = "entry" {
        Set tAllowed = ##class(OcuPilot.Screen.Gate).EvaluateEntry(pStep.%Get("descriptor"), .tFailed)
        Set tHttp = $Select(tAllowed: 200, 1: 403)
        Set tPair = $Get(tFailed)
    }
    Do tLeg.%Set("http", +tHttp, "number")
    Do tLeg.%Set("code", tCode, "string")
    Do tLeg.%Set("failedPair", tPair, "string")
    Quit tLeg
}

}
