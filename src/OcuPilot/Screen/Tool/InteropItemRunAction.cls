/// <p>What Interoperability's three item runtime writes share (AD-6, AD-51, AD-52, AD-53, AD-62, Story 20.25): an
/// action-style write of one item of the running production through <class>OcuPilot.Port.InteropPort</class>, reached by two
/// callers -- the Production items row action, and the agent's proposal and confirmation. None sends a body. Each stops or starts
/// the item's jobs through the vendor's temporary stop and then makes the production's own update, so it also applies any other
/// change waiting for the production; none changes the stored configuration or the production class.</p>
/// <p><b>The fresh read is the port's <code>ITEMRUN</code></b>, composed for the action at the mint and at a screen action
/// (<method>OcuPilot.Screen.Tool.InteropAction.PortQuery</method>): a production that is not running, a disabled item, a start of an
/// item not stopped, a stop of one already stopped or running no jobs of its own, and a name held twice are refused by the port with
/// their own <code>INTEROP.*</code> codes, 409, before any vendor call (<parameter>PRECONDITIONCODES</parameter>); the vendor answers
/// the first three as a success. The confirm's re-read is not composed for the action, so an item that moved closes the proposal
/// through the fingerprint, and the write refuses again by the same codes.</p>
/// <p><b>It declares</b> <code>%Ens_ConfigItemRun:USE</code>, the classic page's own check, and WRITE on the namespace's globals
/// database beyond the screen's pairs (AD-8, AD-62), each refused by name before any port call. It declares neither
/// <code>%Ens_ProductionConfig:WRITE</code>, <code>%Ens_ProductionRun:USE</code> nor the routines database: the production
/// definition and class are not changed. It is not destructive: Start undoes a stop, so each governance key ships enabled
/// (AD-22).</p>
Class OcuPilot.Screen.Tool.InteropItemRunAction Extends OcuPilot.Screen.Tool.InteropItemAction [ Abstract ]
{

/// <p>The fresh read: one item's runtime, composed for the action.</p>
Parameter READTYPE = "ITEMRUN";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Production,Name,ClassName,Enabled,EnabledSource,Count,State,Current,TemporarilyStopped,OwnJobs,Jobs,NeedsUpdate,Namespace";

Parameter WRITERESOURCE = "%Ens_ConfigItemRun";

Parameter WRITEPERMISSION = "USE";

/// <p>The production class is not saved, so no routines database is written.</p>
Parameter ROUTINESDATABASE As BOOLEAN = 0;

/// <p>The item runtime read the confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "TemporarilyStopped";

/// <p>The card's one state row: whether the item is stopped, moving to <parameter>AFTERSTOPPED</parameter>.</p>
Parameter STATEFIELD = "TemporarilyStopped";

/// <p>What the card's row shows the stopped flag as after the action: 1 for a stop; 0 for a start and for a restart, which
/// leaves the item running again.</p>
Parameter AFTERSTOPPED As BOOLEAN = 0;

Parameter FINGERPRINTSUBJECT = "State,Enabled,TemporarilyStopped,OwnJobs,NeedsUpdate,Namespace";

Parameter PRECONDITIONFIELD = "TemporarilyStopped";

/// <p>The one row this proposal's card shows, from the fresh read <var>pFresh</var>: <parameter>STATEFIELD</parameter> moving
/// from the item's value to <parameter>AFTERSTOPPED</parameter>. A read that answered no <code>TemporarilyStopped</code> is
/// <var>pProblem</var>, since an item nobody established is not one to act on.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tField = ..#STATEFIELD
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(tField) '= "boolean") {
            Set pProblem = "this instance did not report the item's state"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", tField, "string")
        Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), "boolean"), "string")
        Do tRow.%Set("after", ##class(OcuPilot.Kernel.Proposal.Mint).Display(''..#AFTERSTOPPED, "boolean"), "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
