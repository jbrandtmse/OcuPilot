/// <p>Pins AD-10's privileged routine application arm (DW-2239, Story 18.10): a delete, a disable, or a change to
/// <code>MatchRoles</code> or <code>Roles</code> of <code>OcuPilotState</code> or <code>OcuPilotIdentity</code> is
/// refused <code>PROHIBITED.OCUPILOTROUTINEAPP</code>, and an unrelated application is not refused by the arm.</p>
/// <p>The privileged routine endpoint's legs (<class>OcuPilot.Port.AdminPort</class>) refuse the same four writes before the
/// vendor is reached, and each leg reads the application before and after the call.</p>
/// <p>Needs the throwaway's install (both applications exist and read). The endpoint legs can reach the vendor only when
/// their guard is mutated, so <code>OnBeforeOneTest</code> records both applications' stored state and
/// <code>OnAfterOneTest</code> puts back any of it that changed. Each leg's mutation is named in the spec's Verification.</p>
Class OcuPilot.Test.OwnRoutineApplication Extends %UnitTest.TestCase
{

/// <p>The probe application the unrelated leg asks about; it is absent, so the set answers not prohibited.</p>
Parameter PROBEPATH = "/csp/ocuprobe1810";

/// <p>The sentence the arm answers, as the published text states it.</p>
Parameter REASON = "OcuPilot reads its own protected state through this privileged routine application, so it cannot be deleted or disabled and the roles it grants cannot be changed.";

/// <p>The stored state of both applications before the test, keyed by application name and then by field.</p>
Property PreparedApps [ MultiDimensional ];

/// <p>Records the stored state of both routine applications, so the after-test can put back what a mutated guard let through.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ..PreparedApps
    For tName = ##class(OcuPilot.Kernel.State.Base).#APPLICATION, ##class(OcuPilot.Kernel.State.Base).#IDENTITYAPPLICATION {
        Set tSC = ..Stored(tName, .tProps)
        If $$$ISERR(tSC) Quit
        Merge ..PreparedApps(tName) = tProps
    }
    Quit tSC
}

/// <p>Puts back the stored state of each routine application whose enabled flag or roles differ from the record. An
/// application the instance no longer holds is created again from the record.</p>
Method OnAfterOneTest() As %Status
{
    For tName = ##class(OcuPilot.Kernel.State.Base).#APPLICATION, ##class(OcuPilot.Kernel.State.Base).#IDENTITYAPPLICATION {
        Set tSC = ..Stored(tName, .tNow)
        If $$$ISERR(tSC) Quit
        If $Data(..PreparedApps(tName)) = 0 Continue
        Set tSame = $Data(tNow) && ($Get(tNow("Enabled")) = $Get(..PreparedApps(tName, "Enabled"))) && ($Get(tNow("MatchRoles")) = $Get(..PreparedApps(tName, "MatchRoles"))) && ($Get(tNow("Roles")) = $Get(..PreparedApps(tName, "Roles")))
        If tSame Continue
        Set tSC = ..Restore(tName)
        Do $$$AssertStatusOK(tSC, tName _ " is put back as it was recorded")
    }
    Quit $$$OK
}

