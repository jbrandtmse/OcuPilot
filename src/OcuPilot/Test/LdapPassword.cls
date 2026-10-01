/// <p>Pins the LDAP search password (AD-6, AD-35, AD-56 (i), AD-58): the editor's Save enters,
/// clears or leaves it, on an edit and on a create, each read back by presence alone and the answer
/// reporting it written, never read; a refused Save writes none; a password write refused after the Save's configuration write is
/// answered as <code>secretsRefused</code>; the agent's <code>security.ldap.password</code> refuses a
/// bare name and a password from the model, asks for the password at the confirm and stores it, while
/// its proposal, draft, ledger row and agent marker carry only the placeholder; and
/// <parameter>OcuPilot.Screen.Tool.Write.CLEARABLESECRETS</parameter> sends an empty value for the LDAP
/// tool alone.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with auditing on, the
/// test principal holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>: it creates and deletes one <code>ocup99*</code> LDAP configuration
/// (<class>OcuPilot.Test.ServiceLdapProbe</class>) per test, and one more through the create's Save,
/// and sets their search password. Every
/// password is synthetic (<method>Secret</method>) and is never written to an assertion message.</p>
Class OcuPilot.Test.LdapPassword Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

Parameter TOOL = "OcuPilot.Screen.Tool.LdapPassword";

Parameter PROBE = "OcuPilot.Test.ServiceLdapProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter CONFIRM = "OcuPilot.Kernel.Proposal.Confirm";

Parameter FIELD = "LDAPSearchPassword";

/// <p>The probe configuration every test sets the password of.</p>
Parameter NAME = "ocup99password.invalid";

Parameter EDITPATH = "/ldap/:id";

Parameter CREATEPATH = "/ldap";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LdapPassword creates LDAP configurations and sets their search password on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $ClassMethod(..#PROBE, "CreateLdap", ..#NAME)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll")
    Do $$$AssertStatusOK(tSC, "every probe configuration is removed")
    Do $$$AssertEquals(##class(OcuPilot.Test.LdapCreate).Residue(), "", "and no ocup99 configuration remains")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

/// <p>AC5 on the screen's caller: a Save carrying a new password stores it and answers it written,
/// never carrying it; a Save without the key leaves it; a Save carrying <code>""</code> clears it; a
/// Save with the field and another change, from no password, stores both; a password that is not a
/// string is 422 on its field. Each is read back by presence alone.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.LdapSave.HandleUpdate</method> writes the
/// password only when it is non-empty -- the clear leg goes red.</p>
Method TestTheSaveEntersClearsAndLeavesThePassword()
{
    Set tPassword = ..Secret("enter")
    Set tSC = ..Save({"LDAPSearchPassword": (tPassword)}, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "a Save entering a password answers 200")
    Do $$$AssertEquals(tRaw [ tPassword, 0, "and its answer does not carry it")
    Do $$$AssertEquals(..Written($Get(tAnswer)), 1, "its read-back reports the password written")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapPasswordSet", ..#NAME), 1, "the instance holds a password")
    Set tSC = ..Save({"Description": "leave"}, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..Written($Get(tAnswer)), "200 0", "a Save without the key answers and writes no password")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapPasswordSet", ..#NAME), 1, "and the password is left as it is")
    Set tSC = ..Save({"LDAPSearchPassword": ""}, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..Written($Get(tAnswer)), "200 1", "a Save clearing the password answers it written")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapPasswordSet", ..#NAME), 0, "and the instance holds none")
    Set tSC = ..Save({"Description": "both", "LDAPSearchPassword": (..Secret("both"))}, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..Written($Get(tAnswer)), "200 1", "a Save carrying a field and a password writes both")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapPasswordSet", ..#NAME), 1, "the instance holds the new password")
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tAfter, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("Description"), 1: ""), "both", "the field reads back")
    Set tSC = ..Save({"LDAPSearchPassword": 7}, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LdapEdit).FirstViolation($Get(tAnswer)), "422 LDAPSearchPassword PORT.FIELD.SHAPE", "a password that is not a string is refused on its field")
}

/// <p>AC5 on a create: <code>POST /ldap</code> carrying a search password answers 201, the new
/// configuration holds a password, and the answer reports it written without carrying it.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.LdapSave.HandleCreate</method> writes no
/// password -- the stored leg goes red.</p>
Method TestACreateStoresItsPassword()
{
    Set tName = "ocup99pwcreate.invalid"
    Set tPassword = ..Secret("create")
    Set tArgs = ##class(OcuPilot.Test.LdapCreate).Args(tName)
    Do tArgs.%Set(..#FIELD, tPassword, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#CREATEPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tArgs.%ToJSON(), "application/json")
    Set tArgs = ""
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tRaw)) } Catch { Set tAnswer = "" }
    Do $$$AssertEquals(tStatus, 201, "a create carrying a password answers 201")
    Do $$$AssertEquals($Get(tRaw) [ tPassword, 0, "and its answer does not carry it")
    Do $$$AssertEquals(..Written(tAnswer), 1, "its read-back reports the password written")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapExists", tName) _ " " _ $ClassMethod(..#PROBE, "LdapPasswordSet", tName), "1 1", "the configuration is created holding a password")
}

