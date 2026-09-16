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
/// the device as the vendor's error body.</p>
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
    If tMode = "write" {
        Set tBody = {"msg": (..#VENDORTEXT)}
        Do tBody.%ToJSON()
    }
    Set tJson = $ListGet(tArm, 2)
    If tJson = "" Quit ""
    Quit ##class(%DynamicAbstractObject).%FromJSON(tJson)
}

}
