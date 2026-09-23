/// <p>The prohibited set over HTTP, against a <b>real</b> web application (Story 5.5, AD-10,
/// AD-39): the shipped <class>OcuPilot.Kernel.Proposal.Confirm</class>, the shipped
/// <class>OcuPilot.Port.AdminPort</class>, and the instance's own record of the target read back
/// afterwards.</p>
/// <p>It also pins the set's idea of which spellings of a path name one application against the
/// instance's own resolution (DW-1352), which is the one claim in that predicate that no fixture
/// can answer.</p>
/// <p><b>Since Story 7.1 it carries the other caller of that same set</b> (AD-53): the screen's own
/// row actions over <code>POST /screens/:screen/action</code>, against this class's own probe
/// application. They live here rather than in a class of their own because they create and delete a
/// web application, which is what <parameter>ARMINGVARIABLE</parameter> arms and what this class is
/// already rostered for in <file>scripts/ci-throwaway.sh</file>.</p>
/// <p>It is also where AD-29's second half is measured -- a <b>real least-privileged principal</b>
/// rather than the <code>%All</code> account every other run uses -- for the write tools whose pair
/// sets an <code>%All</code> run cannot establish: Story 5.9's user write, Story 5.10's auditing
/// write, Story 5.11's task resume and Story 5.12's two process writes.</p>
/// <p><b>What it needs from the environment, and at which scope.</b> Class-wide: the OcuPilot web
/// application reachable on this instance's own web-server port, the applications the install
/// roster declares, an account holding <code>%All</code>, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code> -- every method here creates and
/// deletes a web application and an IRIS account, so <method>OnBeforeAllTests</method> refuses the
/// class where it does not. Per method: <parameter>AUDITVARIABLE</parameter> reading <code>1</code>,
/// required by <parameter>AUDITINGMETHOD</parameter> alone, which turns this instance's auditing
/// off. <method>OnBeforeOneTest</method> skips that one method where it does not read 1, so a
/// container that predates the variable still runs the other nineteen rather than none
/// (DW-1452). Only <file>scripts/ci-throwaway.sh</file> sets either.</p>
/// <p><b>It writes nothing it did not create.</b> The probe application is
/// <method>OcuPilot.Test.ProposalFixture.EnsureWriteTarget</method>'s, which refuses to adopt one
/// it did not make, and every test here asserts that the confirm left it byte for byte as it
/// was.</p>
Class OcuPilot.Test.ProhibitedRoute Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The second variable this class needs, for the same reason
/// <class>OcuPilot.Test.AuditingUpdate</class> declares it:
/// <parameter>AUDITINGMETHOD</parameter> confirms a real disable, so while that one leg runs
/// nothing on this instance is audited at all.</p>
/// <p><b>Declared here is what <file>scripts/ci-throwaway.sh</file>'s roster is held against</b>
/// (<file>ui/tools/ci.test.mjs</file>), so the parameter stays whether or not
/// <method>OnBeforeAllTests</method> reads it. It is <method>OnBeforeOneTest</method> that reads
/// it now, for one method rather than for the class.</p>
Parameter AUDITVARIABLE = "OCUPILOT_ALLOW_AUDIT_TOGGLE";

/// <p>The one test method <parameter>AUDITVARIABLE</parameter> gates: the only method in this
/// class that toggles this instance's auditing. Named in a parameter rather than as a literal
/// inside <method>OnBeforeOneTest</method> so
/// <method>TestTheAuditingMethodParameterNamesAMethodThisClassDeclares</method> can hold it
/// against the class dictionary -- a rename that left a literal behind would silently un-skip the
/// gate and run an audit toggle unarmed.</p>
Parameter AUDITINGMETHOD = "TestALeastPrivilegedPrincipalConfirmsTheAuditingWriteOverTheWire";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

Parameter TOOL = "webapp.list.update";

/// <p>Story 5.9's write tool and the screen that owns it, for the user legs below.</p>
Parameter USERTOOL = "permissions.users.update";

Parameter USERSCREEN = "OcuPilot.Screen.Descriptor.UserList";

/// <p>Story 5.10's write tool and the screen that owns it, for the auditing legs below. The tool's
/// name, its one settable field and the screen's entity type are all read off these classes rather
/// than spelled again here.</p>
Parameter AUDITINGTOOLCLASS = "OcuPilot.Screen.Tool.AuditingUpdate";

Parameter AUDITINGSCREEN = "OcuPilot.Screen.Descriptor.AuditingConfig";

/// <p>Story 5.11's write tool and its screen: the action-style resume, whose declared pair set is
/// the task schedule's own.</p>
Parameter TASKTOOLCLASS = "OcuPilot.Screen.Tool.TaskResume";

Parameter TASKSCREEN = "OcuPilot.Screen.Descriptor.TaskScheduleList";

/// <p>Story 5.12's two write tools and their screen: the action-style suspend and resume, whose
/// declared pair set is the processes list's own three.</p>
Parameter SUSPENDTOOLCLASS = "OcuPilot.Screen.Tool.ProcessSuspend";

Parameter PROCESSRESUMETOOLCLASS = "OcuPilot.Screen.Tool.ProcessResume";

Parameter PROCESSSCREEN = "OcuPilot.Screen.Descriptor.ProcessList";

/// <p>The pair a principal short of the process write's own resource is missing, and the
/// administrative resource it does hold so the router's floor is cleared before the screen's gate
/// runs.</p>
Parameter PROCESSPAIR = "%Admin_Operate:USE";

Parameter PROCESSFLOORADMIN = "%Admin_Manage";

/// <p>An administrative resource that is <b>not</b> <code>%Admin_Secure</code>, granted to the
/// principal of <method>TestAnAccountShortOfTheAuditingPairIsRefusedTheNamedPair</method>.
/// <method>OcuPilot.Api.Router.HoldsAdminResource</method> refuses a caller holding no
/// <code>%Admin_*</code> resource at all with <code>AUTH.NOADMIN</code> before any route runs, so
/// without this the leg would measure the router's floor instead of the screen's own pair
/// set.</p>
Parameter NONSECUREADMIN = "%Admin_Operate";

/// <p>The predefined account the live user refusal is driven against. Read-only throughout: the
/// set is asked directly, so no proposal exists and no write is issued.</p>
Parameter SYSTEMACCOUNT = "_SYSTEM";

/// <p>The write's two declared pairs and nothing else -- deliberately without read on the install
/// namespace's code database, which is what
/// <method>TestAnAccountWithoutTheCodeDatabaseReadIsRefusedABareForbidden</method> measures.</p>
Parameter DECLAREDPAIRSONLY = "%Admin_Secure:U,%DB_IRISSYS:R";

/// <p>A proposal id nothing carries. OcuPilot's own answer for one is a 404 envelope, which is what
/// makes a bare 403 a distinctive measurement.</p>
Parameter UNKNOWNPROPOSAL = "OcuPilotProbeNoSuchProposal";

/// <p>The probe account the least-privileged user write is made against:
/// <class>OcuPilot.Test.ProposalFixture</class>'s, created disabled and removed by the one leg that
/// uses it.</p>
Parameter USERACCOUNT = "OcuPilotProbeRouteUserTarget";

/// <p>The probe application's path, <class>OcuPilot.Test.ProposalFixture</class>'s own.</p>
Parameter TARGET = "/csp/ocupilotprobeconfirm";

/// <p>Story 7.1's screen-action route, as <class>OcuPilot.Api.Router</class>'s own
/// <code>UrlMap</code> declares it, with a concrete screen in the parameter's place.</p>
Parameter ACTIONROUTE = "/screens/:screen/action";

/// <p>The screen every row action below addresses, by its own <code>toolIdentifier</code>.</p>
Parameter ACTIONSCREEN = "webapp.list";

/// <p>The resource the probe application is guarded by while this class runs, so the dropped-
/// authorization predicate has something to drop. A standard IRIS resource, never a new one.</p>
Parameter GUARDRESOURCE = "%Development";

/// <p>A fixed throwaway password for <parameter>PRINCIPALUSER</parameter>: the account is
/// recreated by <method>EnsureLeastPrivilegedPrincipal</method> at the start of the one test that
/// uses it and removed at the end, so nothing about this value needs to be secret or unique across
/// runs -- only long and mixed enough to satisfy the instance's own password policy.</p>
Parameter PRINCIPALPASSWORD = "OcuPilotAc5ProbePassword9Aa";

/// <p>The role, and the user holding only it, that
/// <method>TestOcuPilotsOwnServingPathRefusesALeastPrivilegedPrincipal</method> creates and
/// removes: exactly the write's two required pairs (<class>OcuPilot.Screen.Descriptor.WebAppList</class>'s
/// own, DW-1208) and nothing else. Dedicated names, never <class>OcuPilot.Test.TurnWireFixture</class>'s
/// shared role -- that role's resources are that fixture's own concern, and overwriting them here
/// would leave a later class in the sweep holding the wrong grant.</p>
Parameter PRINCIPALROLE = "OcuPilotProbeProhibitedRouteRole";

Parameter PRINCIPALUSER = "OcuPilotProbeProhibitedRouteUser";

/// <p>Create the probe application and guard it, or refuse to run at all.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProhibitedRoute creates and deletes a web application on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget($Namespace, .tCreated)
    If $$$ISERR(tSC) Quit tSC
    Quit ..Guard(..#GUARDRESOURCE)
}

