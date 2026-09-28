/// <p>Test-only helper for the namespace mapping suites (Story 18.14): creates and removes namespaces
/// named with <parameter>PREFIX</parameter> over the <code>USER</code> database, each by its exact
/// name, through <class>OcuPilot.Port.AdminPort</class>; and seeds and reads global, routine and
/// package mappings in them through <class>Config.MapGlobals</class>,
/// <class>Config.MapRoutines</class> and <class>Config.MapPackages</class> in <code>%SYS</code> by
/// explicit save and restore. It never touches a namespace outside <parameter>PREFIX</parameter>, and
/// a namespace's delete takes its mappings with it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MappingProbe Extends %RegisteredObject
{

/// <p>The prefix every probe namespace's name starts with, compared upper-cased.</p>
Parameter PREFIX = "OCUPROBE1814";

/// <p>The prefix every probe mapping's name starts with; one beginning with
/// <parameter>OWNPREFIX</parameter> or <code>%</code> and then it is a probe mapping too.</p>
Parameter MAPPINGPREFIX = "OcuProbe1814";

Parameter OWNPREFIX = "OcuPilotProbe1814";

Parameter PORT = "OcuPilot.Port.AdminPort";

Parameter ENDPOINT = "Namespace.Namespace";

/// <p>Whether <var>pName</var> is a namespace this helper may create or remove.</p>
ClassMethod IsProbe(pName As %String) As %Boolean
{
    Quit $Extract($ZConvert(pName, "U"), 1, $Length(..#PREFIX)) = ..#PREFIX
}

/// <p>Create the namespace <var>pName</var> over <code>USER</code> through the port; a name outside
/// the probe names is refused.</p>
ClassMethod Add(pName As %String) As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe namespace's name starts with " _ ..#PREFIX)
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "PUT", .tQuery, {"Globals": "USER", "Routines": "USER"}, .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If +$Get(tHttp) '= 201 Quit $$$ERROR($$$GeneralError, "the probe namespace " _ pName _ " was answered " _ $Get(tHttp) _ ", not created")
    Quit $$$OK
}

/// <p>Whether the instance holds the namespace <var>pName</var>.</p>
ClassMethod Holds(pName As %String) As %Boolean
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    Quit $$$ISOK(tSC) && $IsObject($Get(tResult))
}

/// <p>Remove the namespace <var>pName</var> through the port when it is present, and its mappings
/// with it; an error when it survives. A name outside the probe names is refused.</p>
ClassMethod Remove(pName As %String) As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe namespace's name starts with " _ ..#PREFIX)
    If '..Holds(pName) Quit $$$OK
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    If ..Holds(pName) Quit $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the probe namespace " _ pName _ " is still present after its removal"))
    Quit $$$OK
}

/// <p>The <class>Config</class> class that stores mappings of kind <var>pKind</var>.</p>
ClassMethod ConfigClass(pKind As %String) As %String [ Private ]
{
    Quit $Case(pKind, "global": "Config.MapGlobals", "routine": "Config.MapRoutines", "package": "Config.MapPackages", : "")
}

