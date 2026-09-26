/// <p><code>GET /api/ocupilot/ui/system</code> over HTTP (Story 15.4): the panel read asserted on
/// status, content type and body shape through the shipped router rather than by calling the
/// handler in process.</p>
/// <p>The route is a read and writes nothing, so there is no state to set up or tear down. The
/// rows of the story's I/O matrix that need a seam -- a refused source, an unsampled metric, the
/// mirror accessor's caught error and the non-interoperability namespace -- are
/// <class>OcuPilot.Test.UiSystemRead</class>'s; an unreachable instance is the client's and is
/// pinned in <file>ui/tools/system-info.test.mjs</file>.</p>
Class OcuPilot.Test.UiSystemWire Extends %UnitTest.TestCase
{

/// <p>The route under test, from the origin root.</p>
Parameter SYSTEMPATH As %String = "/api/ocupilot/ui/system";

/// <p>The verb it answers. Spelled so the build gate can see that this class covers the route the
/// router declares for it.</p>
Parameter READVERB As %String = "GET";

/// <p>The seven scalar members the body carries. The wire contract, spelled here.</p>
Parameter WIREMEMBERS As %String = "uptime,mirror,databaseSpace,journalSpace,lockTable,writeDaemon,production";

/// <p>One request to <var>pPath</var> as the suite's own credentials.</p>
ClassMethod Call(pPath As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(..#READVERB, pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .pHeaders)
}

/// <p>Whether <var>pHeaders</var> says the answer is JSON.</p>
ClassMethod IsJson(ByRef pHeaders) As %Boolean
{
    Quit $ZConvert($Get(pHeaders("CONTENT-TYPE")), "L") [ "application/json"
}

/// <p><b>The panel read answers 200 with every member, each a string.</b></p>
/// <p>Mutation: drop one member from
/// <method>OcuPilot.Kernel.Shell.SystemInfo.Members</method>, recompile the class and every
/// descendant -- this goes red naming the member.</p>
Method TestThePanelReadCarriesEveryMemberOverTheWire()
{
    Set tSC = ..Call(..#SYSTEMPATH, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Do $$$AssertTrue(..IsJson(.tHeaders), "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    For tI = 1:1:$Length(..#WIREMEMBERS, ",") {
        Set tMember = $Piece(..#WIREMEMBERS, ",", tI)
        Do $$$AssertTrue(tAnswer.%IsDefined(tMember), "the body carries " _ tMember)
        Do $$$AssertEquals(tAnswer.%GetTypeOf(tMember), "string", tMember _ " travels as a string")
    }
}

/// <p><b>The values over the wire are this instance's own</b>, not a shape the handler could
/// satisfy with anything -- the uptime the dashboard reports, the mirror word the accessor
/// answers, and the four alert words drawn from the vocabularies their own source publishes.</p>
Method TestTheValuesOverTheWireAreTheInstancesOwn()
{
    Set tSC = ..Call(..#SYSTEMPATH, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Do $$$AssertTrue(..IsJson(.tHeaders), "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.mirror, $ListGet($SYSTEM.Mirror.GetMemberStatus(), 1), "the mirror state is the accessor's own word: " _ tAnswer.mirror)
    Do $$$AssertNotEquals(tAnswer.uptime, "", "the instance reports an uptime: " _ tAnswer.uptime)
    Do $$$AssertTrue(tAnswer.databaseSpace = "Normal" || (tAnswer.databaseSpace = "Warning") || (tAnswer.databaseSpace = "Troubled"), "the database-space word is one its source publishes: " _ tAnswer.databaseSpace)
    Do $$$AssertTrue(tAnswer.journalSpace = "Normal" || (tAnswer.journalSpace = "Warning") || (tAnswer.journalSpace = "Troubled"), "and so is the journal-space word: " _ tAnswer.journalSpace)
    Do $$$AssertTrue(tAnswer.lockTable = "Normal" || (tAnswer.lockTable = "Warning") || (tAnswer.lockTable = "Troubled"), "and the lock-table word: " _ tAnswer.lockTable)
    Do $$$AssertTrue(tAnswer.writeDaemon = "Normal" || (tAnswer.writeDaemon = "Troubled"), "the write daemon publishes only two: " _ tAnswer.writeDaemon)
}

/// <p><b>The production member carries the vendor's own English state word</b> for the namespace
/// the request is scoped to, which is production-enabled on this container.</p>
Method TestTheProductionMemberCarriesTheVendorsStateWord()
{
    Set tSC = ..Call(..#SYSTEMPATH, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Do $$$AssertTrue(..IsJson(.tHeaders), "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Set tName = ""
    Set tState = ""
    Set tProdSC = ##class(Ens.Director).GetProductionStatus(.tName, .tState)
    Do $$$AssertStatusOK(tProdSC, "this namespace answers a production status")
    Set tWanted = ##class(Ens.Config.Production).ProductionStateToText(tState, 0)
    Do $$$AssertTrue(tAnswer.production [ tWanted, "which the member carries: " _ tAnswer.production)
}

/// <p><b>The production member is the request's scope, over the wire.</b> <code>?ns=%SYS</code>
/// names a namespace that is not production-enabled, so that one member answers <code>""</code>
/// while the same route unscoped answers a word. The router stashes the resolved scope rather than
/// assigning <code>$NAMESPACE</code>, so a handler reading <code>$NAMESPACE</code> would answer
/// the same word for both.</p>
Method TestTheProductionMemberIsTheRequestsScopeOverTheWire()
{
    Set tSC = ..Call(..#SYSTEMPATH, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the unscoped request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Set tUnscoped = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertNotEquals(tUnscoped.production, "", "the request's own namespace is production-enabled: " _ tUnscoped.production)

    Set tScopedSC = ..Call(..#SYSTEMPATH _ "?ns=%25SYS", .tScopedStatus, .tScopedBody, .tScopedHeaders)
    Do $$$AssertStatusOK(tScopedSC, "the scoped request completes")
    Do $$$AssertEquals(tScopedStatus, 200, "and answers 200: " _ tScopedBody)
    Set tScoped = ##class(%DynamicObject).%FromJSON(tScopedBody)
    Do $$$AssertEquals(tScoped.production, "", "%SYS is not production-enabled, so that member reads the empty string")
    Do $$$AssertNotEquals(tScoped.uptime, "", "while the instance-wide members still answer")
}

}
