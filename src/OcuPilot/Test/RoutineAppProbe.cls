/// <p>Test-only helper for Story 18.31's suites: <class>OcuPilot.Test.DocDbAppProbe</class> over the privileged routine
/// applications. The probe applications, the probe resource they name (<parameter>RESOURCE</parameter>), the list as one
/// JSON text (<method>Facts</method>), the agent's mint through a tool's own class (<method>Mint</method>) and a confirm
/// run as a real principal in a child process (<method>RunAs</method>) are the parent's; an application is named by its
/// name alone, so the namespace argument every parent method takes is <code>""</code> here. It holds no
/// assertions.</p>
/// <p><b>Only <parameter>PREFIX</parameter> is ever touched.</b> An application or resource is named from it, in any
/// case, and each is removed by exact name. <code>OcuPilotState</code> and <code>OcuPilotIdentity</code> are never named
/// by it, so no method here can write them.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RoutineAppProbe Extends OcuPilot.Test.DocDbAppProbe
{

/// <p>What every probe application and resource name begins with, in any case.</p>
Parameter PREFIX = "OcuProbe1831";

Parameter RESOURCE = "OcuProbe1831Res";

Parameter ENDPOINT = "Security.PrivilegedRoutine";

Parameter PORT = "OcuPilot.Port.AdminPort";

/// <p>The vendor id of the application <var>pName</var>: the name. <var>pNamespace</var> is ignored.</p>
ClassMethod Id(pNamespace As %String, pName As %String) As %String
{
    Quit pName
}

/// <p>The entry <method>OcuPilot.Test.DocDbAppProbe.Names</method> lists for the list row <var>pRow</var>: the name as
/// stored.</p>
ClassMethod Entry(pRow As %DynamicObject) As %String
{
    Quit pRow.%Get("Name")
}

/// <p>The vendor id of the entry <var>pEntry</var>: the name.</p>
ClassMethod IdOfEntry(pEntry As %String) As %String
{
    Quit pEntry
}

/// <p>The two lists of the application <var>pName</var> as the vendor's <code>GET</code> reads them,
/// <code>MatchRoles|Routines</code> as compact JSON, or <code>absent</code> when the instance holds no such
/// application.</p>
ClassMethod Lists(pName As %String) As %String
{
    Set tRead = ..Stored("", pName)
    If '$IsObject(tRead) Quit "absent"
    Quit tRead.%Get("MatchRoles").%ToJSON() _ "|" _ tRead.%Get("Routines").%ToJSON()
}

/// <p>The body of a probe application that holds one application role and one routine, which a change must send back
/// (AD-4), with the description <var>pDescription</var>.</p>
ClassMethod WithLists(pDescription As %String = "probe") As %DynamicObject
{
    Quit {"Description": (pDescription), "Enabled": true, "Resource": "", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}], "Routines": [{"RoutineOrClass": "OcuProbe1831.Routine", "Db": "HSCUSTOM", "Type": "Class"}]}
}

}
