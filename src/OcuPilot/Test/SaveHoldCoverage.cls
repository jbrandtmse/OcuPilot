/// <p>Pins that every screen Save route takes its target's hold (AD-34, AD-53, AD-55): each
/// <code>PUT</code> and <code>POST</code> route in <class>OcuPilot.Api.Router</class>'s URL map whose
/// handler writes an instance object calls <method>OcuPilot.Kernel.Proposal.Operation.HoldTool</method>
/// and releases it, and every other route is listed in <method>Exemptions</method> with its reason.</p>
/// <p><b>A tripwire aimed at later epics.</b> A new write route fails this class until its handler
/// takes the hold or the route joins <method>Exemptions</method> with a reason. A listed route that is
/// no longer in the map fails it too, so the list cannot go stale.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot compiled with its class definitions, which
/// the throwaway keeps.</p>
Class OcuPilot.Test.SaveHoldCoverage Extends %UnitTest.TestCase
{

Parameter ROUTER = "OcuPilot.Api.Router";

/// <p>The write routes that take no hold, each as <code>METHOD url</code> with its reason. A row
/// also exempts every route whose url continues it after a slash.</p>
ClassMethod Exemptions() As %List
{
    Quit $ListBuild($ListBuild("POST /agent/", "agent configuration and credentials are not an instance object a write tool targets"), $ListBuild("PUT /agent/", "agent configuration is not an instance object a write tool targets"), $ListBuild("POST /turn", "a turn is OcuPilot's own state"), $ListBuild("POST /proposal/", "a confirm holds its target itself (AD-34)"), $ListBuild("POST /conversation", "a conversation is OcuPilot's own state"), $ListBuild("POST /account/", "the caller's own account and preferences"), $ListBuild("POST /screens/", "the screen action route holds its target itself (AD-53)"), $ListBuild("POST /database/check", "reads only"), $ListBuild("POST /ssl/:id/test", "reads only"), $ListBuild("POST /ldap/:id/test", "reads only"), $ListBuild("POST /tasks/check", "reads only"), $ListBuild("POST /license/key/validate", "reads only"), $ListBuild("POST /oauth/server-description/discover", "reads only"), $ListBuild("POST /explorer/sql/", "runs only a statement the instance types as a query"))
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
