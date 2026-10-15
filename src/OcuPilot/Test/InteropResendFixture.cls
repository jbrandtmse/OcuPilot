/// <p>The probe state Story 20.31's armed suites share: the probe production of <class>OcuPilot.Test.ProductionProbe</class> in
/// <code>USER</code> with a second enabled operation (<parameter>TWONAME</parameter>) and a disabled one
/// (<parameter>OFFNAME</parameter>), started and stopped on demand; stored request and response headers to resend, with bodies of
/// the shapes the suites edit; and the reads of what a resend left behind -- headers by session, the vendor's own
/// <code>Resend</code> and <code>ViewContents</code> audit rows, the header count.</p>
/// <p>Every suite that uses it records <method>OcuPilot.Test.ProductionProbe.HighWater</method> before it makes a message and
/// removes what it made with <method>OcuPilot.Test.ProductionProbe.SweepSince</method> after the last test, so no suite asserts on a
/// store being empty. Each method switches to <parameter>NAMESPACE</parameter> by explicit save and restore and calls only vendor
/// classes while switched.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropResendFixture Extends %RegisteredObject
{

Parameter NAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OPNAME = "OcuPilotProbeOp";

/// <p>A second enabled operation, and a disabled one, of the probe production: a message to the first reads <code>resend</code>
/// while the production runs, and one to the second reads <code>targetoff</code>.</p>
Parameter TWONAME = "OcuPilotProbeTwo";

Parameter OFFNAME = "OcuPilotProbeOff";

Parameter OPCLASS = "OcuPilotProbe.Interop.Op";

/// <p>A queue no production has, which a response replies to when its reply queue is gone.</p>
Parameter NOQUEUE = "OcuPilotProbeNoQueue";

/// <p>The longest wait, in seconds, for the production to run or for a message the production was given to be taken.</p>
Parameter WAIT = 30;

/// <p>The body classes <method>CreateBodyClasses</method> compiles in <code>USER</code>: a request of every field shape an edit takes
/// (<parameter>BODYCLASS</parameter>, with an embedded serial object and a credential-named one), and a request whose class name begins
/// <code>OcuPilot</code>, which an edit never opens (<parameter>OWNBODYCLASS</parameter>, in the probe's package, so
/// <method>OcuPilot.Test.ProductionProbe.Remove</method> deletes it).</p>
Parameter BODYPACKAGE = "ResendProbe";

Parameter BODYCLASS = "ResendProbe.Body";

Parameter ADDRESSCLASS = "ResendProbe.Address";

Parameter BOXCLASS = "ResendProbe.Box";

Parameter OWNBODYCLASS = "OcuPilotProbe.Edit.Body";

/// <p>Create the probe, with its two further operations (<parameter>TWONAME</parameter> enabled, <parameter>OFFNAME</parameter>
/// disabled), after removing any the probe left.</p>
ClassMethod Prepare() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddItem", ..#TWONAME, ..#OPCLASS, 1, 1)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddItem", ..#OFFNAME, ..#OPCLASS, 1, 0)
    Quit tSC
}

/// <p>Put the probe production back as its class declares it and add the two further operations again, so a test that moved an
/// item starts from the state <method>Prepare</method> made.</p>
ClassMethod Restore() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Settle")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "ResetProduction")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddItem", ..#TWONAME, ..#OPCLASS, 1, 1)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddItem", ..#OFFNAME, ..#OPCLASS, 1, 0)
    Quit tSC
}

/// <p>Start the probe production in <code>USER</code> and wait, <parameter>WAIT</parameter> seconds at most, until it runs and the
/// queues of its two enabled operations exist. A failing status names what did not come.</p>
ClassMethod Start() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "CheckOwn")
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ##class(Ens.Director).StartProduction(..#PRODUCTION)
        If $$$ISOK(tSC) {
            Set tReady = 0
            For tTry = 1:1:(..#WAIT * 4) {
                Set tSC = ##class(Ens.Director).GetProductionStatus(.tCurrent, .tState, 2)
                If $$$ISOK(tSC) && (tState = 1) && ##class(Ens.Queue).Exists(..#OPNAME) && ##class(Ens.Queue).Exists(..#TWONAME) {
                    Set tReady = 1
                    Quit
                }
                Hang 0.25
            }
            If 'tReady Set tSC = $$$ERROR($$$GeneralError, "the probe production did not run with its queues within " _ ..#WAIT _ " seconds")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store a string request <var>pText</var> sent by the probe service to <var>pTarget</var>, its header's id in <var>pId</var>
