/// <p>The task delete's port (AD-52): <class>OcuPilot.Port.AdminPort</class> with one read
/// completed. A <code>Task.CRUD</code> <code>GET</code> that succeeds is followed by the same
/// endpoint's <code>INFO</code> with the same query, and <code>INFO</code>'s <code>Type</code> is
/// set on the <code>GET</code>'s answer. Every other endpoint and request type is the admin port's
/// own call, unchanged.</p>
/// <p><b>Why the read is completed here.</b> Measured on this build: <code>GET</code> answers the
/// task's <code>Name</code>, <code>TaskClass</code> and <code>NameSpace</code> and no
/// <code>Type</code>, while <code>INFO</code> answers <code>Type</code> (<code>System</code> or
/// <code>User</code>) and no <code>Name</code>. A delete's card names the task and says whether it
/// is one of the instance's own system tasks, so its one fresh read needs both. Which request
/// types carry which field is a vendor wire fact, so it lives in a port (AD-27); the tool declaring
/// this port is what makes the mint's read, the confirm's re-read, the prohibited set's live read
/// and the screen caller's read one answer (AD-52, AD-53).</p>
/// <p><b>It names no administration API class.</b> Both calls go through
/// <method>OcuPilot.Port.AdminPort.Invoke</method>, so the endpoint's gate, the stubs, the
/// namespace switch and the fault mapping are the admin port's, and AD-27's one-file containment
/// is unchanged.</p>
/// <p><b>A create's answer carries the new task's <code>Id</code></b> (Story 9.7). The vendor's
/// <code>POST</code> answers the saved task without its id, which is only in the 201's
/// <code>Location</code> header (<code>/api/admin/v1/task?id=&lt;n&gt;</code>, measured on this
/// build); this port reads that header and sets <code>Id</code>, an integer, on the answer.</p>
/// <p><b>A task whose type declares a classic-only setting is read without its settings</b> (Story 9.8,
/// AD-35). A setting is classic-only when it is typed <parameter>PASSWORDTYPE</parameter> or a
/// subclass, when its name is a credential's, or when it is a collection
/// (<method>ClassicOnlySettings</method>, the one classifier). The vendor answers every setting's
/// value, so a <code>GET</code>, <code>PUT</code> or <code>POST</code> answer for such a task drops the
/// whole <code>Settings</code> object and no secret-typed value reaches a read, a payload, a diff or a
/// ledger row.</p>
/// <p><b>An edit sends only what the vendor keeps</b> (Story 9.8, AD-4's named exception). Measured on
/// this build: a <code>PUT</code> carrying <code>Type</code> answers 400; one that re-sends an unchanged
/// <code>DailyStartTime</code> or <code>DailyEndTime</code> on a task whose start has passed answers
/// 409 #7432; a sent <code>Settings</code> replaces every setting; and a key the body omits is kept. So
/// a <code>Task.CRUD</code> <code>PUT</code> drops <code>Type</code>, and drops the two times and
/// <code>Settings</code> where they equal what the task holds, read fresh inside the call.</p>
Class OcuPilot.Port.TaskPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint whose <code>GET</code> this port completes.</p>
Parameter TASKENDPOINT = "Task.CRUD";

/// <p>The request type completed, and the one it is completed from.</p>
Parameter COMPLETEDTYPE = "GET";

Parameter COMPLETINGTYPE = "INFO";

/// <p>The one <parameter>COMPLETINGTYPE</parameter> field set on the answer.</p>
Parameter COMPLETINGFIELD = "Type";

/// <p>The create's request type, whose answer gains <parameter>CREATEDFIELD</parameter>.</p>
Parameter CREATETYPE = "POST";

/// <p>The field the new task's id is set under.</p>
Parameter CREATEDFIELD = "Id";

/// <p>The edit's request type, whose body <method>Update</method> trims.</p>
Parameter UPDATETYPE = "PUT";

/// <p>The field a task type's own settings travel under.</p>
Parameter SETTINGSFIELD = "Settings";

