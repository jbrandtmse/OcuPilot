/// <p>The probe records and settings Story 24.16's purge tests arrange and read. Every probe record carries <parameter>MARKER</parameter> in its source or
/// configuration name (a body in its text), is made in <parameter>NAMESPACE</parameter> or <parameter>OTHERNAMESPACE</parameter>, and is back-dated by whole
/// days through the vendor's own classes. <method>DropProbes</method> removes every one of them from both namespaces, and <method>SaveSettings</method> and
/// <method>RestoreSettings</method> put each namespace's purge setting nodes back exactly as they were found, a node that was not stored included. It starts no
/// production.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropPurgeFixture Extends %RegisteredObject
{

Parameter MARKER = "OcuProbe2416";

Parameter NAMESPACE = "USER";

Parameter OTHERNAMESPACE = "HSCUSTOM";

/// <p>How old a probe record that a purge is meant to delete is made, in days, and the days to keep such a purge is run with.</p>
Parameter OLDDAYS = 7300;

Parameter KEEPDAYS = 3650;

/// <p>The message statuses the probes use: Queued and Completed.</p>
Parameter QUEUED = 2;

Parameter COMPLETED = 9;

/// <p>The node subscripts of the purge settings.</p>
Parameter NODES = "BodiesToo,KeepIntegrity,NamespaceBitmapMaint,Desc";

/// <p>The instance's own UTC time <var>pSeconds</var> before now, in the vendor's logical form.</p>
ClassMethod UtcAgo(pSeconds As %Integer) As %String
{
    Quit ##class(OcuPilot.Test.InteropMessageRead).UtcAgo(pSeconds)
}

/// <p>Store one probe header in <var>pNamespace</var> with status <var>pStatus</var>, made <var>pDays</var> days ago, in session <var>pSession</var> (its own id when
/// empty), with a probe body when <var>pBody</var> is set, and answer its id, or 0 when it could not be stored. <var>pSuffix</var> tells probes apart.</p>
ClassMethod Header(pNamespace As %String, pStatus As %Integer, pDays As %Integer, pBody As %Boolean = 0, pSession As %String = "", pSuffix As %String = "") As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tId = 0
    ; The stamp is made before the switch: this package is not visible from a namespace that does not hold it.
    Set tCreated = ..UtcAgo(pDays * 86400)
    Try {
        Set $NAMESPACE = pNamespace
        Set tHeader = ##class(Ens.MessageHeader).%New()
        Set tHeader.SourceConfigName = ..#MARKER _ "Src" _ pSuffix
        Set tHeader.TargetConfigName = ..#MARKER _ "Op" _ pSuffix
        If pBody {
            Set tBody = ##class(Ens.StringRequest).%New()
            Set tBody.StringValue = ..#MARKER _ " body " _ pSuffix
            Set tSC = tBody.%Save()
            Set tHeader.MessageBodyClassName = "Ens.StringRequest"
            Set tHeader.MessageBodyId = tBody.%Id()
        }
        Set tHeader.Type = 1
        Set tHeader.Priority = 6
        Set tHeader.Status = pStatus
        Set tHeader.TimeCreated = tCreated
        Set tHeader.TimeProcessed = tHeader.TimeCreated
        If pSession '= "" Set tHeader.SessionId = pSession
        If $$$ISOK(tHeader.%Save()) {
            Set tId = tHeader.%Id()
            If pSession = "" {
                Set tHeader.SessionId = tId
                Do tHeader.%Save()
            }
        }
        Set tHeader = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tId = 0
    }
    Quit tId
}

