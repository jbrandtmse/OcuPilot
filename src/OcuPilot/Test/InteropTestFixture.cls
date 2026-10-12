/// <p>The probe classes and items of Story 20.6's host test, added to <class>OcuPilot.Test.ProductionProbe</class>'s probe production in
/// <code>USER</code> on a throwaway container: a request class that has every kind of field the Test tab lists
/// (<parameter>REQUESTCLASS</parameter>, with <parameter>ADDRESSCLASS</parameter> embedded in it, a boolean, a field whose display
/// values differ from its stored ones, and <parameter>BOXCLASS</parameter> embedded under a credential's name), an operation that answers an echo of
/// what it is sent, and an error for the text <code>fail</code> (<parameter>ECHOCLASS</parameter>), the operation as an enabled item (<parameter>ECHONAME</parameter>) and as a
/// disabled one (<parameter>OFFNAME</parameter>), and the production's stored <code>TestingEnabled</code>. Everything is created in the
/// probe's own package and configuration-name prefix, so <method>OcuPilot.Test.ProductionProbe.Remove</method> removes the classes, the
/// items and the messages; <method>Remove</method> also removes the request rows, the creation marker and the test answers the
/// vendor keeps.</p>
/// <p>A second operation, <parameter>REPLYNAME</parameter> (<parameter>REPLYOPCLASS</parameter>), answers what the echo does not: a
/// response class with a credential-named field, an embedded object named like one and an ordinary one
/// (<parameter>REPLYCLASS</parameter>), a value
/// longer than a result shows, and a virtual document.</p>
/// <p><b>The request class counts its creations</b>: its <code>%OnNew</code> adds one to <code>^OcuPilotProbeInteropNew</code> in
/// <code>USER</code>, so a read that instantiated it, and a send that did not, are both visible (<method>Marker</method>).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. Each method switches to
/// <parameter>NAMESPACE</parameter> by explicit save and restore and calls only vendor classes while switched.</p>
Class OcuPilot.Test.InteropTestFixture Extends %RegisteredObject
{

Parameter NAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter PACKAGE = "OcuPilotProbe.Interop";

Parameter ADDRESSCLASS = "OcuPilotProbe.Interop.TestAddress";

Parameter REQUESTCLASS = "OcuPilotProbe.Interop.TestRequest";

Parameter ECHOCLASS = "OcuPilotProbe.Interop.EchoOp";

/// <p>The vendor's testing service, whose headers and answer nodes a test leaves behind.</p>
Parameter TESTSERVICE = "EnsLib.Testing.Service";

/// <p>A subclass of the request class, which the operation does not name and the Test tab lists after the classes it does.</p>
Parameter SUBCLASS = "OcuPilotProbe.Interop.TestRequestSub";

/// <p>The echo operation's item names: enabled, and disabled. Both begin with the probe's configuration-name prefix.</p>
Parameter ECHONAME = "OcuPilotProbeEchoOp";

Parameter OFFNAME = "OcuPilotProbeEchoOff";

/// <p>The global that counts the request class's creations, in <code>USER</code>.</p>
Parameter MARKER = "^OcuPilotProbeInteropNew";

/// <p>The reply operation's item name, its class, the response class it answers a string request with and the serial class embedded
/// in it, and the text of the document it answers a virtual document with.</p>
Parameter REPLYNAME = "OcuPilotProbeReplyOp";

Parameter REPLYOPCLASS = "OcuPilotProbe.Interop.ReplyOp";

Parameter REPLYCLASS = "OcuPilotProbe.Interop.TestReply";

Parameter BOXCLASS = "OcuPilotProbe.Interop.TestBox";

Parameter REPLYDOCUMENT = "MSH|^~\&|REPLYAPP|REPLYFAC|OCURECV|OCUFAC|20260101000000||ACK^A01|ACK1|P|2.5";

/// <p>The message class a virtual-document test sends, and the text of one message of it, whose sending application the echo returns.</p>
Parameter DOCUMENTCLASS = "EnsLib.HL7.Message";

Parameter DOCUMENTTEXT = "MSH|^~\&|OCUSENDER|OCUFAC|OCURECV|OCUFAC|20260101000000||ADT^A01|MSG1|P|2.5";

/// <p>The text of the probe class <var>pName</var> (<code>TestAddress</code>, <code>TestRequest</code>, <code>TestRequestSub</code>,
/// <code>EchoOp</code>, <code>TestBox</code>, <code>TestReply</code> or <code>ReplyOp</code>).</p>
ClassMethod ClassText(pName As %String) As %String [ Private ]
{
    Set tNL = $Char(13, 10)
    If pName = "TestAddress" {
        Quit "Class " _ ..#ADDRESSCLASS _ " Extends %SerialObject" _ tNL _ "{" _ tNL _
            "Property Street As %String;" _ tNL _
            "Property City As %String(MAXLEN = 30);" _ tNL _ "}" _ tNL
    }
    If pName = "TestRequest" {
        Quit "Class " _ ..#REQUESTCLASS _ " Extends Ens.Request" _ tNL _ "{" _ tNL _
            "Property Text As %String(MAXLEN = 50) [ Required ];" _ tNL _
            "Property Count As %Integer;" _ tNL _
            "Property Kind As %String(VALUELIST = "",alpha,beta,gamma"");" _ tNL _
            "Property Password As %String;" _ tNL _
            "Property Address As " _ ..#ADDRESSCLASS _ ";" _ tNL _
            "Property Flag As %Boolean;" _ tNL _
            "Property Level As %String(DISPLAYLIST = "",Low,High"", VALUELIST = "",L,H"");" _ tNL _
            "Property Credential As " _ ..#BOXCLASS _ ";" _ tNL _
            "Method %OnNew(initvalue As %String = """") As %Status" _ tNL _ "{" _ tNL _
            " Set " _ ..#MARKER _ " = $Get(" _ ..#MARKER _ ") + 1" _ tNL _ " Quit $$$OK" _ tNL _ "}" _ tNL _ "}" _ tNL
    }
    If pName = "TestBox" {
        Quit "Class " _ ..#BOXCLASS _ " Extends %SerialObject" _ tNL _ "{" _ tNL _ "Property Value As %String;" _ tNL _ "}" _ tNL
    }
    If pName = "TestReply" {
        Quit "Class " _ ..#REPLYCLASS _ " Extends Ens.Response" _ tNL _ "{" _ tNL _
            "Property Text As %String(MAXLEN = """");" _ tNL _
            "Property Password As %String;" _ tNL _
            "Property Credential As " _ ..#BOXCLASS _ ";" _ tNL _
            "Property Box As " _ ..#BOXCLASS _ ";" _ tNL _ "}" _ tNL
    }
    If pName = "ReplyOp" {
        Quit "Class " _ ..#REPLYOPCLASS _ " Extends Ens.BusinessOperation" _ tNL _ "{" _ tNL _
            "Parameter INVOCATION = ""Queue"";" _ tNL _
            "Method Reply(pRequest As Ens.StringRequest, Output pResponse As " _ ..#REPLYCLASS _ ") As %Status" _ tNL _ "{" _ tNL _
            " Set pResponse = ##class(" _ ..#REPLYCLASS _ ").%New()" _ tNL _
            " Set pResponse.Text = $Select(pRequest.StringValue = ""long"": $Translate($Justify("""", 1500), "" "", ""x""), 1: ""reply:"" _ pRequest.StringValue)" _ tNL _
            " Set pResponse.Password = ""s3cret-pw""" _ tNL _
            " Set pResponse.Credential = ##class(" _ ..#BOXCLASS _ ").%New()" _ tNL _
            " Set pResponse.Credential.Value = ""s3cret-cred""" _ tNL _
            " Set pResponse.Box = ##class(" _ ..#BOXCLASS _ ").%New()" _ tNL _
            " Set pResponse.Box.Value = ""boxed""" _ tNL _ " Quit $$$OK" _ tNL _ "}" _ tNL _
            "Method ReplyDocument(pRequest As " _ ..#DOCUMENTCLASS _ ", Output pResponse As " _ ..#DOCUMENTCLASS _ ") As %Status" _ tNL _ "{" _ tNL _
            " Set pResponse = ##class(" _ ..#DOCUMENTCLASS _ ").ImportFromString(""" _ ..#REPLYDOCUMENT _ """)" _ tNL _ " Quit $$$OK" _ tNL _ "}" _ tNL _
            "XData MessageMap" _ tNL _ "{" _ tNL _
            "<MapItems><MapItem MessageType=""Ens.StringRequest""><Method>Reply</Method></MapItem>" _
            "<MapItem MessageType=""" _ ..#DOCUMENTCLASS _ """><Method>ReplyDocument</Method></MapItem></MapItems>" _ tNL _ "}" _ tNL _ "}" _ tNL
    }
    If pName = "TestRequestSub" Quit "Class " _ ..#SUBCLASS _ " Extends " _ ..#REQUESTCLASS _ tNL _ "{" _ tNL _ "}" _ tNL
    Quit "Class " _ ..#ECHOCLASS _ " Extends Ens.BusinessOperation" _ tNL _ "{" _ tNL _
        "Parameter INVOCATION = ""Queue"";" _ tNL _
        "Method Echo(pRequest As " _ ..#REQUESTCLASS _ ", Output pResponse As Ens.StringResponse) As %Status" _ tNL _ "{" _ tNL _
        " If pRequest.Text = ""fail"" Quit $$$ERROR($$$GeneralError, ""echo failed"")" _ tNL _
        " Set pResponse = ##class(Ens.StringResponse).%New(""echo:"" _ pRequest.Text)" _ tNL _ " Quit $$$OK" _ tNL _ "}" _ tNL _
        "Method EchoString(pRequest As Ens.StringRequest, Output pResponse As Ens.StringResponse) As %Status" _ tNL _ "{" _ tNL _
        " Set pResponse = ##class(Ens.StringResponse).%New(""echo:"" _ pRequest.StringValue)" _ tNL _ " Quit $$$OK" _ tNL _ "}" _ tNL _
        "Method EchoDocument(pRequest As " _ ..#DOCUMENTCLASS _ ", Output pResponse As Ens.StringResponse) As %Status" _ tNL _ "{" _ tNL _
        " Set pResponse = ##class(Ens.StringResponse).%New(""echo:"" _ pRequest.GetValueAt(""1:3""))" _ tNL _ " Quit $$$OK" _ tNL _ "}" _ tNL _
        "XData MessageMap" _ tNL _ "{" _ tNL _
        "<MapItems><MapItem MessageType=""" _ ..#REQUESTCLASS _ """><Method>Echo</Method></MapItem>" _
        "<MapItem MessageType=""Ens.StringRequest""><Method>EchoString</Method></MapItem>" _
        "<MapItem MessageType=""" _ ..#DOCUMENTCLASS _ """><Method>EchoDocument</Method></MapItem></MapItems>" _ tNL _ "}" _ tNL _ "}" _ tNL
}

/// <p>Create and compile the probe classes in <code>USER</code>, add the echo operation to the stored probe production as an enabled
/// item and as a disabled one, and turn the production's <code>TestingEnabled</code> on. The probe production
/// (<method>OcuPilot.Test.ProductionProbe.Create</method>) must exist; it refuses when <code>USER</code> runs a production of
/// another's.</p>
ClassMethod Create() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "CheckOwn")
    If $$$ISERR(tSC) Quit tSC
    For tName = "TestAddress", "TestRequest", "TestRequestSub", "EchoOp", "TestBox", "TestReply", "ReplyOp" {
        Set tClass = ..#PACKAGE _ "." _ tName
        Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tClass, ..ClassText(tName))
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.CompilePackage(..#PACKAGE, "ck-d")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddItem", ..#ECHONAME, ..#ECHOCLASS, 1, 1)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddItem", ..#OFFNAME, ..#ECHOCLASS, 1, 0)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddItem", ..#REPLYNAME, ..#REPLYOPCLASS, 1, 1)
    If $$$ISOK(tSC) Set tSC = ..EnableTesting(1)
    Quit tSC
}

