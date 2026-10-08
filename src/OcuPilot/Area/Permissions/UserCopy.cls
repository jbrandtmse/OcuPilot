/// <p>The screen's half of a user copy (AD-55, Story 18.29), over <code>POST /users/copy</code>. It is
/// <class>OcuPilot.Area.Permissions.UserCreate</class>'s flow over the copy tool
/// (<class>OcuPilot.Screen.Tool.UserCopy</class>): the same gate, the same name and hold, and the same
/// answer, <code>{name, user, readBack}</code> with 201.</p>
/// <p><b>What differs</b> is the write: the source's roles and escalation roles are read by the tool's
/// composition, the password is the caller's own and is checked by the instance's policy before the port
/// is entered, and the port carries the copy out (<class>OcuPilot.Port.UserCopyPort</class>). AD-10's set
/// is asked over the caller's own fields, as the create asks it.</p>
/// <p>The password is a secret (AD-35): never logged, echoed or returned, and the created account the route
/// answers is the vendor's own read, which carries none.</p>
Class OcuPilot.Area.Permissions.UserCopy Extends OcuPilot.Area.Permissions.UserCreate
{

/// <p>The tool class both callers resolve the write through (AD-55).</p>
Parameter TOOLCLASS = "OcuPilot.Screen.Tool.UserCopy";

/// <p>The copy's form pairs are the create form's (AD-8): the Users form screen.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.UserForm";

/// <p>Perform one copy: the account <var>pName</var> from the caller's body <var>pArgs</var>. The order is
/// <class>OcuPilot.Area.Permissions.UserCreate</class>'s: the name's shape; AD-10's set over the caller's own
/// fields; the create rules, which require the source and the password and check the policy; the composed
/// payload, which reads the source; the password joins the body after the verdict; and then the port.</p>
/// <p><b>Caller contract:</b> as <class>OcuPilot.Area.Permissions.UserCreate</class>'s
/// <method>Perform</method>: <var>pViolations</var> counts the broken rules, and a non-zero count means
/// nothing was written.</p>
ClassMethod Perform(pName As %String, pArgs As %DynamicObject, Output pCreated As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pCreated = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tRules = "OcuPilot.Area.Permissions.UserCreateRules"
        Do $ClassMethod(tRules, "NameViolation", pName, .pViolations)
        If pViolations > 0 Quit
        Set tClass = ..#TOOLCLASS
        Set tRefSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pName, .tTargetRef)
        If $$$ISERR(tRefSC) {
            Set tSC = tRefSC
            Quit
        }

        ; AD-10, AD-55: the set the confirm asks, over the caller's own fields minus the declared secrets.
        Set tSecrets = $ClassMethod(tClass, "SecretArguments")
        Set tProhibitSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(tClass, "TOOLNAME"), tTargetRef, ..CallerFields(pArgs, tSecrets).%ToJSON(), "[]", .tProhibits, .tProhibitCode)
        If $$$ISERR(tProhibitSC) {
            Set tSC = tProhibitSC
            Quit
        }
        If tProhibits {
            Set pHttpStatus = 403
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tProhibitCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tProhibitCode))
            Set tSC = $$$ERROR($$$GeneralError, tProhibitCode)
            Quit
        }

        ; The create rules: the name, the source, the password and its policy, and the full name.
        Set tSC = $ClassMethod(tRules, "Validate", pName, pArgs, .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit
        Set tCopyFrom = ""
        If pArgs.%GetTypeOf("CopyFrom") = "string" Set tCopyFrom = pArgs.%Get("CopyFrom")
        If tCopyFrom = "" {
            Set pViolations = 1
            Set pViolations(1) = $ListBuild("CopyFrom", ##class(OcuPilot.Api.UserCopyError).#SOURCE)
            Quit
        }

        ; The payload is composed from the source as it stands now; the vendor's write is checked against it.
        Set tComposeSC = $ClassMethod(tClass, "ComposeCreate", pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tComposeSC) {
            Set tSC = tComposeSC
            Quit
        }
        If tProblem '= "" {
            Set pViolations = 1
            Set pViolations(1) = $ListBuild("CopyFrom", ##class(OcuPilot.Api.UserCopyError).#SOURCE)
            Quit
        }

        ; AD-35: the password joins the body here, after the verdict and the rules, and nowhere else.
        For tI = 1:1:$ListLength(tSecrets) {
            Set tSecret = $List(tSecrets, tI)
            If pArgs.%GetTypeOf(tSecret) = "string" Do tPayload.%Set(tSecret, pArgs.%Get(tSecret), "string")
        }

        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .pCreated, .pHttpStatus, .pFault)
        ; AD-58: the account read back through the tool's port and compared with what was sent.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pName, tPayload, "", ..PortClass(), $Get(pCreated), pHttpStatus)
        Set tPayload = ""
    } Catch ex {
        Set pCreated = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
