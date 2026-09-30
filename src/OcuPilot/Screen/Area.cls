/// <p>The closed area vocabulary: the eight rail entries, in the daily-use order
/// <file>EXPERIENCE.md</file> "**The rail, top to bottom (daily-use order):**" fixes, each with its rail position, its label key in the
/// one string source, whether its rail item navigates, and its own privilege pair set
/// (AD-8).</p>
/// <p><b>An area's verdict is its screens', and its declared set is what a gated area names.</b>
/// <method>OcuPilot.Screen.Gate.EvaluateArea</method> opens an area -- its rail item, Home tile and
/// side bar -- when any screen its side bar lists passes that screen's own gate, or, for a listed
/// tab group, any of its tabs passes its own, and each screen keeps its own gate. When none does,
/// the area names the first pair of the set declared here that
/// the caller lacks, or, when the caller holds all of it, the first failed pair a listed screen
/// names. <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method> holds the set to every pair
/// the area's screens declare, less the pairs a screen declares its own, so holding it opens every
/// screen of the area that declares no own pair and whose classic page carries no custom resource.</p>
/// <p><b>What each set names.</b> The resource the area's first Release 1 screen's backing
/// admin API endpoint requires, read from the instance 2026-09-12 by constructing the endpoint
/// and calling its own <code>ResourcesOR()</code>: <code>Process</code> and <code>Lock</code>
/// answer <code>%Admin_Operate</code>; <code>Security.User</code>, <code>Security.SSLConfig</code>
/// and <code>WebApp.App</code> answer <code>%Admin_Secure</code>. That is a probe of the six
/// endpoint classes named, not a claim about the other sixty-four. <code>%Admin_Operate</code> is
/// what AD-48 records for the application error log, which is the Logs area's other Release 1
/// source and has no admin API endpoint behind it; the Logs slice (Epic 7) resolves the rest per
/// namespace.</p>
/// <p><b>Every gated area names <code>%DB_IRISSYS:READ</code></b>: the port runs the admin API's
/// endpoints in <code>%SYS</code>, and a caller holding an area's administrative resource without
/// read on that database fails inside every screen one of them backs.</p>
/// <p><b>Logs names three pairs, and the first is not the audit database viewer's endpoint gate.</b>
/// <code>%Admin_Operate:USE</code> is AD-48's, and it is also what
/// <code>%Api.Admin.Endpoints.AsyncResult</code> requires -- the endpoint the port polls a queued
/// task through (AD-26), which the audit database viewer reaches.
/// <code>%Admin_Secure:USE</code> is that screen's own endpoint gate. It is declared second, so a
/// caller short of both is named the operate pair first, which is the pair every Logs screen needs
/// but the two below. Story 16.8's interoperability event log and analytics log declare
/// <code>%Ens_EventLog:USE</code> and <code>%DeepSee_Portal:USE</code> as their own pairs (AD-8),
/// so neither is on this set.</p>
/// <p><b>OS management names a third pair, <code>%Admin_Manage:USE</code></b> -- the only area pair
/// an endpoint's own gate does not name and the port does not need either. Its first screen reads
/// <code>SYS.Process:CONTROLPANEL</code>,
/// and that query checks <code>%Admin_Manage:USE</code> <i>or</i> write on the IRISSYS database for
/// itself, behind the endpoint's own <code>%Admin_Operate</code> gate;
/// <class>OcuPilot.Screen.Descriptor.ProcessList</class> records the vendor line and the choice of
/// the narrower half. An area covers every pair its screens declare, so the area carries it too,
/// and a screen needing fewer of its pairs -- Locks, System usage, the Databases lists -- is
/// sound inside it: the area opens for whoever that screen admits.</p>
/// <p><b>Security and secrets declares <code>%Admin_Secure:USE</code> and
/// <code>%DB_IRISSYS:READ</code> alone.</b> The wallet screens declare <code>%Admin_Wallet:USE</code>
/// and each OAuth 2.0 tab and form its OAuth resource as their own pair (AD-8), so a caller without
/// one loses that screen alone and keeps SSL/TLS, X.509, LDAP and Auditing (Story 16.3, DW-1018).</p>
/// <p><b>A pair set is an AND and cannot express the admin API's OR.</b>
/// <code>Task.CRUD</code> accepts <code>%Admin_Task</code> <i>or</i> <code>%Admin_Operate</code>
/// (same probe). The task screens therefore name the narrower <code>%Admin_Task</code>, so a holder
/// of only <code>%Admin_Operate</code> sees them gated although the endpoint would admit them -- a
/// false denial rather than a false promise, and entries that stay listed, focusable and named
/// either way. <code>%Admin_Task</code> is declared <b>first</b>, because
/// <method>OcuPilot.Screen.Gate.EvaluatePairs</method> names the first pair a caller does not hold
/// and the wire fixtures pin that name.</p>
/// <p><b>Home and Agent co-pilot carry no pairs</b>, which is how "the rail item itself never
/// gates" (<file>EXPERIENCE.md</file> "Agent co-pilot › Definitions and Switches") is expressed:
/// <method>OcuPilot.Screen.Gate.EvaluateArea</method> opens an area with an empty set for every
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
  {"key":"security","railPosition":7,"labelKey":"navAreaSecurity","navigates":false,"pinBottom":false,"privileges":[{"resource":"%Admin_Secure","permission":"USE"},{"resource":"%DB_IRISSYS","permission":"READ"}]},
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
/// <code>$ListBuild(resource, permission)</code>, empty when the area never gates. An area none of
/// whose listed screens opens names the first of them the caller lacks, or a listed screen's failed
/// pair when the caller lacks none (<method>OcuPilot.Screen.Gate.EvaluateArea</method>, AD-8).</p>
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