/// <p>Skip <parameter>AUDITINGMETHOD</parameter>, and only it, where
/// <parameter>AUDITVARIABLE</parameter> does not read <code>1</code>.</p>
/// <p><b>The skip has to be here and cannot be in <method>OnBeforeAllTests</method></b>:
/// <class>%UnitTest.TestCase</class> reads <code>SkipTest</code> after
/// <code>OnBeforeOneTest</code> alone, and its own doc says a <code>$$$AssertSkipped</code> in
/// <code>OnBeforeAllTests</code> "may result in tests appearing to pass rather than being
/// skipped". A class-wide refusal on this variable was the alternative, and it removed AD-29's
/// least-privileged coverage for nineteen methods that never turn auditing off whenever the
/// container predated the variable (DW-1452).</p>
/// <p>A skipped method records <code>Status=2</code> and the manager runs neither the method nor
/// <method>OnAfterOneTest</method> for it, so nothing this class creates is left behind by a
/// skip.</p>
Method OnBeforeOneTest(pMethod As %String = "") As %Status
{
    If pMethod '= ..#AUDITINGMETHOD Quit $$$OK
    If $System.Util.GetEnviron(..#AUDITVARIABLE) = 1 Quit $$$OK
    Do $$$AssertSkipped(pMethod _ " turns this instance's auditing off and runs on a throwaway container only. " _ ..#AUDITVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.ProposalFixture).RemoveWriteTarget()
}

/// <p>Restore this instance's auditing whatever a method did, and <b>report a failed restore as a
/// failure of this teardown</b> rather than of the next class to run
/// (<method>OcuPilot.Test.AuditingUpdate.OnAfterOneTest</method>'s own contract, whose helpers this
/// calls rather than copying). The auditing leg restores in a frame of its own as well, because a
/// raise skips a method's tail; this is the net under it.</p>
/// <p><b>The assertion is on the reading taken BEFORE this teardown repairs anything</b> (AC7): a
/// reading taken after the repair is 1 whether the method's own frame ran or not. A failed repair
/// is held rather than returned at once, so the principal, the <parameter>TARGET</parameter> row
/// and the seeded proposals below are still removed on that path.</p>
Method OnAfterOneTest() As %Status
{
    Set tBefore = ##class(OcuPilot.Test.AuditingUpdate).AuditEnabled()
    Set tEnabled = tBefore
    If tEnabled '= 1 {
        Do ##class(OcuPilot.Test.AuditingUpdate).RestoreAuditing()
        Set tEnabled = ##class(OcuPilot.Test.AuditingUpdate).AuditEnabled()
    }
    Set tResult = $$$OK
    If tEnabled '= 1 Set tResult = $$$ERROR($$$GeneralError, "OcuPilot.Test.ProhibitedRoute left this instance's auditing off (AuditEnabled = " _ tEnabled _ ")")
    Do $$$AssertEquals(tBefore, 1, "the method restored auditing itself, so this teardown had nothing to repair")
    Do ..RemoveLeastPrivilegedPrincipal()
    ; Defensive: TestOcuPilotsOwnServingPathRefusesALeastPrivilegedPrincipal removes this record
    ; itself, but a failure between writing it and removing it would otherwise leave TARGET marked
    ; OcuPilot's own for every later test in this class.
    Do ##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#TARGET)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit tResult
}

/// <p>Set the probe application's guarding resource to <var>pResource</var>. Only ever called for
/// <parameter>TARGET</parameter>, which this suite created.</p>
Method Guard(pResource As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("Resource") = pResource
        Set tSC = ##class(Security.Applications).Modify(..#TARGET, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The probe application as the shipped port answers it now, in <var>pFresh</var>, and its
/// complete property set as one comparable string -- the whole object the vendor's own
/// <code>GET</code> renders, so "byte-for-byte what they were" is compared property for
/// property rather than over a chosen few.</p>
Method Snapshot(Output pFresh As %DynamicObject) As %String
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery("name") = ..#TARGET
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the probe application reads back through the port")
    If $$$ISERR(tSC) || '$IsObject(tFresh) Quit ""
    Set pFresh = tFresh
    Quit tFresh.%ToJSON()
}

/// <p>Seed one completed turn and one live proposal whose payload is the target as the instance
/// holds it now, with <var>pField</var> set to <var>pValue</var> -- the complete property set AD-4
/// requires, with exactly one property weakened.</p>
/// <p><b>A field the shipped tool can set is seeded exactly as a mint stores it</b>: one
/// <method>OcuPilot.Kernel.Proposal.Mint.Merge</method> over one real argument supplies the
/// payload, the diff and the unchanged count, and the fingerprint is that payload's own digest.
/// That is the relationship <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> writes, so both
/// digests <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> compares match and
/// the set is the only gate left between this row and the vendor write -- which is what lets the
/// clauses below asserting the application did not move fail when the set is removed.</p>
/// <p>A field the tool cannot set has no mint-shaped row at all: the tool refuses it 400 before a
/// proposal exists. Such a leg is seeded by hand, and because its stored payload carries the
/// weakened value it cannot digest to the fingerprint the fresh read produces, so the gate behind
/// the set refuses it once the set is removed -- its mutation reddens the 403 and the code, never
/// the untouched-application clause.</p>
Method Seed(pFresh As %DynamicObject, pField As %String, pValue As %RawString, pType As %String) As %String
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", ..#TARGET, .tRef)
    Do $$$AssertStatusOK(tSC, "the target reference is built")
    If $$$ISERR(tSC) Quit ""

    Set tArgs = {}
    Do tArgs.%Set(pField, pValue, pType)
    Set tSC = ..Minted(pFresh, tArgs, .tPayload, .tDiff, .tFingerprint, .tUnchanged)
    If $$$ISERR(tSC) Quit ""
    If tDiff = "[]" {
        ; The shipped merge moved nothing, so this field is outside the tool's settable list and no
        ; mint produces a row for it. Seed the weakened payload by hand against the fresh read's
        ; own digest.
        Set tHand = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
        Do tHand.%Set(pField, pValue, pType)
        Set tPayload = tHand.%ToJSON()
        Set tDiff = ##class(OcuPilot.Test.ProhibitedFixture).Diff(pField)
        Set tFingerprint = ..Digest(pFresh)
        Set tUnchanged = 0
        Set tArgs = {}
    }

    Kill tValues
    Set tValues("user") = tUser
    Set tValues("convKey") = ""
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = ..#TOOL
    Set tValues("targetRef") = tRef
    Set tValues("fingerprint") = tFingerprint
    Set tValues("arguments") = tArgs.%ToJSON()
    Set tValues("payload") = tPayload
    Set tValues("diff") = tDiff
    Set tValues("unchangedCount") = tUnchanged
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>The row a mint would have stored for <var>pArgs</var> against <var>pFresh</var>, built with
/// the shipped methods <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> itself uses: the merge's
/// payload and diff as JSON, that payload's digest under the descriptor's own exclusions, and the
/// merge's unchanged count.</p>
/// <p><var>pDiff</var> reads <code>[]</code> when the merge moved nothing, which is the answer for
/// an argument naming a field the tool's settable list does not carry.</p>
Method Minted(pFresh As %DynamicObject, pArgs As %DynamicObject, Output pPayload As %String, Output pDiff As %String, Output pFingerprint As %String, Output pUnchanged As %Integer, pTool As %String = {..#TOOL}) As %Status
{
    Set pPayload = ""
    Set pDiff = ""
    Set pFingerprint = ""
    Set pUnchanged = 0
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(pTool, .tTool)
    Do $$$AssertStatusOK(tSC, "the write tool resolves")
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tTool) Quit $$$ERROR($$$GeneralError, "the write tool " _ pTool _ " resolved to no entry")
    Set tClass = tTool.%Get("class")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, pArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tMerged, .tRows, .tCount, .tProblem)
    Do $$$AssertStatusOK(tSC, "the shipped merge runs over the fresh read")
    Do $$$AssertEquals(tProblem, "", "with no argument problem")
    If $$$ISERR(tSC) Quit tSC
    Set tExcludes = ""
    Set tDescriptor = $Parameter(tClass, "DESCRIPTORCLASS")
    If tDescriptor '= "" Set tExcludes = $ClassMethod(tDescriptor, "FingerprintExcludes")
    ; AD-51: an action-style write's digest covers the subject its tool declares, and the stored
    ; payload is that subject -- so a row seeded here is the row a real mint would have stored.
    Set tSubject = ##class(OcuPilot.Kernel.Proposal.Mint).FingerprintSubjectOf(tClass)
    If tSubject '= "" {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Projection(tMerged, tSubject, .tMerged)
        Do $$$AssertStatusOK(tSC, "the declared fingerprint subject projects out of the fresh read")
        If $$$ISERR(tSC) Quit tSC
    }
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tMerged, tExcludes, .pFingerprint, tSubject)
    Do $$$AssertStatusOK(tSC, "and the digest is taken")
    If $$$ISERR(tSC) Quit tSC
    Do $$$AssertNotEquals(pFingerprint, "", "which is not empty")
    Set pPayload = tMerged.%ToJSON()
    Set pDiff = tRows.%ToJSON()
    Set pUnchanged = tCount
    Quit tSC
}

/// <p>The digest the shipped confirm re-computes for <var>pFresh</var> with no argument applied:
/// the fresh read merged and hashed through the same shipped methods
/// <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> calls.</p>
/// <p>It is the fingerprint of a hand-seeded leg only, and it is deliberately not the digest of
/// that leg's stored payload -- which is why the stored-payload half of the fingerprint gate
/// refuses such a row the moment the set stops answering first.</p>
Method Digest(pFresh As %DynamicObject) As %String
{
    Set tSC = ..Minted(pFresh, {}, .tPayload, .tDiff, .tFingerprint, .tUnchanged)
    If $$$ISERR(tSC) Quit ""
    Quit tFingerprint
}

/// <p>POST the confirm route for <var>pKey</var> as the test account.</p>
Method Call(pKey As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/proposal/" _ pKey _ "/confirm", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBody, .pHeaders, "", "application/json")
}

/// <p>POST the confirm route for <var>pKey</var> as <var>pUser</var> -- the least-privileged leg's
/// own confirming call, never the test account.</p>
Method CallAs(pKey As %String, pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/proposal/" _ pKey _ "/confirm", pUser, pPassword, .pStatus, .pBody, .pHeaders, "", "application/json")
}

/// <p>The resource that guards read access to the install namespace's own code database --
/// <class>OcuPilot.Test.TurnWireFixture.Resources</class>'s "clears the router's floor" resource,
/// needed here for the same underlying reason: reaching <class>OcuPilot.Api.Router</class> at all
/// over HTTP requires it, independently of and beneath <method>OcuPilot.Kernel.Proposal.Confirm</method>'s
/// own declared pairs. A principal that holds DW-1208's two pairs but not this one is refused a
/// bare 403 with no envelope before the confirm route's own code ever runs -- measured while
/// writing this test, which is why it is granted explicitly rather than assumed to come free with
/// the write's own pairs.</p>
Method CodeDatabaseResource() As %String
{
    Set tResource = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set $NAMESPACE = "%SYS"
        Set tNsObj = ##class(Config.Namespaces).Open(tNs)
        Set tResource = ##class(SYS.Database).%OpenId(##class(Config.Databases).Open(tNsObj.Routines).Directory).ResourceName
    } Catch ex {
        Set tResource = ""
    }
    Set $NAMESPACE = tOrigNS
    Quit tResource
}

