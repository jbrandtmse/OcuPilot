/// <p>Pins <class>OcuPilot.Port.HarvestPort</class> in a real CSP job, over HTTP, which the
/// in-process <class>OcuPilot.Test.Harvest</class> cannot: the port's output capture and
/// <code>New</code>ed stubs against the gateway's real device and <code>%response</code>, the
/// restoring of <code>$NAMESPACE</code> as the route sees it, and the real request's query and body
/// reaching a harvested body. <class>OcuPilot.Test.HarvestWireFixture</class> is the dispatch class.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because it creates and deletes the web application <parameter>APP</parameter>,
/// and an account holding <code>%All</code>.</p>
Class OcuPilot.Test.HarvestWire Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The probe web application's path.</p>
Parameter APP = "/csp/ocuharvestwire";

/// <p>The namespace the application serves, which the route must still be in after the port returns.</p>
Property AppNamespace As %String;

/// <p>The last <method>Call</method>'s HTTP status.</p>
Property LastStatus As %Integer;

/// <p>The last <method>Call</method>'s unparsed body.</p>
Property LastRaw As %String;

/// <p>The last <method>Call</method>'s <code>X-Harvest-Namespace</code> header.</p>
Property LastNamespace As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..AppNamespace = ""
    Set ..LastStatus = 0
    Set ..LastRaw = ""
    Set ..LastNamespace = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.HarvestWire creates and deletes a web application on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Do ..RemoveApp()
    Set ..AppNamespace = $NAMESPACE
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProps("NameSpace") = ..AppNamespace
        Set tProps("Enabled") = 1
        Set tProps("AutheEnabled") = 32
        Set tProps("DispatchClass") = "OcuPilot.Test.HarvestWireFixture"
        Set tProps("Description") = "OcuPilot harvest port wire probe"
        Set tSC = ##class(Security.Applications).Create(..#APP, .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    If $$$ISERR(tSC) Do ..RemoveApp()
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Do ..RemoveApp()
    Set tOrigNS = $NAMESPACE
    Set tLeft = 0
    Try {
        Set $NAMESPACE = "%SYS"
        Set tLeft = ##class(Security.Applications).Exists(..#APP)
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
    Quit $Select(tLeft: $$$ERROR($$$GeneralError, "the probe web application survived: " _ ..#APP), 1: $$$OK)
}

/// <p>Delete the probe web application where it exists.</p>
Method RemoveApp()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(..#APP) Do ##class(Security.Applications).Delete(..#APP)
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>Send <var>pMethod</var> to the route with <var>pCase</var> (and <var>pK</var> when set) as the
/// test account, keep status, raw body and namespace header, and answer the parsed body, or
/// <code>""</code> when it does not parse as one object.</p>
Method Call(pMethod As %String, pCase As %String, pK As %String = "", pBody As %String = "") As %DynamicObject
{
    Set tPath = ..#APP _ "/run?case=" _ $ZConvert(pCase, "O", "URL") _ $Select(pK = "": "", 1: "&k=" _ $ZConvert(pK, "O", "URL"))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, pBody, $Select(pBody = "": "", 1: "application/json"))
    Do $$$AssertStatusOK(tSC, pCase _ ": the request was sent")
    Set ..LastStatus = tStatus
    Set ..LastRaw = tRaw
    Set ..LastNamespace = $Get(tHeaders("X-HARVEST-NAMESPACE"))
    Do $$$AssertEquals((tRaw [ "}{"), 0, pCase _ ": no }{ concatenation in the body")
    Set tParsed = ""
    Try {
        Set tParsed = ##class(%DynamicObject).%FromJSON(tRaw)
    } Catch {
        Do $$$AssertTrue(0, pCase _ ": the body parses as one object (was: " _ $Extract(tRaw, 1, 120) _ ")")
    }
    Quit tParsed
}

Method TestSuccessAnswersTheBareResultOverHttp()
{
    Set tBody = ..Call("GET", "Success")
    Do $$$AssertEquals(..LastStatus, 200, "HTTP 200")
    Do $$$AssertTrue($IsObject(tBody), "one object")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.%ToJSON(), "{""a"":1}", "the bare result, with no status, console or result wrapper")
    Do $$$AssertEquals(..LastNamespace, ..AppNamespace, "the route is back in the application's namespace")
}

Method TestDeviceOutputNeverReachesTheWire()
{
    Set tBody = ..Call("GET", "Chatter")
    Do $$$AssertEquals(..LastStatus, 200, "HTTP 200")
    Do $$$AssertTrue($IsObject(tBody), "one object")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.chatter, 1, "the result, with the body's device output discarded")
}

Method TestTwoRendersAreOneInternalFaultOverHttp()
{
    Set tBody = ..Call("GET", "Twice")
    Do $$$AssertEquals(..LastStatus, 500, "HTTP 500")
    Do $$$AssertTrue($IsObject(tBody), "one object")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.code, ##class(OcuPilot.Api.Error).#INTERNAL, "the INTERNAL fault, not either render")
}

Method TestVendorTextNeverReachesTheWireOverHttp()
{
    Set tBody = ..Call("GET", "Failure")
    Do $$$AssertEquals(..LastStatus, 500, "HTTP 500")
    Do $$$AssertTrue($IsObject(tBody), "one object")
    Do $$$AssertTrue(..LastRaw '[ "vendor text X", "the vendor text is absent from the body")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.code, ##class(OcuPilot.Api.Error).#INTERNAL, "the INTERNAL fault")
    Do $$$AssertEquals(tBody.reason, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, "the generic reason")
}

Method TestStrandedNamespaceIsRestoredOverHttp()
{
    Set tBody = ..Call("GET", "Strand")
    Do $$$AssertEquals(..LastStatus, 200, "HTTP 200")
    Do $$$AssertEquals(..LastNamespace, ..AppNamespace, "a body that returned in %SYS leaves the route in the application's namespace")
    Set tBody = ..Call("GET", "Raise")
    Do $$$AssertEquals(..LastStatus, 500, "an exception: HTTP 500")
    Do $$$AssertEquals(..LastNamespace, ..AppNamespace, "an exception leaves the route in the application's namespace")
}

Method TestRealRequestQueryAndBodyReachTheBody()
{
    Set tBody = ..Call("POST", "Echo", "v", "{""x"":1}")
    Do $$$AssertEquals(..LastStatus, 200, "HTTP 200 with a body")
    Do $$$AssertTrue($IsObject(tBody), "one object")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.k, "v", "the query parameter")
    Do $$$AssertEquals(tBody.body.x, 1, "the JSON body")
    Do $$$AssertEquals(tBody.method, "POST", "a body makes the method POST")
    Set tBody = ..Call("GET", "Echo", "w")
    Do $$$AssertEquals(tBody.method, "GET", "no body makes the method GET")
    Do $$$AssertEquals(tBody.%IsDefined("body"), 0, "and no body is read")
}

Method TestVerbatimTaskListRunsInARealJob()
{
    Set tBody = ..Call("GET", "TaskList")
    Do $$$AssertEquals(..LastStatus, 200, "HTTP 200")
    Do $$$AssertTrue($IsObject(tBody), "one object")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.count, tBody.tasks.%Size(), "count is the size of tasks")
    Do $$$AssertEquals(tBody.%IsDefined("status") + tBody.%IsDefined("console") + tBody.%IsDefined("result"), 0, "no vendor envelope")
}

}
