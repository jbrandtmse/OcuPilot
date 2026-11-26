/// <p>The child process Story 24.17 Batch 5's suites run: <method>ProbeAs</method> starts <method>Probe</method> in a job of its own, as a real user when one is named and as the job's inheritor
/// otherwise, and answers what it signalled, so the gate and the process's roles are tried as that user and not as the test account, and the read is tried in a background job, which has no web
/// request, as the agent's turn does (AD-7). A probe is <code>legs</code> (the four endpoints through the port class, each answered as <code>{http, code, failedPair}</code>), <code>roles</code>
/// (the System monitor read, with the process's roles, user and namespace before and after) or <code>job</code> (the System monitor read and Most active queues, with whether the process held a web
/// request and whether the vendor's unsaved session was left behind) or <code>hold</code> (the System monitor read, after which the process stays alive until it is sent a message, and is
/// answered with its process id as <code>child</code> in every mode).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. It runs only on a throwaway instance, which sets the arming variable
/// <class>OcuPilot.Test.InteropSystemMonitorCase</class> names.</p>
Class OcuPilot.Test.InteropSystemMonitorChild Extends %RegisteredObject
{

Parameter CASE = "OcuPilot.Test.InteropSystemMonitorCase";

/// <p>The answer of the port's <code>LIST</code> of <var>pEndpoint</var> as <code>{http, code, failedPair, rows, running, queues}</code>.</p>
ClassMethod Leg(pEndpoint As %String, pClass As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tHttp = 0
    Set tFault = ""
    Set tSC = $ClassMethod(pClass, "Invoke", pEndpoint, "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
    Set tLeg = {}
    Do tLeg.%Set("http", +tHttp, "number")
    If $IsObject(tFault) {
        Do tLeg.%Set("code", tFault.%Get("code"))
        If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
    }
    If $IsObject($Get(tResult)) {
        Do tLeg.%Set("rows", tResult.%Size(), "number")
        If (pEndpoint = "SystemMonitor") && (tResult.%Size() > 0) Do tLeg.%Set("running", tResult.%Get(0).EnsProductionsRunning)
        If pEndpoint = "SystemMonitorQueues" {
            Set tNames = ""
            Set tIterator = tResult.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                Set tNames = tNames _ "," _ tRow.%Get("Queue")
            }
            Do tLeg.%Set("queues", tNames _ ",")
        }
    }
    Quit tLeg
}

/// <p>The child process: log in as <var>pUsername</var> when one is named, run the probe <var>pMode</var> through the port class <var>pClass</var>, then signal the answer to process
/// <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pMode As %String, pClass As %String)
{
    Set tOut = {}
    Try {
        Set tVariable = $Parameter(..#CASE, "ARMINGVARIABLE")
        If $System.Util.GetEnviron(tVariable) '= 1 {
            Do tOut.%Set("error", tVariable _ " does not read 1 in the probe process")
            Quit
        }
        If pUsername '= "" Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        If pMode = "legs" {
            For tI = 1:1:4 {
                Set tEndpoint = $Piece($Parameter(..#CASE, "ENDPOINTS"), ",", tI)
                Do tOut.%Set(tEndpoint, ..Leg(tEndpoint, pClass))
            }
        } ElseIf pMode = "roles" {
            Set tBefore = $ROLES
            Set tUser = $USERNAME
            Set tNamespace = $NAMESPACE
            Set tLeg = ..Leg("SystemMonitor", pClass)
            Do tOut.%Set("http", tLeg.http, "number")
            Do tOut.%Set("running", tLeg.%Get("running"))
            Do tOut.%Set("before", tBefore)
            Do tOut.%Set("after", $ROLES)
            Do tOut.%Set("sameUser", (tUser = $USERNAME), "boolean")
            Do tOut.%Set("sameNamespace", (tNamespace = $NAMESPACE), "boolean")
        } ElseIf pMode = "hold" {
            Do tOut.%Set("row", ..Leg("SystemMonitor", pClass))
            Do $System.Event.Signal(pParent, tOut.%ToJSON())
            Set tSignalled = 1
            ; The process stays alive until the parent releases it, so anything the call left held stays held.
            Do $System.Event.WaitMsg("", 120)
        } ElseIf pMode = "job" {
            Do tOut.%Set("hasRequest", ''$IsObject($Get(%request)), "boolean")
            Set tBefore = $ROLES
            Set tNamespace = $NAMESPACE
            Do tOut.%Set("row", ..Leg("SystemMonitor", pClass))
            Do tOut.%Set("queues", ..Leg("SystemMonitorQueues", pClass))
            Do tOut.%Set("sameRoles", (tBefore = $ROLES), "boolean")
            Do tOut.%Set("sameNamespace", (tNamespace = $NAMESPACE), "boolean")
            Do tOut.%Set("sessionLeft", ''$Data(^%cspSession($Parameter(pClass, "METRICSSESSIONID"))), "boolean")
            Do tOut.%Set("requestAfter", ''$IsObject($Get(%request)), "boolean")
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    If '$Get(tSignalled) Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Run <method>Probe</method> as <var>pUser</var> (nobody when empty) in a child process and answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String, pMode As %String = "legs", pClass As %String = "OcuPilot.Port.InteropPort") As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropSystemMonitorChild).Probe($Job, pUser, pMode, pClass)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tChild = $ZChild
        Set tMessage = $System.Event.WaitMsg("", 180)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 180 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
        Do tOut.%Set("child", tChild, "number")
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

}
