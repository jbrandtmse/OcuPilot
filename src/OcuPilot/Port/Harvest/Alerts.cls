/// <p>The system alerts bodies harvested from the sibling suite (AD-23), reached only through
/// <class>OcuPilot.Port.HarvestPort</class>. <class>OcuPilot.Port.MonitorPort</class> is their one caller:
/// it reads <method>SystemAlerts</method> with no body and sends <method>AlertsManage</method> only
/// <code>{"action":"reset"}</code>.</p>
/// <p>Outside a <class>OcuPilot.Port.HarvestPort</class> call they record nothing and fail; what keeps them
/// behind the port's gate is the containment rule in <file>scripts/check-objectscript.py</file>.</p>
Class OcuPilot.Port.Harvest.Alerts Extends OcuPilot.Port.Harvest.Handler
{

/// Return active system alerts in JSON format.
/// <p>Queries <code>$SYSTEM.Monitor</code> for the current system state and
/// alert information. Returns the state code, state text, alert count, and
/// alert messages array.</p>
ClassMethod SystemAlerts() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tResult = {}

        ; Switch to %SYS for system monitor queries
        Set $NAMESPACE = "%SYS"

        ; -- System state from $SYSTEM.Monitor.State() --
        ; Returns: -1=Hung, 0=OK, 1=Warning, 2=Alert
        Set tState = $SYSTEM.Monitor.State()
        Set tStateText = $Case(tState, -1:"Hung", 0:"OK", 1:"Warning", 2:"Alert", :"Unknown")
        Do tResult.%Set("state", +tState, "number")
        Do tResult.%Set("stateText", tStateText)

        ; -- Alert count from $SYSTEM.Monitor.Alerts() --
        Set tAlertCount = $SYSTEM.Monitor.Alerts()
        Do tResult.%Set("alertCount", +tAlertCount, "number")

        ; -- Get alert details via $SYSTEM.Monitor.GetAlerts() --
        Set tAlerts = []
        Set tAlertData = ""
        Set tMessages = ""
        Set tLastAlert = ""
        Set tSC2 = $SYSTEM.Monitor.GetAlerts(.tAlertData, .tMessages, .tLastAlert)
        If $$$ISOK(tSC2) {
            ; tMessages is a subscripted array — iterate if available
            Set tKey = ""
            For {
                Set tKey = $Order(tMessages(tKey))
                Quit:tKey=""
                Set tAlert = {}
                Do tAlert.%Set("index", +tKey, "number")
                Do tAlert.%Set("message", $Get(tMessages(tKey)))
                Do tAlert.%Set("severity", tStateText)
                Do tAlert.%Set("category", "system")
                Do tAlerts.%Push(tAlert)
            }
        }
        Do tResult.%Set("alerts", tAlerts)
        Do tResult.%Set("lastAlert", tLastAlert)

        Set $NAMESPACE = tOrigNS
        Do ..RenderResponseBody($$$OK, , tResult)
    }
    Catch ex {
        Set $NAMESPACE = tOrigNS
        Do ..RenderResponseBody(..SanitizeError(ex.AsStatus()))
        Set tSC = $$$OK
    }
    Quit $$$OK
}

/// Reset the system alert counter and state via <code>$SYSTEM.Monitor.Clear()</code>.
/// <p>Accepts a JSON body with a single field: <code>action</code> (must be "reset").</p>
/// <p>The "reset" action calls <code>$SYSTEM.Monitor.Clear()</code> in the <b>%SYS</b>
/// namespace, which clears the in-memory alert counter and resets the system monitor
/// state. The <code>alerts.log</code> file is <b>NOT</b> truncated — historical entries
/// remain on disk for audit.</p>
/// <p><code>clearedAt</code> is the UTC time of the reset (ISO 8601, to the second).</p>
ClassMethod AlertsManage() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        ; Read JSON body BEFORE namespace switch (Utils is in HSCUSTOM, not %SYS)
        Set tSC = ..ReadRequestBody(.tBody)
        If $$$ISERR(tSC) {
            Do ..RenderResponseBody(..SanitizeError(tSC))
            Set tSC = $$$OK
            Quit
        }
        If '$IsObject(tBody) {
            Set tSC = $$$ERROR($$$GeneralError, "Request body is required")
            Do ..RenderResponseBody(..SanitizeError(tSC))
            Set tSC = $$$OK
            Quit
        }

        ; Extract and validate 'action' field before namespace switch
        Set tAction = tBody.%Get("action")
        Set tSC = ..ValidateRequired(tAction, "action")
        If $$$ISERR(tSC) {
            Do ..RenderResponseBody(..SanitizeError(tSC))
            Set tSC = $$$OK
            Quit
        }

        ; Only "reset" is supported
        If tAction '= "reset" {
            Set tSC = $$$ERROR($$$GeneralError, "Invalid action '"_tAction_"'. Supported actions: reset.")
            Do ..RenderResponseBody(..SanitizeError(tSC))
            Set tSC = $$$OK
            Quit
        }

        ; Switch to %SYS for $SYSTEM.Monitor.Clear()
        Set $NAMESPACE = "%SYS"

        ; Clear the alert counter and system monitor state
        Do $SYSTEM.Monitor.Clear()

        ; Restore namespace before building response
        Set $NAMESPACE = tOrigNS

        ; Build response; clearedAt is the UTC time of the reset (ISO 8601, to the second)
        Set tResult = {}
        Do tResult.%Set("action", "reset")
        Do tResult.%Set("clearedAt", ..UtcStamp())

        Do ..RenderResponseBody($$$OK, , tResult)
    }
    Catch ex {
        Set $NAMESPACE = tOrigNS
        Do ..RenderResponseBody(..SanitizeError(ex.AsStatus()))
        Set tSC = $$$OK
    }
    Quit $$$OK
}

/// The UTC instant <var>pNow</var> as ISO 8601 text, <code>YYYY-MM-DDThh:mm:ssZ</code>.
/// <p><var>pNow</var> is a <code>$ZTimeStamp</code> value; the empty string means the
/// current <code>$ZTimeStamp</code>. Fractional seconds are truncated, never rounded, so the
/// result never moves to the next second or day. The result is independent of the process
/// time zone and never reads the local clock.</p>
ClassMethod UtcStamp(pNow As %String = "") As %String
{
    If pNow = "" Set pNow = $ZTimeStamp
    Quit $Translate($ZDateTime($Piece(pNow, "."), 3, 1), " ", "T")_"Z"
}

}
