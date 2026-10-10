/// <p>Pins the Background tasks port's call to the vendor's background task (AD-16, AD-27, AD-53) with
/// the shipped <method>OcuPilot.Port.BackgroundTaskPort.Control</method> and
/// <method>OcuPilot.Port.BackgroundTaskPort.PortalControl</method> running against
/// <class>OcuPilot.Test.BackgroundTaskFake</class> through
/// <class>OcuPilot.Test.BackgroundTaskPortOnFake</class>: Pause, Resume and Cancel of a portal row
/// each answer 200 and call the fake's matching method once, on the row's background task; a vendor
/// state error is the published <code>TASK.BACKGROUND.STATE</code> at 409; any other vendor error is
/// the internal fault at 500; and a background task that no longer opens is the state refusal with
/// nothing sent. It holds the 200 legs that <class>OcuPilot.Test.BackgroundTasksLive</class> cannot
/// hold against a real compact, which can end before its Pause reaches it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, a caller holding the port's two
/// pairs (<code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>), and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the port opens the vendor's
/// class in <code>%SYS</code>, which sees the <parameter>PACKAGE</parameter> package that holds the
/// fake only while this class maps it there. The class maps it before its first test and removes the
/// mapping after its last.</p>
Class OcuPilot.Test.BackgroundTaskPortSeam Extends %UnitTest.TestCase
{

/// <p>The variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PORT = "OcuPilot.Test.BackgroundTaskPortOnFake";

Parameter FAKE = "OcuPilot.Test.BackgroundTaskFake";

/// <p>The package the fake lives in, mapped into <code>%SYS</code> for this class's run.</p>
Parameter PACKAGE = "OcuPilot.Test";

/// <p>The armed portal row's job number and its background task id.</p>
Parameter JOB = "4242";

Parameter TASKID = "7";

/// <p>The sentence <code>TASK.BACKGROUND.STATE</code> is published with in EXPERIENCE.md's Fixed
/// strings.</p>
Parameter PUBLISHED = "This background task's current state does not allow that.";

/// <p>Whether this class's run created the <code>%SYS</code> mapping its teardown removes.</p>
Property PreparedMapping As %Boolean;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedMapping = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.BackgroundTaskPortSeam maps the " _ ..#PACKAGE _ " package into %SYS on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was mapped. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ..MapPackage()
}

