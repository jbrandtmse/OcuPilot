/// <p>Test-only subclass of <class>OcuPilot.Install.Smoke</class> whose screen reads answer what
/// <method>Arm</method> set, without issuing the request. <class>OcuPilot.Test.Smoke</class> uses it
/// to drive <method>OcuPilot.Install.Smoke.CheckAreaLists</method> through a 200 whose body is not a
/// one-row <code>rows</code> array. Every other request goes to the instance unchanged.</p>
/// <p>It also records every screen-read path it is asked for, in order
/// (<method>ClearPaths</method> / <method>Paths</method>), which is how a caller checks <b>which</b>
/// screen each named check read: a report line carries the check's name and its outcome, never the
/// tool behind it, so two checks whose tool identifiers are transposed both still pass.</p>
Class OcuPilot.Test.SmokeListFault Extends OcuPilot.Install.Smoke
{

/// <p>Arm the screen-read answer for this process: <var>pStatus</var> and <var>pBody</var>.</p>
ClassMethod Arm(pStatus As %Integer, pBody As %String = "")
{
    Kill ^||OcuPilotSmokeList
    Set ^||OcuPilotSmokeList("status") = pStatus
    Set ^||OcuPilotSmokeList("body") = pBody
}

/// <p>Remove the armed answer.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotSmokeList
}

/// <p>Forget every recorded screen-read path. Recording is unconditional, so a caller that reads
/// <method>Paths</method> clears first.</p>
ClassMethod ClearPaths()
{
    Kill ^||OcuPilotSmokePath
}

/// <p>The screen-read paths this process has been asked for since <method>ClearPaths</method>, in
/// the order they were issued.</p>
ClassMethod Paths() As %List
{
    Set tPaths = ""
    Set tIndex = ""
    For {
        Set tIndex = $Order(^||OcuPilotSmokePath(tIndex))
        Quit:tIndex=""
        Set tPaths = tPaths _ $ListBuild(^||OcuPilotSmokePath(tIndex))
    }
    Quit tPaths
}

/// <p>Arm the console-log page's answer for this process: <var>pStatus</var> and <var>pBody</var>.
/// Separate from <method>Arm</method> because that check reads no screen and the two are driven
/// in the same run.</p>
ClassMethod ArmLog(pStatus As %Integer, pBody As %String = "")
{
    Kill ^||OcuPilotSmokeLog
    Set ^||OcuPilotSmokeLog("status") = pStatus
    Set ^||OcuPilotSmokeLog("body") = pBody
}

/// <p>Remove the armed console-log answer.</p>
ClassMethod DisarmLog()
{
    Kill ^||OcuPilotSmokeLog
}

/// <p>Arm the application error log's answer for this process: <var>pStatus</var> and
/// <var>pBody</var>. Separate from <method>ArmLog</method> because the two checks read different
/// endpoints and are driven in the same run -- one arming for both would make each test's red a
/// statement about both checks.</p>
ClassMethod ArmErrors(pStatus As %Integer, pBody As %String = "")
{
    Kill ^||OcuPilotSmokeErrors
    Set ^||OcuPilotSmokeErrors("status") = pStatus
    Set ^||OcuPilotSmokeErrors("body") = pBody
}

/// <p>Remove the armed application error log answer.</p>
ClassMethod DisarmErrors()
{
    Kill ^||OcuPilotSmokeErrors
}

ClassMethod Request(pMethod As %String, pPath As %String, pAuthorization As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String) As %Status [ Private ]
{
    If pPath [ "/screens/" {
        Set ^||OcuPilotSmokePath($Increment(^||OcuPilotSmokePath)) = pPath
    }
    If $Data(^||OcuPilotSmokeList("status")) && (pPath [ "/screens/") {
        Set pStatus = ^||OcuPilotSmokeList("status")
        Set pText = ^||OcuPilotSmokeList("body")
        Quit $$$OK
    }
    ; The errors arm is tested first and matches the narrower path, so the console-log arm cannot
    ; swallow it: the two checks read different endpoints under one prefix.
    If $Data(^||OcuPilotSmokeErrors("status")) && (pPath [ "/logs/errors/") {
        Set pStatus = ^||OcuPilotSmokeErrors("status")
        Set pText = ^||OcuPilotSmokeErrors("body")
        Quit $$$OK
    }
    If $Data(^||OcuPilotSmokeLog("status")) && (pPath [ "/logs/messages") {
        Set pStatus = ^||OcuPilotSmokeLog("status")
        Set pText = ^||OcuPilotSmokeLog("body")
        Quit $$$OK
    }
    Quit ##super(pMethod, pPath, pAuthorization, pBody, .pStatus, .pText)
}

}
