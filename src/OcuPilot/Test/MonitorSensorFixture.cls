/// <p>Stands in for <code>SYS.Monitor.SAM.Sensors</code> behind
/// <class>OcuPilot.Test.MonitorPortFixture</class>. <method>Alerts</method> answers whatever a test
/// armed -- a status on <code>%response</code>, a body, a next-cursor header, and optionally a
/// thrown exception or a <code>&lt;MAXSTRING&gt;</code> -- which is how the outcomes the live
/// instance cannot produce on demand are driven.</p>
/// <p>Every entry is counted and the tag it was given recorded, so a test reads "no vendor code ran"
/// off a counter and "tag mode was used" off the recorded request. State lives in
/// <code>^||OcuPilotMonitorSensor</code>; <method>Clear</method> forgets it.</p>
Class OcuPilot.Test.MonitorSensorFixture Extends %RegisteredObject
{

/// <p>Text shaped like the vendor's own error, which the port must log and never put on the
/// wire.</p>
Parameter VENDORTEXT = "ERROR #5001: alerts.log could not be opened";

/// <p>Arm the next call to set <code>%response.Status</code> to <var>pStatus</var>, write
/// <var>pTag</var> to the cursor header and answer <var>pBody</var>. <var>pMode</var>
/// <code>throw</code> raises an ordinary exception instead of answering, <code>maxstring</code>
/// raises <code>&lt;MAXSTRING&gt;</code>, and <code>write</code> also writes
/// <parameter>VENDORTEXT</parameter> to the device as the vendor's error body.</p>
ClassMethod Arm(pStatus As %String, pBody As %String = "", pTag As %String = "", pMode As %String = "")
{
    Set ^||OcuPilotMonitorSensor("arm") = $ListBuild(pStatus, pBody, pTag, pMode)
}

/// <p>Forget every armed answer and every recorded entry.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotMonitorSensor
}

/// <p>How many times <method>Alerts</method> was entered since <method>Clear</method>. This is
/// AC1's witness: a refused call must leave it at zero.</p>
ClassMethod EntryCount() As %Integer
{
    Quit +$Get(^||OcuPilotMonitorSensor("entries"), 0)
}

/// <p>Whether entry <var>pAt</var> found <code>%request.Data("tag",1)</code> defined -- tag mode
/// (AD-7). A call that did not set it is the no-tag path, which advances the instance-wide
/// cursor.</p>
ClassMethod TaggedAt(pAt As %Integer) As %Boolean
{
    Quit ''$Get(^||OcuPilotMonitorSensor("tagged", pAt), 0)
}

/// <p>The tag entry <var>pAt</var> was given, or <code>""</code>.</p>
ClassMethod TagAt(pAt As %Integer) As %String
{
    Quit $Get(^||OcuPilotMonitorSensor("tag", pAt), "")
}

/// <p>The vendor method the port dispatches to, with the vendor's own name and signature.</p>
ClassMethod Alerts() As %String
{
    Set tAt = +$Get(^||OcuPilotMonitorSensor("entries"), 0) + 1
    Set ^||OcuPilotMonitorSensor("entries") = tAt
    Set ^||OcuPilotMonitorSensor("tagged", tAt) = ''$Data(%request.Data("tag", 1))
    Set ^||OcuPilotMonitorSensor("tag", tAt) = $Get(%request.Data("tag", 1), "")

    Set tArm = $Get(^||OcuPilotMonitorSensor("arm"))
    If tArm = "" {
        Set %response.Status = "500 Internal Server Error"
        Quit ""
    }
    Set tStatus = $List(tArm, 1)
    Set tBody = $List(tArm, 2)
    Set tTag = $List(tArm, 3)
    Set tMode = $List(tArm, 4)
    Set %response.Status = tStatus
    If tTag '= "" Set %response.Headers(##class(OcuPilot.Port.MonitorPort).#TAGHEADER) = tTag
    ; The vendor writes its own error body to the device. `%ToJSON` with no argument writes to
    ; the current device, which is what the port's capture must pick up -- and it is how
    ; OcuPilot.Test.MgmntImplFixture stands in for the same behaviour without a bare Write.
    If tMode = "write" {
        Set tVendorBody = {"msg": (..#VENDORTEXT)}
        Do tVendorBody.%ToJSON()
    }
    If tMode = "throw" Throw ##class(%Exception.General).%New("the sensor failed", 5001, , "")
    If tMode = "maxstring" Throw ##class(%Exception.SystemException).%New("<MAXSTRING>", 0, , "")
    Quit tBody
}

}
