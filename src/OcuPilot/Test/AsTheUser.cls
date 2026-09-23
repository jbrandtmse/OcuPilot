/// <p>"Runs strictly as the user", as an observable rather than an architecture claim (Story 5.4,
/// AC1 and AC4). A tool body and a port call, reached through the <b>shipped</b> dispatch chain,
/// are asked what <code>$USERNAME</code> and <code>$ROLES</code> read at the instant they ran.</p>
/// <ul>
/// <li>The body runs under the calling process's own identity, not a service account.</li>
/// <li><code>$ROLES</code> at both points carries none of OcuPilot's protected-storage roles --
/// neither the state role nor the identity role -- so AD-9's escalation is not in effect while
/// tool, port or provider code runs.</li>
/// <li>No <code>$System.Security.Login</code> and no second authenticated hop exists on the tool
/// path, asserted over the whole shipped tree rather than over the one class this drives.</li>
/// </ul>
/// <p><b>Live-safe.</b> It spawns nothing, creates no principal and writes nothing: the one port
/// call it makes is a list.</p>
Class OcuPilot.Test.AsTheUser Extends %UnitTest.TestCase
{

/// <p>The dispatcher, with its registry switched to the probe's.</p>
Parameter PROBE = "OcuPilot.Test.ToolDispatchProbe";

/// <p>The registry holding the recording tool.</p>
Parameter REGISTRY = "OcuPilot.Test.AsTheUserProbe.Registry";

/// <p>The recording tool's wire name.</p>
Parameter WIRE = "probe_astheuser_read";

/// <p>The shipped bounds.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The role the storage escalation obtains, read from the shipped parameter at run time. A
/// literal here would make the absence assertions below vacuous the day the name changed: they
/// would look for a role nothing grants and find it absent.</p>
ClassMethod StateRole() As %String
{
    Quit $Parameter("OcuPilot.Kernel.State.Base", "DBRESOURCE")
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Do ##class(OcuPilot.Test.AsTheUserProbe).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Do ##class(OcuPilot.Test.AsTheUserProbe).Clear()
    Quit $$$OK
}

/// <p>Answer one call to the recording tool through the shipped dispatch chain, as
/// <var>pUser</var>, with <code>port</code> set to <var>pPort</var>.</p>
Method Call(pPort As %Integer, pUser As %String = {$Username}) As %DynamicObject
{
    Do $ClassMethod(..#PROBE, "SetRegistryClass", ..#REGISTRY)
    Set tUses = []
    Set tUse = {"type": "tool_use", "id": "toolu_astheuser"}
    Do tUse.%Set("name", ..#WIRE, "string")
    Set tInput = {}
    Do tInput.%Set("port", pPort, "number")
    Do tUse.%Set("input", tInput)
    Do tUses.%Push(tUse)
    Set tSC = $ClassMethod(..#PROBE, "Answer", "astheuser", pUser, "", tUses, ..#LIMITS, .tResults, .tNames)
    Do $$$AssertStatusOK(tSC, "the dispatcher answers")
    If '$IsObject($Get(tResults)) || (tResults.%Size() '= 1) Quit {}
    Quit tResults.%Get(0)
}

/// <p><b>AC1</b> -- a tool body runs under the caller's own <code>$USERNAME</code>, and the result
/// the model receives is that caller's.</p>
/// <p>Mutation (Rule 19): invoke the probe tool's body through a wrapper that sets
/// <code>$ROLES</code> and a second identity -> this goes red.</p>
Method TestAToolBodyRunsUnderTheCallersRoles()
{
    Set tResult = ..Call(0)
    Do $$$AssertEquals(tResult.%Get("is_error"), 0, "the call is not an error: " _ tResult.%Get("content"))
    Do $$$AssertEquals(##class(OcuPilot.Test.AsTheUserProbe).Observed("tool", "count"), 1, "the body ran exactly once")
    Do $$$AssertEquals(##class(OcuPilot.Test.AsTheUserProbe).Observed("tool", "user"), $Username, "and observed the calling process's own identity, with no service account between")

    Set tRoles = ##class(OcuPilot.Test.AsTheUserProbe).Observed("tool", "roles")
    Do $$$AssertNotEquals(tRoles, "", "the body observed a role set at all: " _ tRoles)
    Do $$$AssertEquals(##class(OcuPilot.Test.AsTheUserProbe).CarriesRole(tRoles, ..StateRole()), 0, "which carries no OcuPilot state role: " _ tRoles)
}

/// <p><b>AC4</b> -- neither AD-9 escalation is in effect inside a tool body or inside a port call,
/// and the port really ran.</p>
/// <p>Mutation (Rule 19): remove the <code>New $ROLES</code> from one guarded method the tool path
/// calls, so the storage role survives the frame -> this goes red.</p>
Method TestNoStateRoleIsPresentInsideAToolBody()
{
    ; A guarded read first, so the escalation has certainly happened in this process before the
    ; tool body runs. If the frame leaked, the role would still be in $ROLES below.
    Set tInside = ##class(OcuPilot.Kernel.State.Base).GuardedRolesSnapshot()
    Do $$$AssertEquals(##class(OcuPilot.Test.AsTheUserProbe).CarriesRole(tInside, ..StateRole()), 1, "the control: the state role IS present inside the guarded frame, so its absence below is a measurement")

    Set tResult = ..Call(1)
    Do $$$AssertEquals(tResult.%Get("is_error"), 0, "the call is not an error: " _ tResult.%Get("content"))
    Do $$$AssertEquals(##class(OcuPilot.Test.AsTheUserProbe).Observed("port", "count"), 1, "the body reached the port exactly once")

    ; The identity role is deliberately not asserted here. Its escalation is entered only from
    ; OcuPilot.Api.Router.OnPreDispatch, which this in-process call never reaches, so an assertion
    ; that it is absent could not fail for any implementation and would read as coverage it is
    ; not. What the identity role does and does not reach is pinned where it can fail, by
    ; OcuPilot.Test.IdentityInstall against the installed objects.
    For tWhere = "tool", "port" {
        Set tRoles = ##class(OcuPilot.Test.AsTheUserProbe).Observed(tWhere, "roles")
        Do $$$AssertNotEquals(tRoles, "", tWhere _ ": observed a role set at all")
        Do $$$AssertEquals(##class(OcuPilot.Test.AsTheUserProbe).CarriesRole(tRoles, ..StateRole()), 0, tWhere _ ": carries no OcuPilot state role: " _ tRoles)
        Do $$$AssertEquals(##class(OcuPilot.Test.AsTheUserProbe).Observed(tWhere, "user"), $Username, tWhere _ ": ran as the caller")
    }
}

/// <p><b>AC1</b> -- no second authenticated hop exists on the tool path: no shipped class calls
/// <code>$System.Security.Login</code> anywhere, and nothing the tool path runs through opens an
/// outbound HTTP request of its own (AD-1: a tool body calls the management surface directly).</p>
/// <p>Asserted over every shipped class rather than over the one the test drives, because the claim
/// is about the tree and a claim about one class would be a generalization from one probe. The
/// outbound half is scoped to the packages a tool call actually reaches -- the tools, the area
/// slices, the dispatcher and the three in-process ports -- because
/// <class>OcuPilot.Port.ProviderPort</class> and the provider adapters exist to make an outbound
/// request and are not on that path.</p>
/// <p>Mutation (Rule 19): add a <code>$System.Security.Login</code> call to any shipped class, or a
/// <code>%Net.HttpRequest</code> to any class on the tool path -> this goes red.</p>
Method TestNoSecondAuthenticatedHopExists()
{
    ; One token, matched case-insensitively. The tree writes both $System. and $SYSTEM., so a
    ; case-sensitive scan for one spelling would miss the other -- and $SYSTEM. is the spelling
    ; this tree actually uses.
    Set tLoginSites = ..SitesNaming(".Security.Login", "")
    Do $$$AssertEquals(tLoginSites, "", "no shipped class calls $System.Security.Login: " _ tLoginSites)

    ; The control for the login half: the same scan over the test package DOES find the one
    ; deliberate login, so the empty answer above is a measurement and not a broken scan.
    Set tProbeLogin = ..SitesNaming(".Security.Login", "OcuPilot.Test.", 1)
    Do $$$AssertTrue(tProbeLogin [ "OcuPilot.Test.ToolSetProbe", "the scan does find the probe's own deliberate login: " _ tProbeLogin)

    Set tPath = "OcuPilot.Screen.Tool.,OcuPilot.Area.,OcuPilot.Kernel.Agent.,OcuPilot.Port.AdminPort,OcuPilot.Port.MgmntPort,OcuPilot.Port.LogSourcePort,OcuPilot.Port.TaskPort"
    Set tHttpSites = ..SitesNaming("%Net.HttpRequest", tPath)
    Do $$$AssertEquals(tHttpSites, "", "nothing on the tool path issues an HTTP request: " _ tHttpSites)
    Set tApiSites = ..SitesNaming("/api/ocupilot", tPath)
    Do $$$AssertEquals(tApiSites, "", "and nothing on it names OcuPilot's own API as a target: " _ tApiSites)

    ; The control: the same scan over the whole shipped tree DOES find the class that actually
    ; constructs the outbound request, so the empty answers above are a measurement and not a
    ; broken scan. It names the provider base rather than the port: the port mentions the class
    ; only in a doc comment, and a control satisfied by narration proves nothing.
    Set tAnySite = ..SitesNaming("%Net.HttpRequest", "")
    Do $$$AssertTrue(tAnySite [ "OcuPilot.Kernel.Provider.Base", "the scan does find the provider base's own outbound request: " _ tAnySite)
}

/// <p>Every shipped class (package <code>OcuPilot</code>, excluding <code>OcuPilot.Test</code>)
/// whose source names <var>pToken</var>, comma-separated in name order. <var>pPrefixes</var>
/// narrows the population to classes whose name starts with one of its comma-separated members;
/// <code>""</code> is the whole shipped tree. <var>pIncludeTests</var> 1 keeps
/// <package>OcuPilot.Test</package> in the population, which is how a scan states its own
/// positive control. Read from the class dictionary's own stored source, so it covers what was
/// compiled rather than what a file on disk says.</p>
/// <p>The match is case-insensitive: <code>[</code> is not, and this tree writes both
/// <code>$System.</code> and <code>$SYSTEM.</code> for the same system class.</p>
ClassMethod SitesNaming(pToken As %String, pPrefixes As %String = "", pIncludeTests As %Boolean = 0) As %String
{
    Set tFound = ""
    Set tExclude = $Select(pIncludeTests: "", 1: " AND NOT (Name %STARTSWITH 'OcuPilot.Test')")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'OcuPilot.'" _ tExclude _ " ORDER BY Name")
    If tRS.%SQLCODE < 0 Quit "SQLCODE=" _ tRS.%SQLCODE
    While tRS.%Next() {
        Set tName = tRS.%GetData(1)
        If pPrefixes '= "" {
            Set tInScope = 0
            For tI = 1:1:$Length(pPrefixes, ",") {
                Set tPrefix = $Piece(pPrefixes, ",", tI)
                If (tPrefix '= "") && ($Extract(tName, 1, $Length(tPrefix)) = tPrefix) Set tInScope = 1  Quit
            }
            If 'tInScope Continue
        }
        Set tText = ""
        Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, tName, .tText)
        ; A class whose source cannot be read is reported, never scored as "no match": a failed
        ; lookup is not a negative result.
        If $$$ISERR(tSC) {
            Set tFound = tFound _ $Select(tFound = "": "", 1: ",") _ tName _ "(unreadable)"
            Continue
        }
        ; Case-insensitive: ObjectScript's [ is case-sensitive, and this tree writes both
        ; $System. and $SYSTEM. for the same system class.
        If $ZConvert(tText, "U") [ $ZConvert(pToken, "U") Set tFound = tFound _ $Select(tFound = "": "", 1: ",") _ tName
    }
    Do tRS.%Close()
    Quit tFound
}

}
