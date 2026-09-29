/// <p>Subclass of <class>OcuPilot.Port.TaskTransferPort</class> overriding only its seams, so the
/// export and import tests run the port's real resolve, file read, rules and refusal mapping: a pair
/// the gate answers as not held, every vendor call recorded before it is made, and a vendor call that
/// fails, after writing part of a file where asked to. The probe helpers make and remove what the
/// tests make: tasks named <parameter>PREFIX</parameter> and files in <method>ProbeDirectory</method>.</p>
/// <p>State lives in <code>^||OcuPilotTaskTransferFixture</code>; <method>Clear</method> forgets it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. Its
/// callers are armed on <code>OCUPILOT_ALLOW_TASK_CONTROL</code>.</p>
Class OcuPilot.Test.TaskTransferFixture Extends OcuPilot.Port.TaskTransferPort
{

/// <p>The name every probe task carries, and the probe directory's name under the first root.</p>
Parameter PREFIX = "OcuP164";

/// <p>The description every task a probe file holds carries: the taken-name case names its task after
/// a vendor task, so a task the import created from a probe file is found by this rather than by its
/// name.</p>
Parameter DESCRIPTION = "OcuPilot Story 16.4 probe";

/// <p>Forget every armed answer and recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotTaskTransferFixture
    Do ##class(OcuPilot.Test.PathPortFixture).Reset()
}

/// <p>Resolve through <class>OcuPilot.Test.PathPortFixture</class>, whose seams the caller sets,
/// until <method>Clear</method>.</p>
ClassMethod UsePathPortFixture()
{
    Set ^||OcuPilotTaskTransferFixture("pathport") = 1
}

ClassMethod PathPortClass() As %String
{
    If $Get(^||OcuPilotTaskTransferFixture("pathport")) Quit "OcuPilot.Test.PathPortFixture"
    Quit ##super()
}

/// <p>Answer the gate as not holding <var>pPair</var>.</p>
ClassMethod DenyPair(pPair As %String)
{
    Set ^||OcuPilotTaskTransferFixture("denied") = pPair
}

/// <p>Fail the next vendor call, after writing <var>pPartial</var> to the file first when it is not
/// empty.</p>
ClassMethod FailVendor(pPartial As %String = "")
{
    Set ^||OcuPilotTaskTransferFixture("fail") = 1
    Set ^||OcuPilotTaskTransferFixture("partial") = pPartial
}

/// <p>Every vendor call made, oldest first, each <code>EXPORT &lt;ids&gt; &lt;file&gt;</code> or
/// <code>IMPORT &lt;file&gt;</code>, joined by <code>|</code>.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotTaskTransferFixture("calls", tAt), 1, tCall)
        If tAt = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: "|") _ tCall
    }
    Quit tOut
}

ClassMethod HoldsPair(pPair As %String) As %Boolean
{
    If pPair = $Get(^||OcuPilotTaskTransferFixture("denied")) Quit 0
    Quit ##super(pPair)
}

ClassMethod VendorExport(pIds As %List, pFile As %String) As %Status [ Private ]
{
    Set ^||OcuPilotTaskTransferFixture("calls", $Increment(^||OcuPilotTaskTransferFixture("calls"))) = "EXPORT " _ $ListToString(pIds) _ " " _ pFile
    If $Get(^||OcuPilotTaskTransferFixture("fail")) Quit ..Failed(pFile)
    Quit ##super(pIds, pFile)
}

ClassMethod VendorImport(pFile As %String) As %Status [ Private ]
{
    Set ^||OcuPilotTaskTransferFixture("calls", $Increment(^||OcuPilotTaskTransferFixture("calls"))) = "IMPORT " _ pFile
    If $Get(^||OcuPilotTaskTransferFixture("fail")) Quit ..Failed(pFile)
    Quit ##super(pFile)
}

/// <p>An armed failure: <var>pFile</var> written with the armed partial text when there is one, and an
/// error status carrying a vendor-shaped message.</p>
ClassMethod Failed(pFile As %String) As %Status [ Private ]
{
    Kill ^||OcuPilotTaskTransferFixture("fail")
    Set tPartial = $Get(^||OcuPilotTaskTransferFixture("partial"))
    If tPartial '= "" Do ..WriteFile(pFile, tPartial)
    Quit $$$ERROR($$$GeneralError, "OcuP164 armed vendor failure for " _ pFile)
}

