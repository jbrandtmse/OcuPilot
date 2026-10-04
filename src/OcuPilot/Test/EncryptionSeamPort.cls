/// <p>Test-only <class>OcuPilot.Port.EncryptionPort</class> subclass: Story 18.7's seam. Every vendor
/// call the port makes through <method>Call</method> is recorded, in order, in
/// <code>^||OcuPilotEncryptionSeam</code> with its body's key names and never a value, and then sent to
/// the vendor.</p>
/// <p>Armed with a key id (<method>Arm</method>), a read through <method>Invoke</method> answers as if the
/// instance depended on that key, without any database being encrypted: <code>protected</code> reads
/// OcuPilot's own database as encrypted with it and <code>system</code> IRISSYS, each in the instance's
/// own <code>Database.SysCRUD</code> <code>LIST</code> rows; <code>journal</code> answers it as
/// <code>Security.Encryption.Settings</code>' <code>DBEncJournalKeyID</code>; and <code>readfails</code>
/// fails the <code>Database.SysCRUD</code> <code>LIST</code> read.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EncryptionSeamPort Extends OcuPilot.Port.EncryptionPort
{

ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pLocation As %String) As %Status
{
    Set tPair = pEndpoint _ "/" _ pType
    Set tIndex = $Increment(^||OcuPilotEncryptionSeam("calls"))
    Set ^||OcuPilotEncryptionSeam("calls", tIndex) = tPair
    Set tKeys = ""
    If $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
        Set tIterator = pBody.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tNames(tKey) = ""
        }
        Set tKey = ""
        For {
            Set tKey = $Order(tNames(tKey))
            If tKey = "" Quit
            Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
        }
    }
    Set ^||OcuPilotEncryptionSeam("keys", tPair) = tKeys
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .pLocation)
}

/// <p>The encryption port's call, with the reads <method>Arm</method> armed answered as armed.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tMode = $Get(^||OcuPilotEncryptionSeam("mode"))
    Set tDatabases = (pEndpoint = "Database.SysCRUD") && (pType = "LIST")
    If tDatabases && (tMode = "readfails") {
        Set pResult = ""
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Quit $$$ERROR($$$GeneralError, "the database list fails, as the seam was armed")
    }
    Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) || '$IsObject($Get(pResult)) Quit tSC
    If (tMode = "journal") && (pEndpoint = "Security.Encryption.Settings") && (pType = "GET") {
        Do pResult.%Set("DBEncJournalKeyID", $Get(^||OcuPilotEncryptionSeam("key")), "string")
        Quit tSC
    }
    If 'tDatabases || ((tMode '= "protected") && (tMode '= "system")) Quit tSC
    Set tDirectory = ..DirectoryOf($Select(tMode = "system": "IRISSYS", 1: ##class(OcuPilot.Kernel.State.Base).#DATABASENAME))
    Set tIterator = pResult.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || '##class(OcuPilot.Port.DatabasePort).SameDirectory(tRow.%Get("Directory"), tDirectory) Continue
        Do tRow.%Set("Encrypted", 1, "boolean")
        Do tRow.%Set("EncryptionKeyID", $Get(^||OcuPilotEncryptionSeam("key")), "string")
    }
    Quit tSC
}

/// <p>The directory of database <var>pName</var>, read in <code>%SYS</code>.</p>
ClassMethod DirectoryOf(pName As %String) As %String
{
    Set tDirectory = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Config.Databases).Get(pName, .tProps)) Set tDirectory = $Get(tProps("Directory"))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tDirectory
}

/// <p>Arm <var>pMode</var> (<code>protected</code>, <code>system</code>, <code>journal</code>,
/// <code>readfails</code>, or <code>""</code> for none) with key
/// <var>pKey</var>.</p>
ClassMethod Arm(pMode As %String, pKey As %String = "")
{
    Set ^||OcuPilotEncryptionSeam("mode") = pMode
    Set ^||OcuPilotEncryptionSeam("key") = pKey
}

/// <p>Forget every recorded call and the armed mode.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotEncryptionSeam
}

/// <p>The recorded calls, comma-joined in order.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotEncryptionSeam("calls")) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $Get(^||OcuPilotEncryptionSeam("calls", tI))
    }
    Quit tOut
}

/// <p>The recorded calls other than lists, comma-joined.</p>
ClassMethod Writes() As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(^||OcuPilotEncryptionSeam("calls")) {
        Set tPair = $Get(^||OcuPilotEncryptionSeam("calls", tI))
        If $Piece(tPair, "/", 2) = "LIST" Continue
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tPair
    }
    Quit tOut
}

/// <p>The body key names the last <var>pPair</var> call carried, sorted and comma-joined.</p>
ClassMethod KeysOf(pPair As %String) As %String
{
    Quit $Get(^||OcuPilotEncryptionSeam("keys", pPair))
}

}