/// <p>The vendor's secret setting type: a setting of this type or a subclass is never read back.</p>
Parameter PASSWORDTYPE = "%SYS.Task.Password";

/// <p>The two times the vendor re-checks against the clock on every save.</p>
Parameter CLOCKFIELDS = "DailyStartTime,DailyEndTime";

/// <p>The admin port's call, with a successful <parameter>TASKENDPOINT</parameter>
/// <parameter>COMPLETEDTYPE</parameter> followed by <parameter>COMPLETINGTYPE</parameter> over
/// the same <var>pQuery</var> and <parameter>COMPLETINGFIELD</parameter> set on
/// <var>pResult</var>.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s. A failed <code>GET</code> answers exactly as
/// the admin port does. A failed <code>INFO</code> fails the whole read with <code>INFO</code>'s
/// status, HTTP status and fault, and <var>pResult</var> empty, so a caller never sees a task
/// half-read. An <code>INFO</code> that answers no string <code>Type</code> leaves the field
/// absent, which a caller that needs it refuses.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If (pEndpoint = ..#TASKENDPOINT) && (pType = ..#CREATETYPE) Quit ..Create(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If (pEndpoint = ..#TASKENDPOINT) && (pType = ..#UPDATETYPE) && $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
        ; AD-4's named exception: the stored task, read fresh here, decides what the body omits.
        Set tReadSC = ##super(pEndpoint, ..#COMPLETEDTYPE, .pQuery, "", .tStored, .tReadHttp, .tReadFault)
        If $$$ISERR(tReadSC) {
            Set pResult = ""
            Set pHttpStatus = tReadHttp
            Set pFault = tReadFault
            Quit tReadSC
        }
        Set pBody = ..Trimmed(pBody, $Get(tStored))
        Set tStored = ""
    }
    Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If pEndpoint '= ..#TASKENDPOINT Quit tSC
    If (pType '= ..#COMPLETEDTYPE) && (pType '= ..#UPDATETYPE) Quit tSC
    If '$IsObject(pResult) || 'pResult.%IsA("%Library.DynamicObject") Quit tSC
    ; AD-35: a type that declares a classic-only setting is answered without its settings.
    Do ..WithholdSettings(pResult)
    If pType '= ..#COMPLETEDTYPE Quit tSC
    Set tInfoSC = ##super(pEndpoint, ..#COMPLETINGTYPE, .pQuery, "", .tInfo, .tInfoHttp, .tInfoFault)
    If $$$ISERR(tInfoSC) {
        Set pResult = ""
        Set pHttpStatus = tInfoHttp
        Set pFault = tInfoFault
        Quit tInfoSC
    }
    If $IsObject(tInfo) && tInfo.%IsA("%Library.DynamicObject") && (tInfo.%GetTypeOf(..#COMPLETINGFIELD) = "string") {
        Do pResult.%Set(..#COMPLETINGFIELD, tInfo.%Get(..#COMPLETINGFIELD), "string")
    }
    Quit tSC
}

/// <p>A copy of the edit body <var>pBody</var> the vendor keeps whole: without <code>Type</code>, which
/// this port's own read adds and the vendor refuses, and without each <parameter>CLOCKFIELDS</parameter>
/// time and <parameter>SETTINGSFIELD</parameter> that equals what <var>pStored</var>, the task's fresh
/// read, holds. A time is compared by its value, so <code>01:00</code> and <code>01:00:00</code> are
/// one time.</p>
ClassMethod Trimmed(pBody As %DynamicObject, pStored As %DynamicObject) As %DynamicObject
{
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
    If tBody.%GetTypeOf(..#COMPLETINGFIELD) '= "unassigned" Do tBody.%Remove(..#COMPLETINGFIELD)
    If '$IsObject(pStored) || 'pStored.%IsA("%Library.DynamicObject") Quit tBody
    For tI = 1:1:$Length(..#CLOCKFIELDS, ",") {
        Set tField = $Piece(..#CLOCKFIELDS, ",", tI)
        If tBody.%GetTypeOf(tField) '= "string" Continue
        Set tSent = ..Seconds(tBody.%Get(tField))
        If (tSent '= "") && (tSent = ..Seconds(pStored.%Get(tField))) Do tBody.%Remove(tField)
    }
    If (tBody.%GetTypeOf(..#SETTINGSFIELD) = "object") && (pStored.%GetTypeOf(..#SETTINGSFIELD) = "object") {
        If ..SameSettings(tBody.%Get(..#SETTINGSFIELD), pStored.%Get(..#SETTINGSFIELD)) Do tBody.%Remove(..#SETTINGSFIELD)
    }
    Quit tBody
}

/// <p>Whether two settings objects name the same keys with the same values, each compared as
/// text.</p>
ClassMethod SameSettings(pOne As %DynamicObject, pTwo As %DynamicObject) As %Boolean [ Private ]
{
    Quit ..Covers(pOne, pTwo) && ..Covers(pTwo, pOne)
}

/// <p>Whether every key of <var>pFrom</var> is one <var>pTo</var> holds with the same text.</p>
ClassMethod Covers(pFrom As %DynamicObject, pTo As %DynamicObject) As %Boolean [ Private ]
{
    Set tSame = 1
    Set tIterator = pFrom.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If pTo.%GetTypeOf(tKey) = "unassigned" Set tSame = 0 Quit
        If ..SettingText(pFrom, tKey) '= ..SettingText(pTo, tKey) Set tSame = 0 Quit
    }
    Quit tSame
}

/// <p>A setting's value as the text the vendor stores.</p>
ClassMethod SettingText(pObject As %DynamicObject, pKey As %String) As %String [ Private ]
{
    Set tType = pObject.%GetTypeOf(pKey)
    If tType = "boolean" Quit $Select(pObject.%Get(pKey): "1", 1: "0")
    If (tType = "string") || (tType = "number") Quit "" _ pObject.%Get(pKey)
    Quit ""
}

/// <p><var>pTime</var> (<code>HH:MM</code> or <code>HH:MM:SS</code>) in seconds after midnight, or
/// <code>""</code>.</p>
ClassMethod Seconds(pTime As %String) As %String [ Private ]
{
    If '$Match(pTime, "^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$") Quit ""
    Quit ($Piece(pTime, ":", 1) * 3600) + ($Piece(pTime, ":", 2) * 60) + $Piece(pTime, ":", 3)
}

/// <p>Remove <var>pTask</var>'s <parameter>SETTINGSFIELD</parameter> when its type declares a
/// classic-only setting (<method>ClassicOnlySettings</method>). A type that cannot be read -- one not
/// compiled in the task's namespace among them -- is treated as one that does, so a setting that
/// cannot be classified is never answered.</p>
ClassMethod WithholdSettings(pTask As %DynamicObject)
{
    If pTask.%GetTypeOf(..#SETTINGSFIELD) = "unassigned" Quit
    Set tSC = ..ClassicOnlySettings(pTask.%Get("TaskClass"), pTask.%Get("NameSpace"), .tKinds, .tRead)
    If $$$ISERR(tSC) || '$Get(tRead) || ($Data(tKinds) > 1) Do pTask.%Remove(..#SETTINGSFIELD)
}

/// <p>The classic-only settings of task type <var>pClass</var> in <var>pNamespace</var>, as
/// <code>pKinds(name) = "secret"|"collection"</code>: the one classifier (Story 9.8). A setting is
/// every property that is neither private nor <code>%</code>-named, which is what the vendor's
/// <code>GetSettings</code> serializes; it is <code>secret</code> when it is typed
/// <parameter>PASSWORDTYPE</parameter> or a subclass or its name is a credential's
/// (<method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>), and <code>collection</code> when it
/// is a list or array. A class that is not compiled there answers none, and <var>pRead</var> 0.</p>
/// <p><b>Caller contract:</b> the dictionary is read in <var>pNamespace</var> by explicit save and
/// restore (AD-16); the classification is made back in the caller's namespace. <var>pRead</var> is
/// whether the class was found and read.</p>
ClassMethod ClassicOnlySettings(pClass As %String, pNamespace As %String, Output pKinds, Output pRead As %Boolean) As %Status
{
    Kill pKinds
    Set pRead = 0
    Set tSC = $$$OK
    If '$Match(pClass, "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") || (pNamespace = "") Quit tSC
    Set tPasswordType = ..#PASSWORDTYPE
    Set tOrigNS = $NAMESPACE
    Kill tRaw
    Try {
        Set $NAMESPACE = pNamespace
        Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(pClass, 0)
        If $IsObject(tCompiled) {
            Set pRead = 1
            Set tProperties = tCompiled.Properties
            For tP = 1:1:tProperties.Count() {
                Set tProperty = tProperties.GetAt(tP)
                If tProperty.Private || ($Extract(tProperty.Name) = "%") Continue
                Set tPassword = 0
                Try {
                    Set tPassword = ''$ClassMethod(tProperty.Type, "%Extends", tPasswordType)
                } Catch {
                    Set tPassword = 0
                }
                Set tRaw($Increment(tRaw)) = $ListBuild(tProperty.Name, tPassword, tProperty.Collection)
            }
            Set tProperties = ""
        }
        Set tCompiled = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tRaw) {
        Set tKind = ..ClassicOnlyKind($List(tRaw(tI), 1), $List(tRaw(tI), 2), $List(tRaw(tI), 3))
        If tKind '= "" Set pKinds($List(tRaw(tI), 1)) = tKind
    }
    Quit tSC
}

/// <p>Whether a setting named <var>pName</var> is classic-only: <code>secret</code> when
/// <var>pPasswordTyped</var> or its name is a credential's, <code>collection</code> when
/// <var>pCollection</var> names one, and <code>""</code> otherwise.</p>
ClassMethod ClassicOnlyKind(pName As %String, pPasswordTyped As %Boolean, pCollection As %String) As %String
{
    If pPasswordTyped Quit "secret"
    If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(pName) Quit "secret"
    If pCollection '= "" Quit "collection"
    Quit ""
}

/// <p>The admin port's create, with the new task's id read from the 201's <code>Location</code> and
/// set on <var>pResult</var> as <parameter>CREATEDFIELD</parameter>. A 2xx whose header carries no
/// numeric <code>id=</code> leaves the field absent, which a caller that needs it refuses.</p>
ClassMethod Create(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..InvokeLocated(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .tLocation)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject(pResult) && pResult.%IsA("%Library.DynamicObject") Do ..WithholdSettings(pResult)
    Set tId = $Piece($Piece($Get(tLocation), "id=", 2), "&", 1)
    If '$Match(tId, "^[0-9]+$") Quit tSC
    If '$IsObject(pResult) || 'pResult.%IsA("%Library.DynamicObject") Set pResult = {}
    Do pResult.%Set(..#CREATEDFIELD, +tId, "number")
    Quit tSC
}

/// <p>The admin port's answer: this port's create and edit are the vendor's own routes.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): <parameter>UPDATETYPE</parameter>
/// sends <method>Trimmed</method>'s body, measured against the stored task the proposal read. A
/// field the proposal's diff (<code>pContext.diff</code>, its changed field names) does not name
/// still holds that read's value, so it is the comparison's stored value; a field the diff names
/// is kept. Every other call is the admin port's script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint = ..#TASKENDPOINT) && (pType = ..#UPDATETYPE) && $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
        Set tStored = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
        If $IsObject(pContext) && (pContext.%GetTypeOf("diff") = "array") {
            Set tIterator = pContext.%Get("diff").%GetIterator()
            While tIterator.%GetNext(.tIndex, .tField) {
                If '$IsObject(tField) && (tField '= "") Do tStored.%Remove(tField)
            }
        }
        Set pBody = ..Trimmed(pBody, tStored)
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

}