/// <p>Remove the mapping this run created; a failing status when it survives.</p>
Method OnAfterAllTests() As %Status
{
    Quit ..UnmapPackage()
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FAKE, "Clear")
    Do $ClassMethod(..#PORT, "Clear")
    Do $ClassMethod(..#FAKE, "Arm", ..#TASKID)
    Do $ClassMethod(..#PORT, "ArmRow", ..#JOB, ..#TASKID)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#FAKE, "Clear")
    Do $ClassMethod(..#PORT, "Clear")
    Quit $$$OK
}

/// <p>AD-27, AD-53: Pause, Resume and Cancel of a portal row each answer 200 with an empty object
/// and no fault, and call the fake's matching method once, on the row's background task and on no
/// other method.</p>
/// <p>Mutation (Rule 19): skip the vendor call in
/// <method>OcuPilot.Port.BackgroundTaskPort.PortalControl</method> -- each "called once" leg goes red;
/// make the fake's <method>OcuPilot.Test.BackgroundTaskFake.Pause</method> answer an error that
/// <method>Arm</method> never armed -- the Pause leg answers 500 and goes red; make
/// <method>OcuPilot.Port.BackgroundTaskPort.PortalControl</method> send every control as a Pause --
/// the Resume and Cancel legs go red.</p>
Method TestPauseResumeAndCancelEachReachTheVendorOnce()
{
    For tType = "PAUSE", "RESUME", "CANCEL" {
        Do $ClassMethod(..#FAKE, "Clear")
        Do $ClassMethod(..#FAKE, "Arm", ..#TASKID)
        Do ..Control(tType, .tHttp, .tResult, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tResult): tResult.%ToJSON(), 1: "") _ " " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""), "200 {} ", tType _ " answers 200 with an empty object and no fault")
        Do $$$AssertEquals($ClassMethod(..#FAKE, "Calls"), $Case(tType, "PAUSE": "Pause", "RESUME": "Resume", "CANCEL": "Cancel") _ " " _ ..#TASKID, tType _ " called the vendor's matching method once, on the row's background task")
    }
}

/// <p>AD-27: each vendor error in
/// <parameter>OcuPilot.Port.BackgroundTaskPort.PORTALSTATECODES</parameter> is the published 409
/// <code>TASK.BACKGROUND.STATE</code> after one vendor call, and a vendor error outside it is the
/// internal fault at 500.</p>
/// <p>Mutation (Rule 19): drop 9503 from
/// <parameter>OcuPilot.Port.BackgroundTaskPort.PORTALSTATECODES</parameter> -- the 9503 leg answers
/// 500 and goes red.</p>
Method TestAVendorStateErrorIsThePublishedRefusal()
{
    For tCode = 9502, 9503, 9505 {
        Do $ClassMethod(..#FAKE, "Clear")
        Do $ClassMethod(..#FAKE, "Arm", ..#TASKID)
        Do $ClassMethod(..#FAKE, "ArmAnswer", tCode)
        Do ..Control("PAUSE", .tHttp, .tResult, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "409 " _ ##class(OcuPilot.Api.Error).#TASKBACKGROUNDSTATE _ " " _ ..#PUBLISHED, "the vendor's " _ tCode _ " is the published state refusal")
        Do $$$AssertEquals($ClassMethod(..#FAKE, "Calls"), "Pause " _ ..#TASKID, "after one vendor call (" _ tCode _ ")")
    }
    Do $ClassMethod(..#FAKE, "Clear")
    Do $ClassMethod(..#FAKE, "Arm", ..#TASKID)
    Do $ClassMethod(..#FAKE, "ArmAnswer", 9509)
    Do ..Control("PAUSE", .tHttp, .tResult, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "while any other vendor error is the internal fault")
}

/// <p>AD-27: a background task that no longer opens is the published 409 refusal, and no control is
/// sent.</p>
/// <p>Mutation (Rule 19): drop the absent test from
/// <method>OcuPilot.Port.BackgroundTaskPort.Control</method> -- the port asks the missing task and
/// answers 200, and this goes red.</p>
Method TestATaskThatNoLongerOpensIsTheStateRefusal()
{
    Do $ClassMethod(..#FAKE, "Clear")
    Do ..Control("RESUME", .tHttp, .tResult, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "409 " _ ##class(OcuPilot.Api.Error).#TASKBACKGROUNDSTATE _ " " _ ..#PUBLISHED, "the state refusal")
    Do $$$AssertEquals($ClassMethod(..#FAKE, "Calls"), "", "with no control sent")
}

/// <p>One control of type <var>pType</var> on the armed portal row, through the port.</p>
Method Control(pType As %String, Output pHttpStatus As %Integer, Output pResult, Output pFault)
{
    Kill tQuery
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Management Portal", ..#JOB))
    Do $ClassMethod(..#PORT, "Invoke", "BackgroundTask", pType, .tQuery, "", .pResult, .pHttpStatus, .pFault)
}

/// <p>Map <parameter>PACKAGE</parameter> into <code>%SYS</code> over the code database of the
/// current namespace, replacing a mapping an earlier run left.</p>
Method MapPackage() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tCodeDatabase = ""
        Set $NAMESPACE = "%SYS"
        Set tNamespace = ##class(Config.Namespaces).Open(tOrigNS)
        If $IsObject(tNamespace) Set tCodeDatabase = tNamespace.Routines
        If tCodeDatabase = "" {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ERROR($$$GeneralError, "the code database of " _ tOrigNS _ " could not be read")
            Quit
        }
        If ##class(Config.MapPackages).Exists("%SYS", ..#PACKAGE) {
            Set tSC = ##class(Config.MapPackages).Delete("%SYS", ..#PACKAGE)
            If $$$ISERR(tSC) {
                Set $NAMESPACE = tOrigNS
                Quit
            }
        }
        Kill tProps
        Set tProps("Database") = tCodeDatabase
        Set tSC = ##class(Config.MapPackages).Create("%SYS", ..#PACKAGE, .tProps)
        If $$$ISOK(tSC) Set ..PreparedMapping = 1
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove the mapping <method>MapPackage</method> made; a failing status when it survives.</p>
Method UnmapPackage() As %Status
{
    Set tSC = $$$OK
    If '..PreparedMapping Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Config.MapPackages).Exists("%SYS", ..#PACKAGE) {
            Set tSC = ##class(Config.MapPackages).Delete("%SYS", ..#PACKAGE)
        }
        If $$$ISOK(tSC) && ##class(Config.MapPackages).Exists("%SYS", ..#PACKAGE) {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.BackgroundTaskPortSeam left the " _ ..#PACKAGE _ " mapping in %SYS")
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISOK(tSC) Set ..PreparedMapping = 0
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
