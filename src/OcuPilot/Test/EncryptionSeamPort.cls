/// <p>Test-only <class>OcuPilot.Port.EncryptionPort</class> subclass: Story 18.7's seam. Every vendor
/// call the port makes through <method>Call</method> is recorded, in order, in
/// <code>^||OcuPilotEncryptionSeam</code> with its body's key names and never a value, and then sent to
/// the vendor.</p>
/// <p>Armed with a key id (<method>Arm</method>), a read through <method>Invoke</method> answers as if the
/// instance depended on that key, without any database being encrypted, naming the key lower-cased and in
/// braces rather than as the key file lists it: <code>protected</code> reads
/// OcuPilot's own database as encrypted with it, <code>system</code> IRISSYS and <code>namespace</code>
/// the install namespace's globals database, each in the instance's own <code>Database.SysCRUD</code>
/// <code>LIST</code> rows; <code>unreadable</code> reads OcuPilot's own database as encrypted with no key
/// id; <code>other</code> reads the first database that is none of OcuPilot's or the instance's own as
/// encrypted with the key, recording its directory (<method>Armed</method>); <code>journal</code> answers
/// the key as <code>Security.Encryption.Settings</code>' <code>DBEncJournalKeyID</code>; and
/// <code>readfails</code>, <code>namesfail</code>, <code>dirsfail</code> and <code>settingsfail</code>
/// fail the <code>Database.SysCRUD</code> <code>LIST</code>, <code>Namespace.Namespace</code>
/// <code>GET</code>, <code>Database.ConfigCRUD</code> <code>LIST</code> and
/// <code>Security.Encryption.Settings</code> <code>GET</code> read. Armed <code>keysfail</code>,
/// <method>Call</method> answers a key file's key list with a 500 that is not the vendor's, without the
/// vendor.</p>
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
    If ($Get(^||OcuPilotEncryptionSeam("mode")) = "keysfail") && (tPair = "Security.Encryption.KeyInFile/LIST") {
        Set pResult = ""
        Set pLocation = ""
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Quit $$$ERROR($$$GeneralError, "the key list fails, as the seam was armed")
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .pLocation)
}

/// <p>The encryption port's call, with the reads <method>Arm</method> armed answered as armed.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tMode = $Get(^||OcuPilotEncryptionSeam("mode"))
    Set tDatabases = (pEndpoint = "Database.SysCRUD") && (pType = "LIST")
    Set tFails = $Case(tMode, "readfails": "Database.SysCRUD/LIST", "namesfail": "Namespace.Namespace/GET", "dirsfail": "Database.ConfigCRUD/LIST", "settingsfail": "Security.Encryption.Settings/GET", : "")
    If (tFails '= "") && (tFails = (pEndpoint _ "/" _ pType)) {
        Set pResult = ""
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Quit $$$ERROR($$$GeneralError, tFails _ " fails, as the seam was armed")
    }
    Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) || '$IsObject($Get(pResult)) Quit tSC
    Set tKey = "{" _ $ZConvert($Get(^||OcuPilotEncryptionSeam("key")), "L") _ "}"
    If (tMode = "journal") && (pEndpoint = "Security.Encryption.Settings") && (pType = "GET") {
        Do pResult.%Set("DBEncJournalKeyID", tKey, "string")
        Quit tSC
    }
    If 'tDatabases || '$ListFind($ListBuild("protected", "system", "namespace", "unreadable", "other"), tMode) Quit tSC
    Set tOwn = ..OwnDirectories()
    Set tDirectory = $Case(tMode, "system": ..DirectoryOf("IRISSYS"), "namespace": ..DirectoryOf(..GlobalsOf($NAMESPACE)), "other": "", : ..DirectoryOf(##class(OcuPilot.Kernel.State.Base).#DATABASENAME))
    Set tIterator = pResult.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If tMode = "other" {
            If ..Within(tOwn, tRow.%Get("Directory")) || ($Get(^||OcuPilotEncryptionSeam("armed")) '= "") Continue
            Set ^||OcuPilotEncryptionSeam("armed") = tRow.%Get("Directory")
        } ElseIf '##class(OcuPilot.Port.DatabasePort).SameDirectory(tRow.%Get("Directory"), tDirectory) {
            Continue
        }
        Do tRow.%Set("Encrypted", 1, "boolean")
        If tMode = "unreadable" {
            Do tRow.%Remove("EncryptionKeyID")
        } Else {
            Do tRow.%Set("EncryptionKeyID", tKey, "string")
        }
    }
    Quit tSC
}

/// <p>The directories of OcuPilot's own database, the seven protected databases and the install
/// namespace's globals and routines databases, read in <code>%SYS</code>.</p>
ClassMethod OwnDirectories() As %List
{
    Set tNames = $ListBuild(##class(OcuPilot.Kernel.State.Base).#DATABASENAME) _ $ListFromString($Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SYSTEMDATABASES")) _ $ListBuild(..GlobalsOf($NAMESPACE), ..RoutinesOf($NAMESPACE))
    Set tOut = ""
    For tI = 1:1:$ListLength(tNames) {
        Set tDirectory = ..DirectoryOf($List(tNames, tI))
        If tDirectory '= "" Set tOut = tOut _ $ListBuild(tDirectory)
    }
    Quit tOut
}

/// <p>Whether <var>pDirectory</var> is one of <var>pDirectories</var>.</p>
ClassMethod Within(pDirectories As %List, pDirectory As %String) As %Boolean
{
    Set tWithin = 0
    For tI = 1:1:$ListLength(pDirectories) {
        If ##class(OcuPilot.Port.DatabasePort).SameDirectory($List(pDirectories, tI), pDirectory) Set tWithin = 1 Quit
    }
    Quit tWithin
}

/// <p>The globals database of namespace <var>pNamespace</var>, read in <code>%SYS</code>.</p>
ClassMethod GlobalsOf(pNamespace As %String) As %String
{
    Quit ..NamespaceField(pNamespace, "Globals")
}

/// <p>The routines database of namespace <var>pNamespace</var>, read in <code>%SYS</code>.</p>
ClassMethod RoutinesOf(pNamespace As %String) As %String
{
    Quit ..NamespaceField(pNamespace, "Routines")
}

/// <p>Field <var>pField</var> of namespace <var>pNamespace</var>'s configuration, or <code>""</code>.</p>
ClassMethod NamespaceField(pNamespace As %String, pField As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Config.Namespaces).Get(pNamespace, .tProps)) Set tValue = $Get(tProps(pField))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tValue
}

/// <p>The directory the <code>other</code> mode armed, or <code>""</code>.</p>
ClassMethod Armed() As %String
{
    Quit $Get(^||OcuPilotEncryptionSeam("armed"))
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

/// <p>Arm <var>pMode</var> (one of the modes this class's header names, or <code>""</code> for none) with
/// key <var>pKey</var>.</p>
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
