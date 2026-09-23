/// <p>The X.509 routes and tools against the instance itself (AD-4, AD-12, AD-27, AD-35, AD-39,
/// AD-55): the routes' envelopes, an import of a certificate alone then an edit that keeps the list
/// it did not send, an import with an encrypted key and its password, an alias compared exactly,
/// the agent's import completed from content through the real port and its delete, and every read
/// scanned for secret text -- the routes, the list read, the port's own reads, the stored proposal
/// and the instance's message log.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// the screen's own pairs, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code> --
/// because the legs import and delete real credentials. <method>OnBeforeAllTests</method> refuses
/// anywhere it does not, and refuses to adopt a probe alias the instance already holds;
/// <method>OnAfterOneTest</method> deletes the probe credentials by exact alias, never by prefix. The
/// PEM material is made once for the class by <class>OcuPilot.Test.X509Material</class>, which needs
/// the image's OpenSSL and <code>$ZF(-100)</code>.</p>
Class OcuPilot.Test.X509Wire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FORMPATH = "/x509/form";

Parameter NAMEPATH = "/x509/name";

Parameter CREATEPATH = "/x509";

/// <p>The edit route; <method>EditPath</method> fills its one segment.</p>
Parameter EDITPATH = "/x509/:id";

Parameter LIST = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter IMPORTTOOL = "OcuPilot.Screen.Tool.X509Import";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.X509Delete";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The screen read route the list and its read tool share (AD-36).</p>
Parameter READPATH = "/screens/security.x509/read?maxRows=1000";

/// <p>The probe aliases: one imported over the routes, the same alias in lower case, one imported
/// with a key, and one the agent imports and deletes.</p>
Parameter PROBE = "OcuPilotProbe85Wire";

Parameter LOWERPROBE = "ocupilotprobe85wire";

Parameter KEYPROBE = "OcuPilotProbe85Key";

Parameter AGENTPROBE = "OcuPilotProbe85Agent";

/// <p>Where the instance's message log was when this class began, which the log scan reads
/// from.</p>
Property StartedAt As %Integer [ InitialExpression = 0 ];

/// <p>The directory <class>OcuPilot.Test.X509Material</class> made the material in.</p>
Property MaterialDirectory As %String;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.X509Wire imports and deletes X.509 credentials on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was imported. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If ..Exists(..#PROBE) || ..Exists(..#LOWERPROBE) || ..Exists(..#KEYPROBE) || ..Exists(..#AGENTPROBE) {
        Quit $$$ERROR($$$GeneralError, "a probe credential of OcuPilot.Test.X509Wire already exists on this instance, and this class deletes what it creates -- it will not adopt one it did not make.")
    }
    Set ..StartedAt = ##class(%File).GetFileSize(..LogPath())
    Set tSC = ##class(OcuPilot.Test.X509Material).Generate(.tDirectory)
    Set ..MaterialDirectory = tDirectory
    Quit tSC
}

