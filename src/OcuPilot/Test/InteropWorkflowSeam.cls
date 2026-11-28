/// <p><class>OcuPilot.Port.InteropPort</class> whose <method>LogFault</method> keeps the text of each line the port would log, the message, the code and the status text, and the namespace it was
/// written in, so a test reads what a refused or failed workflow user write put in the log (Story 24.17 Batch 3a); whose <method>SourceControlled</method> answers 1 when
/// <code>^IRIS.Temp.OcuProbe2417wMode("source")</code> reads 1; whose <method>WorkflowVendor</method> answers what <code>^IRIS.Temp.OcuProbe2417wMode</code> says: <code>status</code> to answer an
/// error status that carries a marker text, <code>fault</code> to raise an error, anything else the vendor's own call; and whose <method>WorkflowHere</method> raises when the mode is
/// <code>here</code>. The namespace of the last vendor call is kept under the global's <code>ranIn</code> subscript. <method>ClearLog</method> forgets the lines.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropWorkflowSeam Extends OcuPilot.Port.InteropPort
{

/// <p>The text a probe fault and a probe status carry, which no log line may.</p>
Parameter MARKER = "OcuMarkerText2417Workflow";

/// <p>Keep the line, its text and the namespace the call was made in.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set tText = pMessage _ " " _ pCode
    Try {
        Set tText = tText _ " " _ $System.Status.GetErrorText(pStatus)
    } Catch {
    }
    Set tAt = $Increment(^||OcuPilotWorkflowSeamLog)
    Set ^||OcuPilotWorkflowSeamLog(tAt) = tText
    Set ^||OcuPilotWorkflowSeamLog(tAt, "ns") = $NAMESPACE
}

/// <p>Every line kept since <method>ClearLog</method>, one after another.</p>
ClassMethod LoggedText() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotWorkflowSeamLog(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: " | ") _ ^||OcuPilotWorkflowSeamLog(tAt)
    }
    Quit tText
}

/// <p>The namespaces the kept lines were written in, comma-separated, one for each line.</p>
ClassMethod LoggedIn() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotWorkflowSeamLog(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ ^||OcuPilotWorkflowSeamLog(tAt, "ns")
    }
    Quit tText
}

/// <p>How many lines were kept since <method>ClearLog</method>.</p>
ClassMethod Logged() As %Integer
{
    Quit +$Get(^||OcuPilotWorkflowSeamLog)
}

/// <p>Forget the lines kept.</p>
ClassMethod ClearLog()
{
    Kill ^||OcuPilotWorkflowSeamLog
}

/// <p>Answer 1 when the mode names source control, else the shipped answer.</p>
ClassMethod SourceControlled(pNamespace As %String) As %Boolean
{
    If $Get(^IRIS.Temp.OcuProbe2417wMode("source")) Quit 1
    Quit ##super(pNamespace)
}