/// <p>The first allowed root, as the Allowed directories read answers it.</p>
ClassMethod FirstRoot() As %String
{
    Set tSC = ##class(OcuPilot.Port.PathPort).Roots(1, .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) || (tRows.%Size() = 0) Quit ""
    Quit tRows.%Get(0).%Get("Directory")
}

/// <p>The probe directory, <parameter>PREFIX</parameter> under <method>FirstRoot</method>, created
/// when absent, with its trailing separator.</p>
ClassMethod ProbeDirectory() As %String
{
    Set tDirectory = ##class(%File).NormalizeDirectory(..FirstRoot() _ ..#PREFIX)
    If '##class(%File).DirectoryExists(tDirectory) Do ##class(%File).CreateDirectoryChain(tDirectory)
    Quit tDirectory
}

/// <p>Write <var>pText</var> to <var>pFile</var>, replacing what it held.</p>
ClassMethod WriteFile(pFile As %String, pText As %String) As %Status
{
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Set tSC = tStream.LinkToFile(pFile)
    If $$$ISERR(tSC) Quit tSC
    Set tStream.TranslateTable = "UTF8"
    Do tStream.Write(pText)
    Set tSC = tStream.%Save()
    Set tStream = ""
    Quit tSC
}

/// <p>What <var>pFile</var> holds, or <code>""</code>.</p>
ClassMethod FileText(pFile As %String) As %String
{
    If '##class(%File).Exists(pFile) Quit ""
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If $$$ISERR(tStream.LinkToFile(pFile)) Quit ""
    Set tText = tStream.Read(1000000)
    Set tStream = ""
    Quit tText
}

/// <p>A task export file's text holding one <code>Task</code> element per entry of <var>pTasks</var>,
/// each <code>{Name, NameSpace, TaskClass, RunAsUser, JobGUID}</code>, run on demand from tomorrow.</p>
ClassMethod ExportText(pTasks As %DynamicArray) As %String
{
    Set tText = "<?xml version=""1.0"" encoding=""UTF-8""?>" _ $Char(10) _ "<Tasks>"
    Set tIterator = pTasks.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTask) {
        Set tText = tText _ "<Task>"
        For tField = "Name", "RunAsUser", "TaskClass", "NameSpace" {
            Set tText = tText _ "<" _ tField _ ">" _ $ZConvert(tTask.%Get(tField), "O", "XML") _ "</" _ tField _ ">"
        }
        Set tText = tText _ "<TimePeriod>5</TimePeriod><JobGUID>" _ tTask.%Get("JobGUID") _ "</JobGUID><StartDate>" _ $ZDate($Horolog + 1, 3) _ "</StartDate><Description>" _ ..#DESCRIPTION _ "</Description></Task>"
    }
    Quit tText _ "</Tasks>" _ $Char(10)
}

