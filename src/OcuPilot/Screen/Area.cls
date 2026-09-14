/// <p>The closed area vocabulary: the eight rail entries, in the daily-use order
/// <file>EXPERIENCE.md</file> `:64` fixes, each with its rail position, its label key in the
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
/// endpoint classes named, not a claim about the other sixty-four. Logs has no admin API
/// endpoint behind its first screen; <code>%Admin_Operate</code> is what AD-48 records for the
/// application error log, and the Logs slice (Epic 7) resolves the rest per namespace.</p>
/// <p><b>Permissions, Web applications and Security and secrets also name
/// <code>%DB_IRISSYS:READ</code></b>, as their screens do: the port runs those endpoints in
/// <code>%SYS</code>, and a caller holding <code>%Admin_Secure</code> without read on that database
/// fails inside every screen of the three areas, so a set without the pair would show the areas
/// allowed and refuse everything in them.
/// <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method> is what holds each area's set to
/// its screens' (AD-8).</p>
/// <p><b>A pair set is an AND and cannot express the admin API's OR.</b>
/// <code>Task.CRUD</code> accepts <code>%Admin_Task</code> <i>or</i> <code>%Admin_Operate</code>
/// (same probe). Tasks therefore names the narrower <code>%Admin_Task</code>, so a holder of
/// only <code>%Admin_Operate</code> sees the Tasks rail item gated although the endpoint would
/// admit them -- a false denial rather than a false promise, and an entry that stays listed,
/// focusable and named either way. Epic 6's task screens are where that widens, in their own
/// descriptors.</p>
/// <p><b>Home and Agent co-pilot carry no pairs</b>, which is how "the rail item itself never
/// gates" (<file>EXPERIENCE.md</file> `:224`) is expressed: an empty set is satisfied by every
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
  {"key":"logs","railPosition":2,"labelKey":"navAreaLogs","navigates":false,"pinBottom":false,"privileges":[{"resource":"%Admin_Operate","permission":"USE"}]},
  {"key":"os-management","railPosition":3,"labelKey":"navAreaOsManagement","navigates":false,"pinBottom":false,"privileges":[{"resource":"%Admin_Operate","permission":"USE"}]},
  {"key":"tasks","railPosition":4,"labelKey":"navAreaTasks","navigates":false,"pinBottom":false,"privileges":[{"resource":"%Admin_Task","permission":"USE"}]},
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
