/// <p>The probe managed alerts and principals Story 24.17 Batch 1's tests arrange. Every probe is an <class>Ens.Alerting.ManagedAlert</class> whose source is <parameter>MARKER</parameter>,
/// saved in <code>USER</code> (<parameter>SOURCE</parameter>) or <code>HSCUSTOM</code> as the process's own user. <method>DropProbes</method> removes every probe from both namespaces and answers
/// whether none is left, <method>Foreign</method> counts the alerts in a namespace that are not probes, and <method>ProbeWithId</method> makes the lower namespace's id counter reach another's so
/// both hold a probe under one id. It starts no production.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropAlertFixture Extends %RegisteredObject
{

Parameter MARKER = "OcuProbe2417";

/// <p>The namespace the probes live in, and the one that holds another's under one id.</p>
Parameter SOURCE = "USER";

Parameter OTHER = "HSCUSTOM";

/// <p>The class that creates and removes the principals.</p>
Parameter GENERATOR = "OcuPilot.Test.InteropArchiveFixture";

/// <p>Store a probe alert in <var>pNamespace</var> with <var>pOwner</var>, open or closed, at escalation level <var>pLevel</var>, with <var>pText</var>, due an hour from now, and answer its id, or 0.</p>
ClassMethod Probe(pNamespace As %String = {..#SOURCE}, pOwner As %String = "", pOpen As %Boolean = 1, pLevel As %Integer = 0, pText As %String = "probe alert") As %Integer
{
    Set tId = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tNow = $ZDateTime($ZTimeStamp, 3, , 3)
        Set tAlert = ##class(Ens.Alerting.ManagedAlert).%New()
        Set tAlert.AlertTime = tNow
        Set tAlert.AlertText = pText
        Set tAlert.SourceConfigName = ..#MARKER
        Set tAlert.Production = ..#MARKER _ ".Production"
        Set tAlert.SessionId = 1
        Set tAlert.CurrentOwner = pOwner
        Set tAlert.IsOpen = pOpen
        Set tAlert.EscalationLevel = pLevel
        Set tAlert.NextActionTime = $System.SQL.DATEADD("mi", 60, tNow)
        If $$$ISOK(tAlert.%Save()) Set tId = tAlert.%Id()
        Set tAlert = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tId = 0
    }
    Quit tId
}

/// <p>Store a probe alert in <var>pNamespace</var> under the id <var>pId</var>, by moving that namespace's id counter to <code>pId - 1</code> first and putting it back to the larger of its value
/// and <var>pId</var> after. Answer the id stored, or 0.</p>
ClassMethod ProbeWithId(pNamespace As %String, pId As %Integer, pOwner As %String = "") As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tId = 0
    Try {
        Set $NAMESPACE = pNamespace
        Set tCounter = +$Get(^Ens.Alerting.ManagedAlertD)
        Set ^Ens.Alerting.ManagedAlertD = pId - 1
        Set $NAMESPACE = tOrigNS
        Set tId = ..Probe(pNamespace, pOwner)
        Set $NAMESPACE = pNamespace
        If +$Get(^Ens.Alerting.ManagedAlertD) < tCounter Set ^Ens.Alerting.ManagedAlertD = tCounter
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tId = 0
    }
    Quit tId
}

/// <p>Delete the alert <var>pId</var> of <var>pNamespace</var>, whatever its source; answer <code>1</code> when it is gone.</p>
ClassMethod Delete(pNamespace As %String, pId As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tGone = 0
    Try {
        Set $NAMESPACE = pNamespace
        Do ##class(Ens.Alerting.ManagedAlert).%DeleteId(pId)
        Set tGone = '##class(Ens.Alerting.ManagedAlert).%ExistsId(pId)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tGone
}

/// <p>The id the next alert saved in <var>pNamespace</var> takes.</p>
ClassMethod NextId(pNamespace As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tNext = 0
    Try {
        Set $NAMESPACE = pNamespace
        Set tNext = +$Get(^Ens.Alerting.ManagedAlertD) + 1
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tNext
}

/// <p>How many alerts <var>pNamespace</var> holds: <code>1</code> the probes, <code>0</code> every one; -1 when it cannot be read.</p>
ClassMethod Count(pNamespace As %String, pMarked As %Boolean) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = -1
    Try {
        Set $NAMESPACE = pNamespace
        Set tSql = "SELECT COUNT(*) FROM Ens_Alerting.ManagedAlert" _ $Select(pMarked: " WHERE SourceConfigName = ?", 1: "")
        Set tRS = $Select(pMarked: ##class(%SQL.Statement).%ExecDirectNoPriv(, tSql, ..#MARKER), 1: ##class(%SQL.Statement).%ExecDirectNoPriv(, tSql))
        If (tRS.%SQLCODE = 0) && tRS.%Next() Set tCount = +tRS.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>How many alerts <var>pNamespace</var> holds that are not probes, which a class that counts every alert refuses to start beside; -1 when it cannot be read.</p>
ClassMethod Foreign(pNamespace As %String) As %Integer
{
    Set tAll = ..Count(pNamespace, 0)
    If tAll < 0 Quit -1
    Quit tAll - ..Count(pNamespace, 1)
}

/// <p>Remove every probe alert from both namespaces; answer <code>1</code> when none is left in either.</p>
ClassMethod DropProbes() As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tLeft = 0
    For tNamespace = ..#SOURCE, ..#OTHER {
        Try {
            Set $NAMESPACE = tNamespace
            Kill tIds
            Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT ID FROM Ens_Alerting.ManagedAlert WHERE SourceConfigName = ?", ..#MARKER)
            While tRS.%Next() {
                Set tIds(tRS.%GetData(1)) = ""
            }
            Set tId = ""
            For {
                Set tId = $Order(tIds(tId))
                If tId = "" Quit
                Do ##class(Ens.Alerting.ManagedAlert).%DeleteId(tId)
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
        Set tCount = ..Count(tNamespace, 1)
        If tCount '= 0 Set tLeft = tLeft + 1
    }
    Quit 'tLeft
}

/// <p>The alert <var>pId</var> of <var>pNamespace</var> as one text, <code>owner|open|level|history rows</code>, or <code>&lt;none&gt;</code> when it is gone.</p>
ClassMethod State(pNamespace As %String, pId As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "<none>"
    Try {
        Set $NAMESPACE = pNamespace
        Set tAlert = ##class(Ens.Alerting.ManagedAlert).%OpenId(pId)
        If $IsObject(tAlert) Set tText = tAlert.CurrentOwner _ "|" _ tAlert.IsOpen _ "|" _ tAlert.EscalationLevel _ "|" _ tAlert.Actions.Count()
        Set tAlert = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = "<unreadable>"
    }
    Quit tText
}

/// <p>The stored next action time of the alert <var>pId</var> of <var>pNamespace</var>, or <code>""</code>.</p>
ClassMethod NextTime(pNamespace As %String, pId As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = pNamespace
        Set tAlert = ##class(Ens.Alerting.ManagedAlert).%OpenId(pId)
        If $IsObject(tAlert) Set tText = tAlert.NextActionTime
        Set tAlert = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tText
}

/// <p>The history row <var>pIndex</var> (1 is the oldest) of the alert <var>pId</var> of <var>pNamespace</var> as one text, <code>user|action|reason</code>, or <code>""</code>.</p>
ClassMethod Action(pNamespace As %String, pId As %String, pIndex As %Integer) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = pNamespace
        Set tAlert = ##class(Ens.Alerting.ManagedAlert).%OpenId(pId)
        If $IsObject(tAlert) && (pIndex '> tAlert.Actions.Count()) {
            Set tAction = tAlert.Actions.GetAt(pIndex)
            Set tText = tAction.Username _ "|" _ tAction.Action _ "|" _ tAction.Reason
        }
        Set tAlert = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tText
}

/// <p>Update the probe <var>pId</var> of <var>pNamespace</var> as the process's own user, through the vendor's own method, <var>pBits</var> and the values in <var>pValues</var>
/// (<code>CurrentOwner</code>, <code>IsOpen</code>, <code>EscalationLevel</code>, <code>NextActionTime</code>), with <var>pReason</var>. Answer the vendor's status.</p>
ClassMethod Touch(pNamespace As %String, pId As %String, pBits As %Integer, ByRef pValues, pReason As %String = "probe") As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(Ens.Alerting.ManagedAlert).UpdateManagedAlert(pId, pBits, .pValues, pReason)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create <var>pUser</var> as one the classic form lists as an owner in <code>USER</code>: a user with <code>%EnsRole_AlertOperator</code> and a role of its own that writes <code>USER</code>'s
/// database, with the password <var>pPassword</var>.</p>
ClassMethod CreateOwner(pUser As %String, pPassword As %String) As %Status
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", pUser _ ":%Development:U,%DB_USER:RW", pPassword)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).AddRoles(pUser, "%EnsRole_AlertOperator")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove <var>pUser</var> and its role.</p>
ClassMethod DropOwner(pUser As %String) As %Status
{
    Quit $ClassMethod(..#GENERATOR, "DeletePrincipals", pUser)
}

}
