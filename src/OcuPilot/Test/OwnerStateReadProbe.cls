/// <p>The child process <class>OcuPilot.Test.OwnerStateRead</class> starts to read the proposal, ledger and
/// per-user stores as a <b>real principal</b> (AD-9). It adds the read steps to
/// <class>OcuPilot.Test.OwnerStateWriteProbe</class>; any step it does not name is the parent's.</p>
/// <p>Every read step answers <code>{kind, ok, code, text}</code> plus <code>seen</code>, the identifying
/// values the call handed back joined by <code>|</code> (<code>""</code> when it handed back none), so a
/// test asserts that a refused read leaked nothing.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OwnerStateReadProbe Extends OcuPilot.Test.OwnerStateWriteProbe
{

Parameter STOREPACKAGE = "OcuPilot.Kernel.State.";

/// <p>Whether <var>pKind</var> is a step this class or a parent class runs.</p>
ClassMethod Handles(pKind As %String) As %Boolean
{
    If $ListFind(..ReadKinds(), pKind) Quit 1
    Quit ##super(pKind)
}

/// <p>The steps this class adds. <code>OwnerRead.Open</code>, <code>OwnerRead.Exists</code> and
/// <code>OwnerRead.StoredValue</code> call <code>Base</code>'s three public reads on the store
/// <code>store</code>; the <code>OwnerRead.Propose.*</code> and <code>OwnerRead.Ledger.*</code> steps call the
/// stores' own key, token, id and user reads; the <code>Route.*</code> steps call the confirm, cancel, draft,
/// claim and transcript-gate paths a person's request reaches and answer the HTTP status and code each maps
/// to; <code>Direct.OpenId</code> and <code>Direct.Sql</code> are the controls, a direct open and a direct
/// query of the protected tables; <code>Held.Stream</code> opens the principal's own proposal and reads its
/// stream outside the escalated frame; <code>Held.StreamSwap</code> holds the principal's own proposal <code>id</code>
/// with its arguments pointed at stream <code>stream</code> and reads proposal <code>key</code>;
/// <code>Held.BaseSave</code> opens the principal's own proposal <code>id</code>, marks it confirmed in memory and
/// saves it through <code>Base</code>'s public save (<code>via</code> <code>save</code> or
/// <code>saveIfCurrent</code>). Each answers <code>opened</code>.</p>
ClassMethod ReadKinds() As %List
{
    Quit $ListBuild("OwnerRead.Open", "OwnerRead.Exists", "OwnerRead.StoredValue", "OwnerRead.Propose.GuardedByKey", "OwnerRead.Propose.GuardedByToken", "OwnerRead.Propose.GuardedRowVersion", "OwnerRead.Propose.GuardedRowsForTurn", "OwnerRead.Propose.GuardedRowsForConvo", "OwnerRead.Propose.GuardedCountForTurn", "OwnerRead.Ledger.GuardedRow", "OwnerRead.Ledger.GuardedIdsForWindow", "OwnerRead.Ledger.GuardedDroppedFor", "OwnerRead.Ledger.GuardedCountForTurn", "Route.Confirm", "Route.Cancel", "Route.Draft", "Route.Claim", "Route.ClaimById", "Route.TranscriptGate", "Direct.OpenId", "Direct.Sql", "Held.Stream", "Held.StreamSwap", "Held.BaseSave")
}

/// <p>Run one step of the plan: the call its <code>kind</code> names, answered as
/// <code>{kind, ok, code, text, seen}</code> plus what the kind adds.</p>
ClassMethod Step(pStep As %DynamicObject) As %DynamicObject
{
    Set tKind = pStep.%Get("kind")
    If '$ListFind(..ReadKinds(), tKind) Quit ##super(pStep)
    Set tLeg = {}
    Set tSC = $$$OK
    Set tSeen = ""
    Try {
        Kill tValues, tRows, tByTurn
        Set tPackage = ..#STOREPACKAGE
        Set tPropose = tPackage _ "Propose"
        Set tLedger = tPackage _ "Ledger"
        If tKind = "OwnerRead.Open" {
            Set tClass = tPackage _ pStep.%Get("store")
            Set tSC = $ClassMethod(tClass, "GuardedOpenId", pStep.%Get("id"), .tRow)
            Do tLeg.%Set("opened", ''$IsObject($Get(tRow)), "boolean")
            If $IsObject($Get(tRow)) Set tSeen = ..Describe($ClassName(tRow), tRow)
            Set tRow = ""
        } ElseIf tKind = "OwnerRead.Exists" {
            Set tSC = $ClassMethod(tPackage _ pStep.%Get("store"), "GuardedExistsId", pStep.%Get("id"), .tExists)
            Do tLeg.%Set("exists", ''$Get(tExists), "boolean")
            If $Get(tExists) Set tSeen = "exists"
        } ElseIf tKind = "OwnerRead.StoredValue" {
            Set tSC = $ClassMethod(tPackage _ pStep.%Get("store"), "GuardedStoredValue", pStep.%Get("method"), pStep.%Get("key"), pStep.%Get("property"), .tValue, .tFound)
            Do tLeg.%Set("found", ''$Get(tFound), "boolean")
            Set tSeen = $Get(tValue)
        } ElseIf tKind = "OwnerRead.Propose.GuardedByKey" {
            Set tSC = $ClassMethod(tPropose, "GuardedByKey", pStep.%Get("key"), .tFound, .tValues)
            Do tLeg.%Set("found", ''$Get(tFound), "boolean")
            Set tSeen = ..ProposalSeen(.tValues)
        } ElseIf tKind = "OwnerRead.Propose.GuardedByToken" {
            Set tSC = $ClassMethod(tPropose, "GuardedByToken", pStep.%Get("token"), .tFound, .tValues)
            Do tLeg.%Set("found", ''$Get(tFound), "boolean")
            Set tSeen = ..ProposalSeen(.tValues)
        } ElseIf tKind = "OwnerRead.Propose.GuardedRowVersion" {
            Set tSC = $ClassMethod(tPropose, "GuardedRowVersion", pStep.%Get("key"), .tVersion)
            Do tLeg.%Set("version", +$Get(tVersion), "number")
            If +$Get(tVersion) Set tSeen = "version " _ tVersion
        } ElseIf tKind = "OwnerRead.Propose.GuardedRowsForTurn" {
            Set tSC = $ClassMethod(tPropose, "GuardedRowsForTurn", pStep.%Get("turnKey"), pStep.%Get("user"), .tRows)
            If $IsObject($Get(tRows)) && (tRows.%Size() > 0) Set tSeen = tRows.%Size() _ " rows " _ tRows.%Get(0).%Get("proposalId")
        } ElseIf tKind = "OwnerRead.Propose.GuardedRowsForConvo" {
            Set tSC = $ClassMethod(tPropose, "GuardedRowsForConvo", pStep.%Get("convKey"), pStep.%Get("user"), .tByTurn)
            Set tTurn = $Order(tByTurn(""))
            If tTurn '= "" Set tSeen = "turn " _ tTurn _ " " _ tByTurn(tTurn).%Size() _ " rows"
        } ElseIf tKind = "OwnerRead.Propose.GuardedCountForTurn" {
            Set tSC = $ClassMethod(tPropose, "GuardedCountForTurn", pStep.%Get("turnKey"), .tCount)
            Do tLeg.%Set("count", +$Get(tCount), "number")
            If +$Get(tCount) Set tSeen = "count " _ tCount
        } ElseIf tKind = "OwnerRead.Ledger.GuardedRow" {
            Set tSC = $ClassMethod(tLedger, "GuardedRow", pStep.%Get("id"), .tValues)
            Set tSeen = ..LedgerSeen(.tValues)
        } ElseIf tKind = "OwnerRead.Ledger.GuardedIdsForWindow" {
            Set tSC = $ClassMethod(tLedger, "GuardedIdsForWindow", pStep.%Get("user"), pStep.%Get("window"), pStep.%Get("turnKey"), 50, .tIds, .tProblem, "", "", "", +pStep.%Get("all"))
            Do tLeg.%Set("count", +$Get(tIds), "number")
            If +$Get(tIds) Set tSeen = +$Get(tIds) _ " ids " _ $Get(tIds(1))
        } ElseIf tKind = "OwnerRead.Ledger.GuardedDroppedFor" {
            Set tSC = $ClassMethod(tLedger, "GuardedDroppedFor", pStep.%Get("user"), pStep.%Get("window"), pStep.%Get("turnKey"), .tCount, "", "", "", +pStep.%Get("all"))
            Do tLeg.%Set("count", +$Get(tCount), "number")
            If +$Get(tCount) Set tSeen = "dropped " _ tCount
        } ElseIf tKind = "OwnerRead.Ledger.GuardedCountForTurn" {
            Set tSC = $ClassMethod(tLedger, "GuardedCountForTurn", pStep.%Get("turnKey"), .tCount)
            Do tLeg.%Set("count", +$Get(tCount), "number")
            If +$Get(tCount) Set tSeen = "count " _ tCount
        } ElseIf tKind = "Route.Confirm" {
            Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(pStep.%Get("id"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
            Do ..RouteAnswer(tLeg, tHttp, tCode)
        } ElseIf tKind = "Route.Cancel" {
            Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Cancel(pStep.%Get("id"), $Username, .tResult, .tHttp, .tCode)
            Do ..RouteAnswer(tLeg, tHttp, tCode)
        } ElseIf tKind = "Route.Draft" {
            Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(pStep.%Get("id"), $Username, "http://localhost", .tAnswer, .tHttp, .tCode)
            Do ..RouteAnswer(tLeg, tHttp, tCode)
        } ElseIf tKind = "Route.Claim" {
            Set tSC = ##class(OcuPilot.Kernel.Proposal.Write).Claim(pStep.%Get("id"), pStep.%Get("token"), $Username, .tProposal, .tCode)
            Do ..RouteAnswer(tLeg, "", tCode)
            If $Data(tProposal) Set tSeen = "claimed"
        } ElseIf tKind = "Route.ClaimById" {
            Set tSC = ##class(OcuPilot.Kernel.Proposal.Write).ClaimById(pStep.%Get("id"), $Username, .tProposal, .tCode)
            Do ..RouteAnswer(tLeg, "", tCode)
            If $Data(tProposal) Set tSeen = "claimed"
        } ElseIf tKind = "Route.TranscriptGate" {
            Set tTurnKeys = $ListBuild(pStep.%Get("turnKey"))
            Set tSC = ##class(OcuPilot.Kernel.Audit.Ledger).GateTurns($Username, pStep.%Get("subject"), pStep.%Get("convKey"), tTurnKeys, .tReleased, .tFailedPair, .tFault)
            Do tLeg.%Set("released", ''$Get(tReleased), "boolean")
            Do tLeg.%Set("faultCode", $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "string")
        } ElseIf tKind = "Direct.OpenId" {
            Set tRow = $ClassMethod(tPackage _ pStep.%Get("store"), "%OpenId", pStep.%Get("id"), 0, .tSC)
            If $IsObject($Get(tRow)) Set tSeen = "opened"
            Set tRow = ""
        } ElseIf tKind = "Direct.Sql" {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State." _ pStep.%Get("table"))
            Do tLeg.%Set("sqlcode", tRS.%SQLCODE, "number")
            If tRS.%SQLCODE < 0 {
                Set tSC = $$$ERROR($$$GeneralError, "SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
            } ElseIf tRS.%Next() {
                Set tSeen = "count " _ tRS.%GetData(1)
            }
        } ElseIf tKind = "Held.StreamSwap" {
            Set tSC = $ClassMethod(tPropose, "GuardedOpenId", pStep.%Get("id"), .tRow)
            Do tLeg.%Set("opened", ''$$$ISOK(tSC), "boolean")
            If $$$ISOK(tSC) {
                Do tRow.ArgumentsSetObjectId(pStep.%Get("stream"))
                Set tSC = $ClassMethod(tPropose, "GuardedByKey", pStep.%Get("key"), .tFound, .tValues)
                Set tSeen = ..ProposalSeen(.tValues)
            }
            Set tRow = ""
        } ElseIf tKind = "Held.BaseSave" {
            Set tSC = $ClassMethod(tPropose, "GuardedOpenId", pStep.%Get("id"), .tRow)
            Do tLeg.%Set("opened", ''$$$ISOK(tSC), "boolean")
            If $$$ISOK(tSC) {
                Set tRow.State = "confirmed"
                Set tSC = ..SaveThroughBase(tRow, pStep.%Get("via") = "save")
            }
            Set tRow = ""
        } ElseIf tKind = "Held.Stream" {
            Set tSC = $ClassMethod(tPropose, "GuardedOpenId", pStep.%Get("id"), .tRow)
            Do tLeg.%Set("opened", ''$$$ISOK(tSC), "boolean")
            If $$$ISOK(tSC) {
                Try {
                    Set tText = tRow.Arguments.Read(100)
                    Set tSeen = "stream " _ tText
                } Catch ex {
                    Set tSC = ex.AsStatus()
                }
            }
            Set tRow = ""
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Do tLeg.%Set("kind", tKind, "string")
    Do tLeg.%Set("ok", ''$$$ISOK(tSC), "boolean")
    Do tLeg.%Set("code", $Select($$$ISOK(tSC): "", 1: $Piece($System.Status.GetErrorCodes(tSC), ",", 1)), "string")
    Do tLeg.%Set("text", $Select($$$ISOK(tSC): "", 1: $System.Status.GetErrorText(tSC)), "string")
    Do tLeg.%Set("seen", tSeen, "string")
    Quit tLeg
}

/// <p>What opened row <var>pRow</var> of <var>pClass</var> says about its owner and content, joined by
/// <code>|</code>.</p>
ClassMethod Describe(pClass As %String, pRow As OcuPilot.Kernel.State.Base) As %String
{
    Set tText = pRow.%Id() _ "|" _ $Property(pRow, $Parameter(pClass, "OWNERWRITE"))
    If pClass [ "Propose" Set tText = tText _ "|" _ pRow.ToolName _ "|" _ pRow.TargetRef
    If pClass [ "Ledger" Set tText = tText _ "|" _ pRow.Name _ "|" _ pRow.Arguments
    Quit tText
}

/// <p>The identifying values of the proposal projection <var>pValues</var>, joined by <code>|</code>, or
/// <code>""</code> when it holds none.</p>
ClassMethod ProposalSeen(ByRef pValues) As %String
{
    If '$Data(pValues) Quit ""
    Quit $Get(pValues("proposalId")) _ "|" _ $Get(pValues("user")) _ "|" _ $Get(pValues("toolName")) _ "|" _ $Get(pValues("targetRef")) _ "|" _ $Get(pValues("arguments"))
}

/// <p>The identifying values of the ledger projection <var>pValues</var>, joined by <code>|</code>, or
/// <code>""</code> when it holds none.</p>
ClassMethod LedgerSeen(ByRef pValues) As %String
{
    If '$Data(pValues) Quit ""
    Quit $Get(pValues("ledgerId")) _ "|" _ $Get(pValues("user")) _ "|" _ $Get(pValues("name")) _ "|" _ $Get(pValues("arguments"))
}

/// <p>Add the HTTP status and the machine code a route answered to <var>pLeg</var>.</p>
ClassMethod RouteAnswer(pLeg As %DynamicObject, pHttp As %String, pCode As %String)
{
    Do pLeg.%Set("http", +$Get(pHttp), "number")
    Do pLeg.%Set("routeCode", $Get(pCode), "string")
}

}
