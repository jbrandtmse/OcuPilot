/// <p>Pins AD-10's privileged routine application arm (DW-2239, Story 18.10): every write to <code>OcuPilotState</code> or
/// <code>OcuPilotIdentity</code> -- a delete, a disable, a change to <code>MatchRoles</code>, a change to any other field, a
/// create -- is refused <code>PROHIBITED.OCUPILOTROUTINEAPP</code> with the kernel's own sentence, and an unrelated
/// application is not refused by it.</p>
/// <p>The privileged routine endpoint's legs (<class>OcuPilot.Port.AdminPort</class>) refuse every call but a read before the
/// vendor is reached, and each leg reads the application before and after the call.</p>
/// <p>Needs the throwaway's install (both applications exist and read). <class>OcuPilot.Port.AdminPort</class> admits no
/// <code>Security.PrivilegedRoutine</code> <code>PUT</code> or <code>DELETE</code> on this build, so a mutated arm answers 501
/// before any vendor call and the after-read cannot differ yet; it carries weight once Story 18.31 admits them.
/// <code>OnBeforeOneTest</code> records both applications' stored state and <code>OnAfterOneTest</code> puts back any of it
/// that changed (<method>PutBack</method>). Each leg's mutation is named in the spec's Verification.</p>
Class OcuPilot.Test.OwnRoutineApplication Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>Refuses to run anywhere <parameter>ARMINGVARIABLE</parameter> does not read 1: this class restores OcuPilot's own privileged routine applications when a mutated guard lets a write through.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OwnRoutineApplication restores OcuPilot's own privileged routine applications when a mutated guard lets a write through, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>The probe application the unrelated leg asks about; it is absent, so the set answers not prohibited.</p>
Parameter PROBEPATH = "/csp/ocuprobe1810";

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

