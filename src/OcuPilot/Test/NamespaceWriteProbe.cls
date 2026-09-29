/// <p>Test-only helper for the namespace suites: creates and removes namespaces named with
/// <parameter>PREFIX</parameter> over the instance's existing databases, each by its exact name,
/// through <class>OcuPilot.Port.AdminPort</class> and never through <class>Config.Namespaces</class>;
/// and seeds the web applications <parameter>APPPREFIX</parameter> bound to one and one global
/// mapping in it, through <class>Security.Applications</class> and <class>Config.MapGlobals</class> in
/// <code>%SYS</code> by explicit save and restore. It never touches a namespace, application or
/// mapping whose name is outside those prefixes and <parameter>EXTRANAMES</parameter>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.NamespaceWriteProbe Extends %RegisteredObject
{

/// <p>The prefix every probe namespace's name starts with, compared upper-cased.</p>
Parameter PREFIX = "OCUPROBE182";

/// <p>The prefix every probe web application's path starts with, compared lower-cased.</p>
Parameter APPPREFIX = "/csp/ocuprobe182";

/// <p>The name corpus's two names outside <parameter>PREFIX</parameter>: one the instance accepts
/// (a leading <code>%</code>) and one it refuses (a leading digit), removed by exact name should
/// either ever be created.</p>
Parameter EXTRANAMES = "%OCUPROBE182P,1OCUPROBE182";

Parameter PORT = "OcuPilot.Port.AdminPort";

Parameter ENDPOINT = "Namespace.Namespace";

/// <p>Whether <var>pName</var> is a name this helper may create or remove.</p>
ClassMethod IsProbe(pName As %String) As %Boolean
{
    Set tName = $ZConvert(pName, "U")
    If $Extract(tName, 1, $Length(..#PREFIX)) = ..#PREFIX Quit 1
    Quit ''$ListFind($ListFromString(..#EXTRANAMES), tName)
}

/// <p>Create the namespace <var>pName</var> over <var>pGlobals</var> and <var>pRoutines</var>
/// through the port; a name outside the probe names is refused.</p>
ClassMethod Add(pName As %String, pGlobals As %String = "USER", pRoutines As %String = "USER") As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe namespace's name starts with " _ ..#PREFIX)
    Kill tQuery
    Set tQuery("name") = pName
    Set tBody = {}
    Do tBody.%Set("Globals", pGlobals, "string")
    Do tBody.%Set("Routines", pRoutines, "string")
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If +$Get(tHttp) '= 201 Quit $$$ERROR($$$GeneralError, "the probe namespace " _ pName _ " was answered " _ $Get(tHttp) _ ", not created")
    Quit $$$OK
}

/// <p>Send <var>pName</var> to the vendor's create with the <code>USER</code> databases, whatever its
/// shape, answering the HTTP status in <var>pHttp</var>: the corpus's question to the instance. A
/// name outside the probe names is refused before the port.</p>
ClassMethod Attempt(pName As %String, Output pHttp As %Integer) As %Status
{
    Set pHttp = 0
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "a probe namespace's name starts with " _ ..#PREFIX)
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "PUT", .tQuery, {"Globals": "USER", "Routines": "USER"}, .tResult, .pHttp, .tFault)
    Quit $$$OK
}

/// <p>The namespace <var>pName</var> as the vendor's <code>GET</code> answers it, or <code>""</code>
/// when the instance does not hold it.</p>
ClassMethod Read(pName As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) || 'tResult.%IsA("%Library.DynamicObject") Quit ""
    Quit tResult
}

/// <p>Whether the instance holds the namespace <var>pName</var>.</p>
ClassMethod Holds(pName As %String) As %Boolean
{
    Quit $IsObject(..Read(pName))
}

/// <p>The namespace <var>pName</var>'s stored <var>pField</var>, or <code>""</code>.</p>
ClassMethod Stored(pName As %String, pField As %String) As %String
{
    Set tRead = ..Read(pName)
    If '$IsObject(tRead) Quit ""
    Quit tRead.%Get(pField)
}

/// <p>Remove the namespace <var>pName</var> through the port when it is present; an error when it
/// survives. A name outside the probe names is refused.</p>
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

/// <p>Create the web application <var>pPath</var> bound to <var>pNamespace</var>, password
/// authenticated and enabled; a path outside <parameter>APPPREFIX</parameter> is refused.</p>
ClassMethod AddApplication(pPath As %String, pNamespace As %String) As %Status
{
    If $Extract($ZConvert(pPath, "L"), 1, $Length(..#APPPREFIX)) '= ..#APPPREFIX Quit $$$ERROR($$$GeneralError, "a probe application's path starts with " _ ..#APPPREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tProperties("NameSpace") = pNamespace
        Set tProperties("Enabled") = 1
        Set tProperties("AutheEnabled") = 32
        Set tProperties("Description") = "OcuPilot namespace probe (throwaway)"
        Set tSC = ##class(Security.Applications).Create(pPath, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the instance holds the web application <var>pPath</var>.</p>
ClassMethod HoldsApplication(pPath As %String) As %Boolean
{
    Set tHeld = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tHeld = ''##class(Security.Applications).Exists(pPath)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tHeld = 0
    }
    Quit tHeld
}

/// <p>Map the global <var>pGlobal</var> of namespace <var>pNamespace</var> to the <code>USER</code>
/// database; a namespace outside the probe names is refused.</p>
ClassMethod AddMapping(pNamespace As %String, pGlobal As %String) As %Status
{
    If '..IsProbe(pNamespace) Quit $$$ERROR($$$GeneralError, "a probe mapping belongs to a probe namespace")
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tProperties("Database") = "USER"
        Set tSC = ##class(Config.MapGlobals).Create($ZConvert(pNamespace, "U"), pGlobal, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many global mappings the namespace <var>pNamespace</var> carries.</p>
ClassMethod MappingCount(pNamespace As %String) As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Config.MapGlobals:List")
        If $$$ISOK(tRS.Execute($ZConvert(pNamespace, "U"), "*")) {
            While tRS.Next() { Set tCount = tCount + 1 }
            Do tRS.Close()
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>The web applications bound to <var>pNamespace</var>, as a sorted comma-separated list.</p>
ClassMethod ApplicationsOf(pNamespace As %String) As %String
{
    Kill tSorted
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Security.Applications:NamespaceList")
        If $$$ISOK(tRS.Execute($ZConvert(pNamespace, "U"))) {
            While tRS.Next() { Set tSorted(tRS.Get("Name")) = "" }
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

/// <p>Whether the instance's configuration holds the database <var>pName</var>.</p>
ClassMethod HoldsDatabase(pName As %String) As %Boolean
{
    Set tHeld = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tHeld = ''##class(Config.Databases).Exists(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tHeld = 0
    }
    Quit tHeld
}

/// <p>Remove every probe namespace and every probe web application, each by its exact name.
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
        Set tApps = ..ProbeApplications()
        If tApps '= "" {
            Set tOrigNS = $NAMESPACE
            Try {
                Set $NAMESPACE = "%SYS"
                For tI = 1:1:$ListLength(tApps) {
                    Set tSC = $$$ADDSC(tSC, ##class(Security.Applications).Delete($List(tApps, tI)))
                }
                Set $NAMESPACE = tOrigNS
            } Catch ex {
                Set $NAMESPACE = tOrigNS
                Set tSC = $$$ADDSC(tSC, ex.AsStatus())
            }
        }
        Set pRemaining = $ListLength(..ProbeNames()) + $ListLength(..ProbeApplications())
        If pRemaining > 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, pRemaining _ " probe namespace(s) or application(s) survived their removal"))
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

/// <p>The probe web applications the instance holds, by exact path.</p>
ClassMethod ProbeApplications() As %List
{
    Set tApps = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Security.Applications:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                Set tName = tRS.Get("Name")
                If $Extract($ZConvert(tName, "L"), 1, $Length(..#APPPREFIX)) = ..#APPPREFIX Set tApps = tApps _ $ListBuild(tName)
            }
            Do tRS.Close()
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tApps
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

}
