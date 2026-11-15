/// <p>The backup body harvested from the sibling suite (AD-23), reached only through
/// <class>OcuPilot.Port.HarvestPort</class>. <class>OcuPilot.Port.BackupPort</class> is its one caller
/// and sends it only <code>{"action":"listHistory"}</code> or
/// <code>{"action":"run","taskName":&lt;name&gt;,"jobbackup":1}</code>.</p>
/// <p>Outside a <class>OcuPilot.Port.HarvestPort</class> call it records nothing and fails; what keeps it
/// behind the port's gate is the containment rule in <file>scripts/check-objectscript.py</file>.</p>
Class OcuPilot.Port.Harvest.Monitor Extends OcuPilot.Port.Harvest.Handler
{

/// Run a backup task, or list backup history.
/// <p>Backed by <code>Backup.General</code> in <code>%SYS</code>:
/// <ul>
/// <li><b>run</b> &rarr; <code>StartTask(taskName, jobbackup, quietflag)</code> runs a backup task BY NAME.
/// The instance ships four tasks (<code>FullAllDatabases</code>, <code>FullDBList</code>,
/// <code>IncrementalDBList</code>, <code>CumuIncrDBList</code>) and lists any the operator defined.
/// Requires <code>taskName</code>.</li>
/// <li><b>listHistory</b> (read) &rarr; walks <code>^SYS("BUHISTORY", hindex, ...)</code>
/// most-recent-first, returning timestamp / type / status / device / log / description.</li>
/// </ul>
/// <code>BackupPort</code> reaches only <code>listHistory</code> and <code>run</code>. Its freeze passes
/// no suspend limit and takes a log file, and its thaw takes credentials, so the port freezes and thaws
/// itself. Restore is not supported: IRIS restore is interactive and not scriptable through
/// <code>Backup.General</code>.</p>
ClassMethod BackupManage() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        ; Read + validate body BEFORE namespace switch (Utils is in HSCUSTOM, not %SYS)
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

        ; action (required)
        Set tAction = tBody.%Get("action")
        Set tSC = ..ValidateRequired(tAction, "action")
        If $$$ISERR(tSC) {
            Do ..RenderResponseBody(..SanitizeError(tSC))
            Set tSC = $$$OK
            Quit
        }

        ; -- restore guard (AC 16.3.3): defend the server even though restore is
        ; not in the tool's enum - refuse cleanly, never crash. --
        If tAction = "restore" {
            ; De-caret (Rule #33 / CR 22.1-3): SanitizeError strips ANY token
            ; containing a caret - including CLUMENU^JRNRESTO, whose caret is
            ; not "leading" but still falls inside a contiguous alnum run and
            ; gets removed. Both routine names are written WITHOUT carets here
            ; so they survive SanitizeError; the doc comment above (a
            ; non-sanitized surface) keeps the caret form.
            Set tSC = $$$ERROR($$$GeneralError, "Restore is not supported via this tool. IRIS restore is interactive (DBREST / CLUMENU in JRNRESTO) and not cleanly scriptable via Backup.General; use the IRIS restore utility or the Management Portal restore instead.")
            Do ..RenderResponseBody(..SanitizeError(tSC))
            Set tSC = $$$OK
            Quit
        }

        ; Validate action enum via EXACT membership (NOT a substring test).
        If (tAction'="run")&&(tAction'="freeze")&&(tAction'="thaw")&&(tAction'="listHistory") {
            Set tSC = $$$ERROR($$$GeneralError, "Invalid action '"_tAction_"'. Supported actions: run, freeze, thaw, listHistory. (restore is not supported - use the IRIS restore utility.)")
            Do ..RenderResponseBody(..SanitizeError(tSC))
            Set tSC = $$$OK
            Quit
        }

        ; Read params (defaults applied; "" coerces via +)
        Set tTaskName = tBody.%Get("taskName")
        Set tBackupType = tBody.%Get("backupType")
        Set tJobBackup = +tBody.%Get("jobbackup")
        Set tDevice = tBody.%Get("device")
        Set tLogFile = tBody.%Get("logFile")
        Set tDescription = tBody.%Get("description")
        Set tUsername = tBody.%Get("username")
        Set tPassword = tBody.%Get("password")

        ; run requires taskName (validate before NS switch - Utils is in HSCUSTOM)
        If tAction = "run" {
            Set tSC = ..ValidateRequired(tTaskName, "taskName")
            If $$$ISERR(tSC) {
                Do ..RenderResponseBody(..SanitizeError(tSC))
                Set tSC = $$$OK
                Quit
            }
        }

        Set $NAMESPACE = "%SYS"

        Set tActionSC = $$$OK
        Set tResult = {}
        Do tResult.%Set("action", tAction)

        If tAction = "listHistory" {
            ; Walk ^SYS("BUHISTORY", hindex, ...) most-recent-first. The hindex is
            ; date*1000000+time ($HOROLOG parts); the "0" index node is skipped by
            ; reverse $Order from "" (numeric keys are all positive).
            Set tEntries = []
            Set tCount = 0
            Set tMax = 50
            Set tKey = $Order(^SYS("BUHISTORY", ""), -1)
            While (tKey '= "") && (tCount < tMax) {
                ; Only treat canonical positive-integer subscripts as history index
                ; nodes. This skips the "0" metadata node (LOGNOTPURGED, etc.) AND
                ; defends against any non-numeric / non-canonical subscript a corrupt
                ; or foreign-written global might carry (which would otherwise feed
                ; garbage to $ZDateTime below).
                If (tKey = +tKey) && (tKey = (tKey \ 1)) && (+tKey > 0) {
                    Set tEntry = {}
                    ; Decode hindex = days*1000000 + seconds back to a $HOROLOG string.
                    ; Guard the timestamp render: a node whose seconds part is out of
                    ; $HOROLOG range (>=86400) or otherwise illegal must degrade this
                    ; ONE entry's timestamp gracefully, never abort the whole listing.
                    Set tHoro = (tKey \ 1000000) _ "," _ (tKey # 1000000)
                    Set tTimestamp = ""
                    Try {
                        Set tTimestamp = $ZDateTime(tHoro, 3)
                    } Catch tTSErr {
                        Set tTimestamp = ""
                    }
                    Do tEntry.%Set("timestamp", tTimestamp)
                    Do tEntry.%Set("type", $Get(^SYS("BUHISTORY", tKey, "TYPE")))
                    Do tEntry.%Set("status", $Get(^SYS("BUHISTORY", tKey, "STATUS")))
                    Do tEntry.%Set("device", $Get(^SYS("BUHISTORY", tKey, "DEVICE")))
                    Do tEntry.%Set("logFile", $Get(^SYS("BUHISTORY", tKey, "LOG")))
                    Do tEntry.%Set("description", $Get(^SYS("BUHISTORY", tKey, "DESC")))
                    Do tEntry.%Set("list", $Get(^SYS("BUHISTORY", tKey, "LIST")))
                    Do tEntries.%Push(tEntry)
                    Set tCount = tCount + 1
                }
                Set tKey = $Order(^SYS("BUHISTORY", tKey), -1)
            }
            Do tResult.%Set("entries", tEntries)
            Do tResult.%Set("count", tCount, "number")
        }
        ElseIf tAction = "run" {
            ; StartTask(taskname, jobbackup, quietflag) - quietflag=1 keeps output
            ; off the principal device (we have none in a REST context).
            Set tActionSC = ##class(Backup.General).StartTask(tTaskName, tJobBackup, 1)
            Do tResult.%Set("taskName", tTaskName)
            Do tResult.%Set("jobbackup", +tJobBackup, "boolean")
            If tBackupType '= "" Do tResult.%Set("backupType", tBackupType)
        }
        ElseIf tAction = "freeze" {
            ; ExternalFreeze(LogFile, Text, SwitchJournalFile=1, TimeOut=10, ...)
            Set tActionSC = ##class(Backup.General).ExternalFreeze(tLogFile, tDescription)
            If tLogFile '= "" Do tResult.%Set("logFile", tLogFile)
        }
        ElseIf tAction = "thaw" {
            ; ExternalThaw(LogFile, Username, Password)
            Set tActionSC = ##class(Backup.General).ExternalThaw(tLogFile, tUsername, tPassword)
            If tLogFile '= "" Do tResult.%Set("logFile", tLogFile)
        }

        Set $NAMESPACE = tOrigNS

        ; Propagate the underlying API %Status on failure (Rule #9).
        If $$$ISERR(tActionSC) {
            Do ..RenderResponseBody(..SanitizeError(tActionSC))
            Set tSC = $$$OK
            Quit
        }

        Do tResult.%Set("success", 1, "boolean")
        Do ..RenderResponseBody($$$OK, , tResult)
    }
    Catch ex {
        Set $NAMESPACE = tOrigNS
        Do ..RenderResponseBody(..SanitizeError(ex.AsStatus()))
        Set tSC = $$$OK
    }
    Quit $$$OK
}

}