/// <p>Store one probe event log row, one probe I/O log row, one closed and one open managed alert in <var>pNamespace</var>, each made <var>pDays</var> days ago;
/// <code>1</code> when every one was stored.</p>
ClassMethod Others(pNamespace As %String, pDays As %Integer) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tOk = 1
    Set tAgo = ..UtcAgo(pDays * 86400)
    Try {
        Set $NAMESPACE = pNamespace
        Set tLog = ##class(Ens.Util.Log).%New()
        Set tLog.TimeLogged = tAgo
        Set tLog.ConfigName = ..#MARKER _ "Log"
        Set tLog.Type = 3
        Set tLog.Text = "probe"
        If $$$ISERR(tLog.%Save()) Set tOk = 0
        Set tIo = ##class(Ens.Util.IOLog).%New()
        Set tIo.ConfigName = ..#MARKER _ "Io"
        Set tIo.TimeReceived = tAgo
        If $$$ISERR(tIo.%Save()) Set tOk = 0
        Set tClosed = ##class(Ens.Alerting.ManagedAlert).%New()
        Set tClosed.AlertTime = tAgo
        Set tClosed.SourceConfigName = ..#MARKER _ "AlertClosed"
        Set tClosed.IsOpen = 0
        If $$$ISERR(tClosed.%Save()) Set tOk = 0
        Set tOpen = ##class(Ens.Alerting.ManagedAlert).%New()
        Set tOpen.AlertTime = tAgo
        Set tOpen.SourceConfigName = ..#MARKER _ "AlertOpen"
        Set tOpen.IsOpen = 1
        If $$$ISERR(tOpen.%Save()) Set tOk = 0
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tOk = 0
    }
    Quit tOk
}