/// <p>Delete the material's directory; a failing status when it survives.</p>
Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.X509Material).Discard(..MaterialDirectory)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    For tAlias = ..#PROBE, ..#LOWERPROBE, ..#KEYPROBE, ..#AGENTPROBE {
        Do ..Remove(tAlias)
    }
    Do $$$AssertEquals(..Exists(..#PROBE) + ..Exists(..#LOWERPROBE) + ..Exists(..#KEYPROBE) + ..Exists(..#AGENTPROBE), 0, "the probe credentials are gone")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>AD-12, AD-39: the two reads, the import and the edit each answer exactly one JSON envelope
/// over a real HTTP request; an import naming nothing is refused on its own envelope code, and an
/// edit of an alias the instance does not hold is 404 with its own.</p>
/// <p>Mutation: render <method>OcuPilot.Area.Security.X509Save.RenderViolations</method> with
/// <code>RESOURCEVALIDATION</code> -> the envelope-code assertion goes red.</p>
Method TestEachRouteAnswersOneJsonEnvelopeOverTheWire()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tPath = tBase _ ..#FORMPATH, tBase _ ..#NAMEPATH _ "?alias=" _ ..#PROBE {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, tUser, tPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tPath _ ": at 200")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tPath _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tPath _ ": exactly one envelope")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH, .tStatus, .tBody)
    Do $$$AssertTrue($IsObject($Get(tBody)), "the form read answers a JSON object")
    If $IsObject($Get(tBody)) Do $$$AssertEquals(tBody.%Get("rules").%Size(), $ListLength(##class(OcuPilot.Api.Error).X509ViolationCodes()), "the form read carries one rule per X.509 code")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?alias=" _ ..#PROBE, .tStatus, .tBody)
    Do $$$AssertTrue($IsObject($Get(tBody)), "the look-up answers a JSON object")
    If $IsObject($Get(tBody)) Do $$$AssertEquals(tBody.%Get("taken"), 0, "the look-up answers a free alias as not taken")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, tPassword, .tStatus, .tBody, .tHeaders, "{}", "application/json")
    Do $$$AssertEquals(tStatus, 422, "an import naming nothing is refused at 422")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tParsed.code, ##class(OcuPilot.Api.Error).#X509VALIDATION, "with the import's own envelope code")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..EditPath(..#PROBE), tUser, tPassword, .tStatus, .tBody, .tHeaders, "{""OwnerList"":[""x""]}", "application/json")
    Do $$$AssertEquals(tStatus, 404, "an edit of an alias the instance does not hold is 404")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tParsed.code, ##class(OcuPilot.Api.Error).#X509ALIASABSENT, "with the absent code")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?alias=" _ ..#PROBE, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 404, "and so is the form read of one")
}

/// <p>AC2, AC4 over the wire: <code>POST /x509</code> imports a certificate alone with both lists;
/// the list's own read then shows its subject, issuer and validity; <code>PUT /x509/:id</code> with
/// the authorized users alone keeps the peers; a second import of the alias is refused as taken,
/// while the same alias in lower case is another credential.</p>
/// <p>Mutation: remove <code>Security.X509Credential/PUT</code> from
/// <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> -> the port answers 501 and the edit
/// leg goes red.</p>
Method TestAnImportShowsOnTheListAndAnEditKeepsTheOtherList()
{
    Set tRequest = {"Alias": (..#PROBE), "Certificate": (..Pem("Certificate")), "OwnerList": ["OcuPilotProbeOwner"], "PeerNames": ["probe.example"]}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the import answers 201")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%Get("alias"), 1: ""), ..#PROBE, "naming the alias")

    Set tRow = ..ListRow(..#PROBE)
    Do $$$AssertTrue($IsObject(tRow), "the list's own read carries the imported credential")
    If $IsObject(tRow) {
        Do $$$AssertEquals(tRow.%Get("SubjectDN"), "CN=OcuPilot Test Certificate", "with its subject")
        Do $$$AssertEquals(tRow.%Get("IssuerDN"), "CN=OcuPilot Test Certificate", "its issuer")
        Do $$$AssertTrue((tRow.%Get("ValidityNotBefore") '= "") && (tRow.%Get("ValidityNotAfter") '= ""), "and its validity")
    }

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..EditPath(..#PROBE), .tStatus, .tBody, "{""OwnerList"":[""OcuPilotProbeOther""]}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the edit answers 200")
    Do $$$AssertEquals(..Lists(..#PROBE), "OcuPilotProbeOther|probe.example|", "the authorized users changed, the peers and the CA file kept")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "a second import of the alias is refused")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: "") [ ##class(OcuPilot.Api.Error).#X509ALIASTAKEN, 1, "as taken")
    Do $$$AssertEquals(..Lists(..#PROBE), "OcuPilotProbeOther|probe.example|", "and the credential was not rewritten")

    Do tRequest.%Set("Alias", ..#LOWERPROBE)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the alias in lower case is another credential")
    Do $$$AssertEquals(..Exists(..#PROBE) + ..Exists(..#LOWERPROBE), 2, "and both are held")
}

/// <p>AC3 over the wire: a credential imported with an encrypted key and its password is held with
/// its key, and no read afterwards -- the form read, the look-up, the list's read, the port's own
/// read and certificate read -- carries the key, the certificate or the password. A refused import
/// with the wrong password writes none of them either.</p>
/// <p>Mutation: add the stored <code>PrivateKey</code> to
/// <method>OcuPilot.Area.Security.X509Rules.HandleForm</method>'s <code>credential</code> -> the form
/// read's scan goes red.</p>
Method TestNoReadCarriesTheKeyOrItsPassword()
{
    Set tSecrets = ..Secrets()
    Set tRequest = {"Alias": (..#KEYPROBE), "OwnerList": [], "PeerNames": []}
    Do tRequest.%Set("Certificate", tSecrets.%Get("Certificate")), tRequest.%Set("PrivateKey", tSecrets.%Get("PrivateKey")), tRequest.%Set("PrivateKeyPassword", tSecrets.%Get("PrivateKeyPassword"))
    Do tRequest.%Set("PrivateKeyPassword", "not the password")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "an import with the wrong password is refused")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: "") [ ##class(OcuPilot.Api.Error).#X509PRIVATEKEYPASSWORDWRONG, 1, "on the password")
    Do $$$AssertEquals(..Leak($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: ""), tSecrets), "", "with no secret in its envelope")
    Do $$$AssertEquals(..Exists(..#KEYPROBE), 0, "and nothing was imported")

    Do tRequest.%Set("PrivateKeyPassword", tSecrets.%Get("PrivateKeyPassword"))
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the import with its password answers 201")
    Do $$$AssertEquals(..Info(..#KEYPROBE).%Get("HasPrivateKey"), 1, "and the instance holds its key")

    Set tReads = ""
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?alias=" _ ..#KEYPROBE, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the form read answers")
    If $IsObject($Get(tBody)) {
        Set tReads = tReads _ tBody.%ToJSON()
        Do $$$AssertEquals(tBody.%Get("credential").%Get("HasPrivateKey"), 1, "reporting a key is present")
        For tField = "Certificate", "PrivateKey", "PrivateKeyPassword" {
            Do $$$AssertEquals(tBody.%Get("credential").%GetTypeOf(tField), "unassigned", "and never carrying " _ tField)
        }
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?alias=" _ ..#KEYPROBE, .tStatus, .tBody)
    If $IsObject($Get(tBody)) Set tReads = tReads _ tBody.%ToJSON()
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#READPATH, .tStatus, .tBody)
    If $IsObject($Get(tBody)) Set tReads = tReads _ tBody.%ToJSON()
    Set tReads = tReads _ ..Info(..#KEYPROBE).%ToJSON() _ ..Read(..#KEYPROBE, "GET").%ToJSON()
    Do $$$AssertTrue(tReads [ ..#KEYPROBE, "the reads name the credential")
    Do $$$AssertEquals(..Leak(tReads, tSecrets), "", "and none carries its certificate, key or password")
}

/// <p>AD-27's second case, AC5 and AC3 through the real port: the agent's import, minted with the
/// two lists and confirmed with the certificate, key and password, is completed from content -- the
/// instance holds the credential with its key -- and nothing of the secrets is in the stored
/// proposal or the instance's message log. Its delete, confirmed the same way, removes it.</p>
/// <p>Mutation: empty <parameter>OcuPilot.Port.AdminPort.CONTENTCOMPLETEDTYPES</parameter> -> the
/// vendor's own <code>POST</code> refuses the content keys and the import leg goes red.</p>
Method TestTheAgentImportIsCompletedFromContentAndItsDeleteRemovesIt()
{
    Set tSecrets = ..Secrets()
    Set tSC = ..Mint(..#IMPORTTOOL, ..#AGENTPROBE, {"Alias": (..#AGENTPROBE), "PeerNames": ["probe.example"]}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the import is minted")
    If $$$ISERR(tSC) Quit
    Set tKey = tProposal.%Get("proposalId")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tKey, tSecrets, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirmed with its secrets: " _ $Get(tCode))
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "created", "answering the created action")
    Set tInfo = ..Info(..#AGENTPROBE)
    Do $$$AssertEquals(tInfo.%Get("SubjectDN") _ "|" _ tInfo.%Get("HasPrivateKey"), "CN=OcuPilot Test Certificate|1", "the instance holds the certificate and its key")
    Do $$$AssertEquals(..Lists(..#AGENTPROBE), "|probe.example|", "with the lists the proposal carried")

    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tValues)
    Set tStored = $Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))
    Do $$$AssertEquals(..Leak(tStored, tSecrets), "", "the stored proposal carries no secret")

    Set tSC = ..Mint(..#DELETETOOL, ..#AGENTPROBE, {"Alias": (..#AGENTPROBE)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is minted against the live credential")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "deleted", "answering the deleted action")
    Do $$$AssertEquals(..Exists(..#AGENTPROBE), 0, "and the instance no longer holds it")
}

/// <p>AC3 on the agent's path through the real port: an import confirmed with a key that does not
/// belong to the certificate is refused at the port and saves nothing, and neither the confirm's
/// answer nor the stored proposal carries the certificate or the key. The port logs the refusal,
/// which <method>TestZNothingReachedTheMessageLog</method> then finds and scans.</p>
Method TestARefusedAgentImportSavesNothingAndAnswersNoSecret()
{
    Set tSecrets = {"Certificate": (..Pem("Certificate")), "PrivateKey": (..Pem("OtherKey"))}
    Set tSC = ..Mint(..#IMPORTTOOL, ..#AGENTPROBE, {"Alias": (..#AGENTPROBE)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the import is minted")
    If $$$ISERR(tSC) Quit
    Set tKey = tProposal.%Get("proposalId")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tKey, tSecrets, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm with a key that is not the certificate's is refused")
    Do $$$AssertEquals(tHttp, 400, "at 400")
    Do $$$AssertEquals(..Exists(..#AGENTPROBE), 0, "and nothing was imported")
    Set tAnswer = $Get(tCode) _ $Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "") _ $Select($IsObject($Get(tDetail)): tDetail.%ToJSON(), 1: "") _ $System.Status.GetErrorText(tSC)
    Do $$$AssertEquals(..Leak(tAnswer, tSecrets), "", "the confirm's answer carries no certificate or key")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tValues)
    Do $$$AssertEquals(..Leak($Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff")), tSecrets), "", "nor the stored proposal")
}

/// <p>AC3, AD-35: nothing this class did -- the refused imports, the confirmed ones, the edits and
/// the delete -- wrote the certificate, a key or a password into the instance's message log. Named
/// to run last, so the log it scans covers every other leg; it first requires the refusal
/// <method>TestARefusedAgentImportSavesNothingAndAnswersNoSecret</method> logged, so a scan that
/// read nothing, or the wrong part of the file, cannot pass.</p>
/// <p>Mutation: append the key text to the status
/// <method>OcuPilot.Port.AdminPort.ImportThroughClass</method> returns for a refused save -> the
/// refusal's log line carries it and the scan goes red.</p>
Method TestZNothingReachedTheMessageLog()
{
    Set tLog = ..LogSince(..StartedAt)
    Do $$$AssertTrue(tLog [ ##class(OcuPilot.Api.Error).#X509PRIVATEKEYMISMATCH, "the log read covers this class's run: it holds the refused agent import's line")
    Do $$$AssertEquals(..Leak(tLog, ##class(OcuPilot.Test.X509Material).All()), "", "the message log written since this class began carries no certificate, key or password")
}

/// <p>The three secrets the imports here carry.</p>
ClassMethod Secrets() As %DynamicObject
{
    Quit {"Certificate": (..Pem("Certificate")), "PrivateKey": (..Pem("EncryptedKey")), "PrivateKeyPassword": (##class(OcuPilot.Test.X509Material).#PASSWORD)}
}

ClassMethod Pem(pName As %String) As %String
{
    Quit ##class(OcuPilot.Test.X509Material).Pem(pName)
}

ClassMethod Leak(pText As %String, pSecrets As %DynamicObject) As %String
{
    Quit ##class(OcuPilot.Test.X509Material).Leak(pText, pSecrets)
}

/// <p>The list row the screen's own read answers for <var>pAlias</var>, or <code>""</code>.</p>
ClassMethod ListRow(pAlias As %String) As %DynamicObject
{
    Set tRow = ""
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#READPATH, .tStatus, .tBody)
    If '$IsObject($Get(tBody)) || (tBody.%GetTypeOf("rows") '= "array") Quit ""
    Set tIterator = tBody.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If $IsObject(tEntry) && (tEntry.%Get("Alias") = pAlias) Set tRow = tEntry Quit
    }
    Quit tRow
}

/// <p>The credential <var>pAlias</var> through the port's own read of type <var>pType</var>, or
/// <code>{}</code>.</p>
ClassMethod Read(pAlias As %String, pType As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("alias") = pAlias
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.X509Credential", pType, .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Quit {}
    Quit tResult
}

ClassMethod Info(pAlias As %String) As %DynamicObject
{
    Quit ..Read(pAlias, "CERTINFO")
}

/// <p><var>pAlias</var>'s owners, peers and CA file as <code>owners|peers|cafile</code>, each list
/// comma-separated.</p>
ClassMethod Lists(pAlias As %String) As %String
{
    Set tRead = ..Read(pAlias, "GET")
    Set tOut = ""
    For tField = "OwnerList", "PeerNames" {
        Set tJoined = ""
        If tRead.%GetTypeOf(tField) = "array" {
            Set tIterator = tRead.%Get(tField).%GetIterator()
            While tIterator.%GetNext(.tIndex, .tValue) {
                Set tJoined = tJoined _ $Select(tJoined = "": "", 1: ",") _ tValue
            }
        }
        Set tOut = tOut _ tJoined _ "|"
    }
    Quit tOut _ tRead.%Get("CAFile")
}

/// <p>Mint one write of tool <var>pTool</var> against <var>pAlias</var> through the shipped mint and
/// port.</p>
Method Mint(pTool As %String, pAlias As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#LIST, $Parameter(pTool, "TOOLNAME"), $Username, "", tTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pAlias, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p><parameter>EDITPATH</parameter> for alias <var>pAlias</var>, its segment encoded by the one
/// shared encoder (AD-13).</p>
ClassMethod EditPath(pAlias As %String) As %String
{
    Quit $Replace(..#EDITPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pAlias))
}

/// <p>The instance's message log.</p>
ClassMethod LogPath() As %String
{
    Quit ##class(%File).NormalizeFilename("messages.log", $System.Util.ManagerDirectory())
}

/// <p>What the message log gained after byte <var>pOffset</var>, at most 4 MB of it.</p>
ClassMethod LogSince(pOffset As %Integer) As %String
{
    Set tText = ""
    Try {
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Set tSC = tStream.LinkToFile(..LogPath())
        If $$$ISERR(tSC) Quit
        If pOffset > 0 Do tStream.MoveTo(pOffset + 1)
        While 'tStream.AtEnd && ($Length(tText) < 4000000) {
            Set tText = tText _ tStream.Read(32000)
        }
    } Catch {
        Set tText = ""
    }
    Quit tText
}

/// <p>Whether the instance holds a credential with exactly the alias <var>pAlias</var>.</p>
ClassMethod Exists(pAlias As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(%SYS.X509Credentials).Exists(pAlias)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = 0
    }
    Quit tExists
}

/// <p>Delete the credential with exactly the alias <var>pAlias</var>, if there is one.</p>
ClassMethod Remove(pAlias As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(%SYS.X509Credentials).Exists(pAlias) Do ##class(%SYS.X509Credentials).Delete(pAlias)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

}
