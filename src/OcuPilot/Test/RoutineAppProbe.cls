/// <p>Test-only helper for Stories 18.31's and 18.33's suites: <class>OcuPilot.Test.DocDbAppProbe</class> over the
/// privileged routine applications. The probe applications, the probe resource they name (<parameter>RESOURCE</parameter>),
/// the agent's mint through a tool's own class (<method>Mint</method>) and a confirm run as a real principal in a child
/// process (<method>RunAs</method>) are the parent's; an application is named by its name alone, so the namespace
/// argument every parent method takes is <code>""</code> here. The probe roles the lists name
/// (<parameter>ROLEPREFIX</parameter>) are its own. It holds no assertions.</p>
/// <p><b>Only <parameter>PREFIX</parameter> and <parameter>ROLEPREFIX</parameter> are ever touched.</b> An application,
/// resource or role is named from them, in any case, and each is removed by exact name. <code>OcuPilotState</code> and
/// <code>OcuPilotIdentity</code> are never named by it, so no method here can write them.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RoutineAppProbe Extends OcuPilot.Test.DocDbAppProbe
{

/// <p>What every probe application and resource name begins with, in any case.</p>
Parameter PREFIX = "OcuProbe1831";

Parameter RESOURCE = "OcuProbe1831Res";

/// <p>What every probe role name begins with, in any case: the roles the probe applications' lists name
/// (<method>EnsureRole</method>).</p>
Parameter ROLEPREFIX = "OcuProbe1833Role";

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

/// <p>The list as one JSON text, then each probe application's settings and lists as its own <code>GET</code> reads
/// them: the vendor's <code>LIST</code> carries no <code>Description</code> and reads <code>Enabled</code> false on every
/// row, so the list alone cannot show a write to either.</p>
ClassMethod Facts() As %String
{
    Set tFacts = ##super()
    If tFacts = "unreadable" Quit tFacts
    Set tNames = ..Names()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tFacts = tFacts _ $Char(10) _ tName _ "=" _ ..Summary("", tName) _ "|" _ ..Lists(tName)
    }
    Quit tFacts
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

/// <p>The probe role <var>pSuffix</var> names: <parameter>ROLEPREFIX</parameter> and it.</p>
ClassMethod RoleName(pSuffix As %String) As %String
{
    Quit ..#ROLEPREFIX _ pSuffix
}

/// <p>Create the probe role <var>pSuffix</var> names in <code>%SYS</code> carrying <var>pResources</var>
/// (<code>resource:permission</code> entries, comma-separated), when the instance holds none of that name. A role that
/// carries an <code>%Admin_</code> resource escalates (<method>OcuPilot.Kernel.Proposal.Prohibited.RoleGrantsAdministrativePrivilege</method>).</p>
ClassMethod EnsureRole(pSuffix As %String, pResources As %String = "") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Security.Roles).Exists(..RoleName(pSuffix)) Set tSC = ##class(Security.Roles).Create(..RoleName(pSuffix), "OcuPilot privileged routine application probe role", pResources, "")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The probe roles the instance holds, as a <class>%List</class> of names exactly as stored.</p>
ClassMethod Roles() As %List
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Security.Roles:ListAll")
        Set tSC = tRS.Execute(..#ROLEPREFIX _ "*")
        While $$$ISOK(tSC) && tRS.Next(.tSC) {
            If $ZConvert($Extract(tRS.Get("Name"), 1, $Length(..#ROLEPREFIX)), "L") = $ZConvert(..#ROLEPREFIX, "L") Set tNames = tNames _ $ListBuild(tRS.Get("Name"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tNames
}

/// <p>Delete every probe role by exact name.</p>
ClassMethod RemoveRoles() As %Status
{
    Set tSC = $$$OK
    Set tNames = ..Roles()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tNames) {
            Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete($List(tNames, tI)))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The probe applications, then the probe roles, then the probe resource are removed
/// (<method>OcuPilot.Test.DocDbAppProbe.RemoveAll</method>).</p>
ClassMethod RemoveAll() As %Status
{
    Set tSC = ##super()
    Quit $$$ADDSC(tSC, ..RemoveRoles())
}

/// <p>How many probe applications, resources and roles the instance holds.</p>
ClassMethod Remaining() As %Integer
{
    Quit ##super() + $ListLength(..Roles())
}

/// <p>The target roles of the entry for <var>pMatch</var> in <var>pName</var>'s <code>MatchRoles</code>, sorted and
/// comma-separated, or <code>absent</code> when the instance holds no such application.</p>
ClassMethod Targets(pName As %String, pMatch As %String = "") As %String
{
    Set tRead = ..Stored("", pName)
    If '$IsObject(tRead) Quit "absent"
    Kill tSorted
    If tRead.%GetTypeOf("MatchRoles") = "array" {
        Set tEntries = tRead.%Get("MatchRoles").%GetIterator()
        While tEntries.%GetNext(.tIndex, .tEntry) {
            If '$IsObject(tEntry) || (tEntry.%Get("MatchRole") '= pMatch) || (tEntry.%GetTypeOf("TargetRoles") '= "array") Continue
            Set tTargets = tEntry.%Get("TargetRoles").%GetIterator()
            While tTargets.%GetNext(.tTargetIndex, .tTarget) {
                Set tSorted(tTarget) = ""
            }
        }
    }
    Set tOut = ""
    Set tRole = ""
    For {
        Set tRole = $Order(tSorted(tRole))
        If tRole = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRole
    }
    Quit tOut
}

/// <p>The routines of <var>pName</var> as <code>name:db:type</code> entries, sorted and comma-separated, or
/// <code>absent</code>.</p>
ClassMethod Entries(pName As %String) As %String
{
    Set tRead = ..Stored("", pName)
    If '$IsObject(tRead) Quit "absent"
    Kill tSorted
    If tRead.%GetTypeOf("Routines") = "array" {
        Set tIterator = tRead.%Get("Routines").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If $IsObject(tEntry) Set tSorted(tEntry.%Get("RoutineOrClass") _ ":" _ tEntry.%Get("Db") _ ":" _ tEntry.%Get("Type")) = ""
        }
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

/// <p>The body of a probe application that holds one application role and one routine, which a change must send back
/// (AD-4), with the description <var>pDescription</var>.</p>
ClassMethod WithLists(pDescription As %String = "probe") As %DynamicObject
{
    Quit {"Description": (pDescription), "Enabled": true, "Resource": "", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%DB_HSCUSTOM"]}], "Routines": [{"RoutineOrClass": "OcuProbe1831.Routine", "Db": "HSCUSTOM", "Type": "Class"}]}
}

}