/// <p>How many probe records of <var>pKind</var> (<code>header</code>, <code>body</code>, <code>log</code>, <code>io</code>, <code>alertClosed</code>,
/// <code>alertOpen</code>) <var>pNamespace</var> holds, or -1 when it cannot be read.</p>
ClassMethod Count(pNamespace As %String, pKind As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = -1
    Try {
        Set $NAMESPACE = pNamespace
        Set tMark = ..#MARKER _ "%"
        Set tSql = ""
        If pKind = "header" Set tSql = "SELECT COUNT(*) FROM Ens.MessageHeader WHERE SourceConfigName LIKE ?"
        If pKind = "body" Set tSql = "SELECT COUNT(*) FROM Ens.StringRequest WHERE StringValue LIKE ?"
        If pKind = "log" Set tSql = "SELECT COUNT(*) FROM Ens_Util.Log WHERE ConfigName LIKE ?"
        If pKind = "io" Set tSql = "SELECT COUNT(*) FROM Ens_Util.IOLog WHERE ConfigName LIKE ?"
        If pKind = "alertClosed" Set tSql = "SELECT COUNT(*) FROM Ens_Alerting.ManagedAlert WHERE IsOpen = 0 AND SourceConfigName LIKE ?"
        If pKind = "alertOpen" Set tSql = "SELECT COUNT(*) FROM Ens_Alerting.ManagedAlert WHERE IsOpen = 1 AND SourceConfigName LIKE ?"
        If tSql '= "" {
            Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, tSql, tMark)
            If (tRS.%SQLCODE = 0) && tRS.%Next() Set tCount = +tRS.%GetData(1)
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>All six counts of <var>pNamespace</var> as one line, for an assertion that compares what a refusal left with what was there.</p>
ClassMethod Counts(pNamespace As %String) As %String
{
    Set tText = ""
    For tKind = "header", "body", "log", "io", "alertClosed", "alertOpen" {
        Set tText = tText _ $Select(tText = "": "", 1: " ") _ tKind _ "=" _ ..Count(pNamespace, tKind)
    }
    Quit tText
}

/// <p>The vendor's own count of the kind <var>pType</var> (<code>Messages</code>, <code>Event Log</code>, ...) in <var>pNamespace</var>, as <code>Ens.Purge.GetAllCounts</code>
/// reads it, or -1.</p>
ClassMethod VendorCount(pNamespace As %String, pType As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = -1
    Try {
        Set $NAMESPACE = pNamespace
        Do ##class(Ens.Purge).GetAllCounts(.tCounts)
        Set tCount = +$Get(tCounts(pType), -1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Remove every probe record from <parameter>NAMESPACE</parameter> and <parameter>OTHERNAMESPACE</parameter>, and answer <code>1</code> when none survives.</p>
ClassMethod DropProbes() As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tClean = 1
    For tNamespace = ..#NAMESPACE, ..#OTHERNAMESPACE {
        Try {
            Set $NAMESPACE = tNamespace
            Set tMark = ..#MARKER _ "%"
            For tSql = "DELETE FROM Ens.MessageHeader WHERE SourceConfigName LIKE ?", "DELETE FROM Ens.StringRequest WHERE StringValue LIKE ?", "DELETE FROM Ens_Util.Log WHERE ConfigName LIKE ?", "DELETE FROM Ens_Util.IOLog WHERE ConfigName LIKE ?", "DELETE FROM Ens_Alerting.ManagedAlert WHERE SourceConfigName LIKE ?" {
                Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, tSql, tMark)
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
            Set tClean = 0
        }
        For tKind = "header", "body", "log", "io", "alertClosed", "alertOpen" {
            If ..Count(tNamespace, tKind) '= 0 Set tClean = 0
        }
    }
    Quit tClean
}

/// <p>The purge settings of <parameter>NAMESPACE</parameter> and <parameter>OTHERNAMESPACE</parameter> as they stand, as one JSON text: for each namespace and node,
/// whether it was stored and its value.</p>
ClassMethod SaveSettings() As %String
{
    Set tSaved = {}
    Set tOrigNS = $NAMESPACE
    For tNamespace = ..#NAMESPACE, ..#OTHERNAMESPACE {
        Set tHere = {}
        Try {
            Set $NAMESPACE = tNamespace
            For tI = 1:1:$Length(..#NODES, ",") {
                Set tNode = $Piece(..#NODES, ",", tI)
                Set tNodeState = {}
                Do tNodeState.%Set("stored", ''($Data(^Ens.Configuration("PurgeSettings", tNode)) # 2), "boolean")
                Do tNodeState.%Set("value", $Get(^Ens.Configuration("PurgeSettings", tNode)), "string")
                Do tHere.%Set(tNode, tNodeState)
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
        Do tSaved.%Set(tNamespace, tHere)
    }
    Quit tSaved.%ToJSON()
}

/// <p>Put each node <method>SaveSettings</method> read back as it was: a node that was stored gets its value, and one that was not is killed.</p>
ClassMethod RestoreSettings(pSaved As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSaved = ##class(%DynamicObject).%FromJSON(pSaved)
        For tNamespace = ..#NAMESPACE, ..#OTHERNAMESPACE {
            Set tHere = tSaved.%Get(tNamespace)
            Set $NAMESPACE = tNamespace
            For tI = 1:1:$Length(..#NODES, ",") {
                Set tNode = $Piece(..#NODES, ",", tI)
                Set tNodeState = tHere.%Get(tNode)
                If tNodeState.stored {
                    Set ^Ens.Configuration("PurgeSettings", tNode) = tNodeState.value
                } Else {
                    Kill ^Ens.Configuration("PurgeSettings", tNode)
                }
            }
            Set $NAMESPACE = tOrigNS
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The purge settings of <var>pNamespace</var> as the one line <code>BodiesToo|KeepIntegrity|NamespaceBitmapMaint|Desc</code>, each <code>&lt;absent&gt;</code> when the node is
/// not stored.</p>
ClassMethod SettingsText(pNamespace As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = pNamespace
        For tI = 1:1:$Length(..#NODES, ",") {
            Set tNode = $Piece(..#NODES, ",", tI)
            Set tText = tText _ $Select(tI = 1: "", 1: "|") _ $Select($Data(^Ens.Configuration("PurgeSettings", tNode)) # 2: ^Ens.Configuration("PurgeSettings", tNode), 1: "<absent>")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "<error " _ ex.DisplayString() _ ">"
    }
    Quit tText
}

/// <p>Store the setting <var>pNode</var> of <var>pNamespace</var> as <var>pValue</var>, or remove the node when <var>pValue</var> is <code>&lt;absent&gt;</code>.</p>
ClassMethod PutSetting(pNamespace As %String, pNode As %String, pValue As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If pValue = "<absent>" {
            Kill ^Ens.Configuration("PurgeSettings", pNode)
        } Else {
            Set ^Ens.Configuration("PurgeSettings", pNode) = pValue
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Hold the classic page's purge lock in <var>pNamespace</var> in this process until the signal says <code>stop</code> (or 60 seconds pass), and signal <code>1</code> once held
/// and <code>2</code> once released. It is the child job <method>OcuPilot.Test.InteropPurgeRefusals</method> starts, and it ends before that test does.</p>
ClassMethod HoldLock(pNamespace As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Lock +^IRIS.Temp.EnsPurgeAll($Namespace, "lock"):5
        If $Test {
            Set ^IRIS.Temp.OcuProbe2416Hold = 1
            For tI = 1:1:600 {
                If $Get(^IRIS.Temp.OcuProbe2416Hold) = "stop" Quit
                Hang 0.1
            }
            Lock -^IRIS.Temp.EnsPurgeAll($Namespace, "lock")
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Set ^IRIS.Temp.OcuProbe2416Hold = 2
}

}
