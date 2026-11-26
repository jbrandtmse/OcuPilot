/// <p>The probe workflow users, roles, memberships, tasks, instance users and principals Story 24.17 Batch 3a's tests arrange, and Batch 3b's extend. Every probe is named
/// <parameter>MARKER</parameter> and something: a workflow user, role, membership, worklist item or task in <code>USER</code> (<parameter>SOURCE</parameter>) or <code>HSCUSTOM</code>,
/// an instance user in <code>%SYS</code> and the role of a principal. <method>DropProbes</method> removes every one by that marker from both namespaces and answers whether none is left,
/// <method>Foreign</method> counts the workflow rows of a namespace that are not probes, and <method>ProbeAs</method> runs port calls as a real user in a process of its own. A probe is saved
/// through the vendor's own calls; the fixture starts no production.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. It runs only on a throwaway instance, which sets the arming variable
/// <class>OcuPilot.Test.InteropWorkflowCase</class> names.</p>
Class OcuPilot.Test.InteropWorkflowFixture Extends %RegisteredObject
{

/// <p>What every probe's name begins with, the instance users', roles' and principals' included.</p>
Parameter MARKER = "OcuP2417w";

/// <p>The marker in upper case, which the SQL matches the names against: the vendor keys a workflow user's name exactly, so a probe may be spelled in any letter case.</p>
Parameter MARKERUPPER = "OCUP2417W";

/// <p>The subject every probe task carries.</p>
Parameter TASKSUBJECT = "OcuP2417w task";

/// <p>The namespace the probes live in, and the one that holds another's under one name.</p>
Parameter SOURCE = "USER";

Parameter OTHER = "HSCUSTOM";

/// <p>The class that creates and removes the principals.</p>
Parameter GENERATOR = "OcuPilot.Test.InteropArchiveFixture";

Parameter CASE = "OcuPilot.Test.InteropWorkflowCase";

/// <p>The tables a namespace's workflow rows live in, and the column each is matched by, in the order they are removed.</p>
Parameter TABLES = "EnsLib_Workflow.Worklist|UserName|RoleName,EnsLib_Workflow.RoleMembership|UserName|RoleName,EnsLib_Workflow.TaskResponse|%Subject|,EnsLib_Workflow.TaskRequest|%Subject|,EnsLib_Workflow.UserDefinition|Name|,EnsLib_Workflow.RoleDefinition|Name|";

/// <p>The workflow classes whose vendor save writes a source-control timestamp in the namespace.</p>
Parameter STAMPED = "EnsLib.Workflow.UserDefinition,EnsLib.Workflow.RoleDefinition,EnsLib.Workflow.RoleMembership";

/// <p>Create the instance user <var>pName</var> in <code>%SYS</code> when it is not there: no role, a password no one reads.</p>
ClassMethod InstanceUser(pName As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Security.Users).Exists(pName) {
            Set tPassword = "OcuP2417w" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
            Set tSC = ##class(Security.Users).Create(pName, "", tPassword, "OcuPilot test workflow probe (throwaway)", "", "", "", 0, 1, "Created by an OcuPilot workflow test; deleted when it ends")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the probe instance user <var>pName</var> from <code>%SYS</code>.</p>
ClassMethod DropInstanceUser(pName As %String) As %Status
{
    If $Extract(pName, 1, $Length(..#MARKER)) '= ..#MARKER Quit $$$ERROR($$$GeneralError, "only a probe instance user is deleted")
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Delete(pName)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store the workflow user <var>pName</var> in <var>pNamespace</var> with <var>pFullName</var> and <var>pActive</var>, through the vendor's own save, and with <var>pInstance</var> make
/// the instance user of that name first. The save of an active user sends nothing to the engine.</p>
ClassMethod ProbeUser(pName As %String, pFullName As %String = "", pActive As %Boolean = 1, pNamespace As %String = {..#SOURCE}, pInstance As %Boolean = 1) As %Status
{
    Set tSC = $$$OK
    If pInstance Set tSC = ..InstanceUser(pName)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tUser = ##class(EnsLib.Workflow.UserDefinition).%New()
        Set tUser.Name = pName
        Set tUser.FullName = pFullName
        Set tUser.IsActive = pActive
        Set tSC = tUser.%Save()
        Set tUser = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store the workflow role <var>pName</var> in <var>pNamespace</var>.</p>
ClassMethod ProbeRole(pName As %String, pNamespace As %String = {..#SOURCE}) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If '##class(EnsLib.Workflow.RoleDefinition).%ExistsId(pName) {
            Set tRole = ##class(EnsLib.Workflow.RoleDefinition).%New()
            Set tRole.Name = pName
            Set tSC = tRole.%Save()
        }
        Set tRole = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Make the workflow user <var>pUser</var> a member of the role <var>pRole</var> in <var>pNamespace</var> through the vendor's own <code>AddUserToRole</code>.</p>
ClassMethod ProbeMember(pRole As %String, pUser As %String, pNamespace As %String = {..#SOURCE}) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(EnsLib.Workflow.RoleDefinition).AddUserToRole(pRole, pUser, 1, "")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store a task of the role <var>pRole</var> in <var>pNamespace</var>, assigned to <var>pOwner</var> (empty for none), and, when <var>pWorklistUser</var> is not empty, a worklist
/// item of that user for it, as a task the vendor assigned. No production is needed. Answer the task's id, or 0.</p>
ClassMethod ProbeTask(pRole As %String, pOwner As %String, pWorklistUser As %String, pNamespace As %String = {..#SOURCE}) As %Integer
{
    Set tId = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRequest = ##class(EnsLib.Workflow.TaskRequest).%New()
        Set tRequest.%Subject = ..#TASKSUBJECT
        Set tSC = tRequest.%Save()
        If $$$ISOK(tSC) {
            Set tTask = ##class(EnsLib.Workflow.TaskResponse).%New()
            Set tStatus = ##class(EnsLib.Workflow.TaskStatus).%New()
            Set tStatus.Role = ##class(EnsLib.Workflow.RoleDefinition).%OpenId(pRole)
            Set tStatus.AssignedTo = pOwner
            Set tStatus.Request = tRequest
            Set tTask.%TaskStatus = tStatus
            Set tTask.%Subject = ..#TASKSUBJECT
            Set tSC = tTask.%Save()
        }
        If $$$ISOK(tSC) {
            Set tId = tTask.%Id()
            If pWorklistUser '= "" {
                Set tItem = ##class(EnsLib.Workflow.Worklist).%New()
                Set tItem.Task = tTask
                Set tItem.User = ##class(EnsLib.Workflow.UserDefinition).%OpenId(pWorklistUser)
                Set tItem.Role = ##class(EnsLib.Workflow.RoleDefinition).%OpenId(pRole)
                If $$$ISERR(tItem.%Save()) Set tId = 0
            }
        }
        Set tItem = ""
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tId = 0
    }
    Quit tId
}

/// <p>The workflow user <var>pName</var> of <var>pNamespace</var> as <code>FullName|IsActive</code>, held under exactly that name, or <code>&lt;absent&gt;</code>.</p>
ClassMethod UserText(pNamespace As %String, pName As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "<absent>"
    Try {
        Set $NAMESPACE = pNamespace
        Set tUser = ##class(EnsLib.Workflow.UserDefinition).%OpenId(pName)
        If $IsObject(tUser) && ('(tUser.Name ] pName)) && ('(pName ] tUser.Name)) Set tText = tUser.FullName _ "|" _ tUser.IsActive
        Set tUser = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = "<unreadable>"
    }
    Quit tText
}

/// <p>What the workflow tables of <var>pNamespace</var> hold for the user <var>pUser</var> as <code>memberships|worklist items|tasks assigned</code>, or <code>?</code> when unreadable.</p>
ClassMethod Facts(pNamespace As %String, pUser As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "?"
    Try {
        Set $NAMESPACE = pNamespace
        Set tText = ..CountOf("SELECT COUNT(*) FROM EnsLib_Workflow.RoleMembership WHERE UserName = ?", pUser) _ "|" _ ..CountOf("SELECT COUNT(*) FROM EnsLib_Workflow.Worklist WHERE UserName = ?", pUser) _ "|" _ ..CountOf("SELECT COUNT(*) FROM EnsLib_Workflow.TaskResponse WHERE TaskStatus_AssignedTo = ?", pUser)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = "?"
    }
    Quit tText
}

/// <p>The first column of the one row the statement <var>pSql</var> answers with <var>pValue</var> bound once, or twice when <var>pSecond</var> is given, in the current namespace; -1 when it cannot be
/// read.</p>
ClassMethod CountOf(pSql As %String, pValue As %String = "", pSecond As %String = "") As %Integer
{
    If pSecond '= "" {
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, pSql, pValue, pSecond)
    } ElseIf pValue '= "" {
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, pSql, pValue)
    } Else {
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, pSql)
    }
    If (tRS.%SQLCODE '= 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>How many probe workflow roles <var>pNamespace</var> holds; -1 when it cannot be read.</p>
ClassMethod RoleCount(pNamespace As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = -1
    Try {
        Set $NAMESPACE = pNamespace
        Set tCount = ..CountOf("SELECT COUNT(*) FROM EnsLib_Workflow.RoleDefinition WHERE UPPER(Name) %STARTSWITH ?", ..#MARKERUPPER)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>How many workflow users <var>pNamespace</var> holds: <code>1</code> the probes, <code>0</code> every one; -1 when it cannot be read.</p>
ClassMethod UserCount(pNamespace As %String, pMarked As %Boolean) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = -1
    Try {
        Set $NAMESPACE = pNamespace
        Set tCount = $Select(pMarked: ..CountOf("SELECT COUNT(*) FROM EnsLib_Workflow.UserDefinition WHERE UPPER(Name) %STARTSWITH ?", ..#MARKERUPPER), 1: ..CountOf("SELECT COUNT(*) FROM EnsLib_Workflow.UserDefinition"))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>How many workflow rows of <var>pNamespace</var> are not probes -- users, roles, memberships, worklist items, task requests and task responses -- which a class that lists and counts
/// every workflow row refuses to start beside; -1 when it cannot be read.</p>
ClassMethod Foreign(pNamespace As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tTotal = 0
    Try {
        Set $NAMESPACE = pNamespace
        For tI = 1:1:$Length(..#TABLES, ",") {
            Set tEntry = $Piece(..#TABLES, ",", tI)
            Set tTable = $Piece(tEntry, "|", 1)
            Set tFirst = $Piece(tEntry, "|", 2)
            Set tSecond = $Piece(tEntry, "|", 3)
            Set tAll = ..CountOf("SELECT COUNT(*) FROM " _ tTable)
            Set tMine = $Select(tSecond = "": ..CountOf("SELECT COUNT(*) FROM " _ tTable _ " WHERE UPPER(" _ tFirst _ ") %STARTSWITH ?", ..#MARKERUPPER), 1: ..CountOf("SELECT COUNT(*) FROM " _ tTable _ " WHERE UPPER(" _ tFirst _ ") %STARTSWITH ? OR UPPER(" _ tSecond _ ") %STARTSWITH ?", ..#MARKERUPPER, ..#MARKERUPPER))
            If (tAll < 0) || (tMine < 0) {
                Set tTotal = -1
                Quit
            }
            Set tTotal = tTotal + tAll - tMine
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tTotal = -1
    }
    Quit tTotal
}

/// <p>The probe instance users and probe roles of the instance, as <code>users|roles</code>; <code>?</code> when unreadable.</p>
ClassMethod InstanceLeft() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "?"
    Try {
        Set $NAMESPACE = "%SYS"
        Set tUsers = 0
        Set tRS = ##class(%ResultSet).%New("Security.Users:List")
        Set tSC = tRS.Execute(..#MARKER _ "*")
        While $$$ISOK(tSC) && tRS.Next() {
            Set tUsers = tUsers + 1
        }
        Set tRoles = 0
        Set tRS = ##class(%ResultSet).%New("Security.Roles:List")
        Set tSC = tRS.Execute(..#MARKER _ "*")
        While $$$ISOK(tSC) && tRS.Next() {
            Set tRoles = tRoles + 1
        }
        Set tText = tUsers _ "|" _ tRoles
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = "?"
    }
    Quit tText
}

/// <p>Whether <var>pNamespace</var> holds the registry entry the vendor's delete of a workflow user reads to take the user's memberships with it, which a compile of
/// <class>EnsLib.Workflow.RoleMembership</class> in that namespace writes; -1 when unreadable. Nothing is written.</p>
ClassMethod CascadeHeld(pNamespace As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tHeld = -1
    Try {
        Set $NAMESPACE = pNamespace
        Set tHeld = ''$Data(^rINDEXEXT("F", "EnsLib.Workflow.UserDefinition", "ID", "f", "EnsLib.Workflow.RoleMembership", "UserKey"))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tHeld = -1
    }
    Quit tHeld
}

/// <p>Take the registry entry <method>CascadeHeld</method> reads out of <var>pNamespace</var>, keeping what it held so <method>RestoreCascade</method> puts it back exactly, and answer whether the
/// namespace then holds none. A namespace already without it is left alone.</p>
ClassMethod HideCascade(pNamespace As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tGone = 0
    Try {
        Set $NAMESPACE = pNamespace
        If $Data(^rINDEXEXT("F", "EnsLib.Workflow.UserDefinition", "ID", "f", "EnsLib.Workflow.RoleMembership", "UserKey")) && '$Data(^||OcuPilotWorkflowCascade(pNamespace)) {
            Merge ^||OcuPilotWorkflowCascade(pNamespace) = ^rINDEXEXT("F", "EnsLib.Workflow.UserDefinition", "ID", "f", "EnsLib.Workflow.RoleMembership", "UserKey")
            Kill ^rINDEXEXT("F", "EnsLib.Workflow.UserDefinition", "ID", "f", "EnsLib.Workflow.RoleMembership", "UserKey")
        }
        Set tGone = '$Data(^rINDEXEXT("F", "EnsLib.Workflow.UserDefinition", "ID", "f", "EnsLib.Workflow.RoleMembership", "UserKey"))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tGone = 0
    }
    Quit tGone
}

/// <p>Put back every registry entry <method>HideCascade</method> took, in the namespace it took it from, and forget it. Nothing is written when none was taken.</p>
ClassMethod RestoreCascade()
{
    Set tOrigNS = $NAMESPACE
    Set tNamespace = ""
    For {
        Set tNamespace = $Order(^||OcuPilotWorkflowCascade(tNamespace))
        If tNamespace = "" Quit
        Try {
            Set $NAMESPACE = tNamespace
            Merge ^rINDEXEXT("F", "EnsLib.Workflow.UserDefinition", "ID", "f", "EnsLib.Workflow.RoleMembership", "UserKey") = ^||OcuPilotWorkflowCascade(tNamespace)
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
    }
    Kill ^||OcuPilotWorkflowCascade
}

/// <p>The vendor's own <code>%DeleteId</code> of the workflow user <var>pName</var> in <var>pNamespace</var>, as a positive control of what the vendor's delete takes with it.</p>
ClassMethod VendorDelete(pNamespace As %String, pName As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(EnsLib.Workflow.UserDefinition).%DeleteId(pName)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Keep, for both namespaces, the source-control timestamp each <parameter>STAMPED</parameter> class's vendor save writes under <code>^Ens.Configuration("sdd")</code>, or that it had none, so
/// <method>RestoreStamps</method> leaves them as a class found them.</p>
ClassMethod KeepStamps()
{
    Kill ^||OcuPilotWorkflowStamps
    Set tOrigNS = $NAMESPACE
    For tNamespace = ..#SOURCE, ..#OTHER {
        Try {
            Set $NAMESPACE = tNamespace
            For tI = 1:1:$Length(..#STAMPED, ",") {
                Set tClass = $Piece(..#STAMPED, ",", tI)
                Set ^||OcuPilotWorkflowStamps(tNamespace, tClass) = $ListBuild($Data(^Ens.Configuration("sdd", tClass, "time")) # 2, $Get(^Ens.Configuration("sdd", tClass, "time")))
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
    }
}

/// <p>Put back the timestamps <method>KeepStamps</method> kept, removing one a namespace did not hold, and forget them.</p>
ClassMethod RestoreStamps()
{
    Set tOrigNS = $NAMESPACE
    For tNamespace = ..#SOURCE, ..#OTHER {
        Try {
            Set $NAMESPACE = tNamespace
            Set tClass = ""
            For {
                Set tClass = $Order(^||OcuPilotWorkflowStamps(tNamespace, tClass), 1, tKept)
                If tClass = "" Quit
                If $List(tKept, 1) {
                    Set ^Ens.Configuration("sdd", tClass, "time") = $List(tKept, 2)
                } Else {
                    Kill ^Ens.Configuration("sdd", tClass, "time")
                }
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
    }
    Kill ^||OcuPilotWorkflowStamps
}

/// <p>Remove every probe from both namespaces and from the instance: each workflow table's probe rows (the worklist and memberships first, then tasks, users and roles), the probe instance users and
/// the probe roles. Answer <code>1</code> when none is left.</p>
ClassMethod DropProbes() As %Boolean
{
    Do ..DropWorkflowRows()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tNames
        Set tRS = ##class(%ResultSet).%New("Security.Users:List")
        Set tSC = tRS.Execute(..#MARKER _ "*")
        While $$$ISOK(tSC) && tRS.Next() {
            Set tNames(tRS.GetData(1)) = ""
        }
        Set tName = ""
        For {
            Set tName = $Order(tNames(tName))
            If tName = "" Quit
            Do ##class(Security.Users).Delete(tName)
        }
        Kill tNames
        Set tRS = ##class(%ResultSet).%New("Security.Roles:List")
        Set tSC = tRS.Execute(..#MARKER _ "*")
        While $$$ISOK(tSC) && tRS.Next() {
            Set tNames(tRS.GetData(1)) = ""
        }
        Set tName = ""
        For {
            Set tName = $Order(tNames(tName))
            If tName = "" Quit
            Do ##class(Security.Roles).Delete(tName)
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit ..Left() = 0
}

/// <p>Remove every probe workflow row from both namespaces, leaving the instance's users and roles, and so the principals a test is signing in as, in place.</p>
ClassMethod DropWorkflowRows()
{
    Set tOrigNS = $NAMESPACE
    For tNamespace = ..#SOURCE, ..#OTHER {
        Try {
            Set $NAMESPACE = tNamespace
            For tI = 1:1:$Length(..#TABLES, ",") {
                Set tEntry = $Piece(..#TABLES, ",", tI)
                Set tSql = "DELETE FROM " _ $Piece(tEntry, "|", 1) _ " WHERE UPPER(" _ $Piece(tEntry, "|", 2) _ ") %STARTSWITH ?"
                If $Piece(tEntry, "|", 3) '= "" {
                    Set tSql = tSql _ " OR UPPER(" _ $Piece(tEntry, "|", 3) _ ") %STARTSWITH ?"
                    Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, tSql, ..#MARKERUPPER, ..#MARKERUPPER)
                } Else {
                    Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, tSql, ..#MARKERUPPER)
                }
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
    }
}

/// <p>How many probes are left: every workflow row of either namespace whose name carries the marker, and the probe instance users and roles; -1 when unreadable.</p>
ClassMethod Left() As %Integer
{
    Set tLeft = 0
    Set tOrigNS = $NAMESPACE
    For tNamespace = ..#SOURCE, ..#OTHER {
        Try {
            Set $NAMESPACE = tNamespace
            For tI = 1:1:$Length(..#TABLES, ",") {
                Set tEntry = $Piece(..#TABLES, ",", tI)
                Set tSql = "SELECT COUNT(*) FROM " _ $Piece(tEntry, "|", 1) _ " WHERE UPPER(" _ $Piece(tEntry, "|", 2) _ ") %STARTSWITH ?"
                If $Piece(tEntry, "|", 3) '= "" {
                    Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, tSql _ " OR UPPER(" _ $Piece(tEntry, "|", 3) _ ") %STARTSWITH ?", ..#MARKERUPPER, ..#MARKERUPPER)
                } Else {
                    Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, tSql, ..#MARKERUPPER)
                }
                Set tCount = $Select((tRS.%SQLCODE = 0) && tRS.%Next(): +tRS.%GetData(1), 1: -1)
                Set tLeft = tLeft + $Select(tCount < 0: 1000000, 1: tCount)
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
            Set tLeft = tLeft + 1000000
        }
    }
    Set tInstance = ..InstanceLeft()
    If tInstance = "?" Quit -1
    Quit tLeft + $Piece(tInstance, "|", 1) + $Piece(tInstance, "|", 2)
}

/// <p>The names of the rows <var>pRows</var> carries under <code>Name</code>, comma-separated in the order they come.</p>
ClassMethod Names(pRows) As %String
{
    Set tText = ""
    If '$IsObject(pRows) Quit tText
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.%Get("Name")
    }
    Quit tText
}

/// <p>The port call of <var>pType</var> on <var>pEndpoint</var> (<code>WorkflowUsers</code>) as the leg <var>pLeg</var> describes it, <code>{endpoint, type, query, body}</code>, answered as
/// <code>{http, code, failedPair, count, names}</code>; <code>names</code> is the choices' or list's names, comma-separated.</p>
ClassMethod Leg(pLeg As %DynamicObject, pClass As %String = "OcuPilot.Port.InteropPort") As %DynamicObject
{
    Kill tQuery
    Set tQuery("namespace") = ..#SOURCE
    If $IsObject(pLeg.%Get("query")) {
        Set tIterator = pLeg.query.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tQuery(tKey) = tValue
        }
    }
    Set tHttp = 0
    Set tFault = ""
    Set tSC = $ClassMethod(pClass, "Invoke", pLeg.%Get("endpoint"), pLeg.type, .tQuery, pLeg.%Get("body"), .tResult, .tHttp, .tFault)
    Set tLeg = {}
    Do tLeg.%Set("http", +tHttp, "number")
    If $IsObject($Get(tResult)) {
        If tResult.%IsA("%Library.DynamicArray") {
            Do tLeg.%Set("count", tResult.%Size(), "number")
            Do tLeg.%Set("names", ..Names(tResult), "string")
        } Else {
            Do tLeg.%Set("name", tResult.%Get("Name"), "string")
        }
    }
    If $IsObject(tFault) {
        Do tLeg.%Set("code", tFault.%Get("code"))
        If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
    }
    Quit tLeg
}

/// <p>The child process: log in as <var>pUsername</var>, run each leg of the JSON array <var>pLegs</var> through the port class <var>pClass</var>, with the process's roles, user and namespace
/// before and after, then signal the answer to process <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pLegs As %String, pClass As %String)
{
    Set tOut = {}
    Try {
        Set tVariable = $Parameter(..#CASE, "ARMINGVARIABLE")
        If $System.Util.GetEnviron(tVariable) '= 1 {
            Do tOut.%Set("error", tVariable _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Set tBefore = $ROLES
        Set tUser = $USERNAME
        Set tNamespace = $NAMESPACE
        Set tLegs = ##class(%DynamicAbstractObject).%FromJSON(pLegs)
        Set tResults = {}
        Set tIterator = tLegs.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLegSpec) {
            Do tResults.%Set(tLegSpec.name, ..Leg(tLegSpec, pClass))
        }
        Do tOut.%Set("legs", tResults)
        Do tOut.%Set("before", tBefore)
        Do tOut.%Set("after", $ROLES)
        Do tOut.%Set("sameUser", (tUser = $USERNAME), "boolean")
        Do tOut.%Set("sameNamespace", (tNamespace = $NAMESPACE), "boolean")
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process over the legs <var>pLegs</var> (a <class>%DynamicArray</class>) and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String, pLegs As %DynamicArray, pClass As %String = "OcuPilot.Port.InteropPort") As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropWorkflowFixture).Probe($Job, pUser, pLegs.%ToJSON(), pClass)::10
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
