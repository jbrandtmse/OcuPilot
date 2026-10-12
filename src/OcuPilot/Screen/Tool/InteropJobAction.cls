/// <p>What Interoperability's three job writes share (AD-6, AD-51, AD-52, AD-53, AD-62, Story 20.23): an action-style write of
/// one job of the running production through <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the Jobs
/// list's row action, or the same action on an item's Jobs tab, and the agent's proposal and confirmation. None sends a body.</p>
/// <p><b>The fresh read is the port's <code>JOB</code></b>, composed for the action at the mint and at a screen action
/// (<method>OcuPilot.Screen.Tool.InteropAction.PortQuery</method>): a job whose process has ended, an abort or suspend of a job
/// that is not retrying a message, and a namespace with no running production are refused by the port with their own
/// <code>INTEROP.*</code> codes, 409, before any vendor call (<parameter>PRECONDITIONCODES</parameter>). The vendor answers each
/// as a success, and an abort or suspend of an idle job leaves a request that kept the next production stop from quiescing
/// (measured). The confirm's re-read is not composed for the action, so a job that moved closes the proposal through the
/// fingerprint, and the write refuses again by the same codes. <method>StateDiff</method> repeats the refusal for a read that
/// reached it unrefused.</p>
/// <p><b>The target is the job's process id</b>, the <code>Job</code> column of the Jobs list and of an item's Jobs tab, which
/// the Jobs tab's rows post to the Jobs list's route (AD-53).</p>
/// <p><b>It declares</b> the vendor's own check as its write pair (<parameter>WRITERESOURCE</parameter>) and WRITE on the
/// namespace's globals database beyond the screen's pairs (AD-8, AD-62), each refused by name before any port call, then the
/// custom resource of each <parameter>CLASSICPAGES</parameter> page (AD-44).</p>
Class OcuPilot.Screen.Tool.InteropJobAction Extends OcuPilot.Screen.Tool.InteropAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropJobList";

/// <p>The fresh read: one job of the running production, composed for the action.</p>
Parameter READTYPE = "JOB";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Production,Item,Job,Host,Status,AdapterState,LastActivity,Retry,ActiveMessage,Dead,Namespace";

/// <p>The job read the confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Status";

Parameter WRITERESOURCE = "%Ens_Jobs";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The classic page whose Jobs tab performs the action (AD-44); the Jobs list's own page is not redeclared.</p>
Parameter CLASSICPAGES = "EnsPortal.ProductionConfig";

/// <p>The word the card's one state row shows the field moving to.</p>
Parameter AFTERWORD;

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTJOBS
}

/// <p>The job's process id, which the Jobs rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Job"
}

/// <p>The host the card titles the job by: the fresh read's <code>Host</code>.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Host") = "string") Quit pFresh.%Get("Host")
    Quit ""
}

/// <p>The derived schema with the job's description replaced: the target is one job of the running production, named by the
/// process id the Jobs list reports.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The job, named by the process id the Jobs list or an item's Jobs tab reports in its Job column. A job the running production does not hold is refused.", "string")
    }
    Quit tSchema
}

/// <p>The one row this proposal's card shows, from the fresh read <var>pFresh</var>: <parameter>STATEFIELD</parameter> moving
/// from the job's value to <parameter>AFTERWORD</parameter>. A job the action does not fit is <var>pProblem</var>, the
/// sentence of the code <method>OcuPilot.Port.InteropPort.RowRefusal</method> names; a read that answered no <code>Dead</code> flag
/// refuses too, since a job nobody established is not one to act on.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Dead") '= "boolean") {
            Set pProblem = "this instance did not report the job's state"
            Quit
        }
        Set tCode = ##class(OcuPilot.Port.InteropPort).RowRefusal(..#WRITETYPE, pFresh)
        If tCode '= "" {
            Set pProblem = ##class(OcuPilot.Port.InteropPort).ReasonFor(tCode)
            Quit
        }
        Set tField = ..#STATEFIELD
        Set tRow = {}
        Do tRow.%Set("field", tField, "string")
        Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField)), "string")
        Do tRow.%Set("after", ..#AFTERWORD, "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
