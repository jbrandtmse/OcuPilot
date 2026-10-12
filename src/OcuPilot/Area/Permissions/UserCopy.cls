/// <p>The screen's half of a user copy (AD-55, Story 18.29), over <code>POST /users/copy</code>. It is
/// <class>OcuPilot.Area.Permissions.UserCreate</class>'s flow over the copy tool
/// (<class>OcuPilot.Screen.Tool.UserCopy</class>): the same gate, the same name and hold, and the same
/// answer, <code>{name, user, readBack}</code> with 201.</p>
/// <p><b>What differs</b> is the write: the source's roles and escalation roles are read by the tool's
/// composition (<method>ComposePayload</method>), the password is the caller's own and is checked by the
/// instance's policy before the port is entered, and the port carries the copy out
/// (<class>OcuPilot.Port.UserCopyPort</class>). AD-10's set is asked over the caller's own fields, as the
/// create asks it.</p>
/// <p>The password is a secret (AD-35): never logged, echoed or returned, and the created account the route
/// answers is the vendor's own read, which carries none.</p>
Class OcuPilot.Area.Permissions.UserCopy Extends OcuPilot.Area.Permissions.UserCreate
{

/// <p>The tool class both callers resolve the write through (AD-55).</p>
Parameter TOOLCLASS = "OcuPilot.Screen.Tool.UserCopy";

/// <p>The copy's form pairs are the create form's (AD-8): the Users form screen.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.UserForm";

/// <p>The copy's payload (<method>OcuPilot.Area.Permissions.UserCreate.ComposePayload</method>): the tool's own
/// <method>OcuPilot.Screen.Tool.UserCopy.ComposeCreate</method>, which reads the source as it stands now. A
/// source that composition refuses (empty, absent, directory-service or delegated) is one violation on
/// <code>CopyFrom</code>, <parameter>OcuPilot.Api.UserCopyError.SOURCE</parameter>, and nothing is composed. The create rules (<method>OcuPilot.Area.Permissions.UserCreateRules.Validate</method>)
/// require the password and check its policy; the source check is the copy's own.</p>
ClassMethod ComposePayload(pName As %String, pArgs As %DynamicObject, Output pPayload As %DynamicObject, ByRef pViolations) As %Status
{
    Set tClass = ..#TOOLCLASS
    Set tSC = $ClassMethod(tClass, "ComposeCreate", pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .pPayload, .tDiff, .tUnchanged, .tProblem)
    If $$$ISERR(tSC) Quit tSC
    If tProblem '= "" {
        Set pViolations = 1
        Set pViolations(1) = $ListBuild($Parameter(tClass, "SOURCEARGUMENT"), ##class(OcuPilot.Api.UserCopyError).#SOURCE)
    }
    Quit $$$OK
}

}