/// <p>Seed the <var>pKind</var> mapping <var>pName</var> of probe namespace <var>pNamespace</var>
/// onto database <var>pDatabase</var>, test-only, in <code>%SYS</code>. A namespace outside the probe
/// names is refused.</p>
ClassMethod AddMapping(pKind As %String, pNamespace As %String, pName As %String, pDatabase As %String = "USER") As %Status
{
    If '..IsProbe(pNamespace) Quit $$$ERROR($$$GeneralError, "a probe mapping belongs to a probe namespace")
    Set tClass = ..ConfigClass(pKind)
    If tClass = "" Quit $$$ERROR($$$GeneralError, "no mapping kind " _ pKind)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tProperties("Database") = pDatabase
        Set tSC = $ClassMethod(tClass, "Create", $ZConvert(pNamespace, "U"), pName, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether namespace <var>pNamespace</var> holds the <var>pKind</var> mapping <var>pName</var>,
/// read in <code>%SYS</code>, with its stored properties in <var>pProperties</var>.</p>
ClassMethod HoldsMapping(pKind As %String, pNamespace As %String, pName As %String, Output pProperties) As %Boolean
{
    Kill pProperties
    Set tHeld = 0
    Set tClass = ..ConfigClass(pKind)
    If tClass = "" Quit 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tHeld = ''$ClassMethod(tClass, "Exists", $ZConvert(pNamespace, "U"), pName)
        If tHeld Do $ClassMethod(tClass, "Get", $ZConvert(pNamespace, "U"), pName, .pProperties)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tHeld = 0
    }
    Quit tHeld
}

/// <p>The <var>pKind</var> mapping <var>pName</var>'s stored <var>pField</var> in namespace
/// <var>pNamespace</var>, or <code>""</code>.</p>
ClassMethod Stored(pKind As %String, pNamespace As %String, pName As %String, pField As %String) As %String
{
    If '..HoldsMapping(pKind, pNamespace, pName, .tProperties) Quit ""
    Quit $Get(tProperties(pField))
}

/// <p>The names of namespace <var>pNamespace</var>'s <var>pKind</var> mappings, sorted and
/// comma-separated, read in <code>%SYS</code>.</p>
ClassMethod Names(pKind As %String, pNamespace As %String) As %String
{
    Kill tSorted
    Set tClass = ..ConfigClass(pKind)
    If tClass = "" Quit ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New(tClass _ ":List")
        If $$$ISOK(tRS.Execute($ZConvert(pNamespace, "U"), "*")) {
            While tRS.Next() { Set tSorted(tRS.GetData(1)) = "" }
            Do tRS.Close()
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
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

/// <p>Remove every probe namespace, each by its exact name, and with it every mapping it holds.
/// <var>pRemaining</var> is how many survived, and the status is an error when any did.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set pRemaining = 0
    Set tSC = $$$OK
    Try {
        Set tNames = ..ProbeNames(.tListSC)
        If $$$ISERR(tListSC) {
            Set tSC = tListSC
            Quit
        }
        For tI = 1:1:$ListLength(tNames) {
            Set tSC = $$$ADDSC(tSC, ..Remove($List(tNames, tI)))
        }
        Set pRemaining = $ListLength(..ProbeNames())
        If pRemaining > 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, pRemaining _ " probe namespace(s) survived their removal"))
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The probe namespaces the instance holds, as the vendor's list names them.</p>
ClassMethod ProbeNames(Output pSC As %Status) As %List
{
    Set tNames = ""
    Kill tQuery
    Set pSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(pSC) || '$IsObject($Get(tRows)) Quit ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If ..IsProbe(tRow.%Get("Name")) Set tNames = tNames _ $ListBuild(tRow.%Get("Name"))
    }
    Quit tNames
}

/// <p>Whether the instance's configuration file validates (<code>Config.CPF.Validate</code>), and
/// whether it names any probe namespace, in <var>pNamesProbe</var>.</p>
ClassMethod CpfValid(Output pNamesProbe As %Boolean) As %Boolean
{
    Set pNamesProbe = 0
    Set tValid = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tFile = ##class(%SYS.System).GetCPFFileName()
        Set tStream = ##class(%Stream.FileCharacter).%New()
        If $$$ISOK(tStream.LinkToFile(tFile)) {
            While 'tStream.AtEnd {
                If $ZConvert(tStream.ReadLine(), "U") [ ..#PREFIX Set pNamesProbe = 1
            }
        }
        Set tStream = ""
        Set tValid = $$$ISOK(##class(Config.CPF).Validate())
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValid = 0
    }
    Quit tValid
}

/// <p>The composite id of <var>pNamespace</var>'s mapping <var>pName</var>.</p>
ClassMethod Id(pNamespace As %String, pName As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pNamespace, pName))
}

}
