/// <p>Pins Story 24.15's credential writes end to end against probe credentials in <code>USER</code> (AD-6, AD-14, AD-15, AD-35, AD-51, AD-53, AD-54,
/// AD-55, AD-58, AD-59, AD-62): a person's Save adds a credential, their Edit, Set password and Remove change and remove one, and the agent's four
/// tools mint and confirm over HTTP, the password supplied at the confirm. Each answers a read-back verdict and the change event's triple, and what it
/// stored reads back from <code>Ens.Config.Credentials</code> exactly as sent; the vendor records no audit row, so OcuPilot's own
/// <code>ConfigChange</code> is the record, naming the namespace, the credential and the field names; a credential changed out of band after the mint
/// closes the confirm target-changed. <b>No password value appears in an answer, an audit row, a read or a script.</b></p>
/// <p>It borrows the transport helpers of <class>OcuPilot.Test.InteropItemControl</class>. <b>What it needs from the environment:</b> an
/// interoperability-enabled <code>USER</code> namespace and an <code>HSCUSTOM</code> one to confirm from, the HTTP test account and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It
/// starts no production and removes every credential, password node and partner it creates.</p>
Class OcuPilot.Test.InteropCredentialControl Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PORT = "OcuPilot.Port.InteropPort";

/// <p>The probe credential every test names.</p>
Parameter NAME = "OcuProbe2415A";

/// <p>The secret every probe password carries, so a leak is a substring test.</p>
Parameter PASSWORD = "OcuPwMarker2415x";

