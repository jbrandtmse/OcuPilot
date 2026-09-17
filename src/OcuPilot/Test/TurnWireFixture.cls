/// <p>Shared setup for the armed turn classes (<class>OcuPilot.Test.TurnWire</class>,
/// <class>OcuPilot.Test.TurnLong</class>): two least-privileged principals, a credential entry, a
/// <code>turnprobe</code> definition made the default, the requests those principals send, and the
/// teardown that leaves no job, turn, slot or stub node behind.</p>
/// <p><b>Each principal's role holds read on the install namespace's code database and on the
/// database the credential entries live in, <code>%Admin_Operate:USE</code> and
/// <code>%Ens_Credentials:READ</code></b> -- enough to clear the router's floor, to resolve the
/// definition's key inside a turn job, and nothing of OcuPilot's own.</p>
/// <p>A principal may hold a second role, <parameter>SECONDROLE</parameter>, which
/// <method>RemoveSecondRole</method> takes away while its turn runs.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: its callers are, and each refuses in
/// <method>OnBeforeAllTests</method> unless both arming variables read 1.</p>
Class OcuPilot.Test.TurnWireFixture Extends %RegisteredObject
{

Parameter USERA = "OcuPilotProbeTurnWireA";

Parameter USERB = "OcuPilotProbeTurnWireB";

Parameter ROLE = "OcuPilotProbeTurnWireRole";

/// <p>The role a two-role principal holds beside <parameter>ROLE</parameter>.</p>
Parameter SECONDROLE = "OcuPilotProbeTurnWireSecond";

Parameter CREDENTIAL = "OcuPilotProbeTurnCredential";

/// <p>A fabricated key of the shape the <code>turnprobe</code> row's prefix requires. It reaches no
/// provider.</p>
Parameter PROBEKEY = "sk-ant-ocupilotturnprobe0000000000";

Parameter DEFINITIONNAME = "OcuPilotProbeAgentTurnWire";

Parameter APIBASE = "/api/ocupilot";

/// <p>The two arming variables, and the one value that arms each.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

/// <p>The resources a probe principal's role holds, <var>pOperate</var> 0 leaving out the one
/// administrative resource.</p>
ClassMethod Resources(pOperate As %Boolean = 1) As %String
{
    Set tNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Set tResources = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tNsObj = ##class(Config.Namespaces).Open(tNs)
        Set tCode = ##class(SYS.Database).%OpenId(##class(Config.Databases).Open(tNsObj.Routines).Directory).ResourceName
        Set tStore = ##class(SYS.Database).%OpenId($Piece(##class(%SYS.Namespace).GetGlobalDest(tNs, "Ens.Conf.CredentialsD"), "^", 2)).ResourceName
        Set $NAMESPACE = tOrigNS
        Set tResources = tCode _ ":R," _ tStore _ ":R,%Ens_Credentials:R" _ $Select(pOperate: ",%Admin_Operate:U", 1: "")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Quit tResources
}

/// <p>Create or reset the role with <var>pResources</var>, and create <var>pUser</var> holding it
/// with <var>pPassword</var>, replacing any account of that name. A non-empty
/// <var>pSecondResources</var> also creates or resets <parameter>SECONDROLE</parameter> with those
/// resources and grants it to <var>pUser</var> as well.</p>
ClassMethod EnsurePrincipal(pUser As %String, pPassword As %String, pResources As %String, pSecondResources As %String = "") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ..SetRole(pResources)
        If $$$ISERR(tSC) Quit
        Set tRoles = ..#ROLE
        If pSecondResources '= "" {
            If ##class(Security.Roles).Exists(..#SECONDROLE, .tR, .tRS) {
                Set tProps("Resources") = pSecondResources
                Set tProps("GrantedRoles") = ""
                Set tSC = ##class(Security.Roles).Modify(..#SECONDROLE, .tProps)
            } Else {
                Set tSC = ##class(Security.Roles).Create(..#SECONDROLE, "OcuPilot turn test principal second role (throwaway)", pSecondResources, "")
            }
            If $$$ISERR(tSC) Quit
            Set tRoles = tRoles _ "," _ ..#SECONDROLE
        }
        If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(pUser)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(pUser, tRoles, pPassword, "OcuPilot turn test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.TurnWireFixture")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Give the probe role exactly <var>pResources</var>. <b>Caller contract:</b> in
/// <code>%SYS</code>, or through <method>SetRoleResources</method>.</p>
ClassMethod SetRole(pResources As %String) As %Status [ Private ]
{
    If ##class(Security.Roles).Exists(..#ROLE, .tR, .tRS) {
        Set tProps("Resources") = pResources
        Set tProps("GrantedRoles") = ""
        Quit ##class(Security.Roles).Modify(..#ROLE, .tProps)
    }
    Quit ##class(Security.Roles).Create(..#ROLE, "OcuPilot turn test principal role (throwaway)", pResources, "")
}