/// <p>Create or reset <parameter>PRINCIPALUSER</parameter> holding <parameter>PRINCIPALROLE</parameter>
/// with exactly <var>pResources</var>, and <var>pPassword</var>. A dedicated principal rather than
/// <class>OcuPilot.Test.TurnWireFixture</class>'s, per <parameter>PRINCIPALROLE</parameter>'s own
/// doc comment.</p>
Method EnsureLeastPrivilegedPrincipal(pPassword As %String, pResources As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Roles).Exists(..#PRINCIPALROLE, .tR, .tRS) {
            Kill tProps
            Set tProps("Resources") = pResources
            Set tProps("GrantedRoles") = ""
            Set tSC = ##class(Security.Roles).Modify(..#PRINCIPALROLE, .tProps)
        } Else {
            Set tSC = ##class(Security.Roles).Create(..#PRINCIPALROLE, "OcuPilot AC5 least-privileged probe (throwaway)", pResources, "")
        }
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#PRINCIPALUSER, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(..#PRINCIPALUSER)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(..#PRINCIPALUSER, ..#PRINCIPALROLE, pPassword, "OcuPilot AC5 least-privileged probe (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.ProhibitedRoute")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove <parameter>PRINCIPALUSER</parameter> when the instance holds it. The role is left in
/// place, the same convention <class>OcuPilot.Test.TurnWireFixture.DeletePrincipal</class> follows
/// for its own role.</p>
Method RemoveLeastPrivilegedPrincipal() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#PRINCIPALUSER, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(..#PRINCIPALUSER)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Seed one completed turn and one live proposal owned by <var>pUser</var> against
/// <var>pTarget</var>, exactly as <method>Seed</method> does for <parameter>TARGET</parameter> and
/// the test account -- the two are parameterized here so the least-privileged leg can mint and
/// confirm as the same principal (<method>OcuPilot.Kernel.Proposal.Write.ClaimById</method> refuses
/// a confirm from anyone but the row's own minting user).</p>
/// <p><b>Mint-shaped only:</b> unlike <method>Seed</method>, there is no hand-seeded fallback for a
/// field the tool cannot set -- every caller here passes a field the tool's settable list carries,
/// so <method>Minted</method> always answers a real diff row.</p>
Method SeedForPrincipal(pUser As %String, pTarget As %String, pFresh As %DynamicObject, pField As %String, pValue As %RawString, pType As %String, pTool As %String = {..#TOOL}, pEntityType As %String = "web-application", pExtraArgs As %DynamicObject = "") As %String
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded for the least-privileged principal")
    If $$$ISERR(tSC) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key(pEntityType, "instance", pTarget, .tRef)
    Do $$$AssertStatusOK(tSC, "the target reference is built")
    If $$$ISERR(tSC) Quit ""

    Set tArgs = {}
    Do tArgs.%Set(pField, pValue, pType)
    ; A second argument the one (field, value, type) triple cannot express -- an array, or simply a
    ; second field, so a caller can seed the multi-field change an acceptance criterion names.
    If $IsObject(pExtraArgs) {
        Set tExtra = pExtraArgs.%GetIterator()
        While tExtra.%GetNext(.tExtraKey, .tExtraValue) {
            Do tArgs.%Set(tExtraKey, tExtraValue)
        }
    }
    Set tSC = ..Minted(pFresh, tArgs, .tPayload, .tDiff, .tFingerprint, .tUnchanged, pTool)
    If $$$ISERR(tSC) Quit ""

    Kill tValues
    Set tValues("user") = pUser
    Set tValues("convKey") = ""
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = pTool
    Set tValues("targetRef") = tRef
    Set tValues("fingerprint") = tFingerprint
    Set tValues("arguments") = tArgs.%ToJSON()
    Set tValues("payload") = tPayload
    Set tValues("diff") = tDiff
    Set tValues("unchangedCount") = tUnchanged
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded for the least-privileged principal")
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>Seed a proposal weakening <var>pField</var>, confirm it over HTTP, and assert the 403 it
/// earns, the sentence beside the code, and that the application on the instance did not move.</p>
Method Weakened(pField As %String, pValue As %RawString, pType As %String, pExpected As %String)
{
    Set tBefore = ..Snapshot(.tFresh)
    If tBefore = "" Quit
    Set tKey = ..Seed(tFresh, pField, pValue, pType)
    If tKey = "" Quit

    Set tSC = ..Call(tKey, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 403, "and is refused: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(tBody [ "}{", 0, "in exactly one envelope")
    Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tEnvelope.%Get("code"), pExpected, "carrying " _ pExpected)
    Do $$$AssertEquals(tEnvelope.%Get("error"), ##class(OcuPilot.Api.Error).#FORBIDDEN, "under the forbidden slug")
    Do $$$AssertEquals(tEnvelope.%Get("reason"), ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(pExpected), "with the set's own written sentence rendered beside it")

    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "the row was not claimed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 0, "and the token is unspent")
    Do $$$AssertEquals(..Snapshot(.tAfter), tBefore, "the application's properties on the instance are what they were")
}

/// <p>The integration acceptance criterion: a stored proposal that would drop a real probe web
/// application's resource is refused 403 <code>PROHIBITED.AUTHORIZATION</code> over the wire, and
/// the application on the instance is untouched.</p>
/// <p>Mutation: point <method>OcuPilot.Kernel.Proposal.Write.ProhibitedClass</method> back at
/// <code>""</code>, or remove the prohibited call from
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method>. This row is mint-shaped, so
/// either mutation carries it past the fingerprint gate and into the vendor write: the 403, the
/// code, the row's live state, the unspent token <b>and</b> the untouched-application clause all
/// redden together.</p>
/// <p>AD-10, Story 7.1: <b>the registry advertises exactly the two write verbs this screen has
/// reviewed.</b> Story 5.8 asserted that no delete verb existed at all -- a tripwire aimed at the
/// story that would ship one -- and this is the positive roster that replaces it in the same pass
/// that shipped the tool.</p>
/// <p>Asked of every registered tool rather than of two names: a third verb could arrive under any
/// name, and the shape that would make it reachable is a <code>write</code>-kind tool on this
/// screen's identifier that is neither of the two.</p>
/// <p>Both names are read from the instance's own classes rather than recalled, so a rename that
/// left this roster behind reddens here rather than passing against a literal nobody updated.</p>
/// <p>Mutation (Rule 19): add a third <code>write</code> tool under the <code>webapp.list</code>
/// identifier and recompile the package -- this goes red naming it. Removing either roster row
/// reddens this method alone.</p>
Method TestTheWebApplicationWriteVerbsAreTheTwoThisScreenDeclares()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tool registry lists its tools")
    Set tIdentifier = $ClassMethod("OcuPilot.Screen.Descriptor.WebAppList", "ToolIdentifier")
    Do $$$AssertNotEquals(tIdentifier, "", "the web applications screen declares a tool identifier")

    ; The canonical names, read from the classes that declare them.
    Set tUpdate = $Parameter("OcuPilot.Screen.Tool.WebAppUpdate", "TOOLNAME")
    Set tDelete = $Parameter("OcuPilot.Screen.Tool.WebAppDelete", "TOOLNAME")
    Do $$$AssertEquals(tUpdate, ..#TOOL, "the update tool's own name is the one this class drives")
    Do $$$AssertNotEquals(tDelete, "", "and the delete tool declares one")
    Set tRoster = $ListBuild(tUpdate, tDelete)

    Set tSeen = 0
    Set tWrites = 0
    Kill tFound
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If $Piece(tTool.%Get("name"), ".", 1, 2) '= tIdentifier Continue
        Set tSeen = tSeen + 1
        If tTool.%Get("kind") '= "write" Continue
        Set tWrites = tWrites + 1
        Set tFound(tTool.%Get("name")) = ""
        Do $$$AssertTrue($ListFind(tRoster, tTool.%Get("name")) > 0, "every write verb on " _ tIdentifier _ " is one of the two this screen declares, not '" _ tTool.%Get("name") _ "'")
    }
    Do $$$AssertTrue(tSeen > 0, "the registry carries tools on " _ tIdentifier _ " at all, so this assertion ran over something")
    Do $$$AssertEquals(tWrites, 2, "and exactly two of them are write-kind")
    ; Both directions: a roster row naming a tool the registry does not carry is a row that names
    ; nothing, which is what makes removing one redden this method.
    For tI = 1:1:$ListLength(tRoster) {
        Do $$$AssertTrue($Data(tFound($List(tRoster, tI))), $List(tRoster, tI) _ " is registered under " _ tIdentifier)
    }
}

/// <p>Story 7.1, AD-53: the <b>screen's</b> caller of the same operation, over the same route the
/// browser uses -- <code>POST /screens/:screen/action</code>, named here verbatim as
/// <class>OcuPilot.Api.Router</class>'s own <code>UrlMap</code> declares it.</p>
/// <p>Three legs against this class's own probe application: the row's disable and enable run the
/// shipped merge write and the instance's own record moves both ways; the row's delete removes the
/// application and answers the <code>deleted</code> action; and an action the screen does not
/// declare is a 404 that writes nothing. The application is put back afterwards, guarded as
/// <method>OnBeforeAllTests</method> guarded it, so the later methods in this class see what they
/// expect.</p>
/// <p><b>It lives here rather than in a class of its own</b> because it creates and deletes a web
/// application, which is what <parameter>ARMINGVARIABLE</parameter> arms and what this class is
/// already rostered for in <file>scripts/ci-throwaway.sh</file>.</p>
/// <p>AD-53's two differences from the agent's caller are asserted on the same legs: the disable
/// runs with the kill switch and enforced read-only both on, because those switches are the
/// agent's; and no OcuPilot <code>AgentWrite</code> marker names the probe after either write,
/// because a person's row action is the human write that marker is distinguished from.</p>
/// <p>Mutation (Rule 19): remove <code>enable=Enabled:true</code> from
/// <parameter>OcuPilot.Screen.Tool.WebAppUpdate.SCREENACTIONS</parameter> and recompile -- the
/// enable leg answers 404 and its read-back goes red.</p>
Method TestTheScreensOwnRowActionsRunOverTheWire()
{
    Set tMap = ..RouterMap()
    Do $$$AssertTrue(tMap [ ("<Route Url=""" _ ..#ACTIONROUTE _ """ Method=""POST"""), "the router declares POST " _ ..#ACTIONROUTE)

    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Enabled"), 1, "the probe application starts enabled")

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(1, "OcuPilot probe: the agent is off", 1), "the kill switch and enforced read-only are both on")
    Set tSC = ..Act("disable", ..#TARGET, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds), "and both are off again")
    Do $$$AssertStatusOK(tSC, "the disable request completes")
    Do $$$AssertEquals(tStatus, 200, "and is accepted: " _ tBody)
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "in exactly one envelope")
    If tStatus = 200 {
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tAnswer.%Get("action"), "updated", "the answer carries the tool's own AD-14 action")
        Do $$$AssertEquals(tAnswer.%Get("target").%Get("type"), "web-application", "and the screen's entity type")
        Do $$$AssertEquals(tAnswer.%Get("target").%Get("id"), ..#TARGET, "and the canonical target id")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Enabled"), 0, "the instance's own record reads disabled")

    Set tSC = ..Act("enable", ..#TARGET, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC, "the enable request completes")
    Do $$$AssertEquals(tStatus2, 200, "and is accepted: " _ tBody2)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Enabled"), 1, "and the record reads enabled again")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, $Parameter("OcuPilot.Kernel.Audit.Event", "EVENTAGENTWRITE"), $Piece(..#TARGET, "/", *), .tMarkerData), 0, "and neither write left an agent marker naming the probe")

    ; An action the screen does not declare has no operation at that address, and writes nothing.
    Set tSC = ..Act("terminate", ..#TARGET, .tStatus3, .tBody3, .tHeaders3)
    Do $$$AssertStatusOK(tSC, "the undeclared-action request completes")
    Do $$$AssertEquals(tStatus3, 404, "and is not found: " _ tBody3)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Enabled"), 1, "and nothing was written")

    ; The destructive one, last: it removes the application this class works on, so the method
    ; puts it back before it returns.
    Set tSC = ..Act("delete", ..#TARGET, .tStatus4, .tBody4, .tHeaders4)
    Do $$$AssertStatusOK(tSC, "the delete request completes")
    Do $$$AssertEquals(tStatus4, 200, "and is accepted: " _ tBody4)
    If tStatus4 = 200 {
        Set tAnswer4 = ##class(%DynamicObject).%FromJSON(tBody4)
        Do $$$AssertEquals(tAnswer4.%Get("action"), "deleted", "the answer carries the delete tool's own AD-14 action")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Enabled"), "", "and the application is gone from the instance")

    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget($Namespace), "the probe application is put back for the rest of this class")
    Do $$$AssertStatusOK(..Guard(..#GUARDRESOURCE), "and guarded as OnBeforeAllTests guarded it")
}

/// <p>Story 7.1, AD-10, AD-13, AD-53: the screen's own caller reaches the same prohibited set the
/// agent's does. A row action against an application OcuPilot is served through is refused
/// <code>PROHIBITED.SERVINGPATH</code> with the set's own published sentence, whichever spelling
/// the instance resolves to it, and the application is left as it was.</p>
/// <p>Driven against this class's own probe application, marked as OcuPilot's own through
/// install's record for the span of this method, so no write reaches a real serving
/// application.</p>
/// <p>Mutation (Rule 19): restore <code>pServes &amp;&amp; +$Get(pChanged)</code> in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WebApplication</method> -- the delete legs carry no
/// changed field at all, so they pass the arm, answer 200, and the survival assertions go red.</p>
Method TestTheScreensOwnRowActionIsRefusedForOcuPilotsOwnApplication()
{
    Do ##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#TARGET)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).GuardedRecord("probe", ..#TARGET, "created"), "the probe application is recorded as OcuPilot's own for this leg")
    Set tExpected = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGPATH")
    Set tReason = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tExpected)

    Set tSpellings = $ListBuild(..#TARGET, $ZConvert(..#TARGET, "U"), ..#TARGET _ "/")
    For tI = 1:1:$ListLength(tSpellings) {
        Set tSpelling = $List(tSpellings, tI)
        Set tSC = ..Act("delete", tSpelling, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the delete of " _ tSpelling _ " completes")
        Do $$$AssertEquals(tStatus, 403, "and is refused: " _ tBody)
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, "in exactly one envelope")
        If tStatus = 403 {
            Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
            Do $$$AssertEquals(tEnvelope.%Get("code"), tExpected, "with the serving-path code")
            Do $$$AssertEquals(tEnvelope.%Get("error"), ##class(OcuPilot.Api.Error).#FORBIDDEN, "under the forbidden slug")
            Do $$$AssertEquals(tEnvelope.%Get("reason"), tReason, "and the set's own published sentence")
        }
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Enabled"), 1, "the application is still there, still enabled, after " _ tSpelling)
    }

    Set tSC = ..Act("disable", ..#TARGET, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC, "the disable request completes")
    Do $$$AssertEquals(tStatus2, 403, "and is refused too: " _ tBody2)
    If tStatus2 = 403 {
        Set tEnvelope2 = ##class(%DynamicObject).%FromJSON(tBody2)
        Do $$$AssertEquals(tEnvelope2.%Get("code"), tExpected, "with the serving-path code")
        Do $$$AssertEquals(tEnvelope2.%Get("error"), ##class(OcuPilot.Api.Error).#FORBIDDEN, "under the forbidden slug")
        Do $$$AssertEquals(tEnvelope2.%Get("reason"), tReason, "and the set's own published sentence")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Enabled"), 1, "and the application is untouched")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#TARGET), "the temporary record is removed")
}

/// <p>One <code>POST</code> of <var>pAction</var> against <var>pId</var> on the web applications
/// screen, as the test account.</p>
Method Act(pAction As %String, pId As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/screens/" _ ..#ACTIONSCREEN _ "/action", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBody, .pHeaders, tRequest.%ToJSON(), "application/json")
}

/// <p>The shipped router's <code>UrlMap</code> as one string, read to the end: one
/// 32,000-character bite would silently truncate a map that outgrew it.</p>
Method RouterMap() As %String
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Api.Router", "UrlMap", , .tOpenSC)
    Do $$$AssertTrue($IsObject(tXData), "the router's UrlMap is readable")
    If '$IsObject(tXData) Quit ""
    Do tXData.Data.Rewind()
    Set tMap = ""
    While 'tXData.Data.AtEnd {
        Set tMap = tMap _ tXData.Data.Read(32000)
    }
    Quit tMap
}

/// <p>AD-13, AD-10: the agent's own delete of one of OcuPilot's applications is refused
/// <code>PROHIBITED.SERVINGPATH</code> over the wire, and a non-canonical spelling of the same
/// path earns the same verdict -- the canonical form is what
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ServesOcuPilot</method> is asked about.</p>
/// <p>Driven against this class's own probe application, marked as OcuPilot's own through
/// install's record for the span of this method, so no write reaches a real serving
/// application.</p>
/// <p><b>This is the arm AD-53 opened.</b> A delete carries no changed field, so the serving-path
/// predicate cannot rest on the diff.</p>
/// <p>Mutation (Rule 19): restore <code>pServes &amp;&amp; +$Get(pChanged)</code> in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WebApplication</method> -- both legs pass the arm,
/// the confirm reaches the vendor delete, and the survival assertion goes red.</p>
Method TestTheAgentsDeleteOfOcuPilotsOwnApplicationIsRefusedOverTheWire()
{
    Do ##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#TARGET)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).GuardedRecord("probe", ..#TARGET, "created"), "the probe application is recorded as OcuPilot's own for this leg")
    Set tExpected = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGPATH")

    Set tBefore = ..Snapshot(.tFresh)
    Do $$$AssertNotEquals(tBefore, "", "the probe application is there to begin with")
    If tBefore '= "" {
        Set tSpellings = $ListBuild(..#TARGET, $ZConvert(..#TARGET, "U") _ "/")
        For tI = 1:1:$ListLength(tSpellings) {
            Set tKey = ..SeedDelete($List(tSpellings, tI), tFresh)
            Do $$$AssertNotEquals(tKey, "", "a delete proposal named " _ $List(tSpellings, tI) _ " was seeded, so this leg measures something")
            If tKey = "" Continue
            Set tSC = ..Call(tKey, .tStatus, .tBody, .tHeaders)
            Do $$$AssertStatusOK(tSC, "the confirm of a delete named " _ $List(tSpellings, tI) _ " completes")
            Do $$$AssertEquals(tStatus, 403, "and is refused: " _ tBody)
            If tStatus = 403 {
                Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
                Do $$$AssertEquals(tEnvelope.%Get("code"), tExpected, "with the serving-path code")
                Do $$$AssertEquals(tEnvelope.%Get("reason"), ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tExpected), "and the set's own published sentence")
            }
            Do $$$AssertEquals(..Snapshot(.tAfter), tBefore, "and the application is still there, byte for byte")
        }
    }

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#TARGET), "the temporary record is removed")
}

/// <p>One stored <code>webapp.list.delete</code> proposal against <var>pPath</var>, minted the way
/// the delete tool mints one: the fresh read projected to the declared fingerprint subject, the
/// tool's own removal rows as the diff, and the digest over that projection.</p>
ClassMethod SeedDelete(pPath As %String, pFresh As %DynamicObject) As %String
{
    Set tKey = ""
    Try {
        Set tClass = "OcuPilot.Screen.Tool.WebAppDelete"
        Set tSubject = $ClassMethod(tClass, "FingerprintSubject")
        If $$$ISERR(##class(OcuPilot.Kernel.Proposal.Fingerprint).Projection(pFresh, tSubject, .tPayload)) Quit
        If $$$ISERR($ClassMethod(tClass, "StateDiff", pFresh, .tRows, .tProblem)) Quit
        If tProblem '= "" Quit
        If $$$ISERR(##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tPayload, "", .tPrint, tSubject)) Quit
        If $$$ISERR(##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", pPath, .tRef)) Quit
        Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        ; A proposal is confirmable only from a turn that finished normally, so the row carries one
        ; -- the same completed probe turn every seeded row in this class carries.
        If $$$ISERR(##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .tTurnKey)) Quit
        Kill tValues
        Set tValues("user") = tUser
        Set tValues("turnKey") = tTurnKey
        Set tValues("toolName") = $Parameter(tClass, "TOOLNAME")
        Set tValues("targetRef") = tRef
        Set tValues("fingerprint") = tPrint
        Set tValues("arguments") = {"Name": (pPath)}.%ToJSON()
        Set tValues("payload") = tPayload.%ToJSON()
        Set tValues("diff") = tRows.%ToJSON()
        Set tValues("unchangedCount") = 0
        Set tValues("destructive") = 1
        If $$$ISERR(##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey)) Set tKey = ""
    } Catch {
        Set tKey = ""
    }
    Quit tKey
}

/// <p>One <code>POST</code> of <var>pAction</var> against <var>pId</var> on the web applications
/// screen, as <var>pUser</var> -- the least-privileged leg's own call, never the test account.</p>
Method ActAs(pAction As %String, pId As %String, pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/screens/" _ ..#ACTIONSCREEN _ "/action", pUser, pPassword, .pStatus, .pBody, .pHeaders, tRequest.%ToJSON(), "application/json")
}

/// <p>AD-8, AD-29, AD-53: a <b>real least-privileged principal</b> holding an administrative
/// resource but not <code>%Admin_Secure:USE</code> is refused the screen's own row action over
/// <code>POST /screens/:screen/action</code> 403 <code>AUTH.NOPRIVILEGE</code> naming that pair,
/// and this class's probe application does not move.</p>
/// <p>The principal holds <parameter>NONSECUREADMIN</parameter> at <code>USE</code> and the two
/// database reads, so the pair the refusal names is the only one it is short of: without the
/// first, the router's floor would refuse it <code>AUTH.NOADMIN</code> before the route ran.</p>
/// <p>Mutation (Rule 19): delete the pair check ahead of the fresh read in
/// <method>OcuPilot.Api.ScreenAction.Run</method> and recompile -- the port's own gate refuses the
/// read <code>PORT.ACCESSDENIED</code> naming no pair, and the code and failed-pair assertions go
/// red.</p>
Method TestAnAccountShortOfTheScreenPairIsRefusedTheRowActionNamingIt()
{
    Set tCodeResource = ..CodeDatabaseResource()
    Do $$$AssertNotEquals(tCodeResource, "", "the install namespace's code database resource resolves")
    If tCodeResource = "" Quit
    Set tSC = ..EnsureLeastPrivilegedPrincipal(..#PRINCIPALPASSWORD, ..#NONSECUREADMIN _ ":U,%DB_IRISSYS:R," _ tCodeResource _ ":R")
    Do $$$AssertStatusOK(tSC, "a principal short of only the screen's administrative pair is created: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit

    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Secure", "USE"), 0, "it holds no %Admin_Secure:USE, which is the pair a row action requires")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, ..#NONSECUREADMIN, "USE"), 1, "it does hold an administrative resource, so the router's own floor is cleared")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%DB_IRISSYS", "READ"), 1, "and the security database read, so the administrative pair is the only one it is short of")

    Set tBefore = ..Snapshot(.tFresh)
    Do $$$AssertNotEquals(tBefore, "", "the probe application is there to act on")
    If tBefore = "" Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Enabled"), 1, "and starts enabled, so a permitted disable would have something to change")

    Set tSC = ..ActAs("disable", ..#TARGET, ..#PRINCIPALUSER, ..#PRINCIPALPASSWORD, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the row action request completes")
    Do $$$AssertEquals(tStatus, 403, "and is refused -- not 200, not the router's 403 with no body: " _ tBody)
    Do $$$AssertEquals((tBody [ "}{"), 0, "in exactly one envelope")
    If tStatus = 403 {
        Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tEnvelope.%Get("code"), ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "with the screen-privilege code, not AUTH.NOADMIN")
        Do $$$AssertEquals(tEnvelope.%Get("error"), ##class(OcuPilot.Api.Error).#FORBIDDEN, "under the forbidden slug")
        Do $$$AssertEquals($Select($IsObject(tEnvelope.%Get("detail")): tEnvelope.%Get("detail").%Get("failedPair"), 1: ""), "%Admin_Secure:USE", "naming the pair that failed")
    }
    Do $$$AssertEquals(..Snapshot(.tAfter), tBefore, "and the probe application's properties on the instance are what they were")
}

/// <p>AD-6, AD-34: a delete proposal whose target was removed after it was made is refused 409
/// <code>PROPOSAL.TARGETCHANGED</code> at the confirm. The row closes with the target-changed
/// reason and its token is never spent, and the write comes only after that claim, so nothing
/// reaches the port.</p>
/// <p>Against this class's own probe application, removed out of band between the proposal and
/// the confirm, and put back afterwards, guarded as <method>OnBeforeAllTests</method> guarded it, so
/// the later methods in this class see what they expect.</p>
/// <p>Mutation (Rule 19): set <code>pMatches = 1</code> where the re-read fails in
/// <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> and recompile it with its
/// subclasses -- the confirm claims the row and reaches the vendor delete, and the 409, the code,
/// the closed row and the unspent token go red.</p>
Method TestADeleteWhoseTargetWasRemovedIsRefusedAndWritesNothing()
{
    Set tBefore = ..Snapshot(.tFresh)
    Do $$$AssertNotEquals(tBefore, "", "the probe application is there when the proposal is made")
    If tBefore '= "" {
        Set tKey = ..SeedDelete(..#TARGET, tFresh)
        Do $$$AssertNotEquals(tKey, "", "a delete proposal was seeded against it, so this leg measures something")
        If tKey '= "" {
            Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveWriteTarget(), "the application is removed out of band after the proposal")
            Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Enabled"), "", "and the instance no longer holds it")

            Set tSC = ..Call(tKey, .tStatus, .tBody, .tHeaders)
            Do $$$AssertStatusOK(tSC, "the confirm request completes")
            Do $$$AssertEquals(tStatus, 409, "and is refused: " _ tBody)
            Do $$$AssertEquals((tBody [ "}{"), 0, "in exactly one envelope")
            If tStatus = 409 {
                Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
                Do $$$AssertEquals(tEnvelope.%Get("code"), ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "with the target-changed code")
            }
            Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), ##class(OcuPilot.Kernel.State.Propose).#STATECANCELED, "the row is closed")
            Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "ClosedReason"), ##class(OcuPilot.Kernel.State.Propose).#REASONTARGETCHANGED, "for the target-changed reason")
            Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 0, "and its token was never spent, so the write that follows the claim never ran")
        }
    }

    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget($Namespace), "the probe application is put back for the rest of this class")
    Do $$$AssertStatusOK(..Guard(..#GUARDRESOURCE), "and guarded as OnBeforeAllTests guarded it")
}

/// <p>AC4, AD-13: a delete the agent's own tool mints against a re-cased, slash-suffixed spelling
/// of an application OcuPilot is served through is stored under the canonical reference, and its
/// confirm is refused <code>PROHIBITED.SERVINGPATH</code> with the application untouched.</p>
/// <p>Minted through <method>OcuPilot.Screen.Tool.WebAppDelete.View</method>, the entry point the
/// model reaches, on a completed probe turn, and confirmed through the shipped transition in this
/// process as the user the tool minted it for: a tool runs as its caller, and only the minting
/// user may confirm. This class's probe application is recorded as OcuPilot's own for the span of
/// this method, so no write reaches a real serving application.</p>
/// <p>Mutations (Rule 19): build the target reference in
/// <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> from the id as supplied rather than
/// through <method>OcuPilot.Kernel.EntityRef.Key</method> -- the canonical-reference assertions go
/// red; or restore <code>pServes &amp;&amp; +$Get(pChanged)</code> in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WebApplication</method> -- the refusal and the
/// survival assertions go red.</p>
Method TestTheAgentsDeleteMintedUnderAnotherSpellingIsStoredCanonicalAndRefused()
{
    Do ##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#TARGET)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).GuardedRecord("probe", ..#TARGET, "created"), "the probe application is recorded as OcuPilot's own for this leg")
    Set tExpected = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGPATH")
    Set tSpelling = $ZConvert(..#TARGET, "U") _ "/"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", ..#TARGET, .tCanonical), "the canonical reference is built from the path as the instance stores it")

    Set tBefore = ..Snapshot(.tFresh)
    Do $$$AssertNotEquals(tBefore, "", "the probe application is there to begin with")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded for the minting user")
    If (tBefore '= "") && $$$ISOK(tSC) {
        Set tArgs = {}
        Do tArgs.%Set(##class(OcuPilot.Screen.Tool.WebAppDelete).IdArgument(), tSpelling, "string")
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
        Set tMintSC = ##class(OcuPilot.Screen.Tool.WebAppDelete).View("", tArgs, 0, .tProposal, .tMintHttp, .tMintFault)
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
        Do $$$AssertStatusOK(tMintSC, "the tool mints a proposal for " _ tSpelling _ " (HTTP " _ +$Get(tMintHttp) _ ")")
        Do $$$AssertTrue($IsObject($Get(tProposal)), "and answers it")
        If $IsObject($Get(tProposal)) {
            Set tKey = tProposal.%Get("proposalId")
            Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "TargetRef"), tCanonical, "the stored target reference is the canonical one, not the spelling the tool was handed")
            Do $$$AssertEquals(tProposal.%Get("target").%Get("id"), ..#TARGET, "and so is the target the card is drawn with")

            Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
            Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
            Do $$$AssertEquals(tHttp, 403, "with 403")
            Do $$$AssertEquals(tCode, tExpected, "and the serving-path code")
            Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "the row was not claimed")
            Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 0, "and the token is unspent")
            Do $$$AssertEquals(..Snapshot(.tAfter), tBefore, "and the application is still there, byte for byte")
        }
    }

    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#TARGET), "the temporary record is removed")
}

/// <p>Story 5.8's residual: the pairs-before-prohibited reorder that fixed DW-1208 (a caller short
/// a pair reaching <method>Prohibited.Target</method>'s live port read and being answered a generic
/// internal error instead of <code>AUTH.NOPRIVILEGE</code>) is pinned as <code>%All</code> at the
/// unit tier (<class>OcuPilot.Test.ProposalConfirm</class>'s two
/// <method>TestThePrivilegeGateAnswersBefore...</method> methods) and as a real least-privileged
/// principal at the browser tier, but only against <code>/csp/myapp</code>
/// (<file>ui/browser/proposal-demo.browser-spec.mjs</file>'s AC4 leg). AC5's own serving-path
/// refusal reads live state through that same <method>Target</method> call, and had never been
/// measured for a caller who is not <code>%All</code>: the over-the-wire legs in this class run
/// as <code>%All</code> (this class's own header), and
/// <method>OcuPilot.Test.ProhibitedByEffect.TestAChangeToOcuPilotsOwnApplicationIsRefused</method>
/// replaces the port with a fixture and never asks a real privilege question at all. So nobody had
/// proven that a holder of exactly the write's two pairs reaches
/// <code>PROHIBITED.SERVINGPATH</code> for one of OcuPilot's own applications, rather than the same
/// internal error DW-1208 named for a different gate.</p>
/// <p><b>Drives this class's own probe application, not the instance's real API or shell
/// application.</b> Install's own "recorded" table -- the same mechanism
/// <method>OcuPilot.Test.ProhibitedByEffect.TestAChangeToOcuPilotsOwnApplicationIsRefused</method>
/// exercises for its <parameter>RECORDEDPATH</parameter> leg -- marks <parameter>TARGET</parameter>
/// as OcuPilot's own for exactly the span of this test, so the serving-path predicate fires over
/// the real HTTP/port path (needed to reach the privilege gate this test is actually about) without
/// any write ever reaching the instance's own live-serving applications. The record is removed
/// before this method returns and again, defensively, in <method>OnAfterOneTest</method>.</p>
/// <p>Reads only past the record itself: disabling the (recorded) probe application is refused
/// before the port <code>PUT</code> is ever reached, so nothing here writes to it, and the
/// application is read back afterwards to confirm that. The principal's grant is checked on the
/// instance rather than assumed (Rule 19).</p>
/// <p>Mutation (Rule 19): drop the <method>DeleteByPath</method>/<method>GuardedRecord</method>
/// pair -- with <parameter>TARGET</parameter> never recorded, this leg's own proposal reaches the
/// same <code>AUTHORIZATION</code>/<code>UNAUTHENTICATED</code>/<code>DISPATCH</code> family
/// <method>Weakened</method>'s legs pin instead of <code>SERVINGPATH</code>, which reddens the code
/// assertion. The order fix itself is pinned by
/// <method>OcuPilot.Test.ProposalConfirm.TestThePrivilegeGateAnswersBeforeTheProhibitedSet</method>
/// and is <b>not</b> what this test falsifies: this principal holds the pair
/// <method>Target</method>'s own read requires, so that read succeeds regardless of gate order, and
/// this test pins that the fix generalizes to AC5's refusal for a caller who is not
/// <code>%All</code>, not the order itself.</p>
Method TestOcuPilotsOwnServingPathRefusesALeastPrivilegedPrincipal()
{
    Set tCodeResource = ..CodeDatabaseResource()
    Do $$$AssertNotEquals(tCodeResource, "", "the install namespace's code database resource resolves")
    If tCodeResource = "" Quit
    Set tSC = ..EnsureLeastPrivilegedPrincipal(..#PRINCIPALPASSWORD, "%Admin_Secure:U,%DB_IRISSYS:R," _ tCodeResource _ ":R")
    Do $$$AssertStatusOK(tSC, "the least-privileged principal is created")
    If $$$ISERR(tSC) Quit

    ; Measured, not assumed: the principal holds exactly the write's two pairs and not the
    ; permission DW-1208 replaced.
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Secure", "USE"), 1, "the principal holds %Admin_Secure:USE")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%DB_IRISSYS", "READ"), 1, "and %DB_IRISSYS:READ")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Secure", "WRITE"), 0, "and not the WRITE permission DW-1208 replaced")

    Do ##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#TARGET)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).GuardedRecord("probe", ..#TARGET, "created"), "the probe application is recorded as OcuPilot's own for this leg")

    Set tBefore = ..Snapshot(.tFresh)
    If tBefore '= "" {
        Set tKey = ..SeedForPrincipal(..#PRINCIPALUSER, ..#TARGET, tFresh, "Enabled", 0, "boolean")
        If tKey '= "" {
            Set tSC = ..CallAs(tKey, ..#PRINCIPALUSER, ..#PRINCIPALPASSWORD, .tStatus, .tBody, .tHeaders)
            Do $$$AssertStatusOK(tSC, "the request completes")
            Do $$$AssertEquals(tStatus, 403, "and is refused -- not a 500 from the live read, not a 401: " _ tBody)
            Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
            Do $$$AssertEquals(tEnvelope.%Get("code"), $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGPATH"), "with the serving-path code, not AUTH.NOPRIVILEGE and not an internal error")
            Do $$$AssertEquals(tEnvelope.%Get("error"), ##class(OcuPilot.Api.Error).#FORBIDDEN, "under the forbidden slug")
            Do $$$AssertEquals(..Snapshot(.tAfter), tBefore, "the probe application on the instance is what it was")
        }
    }

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#TARGET), "the temporary record is removed")
}

Method TestADroppedResourceIsRefusedOverTheWire()
{
    Do ..Weakened("Resource", "", "string", $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "AUTHORIZATION"))
}

/// <p>DW-1207's second field against the same real application: adding the unauthenticated bit to
/// a probe application the fixture created reading 32.</p>
/// <p>Mutation: as above, and with the same reach -- <code>AutheEnabled</code> is one of the
/// fields the tool admits, so this row is mint-shaped too and the untouched-application clause is
/// load-bearing.</p>
Method TestAWeakenedAuthenticationIsRefusedOverTheWire()
{
    Do ..Weakened("AutheEnabled", 96, "number", $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "UNAUTHENTICATED"))
}

/// <p>Repointing the dispatch class is refused at the write as well as being absent from the tool
/// set, so a proposal that reached confirm by any other route is still refused.</p>
/// <p>Mutation: as above, but this row is hand-seeded -- the tool cannot set
/// <code>DispatchClass</code>, so no mint produces one and its stored payload cannot digest to its
/// fingerprint. Removing the set therefore reddens the 403, the code and the live-row clauses, and
/// the row is refused 409 <code>PROPOSAL.TARGETCHANGED</code> by the gate behind the set rather
/// than reaching the port -- so the untouched-application clause stays green here by construction
/// and is not what this leg pins.</p>
Method TestARepointedDispatchClassIsRefusedOverTheWire()
{
    Do ..Weakened("DispatchClass", "OcuPilot.Api.Router", "string", $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "DISPATCH"))
}

/// <p>DW-1352: the set normalizes a web application's name exactly as far as this instance
/// resolves it. For every path the install roster declares, a spelling the shipped port's own
/// <code>GET</code> answers that same application for must normalize to it, and one the port
/// answers nothing for must not -- so a re-cased or slash-suffixed id cannot reach OcuPilot's own
/// API through the endpoint while the serving-path predicate reads the target as somebody
/// else's.</p>
/// <p>The instance is the authority here, not a remembered rule: each leg asks the port and the set
/// the same question and compares the two answers, so a build that normalized differently reddens
/// this rather than passing silently.</p>
/// <p><b>It reads only:</b> no proposal is seeded, no application is modified, and the probe
/// application plays no part.</p>
/// <p>Mutations: drop the trailing-slash loop from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.NormalizedPath</method>, or make it strip a leading
/// slash as well -- the first goes red on the slash-suffixed spellings and the second on the
/// leading-slash-less one, because in each case the set and the instance disagree.</p>
Method TestTheSetNormalizesAPathTheWayTheInstanceResolvesIt()
{
    Set tKeys = ##class(OcuPilot.Install.Roster).Keys()
    Do $$$AssertNotEquals(tKeys, "", "the roster declares its application keys")
    For tI = 1:1:$Length(tKeys, ",") {
        Set tSC = ##class(OcuPilot.Install.Roster).Application($Piece(tKeys, ",", tI), .tApp)
        Do $$$AssertStatusOK(tSC, "the roster reads application " _ $Piece(tKeys, ",", tI))
        If $$$ISERR(tSC) Continue
        Set tPath = tApp.path
        Set tCanonical = ..Read(tPath)
        Do $$$AssertNotEquals(tCanonical, "", tPath _ " reads back through the port, so the comparison below has an answer to compare with")
        If tCanonical = "" Continue
        ; Three spellings this build resolves and three it does not, so the agreement is asserted
        ; in both directions rather than only where the set says yes.
        Set tForms = $ListBuild($ZConvert(tPath, "U"), tPath _ "/", $ZConvert(tPath, "U") _ "///")
        Set tForms = tForms _ $ListBuild($Extract(tPath, 2, $Length(tPath)), "/" _ tPath, tPath _ " ")
        For tJ = 1:1:$ListLength(tForms) {
            Set tForm = $List(tForms, tJ)
            Set tResolves = (..Read(tForm) = tCanonical)
            Set tNormalizes = (##class(OcuPilot.Kernel.Proposal.Prohibited).NormalizedPath(tForm) = ##class(OcuPilot.Kernel.Proposal.Prohibited).NormalizedPath(tPath))
            Do $$$AssertEquals(tNormalizes, tResolves, "the set and the instance agree about '" _ tForm _ "', which the instance resolves to " _ tPath _ ": " _ tResolves)
        }
    }
}

/// <p>AC1, AD-8 as amended and AD-29: a <b>real least-privileged principal</b> -- holding the Users
/// screen's own two pairs plus the code-database read the router's floor needs, and <b>not</b>
/// <code>%All</code> -- confirms a user write over HTTP, the vendor <code>PUT</code> lands, and the
/// ledger row records the pairs it exercised.</p>
/// <p><b>Why this leg exists rather than a <code>%All</code> one.</b> AD-29 requires a screen's
/// declared pair set to be established two ways together: the backing class's own check, and a real
/// least-privileged principal on a throwaway. DW-1208's defect was found exactly because
/// <code>%All</code> passes every gate, so a set that is one pair short reads green. Everything
/// else in <class>OcuPilot.Test.UserUpdate</class> runs as the suite's own <code>%All</code>
/// account; this is the one measurement that says the declared set is sufficient for the vendor
/// <code>Security.User</code> <code>PUT</code> and not merely for its <code>GET</code>.</p>
/// <p>The account it writes to is <class>OcuPilot.Test.ProposalFixture</class>'s own, created and
/// removed here, and the principal's own grants are read off the instance rather than assumed from
/// the role's resource string.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Secure:U</code> from the principal's role -- the
/// confirm answers 403 <code>AUTH.NOPRIVILEGE</code> and the write assertions go red, which is what
/// separates "this account may do it" from "some account may".</p>
Method TestALeastPrivilegedPrincipalConfirmsAUserWriteOverTheWire()
{
    Set tCodeResource = ..CodeDatabaseResource()
    Do $$$AssertNotEquals(tCodeResource, "", "the install namespace's code database resource resolves")
    If tCodeResource = "" Quit
    Set tSC = ..EnsureLeastPrivilegedPrincipal(..#PRINCIPALPASSWORD, ..#DECLAREDPAIRSONLY _ "," _ tCodeResource _ ":R")
    Do $$$AssertStatusOK(tSC, "the least-privileged principal is created")
    If $$$ISERR(tSC) Quit

    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Secure", "USE"), 1, "it holds the Users screen's administrative pair")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%DB_IRISSYS", "READ"), 1, "and its database read")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Secure", "WRITE"), 0, "and not the WRITE permission AD-8's amendment replaced")
    Set tRoles = ""
    Do $SYSTEM.Security.GetUserRecursedRoleSet(..#PRINCIPALUSER, .tRoles)
    Do $$$AssertEquals(tRoles [ "%All", 0, "and holds no %All by any path: " _ tRoles)

    ; Any ledger row an earlier run of this leg left behind goes first: the read below takes the
    ; one row for this principal, and the ledger outlives its subject by design (AD-37), so a
    ; second run would otherwise read a row from the first.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForUser(..#PRINCIPALUSER), "any ledger row an earlier run left for this principal is removed")

    Set tSC = ##class(OcuPilot.Test.ProposalFixture).EnsureUser(..#USERACCOUNT, "", 0, .tCreated)
    Do $$$AssertStatusOK(tSC, "the probe account is created disabled: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Try {
        Kill tQuery
        Set tQuery("name") = ..#USERACCOUNT
        Set tReadSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
        Do $$$AssertStatusOK(tReadSC, "it reads fresh through the shipped port")
        Do $$$AssertTrue($IsObject(tFresh), "the port answered the account, so the assertions below run over something")
        If $IsObject(tFresh) {
            ; AC1's own change: an enable PLUS an ordinary role add. The role half matters on its
            ; own -- assigning a role is the operation most likely to need a privilege beyond
            ; %Admin_Secure:USE on the vendor side, and a flag flip would not find that out.
            Set tRoleAdd = {}
            Do tRoleAdd.%Set("Roles", [])
            Do tRoleAdd.%Get("Roles").%Push($Parameter("OcuPilot.Test.ProposalFixture", "USERORDINARYROLE"))
            Set tKey = ..SeedForPrincipal(..#PRINCIPALUSER, ..#USERACCOUNT, tFresh, "Enabled", 1, "boolean", ..#USERTOOL, "user", tRoleAdd)
            ; Without this the leg reports green having measured nothing on any path that answers
            ; "" -- Minted's "resolved to no entry" status is returned, not asserted.
            Do $$$AssertNotEquals(tKey, "", "a proposal was seeded for the least-privileged principal")
            If tKey '= "" {
                Set tSC = ..CallAs(tKey, ..#PRINCIPALUSER, ..#PRINCIPALPASSWORD, .tStatus, .tBody, .tHeaders)
                Do $$$AssertStatusOK(tSC, "the confirm request completes")
                Do $$$AssertEquals(tStatus, 200, "and the write is allowed -- the declared set is sufficient for the vendor PUT: " _ tBody)
                Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
                Do $$$AssertEquals(tEnvelope.%Get("state"), $Parameter("OcuPilot.Kernel.State.Propose", "STATECONFIRMED"), "the row is confirmed: " _ tBody)
                Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).UserField(..#USERACCOUNT, "Enabled"), 1, "and the account is enabled on the instance")
                Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).UserField(..#USERACCOUNT, "Roles"), $Parameter("OcuPilot.Test.ProposalFixture", "USERORDINARYROLE"), "and holds the role the same confirm added, so the declared set is sufficient for a role assignment and not only for a flag")
                Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT RequiredPairs, Status FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(UserName) = ? AND %EXACT(Kind) = ?", ..#PRINCIPALUSER, $Parameter("OcuPilot.Kernel.State.Ledger", "KINDWRITE"))
                Do $$$AssertTrue(tRS.%Next(), "the confirmed write left a ledger row for that principal")
                Do $$$AssertEquals(tRS.%Get("Status"), "ok", "recorded ok")
                Do $$$AssertEquals(tRS.%Get("RequiredPairs"), ##class(OcuPilot.Kernel.Audit.Ledger).PairsToString($ClassMethod("OcuPilot.Screen.Tool.UserUpdate", "PrivilegePairs", "", .tResolved), .tTruncated), "carrying the pairs it exercised")

                ; A second confirm, a DISABLE, because that is the only path that enters the %All
                ; census -- and the census asks the instance for another account's recursed role
                ; set, which is the heaviest privilege this story's kernel code demands. Asserted
                ; rather than inferred from a doc comment: if the declared pair set cannot run it,
                ; the status propagates and the confirm answers 500 for every disable an operator
                ; attempts, while every %All-run leg stays green.
                Set tReadSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "GET", .tQuery, "", .tAfter, .tHttp, .tFault)
                Do $$$AssertStatusOK(tReadSC, "the enabled account reads fresh again")
                If $IsObject(tAfter) {
                    Set tOffKey = ..SeedForPrincipal(..#PRINCIPALUSER, ..#USERACCOUNT, tAfter, "Enabled", 0, "boolean", ..#USERTOOL, "user")
                    Do $$$AssertNotEquals(tOffKey, "", "a disable proposal was seeded for the same principal")
                    If tOffKey '= "" {
                        Set tSC = ..CallAs(tOffKey, ..#PRINCIPALUSER, ..#PRINCIPALPASSWORD, .tOffStatus, .tOffBody, .tOffHeaders)
                        Do $$$AssertStatusOK(tSC, "the disable confirm request completes")
                        Do $$$AssertEquals(tOffStatus, 200, "and the census ran to completion under the declared pair set -- no 500: " _ tOffBody)
                        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).UserField(..#USERACCOUNT, "Enabled"), 0, "the account is disabled on the instance")
                    }
                }
            }
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the leg completes without raising")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveUser(..#USERACCOUNT), "the probe account is removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForUser(..#PRINCIPALUSER), "and so is the ledger row this leg wrote")
}

/// <p>The auditing configuration as the shipped port answers it now, in <var>pFresh</var>, with
/// <code>1</code> when it answered an object at all. The endpoint's one-property read, taken
/// through the same port the confirm re-reads it with, so the seeded row's fingerprint is the one
/// that confirm recomputes.</p>
Method AuditingFresh(Output pFresh As %DynamicObject) As %Boolean
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery($ClassMethod(..#AUDITINGTOOLCLASS, "IdParam")) = ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke($ClassMethod(..#AUDITINGTOOLCLASS, "Endpoint"), "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the auditing configuration reads fresh through the shipped port: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) || '$IsObject(tFresh) Quit 0
    Set pFresh = tFresh
    Quit 1
}

/// <p>DW-1452: <parameter>AUDITINGMETHOD</parameter> names a test method this class actually
/// declares.</p>
/// <p><b>Without this, a rename un-skips the gate silently.</b>
/// <method>OnBeforeOneTest</method> compares the running method's name against that parameter, and
/// a comparison against a name nothing answers to is simply never true -- so the auditing toggle
/// would run on an unarmed container with no refusal and no skip, which is the state DW-1452 was
/// filed about in the first place.</p>
/// <p>Mutation (Rule 19): point <parameter>AUDITINGMETHOD</parameter> at a name this class does not
/// declare -- this goes red on the dictionary leg.</p>
Method TestTheAuditingMethodParameterNamesAMethodThisClassDeclares()
{
    Set tName = ..#AUDITINGMETHOD
    Do $$$AssertNotEquals(tName, "", "the class names the method AUDITVARIABLE gates")
    Do $$$AssertTrue(##class(%Dictionary.CompiledMethod).IDKEYExists($ClassName(), tName), $ClassName() _ " declares a method named " _ tName)
    Do $$$AssertEquals($Extract(tName, 1, 4), "Test", "and it is a method the framework runs, not a helper")
    Do $$$AssertNotEquals(..#AUDITVARIABLE, "", "and the variable it gates on is still declared, which ci.test.mjs holds against ci-throwaway.sh")
}

/// <p>Seed one auditing proposal owned by <parameter>PRINCIPALUSER</parameter> setting
/// <code>Enabled</code> to <var>pEnabled</var> over <var>pFresh</var>, and answer its id.</p>
Method SeedAuditing(pFresh As %DynamicObject, pEnabled As %Boolean) As %String
{
    Quit ..SeedForPrincipal(..#PRINCIPALUSER, ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID, pFresh, $Parameter(..#AUDITINGTOOLCLASS, "PERMITTEDFIELDS"), ''pEnabled, "boolean", $Parameter(..#AUDITINGTOOLCLASS, "TOOLNAME"), $ClassMethod(..#AUDITINGSCREEN, "PrimaryEntityType"))
}

/// <p>AC4, AD-8 as amended and AD-29: a <b>real least-privileged principal</b> -- holding the
/// auditing screen's own two pairs plus the code-database read the router's floor needs, and
/// <b>not</b> <code>%All</code> -- confirms the auditing write over HTTP, and this instance's
/// auditing is off on the instance afterwards.</p>
/// <p><b>Why this leg exists rather than a <code>%All</code> one.</b> AD-29 requires a screen's
/// declared pair set to be established two ways together: the backing class's own check, and a real
/// least-privileged principal on a throwaway. Everything else that confirms this write runs as the
/// suite's own <code>%All</code> account, which passes every gate, so a set one pair short of what
/// the vendor <code>Security.Audit.Enabled</code> <code>PUT</code> needs would read green. This is
/// the one measurement that says the declared set is sufficient for that <code>PUT</code> and not
/// merely for its <code>GET</code>.</p>
/// <p><b>It turns this instance's auditing off for real</b>, which is why
/// <parameter>AUDITVARIABLE</parameter> arms this method and <method>OnBeforeOneTest</method>
/// skips it where that variable does not read 1. Auditing is restored in a frame of its own
/// after <code>Try</code>/<code>Catch</code> -- a raise skips a method's tail -- and again in
/// <method>OnAfterOneTest</method>, which asserts the restore worked.</p>
/// <p>Mutation (Rule 19): set
/// <parameter>OcuPilot.Screen.Tool.AuditingUpdate.WRITEPERMISSION</parameter> back to
/// <code>"WRITE"</code> and recompile the package -- no IRIS-shipped role grants an administrative
/// resource at <code>WRITE</code>, so the confirm answers 403 and the auditing-off assertion goes
/// red, which is what separates "this account may do it" from "some account may".</p>
Method TestALeastPrivilegedPrincipalConfirmsTheAuditingWriteOverTheWire()
{
    ; The skip is the only thing standing between this body and a real auditing disable, and a
    ; parameter naming a real method does not establish that the skip still runs. Reaching this
    ; line unarmed means OnBeforeOneTest is no longer wired, so say so here rather than turn the
    ; instance's auditing off and pass.
    Do $$$AssertEquals($System.Util.GetEnviron(..#AUDITVARIABLE), 1, ..#AUDITVARIABLE _ " reads 1 wherever this body runs -- OnBeforeOneTest skips this method where it does not")
    If $System.Util.GetEnviron(..#AUDITVARIABLE) '= 1 Quit

    Set tCodeResource = ..CodeDatabaseResource()
    Do $$$AssertNotEquals(tCodeResource, "", "the install namespace's code database resource resolves")
    If tCodeResource = "" Quit
    Set tSC = ..EnsureLeastPrivilegedPrincipal(..#PRINCIPALPASSWORD, ..#DECLAREDPAIRSONLY _ "," _ tCodeResource _ ":R")
    Do $$$AssertStatusOK(tSC, "the least-privileged principal is created: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit

    ; Measured off the instance, not assumed from the role's resource string.
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Secure", "USE"), 1, "it holds the auditing screen's administrative pair")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%DB_IRISSYS", "READ"), 1, "and its database read")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Secure", "WRITE"), 0, "and not the WRITE permission AD-8's amendment replaced")
    Set tRoles = ""
    Do $SYSTEM.Security.GetUserRecursedRoleSet(..#PRINCIPALUSER, .tRoles)
    Do $$$AssertEquals(tRoles [ "%All", 0, "and holds no %All by any path: " _ tRoles)

    Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).AuditEnabled(), 1, "this instance starts audited, so the confirm below has something to change")
    Try {
        If ..AuditingFresh(.tFresh) {
            Set tKey = ..SeedAuditing(tFresh, 0)
            Do $$$AssertNotEquals(tKey, "", "a disable proposal was seeded for the least-privileged principal")
            If tKey '= "" {
                Set tSC = ..CallAs(tKey, ..#PRINCIPALUSER, ..#PRINCIPALPASSWORD, .tStatus, .tBody, .tHeaders)
                Do $$$AssertStatusOK(tSC, "the confirm request completes")
                Do $$$AssertEquals(tStatus, 200, "and the write is allowed -- the declared set is sufficient for the vendor PUT: " _ tBody)
                Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
                Do $$$AssertEquals(tEnvelope.%Get("state"), $Parameter("OcuPilot.Kernel.State.Propose", "STATECONFIRMED"), "the row is confirmed: " _ tBody)
                Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).AuditEnabled(), 0, "and this instance's auditing is off on the instance, not merely reported off")
            }
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the leg completes without raising")
    }
    ; Its own frame: a raise above skips the method's tail, and this instance must not be left
    ; unaudited for the rest of the sweep whatever happened (AC7).
    Do ##class(OcuPilot.Test.AuditingUpdate).RestoreAuditing()
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).AuditEnabled(), 1, "and this instance is audited again")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForUser(..#PRINCIPALUSER)
}

/// <p>AC4's second half, AD-8: a caller holding an administrative resource but <b>not</b>
/// <code>%Admin_Secure:USE</code> is refused the auditing write 403
/// <code>AUTH.NOPRIVILEGE</code> naming that pair, and this instance's auditing does not
/// move.</p>
/// <p>The principal deliberately holds <parameter>NONSECUREADMIN</parameter> at <code>USE</code>
/// and the security database read, so the only pair it is short of is the one the refusal must
/// name: without the first it would be refused <code>AUTH.NOADMIN</code> by the router's floor
/// before the screen's own gate ran, which is a different refusal about a different thing.</p>
/// <p>Mutation (Rule 19): remove the <code>%Admin_Secure:USE</code> pair from
/// <class>OcuPilot.Screen.Descriptor.AuditingConfig</class>'s declared privileges and recompile --
/// the confirm answers 200, the failed-pair and auditing-unmoved assertions go red, and the write
/// this account may not make lands.</p>
Method TestAnAccountShortOfTheAuditingPairIsRefusedTheNamedPair()
{
    Set tCodeResource = ..CodeDatabaseResource()
    Do $$$AssertNotEquals(tCodeResource, "", "the install namespace's code database resource resolves")
    If tCodeResource = "" Quit
    Set tSC = ..EnsureLeastPrivilegedPrincipal(..#PRINCIPALPASSWORD, ..#NONSECUREADMIN _ ":U,%DB_IRISSYS:R," _ tCodeResource _ ":R")
    Do $$$AssertStatusOK(tSC, "a principal short of only the administrative pair is created: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit

    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Secure", "USE"), 0, "it holds no %Admin_Secure:USE, which is the pair this write requires")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, ..#NONSECUREADMIN, "USE"), 1, "it does hold an administrative resource, so the router's own floor is cleared")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%DB_IRISSYS", "READ"), 1, "and the security database read, so the administrative pair is the only one it is short of")

    Set tBefore = ##class(OcuPilot.Test.AuditingUpdate).AuditEnabled()
    Do $$$AssertEquals(tBefore, 1, "this instance is audited before the refusal")
    If '..AuditingFresh(.tFresh) Quit
    Set tKey = ..SeedAuditing(tFresh, 0)
    Do $$$AssertNotEquals(tKey, "", "a disable proposal was seeded for that principal")
    If tKey = "" Quit

    Set tSC = ..CallAs(tKey, ..#PRINCIPALUSER, ..#PRINCIPALPASSWORD, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the confirm request completes")
    Do $$$AssertEquals(tStatus, 403, "and is refused -- not 200, not the router's 403 with no body: " _ tBody)
    Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tEnvelope.%Get("code"), ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "with the screen-privilege code, not AUTH.NOADMIN")
    Do $$$AssertEquals(tEnvelope.%Get("error"), ##class(OcuPilot.Api.Error).#FORBIDDEN, "under the forbidden slug")
    Do $$$AssertEquals($Select($IsObject(tEnvelope.%Get("detail")): tEnvelope.%Get("detail").%Get("failedPair"), 1: ""), "%Admin_Secure:USE", "naming the pair that failed")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).AuditEnabled(), tBefore, "and this instance's auditing did not move")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "the row was not claimed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 0, "and the token is unspent")
}

/// <p>AC11, AD-8, AD-29 (Story 5.11): a caller short of <code>%Admin_Task:USE</code> is refused
/// the task resume 403 <code>AUTH.NOPRIVILEGE</code> naming that pair, and the task stays
/// suspended.</p>
/// <p>The principal deliberately holds <parameter>NONSECUREADMIN</parameter> at <code>USE</code>
/// and the security database read, so the only pair it is short of is the one the refusal must
/// name: without the first it would be refused <code>AUTH.NOADMIN</code> by the router's floor
/// before the screen's own gate ran.</p>
/// <p><b>The state is asserted as well as the status, and only the status is load-bearing here.</b>
/// A bodyless write leaves nothing in a payload to inspect, so the task's own suspended state is
/// read back through <method>OcuPilot.Test.TaskResume.TaskSuspended</method> rather than from the
/// envelope. That read-back cannot fail under the mutation below -- the vendor's own
/// <code>ResourcesOR()</code> for <code>%Admin_Task</code> still stands behind both OcuPilot gates,
/// so a principal holding neither pair never reaches the write whatever this screen declares. It
/// is there as the belt to the status's braces, and the code and failed-pair assertions are what
/// the mutation reddens.</p>
/// <p>Mutation (Rule 19): answer
/// <code>$ListBuild($ListBuild("%DB_IRISSYS", "READ"))</code> from
/// <method>OcuPilot.Screen.Tool.TaskResume.PrivilegePairs</method> -- the one pair this principal
/// does hold -- and recompile: the screen gate no longer refuses, so the code and failed-pair
/// assertions go red. <b>Removing the pair from
/// <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class> is not the mutation</b>: the tool
/// re-adds it from <parameter>WRITERESOURCE</parameter>, and dropping it from both makes the
/// registry refuse the roster in <method>OnBeforeAllTests</method>, which reddens the class
/// without exercising this method at all.</p>
Method TestAnAccountShortOfTheTaskPairIsRefusedTheNamedPair()
{
    Set tCodeResource = ..CodeDatabaseResource()
    Do $$$AssertNotEquals(tCodeResource, "", "the install namespace's code database resource resolves")
    If tCodeResource = "" Quit
    Set tSC = ..EnsureLeastPrivilegedPrincipal(..#PRINCIPALPASSWORD, ..#NONSECUREADMIN _ ":U,%DB_IRISSYS:R," _ tCodeResource _ ":R")
    Do $$$AssertStatusOK(tSC, "a principal short of only the task pair is created: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit

    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Task", "USE"), 0, "it holds no %Admin_Task:USE, which is the pair this write requires")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, ..#NONSECUREADMIN, "USE"), 1, "it does hold an administrative resource, so the router's own floor is cleared")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%DB_IRISSYS", "READ"), 1, "and the security database read, so the task pair is the only one it is short of")

    Set tTaskSC = ##class(OcuPilot.Test.TaskResume).EnsureProbeTask(.tTaskId)
    Do $$$AssertStatusOK(tTaskSC, "a suspended probe task exists: " _ $System.Status.GetErrorText(tTaskSC))
    If $$$ISERR(tTaskSC) Quit
    Try {
        Do $$$AssertEquals(##class(OcuPilot.Test.TaskResume).TaskSuspended(tTaskId), 1, "and starts suspended, so a permitted resume would have something to change")
        Kill tQuery
        Set tQuery($ClassMethod(..#TASKTOOLCLASS, "IdParam")) = tTaskId
        Set tReadSC = ##class(OcuPilot.Port.AdminPort).Invoke($ClassMethod(..#TASKTOOLCLASS, "Endpoint"), $ClassMethod(..#TASKTOOLCLASS, "ReadType"), .tQuery, "", .tFresh, .tHttp, .tFault)
        Do $$$AssertStatusOK(tReadSC, "the task reads fresh through the shipped port with the tool's own request type")
        If $$$ISERR(tReadSC) || '$IsObject(tFresh) Quit
        Set tKey = ..SeedTaskResume(tTaskId, tFresh)
        Do $$$AssertNotEquals(tKey, "", "a resume proposal was seeded for that principal")
        If tKey = "" Quit

        Set tSC = ..CallAs(tKey, ..#PRINCIPALUSER, ..#PRINCIPALPASSWORD, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the confirm request completes")
        Do $$$AssertEquals(tStatus, 403, "and is refused -- not 200, not the router's 403 with no body: " _ tBody)
        Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tEnvelope.%Get("code"), ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "with the screen-privilege code, not AUTH.NOADMIN")
        Do $$$AssertEquals(tEnvelope.%Get("error"), ##class(OcuPilot.Api.Error).#FORBIDDEN, "under the forbidden slug")
        Do $$$AssertEquals($Select($IsObject(tEnvelope.%Get("detail")): tEnvelope.%Get("detail").%Get("failedPair"), 1: ""), "%Admin_Task:USE", "naming the pair that failed")
        Do $$$AssertEquals(##class(OcuPilot.Test.TaskResume).TaskSuspended(tTaskId), 1, "and the task is still suspended on the instance")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "the row was not claimed")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 0, "and the token is unspent")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the leg completes without raising")
    }
    ; Its own frame: this class does not own the probe task's lifetime, so it leaves the instance
    ; without one whatever happened above.
    Do ##class(OcuPilot.Test.TaskResume).DeleteProbeTask(tTaskId)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForUser(..#PRINCIPALUSER)
}

/// <p>AD-29's second half for Story 5.12's two writes, over the wire as a <b>real</b>
/// least-privileged principal: an account holding every declared pair but
/// <parameter>PROCESSPAIR</parameter> is refused 403 naming it, for the suspend and for the resume
/// alike, and the target process is still running afterwards.</p>
/// <p>The principal holds <parameter>PROCESSFLOORADMIN</parameter> at <code>USE</code> so the
/// router's own floor is cleared before the screen's gate runs -- without it the leg would measure
/// <code>AUTH.NOADMIN</code> instead of the pair set -- plus the security database read and the
/// install namespace's code database read.</p>
/// <p>The target is a process this method starts through
/// <class>OcuPilot.Test.ProcessControl</class> and stops in a frame of its own: never a daemon, the
/// Task Manager, a Work Queue worker or the confirming job.</p>
/// <p>Mutation (Rule 19): answer
/// <code>$ListBuild($ListBuild("%DB_IRISSYS", "READ"))</code> from
/// <method>OcuPilot.Screen.Tool.ProcessSuspend.PrivilegePairs</method> and recompile -- the screen
/// gate no longer refuses and the code and failed-pair assertions go red.</p>
Method TestAnAccountShortOfTheProcessPairIsRefusedTheNamedPair()
{
    Set tCodeResource = ..CodeDatabaseResource()
    Do $$$AssertNotEquals(tCodeResource, "", "the install namespace's code database resource resolves")
    If tCodeResource = "" Quit
    Set tSC = ..EnsureLeastPrivilegedPrincipal(..#PRINCIPALPASSWORD, ..#PROCESSFLOORADMIN _ ":U,%DB_IRISSYS:R," _ tCodeResource _ ":R")
    Do $$$AssertStatusOK(tSC, "a principal short of only the process pair is created: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit

    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, $Piece(..#PROCESSPAIR, ":", 1), "USE"), 0, "it holds no " _ ..#PROCESSPAIR _ ", which is the pair these writes require")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, ..#PROCESSFLOORADMIN, "USE"), 1, "it does hold an administrative resource, so the router's own floor is cleared")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%DB_IRISSYS", "READ"), 1, "and the security database read, so the process pair is the only one it is short of")

    Set tSC = ##class(OcuPilot.Test.ProcessControl).EnsureProbeOwner()
    Do $$$AssertStatusOK(tSC, "the probe process's owner account exists: " _ $System.Status.GetErrorText(tSC))
    Set tPid = ##class(OcuPilot.Test.ProcessControl).StartProbeProcess()
    Do $$$AssertNotEquals(tPid, "", "a probe process of this suite's own is running")
    If tPid = "" Quit
    Try {
        Kill tQuery
        Set tQuery($ClassMethod(..#SUSPENDTOOLCLASS, "IdParam")) = tPid
        Set tReadSC = ##class(OcuPilot.Port.AdminPort).Invoke($ClassMethod(..#SUSPENDTOOLCLASS, "Endpoint"), $ClassMethod(..#SUSPENDTOOLCLASS, "ReadType"), .tQuery, "", .tFresh, .tHttp, .tFault)
        Do $$$AssertStatusOK(tReadSC, "the process reads fresh through the shipped port with the tool's own request type")
        If $$$ISERR(tReadSC) || '$IsObject(tFresh) Quit

        For tTool = ..#SUSPENDTOOLCLASS, ..#PROCESSRESUMETOOLCLASS {
            Set tName = $Parameter(tTool, "TOOLNAME")
            Set tKey = ..SeedForPrincipal(..#PRINCIPALUSER, tPid, tFresh, $ClassMethod(tTool, "IdArgument"), tPid, "string", tName, $ClassMethod(..#PROCESSSCREEN, "PrimaryEntityType"))
            Do $$$AssertNotEquals(tKey, "", tName _ ": a proposal was seeded for that principal")
            If tKey = "" Continue
            Set tSC = ..CallAs(tKey, ..#PRINCIPALUSER, ..#PRINCIPALPASSWORD, .tStatus, .tBody, .tHeaders)
            Do $$$AssertStatusOK(tSC, tName _ ": the confirm request completes")
            Do $$$AssertEquals(tStatus, 403, tName _ ": and is refused -- not 200, not the router's 403 with no body: " _ tBody)
            Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
            Do $$$AssertEquals(tEnvelope.%Get("code"), ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, tName _ ": with the screen-privilege code, not AUTH.NOADMIN")
            Do $$$AssertEquals($Select($IsObject(tEnvelope.%Get("detail")): tEnvelope.%Get("detail").%Get("failedPair"), 1: ""), ..#PROCESSPAIR, tName _ ": naming the pair that failed")
            Do $$$AssertTrue('(##class(OcuPilot.Test.ProcessControl).ProcessState(tPid) [ "SUSP"), tName _ ": and the process is still running on the instance")
            Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", tName _ ": the row was not claimed")
            Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 0, tName _ ": and the token is unspent")
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the leg completes without raising")
    }
    ; Its own frame: this class does not own the probe process's lifetime, so it leaves the
    ; instance without one whatever happened above.
    Do ##class(OcuPilot.Test.ProcessControl).StopProbeProcess(tPid)
    Do ##class(OcuPilot.Test.ProcessControl).RemoveProbeOwner()
    Do $$$AssertEquals(##class(OcuPilot.Test.ProcessControl).ProcessState(tPid), "", "and the probe process this leg started is gone")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForUser(..#PRINCIPALUSER)
}

/// <p>Seed one resume proposal owned by <parameter>PRINCIPALUSER</parameter> against task
/// <var>pTaskId</var> over the fresh read <var>pFresh</var>, and answer its id.</p>
/// <p>The tool admits no settable field, so the seeded arguments carry the identifying property
/// alone -- which is what a real mint stores for an action-style write (AD-51).</p>
Method SeedTaskResume(pTaskId As %String, pFresh As %DynamicObject) As %String
{
    Quit ..SeedForPrincipal(..#PRINCIPALUSER, pTaskId, pFresh, $ClassMethod(..#TASKTOOLCLASS, "IdArgument"), pTaskId, "string", $Parameter(..#TASKTOOLCLASS, "TOOLNAME"), $ClassMethod(..#TASKSCREEN, "PrimaryEntityType"))
}

/// <p>DW-1431, AD-9, AD-21: what a principal holding the write's two declared pairs and <b>no</b>
/// read on the install namespace's code database is actually answered. Database READ is
/// routine-execution permission, so the framework's own <method>%CSP.REST.AccessCheck</method>
/// refuses the request before any OcuPilot-resident method runs, and it sets 403 inline rather than
/// through <method>OcuPilot.Api.Router.ReportHttpStatusCode</method> -- an empty body, with nothing
/// naming the missing grant. That is why the prerequisite is stated in README's roles section
/// rather than left to be discovered from a response, and why no envelope half was built: an
/// <code>AccessCheck</code> override is itself compiled into that database, so dispatching to it
/// raises <code>&lt;PROTECT&gt;</code> and the caller gets a vendor 500 error page instead.</p>
/// <p>The framework's own JWT token endpoint is measured beside it, because it answers 200 for the
/// same principal -- it reaches no OcuPilot class -- so "the account can sign in" is not evidence
/// that it can use anything.</p>
/// <p>Mutation (Rule 19): add the code-database resource to the principal's role below -- the 403
/// becomes OcuPilot's own 404 envelope for the unknown proposal id, which reddens both the status
/// and the empty-body assertion.</p>
Method TestAnAccountWithoutTheCodeDatabaseReadIsRefusedABareForbidden()
{
    Set tCodeResource = ..CodeDatabaseResource()
    Do $$$AssertNotEquals(tCodeResource, "", "the install namespace's code database resource resolves")
    If tCodeResource = "" Quit

    Set tSC = ..EnsureLeastPrivilegedPrincipal(..#PRINCIPALPASSWORD, ..#DECLAREDPAIRSONLY)
    Do $$$AssertStatusOK(tSC, "a principal holding the write's declared pairs and nothing else is created: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    ; The grants are read back off the instance rather than assumed from the role's resource string.
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Secure", "USE"), 1, "it holds the administrative pair")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%DB_IRISSYS", "READ"), 1, "and the security database read")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, tCodeResource, "READ"), 0, "and not read on " _ tCodeResource _ ", which is the whole point of this leg")

    ; The proposal id is deliberately one nothing carries: the refusal happens before any route
    ; code, so a real row would change nothing, and OcuPilot's own answer for an unknown id is a
    ; 404 envelope -- which is what makes 403 with no body a distinctive measurement.
    Set tSC = ..CallAs(..#UNKNOWNPROPOSAL, ..#PRINCIPALUSER, ..#PRINCIPALPASSWORD, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the confirm route answers: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tStatus, 403, "with 403")
    Do $$$AssertEquals($ZStrip($Get(tBody), "<>W"), "", "and an empty body, so nothing names the missing grant: " _ $Extract($Get(tBody), 1, 200))

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/login", ..#PRINCIPALUSER, ..#PRINCIPALPASSWORD, .tLoginStatus, .tLoginBody, .tLoginHeaders, "{}", "application/json")
    Do $$$AssertStatusOK(tSC, "the login route answers: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tLoginStatus, 200, "200 for the same principal, because the token endpoints are the framework's own and reach no OcuPilot class")
}

/// <p>Stories 5.9 and 7.2, AD-10: <b>the registry advertises exactly three write verbs for a user
/// account</b> -- the reviewed update, the delete and the password change -- and a real disable
/// and a real bodyless delete of <code>_SYSTEM</code> are each refused through the real port and
/// the real set.</p>
/// <p>The refusal target is <code>_SYSTEM</code>, which this suite only ever reads: the set is
/// asked directly, so nothing is minted and no write is issued, and the account's own enabled flag
/// is read back afterwards to show it.</p>
/// <p>Mutations (Rule 19): add a fourth <code>write</code> tool under the
/// <code>permissions.users</code> identifier and recompile the package (the roster assertion goes
/// red naming it), or return <code>pProhibits = 0</code> from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.User</method> (both live refusals go red).</p>
Method TestTheUserWriteVerbsAreRosteredAndALiveSystemDisableOrDeleteIsRefused()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tool registry lists its tools")
    Set tIdentifier = $ClassMethod(..#USERSCREEN, "ToolIdentifier")
    Do $$$AssertNotEquals(tIdentifier, "", "the users screen declares a tool identifier")
    Set tRoster = $ListBuild(..#USERTOOL, "permissions.users.delete", "permissions.users.password")
    Set tSeen = 0
    Set tWrites = 0
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If $Piece(tTool.%Get("name"), ".", 1, 2) '= tIdentifier Continue
        Set tSeen = tSeen + 1
        If tTool.%Get("kind") '= "write" Continue
        Set tWrites = tWrites + 1
        Do $$$AssertTrue($ListFind(tRoster, tTool.%Get("name")) > 0, "every write verb on " _ tIdentifier _ " is a rostered one, not '" _ tTool.%Get("name") _ "'")
    }
    Do $$$AssertTrue(tSeen > 0, "the registry carries tools on " _ tIdentifier _ " at all, so this assertion ran over something")
    Do $$$AssertEquals(tWrites, $ListLength(tRoster), "and exactly the rostered three are write-kind")

    Kill tQuery
    Set tQuery("name") = ..#SYSTEMACCOUNT
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the predefined account reads fresh through the shipped port")
    If '$IsObject(tFresh) Quit
    Set tEnabledBefore = ##class(OcuPilot.Kernel.Proposal.Mint).Display(tFresh.%Get("Enabled"), tFresh.%GetTypeOf("Enabled"))
    Set tPayload = ##class(%DynamicAbstractObject).%FromJSON(tFresh.%ToJSON())
    Do tPayload.%Set("Enabled", 0, "boolean")
    ; A second spelling, so "in any spelling" is measured rather than asserted in prose.
    Set tRef = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("user", "instance", $ZConvert(..#SYSTEMACCOUNT, "L"), .tRef), "a reference key builds from a re-cased spelling")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits(..#USERTOOL, tRef, tPayload.%ToJSON(), ##class(OcuPilot.Test.ProhibitedFixture).Diff("Enabled"), .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the shipped set answers over the shipped port: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tProhibits, 1, "disabling the predefined account is refused")
    Do $$$AssertEquals(tCode, $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SYSTEMACCOUNT"), "with the code that names the cause")

    ; AD-10 as amended: the bodyless delete changes no field, and is refused all the same.
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits("permissions.users.delete", tRef, tFresh.%ToJSON(), ##class(OcuPilot.Test.ProhibitedFixture).Diff("Enabled,FullName,Roles"), .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the shipped set answers the delete over the shipped port: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tProhibits, 1, "deleting the predefined account is refused")
    Do $$$AssertEquals(tCode, $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SYSTEMACCOUNT"), "with the same code")

    Kill tQuery
    Set tQuery("name") = ..#SYSTEMACCOUNT
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "GET", .tQuery, "", .tAfter, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the account reads back")
    If $IsObject(tAfter) Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).Display(tAfter.%Get("Enabled"), tAfter.%GetTypeOf("Enabled")), tEnabledBefore, "and nothing about it changed")
}

/// <p>The application at <var>pPath</var> as the shipped port's own <code>GET</code> renders it, or
/// <code>""</code> where the instance resolves none. Quiet on purpose: a refusal is one of the two
/// answers this question has, not a failure.</p>
Method Read(pPath As %String) As %String
{
    Kill tQuery
    Set tQuery("name") = pPath
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject(tFresh) Quit ""
    Quit tFresh.%ToJSON()
}

}