/// <p>AC5, AC8: a Save the rules refuse, and a create of a name already taken, each carrying a
/// password, answer 422 and write no password: the configuration they name holds none
/// afterwards.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.LdapSave.HandleUpdate</method> and
/// <method>OcuPilot.Area.Security.LdapSave.HandleCreate</method> write the password whatever the
/// violations -- both legs go red.</p>
Method TestARefusedSaveWritesNoPassword()
{
    Set tBody = {"LDAPFlags": 192}
    Do tBody.%Set(..#FIELD, ..Secret("refusedsave"), "string")
    Set tSC = ..Save(tBody, .tStatus, .tRaw, .tAnswer)
    Set tBody = ""
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LdapEdit).FirstViolation($Get(tAnswer)), "422 LDAPFlags LDAP.FLAGS.KERBEROS", "a Save the rules refuse answers 422")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapPasswordSet", ..#NAME), 0, "and writes no password")
    Set tArgs = ##class(OcuPilot.Test.LdapCreate).Args(..#NAME)
    Do tArgs.%Set(..#FIELD, ..Secret("taken"), "string")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tAnswer, tArgs.%ToJSON(), "application/json")
    Set tArgs = ""
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LdapEdit).FirstViolation($Get(tAnswer)), "422 Name LDAP.NAME.TAKEN", "a create of a taken name answers 422")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapPasswordSet", ..#NAME), 0, "and writes no password over the configuration it names")
}

/// <p>The Save's password write refused after its configuration write: the edit's route answers 200
/// carrying <code>secretsRefused</code>, the refusal's own sentence, and no password written; the
/// other change lands and no password is stored. The refusal is
/// <class>OcuPilot.Test.LdapFailPort</class>'s; the route runs in this process through
/// <class>OcuPilot.Test.LdapFailSave</class>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.LdapSave.Answer</method> drops
/// <code>secretsRefused</code> -- this goes red.</p>
Method TestAPasswordRefusedAfterTheSaveIsAnswered()
{
    Set tPassword = ..Secret("refused")
    Do ##class(OcuPilot.Test.LdapFailPort).Clear()
    Set tBody = {"Description": "saved before the refusal"}
    Do tBody.%Set(..#FIELD, tPassword, "string")
    Set tSC = ##class(OcuPilot.Test.LdapFailSave).Handle(..#NAME, tBody, .tRaw, .tStatus)
    Set tBody = ""
    Set tReached = ##class(OcuPilot.Test.LdapFailPort).Reached()
    Do ##class(OcuPilot.Test.LdapFailPort).Clear()
    Do $$$AssertStatusOK(tSC, "the edit's route runs")
    Do $$$AssertEquals(tStatus, 200, "and answers 200")
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tRaw)) } Catch { Set tAnswer = "" }
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("secretsRefused"), 1: ""), ##class(OcuPilot.Test.LdapFailPort).#REFUSEDREASON, "carrying secretsRefused, the refusal's sentence")
    Do $$$AssertEquals(..Written(tAnswer), 0, "and no password written")
    Do $$$AssertEquals($Get(tRaw) [ tPassword, 0, "and not the password")
    Do $$$AssertEquals(tReached, 1, "the password write reached the refusing port once")
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tAfter, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("Description"), 1: ""), "saved before the refusal", "the other change lands")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapPasswordSet", ..#NAME), 0, "and no password is stored")
}