/// <p>Give the probe role exactly <var>pResources</var>, from any namespace.</p>
ClassMethod SetRoleResources(pResources As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ..SetRole(pResources)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Take <parameter>SECONDROLE</parameter> away from <var>pUser</var>, leaving
/// <parameter>ROLE</parameter>.</p>
ClassMethod RemoveSecondRole(pUser As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProps("Roles") = ..#ROLE
        Set tSC = ##class(Security.Users).Modify(pUser, .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete <var>pUser</var> when the instance holds it.</p>
ClassMethod DeletePrincipal(pUser As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(pUser, .tU, .tUS) Set tSC = ##class(Security.Users).Delete(pUser)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete both principals and both roles, and answer what survives
/// (<method>PrincipalsLeft</method>).</p>
ClassMethod RemovePrincipals() As %String
{
    Set tLeft = ""
    Do ..DeletePrincipal(..#USERA)
    Do ..DeletePrincipal(..#USERB)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tRole = ..#ROLE, ..#SECONDROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
        }
    } Catch ex {
        Set tLeft = " (" _ ex.DisplayString() _ ")"
    }
    Set $NAMESPACE = tOrigNS
    Quit tLeft _ ..PrincipalsLeft()
}

/// <p>Which probe principals and roles the instance holds, <code>""</code> when none.</p>
ClassMethod PrincipalsLeft() As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tName = ..#USERA, ..#USERB {
            If ##class(Security.Users).Exists(tName, .tU, .tUS) Set tLeft = tLeft _ " user " _ tName
        }
        For tRole = ..#ROLE, ..#SECONDROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Set tLeft = tLeft _ " role " _ tRole
        }
    } Catch ex {
        Set tLeft = tLeft _ " (" _ ex.DisplayString() _ ")"
    }
    Set $NAMESPACE = tOrigNS
    Quit tLeft
}

/// <p>A fresh password for a probe principal.</p>
ClassMethod NewPassword() As %String
{
    Quit "OcuPilotTrn" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
}

/// <p>The id of the definition carrying the default marker, or <code>""</code>.</p>
ClassMethod MarkedDefault() As %String
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM OcuPilot_Kernel_State.Agent WHERE DefaultMark = '1'")
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit ""
    Quit tRS.%GetData(1)
}

/// <p>Store the probe key, create the <code>turnprobe</code> definition with model
/// <var>pTag</var> on it, enabled and verified, and make it the default. <var>pId</var> is its
/// id.</p>
ClassMethod EnsureDefinition(pTag As %String, Output pId As %String) As %Status
{
    Set pId = ""
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#CREDENTIAL)
    Set tSC = ##class(OcuPilot.Kernel.Secret.Ladder).Store(..#CREDENTIAL, ##class(OcuPilot.Test.CredentialFixture).Payload(..#PROBEKEY), "apiKey")
    If $$$ISERR(tSC) Quit tSC
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = ..#DEFINITIONNAME
    Set tRow.Provider = "turnprobe"
    Set tRow.Model = pTag
    Set tRow.EndpointUrl = "https://192.0.2.10/v1/messages"
    Set tRow.CredType = "creds"
    Set tRow.CredentialName = ..#CREDENTIAL
    Set tRow.MaxTokens = 1024
    Set tRow.MaxIterationsPerTurn = 10
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
    If $$$ISERR(tSC) Quit tSC
    Set pId = tRow.%Id()
    Set tRow = ""
    Set tSC = ##class(OcuPilot.Test.AgentFixture).SetFlags(pId, 1, 1)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(pId)
}

/// <p>Point definition <var>pId</var> at the stub script <var>pTag</var>.</p>
ClassMethod SetTag(pId As %String, pTag As %String) As %Status
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tRow, .tSnapshot)
    Set tRow.Model = pTag
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tRow, .tSnapshot)
    Set tRow = ""
    Quit tSC
}

/// <p>Remove the probe definitions and the credential entry, and move the default marker back to
/// <var>pPrior</var> when it is still an enabled definition.</p>
ClassMethod RemoveDefinition(pPrior As %String) As %Status
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#CREDENTIAL)
    If (pPrior '= "") && ##class(OcuPilot.Kernel.State.Agent).%ExistsId(pPrior) Do ##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(pPrior)
    If $$$ISOK(tSC) && (tRemaining '= 0) Set tSC = $$$ERROR($$$GeneralError, tRemaining _ " probe definitions survive")
    Quit tSC
}

/// <p>One request to the turn routes as <var>pUser</var>. <var>pPath</var> follows
/// <parameter>APIBASE</parameter>.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pUser As %String, pPassword As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String, Output pHeaders, pTimeout As %Integer = 0) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ pPath, pUser, pPassword, .pStatus, .pText, .pHeaders, pBody, "application/json", , pTimeout)
}

