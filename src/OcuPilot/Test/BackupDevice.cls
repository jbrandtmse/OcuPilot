/// <p>Pins what a backup action leaves of the web process's devices: the freeze and thaw call <code>SuspendCall</code>, which switches to
/// the null device for the vendor's call. A process that held the null device before still holds it, so the vendor's compile routes that
/// <code>Use</code> it without opening it keep working; a process that did not hold it does not hold it afterwards; and the caller's current
/// device and output redirection are the same on a good status, an error status and a raise. The shared check
/// <method>OcuPilot.Kernel.Utils.DeviceIsOpen</method> is pinned beside it.</p>
/// <p>The vendor call is replaced by <class>OcuPilot.Test.BackupDeviceSeam</class>, so nothing is frozen. The test puts its own process's null device back as
/// it found it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot compiled; no principal, web application or install state.</p>
Class OcuPilot.Test.BackupDevice Extends %UnitTest.TestCase
{

Parameter SEAM = "OcuPilot.Test.BackupDeviceSeam";

/// <p>What a bare <code>Use</code> of <var>pDevice</var>, as the vendor's compile routes issue it, raises in this process
/// (<code>&lt;NOTOPEN&gt;</code> for a device it has not opened), or <code>""</code> when it succeeds, with the device's redirection switch in
/// <var>pRedirected</var>; the current device is the same after the call.</p>
ClassMethod UseWithoutOpening(pDevice As %String, Output pRedirected As %String) As %String
{
    Set tIO = $IO
    Set (tRaised, pRedirected) = ""
    Try {
        Use pDevice
        Set pRedirected = ##class(%Library.Device).ReDirectIO()
    } Catch ex {
        Set tRaised = ex.Name
    }
    If tRaised = "" Use tIO
    Quit tRaised
}

/// <p>Close the process's null device if it holds it.</p>
ClassMethod CloseNull(pNull As %String)
{
    If ..UseWithoutOpening(pNull) = "" Close pNull
}

/// <p>Whether <method>OcuPilot.Kernel.Utils.DeviceIsOpen</method> answers from what the process holds: no for a null device it has not
/// opened, yes once it has, and the current device is the same after either answer.</p>
/// <p>Mutation (Rule 19): <method>DeviceIsOpen</method> answers 1 whatever the process holds -> the closed leg goes red; answers 0 -> the open
/// leg goes red.</p>
Method TestDeviceIsOpenAnswersFromWhatTheProcessHolds()
{
    Set tNull = ##class(%Library.Device).GetNullDevice()
    Set tIO = $IO
    Set tWasOpen = (..UseWithoutOpening(tNull) = "")
    Try {
        Do ..CloseNull(tNull)
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Utils).DeviceIsOpen(tNull), 0, "a null device the process has not opened is not open")
        Do $$$AssertEquals($IO, tIO, "and the current device is the same")
        Open tNull::1
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Utils).DeviceIsOpen(tNull), 1, "a null device the process has opened is open")
        Do $$$AssertEquals($IO, tIO, "and the current device is the same")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the legs ran to the end")
    }
    Do ..CloseNull(tNull)
    If $IO '= tIO Use tIO
    If tWasOpen Open tNull::1
}

/// <p>The null device and the current device after <method>OcuPilot.Test.BackupDeviceSeam.Suspend</method> of a freeze and of a thaw, with the null
/// device held before and not held before, for each answer the vendor call gives (a good status, an error status, a raise): a held device
/// is still held and a device not held is not held, the vendor call ran with the null device current, the caller's device is current
/// again and its output redirection is as it was, and the status is the vendor's own.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.BackupPort.SuspendCall</method> opens the null device whether or not <code>DeviceIsOpen</code> says the
/// process holds it, closing it afterwards -> every held leg goes red; closes the null device whether or not it opened it -> every held leg
/// goes red; leaves the caller's device unrestored -> every leg's current-device assertion goes red.</p>
Method TestSuspendLeavesTheNullDeviceAsItFoundIt()
{
    Set tNull = ##class(%Library.Device).GetNullDevice()
    Set tIO = $IO
    Set tRedirectedBefore = ##class(%Library.Device).ReDirectIO()
    Set tWasOpen = (..UseWithoutOpening(tNull) = "")
    Try {
        For tType = "FREEZE", "THAW" {
            For tHeld = 0, 1 {
                For tMode = "ok", "status", "raise" {
                    Set tLeg = tType _ "/" _ $Select(tHeld: "held", 1: "not held") _ "/" _ tMode
                    Do ..CloseNull(tNull)
                    If tHeld Open tNull::1
                    Do $ClassMethod(..#SEAM, "Mode", tMode)
                    Set tSC = $ClassMethod(..#SEAM, "Suspend", tType)
                    Do $$$AssertEquals($IO, tIO, tLeg _ ": the caller's device is current again")
                    Do $$$AssertEquals(##class(%Library.Device).ReDirectIO(), tRedirectedBefore, tLeg _ ": its output redirection is as it was")
                    Do $$$AssertEquals(..UseWithoutOpening(tNull, .tRedirected) _ "|" _ tRedirected, $Select(tHeld: "|0", 1: "<NOTOPEN>|"), tLeg _ ": the null device is left " _ $Select(tHeld: "open", 1: "closed"))
                    Do $$$AssertEquals($Piece($ClassMethod(..#SEAM, "Seen"), ":", 1), tNull, tLeg _ ": the vendor call ran with the null device current")
                    Do $$$AssertEquals($$$ISOK(tSC), (tMode = "ok"), tLeg _ ": the status is the vendor's own")
                }
            }
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the legs ran to the end")
    }
    Do ..CloseNull(tNull)
    If $IO '= tIO Use tIO
    If tWasOpen Open tNull::1
    Do $ClassMethod(..#SEAM, "Mode", "ok")
}

/// <p>A caller already writing to the null device keeps it: the device is still open and still current after a suspend, whatever the vendor call
/// answers.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.BackupPort.SuspendCall</method> closes the null device whether or not it opened it -> the device is no
/// longer open and both legs go red.</p>
Method TestSuspendKeepsACallersNullDevice()
{
    Set tNull = ##class(%Library.Device).GetNullDevice()
    Set tIO = $IO
    Set tWasOpen = (..UseWithoutOpening(tNull) = "")
    Try {
        For tMode = "ok", "raise" {
            Do ..CloseNull(tNull)
            Open tNull::1
            Use tNull
            Do $ClassMethod(..#SEAM, "Mode", tMode)
            Set tSC = $ClassMethod(..#SEAM, "Suspend", "THAW")
            Set tCurrent = $IO
            Use tIO
            Do $$$AssertEquals($Piece(tCurrent, ":", 1), tNull, tMode _ ": the null device is still the current device")
            Do $$$AssertEquals(..UseWithoutOpening(tNull), "", tMode _ ": and still open")
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the legs ran to the end")
    }
    If $IO '= tIO Use tIO
    Do ..CloseNull(tNull)
    If tWasOpen Open tNull::1
    Do $ClassMethod(..#SEAM, "Mode", "ok")
}

}
