/// <p>The Story 19.17 fixture: <code>%Service_DocDB</code> enabled and restored, probe document databases
/// named <parameter>PREFIX</parameter> made and removed, the vendor's DocDB access-denied audit rows
/// counted, and a child process that calls <class>OcuPilot.Port.DocDbPort</class> as a real principal
/// (<method>Probe</method>).</p>
/// <p><b>Every method refuses unless <parameter>ARMINGVARIABLE</parameter> reads 1</b>, so a runner
/// pointed at an instance someone cares about enables no service and creates or drops nothing through
/// this class. A database or class is removed only when its name carries <parameter>PREFIX</parameter>,
/// and the removal is read back.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DocDbProbe Extends %RegisteredObject
{

/// <p>The environment variable that arms every method here, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

/// <p>The service the fixture enables and restores.</p>
Parameter SERVICE = "%Service_DocDB";

/// <p>The prefix every probe database's name carries, compared without regard to case.</p>
Parameter PREFIX = "OcuProbe1917";

/// <p>An error status unless the arming variable reads 1.</p>
ClassMethod Armed() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DocDbProbe enables %Service_DocDB and creates and drops document databases, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Quit $$$OK
}

/// <p>Whether <parameter>SERVICE</parameter> is enabled, in <var>pEnabled</var>.</p>
ClassMethod ServiceEnabled(Output pEnabled As %Boolean) As %Status
{
    Set pEnabled = ""
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Services).Get(..#SERVICE, .tProperties)
        Set $NAMESPACE = tOrigNS
        If $$$ISOK(tSC) Set pEnabled = +$Get(tProperties("Enabled"))
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Enable <parameter>SERVICE</parameter>, answering in <var>pPrior</var> whether it was enabled
/// before; an error status when it does not read back enabled.</p>
ClassMethod EnableService(Output pPrior As %Boolean) As %Status
{
    Set pPrior = ""
    Set tSC = ..ServiceEnabled(.pPrior)
    If $$$ISERR(tSC) Quit tSC
    Quit ..SetService(1)
}

/// <p>Put <parameter>SERVICE</parameter> back as <var>pPrior</var> held it, and read it back.</p>
ClassMethod RestoreService(pPrior As %Boolean) As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    If (pPrior '= 0) && (pPrior '= 1) Quit $$$ERROR($$$GeneralError, "no prior state of " _ ..#SERVICE _ " to restore")
    Quit ..SetService(pPrior)
}

/// <p>Set <parameter>SERVICE</parameter>'s <code>Enabled</code> to <var>pEnabled</var> and read it
/// back.</p>
ClassMethod SetService(pEnabled As %Boolean) As %Status [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tProperties("Enabled") = ''pEnabled
        Set tSC = ##class(Security.Services).Modify(..#SERVICE, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ServiceEnabled(.tNow)
    If $$$ISERR(tSC) Quit tSC
    If tNow '= ''pEnabled Quit $$$ERROR($$$GeneralError, ..#SERVICE _ " reads Enabled " _ tNow _ " after it was set to " _ (''pEnabled))
    Quit $$$OK
}

/// <p>Create probe database <var>pName</var> in <var>pNamespace</var> through <code>%SYSTEM.DocDB</code>
/// directly, with no document type and no resource; a name without <parameter>PREFIX</parameter> is
/// refused.</p>
ClassMethod Make(pNamespace As %String, pName As %String) As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "'" _ pName _ "' is not a probe database name")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tDatabase = ##class(%SYSTEM.DocDB).CreateDatabase(pName)
        Set tDatabase = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pNamespace</var> holds a document database named <var>pName</var>, in any case. A
/// lookup that fails raises, so a failure is never read as absence.</p>
ClassMethod Exists(pNamespace As %String, pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tExists = ##class(%SYSTEM.DocDB).Exists(pName)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Quit tExists
}

/// <p>Whether <var>pNamespace</var> defines class <var>pClass</var>, its name compared exactly. A lookup
/// that fails raises.</p>
ClassMethod ClassExists(pNamespace As %String, pClass As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tExists = ##class(%Dictionary.ClassDefinition).%ExistsId(pClass)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Quit tExists
}

/// <p>Save <var>pDocument</var> into probe database <var>pName</var> of <var>pNamespace</var> through the
/// vendor's own database object; a name without <parameter>PREFIX</parameter> is refused.</p>
ClassMethod AddDocument(pNamespace As %String, pName As %String, pDocument As %DynamicObject) As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    If '..IsProbe(pName) Quit $$$ERROR($$$GeneralError, "'" _ pName _ "' is not a probe database name")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tDatabase = ##class(%SYSTEM.DocDB).GetDatabase(pName)
        Set tDocument = tDatabase.%SaveDocument(pDocument)
        Set tDocument = ""
        Set tDatabase = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The global <var>pNamespace</var>'s compiled storage of class <var>pClass</var> keeps its