Parameter SCREEN = "/screens/interop.credentials";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropCredentialControl writes probe credentials in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the probe credentials are removed")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialCount", "OcuProbe2415") + $ClassMethod(..#FIXTURE, "CredentialCount", "OcuProbe2415", "HSCUSTOM"), 0, "and none survives, with its password node, in either namespace")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The credential <var>pName</var> as the port's single-credential read answers it, or <code>""</code> when it is not held.</p>
ClassMethod Held(pName As %String = {..#NAME}) As %DynamicObject
{
    Kill tQuery
    Set tQuery("id") = pName
    Set tQuery("namespace") = "USER"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Credentials", "CREDENTIAL", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select(tHttp = 200: tRow, 1: "")
}

/// <p>The port's call of the type <var>pType</var> on <var>pName</var> in USER as <code>status code</code>.</p>
ClassMethod Verdict(pType As %String, pName As %String, pBody As %DynamicObject = "") As %String
{
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Credentials", pType, .tQuery, pBody, .tRow, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>One person's row action on the Credentials screen as <code>status code</code>, the answer in <var>pAnswer</var>. <var>pValues</var>, when it is
/// an object, is the dialog's values.</p>
ClassMethod Act(pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pAnswer) As %String
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#SCREEN _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The person's Save of a credential as <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod Save(pBody As %DynamicObject, Output pAnswer) As %String
{
    Do $ClassMethod(..#CONTROL, "Call", "POST", "/interop/credentials", pBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The body of a Save of the probe credential <var>pName</var> with <var>pUsername</var>, <var>pPartner</var> and, when not empty,
/// <var>pPassword</var>.</p>
ClassMethod SaveBody(pName As %String, pUsername As %String, pPartner As %String = "", pPassword As %String = "") As %DynamicObject
{
    Set tBody = {"Name": (pName), "Username": (pUsername), "BusinessPartner": (pPartner)}
    If pPassword '= "" Do tBody.%Set("Password", pPassword, "string")
    Quit tBody
}

/// <p>The rows of OcuPilot's own <code>ConfigChange</code> since <var>pSince</var> that name the credential <var>pName</var>, with the last row's data in
/// <var>pData</var>.</p>
ClassMethod OwnRows(pSince As %String, Output pData As %String, pName As %String = {..#NAME}) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", pName, .pData)
}

/// <p>How many rows of the vendor's own <code>%Ensemble</code> audit since <var>pSince</var> carry <var>pWords</var> in their data or description: the
/// vendor records no credential row (measured).</p>
ClassMethod VendorRows(pSince As %String, pWords As %String) As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventData, Description FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = '%Ensemble'", pSince)
        While tRS.%Next() {
            If (tRS.%Get("EventData") [ pWords) || (tRS.%Get("Description") [ pWords) Set tCount = tCount + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>The arguments of a call naming the probe credential <var>pName</var>, with each member of <var>pSet</var> beside it.</p>
ClassMethod ArgsFor(pName As %String, pSet As %DynamicObject = "") As %DynamicObject
{
    Set tArgs = {"Name": (pName)}
    If $IsObject(pSet) {
        Set tIterator = pSet.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Do tArgs.%Set(tKey, tValue, pSet.%GetTypeOf(tKey))
        }
    }
    Quit tArgs
}

/// <p>Mint <var>pTool</var> (a class name) for <var>pArgs</var> as the HTTP account, with the proposal in <var>pProposal</var>.</p>
ClassMethod Mint(pTool As %String, pArgs As %DynamicObject, Output pProposal, Output pFault, Output pTurn) As %Status
{
    Quit $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool." _ pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .pFault, .pTurn)
}

/// <p>Confirm <var>pProposal</var> over HTTP with the secrets <var>pSecrets</var> as the body: the status, and the answer in <var>pAnswer</var>.</p>
ClassMethod Confirm(pProposal As %DynamicObject, pSecrets As %DynamicObject = "", Output pAnswer, Output pRaw) As %Integer
{
    Set pAnswer = ""
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/proposal/" _ pProposal.proposalId _ "/confirm?ns=USER"
    Set tJson = $Select($IsObject(pSecrets): pSecrets.%ToJSON(), 1: "")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .pRaw, .tHeaders, tJson, "application/json", .tExtra, 180)
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(pRaw) } Catch { Set pAnswer = "" }
    Quit tStatus
}

/// <p>How many ledger rows the turn <var>pTurn</var> holds for the tool <var>pTool</var>.</p>
ClassMethod LedgerCount(pTurn As %String, pTool As %String) As %Integer
{
    Quit $ClassMethod(..#CONTROL, "LedgerCount", pTurn, pTool)
}

/// <p>The screen is declared as the plan places it: in the Interoperability area at side bar 14 with the credential's name as its key, New credential
/// as its primary action and Edit, Set password and Remove as its row actions, over <code>%Ens_Credentials:READ</code>, naming the entity type
/// <code>interop-credential</code>, the classic page it replaces, and the password as its one declared secret argument.</p>
/// <p>Mutation (Rule 19): change the screen's <code>sideBarPosition</code> to 13 -- this goes red.</p>
Method TestTheDeclarationRegisters()
{
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropCredentialList).DeclarationJson(.tDeclaration)
    Do $$$AssertStatusOK(tSC, "the screen declares JSON")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.area, "interoperability/credentials|14|list|interoperability", "its route, place, archetype and area")
    Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.id.kind _ "|" _ tDeclaration.id.parts.%ToJSON() _ "|" _ tDeclaration.toolIdentifier, "interop-credential|composite|[""Name""]|interop.credentials", "its entity type, its key and its tool identifier")
    Do $$$AssertEquals(tDeclaration.primaryAction.id _ "|" _ tDeclaration.rowActions.%Get(0).id _ "," _ tDeclaration.rowActions.%Get(1).id _ "," _ tDeclaration.rowActions.%Get(2).id, "add|edit,password,remove", "its actions")
    Do $$$AssertEquals(tDeclaration.classicPage _ "|" _ tDeclaration.secretArguments.%ToJSON() _ "|" _ tDeclaration.context.secretFields.%ToJSON(), "EnsPortal.Credentials|[""Password""]|[]", "its classic page and its one declared secret")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_Credentials"",""permission"":""READ""}]", "its pairs are the classic page's")
}

/// <p>AC1, AC3: a person's Save adds a credential: it answers 201 with the name as its id, its target in the change event's triple and a read-back that
/// matches, stores exactly what was sent, stores the password the dialog typed and none when it was left empty, and records one
/// <code>ConfigChange</code> naming the namespace, the credential and the field names, and no password. The vendor records none.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformCredential</method> drop <code>BusinessPartner</code> on an add -- the
/// stored-text leg goes red.</p>
Method TestTheSaveAddsACredentialThatReadsBackExactly()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutPartner"), "a probe partner is arranged")
    Set tPartner = $Parameter(..#FIXTURE, "PARTNER")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertTrue('$IsObject(..Held()), "the credential is not held yet")
    Set tText = ..Save(..SaveBody(..#NAME, "probe", tPartner, ..#PASSWORD), .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "the Save answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, 1: ""), ..#NAME _ "|interop-credential|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the name as its id, its entity type and a matching read-back: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "probe|" _ tPartner _ "|1", "the class holds exactly what was sent, and a password is stored")
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() '[ ..#PASSWORD), "and the answer carries no password")
    Do $$$AssertEquals(..OwnRows(tSince, .tData), 1, "OcuPilot records one ConfigChange row")
    Do $$$AssertTrue((tData [ "USER") && (tData [ "Username,BusinessPartner,Password") && (tData '[ ..#PASSWORD), "naming the namespace and the field names, never a value: " _ tData)
    Do $$$AssertEquals(..VendorRows(tSince, ..#NAME), 0, "and the vendor records none")
    Do $$$AssertEquals(..Held().Password, "stored", "the read says a password is stored")
    Set tNone = ..#NAME _ "N"
    Set tText = ..Save(..SaveBody(tNone, "nopw"), .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "a Save with no password answers 201")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", tNone), "nopw||0", "and stores none")
    Do $$$AssertEquals(..Held(tNone).Password, "not stored", "the read says so")
}

/// <p>AC1: the Save route answers JSON over the wire: 201 with the name as its id, and a name the namespace holds, in another letter case too, 409 with
/// <code>INTEROP.CREDENTIAL.TAKEN</code>, the refusal carrying no password.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Interop.CredentialSave.IdOf</method> answer an empty id -- this goes red.</p>
Method TestTheSaveRouteAnswersJsonOverTheWire()
{
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/interop/credentials?ns=USER"
    Set tBody = ..SaveBody(..#NAME, "wire", "", ..#PASSWORD)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the Save answers 201: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, ..#NAME _ "|interop-credential|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the name's id, its target and a matching read-back")
    For tName = ..#NAME, $ZConvert(..#NAME, "L") {
        Set tBody = ..SaveBody(tName, "again", "", ..#PASSWORD)
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
        Do $$$AssertEquals(tStatus, 409, "a held name '" _ tName _ "' is refused 409: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tRaw).code, "INTEROP.CREDENTIAL.TAKEN", "with the envelope's code")
        Do $$$AssertTrue($Get(tRaw) '[ ..#PASSWORD, "and the refusal carries no password")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "wire||1", "the held credential is untouched")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialCount", "OcuProbe2415"), 2, "and only its row and its password node exist")
}

/// <p>AC1, AC3: a person's Edit, Set password and Remove answer 200 with the <code>updated</code> and <code>deleted</code> events: an Edit that
/// carries the user name alone changes it and keeps the partner and the password, a Set password stores a new password and changes nothing else, an
/// Edit that changes nothing calls nothing, and a Remove takes the credential and its password node; each change records one
/// <code>ConfigChange</code>, none carrying a value.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformCredential</method> skip <code>PasswordSet</code> on a password write --
/// the stored leg goes red.</p>
Method TestThePersonsEditPasswordAndRemoveChangeOnlyWhatTheyCarry()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutPartner"), "a probe partner is arranged")
    Set tPartner = $Parameter(..#FIXTURE, "PARTNER")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutCredential", ..#NAME, "before", tPartner, "OcuPwBefore2415"), "the probe credential is arranged")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Act("edit", ..#NAME, {"Username": "after"}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "an Edit answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, 1: ""), "updated|interop-credential|" _ ..#NAME _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "publishing the updated event for the credential, whose read-back matches")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "after|" _ tPartner _ "|1", "the user name changed and the partner and the password are kept")
    Do $$$AssertEquals(..Act("edit", ..#NAME, {"BusinessPartner": ""}, .tAnswer), "200 ", "an Edit that sends an empty partner answers 200")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "after||1", "and the partner is cleared")
    Do $$$AssertEquals(..Act("edit", ..#NAME, {"BusinessPartner": ""}, .tAnswer), "200 ", "an Edit that changes nothing is accepted and calls nothing")
    Do $$$AssertEquals(..OwnRows(tSince, .tData), 2, "so OcuPilot records a row for each of the two changes and no more")
    Do $ClassMethod(..#FIXTURE, "DropCredentials", ..#NAME)
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutCredential", ..#NAME, "after", ""), "the credential is re-arranged with no password")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "after||0", "so none is stored before Set password")
    Set tText = ..Act("password", ..#NAME, {"Password": (..#PASSWORD)}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Set password answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() '[ ..#PASSWORD), "with no password in the answer")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "after||1", "the password is now stored and the user name and the partner are as they were")
    Do $$$AssertEquals(..OwnRows(tSince, .tData), 3, "and the password write records a row")
    Do $$$AssertTrue((tData [ "Password") && (tData '[ ..#PASSWORD) && (tData '[ "OcuPwBefore2415"), "naming the field and no value: " _ tData)
    Set tEmpty = ..Act("password", ..#NAME, {"Password": ""}, .tAnswer)
    Do $$$AssertEquals(tEmpty, "400 TOOL.ARGUMENTS", "an empty password is not a password supplied, so the screen refuses it and nothing is stored")
    Do $$$AssertEquals(..Verdict("PASSWORDCREDENTIAL", ..#NAME, {"Password": ""}), "422 PORT.FIELD.SHAPE", "and the port refuses it too")
    Set tText = ..Act("remove", ..#NAME, "", .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Remove answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type, 1: ""), "deleted|interop-credential", "as a deletion")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "<absent>", "the credential is gone from the class")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "PasswordNode", ..#NAME), 0, "and its password node with it")
    Do $$$AssertEquals(..Act("remove", ..#NAME, "", .tAnswer), "404 PORT.NOTFOUND", "a second Remove finds none")
    Do $$$AssertEquals(..VendorRows(tSince, ..#NAME), 0, "and the vendor recorded no row throughout")
}

/// <p>AC1, AC3: the agent's add of a credential, minted for the HTTP account and confirmed over HTTP with the password supplied at the confirm, creates a
/// credential that did not exist, answers one envelope with a read-back that matches, is ledgered once and marked (AD-15); the card names the password
/// as a masked, optional row and the stored proposal carries none; a name taken after the mint closes the confirm target-changed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropCredentialAdd.StateDiff</method> answer no row -- the card leg goes red.</p>
Method TestTheAgentsAddConfirmsOverHttp()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Mint("InteropCredentialAdd", ..ArgsFor(..#NAME, {"Username": "agent"}), .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the add mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-credential|USER|" _ ..#NAME, "the target is the credential, by its name")
    Do $$$AssertTrue((tProposal.changed.%ToJSON() [ """field"":""Password""") && (tProposal.changed.%ToJSON() [ """optional"":true"), "its card names the password as a masked, optional row: " _ tProposal.changed.%ToJSON())
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "<absent>", "nothing is written by the mint")
    Set tStatus = ..Confirm(tProposal, {"Password": (..#PASSWORD)}, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the add confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|created|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as a creation, marked (AD-15), whose read-back matches")
    Do $$$AssertTrue($Get(tRaw) '[ ..#PASSWORD, "the answer carries no password")
    Do $$$AssertEquals(..LedgerCount(tTurn, "interop.credentials.add"), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "agent||1", "the class holds what the proposal reviewed and the password the confirm supplied")
    Do $$$AssertEquals(..VendorRows(tSince, ..#NAME), 0, "the vendor records no row")
    Do $$$AssertEquals(..OwnRows(tSince, .tData), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue(tData '[ ..#PASSWORD, "carrying no password")
    ; A name taken after the mint closes the proposal.
    Set tOther = ..#NAME _ "B"
    Set tSC = ..Mint("InteropCredentialAdd", ..ArgsFor(tOther, {"Username": "agent"}), .tSecond, .tFault, .tSecondTurn)
    Do $$$AssertStatusOK(tSC, "a second add mints")
    If '$IsObject($Get(tSecond)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutCredential", $ZConvert(tOther, "L"), "taken"), "the name is taken after the mint, in another letter case")
    Set tStatus = ..Confirm(tSecond, {"Password": (..#PASSWORD)}, .tAnswer, .tRaw)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", tOther), "<absent>", "and nothing was written under the name the agent proposed")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tSecondTurn))
}

/// <p>AC1, AC3: the agent's update changes the user name and keeps the password, the agent's password tool stores the password supplied at the
/// confirm and nothing else, and the agent's remove is destructive and ships off: it is refused while the tool's key is off, closes target-changed
/// when the credential moved after the mint, and removes the credential and its password node once it is on. No answer, card or ledger row carries
/// a password.</p>
/// <p>Mutation (Rule 19): turn the remove tool's baseline key on -- the refusal leg goes red.</p>
Method TestTheAgentsUpdatePasswordAndRemoveConfirmOverHttp()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutCredential", ..#NAME, "one", "", "OcuPwBefore2415"), "the probe credential is arranged")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Try {
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the stored policy is cleared")
        Set tSC = ..Mint("InteropCredentialUpdate", ..ArgsFor(..#NAME, {"Username": "two"}), .tUpdate, .tFault, .tUpdateTurn)
        Do $$$AssertStatusOK(tSC, "the update mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tUpdate)) Quit
        Do $$$AssertEquals(tUpdate.changed.%ToJSON(), "[{""field"":""Username"",""before"":""one"",""after"":""two""}]", "its card shows the one field it moves")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tUpdate.proposalId, "Consequence"), "INTEROP.CREDENTIAL.CHANGE", "its consequence says what signs in with the credential uses the change from its next connection")
        Set tStatus = ..Confirm(tUpdate, "", .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "the update confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "two||1", "the user name changed and the password is kept")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tUpdateTurn)
        Do $ClassMethod(..#FIXTURE, "DropCredentials", ..#NAME)
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutCredential", ..#NAME, "two", ""), "the credential is re-arranged with no password")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "two||0", "so none is stored before the password tool")
        Set tSC = ..Mint("InteropCredentialPassword", ..ArgsFor(..#NAME), .tPassword, .tFault, .tPasswordTurn)
        Do $$$AssertStatusOK(tSC, "the password tool mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tPassword)) Quit
        Do $$$AssertEquals(tPassword.changed.%ToJSON(), "[{""field"":""Password"",""before"":"""",""after"":""""}]", "its card is one masked row with no value on either side")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tPassword.proposalId, "Consequence"), "INTEROP.CREDENTIAL.CHANGE", "and its consequence is the same sentence")
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tStatus = ..Confirm(tPassword, {"Password": (..#PASSWORD)}, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "it confirms with the password supplied: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertTrue($Get(tRaw) '[ ..#PASSWORD, "the answer carries no password")
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action, 1: ""), "1|updated", "marked (AD-15)")
        Do $$$AssertEquals(..LedgerCount(tPasswordTurn, "interop.credentials.password"), 1, "ledgered once")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tPasswordTurn)
        Do $$$AssertEquals(..OwnRows(tSince, .tData), 1, "OcuPilot records one row for the password write")
        Do $$$AssertTrue(tData '[ ..#PASSWORD, "carrying no password: " _ tData)
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "two||1", "and the password is stored beside the user name as it was")
        ; The remove.
        Set tSC = ..Mint("InteropCredentialRemove", ..ArgsFor(..#NAME), .tRemove, .tFault, .tRemoveTurn)
        Do $$$AssertStatusOK(tSC, "the remove mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tRemove)) Quit
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tRemove.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tRemove.proposalId, "Destructive") + 0), "INTEROP.CREDENTIAL.REMOVE|1", "its consequence says nothing can use the credential again, and it is destructive")
        Set tStatus = ..Confirm(tRemove, "", .tAnswer, .tRaw)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the confirm is refused while the tool's key is off: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "two||1", "and the credential is still there")
        Kill tSettings
        Set tSettings("interop.credentials.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is turned on")
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutCredential", $ZConvert(..#NAME, "L") _ "x", "other"), "a credential is added beside it")
        Do $ClassMethod(..#FIXTURE, "DropCredentials", ..#NAME)
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutCredential", ..#NAME, "moved"), "the credential is replaced by one that differs")
        Set tStatus = ..Confirm(tRemove, "", .tAnswer, .tRaw)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), "PROPOSAL.TARGETCHANGED", "a credential changed after the mint closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "moved||0", "and the credential is still there")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tRemoveTurn))
        Set tSC = ..Mint("InteropCredentialRemove", ..ArgsFor(..#NAME), .tRemove, .tFault, .tRemoveTurn)
        Do $$$AssertStatusOK(tSC, "a fresh remove mints")
        If '$IsObject($Get(tRemove)) Quit
        Set tStatus = ..Confirm(tRemove, "", .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "and the remove then confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|deleted|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTFOUND, "as a deletion, marked (AD-15), whose read-back finds the credential gone")
        Do $$$AssertEquals(..LedgerCount(tRemoveTurn, "interop.credentials.remove"), 1, "ledgered once")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME) _ "|" _ $ClassMethod(..#FIXTURE, "PasswordNode", ..#NAME), "<absent>|0", "the credential and its password node are gone")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    For tTurn = $Get(tUpdateTurn), $Get(tPasswordTurn), $Get(tRemoveTurn) {
        If tTurn '= "" Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
}

/// <p>AC1 (AD-52): the agent's add, minted in <code>USER</code> naming a business partner only <code>USER</code> holds and confirmed from
/// <code>HSCUSTOM</code>, judges its fields where the proposal read and creates the credential there.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropCredentialAction.MintClass</method> answer the kernel's own mint -- the confirm
/// judges the partner in <code>HSCUSTOM</code>, is refused, and this goes red.</p>
Method TestAnAddConfirmedFromAnotherNamespaceIsJudgedWhereItRead()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutPartner"), "a probe partner is arranged in USER alone")
    Set tPartner = $Parameter(..#FIXTURE, "PARTNER")
    Set tSC = ..Mint("InteropCredentialAdd", ..ArgsFor(..#NAME, {"Username": "agent", "BusinessPartner": (tPartner)}), .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the add mints in USER: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/proposal/" _ tProposal.proposalId _ "/confirm?ns=HSCUSTOM"
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, {"Password": (..#PASSWORD)}.%ToJSON(), "application/json", .tExtra, 180)
    Do $$$AssertEquals(tStatus, 200, "a confirm sent from HSCUSTOM answers: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME), "agent|" _ tPartner _ "|1", "the credential is created in USER, where the proposal read")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialText", ..#NAME, "HSCUSTOM"), "<absent>", "and not in HSCUSTOM")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC3: no password appears in what a person or the agent reads: the list, the single-credential read and the agent's read tool say only
/// <code>stored</code> or <code>not stored</code>, and the script form of each write renders the placeholder <code>&lt;Password&gt;</code> where the
/// body carries one, never the value. The add's script, run, only sets the taken refusal for a name held in another letter case (AD-59).</p>
/// <p>Mutation (Rule 19): drop the <code>'tHeld</code> gate from the add in <method>OcuPilot.Port.InteropPort.CredentialSnippet</method> -- the
/// held-name run goes red. Make it render the body's password -- the script leg goes red,
/// (the draft masks a secret before the port sees it, so <method>OcuPilot.Test.DraftRegistry.TestNoSecretReachesAnyRenderedScript</method> stays green).</p>
Method TestNoPasswordAppearsInAReadOrAScript()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutCredential", ..#NAME, "reader", "", ..#PASSWORD), "a credential with a stored password is arranged")
    Do $ClassMethod(..#CONTROL, "Call", "GET", ..#SCREEN _ "/read?maxRows=1000", "", .tStatus, .tScreen)
    Do $$$AssertTrue($IsObject(tScreen) && (tScreen.%ToJSON() '[ ..#PASSWORD) && (tScreen.%ToJSON() [ ..#NAME) && (tScreen.%ToJSON() [ "stored"), "the screen's read lists the credential as stored without the password")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Credentials", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertTrue((tHttp = 200) && (tRows.%ToJSON() '[ ..#PASSWORD), "the port's list carries no password")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.credentials.read", .tTool)
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 1000, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertTrue((+$Get(tToolHttp) = 200) && (tResult.%ToJSON() '[ ..#PASSWORD) && (tResult.%ToJSON() [ ..#NAME), "the agent's read tool lists it without the password")
    For tType = "ADDCREDENTIAL", "SETCREDENTIAL", "PASSWORDCREDENTIAL", "REMOVECREDENTIAL" {
        Kill tScript
        Set tScript("namespace") = "USER"
        Set tScript("id") = ..#NAME
        Set tSteps = $ClassMethod(..#PORT, "Snippet", "Credentials", tType, .tScript, {"Username": "u", "BusinessPartner": "", "Password": (..#PASSWORD)})
        Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
        Do $$$AssertTrue((tText [ ..#NAME) && (tText '[ ..#PASSWORD), tType _ ": the script form names the credential and never the password")
        If (tType = "ADDCREDENTIAL") || (tType = "PASSWORDCREDENTIAL") Do $$$AssertTrue(tText [ "<Password>", tType _ ": and renders the placeholder: " _ tText)
    }
    Set tBefore = $ClassMethod(..#FIXTURE, "CredentialCount", ..#NAME)
    Kill tScript
    Set tScript("namespace") = "USER"
    Set tScript("id") = $ZConvert(..#NAME, "L")
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Credentials", "ADDCREDENTIAL", .tScript, {"Username": "u", "BusinessPartner": ""})
    Do $$$AssertEquals(##class(OcuPilot.Test.AnalyticsListingGroupBase).RunScript(tSteps), 0, "the add's script only sets the refusal for a name held in another letter case (AD-59)")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CredentialCount", ..#NAME), tBefore, "and adds no credential")
}

}
