/// <p>The Task schedule's delete tool (AD-6, AD-51, AD-53, FR-53): remove one task from the Task
/// Manager. Two callers reach it: the list's Delete row action through
/// <class>OcuPilot.Api.ScreenAction</class>, behind the typed-name dialog, and the agent's proposal
/// and confirmation. Both read the task fresh and issue the vendor's <code>DELETE</code>.</p>
/// <p><b>It is action-style</b> (AD-51): <code>DELETE</code> reads no body, so the tool admits no
/// settable field and sends none.</p>
/// <p><b>Its read goes through <class>OcuPilot.Port.TaskPort</class></b> (AD-52), whose
/// <code>GET</code> carries the task's <code>Name</code>, <code>TaskClass</code> and
/// <code>NameSpace</code> and, from the same endpoint's <code>INFO</code>, its <code>Type</code>.
/// The card lists those four as removal rows, so a proposal to delete one of the instance's own
/// system tasks says so in its rows, where the card reads it.</p>
/// <p><b>A system task is deletable.</b> The vendor's <code>RunDelete</code> removes any task, and
/// nothing on OcuPilot's write path refuses one: the confirmation is the typed name, and the dialog
/// and the card both state the consequence. The vendor keeps a deleted task's history rows.</p>
/// <p><b>It is destructive</b>: a deleted task cannot be proposed back.</p>
Class OcuPilot.Screen.Tool.TaskDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "tasks.schedule.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Parameter DESCRIPTION = "Propose deleting one task from this instance's Task Manager, so it no longer runs. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the task by the numeric id the task schedule reports for it, not by its name. The task's history is kept.";

/// <p>The screen's own Delete row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "delete";

/// <p>The port the read and the write go through (AD-52): the admin port with its
/// <code>Task.CRUD</code> <code>GET</code> completed by <code>INFO</code>'s <code>Type</code>.</p>
Parameter PORTCLASS = "OcuPilot.Port.TaskPort";

/// <p>The single-object read, which names the task.</p>
Parameter READTYPE = "GET";

/// <p>The vendor's own delete: <code>DELETE /task?id=</code>, whose <code>RunDelete</code> is
/// <code>%DeleteId</code> and answers 404 for an unknown id (measured on this build).</p>
Parameter WRITETYPE = "DELETE";

Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The target is removed, so a screen showing it drops the row (AD-14).</p>
Parameter CHANGEACTION = "deleted";

Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p><code>%Admin_Task:USE</code>, one of the two resources the vendor's
/// <code>ResourcesOR()</code> admits for <code>DELETE</code> and one of the screen's own two
/// pairs (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Task";

Parameter WRITEPERMISSION = "USE";

/// <p>The read field the precondition reads: a task whose name the read did not answer is not one
/// to delete.</p>
Parameter PRECONDITIONFIELD = "Name";

/// <p>What the user reviewed about the task: its name, the class it runs, the namespace it runs in
/// and whether it is one of the instance's own system tasks.</p>
Parameter FINGERPRINTSUBJECT = "Name,TaskClass,NameSpace,Type";

/// <p>What <parameter>PORTCLASS</parameter>'s <code>GET</code> answers of the subject. The list
/// spells the namespace <code>Namespace</code> and carries no <code>TaskClass</code>, so the
/// subject is validated against this read's own names.</p>
Parameter READANSWERS = "Name,TaskClass,NameSpace,Type";

ClassMethod Endpoint() As %String
{
    Quit "Task.CRUD"
}

/// <p>The vendor's numeric task id, which the list's rows carry as <code>Id</code>.</p>
ClassMethod IdArgument() As %String
{
    Quit "Id"
}

/// <p>The query parameter <code>Task.CRUD</code> identifies a task by, for the read and the
/// delete.</p>
ClassMethod IdParam() As %String
{
    Quit "id"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The task to delete, named by the numeric id this instance's own task schedule reports for it. A task the schedule does not report is refused.", "string")
    Quit tSchema
}

/// <p>The screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, appended only when
/// the screen does not already declare it.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// subject field, carrying the value the instance holds and no after-state.</p>
/// <p>A read that answered no <code>Name</code>, or no <code>Type</code>, is <var>pProblem</var>:
/// without the name the task is not one the user can recognise, and without the type the card
/// cannot say whether it is a system task, so the delete is not proposed.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tName = ""
        Set tType = ""
        If $IsObject(pFresh) {
            Set tName = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#PRECONDITIONFIELD), pFresh.%GetTypeOf(..#PRECONDITIONFIELD))
            Set tType = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get("Type"), pFresh.%GetTypeOf("Type"))
        }
        If tName = "" {
            Set pProblem = "this instance did not report that task's name, and a task nobody can recognise is not one to delete"
            Quit
        }
        If tType = "" {
            Set pProblem = "this instance did not report whether that task is one of its own system tasks, so its delete cannot be proposed"
            Quit
        }
        Set tSubject = ..FingerprintSubject()
        For tI = 1:1:$ListLength(tSubject) {
            Set tField = $List(tSubject, tI)
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField)), "string")
            Do tRow.%Set("after", "", "string")
            Do tRow.%Set("removed", 1, "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