/// <p>AC5 on the agent's caller: a bare name is refused at the mint by <code>LDAP.NAME.FORM</code>
/// (AD-13) even where a configuration answers its target read
/// (<method>OcuPilot.Test.LdapCreate.FixtureMint</method>); a password the model supplies is refused at the mint; the mint's one row names the
/// secret, empty on both sides; its draft carries the placeholder; the confirm, supplied the
/// password, stores it; the proposal, the ledger row, the agent marker, the application error log and
/// messages.log never carry it; and a confirm supplied <code>""</code> clears it.</p>
Method TestTheAgentsPasswordIsAskedAtConfirmAndNeverStored()
{
    Set tShort = {}
    Do tShort.%Set("Name", "OcuP99Password", "string")
    Set tSC = ##class(OcuPilot.Test.LdapCreate).FixtureMint(..#TOOL, "OcuP99Password", tShort, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue(($Get(tHttp) = 400) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ##class(OcuPilot.Api.LdapError).#REASONNAMEFORM), "a bare name is refused at the mint by LDAP.NAME.FORM: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    Set tPassword = ..Secret("agent")
    Set tArgs = {}
    Do tArgs.%Set("Name", ..#NAME, "string")
    Do tArgs.%Set(..#FIELD, tPassword, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, ..#NAME, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ "is a secret field"), "a password from the model is refused at the mint")
    Set tArgs = {}
    Do tArgs.%Set("Name", ..#NAME, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, ..#NAME, tArgs, .tDrafted, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a proposal is minted to draft: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If $IsObject($Get(tDrafted)) {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(tDrafted.%Get("proposalId"), $Username, "http://localhost", .tDraft, .tHttp, .tCode)
        Do $$$AssertEquals(tHttp, 200, "its draft is taken: " _ $Get(tCode))
        Set tText = $Select($IsObject($Get(tDraft)): tDraft.%ToJSON(), 1: "")
        Do $$$AssertTrue(tText [ ("<" _ ..#FIELD _ ">"), "the draft carries the placeholder")
        Do $$$AssertEquals(tText [ tPassword, 0, "and no password")
    }
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, ..#NAME, tArgs, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the password write is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRows = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tRows = tRows _ $ListBuild(tRow.%Get("field") _ "|" _ tRow.%Get("before") _ "|" _ tRow.%Get("after")) }
    Do $$$AssertEquals($ListToString(tRows, ","), ..#FIELD _ "||", "one row naming the secret, empty on both sides")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSecrets = {}
    Do tSecrets.%Set(..#FIELD, tPassword, "string")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), tSecrets, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Set tSecrets = ""
    Do $$$AssertStatusOK(tSC, "the password write is confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapPasswordSet", ..#NAME), 1, "and the instance holds the password")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertTrue($Get(tFound) && (($Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))) '[ tPassword), "the proposal stores no password")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tLedger), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tLedger("Fields")) [ tPassword, 0, "which carries no password")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposal.%Get("proposalId") _ """", .tData), 1, "one agent marker names the proposal")
    Do $$$AssertEquals($Get(tData) [ tPassword, 0, "and carries no password")
    Do $$$AssertEquals(##class(OcuPilot.Test.LdapTest).ErrorsCarry(tPassword), 0, "the application error log carries none")
    Do $$$AssertEquals(##class(OcuPilot.Test.LdapTest).LogCarries(tPassword), 0, "and messages.log carries none")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows it wrote")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, ..#NAME, tArgs, .tCleared, .tHttp, .tFault, .tClearTurn)
    If '$IsObject($Get(tCleared)) Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tCleared.%Get("proposalId"), {"LDAPSearchPassword": ""}, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "a confirm supplied an empty value is applied: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapPasswordSet", ..#NAME), 0, "and clears the password")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tClearTurn), "this class removes the ledger rows it wrote")
}

/// <p>AD-56 (i): <method>OcuPilot.Kernel.Proposal.Operation.SecretBody</method> keeps an explicitly
/// supplied <code>""</code> for a name the tool's <code>CLEARABLESECRETS</code> lists -- the LDAP
/// password tool's -- and still drops it for a tool that lists none, the users' password tool.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Operation.SecretBody</method> drops
/// <code>""</code> for every name -- the LDAP leg goes red.</p>
Method TestAnEmptySecretIsSentOnlyWhereDeclaredClearable()
{
    Set tOperation = "OcuPilot.Kernel.Proposal.Operation"
    Do $$$AssertEquals($Parameter(..#TOOL, "CLEARABLESECRETS"), ..#FIELD, "the LDAP password tool declares its secret clearable")
    Do $$$AssertEquals($ClassMethod(tOperation, "SecretBody", ..#TOOL, {"LDAPSearchPassword": ""}, $ListBuild(..#FIELD)).%ToJSON(), "{""LDAPSearchPassword"":""""}", "an empty LDAP password reaches the body")
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.UserPassword", "CLEARABLESECRETS"), "", "the users' password tool declares none")
    Do $$$AssertEquals($ClassMethod(tOperation, "SecretBody", "OcuPilot.Screen.Tool.UserPassword", {"Password": ""}, $ListBuild("Password")).%ToJSON(), "{}", "so its empty password is still dropped")
}

/// <p>Send the edit Save <var>pBody</var> for <parameter>NAME</parameter> as the test principal, with
/// the raw answer in <var>pRaw</var> and its parse in <var>pAnswer</var>.</p>
Method Save(pBody As %DynamicObject, Output pStatus As %Integer, Output pRaw As %String, Output pAnswer As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ $Replace(..#EDITPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(..#NAME))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pRaw, .tHeaders, pBody.%ToJSON(), "application/json")
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON($Get(pRaw)) } Catch { Set pAnswer = "" }
    Quit tSC
}

/// <p>Whether a Save's answer <var>pAnswer</var> reports the search password written in its
/// read-back.</p>
ClassMethod Written(pAnswer) As %Boolean
{
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("readBack") '= "object") Quit 0
    Set tWritten = pAnswer.%Get("readBack").%Get("written")
    If '$IsObject(tWritten) Quit 0
    Quit tWritten.%ToJSON() [ ("""" _ ..#FIELD _ """")
}

/// <p>A synthetic password unique to this run and <var>pPurpose</var>.</p>
ClassMethod Secret(pPurpose As %String) As %String
{
    Quit "OcuP99Pw" _ pPurpose _ $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.GenCryptRand(6)), "L")
}

}