/// <p>The probe's answer for the mode in <code>^IRIS.Temp.OcuProbe2417wMode</code>.</p>
ClassMethod WorkflowVendor(pType As %String, pObject As %RegisteredObject, pName As %String) As %Status
{
    Set tMode = $Get(^IRIS.Temp.OcuProbe2417wMode)
    Set ^IRIS.Temp.OcuProbe2417wMode("ranIn") = $NAMESPACE
    Set ^IRIS.Temp.OcuProbe2417wMode("ran") = $Get(^IRIS.Temp.OcuProbe2417wMode("ran")) + 1
    If tMode = "status" Quit $$$ERROR($$$GeneralError, ..#MARKER _ " answered for " _ pName)
    If tMode = "fault" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised for " _ pName))
    Quit ##super(pType, pObject, pName)
}

/// <p>The probe's answer for the mode in <code>^IRIS.Temp.OcuProbe2417wMode</code> to a workflow role write (Story 24.17 Batch 3b): <code>status</code> and <code>fault</code> as
/// <method>WorkflowVendor</method> answers them, anything else the vendor's own call.</p>
ClassMethod WorkflowRoleVendor(pType As %String, pObject As %RegisteredObject, pName As %String) As %Status
{
    Set tMode = $Get(^IRIS.Temp.OcuProbe2417wMode)
    Set ^IRIS.Temp.OcuProbe2417wMode("ranIn") = $NAMESPACE
    Set ^IRIS.Temp.OcuProbe2417wMode("ran") = $Get(^IRIS.Temp.OcuProbe2417wMode("ran")) + 1
    If tMode = "status" Quit $$$ERROR($$$GeneralError, ..#MARKER _ " answered for " _ pName)
    If tMode = "fault" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised for " _ pName))
    Quit ##super(pType, pObject, pName)
}

/// <p>The probe's answer for the mode in <code>^IRIS.Temp.OcuProbe2417wMode</code> to a member write (Story 24.17 Batch 3b): <code>status</code> makes the vendor's own call and then
/// answers an error status that carries a marker text, so the membership was saved or removed and the answer says otherwise; <code>fault</code> raises; <code>keep</code> answers OK to a
/// remove and deletes nothing, as the vendor's <code>RemoveUserFromRole</code> does when its delete fails; anything else is the vendor's own call.</p>
ClassMethod WorkflowMemberVendor(pType As %String, pRole As %String, pUser As %String, pRank As %String, pTitle As %String) As %Status
{
    Set tMode = $Get(^IRIS.Temp.OcuProbe2417wMode)
    Set ^IRIS.Temp.OcuProbe2417wMode("ranIn") = $NAMESPACE
    Set ^IRIS.Temp.OcuProbe2417wMode("ran") = $Get(^IRIS.Temp.OcuProbe2417wMode("ran")) + 1
    If tMode = "fault" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised for " _ pUser))
    If (tMode = "keep") && (pType = ..#TYPEREMOVEWORKFLOWMEMBER) Quit $$$OK
    Set tSC = ##super(pType, pRole, pUser, pRank, pTitle)
    If tMode = "status" Quit $$$ERROR($$$GeneralError, ..#MARKER _ " answered for " _ pUser)
    Quit tSC
}

/// <p>The probe's answer for the mode in <code>^IRIS.Temp.OcuProbe2417wMode</code> to the take of the memberships a role's delete left behind (Story 24.17 Batch 3b): <code>gone</code> takes none
/// and answers an error status, as a membership that could not be removed; anything else is the port's own.</p>
ClassMethod WorkflowMembersGone(pRole As %String) As %Status
{
    If $Get(^IRIS.Temp.OcuProbe2417wMode) = "gone" Quit $$$ERROR($$$GeneralError, ..#MARKER _ " kept the memberships of " _ pRole)
    Quit ##super(pRole)
}

/// <p>The probe's answer for the mode in <code>^IRIS.Temp.OcuProbe2417wMode</code> to a workflow task write (Story 24.17 Batch 4): <code>status</code> makes the vendor's own call for an assign
/// or an unassign, so the task was saved, and then answers an error status that carries a marker text, and answers that status for a cancel without calling the vendor; <code>fault</code> raises;
/// anything else is the vendor's own call.</p>
ClassMethod WorkflowTaskVendor(pType As %String, pTask As %RegisteredObject, pUser As %String) As %Status
{
    Set tMode = $Get(^IRIS.Temp.OcuProbe2417wMode)
    Set ^IRIS.Temp.OcuProbe2417wMode("ranIn") = $NAMESPACE
    Set ^IRIS.Temp.OcuProbe2417wMode("ran") = $Get(^IRIS.Temp.OcuProbe2417wMode("ran")) + 1
    If tMode = "fault" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised for " _ pUser))
    If (tMode = "status") && (pType = ..#TYPECANCELWORKFLOWTASK) Quit $$$ERROR($$$GeneralError, ..#MARKER _ " answered for the cancel")
    Set tSC = ##super(pType, pTask, pUser)
    If tMode = "status" Quit $$$ERROR($$$GeneralError, ..#MARKER _ " answered for " _ pUser)
    Quit tSC
}

/// <p>Raise inside each namespace-switched block when the mode is <code>here</code>.</p>
ClassMethod WorkflowHere() [ Private ]
{
    If $Get(^IRIS.Temp.OcuProbe2417wMode) = "here" {
        Set ^IRIS.Temp.OcuProbe2417wMode("hereIn") = $NAMESPACE
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised in the workflow user's namespace"))
    }
}

}
