/// <p>The child process Story 24.17 Batch 2's principal legs run: <method>ProbeAs</method> starts <method>Probe</method> as a real user in a job of its own and answers what it signalled, so
/// the gate, the process's roles and the classic page's own query are tried as that user and not as the test account. A probe is <code>legs</code> (the six calls of the two logs through the port,
/// each answered as <code>{http, code, failedPair}</code>), <code>roles</code> (one purge of a log through the port or a seam, with the process's roles, user and namespace before and after) or
/// <code>equality</code> (for each log, whether its list is admitted and whether the classic page's own query prepares).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. It runs only on a throwaway instance, which sets the arming variable <class>OcuPilot.Test.InteropLogPurgeCase</class> names.</p>
Class OcuPilot.Test.InteropLogPurgeChild Extends %RegisteredObject
{

Parameter CASE = "OcuPilot.Test.InteropLogPurgeCase";

/// <p>The six legs of <code>legs</code>, in order, <code>&lt;name&gt;|&lt;log&gt;|&lt;type&gt;</code>, the type being <code>LIST</code>, <code>state</code> or <code>write</code>.</p>
Parameter LEGS = "list|rule|LIST,plist|process|LIST,rstate|rule|state,pstate|process|state,rpurge|rule|write,ppurge|process|write";

/// <p>The statements of the classic pages' own queries (<code>EnsPortal.RuleLog</code> and <code>EnsPortal.BPInstances</code>), which the vendor prepares with the caller's SQL privileges.</p>
Parameter RULEQUERY = "SELECT TOP 1 ID, SessionId, RuleName, IsError, ReturnValue, ''||%EXTERNAL(TimeExecuted) As TimeExecutedStr FROM Ens_Rule.Log ORDER BY ID DESC";

Parameter PROCESSQUERY = "SELECT %ID, %IsCompleted, %ConfigName, %SessionId, %PrimaryRequestHeader, %EXTERNAL(%TimeCreated) As TimeCreatedFull FROM Ens.BusinessProcess";

/// <p>The answer of the port's call of <var>pType</var> of the log <var>pKind</var> in <code>USER</code> as <code>{http, code, failedPair}</code>; a purge keeps 3,650 days.</p>
ClassMethod Leg(pKind As %String, pType As %String, pClass As %String = "OcuPilot.Port.InteropPort") As %DynamicObject
{
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("days") = 3650
    Set tType = $Case(pType, "state": $ClassMethod(..#CASE, "Spec", pKind, "state"), "write": $ClassMethod(..#CASE, "Spec", pKind, "write"), : pType)
    Set tHttp = 0
    Set tFault = ""
    Set tSC = $ClassMethod(pClass, "Invoke", $ClassMethod(..#CASE, "Spec", pKind, "endpoint"), tType, .tQuery, "", .tResult, .tHttp, .tFault)
    Set tLeg = {}
    Do tLeg.%Set("http", +tHttp, "number")
    If $IsObject(tFault) {
        Do tLeg.%Set("code", tFault.%Get("code"))
        If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
    }
    Quit tLeg
}

/// <p>The child process: log in as <var>pUsername</var>, run the probe <var>pMode</var> for the log <var>pKind</var> through the port class <var>pClass</var>, then signal the answer to
/// process <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pMode As %String, pKind As %String, pClass As %String)
{
    Set tOut = {}
    Try {
        Set tVariable = $Parameter(..#CASE, "ARMINGVARIABLE")
        If $System.Util.GetEnviron(tVariable) '= 1 {
            Do tOut.%Set("error", tVariable _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        If pMode = "legs" {
            For tI = 1:1:$Length(..#LEGS, ",") {
                Set tSpec = $Piece(..#LEGS, ",", tI)
                Do tOut.%Set($Piece(tSpec, "|", 1), ..Leg($Piece(tSpec, "|", 2), $Piece(tSpec, "|", 3), pClass))
            }
        } ElseIf pMode = "roles" {
            Set tBefore = $ROLES
            Set tUser = $USERNAME
            Set tNamespace = $NAMESPACE
            Set tLeg = ..Leg(pKind, "write", pClass)
            Do tOut.%Set("http", tLeg.http, "number")
            Do tOut.%Set("before", tBefore)
            Do tOut.%Set("after", $ROLES)
            Do tOut.%Set("sameUser", (tUser = $USERNAME), "boolean")
            Do tOut.%Set("sameNamespace", (tNamespace = $NAMESPACE), "boolean")
        } ElseIf pMode = "equality" {
            Set tOrigNS = $NAMESPACE
            For tKind = "rule", "process" {
                Set tListed = ..Leg(tKind, "LIST")
                Set $NAMESPACE = "USER"
                Set tResultSet = ##class(%Library.ResultSet).%New()
                Set tSC = tResultSet.Prepare($Select(tKind = "rule": ..#RULEQUERY, 1: ..#PROCESSQUERY))
                Set $NAMESPACE = tOrigNS
                Set tEntry = {}
                Do tEntry.%Set("http", tListed.http, "number")
                Do tEntry.%Set("failedPair", tListed.%Get("failedPair"))
                Do tEntry.%Set("prepared", $$$ISOK(tSC), "boolean")
                Do tEntry.%Set("refused5580", ($$$ISERR(tSC) && ($System.Status.GetErrorText(tSC) [ "#5580")), "boolean")
                Do tOut.%Set(tKind, tEntry)
            }
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String, pMode As %String = "legs", pKind As %String = "rule", pClass As %String = "OcuPilot.Port.InteropPort") As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropLogPurgeChild).Probe($Job, pUser, pMode, pKind, pClass)::10
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

}
