/// <p>The probe messages and archive state Story 24.16's archive tests arrange. Every probe header carries <parameter>MARKER</parameter> in its source and target, is made in
/// <parameter>SOURCE</parameter> (or <parameter>TARGET</parameter> for a header the target already holds), and is back-dated by whole days; its body is one of four kinds: an HL7 v2
/// message, an <class>Ens.StringRequest</class>, a character stream, or none. <method>DropProbes</method> removes every probe header and body from both namespaces and every archived
/// copy of one from the target, <method>SaveTrees</method> and <method>RestoreTrees</method> put each namespace's <code>^Ens.ArchiveManager</code> back exactly as it was found,
/// and <method>Left</method> reads what a test left behind. It starts no production.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropArchiveFixture Extends %RegisteredObject
{

Parameter MARKER = "OcuProbe2416Arc";

Parameter SOURCE = "HSCUSTOM";

Parameter TARGET = "USER";

/// <p>How old a probe that an archive run is meant to move is made, in days, and the days such a run is given.</p>
Parameter OLDDAYS = 7300;

Parameter RUNDAYS = 3650;

/// <p>The archive class a run is allowed to use.</p>
Parameter VENDORCLASS = "Ens.Archive.Manager";

/// <p>The text no archived copy's header may carry beyond its body: the sentinel every text body holds.</p>
Parameter SENTINEL = "ZqArchiveSentinel2416";

/// <p>The text of an HL7 probe body. Its characters stay within Latin-1: the vendor's archive saves an HL7 body's character above 255 as <code>?</code> (measured).</p>
ClassMethod Hl7Text() As %String
{
    Quit "MSH|^~\&|PROBE|FAC|RCV|FAC|20260101120000||ADT^A01|MSG2416|P|2.3.1" _ $Char(13) _ "PID|1||123^^^MRN||DO" _ $Char(233) _ "^J" _ $Char(246) _ "N" _ $Char(13) _ "NTE|1||" _ ..#SENTINEL
}

/// <p>The text of a character stream probe body.</p>
ClassMethod CharText() As %String
{
    Quit "alpha" _ $Char(10) _ "beta " _ $Char(233) _ $Char(10) _ "gamma " _ ..#SENTINEL
}

/// <p>The text of an <class>Ens.StringRequest</class> probe body.</p>
ClassMethod XmlText() As %String
{
    Quit ..#SENTINEL _ " xml <&> " _ $Char(233)
}

/// <p>Store a probe header in <var>pNamespace</var> made <var>pDays</var> days ago with status <var>pStatus</var> and a new body of kind <var>pKind</var> (<code>hl7</code>,
/// <code>xml</code>, <code>chars</code> or <code>none</code>), and answer its id, or 0 when it could not be stored. <var>pSuffix</var> tells probes apart. The body's class and id are
/// kept for <method>DropProbes</method>.</p>
ClassMethod Store(pNamespace As %String, pKind As %String, pSuffix As %String = "", pDays As %Integer = {..#OLDDAYS}, pStatus As %Integer = 9) As %Integer
{
    Set tId = 0
    Set tOrigNS = $NAMESPACE
    ; The stamp is made before the switch: the test package is not visible from a namespace that does not hold it.
    Set tCreated = ##class(OcuPilot.Test.InteropMessageRead).UtcAgo(pDays * 86400)
    If pNamespace = ..#SOURCE Do ..RaiseAboveTarget()
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = $$$OK
        Set tClass = ""
        If pKind = "hl7" {
            Set tBody = ##class(EnsLib.HL7.Message).ImportFromString(..Hl7Text(), .tSC)
            Set tClass = "EnsLib.HL7.Message"
        } ElseIf pKind = "xml" {
            Set tBody = ##class(Ens.StringRequest).%New()
            Set tBody.StringValue = ..XmlText()
            Set tClass = "Ens.StringRequest"
        } ElseIf pKind = "chars" {
            Set tBody = ##class(%Stream.GlobalCharacter).%New()
            Do tBody.Write(..CharText())
            Set tClass = "%Stream.GlobalCharacter"
        }
        If (tClass '= "") && $$$ISOK(tSC) Set tSC = tBody.%Save()
        If $$$ISOK(tSC) {
            Set tHeader = ##class(Ens.MessageHeader).%New()
            Set tHeader.SourceConfigName = ..#MARKER _ "Src" _ pSuffix
            Set tHeader.TargetConfigName = ..#MARKER _ "Op" _ pSuffix
            If tClass '= "" {
                Set tHeader.MessageBodyClassName = tClass
                Set tHeader.MessageBodyId = tBody.%Id()
            }
            Set tHeader.Type = 1
            Set tHeader.Priority = 6
            Set tHeader.Status = pStatus
            Set tHeader.TimeCreated = tCreated
            Set tHeader.TimeProcessed = tCreated
            Set tSC = tHeader.%Save()
            If $$$ISOK(tSC) {
                Set tId = tHeader.%Id()
                Set tHeader.SessionId = tId
                Do tHeader.%Save()
                If tClass '= "" Set ^||OcuArchiveBodies(pNamespace, tClass, tBody.%Id()) = tId
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

/// <p>Store the probe header <var>pId</var> in <var>pNamespace</var> with no body, back-dated <var>pDays</var> days, by moving that namespace's id counter to <code>pId - 1</code>
/// first: a namespace that holds a message with the id another namespace's probe has. The counter is put back to the larger of its value and <var>pId</var>. Answer the id stored,
/// or 0.</p>
ClassMethod StoreWithId(pNamespace As %String, pId As %Integer, pSuffix As %String = "", pDays As %Integer = {..#OLDDAYS}) As %Integer
{
    Set tId = 0
    Set tOrigNS = $NAMESPACE
    Set tCreated = ##class(OcuPilot.Test.InteropMessageRead).UtcAgo(pDays * 86400)
    Try {
        Set $NAMESPACE = pNamespace
        Set tCounter = +$Get(^Ens.MessageHeaderD)
        Set ^Ens.MessageHeaderD = pId - 1
        Set tHeader = ##class(Ens.MessageHeader).%New()
        Set tHeader.SourceConfigName = ..#MARKER _ "Src" _ pSuffix
        Set tHeader.TargetConfigName = ..#MARKER _ "Op" _ pSuffix
        Set tHeader.Type = 1
        Set tHeader.Priority = 6
        Set tHeader.Status = 9
        Set tHeader.TimeCreated = tCreated
        Set tHeader.TimeProcessed = tCreated
        If $$$ISOK(tHeader.%Save()) Set tId = tHeader.%Id()
        Set tHeader = ""
        If +$Get(^Ens.MessageHeaderD) < tCounter Set ^Ens.MessageHeaderD = tCounter
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tId = 0
    }
    Quit tId
}

/// <p>Store a probe header in <var>pNamespace</var> back-dated <var>pDays</var> days that names a body class that does not exist, so the vendor's run raises an error for it and
/// logs it; answer its id, or 0.</p>
ClassMethod StoreBroken(pNamespace As %String, pSuffix As %String = "", pDays As %Integer = {..#OLDDAYS}) As %Integer
{
    Set tId = 0
    Set tOrigNS = $NAMESPACE
    Set tCreated = ##class(OcuPilot.Test.InteropMessageRead).UtcAgo(pDays * 86400)
    If pNamespace = ..#SOURCE Do ..RaiseAboveTarget()
    Try {
        Set $NAMESPACE = pNamespace
        Set tHeader = ##class(Ens.MessageHeader).%New()
        Set tHeader.SourceConfigName = ..#MARKER _ "Src" _ pSuffix
        Set tHeader.TargetConfigName = ..#MARKER _ "Op" _ pSuffix
        Set tHeader.MessageBodyClassName = "OcuProbe2416.NoSuchBodyClass"
        Set tHeader.MessageBodyId = 1
        Set tHeader.Type = 1
        Set tHeader.Priority = 6
        Set tHeader.Status = 9
        Set tHeader.TimeCreated = tCreated
        Set tHeader.TimeProcessed = tCreated
        If $$$ISOK(tHeader.%Save()) {
            Set tId = tHeader.%Id()
            Set tHeader.SessionId = tId
            Do tHeader.%Save()
        }
        Set tHeader = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tId = 0
    }
    Quit tId
}

/// <p>Create each principal of <var>pPrincipals</var> (<code>user:pairs</code>, separated by <code>;</code>) with a role of its own holding exactly its pairs, every user with the
/// password <var>pPassword</var>. Unlike <class>OcuPilot.Test.InteropLookupGate</class>'s, the role holds no database beyond those the pairs name, so a pair set can leave the
/// install namespace's database at READ or without WRITE.</p>
ClassMethod CreatePrincipals(pPrincipals As %String, pPassword As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(pPrincipals, ";") {
            Set tEntry = $Piece(pPrincipals, ";", tI)
            Set tUser = $Piece(tEntry, ":", 1)
            Set tRole = tUser _ "Role"
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the archive gate (throwaway)", $Piece(tEntry, ":", 2, *), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, pPassword, "OcuPilot test principal (throwaway)", "", "", "", 0, 1, "Created by an OcuPilot gate test; deleted when it ends")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove each user of <var>pPrincipals</var> and its role.</p>
ClassMethod DeletePrincipals(pPrincipals As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(pPrincipals, ";") {
            Set tUser = $Piece($Piece(pPrincipals, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Delete(tUser))
            If ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete(tUser _ "Role"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Move <var>pNamespace</var>'s message header id counter to <var>pValue</var> when it is lower, so the next header stored there takes an id above it. Answer the counter.</p>
ClassMethod RaiseCounter(pNamespace As %String, pValue As %Integer) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCounter = -1
    Try {
        Set $NAMESPACE = pNamespace
        If +$Get(^Ens.MessageHeaderD) < pValue Set ^Ens.MessageHeaderD = pValue
        Set tCounter = +$Get(^Ens.MessageHeaderD)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCounter
}

/// <p>Raise the source's message header id counter above every id the target holds or has given out, so a probe stored in the source never shares an id with a message
/// another class left in the target, which a run would refuse as taken. <method>Store</method> and <method>StoreBroken</method> call it for each probe stored in the source.
/// Answer the source's counter.</p>
ClassMethod RaiseAboveTarget() As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tHighest = 0
    Try {
        Set $NAMESPACE = ..#TARGET
        Set tHighest = +$Get(^Ens.MessageHeaderD)
        Set tLast = +$Order(^Ens.MessageHeaderD(""), -1)
        If tLast > tHighest Set tHighest = tLast
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit ..RaiseCounter(..#SOURCE, tHighest)
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

/// <p>How many headers of any kind <var>pNamespace</var> holds, or -1 when it cannot be read.</p>
ClassMethod AllHeaders(pNamespace As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = -1
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT COUNT(*) FROM Ens.MessageHeader")
        If (tRS.%SQLCODE = 0) && tRS.%Next() Set tCount = +tRS.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>The ids of the probe headers <var>pNamespace</var> holds, ascending, as a comma-separated text, or <code>?</code> when it cannot be read.</p>
ClassMethod HeaderIds(pNamespace As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT ID FROM Ens.MessageHeader WHERE SourceConfigName LIKE ? ORDER BY ID", ..#MARKER _ "%")
        While tRS.%Next() {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRS.%GetData(1)
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = "?"
    }
    Quit tText
}

/// <p>What <var>pNamespace</var> holds for the probe header <var>pId</var>, as <code>class|bodyId|text</code>: the body class and id the header names and the body's text as the
/// archive stores it (the stream of an archived body), <code>&lt;none&gt;</code> for a header that is not there and <code>&lt;nobody&gt;</code> for one that names no body. Answer
/// the original body text for a body the namespace still holds, by its class's own read.</p>
ClassMethod BodyOf(pNamespace As %String, pId As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "<none>"
    Try {
        Set $NAMESPACE = pNamespace
        Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId)
        If $IsObject(tHeader) {
            Set tClass = tHeader.MessageBodyClassName
            Set tBodyId = tHeader.MessageBodyId
            Set tText = tClass _ "|" _ tBodyId _ "|"
            If tClass = "" {
                Set tText = tText _ "<nobody>"
            } ElseIf $ClassMethod(tClass, "%ExistsId", tBodyId) {
                Set tBody = $ClassMethod(tClass, "%OpenId", tBodyId)
                If tClass = "Ens.Archive.MessageBody" {
                    Do tBody.OriginalMessageBodyStream.Rewind()
                    Set tText = tText _ tBody.OriginalMessageBodyStream.Read(100000)
                } ElseIf tBody.%Extends("%Stream.Object") {
                    Do tBody.Rewind()
                    Set tText = tText _ tBody.Read(100000)
                } ElseIf tBody.%Extends("Ens.StringRequest") {
                    Set tText = tText _ tBody.StringValue
                } Else {
                    Set tText = tText _ tBody.OutputToString()
                }
            } Else {
                Set tText = tText _ "<gone>"
            }
        }
        Set tHeader = ""
        Set tBody = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "<unread " _ ex.Name _ ">"
    }
    Quit tText
}

/// <p>The source name of the header <var>pId</var> in <var>pNamespace</var>, or <code>&lt;none&gt;</code>: which of two messages of one id a namespace holds.</p>
ClassMethod SourceOf(pNamespace As %String, pId As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "<none>"
    Try {
        Set $NAMESPACE = pNamespace
        Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId)
        If $IsObject(tHeader) Set tText = tHeader.SourceConfigName
        Set tHeader = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = "<unread>"
    }
    Quit tText
}

/// <p>How many probe bodies this process stored are still in the namespace that held them.</p>
ClassMethod BodiesLeft() As %Integer
{
    Set tLeft = 0
    Set tOrigNS = $NAMESPACE
    Set tNamespace = ""
    For {
        Set tNamespace = $Order(^||OcuArchiveBodies(tNamespace))
        If tNamespace = "" Quit
        Try {
            Set $NAMESPACE = tNamespace
            Set tClass = ""
            For {
                Set tClass = $Order(^||OcuArchiveBodies(tNamespace, tClass))
                If tClass = "" Quit
                Set tBodyId = ""
                For {
                    Set tBodyId = $Order(^||OcuArchiveBodies(tNamespace, tClass, tBodyId))
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

/// <p>How many archived bodies <var>pNamespace</var> holds that came from <parameter>SOURCE</parameter> and carry <parameter>SENTINEL</parameter> or name a probe header, or -1.</p>
ClassMethod ArchivedBodies(pNamespace As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = -1
    Try {
        Set $NAMESPACE = pNamespace
        Set tCount = 0
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT ID FROM Ens_Archive.MessageBody")
        While tRS.%Next() {
            Set tBody = ##class(Ens.Archive.MessageBody).%OpenId(tRS.%GetData(1))
            If $IsObject(tBody) && ..IsProbeArchive(tBody) Set tCount = tCount + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Whether the archived body <var>pBody</var> is a probe's: its stream carries <parameter>SENTINEL</parameter>, or it names a probe's body id in <parameter>SOURCE</parameter>
/// that this process stored.</p>
ClassMethod IsProbeArchive(pBody As Ens.Archive.MessageBody) As %Boolean
{
    Do pBody.OriginalMessageBodyStream.Rewind()
    If pBody.OriginalMessageBodyStream.Read(100000) [ ..#SENTINEL Quit 1
    Quit $Data(^||OcuArchiveBodies(pBody.OriginalMessageNamespace, pBody.OriginalMessageBodyClassname, pBody.OriginalMessageBodyId)) > 0
}

/// <p>Everything a test left, as one line: <code>headers=&lt;target&gt;/&lt;source&gt; bodies=&lt;n&gt; archived=&lt;n&gt;</code>. Clean is
/// <code>headers=0/0 bodies=0 archived=0</code>.</p>
ClassMethod Left() As %String
{
    Quit "headers=" _ ..Headers(..#TARGET) _ "/" _ ..Headers(..#SOURCE) _ " bodies=" _ ..BodiesLeft() _ " archived=" _ ..ArchivedBodies(..#TARGET)
}

/// <p>Remove every probe header, and the body each names, from <parameter>SOURCE</parameter> and <parameter>TARGET</parameter>, every archived copy of a probe body from
/// <parameter>TARGET</parameter>, and the bodies this process stored whose header was already moved or removed; answer <code>1</code> when nothing survives.</p>
ClassMethod DropProbes() As %Boolean
{
    Set tOrigNS = $NAMESPACE
    For tNamespace = ..#TARGET, ..#SOURCE {
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
            Kill tArchived
            Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT ID FROM Ens_Archive.MessageBody")
            While tRS.%Next() {
                Set tBody = ##class(Ens.Archive.MessageBody).%OpenId(tRS.%GetData(1))
                If $IsObject(tBody) && ..IsProbeArchive(tBody) Set tArchived($Increment(tArchived)) = tRS.%GetData(1)
                Set tBody = ""
            }
            For tI = 1:1:+$Get(tArchived) {
                Do ##class(Ens.Archive.MessageBody).%DeleteId(tArchived(tI))
            }
            Set tClass = ""
            For {
                Set tClass = $Order(^||OcuArchiveBodies(tNamespace, tClass))
                If tClass = "" Quit
                Set tBodyId = ""
                For {
                    Set tBodyId = $Order(^||OcuArchiveBodies(tNamespace, tClass, tBodyId))
                    If tBodyId = "" Quit
                    If $ClassMethod(tClass, "%ExistsId", tBodyId) Do $ClassMethod(tClass, "%DeleteId", tBodyId)
                }
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
    }
    Set tClean = (..Left() = "headers=0/0 bodies=0 archived=0")
    Kill ^||OcuArchiveBodies
    Quit tClean
}

/// <p>The nodes of <code>^Ens.ArchiveManager</code> in <var>pNamespace</var> as one JSON array of <code>{r, v}</code> (the full reference and its value), the root's own value
/// included, in the order <code>$Query</code> walks them.</p>
ClassMethod Tree(pNamespace As %String) As %String
{
    Set tList = []
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRoot = "^Ens.ArchiveManager"
        If $Data(@tRoot) # 2 {
            Set tNode = {}
            Do tNode.%Set("r", tRoot)
            Do tNode.%Set("v", @tRoot)
            Do tList.%Push(tNode)
        }
        Set tRef = tRoot
        For {
            Set tRef = $Query(@tRef)
            If (tRef = "") || ($Extract(tRef, 1, $Length(tRoot) + 1) '= (tRoot _ "(")) Quit
            Set tNode = {}
            Do tNode.%Set("r", tRef)
            Do tNode.%Set("v", @tRef)
            Do tList.%Push(tNode)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tList = ["<unread>"]
    }
    Quit tList.%ToJSON()
}

/// <p>Both namespaces' <code>^Ens.ArchiveManager</code> trees as they stand, as one JSON text.</p>
ClassMethod SaveTrees() As %String
{
    Set tSaved = {}
    Do tSaved.%Set(..#SOURCE, ##class(%DynamicAbstractObject).%FromJSON(..Tree(..#SOURCE)))
    Do tSaved.%Set(..#TARGET, ##class(%DynamicAbstractObject).%FromJSON(..Tree(..#TARGET)))
    Quit tSaved.%ToJSON()
}

/// <p>Put both namespaces' <code>^Ens.ArchiveManager</code> trees back as <method>SaveTrees</method> read them: each tree is killed and its saved nodes set again, so a node that
/// was not there is not.</p>
ClassMethod RestoreTrees(pSaved As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSaved = ##class(%DynamicAbstractObject).%FromJSON(pSaved)
        For tNamespace = ..#SOURCE, ..#TARGET {
            Set tNodes = tSaved.%Get(tNamespace)
            Set $NAMESPACE = tNamespace
            Kill ^Ens.ArchiveManager
            Set tIterator = tNodes.%GetIterator()
            While tIterator.%GetNext(, .tNode) {
                Set tRef = tNode.%Get("r")
                Set @tRef = tNode.%Get("v")
            }
            Set $NAMESPACE = tOrigNS
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Record <var>pCount</var> errors in <var>pNamespace</var>'s last run as the vendor's run records them (an error status, the time, a message id), so the error list can be read
/// past a cap without a run: a run ends at the first error the vendor's trap catches, as a body class that does not exist raises, so such a run makes only one.</p>
ClassMethod SeedErrors(pNamespace As %String, pCount As %Integer)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        For tI = 1:1:pCount {
            Set ^Ens.ArchiveManager("run", "error", tI) = $ListBuild($System.Status.Error(5001, "seeded error " _ tI), $ZDateTime($ZTimeStamp, 3, , 3), 900000 + tI)
        }
        Set ^Ens.ArchiveManager("run", "error") = pCount
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>The archive settings of <var>pNamespace</var> as one line <code>namespace|class|days</code>, each <code>&lt;absent&gt;</code> when the node is not stored.</p>
ClassMethod SettingsText(pNamespace As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = pNamespace
        For tI = 1:1:3 {
            Set tNode = $Piece("Namespace,Classname,DaysToArchive", ",", tI)
            Set tText = tText _ $Select(tI = 1: "", 1: "|") _ $Select($Data(^Ens.ArchiveManager(tNode)) # 2: ^Ens.ArchiveManager(tNode), 1: "<absent>")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "<error " _ ex.DisplayString() _ ">"
    }
    Quit tText
}

/// <p>Store the archive settings of <var>pNamespace</var> as <var>pTarget</var>, <var>pClass</var> and <var>pDays</var> directly, a value of <code>&lt;absent&gt;</code> removing the
/// node.</p>
ClassMethod PutSettings(pNamespace As %String, pTarget As %String, pClass As %String, pDays As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        For tI = 1:1:3 {
            Set tNode = $Piece("Namespace,Classname,DaysToArchive", ",", tI)
            Set tValue = $Case(tI, 1: pTarget, 2: pClass, : pDays)
            If tValue = "<absent>" {
                Kill ^Ens.ArchiveManager(tNode)
            } Else {
                Set ^Ens.ArchiveManager(tNode) = tValue
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Hold the vendor's archive lock in <var>pNamespace</var> in this process until the signal says <code>stop</code> (or 60 seconds pass), and signal <code>1</code> once held and
/// <code>2</code> once released. It is the child job <class>OcuPilot.Test.InteropArchiveRefusals</class> starts, and it ends before that test does.</p>
ClassMethod HoldLock(pNamespace As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Lock +^Ens.ArchiveManager("lock"):5
        If $Test {
            Set ^IRIS.Temp.OcuProbe2416ArcHold = 1
            For tI = 1:1:600 {
                If $Get(^IRIS.Temp.OcuProbe2416ArcHold) = "stop" Quit
                Hang 0.1
            }
            Lock -^Ens.ArchiveManager("lock")
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Set ^IRIS.Temp.OcuProbe2416ArcHold = 2
}

/// <p>The child job <method>LockHeld</method> starts: try the vendor's archive lock of <var>pNamespace</var> at once, let go when it was taken, and signal <code>1</code> to
/// <var>pParent</var> when it was free and <code>0</code> when it was held.</p>
ClassMethod TryLock(pParent As %Integer, pNamespace As %String)
{
    Set tFree = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Lock +^Ens.ArchiveManager("lock"):0
        If $Test {
            Lock -^Ens.ArchiveManager("lock")
            Set tFree = 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Do $System.Event.Signal(pParent, tFree)
}

/// <p>Whether any other process, or this one, holds the vendor's archive lock of <var>pNamespace</var>, asked by a child job so that a hold this process keeps is seen too.</p>
ClassMethod LockHeld(pNamespace As %String) As %Boolean
{
    Do $System.Event.Clear($Job)
    Job ##class(OcuPilot.Test.InteropArchiveFixture).TryLock($Job, pNamespace)::10
    If '$Test Quit 1
    Set tMessage = $System.Event.WaitMsg("", 30)
    Quit ($ListGet(tMessage, 2) '= 1)
}

}
