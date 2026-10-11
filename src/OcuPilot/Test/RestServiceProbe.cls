/// <p>Test-only helper for Story 18.32's suites: <class>OcuPilot.Test.DocDbAppProbe</class> over the spec-based REST
/// services. The agent's mint through a tool's own class (<method>Mint</method>) and a confirm run as a real principal
/// in a child process (<method>RunAs</method>, which reaches <class>OcuPilot.Port.MgmntPort</class>) are the parent's.
/// This class adds the probe services of a namespace (<method>Seed</method>, <method>Services</method>,
/// <method>Document</method>), a web application that deploys one (<method>Deploy</method>), and the removal of every
/// object a probe made (<method>RemoveAll</method>). It holds no assertions.</p>
/// <p><b>Only <parameter>PREFIX</parameter> and <parameter>APPLICATIONPREFIX</parameter> are ever touched.</b> A class
/// is named from the first, in any case, and a web application from the second; each is removed by exact name, and
/// <code>OcuPilot</code> names are never built by it. A service is created and deleted through the real management
/// API port, and the classes a delete keeps (<code>.impl</code>) are removed by name.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RestServiceProbe Extends OcuPilot.Test.DocDbAppProbe
{

/// <p>What every probe package and class name begins with, in any case.</p>
Parameter PREFIX = "OcuProbe1832";

/// <p>Inherited and unused: the REST services name no resource.</p>
Parameter RESOURCE = "OcuProbe1832Res";

Parameter ENDPOINT = "Service";

Parameter PORT = "OcuPilot.Port.MgmntPort";

/// <p>What every probe web application's path begins with, in lower case. It is under <code>/api/</code>, never
/// under the paths <class>OcuPilot.Test.DatabaseWriteProbe</class> sweeps.</p>
Parameter APPLICATIONPREFIX = "/api/ocuprobe1832";

/// <p>A valid OpenAPI 2.0 document of one operation, titled <var>pTitle</var>, which the management API builds a
/// service from.</p>
ClassMethod Document(pTitle As %String = "probe") As %DynamicObject
{
    Quit {"swagger": "2.0", "info": {"title": (pTitle), "version": "1"}, "basePath": "/probe", "paths": {"/ping": {"get": {"operationId": "ping", "responses": {"200": {"description": "ok"}}}}}}
}

/// <p>A 2.0 document that passes the port's rules and that the management API cannot build: a path parameter nothing
/// declares.</p>
ClassMethod Unbuildable() As %DynamicObject
{
    Quit {"swagger": "2.0", "info": {"title": "unbuildable", "version": "1"}, "paths": {"/items/{id}": {"get": {"operationId": "getItem", "responses": {"200": {"description": "ok"}}}}}}
}

/// <p>Create the probe service <var>pName</var> in <var>pNamespace</var> through the real port, from
/// <var>pDocument</var> (<method>Document</method> when none is given).</p>
ClassMethod Seed(pNamespace As %String, pName As %String, pDocument As %DynamicObject = "") As %Status
{
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "only a name beginning " _ ..#PREFIX _ " is written")
    If '$IsObject(pDocument) Set pDocument = ..Document()
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("application") = pName
    Quit $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "POST", .tQuery, {"Document": (pDocument)}, .tResult, .tHttp, .tFault)
}

/// <p>The name the port's explorer list reports for each probe service <var>pNamespace</var> lists that no web
/// application deploys, as a <class>%List</class> exactly as stored.</p>
ClassMethod Services(pNamespace As %String) As %List
{
    Set tNames = ""
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Applications", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit tNames
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If ..IsProbe(tRow.%Get("Name")) Set tNames = tNames _ $ListBuild(tRow.%Get("Name"))
    }
    Quit tNames
}

/// <p>Whether the listed services of <var>pNamespace</var> include <var>pName</var>, in any letter case.</p>
ClassMethod Listed(pNamespace As %String, pName As %String) As %Boolean
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("application") = pName
    Quit $$$ISOK($ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "STATE", .tQuery, "", .tResult, .tHttp, .tFault))
}