/// <p>Puts back the stored state of each routine application whose stored fields differ from the record.</p>
Method OnAfterOneTest() As %Status
{
    For tName = ##class(OcuPilot.Kernel.State.Base).#APPLICATION, ##class(OcuPilot.Kernel.State.Base).#IDENTITYAPPLICATION {
        If $Data(..PreparedApps(tName)) = 0 Continue
        Kill tWas
        Merge tWas = ..PreparedApps(tName)
        Set tSC = ..PutBack(tName, .tWas)
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

/// <p>Puts the application <var>pName</var> back to <var>pWas</var>, as <method>Stored</method> read it, when any of its
/// stored fields differs now: modified when the instance still holds it, created when not. A caller that records with
/// <method>Stored</method> before a test restores with this after it.</p>
ClassMethod PutBack(pName As %String, ByRef pWas) As %Status
{
    Set tSC = ..Stored(pName, .tNow)
    If $$$ISERR(tSC) Quit tSC
    Set tSame = ($Data(tNow) > 0)
    Set tField = ""
    For {
        Set tField = $Order(pWas(tField))
        If (tField = "") || 'tSame Quit
        If $Get(tNow(tField)) '= $Get(pWas(tField)) Set tSame = 0
    }
    If tSame Quit $$$OK
    Kill tProps
    Merge tProps = pWas
    Set tOrigNS = $NAMESPACE
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
/// <p>Mutation (Rule 19): in <class>OcuPilot.Kernel.Proposal.Prohibited</class>'s <method>Prohibits</method>, append
/// <code>&amp;&amp; (..WriteTypeOf(..ToolClassNamed(pToolName)) '= "DELETE")</code> to the arm's condition, so the arm skips a
/// delete: both delete legs go red. In <method>OwnRoutineApplication</method>, replace the comparison with
/// <parameter>APPLICATION</parameter> by <code>0</code>: the OcuPilotState legs go red; the same for
/// <parameter>IDENTITYAPPLICATION</parameter> and the OcuPilotIdentity legs.</p>
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

/// <p>A change to any other field, and a create, are refused the arm as well: the arm is over the application, so it lists
/// no field.</p>
/// <p>Mutation (Rule 19): in <class>OcuPilot.Kernel.Proposal.Prohibited</class>'s <method>Prohibits</method>, append
/// <code>&amp;&amp; ((..WriteTypeOf(..ToolClassNamed(pToolName)) = "DELETE") || (pDiff [ "Enabled") || (pDiff [ "MatchRoles"))</code>
/// to the arm's condition <code>If (tType = ..#TYPEWEBAPPLICATION) &amp;&amp; ..OwnRoutineApplication(tId) {</code>, which
/// reintroduces a field list: the delete, disable and MatchRoles legs stay green and this leg goes red on the Description,
/// Resource, NameSpace and create cases.</p>
Method TestAnyOtherWriteIsRefused()
{
    For tName = ##class(OcuPilot.Kernel.State.Base).#APPLICATION, ##class(OcuPilot.Kernel.State.Base).#IDENTITYAPPLICATION {
        For tCase = $ListBuild("Description", "b"), $ListBuild("Resource", "%Admin_Manage"), $ListBuild("NameSpace", "USER"), $ListBuild("Enabled", "true") {
            Set tField = $List(tCase, 1)
            Set tDiff = [{"field": (tField), "before": "a", "after": ($List(tCase, 2))}]
            Set tPayload = {}
            Do tPayload.%Set(tField, $List(tCase, 2))
            Set tProhibits = ..Ask("webapp.list.update", tName, tPayload.%ToJSON(), tDiff.%ToJSON(), .tCode, .tSC)
            Do $$$AssertStatusOK(tSC, "the set answers a " _ tField _ " change of " _ tName)
            Do $$$AssertTrue(tProhibits, "a " _ tField _ " change of " _ tName _ " is prohibited")
            Do $$$AssertEquals(tCode, "PROHIBITED.OCUPILOTROUTINEAPP", "a " _ tField _ " change of " _ tName _ " answers the routine application code")
        }
        Set tProhibits = ..Ask("webapp.list.create", tName, "{}", "[]", .tCode, .tSC)
        Do $$$AssertStatusOK(tSC, "the set answers a create of " _ tName)
        Do $$$AssertTrue(tProhibits, "a create of " _ tName _ " is prohibited")
        Do $$$AssertEquals(tCode, "PROHIBITED.OCUPILOTROUTINEAPP", "a create of " _ tName _ " answers the routine application code")
    }
    Quit
}

/// <p>The privileged routine endpoint's arm refuses a write only when it names OcuPilotState or OcuPilotIdentity: a
/// <code>PUT</code> or <code>DELETE</code> naming another application is left to the port.</p>
/// <p>Mutation (Rule 19): in <class>OcuPilot.Kernel.Proposal.Prohibited</class>'s <method>RoutineEndpointRefused</method>, drop
/// <code> || '..OwnRoutineApplication(pName)</code> from the first condition: both legs go red.</p>
Method TestTheEndpointArmSparesOtherApplications()
{
    For tType = "PUT", "DELETE" {
        Set tRefused = ##class(OcuPilot.Kernel.Proposal.Prohibited).RoutineEndpointRefused(tType, "OcuProbe1810Routine", .tCode)
        Do $$$AssertTrue('tRefused, "a " _ tType _ " naming another application is not refused by the arm")
        Do $$$AssertEquals(tCode, "", "and carries no routine application code")
    }
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
/// Story 18.10): a read is 404 and a write 409 <code>PRIVROUTINE.TYPE</code>, while OcuPilotState and OcuPilotIdentity,
/// routine applications, still read.</p>
/// <p>Mutation (Rule 19): in <class>OcuPilot.Kernel.Proposal.Prohibited</class>'s <method>RoutineEndpointRefused</method>, drop
/// <code>(pType = "GET") || </code> from the first condition: a read of either routine application is refused 403 and the last
/// legs go red.</p>
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
    For tName = ##class(OcuPilot.Kernel.State.Base).#APPLICATION, ##class(OcuPilot.Kernel.State.Base).#IDENTITYAPPLICATION {
        Kill tQuery
        Set tQuery("name") = tName
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.PrivilegedRoutine", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tName _ " still reads through the privileged routine endpoint")
    }
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
    Do $$$AssertEquals(tReason, ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTROUTINEAPPREASON, pLabel _ " carries the arm's own sentence")
    Do $$$AssertEquals(..WebAppJSON(pName), tBefore, pLabel _ " and the vendor was not reached: " _ pName _ " reads as it did")
    Quit
}

/// <p>The privileged routine endpoint refuses a delete of OcuPilotState before the vendor.</p>
/// <p>Mutation (Rule 19): in <class>OcuPilot.Kernel.Proposal.Prohibited</class>'s <method>RoutineEndpointRefused</method>,
/// change <code>(pType = "GET")</code> to <code>(pType = "GET") || (pType = "DELETE")</code>, so a <code>DELETE</code> is no longer
/// refused. The delete then reaches the port's 501 for an endpoint type it does not admit, and this leg goes red on the status
/// and the code.</p>
Method TestEndpointDeleteRefused()
{
    Do ..AssertEndpointRefused("the privileged routine endpoint's delete of OcuPilotState", ##class(OcuPilot.Kernel.State.Base).#APPLICATION, "DELETE")
    Quit
}

/// <p>The privileged routine endpoint refuses a PUT that sets OcuPilotIdentity's Enabled to false before the vendor.</p>
/// <p>Mutation (Rule 19): in <method>RoutineEndpointRefused</method>, change <code>(pType = "GET")</code> to
/// <code>(pType = "GET") || (pType = "PUT")</code>, so a <code>PUT</code> is no longer refused. The call then reaches the port's
/// 501, and this leg goes red on the status and the code, with the other <code>PUT</code> legs.</p>
Method TestEndpointDisableRefused()
{
    Do ..AssertEndpointRefused("the privileged routine endpoint's disable of OcuPilotIdentity", ##class(OcuPilot.Kernel.State.Base).#IDENTITYAPPLICATION, "PUT", {"Enabled": false})
    Quit
}

/// <p>The privileged routine endpoint refuses a PUT that names OcuPilotState's MatchRoles before the vendor.</p>
/// <p>Mutation (Rule 19): the one of <method>TestEndpointDisableRefused</method>; every <code>PUT</code> leg shares it.</p>
Method TestEndpointMatchRolesRefused()
{
    Do ..AssertEndpointRefused("the privileged routine endpoint's MatchRoles change of OcuPilotState", ##class(OcuPilot.Kernel.State.Base).#APPLICATION, "PUT", {"MatchRoles": "%Operator"})
    Quit
}

/// <p>The privileged routine endpoint refuses a PUT of any other field, and a PUT with an empty body, which the vendor
/// reads as emptying the application's routines, before the vendor.</p>
/// <p>Mutation (Rule 19): the one of <method>TestEndpointDisableRefused</method>; every <code>PUT</code> leg shares it.</p>
Method TestEndpointAnyFieldRefused()
{
    Do ..AssertEndpointRefused("the privileged routine endpoint's Description change of OcuPilotState", ##class(OcuPilot.Kernel.State.Base).#APPLICATION, "PUT", {"Description": "changed"})
    Do ..AssertEndpointRefused("the privileged routine endpoint's Resource change of OcuPilotIdentity", ##class(OcuPilot.Kernel.State.Base).#IDENTITYAPPLICATION, "PUT", {"Resource": "%Admin_Manage"})
    Do ..AssertEndpointRefused("the privileged routine endpoint's empty-body PUT of OcuPilotState", ##class(OcuPilot.Kernel.State.Base).#APPLICATION, "PUT", {})
    Quit
}

}