/// (<method>OcuPilot.Test.ProductionProbe.StoredRequest</method>).</p>
ClassMethod Request(pText As %String, pTarget As %String = {..#OPNAME}, Output pId As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tBody = ##class(Ens.StringRequest).%New()
        Set tBody.StringValue = pText
        Set $NAMESPACE = tOrigNS
        Set tSC = $ClassMethod(..#PROBE, "StoredRequest", tBody, pTarget, .pId)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store the HL7 v2 message <var>pText</var> (<class>EnsLib.HL7.Message</class>) sent to <var>pTarget</var>, its header's id in
/// <var>pId</var>.</p>
ClassMethod Hl7(pText As %String, pTarget As %String = {..#OPNAME}, Output pId As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tBody = ##class(EnsLib.HL7.Message).ImportFromString(pText, .tSC)
        Set $NAMESPACE = tOrigNS
        If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "StoredRequest", tBody, pTarget, .pId)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The stored property <var>pProperty</var> of the message header <var>pId</var> in <code>USER</code>, <code>"&lt;none&gt;"</code>
/// for a header that is not there. <code>Resent</code> and <code>SessionId</code> are read as numbers.</p>
ClassMethod Property(pId As %String, pProperty As %String) As %String
{
    Set tValue = "<none>"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId)
        If $IsObject(tHeader) Set tValue = $Property(tHeader, pProperty)
        Set tHeader = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = "<unread>"
    }
    Quit tValue
}

/// <p>The headers of the session <var>pSession</var> in <code>USER</code> above the id <var>pAbove</var> (none when 0), in id order, as
/// <code>id:resent:description:bodyClass:bodyId</code> joined by <code>;</code>.</p>
ClassMethod Session(pSession As %String, pAbove As %String = 0) As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, Resent, Description, MessageBodyClassName, MessageBodyId FROM Ens.MessageHeader WHERE SessionId = ? AND ID > ? ORDER BY ID", pSession, pAbove)
        While tRS.%Next() {
            Set tText = tText _ $Select(tText = "": "", 1: ";") _ tRS.%GetData(1) _ ":" _ tRS.%GetData(2) _ ":" _ tRS.%GetData(3) _ ":" _ tRS.%GetData(4) _ ":" _ tRS.%GetData(5)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>How many message headers <code>USER</code> holds.</p>
ClassMethod HeaderCount() As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Ens.MessageHeader")
        If tRS.%Next() Set tCount = +tRS.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>The highest message header id in <code>USER</code> (<code>0</code> for none), which a test records to name the headers made after
/// it.</p>
ClassMethod TopId() As %Integer
{
    Quit +$Piece($ClassMethod(..#PROBE, "HighWater"), "|", 1)
}

/// <p>The fields of the body <var>pClass</var> <var>pId</var> in <code>USER</code>, <code>name=value</code> joined by <code>;</code>
/// for each of <var>pFields</var> (comma-separated, dotted for an embedded object's, a path with a colon read as an HL7 message's
/// <code>GetValueAt</code>), <code>"&lt;none&gt;"</code> when the body is gone.</p>
ClassMethod BodyFields(pClass As %String, pId As %String, pFields As %String) As %String
{
    Set tText = "<none>"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If $ClassMethod(pClass, "%ExistsId", pId) {
            Set tBody = $ClassMethod(pClass, "%OpenId", pId)
            Set tText = ""
            For tI = 1:1:$Length(pFields, ",") {
                Set tPath = $Piece(pFields, ",", tI)
                Set tCurrent = tBody
                If tPath [ ":" {
                    Set tText = tText _ $Select(tText = "": "", 1: ";") _ tPath _ "=" _ $Method(tBody, "GetValueAt", tPath)
                    Continue
                }
                For tJ = 1:1:$Length(tPath, ".") {
                    If '$IsObject(tCurrent) Quit
                    Set tCurrent = $Property(tCurrent, $Piece(tPath, ".", tJ))
                }
                Set tText = tText _ $Select(tText = "": "", 1: ";") _ tPath _ "=" _ $Select($IsObject(tCurrent): "<object>", 1: tCurrent)
            }
            Set tBody = ""
            Set tCurrent = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>The text of the body class <var>pName</var> (<code>Address</code>, <code>Box</code>, <code>Body</code> or <code>Own</code>).</p>
ClassMethod BodyClassText(pName As %String) As %String [ Private ]
{
    Set tNL = $Char(13, 10)
    If pName = "Address" Quit "Class " _ ..#ADDRESSCLASS _ " Extends %SerialObject" _ tNL _ "{" _ tNL _ "Property Street As %String;" _ tNL _ "Property City As %String(MAXLEN = 30);" _ tNL _ "}" _ tNL
    If pName = "Box" Quit "Class " _ ..#BOXCLASS _ " Extends %SerialObject" _ tNL _ "{" _ tNL _ "Property Value As %String;" _ tNL _ "}" _ tNL
    If pName = "Own" Quit "Class " _ ..#OWNBODYCLASS _ " Extends Ens.Request" _ tNL _ "{" _ tNL _ "Property Text As %String;" _ tNL _ "}" _ tNL
    Quit "Class " _ ..#BODYCLASS _ " Extends Ens.Request" _ tNL _ "{" _ tNL _
        "Property Text As %String(MAXLEN = 50) [ Required ];" _ tNL _
        "Property Count As %Integer;" _ tNL _
        "Property Kind As %String(VALUELIST = "",alpha,beta,gamma"");" _ tNL _
        "Property Password As %String;" _ tNL _
        "Property Address As " _ ..#ADDRESSCLASS _ ";" _ tNL _
        "Property Flag As %Boolean;" _ tNL _
        "Property Level As %String(DISPLAYLIST = "",Low,High"", VALUELIST = "",L,H"");" _ tNL _
        "Property Credential As " _ ..#BOXCLASS _ ";" _ tNL _ "}" _ tNL
}

/// <p>Create and compile, in <code>USER</code>, the body classes of <parameter>BODYPACKAGE</parameter> and the class
/// <parameter>OWNBODYCLASS</parameter>. Called after <method>Prepare</method>, whose probe removal deletes the second.</p>
ClassMethod CreateBodyClasses() As %Status
{
    Set tSC = $$$OK
    For tName = "Address", "Box", "Body", "Own" {
        Set tClass = $Case(tName, "Address": ..#ADDRESSCLASS, "Box": ..#BOXCLASS, "Body": ..#BODYCLASS, : ..#OWNBODYCLASS)
        Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tClass, ..BodyClassText(tName))
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.CompilePackage(..#BODYPACKAGE, "ck-d")
        If $$$ISOK(tSC) Set tSC = $System.OBJ.Compile(..#OWNBODYCLASS, "ck-d")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the body classes <method>CreateBodyClasses</method> made, and the objects they stored, from <code>USER</code>.</p>
ClassMethod RemoveBodyClasses() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If ##class(%Dictionary.CompiledClass).%ExistsId(..#BODYCLASS) Set tSC = $ClassMethod(..#BODYCLASS, "%KillExtent")
        Set tSC = $System.Status.AppendStatus(tSC, $System.OBJ.DeletePackage(..#BODYPACKAGE, "-d"))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store an <code>EnsLib.EDI.X12.Document</code> of a minimal interchange sent to <var>pTarget</var>, its header's id in
/// <var>pId</var>: a body of a document kind an edit does not take.</p>
ClassMethod X12(pTarget As %String = {..#OPNAME}, Output pId As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tText = "ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *260101*1200*^*00501*000000001*0*P*:~GS*HC*SENDER*RECEIVER*20260101*1200*1*X*005010X222~ST*837*0001~BHT*0019*00*1*20260101*1200*CH~SE*3*0001~GE*1*1~IEA*1*000000001~"
        Set tBody = ##class(EnsLib.EDI.X12.Document).ImportFromString(tText, .tSC)
        Set $NAMESPACE = tOrigNS
        If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "StoredRequest", tBody, pTarget, .pId)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store a <code>%Stream.GlobalCharacter</code> holding the text <var>pText</var> as the body of a request sent to
/// <var>pTarget</var>, its header's id in <var>pId</var>: a body that is a stream, which an edit does not take.</p>
ClassMethod StreamBody(pText As %String, pTarget As %String = {..#OPNAME}, Output pId As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tBody = ##class(%Stream.GlobalCharacter).%New()
        Do tBody.Write(pText)
        Set $NAMESPACE = tOrigNS
        Set tSC = $ClassMethod(..#PROBE, "StoredRequest", tBody, pTarget, .pId)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete, in <code>USER</code>, the body the message header <var>pId</var> names, leaving the header: a message whose body is
/// gone. The answer is 1 when a body was deleted.</p>
ClassMethod DeleteBody(pId As %String) As %Boolean
{
    Set tDeleted = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId)
        If $IsObject(tHeader) {
            Set tClass = tHeader.MessageBodyClassName
            Set tBodyId = tHeader.MessageBodyId
            Set tHeader = ""
            Set tDeleted = $$$ISOK($ClassMethod(tClass, "%DeleteId", tBodyId))
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tDeleted
}

/// <p>Set, in <code>USER</code>, the stored property <var>pProperty</var> of the body the message header <var>pId</var> names to
/// <var>pValue</var> and save the body: a body that changed after it was reviewed.</p>
ClassMethod SetBodyProperty(pId As %String, pProperty As %String, pValue As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId)
        Set tBody = $$$NULLOREF
        If $IsObject(tHeader) Set tBody = $ClassMethod(tHeader.MessageBodyClassName, "%OpenId", tHeader.MessageBodyId)
        Set tHeader = ""
        If $IsObject(tBody) {
            Set $Property(tBody, pProperty) = pValue
            Set tSC = tBody.%Save()
        } Else {
            Set tSC = $$$ERROR($$$GeneralError, "no body for message header " _ pId)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many <class>Ens.StringRequest</class> bodies <code>USER</code> holds, <code>-1</code> when it could not be read.</p>
ClassMethod StringRequestCount() As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Ens.StringRequest")
        If tRS.%Next() Set tCount = +tRS.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>A new object of the class <var>pClass</var> whose properties are set from <var>pValues</var> (a <class>%DynamicObject</class> of
/// text values, dotted names for an embedded object's, the embedded object created when the path passes through none). Called while
/// <code>USER</code> is switched to.</p>
ClassMethod Build(pClass As %String, pValues As %DynamicObject) As %RegisteredObject [ Private ]
{
    Set tObject = $ClassMethod(pClass, "%New")
    Set tIterator = pValues.%GetIterator()
    While tIterator.%GetNext(.tPath, .tValue) {
        Set tCurrent = tObject
        For tJ = 1:1:$Length(tPath, ".") - 1 {
            Set tNext = $Property(tCurrent, $Piece(tPath, ".", tJ))
            If '$IsObject(tNext) {
                Set tSerial = ##class(%Dictionary.CompiledProperty).%OpenId(tCurrent.%ClassName(1) _ "||" _ $Piece(tPath, ".", tJ)).Type
                Set tNext = $ClassMethod(tSerial, "%New")
                Set $Property(tCurrent, $Piece(tPath, ".", tJ)) = tNext
            }
            Set tCurrent = tNext
        }
        Set $Property(tCurrent, $Piece(tPath, ".", $Length(tPath, "."))) = tValue
    }
    Quit tObject
}

/// <p>Store a request of the class <var>pClass</var> whose properties are set from <var>pValues</var> (<method>Build</method>'s),
/// sent to <var>pTarget</var>, its header's id in <var>pId</var> and its body's id in <var>pBodyId</var>.</p>
ClassMethod StoredObject(pClass As %String, pValues As %DynamicObject, pTarget As %String = {..#OPNAME}, Output pId As %String, Output pBodyId As %String) As %Status
{
    Set pBodyId = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tBody = ..Build(pClass, pValues)
        Set $NAMESPACE = tOrigNS
        Set tSC = $ClassMethod(..#PROBE, "StoredRequest", tBody, pTarget, .pId)
        If $$$ISOK(tSC) Set pBodyId = tBody.%Id()
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store the item <var>pName</var> of the probe production as enabled when <var>pEnabled</var> is 1 and disabled otherwise, in the
/// stored configuration only, the way the vendor's own code does (<method>OcuPilot.Test.ProductionProbe.AddItem</method>'s); the
/// running production keeps the queue it started with, and the resend read judges the stored configuration.</p>
ClassMethod SetEnabled(pName As %String, pEnabled As %Boolean) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tProduction = ##class(Ens.Config.Production).%OpenId(..#PRODUCTION, 4)
        Set tItem = tProduction.FindItemByConfigName(pName)
        If '$IsObject(tItem) {
            Set tSC = $$$ERROR($$$GeneralError, "the probe production holds no item " _ pName)
        } Else {
            Set tItem.Enabled = ''pEnabled
            Set tSC = tProduction.%Save()
        }
        Set tItem = ""
        Set tProduction = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The vendor's audit rows of event <var>pEvent</var> (<code>Resend</code> or <code>ViewContents</code>) since <var>pSince</var>
/// whose data names the message header <var>pId</var> (<code>MessageHeaderId = &lt;id&gt;,</code>): their count, and the last one's
/// source and data in <var>pData</var>.</p>
ClassMethod AuditRows(pSince As %String, pEvent As %String, pId As %String, Output pData As %String) As %Integer
{
    Set pData = ""
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Description, EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = '%Ensemble' AND %NOINDEX EventType = '%Message' AND %NOINDEX Event = ? ORDER BY UTCTimeStamp", pSince, pEvent)
        While tRS.%Next() {
            If tRS.%Get("EventData") [ ("MessageHeaderId = " _ pId _ ",") {
                Set tCount = tCount + 1
                Set pData = tRS.%Get("Description") _ "|" _ tRS.%Get("EventData")
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
        Set pData = ex.DisplayString()
    }
    Quit tCount
}

/// <p>The audit time a suite takes before it acts, in the form <method>AuditRows</method> compares with
/// (<method>OcuPilot.Test.AuditEvent.Now</method>).</p>
ClassMethod Now() As %String
{
    Quit ##class(OcuPilot.Test.AuditEvent).Now()
}

}
