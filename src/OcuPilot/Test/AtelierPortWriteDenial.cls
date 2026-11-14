/// <p>Pins the routines database's WRITE pair on System Explorer's compile, delete, import and save
/// against real principals over HTTP (AD-8, AD-29, AD-61 rule 1, Story 19.2 AC6, Story 19.13 AC4,
/// Story 19.3 AC6): a principal holding the read pairs and READ alone on <code>USER</code>'s database
/// is refused each by name with nothing changed, exports to this browser, and is refused an export to
/// a server file naming the file pair it lacks; one holding READ and WRITE compiles, deletes and saves,
/// and is refused an import of a server file naming the file pair it lacks; and a <code>%Developer</code>
/// principal compiles, deletes and imports in <code>USER</code>, whose database its role writes, is
/// refused in the install namespace by name, and exports to this browser there. The tools take the pair
/// from the namespace their proposal stored, else the request's, and an agent's compile minted in one
/// namespace and confirmed in another is gated on the namespace it writes.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates three users and
/// three roles, read back before any test and removed after the last. It creates and removes the
/// probe documents <class>OcuPilot.Test.ExplorerProbe</class> names in <code>USER</code> and the
/// install namespace, and those <class>OcuPilot.Test.ExplorerSaveProbe</class> names in both.</p>
Class OcuPilot.Test.AtelierPortWriteDenial Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's principals, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ExplorerProbe";

/// <p>The save's probe documents.</p>
Parameter SAVEPROBE = "OcuPilot.Test.ExplorerSaveProbe";

/// <p>The namespace whose database the principals are granted.</p>
Parameter OTHERNAMESPACE = "USER";

/// <p>The principal holding READ alone on <parameter>OTHERNAMESPACE</parameter>'s database, the one
/// holding READ and WRITE, and the one holding the vendor's <code>%Developer</code> role; each also
/// reads the install namespace's code database, as every caller of the API must.</p>
Parameter READONLYUSER = "OcuP192ReadOnly";

Parameter READWRITEUSER = "OcuP192ReadWrite";

Parameter DEVELOPERUSER = "OcuP192Developer";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AtelierPortWriteDenial creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP192Deny" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove", ..#OTHERNAMESPACE)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove", $Namespace)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#SAVEPROBE, "Remove", ..#OTHERNAMESPACE)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#SAVEPROBE, "Remove", $Namespace)
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

