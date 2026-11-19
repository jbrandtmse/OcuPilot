/// <p>What the Worklists screen's two write tools share (AD-6, AD-13, AD-51, AD-52, AD-53, AD-58, AD-65, Story 24.13): showing and hiding one worklist option on one panel of one page of the request's
/// namespace through <class>OcuPilot.Port.AnalyticsPort</class>, reached by two callers, the screen's row actions Show and Hide and the agent's proposal and confirmation. It is
/// <class>OcuPilot.Screen.Tool.AnalyticsAction</class> with the settings global as its destination, an action-style write that sends no body.</p>
/// <p><b>The target is the composite <code>[Page, Panel, Class]</code></b> (<class>OcuPilot.Screen.Tool.AnalyticsWorklistMint</class>), each part kept exactly (AD-13). <b>The fresh read is the port's
/// <code>WORKLIST</code></b>, composed for the action at the mint and at a screen action: a worklist the page does not list is refused 404 <code>ANALYTICS.WORKLIST.ABSENT</code> and a namespace whose
/// worklists are not customized 409 <code>ANALYTICS.WORKLIST.NOTCUSTOMIZED</code>, before any vendor call.</p>
/// <p><b>The option is the state it is moved to.</b> The stored payload carries <code>Shown</code> as the state the write sets (<method>MergeUpdate</method>), which the read-back compares with the
/// option as it reads afterwards (<parameter>READBACKPAYLOAD</parameter>); the fingerprint covers the option's identity and whether the worklists are customized, and so is not moved by an option
/// somebody else already set to the same state, which the write would leave as it is.</p>
Class OcuPilot.Screen.Tool.AnalyticsWorklistAction Extends OcuPilot.Screen.Tool.AnalyticsAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsWorklistList";

Parameter DESTINATIONGLOBAL = "^DeepSee.UserPortalSettings";

Parameter CLASSICPAGES = "%DeepSee.UI.Settings";

/// <p>The fresh read: one worklist option.</p>
Parameter READTYPE = "WORKLIST";

Parameter READANSWERS = "Page,Panel,Worklist,Class,Shown,Customized,Namespace";

/// <p>The read field a stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Customized";

Parameter STATEFIELD = "Shown";

/// <p>The write acts on worklists the page shows by its own choice, so they must be customized.</p>
Parameter PRECONDITIONFIELD = "Customized";

Parameter FINGERPRINTSUBJECT = "Page,Panel,Class,Customized,Shown,Namespace";

Parameter PRECONDITIONCODES = "ANALYTICS.WORKLIST.ABSENT,ANALYTICS.WORKLIST.NOTCUSTOMIZED,ANALYTICS.SETTING.READONLY,ANALYTICS.NAMESPACE";

/// <p>What the read-back compares: whether the option is shown, against the state this write sets.</p>
Parameter READBACKFIELDS = "Shown";

Parameter READBACKPAYLOAD As BOOLEAN = 1;

/// <p>The state this write sets the option to, <code>1</code> to show and <code>0</code> to hide.</p>
Parameter SHOWN As BOOLEAN = 1;

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTWORKLISTS
}

/// <p><class>OcuPilot.Screen.Tool.AnalyticsWorklistMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.AnalyticsWorklistMint"
}

/// <p>The worklist class, which the screen's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Class"
}

/// <p>The title the card gives the option: the worklist's name, else its class.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Worklist") = "string") Quit pFresh.%Get("Worklist")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Class") = "string") Quit pArgs.%Get("Class")
    Quit ""
}

/// <p>The derived schema with the page, the panel and the class described, the first two added and required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set("Page", {"type": "string", "description": "The page, named exactly as the Worklists list reports it in its Page column: Home or DashboardViewer."})
    Do tProperties.%Set("Panel", {"type": "string", "description": "The panel of that page, as the Worklists list reports it in its Panel column: 1 or 2."})
    If tSchema.%GetTypeOf("required") = "array" {
        Do tSchema.%Get("required").%Push("Page")
        Do tSchema.%Get("required").%Push("Panel")
    }
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The worklist's class, named exactly as the Worklists list reports it in its Class column. A worklist the list does not report is refused.", "string")
    Quit tSchema
}

/// <p>The state this write moves the option to, put into the fresh read the screen's action then builds its payload from, as <method>MergeUpdate</method> puts it into the agent's. The action
/// takes no value of its own.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If $IsObject(pFresh) Do pFresh.%Set("Shown", ''..#SHOWN, "boolean")
    Quit $$$OK
}

/// <p>The option's own state with <code>Shown</code> set to the state this write moves it to: the stored payload and the digest a confirm recomputes are taken from it, so they agree for the same option
/// whatever its state has become since.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set pPayload = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
    Do pPayload.%Set("Shown", ''..#SHOWN, "boolean")
    Quit $$$OK
}

/// <p>The card's rows, from the fresh read <var>pFresh</var>: the page, the panel and the worklist's class, and <code>Shown</code> moving to the state this write sets. A read that answered no
/// <code>Customized</code> flag refuses, since a state nobody established is not one to act on.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Customized") '= "boolean") {
            Set pProblem = "this instance did not report whether the worklists are customized"
            Quit
        }
        If 'pFresh.%Get("Customized") {
            Set pProblem = ##class(OcuPilot.Port.AnalyticsPort).ReasonFor("ANALYTICS.WORKLIST.NOTCUSTOMIZED")
            Quit
        }
        For tField = "Page", "Panel", "Class", "Shown" {
            Set tBefore = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField))
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", tBefore, "string")
            Do tRow.%Set("after", $Select(tField = "Shown": ##class(OcuPilot.Kernel.Proposal.Mint).Display(''..#SHOWN, "boolean"), 1: tBefore), "string")
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
