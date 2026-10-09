/// <p>Pins that every screen Save route takes its target's hold (AD-34, AD-53, AD-55): each
/// <code>PUT</code> and <code>POST</code> route in <class>OcuPilot.Api.Router</class>'s URL map whose
/// handler writes an instance object calls <method>OcuPilot.Kernel.Proposal.Operation.HoldTool</method>
/// and releases it, and every other route is listed in <method>Exemptions</method> with its reason.</p>
/// <p><b>A tripwire aimed at later epics.</b> A new write route fails this class until its handler
/// takes the hold or the route joins <method>Exemptions</method> with a reason. A listed route that is
/// no longer in the map fails it too, so the list cannot go stale.</p>
/// <p>Three create Saves build their target's id from more than one body field, as their tools' mints
/// do; <method>TestACreateSaveHoldsTheKeyItsMintComputes</method> holds each mint's key and sees the
/// Save wait on it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot compiled with its class definitions, which
/// the throwaway keeps, and serving its API for the held-key legs, which write nothing.</p>
Class OcuPilot.Test.SaveHoldCoverage Extends %UnitTest.TestCase
{

Parameter ROUTER = "OcuPilot.Api.Router";

/// <p>The write routes that take no hold, each as <code>METHOD url</code> with its reason. A row
/// also exempts every route whose url continues it after a slash.</p>
ClassMethod Exemptions() As %List
{
    Quit $ListBuild($ListBuild("POST /agent/", "agent configuration and credentials are not an instance object a write tool targets"), $ListBuild("PUT /agent/", "agent configuration is not an instance object a write tool targets"), $ListBuild("POST /turn", "a turn is OcuPilot's own state"), $ListBuild("POST /proposal/", "a confirm holds its target itself (AD-34)"), $ListBuild("POST /conversation", "a conversation is OcuPilot's own state"), $ListBuild("POST /account/", "the caller's own account and preferences"), $ListBuild("POST /screens/", "the screen action route holds its target itself (AD-53)"), $ListBuild("POST /database/check", "reads only"), $ListBuild("POST /ssl/:id/test", "reads only"), $ListBuild("POST /ldap/:id/test", "reads only"), $ListBuild("POST /tasks/check", "reads only"), $ListBuild("POST /license/key/validate", "reads only"), $ListBuild("POST /oauth/server-description/discover", "reads only"), $ListBuild("POST /explorer/sql/run", "runs only a statement the instance types as a query"), $ListBuild("POST /explorer/sql/plan", "explains a statement and runs nothing"), $ListBuild("POST /explorer/sql/background", "runs only a statement the instance types as a query, in the caller's own background run"), $ListBuild("POST /explorer/sql/background/:id/cancel", "stops the caller's own background run, which is OcuPilot's own state"), $ListBuild("POST /explorer/sql/data", "reads a page of a table"), $ListBuild("POST /users/password-check", "checks a candidate password against the instance's policy and writes nothing"))
}

/// <p>Every <code>PUT</code> and <code>POST</code> route that is not exempt takes the hold, and
/// every exemption names a route that exists.</p>
/// <p>Mutation (Rule 19): drop the hold from <method>OcuPilot.Area.Explorer.DocDbSave.HandleCreate</method>
/// -- its route goes red here.</p>
Method TestEveryWriteRouteTakesTheHoldOrIsExempt()
{
    Set tRoutes = ..Routes()
    Set tExemptions = ..Exemptions()
    Set tCovered = 0
    Set tWrites = 0
    Kill tUsed
    For tI = 1:1:$ListLength(tRoutes) {
        Set tRoute = $List(tRoutes, tI)
        Set tMethod = $List(tRoute, 2)
        If (tMethod '= "PUT") && (tMethod '= "POST") Continue
        Set tWrites = tWrites + 1
        Set tKey = tMethod _ " " _ $List(tRoute, 1)
        Set tExempted = 0
        For tJ = 1:1:$ListLength(tExemptions) {
            Set tPattern = $List($List(tExemptions, tJ), 1)
            Set tBoundary = tPattern _ $Select($Extract(tPattern, $Length(tPattern)) = "/": "", 1: "/")
            If (tKey = tPattern) || ($Extract(tKey, 1, $Length(tBoundary)) = tBoundary) {
                Set tUsed(tJ) = 1
                Set tExempted = 1
            }
        }
        If tExempted Continue
        Set tHandler = ..HandlerOf($List(tRoute, 3), .tClass, .tName)
        Do $$$AssertTrue(tHandler '= "", tKey _ " resolves to a handler (" _ tClass _ "." _ tName _ ")")
        If tHandler = "" Continue
        Do $$$AssertTrue((tHandler [ ".HoldTool(") && (tHandler [ ".Release("), tKey _ " takes the target hold and releases it in " _ tClass _ "." _ tName)
        Set tCovered = tCovered + 1
    }
    Do $$$AssertTrue(tWrites > 0, "the route map holds write routes")
    Do $$$AssertTrue(tCovered > 0, "and some of them are screen Saves that take the hold")
    For tJ = 1:1:$ListLength(tExemptions) {
        Do $$$AssertTrue($Get(tUsed(tJ)), "the exemption '" _ $List($List(tExemptions, tJ), 1) _ "' names a route in the map")
    }
}

/// <p>The audit event create holds <code>Source/Type/Name</code>, the create tool's
/// <code>EventName</code>, and the key file create the composite of <code>root</code> and
/// <code>path</code> its tool's mint builds: with this process holding each key as another write
/// would, the Save waits out <parameter>OcuPilot.Kernel.State.Propose.CLAIMLOCKSECONDS</parameter> and
/// answers 409 <code>WRITE.TARGETBUSY</code>. Each body also breaks a rule the Save checks after the
/// hold, so a Save holding any other key answers that refusal instead, and neither writes.</p>
/// <p>Mutation (Rule 19): hold the key file's <code>path</code> alone in
/// <method>OcuPilot.Area.Security.EncryptionKeyFileSave.HandleCreate</method>, or the body's absent
/// <code>EventName</code> in <method>OcuPilot.Area.Security.AuditEventSave.HandleCreate</method> --
/// that leg answers 400 or 422 at once and goes red.</p>
Method TestACreateSaveHoldsTheKeyItsMintComputes()
{
    Set tKeyFile = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("/ocuprobe/hold/", "hold.key"))
    Do ..HeldLeg("/audit-events", "OcuPilot.Screen.Tool.AuditUserEventCreate", "OcuProbeHold/Hold/Key", {"Source": "OcuProbeHold", "Type": "Hold", "Name": "Key", "Enabled": "not a flag"}.%ToJSON())
    Do ..HeldLeg("/encryption-key-file", "OcuPilot.Screen.Tool.EncryptionKeyFileCreate", tKeyFile, {"root": "/ocuprobe/hold/", "path": "hold.key", "OcuProbeUnexpected": 1}.%ToJSON())
    ; The Save names the application in another case, so the leg holds only if both sides fold it (foldcase-firstpart).
    Set tEntry = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("/csp/ocuprobehold", "AllowClass", "%OcuProbe1810.Hold"))
    Do ..HeldLeg("/web-app/pct-access", "OcuPilot.Screen.Tool.WebAppPctAccessCreate", tEntry, {"Name": "/CSP/OcuProbeHold", "AllowType": "AllowClass", "Class": "%OcuProbe1810.Hold", "AllowAccess": "not a flag"}.%ToJSON())
}

/// <p>Hold the key <var>pTool</var>'s mint computes for <var>pId</var>, <code>POST</code>
/// <var>pBody</var> to <var>pPath</var>, release, and assert the Save was refused busy after the wait.</p>
Method HeldLeg(pPath As %String, pTool As %String, pId As %String, pBody As %String)
{
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).TargetRefOf($Parameter(pTool, "DESCRIPTORCLASS"), pId, .tRef)
    Do $$$AssertStatusOK(tSC, pPath _ ": the mint's reference is built")
    Set tLockKey = ##class(OcuPilot.Kernel.State.Propose).TargetHoldKey($Get(tRef))
    Do $$$AssertNotEquals(tLockKey, "", pPath _ ": the target names a lock")
    If tLockKey = "" Quit
    Lock +^OcuPilotProposalTarget(tLockKey):5
    Set tHeld = $Test
    Do $$$AssertTrue(tHeld, pPath _ ": this process holds it, as another write's hold does")
    If 'tHeld Quit
    Set tStatus = 0
    Set tAnswer = ""
    Set tWaited = 0
    Try {
        Set tStarted = $ZHorolog
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", pPath, .tStatus, .tAnswer, pBody, "application/json")
        Set tWaited = $ZHorolog - tStarted
    } Catch {
        Set tWaited = 0
    }
    Lock -^OcuPilotProposalTarget(tLockKey)
    Set tSaid = tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tAnswer)
    Do $$$AssertEquals(tSaid, "409 WRITE.TARGETBUSY", pPath _ ": the Save on the held key is refused busy")
    Do $$$AssertTrue(tWaited >= ($Parameter("OcuPilot.Kernel.State.Propose", "CLAIMLOCKSECONDS") - 1), pPath _ ": after waiting for the hold (" _ $FNumber(tWaited, "", 1) _ " s)")
}