/// <p>Store the probe production's <code>TestingEnabled</code> as <var>pOn</var>. A running production reads an update pending until
/// it is updated or started again.</p>
ClassMethod EnableTesting(pOn As %Boolean) As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "CheckOwn")
    If $$$ISERR(tSC) Quit tSC
    Set tName = $Parameter(..#PROBE, "PRODUCTION")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tProduction = ##class(Ens.Config.Production).%OpenId(tName, 4)
        Set tProduction.TestingEnabled = ''pOn
        Set tSC = tProduction.%Save()
        Set tProduction = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Start the probe production through the port, wait for its own update after the start, then wait, twenty seconds at most, for
/// the testing service to read registered, which is what the tab's read calls <code>Testing</code>. A failing status names the step
/// that did not come.</p>
ClassMethod Start() As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = $Parameter(..#PROBE, "PRODUCTION")
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "START", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit $$$ERROR($$$GeneralError, "the probe production did not start: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$ClassMethod("OcuPilot.Test.InteropJobEnd", "StartUpdated", .tWhy) Quit $$$ERROR($$$GeneralError, tWhy)
    For tTry = 1:1:80 {
        If ..Testing() Quit
        Hang 0.25
    }
    If '..Testing() Quit $$$ERROR($$$GeneralError, "the testing service was not registered twenty seconds after the probe production started")
    Quit $$$OK
}

/// <p>Whether the item test's fresh read for the echo item reads <code>Testing</code> true.</p>
ClassMethod Testing() As %Boolean
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = $Parameter(..#PROBE, "PRODUCTION") _ "||" _ ..#ECHONAME
    Set tSC = $ClassMethod(..#PORT, "Invoke", "ItemTest", "TESTTARGET", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $$$ISOK(tSC) && $IsObject(tRow) && tRow.%Get("Testing")
}

/// <p>How many times the request class was created since the marker was last cleared, in <code>USER</code>.</p>
ClassMethod Marker() As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tCount = +$Get(^OcuPilotProbeInteropNew)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>Clear the creation marker.</p>
ClassMethod ClearMarker()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Kill ^OcuPilotProbeInteropNew
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>How many saved request rows and message headers <code>USER</code> holds, as <code>requests/headers</code>, <code>-</code> for a
/// count that could not be read.</p>
ClassMethod Counts() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tRequests = "-"
    Set tHeaders = "-"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If ##class(%Dictionary.CompiledClass).%ExistsId(..#REQUESTCLASS) {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilotProbe_Interop.TestRequest")
            If tRS.%Next() Set tRequests = tRS.%GetData(1)
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Ens.MessageHeader")
        If tRS.%Next() Set tHeaders = tRS.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tRequests _ "/" _ tHeaders
}

/// <p>The newest saved request's <code>Text</code>, <code>Count</code>, <code>Kind</code>, <code>Flag</code>, <code>Level</code> and
/// <code>Address.City</code>, as stored, joined by <code>|</code>; <code>""</code> when there is none.</p>
ClassMethod LastRequest() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(ID) FROM OcuPilotProbe_Interop.TestRequest")
        Set tId = $Select(tRS.%Next(): tRS.%GetData(1), 1: "")
        Set tRequest = $Select(tId = "": "", 1: $ClassMethod(..#REQUESTCLASS, "%OpenId", tId))
        If $IsObject(tRequest) {
            Set tText = tRequest.Text _ "|" _ tRequest.Count _ "|" _ tRequest.Kind _ "|" _ tRequest.Flag _ "|" _ tRequest.Level _ "|" _ $Select($IsObject(tRequest.Address): tRequest.Address.City, 1: "")
        }
        Set tRequest = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tText
}

/// <p>How many messages the testing service has sent in <code>USER</code>: one for each test it was given.</p>
ClassMethod TestSends() As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = -1
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Ens.MessageHeader WHERE SourceConfigName = ?", ..#TESTSERVICE)
        If tRS.%Next() Set tCount = tRS.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>Remove the request rows, the creation marker and the answers of the testing service the vendor keeps for <code>USER</code>,
/// and the messages a test leaves in the message store: the bodies of every message the probe's items and the testing service
/// exchanged, and the testing service's own headers. The classes, items and the probe's own headers are
/// <method>OcuPilot.Test.ProductionProbe.Remove</method>'s.</p>
ClassMethod Remove() As %Status
{
    Set tPrefix = $Parameter(..#PROBE, "CONFIGPREFIX")
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Kill tBodies
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT MessageBodyClassName, MessageBodyId FROM Ens.MessageHeader WHERE SourceConfigName %STARTSWITH ? OR TargetConfigName %STARTSWITH ? OR SourceConfigName = ?", tPrefix, tPrefix, ..#TESTSERVICE)
        While tRS.%Next() {
            Set tClass = tRS.%GetData(1)
            If (tClass '= "") && (tRS.%GetData(2) '= "") Set tBodies(tClass, tRS.%GetData(2)) = ""
        }
        Set tClass = ""
        For {
            Set tClass = $Order(tBodies(tClass))
            If tClass = "" Quit
            If '##class(%Dictionary.CompiledClass).%ExistsId(tClass) || '$ClassMethod(tClass, "%Extends", "%Library.Persistent") Continue
            Set tId = ""
            For {
                Set tId = $Order(tBodies(tClass, tId))
                If tId = "" Quit
                Do $ClassMethod(tClass, "%DeleteId", tId)
            }
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM Ens.MessageHeader WHERE SourceConfigName = ?", ..#TESTSERVICE)
        If ##class(%Dictionary.CompiledClass).%ExistsId(..#REQUESTCLASS) Do $ClassMethod(..#REQUESTCLASS, "%KillExtent")
        Kill ^OcuPilotProbeInteropNew
        Kill ^IRIS.Temp.EnsRuntimeAppData(..#NAMESPACE, ..#TESTSERVICE)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>1 when no answer node of the testing service is left for <code>USER</code>.</p>
ClassMethod NodesGone() As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tGone = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tGone = ('$Data(^IRIS.Temp.EnsRuntimeAppData(..#NAMESPACE, "EnsLib.Testing.Service")))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tGone
}

}
