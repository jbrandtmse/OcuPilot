/// <p>A seam subclass of <class>OcuPilot.Port.PathPort</class> and the allow-list helpers its two
/// test classes share. As a port it denies the pairs <method>Deny</method> names and counts every
/// admin port call it forwards, so a test can show the gate refusing with none made (AD-29). The
/// helpers record, set and restore the instance's <parameter>PURPOSE</parameter> allow-list through
/// <code>%SYS.FileSystemAccess</code> in <code>%SYS</code>.</p>
/// <p><b>Caller contract:</b> the helpers change the instance's own file-dialog allow-list, so only
/// a class armed by <code>OCUPILOT_ALLOW_PRINCIPALS</code> calls them, and it restores what
/// <method>Snapshot</method> recorded once it is done. They need a process holding
/// <code>%Admin_FileSystemAccess:USE</code>, and the directories they name must exist.</p>
Class OcuPilot.Test.PathPortFixture Extends OcuPilot.Port.PathPort
{

/// <p>Forget every denied pair and the call count.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotPathPortFixture
}

/// <p>Deny <var>pPair</var>, spelled <code>resource:permission</code>, until <method>Reset</method>.</p>
ClassMethod Deny(pPair As %String)
{
    Set ^||OcuPilotPathPortFixture("deny", pPair) = 1
}

/// <p>How many admin port calls this seam has forwarded since <method>Reset</method>.</p>
ClassMethod Calls() As %Integer
{
    Quit +$Get(^||OcuPilotPathPortFixture("calls"))
}

ClassMethod HoldsPrivilege(pResource As %String, pPermission As %String) As %Boolean
{
    If $Get(^||OcuPilotPathPortFixture("deny", pResource _ ":" _ pPermission)) Quit 0
    Quit ##super(pResource, pPermission)
}

ClassMethod AdminPortClass() As %String
{
    Quit $ClassName()
}

/// <p>Answer <var>pEndpoint</var> <var>pType</var> with HTTP <var>pHttp</var> until
/// <method>Reset</method>, instead of forwarding it: a 2xx with <var>pJson</var> parsed as the result,
/// anything else as a failed status carrying the fault <class>OcuPilot.Kernel.Fault</class> maps that
/// status to.</p>
ClassMethod Script(pEndpoint As %String, pType As %String, pHttp As %Integer, pJson As %String = "")
{
    Set ^||OcuPilotPathPortFixture("script", pEndpoint, pType) = $ListBuild(pHttp, pJson)
}

/// <p>The fault code a scripted failure of HTTP <var>pHttp</var> carries.</p>
ClassMethod ScriptedCode(pHttp As %Integer) As %String
{
    Do ##class(OcuPilot.Kernel.Fault).Outcome(pHttp, $$$ERROR($$$GeneralError, "scripted"), .tFault, .tDetail)
    Quit tFault.code
}

/// <p>The admin port's own <code>Invoke</code>, counted, or the answer <method>Script</method>
/// set for that endpoint and type.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotPathPortFixture("calls") = ..Calls() + 1
    Set tScript = $Get(^||OcuPilotPathPortFixture("script", pEndpoint, pType))
    If tScript = "" Quit ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set pHttpStatus = $List(tScript, 1)
    Set pResult = ""
    Set pFault = ""
    If (pHttpStatus >= 200) && (pHttpStatus < 300) {
        If $List(tScript, 2) '= "" Set pResult = ##class(%DynamicAbstractObject).%FromJSON($List(tScript, 2))
        Quit $$$OK
    }
    Set tSC = $$$ERROR($$$GeneralError, "scripted " _ pHttpStatus)
    Do ##class(OcuPilot.Kernel.Fault).Outcome(pHttpStatus, tSC, .pFault, .tDetail)
    Quit tSC
}

/// <p>The allow-list as it stands: whether <parameter>PURPOSE</parameter> exists, whether it is
/// restricted, and its root paths in the vendor's order.</p>
ClassMethod Snapshot(Output pExists As %Boolean, Output pRestricted As %Boolean, Output pPaths As %List) As %Status
{
    Set tSC = $$$OK
    Set pExists = 0
    Set pRestricted = 0
    Set pPaths = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set pExists = ''##class(%SYS.FileSystemAccess).PurposeExists(..#PURPOSE)
        If pExists {
            Set pRestricted = ''##class(%SYS.FileSystemAccess).IsRestricted(..#PURPOSE)
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT RootPath FROM %SYS.FileSystemAccess WHERE Purpose = ? ORDER BY RootPath", ..#PURPOSE)
            If tRS.%SQLCODE < 0 {
                Set tSC = $$$ERROR($$$GeneralError, "the allow-list could not be read: SQLCODE " _ tRS.%SQLCODE)
            } Else {
                While tRS.%Next() {
                    Set pPaths = pPaths _ $ListBuild(tRS.%GetData(1))
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Make <parameter>PURPOSE</parameter> hold exactly the root paths <var>pPaths</var>, with its
/// flag <var>pRestricted</var>. It exists afterwards even with no paths.</p>
ClassMethod SetUp(pRestricted As %Boolean, pPaths As %List = "") As %Status
{
    Set tSC = ..Clear()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(pPaths) {
            Set tSC = ##class(%SYS.FileSystemAccess).Create($List(pPaths, tI), ..#PURPOSE)
            If $$$ISERR(tSC) Quit
        }
        If $$$ISOK(tSC) {
            If pRestricted {
                Set tSC = ##class(%SYS.FileSystemAccess).EnablePurpose(..#PURPOSE)
            } Else {
                Set tSC = ##class(%SYS.FileSystemAccess).DisablePurpose(..#PURPOSE)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove <parameter>PURPOSE</parameter>, its root paths and its flag, as a fresh instance has
/// it. A purpose already absent is left so.</p>
ClassMethod Clear() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(%SYS.FileSystemAccess).PurposeExists(..#PURPOSE) Set tSC = ##class(%SYS.FileSystemAccess).ClearPurpose(..#PURPOSE)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove one root path from <parameter>PURPOSE</parameter>, leaving the rest and the flag.</p>
ClassMethod RemoveRoot(pRoot As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%SYS.FileSystemAccess).Delete(pRoot, ..#PURPOSE)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Put back what <method>Snapshot</method> recorded: <method>Clear</method> when the purpose was
/// absent, <method>SetUp</method> otherwise.</p>
ClassMethod Restore(pExists As %Boolean, pRestricted As %Boolean, pPaths As %List) As %Status
{
    If 'pExists Quit ..Clear()
    Quit ..SetUp(pRestricted, pPaths)
}

}
