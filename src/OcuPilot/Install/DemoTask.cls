/// <p>The demo walkthrough task (DW-14, AC11, AC9). A <code>%SYS.Task.Definition</code>
/// subclass whose <method>OnTask</method> deliberately returns an error, so that when
/// <class>OcuPilot.Install.Fixture</class> schedules it with <code>SuspendOnError = 1</code>
/// and forces one real run, the Task Manager's own framework -- not this code -- writes
/// readable <code>Error</code> text and sets <code>Suspended &gt; 0</code>. There is no
/// supported setter for those columns; a real, controlled, self-inflicted failure is the
/// only route to them (this story's Design Notes, "DW-14 -- addressed").</p>
/// <p><b><code>Status</code> is deliberately not claimed here.</b> This header previously
/// said the framework writes a populated <code>Status</code> of <code>-2</code>
/// (<code>JobUntrappedError</code>); that is what
/// <class>%SYS.TaskSuper</class>'s own doc comment promises, but it is <b>not</b> what
/// this build does -- see <method>OnTask</method>'s own doc below, where it was verified
/// live and recorded. AC11's "Status below zero" clause was dropped for exactly this
/// reason (this story's <code>## Spec Change Log</code>, 2026-09-10). Corrected at its
/// origin so the superseded claim is not mined from this file later.</p>
/// <p>A separate class because a <code>%SYS.Task.Definition</code> subclass has to be --
/// this is not an AD-17 "one installer class" violation (this story's Design Notes,
/// "Reading of AD-17's 'one installer class'").</p>
Class OcuPilot.Install.DemoTask Extends %SYS.Task.Definition
{

Parameter TaskName = "OcuPilot demo nightly purge";

/// <p>Deliberately fails every run -- the fixture exists to demonstrate the
/// suspended-after-error state (DW-14, Stories 2.8 and 5.11), never to do real work.</p>
/// <p><b>Throws</b> rather than returning a bad <code>%Status</code>: verified live
/// against this build (three independent runs through the real Task Manager daemon via
/// <code>%SYS.Task.RunNow</code>, each observed after its own full ~70-second poll
/// cycle) that a returned bad <code>%Status</code> leaves
/// <property>%SYS.Task.Error</property> <b>empty</b> while
/// <property>%SYS.Task.Status</property> holds the raw, undecoded <code>%Status</code>
/// list value -- satisfying neither half of AC11's "Status below zero and non-empty
/// readable Error text". An uncaught exception instead populates
/// <property>Error</property> with readable text
/// (<code>&lt;THROW&gt;OnTask+1^OcuPilot.Install.DemoTask.1 ...</code>), which is what
/// this method now relies on.</p>
/// <p><b>Recorded, not silently worked around: <property>Status</property> itself does
/// not go negative on this build</b> either way -- confirmed identically for both a
/// thrown <code>%Exception.StatusException</code> and a genuine uncaught
/// <code>&lt;DIVIDE&gt;</code> error, both leaving <property>Status</property> at
/// <code>1</code> (the same value a successful run leaves it at), which contradicts
/// <class>%SYS.TaskSuper</class>'s own doc comment
/// ("<code>JobUntrappedError</code> Status will be <code>-2</code>"). This story's
/// fixture and its test therefore key on <property>Suspended</property> and
/// <property>Error</property> -- both independently verified live and both directly
/// useful to Stories 2.8 and 5.11 -- rather than on a <property>Status</property> value
/// this build never produces through the supported, documented task-running path.</p>
Method OnTask() As %Status
{
    Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "OcuPilot demo task: this task always fails by design, to demonstrate the suspended-after-error state (DW-14)."))
}

}
