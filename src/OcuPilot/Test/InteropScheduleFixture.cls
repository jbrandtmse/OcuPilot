/// <p>The probe schedule specs Story 24.15's schedule tests arrange and read (Story 24.15). Every probe schedule spec is named
/// <parameter>PREFIX</parameter> and something, in <parameter>NAMESPACE</parameter> or <parameter>OTHERNAMESPACE</parameter>, and
/// <method>DropSchedules</method> removes each of them, in any letter case. It writes only <code>Ens.Util.Schedule</code>, through the vendor's own
/// calls, and starts no production.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropScheduleFixture Extends %RegisteredObject
{

/// <p>What every probe schedule spec's name begins with.</p>
Parameter PREFIX = "OcuProbe2415S";

/// <p>The namespace the probe schedule specs are written to by default, and the second one a cross-namespace test also writes.</p>
Parameter NAMESPACE = "USER";

Parameter OTHERNAMESPACE = "HSCUSTOM";

/// <p>A valid spec the probes use.</p>
Parameter SPEC = "START:*-*-*T08:00:00,STOP:*-*-*T17:00:00";

/// <p>Store the schedule spec <var>pName</var> in <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when empty) with <var>pSpec</var>,
/// <var>pDescription</var> and <var>pDeployable</var>, through the vendor's own save, which updates one the namespace already holds.</p>
ClassMethod PutSchedule(pName As %String, pSpec As %String = {..#SPEC}, pDescription As %String = "", pDeployable As %Boolean = 0, pNamespace As %String = "") As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
        Set tSchedule = ##class(Ens.Util.Schedule).%OpenId(pName)
        If '$IsObject(tSchedule) {
            Set tSchedule = ##class(Ens.Util.Schedule).%New()
            Set tSchedule.Name = pName
        }
        Set tSchedule.ScheduleSpec = pSpec
        Set tSchedule.Description = pDescription
        Set tSchedule.Deployable = pDeployable
        Set tSC = tSchedule.%Save()
        Set tSchedule = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The schedule spec <var>pName</var> of <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when empty) as
/// <code>spec|description|deployable</code>, or <code>&lt;absent&gt;</code> when the namespace does not hold it exactly.</p>
ClassMethod ScheduleText(pName As %String, pNamespace As %String = "") As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "<absent>"
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
        Set tSchedule = ##class(Ens.Util.Schedule).%OpenId(pName)
        If $IsObject(tSchedule) Set tText = tSchedule.ScheduleSpec _ "|" _ tSchedule.Description _ "|" _ (+tSchedule.Deployable)
        Set tSchedule = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "<error " _ ex.DisplayString() _ ">"
    }
    Quit tText
}

/// <p>How many schedule specs of <var>pNamespace</var> (<parameter>NAMESPACE</parameter> when empty) are named with <var>pPrefix</var>
/// (<parameter>PREFIX</parameter> when empty), in any letter case.</p>
ClassMethod ScheduleCount(pPrefix As %String = {..#PREFIX}, pNamespace As %String = "") As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = 0
    Try {
        Set $NAMESPACE = $Select(pNamespace '= "": pNamespace, 1: ..#NAMESPACE)
        Set tName = ""
        For {
            Set tName = $Order(^Ens.Util.ScheduleD(tName))
            If tName = "" Quit
            If $ZConvert($Extract(tName, 1, $Length(pPrefix)), "U") = $ZConvert(pPrefix, "U") Set tCount = tCount + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Remove every schedule spec named with <var>pPrefix</var> (<parameter>PREFIX</parameter> when empty), in any letter case, from
/// <parameter>NAMESPACE</parameter> and <parameter>OTHERNAMESPACE</parameter>, as the vendor's own delete does; no other schedule spec is touched.</p>
ClassMethod DropSchedules(pPrefix As %String = {..#PREFIX}) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    For tNamespace = ..#NAMESPACE, ..#OTHERNAMESPACE {
        Try {
            Set $NAMESPACE = tNamespace
            Kill tIds
            Set tName = ""
            For {
                Set tName = $Order(^Ens.Util.ScheduleD(tName))
                If tName = "" Quit
                If $ZConvert($Extract(tName, 1, $Length(pPrefix)), "U") = $ZConvert(pPrefix, "U") Set tIds($Increment(tIds)) = tName
            }
            For tI = 1:1:$Get(tIds) {
                Set tSC = $$$ADDSC(tSC, ##class(Ens.Util.Schedule).%DeleteId(tIds(tI)))
            }
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ADDSC(tSC, ex.AsStatus())
        }
    }
    Quit tSC
}

}