/// <p>Remove the probes, the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove", ..#OTHERNAMESPACE)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove", $Namespace))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#SAVEPROBE, "Remove", ..#OTHERNAMESPACE))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#SAVEPROBE, "Remove", $Namespace))
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#READONLYUSER, ..#READWRITEUSER, ..#DEVELOPERUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AtelierPortWriteDenial left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "every seeded proposal and turn is removed")
    Do $$$AssertEquals($Get(tRemaining), 0, "and none survives")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForUser(..#READWRITEUSER), "the read-and-write principal's ledger rows are removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#OTHERNAMESPACE), "every probe document in " _ ..#OTHERNAMESPACE _ " is removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", $Namespace), "and in the install namespace")
    Do $$$AssertStatusOK($ClassMethod(..#SAVEPROBE, "Remove", ..#OTHERNAMESPACE), "and the save's in " _ ..#OTHERNAMESPACE)
    Do $$$AssertStatusOK($ClassMethod(..#SAVEPROBE, "Remove", $Namespace), "and in the install namespace")
    Quit $$$OK
}

/// <p>One screen action on the Classes list in <var>pNamespace</var> as <var>pUser</var>:
/// <var>pAction</var> on <var>pId</var>; the HTTP status and the parsed envelope.</p>
Method Act(pUser As %String, pNamespace As %String, pAction As %String, pId As %String, Output pStatus As %Integer, Output pBody)
{
    Set pBody = ""
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    If pAction = "compile" Do tRequest.%Set("values", {"KeepSource": "true", "CompileDependents": "false", "SkipUpToDate": "true"})
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/explorer.classes/action?ns=" _ pNamespace, pUser, ..PreparedPassword, .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
}

/// <p>One screen action on the Classes list in <var>pNamespace</var> as <var>pUser</var>:
/// <var>pAction</var> on <var>pId</var> with <var>pValues</var>; the HTTP status and the parsed
/// envelope.</p>
Method ActWith(pUser As %String, pNamespace As %String, pAction As %String, pId As %String, pValues As %DynamicObject, Output pStatus As %Integer, Output pBody)
{
    Set pBody = ""
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    If $IsObject(pValues) Do tRequest.%Set("values", pValues)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/explorer.classes/action?ns=" _ pNamespace, pUser, ..PreparedPassword, .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
}

/// <p>A local file holding one probe class, <var>pName</var> in the probe package, as the
/// <code>import-local</code> values.</p>
ClassMethod LocalFile(pName As %String) As %DynamicObject
{
    Set tValues = {"fileName": "Imported.cls", "Compile": "true"}
    Do tValues.%Set("content", "Class " _ $Parameter(..#PROBE, "PACKAGE") _ "." _ pName _ " Extends %RegisteredObject" _ $Char(10) _ "{" _ $Char(10) _ "}" _ $Char(10), "string")
    Quit tValues
}

/// <p>Story 19.13 AC4: holding the read pairs and READ alone on <code>USER</code>'s database, an
/// import is refused 403 naming <code>%DB_USER:WRITE</code> with nothing created, an export to a
/// server file 403 naming the file pair the principal lacks, and an export to this browser goes
/// through.</p>
Method TestAnImportWithoutWriteIsRefusedByName()
{
    Do ..ActWith(..#READONLYUSER, ..#OTHERNAMESPACE, "import-local", "import", ..LocalFile("Imported"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tBody), "403 AUTH.NOPRIVILEGE %DB_USER:WRITE", "the import is refused naming the routines database's WRITE pair")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#OTHERNAMESPACE, $Parameter(..#PROBE, "PACKAGE") _ ".Imported.cls"), "and nothing is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#OTHERNAMESPACE, $Parameter(..#PROBE, "PACKAGE") _ ".Alpha"), "a probe class is saved")
    Do ..ActWith(..#READONLYUSER, ..#OTHERNAMESPACE, "export-browser", $Parameter(..#PROBE, "PACKAGE") _ ".Alpha.cls", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "an export to this browser goes through: " _ $Select($IsObject(tBody): $Extract(tBody.%ToJSON(), 1, 200), 1: $Get(tBody)))
    Do ..ActWith(..#READONLYUSER, ..#OTHERNAMESPACE, "export", $Parameter(..#PROBE, "PACKAGE") _ ".Alpha.cls", {"root": ($System.Util.ManagerDirectory()), "path": "OcuProbe1913/denied.xml"}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tBody), "403 AUTH.NOPRIVILEGE %Admin_FileSystemAccess:USE", "an export to a server file is refused naming the file pair")
}

/// <p>Story 19.13 AC4: a <code>%Developer</code> principal imports a probe class into <code>USER</code>,
/// is refused an import in the install namespace naming that namespace's code database's WRITE pair
/// with nothing created, and exports a class to this browser there.</p>
Method TestADeveloperImportsInUserAndExportsAnywhere()
{
    Set tPackage = $Parameter(..#PROBE, "PACKAGE")
    Do ..ActWith(..#DEVELOPERUSER, ..#OTHERNAMESPACE, "import-local", "import", ..LocalFile("Imported"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "it imports in " _ ..#OTHERNAMESPACE _ ": " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: $Get(tBody)))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Compiled", ..#OTHERNAMESPACE, tPackage _ ".Imported"), "the class is created and compiled")
    Do ..ActWith(..#DEVELOPERUSER, $Namespace, "import-local", "import", ..LocalFile("Imported"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tBody), "403 AUTH.NOPRIVILEGE " _ ##class(OcuPilot.Test.DeveloperFloorFixture).CodeResource() _ ":WRITE", "it is refused an import in the install namespace by name")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", $Namespace, tPackage _ ".Imported.cls"), "with nothing created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", $Namespace, tPackage _ ".Alpha"), "a probe class is saved in the install namespace")
    Do ..ActWith(..#DEVELOPERUSER, $Namespace, "export-browser", tPackage _ ".Alpha.cls", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody) && $IsObject(tBody.%Get("output")): (tBody.output.lines.%ToJSON() [ "<Export"), 1: ""), "200 1", "and exports to this browser there")
}

/// <p>Story 19.13 AC4: holding WRITE on <code>USER</code>'s database but not PathPort's pairs, an import
/// naming a server file is refused 403 naming <code>%Admin_FileSystemAccess:USE</code>.</p>
Method TestAnImportOfAServerFileWithoutTheFilePairIsRefusedByName()
{
    Do ..ActWith(..#READWRITEUSER, ..#OTHERNAMESPACE, "import", "import", {"root": ($System.Util.ManagerDirectory()), "path": "OcuProbe1913/denied.xml", "Compile": "true"}, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tBody), "403 AUTH.NOPRIVILEGE %Admin_FileSystemAccess:USE", "the import is refused naming the file pair")
}

/// <p>Story 19.3 AC6: holding the read pairs and READ alone on <code>USER</code>'s database, a save
/// of a probe class at the version read is refused 403 naming <code>%DB_USER:WRITE</code> with the
/// class unchanged; holding READ and WRITE, the same save goes through; and a <code>%Developer</code>
/// principal's save in the install namespace is refused naming that namespace's code database's
/// WRITE pair, with the class unchanged.</p>
Method TestASaveWithoutWriteIsRefusedByName()
{
    Set tName = $Parameter(..#SAVEPROBE, "PACKAGE") _ ".Alpha"
    Do $$$AssertStatusOK($ClassMethod(..#SAVEPROBE, "MakeClass", ..#OTHERNAMESPACE, tName), "a probe class is saved")
    Set tBefore = $ClassMethod(..#SAVEPROBE, "Source", ..#OTHERNAMESPACE, tName _ ".cls")
    Set tValues = {"Compile": "false"}
    Do tValues.%Set("content", $ClassMethod(..#SAVEPROBE, "ClassText", tName, "2"), "string")
    Do tValues.%Set("version", $ClassMethod(..#SAVEPROBE, "Version", ..#OTHERNAMESPACE, tName _ ".cls"), "string")
    Do ..ActWith(..#READONLYUSER, ..#OTHERNAMESPACE, "save", tName _ ".cls", tValues, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tBody), "403 AUTH.NOPRIVILEGE %DB_USER:WRITE", "the save is refused naming the routines database's WRITE pair")
    Do $$$AssertEquals($ClassMethod(..#SAVEPROBE, "Source", ..#OTHERNAMESPACE, tName _ ".cls"), tBefore, "and the class is unchanged")
    Do ..ActWith(..#READWRITEUSER, ..#OTHERNAMESPACE, "save", tName _ ".cls", tValues, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "holding WRITE, the save goes through: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: $Get(tBody)))
    Do $$$AssertEquals($ClassMethod(..#SAVEPROBE, "Source", ..#OTHERNAMESPACE, tName _ ".cls"), tValues.content, "and the class holds the text")
    Do $$$AssertStatusOK($ClassMethod(..#SAVEPROBE, "MakeClass", $Namespace, tName), "a probe class is saved in the install namespace")
    Set tBefore = $ClassMethod(..#SAVEPROBE, "Source", $Namespace, tName _ ".cls")
    Set tValues = {"Compile": "false"}
    Do tValues.%Set("content", $ClassMethod(..#SAVEPROBE, "ClassText", tName, "3"), "string")
    Do tValues.%Set("version", $ClassMethod(..#SAVEPROBE, "Version", $Namespace, tName _ ".cls"), "string")
    Do ..ActWith(..#DEVELOPERUSER, $Namespace, "save", tName _ ".cls", tValues, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tBody), "403 AUTH.NOPRIVILEGE " _ ##class(OcuPilot.Test.DeveloperFloorFixture).CodeResource() _ ":WRITE", "a %Developer's save in the install namespace is refused by name")
    Do $$$AssertEquals($ClassMethod(..#SAVEPROBE, "Source", $Namespace, tName _ ".cls"), tBefore, "and the class is unchanged")
}

/// <p>The code and failed pair an envelope <var>pBody</var> carries, as <code>code pair</code>.</p>
ClassMethod Refusal(pBody) As %String
{
    If '$IsObject(pBody) Quit $Get(pBody)
    Quit pBody.%Get("code") _ " " _ $Select($IsObject(pBody.%Get("detail")): pBody.detail.%Get("failedPair"), 1: "")
}

/// <p>Every System Explorer write that writes code -- compile, delete, import, save and create --
/// declares the list's pair alone and takes WRITE on the routines database as an argument pair, read from
/// the namespace the proposal stored, else the request's. The export tools declare the list's pair alone
/// and add no WRITE.</p>
/// <p>Mutation (Rule 19): give <method>OcuPilot.Screen.Tool.ExplorerWrite.ArgumentPairs</method> the request's
/// scope instead of the stored namespace, or restore the WRITE pair to
/// <method>OcuPilot.Screen.Tool.ExplorerWrite.PrivilegePairs</method> -- this goes red; give the import
/// <class>OcuPilot.Screen.Tool.ExplorerExport</class>'s <method>ArgumentPairs</method> (the file pairs
/// alone) -- the import legs go red.</p>
Method TestTheToolsTakeTheirWritePairFromTheStoredNamespace()
{
    For tCase = $ListBuild(..#OTHERNAMESPACE, "%DB_USER"), $ListBuild($Namespace, ##class(OcuPilot.Test.DeveloperFloorFixture).CodeResource()) {
        Do ##class(OcuPilot.Kernel.Scope).Set($List(tCase, 1))
        For tTool = "OcuPilot.Screen.Tool.ExplorerClassSave", "OcuPilot.Screen.Tool.ExplorerRoutineSave", "OcuPilot.Screen.Tool.ExplorerClassCreate", "OcuPilot.Screen.Tool.ExplorerRoutineCreate", "OcuPilot.Screen.Tool.ExplorerClassCompile", "OcuPilot.Screen.Tool.ExplorerRoutineCompile", "OcuPilot.Screen.Tool.ExplorerClassDelete", "OcuPilot.Screen.Tool.ExplorerRoutineDelete", "OcuPilot.Screen.Tool.ExplorerClassImport", "OcuPilot.Screen.Tool.ExplorerRoutineImport" {
            Set tDeclared = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
            Do $$$AssertTrue(tResolved && $ListFind(tDeclared, $ListBuild("%Development", "USE")) && '$ListFind(tDeclared, $ListBuild($List(tCase, 2), "WRITE")), tTool _ " in " _ $List(tCase, 1) _ " declares %Development:USE and no WRITE pair")
            Set tArgumentPairs = $ClassMethod(tTool, "ArgumentPairs", "", {}, .tResolved)
            Do $$$AssertTrue(tResolved && $ListFind(tArgumentPairs, $ListBuild($List(tCase, 2), "WRITE")), tTool _ " in " _ $List(tCase, 1) _ " with no stored namespace takes WRITE from the request's")
            Set tOpposite = $Select($List(tCase, 1) = ..#OTHERNAMESPACE: $ListBuild($Namespace, ##class(OcuPilot.Test.DeveloperFloorFixture).CodeResource()), 1: $ListBuild(..#OTHERNAMESPACE, "%DB_USER"))
            Set tStored = {"Namespace": ($List(tOpposite, 1))}
            Set tArgumentPairs = $ClassMethod(tTool, "ArgumentPairs", "", tStored, .tResolved)
            Do $$$AssertTrue(tResolved && $ListFind(tArgumentPairs, $ListBuild($List(tOpposite, 2), "WRITE")) && '$ListFind(tArgumentPairs, $ListBuild($List(tCase, 2), "WRITE")), tTool _ " in " _ $List(tCase, 1) _ " with " _ $List(tOpposite, 1) _ " stored takes WRITE from the stored namespace, not the request's")
        }
        For tTool = "OcuPilot.Screen.Tool.ExplorerClassImport", "OcuPilot.Screen.Tool.ExplorerRoutineImport" {
            Set tArgumentPairs = $ClassMethod(tTool, "ArgumentPairs", "", {"root": "manager"}, .tResolved)
            Do $$$AssertTrue(tResolved && $ListFind(tArgumentPairs, $ListBuild($List(tCase, 2), "WRITE")) && $ListFind(tArgumentPairs, $ListBuild("%Admin_FileSystemAccess", "USE")), tTool _ " in " _ $List(tCase, 1) _ " naming a server file adds the file pair beside WRITE")
        }
        For tTool = "OcuPilot.Screen.Tool.ExplorerClassCompile", "OcuPilot.Screen.Tool.ExplorerRoutineCompile", "OcuPilot.Screen.Tool.ExplorerClassDelete", "OcuPilot.Screen.Tool.ExplorerRoutineDelete", "OcuPilot.Screen.Tool.ExplorerClassImport", "OcuPilot.Screen.Tool.ExplorerRoutineImport" {
            For tArguments = {"Namespace": "OCUPROBENOSUCHNS"}, {"Namespace": "OCUPROBENOSUCHNS", "root": "manager"} {
                Set tArgumentPairs = $ClassMethod(tTool, "ArgumentPairs", "", tArguments, .tResolved)
                Do $$$AssertTrue('tResolved && (tArgumentPairs = ""), tTool _ " in " _ $List(tCase, 1) _ " with a stored namespace that names no routines database resolves to no pairs: " _ tArguments.%ToJSON())
            }
        }
        For tTool = "OcuPilot.Screen.Tool.ExplorerClassExport", "OcuPilot.Screen.Tool.ExplorerRoutineExport" {
            Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
            Do $$$AssertTrue(tResolved && $ListFind(tPairs, $ListBuild("%Development", "USE")) && '$ListFind(tPairs, $ListBuild($List(tCase, 2), "WRITE")), tTool _ " in " _ $List(tCase, 1) _ " declares %Development:USE and no WRITE pair")
        }
    }
}

/// <p>A compile the agent minted in <code>USER</code> for the principal holding READ and WRITE on
/// <code>USER</code>'s database alone is confirmed by that principal over HTTP at the install namespace
/// (<code>?ns=</code>) and compiles in <code>USER</code>: the gate requires the namespace the write lands
/// in. The converse, gated at <code>USER</code> on stored arguments naming the install namespace,
/// requires the install namespace's code database's WRITE, which the principal lacks, and the refusal
/// names that pair.</p>
/// <p>Mutation (Rule 19): give <method>OcuPilot.Screen.Tool.ExplorerWrite.ArgumentPairs</method> the request's
/// scope, leave <code>Namespace</code> out of <class>OcuPilot.Screen.Tool.ExplorerMint</class>, or restore
/// WRITE to <method>OcuPilot.Screen.Tool.ExplorerWrite.PrivilegePairs</method> -- the confirm leg goes
/// red.</p>
Method TestAnAgentCompileIsGatedOnTheNamespaceItWrites()
{
    Set tUser = ..#READWRITEUSER
    Set tCode = ##class(OcuPilot.Test.DeveloperFloorFixture).CodeResource()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#OTHERNAMESPACE, "OcuProbe192.Alpha"), "a probe class is saved in " _ ..#OTHERNAMESPACE)
    Do ##class(OcuPilot.Kernel.Scope).Set(..#OTHERNAMESPACE)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn), "a completed turn is seeded")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
    Set tSC = ##class(OcuPilot.Screen.Tool.ExplorerClassCompile).View("", {"Names": "OcuProbe192.Alpha.cls", "KeepSource": false, "CompileDependents": false, "SkipUpToDate": false}, 0, .tProposal, .tMintHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tProposal)), "the agent's compile is minted in " _ ..#OTHERNAMESPACE)
    If $$$ISOK(tSC) && $IsObject($Get(tProposal)) {
        ; The mint runs as the test's own account; the proposal and its turn are then made the principal's,
        ; since a dispatch cannot run as another user.
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Proposal SET UserName = ? WHERE %EXACT(TurnKey) = ?", tUser, tTurn)
        Do $$$AssertEquals(tRS.%SQLCODE, 0, "the proposal is the principal's")
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Turn SET UserName = ? WHERE %EXACT(TurnKey) = ?", tUser, tTurn)
        Do $$$AssertEquals(tRS.%SQLCODE, 0, "and so is its turn")
        Do ##class(OcuPilot.Kernel.Scope).Clear()
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/proposal/" _ tProposal.%Get("proposalId") _ "/confirm?ns=" _ $Namespace, tUser, ..PreparedPassword, .tStatus, .tRaw, .tHeaders, "", "application/json")
        Do $$$AssertStatusOK(tSC, "the principal's confirm at ?ns=" _ $Namespace _ " is sent")
        Do $$$AssertEquals($Get(tStatus), 200, "and is accepted: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertTrue($ClassMethod(..#PROBE, "Compiled", ..#OTHERNAMESPACE, "OcuProbe192.Alpha"), "and the class is compiled in " _ ..#OTHERNAMESPACE)
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the seeded proposal and turn are removed")
    Do $$$AssertEquals($Get(tRemaining), 0, "and none of them survives")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForUser(tUser), "and the principal's ledger rows")

    Do ##class(OcuPilot.Kernel.Scope).Set(..#OTHERNAMESPACE)
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).Resolve("explorer.classes.compile", .tTool), "the compile tool resolves")
    Set tStored = {"Names": "OcuProbe192.Alpha.cls", "Namespace": ($Namespace)}
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, "", "{}", "[]", tStored.%ToJSON(), tUser, "", "OcuPilot.Kernel.Proposal.Confirm", .tPairs, .tRefused, .tGateHttp, .tGateCode, .tGateDetail)
    Do $$$AssertStatusOK(tSC, "the gate answers for a proposal read in " _ $Namespace _ " and confirmed in " _ ..#OTHERNAMESPACE)
    Do $$$AssertEquals(tRefused _ " " _ tGateHttp _ " " _ tGateCode _ " " _ $Select($IsObject(tGateDetail): tGateDetail.%Get("failedPair"), 1: ""), "1 403 AUTH.NOPRIVILEGE " _ tCode _ ":WRITE", "the principal without " _ $Namespace _ "'s WRITE is refused naming it")
}

/// <p>A proposal that stored no <code>Namespace</code> (minted before the namespace was stored) is gated
/// on the namespace the request is scoped to: for the principal holding READ and WRITE on
/// <code>USER</code>'s database alone, the gate accepts it at <code>USER</code> and refuses it at the
/// install namespace naming that namespace's code database's WRITE pair.</p>
/// <p>Mutation (Rule 19): give <method>OcuPilot.Screen.Tool.ExplorerWrite.ArgumentPairs</method> a fixed
/// namespace instead of the request's scope when none is stored -- one of the two legs goes red.</p>
Method TestAProposalWithNoStoredNamespaceIsGatedOnTheRequestsNamespace()
{
    Set tUser = ..#READWRITEUSER
    Set tCode = ##class(OcuPilot.Test.DeveloperFloorFixture).CodeResource()
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).Resolve("explorer.classes.compile", .tTool), "the compile tool resolves")
    Set tStored = {"Names": "OcuProbe192.Alpha.cls"}
    Do ##class(OcuPilot.Kernel.Scope).Set(..#OTHERNAMESPACE)
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, "", "{}", "[]", tStored.%ToJSON(), tUser, "", "OcuPilot.Kernel.Proposal.Confirm", .tPairs, .tRefused, .tGateHttp, .tGateCode, .tGateDetail)
    Do $$$AssertStatusOK(tSC, "the gate answers at " _ ..#OTHERNAMESPACE)
    Do $$$AssertTrue('tRefused && $ListFind(tPairs, $ListBuild("%DB_USER", "WRITE")), "a proposal with no stored namespace confirmed at " _ ..#OTHERNAMESPACE _ " requires and is granted that database's WRITE")
    Do ##class(OcuPilot.Kernel.Scope).Set($Namespace)
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, "", "{}", "[]", tStored.%ToJSON(), tUser, "", "OcuPilot.Kernel.Proposal.Confirm", .tPairs, .tRefused, .tGateHttp, .tGateCode, .tGateDetail)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tSC, "the gate answers at " _ $Namespace)
    Do $$$AssertEquals(tRefused _ " " _ tGateHttp _ " " _ tGateCode _ " " _ $Select($IsObject(tGateDetail): tGateDetail.%Get("failedPair"), 1: ""), "1 403 AUTH.NOPRIVILEGE " _ tCode _ ":WRITE", "the same proposal confirmed at " _ $Namespace _ " is refused naming that namespace's WRITE")
}

/// <p>AC6: holding the read pairs and READ alone on <code>USER</code>'s database, a compile and a
/// delete are each refused 403 naming <code>%DB_USER:WRITE</code>, and the document is neither
/// compiled nor deleted.</p>
Method TestReadWithoutWriteIsRefusedByName()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#OTHERNAMESPACE, "OcuProbe192.Alpha"), "a probe class is saved")
    For tAction = "compile", "delete" {
        Do ..Act(..#READONLYUSER, ..#OTHERNAMESPACE, tAction, "OcuProbe192.Alpha.cls", .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tBody), "403 AUTH.NOPRIVILEGE %DB_USER:WRITE", tAction _ " is refused naming the routines database's WRITE pair")
    }
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#OTHERNAMESPACE, "OcuProbe192.Alpha.cls") && '$ClassMethod(..#PROBE, "Compiled", ..#OTHERNAMESPACE, "OcuProbe192.Alpha"), "and the class is neither deleted nor compiled")
}

/// <p>Holding READ and WRITE on <code>USER</code>'s database, the same principal's compile and
/// delete go through.</p>
Method TestReadAndWriteCompilesAndDeletes()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#OTHERNAMESPACE, "OcuProbe192.Alpha"), "a probe class is saved")
    Do ..Act(..#READWRITEUSER, ..#OTHERNAMESPACE, "compile", "OcuProbe192.Alpha.cls", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the compile goes through: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: $Get(tBody)))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Compiled", ..#OTHERNAMESPACE, "OcuProbe192.Alpha"), "the class is compiled")
    Do ..Act(..#READWRITEUSER, ..#OTHERNAMESPACE, "delete", "OcuProbe192.Alpha.cls", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the delete goes through: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: $Get(tBody)))
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#OTHERNAMESPACE, "OcuProbe192.Alpha.cls"), "the class is gone")
}

/// <p>A <code>%Developer</code> principal compiles and deletes a probe in <code>USER</code>, whose
/// database its role writes, and is refused a compile in the install namespace naming that
/// namespace's code database's WRITE pair, with nothing compiled.</p>
Method TestADeveloperWritesInUserAndIsRefusedInTheInstallNamespace()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#OTHERNAMESPACE, "OcuProbe192.Alpha"), "a probe class is saved in " _ ..#OTHERNAMESPACE)
    Do ..Act(..#DEVELOPERUSER, ..#OTHERNAMESPACE, "compile", "OcuProbe192.Alpha.cls", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "it compiles there: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: $Get(tBody)))
    Do ..Act(..#DEVELOPERUSER, ..#OTHERNAMESPACE, "delete", "OcuProbe192.Alpha.cls", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "and deletes there")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#OTHERNAMESPACE, "OcuProbe192.Alpha.cls"), "the class is gone")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", $Namespace, "OcuProbe192.Alpha"), "a probe class is saved in the install namespace")
    Do ..Act(..#DEVELOPERUSER, $Namespace, "compile", "OcuProbe192.Alpha.cls", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tBody), "403 AUTH.NOPRIVILEGE " _ ##class(OcuPilot.Test.DeveloperFloorFixture).CodeResource() _ ":WRITE", "it is refused in the install namespace by name")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Compiled", $Namespace, "OcuProbe192.Alpha"), "with nothing compiled")
}

/// <p>Create the three principals, each with a role of its own, and read the grants back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tCode = ##class(OcuPilot.Test.DeveloperFloorFixture).CodeResource()
    If tCode = "" Quit $$$ERROR($$$GeneralError, "the install namespace's code database resource could not be read")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tCases = $ListBuild($ListBuild(..#READONLYUSER, tCode _ ":R,%Development:U,%DB_USER:R", ""), $ListBuild(..#READWRITEUSER, tCode _ ":R,%Development:U,%DB_USER:RW", ""), $ListBuild(..#DEVELOPERUSER, tCode _ ":R", "%Developer"))
        For tI = 1:1:$ListLength(tCases) {
            Set tCase = $List(tCases, tI)
            Set tUser = $List(tCase, 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            Set tSC = ##class(Security.Roles).Create(tUser _ "Role", "OcuPilot test: System Explorer write gate (throwaway)", $List(tCase, 2), "")
            If $$$ISERR(tSC) Quit
            Set tRoles = tUser _ "Role" _ $Select($List(tCase, 3) = "": "", 1: "," _ $List(tCase, 3))
            Set tSC = ##class(Security.Users).Create(tUser, tRoles, ..PreparedPassword, "OcuPilot System Explorer write gate test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.AtelierPortWriteDenial; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISOK(tSC) {
            If ($SYSTEM.Security.CheckUserPermission(..#READONLYUSER, "%DB_USER", "WRITE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#READONLYUSER, "%DB_USER", "READ") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#READWRITEUSER, "%DB_USER", "WRITE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#DEVELOPERUSER, "%DB_USER", "WRITE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#DEVELOPERUSER, tCode, "WRITE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#READONLYUSER, "%Admin_Secure", "USE") = 1) {
                Set tSC = $$$ERROR($$$GeneralError, "the throwaway principals' grants did not read back as declared")
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
