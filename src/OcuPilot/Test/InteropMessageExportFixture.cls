/// <p>The probe messages Story 24.16 Batch 3's export tests arrange: stored headers, each marked <parameter>MARKER</parameter> in its source and target, each naming a body of one
/// of the four kinds an export meets -- an HL7 v2 message, an <class>Ens.StringRequest</class> (the XML adaptor), a character stream and a binary stream -- made in
/// <parameter>NAMESPACE</parameter> or <parameter>OTHERNAMESPACE</parameter>. <method>DropProbes</method> removes every one of them, and the body each names, from both namespaces, and
/// <method>Left</method> counts what survives, so a test can assert it left nothing behind. It starts no production.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropMessageExportFixture Extends %RegisteredObject
{

Parameter MARKER = "OcuProbe2416x";

Parameter NAMESPACE = "USER";

Parameter OTHERNAMESPACE = "HSCUSTOM";

/// <p>The text every probe body holds, which no log line, row or ledger entry may.</p>
Parameter SENTINEL = "ZqExportSentinel2416";

/// <p>The probe body classes by kind.</p>
Parameter HL7CLASS = "EnsLib.HL7.Message";

Parameter XMLCLASS = "Ens.StringRequest";

Parameter CHARCLASS = "%Stream.GlobalCharacter";

Parameter BINCLASS = "%Stream.GlobalBinary";

/// <p>The text of an HL7 probe body: two segments, the second with a character above 127 and one above 255, and a note holding <parameter>SENTINEL</parameter>.</p>
ClassMethod Hl7Text() As %String
{
    Quit "MSH|^~\&|PROBE|FAC|RCV|FAC|20260101120000||ADT^A01|MSG2416|P|2.3.1" _ $Char(13) _ "PID|1||123^^^MRN||DO" _ $Char(233) _ "^J" _ $Char(8364) _ "N" _ $Char(13) _ "NTE|1||" _ ..#SENTINEL
}

/// <p>The text of a character stream probe body, lines ending in a line feed.</p>
ClassMethod CharText() As %String
{
    Quit "alpha" _ $Char(10) _ "beta " _ $Char(233) _ $Char(10) _ "gamma " _ ..#SENTINEL
}

/// <p>The text of an XML probe body's one field.</p>
ClassMethod XmlText() As %String
{
    Quit ..#SENTINEL _ " xml <&> " _ $Char(233)
}

/// <p>The instance's own UTC time a minute ago in the vendor's logical form, made before a namespace is switched, as <class>OcuPilot.Test.InteropPurgeFixture</class> does.</p>
ClassMethod Stamp() As %String
{
    Quit ##class(OcuPilot.Test.InteropMessageRead).UtcAgo(60)
}

/// <p>Store a probe header in <var>pNamespace</var> naming a new body of kind <var>pKind</var> (<code>hl7</code>, <code>xml</code>, <code>chars</code> or <code>binary</code>) and answer
/// its id, or 0 when it could not be stored. <var>pSuffix</var> tells probes apart; <var>pText</var> replaces the kind's own body text when it is not empty. The body's class and id are
/// kept for <method>Left</method>.</p>
ClassMethod Store(pNamespace As %String, pKind As %String, pSuffix As %String = "", pText As %String = "") As %Integer
{
    Set tId = 0
    Set tOrigNS = $NAMESPACE
    Set tCreated = ..Stamp()
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = $$$OK
        If pKind = "hl7" {
            Set tBody = ##class(EnsLib.HL7.Message).ImportFromString($Select(pText '= "": pText, 1: ..Hl7Text()), .tSC)
            Set tClass = ..#HL7CLASS
        } ElseIf pKind = "xml" {
            Set tBody = ##class(Ens.StringRequest).%New()
            Set tBody.StringValue = $Select(pText '= "": pText, 1: ..XmlText())
            Set tClass = ..#XMLCLASS
        } ElseIf pKind = "chars" {
            Set tBody = ##class(%Stream.GlobalCharacter).%New()
            Do tBody.Write($Select(pText '= "": pText, 1: ..CharText()))
            Set tClass = ..#CHARCLASS
        } Else {
            Set tBody = ##class(%Stream.GlobalBinary).%New()
            Do tBody.Write($Select(pText '= "": pText, 1: "binary body " _ ..#SENTINEL))
            Set tClass = ..#BINCLASS
        }
        If $$$ISOK(tSC) Set tSC = tBody.%Save()
        If $$$ISOK(tSC) {
            Set tHeader = ##class(Ens.MessageHeader).%New()
            Set tHeader.SourceConfigName = ..#MARKER _ "Src" _ pSuffix
            Set tHeader.TargetConfigName = ..#MARKER _ "Op" _ pSuffix
            Set tHeader.MessageBodyClassName = tClass
            Set tHeader.MessageBodyId = tBody.%Id()
            Set tHeader.Type = 1
            Set tHeader.Priority = 6
            Set tHeader.Status = 9
            Set tHeader.TimeCreated = tCreated
            Set tHeader.TimeProcessed = tCreated
            Set tSC = tHeader.%Save()
            If $$$ISOK(tSC) {
                Set tId = tHeader.%Id()
                Set tHeader.SessionId = tId
                Do tHeader.%Save()
                Set ^||OcuExportBodies(pNamespace, tClass, tBody.%Id()) = tId
            }
        }
        Set tBody = ""
        Set tHeader = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tId = 0
    }
    Quit tId
}

/// <p>Delete the body header <var>pId</var> names in <var>pNamespace</var>, leaving the header: a message whose body is gone.</p>
ClassMethod DeleteBody(pNamespace As %String, pId As %String) As %Boolean
{
    Set tDone = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId)
        If $IsObject(tHeader) Set tDone = $$$ISOK($ClassMethod(tHeader.MessageBodyClassName, "%DeleteId", tHeader.MessageBodyId))
        Set tHeader = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tDone = 0
    }
    Quit tDone
}

/// <p>The text of the body header <var>pId</var> names in <var>pNamespace</var> as the class's own text read, <code>&lt;none&gt;</code> for a body that is gone: the
/// <code>StringValue</code> of an XML probe, the stream's text, or the HL7 message's raw content.</p>
ClassMethod BodyText(pNamespace As %String, pId As %String) As %String
{
    Set tText = "<none>"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId)
        If $IsObject(tHeader) && $ClassMethod(tHeader.MessageBodyClassName, "%ExistsId", tHeader.MessageBodyId) {
            Set tBody = $ClassMethod(tHeader.MessageBodyClassName, "%OpenId", tHeader.MessageBodyId)
            If tBody.%Extends("%Stream.Object") {
                Do tBody.Rewind()
                Set tText = tBody.Read(100000)
            } ElseIf tBody.%Extends("Ens.StringRequest") {
                Set tText = tBody.StringValue
            } Else {
                Set tText = tBody.OutputToString()
            }
        }
        Set tHeader = ""
        Set tBody = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = "<unread>"
    }
    Quit tText
}

/// <p>How many probe headers <var>pNamespace</var> holds, or -1 when it cannot be read.</p>
ClassMethod Headers(pNamespace As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = -1
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT COUNT(*) FROM Ens.MessageHeader WHERE SourceConfigName LIKE ?", ..#MARKER _ "%")
        If (tRS.%SQLCODE = 0) && tRS.%Next() Set tCount = +tRS.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>How many probe bodies this process stored are still in their namespaces.</p>
ClassMethod BodiesLeft() As %Integer
{
    Set tLeft = 0
    Set tOrigNS = $NAMESPACE
    Set tNamespace = ""
    For {
        Set tNamespace = $Order(^||OcuExportBodies(tNamespace))
        If tNamespace = "" Quit
        Try {
            Set $NAMESPACE = tNamespace
            Set tClass = ""
            For {
                Set tClass = $Order(^||OcuExportBodies(tNamespace, tClass))
                If tClass = "" Quit
                Set tBodyId = ""
                For {
                    Set tBodyId = $Order(^||OcuExportBodies(tNamespace, tClass, tBodyId))
                    If tBodyId = "" Quit
                    If $ClassMethod(tClass, "%ExistsId", tBodyId) Set tLeft = tLeft + 1
                }
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
            Set tLeft = tLeft + 1
        }
    }
    Quit tLeft
}

/// <p>Everything a test left, as one line: <code>headers=&lt;USER&gt;/&lt;HSCUSTOM&gt; bodies=&lt;n&gt;</code>. Clean is <code>headers=0/0 bodies=0</code>.</p>
ClassMethod Left() As %String
{
    Quit "headers=" _ ..Headers(..#NAMESPACE) _ "/" _ ..Headers(..#OTHERNAMESPACE) _ " bodies=" _ ..BodiesLeft()
}

/// <p>Remove every probe header, and the body each names, from <parameter>NAMESPACE</parameter> and <parameter>OTHERNAMESPACE</parameter>, and the bodies this process stored whose
/// header was already removed; answer <code>1</code> when nothing survives.</p>
ClassMethod DropProbes() As %Boolean
{
    Set tOrigNS = $NAMESPACE
    For tNamespace = ..#NAMESPACE, ..#OTHERNAMESPACE {
        Try {
            Set $NAMESPACE = tNamespace
            Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT ID, MessageBodyClassName, MessageBodyId FROM Ens.MessageHeader WHERE SourceConfigName LIKE ?", ..#MARKER _ "%")
            Kill tFound
            While tRS.%Next() {
                Set tFound($Increment(tFound)) = $ListBuild(tRS.%GetData(1), tRS.%GetData(2), tRS.%GetData(3))
            }
            For tI = 1:1:+$Get(tFound) {
                Do ##class(Ens.MessageHeader).%DeleteId($List(tFound(tI), 1))
                If ($List(tFound(tI), 2) '= "") && ##class(%Dictionary.CompiledClass).%ExistsId($List(tFound(tI), 2)) Do $ClassMethod($List(tFound(tI), 2), "%DeleteId", $List(tFound(tI), 3))
            }
            Set tClass = ""
            For {
                Set tClass = $Order(^||OcuExportBodies(tNamespace, tClass))
                If tClass = "" Quit
                Set tBodyId = ""
                For {
                    Set tBodyId = $Order(^||OcuExportBodies(tNamespace, tClass, tBodyId))
                    If tBodyId = "" Quit
                    If $ClassMethod(tClass, "%ExistsId", tBodyId) Do $ClassMethod(tClass, "%DeleteId", tBodyId)
                }
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
    }
    Set tClean = (..Left() = "headers=0/0 bodies=0")
    Kill ^||OcuExportBodies
    Quit tClean
}

}
