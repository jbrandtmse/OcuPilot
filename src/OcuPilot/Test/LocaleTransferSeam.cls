/// <p><class>OcuPilot.Port.LocalePort</class> with the two vendor calls that take a file replaced by recordings, so
/// <class>OcuPilot.Test.LocaleImportRules</class> sees the temporary file the port hands the vendor and what becomes of it: <method>VendorImport</method> and
/// <method>VendorExport</method> record the file's name, whether it exists and the directory it is in, and then answer what <method>Mode</method> names. Every
/// other step, the temporary file's making and its deletion included, is the shipped port's. <b>Not a <class>%UnitTest.TestCase</class></b>.</p>
Class OcuPilot.Test.LocaleTransferSeam Extends OcuPilot.Port.LocalePort
{

/// <p>The record of the vendor calls, one <code>operation|file|existed|directory|directoryExisted</code> node each.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotTransferCalls, ^||OcuPilotTransferMode, ^||OcuPilotTransferLogged, ^||OcuPilotTransferName
}

/// <p>Make every transfer's directory name end in <var>pName</var>, so a test can pose one that is taken, until <method>Reset</method>.</p>
ClassMethod FixName(pName As %String)
{
    Set ^||OcuPilotTransferName = pName
}

ClassMethod TransferName() As %String
{
    If $Data(^||OcuPilotTransferName) Quit ^||OcuPilotTransferName
    Quit ##super()
}

/// <p>The status texts the port logged since <method>Reset</method>, joined by <code>|</code>.</p>
ClassMethod Logged() As %String
{
    Set tOut = ""
    Set tI = ""
    For {
        Set tI = $Order(^||OcuPilotTransferLogged(tI))
        If tI = "" Quit
        Set tOut = tOut _ "|" _ ^||OcuPilotTransferLogged(tI)
    }
    Quit tOut
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set ^||OcuPilotTransferLogged($Increment(^||OcuPilotTransferLogged)) = $System.Status.GetErrorText(pStatus)
    Do ##super(pMessage, pStatus, pCode)
}

/// <p>How the vendor calls end until <method>Reset</method>: <code>ok</code> (the default), <code>error</code> (an error status) or <code>throw</code> (an
/// exception).</p>
ClassMethod Mode(pMode As %String)
{
    Set ^||OcuPilotTransferMode = pMode
}

/// <p>The calls recorded, as <code>operation|file|existed|directory|directoryExisted</code>, in order.</p>
ClassMethod Calls(Output pCalls)
{
    Kill pCalls
    Merge pCalls = ^||OcuPilotTransferCalls
}

ClassMethod VendorImport(pFile As %String, Output pCounts) As %Status [ Private ]
{
    Kill pCounts
    Set ^||OcuPilotTransferCalls($Increment(^||OcuPilotTransferCalls)) = "import|" _ pFile _ "|" _ ##class(%File).Exists(pFile) _ "|" _ ##class(%File).GetDirectory(pFile) _ "|" _ ##class(%File).DirectoryExists(##class(%File).GetDirectory(pFile))
    Quit ..Answer(.pCounts)
}

ClassMethod VendorExport(pFile As %String, pName As %String, Output pCounts) As %Status [ Private ]
{
    Kill pCounts
    Set ^||OcuPilotTransferCalls($Increment(^||OcuPilotTransferCalls)) = "export|" _ pFile _ "|" _ ##class(%File).Exists(pFile) _ "|" _ ##class(%File).GetDirectory(pFile) _ "|" _ ##class(%File).DirectoryExists(##class(%File).GetDirectory(pFile))
    Set tSC = ..Answer(.pCounts)
    If $$$ISOK(tSC) {
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Do tStream.LinkToFile(pFile)
        Do tStream.Write("<LocalesDeepExport/>")
        Do tStream.%Save()
    }
    Quit tSC
}

/// <p>The answer <method>Mode</method> names, with one locale counted.</p>
ClassMethod Answer(Output pCounts) As %Status [ Private ]
{
    Set tMode = $Get(^||OcuPilotTransferMode, "ok")
    If tMode = "throw" {
        Set tZero = 0
        Set tNever = 1 / tZero
    }
    Set pCounts("Locales") = 1
    Set pCounts("Tables") = 0
    Set pCounts("SubTables") = 0
    If tMode = "error" Quit $$$ERROR($$$GeneralError, "a vendor refusal fed by the test, with value: yqfilevalue")
    Quit $$$OK
}

}
