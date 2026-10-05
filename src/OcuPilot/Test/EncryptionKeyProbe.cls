/// <p>Test-only helper for Story 18.22's encryption key suites: <class>OcuPilot.Test.EncryptionProbe</class>
/// under its own prefix, <parameter>PREFIX</parameter>, and its own directory under the manager directory,
/// so it shares no object with Story 18.7's suites. It inherits the encryption facts, the snapshot, the
/// diff, the timed port call and <method>RunAs</method>, and adds what activating a key needs: a second
/// key in a probe key file, a probe database encrypted with a probe key, the probe keys the instance holds
/// active, and <method>Restore</method>, which deactivates every active probe key and puts the instance's
/// default and journal keys back as a snapshot found them, in <code>%SYS</code>, test-only.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EncryptionKeyProbe Extends OcuPilot.Test.EncryptionProbe
{

Parameter PREFIX = "OCUPROBEACT";

Parameter DIRECTORYNAME = "ocuprobeact";

Parameter MARKER = "OCUPROBEACT.marker";

Parameter PRINCIPAL = "OcuProbeActT0User";

Parameter PRINCIPALROLE = "OcuProbeActT0Role";

Parameter ADMIN = "OcuProbeActAdmin";

Parameter PASSWORD = "OcuProbeAct-Pass1";

/// <p>The <class>Security.System</class> properties a first database key activation sets and
/// <method>Restore</method> puts back (measured at Story 18.22's Task 0).</p>
Parameter RESTOREDPROPERTIES = "DBEncStartMode,DBEncDefaultKeyID,DBEncJournalKeyID";

/// <p>The probe database's folder under the probe directory.</p>
Parameter DATABASEFOLDER = "db";

/// <p>The probe database's folder, with its trailing separator.</p>
ClassMethod DatabaseDirectory() As %String
{
    Quit ##class(%File).NormalizeDirectory(..Directory() _ ..#DATABASEFOLDER)
}

/// <p>Add one key of <var>pKeyLen</var> bits to probe key file <var>pName</var> through the vendor's own
/// routine in <code>%SYS</code>, as administrator <var>pAdmin</var>; <var>pKeyId</var> is the new key's
/// identifier, read as the one the file's key list gained.</p>
ClassMethod AddKeyToFile(pName As %String, pKeyLen As %Integer = 256, Output pKeyId As %String, pAdmin As %String = {..#ADMIN}, pPassword As %String = {..#PASSWORD}) As %Status
{
    Set pKeyId = ""
    If '..NameAdmitted(pName) || '##class(%File).Exists(..Directory() _ ..#MARKER) Quit $$$ERROR($$$GeneralError, "only a probe file is changed")
    Set tPath = ..FilePath(pName)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tBefore = $$KeyList^EncryptionKey(tPath, .tListSC)
        Set tSC = $$KeyAdd^EncryptionKey(tPath, pAdmin, pPassword, "OCUPROBEACT added", pKeyLen \ 8)
        Set tAfter = $$KeyList^EncryptionKey(tPath, .tListSC)
        Set $NAMESPACE = tOrigNS
        For tI = 1:1:$Length(tAfter, ",") {
            Set tId = $Piece(tAfter, ",", tI)
            If (tId '= "") && '$ListFind($ListFromString(tBefore), tId) Set pKeyId = tId
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The identifiers of every key in every probe key file in the probe directory, as a
/// <class>%List</class>, read through the vendor's own routine in <code>%SYS</code>.</p>
ClassMethod ProbeKeyIds() As %List
{
    Set tIds = ""
    If '..DirectoryExists() Quit tIds
    Set tOrigNS = $NAMESPACE
    Try {
        Set tRS = ##class(%ResultSet).%New("%File:FileSet")
        If $$$ISOK(tRS.Execute(..Directory(), "*.key")) {
            While tRS.Next() {
                Set tPaths($Increment(tPaths)) = tRS.Get("Name")
            }
        }
        Set tRS = ""
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:+$Get(tPaths) {
            Set tList = $$KeyList^EncryptionKey(tPaths(tI), .tListSC)
            For tJ = 1:1:$Length(tList, ",") {
                Set tId = $Piece(tList, ",", tJ)
                If (tId '= "") && '$ListFind(tIds, tId) Set tIds = tIds _ $ListBuild(tId)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tIds
}

/// <p>The probe keys the instance holds active, as <code>{database: [id], dataElement: [id]}</code>:
/// each active key whose identifier a probe key file holds, or <var>pIds</var> when given.</p>
ClassMethod ActiveProbeKeys(pIds As %List = "") As %DynamicObject
{
    Set tIds = $Select(pIds = "": ..ProbeKeyIds(), 1: pIds)
    Set tOut = {"database": [], "dataElement": []}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDatabase = $SYSTEM.Security.System.GetDBEncKeyIDList()
        Set tElement = $SYSTEM.Security.System.GetMKEncKeyIDList()
        Set $NAMESPACE = tOrigNS
        For tI = 1:1:$Length(tDatabase, ",") {
            Set tId = $Piece(tDatabase, ",", tI)
            If (tId '= "") && $ListFind(tIds, tId) Do tOut.%Get("database").%Push(tId)
        }
        For tI = 1:1:$Length(tElement, ",") {
            Set tId = $Piece(tElement, ",", tI)
            If (tId '= "") && $ListFind(tIds, tId) Do tOut.%Get("dataElement").%Push(tId)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do tOut.%Set("error", ex.DisplayString(), "string")
    }
    Quit tOut
}

/// <p>Create the probe database in <method>DatabaseDirectory</method>, encrypted with active key
/// <var>pKeyId</var>, and mount it (test-only, through <class>SYS.Database</class> in <code>%SYS</code>).
/// The folder must not hold a database already.</p>
ClassMethod SeedEncryptedDatabase(pKeyId As %String, Output pDirectory As %String) As %Status
{
    Set pDirectory = ..DatabaseDirectory()
    If '##class(%File).Exists(..Directory() _ ..#MARKER) Quit $$$ERROR($$$GeneralError, "the probe directory is absent")
    If ##class(%File).Exists(pDirectory _ "IRIS.DAT") Quit $$$ERROR($$$GeneralError, "the probe database already exists")
    If '##class(%File).CreateDirectoryChain(pDirectory) Quit $$$ERROR($$$GeneralError, "the probe database folder could not be created")
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(SYS.Database).CreateDatabase(pDirectory, 1, 8192, 1, "%DB_%DEFAULT", , , , , , , , , 0, pKeyId)
        If $$$ISOK(tSC) && '##class(SYS.Database).%OpenId(pDirectory).Mounted Set tSC = ##class(SYS.Database).MountDatabase(pDirectory)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Dismount and delete the probe database when its folder holds one (test-only).</p>
ClassMethod RemoveDatabase() As %Status
{
    Set tDirectory = ..DatabaseDirectory()
    If '##class(%File).Exists(tDirectory _ "IRIS.DAT") Quit $$$OK
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDatabase = ##class(SYS.Database).%OpenId(tDirectory)
        If $IsObject(tDatabase) && tDatabase.Mounted Set tSC = ##class(SYS.Database).DismountDatabase(tDirectory)
        Set tDatabase = ""
        If $$$ISOK(tSC) Set tSC = ##class(SYS.Database).DeleteDatabase(tDirectory)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Put the instance's encryption state back after a probe (test-only, in <code>%SYS</code>):
/// deactivate every active probe key, data-element keys first, through the vendor's own routines, and
/// set each <parameter>RESTOREDPROPERTIES</parameter> member of <class>Security.System</class> that
/// differs to the value <var>pFacts</var> (an <method>EncryptionFacts</method> answer taken before)
/// holds, because a first database key activation sets them and no deactivation clears them (measured).
/// <var>pDone</var> lists what was changed.</p>
ClassMethod Restore(pFacts As %DynamicObject, Output pDone As %DynamicArray) As %Status
{
    Set pDone = []
    Set tSC = $$$OK
    Set tIds = ..ProbeKeyIds()
    Set tActive = ..ActiveProbeKeys(tIds)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tIterator = tActive.%Get("dataElement").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tId) {
            Set tOne = $$DeactivateMK^EncryptionKey(tId)
            Do pDone.%Push("DeactivateMK " _ tId _ " " _ $Select($$$ISOK(tOne): "ok", 1: $System.Status.GetErrorCodes(tOne)))
            Set tSC = $$$ADDSC(tSC, tOne)
        }
        ; The default key last, since the vendor refuses it while another key is active.
        Set tDefault = $SYSTEM.Security.System.GetDBEncKeyID()
        For tPass = 1, 2 {
            Set tIterator = tActive.%Get("database").%GetIterator()
            While tIterator.%GetNext(.tIndex, .tId) {
                If (tPass = 1) && (tId = tDefault) Continue
                If (tPass = 2) && (tId '= tDefault) Continue
                Set tOne = $$DeactivateDB^EncryptionKey(tId)
                Do pDone.%Push("DeactivateDB " _ tId _ " " _ $Select($$$ISOK(tOne): "ok", 1: $System.Status.GetErrorCodes(tOne)))
                Set tSC = $$$ADDSC(tSC, tOne)
            }
        }
        If $IsObject(pFacts) {
            Kill tProps
            Set tChanged = 0
            Set tSystem = ##class(Security.System).%OpenId("SYSTEM")
            For tI = 1:1:$Length(..#RESTOREDPROPERTIES, ",") {
                Set tName = $Piece(..#RESTOREDPROPERTIES, ",", tI)
                If ($Property(tSystem, tName) _ "") '= (pFacts.%Get(tName) _ "") {
                    Set tProps(tName) = pFacts.%Get(tName) _ ""
                    Set tChanged = 1
                }
            }
            Set tSystem = ""
            If tChanged {
                Set tOne = ##class(Security.System).Modify("SYSTEM", .tProps)
                Do pDone.%Push("Security.System.Modify " _ $Select($$$ISOK(tOne): "ok", 1: $System.Status.GetErrorCodes(tOne)))
                Set tSC = $$$ADDSC(tSC, tOne)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>Remove every probe object: the probe database, then the inherited users, roles and probe
/// directory.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set tSC = ..RemoveDatabase()
    Quit $$$ADDSC(tSC, ##super(.pRemaining))
}

}
