/// <p>Pins Story 18.48's encrypted database create (DW-2085; AD-10, AD-52, AD-55): <code>Encrypted</code> is the create
/// tool's sixth argument, refused <code>DATABASE.ENCRYPT.NOKEY</code> on its field while no database encryption key is
/// the default -- on the screen's Save, at the agent's mint, in the step check and at the port -- the form read answers
/// the default key's id or <code>""</code>, the file's body carries <code>Encrypted</code> and that key's id only for an
/// encrypted create, and a create over an active key makes a database that reads encrypted with that key.</p>
/// <p><b>The live leg activates a probe key and restores the instance without a restart.</b> It creates a probe key
/// file, activates its key through <class>OcuPilot.Port.EncryptionPort</class> (which sets key activation at startup to
/// Interactive), creates one database over it, and then, on every path (<method>Cleanup</method>), deletes the database,
/// its configuration and its resource, deactivates the probe key, puts the default and journal key ids back and sets key
/// activation at startup to None through the settings <code>PUT</code>; the test asserts the encryption facts read as it
/// found them.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the manager directory among the allowed
/// directories, no database encryption key active (the no-key legs read the real form route and the real port), and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the live leg activates an encryption key and
/// creates a database on this instance. It runs on a throwaway container only.</p>
Class OcuPilot.Test.DatabaseCreateEncrypted Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ENCRYPTION_CONFIG";

Parameter PROBE = "OcuPilot.Test.EncryptionKeyProbe";

Parameter WRITE = "OcuPilot.Test.DatabaseWrite";

Parameter PORT = "OcuPilot.Port.DatabasePort";

Parameter NOKEYPORT = "OcuPilot.Test.DatabaseNoKeyPort";

Parameter RULES = "OcuPilot.Test.DatabaseRulesFixture";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseCreate";

/// <p>The probe database's name and its folder under the probe directory.</p>
Parameter NAME = "OCUPROBEACTENC";

Parameter FOLDER = "dbenc";

Parameter FORMPATH = "/database/form";

Parameter CHECKPATH = "/database/check";

/// <p>The encryption facts before each test.</p>
Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If '..Armed() {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DatabaseCreateEncrypted activates an encryption key and creates a database on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ..Cleanup("")
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "EncryptionFacts").%ToJSON()
    Kill ^||OcuPilotDatabaseRulesPort, ^||OcuPilotDatabaseWritePort
    Quit $ClassMethod(..#PROBE, "SeedDirectory", .tCreated)
}

