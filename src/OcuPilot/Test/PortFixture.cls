/// <p>Subclass of <class>OcuPilot.Port.AdminPort</class> overriding only its seams, so tests run
/// the port's real derivation, probe contract and invocation sequence against fixture classes and
/// armed answers. Nothing about the instance's own admin API, version row or security is changed.</p>
/// <p>Every seam falls back to <code>##super()</code> when nothing is armed, so an unconfigured
/// call behaves like production. <method>LogFault</method> is the exception: it always routes
/// through <class>OcuPilot.Test.FaultProbe</class>, so a test's vendor text lands in
/// <class>OcuPilot.Test.LogProbe</class>'s capture rather than <code>messages.log</code>.</p>
/// <p>State lives in <code>^||OcuPilotPortFixture</code>; <method>Clear</method> forgets it.</p>
Class OcuPilot.Test.PortFixture Extends OcuPilot.Port.AdminPort
{

/// <p>The shipped roster plus the one probe pair this suite invokes:
/// <class>OcuPilot.Test.AdminPortAsync</class> drives the port's mutating-and-queued refusal
/// against <code>OcuPilotProbeAsyncWrite</code> with <code>PUT</code>, which is a pair no shipped
/// endpoint carries.</p>
/// <p><b>The probe pair is added here and never to the shipped parameter</b> (DW-1473): the
/// admitted set is what a confirmed write is allowed to issue against the instance, and a test
/// surface has no place in it. <class>OcuPilot.Test.ToolWrite</class> reads
/// <class>OcuPilot.Port.AdminPort</class>'s own copy, so this override cannot satisfy that
/// roster.</p>
Parameter MUTATINGTYPES = "WebApp.App/PUT,Security.User/PUT,Security.Audit.Enabled/PUT,Task.CRUD/RESUME,Process/SUSPEND,Process/RESUME,OcuPilotProbeAsyncWrite/PUT,Security.User/POST,Security.Role/PUT,Security.Role/DELETE,Security.Resource/PUT,Security.Resource/DELETE,Security.X509Credential/POST,Security.X509Credential/PUT,Security.X509Credential/DELETE,Wallet.Secret/PUT,Device.Standard/PUT,Device.Standard/DELETE,WebApp.App/DELETE,Security.OAuth2.Client.ClientConfiguration/DELETE,Security.OAuth2.ServerClients/DELETE,Security.User/DELETE,Security.User/CHANGEPWD,Task.CRUD/RUN,Task.CRUD/SUSPEND,Task.CRUD/DELETE,Process/TERMINATE,Security.Audit.Event/PUT,Security.Audit.Event/DELETE,Security.Audit.Event/CLEARCOUNT,Security.SSLConfig/PUT,Security.SSLConfig/DELETE,Wallet.Secret/DELETE,Task.CRUD/POST,Task.CRUD/PUT,Security.Service/PUT,Security.LDAP/PUT,Security.OAuth2.Server/REVOKE,Security.Audit.Record/COPY,Security.Audit.Record/PURGE,Security.OAuth2.Client.ServerDefinition/POST,Security.OAuth2.Client.ServerDefinition/PUT,Security.OAuth2.Client.ServerDefinition/DELETE,Security.OAuth2.Client.ServerDefinition/TOKEN,Security.OAuth2.Client.ServerDefinition/REFRESHJWKS,Security.OAuth2.Client.ClientConfiguration/PUT,Security.OAuth2.Client.ClientConfiguration/CHANGESECRET,Security.OAuth2.Client.ClientConfiguration/ROTATEKEYS,Security.OAuth2.Client.ClientConfiguration/REGISTERCLIENT,Security.OAuth2.ResourceServer/PUT,Security.OAuth2.ResourceServer/CHANGESECRET,Security.OAuth2.ResourceServer/DELETE,Security.OAuth2.ResourceServer/ADDMAPPING,Security.OAuth2.ResourceServer/REMOVEMAPPING,Security.OAuth2.ResourceServerMapping/PUT,Security.OAuth2.ResourceServerMapping/DELETE,Security.OAuth2.Server/PUT,Security.OAuth2.Server/DELETE,Security.OAuth2.Server/CHANGEPWD,Security.OAuth2.Server/ROTATEKEYS,Security.OAuth2.ServerClients/POST,Security.OAuth2.ServerClients/PUT,Security.OAuth2.ServerClients/SECRET,Security.OAuth2.ServerClients/REFRESHJWKS,Namespace.Namespace/PUT,Namespace.Namespace/DELETE,WebSession/DELETE,AsyncResult/CANCEL,AsyncResult/PAUSE,AsyncResult/RESUME,BackgroundTask/CANCEL,BackgroundTask/PAUSE,BackgroundTask/RESUME,Namespace.GlobalMappings/PUT,Namespace.GlobalMappings/DELETE,Namespace.RoutineMappings/PUT,Namespace.RoutineMappings/DELETE,Namespace.PackageMappings/PUT,Namespace.PackageMappings/DELETE,Namespace.Namespace/MAPPINGS,Process/BROADCAST,Database.SysCRUD/POST,Database.SysCRUD/PUT,Database.SysCRUD/DELETE,Database.ConfigCRUD/PUT,Database.ConfigCRUD/DELETE,Database.Actions/MOUNT,Database.Actions/DISMOUNT,Database.Actions/TRUNCATE,Database.Actions/COMPACT,Database.Actions/DEFRAGMENT,Database.Actions/EXPANDVOL,Database.Actions/MODIFYSIZE,Database.Actions/INTEGRITYCHECK,TaskTransfer/EXPORT,TaskTransfer/IMPORT,LanguageServer/START,LanguageServer/STOP,LanguageServer/PUT,LanguageServer/DELETE,Task.Manager/SUSPEND,Task.Manager/RESUME,Task.Manager/RUN,Lock/REMOVE,Lock/REMOVEOWNER,Lock/DELETE,Security.LDAP/CHANGEPWD,Security.LDAP/DELETE,Namespace.Namespace/INTEROP,Journal.Settings/SWITCHFILE,Journal.Settings/SWITCHDIR,Journal.File/INTEGRITYCHECK,Journal.Settings/PUT,License.Key/PUT,License.Server/PUT,License.Server/DELETE,ECP.DataServer/PUT,ECP.DataServer/DELETE,ECP.DataServer/SERVERACTION,ECP.Settings/PUT,ECP.AppServerSSLConnection/AUTHORIZE,ECP.AppServerSSLConnection/REJECT,ECP.AppServerSSLConnection/DELETE";

/// <p>Point the derivation at <var>pClass</var> instead of the vendor's routing class.
/// <code>""</code> restores the production value.</p>
ClassMethod SetAdminApiClass(pClass As %String)
{
    Set ^||OcuPilotPortFixture("api") = pClass
}

/// <p>Point the probe at <var>pClass</var> instead of the vendor's endpoint.
/// <code>""</code> restores the production value.</p>
ClassMethod SetProbeEndpointClass(pClass As %String)
{
    Set ^||OcuPilotPortFixture("probe") = pClass
}

/// <p>Resolve every endpoint name to <var>pClass</var>. <code>""</code> restores the
/// production resolution.</p>
ClassMethod SetEndpointClass(pClass As %String)
{
    Set ^||OcuPilotPortFixture("endpoint") = pClass
}

/// <p>Answer every resource check with <var>pHolds</var>.</p>
ClassMethod SetHoldsResource(pHolds As %Boolean)
{
    Set ^||OcuPilotPortFixture("holds") = pHolds
}

/// <p>Declare <var>pSet</var> (<code>&lt;pair&gt;|&lt;pair&gt;</code>) as the backing-query pair
/// set for every endpoint and request type. <code>""</code> restores the production table.</p>
ClassMethod SetQueryPairs(pSet As %String)
{
    Set ^||OcuPilotPortFixture("queryPairs") = pSet
}

/// <p>Answer every backing-query pair check with <var>pHolds</var>. Distinct from
/// <method>SetHoldsResource</method>, which arms the endpoint's own
/// <code>ResourcesOR()</code> gate: DW-274's whole point is that a caller can pass one and be
/// refused by the other.</p>
ClassMethod SetHoldsPair(pHolds As %Boolean)
{
    Set ^||OcuPilotPortFixture("holdsPair") = pHolds
}

/// <p>Bound the async wait at <var>pSeconds</var>.</p>
ClassMethod SetAsyncTimeout(pSeconds As %Numeric)
{
    Set ^||OcuPilotPortFixture("timeout") = pSeconds
}

/// <p>Answer every poll with the <code>AsyncResult</code> answer <var>pJson</var>, and delete no
/// row. Stored as JSON because a process-private global cannot hold an OREF.</p>
ClassMethod SetCannedAnswer(pJson As %String)
{
    Set ^||OcuPilotPortFixture("canned") = pJson
}

/// <p>Answer every poll as a refused read: HTTP <var>pHttp</var>, no answer, and an error status
/// carrying <var>pText</var>. Deletes no row. Takes precedence over
/// <method>SetCannedAnswer</method>.</p>
ClassMethod SetCannedPollRefusal(pHttp As %Integer, pText As %String)
{
    Set ^||OcuPilotPortFixture("pollHttp") = pHttp
    Set ^||OcuPilotPortFixture("pollText") = pText
}

/// <p>A recorded value: <code>name</code> (the endpoint's <code>Name</code> when
/// <code>Run()</code> was about to start), <code>taskName</code> (the last real poll's
/// <code>TaskName</code>), <code>forgot</code> (the GUID last passed to
/// <method>ForgetTask</method>) or <code>polls</code> (how many polls ran). <code>""</code> when
/// never recorded.</p>
ClassMethod Recorded(pKey As %String) As %String
{
    Quit $Get(^||OcuPilotPortFixture("recorded", pKey), "")
}

/// <p>Forget every override and record.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotPortFixture
}