/// <p>One entry for <method>ExportText</method>: a probe task named <parameter>PREFIX</parameter> and
/// <var>pSuffix</var>, run as the caller, with a fresh GUID unless <var>pGuid</var> names one.</p>
ClassMethod Entry(pSuffix As %String, pNamespace As %String = "%SYS", pClass As %String = "%SYS.Task.PurgeTaskHistory", pRunAs As %String = "", pGuid As %String = "") As %DynamicObject
{
    Set tEntry = {}
    Do tEntry.%Set("Name", ..#PREFIX _ pSuffix, "string")
    Do tEntry.%Set("NameSpace", pNamespace, "string")
    Do tEntry.%Set("TaskClass", pClass, "string")
    Do tEntry.%Set("RunAsUser", $Select(pRunAs = "": $Username, 1: pRunAs), "string")
    Do tEntry.%Set("JobGUID", $Select(pGuid = "": $System.Util.CreateGUID(), 1: pGuid), "string")
    Quit tEntry
}

/// <p>Create a probe task named <parameter>PREFIX</parameter> and <var>pSuffix</var> in
/// <code>%SYS</code>, run on demand as <var>pRunAs</var> (the caller when empty), and answer its id,
/// with its <code>JobGUID</code> in <var>pGuid</var>.</p>
ClassMethod MakeTask(pSuffix As %String, Output pId As %String, Output pGuid As %String, pRunAs As %String = "") As %Status
{
    Set pId = ""
    Set pGuid = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = ##class(%SYS.Task).%New()
        Set tTask.Name = ..#PREFIX _ pSuffix
        Set tTask.NameSpace = "%SYS"
        Set tTask.TaskClass = "%SYS.Task.PurgeTaskHistory"
        Set tTask.TimePeriod = 5
        Set tTask.RunAsUser = $Select(pRunAs = "": $Username, 1: pRunAs)
        Set tTask.Description = ..#DESCRIPTION
        Set tSC = tTask.%Save()
        If $$$ISOK(tSC) {
            Set pId = tTask.%Id()
            Set pGuid = tTask.JobGUID
        }
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create a probe diagnostic report task named <parameter>PREFIX</parameter> and <var>pSuffix</var>,
/// run on demand as the caller, whose password setting holds <var>pPassword</var>, and answer its
/// id.</p>
ClassMethod MakeSecretTask(pSuffix As %String, pPassword As %String, Output pId As %String) As %Status
{
    Set pId = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = ##class(%SYS.Task).%New()
        Set tTask.Name = ..#PREFIX _ pSuffix
        Set tTask.NameSpace = "%SYS"
        Set tTask.TaskClass = "%SYS.Task.DiagnosticReport"
        Set tTask.TimePeriod = 5
        Set tTask.RunAsUser = $Username
        Set tTask.Description = ..#DESCRIPTION
        Set tDefinition = ##class(%SYS.Task.DiagnosticReport).%New()
        Set tDefinition.SMTPServer = "smtp.invalid"
        Set tDefinition.SMTPPass = pPassword
        Set tSC = tTask.AssignSettings(tDefinition)
        If $$$ISOK(tSC) Set tSC = tTask.%Save()
        If $$$ISOK(tSC) Set pId = tTask.%Id()
        Set tDefinition = ""
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The ids of the tasks whose name starts with <parameter>PREFIX</parameter> or whose description is
/// <parameter>DESCRIPTION</parameter>, keyed by name, as <code>pIds(name) = id</code>, with the count
/// answered.</p>
ClassMethod Probes(Output pIds) As %Integer
{
    Kill pIds
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, Name, Description FROM %SYS.Task WHERE Name %STARTSWITH ? OR Description = ?", ..#PREFIX, ..#DESCRIPTION)
        While tRS.%Next() {
            If ($Extract(tRS.%Get("Name"), 1, $Length(..#PREFIX)) '= ..#PREFIX) && (tRS.%Get("Description") '= ..#DESCRIPTION) Continue
            Set pIds(tRS.%Get("Name")) = tRS.%Get("ID")
            Set tCount = tCount + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Delete task <var>pId</var> when its name starts with <parameter>PREFIX</parameter> or its description
/// is <parameter>DESCRIPTION</parameter>; any other task is left alone.</p>
ClassMethod RemoveTask(pId As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = ##class(%SYS.Task).%OpenId(pId, 0)
        If $IsObject(tTask) && (($Extract(tTask.Name, 1, $Length(..#PREFIX)) = ..#PREFIX) || (tTask.Description = ..#DESCRIPTION)) {
            Set tTask = ""
            Set tSC = ##class(%SYS.Task).%DeleteId(pId)
        }
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every probe task and the probe directory with everything in it; an error naming what
/// survives.</p>
ClassMethod RemoveProbes() As %Status
{
    Set tSC = $$$OK
    Do ..Probes(.tIds)
    Set tName = ""
    For {
        Set tName = $Order(tIds(tName), 1, tId)
        If tName = "" Quit
        Set tSC = $$$ADDSC(tSC, ..RemoveTask(tId))
    }
    If ..Probes() '= 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "a probe task named " _ ..#PREFIX _ "* survived its removal"))
    Set tDirectory = ##class(%File).NormalizeDirectory(..FirstRoot() _ ..#PREFIX)
    If ##class(%File).DirectoryExists(tDirectory) Do ##class(%File).RemoveDirectoryTree(tDirectory)
    If ##class(%File).DirectoryExists(tDirectory) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the probe directory " _ ..#PREFIX _ " survived its removal"))
    Quit tSC
}

}
