/// <p>Stands in for the management API's business-logic class behind
/// <class>OcuPilot.Test.MgmntPortFixture</class>. It answers the four methods
/// <class>OcuPilot.Port.MgmntPort</class> calls with whatever a test armed -- a status on
/// <code>%response</code>, a JSON value, and optionally a thrown exception or vendor-shaped text
/// written to the device -- which is how the 400, 403, 404 and fault rows the live instance cannot
/// produce on demand are driven.</p>
/// <p>Every call is recorded, method and arguments, so a test reads "no vendor call was made" off a
/// counter. A method nothing armed answers 500 with no value. State lives in
/// <code>^||OcuPilotMgmntImpl</code>; <method>Clear</method> forgets it.</p>
Class OcuPilot.Test.MgmntImplFixture Extends %RegisteredObject
{

/// <p>Text shaped like the vendor's own error, naming a status number and a class, which the port
/// must log and never put on the wire.</p>
Parameter VENDORTEXT = "ERROR #8753: REST application not found: %Api.Probe.v1.disp";

/// <p>Arm <var>pMethod</var> to set <code>%response.Status</code> to <var>pStatus</var> and answer
/// <var>pJson</var> parsed (<code>""</code> answers no value). <var>pMode</var> <code>throw</code>
/// raises instead of answering; <code>write</code> also writes <parameter>VENDORTEXT</parameter> to
/// the device as the vendor's error body; <code>admincall</code> writes it and then calls
/// <method>OcuPilot.Port.AdminPort.Invoke</method> from inside the caller's capture window,
/// recording what that nested call answered for <method>InnerCall</method>.</p>
ClassMethod Arm(pMethod As %String, pStatus As %String, pJson As %String = "", pMode As %String = "")
{
    Set ^||OcuPilotMgmntImpl("arm", pMethod) = $ListBuild(pStatus, pJson, pMode)
}

/// <p>Forget every armed answer and every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotMgmntImpl
}

/// <p>How many calls were made since <method>Clear</method>.</p>
ClassMethod CallCount() As %Integer
{
    Quit +$Get(^||OcuPilotMgmntImpl("calls"), 0)
}

/// <p>Call <var>pAt</var> as <code>Method(namespace,name)</code>, or <code>""</code>.</p>
ClassMethod CallAt(pAt As %Integer) As %String
{
    Set tCall = $Get(^||OcuPilotMgmntImpl("call", pAt))
    If tCall = "" Quit ""
    Quit $List(tCall, 1) _ "(" _ $List(tCall, 2) _ $Select($List(tCall, 3) = "": "", 1: "," _ $List(tCall, 3)) _ ")"
}

/// <p>Every recorded call, in order, joined by <code>|</code>.</p>
ClassMethod CallText() As %String
{
    Set tText = ""
    For tI = 1:1:..CallCount() {
        Set tText = tText _ $Select(tI = 1: "", 1: "|") _ ..CallAt(tI)
    }
    Quit tText
}

/// <p>What the <code>admincall</code> mode's nested
/// <method>OcuPilot.Port.AdminPort.Invoke</method> answered, as
/// <code>&lt;statusOK&gt;|&lt;http&gt;|&lt;code&gt;</code>, or <code>""</code> when no armed mode made
/// one.</p>
ClassMethod InnerCall() As %String
{
    Quit $Get(^||OcuPilotMgmntImpl("inner"), "")
}

/// <p>One admin-port call through <class>OcuPilot.Test.PortFixture</class>, made from wherever this
/// fixture is running -- which is inside the calling port's capture window. The caller arms the
/// endpoint fixture; this only makes the call, because where it is made from is the whole point.</p>
ClassMethod NestedAdminCall() As %String [ Private ]
{
    ; Answers a sentence rather than raising: a raise here would unwind through the calling port's
    ; open capture window, and the caller would read an empty InnerCall() with no cause named.
    Set tOut = ""
    Try {
        Set tQuery("name") = "fixture-item"
        Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("Fixture.Endpoint", "GET", .tQuery, , .tResult, .tHttp, .tFault)
        Set tOut = $System.Status.IsOK(tSC) _ "|" _ +$Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
    } Catch ex {
        Set tOut = "the nested call raised: " _ ex.DisplayString()
    }
    Quit tOut
}

ClassMethod GetWebRESTApps(pNamespace As %String) As %DynamicObject
{
    Quit ..Answer("GetWebRESTApps", pNamespace, "")
}

ClassMethod GetRESTApps(pNamespace As %String) As %DynamicObject
{
    Quit ..Answer("GetRESTApps", pNamespace, "")
}

ClassMethod GetApplication(pNamespace As %String, pName As %String) As %DynamicObject
{
    Quit ..Answer("GetApplication", pNamespace, pName)
}

ClassMethod GetWebRESTApplication(pNamespace As %String, pName As %String) As %DynamicObject
{
    Quit ..Answer("GetWebRESTApplication", pNamespace, pName)
}

/// <p>Record the call, clear <code>%session</code> as a vendor method that touched it would, then
/// answer as armed.</p>
ClassMethod Answer(pMethod As %String, pNamespace As %String, pName As %String) As %DynamicAbstractObject [ Private ]
{
    Set tCount = ..CallCount() + 1
    Set ^||OcuPilotMgmntImpl("calls") = tCount
    Set ^||OcuPilotMgmntImpl("call", tCount) = $ListBuild(pMethod, pNamespace, pName)
    Set %session = ""
    Set tArm = $Get(^||OcuPilotMgmntImpl("arm", pMethod))
    If tArm = "" {
        Set %response.Status = "500 Internal Server Error"
        Quit ""
    }
    Set %response.Status = $List(tArm, 1)
    Set tMode = $ListGet(tArm, 3)
    If tMode = "throw" Throw ##class(%Exception.General).%New("MgmntImplFixture", 5001, , ..#VENDORTEXT)
    ; One write for both modes. For admincall it comes first on purpose: a capture counts as open
    ; only once it holds output, so without it the nested call's own capture would be silently
    ; nestable and this fixture would arm a condition that is not the one under test.
    If (tMode = "write") || (tMode = "admincall") {
        Set tBody = {"msg": (..#VENDORTEXT)}
        Do tBody.%ToJSON()
    }
    If tMode = "admincall" {
        Set ^||OcuPilotMgmntImpl("inner") = ..NestedAdminCall()
    }
    Set tJson = $ListGet(tArm, 2)
    If tJson = "" Quit ""
    Quit ##class(%DynamicAbstractObject).%FromJSON(tJson)
}

}