/// <p>Every route in the URL map, as <code>$ListBuild(url, method, call)</code>.</p>
ClassMethod Routes() As %List
{
    Set tList = ""
    Set tXData = ##class(%Dictionary.XDataDefinition).%OpenId(..#ROUTER _ "||UrlMap")
    If '$IsObject(tXData) Quit ""
    Set tText = tXData.Data.Read(3000000)
    For tI = 2:1:$Length(tText, "<Route ") {
        Set tPiece = $Piece($Piece(tText, "<Route ", tI), "/>", 1)
        Set tList = tList _ $ListBuild($ListBuild($Piece(tPiece, """", 2), $Piece(tPiece, """", 4), $Piece(tPiece, """", 6)))
    }
    Quit tList
}

/// <p>The source of the handler the router method <var>pCall</var> delegates to, with its class and
/// method name in <var>pClass</var> and <var>pName</var>: the method's own class when it is inherited.
/// <code>""</code> when it cannot be read.</p>
ClassMethod HandlerOf(pCall As %String, Output pClass As %String, Output pName As %String) As %String
{
    Set pClass = ""
    Set pName = ""
    Set tRouter = ##class(%Dictionary.MethodDefinition).%OpenId(..#ROUTER _ "||" _ pCall)
    If '$IsObject(tRouter) Quit ""
    Set tBody = tRouter.Implementation.Read(100000)
    Set tAfter = $Piece(tBody, "##class(", 2)
    Set pClass = $Piece(tAfter, ")", 1)
    Set pName = $Piece($Piece(tAfter, ").", 2), "(", 1)
    Set tCompiled = ##class(%Dictionary.CompiledMethod).%OpenId(pClass _ "||" _ pName)
    If '$IsObject(tCompiled) Quit ""
    Set pClass = tCompiled.Origin
    Set tMethod = ##class(%Dictionary.MethodDefinition).%OpenId(pClass _ "||" _ pName)
    If '$IsObject(tMethod) Quit ""
    Quit tMethod.Implementation.Read(1000000)
}

}
