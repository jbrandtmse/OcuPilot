/// <p>A seam subclass of <class>OcuPilot.Port.PathPort</class> and the allow-list helpers its test
/// classes share. As a port it denies the pairs <method>Deny</method> names, admits any name
/// after <method>AdmitAnyName</method>, answers the configuration file
/// <method>UseConfigurationFile</method> names, the database and journal directories
/// <method>UseDatabaseDirectories</method> and <method>UseJournalDirectories</method> name, the
/// three journal sources <method>UseJournalSources</method> names and the served directory
/// <method>UseServedDirectory</method> names, and
/// counts every admin port call it forwards, so a test can show the gate refusing with none made
/// (AD-29). The
/// helpers record, set and restore the instance's <parameter>PURPOSE</parameter> allow-list through
/// <code>%SYS.FileSystemAccess</code> in <code>%SYS</code>.</p>
/// <p><b>Caller contract:</b> the helpers change the instance's own file-dialog allow-list, so only
/// a class armed by <code>OCUPILOT_ALLOW_PRINCIPALS</code> calls them, and it restores what
/// <method>Snapshot</method> recorded once it is done. They need a process holding
/// <code>%Admin_FileSystemAccess:USE</code>, and the directories they name must exist.</p>
Class OcuPilot.Test.PathPortFixture Extends OcuPilot.Port.PathPort
{

/// <p>Forget everything the seams were told, and the call count.</p>
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

/// <p>Admit every relative name until <method>Reset</method>, so a test can reach the containment
/// check behind the name rule.</p>
ClassMethod AdmitAnyName()
{
    Set ^||OcuPilotPathPortFixture("admitany") = 1
}

ClassMethod NameAdmitted(pPath As %String, pKind As %String) As %Boolean
{
    If $Get(^||OcuPilotPathPortFixture("admitany")) Quit 1
    Quit ##super(pPath, pKind)
}

/// <p>Answer <var>pFile</var> as the instance's configuration file until <method>Reset</method>,
/// so a test can show the port reads its location rather than assuming one.</p>
ClassMethod UseConfigurationFile(pFile As %String)
{
    Set ^||OcuPilotPathPortFixture("cpf") = pFile
}

ClassMethod ConfigurationFile() As %String
{
    If $Data(^||OcuPilotPathPortFixture("cpf")) Quit ^||OcuPilotPathPortFixture("cpf")
    Quit ##super()
}

/// <p>Answer the directories <var>pDirectories</var> and stream locations <var>pStreams</var>, each
/// a <code>$List</code> of normalized directories, as the configured databases' until
/// <method>Reset</method>; with <var>pFail</var>, fail that read instead.</p>
ClassMethod UseDatabaseDirectories(pDirectories As %List = "", pStreams As %List = "", pFail As %Boolean = 0)
{
    Set ^||OcuPilotPathPortFixture("databases") = $ListBuild(pDirectories, pStreams, ''pFail)
}

ClassMethod DatabaseDirectories(Output pDirectories As %List, Output pStreams As %List) As %Status
{
    If '$Data(^||OcuPilotPathPortFixture("databases")) Quit ##super(.pDirectories, .pStreams)
    Set tSeam = ^||OcuPilotPathPortFixture("databases")
    Set pDirectories = ""
    Set pStreams = ""
    If $List(tSeam, 3) Quit $$$ERROR($$$GeneralError, "the database read failed, as the fixture was told")
    Set pDirectories = $List(tSeam, 1)
    Set pStreams = $List(tSeam, 2)
    Quit $$$OK
}

/// <p>Fail every database's volume-directory read until <method>Reset</method>, overriding
/// <method>VolumeDirectories</method> alone, so the real <code>Config.Databases</code> read runs and the
/// reader's own handling of an inner failure is what a test reaches (Story 18.3, DW-1796).</p>
ClassMethod FailVolumeDirectories()
{
    Set ^||OcuPilotPathPortFixture("volumesFail") = 1
}

ClassMethod VolumeDirectories(pDirectory As %String, Output pDirectories As %List) As %Status
{
    Set pDirectories = ""
    If $Get(^||OcuPilotPathPortFixture("volumesFail")) Quit $$$ERROR($$$GeneralError, "the volume read failed, as the fixture was told")
    Quit ##super(pDirectory, .pDirectories)
}

/// <p>Answer the directories <var>pDirectories</var>, a <code>$List</code> of normalized
/// directories, as the instance's journal directories until <method>Reset</method>; with
/// <var>pFail</var>, fail that read instead.</p>
ClassMethod UseJournalDirectories(pDirectories As %List = "", pFail As %Boolean = 0)
{
    Set ^||OcuPilotPathPortFixture("journals") = $ListBuild(pDirectories, ''pFail)
}

ClassMethod JournalDirectories(Output pDirectories As %List) As %Status
{
    If '$Data(^||OcuPilotPathPortFixture("journals")) Quit ##super(.pDirectories)
    Set tSeam = ^||OcuPilotPathPortFixture("journals")
    Set pDirectories = ""
    If $List(tSeam, 2) Quit $$$ERROR($$$GeneralError, "the journal read failed, as the fixture was told")
    Set pDirectories = $List(tSeam, 1)
    Quit $$$OK
}

/// <p>Answer <var>pPrimary</var>, <var>pAlternate</var> and <var>pCurrentFile</var> as the
/// instance's primary and alternate journal directories and current journal file until
/// <method>Reset</method>, so the port's own composition of the three is what runs; with
/// <var>pFail</var>, answer them and fail that read as well, as a read that stops part way
/// does.</p>
ClassMethod UseJournalSources(pPrimary As %String = "", pAlternate As %String = "", pCurrentFile As %String = "", pFail As %Boolean = 0)
{
    Set ^||OcuPilotPathPortFixture("journalsources") = $ListBuild(pPrimary, pAlternate, pCurrentFile, ''pFail)
}

ClassMethod JournalSources(Output pPrimary As %String, Output pAlternate As %String, Output pCurrentFile As %String) As %Status
{
    If '$Data(^||OcuPilotPathPortFixture("journalsources")) Quit ##super(.pPrimary, .pAlternate, .pCurrentFile)
    Set tSeam = ^||OcuPilotPathPortFixture("journalsources")
    Set pPrimary = $List(tSeam, 1)
    Set pAlternate = $List(tSeam, 2)
    Set pCurrentFile = $List(tSeam, 3)
    If $List(tSeam, 4) Quit $$$ERROR($$$GeneralError, "the journal source read failed, as the fixture was told")
    Quit $$$OK
}

/// <p>Answer <var>pDirectory</var> as the directory OcuPilot's client is served from until
/// <method>Reset</method>; <code>""</code> answers a read that found none.</p>
ClassMethod UseServedDirectory(pDirectory As %String = "")
{
    Set ^||OcuPilotPathPortFixture("served") = pDirectory
}

ClassMethod ServedDirectory() As %String
{
    If $Data(^||OcuPilotPathPortFixture("served")) Quit ^||OcuPilotPathPortFixture("served")
    Quit ##super()
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
