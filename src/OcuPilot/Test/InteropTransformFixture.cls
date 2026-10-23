/// <p>The probe data transformations of Story 20.27's transformation test, created in <code>USER</code> on a throwaway container: a
/// transformation of each shape the test meets (<parameter>XML</parameter> to <parameter>HL7</parameter> and <parameter>X12</parameter>,
/// an EDI XML copy (<parameter>EDIXML</parameter>), an existing target, a Record Map batch, stream classes, a fault that escapes <code>Transform</code>) and one named like OcuPilot's
/// own code (<parameter>OWN</parameter>) for the prohibited leg. Everything is created in the packages
/// <parameter>PACKAGE</parameter> and <parameter>OWNPACKAGE</parameter> and removed by <method>Remove</method>, with the run counter
/// <parameter>COUNTER</parameter>.</p>
/// <p><b>Every transformation counts its runs</b> in <parameter>COUNTER</parameter>. The XML transformation does what its input says:
/// <code>fail</code> answers an error status, <code>write</code> writes a line to the device, <code>noisy</code> writes 1,000,100
/// characters to it, past the output bound, <code>save</code> saves its target and
/// <code>none</code> leaves no target and <code>big</code> makes the target 12,000 lines of 99 characters, 1.2 million characters in
/// all, past the output bound. Any other value answers <code>out:&lt;value&gt;</code>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. Each method switches to
/// <parameter>NAMESPACE</parameter> by explicit save and restore and calls only vendor classes while switched.</p>
Class OcuPilot.Test.InteropTransformFixture Extends %RegisteredObject
{

Parameter NAMESPACE = "USER";

Parameter PACKAGE = "OcuProbeDtl";

Parameter OWNPACKAGE = "OcuPilotProbe";

Parameter XML = "OcuProbeDtl.Xml";

Parameter EXISTING = "OcuProbeDtl.Existing";

Parameter HL7 = "OcuProbeDtl.Hl7";

Parameter X12 = "OcuProbeDtl.X12";

/// <p>A copy of an EDI XML document, which is a virtual document and an XML adaptor class both.</p>
Parameter EDIXML = "OcuProbeDtl.EdiXml";

Parameter RAW = "OcuProbeDtl.Raw";

Parameter BATCH = "OcuProbeDtl.Batch";

Parameter FROMSTREAM = "OcuProbeDtl.FromStream";

Parameter TOSTREAM = "OcuProbeDtl.ToStream";

/// <p>A source and a target that are both streams, so the source is the format refusal that is answered.</p>
Parameter STREAMBOTH = "OcuProbeDtl.StreamBoth";

/// <p>The transformations whose source is a record class of each remaining Record Map base the test refuses, and those record
/// classes. The bases are abstract mixins, so each record class extends one beside <class>%RegisteredObject</class> and the XML adaptor.</p>
Parameter RMBASE = "OcuProbeDtl.RmBase";

Parameter RMCOMPLEXBASE = "OcuProbeDtl.RmComplexBase";

Parameter RMCOMPLEXPARENT = "OcuProbeDtl.RmComplexParent";

Parameter RECBASE = "OcuProbeDtl.RecBase";

Parameter RECCOMPLEXBASE = "OcuProbeDtl.RecComplexBase";

Parameter RECCOMPLEXPARENT = "OcuProbeDtl.RecComplexParent";

/// <p>A transformation whose class is stored but never compiled, so the list reports it and the test cannot run it.</p>
Parameter UNCOMPILED = "OcuProbeDtl.Uncompiled";

/// <p>The transformation named like OcuPilot's own code, which the prohibited set refuses.</p>
Parameter OWN = "OcuPilotProbe.OwnDtl";

/// <p>The global, in <parameter>NAMESPACE</parameter>, that counts the probe transformations' runs.</p>
Parameter COUNTER = "^OcuProbeDtlRuns";

/// <p>The line the XML transformation writes to the device for <code>write</code>.</p>
Parameter DEVICELINE = "probe-device-line";

/// <p>The text of an XML message the XML transformation parses, and of an HL7 ADT_A01 and an X12 interchange.</p>
Parameter XMLTEXT = "<StringRequest><StringValue>x</StringValue></StringRequest>";

Parameter EDIXMLTEXT = "<root><a>1</a><b>two</b></root>";

Parameter X12TEXT = "ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *210101*1200*^*00501*000000001*0*P*:~GS*HC*SENDER*RECEIVER*20210101*1200*1*X*005010X222A1~ST*837*0001*005010X222A1~BHT*0019*00*0123*20210101*1200*CH~SE*3*0001~GE*1*1~IEA*1*000000001~";

/// <p>The names of the classes this fixture creates, comma-separated.</p>
Parameter CLASSES = "OcuProbeDtl.Xml,OcuProbeDtl.Existing,OcuProbeDtl.Hl7,OcuProbeDtl.X12,OcuProbeDtl.EdiXml,OcuProbeDtl.Raw,OcuProbeDtl.Batch,OcuProbeDtl.FromStream,OcuProbeDtl.ToStream,OcuProbeDtl.StreamBoth,OcuProbeDtl.RecBase,OcuProbeDtl.RecComplexBase,OcuProbeDtl.RecComplexParent,OcuProbeDtl.RmBase,OcuProbeDtl.RmComplexBase,OcuProbeDtl.RmComplexParent,OcuProbeDtl.Uncompiled,OcuPilotProbe.OwnDtl";

/// <p>An XML message for the XML transformation whose value is <var>pValue</var>.</p>
ClassMethod Message(pValue As %String) As %String
{
    Quit "<StringRequest><StringValue>" _ pValue _ "</StringValue></StringRequest>"
}

/// <p>An HL7 ADT_A01 message, its segments separated by carriage returns.</p>
ClassMethod Hl7Text() As %String
{
    Set tCR = $Char(13)
    Quit "MSH|^~\&|OCUSENDER|OCUFAC|OCURECV|OCUFAC|20260101000000||ADT^A01|MSG1|P|2.5" _ tCR _ "EVN|A01|20260101000000" _ tCR _ "PID|1||PAT001^^^OCU^MR||DOE^JANE||19800101|F" _ tCR _ "PV1|1|I|ICU^101^A"
}

/// <p>The text of the probe class <var>pName</var>.</p>
ClassMethod ClassText(pName As %String) As %String [ Private ]
{
    Set tNL = $Char(13, 10)
    Set tHead = "Parameter IGNOREMISSINGSOURCE = 1;" _ tNL _ "Parameter REPORTERRORS = 1;" _ tNL _ "XData DTL [ XMLNamespace = ""http://www.intersystems.com/dtl"" ]" _ tNL _ "{" _ tNL
    Set tCount = "<code><![CDATA[ Set " _ ..#COUNTER _ " = $Get(" _ ..#COUNTER _ ") + 1]]></code>" _ tNL
    If (pName = ..#XML) || (pName = ..#OWN) {
        Quit "Class " _ pName _ " Extends Ens.DataTransformDTL" _ tNL _ "{" _ tNL _ tHead _
            "<transform sourceClass='Ens.StringRequest' targetClass='Ens.StringResponse' create='new' language='objectscript'>" _ tNL _
            "<assign value='""out:""_source.StringValue' property='target.StringValue' action='set' />" _ tNL _
            tCount _
            "<code><![CDATA[ If source.StringValue = ""fail"" Set tSC = $$$ERROR($$$GeneralError, ""probe-fail"")]]></code>" _ tNL _
            "<code><![CDATA[ If source.StringValue = ""write"" W """ _ ..#DEVICELINE _ """]]></code>" _ tNL _
            "<code><![CDATA[ If source.StringValue = ""save"" Set tSC = target.%Save()]]></code>" _ tNL _
            "<code><![CDATA[ If source.StringValue = ""none"" Set target = """"]]></code>" _ tNL _
            "<code><![CDATA[ If source.StringValue = ""noisy"" W $Translate($Justify("""", 1000100), "" "", ""n"")]]></code>" _ tNL _
            "<code><![CDATA[ If source.StringValue = ""big"" { Set tBigText = """" For tBigN = 1:1:12000 { Set tBigText = tBigText _ ""line-"" _ $Translate($Justify(tBigN, 94), "" "", ""0"") _ $Char(10) } Set target.StringValue = tBigText }]]></code>" _ tNL _
            "</transform>" _ tNL _ "}" _ tNL _ "}" _ tNL
    }
    If pName = ..#EXISTING {
        Quit "Class " _ pName _ " Extends Ens.DataTransformDTL" _ tNL _ "{" _ tNL _ tHead _
            "<transform sourceClass='Ens.StringRequest' targetClass='Ens.StringResponse' create='existing' language='objectscript'>" _ tNL _
            tCount _
            "<assign value='target.StringValue_""existing:""_source.StringValue' property='target.StringValue' action='set' />" _ tNL _
            "</transform>" _ tNL _ "}" _ tNL _ "}" _ tNL
    }
    If pName = ..#HL7 {
        Quit "Class " _ pName _ " Extends Ens.DataTransformDTL" _ tNL _ "{" _ tNL _ tHead _
            "<transform sourceClass='EnsLib.HL7.Message' targetClass='EnsLib.HL7.Message' sourceDocType='2.5:ADT_A01' targetDocType='2.5:ADT_A01' create='copy' language='objectscript'>" _ tNL _
            tCount _
            "<assign value='""PROBEAPP""' property='target.{MSH:SendingApplication}' action='set' />" _ tNL _
            "</transform>" _ tNL _ "}" _ tNL _ "}" _ tNL
    }
    If pName = ..#X12 {
        Quit "Class " _ pName _ " Extends Ens.DataTransformDTL" _ tNL _ "{" _ tNL _ tHead _
            "<transform sourceClass='EnsLib.EDI.X12.Document' targetClass='EnsLib.EDI.X12.Document' create='copy' language='objectscript'>" _ tNL _
            tCount _
            "</transform>" _ tNL _ "}" _ tNL _ "}" _ tNL
    }
    If pName = ..#EDIXML {
        Quit "Class " _ pName _ " Extends Ens.DataTransformDTL" _ tNL _ "{" _ tNL _ tHead _
            "<transform sourceClass='EnsLib.EDI.XML.Document' targetClass='EnsLib.EDI.XML.Document' create='copy' language='objectscript'>" _ tNL _
            tCount _
            "</transform>" _ tNL _ "}" _ tNL _ "}" _ tNL
    }
    If pName = ..#RAW Quit ..CodeText(pName, "Ens.StringRequest", "Ens.StringResponse", " Set tZero = 0" _ tNL _ " Quit 1 / tZero")
    If pName = ..#BATCH Quit ..CodeText(pName, "EnsLib.RecordMap.SimpleBatch", "Ens.StringResponse", " Quit $$$OK")
    If pName = ..#FROMSTREAM Quit ..CodeText(pName, "%Stream.GlobalCharacter", "Ens.StringResponse", " Quit $$$OK")
    If pName = ..#STREAMBOTH Quit ..CodeText(pName, "%Stream.GlobalCharacter", "%Stream.GlobalCharacter", " Quit $$$OK")
    If pName = ..#RECBASE Quit ..RecordText(pName, "EnsLib.RecordMap.Base")
    If pName = ..#RECCOMPLEXBASE Quit ..RecordText(pName, "EnsLib.RecordMap.ComplexBase")
    If pName = ..#RECCOMPLEXPARENT Quit ..RecordText(pName, "EnsLib.RecordMap.ComplexParent")
    If pName = ..#RMBASE Quit ..CodeText(pName, ..#RECBASE, "Ens.StringResponse", " Quit $$$OK")
    If pName = ..#RMCOMPLEXBASE Quit ..CodeText(pName, ..#RECCOMPLEXBASE, "Ens.StringResponse", " Quit $$$OK")
    If pName = ..#RMCOMPLEXPARENT Quit ..CodeText(pName, ..#RECCOMPLEXPARENT, "Ens.StringResponse", " Quit $$$OK")
    If pName = ..#UNCOMPILED Quit ..CodeText(pName, "Ens.StringRequest", "Ens.StringResponse", " Quit $$$OK")
    Quit ..CodeText(pName, "Ens.StringRequest", "%Stream.GlobalCharacter", " Quit $$$OK")
}

/// <p>The text of a transformation written as code: an <code>Ens.DataTransform</code> subclass whose own <code>Transform</code> takes
/// <var>pSource</var> and gives <var>pTarget</var> and runs <var>pBody</var>.</p>
ClassMethod CodeText(pName As %String, pSource As %String, pTarget As %String, pBody As %String) As %String [ Private ]
{
    Set tNL = $Char(13, 10)
    Quit "Class " _ pName _ " Extends Ens.DataTransform" _ tNL _ "{" _ tNL _
        "ClassMethod Transform(source As " _ pSource _ ", ByRef target As " _ pTarget _ ") As %Status" _ tNL _ "{" _ tNL _
        " Set " _ ..#COUNTER _ " = $Get(" _ ..#COUNTER _ ") + 1" _ tNL _ pBody _ tNL _ "}" _ tNL _ "}" _ tNL
}

/// <p>The text of a record class of the Record Map base <var>pBase</var>: a plain class that extends it and the XML adaptor, as a
/// generated record does, so only the base tells it from an XML class.</p>
ClassMethod RecordText(pName As %String, pBase As %String) As %String [ Private ]
{
    Set tNL = $Char(13, 10)
    Quit "Class " _ pName _ " Extends (%RegisteredObject, %XML.Adaptor, " _ pBase _ ")" _ tNL _ "{" _ tNL _ "}" _ tNL
}

/// <p>The probe classes that are compiled: <parameter>CLASSES</parameter> without <parameter>UNCOMPILED</parameter>, which is stored
/// and left as it is.</p>
ClassMethod CompiledClasses() As %String [ Private ]
{
    Set tList = ""
    For tI = 1:1:$Length(..#CLASSES, ",") {
        Set tClass = $Piece(..#CLASSES, ",", tI)
        If tClass '= ..#UNCOMPILED Set tList = tList _ $Select(tList = "": "", 1: ",") _ tClass
    }
    Quit tList
}

/// <p>Create the probe classes in <parameter>NAMESPACE</parameter>, compile all but <parameter>UNCOMPILED</parameter>, and reset the
/// run counter. Removes what it made when a class does not compile.</p>
ClassMethod Create() As %Status
{
    Set tSC = ..Remove()
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Length(..#CLASSES, ",") {
        Set tClass = $Piece(..#CLASSES, ",", tI)
        Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tClass, ..ClassText(tClass))
        If $$$ISERR(tSC) Quit
    }
    If $$$ISOK(tSC) {
        Set tOrigNS = $NAMESPACE
        Set tCompiled = ..CompiledClasses()
        Try {
            Set $NAMESPACE = ..#NAMESPACE
            Set tSC = $System.OBJ.Compile(tCompiled, "ck-d")
            Set tCounter = ..#COUNTER
            Kill @tCounter
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Set tSC = ex.AsStatus()
        }
    }
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..Remove())
    Quit tSC
}

/// <p>Delete the probe classes and the run counter, and a failing status when any class survives.</p>
ClassMethod Remove() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tI = 1:1:$Length(..#CLASSES, ",") {
            Set tClass = $Piece(..#CLASSES, ",", tI)
            If ##class(%Dictionary.ClassDefinition).%ExistsId(tClass) Set tSC = $$$ADDSC(tSC, $System.OBJ.Delete(tClass, "-d"))
        }
        Set tCounter = ..#COUNTER
        Kill @tCounter
        For tI = 1:1:$Length(..#CLASSES, ",") {
            Set tClass = $Piece(..#CLASSES, ",", tI)
            If ##class(%Dictionary.ClassDefinition).%ExistsId(tClass) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the probe class " _ tClass _ " was not removed"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many times the probe transformations have run since the fixture was created, in <parameter>NAMESPACE</parameter>.</p>
ClassMethod Runs() As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tCounter = ..#COUNTER
        Set tCount = +$Get(@tCounter)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>The row counts, in <parameter>NAMESPACE</parameter>, of the extents a transformation could store a message in: the string
/// requests and responses, the HL7 messages and the X12 documents, as <code>name=count</code> pairs separated by semicolons. A
/// count the extent cannot give reads <code>-1</code>.</p>
ClassMethod Counts() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tTable = "Ens.StringRequest", "Ens.StringResponse", "EnsLib_HL7.Message", "EnsLib_EDI_X12.Document" {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM " _ tTable)
            Set tCount = $Select((tRS.%SQLCODE = 0) && tRS.%Next(): tRS.%GetData(1), 1: -1)
            Set tText = tText _ $Select(tText = "": "", 1: ";") _ tTable _ "=" _ tCount
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread"
    }
    Quit tText
}

}
