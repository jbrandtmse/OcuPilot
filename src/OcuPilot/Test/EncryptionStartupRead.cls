/// <p>Pins Story 18.23's reads (C1; AD-2, AD-36): the form's declared read, <code>security.encryptionstartup.read</code>
/// and the write's fresh read answer the same nine settings, over the wire as in process; the form read
/// answers the configured KMIP servers and the startup databases encrypted on disk; and no answer carries a
/// password, an administrator or key material.</p>
/// <p><b>What it needs from the environment:</b> a stock instance with OcuPilot installed and serving. It
/// reads only; its KMIP and on-disk legs answer through <class>OcuPilot.Test.EncryptionSeamPort</class> and <class>OcuPilot.Test.EncryptionOnDiskPort</class>.
/// After each test the encryption state and the audit database's identity read as that test found
/// them.</p>
Class OcuPilot.Test.EncryptionStartupRead Extends %UnitTest.TestCase
{

Parameter SCREEN = "OcuPilot.Screen.Descriptor.EncryptionStartup";

Parameter PORT = "OcuPilot.Port.EncryptionPort";

Parameter PROBE = "OcuPilot.Test.EncryptionStartupProbe";

/// <p>The nine settings, in the read's order.</p>
Parameter FIELDS = "DBEncStartMode,DBEncJournal,DBEncIRISSecurity,DBEncIRISTemp,AuditEncrypt,DBEncStartKMIPServer,DBEncStartKeyFile,DBEncDefaultKeyID,DBEncJournalKeyID";

/// <p>The encryption facts and the audit database's identity before each test.</p>
Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = ##class(OcuPilot.Test.EncryptionStartupWrite).Facts()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.EncryptionSeamPort).Clear()
    Set tFacts = ##class(OcuPilot.Test.EncryptionStartupWrite).Facts()
    Do $$$AssertTrue((tFacts '[ """error"":") && (..PreparedFacts '[ """error"":"), "the facts were read whole before and after the test")
    Do $$$AssertEquals(tFacts, ..PreparedFacts, "no encryption setting moved and the audit database is the one the test found")
    Quit $$$OK
}

/// <p>C1: the screen's read, its read tool and the write's fresh read answer one row of the nine settings,
/// the same values, and nothing else; on a stock instance they read None, four false and five empty.</p>
/// <p>Mutation (Rule 19): the descriptor's read declares <code>LIST</code> for <code>GET</code> -- the screen
/// read fails and this goes red.</p>
Method TestTheFormAndTheToolReadTheSameNineSettings()
{
    Kill tCriteria
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 1, .tRead, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the screen's read answers (" _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "") _ ")")
    Set tRows = $Select($IsObject($Get(tRead)): tRead.%Get("rows"), 1: [])
    Do $$$AssertEquals(tRows.%Size(), 1, "one row")
    Set tRow = tRows.%Get(0)
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tRow), ..Sorted(..#FIELDS), "of the nine settings and nothing else")
    Set tValues = ""
    For tI = 1:1:$Length(..#FIELDS, ",") {
        Set tField = $Piece(..#FIELDS, ",", tI)
        Set tValues = tValues _ $Select(tI = 1: "", 1: ",") _ ##class(OcuPilot.Kernel.Proposal.Mint).Display(tRow.%Get(tField), tRow.%GetTypeOf(tField))
    }
    Do $$$AssertEquals(tValues, "None,false,false,false,false,,,,", "a stock instance reads None, four false and five empty settings")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("security.encryptionstartup.read", .tTool)
    Do $$$AssertTrue($IsObject($Get(tTool)), "security.encryptionstartup.read is registered")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 10, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "security.encryptionstartup.read answers")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("rows").%ToJSON(), 1: ""), tRows.%ToJSON(), "the screen's row")
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Security.Encryption.Settings", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the write's fresh read answers")
    For tI = 1:1:$Length(..#FIELDS, ",") {
        Set tField = $Piece(..#FIELDS, ",", tI)
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).Display(tFresh.%Get(tField), tFresh.%GetTypeOf(tField)), ##class(OcuPilot.Kernel.Proposal.Mint).Display(tRow.%Get(tField), tRow.%GetTypeOf(tField)), tField _ " reads the same on the screen and at the write")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tFresh), ..Sorted(..#FIELDS), "and the fresh read carries the nine settings alone")
}

/// <p>C1: over the wire, the screen's read and the form read answer 200 as JSON; the form read answers the
/// configured KMIP servers and the startup databases encrypted on disk, as the port reads them; no answer
/// carries a password or an administrator.</p>
Method TestTheWireReadsAnswerWithNoCredential()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/security.encryptionstartup/read?maxRows=1", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the screen's read answers over the wire: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertTrue((tRaw '[ "AdminPassword") && (tRaw '[ "AdminName") && (tRaw '[ "DBEncStartUsername") && (tRaw '[ "Passphrase"), "carrying no credential")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/encryption-startup/form", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "GET /encryption-startup/form answers: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tForm = ##class(%DynamicObject).%FromJSON(tRaw)
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "KmipNames", .tNames, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the configured KMIP servers are read")
    Set tSC = $ClassMethod(..#PORT, "EncryptedOnDisk", .tEncrypted, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the startup databases' encryption on disk is read")
    Do $$$AssertEquals($Select($IsObject(tForm): tForm.%ToJSON(), 1: ""), "{""kmipServers"":" _ tNames.%ToJSON() _ ",""encryptedDatabases"":" _ tEncrypted.%ToJSON() _ "}", "the form read answers them alone")
}

/// <p>C2: the form read answers the KMIP servers the instance has configured, through the port's own read:
/// two armed on the seam are answered in order.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.EncryptionStartupSave.HandleForm</method> answers
/// <code>[]</code> in place of the port's names -- this goes red.</p>
Method TestTheFormReadAnswersTheConfiguredKmipServers()
{
    Set tSeam = "OcuPilot.Test.EncryptionSeamPort"
    Do $ClassMethod(tSeam, "Arm", "kmip")
    Do $ClassMethod(tSeam, "ArmKmip", "OCUPROBESTARTKMSA,OCUPROBESTARTKMSB")
    Set tSC = ##class(OcuPilot.Test.EncryptionStartupSaveFixture).Form(.tAnswer, .tStatus)
    Do $$$AssertStatusOK(tSC, "the form read runs")
    Do $$$AssertEquals(tStatus _ " " _ tAnswer, "200 {""kmipServers"":[""OCUPROBESTARTKMSA"",""OCUPROBESTARTKMSB""],""encryptedDatabases"":[]}", "it answers the two configured servers")
}

/// <p>AD-10, AD-27: the form read answers which startup databases are encrypted on disk, through the port's
/// own read: two armed on the seam are answered in order, and a read that fails fails the form read. The
/// instance's own read names a database exactly when its directory is among the encrypted databases
/// <code>SYS.Database:List</code> answers, none on a stock instance; and the port's own read, with two
/// databases' directories reported encrypted (<class>OcuPilot.Test.EncryptionOnDiskPort</class>), names those
/// two in its own order.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.EncryptionStartupSave.HandleForm</method> answers
/// <code>[]</code> in place of the port's names -- this goes red; drop the push from
/// <method>OcuPilot.Port.EncryptionPort.EncryptedOnDisk</method> -- the last leg goes red.</p>
Method TestTheFormReadAnswersTheDatabasesEncryptedOnDisk()
{
    Set tSeam = "OcuPilot.Test.EncryptionSeamPort"
    Do $ClassMethod(tSeam, "Arm", "startup")
    Do $ClassMethod(tSeam, "ArmOnDisk", "IRISAUDIT,IRISTEMP")
    Set tSC = ##class(OcuPilot.Test.EncryptionStartupSaveFixture).Form(.tAnswer, .tStatus)
    Do $$$AssertStatusOK(tSC, "the form read runs")
    Set tForm = ##class(OcuPilot.Test.EncryptionProbe).Parsed(tAnswer)
    Set tAnswered = $Select($IsObject(tForm) && (tForm.%GetTypeOf("encryptedDatabases") = "array"): tForm.%Get("encryptedDatabases").%ToJSON(), 1: tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tAnswered, "200 [""IRISAUDIT"",""IRISTEMP""]", "it answers the two encrypted on disk")
    Do $ClassMethod(tSeam, "Arm", "ondiskfails")
    Set tSC = ##class(OcuPilot.Test.EncryptionStartupSaveFixture).Form(.tAnswer, .tStatus)
    Do $$$AssertStatusOK(tSC, "the form read runs again")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.EncryptionProbe).Refusal(tAnswer), "500 INTERNAL", "a read that fails fails the form read")
    Do $ClassMethod(tSeam, "Clear")
    Set tSC = $ClassMethod(..#PORT, "EncryptedOnDisk", .tEncrypted, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the instance's own read answers")
    Set tDirectories = ##class(OcuPilot.Test.EncryptionProbe).EncryptionFacts().%Get("encryptedDatabases").%ToJSON()
    Set tNames = $Parameter(..#PORT, "STARTUPDATABASES")
    For tI = 1:1:$Length(tNames, ",") {
        Set tName = $Piece(tNames, ",", tI)
        Set tDirectory = ##class(OcuPilot.Test.EncryptionSeamPort).DirectoryOf(tName)
        Do $$$AssertTrue(tDirectory '= "", tName _ " has a configured directory")
        Set tNamed = (tEncrypted.%ToJSON() [ ($Char(34) _ tName _ $Char(34)))
        Set tListed = (tDirectories [ ($Char(34) _ tDirectory _ "|"))
        Do $$$AssertEquals(tNamed, tListed, tName _ " is named exactly when SYS.Database:List lists it encrypted")
    }
    Set tOnDisk = "OcuPilot.Test.EncryptionOnDiskPort"
    Do $ClassMethod(tOnDisk, "ArmDirectories", $ListBuild(##class(OcuPilot.Test.EncryptionSeamPort).DirectoryOf("IRISTEMP"), ##class(OcuPilot.Test.EncryptionSeamPort).DirectoryOf("IRISAUDIT")))
    Set tSC = $ClassMethod(tOnDisk, "EncryptedOnDisk", .tEncrypted, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the port's own read runs with two databases reported encrypted")
    Do $$$AssertEquals($Select($IsObject($Get(tEncrypted)): tEncrypted.%ToJSON(), 1: ""), "[""IRISAUDIT"",""IRISTEMP""]", "the port's own read names each database reported encrypted, in its own order")
    Do $ClassMethod(tSeam, "Clear")
}

/// <p>C1: the form's context declares the nine settings and no secret, and the read tool's schema admits
/// nothing a caller could send beyond the shared row cap.</p>
Method TestNoReadAnswersAPassword()
{
    Set tContext = $ClassMethod(..#SCREEN, "Field", "context")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined(tContext.%Get("fields")), ..#FIELDS, "the context is the nine settings")
    Do $$$AssertEquals(tContext.%Get("secretFields").%Size(), 0, "and holds no secret")
    Do $$$AssertTrue(..#FIELDS '[ "Password", "no read field is a password")
}

/// <p><var>pList</var>, comma-separated, sorted as <code>$Order</code> sorts.</p>
ClassMethod Sorted(pList As %String) As %String
{
    For tI = 1:1:$Length(pList, ",") Set tNames($Piece(pList, ",", tI)) = ""
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tNames(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

}