/// <p>Save class <var>pClass</var>, a plain <class>%RegisteredObject</class> no service lists, in <var>pNamespace</var>.
/// A name that does not begin with <parameter>PREFIX</parameter>, in any case, is refused.</p>
ClassMethod SeedClass(pNamespace As %String, pClass As %String) As %Status
{
    If $ZConvert($Extract(pClass, 1, $Length(..#PREFIX)), "U") '= $ZConvert(..#PREFIX, "U") Quit $$$ERROR($$$GeneralError, "not a probe class: " _ pClass)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tDefinition = ##class(%Dictionary.ClassDefinition).%New(pClass)
        Set tDefinition.Super = "%RegisteredObject"
        Set tSC = tDefinition.%Save()
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pNamespace</var> holds class <var>pClass</var>.</p>
ClassMethod HasClass(pNamespace As %String, pClass As %String) As %Boolean
{
    Set tHas = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tHas = ''##class(%Dictionary.ClassDefinition).%ExistsId(pClass)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHas
}

/// <p>Which of the specification, dispatch and implementation classes of package <var>pName</var> <var>pNamespace</var>
/// holds, as three digits in that order.</p>
ClassMethod Classes(pNamespace As %String, pName As %String) As %String
{
    Quit ..HasClass(pNamespace, pName _ ".spec") _ ..HasClass(pNamespace, pName _ ".disp") _ ..HasClass(pNamespace, pName _ ".impl")
}

/// <p>Replace the body of method <var>pMethod</var> of the probe class <var>pClass</var> in <var>pNamespace</var> with
/// <var>pBody</var>, the way an author edits a service's implementation class.</p>
ClassMethod SetMethodBody(pNamespace As %String, pClass As %String, pMethod As %String, pBody As %String) As %Status
{
    If '..IsProbe(pClass) Quit $$$ERROR($$$GeneralError, "only a class beginning " _ ..#PREFIX _ " is written")
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tMethod = ##class(%Dictionary.MethodDefinition).%OpenId(pClass _ "||" _ pMethod)
        If '$IsObject(tMethod) {
            Set tSC = $$$ERROR($$$GeneralError, pClass _ " holds no method " _ pMethod)
        } Else {
            Do tMethod.Implementation.Clear()
            Do tMethod.Implementation.WriteLine(pBody)
            Set tSC = tMethod.%Save()
        }
        Set tMethod = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The body of method <var>pMethod</var> of the probe class <var>pClass</var> in <var>pNamespace</var>, without its
/// line ends and its indentation, or <code>absent</code> when the class holds no such method.</p>
ClassMethod MethodBody(pNamespace As %String, pClass As %String, pMethod As %String) As %String
{
    Set tBody = "absent"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tMethod = ##class(%Dictionary.MethodDefinition).%OpenId(pClass _ "||" _ pMethod)
        If $IsObject(tMethod) Set tBody = $ZStrip(tMethod.Implementation.Read(2000), "<>WC")
        Set tMethod = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tBody
}

/// <p>Create the web application <var>pPath</var> (which begins <parameter>APPLICATIONPREFIX</parameter>) in
/// <var>pNamespace</var> dispatching to the probe service <var>pName</var>'s dispatch class.</p>
ClassMethod Deploy(pNamespace As %String, pName As %String, pPath As %String) As %Status
{
    If $ZConvert($Extract(pPath, 1, $Length(..#APPLICATIONPREFIX)), "L") '= ..#APPLICATIONPREFIX Quit $$$ERROR($$$GeneralError, "only a path beginning " _ ..#APPLICATIONPREFIX _ " is written")
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("NameSpace") = pNamespace
        Set tProps("DispatchClass") = pName _ ".disp"
        Set tProps("Enabled") = 1
        Set tProps("AutheEnabled") = 32
        Set tSC = ##class(Security.Applications).Create(pPath, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The probe web applications the instance holds, as a <class>%List</class> exactly as stored.</p>
ClassMethod Applications() As %List
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM Security.Applications WHERE LOWER(Name) %STARTSWITH ?", ..#APPLICATIONPREFIX)
        While tRS.%Next() {
            Set tNames = tNames _ $ListBuild(tRS.%GetData(1))
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tNames
}

/// <p>The names of the probe classes <var>pNamespace</var> holds, in any case, as a <class>%List</class> exactly as
/// stored.</p>
ClassMethod ClassNames(pNamespace As %String) As %List
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE UPPER(Name) %STARTSWITH ?", $ZConvert(..#PREFIX, "U"))
        While tRS.%Next() {
            Set tNames = tNames _ $ListBuild(tRS.%GetData(1))
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tNames
}

/// <p>The state a test must leave as it found it: the probe classes of <var>pNamespace</var> and the probe web
/// applications, as one text.</p>
ClassMethod Facts(pNamespace As %String = "USER") As %String
{
    Quit $ListToString(..ClassNames(pNamespace)) _ "|" _ $ListToString(..Applications())
}

/// <p>Delete every probe web application, then every probe service of <var>pNamespace</var> through the real port, then
/// every probe class it still holds, in any case (a delete keeps <code>.impl</code>), then clear the system monitor:
/// the port logs a write the vendor refused, which raises the instance's alert state, and only a clear resets it.</p>
ClassMethod RemoveAll(pNamespace As %String = "USER") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tApps = ..Applications()
        For tI = 1:1:$ListLength(tApps) {
            Set tApp = $List(tApps, tI)
            If ##class(Security.Applications).Exists(tApp) Set tSC = $$$ADDSC(tSC, ##class(Security.Applications).Delete(tApp))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Set tNames = ..Services(pNamespace)
    For tI = 1:1:$ListLength(tNames) {
        Kill tQuery
        Set tQuery("namespace") = pNamespace
        Set tQuery("application") = $List(tNames, tI)
        Do $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    }
    Set tClasses = ..ClassNames(pNamespace)
    Try {
        Set $NAMESPACE = pNamespace
        For tI = 1:1:$ListLength(tClasses) {
            Set tClass = $List(tClasses, tI)
            If ##class(%Dictionary.ClassDefinition).%ExistsId(tClass) Set tSC = $$$ADDSC(tSC, $System.OBJ.Delete(tClass, "-d"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Do $SYSTEM.Monitor.Clear()
    Quit tSC
}

/// <p>How many probe classes <var>pNamespace</var> and probe web applications the instance holds.</p>
ClassMethod Remaining(pNamespace As %String = "USER") As %Integer
{
    Quit $ListLength(..ClassNames(pNamespace)) + $ListLength(..Applications())
}

}