/// documents in (<code>DataLocation</code>), in <var>pGlobal</var>, or <code>""</code> when the class
/// has no compiled storage.</p>
ClassMethod DataGlobal(pNamespace As %String, pClass As %String, Output pGlobal As %String) As %Status
{
    Set pGlobal = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT DataLocation FROM %Dictionary.CompiledStorage WHERE parent = ?", pClass)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the compiled storage could not be read: SQLCODE " _ tRS.%SQLCODE)
        } ElseIf tRS.%Next() {
            Set pGlobal = tRS.%GetData(1)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether global reference <var>pGlobal</var> holds any node in <var>pNamespace</var>; 0 for a
/// value that is not a global reference. A lookup that fails raises.</p>
ClassMethod HasData(pNamespace As %String, pGlobal As %String) As %Boolean
{
    If $Extract(pGlobal) '= "^" Quit 0
    Set tHas = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tHas = ($Data(@pGlobal) > 0)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Quit tHas
}

/// <p>Drop every document database of <var>pNamespace</var> whose name or class carries
/// <parameter>PREFIX</parameter>, then delete every class whose name does and that survived, and read
/// both back: an error status names whatever is left.</p>
ClassMethod RemoveAll(pNamespace As %String) As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tNames = ##class(%SYSTEM.DocDB).GetAllDatabases()
        Set tIterator = tNames.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) {
            Set tDatabase = ##class(%SYSTEM.DocDB).GetDatabase(tName)
            Set tClass = tDatabase.ClassName
            Set tDatabase = ""
            If ($ZConvert(tName, "U") '[ $ZConvert(..#PREFIX, "U")) && ($ZConvert(tClass, "U") '[ $ZConvert(..#PREFIX, "U")) Continue
            Do ##class(%SYSTEM.DocDB).DropDatabase(tName)
        }
        Set tLeft = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE UPPER(Name) [ ?", $ZConvert(..#PREFIX, "U"))
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the probe classes could not be listed: SQLCODE " _ tRS.%SQLCODE)
        } Else {
            While tRS.%Next() {
                Set tLeft = tLeft _ $ListBuild(tRS.%GetData(1))
            }
        }
        For tI = 1:1:$ListLength(tLeft) {
            Do $System.OBJ.Delete($List(tLeft, tI), "-d")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    Quit ..Remaining(pNamespace)
}

/// <p>An error status naming every probe database or probe class <var>pNamespace</var> still holds,
/// or OK when it holds none.</p>
ClassMethod Remaining(pNamespace As %String) As %Status
{
    Set tLeft = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tNames = ##class(%SYSTEM.DocDB).GetAllDatabases()
        Set tIterator = tNames.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) {
            If $ZConvert(tName, "U") [ $ZConvert(..#PREFIX, "U") Set tLeft = tLeft _ " database " _ tName
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE UPPER(Name) [ ?", $ZConvert(..#PREFIX, "U"))
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the probe classes could not be listed: SQLCODE " _ tRS.%SQLCODE)
        } Else {
            While tRS.%Next() {
                Set tLeft = tLeft _ " class " _ tRS.%GetData(1)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, pNamespace _ " still holds" _ tLeft)
    Quit $$$OK
}

/// <p>How many <code>%System/%Security/AccessDenied</code> "Doc DB Access" rows the audit database
/// holds, in <var>pCount</var>, counted with every index ignored: the indexed count lags the rows
/// (measured).</p>
ClassMethod DeniedCount(Output pCount As %Integer) As %Status
{
    Set pCount = ""
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %IGNOREINDEX * %SYS.Audit WHERE EventSource = '%System' AND EventType = '%Security' AND Event = 'AccessDenied' AND Description = 'Doc DB Access'")
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the audit rows could not be counted: SQLCODE " _ tRS.%SQLCODE)
        } ElseIf tRS.%Next() {
            Set pCount = +tRS.%GetData(1)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The child process <class>OcuPilot.Test.DocDbGate</class> starts: log in as <var>pUsername</var>,
/// then call <class>OcuPilot.Port.DocDbPort</class> in <var>pNamespace</var> to list, create
/// <var>pName</var>, read it and drop it, and signal <code>{loggedIn, username, LIST, CREATE, DATABASE,
/// DROP}</code> to process <var>pParent</var>, each leg <code>{http, code, failedPair}</code>, or
/// <code>{error}</code> when something raised. It runs in its own process so the login never touches the
/// test's own identity; the process ends when this returns.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String, pName As %String)
{
    Set tOut = {}
    Try {
        Set tSC = ..Armed()
        If $$$ISERR(tSC) {
            Do tOut.%Set("error", $System.Status.GetErrorText(tSC))
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        For tType = "LIST", "CREATE", "DATABASE", "DROP" {
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            Set tQuery("name") = pName
            Set tQuery("maxRows") = 5
            Set tHttp = 0
            Set tFault = ""
            Set tSC = ##class(OcuPilot.Port.DocDbPort).Invoke("Databases", tType, .tQuery, "", .tResult, .tHttp, .tFault)
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            If $IsObject(tFault) {
                Do tLeg.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
            Do tOut.%Set(tType, tLeg)
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Whether <var>pName</var> carries <parameter>PREFIX</parameter>, in any case.</p>
ClassMethod IsProbe(pName As %String) As %Boolean [ Private ]
{
    Quit ($ZConvert(pName, "U") [ $ZConvert(..#PREFIX, "U"))
}

}