/// <p>The stored fields of the application <var>pName</var> in <var>pProps</var>, read in <code>%SYS</code>, or nothing
/// when the instance does not hold it.</p>
ClassMethod Stored(pName As %String, Output pProps) As %Status
{
    Kill pProps
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(pName) {
            Set tSC = ##class(Security.Applications).Get(pName, .pProps)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Writes the recorded fields of <var>pName</var> back: modified when the instance still holds it, created when not.</p>
Method Restore(pName As %String) As %Status
{
    Kill tProps
    Merge tProps = ..PreparedApps(pName)
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(pName) {
            Set tSC = ##class(Security.Applications).Modify(pName, .tProps)
        } Else {
            Set tSC = ##class(Security.Applications).Create(pName, .tProps)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Prohibits for <var>pTool</var> against the web application <var>pId</var>, with <var>pPayload</var> and
/// <var>pDiff</var>: the verdict, its code, and the status the set answered. An error status is returned to the
/// caller, which asserts it, so a failed call is never read as "not prohibited".</p>
ClassMethod Ask(pTool As %String, pId As %String, pPayload As %String, pDiff As %String, Output pCode As %String, Output pSC As %Status) As %Boolean
{
    Set pCode = ""
    Set pSC = ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", pId, .tRef)
    If $$$ISERR(pSC) Quit 0
    Set pSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits(pTool, tRef, pPayload, pDiff, .tProhibits, .tCode)
    If $$$ISERR(pSC) Quit 0
    Set pCode = tCode
    Quit tProhibits
}

/// <p>The web application <var>pName</var> as the vendor's own read renders it, as JSON, or <code>""</code> when
/// the instance does not answer. Compared before and after a refused write to show the vendor was not reached.</p>
ClassMethod WebAppJSON(pName As %String) As %String
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject(tRead) Quit ""
    Quit tRead.%ToJSON()
}

/// <p>A delete of OcuPilotState is refused the arm.</p>
Method TestDeleteStateRefused()
{
    Set tProhibits = ..Ask("webapp.list.delete", "OcuPilotState", "{}", "[]", .tCode, .tSC)
    Do $$$AssertTrue(tProhibits, "a delete of OcuPilotState is prohibited")
    Do $$$AssertEquals(tCode, "PROHIBITED.OCUPILOTROUTINEAPP", "a delete of OcuPilotState answers the routine application code")
    Quit
}

/// <p>A delete of OcuPilotIdentity is refused the arm.</p>
Method TestDeleteIdentityRefused()
{
    Set tProhibits = ..Ask("webapp.list.delete", "OcuPilotIdentity", "{}", "[]", .tCode, .tSC)
    Do $$$AssertTrue(tProhibits, "a delete of OcuPilotIdentity is prohibited")
    Do $$$AssertEquals(tCode, "PROHIBITED.OCUPILOTROUTINEAPP", "a delete of OcuPilotIdentity answers the routine application code")
    Quit
}

/// <p>Disabling either application is refused the arm.</p>
Method TestDisableRefused()
{
    Set tDiff = [{"field": "Enabled", "before": "true", "after": "false"}]
    Set tProhibits = ..Ask("webapp.list.update", "OcuPilotIdentity", "{""Enabled"": false}", tDiff.%ToJSON(), .tCode, .tSC)
    Do $$$AssertTrue(tProhibits, "disabling OcuPilotIdentity is prohibited")
    Do $$$AssertEquals(tCode, "PROHIBITED.OCUPILOTROUTINEAPP", "disabling OcuPilotIdentity answers the routine application code")
    Quit
}

/// <p>A change to MatchRoles is refused the arm.</p>
Method TestMatchRolesRefused()
{
    Set tProhibits = ..Ask("webapp.list.update", "OcuPilotState", "{""MatchRoles"": []}", "[{""field"": ""MatchRoles"", ""before"": ""a"", ""after"": ""b""}]", .tCode, .tSC)
    Do $$$AssertTrue(tProhibits, "a MatchRoles change on OcuPilotState is prohibited")
    Do $$$AssertEquals(tCode, "PROHIBITED.OCUPILOTROUTINEAPP", "a MatchRoles change on OcuPilotState answers the routine application code")
    Quit
}

/// <p>A change to Roles is refused the arm (no endpoint carries Roles, so the set is asked directly).</p>
Method TestRolesRefused()
{
    Set tProhibits = ..Ask("webapp.list.update", "OcuPilotIdentity", "{""Roles"": []}", "[{""field"": ""Roles"", ""before"": ""a"", ""after"": ""b""}]", .tCode, .tSC)
    Do $$$AssertTrue(tProhibits, "a Roles change on OcuPilotIdentity is prohibited")
    Do $$$AssertEquals(tCode, "PROHIBITED.OCUPILOTROUTINEAPP", "a Roles change on OcuPilotIdentity answers the routine application code")
    Quit
}

/// <p>An absent application the arm does not name is not refused by it.</p>
Method TestUnrelatedNotRefused()
{
    Set tProhibits = ..Ask("webapp.list.delete", ..#PROBEPATH, "{}", "[]", .tCode, .tSC)
    Do $$$AssertStatusOK(tSC, "the set answers without error, so a refusal to answer cannot read as not prohibited")
    Do $$$AssertTrue('tProhibits, "an absent application the arm does not name is not prohibited")
    Do $$$AssertEquals(tCode, "", "an application the arm does not name is not refused the routine application code")
    Quit
}

/// <p>The privileged routine endpoint refuses a web application named there before the vendor (AD-10 as amended,
/// Story 18.10): a read is 404 and a write 409 <code>PRIVROUTINE.TYPE</code>, while OcuPilotState, a routine application,
/// still reads.</p>
Method TestPrivilegedRoutineEndpointRefusesAWebApp()
{
    Kill tQuery
    Set tQuery("name") = "/csp/user"
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.PrivilegedRoutine", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 404, "a read of a web application through the privileged routine endpoint answers 404")
    Do $$$AssertEquals(tFault.code, "PRIVROUTINE.TYPE", "the refusal names the type")
    Kill tQuery
    Set tQuery("name") = "/csp/user"
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.PrivilegedRoutine", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 409, "a delete of a web application through the privileged routine endpoint answers 409")
    Do $$$AssertEquals(tFault.code, "PRIVROUTINE.TYPE", "the delete refusal names the type")
    Kill tQuery
    Set tQuery("name") = "/csp/user"
    Set tBefore = ..WebAppJSON("/csp/user")
    Do $$$AssertNotEquals(tBefore, "", "/csp/user reads before the write, so the unchanged read below cannot pass on an empty read")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.PrivilegedRoutine", "PUT", .tQuery, {"Enabled": true}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 409, "a write of a web application through the privileged routine endpoint answers 409")
    Do $$$AssertEquals(tFault.code, "PRIVROUTINE.TYPE", "the write refusal names the type")
    Do $$$AssertEquals(..WebAppJSON("/csp/user"), tBefore, "and the vendor was not reached: the application reads as it did")
    Kill tQuery
    Set tQuery("name") = ##class(OcuPilot.Kernel.State.Base).#APPLICATION
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.PrivilegedRoutine", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "OcuPilotState still reads through the privileged routine endpoint")
    Quit
}

/// <p>One call of the privileged routine endpoint, <var>pType</var> with <var>pBody</var>, against the routine application
/// <var>pName</var>: refused 403 with the arm's code and sentence, and the application reads back as it was before.</p>
Method AssertEndpointRefused(pLabel As %String, pName As %String, pType As %String, pBody As %DynamicObject = "")
{
    Set tBefore = ..WebAppJSON(pName)
    Do $$$AssertNotEquals(tBefore, "", pLabel _ ": " _ pName _ " reads before the call, so the unchanged read below cannot pass on an empty read")
    If tBefore = "" Quit
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.PrivilegedRoutine", pType, .tQuery, pBody, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 403, pLabel _ " is refused 403")
    Set tCode = ""
    Set tReason = ""
    If $Data(tFault) && $IsObject(tFault) {
        Set tCode = tFault.code
        Set tReason = tFault.reason
    }
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTROUTINEAPP, pLabel _ " is refused the routine application code")
    Do $$$AssertEquals(tReason, ..#REASON, pLabel _ " carries the published sentence")
    Do $$$AssertEquals(..WebAppJSON(pName), tBefore, pLabel _ " and the vendor was not reached: " _ pName _ " reads as it did")
    Quit
}

/// <p>The privileged routine endpoint refuses a delete of OcuPilotState before the vendor.</p>
/// <p>Mutation (Rule 19): in <class>OcuPilot.Kernel.Proposal.Prohibited</class>'s <method>RoutineEndpointRefused</method>,
/// change <code>If pType = "DELETE" {</code> to <code>If 0 {</code>. The vendor is then asked to delete the application on
/// the throwaway, the read after the call is empty and this leg goes red; <code>OnAfterOneTest</code> puts it back.</p>
Method TestEndpointDeleteRefused()
{
    Do ..AssertEndpointRefused("the privileged routine endpoint's delete of OcuPilotState", ##class(OcuPilot.Kernel.State.Base).#APPLICATION, "DELETE")
    Quit
}

/// <p>The privileged routine endpoint refuses a PUT that sets OcuPilotIdentity's Enabled to false before the vendor.</p>
/// <p>Mutation (Rule 19): in <method>RoutineEndpointRefused</method>, change <code>Set tFields = "Enabled," _</code> to
/// <code>Set tFields = </code>. The disable is then passed to the vendor, the read after the call differs and this leg goes
/// red; <code>OnAfterOneTest</code> puts the enabled flag back.</p>
Method TestEndpointDisableRefused()
{
    Do ..AssertEndpointRefused("the privileged routine endpoint's disable of OcuPilotIdentity", ##class(OcuPilot.Kernel.State.Base).#IDENTITYAPPLICATION, "PUT", {"Enabled": false})
    Quit
}

/// <p>The privileged routine endpoint refuses a PUT that names OcuPilotState's MatchRoles before the vendor.</p>
/// <p>Mutation (Rule 19): in <class>OcuPilot.Kernel.Proposal.Prohibited</class>, change the parameter
/// <code>ROUTINEAPPLICATIONFIELDS = "MatchRoles,Roles"</code> to <code>"Roles"</code>. The kernel's MatchRoles legs go red
/// with this one, which is the shared predicate's own leg; <code>OnAfterOneTest</code> restores the record.</p>
Method TestEndpointMatchRolesRefused()
{
    Do ..AssertEndpointRefused("the privileged routine endpoint's MatchRoles change of OcuPilotState", ##class(OcuPilot.Kernel.State.Base).#APPLICATION, "PUT", {"MatchRoles": "%Operator"})
    Quit
}

/// <p>The privileged routine endpoint refuses a PUT that names OcuPilotIdentity's Roles before the vendor.</p>
/// <p>Mutation (Rule 19): in <class>OcuPilot.Kernel.Proposal.Prohibited</class>, change the parameter
/// <code>ROUTINEAPPLICATIONFIELDS = "MatchRoles,Roles"</code> to <code>"MatchRoles"</code>. The Roles legs go red with it,
/// and <code>OnAfterOneTest</code> restores the record.</p>
Method TestEndpointRolesRefused()
{
    Do ..AssertEndpointRefused("the privileged routine endpoint's Roles change of OcuPilotIdentity", ##class(OcuPilot.Kernel.State.Base).#IDENTITYAPPLICATION, "PUT", {"Roles": "%Developer"})
    Quit
}

}
