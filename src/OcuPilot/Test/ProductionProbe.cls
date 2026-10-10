/// <p>Test-only helper for Story 20.2's suites: a probe production in <code>USER</code> that the tests
/// start, stop, restart, update and recover through <class>OcuPilot.Port.InteropPort</class>. It
/// creates, in package <parameter>PACKAGE</parameter>, the productions
/// <parameter>PRODUCTION</parameter> and <parameter>OTHER</parameter>, a business operation
/// (<parameter>OPNAME</parameter>, with a <code>HangSeconds</code> and an <code>InitSeconds</code>
/// setting), a business service (<parameter>SVCNAME</parameter>) and a business rule class
/// (<parameter>RULECLASS</parameter>), and removes only those and the
/// runtime state and message rows whose configuration names begin with
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

/// <p>The probe business rule class, a bare <code>Ens.Rule.Definition</code> subclass.</p>
Parameter RULECLASS = "OcuPilotProbe.Interop.Rule";

/// <p>The prefix of every configuration name the probe owns.</p>
Parameter CONFIGPREFIX = "OcuPilotProbe";

/// <p>The class text of one probe class, <var>pName</var> without its package.</p>
ClassMethod ClassText(pName As %String) As %String [ Private ]
{
    Set tNL = $Char(13, 10)
    If pName = "Op" {
        Quit "Class " _ ..#PACKAGE _ ".Op Extends Ens.BusinessOperation" _ tNL _ "{" _ tNL _
            "Parameter INVOCATION = ""Queue"";" _ tNL _
            "Parameter SETTINGS = ""HangSeconds:Probe,InitSeconds:Probe"";" _ tNL _
            "Property HangSeconds As %Integer [ InitialExpression = 0 ];" _ tNL _
            "Property InitSeconds As %Integer [ InitialExpression = 0 ];" _ tNL _
            "Method OnInit() As %Status" _ tNL _ "{" _ tNL _
            " If +..InitSeconds > 0 Hang ..InitSeconds" _ tNL _ " Quit $$$OK" _ tNL _ "}" _ tNL _
            "Method Hang(pRequest As Ens.Request, Output pResponse As Ens.Response) As %Status" _ tNL _ "{" _ tNL _
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
            " Quit ..SendRequestAsync(""" _ ..#OPNAME _ """, pInput)" _ tNL _ "}" _ tNL _ "}" _ tNL
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
    For tName = "Op", "Svc", "TearOp", "Rule", "Production", "Other" {
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
/// given, with that host setting at <var>pSettingValue</var> (Story 20.3). It works on the stored
/// configuration the way the vendor's own code does and never through OcuPilot's port, so a test can build a
/// state the port refuses to make, such as a second item of one name. The production class is not saved, so
/// the item lasts until <method>ResetProduction</method> or the class is compiled again.</p>
ClassMethod AddItem(pName As %String, pClass As %String, pPoolSize As %Integer = 1, pEnabled As %Boolean = 1, pSettingName As %String = "", pSettingValue As %String = "") As %Status
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
            Set tSetting.Target = "Host"
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

/// <p>Add the probe operation whose teardown waits <var>pSeconds</var> seconds (Story 20.3) to the stored
/// probe production, enabled, as <parameter>TEARNAME</parameter>: a production that stops with it running
/// quiesces and then outlasts a stop's wait, which the vendor answers <code>ErrJobsNotStopped</code>.</p>
ClassMethod AddTearItem(pSeconds As %Integer) As %Status
{
    Quit ..AddItem(..#TEARNAME, ..#PACKAGE _ ".TearOp", 1, 1, "TearDownSeconds", +pSeconds)
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

/// <p>Queue one message to the probe operation, through the probe service, which must be running.</p>
ClassMethod Send() As %Status
{
    Set tSC = ..CheckOwn()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ##class(Ens.Director).CreateBusinessService(..#SVCNAME, .tService)
        If $$$ISOK(tSC) Set tSC = tService.ProcessInput(##class(Ens.Request).%New(), .tOutput)
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
/// read Troubled).</p>
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
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Pid FROM %SYS.ProcessQuery WHERE UserName = '_Ensemble' AND NameSpace = ?", ..#NAMESPACE)
            While tRS.%Next() {
                Do $System.Process.Terminate(tRS.%GetData(1))
            }
            Hang 1
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
