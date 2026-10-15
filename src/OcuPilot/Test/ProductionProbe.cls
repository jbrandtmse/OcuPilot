/// <p>Test-only helper for Story 20.2's suites: a probe production in <code>USER</code> that the tests
/// start, stop, restart, update and recover through <class>OcuPilot.Port.InteropPort</class>. It
/// creates, in package <parameter>PACKAGE</parameter>, the productions
/// <parameter>PRODUCTION</parameter> and <parameter>OTHER</parameter>, a business operation
/// (<parameter>OPNAME</parameter>, with a <code>HangSeconds</code> and an <code>InitSeconds</code>
/// setting and, for Story 20.22, an <code>ApiToken</code> (a credential-named string), a
/// <code>ProbeDirectory</code> (a <code>directorySelector</code>) and a <code>ProbeFile</code> (a
/// <code>fileSelector</code>)), a business service (<parameter>SVCNAME</parameter>) and a business rule class
/// (<parameter>RULECLASS</parameter>), and, for Story 20.23, a business operation that fails and asks to be retried
/// (<parameter>RETRYCLASS</parameter>, added to the stored production by <method>AddRetryItem</method>), and removes only those
/// and the runtime state and message rows whose configuration names begin with
/// <parameter>CONFIGPREFIX</parameter>.</p>
/// <p>Every entry point refuses, touching nothing, when <code>USER</code>'s current production is not
/// one of the two the probe owns. The classes are compiled in <code>USER</code>, so a run of the
/// probe needs a throwaway: it starts a production there.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ProductionProbe Extends %RegisteredObject
{

/// <p>The namespace the probe lives in.</p>
Parameter NAMESPACE = "USER";

/// <p>The package every probe class is created in.</p>
Parameter PACKAGE = "OcuPilotProbe.Interop";

/// <p>The probe production the tests drive.</p>
Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

/// <p>The second probe production, which a start of the first must refuse beside it.</p>
Parameter OTHER = "OcuPilotProbe.Interop.Other";

/// <p>The probe operation's configuration name.</p>
Parameter OPNAME = "OcuPilotProbeOp";

/// <p>The probe service's configuration name.</p>
Parameter SVCNAME = "OcuPilotProbeSvc";

/// <p>The probe operation whose teardown waits (Story 20.3): its configuration name, added to the stored
/// production by <method>AddTearItem</method>.</p>
Parameter TEARNAME = "OcuPilotProbeTearOp";

/// <p>The probe operation that fails every message and asks to be retried (Story 20.23): its job reads <code>Retry</code>
/// with the message it keeps retrying until its failure timeout.</p>
Parameter RETRYCLASS = "OcuPilotProbe.Interop.RetryOp";

/// <p>The probe business rule class, a bare <code>Ens.Rule.Definition</code> subclass.</p>
Parameter RULECLASS = "OcuPilotProbe.Interop.Rule";

/// <p>The stored <code>HangSeconds</code> above which <method>Release</method> ends a job holding a message before a
/// stop (Story 20.4).</p>
Parameter RELEASEABOVE = 30;

/// <p>The prefix of every configuration name the probe owns.</p>
Parameter CONFIGPREFIX = "OcuPilotProbe";

/// <p>The event-log line the probe operation writes for each message it takes, before it hangs, so each message
/// leaves one row whose configuration name is the operation's (Story 20.4).</p>
Parameter LOGTEXT = "OcuPilot probe message";

/// <p>The class text of one probe class, <var>pName</var> without its package.</p>
ClassMethod ClassText(pName As %String) As %String [ Private ]
{
    Set tNL = $Char(13, 10)
    If pName = "Op" {
        Quit "Class " _ ..#PACKAGE _ ".Op Extends Ens.BusinessOperation" _ tNL _ "{" _ tNL _
            "Parameter INVOCATION = ""Queue"";" _ tNL _
            "Parameter SETTINGS = ""HangSeconds:Probe,InitSeconds:Probe,ApiToken:Probe,ProbeDirectory:Probe:directorySelector,ProbeFile:Probe:fileSelector"";" _ tNL _
            "Property HangSeconds As %Integer [ InitialExpression = 0 ];" _ tNL _
            "Property InitSeconds As %Integer [ InitialExpression = 0 ];" _ tNL _
            "Property ApiToken As %String;" _ tNL _
            "Property ProbeDirectory As %String;" _ tNL _
            "Property ProbeFile As %String;" _ tNL _
            "Method OnInit() As %Status" _ tNL _ "{" _ tNL _
            " If +..InitSeconds > 0 Hang ..InitSeconds" _ tNL _ " Quit $$$OK" _ tNL _ "}" _ tNL _
            "Method Hang(pRequest As Ens.Request, Output pResponse As Ens.Response) As %Status" _ tNL _ "{" _ tNL _
            " $$$LOGINFO(""" _ ..#LOGTEXT _ """)" _ tNL _
            " If +..HangSeconds > 0 Hang ..HangSeconds" _ tNL _ " Quit $$$OK" _ tNL _ "}" _ tNL _
            "XData MessageMap" _ tNL _ "{" _ tNL _
            "<MapItems><MapItem MessageType=""Ens.Request""><Method>Hang</Method></MapItem></MapItems>" _ tNL _ "}" _ tNL _ "}" _ tNL
    }
    If pName = "TearOp" {
        Quit "Class " _ ..#PACKAGE _ ".TearOp Extends Ens.BusinessOperation" _ tNL _ "{" _ tNL _
            "Parameter INVOCATION = ""Queue"";" _ tNL _
            "Parameter SETTINGS = ""TearDownSeconds:Probe"";" _ tNL _
            "Property TearDownSeconds As %Integer [ InitialExpression = 0 ];" _ tNL _
            "Method OnTearDown() As %Status" _ tNL _ "{" _ tNL _
            " If +..TearDownSeconds > 0 Hang ..TearDownSeconds" _ tNL _ " Quit $$$OK" _ tNL _ "}" _ tNL _
            "Method Idle(pRequest As Ens.Request, Output pResponse As Ens.Response) As %Status" _ tNL _ "{" _ tNL _
            " Quit $$$OK" _ tNL _ "}" _ tNL _
            "XData MessageMap" _ tNL _ "{" _ tNL _
            "<MapItems><MapItem MessageType=""Ens.Request""><Method>Idle</Method></MapItem></MapItems>" _ tNL _ "}" _ tNL _ "}" _ tNL
    }
    If pName = "RetryOp" {
        Quit "Class " _ ..#RETRYCLASS _ " Extends Ens.BusinessOperation" _ tNL _ "{" _ tNL _
            "Parameter INVOCATION = ""Queue"";" _ tNL _
            "Method Fail(pRequest As Ens.Request, Output pResponse As Ens.Response) As %Status" _ tNL _ "{" _ tNL _
            " Set ..Retry = 1" _ tNL _ " Quit $$$ERROR($$$GeneralError, ""OcuPilot probe retry"")" _ tNL _ "}" _ tNL _
            "XData MessageMap" _ tNL _ "{" _ tNL _
            "<MapItems><MapItem MessageType=""Ens.Request""><Method>Fail</Method></MapItem></MapItems>" _ tNL _ "}" _ tNL _ "}" _ tNL
    }
    If pName = "Rule" {
        Quit "Class " _ ..#RULECLASS _ " Extends Ens.Rule.Definition" _ tNL _ "{" _ tNL _
            "XData RuleDefinition [ XMLNamespace = ""http://www.intersystems.com/rule"" ]" _ tNL _ "{" _ tNL _
            "<ruleDefinition alias="""" context=""EnsLib.MsgRouter.RoutingEngine"" production="""">" _ tNL _
            "<ruleSet name="""" effectiveBegin="""" effectiveEnd=""""><rule name=""""><when condition=""1""></when></rule></ruleSet>" _ tNL _
            "</ruleDefinition>" _ tNL _ "}" _ tNL _ "}" _ tNL
    }
    If pName = "Svc" {
        Quit "Class " _ ..#PACKAGE _ ".Svc Extends Ens.BusinessService" _ tNL _ "{" _ tNL _
            "Method OnProcessInput(pInput As %RegisteredObject, Output pOutput As %RegisteredObject, ByRef pHint As %String) As %Status" _ tNL _ "{" _ tNL _
            " Quit ..SendRequestAsync($Select($Get(pHint) '= """": pHint, 1: """ _ ..#OPNAME _ """), pInput)" _ tNL _ "}" _ tNL _ "}" _ tNL
    }
    Set tName = $Select(pName = "Other": ..#OTHER, 1: ..#PRODUCTION)
    Quit "Class " _ tName _ " Extends Ens.Production" _ tNL _ "{" _ tNL _
        "XData ProductionDefinition" _ tNL _ "{" _ tNL _
        "<Production Name=""" _ tName _ """ LogGeneralTraceEvents=""false"">" _ tNL _
        "<Description>Story 20.2 probe production</Description>" _ tNL _
        "<ActorPoolSize>1</ActorPoolSize>" _ tNL _
        "<Item Name=""" _ ..#OPNAME _ """ Category="""" ClassName=""" _ ..#PACKAGE _ ".Op"" PoolSize=""1"" Enabled=""true"" Foreground=""false"" Comment="""" LogTraceEvents=""false"" Schedule="""">" _ tNL _
        "<Setting Target=""Host"" Name=""HangSeconds"">0</Setting>" _ tNL _
        "</Item>" _ tNL _
        "<Item Name=""" _ ..#SVCNAME _ """ Category="""" ClassName=""" _ ..#PACKAGE _ ".Svc"" PoolSize=""0"" Enabled=""true"" Foreground=""false"" Comment="""" LogTraceEvents=""false"" Schedule="""">" _ tNL _
        "</Item>" _ tNL _
        "</Production>" _ tNL _ "}" _ tNL _ "}" _ tNL
}

/// <p>The probe rule class's document name, as the Rules list names it.</p>
ClassMethod RuleDocument() As %String
{
    Quit ..#RULECLASS _ ".cls"
}

/// <p>The production <code>USER</code> is running or holds suspended or troubled, <code>""</code> when
/// none; and in <var>pState</var> its state number.</p>
ClassMethod Current(Output pState As %Integer) As %String
{
    Set pState = 0
    Set tCurrent = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ##class(Ens.Director).GetProductionStatus(.tCurrent, .pState, 2)
        If $$$ISERR(tSC) Set tCurrent = "", pState = 0
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCurrent = ""
        Set pState = 0
    }
    Quit $Get(tCurrent)
}

/// <p>A failing status naming the foreign production when <code>USER</code>'s current production is
/// neither empty nor one the probe owns.</p>
ClassMethod CheckOwn() As %Status
{
    Set tCurrent = ..Current()
    If (tCurrent '= "") && (tCurrent '= ..#PRODUCTION) && (tCurrent '= ..#OTHER) Quit $$$ERROR($$$GeneralError, "USER's current production is not the probe's own: " _ tCurrent)
    Quit $$$OK
}

/// <p>Create and compile the probe classes in <code>USER</code>.</p>
ClassMethod Create() As %Status
{
    Set tSC = ..CheckOwn()
    If $$$ISERR(tSC) Quit tSC
    For tName = "Op", "Svc", "TearOp", "RetryOp", "Rule", "Production", "Other" {
        Set tClass = $Select(tName = "Production": ..#PRODUCTION, tName = "Other": ..#OTHER, 1: ..#PACKAGE _ "." _ tName)
        Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tClass, ..ClassText(tName))
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.CompilePackage(..#PACKAGE, "ck-d")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The probe operation's <code>Ens.Config.Item</code> in the probe production, or
/// <code>""</code>.</p>
ClassMethod OpItem(pProduction As Ens.Config.Production) As Ens.Config.Item [ Private ]
{
    Set tItem = ""
    For tI = 1:1:pProduction.Items.Count() {
        If pProduction.Items.GetAt(tI).Name = ..#OPNAME Set tItem = pProduction.Items.GetAt(tI)
    }
    Quit tItem
}

/// <p>Add the item <var>pName</var>, of class <var>pClass</var>, to the stored probe production with pool size
/// <var>pPoolSize</var>, enabled unless <var>pEnabled</var> is 0, and, when <var>pSettingName</var> is
/// given, with that setting at <var>pSettingValue</var> in the group <var>pSettingTarget</var>, Host unless
/// another is given (Stories 20.3 and 20.22). It works on the stored
/// configuration the way the vendor's own code does and never through OcuPilot's port, so a test can build a
/// state the port refuses to make, such as a second item of one name. The production class is not saved, so
/// the item lasts until <method>ResetProduction</method> or the class is compiled again.</p>
ClassMethod AddItem(pName As %String, pClass As %String, pPoolSize As %Integer = 1, pEnabled As %Boolean = 1, pSettingName As %String = "", pSettingValue As %String = "", pSettingTarget As %String = "Host") As %Status
{
    Set tSC = ..CheckOwn()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tProduction = ##class(Ens.Config.Production).%OpenId(..#PRODUCTION, 4)
        Set tItem = ##class(Ens.Config.Item).%New(pClass)
        Set tItem.Name = pName
        Set tItem.PoolSize = pPoolSize
        Set tItem.Enabled = ''pEnabled
        If pSettingName '= "" {
            Set tSetting = ##class(Ens.Config.Setting).%New()
            Set tSetting.Target = pSettingTarget
            Set tSetting.Name = pSettingName
            Set tSetting.Value = pSettingValue
            Do tItem.Settings.Insert(tSetting)
        }
        Do tProduction.Items.Insert(tItem)
        Set tSC = tProduction.%Save()
        Set tSetting = "", tItem = "", tProduction = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the probe's retrying operation (Story 20.23) to the stored probe production as <var>pName</var>, enabled, with its
/// <code>RetryInterval</code> at <var>pInterval</var> seconds and its <code>FailureTimeout</code> at <var>pTimeout</var>: a message
/// sent to it fails, and the item's job reads <code>Retry</code> with that message until the timeout ends.</p>
ClassMethod AddRetryItem(pName As %String, pInterval As %Integer = 2, pTimeout As %Integer = 300) As %Status
{
    Set tSC = ..AddItem(pName, ..#RETRYCLASS, 1, 1)
    If $$$ISOK(tSC) Set tSC = ..PutItemSetting(pName, "Host", "RetryInterval", pInterval)
    If $$$ISOK(tSC) Set tSC = ..PutItemSetting(pName, "Host", "FailureTimeout", pTimeout)
    Quit tSC
}

/// <p>Add the probe operation whose teardown waits <var>pSeconds</var> seconds (Story 20.3) to the stored
/// probe production, enabled, as <parameter>TEARNAME</parameter>: a production that stops with it running
/// quiesces and then outlasts a stop's wait, which the vendor answers <code>ErrJobsNotStopped</code>.</p>
ClassMethod AddTearItem(pSeconds As %Integer) As %Status
{
    Quit ..AddItem(..#TEARNAME, ..#PACKAGE _ ".TearOp", 1, 1, "TearDownSeconds", +pSeconds)
}

/// <p>Add a <b>disabled</b> item <var>pName</var> of the file class <var>pClass</var> (<code>EnsLib.File.PassthroughOperation</code>
/// or <code>EnsLib.File.PassthroughService</code>) with its adapter's <code>FilePath</code> at <var>pFilePath</var> and,
/// when <var>pLevels</var> is not empty, its <code>SubdirectoryLevels</code> at <var>pLevels</var> (Story 20.22). It is
/// <method>AddItem</method> with the adapter group, so the item is never started and no job reads the path.</p>
ClassMethod AddFileItem(pName As %String, pClass As %String, pFilePath As %String, pLevels As %String = "") As %Status
{
    Set tSC = ..AddItem(pName, pClass, 1, 0, "FilePath", pFilePath, "Adapter")
    If $$$ISERR(tSC) || (pLevels = "") Quit tSC
    Quit ..PutItemSetting(pName, "Adapter", "SubdirectoryLevels", pLevels)
}

/// <p>Store the setting <var>pTarget</var>/<var>pName</var> of the item <var>pItem</var> of the probe production at
/// <var>pValue</var>, in the stored configuration only (Story 20.22); the production class is not saved.</p>
ClassMethod PutItemSetting(pItem As %String, pTarget As %String, pName As %String, pValue As %String) As %Status
{
    Set tSC = ..CheckOwn()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tProduction = ##class(Ens.Config.Production).%OpenId(..#PRODUCTION, 4)
        Set tItem = tProduction.FindItemByConfigName(pItem)
        If '$IsObject(tItem) {
            Set tSC = $$$ERROR($$$GeneralError, "the probe production holds no item " _ pItem)
        } Else {
            Set tSetting = tItem.FindSettingByName(pName, pTarget)
            If '$IsObject(tSetting) {
                Set tSetting = ##class(Ens.Config.Setting).%New()
                Set tSetting.Target = pTarget
                Set tSetting.Name = pName
                Do tItem.Settings.Insert(tSetting)
            }
            Set tSetting.Value = pValue
            Set tSC = tProduction.%Save()
        }
        Set tSetting = "", tItem = "", tProduction = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store a system default setting for the item <var>pItem</var> of the probe production (Story 20.22):
/// <var>pName</var> of the group <var>pTarget</var> at <var>pValue</var>. An item's own Core setting is named bare, as the
/// vendor reads it; a Host or Adapter setting by its group and name. <method>RemoveDefaults</method> removes every default
/// the probe stored.</p>
ClassMethod PutDefault(pItem As %String, pTarget As %String, pName As %String, pValue As %String) As %Status
{
    Set tProduction = ..#PRODUCTION
    Set tSettingName = $Select(pTarget = "Core": pName, 1: pTarget _ ":" _ pName)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tDefault = ##class(Ens.Config.DefaultSettings).%New()
        Set tDefault.ProductionName = tProduction
        Set tDefault.ItemName = pItem
        Set tDefault.SettingName = tSettingName
        Set tDefault.SettingValue = pValue
        Set tSC = tDefault.%Save()
        Set tDefault = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every system default setting the probe stored for the probe production (Story 20.22).</p>
ClassMethod RemoveDefaults()
{
    Set tProduction = ..#PRODUCTION
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        &sql(DELETE FROM Ens_Config.DefaultSettings WHERE ProductionName = :tProduction)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Put the probe production back as <method>ClassText</method> declares it (Story 20.3): its class is
/// written again and compiled, so the stored configuration is reloaded from the class and every item an
/// earlier test added, removed or switched is as it was made. It refuses, touching nothing, when
/// <code>USER</code>'s current production is not one of the probe's own.</p>
ClassMethod ResetProduction() As %Status
{
    Set tSC = ..CheckOwn()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, ..#PRODUCTION, ..ClassText("Production"))
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.Compile(..#PRODUCTION, "ck-d")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Queue one message to the probe operation, through the probe service, which must be running. With <var>pTarget</var> the
/// service forwards it to the item of that name instead (Story 20.23).</p>
ClassMethod Send(pTarget As %String = "") As %Status
{
    Set tSC = ..CheckOwn()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tHint = pTarget
        Set tSC = ##class(Ens.Director).CreateBusinessService(..#SVCNAME, .tService)
        If $$$ISOK(tSC) Set tSC = tService.ProcessInput(##class(Ens.Request).%New(), .tOutput, .tHint)
        Set tService = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Set the probe operation's setting <var>pName</var> (<code>HangSeconds</code> or
/// <code>InitSeconds</code>) to <var>pValue</var> in the stored production configuration, which a
/// running production reads as a pending update.</p>
ClassMethod SetSetting(pName As %String, pValue As %Integer) As %Status
{
    If (pName '= "HangSeconds") && (pName '= "InitSeconds") Quit $$$ERROR($$$GeneralError, "the probe operation has two settings: HangSeconds and InitSeconds")
    Set tSC = ..CheckOwn()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tProduction = ##class(Ens.Config.Production).%OpenId(..#PRODUCTION)
        Set tItem = ..OpItem(tProduction)
        If '$IsObject(tItem) {
            Set tSC = $$$ERROR($$$GeneralError, "the probe operation is not in the probe production")
        } Else {
            Set tSetting = tItem.FindSettingByName(pName, "Host")
            If '$IsObject(tSetting) {
                Set tSetting = ##class(Ens.Config.Setting).%New()
                Set tSetting.Target = "Host"
                Set tSetting.Name = pName
                Do tItem.Settings.Insert(tSetting)
            }
            Set tSetting.Value = +pValue
            Set tSC = tProduction.%Save()
            Set tSetting = ""
        }
        Set tItem = "", tProduction = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Set the probe operation's <code>HangSeconds</code> to <var>pSeconds</var>.</p>
ClassMethod SetHang(pSeconds As %Integer) As %Status
{
    Quit ..SetSetting("HangSeconds", pSeconds)
}

/// <p>Leave the probe production reading Troubled: start it, terminate its <code>_Ensemble</code> jobs
/// in <code>USER</code> and kill <code>^%SYS("Ensemble","RunningNamespace","USER")</code> (measured to
/// read Troubled). No <code>_Ensemble</code> job is left in <code>USER</code> on success, so nothing
/// takes an <code>Ens.Actor</code> entry a caller queues afterwards: a job the start launched after one
/// termination pass lingers for about twenty seconds in <code>Ens.Queue</code> (measured), so passes
/// repeat until two in a row find none, for at most thirty seconds, and an error is returned past that.</p>
ClassMethod MakeTroubled() As %Status
{
    Set tSC = ..CheckOwn()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tCurrent = ..Current(.tState)
        If tState '= 1 Set tSC = ##class(Ens.Director).StartProduction(..#PRODUCTION)
        If $$$ISOK(tSC) {
            Set tQuiet = 0
            Set tDeadline = $ZHorolog + 30
            While (tQuiet < 2) && ($ZHorolog < tDeadline) {
                Set tFound = 0
                Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Pid FROM %SYS.ProcessQuery WHERE UserName = '_Ensemble' AND NameSpace = ?", ..#NAMESPACE)
                While tRS.%Next() {
                    Set tFound = 1
                    Do $System.Process.Terminate(tRS.%GetData(1))
                }
                Set tQuiet = $Select(tFound: 0, 1: tQuiet + 1)
                Hang 0.5
            }
            If tQuiet < 2 Set tSC = $$$ERROR($$$GeneralError, "an _Ensemble job in " _ ..#NAMESPACE _ " outlived thirty seconds of termination passes")
            Kill ^%SYS("Ensemble", "RunningNamespace", ..#NAMESPACE)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Leave <code>USER</code> with no production running, suspended or troubled: recover a troubled
/// production, start a suspended one, abort every queue still holding a message (a production whose
/// queues hold one stops as Suspended, never as Stopped), then stop it, forcing only when a normal stop
/// is refused; and put the probe operation's <code>HangSeconds</code> back to zero. Nothing is deleted.
/// A failing status when a production is still current afterwards.</p>
ClassMethod Settle() As %Status
{
    Set tSC = ..CheckOwn()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tPass = 1:1:4 {
            Set tCurrent = ..Current(.tState)
            If tCurrent = "" Quit
            If tState = 4 Do ##class(Ens.Director).RecoverProduction()
            Set tCurrent = ..Current(.tState)
            If tState = 3 {
                Do ##class(Ens.Director).StartProduction(tCurrent)
                Hang 2
            }
            Set tCurrent = ..Current(.tState)
            If tState = 1 {
                Do ..AbortRetrying()
                Do ..Release()
                Do ..AbortQueues()
                If $$$ISERR(##class(Ens.Director).StopProduction(10, 0)) Do ##class(Ens.Director).StopProduction(10, 1)
            }
        }
        Set tCurrent = ..Current(.tState)
        If tCurrent '= "" Set tSC = $$$ERROR($$$GeneralError, "the probe could not settle USER: " _ tCurrent _ " reads state " _ tState)
        If $$$ISOK(tSC) && ##class(Ens.Config.Production).%ExistsId(..#PRODUCTION) Set tSC = ..SetHang(0)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Abort the message of every probe job that is retrying one (Story 20.23) and wait, fifteen seconds at most, until each job
/// has taken the abort: a stop of a production whose job is retrying puts the message back on its queue, which leaves the
/// production Suspended and its next start retrying again. The abort is the vendor's own, taken when the job's current retry
/// wait ends. Called only inside <code>USER</code>, while the probe's own production is current.</p>
ClassMethod AbortRetrying() [ Private ]
{
    Set tHosts = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateHostStatus")
    Do tHosts.Execute()
    Kill tNames
    While tHosts.Next() {
        If $Extract(tHosts.GetData(1), 1, $Length(..#CONFIGPREFIX)) = ..#CONFIGPREFIX Set tNames(tHosts.GetData(1)) = ""
    }
    Do tHosts.Close()
    If '..RetryingJobs(.tNames, .tPids) Quit
    Set tPid = ""
    For {
        Set tPid = $Order(tPids(tPid))
        If tPid = "" Quit
        Do ##class(Ens.Job).AbortOperation(tPid)
    }
    For tTry = 1:1:60 {
        Hang 0.25
        If '..RetryingJobs(.tNames, .tAgain) Quit
    }
}

/// <p>How many jobs of the hosts named in <var>pNames</var> (the subscripts) read <code>Retry</code> with a message, and their
/// process ids in <var>pPids</var> (the subscripts).</p>
ClassMethod RetryingJobs(ByRef pNames, Output pPids) As %Integer [ Private ]
{
    Kill pPids
    Set tCount = 0
    Set tName = ""
    For {
        Set tName = $Order(pNames(tName))
        If tName = "" Quit
        Set tRS = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateJobStatus")
        Do tRS.Execute(tName)
        While tRS.Next() {
            If (tRS.GetData(3) = "Retry") && (tRS.GetData(9) '= "") && (+tRS.GetData(2) > 0) {
                Set pPids(tRS.GetData(2)) = ""
                Set tCount = tCount + 1
            }
        }
        Do tRS.Close()
    }
    Quit tCount
}

/// <p>End the probe operation's jobs that hold a message while its stored <code>HangSeconds</code> is above
/// <parameter>RELEASEABOVE</parameter>: a job hung that long outlasts any stop, and a forced stop puts its message back
/// on the queue, which leaves the production Suspended and its next start hung again. It waits, fifteen seconds at
/// most, until the vendor has marked each ended job dead and taken its message back (the job's own row leaves the host
/// monitor), so the queues are aborted after. Called only inside <code>USER</code>, while the probe's own production is
/// current.</p>
ClassMethod Release() [ Private ]
{
    Set tProduction = ##class(Ens.Config.Production).%OpenId(..#PRODUCTION)
    If '$IsObject(tProduction) Quit
    Set tItem = ..OpItem(tProduction)
    Set tHang = 0
    If $IsObject(tItem) {
        Set tSetting = tItem.FindSettingByName("HangSeconds", "Host")
        If $IsObject(tSetting) Set tHang = +tSetting.Value
    }
    Set tSetting = "", tItem = "", tProduction = ""
    If tHang <= ..#RELEASEABOVE Quit
    Set tRS = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateJobStatus")
    Do tRS.Execute(..#OPNAME)
    Kill tPids
    While tRS.Next() {
        If (tRS.GetData(9) '= "") && (+tRS.GetData(2) > 0) Set tPids(+tRS.GetData(2)) = ""
    }
    Set tPid = ""
    For {
        Set tPid = $Order(tPids(tPid))
        If tPid = "" Quit
        If tPid > 0 Do $System.Process.Terminate(tPid)
    }
    If '$Data(tPids) Quit
    For tTry = 1:1:60 {
        Hang 0.25
        Set tHeld = 0
        Set tRS = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateJobStatus")
        Do tRS.Execute(..#OPNAME)
        While tRS.Next() {
            If $Data(tPids(+tRS.GetData(2))) Set tHeld = 1
        }
        Do tRS.Close()
        If 'tHeld Quit
    }
}

/// <p>Abort the interoperability queues of <code>USER</code> that hold a message and are the scheduler's
/// or the probe's own, never a job's private queue. Called only inside <code>USER</code>, while the
/// probe's own production is current.</p>
ClassMethod AbortQueues() [ Private ]
{
    Set tRS = ##class(%ResultSet).%New("Ens.Queue:Enumerate")
    Do tRS.Execute()
    Kill tNames
    While tRS.Next() {
        Set tName = tRS.GetData(1)
        If (tName = "Ens.ScheduleHandler") || ($Extract(tName, 1, $Length(..#CONFIGPREFIX)) = ..#CONFIGPREFIX) Set tNames(tName) = ""
    }
    Set tName = ""
    For {
        Set tName = $Order(tNames(tName))
        If tName = "" Quit
        Do ##class(Ens.Queue).AbortQueue(tName)
    }
}

/// <p>USER's highest <code>Ens.MessageHeader</code> id and highest <code>Ens_Util.Log</code> id, as <code>&lt;headers&gt;|&lt;logs&gt;</code>
/// (<code>0</code> for an empty table): the mark a suite records before it makes messages, so <method>SweepSince</method> removes
/// exactly what the suite made and nothing a person or an earlier run left (Story 20.31). <code>""</code> when either table could not
/// be read, which <method>SweepSince</method> refuses to sweep from.</p>
ClassMethod HighWater() As %String
{
    Set tMark = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(ID) FROM Ens.MessageHeader")
        Set tHeaders = $Select(tRS.%Next(): +tRS.%GetData(1), 1: "")
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(ID) FROM Ens_Util.Log")
        Set tLogs = $Select(tRS.%Next(): +tRS.%GetData(1), 1: "")
        If (tHeaders '= "") && (tLogs '= "") Set tMark = tHeaders _ "|" _ tLogs
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tMark = ""
    }
    Quit tMark
}

/// <p>Delete, in <code>USER</code>, every message header above the mark <var>pMark</var> (<method>HighWater</method>'s) and the
/// persistent or stream body each names that no header at or below the mark still names (a resend shares its original's body), and
/// every event-log row above the mark. The answer is what is left above the mark, as <code>&lt;headers&gt;|&lt;logs&gt;</code>:
/// <code>0|0</code> for a clean sweep (Story 20.31). A mark that is not <code>&lt;digits&gt;|&lt;digits&gt;</code> deletes nothing
/// and answers <code>?|?</code>.</p>
ClassMethod SweepSince(pMark As %String) As %String
{
    Set tLeft = "?|?"
    If pMark '? 1.N1"|"1.N Quit tLeft
    Set tHeaderMark = +$Piece(pMark, "|", 1)
    Set tLogMark = +$Piece(pMark, "|", 2)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Kill tBodies
        ; The class name is read from the header, not from a query: an index returns it in upper case, which no class carries.
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM Ens.MessageHeader WHERE ID > ?", tHeaderMark)
        While tRS.%Next() {
            Set tHeader = ##class(Ens.MessageHeader).%OpenId(tRS.%GetData(1))
            If $IsObject(tHeader) && (tHeader.MessageBodyClassName '= "") && (tHeader.MessageBodyId '= "") Set tBodies(tHeader.MessageBodyClassName, tHeader.MessageBodyId) = ""
            Set tHeader = ""
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM Ens.MessageHeader WHERE ID > ?", tHeaderMark)
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM Ens_Util.Log WHERE ID > ?", tLogMark)
        Set tClass = ""
        For {
            Set tClass = $Order(tBodies(tClass))
            If tClass = "" Quit
            If '$Match(tClass, "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") || '##class(%Dictionary.CompiledClass).%ExistsId(tClass) Continue
            If '$ClassMethod(tClass, "%Extends", "%Library.Persistent") && '$ClassMethod(tClass, "%Extends", "%Stream.Object") Continue
            Set tId = ""
            For {
                Set tId = $Order(tBodies(tClass, tId))
                If tId = "" Quit
                Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Ens.MessageHeader WHERE MessageBodyClassName = ? AND MessageBodyId = ?", tClass, tId)
                If tRS.%Next() && (+tRS.%GetData(1) = 0) Do $ClassMethod(tClass, "%DeleteId", tId)
            }
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Ens.MessageHeader WHERE ID > ?", tHeaderMark)
        Set tHeaders = $Select(tRS.%Next(): +tRS.%GetData(1), 1: "?")
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Ens_Util.Log WHERE ID > ?", tLogMark)
        Set tLogs = $Select(tRS.%Next(): +tRS.%GetData(1), 1: "?")
        Set tLeft = tHeaders _ "|" _ tLogs
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tLeft
}

/// <p>Save the body <var>pBody</var> and a request header for it in <code>USER</code>, through
/// <code>Ens.MessageHeader.NewRequestMessage</code>, sent by the probe service (<parameter>SVCNAME</parameter>) to the item
/// <var>pTarget</var> and read <code>Completed</code>, so a resend of it needs no production to have handled it first
/// (Story 20.31). The new header's id is in <var>pId</var>. It refuses, touching nothing, when <code>USER</code>'s current
/// production is not one of the probe's own.</p>
ClassMethod StoredRequest(pBody As %RegisteredObject, pTarget As %String = {..#OPNAME}, Output pId As %String) As %Status
{
    Set pId = ""
    Set tSC = ..CheckOwn()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ##class(Ens.MessageHeader).NewRequestMessage(.tHeader, pBody, .tSession)
        If $$$ISOK(tSC) {
            Set tHeader.SourceConfigName = ..#SVCNAME
            Set tHeader.SourceBusinessType = 1
            Set tHeader.TargetConfigName = pTarget
            Set tHeader.TargetBusinessType = 3
            Set tHeader.TargetQueueName = pTarget
            Set tHeader.Invocation = 1
            Set tHeader.Status = 9
            Set tSC = tHeader.%Save()
            Set pId = tHeader.%Id()
        }
        Set tHeader = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Save, in <code>USER</code>, the response header to the request header <var>pRequestId</var> through
/// <code>Ens.MessageHeader.NewResponseMessage</code>, with the reply queue it is addressed to set to <var>pQueue</var> and
/// the status <code>Completed</code> (Story 20.31): a queue no production has makes it a response whose reply queue no longer
/// exists. The new header's id is in <var>pId</var>. It refuses, touching nothing, when <code>USER</code>'s current production is not
/// one of the probe's own.</p>
ClassMethod StoredResponse(pRequestId As %String, pQueue As %String, Output pId As %String) As %Status
{
    Set pId = ""
    Set tSC = ..CheckOwn()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRequest = ##class(Ens.MessageHeader).%OpenId(pRequestId)
        If '$IsObject(tRequest) {
            Set tSC = $$$ERROR($$$GeneralError, "the request header " _ pRequestId _ " is not there")
        } Else {
            Set tBody = ##class(Ens.StringResponse).%New()
            Set tBody.StringValue = "reply"
            Set tSC = tRequest.NewResponseMessage(.tHeader, tBody)
            If $$$ISOK(tSC) {
                Set tHeader.TargetQueueName = pQueue
                Set tHeader.Status = 9
                Set tSC = tHeader.%Save()
                Set pId = tHeader.%Id()
            }
        }
        Set tHeader = ""
        Set tRequest = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>1 when <code>USER</code> holds no probe state: no current production, no probe production
/// configuration and no probe class; 0 otherwise.</p>
ClassMethod Gone() As %Boolean
{
    Set tGone = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tGone = (..Current() = "") && '##class(Ens.Config.Production).%ExistsId(..#PRODUCTION) && '##class(Ens.Config.Production).%ExistsId(..#OTHER) && '##class(%Dictionary.ClassDefinition).%ExistsId(..#PRODUCTION) && '##class(%Dictionary.ClassDefinition).%ExistsId(..#RULECLASS)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tGone = 0
    }
    Quit tGone
}

/// <p>Leave <code>USER</code> holding no probe state: settle the current production, delete the probe
/// classes, their configuration rows, their activity and last-production records, and the message
/// headers and event-log rows whose configuration names begin with <parameter>CONFIGPREFIX</parameter>.
/// It refuses, touching nothing, when <code>USER</code>'s current production is not one of its own. One
/// of its own that cannot be settled is removed all the same, and the failure is the status returned.</p>
ClassMethod Remove() As %Status
{
    Set tSC = ..CheckOwn()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Settle()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        ; A production that could not be settled and whose class is gone is a suspended marker alone.
        If $ListFind($ListBuild(..#PRODUCTION, ..#OTHER), $Get(^Ens.Suspended)) Kill ^Ens.Suspended
        Set tProductionName = ""
        For tProductionName = ..#PRODUCTION, ..#OTHER {
            If ##class(Ens.Config.Production).%ExistsId(tProductionName) Do ##class(Ens.Config.Production).%DeleteId(tProductionName)
            Kill ^Ens.Configuration("csp", "Activity", tProductionName)
            If $Get(^Ens.Configuration("csp", "LastProduction")) = tProductionName Kill ^Ens.Configuration("csp", "LastProduction")
        }
        Do $System.OBJ.DeletePackage(..#PACKAGE, "-d")
        Do $System.OBJ.DeletePackage("OcuPilotProbe", "-d")
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM Ens.MessageHeader WHERE SourceConfigName %STARTSWITH ? OR TargetConfigName %STARTSWITH ?", ..#CONFIGPREFIX, ..#CONFIGPREFIX)
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM Ens_Util.Log WHERE ConfigName %STARTSWITH ?", ..#CONFIGPREFIX)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
