/// <p><class>OcuPilot.Port.InteropPort</class> whose <method>LogFault</method> keeps the text of each line the port would log, the message, the code, the status text and the namespace it was
/// written in, so a test reads what a refused or failed read or purge put in the log (Story 24.17 Batch 2); whose <method>VendorLogPurge</method> answers what
/// <code>^IRIS.Temp.OcuProbe2417LogMode</code> says: <code>status</code> to delete the oldest probe of the log and answer an error status that carries a marker text, <code>fault</code> to
/// raise an error, <code>roles</code> to change the process's roles and then raise, <code>rolesok</code> to run the vendor's own purge and then change them, anything else the vendor's own purge;
/// whose <method>LogHere</method> raises when the mode is <code>here</code>; and whose two list limits are three. The namespace, the kind, the days and the roles before the call are kept under the
/// global's <code>ranIn</code>, <code>kind</code>, <code>days</code> and <code>before</code> subscripts. <method>ClearLog</method> forgets the lines.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropLogPurgeSeam Extends OcuPilot.Port.InteropPort
{

/// <p>The text a probe fault and a probe status carry, which no log line may.</p>
Parameter MARKER = "OcuMarkerText2417Log";

/// <p>The marker of the probes, spelled here because the call that deletes one runs in the log's namespace, which holds no test class.</p>
Parameter PROBEMARKER = "OcuProbe2417";

/// <p>The lowered list limits.</p>
Parameter RULELOGMAX As INTEGER = 3;

Parameter PROCESSLOGMAX As INTEGER = 3;

/// <p>Keep the line, its text and the namespace the call was made in.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set tText = pMessage _ " " _ pCode
    Try {
        Set tText = tText _ " " _ $System.Status.GetErrorText(pStatus)
    } Catch {
    }
    Set tAt = $Increment(^||OcuPilotLogSeamLog)
    Set ^||OcuPilotLogSeamLog(tAt) = tText
    Set ^||OcuPilotLogSeamLog(tAt, "ns") = $NAMESPACE
}

/// <p>Every line kept since <method>ClearLog</method>, one after another.</p>
ClassMethod LoggedText() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotLogSeamLog(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: " | ") _ ^||OcuPilotLogSeamLog(tAt)
    }
    Quit tText
}

/// <p>The namespaces the kept lines were written in, comma-separated, one for each line.</p>
ClassMethod LoggedIn() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotLogSeamLog(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ ^||OcuPilotLogSeamLog(tAt, "ns")
    }
    Quit tText
}

/// <p>Forget the lines kept.</p>
ClassMethod ClearLog()
{
    Kill ^||OcuPilotLogSeamLog
}

/// <p>Delete the oldest probe of the log of kind <var>pKind</var> in the current namespace, which the vendor's partial purge leaves behind it.</p>
ClassMethod DeleteOne(pKind As %String) [ Private ]
{
    If pKind = ..#LOGKINDRULE {
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT MIN(ID) FROM Ens_Rule.Log WHERE RuleName = ?", ..#PROBEMARKER)
        If tResult.%Next() && (tResult.%GetData(1) '= "") Do ##class(%SQL.Statement).%ExecDirectNoPriv(, "DELETE FROM Ens_Rule.Log WHERE ID = ?", tResult.%GetData(1))
        Quit
    }
    Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT MIN(ID) FROM Ens.BusinessProcess WHERE %ConfigName = ?", ..#PROBEMARKER)
    If tResult.%Next() && (tResult.%GetData(1) '= "") Do ##class(EnsLib.MsgRouter.RoutingEngine).%DeleteId(tResult.%GetData(1))
}

/// <p>The probe's answer for the mode in <code>^IRIS.Temp.OcuProbe2417LogMode</code>.</p>
ClassMethod VendorLogPurge(pKind As %String, pDays As %Integer, Output pDeleted) As %Status
{
    Set tMode = $Get(^IRIS.Temp.OcuProbe2417LogMode)
    Set ^IRIS.Temp.OcuProbe2417LogMode("ranIn") = $NAMESPACE
    Set ^IRIS.Temp.OcuProbe2417LogMode("kind") = pKind
    Set ^IRIS.Temp.OcuProbe2417LogMode("days") = pDays
    Set ^IRIS.Temp.OcuProbe2417LogMode("before") = $ROLES
    If tMode = "status" {
        Do ..DeleteOne(pKind)
        Quit $$$ERROR($$$GeneralError, ..#MARKER _ " answered")
    }
    If tMode = "rolesok" {
        Set tSC = ##super(pKind, pDays, .pDeleted)
        Try {
            Set $ROLES = "%DB_USER"
        } Catch {
        }
        Set ^IRIS.Temp.OcuProbe2417LogMode("inside") = $ROLES
        Quit tSC
    }
    If tMode = "roles" {
        Try {
            Set $ROLES = "%DB_USER"
        } Catch {
        }
        Set ^IRIS.Temp.OcuProbe2417LogMode("inside") = $ROLES
    }
    If (tMode = "fault") || (tMode = "roles") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised"))
    Quit ##super(pKind, pDays, .pDeleted)
}

/// <p>Raise inside each namespace-switched block of the privilege check and the state read when the mode is <code>here</code>.</p>
ClassMethod LogHere() [ Private ]
{
    If $Get(^IRIS.Temp.OcuProbe2417LogMode) = "here" {
        Set ^IRIS.Temp.OcuProbe2417LogMode("hereIn") = $NAMESPACE
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#MARKER _ " raised in the log's namespace"))
    }
}

}