/// <p>The body a start posts for <var>pMessage</var>, as the UTF-8 bytes a browser sends.</p>
ClassMethod StartBody(pMessage As %String) As %String
{
    Set tBody = {}
    Do tBody.%Set("message", pMessage, "string")
    Quit $ZConvert(tBody.%ToJSON(), "O", "UTF8")
}

/// <p>Poll turn <var>pTurnId</var> as <var>pUser</var> every second until it ends or
/// <var>pSeconds</var> pass; <var>pView</var> is the last answer, <code>""</code> when none parsed.
/// Every poll renews the lease, as the panel's do.</p>
ClassMethod AwaitEnd(pTurnId As %String, pUser As %String, pPassword As %String, pSeconds As %Integer, Output pView) As %String
{
    Set pView = ""
    Set tDeadline = $ZHorolog + pSeconds
    For {
        Do ..Call("GET", "/turn/" _ pTurnId _ "/progress", pUser, pPassword, "", .tStatus, .tText, .tHeaders)
        If tStatus = 200 Set pView = ##class(%DynamicObject).%FromJSON(tText)
        If $IsObject(pView) && ##class(OcuPilot.Kernel.State.Turn).IsTerminal(pView.state) Quit
        If $ZHorolog > tDeadline Quit
        Hang 1
    }
    Quit $Select($IsObject(pView): pView.state, 1: "")
}

/// <p>Wait up to <var>pSeconds</var> for stub script <var>pTag</var> to record call
/// <var>pCall</var>.</p>
ClassMethod AwaitCall(pTag As %String, pCall As %Integer, pSeconds As %Integer) As %Boolean
{
    Set tDeadline = $ZHorolog + pSeconds
    While (##class(OcuPilot.Test.TurnProvider).Calls(pTag) < pCall) && ($ZHorolog < tDeadline) {
        Hang 0.25
    }
    Quit ##class(OcuPilot.Test.TurnProvider).Calls(pTag) >= pCall
}

/// <p>Signal every probe user's turns to abandon, wait up to ten seconds for each job to end and
/// terminate any that has not, remove every probe turn and the stub nodes of each tag in
/// <var>pTags</var>, and answer
/// what was left, <code>""</code> when nothing was: a live job, a turn, a held slot or a stub
/// node.</p>
ClassMethod Sweep(pTags As %List) As %String
{
    Set tLeft = ""
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedAbandonForUser(..#USERA, .tCount)
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedAbandonForUser(..#USERB, .tCount)
    Do ##class(OcuPilot.Test.TurnFixture).Keys(.tKeys)
    For tI = 1:1:tKeys {
        Set tPid = ##class(OcuPilot.Test.TurnFixture).Field(tKeys(tI), "JobId")
        If tPid = "" Continue
        Set tDeadline = $ZHorolog + 10
        While $Data(^$JOB(tPid)) && '##class(OcuPilot.Kernel.State.Turn).IsTerminal(##class(OcuPilot.Test.TurnFixture).Field(tKeys(tI), "State")) && ($ZHorolog < tDeadline) {
            Hang 0.25
        }
    }
    Do ##class(OcuPilot.Test.TurnFixture).StopProbeJobs(.tKilled)
    If tKilled Hang 1
    Do ##class(OcuPilot.Test.TurnFixture).Keys(.tKeys)
    For tI = 1:1:tKeys {
        Set tPid = ##class(OcuPilot.Test.TurnFixture).Field(tKeys(tI), "JobId")
        If (tPid '= "") && '##class(OcuPilot.Kernel.State.Turn).IsTerminal(##class(OcuPilot.Test.TurnFixture).Field(tKeys(tI), "State")) && $Data(^$JOB(tPid)) Set tLeft = tLeft _ " job " _ tPid
    }
    Set tSC = ##class(OcuPilot.Test.TurnFixture).RemoveTurns(.tRemaining)
    If $$$ISERR(tSC) || (tRemaining '= 0) Set tLeft = tLeft _ " turns (" _ tRemaining _ ")"
    If ##class(OcuPilot.Test.TurnFixture).AnyProbeSlotHeld() Set tLeft = tLeft _ " a slot"
    For tI = 1:1:$ListLength(pTags) {
        Do ##class(OcuPilot.Test.TurnProvider).Forget($List(pTags, tI))
        If ##class(OcuPilot.Test.TurnProvider).Remains($List(pTags, tI)) Set tLeft = tLeft _ " stub " _ $List(pTags, tI)
    }
    Quit tLeft
}

}