Method OnAfterOneTest() As %Status
{
    If '..Armed() Quit $$$OK
    Kill ^||OcuPilotDatabaseRulesPort, ^||OcuPilotDatabaseWritePort
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Do $$$AssertEquals(tSeeded, 0, "the turns and proposals the mints seeded are removed")
    Do $$$AssertStatusOK(..Cleanup(..PreparedFacts), "the probe database, key and directory are removed and the key state is restored")
    Set tFacts = $ClassMethod(..#PROBE, "EncryptionFacts")
    Do $$$AssertTrue('tFacts.%IsDefined("error") && (..PreparedFacts '[ """error"":"), "the encryption facts were read whole before and after the test")
    Do $$$AssertEquals(tFacts.%ToJSON(), ..PreparedFacts, "no key is active and no encryption setting moved")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If '..Armed() Quit $$$OK
    Quit ..Cleanup("")
}

/// <p>Whether <parameter>ARMINGVARIABLE</parameter> reads <code>1</code>: only an armed run creates anything, so only an
/// armed run cleans up.</p>
ClassMethod Armed() As %Boolean
{
    Quit ($System.Util.GetEnviron(..#ARMINGVARIABLE) = 1)
}

/// <p>Refuse, with nothing created: a create asking for an encrypted database while the instance's keys hold no
/// default is 422 <code>DATABASE.ENCRYPT.NOKEY</code> on <code>Encrypted</code> at the port (which names no resource and
/// no file), on the screen's Save, in the step check, in the rules and at the agent's mint, each with the published
/// sentence; the form read answers an empty key id; and an unencrypted create is not refused. The instance holds no
/// key here, and the port seam finds none whatever it holds.</p>
/// <p>Mutation (Rule 19): drop the <code>ENCRYPTNOKEY</code> refusal from
/// <method>OcuPilot.Port.DatabasePort.Create</method> -- the port legs create and go red; from
/// <method>OcuPilot.Area.OsMgmt.DatabaseRules.Validate</method> -- the Save, step, rules and mint legs go red.</p>
Method TestAnEncryptedCreateIsRefusedWhileNoKeyIsActive()
{
    Set tP = ..#PROBE
    Set tRoot = $ClassMethod(tP, "Root")
    Set tPath = $ClassMethod(tP, "RelativeName", ..#FOLDER)
    Set tReason = ##class(OcuPilot.Api.DatabaseError).#REASONENCRYPTNOKEY
    Do $$$AssertEquals($ClassMethod(tP, "EncryptionFacts").%Get("activeKeys"), "", "the instance holds no active key")
    For tPort = ..#PORT, ..#NOKEYPORT {
        Kill tQuery
        Set tQuery("name") = ..#NAME
        Set tQuery("root") = tRoot
        Set tQuery("path") = tPath
        Set tQuery("Encrypted") = 1
        Set tSC = $ClassMethod(tPort, "Invoke", "Database.ConfigCRUD", "PUT", .tQuery, {}, .tResult, .tHttp, .tFault)
        Set tViolation = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("violations").%Get(0), 1: "")
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tViolation): tViolation.%Get("field") _ ":" _ tViolation.%Get("code") _ ":" _ tViolation.%Get("reason"), 1: ""), "422 Encrypted:DATABASE.ENCRYPT.NOKEY:" _ tReason, tPort _ ": the port refuses it on the field with the sentence")
        Do $$$AssertTrue('##class(%File).DirectoryExists(tRoot _ tPath), tPort _ ": and creates no directory")
        Do $$$AssertEquals(..ResourceHeld("%DB_" _ ..#NAME), 0, tPort _ ": or resource")
    }
    Set tSC = $ClassMethod(..#WRITE, "Save", "create", ..#NAME, {"Name": (..#NAME), "root": (tRoot), "path": (tPath), "Encrypted": true}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Encrypted:DATABASE.ENCRYPT.NOKEY", "the screen's Save refuses it on the field")
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..#CREATETOOL, ..#NAME, {"Name": (..#NAME), "root": (tRoot), "path": (tPath), "Encrypted": true}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "the agent's mint is refused")
    Do $$$AssertTrue(tProblem [ ("'Encrypted': " _ tReason), "naming the field and the published sentence: " _ tProblem)
    Set ^||OcuPilotDatabaseRulesPort = ..#NOKEYPORT
    Set tSC = $ClassMethod(..#RULES, "Validate", ..#NAME, {"root": (tRoot), "path": (tPath), "Encrypted": true}, .tViolations, "create", 0, "", .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ +$Get(tViolations) _ " " _ $Select(+$Get(tViolations): $List(tViolations(1), 1) _ ":" _ $List(tViolations(1), 2), 1: ""), "1 1 Encrypted:DATABASE.ENCRYPT.NOKEY", "the rules refuse it, whatever port answers the keys")
    Set tSC = $ClassMethod(..#RULES, "Validate", ..#NAME, {"root": (tRoot), "path": (tPath), "Encrypted": false}, .tViolations, "create", 0, "", .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ +$Get(tViolations), "1 0", "and an unencrypted create is not refused")
    Set tSC = $ClassMethod(..#RULES, "Validate", ..#NAME, {"Size": 1}, .tViolations, "create", 0, $ListBuild("Size", "GlobalJournalState", "Encrypted"), .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ +$Get(tViolations), "1 0", "the size step, which checks the flag, finds none asked")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CHECKPATH, tUser, tPassword, .tStatus, .tRaw, .tHeaders, {"step": "size", "values": {"Size": 1, "Encrypted": true}}.%ToJSON(), "application/json")
    Set tAnswer = ##class(OcuPilot.Test.EncryptionProbe).Parsed(tRaw)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer) && (tAnswer.%GetTypeOf("violations") = "array") && (tAnswer.violations.%Size() > 0): tAnswer.violations.%Get(0).field _ ":" _ tAnswer.violations.%Get(0).code, 1: ""), "200 Encrypted:DATABASE.ENCRYPT.NOKEY", "the step check answers it on the field: " _ $Extract(tRaw, 1, 200))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#FORMPATH, tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Set tAnswer = ##class(OcuPilot.Test.EncryptionProbe).Parsed(tRaw)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%GetTypeOf("EncryptionKeyID") _ "|" _ tAnswer.%Get("EncryptionKeyID"), 1: ""), "200 string|", "the form read answers an empty key id: " _ $Extract(tRaw, 1, 200))
}

/// <p>The file's body: <code>{Directory, Size, GlobalJournalState, ResourceName}</code> as ever for a create that asks
/// for no encryption -- with or without the flag -- and, for one that does, those four with <code>Encrypted</code> true
/// and <code>EncryptionKeyID</code> the key id handed over.</p>
/// <p>Mutation (Rule 19): drop <code>Encrypted</code> from <method>OcuPilot.Port.DatabasePort.FileBody</method> -- the
/// encrypted body goes red here, and the live leg reads an unencrypted database.</p>
Method TestTheFileBodyCarriesTheFlagAndTheKeyOnlyForAnEncryptedCreate()
{
    Set tPort = ..#PORT
    Kill tQuery
    Set tBody = $ClassMethod(tPort, "FileBody", "/d/", .tQuery, "%DB_X", "")
    Do $$$AssertEquals(..Keys(tBody), "Directory,GlobalJournalState,ResourceName,Size", "no flag: the four")
    Set tQuery("Encrypted") = 0
    Set tBody = $ClassMethod(tPort, "FileBody", "/d/", .tQuery, "%DB_X", "")
    Do $$$AssertEquals(..Keys(tBody), "Directory,GlobalJournalState,ResourceName,Size", "the flag off: the four")
    Set tQuery("Encrypted") = 1
    Set tBody = $ClassMethod(tPort, "FileBody", "/d/", .tQuery, "%DB_X", "KEY-1")
    Do $$$AssertEquals(..Keys(tBody), "Directory,Encrypted,EncryptionKeyID,GlobalJournalState,ResourceName,Size", "the flag on: the four, the flag and the key id")
    Do $$$AssertEquals(tBody.%Get("Encrypted") _ " " _ tBody.%GetTypeOf("Encrypted") _ " " _ tBody.%Get("EncryptionKeyID"), "1 boolean KEY-1", "true, and the key handed over")
}

/// <p>The live leg: over an active probe key, the form read answers the key's id, an encrypted create through the
/// screen's Save is 201, and the database reads encrypted with that key on the instance
/// (<code>SYS.Database</code>); and the agent's mint of the same create is accepted and its card shows the flag.</p>
/// <p>Mutation (Rule 19): drop <code>Encrypted</code> from <method>OcuPilot.Port.DatabasePort.FileBody</method> -- the
/// database reads unencrypted and this goes red; send an empty key id -- the key leg goes red.</p>
Method TestAnEncryptedCreateMakesADatabaseEncryptedWithTheDefaultKey()
{
    Set tP = ..#PROBE
    Set tRoot = $ClassMethod(tP, "Root")
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "live.key", , , 256, "OCUPROBEACT LIVE", .tKey), "a probe key file")
    Kill tQuery
    Set tQuery("keyfile") = $ClassMethod(tP, "KeyFileId", "live.key")
    Set tQuery("Action") = "ActivateDB"
    Set tQuery("AdminName") = $Parameter(tP, "ADMIN")
    Set tSC = ##class(OcuPilot.Port.EncryptionPort).Invoke("Security.Encryption.File", "ACTIVATE", .tQuery, {"AdminPassword": ($Parameter(tP, "PASSWORD"))}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ tHttp, "1 200", "the probe key is activated")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#FORMPATH, tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Set tAnswer = ##class(OcuPilot.Test.EncryptionProbe).Parsed(tRaw)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("EncryptionKeyID"), 1: ""), "200 " _ tKey, "the form read answers the default key's id: " _ $Extract(tRaw, 1, 200))
    Set tPath = $ClassMethod(tP, "RelativeName", ..#FOLDER)
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..#CREATETOOL, ..#NAME, {"Name": (..#NAME), "root": (tRoot), "path": (tPath), "Encrypted": true}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's encrypted create is minted (" _ tProblem _ ")")
    Set tRow = ""
    If $IsObject($Get(tProposal)) {
        Set tIterator = tProposal.%Get("changed").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            If tField.%Get("field") = "Encrypted" Set tRow = tField.%Get("after")
        }
    }
    Do $$$AssertEquals(tRow, "true", "its card shows the flag")
    Set tSC = $ClassMethod(..#WRITE, "Save", "create", ..#NAME, {"Name": (..#NAME), "root": (tRoot), "path": (tPath), "Encrypted": true}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "201 ", "the screen's encrypted create answers 201")
    Set tDirectory = $ClassMethod(tP, "Root") _ tPath _ "/"
    Set tFacts = $ClassMethod(tP, "EncryptionFacts")
    Set tFound = ""
    Set tIterator = tFacts.%Get("encryptedDatabases").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If $ZConvert($Piece(tEntry, "|", 1), "L") = $ZConvert(##class(%File).NormalizeDirectory(tDirectory), "L") Set tFound = $Piece(tEntry, "|", 2)
    }
    Do $$$AssertEquals(tFound, tKey, "the new database reads encrypted with the default key: " _ tFacts.%Get("encryptedDatabases").%ToJSON())
}

/// <p>Delete the probe database -- configuration, file and resource -- deactivate the probe key, put the default and
/// journal key ids back as <var>pFactsJson</var> held them and set key activation at startup to None when a key activation
/// moved it, then remove the probe objects. Nothing is removed from disk while the database is still configured, so a
/// failed delete leaves a database the instance still holds in a directory that is still there. <var>pFactsJson</var>
/// <code>""</code> restores no key ids and leaves the start mode alone.</p>
ClassMethod Cleanup(pFactsJson As %String) As %Status
{
    Set tP = ..#PROBE
    Set tSC = $$$OK
    Kill tQuery
    Set tQuery("name") = ..#NAME
    Set tHeld = $ClassMethod(..#PORT, "Invoke", "Database.ConfigCRUD", "GET", .tQuery, "", .tConfig, .tHttp, .tFault)
    If $$$ISOK(tHeld) {
        Kill tQuery
        Set tQuery("name") = ..#NAME
        Set tQuery("DeleteFile") = 1
        Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PORT, "Invoke", "Database.ConfigCRUD", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault))
    }
    If ..ResourceHeld("%DB_" _ ..#NAME) {
        Kill tQuery
        Set tQuery("name") = "%DB_" _ ..#NAME
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Port.AdminPort).Invoke("Security.Resource", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault))
    }
    Set tFacts = ""
    If pFactsJson '= "" Set tFacts = ##class(%DynamicObject).%FromJSON(pFactsJson)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tP, "Restore", tFacts, .tDone))
    If $IsObject(tFacts) && (tFacts.%Get("DBEncStartMode") = 0) && ($ClassMethod(tP, "EncryptionFacts").%Get("DBEncStartMode") '= 0) {
        Kill tQuery
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Port.EncryptionPort).Invoke("Security.Encryption.Settings", "PUT", .tQuery, {"DBEncStartMode": "None"}, .tResult, .tHttp, .tFault))
    }
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(tP, "RemoveAll", .tRemaining)
}

/// <p>Whether the instance holds resource <var>pName</var>.</p>
ClassMethod ResourceHeld(pName As %String) As %Boolean
{
    Kill tQuery
    Set tQuery("name") = pName
    Quit $$$ISOK(##class(OcuPilot.Port.AdminPort).Invoke("Security.Resource", "GET", .tQuery, "", .tResource, .tHttp, .tFault))
}

/// <p>The key names of <var>pObject</var>, sorted and comma-joined.</p>
ClassMethod Keys(pObject As %DynamicObject) As %String
{
    Kill tNames
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tNames(tKey) = ""
    }
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
