/// <p>DW-213: <method>OcuPilot.Install.Fixture.Create</method> binds every demo fixture it
/// creates to the namespace its caller names, not to the namespace the caller stands in.
/// Calls <code>Create("probe", ..., "USER")</code> from the install namespace and reads each
/// binding back from the instance.</p>
/// <p>Needs the production profile installed (the fixture inventory lives in its protected
/// database), a <code>USER</code> namespace and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>. Creates and removes the <code>"probe"</code>
/// fixtures, and deletes the one application-error entry it seeded in <code>USER</code>.</p>
Class OcuPilot.Test.FixtureNamespace Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone: the demo fixture creates and removes a TLS configuration, an X.509 credential and a
/// wallet collection on this instance.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SSL_CONFIG";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.FixtureNamespace creates and removes the demo fixture's objects on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>The namespace the fixtures are bound to: not the one this suite runs in.</p>
Parameter TARGETNAMESPACE = "USER";

/// <p>The application-error entry this test seeded, for teardown. Prefix deliberately not
/// "Test" (<file>.claude/rules/objectscript-testing.md</file>).</p>
Property SeededErrorEntryId As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..SeededErrorEntryId = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Kill tReports
    Quit ##class(OcuPilot.Install.Fixture).Remove("probe", .tReports)
}

Method OnAfterOneTest() As %Status
{
    Kill tReports
    Set tSC = ##class(OcuPilot.Install.Fixture).Remove("probe", .tReports)
    If ..SeededErrorEntryId '= "" {
        Set tOrigNS = $NAMESPACE
        Try {
            Set $NAMESPACE = "%SYS"
            Do ##class(SYS.ApplicationError).DeleteByError(..#TARGETNAMESPACE, $ZDate($Piece(..SeededErrorEntryId, ",", 1), 1), $Piece(..SeededErrorEntryId, ",", 2))
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
    }
    Quit tSC
}

/// <p>Mutation (Rule 19): make <method>OcuPilot.Install.Fixture.Create</method> ignore
/// <var>pNamespace</var> (<code>Set tInstallNs = tOrigNS</code>) -- every binding reads the
/// install namespace and red.</p>
Method TestCreateBindsEveryFixtureToTheNamedNamespace()
{
    Set tTarget = ..#TARGETNAMESPACE
    Set tStart = $NAMESPACE
    Do $$$AssertNotEquals(tStart, tTarget, "the suite runs in a namespace other than " _ tTarget)
    Do $$$AssertTrue(##class(%SYS.Namespace).Exists(tTarget), tTarget _ " exists on this instance")

    Kill tReports
    Set tSC = ##class(OcuPilot.Install.Fixture).Create("probe", .tReports, .tErrorEntryId, tTarget)
    Set ..SeededErrorEntryId = tErrorEntryId
    Do $$$AssertStatusOK(tSC, "Create returns OK")
    Do $$$AssertEquals($NAMESPACE, tStart, "the caller's namespace is restored")

    ; The inventory's own record of what was created and where.
    Set tWebAppCreated = 0
    Set tTaskName = ""
    Set tIdsSC = ##class(OcuPilot.Kernel.State.Demo).GuardedIdsForProfile("probe", .tIds)
    Do $$$AssertStatusOK(tIdsSC, "the probe inventory reads")
    Set tN = $Order(tIds(""))
    While tN '= "" {
        Set tRowSC = ##class(OcuPilot.Kernel.State.Demo).GuardedOpenId(tIds(tN), .tRow)
        If $$$ISOK(tRowSC), $IsObject(tRow) {
            If tRow.Kind = "webapp" Set tWebAppCreated = 1
            If tRow.Kind = "task" Set tTaskName = tRow.Name
            If (tRow.Kind = "task") || (tRow.Kind = "errorentry") {
                Do $$$AssertEquals(tRow.Scope, tTarget, "the " _ tRow.Kind _ " inventory row is scoped to " _ tTarget)
            }
        }
        Set tN = $Order(tIds(tN))
    }
    Do $$$AssertTrue(tErrorEntryId '= "", "Create seeded and confirmed an application-error entry")

    ; The task fixture's class is compiled only where OcuPilot is installed, so %SYS.Task refuses
    ; a task bound to a namespace without it (ERROR #7414, naming that namespace). A task that was
    ; created must run in the target; one that was refused must have been refused for the target;
    ; and neither may land in the namespace the caller stands in.
    Set tTaskRefusedFor = ""
    Set tR = $Order(tReports(""))
    While tR '= "" {
        If tReports(tR, "message") [ "Could not create the demo task fixture" {
            Set tData = tReports(tR, "data")
            If $IsObject(tData) Set tTaskRefusedFor = tData.error
        }
        Set tR = $Order(tReports(tR))
    }
    Set tProbeTaskName = ##class(OcuPilot.Install.Fixture).ResolvedPrefix("probe") _ " nightly purge"
    Set tAppPath = ##class(OcuPilot.Install.Fixture).#APPPATH
    Set tTaskNs = ""
    Set tTaskInStart = 0
    Set tAppNs = ""
    Set tErrorFound = 0
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT NameSpace FROM %SYS.Task WHERE Name = ?", tProbeTaskName)
        While tRS.%Next() {
            If tRS.%GetData(1) = tTarget Set tTaskNs = tTarget
            If tRS.%GetData(1) = tStart Set tTaskInStart = 1
        }
        If tWebAppCreated {
            Set tGetSC = ##class(Security.Applications).Get(tAppPath, .tProps)
            If $$$ISOK(tGetSC) Set tAppNs = $Get(tProps("NameSpace"))
        }
        If tErrorEntryId '= "" {
            Set tList = ##class(%ResultSet).%New("SYS.ApplicationError:ErrorList")
            If $IsObject(tList), $$$ISOK(tList.Execute(tTarget, $ZDate($Piece(tErrorEntryId, ",", 1), 1))) {
                While tList.Next() {
                    If tList.Get("Error #") = $Piece(tErrorEntryId, ",", 2) Set tErrorFound = 1
                }
                Do tList.Close()
            }
        }
        Set $NAMESPACE = tStart
    } Catch ex {
        Set $NAMESPACE = tStart
        Do $$$AssertTrue(0, "reading the bindings back raised " _ ex.DisplayString())
    }
    If tTaskName '= "" {
        Do $$$AssertEquals(tTaskNs, tTarget, "the task fixture runs in " _ tTarget)
    } Else {
        Do $$$AssertTrue((tTaskRefusedFor [ "does not exist in") && (tTaskRefusedFor [ tTarget), "the task fixture was bound to " _ tTarget _ " and refused there: " _ tTaskRefusedFor)
    }
    Do $$$AssertTrue('tTaskInStart, "no task fixture was created in " _ tStart)
    If tWebAppCreated {
        Do $$$AssertEquals(tAppNs, tTarget, "the web application is bound to " _ tTarget)
    }
    Do $$$AssertTrue(tErrorFound, "the seeded error entry is in " _ tTarget _ "'s application error log")
}

}