ClassMethod AdminApiClass() As %String
{
    Set tForced = $Get(^||OcuPilotPortFixture("api"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod ProbeEndpointClass() As %String
{
    Set tForced = $Get(^||OcuPilotPortFixture("probe"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod EndpointClass(pEndpoint As %String) As %String
{
    Set tForced = $Get(^||OcuPilotPortFixture("endpoint"), "")
    If tForced '= "" Quit tForced
    Quit ##super(pEndpoint)
}

ClassMethod HoldsResource(pResource As %String) As %Boolean
{
    If $Data(^||OcuPilotPortFixture("holds")) Quit ^||OcuPilotPortFixture("holds")
    Quit ##super(pResource)
}

ClassMethod QueryPairs(pEndpoint As %String, pType As %String) As %String
{
    Set tForced = $Get(^||OcuPilotPortFixture("queryPairs"), "")
    If tForced '= "" Quit tForced
    Quit ##super(pEndpoint, pType)
}

ClassMethod HoldsPair(pPair As %String) As %Boolean
{
    If $Data(^||OcuPilotPortFixture("holdsPair")) Quit ^||OcuPilotPortFixture("holdsPair")
    Quit ##super(pPair)
}

ClassMethod AsyncTimeout() As %Numeric
{
    Set tForced = $Get(^||OcuPilotPortFixture("timeout"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

/// <p>Records the endpoint's <code>Name</code>; an endpoint without one records nothing.</p>
ClassMethod OnBeforeRun(pEndpoint As %RegisteredObject)
{
    Try {
        Set ^||OcuPilotPortFixture("recorded", "name") = $Property(pEndpoint, "Name")
    } Catch {
    }
}

ClassMethod PollTask(pGuid As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer) As %Status
{
    Set ^||OcuPilotPortFixture("recorded", "polls") = $Get(^||OcuPilotPortFixture("recorded", "polls"), 0) + 1
    If $Data(^||OcuPilotPortFixture("pollHttp")) {
        Set pAnswer = ""
        Set pHttpStatus = ^||OcuPilotPortFixture("pollHttp")
        Quit $$$ERROR($$$GeneralError, $Get(^||OcuPilotPortFixture("pollText"), ""))
    }
    Set tCanned = $Get(^||OcuPilotPortFixture("canned"), "")
    If tCanned '= "" {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tCanned)
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set tSC = ##super(pGuid, .pAnswer, .pHttpStatus)
    If $IsObject($Get(pAnswer)) Set ^||OcuPilotPortFixture("recorded", "taskName") = pAnswer.TaskName
    Quit tSC
}

ClassMethod ForgetTask(pGuid As %String)
{
    Set ^||OcuPilotPortFixture("recorded", "forgot") = pGuid
    If $Get(^||OcuPilotPortFixture("canned"), "") '= "" Quit
    If $Data(^||OcuPilotPortFixture("pollHttp")) Quit
    Do ##super(pGuid)
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Test.FaultProbe).LogRaw("adminport", pMessage, pStatus, pCode)
}

/// <p>Save one async task row of the vendor's own class (<parameter>ASYNCTASKCLASS</parameter>,
/// AD-27) with GUID <var>pGuid</var>, task name <var>pTaskName</var>, state <var>pState</var> and
/// <code>TimeQueued</code> <var>pQueued</var> (<code>YYYY-MM-DD HH:MM:SS</code>), owned by
/// <var>pUsername</var>, or by the caller when it is empty, carrying work-queue token
/// <var>pToken</var>. Nothing queues it, so a non-empty token names no queue.</p>
ClassMethod SeedTaskRow(pGuid As %String, pTaskName As %String, pState As %String, pQueued As %String, pUsername As %String = "", pToken As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        Set tRow = $ClassMethod(..#ASYNCTASKCLASS, "%New")
        Set tRow.GUID = pGuid
        Set tRow.TaskName = pTaskName
        Set tRow.State = pState
        Set tRow.Username = $Select(pUsername = "": $Username, 1: pUsername)
        Set tRow.TimeQueued = pQueued
        Set tRow.WQMToken = pToken
        Set tSC = tRow.%Save()
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the vendor's async task table holds a row with GUID <var>pGuid</var>.</p>
ClassMethod TaskRowExists(pGuid As %String) As %Boolean
{
    Quit ''$ClassMethod(..#ASYNCTASKCLASS, "%ExistsId", pGuid)
}

/// <p>Delete the async task row with GUID <var>pGuid</var>, if there is one.</p>
ClassMethod RemoveTaskRow(pGuid As %String) As %Status
{
    If '..TaskRowExists(pGuid) Quit $$$OK
    Quit $ClassMethod(..#ASYNCTASKCLASS, "%DeleteId", pGuid)
}

/// <p>The GUID of every row of the vendor's async task table, as a <class>%List</class>, read in
/// <code>%SYS</code> through its own table; <code>""</code> when it cannot be read.</p>
ClassMethod TaskGuids() As %List
{
    Set tGuids = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tTable = ##class(%Dictionary.CompiledClass).%OpenId(..#ASYNCTASKCLASS).SqlQualifiedNameQ
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(GUID) AS GUID FROM " _ tTable)
        While tResult.%Next() {
            Set tGuids = tGuids _ $ListBuild(tResult.%Get("GUID"))
        }
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tGuids = ""
    }
    Quit tGuids
}

/// <p>Whether any node of the vendor async task class's data or stream global carries
/// <var>pText</var>, read in <code>%SYS</code>. The text is only searched for, never written.</p>
ClassMethod TaskGlobalsCarry(pText As %String) As %Boolean
{
    Set tCarries = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tStorage = ##class(%Dictionary.CompiledStorage).%OpenId(..#ASYNCTASKCLASS _ "||Default")
        Set tGlobals = $ListBuild(tStorage.DataLocation, tStorage.StreamLocation)
        Set tStorage = ""
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tGlobals) {
            Set tNode = $List(tGlobals, tI)
            If tNode = "" Continue
            If ($Data(@tNode) # 2) && ($Get(@tNode) [ pText) Set tCarries = 1
            For {
                Set tNode = $Query(@tNode)
                If (tNode = "") || tCarries Quit
                If $Get(@tNode) [ pText Set tCarries = 1
            }
            If tCarries Quit
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCarries = 1
    }
    Quit tCarries
}

}
