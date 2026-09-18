/// <p>The closed area vocabulary: the eight rail entries, in the daily-use order
/// <file>EXPERIENCE.md</file> "**The rail, top to bottom (daily-use order):**" fixes, each with its rail position, its label key in the
/// one string source, whether its rail item navigates, and its own privilege pair set
/// (AD-8).</p>
/// <p><b>Why an area carries a privilege set of its own rather than deriving one from its
/// screens.</b> Home's tile grid gates per area (epics.md `:1441-1443`), and at the end of
/// Epic 1 every area's screen list is empty -- the six areas' first screens are Epic 2's -- so
/// a set derived from a screen list would gate nothing at all. The set is declared here, in
/// one place, and a screen's own descriptor stays authoritative for that screen.</p>
/// <p><b>What each set names.</b> The resource the area's first Release 1 screen's backing
/// admin API endpoint requires, read from the instance 2026-09-12 by constructing the endpoint
/// and calling its own <code>ResourcesOR()</code>: <code>Process</code> and <code>Lock</code>
/// answer <code>%Admin_Operate</code>; <code>Security.User</code>, <code>Security.SSLConfig</code>
/// and <code>WebApp.App</code> answer <code>%Admin_Secure</code>. That is a probe of the six
/// endpoint classes named, not a claim about the other sixty-four. <code>%Admin_Operate</code> is
/// what AD-48 records for the application error log, which is the Logs area's other Release 1
/// source and has no admin API endpoint behind it; the Logs slice (Epic 7) resolves the rest per
/// namespace.</p>
/// <p><b>Every gated area names <code>%DB_IRISSYS:READ</code></b>, as its screens do: the port runs
/// those endpoints in <code>%SYS</code>, and a caller holding the area's administrative resource
/// without read on that database fails inside every screen, so a set without the pair would show
/// the areas allowed and refuse everything in them.
/// <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method> is what holds each area's set to
/// its screens' (AD-8).</p>
/// <p><b>Logs names three pairs, and the first is not its first screen's endpoint gate.</b>
/// <code>%Admin_Operate:USE</code> is AD-48's, and it is also what
/// <code>%Api.Admin.Endpoints.AsyncResult</code> requires -- the endpoint the port polls a queued
/// task through (AD-26), which the audit database viewer reaches.
/// <code>%Admin_Secure:USE</code> is that screen's own endpoint gate. It is declared second, so a
/// caller short of both is named the operate pair first, which is the pair every Logs screen needs.
/// The consequence AD-8 makes unavoidable: the whole Logs rail entry, Stories 2.11 and 2.12's
/// screens included, is gated on <code>%Admin_Secure:USE</code> because one screen in it requires
/// that pair.</p>
/// <p><b>OS management names a third pair, <code>%Admin_Manage:USE</code></b> -- the only area pair
/// an endpoint's own gate does not name and the port does not need either. Its first screen reads
/// <code>SYS.Process:CONTROLPANEL</code>,
/// and that query checks <code>%Admin_Manage:USE</code> <i>or</i> write on the IRISSYS database for
/// itself, behind the endpoint's own <code>%Admin_Operate</code> gate;
/// <class>OcuPilot.Screen.Descriptor.ProcessList</class> records the vendor line and the choice of
/// the narrower half. An area covers every pair its screens declare, so the area carries it too.</p>
/// <p><b>The union stands, and the false denial it produces for a narrower screen is accepted</b>
/// (DW-275, decided in Story 2.13). <class>OcuPilot.Screen.Descriptor.ProcessList</class> was the
/// first screen to need <code>%Admin_Manage:USE</code> and Story 6.11's three Databases reads need
/// it too; Stories 6.8's and 6.10's screens do not, which was settled by running each new read as
/// a least-privileged principal on a throwaway as that screen landed rather than inferred from the
/// <code>ResourcesOR()</code> probe recorded above. An
/// operator holding only <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code> will
/// therefore see the whole OS management rail entry denied on a pair five of its eight screens
/// require. That is a false denial, and it is preferred to the alternative: relaxing
/// <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method> to per-screen coverage trades it
/// for the false admission AD-8 exists to prevent -- an area that reads allowed while every screen
/// inside it refuses. DW-278's owner-delegated decision of 2026-09-14 declined that relaxation in
/// general terms, and <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method> and
/// <method>OcuPilot.Screen.Gate.Evaluate</method> say the same. Splitting the area is not
/// available either: the vocabulary here is closed at eight and
/// <class>OcuPilot.Test.Descriptor</class> pins it.</p>
/// <p><b>What this costs, counted:</b> 2 of 4 os-management screens falsely denied before Story
/// 6.11 (<class>OcuPilot.Screen.Descriptor.LockList</class> and
/// <class>OcuPilot.Screen.Descriptor.SystemUsage</class>), 5 of 8 with its four descriptors
/// landed. A screen is falsely denied when its own pair set is a strict subset of this union,
/// because <method>OcuPilot.Screen.Gate.EvaluatePairs</method> requires every pair the area names:
/// <class>OcuPilot.Screen.Descriptor.DatabaseDetails</class> joins the two above, denied on
/// <code>%Admin_Manage:USE</code>, and <class>OcuPilot.Screen.Descriptor.DatabaseList</class> and
/// <code>DatabaseVolumeList</code> are this area's first screens denied on
/// <code>%Admin_Operate:USE</code> instead -- each declares <code>%Admin_Manage:USE</code> and
/// <code>%DB_IRISSYS:READ</code> and needs no Operate pair, which
/// <class>OcuPilot.Test.WireSecurityRead</class> establishes against a real least-privileged
/// principal on the throwaway: its Manage-only account reads both at 200. Only
/// <code>DatabaseFreeSpace</code> declares the whole union, and it alone of the four is not
/// falsely denied. <b>What it must not become:</b> dropping
/// <code>%Admin_Manage:USE</code> from this area to make the narrow screens reachable makes
/// <code>AreaCoverageProblem</code> refuse <code>ProcessList</code> at install --
/// <class>OcuPilot.Test.NarrowArea</class> pins both halves, so the decision cannot be reversed by
/// accident.</p>
/// <p><b>Security and secrets names <code>%Admin_Wallet:USE</code> third</b>, after its screens'
/// shared <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>: the Wallet list and its
/// Secrets list declare it, and an area covers every pair its screens declare. Appended rather than
/// placed first, so a caller short of <code>%Admin_Secure:USE</code> is still named that pair. The
/// union is kept on the ground DW-275 and DW-278 give for OS management, and it costs the same kind
/// of false denial: a caller holding <code>%Admin_Secure:USE</code> and
/// <code>%DB_IRISSYS:READ</code> without <code>%Admin_Wallet:USE</code> sees the Security rail item
/// gated, and a gated rail item opens no side bar, while SSL/TLS, X.509 and LDAP / Kerberos -- 3 of
/// the area's 5 built screens -- would serve them and stay reachable by the command box and a deep
/// link.</p>
/// <p><b>It then names <code>%Admin_OAuth2_Client:USE</code>, <code>%Admin_OAuth2_Server:USE</code> and
/// <code>%Admin_OAuth2_Registration:USE</code></b>, in that order, which the OAuth 2.0 tabs declare.
/// The cost is the same kind of false denial: a caller holding the secure, system-database and wallet
/// pairs without an OAuth resource sees the rail item gated while 6 of the area's 10 built screens
/// would serve them. The stock <code>%Manager</code> and <code>%SecurityAdministrator</code> roles hold
/// all three OAuth resources (observed on slot B), so no stock role is newly denied by them.</p>
/// <p><b>A pair set is an AND and cannot express the admin API's OR.</b>
/// <code>Task.CRUD</code> accepts <code>%Admin_Task</code> <i>or</i> <code>%Admin_Operate</code>
/// (same probe). Tasks therefore names the narrower <code>%Admin_Task</code>, so a holder of
/// only <code>%Admin_Operate</code> sees the Tasks rail item gated although the endpoint would
/// admit them -- a false denial rather than a false promise, and an entry that stays listed,
/// focusable and named either way. Epic 6's task screens are where that widens, in their own
/// descriptors. <code>%Admin_Task</code> is declared <b>first</b>, because
/// <method>OcuPilot.Screen.Gate.EvaluatePairs</method> names the first pair a caller does not hold
/// and the wire fixtures pin that name.</p>
/// <p><b>Home and Agent co-pilot carry no pairs</b>, which is how "the rail item itself never
/// gates" (<file>EXPERIENCE.md</file> "Agent co-pilot › Definitions and Switches") is expressed: an empty set is satisfied by every
/// caller. There is no second "never gates" flag to keep in step with it.</p>
Class OcuPilot.Screen.Area Extends %RegisteredObject
{

/// <p>The one declaration. Read by <class>OcuPilot.Screen.Registry</class> on the server and
/// by <file>ui/tools/screen-mirror.mjs</file> off disk, so the rail the browser draws and the
/// navigation map the instance computes come from the same eight lines.</p>
XData Areas
{
{"areas":[
  {"key":"home","railPosition":1,"labelKey":"navAreaHome","navigates":true,"pinBottom":false,"privileges":[]},
  {"key":"logs","railPosition":2,"labelKey":"navAreaLogs","navigates":false,"pinBottom":false,"privileges":[{"resource":"%Admin_Operate","permission":"USE"},{"resource":"%Admin_Secure","permission":"USE"},{"resource":"%DB_IRISSYS","permission":"READ"}]},
  {"key":"os-management","railPosition":3,"labelKey":"navAreaOsManagement","navigates":false,"pinBottom":false,"privileges":[{"resource":"%Admin_Operate","permission":"USE"},{"resource":"%Admin_Manage","permission":"USE"},{"resource":"%DB_IRISSYS","permission":"READ"}]},
  {"key":"tasks","railPosition":4,"labelKey":"navAreaTasks","navigates":false,"pinBottom":false,"privileges":[{"resource":"%Admin_Task","permission":"USE"},{"resource":"%DB_IRISSYS","permission":"READ"}]},
  {"key":"permissions","railPosition":5,"labelKey":"navAreaPermissions","navigates":false,"pinBottom":false,"privileges":[{"resource":"%Admin_Secure","permission":"USE"},{"resource":"%DB_IRISSYS","permission":"READ"}]},
  {"key":"web-applications","railPosition":6,"labelKey":"navAreaWebApplications","navigates":false,"pinBottom":false,"privileges":[{"resource":"%Admin_Secure","permission":"USE"},{"resource":"%DB_IRISSYS","permission":"READ"}]},
  {"key":"security","railPosition":7,"labelKey":"navAreaSecurity","navigates":false,"pinBottom":false,"privileges":[{"resource":"%Admin_Secure","permission":"USE"},{"resource":"%DB_IRISSYS","permission":"READ"},{"resource":"%Admin_Wallet","permission":"USE"},{"resource":"%Admin_OAuth2_Client","permission":"USE"},{"resource":"%Admin_OAuth2_Server","permission":"USE"},{"resource":"%Admin_OAuth2_Registration","permission":"USE"}]},
  {"key":"agent","railPosition":8,"labelKey":"navAreaAgent","navigates":false,"pinBottom":true,"privileges":[]}
]}
}

/// <p>The declaration as a <class>%DynamicObject</class>. Re-read on every call rather than
/// cached: the cost is one dictionary open, and a cached copy is a second source of truth
/// that a recompile does not reach.</p>
ClassMethod Declaration(Output pObject As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pObject = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Areas", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "area declaration XData is missing from " _ $ClassName())
            Quit
        }
        Do tXData.Data.Rewind()
        Set pObject = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
    } Catch ex {
        Set pObject = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The declared areas as a <class>%DynamicArray</class>, in rail order.</p>
ClassMethod List(Output pAreas As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pAreas = ""
    Try {
        Set tSC = ..Declaration(.tObject)
        If $$$ISERR(tSC) Quit
        Set pAreas = tObject.areas
        If '$IsObject(pAreas) {
            Set pAreas = ""
            Set tSC = $$$ERROR($$$GeneralError, "area declaration in " _ $ClassName() _ " carries no areas array")
        }
    } Catch ex {
        Set pAreas = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The declared area whose <code>key</code> is <var>pKey</var>, or an empty string when
/// there is none.</p>
ClassMethod Find(pKey As %String) As %DynamicObject
{
    Set tFound = ""
    Try {
        Set tSC = ..List(.tAreas)
        If $$$ISERR(tSC) Quit
        Set tIterator = tAreas.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tArea) {
            If tArea.key = pKey {
                Set tFound = tArea
                Quit
            }
        }
    } Catch {
        Set tFound = ""
    }
    Quit tFound
}

/// <p>Whether <var>pKey</var> names a declared area. A descriptor naming an area that is not
/// here is refused by <class>OcuPilot.Screen.Registry</class>.</p>
ClassMethod Exists(pKey As %String) As %Boolean
{
    Quit $IsObject(..Find(pKey))
}

/// <p><var>pKey</var>'s privilege pair set as a <class>%List</class> of
/// <code>$ListBuild(resource, permission)</code>, empty when the area never gates. The gate
/// requires <b>all</b> of them (AD-8).</p>
ClassMethod PrivilegePairs(pKey As %String) As %List
{
    Set tPairs = ""
    Set tArea = ..Find(pKey)
    If '$IsObject(tArea) Quit tPairs
    Quit ..PairsFrom(tArea.privileges)
}

/// <p>Convert a declared <code>privileges</code> array into the <class>%List</class> of
/// <code>$ListBuild(resource, permission)</code> pairs the gate evaluates. Shared with
/// <class>OcuPilot.Screen.Descriptor.Base</class> so an area's set and a screen's set cannot
/// be read two different ways.</p>
ClassMethod PairsFrom(pDeclared As %DynamicArray) As %List
{
    Set tPairs = ""
    If '$IsObject(pDeclared) Quit tPairs
    Set tIterator = pDeclared.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPair) {
        If '$IsObject(tPair) Continue
        Set tResource = tPair.resource
        Set tPermission = tPair.permission
        If (tResource = "") || (tPermission = "") Continue
        Set tPairs = tPairs _ $ListBuild($ListBuild(tResource, tPermission))
    }
    Quit tPairs
}

}
