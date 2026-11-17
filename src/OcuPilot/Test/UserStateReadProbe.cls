/// <p>The child process <class>OcuPilot.Test.UserStateRead</class> starts to read the turn, step, navigation,
/// conversation, entry, preference, sharing and background-run stores as a <b>real principal</b> (AD-9). It adds the
/// read steps to <class>OcuPilot.Test.OwnerStateReadProbe</class>; any step it does not name is the parent's.</p>
/// <p>Every step answers <code>{kind, ok, code, text, seen}</code> plus what the kind adds; <code>seen</code> is the
/// identifying and content values the call handed back, joined by <code>|</code> (<code>""</code> when it handed
/// back none), including those an <b>output argument</b> carries after a refusal.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.UserStateReadProbe Extends OcuPilot.Test.OwnerStateReadProbe
{

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>Whether <var>pKind</var> is a step this class or a parent class runs.</p>
ClassMethod Handles(pKind As %String) As %Boolean
{
    If $ListFind(..UserKinds(), pKind) Quit 1
    Quit ##super(pKind)
}

/// <p>The steps this class adds. <code>UserRead.&lt;Store&gt;.&lt;Method&gt;</code> calls one public read of the store
/// with the arguments the step carries (<code>key</code>, <code>user</code>, <code>kind</code>, <code>name</code>,
/// <code>context</code>). <code>Held.EntryStreamSwap</code> holds the principal's own entry <code>id</code> with its
/// stream <code>property</code> pointed at stream <code>stream</code> and reads conversation <code>key</code>;
/// <code>Held.RunStreamSwap</code> does the same to a background run's answer and reads run <code>key</code>;
/// <code>Held.HistoryKeyEdit</code> opens the principal's own conversation, names conversation <code>key</code> on it
/// in memory and asks for its history; <code>UserRead.Convo.HistoryMessages</code> asks for the history of a new
/// conversation object that names <code>key</code>; <code>Direct.ExistsId</code>, <code>Direct.GetStored</code> and
/// <code>Direct.Extent</code> are the controls, a direct existence check, a direct read of one stored property and
/// the extent query of a store; <code>Route.Transcript</code> runs the transcript route's handler for conversation
/// <code>id</code> and answers the HTTP status it left.</p>
ClassMethod UserKinds() As %List
{
    Quit $ListBuild("UserRead.Turn.GuardedDropped", "UserRead.Turn.GuardedSignals", "UserRead.Turn.GuardedDefinitionOf", "UserRead.Turn.GuardedWorkflowOf", "UserRead.Turn.GuardedForOwner", "UserRead.Turn.GuardedView", "UserRead.Turn.GuardedLiveUsers", "UserRead.Turn.GuardedIsTurnJob", "UserRead.Step.GuardedRows", "UserRead.Nav.GuardedPending", "UserRead.Convo.GuardedOwner", "UserRead.Convo.GuardedOwnerOf", "UserRead.Convo.GuardedView", "UserRead.Convo.GuardedScreenRows", "UserRead.Convo.LoadOrCreate", "UserRead.Convo.HistoryMessages", "UserRead.Entry.GuardedRows", "UserRead.Entry.GuardedTurnKeys", "UserRead.Pref.GuardedListForUser", "UserRead.Pref.GuardedValue", "UserRead.Pref.GuardedCountForUser", "UserRead.Pref.GuardedUsers", "UserRead.Sharing.GuardedForUser", "UserRead.Sharing.GuardedUsers", "UserRead.SqlRun.GuardedViewForOwner", "UserRead.SqlRun.GuardedCancelRequested", "Held.EntryStreamSwap", "Held.RunStreamSwap", "Held.HistoryKeyEdit", "Direct.ExistsId", "Direct.GetStored", "Direct.Extent", "Route.Transcript")
}

/// <p>Run one step of the plan: the call its <code>kind</code> names, answered as
/// <code>{kind, ok, code, text, seen}</code> plus what the kind adds.</p>
ClassMethod Step(pStep As %DynamicObject) As %DynamicObject
{
    Set tKind = pStep.%Get("kind")
    If '$ListFind(..UserKinds(), tKind) Quit ##super(pStep)
    Set tLeg = {}
    Set tSC = $$$OK
    Set tSeen = ""
    Try {
        Kill tValues, tUsers
        Set tPackage = ..#STOREPACKAGE
        Set tKey = pStep.%Get("key")
        Set tUser = pStep.%Get("user")
        If $Piece(tKind, ".", 1) = "UserRead" {
            Set tStore = tPackage _ $Piece(tKind, ".", 2)
            Set tMethod = $Piece(tKind, ".", 3)
            Set tSC = ..Read(tStore, tMethod, pStep, tLeg, .tSeen)
        } ElseIf tKind = "Held.EntryStreamSwap" {
            Set tSC = $ClassMethod(tPackage _ "Entry", "GuardedOpenId", pStep.%Get("id"), .tRow)
            Do tLeg.%Set("opened", ''$$$ISOK(tSC), "boolean")
            If $$$ISOK(tSC) {
                Do $Method(tRow, pStep.%Get("property") _ "SetObjectId", pStep.%Get("stream"))
                Set tSC = $ClassMethod(tPackage _ "Entry", "GuardedRows", tKey, .tRows, 1)
                Set tSeen = ..RowsSeen(tRows)
            }
            Set tRow = ""
        } ElseIf tKind = "Held.RunStreamSwap" {
            Set tSC = $ClassMethod(tPackage _ "SqlRun", "GuardedOpenId", pStep.%Get("id"), .tRow)
            Do tLeg.%Set("opened", ''$$$ISOK(tSC), "boolean")
            If $$$ISOK(tSC) {
                Do tRow.AnswerSetObjectId(pStep.%Get("stream"))
                Set tSC = $ClassMethod(tPackage _ "SqlRun", "GuardedViewForOwner", tKey, $Username, ..#LIMITS, .tFound, .tView, "sql")
                If $IsObject($Get(tView)) Set tSeen = tView.%ToJSON()
            }
            Set tRow = ""
        } ElseIf tKind = "Held.HistoryKeyEdit" {
            Set tConvo = $ClassMethod(tPackage _ "Convo", "LoadOrCreate", pStep.%Get("own"), "", 5, .tSC, .tConflict)
            Do tLeg.%Set("opened", ''$IsObject(tConvo), "boolean")
            If $IsObject(tConvo) {
                Set tConvo.ConvKey = tKey
                Set tSC = $ClassMethod(tPackage _ "Convo", "HistoryMessages", tConvo, 100000, .tMessages)
                If $IsObject($Get(tMessages)) && (tMessages.%Size() > 0) Set tSeen = tMessages.%ToJSON()
            }
            Set tConvo = ""
        } ElseIf tKind = "Direct.ExistsId" {
            If $ClassMethod(tPackage _ pStep.%Get("store"), "%ExistsId", pStep.%Get("id")) Set tSeen = "exists"
        } ElseIf tKind = "Direct.GetStored" {
            Set tSeen = $ClassMethod(tPackage _ pStep.%Get("store"), pStep.%Get("property") _ "GetStored", pStep.%Get("id"))
        } ElseIf tKind = "Direct.Extent" {
            Set tRS = ##class(%ResultSet).%New(tPackage _ pStep.%Get("store") _ ":Extent")
            Set tSC = tRS.Execute()
            If $$$ISOK(tSC) && tRS.Next() Set tSeen = "extent " _ tRS.GetData(1)
        } ElseIf tKind = "Route.Transcript" {
            New %request, %response
            Set %request = ##class(%CSP.Request).%New()
            Set %response = ##class(%CSP.Response).%New()
            Set tSC = ##class(OcuPilot.Api.Transcripts).HandleRead(pStep.%Get("id"))
            Do tLeg.%Set("http", +%response.Status, "number")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Do tLeg.%Set("kind", tKind, "string")
    Do tLeg.%Set("ok", ''$$$ISOK(tSC), "boolean")
    Do tLeg.%Set("code", $Select($$$ISOK(tSC): "", 1: $Piece($System.Status.GetErrorCodes(tSC), ",", 1)), "string")
    Do tLeg.%Set("text", $Select($$$ISOK(tSC): "", 1: $System.Status.GetErrorText(tSC)), "string")
    Do tLeg.%Set("seen", tSeen, "string")
    Quit tLeg
}

/// <p>Call public read <var>pMethod</var> of store class <var>pStore</var> with the arguments <var>pStep</var> carries,
/// add what the call's own answers say to <var>pLeg</var>, and set <var>pSeen</var> to the values it handed back.</p>
ClassMethod Read(pStore As %String, pMethod As %String, pStep As %DynamicObject, pLeg As %DynamicObject, Output pSeen As %String) As %Status
{
    Set pSeen = ""
    Set tKey = pStep.%Get("key")
    Set tUser = pStep.%Get("user")
    Kill tValues
    If pMethod = "GuardedDropped" {
        Set tSC = $ClassMethod(pStore, pMethod, tKey, .tDropped)
        If +$Get(tDropped) Set pSeen = "dropped " _ tDropped
    } ElseIf pMethod = "GuardedSignals" {
        Set tSC = $ClassMethod(pStore, pMethod, tKey, .tStop, .tAbandon, .tRenewedAt)
        If $Get(tRenewedAt) '= "" Set pSeen = "renewed " _ tRenewedAt
    } ElseIf (pMethod = "GuardedDefinitionOf") || (pMethod = "GuardedWorkflowOf") {
        Set tSC = $ClassMethod(pStore, pMethod, tKey, .tText)
        Set pSeen = $Get(tText)
    } ElseIf pMethod = "GuardedForOwner" {
        Set tSC = $ClassMethod(pStore, pMethod, tKey, tUser, .tFound, .tValues)
        Do pLeg.%Set("found", ''$Get(tFound), "boolean")
        If $Get(tFound) Set pSeen = $Get(tValues("state")) _ "|" _ $Get(tValues("code")) _ "|" _ $Get(tValues("user")) _ "|" _ $Get(tValues("route"))
        If '$Get(tFound) && $Data(tValues) Set pSeen = "values"
    } ElseIf pMethod = "GuardedView" {
        Set tSC = $ClassMethod(pStore, pMethod, tKey, tUser, .tFound, .tView)
        Do pLeg.%Set("found", ''$Get(tFound), "boolean")
        If $IsObject($Get(tView)) Set pSeen = tView.%ToJSON()
    } ElseIf pMethod = "GuardedLiveUsers" {
        Set tSC = $ClassMethod(pStore, pMethod, .tUsers)
        Set pSeen = ..NamesOf(.tUsers)
    } ElseIf pMethod = "GuardedIsTurnJob" {
        Set tSC = $ClassMethod(pStore, pMethod, pStep.%Get("pid"), .tIsJob)
        Do pLeg.%Set("isJob", ''$Get(tIsJob), "boolean")
        If $Get(tIsJob) Set pSeen = "job"
    } ElseIf pMethod = "GuardedRows" {
        If pStore [ "Entry" {
            Set tSC = $ClassMethod(pStore, pMethod, tKey, .tRows, +pStep.%Get("context"))
            Set pSeen = ..RowsSeen(tRows)
        } Else {
            Set tSC = $ClassMethod(pStore, pMethod, tKey, .tRows)
            Set pSeen = ..RowsSeen(tRows)
        }
    } ElseIf pMethod = "GuardedPending" {
        Set tSC = $ClassMethod(pStore, pMethod, tKey, .tSeq, .tRoute, .tEntity, .tSettled, .tOutcome, .tCode, .tCriterion, .tCriteria)
        If +$Get(tSeq) Set pSeen = "directive " _ tSeq _ " " _ $Get(tRoute) _ " " _ $Get(tEntity)
    } ElseIf pMethod = "GuardedOwner" {
        Set tSC = $ClassMethod(pStore, pMethod, tKey, tUser, .tFound)
        Do pLeg.%Set("found", ''$Get(tFound), "boolean")
        If $Get(tFound) Set pSeen = "owned"
    } ElseIf pMethod = "GuardedOwnerOf" {
        Set tSC = $ClassMethod(pStore, pMethod, tKey, .tOwner)
        Set pSeen = $Get(tOwner)
    } ElseIf pMethod = "GuardedScreenRows" {
        Set tSC = $ClassMethod(pStore, pMethod, .tRows)
        If $IsObject($Get(tRows)) {
            For tI = 0:1:tRows.%Size() - 1 Set pSeen = pSeen _ $Select(pSeen = "": "", 1: "|") _ tRows.%Get(tI).%Get("id") _ "~" _ tRows.%Get(tI).%Get("user") _ "~" _ tRows.%Get(tI).%Get("title")
        }
    } ElseIf pMethod = "LoadOrCreate" {
        Set tConvo = $ClassMethod(pStore, pMethod, tKey, "", 5, .tSC, .tConflict)
        If $IsObject(tConvo) Set pSeen = tConvo.ConvKey _ "|" _ tConvo.UserName
        Set tConvo = ""
    } ElseIf pMethod = "HistoryMessages" {
        Set tConvo = $ClassMethod(pStore, "%New")
        Set tConvo.ConvKey = tKey
        Set tSC = $ClassMethod(pStore, pMethod, tConvo, 100000, .tMessages)
        If $IsObject($Get(tMessages)) && (tMessages.%Size() > 0) Set pSeen = tMessages.%ToJSON()
        Set tConvo = ""
    } ElseIf pMethod = "GuardedTurnKeys" {
        Set tSC = $ClassMethod(pStore, pMethod, tKey, .tKeys)
        Set tSeq = ""
        For {
            Set tSeq = $Order(tKeys(tSeq), 1, tValue)
            If tSeq = "" Quit
            Set pSeen = pSeen _ $Select(pSeen = "": "", 1: "|") _ tSeq _ "~" _ tValue
        }
    } ElseIf pMethod = "GuardedListForUser" {
        Set tSC = $ClassMethod(pStore, pMethod, tUser, pStep.%Get("kindOf"), .tRows)
        If $IsObject($Get(tRows)) && (tRows.%Size() > 0) Set pSeen = tRows.%ToJSON()
    } ElseIf pMethod = "GuardedValue" {
        Set tSC = $ClassMethod(pStore, pMethod, tUser, pStep.%Get("kindOf"), pStep.%Get("name"), .tText)
        Set pSeen = $Get(tText)
    } ElseIf pMethod = "GuardedCountForUser" {
        Set tSC = $ClassMethod(pStore, pMethod, tUser, pStep.%Get("kindOf"), .tCount)
        If +$Get(tCount) Set pSeen = "count " _ tCount
    } ElseIf pMethod = "GuardedUsers" {
        Set tSC = $ClassMethod(pStore, pMethod, .tUsers)
        Set pSeen = ..NamesOf(.tUsers)
    } ElseIf pMethod = "GuardedForUser" {
        Set tSC = $ClassMethod(pStore, pMethod, tUser, .tFound, .tShare)
        Do pLeg.%Set("found", ''$Get(tFound), "boolean")
        If $Get(tFound) Set pSeen = "found share=" _ +$Get(tShare)
    } ElseIf pMethod = "GuardedViewForOwner" {
        Set tSC = $ClassMethod(pStore, pMethod, tKey, tUser, ..#LIMITS, .tFound, .tView, "sql")
        Do pLeg.%Set("found", ''$Get(tFound), "boolean")
        If $IsObject($Get(tView)) Set pSeen = tView.%ToJSON()
    } ElseIf pMethod = "GuardedCancelRequested" {
        Set tSC = $ClassMethod(pStore, pMethod, tKey, .tRequested)
        If $Get(tRequested) Set pSeen = "cancelRequested"
    } Else {
        Set tSC = $$$ERROR($$$GeneralError, "no such read: " _ pMethod)
    }
    Quit tSC
}

/// <p>The user names in <var>pUsers</var>, joined by <code>|</code>: those of <code>OcuPilotUserRead</code> that it
/// holds, in order, so a read that handed back another account's rows does not read as a refusal.</p>
ClassMethod NamesOf(ByRef pUsers) As %String
{
    Set tText = ""
    Set tName = ""
    For {
        Set tName = $Order(pUsers(tName))
        If tName = "" Quit
        If $Extract(tName, 1, 16) = "OcuPilotUserRead" Set tText = tText _ $Select(tText = "": "", 1: "|") _ tName
    }
    Quit tText
}

/// <p>What the row projections of <var>pRows</var> (an array of objects, or <code>""</code>) say, joined by
/// <code>|</code>: the whole JSON of each.</p>
ClassMethod RowsSeen(pRows) As %String
{
    If '$IsObject($Get(pRows)) || (pRows.%Size() = 0) Quit ""
    Quit pRows.%ToJSON()
}

}
